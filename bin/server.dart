import "dart:io";
import "dart:convert";
import "dart:async";
import "package:shelf_static/shelf_static.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as io;
import "package:shelf_route/shelf_route.dart";
import "package:managed_mongo/managed_mongo.dart";
import "package:mongo_dart/mongo_dart.dart";

const Map headers = const {HttpHeaders.CONTENT_TYPE: 'application/json', "Access-Control-Allow-Origin": "*"};
final PubClient pubClient = new PubClient.forUrl("https://pub.dartlang.org/api");

var analysisResult;
MongoDB mongodb;

main() async {
  runZoned(() async {
    var downloadUrl = "https://fastdl.mongodb.org/osx/mongodb-osx-x86_64-2.6.5.tgz";
    mongodb = new MongoDB(downloadUrl, workFolder: "mongo");
    await mongodb.start();

    await refreshStats();

    String staticPath = "../build/web";
    if (!new Directory(staticPath).existsSync()) {
      staticPath = "build";
    }
    var staticHandler = createStaticHandler(staticPath, defaultDocument: "index.html");

    var myRouter = router()
      ..get("/api", (_) => new Response.ok("Hello from API"))
      ..get("/api/packages", (request) => new Response.ok(JSON.encode(analysisResult["packageMap"].keys.toList()
      ..sort()), headers: headers))
      ..get("/api/packages/{package}", (request) {
      var report = analysisResult["packageMap"][getPathParameter(request, "package")];
      if (report != null) {
        report["dependents"].sort();
        report["dev_dependents"].sort();
        return new Response.ok(JSON.encode(report), headers: headers);
      } else {
        return new Response.notFound("Package not found");
      }
    });

    var cascade = new Cascade()
    .add(staticHandler)
    .add(myRouter.handler);

    var handler = const Pipeline()
    .addMiddleware(logRequests())
    .addHandler(cascade.handler);

    io.serve(handler, '0.0.0.0', 8080);
  }, onError: (error) async {
    if (mongodb != null) {
      await mongodb.stop();
    }
    throw error;
  });
}

refreshStats() async {
  var packages = await pubClient.getAllPackages();

  Db db = new Db("mongodb://localhost:27017/pubstats");
  await db.open();
  PackageDao packageDao = new PackageDao(db.collection("packages"));
  PackagePersistence packagePersistence = new PackagePersistence(packageDao);
  packages = await packagePersistence.savePackages(packages);
  await db.close();
  PackageAnalyzer packageAnalyzer = new PackageAnalyzer(packages);
  analysisResult = packageAnalyzer.runAnalysis();
  new Future.delayed(const Duration(hours: 24), refreshStats);
}

class PubClient {

  final HttpClient _client = new HttpClient();
  String baseApiUrl;

  PubClient.forUrl(String baseApiUrl) {
    this.baseApiUrl = _normalizeUrl(baseApiUrl);
  }

  _normalizeUrl(String url) {
    if (url.endsWith("/")) {
      return url.substring(0, url.length - 1);
    }
    return url;
  }

  getAllPackages() async {
    var packages = [];
    var currentPage = 1;
    var totalPages = 1;
    while (currentPage <= totalPages) {
      var response = await getPageOfPackages(currentPage);
      packages.addAll(response["packages"]);
      totalPages = response["pages"];
      currentPage++;
    }
    print("${packages.length} packages found");
    return packages;
  }

  Future<Map> getPageOfPackages(pageNumber) async {
    var url = "$baseApiUrl/packages?page=$pageNumber";
    print("Requesting data from $url");
    Completer completer = new Completer();
    HttpClientRequest request = await _client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    response.transform(UTF8.decoder).transform(JSON.decoder).listen((contents) {
      completer.complete(contents);
    });
    return completer.future;
  }
}

class PackagePersistence {
  final PackageDao packageDao;

  PackagePersistence(PackageDao this.packageDao);

  Future<List> savePackages(List packages) async {
    await packageDao.insertPackages(packages);
    return await packageDao.getPackages();
  }
}

class PackageDao {
  final DbCollection collection;

  PackageDao(DbCollection this.collection);

  Future insertPackages(List packages) async {
    return collection.insertAll(packages);
  }

  Future<List<Map>> getPackages() async {
    return collection.find().toList();
  }

}

class PackageAnalyzer {
  List _packages = [];
  var packageMap = {};

  PackageAnalyzer(List this._packages);

  runAnalysis() {
    print("Running analysis for ${_packages.length} packages");
    _packages.forEach((package) {
      var name = package["name"];

      packageMap.putIfAbsent(name, () => {});
      packageMap[name]["package"] = package;
      packageMap[name].putIfAbsent("dependents", () => []);
      packageMap[name].putIfAbsent("dev_dependents", () => []);

      var pubspec = package["latest"]["pubspec"];
      Map dependencies = pubspec["dependencies"];
      if (dependencies != null) {
        dependencies.forEach((key, value) {
          packageMap.putIfAbsent(key, () => {});
          packageMap[key].putIfAbsent("dependents", () => []);
          packageMap[key]["dependents"].add(name);
        });
      }

      var devDependencies = pubspec["dev_dependencies"];
      if (devDependencies != null) {
        devDependencies.forEach((key, value) {
          packageMap.putIfAbsent(key, () => {});
          packageMap[key].putIfAbsent("dev_dependents", () => []);
          packageMap[key]["dev_dependents"].add(name);
        });
      }
    });
    print("Anaylsis complete");
    
    return {
      "packageMap": packageMap
    };
  }
}
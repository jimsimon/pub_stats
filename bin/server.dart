import "dart:io";
import "dart:convert";
import "dart:async";
import "package:shelf_static/shelf_static.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as io;
import "package:shelf_route/shelf_route.dart";

const Map headers = const {HttpHeaders.CONTENT_TYPE: 'application/json', "Access-Control-Allow-Origin": "*"};
final PubClient pubClient = new PubClient.forUrl("https://pub.dartlang.org/api");

var analysisResult;

main() async {
  await refreshStats();

  String staticPath = "../build/web";
  if (!new Directory(staticPath).existsSync()) {
    staticPath = "build";
  }
  var staticHandler = createStaticHandler(staticPath, defaultDocument: "index.html");

  var myRouter = router()
    ..get("/api", (_) => new Response.ok("Hello from API"))
    ..get("/api/packages", (request) => new Response.ok(JSON.encode(analysisResult["packageMap"].keys.toList()), headers: headers))
    ..get("/api/packages/{package}", (request) {
      var report = analysisResult["packageMap"][getPathParameter(request, "package")];
      if (report != null) {
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
}

refreshStats() async {
  var packages = await pubClient.getAllPackages();
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
import "dart:io";
import "dart:convert";
import "dart:async";
import "package:shelf_static/shelf_static.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as io;
import "package:shelf_route/shelf_route.dart";
import "package:managed_mongo/managed_mongo.dart";
import "package:mongo_dart/mongo_dart.dart";
import "package:pub_client/pub_client.dart";
import "package:dartson/dartson.dart";
import "package:dartson/transformers/date_time.dart";
import "package:logging/logging.dart";
import "package:dartson/type_transformer.dart";
import "dart:mirrors";

final Map _HEADERS = const {"Content-Type": "application/json"};

final Dartson dartson = new Dartson.JSON();
final PubClient pubClient = new PubClient();

var analysisResult;
MongoDB mongodb;

Future<Type> _getTwoByteStringType() async {
  MirrorSystem ms = await currentMirrorSystem();
  Uri uri = Uri.parse("dart:core");
  LibraryMirror lm = ms.libraries[uri];
  Type type;
  lm.declarations.forEach((Symbol name, DeclarationMirror value){
    if (MirrorSystem.getName(name).contains("_TwoByteString")) {
      type = (value as TypeMirror).reflectedType;
    }
  });
  if (type != null) {
    return type;
  }
  throw new Exception("dart.core._TwoByteString type not found");
}

main() async {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  runZoned(() async {
    dartson.addTransformer(new DateTimeParser(), DateTime);
    dartson.addTransformer(new TwoByteStringTransformer(), await _getTwoByteStringType());
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
      ..sort()), headers: _HEADERS))
      ..get("/api/packages/{package}", (request) {
      var report = analysisResult["packageMap"][getPathParameter(request, "package")];
      if (report != null) {
        report["dependents"].sort();
        report["dev_dependents"].sort();
        var json = dartson.encode(report);
        return new Response.ok(json, headers: _HEADERS);
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
  stdout.write("refreshing packages...");
  List<Package> packages = await pubClient.getAllPackages();
  stdout.writeln("done");

  Db db = new Db("mongodb://localhost:27017/pubstats");
  await db.open();
  PackageDao packageDao = new PackageDao(db.collection("packages"));
  PackagePersistence packagePersistence = new PackagePersistence(packageDao);
  packages = await packagePersistence.savePackages(packages);
  await db.close();
  stdout.write("refreshing stats...");
  PackageAnalyzer packageAnalyzer = new PackageAnalyzer(packages);
  analysisResult = packageAnalyzer.runAnalysis();
  new Future.delayed(const Duration(hours: 24), refreshStats);
  stdout.writeln("done");
}

class PackagePersistence {
  final PackageDao packageDao;

  PackagePersistence(PackageDao this.packageDao);

  Future<List> savePackages(List<Package> packages) async {
    await packageDao.insertPackages(packages);
    var dbPackages = await packageDao.getPackages();
    return dbPackages;
  }
}

class PackageDao {
  final DbCollection collection;

  PackageDao(DbCollection this.collection);

  Future insertPackages(List<Package> packages) async {
    List<Map> data = dartson.serialize(packages);
    collection.insertAll(data);
  }

  Future<List<Package>> getPackages() async {
    List<Map> data = await collection.find().toList();
    return dartson.map(data, new Package(), true);
  }
}

class PackageAnalyzer {
  List<Package> _packages = [];
  var packageMap = {};

  PackageAnalyzer(List<Package> this._packages);

  runAnalysis() {
    print("Running analysis for ${_packages.length} packages");
    _packages.forEach((package) {
      var name = package.name;

      packageMap.putIfAbsent(name, () => {});
      packageMap[name]["package"] = package;
      packageMap[name].putIfAbsent("dependents", () => []);
      packageMap[name].putIfAbsent("dev_dependents", () => []);

      var pubspec = package.latest.pubspec;
      Map dependencies = pubspec.dependencies;
      if (dependencies != null) {
        dependencies.forEach((key, value) {
          packageMap.putIfAbsent(key, () => {});
          packageMap[key].putIfAbsent("dependents", () => []);
          packageMap[key]["dependents"].add(name);
        });
      }

      var devDependencies = pubspec.dev_dependencies;
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

class TwoByteStringTransformer extends TypeTransformer {

  @override
  decode(value) {
    return value as String;
  }

  @override
  encode(value) {
    return value as String;
  }
}
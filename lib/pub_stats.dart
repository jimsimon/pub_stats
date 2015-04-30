library pub_stats;

import "dart:io";
import "dart:convert";
import "dart:async";
import "package:shelf/shelf.dart";
import "package:shelf_route/shelf_route.dart" as route;
import "package:mongo_dart/mongo_dart.dart";
import "package:pub_client/pub_client.dart";
import "package:dartson/dartson.dart";
import "package:dartson/transformers/date_time.dart";
import "package:dartson/type_transformer.dart";
import "dart:mirrors";

part "src/package_persistence.dart";
part "src/package_dao.dart";
part "src/package_analyzer.dart";
part "src/two_byte_string_transformer.dart";

final Map _HEADERS = const {"Content-Type": "application/json"};

final PubClient pubClient = new PubClient();

class PubStatsServer {

  final Dartson dartson;

  var analysisResult;

  static Future<PubStatsServer> getInstance() async {
    Dartson dartson = new Dartson.JSON();
    dartson.addTransformer(new DateTimeParser(), DateTime);
    dartson.addTransformer(new TwoByteStringTransformer(), await _getTwoByteStringType());
    return new PubStatsServer._internal(dartson);
  }

  PubStatsServer._internal(Dartson this.dartson);

  get router async {
    var myRouter = route.router()
      ..get("/api", (_) => new Response.ok("Hello from API"))
      ..get("/api/packages", (request) => new Response.ok(JSON.encode(analysisResult["packageMap"].keys.toList()
      ..sort()), headers: _HEADERS))
      ..get("/api/packages/{package}", (request) {
        var report = analysisResult["packageMap"][route.getPathParameter(request, "package")];
        if (report != null) {
          report["dependents"].sort();
          report["dev_dependents"].sort();
          var json = dartson.encode(report);
          return new Response.ok(json, headers: _HEADERS);
        } else {
          return new Response.notFound("Package not found");
        }
      });
    return myRouter;
  }

  refreshStats() async {
    stdout.write("refreshing packages...");
    List<Package> packages = await pubClient.getAllPackages();
//    List<Package> packages = (await pubClient.getPageOfPackages(1)).packages;
    stdout.writeln("done");

//    Db db = new Db("mongodb://localhost:27017/pubstats");
//    await db.open();
//    PackageDao packageDao = new PackageDao(dartson, db.collection("packages"));
//    PackagePersistence packagePersistence = new PackagePersistence(packageDao);
//    packages = await packagePersistence.savePackages(packages);
//    await db.close();
    stdout.write("refreshing stats...");
    PackageAnalyzer packageAnalyzer = new PackageAnalyzer(packages);
    analysisResult = packageAnalyzer.runAnalysis();
    new Future.delayed(const Duration(hours: 24), refreshStats);
    stdout.writeln("done");
  }

  static Future<Type> _getTwoByteStringType() async {
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
}
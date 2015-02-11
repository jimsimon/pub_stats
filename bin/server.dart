import "dart:io";
import "dart:convert";
import "dart:async";
import "package:shelf_static/shelf_static.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as io;
import "package:shelf_route/shelf_route.dart";

const Map headers = const {HttpHeaders.CONTENT_TYPE: 'application/json', "Access-Control-Allow-Origin": "*"};

String startingUrl = "https://pub.dartlang.org/api/packages";
PubStats pubStats;

main() async {

  await refreshStats();

  var staticHandler = createStaticHandler("build", defaultDocument: "index.html");

  var myRouter = router()
    ..get("/api", (_) => new Response.ok("Hello from API"))
    ..get("/api/packages", (request) => new Response.ok(JSON.encode(pubStats.reverseDependencyMap.keys.toList()), headers: headers))
    ..get("/api/packages/{package}", (request) {
      var report = pubStats.getReportForPackage(getPathParameter(request, "package"));
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
  PubStats newPubStats = new PubStats.forUrl(startingUrl);
  await newPubStats.collect();
  pubStats = newPubStats;
  new Future.delayed(const Duration(hours: 24), refreshStats);
}

class PubStats {

  final HttpClient _client = new HttpClient();

  String url;

  var packages = [];
  var reverseDependencyMap = {};

  PubStats.forUrl(this.url);

  collect() async {
    await _fetchPackages();
    _parsePackages();
  }

  getReportForPackage(String packageName) {
    return reverseDependencyMap[packageName];
  }

  _fetchPackages() async {
//    while (url != null) {
      print("Fetching $url");
      var response = await _fetchPage(url);
      url = response["next_url"];
      packages.addAll(response["packages"]);
      print("${packages.length} packages retrieved so far...");
//    }
  }

  _parsePackages() {
    packages.forEach((package) {
      var name = package["name"];

      var pubspec = package["latest"]["pubspec"];
      Map dependencies = pubspec["dependencies"];
      if (dependencies != null) {
        dependencies.forEach((key, value) {
          reverseDependencyMap.putIfAbsent(key, () => {});
          reverseDependencyMap[key].putIfAbsent("dependents", () => []);
          reverseDependencyMap[key]["dependents"].add(name);
        });
      }

      var devDependencies = pubspec["dev_dependencies"];
      if (devDependencies != null) {
        devDependencies.forEach((key, value) {
          reverseDependencyMap.putIfAbsent(key, () => {});
          reverseDependencyMap[key].putIfAbsent("dev_dependents", () => []);
          reverseDependencyMap[key]["dev_dependents"].add(name);
        });
      }
    });
//    print(reverseDependencyMap);
  }

  _fetchPage(String url) async {
    Completer completer = new Completer();
    HttpClientRequest request = await _client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    response.transform(UTF8.decoder).transform(JSON.decoder).listen((contents) {
      completer.complete(contents);
    });
    return completer.future;
  }
}
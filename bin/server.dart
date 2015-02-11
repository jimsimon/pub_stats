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

  var staticHandler = createStaticHandler("build", defaultDocument: "index.html");

  var myRouter = router()
    ..get("/api", (_) => new Response.ok("Hello from API"))
    ..get("/api/packages", (request) => new Response.ok(JSON.encode(analysisResult["reverseDependencyMap"].keys.toList()), headers: headers))
    ..get("/api/packages/{package}", (request) {
      var report = analysisResult["reverseDependencyMap"][getPathParameter(request, "package")];
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

  getPageOfPackages(pageNumber) async {
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
  var _reverseDependencyMap = {};

  PackageAnalyzer(List this._packages);

  runAnalysis() {
    print("Running analysis for ${_packages.length} packages");
    _packages.forEach((package) {
      var name = package["name"];

      var pubspec = package["latest"]["pubspec"];
      Map dependencies = pubspec["dependencies"];
      if (dependencies != null) {
        dependencies.forEach((key, value) {
          _reverseDependencyMap.putIfAbsent(key, () => {});
          _reverseDependencyMap[key].putIfAbsent("dependents", () => []);
          _reverseDependencyMap[key]["dependents"].add(name);
        });
      }

      var devDependencies = pubspec["dev_dependencies"];
      if (devDependencies != null) {
        devDependencies.forEach((key, value) {
          _reverseDependencyMap.putIfAbsent(key, () => {});
          _reverseDependencyMap[key].putIfAbsent("dev_dependents", () => []);
          _reverseDependencyMap[key]["dev_dependents"].add(name);
        });
      }
    });
    print("Anaylsis complete");

    return {
      "reverseDependencyMap": _reverseDependencyMap
    };
  }
}
import "dart:io";
import "dart:convert";
import "dart:async";

final packageName = "unittest";

main() async {
  String url = "https://pub.dartlang.org/api/packages";
  var packages = [];
  PubStats pubStats = new PubStats();
//  while (url != null) {
    print("Fetching $url");
    var response = await pubStats.fetchPage(url);
    url = response["next_url"];
    packages.addAll(response["packages"]);
    print("${packages.length} packages retrieved so far...");
//  }

  var referencingPackages = packages.where((package) {
    var pubspec = package["latest"]["pubspec"];
    var dependencies = pubspec["dependencies"];
    var devDependencies = pubspec["dev_dependencies"];
    return (dependencies != null && dependencies.containsKey(packageName)) || (devDependencies != null && devDependencies.containsKey(packageName));
  });
  print("Found ${referencingPackages.length} packages: ");
  referencingPackages.forEach((package) => print(package["name"]));
}

class PubStats {
  HttpClient client = new HttpClient();

  fetchPage(String url) async {
    Completer completer = new Completer();
    HttpClientRequest request = await client.getUrl(Uri.parse(url));
    HttpClientResponse response = await request.close();
    response.transform(UTF8.decoder).transform(JSON.decoder).listen((contents) {
        completer.complete(contents);
    });
    return completer.future;
  }
}
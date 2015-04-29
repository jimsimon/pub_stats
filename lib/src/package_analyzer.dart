part of pub_stats;

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
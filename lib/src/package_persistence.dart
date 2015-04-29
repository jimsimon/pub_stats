part of pub_stats;

class PackagePersistence {
  final PackageDao packageDao;

  PackagePersistence(PackageDao this.packageDao);

  Future<List> savePackages(List<Package> packages) async {
    await packageDao.insertPackages(packages);
    var dbPackages = await packageDao.getPackages();
    return dbPackages;
  }
}
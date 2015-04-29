part of pub_stats;

class PackageDao {
  final Dartson dartson;
  final DbCollection collection;

  PackageDao(Dartson this.dartson, DbCollection this.collection);

  Future insertPackages(List<Package> packages) async {
    List<Map> data = dartson.serialize(packages);
    collection.insertAll(data);
  }

  Future<List<Package>> getPackages() async {
    List<Map> data = await collection.find().toList();
    return dartson.map(data, new Package(), true);
  }
}
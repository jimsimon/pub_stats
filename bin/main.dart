import "dart:io";
import "package:managed_mongo/managed_mongo.dart";
import "package:logging/logging.dart";
import "package:pub_stats/pub_stats.dart";
import "package:shelf_static/shelf_static.dart";
import "package:shelf/shelf.dart";
import "package:shelf/shelf_io.dart" as io;

MongoDB mongodb;

main() async {
  Logger.root.level = Level.WARNING;
  Logger.root.onRecord.listen((LogRecord rec) {
    print('${rec.level.name}: ${rec.time}: ${rec.message}');
  });
  try {
    var downloadUrl = "https://fastdl.mongodb.org/osx/mongodb-osx-x86_64-2.6.5.tgz";
    mongodb = new MongoDB(downloadUrl, workFolder: "mongo");
//    await mongodb.start();

    String staticPath = "build/web";
    if (!new Directory(staticPath).existsSync()) {
      throw "Unable to find built web folder for static route";
    }
    var staticHandler = createStaticHandler(staticPath, defaultDocument: "index.html");

    PubStatsServer server = await PubStatsServer.getInstance();
    await server.refreshStats();
    var pubStatsRouter = await server.router;

    var cascade = new Cascade()
    .add(staticHandler)
    .add(pubStatsRouter.handler);

    var handler = const Pipeline()
    .addMiddleware(logRequests())
    .addHandler(cascade.handler);

    io.serve(handler, '0.0.0.0', 8080);
  } catch(error) {
    if (mongodb != null) {
      await mongodb.stop();
    }
  };
}






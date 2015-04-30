import 'package:polymer/polymer.dart';

/**
 * A Polymer pubstats-package element.
 */
@CustomTag('package-dependency-list')
class PubstatsPackage extends PolymerElement {

  @published String label;
  @published var dependencies = [];

  /// Constructor used to create instance of PubstatsPackage.
  PubstatsPackage.created() : super.created() {}

  get dependencyCount => dependencies != null ? dependencies.length : 0;

  sortIterable(iterable) => iterable.toList()..sort();
}

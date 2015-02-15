import 'package:polymer/polymer.dart';
import "dart:convert";

/**
 * A Polymer pubstats-package element.
 */
@CustomTag('pubstats-package')
class PubstatsPackage extends PolymerElement {

  @published var name;
  @observable var package;

  /// Constructor used to create instance of PubstatsPackage.
  PubstatsPackage.created() : super.created() {
  }

  sortIterable(iterable) => iterable.toList()..sort();

  take(number) => (list) => list.take(number);
}

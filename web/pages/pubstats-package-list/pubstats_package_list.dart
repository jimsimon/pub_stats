import 'package:polymer/polymer.dart';

/**
 * A Polymer pubstats-package-list element.
 */
@CustomTag('pubstats-package-list')

class PubstatsPackageList extends PolymerElement {

  @observable var packages;

  /// Constructor used to create instance of PubstatsPackageList.
  PubstatsPackageList.created() : super.created() {
  }
}

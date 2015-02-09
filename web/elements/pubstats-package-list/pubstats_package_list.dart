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

  /*
   * Optional lifecycle methods - uncomment if needed.
   *

  /// Called when an instance of pubstats-package-list is inserted into the DOM.
  attached() {
    super.attached();
  }

  /// Called when an instance of pubstats-package-list is removed from the DOM.
  detached() {
    super.detached();
  }

  /// Called when an attribute (such as  a class) of an instance of
  /// pubstats-package-list is added, changed, or removed.
  attributeChanged(String name, String oldValue, String newValue) {
  }

  /// Called when pubstats-package-list has been fully prepared (Shadow DOM created,
  /// property observers set up, event listeners attached).
  ready() {
  }
   
  */
  
}

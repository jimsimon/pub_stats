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

  String toJSON(package) {
    return JSON.encode(package);
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

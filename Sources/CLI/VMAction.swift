import Foundation

/// What `hangar vm <action>` can do.
enum VMAction: String {
  case start
  case stop
  case suspend
  case kill
  case ip
}

import Darwin
import Foundation

private enum Constants {
  static let loopback = "127.0.0.1"
  /// How far past the preferred port to look for a free one.
  static let searchRange = 100
}

/// Whether something listens on a local port, and which nearby port is free.
enum PortProbe {
  /// True when a TCP connect to 127.0.0.1:`port` succeeds.
  static func isListening(_ port: Int) -> Bool {
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else { return false }
    defer { close(socket) }
    var address = loopbackAddress(port)
    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    return result == 0
  }

  /// `preferred` if nothing holds it, else the next port that binds; nil if none does.
  static func freePort(from preferred: Int) -> Int? {
    (preferred..<preferred + Constants.searchRange).first(where: canBind)
  }

  /// Whether a socket can bind to the port right now — stricter than connect, which misses
  /// servers that only listen on another interface.
  static func canBind(_ port: Int) -> Bool {
    let socket = Darwin.socket(AF_INET, SOCK_STREAM, 0)
    guard socket >= 0 else { return false }
    defer { close(socket) }
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(UInt16(port).bigEndian)
    address.sin_addr.s_addr = INADDR_ANY
    let result = withUnsafePointer(to: &address) {
      $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        bind(socket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
      }
    }
    return result == 0
  }

  private static func loopbackAddress(_ port: Int) -> sockaddr_in {
    var address = sockaddr_in()
    address.sin_family = sa_family_t(AF_INET)
    address.sin_port = in_port_t(UInt16(port).bigEndian)
    inet_pton(AF_INET, Constants.loopback, &address.sin_addr)
    return address
  }
}

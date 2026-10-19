import Foundation
import Network

private enum Constants {
  /// Port 80 first, for URLs without a port; then DevTray's fallbacks.
  static let httpPort: UInt16 = 80
  static let firstFallbackPort: UInt16 = 7878
  static let secondFallbackPort: UInt16 = 8787
  static let thirdFallbackPort: UInt16 = 9977
  static let candidatePorts = [httpPort, firstFallbackPort, secondFallbackPort, thirdFallbackPort]
  static let queueLabel = "com.burakustun.hangar.proxy"
}

/// Serves `http://<name>.localhost` by forwarding each connection to the port of the project
/// that owns the name. Bytes are piped unchanged after the first request head, so WebSockets
/// (hot reload) and streaming work, and the app still sees its own `Host`.
///
/// macOS lets an unprivileged process listen on port 80 only on every interface, never on
/// loopback alone — so the proxy listens everywhere and drops any connection that does not
/// come from this Mac.
final class LocalhostProxy: @unchecked Sendable {
  // Everything below is touched only on `queue`.
  private let queue = DispatchQueue(label: Constants.queueLabel)
  private var listener: NWListener?
  private var routes: [String: Int] = [:]
  private var liveSessions: [ObjectIdentifier: ProxySession] = [:]
  private let candidatePorts: [UInt16]

  /// `candidatePorts` are tried in order; tests pass their own.
  init(candidatePorts: [UInt16] = Constants.candidatePorts) {
    self.candidatePorts = candidatePorts
  }

  /// Starts on the first candidate port that is free and reports it, or nil if none was.
  func start(onReady: @escaping @Sendable (UInt16?) -> Void) {
    queue.async { self.listen(on: self.candidatePorts[...], onReady: onReady) }
  }

  /// Replaces the host → port table.
  func setRoutes(_ routes: [String: Int]) {
    queue.async { self.routes = routes }
  }

  func stop() {
    queue.async {
      self.listener?.cancel()
      self.listener = nil
    }
  }

  private func listen(on ports: ArraySlice<UInt16>, onReady: @escaping @Sendable (UInt16?) -> Void)
  {
    guard let port = ports.first, let endpointPort = NWEndpoint.Port(rawValue: port),
      let listener = try? NWListener(using: .tcp, on: endpointPort)
    else {
      if ports.isEmpty { onReady(nil) } else { listen(on: ports.dropFirst(), onReady: onReady) }
      return
    }
    listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
    listener.stateUpdateHandler = { [weak self, weak listener] state in
      guard let self else { return }
      switch state {
      case .ready:
        onReady(port)
      case .failed, .waiting:
        listener?.cancel()
        if self.listener === listener {
          self.listener = nil
          self.listen(on: ports.dropFirst(), onReady: onReady)
        }
      default:
        break
      }
    }
    self.listener = listener
    listener.start(queue: queue)
  }

  private func accept(_ connection: NWConnection) {
    guard Self.isFromThisMac(connection.endpoint) else {
      connection.cancel()
      return
    }
    let session = ProxySession(client: connection, queue: queue) { [weak self] host in
      self?.routes[host]
    }
    let id = ObjectIdentifier(session)
    liveSessions[id] = session
    session.onFinish = { [weak self] in self?.liveSessions[id] = nil }
    session.start()
  }

  /// Loopback only, IPv4 or IPv6 (including IPv4-mapped).
  static func isFromThisMac(_ endpoint: NWEndpoint) -> Bool {
    guard case .hostPort(let host, _) = endpoint else { return false }
    switch host {
    case .ipv4(let address): return address.isLoopback
    case .ipv6(let address): return address.isLoopback || address.asIPv4?.isLoopback == true
    default: return false
    }
  }
}

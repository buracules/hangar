import Foundation
import Network

private enum Constants {
  /// A request head bigger than this is not a browser's.
  static let maxHeadBytes = 32_768
  static let chunkBytes = 65_536
  static let backendHost = "localhost"
}

/// One client connection: reads the first request head, picks the backend by its `Host`,
/// then pipes bytes both ways until either side closes. Runs on the proxy's queue.
final class ProxySession: @unchecked Sendable {
  var onFinish: (() -> Void)?

  private let client: NWConnection
  private let queue: DispatchQueue
  private let route: (String) -> Int?
  private var backend: NWConnection?
  private var head = Data()
  private var isFinished = false
  /// Directions that have ended; the session is over when both have.
  private var closedDirections = 0

  init(client: NWConnection, queue: DispatchQueue, route: @escaping (String) -> Int?) {
    self.client = client
    self.queue = queue
    self.route = route
  }

  func start() {
    client.stateUpdateHandler = { [weak self] state in
      if case .failed = state { self?.finish() }
      if case .cancelled = state { self?.finish() }
    }
    client.start(queue: queue)
    readHead()
  }

  private func readHead() {
    read(from: client) { [weak self] data, isComplete, error in
      guard let self else { return }
      if let data { head.append(data) }
      if HTTPRequestHead.isComplete(head) {
        connectBackend()
      } else if error != nil || isComplete || head.count > Constants.maxHeadBytes {
        finish()
      } else {
        readHead()
      }
    }
  }

  private func connectBackend() {
    guard let host = HTTPRequestHead.host(in: head) else { return reply(ProxyResponse.badRequest) }
    guard let port = route(host), let endpointPort = NWEndpoint.Port(rawValue: UInt16(port)) else {
      return reply(ProxyResponse.unknownHost(host))
    }
    // "localhost" lets Network race ::1 and 127.0.0.1: Vite and Node often bind only one.
    let backend = NWConnection(
      host: NWEndpoint.Host(Constants.backendHost),
      port: endpointPort,
      using: .tcp
    )
    self.backend = backend
    backend.stateUpdateHandler = { [weak self] state in
      guard let self else { return }
      switch state {
      case .ready:
        backend.send(content: head, completion: .contentProcessed { _ in })
        pump(from: client, to: backend)
        pump(from: backend, to: client)
      case .waiting, .failed:
        backend.stateUpdateHandler = nil
        backend.cancel()
        reply(ProxyResponse.notListening(host, port: port))
      default:
        break
      }
    }
    backend.start(queue: queue)
  }

  /// Copies one direction until it ends, then half-closes the other side so a response
  /// still in flight can finish.
  private func pump(from source: NWConnection, to destination: NWConnection) {
    read(from: source) { [weak self] data, isComplete, error in
      guard let self, !isFinished else { return }
      if let data, !data.isEmpty {
        destination.send(content: data, completion: .contentProcessed { _ in })
      }
      if isComplete {
        destination.send(
          content: nil,
          contentContext: .finalMessage,
          isComplete: true,
          completion: .idempotent
        )
        closedDirections += 1
      }
      if error != nil || closedDirections == 2 {
        finish()
      } else if !isComplete {
        pump(from: source, to: destination)
      }
    }
  }

  /// Up to one chunk from `connection`, as soon as any bytes arrive.
  private func read(
    from connection: NWConnection,
    _ handler: @escaping (Data?, Bool, NWError?) -> Void
  ) {
    let size = Constants.chunkBytes
    connection.receive(minimumIncompleteLength: 1, maximumLength: size) { data, _, done, error in
      handler(data, done, error)
    }
  }

  private func reply(_ response: Data) {
    client.send(
      content: response,
      contentContext: .finalMessage,
      isComplete: true,
      completion: .contentProcessed { [weak self] _ in
        self?.finish()
      }
    )
  }

  private func finish() {
    guard !isFinished else { return }
    isFinished = true
    client.cancel()
    backend?.cancel()
    onFinish?()
    onFinish = nil
  }
}

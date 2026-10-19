import Foundation
import Network
import Testing

@testable import Hangar

struct LocalhostNameTests {
  @Test func projectNamesBecomeSlugs() {
    #expect(LocalhostName.defaultHost(for: "Portal Web") == "portal-web.localhost")
    #expect(LocalhostName.defaultHost(for: "  Café_API v2 ") == "caf-api-v2.localhost")
    #expect(LocalhostName.defaultHost(for: "!!!") == "project.localhost")
  }

  @Test func configuredHostnamesAreCleanedUp() {
    #expect(LocalhostName.normalize("http://Canvas.localhost:4301/x") == "canvas.localhost")
    #expect(LocalhostName.normalize("canvas") == "canvas.localhost")
    #expect(LocalhostName.normalize("not a host") == nil)
  }

  @Test func theHostComesFromTheRequestHeadWithoutItsPort() {
    let head = Data("GET / HTTP/1.1\r\nUser-Agent: x\r\nHOST: Portal-Web.localhost:80\r\n\r\n".utf8)
    #expect(HTTPRequestHead.isComplete(head))
    #expect(HTTPRequestHead.host(in: head) == "portal-web.localhost")
    #expect(!HTTPRequestHead.isComplete(Data("GET / HTTP/1.1\r\nHost: a".utf8)))
  }

  @Test func onlyLoopbackPeersAreServed() {
    let local = NWEndpoint.hostPort(host: "127.0.0.1", port: 5000)
    let localV6 = NWEndpoint.hostPort(host: "::1", port: 5000)
    let lan = NWEndpoint.hostPort(host: "192.168.1.20", port: 5000)
    #expect(LocalhostProxy.isFromThisMac(local))
    #expect(LocalhostProxy.isFromThisMac(localV6))
    #expect(!LocalhostProxy.isFromThisMac(lan))
  }
}

struct LocalhostProxyTests {
  /// The HTTP status curl gets for `url`.
  private func status(_ url: String) async throws -> String {
    let curl = try ChildProcess(
      command: "curl -s -o /dev/null -m 5 -w '%{http_code}' \(url)",
      directory: FileManager.default.temporaryDirectory,
      environment: ProcessInfo.processInfo.environment
    )
    var out = ""
    for await (isStderr, data) in curl.output() where !isStderr {
      out += String(bytes: data, encoding: .utf8) ?? ""
    }
    _ = await curl.waitForExit()
    return out
  }

  /// A free port for a throwaway listener.
  private func freePort() throws -> Int {
    try #require(PortProbe.freePort(from: 41_000))
  }

  @Test func aRequestForAHostnameReachesItsProjectsPort() async throws {
    let backendPort = try freePort()
    let backend = try ChildProcess(
      command: "exec python3 -m http.server \(backendPort) --bind 127.0.0.1",
      directory: FileManager.default.temporaryDirectory,
      environment: ProcessInfo.processInfo.environment
    )
    defer { backend.signal(SIGTERM) }
    let proxyPort = try freePort() + 1
    let proxy = LocalhostProxy(candidatePorts: [UInt16(proxyPort)])
    let ready: UInt16? = await withCheckedContinuation { continuation in
      proxy.start { continuation.resume(returning: $0) }
    }
    defer { proxy.stop() }
    #expect(ready == UInt16(proxyPort))
    proxy.setRoutes(["demo.localhost": backendPort])
    for _ in 0..<50 where !PortProbe.isListening(backendPort) {
      try await Task.sleep(for: .milliseconds(100))
    }

    // curl, not URLSession: App Transport Security blocks plain HTTP to *.localhost names
    // inside the app, while browsers allow it.
    #expect(try await status("http://demo.localhost:\(proxyPort)/") == "200")
    #expect(try await status("http://nope.localhost:\(proxyPort)/") == "404")
  }
}

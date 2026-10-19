import AppKit
import Foundation
import Observation

private enum Constants {
  static let flushIntervalMilliseconds = 100
  /// How often to look for the port while starting, then how often to health-check.
  static let startProbeMilliseconds = 500
  static let healthIntervalSeconds = 10
  /// Failures in a row before a running project counts as unhealthy.
  static let unhealthyAfter = 2
  /// SIGTERM, then SIGKILL if the group is still there after this long.
  static let stopGraceSeconds = 5
  static let portVariable = "PORT"
  static let forceColorVariable = "FORCE_COLOR"
  static let localhost = "http://localhost:"
  static let healthTimeoutSeconds: TimeInterval = 5
  static let successCodes = 200..<400
  static let millisecondsPerSecond = 1000
  static let attosecondsPerMillisecond: Int64 = 1_000_000_000_000_000
}

/// One project's process while Hangar runs it: state, port, output and health. Processes
/// are Hangar's children, so they stop when Hangar quits.
@MainActor
@Observable
final class ProjectRun {
  /// Where the run is.
  enum State: Equatable {
    case stopped
    case starting
    case running
    case unhealthy(String)
    case stopping
    case crashed(exitCode: Int32)
    case failed(String)
  }

  private(set) var state = State.stopped {
    didSet { if state != oldValue { onChange?() } }
  }
  /// The port it was given; may differ from the spec's when that one was taken.
  private(set) var port: Int?
  /// Why the port differs from the preferred one: "3000 was taken".
  private(set) var portNote: String?
  private(set) var pid: Int32?
  private(set) var startedAt: Date?
  /// The last health check, for "200 in 84 ms".
  private(set) var lastHealth: HealthCheckResult?
  /// The command line actually run.
  private(set) var command: String?
  let buffer = LogBuffer()

  /// Records an event for the timeline: outcome, title, cause, detail.
  typealias Recorder = (ActivityEvent.Outcome, String, String?, String?) -> Void

  /// Called with each event worth a line in the timeline.
  @ObservationIgnored var record: Recorder?
  /// Called after every state change, so the proxy can re-route.
  @ObservationIgnored var onChange: (() -> Void)?
  /// The address to open in the browser — the proxy's `*.localhost` one when it has it.
  @ObservationIgnored var browserURL: ((String) -> URL?)?

  @ObservationIgnored private var process: ChildProcess?
  @ObservationIgnored private var probeTask: Task<Void, Never>?
  @ObservationIgnored private var isStopRequested = false

  var isActive: Bool {
    switch state {
    case .starting, .running, .unhealthy, .stopping: true
    case .stopped, .crashed, .failed: false
    }
  }

  /// Starts the project; does nothing while it is already running.
  func start(_ project: Project, spec: ProjectSpec, cause: String?) {
    guard !isActive else { return }
    guard let preferred = spec.command else {
      state = .failed("No start command — add a .hangar.json with \"command\".")
      return
    }
    resolvePort(spec)
    if case .failed = state { return }
    let launch = spec.launchCommand(port: port) ?? preferred
    var environment = ProcessInfo.processInfo.environment.merging(spec.env) { $1 }
    environment[Constants.forceColorVariable] = "1"
    if let port { environment[Constants.portVariable] = String(port) }
    buffer.reset()
    buffer.stage([.note("$ \(launch)")])
    do {
      let process = try ChildProcess(
        command: launch,
        directory: project.url,
        environment: environment
      )
      self.process = process
      command = launch
      pid = process.pid
      startedAt = .now
      lastHealth = nil
      isStopRequested = false
      state = .starting
      record?(.busy, "Started", cause, "PID \(process.pid)")
      readOutput(process)
      watchExit(process, project: project, spec: spec)
      probeTask = probe(spec)
    } catch {
      state = .failed(error.localizedDescription)
      buffer.end(error.localizedDescription)
    }
  }

  /// Asks the group to stop, then kills it if it lingers.
  func stop(cause: String?) {
    guard let process, isActive else { return }
    isStopRequested = true
    state = .stopping
    process.signal(SIGTERM)
    record?(.stopped, "Stopped", cause, nil)
    Task {
      try? await Task.sleep(for: .seconds(Constants.stopGraceSeconds))
      if self.process === process { process.signal(SIGKILL) }
    }
  }

  /// Kills the group at once — for quitting Hangar.
  func terminateNow() {
    process?.signal(SIGTERM)
  }

  /// `http://localhost:<port><openPath>`.
  func url(openPath: String) -> URL? {
    port.flatMap { URL(string: Constants.localhost + String($0) + openPath) }
  }

  // MARK: - Running

  private func resolvePort(_ spec: ProjectSpec) {
    port = nil
    portNote = nil
    guard let preferred = spec.port else { return }
    if PortProbe.canBind(preferred) {
      port = preferred
    } else if spec.isPortFixed {
      state = .failed("Port \(preferred) is in use by another process.")
    } else if let free = PortProbe.freePort(from: preferred + 1) {
      port = free
      portNote = "\(preferred) was taken"
      record?(.busy, "Port \(free) assigned", nil, "\(preferred) was taken")
    } else {
      state = .failed("No free port near \(preferred).")
    }
  }

  private func readOutput(_ process: ChildProcess) {
    let buffer = buffer
    let flusher = Task { @MainActor in
      while !Task.isCancelled {
        try? await Task.sleep(for: .milliseconds(Constants.flushIntervalMilliseconds))
        buffer.flush()
      }
    }
    Task { @MainActor in
      var decoders = [false: LogDecoder(isRaw: true), true: LogDecoder(isRaw: true)]
      for await (isStderr, data) in process.output() {
        let now = Date.now
        let lines = decoders[isStderr, default: LogDecoder(isRaw: true)].feed(data)
        buffer.stage(lines.map { $0.stamped(at: now, isStderr: isStderr) })
      }
      flusher.cancel()
      buffer.flush()
    }
  }

  private func watchExit(_ process: ChildProcess, project: Project, spec: ProjectSpec) {
    Task { @MainActor in
      let code = await process.waitForExit()
      // Children can outlive the shell that started them; they go down with it.
      process.signal(SIGTERM)
      guard self.process === process else { return }
      self.process = nil
      pid = nil
      probeTask?.cancel()
      if isStopRequested || code == 0 {
        state = .stopped
        buffer.end(isStopRequested ? "Stopped" : "Exited")
      } else {
        state = .crashed(exitCode: code)
        buffer.end("Exited with code \(code)")
        record?(.error, "Crashed", nil, "exit code \(code)")
        if spec.restartOnCrash { start(project, spec: spec, cause: "after a crash") }
      }
    }
  }

  /// Waits for the port to answer, then health-checks it every few seconds.
  private func probe(_ spec: ProjectSpec) -> Task<Void, Never> {
    Task { @MainActor in
      guard let port else {
        // Nothing to probe: it counts as running once it is up at all.
        if state == .starting { state = .running }
        return
      }
      while !Task.isCancelled, state == .starting {
        if await isListening(port) {
          state = .running
          record?(.running, "Ready on localhost:\(port)", nil, nil)
          if spec.autoOpen, let url = browserURL?(spec.openPath) ?? url(openPath: spec.openPath) {
            NSWorkspace.shared.open(url)
          }
        } else {
          try? await Task.sleep(for: .milliseconds(Constants.startProbeMilliseconds))
        }
      }
      guard let path = spec.healthCheck else { return }
      var failures = 0
      while !Task.isCancelled, isActive, state != .stopping {
        let (code, milliseconds) = await check(port: port, path: path)
        lastHealth = HealthCheckResult(statusCode: code, milliseconds: milliseconds, date: .now)
        if let code, Constants.successCodes.contains(code) {
          if case .unhealthy = state {
            record?(.running, "Health check passing again", nil, String(code))
          }
          failures = 0
          state = .running
        } else {
          failures += 1
          if failures >= Constants.unhealthyAfter, state == .running {
            let reason = code.map { "GET \(path) returned \($0)" } ?? "GET \(path) did not answer"
            state = .unhealthy(reason)
            record?(.error, "Unhealthy", nil, reason)
          }
        }
        try? await Task.sleep(for: .seconds(Constants.healthIntervalSeconds))
      }
    }
  }

  private nonisolated func isListening(_ port: Int) async -> Bool {
    await Task.detached { PortProbe.isListening(port) }.value
  }

  private nonisolated func check(port: Int, path: String) async -> (Int?, Int) {
    guard let url = URL(string: Constants.localhost + String(port) + path) else { return (nil, 0) }
    var request = URLRequest(url: url)
    request.timeoutInterval = Constants.healthTimeoutSeconds
    let start = ContinuousClock.now
    let response = try? await URLSession.shared.data(for: request).1 as? HTTPURLResponse
    let elapsed = (ContinuousClock.now - start).components
    let milliseconds =
      Int(elapsed.seconds) * Constants.millisecondsPerSecond
      + Int(elapsed.attoseconds / Constants.attosecondsPerMillisecond)
    return (response?.statusCode, milliseconds)
  }
}

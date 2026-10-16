import Darwin
import Foundation

private enum Constants {
  static let shell = "/bin/zsh"
  /// A login shell, so PATH has what the user's terminal has: nvm, pnpm, pyenv.
  static let shellArguments = ["-l", "-c"]
  static let signalMask: Int32 = 0x7f
  static let exitCodeShift: Int32 = 8
  static let exitCodeMask: Int32 = 0xff
  /// Shells report death by signal N as exit code 128 + N.
  static let signalExitBase: Int32 = 128
}

/// A shell command running in its own process group, so stopping it also stops whatever
/// it spawned — `pnpm dev` starts node, which may start more.
final class ChildProcess: Sendable {
  /// The leader's pid, which is also the group id.
  let pid: pid_t
  private let stdout: FileHandle
  private let stderr: FileHandle

  /// Starts `command` in `directory` with `environment`.
  init(command: String, directory: URL, environment: [String: String]) throws {
    var outPipe: [Int32] = [0, 0]
    var errorPipe: [Int32] = [0, 0]
    guard pipe(&outPipe) == 0, pipe(&errorPipe) == 0 else {
      throw Failure.couldNotStart(String(cString: strerror(errno)))
    }
    var actions: posix_spawn_file_actions_t?
    posix_spawn_file_actions_init(&actions)
    defer { posix_spawn_file_actions_destroy(&actions) }
    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO)
    posix_spawn_file_actions_adddup2(&actions, errorPipe[1], STDERR_FILENO)
    for descriptor in outPipe + errorPipe {
      posix_spawn_file_actions_addclose(&actions, descriptor)
    }
    posix_spawn_file_actions_addchdir_np(&actions, directory.path)

    var attributes: posix_spawnattr_t?
    posix_spawnattr_init(&attributes)
    defer { posix_spawnattr_destroy(&attributes) }
    posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
    posix_spawnattr_setpgroup(&attributes, 0)

    let arguments = [Constants.shell] + Constants.shellArguments + [command]
    let argv = arguments.map { strdup($0) } + [nil]
    let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
    defer { (argv + envp).forEach { free($0) } }

    var pid: pid_t = 0
    let status = posix_spawn(&pid, Constants.shell, &actions, &attributes, argv, envp)
    close(outPipe[1])
    close(errorPipe[1])
    guard status == 0 else {
      close(outPipe[0])
      close(errorPipe[0])
      throw Failure.couldNotStart(String(cString: strerror(status)))
    }
    self.pid = pid
    stdout = FileHandle(fileDescriptor: outPipe[0], closeOnDealloc: true)
    stderr = FileHandle(fileDescriptor: errorPipe[0], closeOnDealloc: true)
  }

  /// Output as it arrives, tagged stdout or stderr; finishes when both pipes close. Each
  /// pipe is read on its own thread: the reads block, which the async pool must not do.
  func output() -> AsyncStream<(isStderr: Bool, data: Data)> {
    let (stream, continuation) = AsyncStream<(isStderr: Bool, data: Data)>.makeStream()
    let group = DispatchGroup()
    for (handle, isStderr) in [(stdout, false), (stderr, true)] {
      group.enter()
      Thread.detachNewThread {
        while case let data = handle.availableData, !data.isEmpty {
          continuation.yield((isStderr, data))
        }
        group.leave()
      }
    }
    group.notify(queue: .global()) { continuation.finish() }
    return stream
  }

  /// Waits for the leader to exit and returns its exit code (128 + signal when killed).
  func waitForExit() async -> Int32 {
    let pid = pid
    return
      await Task.detached {
        var status: Int32 = 0
        while waitpid(pid, &status, 0) == -1 && errno == EINTR {}
        // The wait(2) status macros, which Swift does not import.
        let signal = status & Constants.signalMask
        return signal == 0
          ? (status >> Constants.exitCodeShift) & Constants.exitCodeMask
          : Constants.signalExitBase + signal
      }
      .value
  }

  /// Sends `signal` to the whole group.
  func signal(_ signal: Int32) {
    killpg(pid, signal)
  }
}

import Darwin
import Foundation

/// The file descriptor of a streaming request, shared between its reader thread and the
/// stream's cancellation, which can arrive before the socket is even connected.
final class StreamSocket: @unchecked Sendable {
  private let lock = NSLock()
  private var fd: Int32 = -1
  private var isCancelled = false

  /// Takes ownership of `fd`. Returns false (and closes it) if the stream was already cancelled.
  func adopt(_ fd: Int32) -> Bool {
    lock.withLock {
      if isCancelled {
        Darwin.close(fd)
        return false
      }
      self.fd = fd
      return true
    }
  }

  /// Unblocks a pending read; the reader then closes the socket.
  func shutdown() {
    lock.withLock {
      isCancelled = true
      if fd >= 0 { Darwin.shutdown(fd, SHUT_RDWR) }
    }
  }

  func close() {
    lock.withLock {
      if fd >= 0 { Darwin.close(fd) }
      fd = -1
    }
  }
}

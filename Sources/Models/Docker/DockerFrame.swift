import Foundation

private enum Constants {
  static let headerLength = 8
  static let stdinStream: UInt8 = 0
  static let stdoutStream: UInt8 = 1
  static let stderrStream: UInt8 = 2
  /// Header bytes 4…7 hold the payload size, big-endian.
  static let sizeOffset = 4
  static let bitsPerByte = 8
}

/// Docker's stream framing for containers and execs without a TTY: each frame is an 8-byte
/// header — stream id, three zero bytes, big-endian payload size — followed by the payload.
enum DockerFrame {
  static let headerLength = Constants.headerLength
  static let stdout = Constants.stdoutStream
  static let stderr = Constants.stderrStream

  /// Whether `bytes` start like a frame header, which is how a framed stream is told apart
  /// from a raw (TTY) one.
  static func looksFramed(_ bytes: Data) -> Bool {
    guard bytes.count >= headerLength else { return false }
    let header = [UInt8](bytes.prefix(Constants.sizeOffset))
    return header[0] <= Constants.stderrStream && header.dropFirst().allSatisfy { $0 == 0 }
  }

  /// The stream a header belongs to: stderr, or stdout for anything else.
  static func stream(ofHeader header: [UInt8]) -> UInt8 {
    header[0] == Constants.stderrStream ? Constants.stderrStream : Constants.stdoutStream
  }

  /// The payload size a header announces.
  static func payloadSize(ofHeader header: [UInt8]) -> Int {
    header[Constants.sizeOffset..<Constants.headerLength]
      .reduce(0) {
        $0 << Constants.bitsPerByte | Int($1)
      }
  }

  /// Splits a complete framed stream into stdout and stderr.
  static func demultiplex(_ data: Data) -> (stdout: Data, stderr: Data) {
    var stdout = Data()
    var stderr = Data()
    var offset = data.startIndex
    while data.endIndex - offset >= headerLength {
      let header = [UInt8](data[offset..<offset + headerLength])
      let start = offset + headerLength
      let end = min(start + payloadSize(ofHeader: header), data.endIndex)
      if stream(ofHeader: header) == Constants.stderrStream {
        stderr.append(data[start..<end])
      } else {
        stdout.append(data[start..<end])
      }
      offset = end
    }
    return (stdout, stderr)
  }
}

import Foundation

@testable import Hangar

/// Builders for the byte streams Docker sends.
enum Fixtures {
  /// One Docker stream frame: stream id, three zero bytes, big-endian size, payload.
  static func frame(_ stream: UInt8, _ text: String) -> Data {
    let payload = Data(text.utf8)
    var data = Data([stream, 0, 0, 0])
    withUnsafeBytes(of: UInt32(payload.count).bigEndian) { data.append(contentsOf: $0) }
    data.append(payload)
    return data
  }

  /// Raw (TTY) output.
  static func raw(_ text: String) -> Data { Data(text.utf8) }

  /// Feeds chunks to a fresh decoder and returns every line it produced.
  static func decode(_ chunks: [Data]) -> [LogLine] {
    var decoder = LogDecoder()
    return chunks.flatMap { decoder.feed($0) }
  }
}

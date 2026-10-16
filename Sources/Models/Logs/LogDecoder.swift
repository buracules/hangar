import Foundation

/// Turns Docker's log stream into lines. Containers without a TTY send `DockerFrame`s; with
/// a TTY the bytes are raw. Feed it chunks as they arrive, in order.
struct LogDecoder {
  private var pending = Data()
  private var isFramed: Bool?
  /// Per stream (raw output counts as stdout): bytes of the line in progress, and the colour
  /// state, which carries over from one line to the next.
  private var partial: [UInt8: Data] = [:]
  private var parsers: [UInt8: ANSIParser] = [:]

  /// `isRaw` skips framing detection, for output that never comes from Docker — a project's
  /// stdout, whose first bytes could otherwise look like a frame header.
  init(isRaw: Bool = false) {
    isFramed = isRaw ? false : nil
  }

  /// The complete lines `data` finishes; a trailing partial line waits for the next chunk.
  mutating func feed(_ data: Data) -> [LogLine] {
    pending.append(data)
    if isFramed == nil {
      guard pending.count >= DockerFrame.headerLength else { return [] }
      isFramed = DockerFrame.looksFramed(pending)
    }
    guard isFramed == true else {
      defer { pending = Data() }
      return take(pending, stream: DockerFrame.stdout)
    }
    var lines: [LogLine] = []
    while pending.count >= DockerFrame.headerLength {
      let header = [UInt8](pending.prefix(DockerFrame.headerLength))
      let size = DockerFrame.payloadSize(ofHeader: header)
      guard pending.count >= DockerFrame.headerLength + size else { break }
      let payload = Data(pending.dropFirst(DockerFrame.headerLength).prefix(size))
      lines += take(payload, stream: DockerFrame.stream(ofHeader: header))
      pending = Data(pending.dropFirst(DockerFrame.headerLength + size))
    }
    return lines
  }

  /// Appends to a stream's line in progress and returns the lines that completes.
  private mutating func take(_ bytes: Data, stream: UInt8) -> [LogLine] {
    var buffer = partial[stream, default: Data()]
    buffer.append(bytes)
    // Only complete lines; a multi-byte character may straddle the last newline otherwise.
    guard let lastNewline = buffer.lastIndex(of: UInt8(ascii: "\n")) else {
      partial[stream] = buffer
      return []
    }
    // Lossy on purpose: one invalid byte should cost a replacement character, not the line.
    // swiftlint:disable:next optional_data_string_conversion
    let complete = String(decoding: buffer[..<lastNewline], as: UTF8.self)
    partial[stream] = Data(buffer[buffer.index(after: lastNewline)...])
    var parser = parsers[stream, default: ANSIParser()]
    defer { parsers[stream] = parser }
    return complete.split(separator: "\n", omittingEmptySubsequences: false)
      .map { raw in
        line(from: raw, stream: stream, parser: &parser)
      }
  }

  /// One line: Docker's timestamp taken off the front, the rest parsed for colour.
  private func line(from raw: Substring, stream: UInt8, parser: inout ANSIParser) -> LogLine {
    var raw = raw.hasSuffix("\r") ? raw.dropLast() : raw
    var time: Date?
    if let space = raw.firstIndex(of: " "), let parsed = LogTimestamp.dockerTime(raw[..<space]) {
      time = parsed
      raw = raw[raw.index(after: space)...]
    }
    let runs = parser.parse(raw)
    let text = runs.map(\.text).joined()
    return LogLine(
      text: text,
      runs: runs,
      isStderr: stream == DockerFrame.stderr,
      level: LogLevel.detect(in: text),
      time: time,
      timestampLength: LogTimestamp.ownTimestampLength(in: text)
    )
  }
}

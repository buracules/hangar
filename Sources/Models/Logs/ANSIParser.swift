import Foundation

private enum Constants {
  static let escape: Unicode.Scalar = "\u{1B}"
  static let bell: Unicode.Scalar = "\u{07}"
  static let delete: UInt32 = 0x7F
  static let firstPrintable: UInt32 = 0x20
  /// A CSI sequence ends at its first byte in this range.
  static let csiFinalBytes: ClosedRange<UInt32> = 0x40...0x7E

  /// Select Graphic Rendition parameters.
  enum SGR {
    static let reset = 0
    static let bold = 1
    static let dim = 2
    static let underline = 4
    static let normalIntensity = 22
    static let noUnderline = 24
    static let foreground = 30...37
    static let extendedForeground = 38
    static let defaultForeground = 39
    static let background = 40...47
    static let extendedBackground = 48
    static let defaultBackground = 49
    static let brightForeground = 90...97
    static let brightBackground = 100...107
    /// Bright colours are palette entries 8–15.
    static let brightOffset = 8
    /// `38;5;n`: a palette index follows.
    static let paletteMode = 5
    /// `38;2;r;g;b`: three channels follow.
    static let rgbMode = 2
    static let rgbChannelCount = 3
    static let paletteRange = 0...255
  }
}

/// Reads SGR colour sequences into styles and drops every other escape: cursor movement,
/// erase, OSC hyperlinks and titles. A bare `\r` rewinds the line the way a terminal would,
/// so progress bars resolve to their last state. The style carries over between lines.
struct ANSIParser {
  private(set) var style = LogStyle()

  /// The line's visible text, split into runs of one style each.
  mutating func parse(_ line: Substring) -> [LogRun] {
    var runs: [LogRun] = []
    var current = String.UnicodeScalarView()
    let scalars = line.unicodeScalars
    var index = scalars.startIndex
    while index < scalars.endIndex {
      let scalar = scalars[index]
      index = scalars.index(after: index)
      switch scalar {
      case Constants.escape:
        if let parameters = skipEscape(in: scalars, from: &index) {
          flush(&current, into: &runs)
          applySGR(parameters)
        }
      case "\r":
        current = String.UnicodeScalarView()
        runs.removeAll()
      case "\t":
        current.append(scalar)
      default:
        if scalar.value >= Constants.firstPrintable && scalar.value != Constants.delete {
          current.append(scalar)
        }
      }
    }
    flush(&current, into: &runs)
    return runs
  }

  /// Moves `index` past an escape sequence. Returns its parameters if it was an SGR one.
  private func skipEscape(
    in scalars: Substring.UnicodeScalarView,
    from index: inout Substring.UnicodeScalarView.Index
  ) -> String? {
    guard index < scalars.endIndex else { return nil }
    let kind = scalars[index]
    index = scalars.index(after: index)
    if kind == "[" {
      // CSI: parameter and intermediate bytes, then one final byte.
      var parameters = ""
      while index < scalars.endIndex, !Constants.csiFinalBytes.contains(scalars[index].value) {
        parameters.unicodeScalars.append(scalars[index])
        index = scalars.index(after: index)
      }
      guard index < scalars.endIndex else { return nil }
      let isSGR = scalars[index] == "m"
      index = scalars.index(after: index)
      return isSGR ? parameters : nil
    }
    if kind == "]" {
      // OSC: runs to BEL or ST (ESC \).
      while index < scalars.endIndex {
        let scalar = scalars[index]
        index = scalars.index(after: index)
        if scalar == Constants.bell { break }
        if scalar == Constants.escape {
          if index < scalars.endIndex { index = scalars.index(after: index) }
          break
        }
      }
    }
    return nil
  }

  /// Ends the run in progress, merging it into the previous one when the style is the same.
  private func flush(_ current: inout String.UnicodeScalarView, into runs: inout [LogRun]) {
    guard !current.isEmpty else { return }
    if let last = runs.last, last.style == style {
      runs[runs.count - 1].text.unicodeScalars.append(contentsOf: current)
    } else {
      runs.append(LogRun(text: String(current), style: style))
    }
    current = String.UnicodeScalarView()
  }

  private mutating func applySGR(_ parameters: String) {
    var codes = parameters.split { $0 == ";" || $0 == ":" }.map { Int($0) ?? Constants.SGR.reset }
    if codes.isEmpty { codes = [Constants.SGR.reset] }
    var index = 0
    while index < codes.count {
      let code = codes[index]
      if code == Constants.SGR.extendedForeground || code == Constants.SGR.extendedBackground {
        let (color, consumed) = extendedColor(codes, after: index)
        if code == Constants.SGR.extendedForeground {
          style.foreground = color
        } else {
          style.background = color
        }
        index += consumed
      } else {
        apply(code)
      }
      index += 1
    }
  }

  /// One plain SGR code: a text attribute or a basic colour.
  private mutating func apply(_ code: Int) {
    if !applyAttribute(code) { applyColor(code) }
  }

  /// Bold, dim, underline and reset. Returns false if `code` is none of them.
  private mutating func applyAttribute(_ code: Int) -> Bool {
    let sgr = Constants.SGR.self
    switch code {
    case sgr.reset: style = LogStyle()
    case sgr.bold: style.isBold = true
    case sgr.dim: style.isDim = true
    case sgr.underline: style.isUnderlined = true
    case sgr.normalIntensity:
      style.isBold = false
      style.isDim = false
    case sgr.noUnderline: style.isUnderlined = false
    default: return false
    }
    return true
  }

  /// The 16 basic foreground and background colours, and their resets.
  private mutating func applyColor(_ code: Int) {
    let sgr = Constants.SGR.self
    switch code {
    case sgr.foreground: style.foreground = .indexed(code - sgr.foreground.lowerBound)
    case sgr.brightForeground:
      style.foreground = .indexed(code - sgr.brightForeground.lowerBound + sgr.brightOffset)
    case sgr.defaultForeground: style.foreground = nil
    case sgr.background: style.background = .indexed(code - sgr.background.lowerBound)
    case sgr.brightBackground:
      style.background = .indexed(code - sgr.brightBackground.lowerBound + sgr.brightOffset)
    case sgr.defaultBackground: style.background = nil
    default: break
    }
  }

  /// The colour after a 38/48 code — `5;n` or `2;r;g;b` — and how many codes it used.
  private func extendedColor(_ codes: [Int], after index: Int) -> (LogColor?, Int) {
    let rest = codes.dropFirst(index + 1)
    guard let mode = rest.first else { return (nil, 0) }
    let values = Array(rest.dropFirst())
    switch mode {
    case Constants.SGR.paletteMode:
      guard let value = values.first else { return (nil, 1) }
      let range = Constants.SGR.paletteRange
      return (.indexed(min(max(value, range.lowerBound), range.upperBound)), 2)
    case Constants.SGR.rgbMode:
      let channelCount = Constants.SGR.rgbChannelCount
      guard values.count >= channelCount else { return (nil, 1) }
      let channels = values.prefix(channelCount).map { UInt8(clamping: $0) }
      return (.rgb(red: channels[0], green: channels[1], blue: channels[2]), 1 + channelCount)
    default:
      return (nil, 0)
    }
  }
}

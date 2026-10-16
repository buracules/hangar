import AppKit

private enum Constants {
  /// The gap between the time column and the text. `--sp-1-5`
  static let timeGap = Spacing.sm
  static let timeSample = "00:00:00"
  static let dimAlpha = 0.6
  static let backgroundAlpha = 0.3
  static let brightOffset = 8
  /// The xterm 6×6×6 colour cube starts at 16; greys run from 232 to 255.
  static let cubeStart = 16
  static let cubeEnd = 231
  static let cubeSide = 6
  /// Cube levels are 0, then 95, 135 … 255: a first step of 55 + 40, then 40 each.
  static let cubeFirstLevel: CGFloat = 55
  static let cubeLevelStep: CGFloat = 40
  static let greyStart = 232
  static let greyBase: CGFloat = 8
  static let greyStep: CGFloat = 10
  static let channelMax: CGFloat = 255
}

/// How log lines look: the program's own ANSI colours mapped to the design's palette,
/// otherwise a colour for the level; a dim local-time column; ERROR lines tinted edge to
/// edge. Wrapped lines indent past the time column.
@MainActor
enum LogStyler {
  static let font = NSFont.monospacedSystemFont(ofSize: FontSize.mono, weight: .regular)
  static let boldFont = NSFont.monospacedSystemFont(ofSize: FontSize.mono, weight: .bold)

  static func attributed(_ lines: ArraySlice<LogLine>, continuing: Bool) -> NSAttributedString {
    let out = NSMutableAttributedString()
    for (offset, line) in lines.enumerated() {
      if continuing || offset > 0 {
        out.append(NSAttributedString(string: "\n", attributes: baseAttributes))
      }
      out.append(attributed(line))
    }
    return out
  }

  /// Font and line spacing every character shares.
  static let baseAttributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .paragraphStyle: paragraphStyle,
    .foregroundColor: NSColor.label,
  ]

  private static func attributed(_ line: LogLine) -> NSAttributedString {
    let isOwnColour = line.hasOwnColor
    let base = isOwnColour ? NSColor.label : levelColour(line.level)
    let out = NSMutableAttributedString()
    if let time = line.time {
      var attributes = baseAttributes
      attributes[.foregroundColor] = NSColor.logTimestamp
      let column = timeFormatter.string(from: time) + "\t"
      out.append(NSAttributedString(string: column, attributes: attributes))
    }
    let textStart = out.length
    for run in line.runs {
      let styled = attributes(run.style, base: base)
      out.append(NSAttributedString(string: run.text, attributes: styled))
    }
    // The program's own timestamp is redundant next to the time column.
    if line.time != nil, line.timestampLength > 0, textStart + line.timestampLength <= out.length {
      out.deleteCharacters(in: NSRange(location: textStart, length: line.timestampLength))
    }
    if line.level == .error {
      let whole = NSRange(location: 0, length: out.length)
      out.addAttribute(.logLineBackground, value: NSColor.errorBackground, range: whole)
    }
    return out
  }

  private static func levelColour(_ level: LogLevel?) -> NSColor {
    switch level {
    case .error: .logError
    case .warning: .logWarning
    case .debug: .logDebug
    case nil: .label
    }
  }

  private static func attributes(
    _ style: LogStyle,
    base: NSColor
  ) -> [NSAttributedString.Key: Any] {
    var attributes = baseAttributes
    var colour = style.foreground.map(nsColour) ?? base
    if style.isDim { colour = colour.withAlphaComponent(Constants.dimAlpha) }
    attributes[.foregroundColor] = colour
    if style.isBold { attributes[.font] = boldFont }
    if let background = style.background {
      let tint = nsColour(background).withAlphaComponent(Constants.backgroundAlpha)
      attributes[.backgroundColor] = tint
    }
    if style.isUnderlined { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
    return attributes
  }

  /// The 16 basic colours map to the design's ANSI tokens, which read in both themes;
  /// black and white become label shades rather than vanishing into the background.
  private static func nsColour(_ colour: LogColor) -> NSColor {
    switch colour {
    case .rgb(let red, let green, let blue):
      return NSColor(
        srgbRed: CGFloat(red) / Constants.channelMax,
        green: CGFloat(green) / Constants.channelMax,
        blue: CGFloat(blue) / Constants.channelMax,
        alpha: 1
      )
    case .indexed(let index) where index < Constants.cubeStart:
      return basic(index % Constants.brightOffset, isBright: index >= Constants.brightOffset)
    case .indexed(let index) where index <= Constants.cubeEnd:
      let cube = index - Constants.cubeStart
      let side = Constants.cubeSide
      let channel = { (step: Int) -> CGFloat in
        guard step > 0 else { return 0 }
        let level = Constants.cubeFirstLevel + CGFloat(step) * Constants.cubeLevelStep
        return level / Constants.channelMax
      }
      return NSColor(
        srgbRed: channel(cube / (side * side)),
        green: channel(cube / side % side),
        blue: channel(cube % side),
        alpha: 1
      )
    case .indexed(let index):
      let grey = Constants.greyBase + CGFloat(index - Constants.greyStart) * Constants.greyStep
      return NSColor(white: grey / Constants.channelMax, alpha: 1)
    }
  }

  private static func basic(_ index: Int, isBright: Bool) -> NSColor {
    switch AnsiColour(rawValue: index) {
    case .black: isBright ? .tertiaryLabel : .label
    case .red: .statusError
    case .green: .ansiGreen
    case .yellow: .ansiYellow
    case .blue: .ansiBlue
    case .magenta: .ansiMagenta
    case .cyan: .ansiCyan
    case .white, nil: isBright ? .label : .secondaryLabel
    }
  }

  /// Wrapped lines indent past the time column; the tab after the time lands there too.
  private static let paragraphStyle: NSParagraphStyle = {
    let style = NSMutableParagraphStyle()
    style.minimumLineHeight = LineHeight.mono
    style.maximumLineHeight = LineHeight.mono
    let timeWidth = (Constants.timeSample as NSString).size(withAttributes: [.font: font]).width
    let indent = timeWidth + Constants.timeGap
    style.tabStops = [NSTextTab(textAlignment: .left, location: indent)]
    style.headIndent = indent
    return style
  }()

  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm:ss"
    return formatter
  }()
}

/// The order of the eight basic ANSI colours.
private enum AnsiColour: Int {
  case black
  case red
  case green
  case yellow
  case blue
  case magenta
  case cyan
  case white
}

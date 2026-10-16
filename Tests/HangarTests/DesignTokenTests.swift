import AppKit
import Testing

@testable import Hangar

struct DesignTokenTests {
  /// One generated colour from each group, so a renamed or missing colour set fails here
  /// rather than drawing nothing at runtime.
  @Test(arguments: [
    "Colors/backgroundContent", "Colors/secondaryLabel", "Colors/selectionFill",
    "Colors/statusRunning", "Colors/logError", "Colors/ansiCyan", "Colors/sqlFunction",
    "Colors/errorBorder", "AccentColor",
  ])
  func colourAssetsResolve(name: String) {
    #expect(NSColor(named: name) != nil)
  }

  @Test(arguments: ["MenuBarIcon", "MenuBarIconUp", "MenuBarIconAlert"])
  func menuBarIconsAreTemplates(name: String) throws {
    let image = try #require(NSImage(named: name))

    #expect(image.isTemplate)
  }

  @Test func statusColoursDifferBetweenLightAndDark() throws {
    let color = try #require(NSColor(named: "Colors/statusRunning"))
    let light = try #require(NSAppearance(named: .aqua))
    let dark = try #require(NSAppearance(named: .darkAqua))

    var lightValue: NSColor?
    var darkValue: NSColor?
    light.performAsCurrentDrawingAppearance { lightValue = color.usingColorSpace(.sRGB) }
    dark.performAsCurrentDrawingAppearance { darkValue = color.usingColorSpace(.sRGB) }

    #expect(lightValue != darkValue)
  }
}

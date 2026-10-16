#!/usr/bin/env python3
"""Generates Hangar's colours from the design's CSS tokens.

Reads the light (`.hg{}`) and dark (`.hg.dark{}`) blocks of Design/design/hangar.css and
writes, for every colour token in TOKENS:
  - Resources/Assets.xcassets/Colors/<Name>.colorset   (light + dark appearance)
  - Sources/DesignSystem/Color+Tokens.swift            (a `Color` static per token)
  - Sources/DesignSystem/NSColor+Tokens.swift          (the same, as `NSColor`, for AppKit views)
`--accent` becomes the app's AccentColor, so `Color.accentColor` is the design's accent.

Run it after the design changes:  python3 Scripts/generate-colors.py
"""

import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSS = ROOT / "Design/design/hangar.css"
ASSETS = ROOT / "Resources/Assets.xcassets"
COLORS = ASSETS / "Colors"
SWIFT = ROOT / "Sources/DesignSystem/Color+Tokens.swift"
NSCOLOR_SWIFT = ROOT / "Sources/DesignSystem/NSColor+Tokens.swift"

# CSS token → (Swift name, what it is for). Order is the order in the generated Swift.
TOKENS = {
    "bg-content": ("backgroundContent", "Detail panes, log and grid bodies."),
    "bg-sidebar": ("backgroundSidebar", "The sidebar."),
    "bg-pane": ("backgroundPane", "Secondary panes: the database table list, row numbers."),
    "bg-header": ("backgroundHeader", "Grid column headers."),
    "bg-editor": ("backgroundEditor", "The SQL editor."),
    "bg-popover": ("backgroundPopover", "The menu bar panel and alerts."),
    "bg-card": ("backgroundCard", "Cards: profile cards in the menu bar panel."),
    "bg-menu": ("backgroundMenu", "Custom menus."),
    "label": ("label", "Primary text."),
    "label-2": ("secondaryLabel", "Secondary text: statuses, captions, values."),
    "label-3": ("tertiaryLabel", "Section headers, placeholders, chevrons, NULL."),
    "label-4": ("quaternaryLabel", "Disabled text, line-number gutters."),
    "sep": ("separator", "Hairlines between rows and panes."),
    "sep-strong": ("strongSeparator", "Grid header rule, menu separators, outlined chips."),
    "fill-1": ("hoverFill", "Row hover."),
    "fill-2": ("controlFill", "Chips, segmented controls, toolbar button hover, skeletons."),
    "fill-sel": ("selectionFill", "The selected sidebar row."),
    "control-bg": ("controlBackground", "Push buttons and pop-up buttons."),
    "control-border": ("controlBorder", "Text field borders."),
    "control-on": ("controlSelected", "The selected segment."),
    "field-bg": ("fieldBackground", "Text fields."),
    "zebra": ("zebraStripe", "Every other grid row."),
    "accent-text": ("accentText", "Accent-coloured text and links: ports, FK tags."),
    "accent-soft": ("accentSoft", "Tinted backgrounds: port chips, detail icons, selected rows."),
    "on-accent": ("onAccent", "Text on accent backgrounds."),
    "st-running": ("statusRunning", "● running"),
    "st-paused": ("statusPaused", "◐ paused"),
    "st-busy": ("statusBusy", "◌ starting / stopping"),
    "st-stopped": ("statusStopped", "○ stopped"),
    "st-error": ("statusError", "✕ crashed / error, destructive actions"),
    "st-unhealthy": ("statusUnhealthy", "▲ unhealthy"),
    "log-error": ("logError", "ERROR log lines and inline SQL errors."),
    "log-warn": ("logWarning", "WARN log lines."),
    "log-debug": ("logDebug", "DEBUG / TRACE log lines."),
    "log-ts": ("logTimestamp", "The local-time column in logs."),
    "ansi-green": ("ansiGreen", "ANSI green (SGR 32/92)."),
    "ansi-yellow": ("ansiYellow", "ANSI yellow (SGR 33/93)."),
    "ansi-blue": ("ansiBlue", "ANSI blue (SGR 34/94)."),
    "ansi-magenta": ("ansiMagenta", "ANSI magenta (SGR 35/95)."),
    "ansi-cyan": ("ansiCyan", "ANSI cyan (SGR 36/96)."),
    "sql-kw": ("sqlKeyword", "SQL keywords."),
    "sql-str": ("sqlString", "SQL string literals."),
    "sql-num": ("sqlNumber", "SQL numbers."),
    "sql-fn": ("sqlFunction", "SQL function names."),
    "err-bg": ("errorBackground", "ERROR log lines and error boxes."),
    "err-border": ("errorBorder", "Error box outlines."),
}
ACCENT = "accent"


def block(css: str, selector: str) -> dict[str, str]:
    """The custom properties declared in the first block for `selector`."""
    match = re.search(re.escape(selector) + r"\s*\{(.*?)\}", css, re.S)
    if not match:
        sys.exit(f"no {selector} block in {CSS}")
    return {k: v.strip() for k, v in re.findall(r"(--[\w-]+)\s*:\s*([^;]+);", match.group(1))}


def components(value: str) -> dict[str, str]:
    """An asset-catalog colour from `#RRGGBB` or `rgba(r,g,b,a)`."""
    if value.startswith("#") and len(value) == 7:
        r, g, b = (int(value[i:i + 2], 16) for i in (1, 3, 5))
        alpha = 1.0
    else:
        match = re.fullmatch(r"rgba\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", value)
        if not match:
            sys.exit(f"unsupported colour {value!r}")
        r, g, b = (int(float(match.group(i))) for i in (1, 2, 3))
        alpha = float(match.group(4))
    return {
        "red": f"0x{r:02X}",
        "green": f"0x{g:02X}",
        "blue": f"0x{b:02X}",
        "alpha": f"{alpha:.3f}",
    }


def colorset(light: str, dark: str) -> dict:
    """Contents.json for a colour with light and dark appearances."""
    entry = lambda value: {"color": {"color-space": "srgb", "components": components(value)}, "idiom": "universal"}
    dark_entry = entry(dark)
    dark_entry["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
    return {"colors": [entry(light), dark_entry], "info": {"author": "xcode", "version": 1}}


def write_json(path: Path, value: dict) -> None:
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(value, indent=2) + "\n")


def main() -> None:
    css = CSS.read_text()
    light = block(css, ".hg")
    dark = {**light, **block(css, ".hg.dark")}

    missing = [f"--{token}" for token in [*TOKENS, ACCENT] if f"--{token}" not in light]
    if missing:
        sys.exit(f"tokens missing from the CSS: {', '.join(missing)}")

    write_json(ASSETS, {"info": {"author": "xcode", "version": 1}})
    shutil.rmtree(COLORS, ignore_errors=True)
    write_json(COLORS, {"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": True}})
    for token, (name, _) in TOKENS.items():
        write_json(COLORS / f"{name}.colorset", colorset(light[f"--{token}"], dark[f"--{token}"]))
    write_json(ASSETS / "AccentColor.colorset", colorset(light[f"--{ACCENT}"], dark[f"--{ACCENT}"]))

    lines = [
        "// Generated by Scripts/generate-colors.py from Design/design/hangar.css — do not edit.",
        "",
        "import SwiftUI",
        "",
        "// MARK: - Tokens",
        "",
        "extension Color {",
    ]
    for token, (name, purpose) in TOKENS.items():
        lines += [f"  /// {purpose} `--{token}`", f'  static let {name} = Color("Colors/{name}")']
    lines += ["}", ""]
    SWIFT.parent.mkdir(parents=True, exist_ok=True)
    SWIFT.write_text("\n".join(lines))

    lines = [
        "// Generated by Scripts/generate-colors.py from Design/design/hangar.css — do not edit.",
        "",
        "import AppKit",
        "",
        "// MARK: - Tokens",
        "",
        "extension NSColor {",
    ]
    for token, (name, purpose) in TOKENS.items():
        # A missing colour set is caught by DesignTokenTests; the fallback only keeps text visible.
        lines += [f"  /// {purpose} `--{token}`", f'  static let {name} = NSColor(named: "Colors/{name}") ?? .textColor']
    lines += ["}", ""]
    NSCOLOR_SWIFT.write_text("\n".join(lines))
    print(f"{len(TOKENS)} colours + AccentColor → {COLORS.relative_to(ROOT)}, {SWIFT.name}, {NSCOLOR_SWIFT.name}")


if __name__ == "__main__":
    main()

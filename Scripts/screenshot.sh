#!/usr/bin/env bash
# Screenshot one screen of Hangar's main window — only that window, never the whole screen.
#
#   Scripts/screenshot.sh <selection> <out.png> [light|dark] [database|structure|sql] [query]
#   Scripts/screenshot.sh container:hermes-postgres /tmp/logs.png dark
#
# <selection> is profile:<name>, vm:<name> or container:<name>, or "none" for no selection.
# Needs Screen Recording permission for the terminal that runs it.

set -euo pipefail

SELECTION="${1:?selection, e.g. container:hermes-postgres}"
OUT="${2:?output png path}"
APPEARANCE="${3:-}"
TAB="${4:-}"
SQL="${5:-}"
APP="$(cd "$(dirname "$0")/.." && pwd)/build/Build/Products/Debug/Hangar.app"
SETTLE_SECONDS=6

pkill -f "$APP/Contents/MacOS/Hangar( |$)" 2>/dev/null || true
sleep 1

args=(-HangarOpenWindowAtLaunch YES)
[[ "$SELECTION" != "none" ]] && args+=(-HangarSelect "$SELECTION")
[[ -n "$APPEARANCE" ]] && args+=(-HangarAppearance "$APPEARANCE")
[[ -n "$TAB" ]] && args+=(-HangarTab "$TAB")
[[ -n "$SQL" ]] && args+=(-HangarSQL "$SQL")
open -n "$APP" --args "${args[@]}"
sleep "$SETTLE_SECONDS"

pid="$(pgrep -f "$APP/Contents/MacOS/Hangar( |$)" | head -1 || true)"
[[ -n "$pid" ]] || { echo "Hangar did not start" >&2; exit 1; }

# The main window: the app's largest on-screen, normal-layer window.
window_id="$(swift - "$pid" <<'SWIFT'
import CoreGraphics
let pid = Int(CommandLine.arguments[1])!
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let mine = windows.filter { ($0[kCGWindowOwnerPID as String] as? Int) == pid && ($0[kCGWindowLayer as String] as? Int) == 0 }
let largest = mine.max { a, b in
  let area = { (w: [String: Any]) -> Double in
    let r = w[kCGWindowBounds as String] as? [String: Double] ?? [:]
    return (r["Width"] ?? 0) * (r["Height"] ?? 0)
  }
  return area(a) < area(b)
}
print(largest?[kCGWindowNumber as String] as? Int ?? 0)
SWIFT
)"
[[ "$window_id" != "0" ]] || { echo "no Hangar window on screen" >&2; exit 1; }

screencapture -x -o -l "$window_id" "$OUT"
echo "$OUT"

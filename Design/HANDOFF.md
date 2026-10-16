# Hangar — design handoff

Native macOS 15+ app, SwiftUI, light + dark. Menu bar extra (`MenuBarExtra`, `.window` style, 360 pt) + main window (`NavigationSplitView`, sidebar 232 pt).

## What's in here

- `design/*.dc.html` — one file per screen (HTML mockups, the source of truth for layout and copy). Open `design/canvas.json` to see the board list and titles.
  - `Main` menu bar panel · `Sidebar` (shared, `selected` / `empty` props) · `ContainerLogs` · `DBData` (Data / Structure / SQL via `view`) · `DBDataDark`, `DBStructure`, `DBSQL` (wrappers around DBData) · `DBStates` (empty, loading, error, alerts, empty sidebar) · `VMDetail` · `ProfileDetail` · `ProjectDetail` (future) · `Icons` · `Components` · `Tokens`.
  - Files use `{{holes}}`, `<sc-for>`, `<sc-if>`, `<dc-import>` and a small `renderVals()` class — read them as templates; the data inside `renderVals()` is sample data.
- `design/hangar.css` — **all tokens** as CSS custom properties (`.hg` = light, `.hg.dark` = dark) plus component styles. Port to a Swift `enum HangarTokens` with the same names (e.g. `--sp-2` → `HangarTokens.Space.s2`, `--st-running` → `HangarTokens.Status.running`).
- `icons/` — `AppIcon-1024.svg` (full art), `AppIcon-small-32.svg` (≤32 pt), `MenuBarIcon*.svg` (template images, Render As: Template Image).

## Rules to keep

1. Status language: every state = shape + color + word.
   running ● `circle.fill` · paused ◐ `circle.lefthalf.filled` · starting/stopping ◌ `circle.dotted` (rotates, off with Reduce Motion) · stopped ○ `circle` · crashed/error ✕ `xmark` · unhealthy ▲ `exclamationmark.triangle.fill`.
   Profiles show counts ("2/3 up"), not a shape.
2. Use `Color.accentColor`, system materials (`.sidebar`, `.popover`), SF Pro / SF Mono. Monospace only for logs, SQL, IDs, ports, grid values.
3. Primary action in the detail header; secondary in a `…` menu; destructive actions after a divider or at the bottom, ending in "…", always confirmed (Cancel is default).
4. Logs: local-time column, ERROR red, WARN orange, DEBUG dim, ANSI SGR mapped to `ansi-*` tokens. Scrolling up turns Follow off and shows the "Jump to latest ↓" pill.
5. Database tab runs `psql` inside the container. States: container stopped, psql missing, auth error, empty DB, loading, inline SQL error with Postgres' `LINE n:` / `^` pointer.
6. Menu bar icon never uses color: Idle (outline) / Up (door filled) / Alert (dot badge).

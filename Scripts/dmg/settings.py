# dmgbuild settings for Hangar's installer window: the app on the left, Applications on the
# right, over Scripts/dmg/background.tiff (rendered from background.svg at 1x and 2x by
# Scripts/render-dmg-background.swift).
#
#   dmgbuild -s Scripts/dmg/settings.py -D app=path/to/Hangar.app -D art=Scripts/dmg "Hangar 0.1.0" out.dmg
import os.path

app = defines["app"]  # noqa: F821 (dmgbuild provides `defines`)
here = defines["art"]  # noqa: F821

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
# The volume shows the app's own icon.
icon = os.path.join(app, "Contents", "Resources", "AppIcon.icns")
background = os.path.join(here, "background.tiff")
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
# The frame includes the 28-pt title bar above the 660×420 background.
window_rect = ((200, 120), (660, 448))
default_view = "icon-view"
show_icon_preview = False
icon_size = 128
text_size = 13
icon_locations = {
    os.path.basename(app): (190, 215),
    "Applications": (470, 215),
    # dmgbuild's own hidden files, parked outside the window: with hidden files shown in
    # Finder (⌘⇧.) they would otherwise sit under the hint text.
    ".background.tiff": (1200, 900),
    ".VolumeIcon.icns": (1400, 900),
}

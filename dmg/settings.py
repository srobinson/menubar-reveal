# dmgbuild settings for the release DMG; scripts/release.sh passes app, background and icon with -D.
# dmgbuild writes .DS_Store directly, so no Finder automation runs. The window is the background's width;
# its height leaves the icons and labels clear of Finder's toolbar, path bar and status bar in any combination.
import os

app = defines["app"]  # noqa: F821 (dmgbuild injects defines)
app_name = os.path.basename(app)

format = "ULFO"
filesystem = "HFS+"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]  # noqa: F821
background = defines["background"]  # noqa: F821

window_rect = ((240, 240), (660, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

icon_size = 128
text_size = 13
icon_locations = {app_name: (170, 180), "Applications": (490, 180)}
# No hide_extensions: it sets com.apple.FinderInfo on the app, and a copy then fails codesign --verify --strict.

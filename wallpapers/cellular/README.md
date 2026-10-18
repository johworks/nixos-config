# Pixel Weather

A native Plasma 6 wallpaper with two stable pixel-art landscapes: a little tree
on rolling hills, and a mountain lake. Simulated **Sunny**, **Cloudy**, and
**Rainy** conditions change the whole palette, sunlight, cloud cover, and rain.
Clouds drift gently; rain falls across the landscape. This prototype does not
fetch weather or use a location.

The plugin keeps its existing ID, `org.nixos.cellular`, and installation through
`hosts/desktop/cellular-wallpaper.nix`. Its displayed name is **Pixel Weather**.
The old Life helper and its tests remain as unused legacy code.

Under **Desktop and Wallpaper → Wallpaper type → Pixel Weather**, choose the
landscape, weather, cell size (2–20), animation speed (1–20; 10 is normal), and
pause state. Right-click the desktop for Sunny, Cloudy, Rainy, and pause/resume
actions. These manual settings use Plasma's per-desktop wallpaper configuration.
Old saved CellSize/Speed values carry forward; obsolete ReseedSeconds is ignored.
Fresh defaults are 4-pixel cells, normal speed, hill/tree, and sunny weather.

Every layer paints integer cells on the same grid. The scene uses uniform
scaling and extends the sky/terrain on different screen shapes rather than
stretching trees or peaks. Detail changes retain composition. Rendering is
capped at 480 × 300 cells with the cap applied uniformly to both dimensions.
The timer runs at 20 FPS; speed changes motion rather than render frequency.
Animation stops when paused or when the item is hidden. The clock avoids a
large jump after resume. Each desktop has its own animation clock.

## Checks and local preview

Run model/renderer checks and the existing Life checks:

```sh
node --test wallpapers/cellular/*.test.cjs
```

With Qt 6 tools and QML imports available, run actual offscreen Canvas and
settings tests, or capture all six scene/weather combinations without changing
the desktop:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input wallpapers/cellular/tests
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qml wallpapers/cellular/preview.qml -- --capture
```

Capture writes `/tmp/pixel-weather-preview.png`. An inspected sample is saved as
[preview.png](preview.png). Running `qml
wallpapers/cellular/preview.qml` without `--capture` opens an animated comparison
window. These previews use the real WeatherScene Canvas but do not exercise
Plasma's wallpaper hosting, persistence, or desktop context menu.

On NixOS, the tools may be outside PATH: use qtdeclarative's `bin/qml`,
`bin/qmltestrunner`, `bin/qmllint`, and `bin/qmlformat`, and set QML_IMPORT_PATH to
its `lib/qt-6/qml`, the system `lib/qt-6/qml`, and Kirigami's `lib/qt-6/qml`.
Exact paths and actual results are recorded in [IMPLEMENTATION.md](IMPLEMENTATION.md).

## Desktop preview and restore

The lead activated this prototype on 2026-10-18 as the separate local plugin
**Pixel Weather Preview** (`org.nixos.pixelweather.preview`). It is installed in
`/home/john/.local/share/plasma/wallpapers/`; the existing Home Manager wallpaper
symlink and its saved settings were preserved. The active connected desktop
uses the sunny hill/tree scene, cell size 4, speed 10, and animation enabled.
Choose **Pixel Weather Preview** in Desktop and Wallpaper settings to adjust
this installed preview. Source changes require updating the preview package
and reloading it; the installed preview is a copy, not a live worktree link.

To restore the previous wallpaper in this session:

```sh
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'desktops().filter(function (d) { return d.screen >= 0; }).forEach(function (d) { d.wallpaperPlugin = "org.nixos.cellular"; });'
```

Its original cell size 12, speed 8, and reseed interval 120 were not changed.
The login service also selects the original plugin. This separate preview
installation does not deploy the feature through NixOS or Home Manager.

For a future preview using the original plugin ID instead:

The lead handles desktop activation after review. Save the current wallpaper
plugin/configuration and resolve the existing
`~/.local/share/plasma/wallpapers/org.nixos.cellular` symlink before replacing
anything. A focused temporary preview can replace only that symlink with a
symlink to this worktree's `wallpapers/cellular` directory. Preserve the original
link target for restore. Re-select the wallpaper in Plasma settings to reload
it; do not assume a running shell reloads edited QML. If needed, select another
wallpaper before selecting Pixel Weather again.

Check both landscapes, all three conditions, settings Apply/reopen, context-menu
weather/pause, detail, resizing, and persistence across reload. Restore by
replacing the temporary link with its saved original target, then re-selecting
the previous plugin and restoring its saved settings. Do not edit Nix store
contents or overwrite unrelated desktop settings. No desktop activation is
performed by the automated tests.

The existing Nix installation selects this plugin at Plasma login; after a
separately authorized rebuild, `systemctl --user start cellular-wallpaper` selects
it in the current session. No Nix module changes are needed for this prototype.

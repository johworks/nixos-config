# Pixel Weather

A native Plasma 6 wallpaper: a little tree on the left foreground hill, layered
mountains behind it, and an open valley/lake toward the right. Mountain faces,
snow gullies, distant forest belts, tree branches and leaf clusters, terrain
contours, grasses, flowers, rocks, and a winding path form one detailed scene.

Simulated **Sunny**, **Cloudy**, and **Rainy** weather changes light and color
throughout the scene. Clouds drift behind the mountains; rain falls in front.
This prototype does not fetch weather or use a location.

The plugin keeps ID `org.nixos.cellular` and installation through
`hosts/desktop/cellular-wallpaper.nix`. Its displayed name is **Pixel Weather**.
Unused legacy Life code/tests remain. The former Scene setting is ignored;
there is one composed landscape and no scene selector.

## Controls and rendering

Under **Desktop and Wallpaper → Wallpaper type → Pixel Weather**, select weather,
cell size (2–20), speed (1–20; 10 is normal), and pause. Right-click the desktop
for weather and pause/resume actions. Settings use Plasma's per-desktop wallpaper
configuration. Existing CellSize/Speed/Weather/Paused values carry forward; the
fresh default is now 2-pixel cells to reveal the richer source. Existing saved
cell sizes are not overridden. Obsolete Scene/ReseedSeconds entries are unused.

The artwork is composed **before** pixelation. Sky and transparent scenery are
cached on separate high-detail Canvases. Each weather frame draws the cached
sky, moving clouds, cached terrain/tree, and rain into a source Canvas. One final
Canvas samples that complete image to the adjustable output grid, then scales it
without smoothing. Changing detail resamples the existing composition without
regenerating geometry or repainting the static artwork.

The 1280 × 720 design uses uniform scale and extends sky/terrain for other screen
shapes. Source images are capped at 1600 × 1000, independently of the output grid,
which is capped uniformly at 960 × 600. At 16:9 the source stays 1280 × 720 even on
8K displays. Static layers repaint only for weather/source-aspect changes.
Animation runs at a fixed 20 FPS; speed changes motion. It stops for paused,
hidden, or minimized windows/items and avoids large jumps after resume.
A wallpaper covered by another app may remain visible to Qt and keep animating.

## Full-size evidence and local preview

These are **1280 × 720 captures of the actual Qt composition and final sampling
path**, at a fixed weather phase. Compare [sunny/fine](preview-sunny.png),
[cloudy/fine](preview-cloudy.png), [rainy/fine](preview-rainy.png), and
[sunny/coarse](preview-coarse.png). The old [six-way preview](preview.png) is
historical evidence of the superseded separate-scene prototype.

Run model/clock checks and the existing Life checks:

```sh
node --test wallpapers/cellular/*.test.cjs
```

With Qt 6 tools and imports available, run the real offscreen Canvas/settings
tests or capture a full landscape without changing the desktop:

```sh
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input wallpapers/cellular/tests
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qml wallpapers/cellular/preview.qml -- --capture --weather=0 --cell=2 \
  --output=/tmp/pixel-weather-preview.png
```

Weather is 0 sunny, 1 cloudy, 2 rainy. Use `--cell=10` for the coarse comparison.
Omit `--capture` for an animated preview window. On NixOS, use qtdeclarative's
tools and set QML_IMPORT_PATH to the Qt, system, and Kirigami QML directories;
exact installed paths are in [IMPLEMENTATION.md](IMPLEMENTATION.md).

These previews exercise the real postprocess path but do not establish native
Plasma hosting, settings reload, or context-menu behavior for this revision.

## Desktop preview and restore

The reviewed revision is active as **Pixel Weather Preview 2**, a separate copy at
`/home/john/.local/share/plasma/wallpapers/org.nixos.pixelweather.preview2`, with
its own metadata ID/name. The connected desktop uses sunny weather, cell size
2, speed 10, and animation enabled. Select Pixel Weather Preview 2 in Desktop
and Wallpaper settings to adjust it. Native rendering and configuration
persistence across reload were checked; interactive menu clicks and settings
dialog Apply/reopen were not exercised. See the lead acceptance record below
the revision findings in IMPLEMENTATION.md.

Keep the original Home Manager `org.nixos.cellular` package
untouched. Preserve the preview copy and active plugin/settings before updating
it. Copy the revised package into the preview, retain its distinct metadata ID,
and re-select it to reload; do not assume edited QML reloads in a running shell.
Plasma retained old QML after an in-place package upgrade and re-selection in
this session. A fresh preview ID loaded revision 2 without restarting Plasma.

Check weather, coarse/fine detail, pause/speed, configuration Apply/reopen,
context actions, and persistence across plugin reload. Restore the saved preview
copy and previous plugin/settings when desired. Do not replace the whole Plasma
desktop configuration or edit store contents. Restore the original installed
wallpaper, whose settings remain unchanged, with:

```sh
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'desktops().filter(function (d) { return d.screen >= 0; }).forEach(function (d) { d.wallpaperPlugin = "org.nixos.cellular"; });'
```

The Nix install continues to select the original plugin at Plasma login. No Nix
module change or rebuild is needed for the separate local preview workflow.

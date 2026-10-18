# Pixel Weather

A native Plasma 6 wallpaper with a richly textured pixel-art canyon vista: a
broad tree and rocky overlook on the left, layered violet terrain, and a winding
river toward the center-right. The original generated scenery and cloud assets
were guided by John's visual reference; provenance is in [ARTWORK.md](ARTWORK.md).

Simulated **Sunny**, **Cloudy**, and **Rainy** weather changes the whole scene.
Sunny has coral/gold light and violet depth. Cloudy desaturates and cools the
terrain and turns clouds white-grey. Rainy darkens terrain and clouds and adds
falling rain. Sky, sun, drifting textured clouds, scenery, and rain are separate
layers. This prototype does not fetch weather or use a location.

The plugin keeps ID `org.nixos.cellular` and installation through
`hosts/desktop/cellular-wallpaper.nix`. Its displayed name is **Pixel Weather**.
Unused legacy Life code/tests remain. There is one composed landscape; obsolete
Scene/ReseedSeconds entries are ignored.

## Controls and rendering

In **Desktop and Wallpaper → Wallpaper type → Pixel Weather**, select weather,
cell size (2–20), speed (1–20; 10 is normal), and pause. Right-click the desktop
for weather and pause/resume actions. Existing CellSize/Speed/Weather/Paused keys
and their per-desktop Plasma persistence route are unchanged. Fresh default is
2-pixel cells; existing saved values are retained.

ArtworkLayer.qml explicitly loads each PNG into Canvas's image cache. When its
image, source size, or weather changes, it draws and grades the source pixels
once, retaining alpha. Animation waits for both graded caches to be ready, and
loading completion uses the latest weather. The original PNGs are never edited.

Each frame composes cached sky/sun, drifting cloud artwork, cached scenery, and
rain. One final Canvas samples the **complete composition** onto the adjustable
pixel grid, then scales it without smoothing. Finer detail reveals the existing
artwork; it does not regenerate geometry. Animation and detail changes do not
run the per-pixel grading/readback step.

The PNG aspect is preserved by fitting its width and anchoring terrain to the
bottom. Taller screens extend the sky; wider screens crop vertically. Source
Canvases and image decoding are bounded at 1600 × 1000; the final grid is bounded
uniformly at 960 × 600. At 16:9 the composition source stays 1280 × 720 even on
8K displays. Clouds drift slowly within an oversized 112% layer, so image edges
remain outside the viewport throughout the bounded motion.

Animation runs at a fixed 20 FPS; speed changes motion. It stops while paused,
hidden, minimized, or waiting for assets. A wallpaper covered by another app may
remain visible to Qt and keep animating. A capped clock avoids jumps on resume.

## Full-size evidence and local preview

These **1280 × 720 captures use the actual Qt asset, grading, composition, and
final sampling path**: [sunny/fine](preview-sunny.png),
[cloudy/fine](preview-cloudy.png), [rainy/fine](preview-rainy.png), and
[sunny/coarse](preview-coarse.png). They supersede the procedural revision's
captures. The old [six-way preview](preview.png) remains historical.

```sh
node --test wallpapers/cellular/*.test.cjs
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input wallpapers/cellular/tests
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qml wallpapers/cellular/preview.qml -- --capture --weather=0 --cell=2 \
  --output=/tmp/pixel-weather-preview.png
```

Weather is 0 sunny, 1 cloudy, 2 rainy. Use `--cell=10` for the coarse comparison.
Omit `--capture` for an animated preview window. Capture waits for cached assets
and exits with an error if loading fails or times out. On NixOS, use
qtdeclarative's tools and set QML_IMPORT_PATH to the Qt, system, and Kirigami QML
directories; exact installed paths are in [IMPLEMENTATION.md](IMPLEMENTATION.md).

Offscreen tests cover actual image loading, alpha and weather grading, weather
changes before/after loading, composition order, cloud motion, caching, final
sampling, controls, and bounds. They do not establish native Plasma hosting,
GPU behavior, settings reload, or interactive context actions for this revision.

## Desktop preview and restore

The reviewed asset-based revision is active as **Pixel Weather Preview 3**
(`org.nixos.pixelweather.preview3`) on the connected desktop. It uses sunny
weather, cell size 2, speed 10, and animation enabled. Select that preview in
Desktop and Wallpaper settings to adjust it. Native asset rendering, the rainy
transition, and settings persistence across plugin reload were verified; manual
menu clicks and the settings dialog Apply/reopen flow were not exercised.

The lead updates the authorized native preview **after review**. Use a **fresh
preview plugin ID** for this asset pipeline; Plasma cached prior QML across
reloads. Copy the package to a distinct preview directory and change only that
copy's metadata ID/name. Keep the Home Manager `org.nixos.cellular` package and
previous preview copy untouched. Save the active plugin and per-desktop settings
before selecting the fresh preview.

Verify weather, coarse/fine detail, loading, pause/speed, settings Apply/reopen,
context actions, and persistence across reload. Restore the saved plugin/settings
to return to the previous preview or original wallpaper. Do not replace the
whole Plasma configuration or edit store contents. Earlier native acceptance in
IMPLEMENTATION.md is historical and does not verify this asset pipeline.

Select **Pixel Weather Preview 2** to return to the preceding procedural
landscape, or restore the original installed wallpaper with:

```sh
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'desktops().filter(function (d) { return d.screen >= 0; }).forEach(function (d) { d.wallpaperPlugin = "org.nixos.cellular"; });'
```

The Nix install still selects the original plugin at Plasma login. No Nix module
change or rebuild is needed for the separate local preview workflow.

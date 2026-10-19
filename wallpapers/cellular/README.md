# Pixel Weather

One dynamic pixel-art canyon scene with a broad tree/overlook on the left,
receding violet terrain, and a winding river. One original scenery PNG and one
original cloud PNG feed the compositor; artwork/provenance is in
[ARTWORK.md](ARTWORK.md). Lighting, sun, clouds, wind, and rain are independently
adjustable in Manual mode. Automatic mode adds fixed-location Open-Meteo weather,
local daylight and a gradual seasonal palette using the same composed scene.

## Automatic weather

In the wallpaper settings, check **Automatic (uncheck for Manual)** and press
**Apply**. Boston, Massachusetts, USA is the default: latitude **42.35843**,
longitude **−71.05977**. For another fixed location, edit its name and coordinates
before Apply. The name is descriptive; coordinates determine the weather and
sun. Latitude must be −90…90 and longitude −180…180. No device/IP geolocation,
API key, background service or additional app is involved.

The **Active status** displays the running mode/location, provider, weather,
daylight phase, season, estimate age, fetch age and any error/fallback. It shows
the currently applied state while edits are pending. [Actual Qt form with a live
Boston response](preview-auto-settings.png) is an offscreen preview, not a native
desktop screenshot. New/old configurations default to Manual until enabled.

Automatic controls are derived separately from saved Manual knobs. Uncheck
Automatic and Apply to restore those knobs; none are overwritten by weather
updates. Manual form presets select Manual, taking effect on Apply. Desktop
context presets select Manual and save immediately. Detail, speed and pause
work in either mode. Pause freezes cloud/drop motion; Automatic's real solar
clock and weather refresh continue independently of animation speed/pause.

[Open-Meteo](https://open-meteo.com/) supplies **model-based current estimates**,
not a local weather-station observation. Refresh is approximately every15min,
with a15s timeout, no overlapping requests and no rapid error retries. Manual,
invalid coordinates and unloaded instances make no requests. Errors retain the
last good estimate for the same location in memory, with visible age/error;
it is not cached across reloads. Before any successful response, the explicitly
labeled fallback assumes partly cloudy, dry and calm while solar time continues.
Location changes discard old-location data. Estimates older than30min are labeled
stale; newly received estimates over2h old are rejected.

Cloud cover drives cloud amount; cloud/precipitation darken clouds. Liquid rain
and showers determine drop density, normalized from their current accumulation
interval to mm/hour. Snowfall is in cm and is never added to liquid rain. Snow
conditions are reported as unsupported animation: snow-only estimates draw no
rain. Thunder/hail/fog are reported and affect available cloud/rain fields;
there is no lightning, hail or fog particle effect. Horizontal wind uses the
eastward component of the meteorological bearing, capped visually at60km/h;
a northerly/southerly wind can therefore have no horizontal drift.

The [NOAA solar approximation](https://gml.noaa.gov/grad/solcalc/solareqns.PDF)
uses real UTC plus latitude/longitude every minute. The sun moves through the
painted sky and hides below the horizon; twilight warms the scene, and night
keeps legible cool terrain. This needs no cached timezone offset, so Boston DST
does not jump the sun. Polar day/night works without requiring sunrise events.
The provider timezone is shown as a label; there is no civil-clock display.

Seasonal warmth blends smoothly between winter/spring/summer/autumn calendar
tones, opposite in the southern hemisphere, using the location's mean solar
calendar rather than the computer's timezone. It is an approximate hemisphere
palette, not local vegetation phenology. Original leaves/tree/cliff/river,
painted highlights and composition remain baked; no bare branches, accumulated
snow, new terrain, moon or stars are generated. Low sun can be occluded by the
painted mountains. Pixel grading remains cached, never driven at frame rate.

Actual1280×720 fixture captures: [clear noon](preview-auto-noon.png),
[dusk](preview-auto-dusk.png), [rainy night](preview-auto-night.png),
[autumn](preview-auto-autumn.png), [winter](preview-auto-winter.png).
These use documented synthetic weather/date fixtures to inspect visual response,
not claims of current Boston conditions. [API field/units documentation](https://open-meteo.com/en/docs);
[geocoding/GeoNames source](https://open-meteo.com/en/docs/geocoding-api) for Boston's public coordinates.

## Controls

In **Desktop and Wallpaper → Wallpaper type → Pixel Weather**, the form groups
controls by mode/location/status, saved Manual lighting/sun/clouds/wind/rain,
and animation. Manual weather knobs are disabled while Automatic is selected:

| Control | Range | Default |
| --- | --- | --- |
| Scene brightness | 0–150% | 100 |
| Color warmth | −100 cool to +100 warm | +100 |
| Sun horizontal / vertical position | 0–100%; vertical 0 is top | 73 / 34 |
| Sun strength | 0 hidden to 100 | 100 |
| Cloud amount | 0 clear to 100 dense | 100 |
| Cloud darkness | 0 light to 100 dark grey | 0 |
| Wind | −100 left to +100 right; 0 still | +35 |
| Rain intensity | 0 dry to 100 | 0 |

Cell size remains 2–20 (smaller is finer), global speed 1–20 (10 normal), and
pause is persistent. Sun/clouds stay behind terrain; rain stays in front. Cloud
amount adjusts the cloud layer's visible density. Wind zero stops cloud drift
and horizontal rain movement while rain can still fall vertically. Wind changes
retain motion phase. Two cached cloud copies crossfade through bounded offsets
so either direction continues without exposed image edges or position resets.

Sunny, Cloudy, and Rainy buttons/context actions **write the atmosphere knobs**
as convenient starting points. Any knob can then be edited independently. A
preset resets all atmosphere knobs, including sun position, while retaining grid
detail, pause, and global speed. Presets do not select images or render modes.

### Try the rain

The native wallpaper form starts with Apply/scroll guidance. Changes in this
form take effect when you press **Apply**; Cancel discards unapplied edits.
Scroll down for **Wind and rain** and **Detail and animation**.
[Guidance in the actual Qt form](preview-controls-guidance.png) (offscreen preview).

1. Choose Sunny, set Rain intensity to **70**, Wind to **0**, speed to **10**,
   and uncheck Pause animation. Press Apply to see vertical rain in warm light.
2. Set Wind to **−60**, then **+60**, applying each time to compare left/right
   drift and cloud movement. Set it back to 0 for still clouds and vertical rain.
3. Vary Rain intensity (0 is dry; higher values add drops) and Animation speed
   (affects rain and clouds), then Apply. Lighting and rain remain independent.
4. Check Pause animation and Apply to inspect a frozen frame. Uncheck it and
   Apply to resume from the same positions.
5. Choose Sunny and Apply to return to the warm, dry baseline. Presets retain
   pause, speed and detail: unpause and set speed10/cell size2 if needed.

This is one composed scene, with independent sky/sun, clouds and foreground
rain. Brightness/warmth grade the artwork; the tree/cliff/river and painted
highlight direction remain baked into one scenery image.

Rain uses at most 240 particles with random birth positions, fall speeds,
lengths and opacity. Initial drops fill the view; offscreen drops respawn above
it with fresh values. Positions persist between frames, so repainting does not
flicker or replay a fixed wrap pattern. Density changes retain surviving drops;
changing pixel detail does not reseed them. Compare [start](preview-rain-start.png)
and [5.5 seconds later](preview-rain-later.png), with rain70/wind0/seed73.

The approved warm default is retained: the current default Qt capture matches
the preceding approved sunny capture byte-for-byte. Sun position moves the sky
sun; painted terrain highlights retain their source direction. Tree, cliff and
river remain a single source artwork layer.

## Persistence and migration

Plugin ID/install route remain `org.nixos.cellular` through
`hosts/desktop/cellular-wallpaper.nix`. Existing CellSize, Speed and Paused keys
are unchanged. New atmosphere keys are Brightness, Warmth, SunX, SunY,
SunStrength, CloudAmount, CloudDarkness, Wind and RainIntensity.

Legacy Weather is read **once** when ControlsVersion is 0/missing. Its old
sunny/cloudy/rainy condition initializes the knobs, then ControlsVersion becomes
1. The shared preset writer commits that version after all knobs, including
context presets after a reset. The runtime wrapper explicitly calls the native
configuration map's `writeConfig()` once after migration, a context preset, or
a pause toggle. Settings-form edits remain unsaved until Plasma's Apply action.
Later loads honor independent saved values, regardless of the old Weather
value. The wallpaper wrapper and settings form both use the same migration
helper; form initialization defers until saved cfg_* values are injected, so
configuration before activation can migrate too. Preset buttons mark the form
as initialized, and user knob edits do too (including after Reset Defaults).
Obsolete Scene/ReseedSeconds are ignored. Legacy Life code and
its tests remain unused.

## Rendering and evidence

ArtworkLayer.qml explicitly caches each PNG and regrades only for properties
that affect it: brightness/warmth for scenery, plus darkness for clouds. Sun
position/strength, cloud amount, wind and rain changes reuse those source caches.
Animation/detail changes never run per-pixel image processing. Asset loading
uses the latest independent values and preserves alpha. Original PNGs are intact.

Each frame composes sky/sun, textured moving clouds, scenery, then rain before
one final grid sampling pass. Source/decode bounds remain 1600 × 1000, with a
1280 × 720 source at 16:9; final grid is capped uniformly at 960 × 600. Artwork
fits width and anchors to the bottom: tall views extend sky, wide views crop
vertically. Animation is 20 FPS, bounded across stalls, and stops while paused,
hidden/minimized or waiting for assets. A wallpaper covered by another app may
still be visible to Qt.

Actual **1280 × 720** captured settings examples:

- [Approved default](preview-sunny.png).
- [Sun shower](preview-sunshower.png): rain 65, wind 0, cloud amount 35; warm light and sun remain.
- [Dark dry sky](preview-dark-dry.png): brightness 45, warmth −70, sun 0, cloud amount 60/darkness 75; rain 0.
- [Clear cool light](preview-clear-cool.png): brightness 110, warmth −75, sun at 55/25 with strength 50, clouds 0.
- [Warm overcast](preview-warm-overcast.png): brightness 105, warmth 80, sun 0, cloud darkness 65, wind −35.

Earlier cloudy/rainy/coarse/six-way PNGs are historical captures, not image
choices used by the live renderer. Mixed captures above predate randomized
rain; the temporal pair in Try the rain shows the new drops.

```sh
node --test wallpapers/cellular/*.test.cjs
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qmltestrunner -input wallpapers/cellular/tests
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  qml wallpapers/cellular/preview.qml -- --capture --preset=sunny \
  --RainIntensity=65 --Wind=0 --CloudAmount=35 --cell=2 \
  --output=/tmp/pixel-weather-sunshower.png
```

Any atmosphere key above can be overridden as `--Key=value`. Omit `--capture`
for an animated preview. Capture waits for ready caches and reports loading
error/timeout. Installed Qt tools/import paths, actual checks and historical
native evidence are in [IMPLEMENTATION.md](IMPLEMENTATION.md).

For repeatable rain captures, add `--seed=73` (normal wallpaper instances use
fresh randomness). `--capture --frames=12 --output=/tmp/pixel-weather-rain`
writes `/tmp/pixel-weather-rain-01.png` through `-12.png`, advancing half a
simulation second between frames. Frames are bounded to 40. These options are
preview tools; there is no seed field to manage in the native settings form.

Use `--automatic-fixture=noon|dusk|night|autumn|winter --capture --seed=73` to
capture the Automatic mapping without network traffic. Fixture dates/values are
in weather-fixtures.js; normal standalone previews remain Manual by default.

## Native preview and restore

The reviewed Automatic revision is active as **Pixel Weather Preview 8**
(`org.nixos.pixelweather.preview8`), with Boston fixed coordinates and Automatic
enabled. The native form displays the actual running source, weather estimate,
phase/season and update ages: [current native form](preview-auto-native-settings.png).
The settings dialog is open for experiments. Uncheck Automatic and Apply to
restore the saved Manual controls, or choose a Manual preset and Apply.

The latest user-edited Manual values were copied from preview7 before selection:
brightness100/warmth100, sun73/34 at strength100, cloud100/darkness0, wind35,
rain0, cell2/speed8/unpaused. Automatic never overwrites them. Native mode and
Boston coordinates persisted on disk and through unload/reload; returning to
Manual preserved those exact values. Automatic is enabled again.

Native legacy migration saves all converted values/version to disk. Custom
controls survived unload/reload, and the final form reopened with correct saved
values and no plugin-specific initial-property errors. Native mode changes were
performed through Plasma's configuration API. Interactive preset/reset/pause,
Apply/Cancel clicks and scrolling were not automated; Qt tests cover the
form/helper/save contracts. IMPLEMENTATION.md records the verification limits.

Lead owns native activation **after review**, using a fresh preview plugin ID
because Plasma cached earlier QML across reloads. Preserve the original Home
Manager package and prior preview copies. Copy the package to a distinct
preview directory, change only its metadata ID/name, save active plugin/settings,
and select it. Verify controls, grouped form/scrolling, presets/manual edits,
legacy migration, Apply/reopen, pause/speed, context actions and persistence
across reload. Restore the saved plugin/settings to return to the prior preview.

The builder's offscreen checks are supplemented by the lead's native acceptance
above. Earlier native acceptance applies to earlier revisions. No Nix module
changes or system rebuild were needed. Original Home Manager wallpaper and prior
previews remain available. To restore the original installed wallpaper:

```sh
qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript \
  'desktops().filter(function (d) { return d.screen >= 0; }).forEach(function (d) { d.wallpaperPlugin = "org.nixos.cellular"; });'
```

import QtQuick
import QtTest
import "../contents/ui"
import "../contents/ui/controls.js" as Controls
import "../contents/ui/landscape.js" as Landscape

Item {
    id: host
    width: 1280
    height: 720
    WeatherScene {
        id: scene
        anchors.fill: parent
        paused: true
        time: 12
        windTime: 12
    }
    CelestialClock {
        id: clock
    }
    CelestialLayer {
        id: moon
        width: 1280
        height: 720
        opacity: 0
    }
    TestCase {
        name: "CelestialSky"
        when: windowShown
        function skyState(phase, fade, stars) {
            return {
                now: Date.parse("2026-10-19T03:00:00Z"),
                place: {
                    latitude: 42.35843,
                    longitude: -71.05977
                },
                phase: phase,
                fade: fade,
                starStrength: stars,
                moonStrength: 1,
                moonX: 0.5,
                moonY: 0.25
            };
        }
        function controls(amount, dark) {
            var knobs = Controls.preset("sunny");
            knobs.Brightness = 46;
            knobs.Warmth = -70;
            knobs.SunStrength = 0;
            knobs.CloudAmount = amount;
            knobs.CloudDarkness = dark;
            return knobs;
        }
        function init() {
            scene.celestial = null;
            scene.controls = controls(0, 0);
            clock.automatic = false;
            clock.manualNight = false;
            clock.starStrength = 70;
            clock.moonStrength = 85;
            clock.latitude = "42.35843";
            clock.longitude = "-71.05977";
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
        }
        function moonPixel(x, y) {
            return moon.getContext("2d").getImageData(x, y, 1, 1).data;
        }
        function test_moon_lit_side_and_fade_pixels() {
            moon.sky = skyState(0.25, 1, 0);
            wait(100);
            verify(moonPixel(655, 180)[3] > 250, "first-quarter right limb lit");
            verify(moonPixel(625, 180)[3] < 30, "left limb only restrained halo");
            moon.sky = skyState(0.75, 1, 0);
            wait(100);
            verify(moonPixel(625, 180)[3] > 250, "last-quarter left limb lit");
            verify(moonPixel(655, 180)[3] < 30);
            moon.sky = skyState(0.1, 1, 0);
            wait(100);
            verify(moonPixel(662, 180)[3] > 250, "waxing crescent right edge lit");
            verify(moonPixel(650, 180)[3] < 30, "crescent center remains unlit");
            moon.sky = skyState(0.4, 1, 0);
            wait(100);
            verify(moonPixel(625, 180)[3] > 250, "waxing gibbous lights most of left half too");
            moon.sky = skyState(0.5, 0.5, 0);
            wait(100);
            verify(moonPixel(640, 180)[3] >= 126 && moonPixel(640, 180)[3] <= 140, "twilight attenuates moon alpha gradually");
            moon.sky = skyState(0.5, 0, 1);
            wait(100);
            compare(moonPixel(640, 180)[3], 0, "day removes moon and stars");
            compare(moon.projectedCount, 0);
            moon.sky = skyState(0, 1, 0);
            wait(100);
            compare(moonPixel(640, 180)[3], 0, "new moon absent, including halo");
        }
        function test_layer_order_and_cloud_suppression() {
            var base = grabImage(scene);
            scene.celestial = skyState(0.5, 0, 1);
            wait(100);
            verify(grabImage(scene).equals(base), "daytime render exactly unchanged");
            scene.celestial = skyState(0.5, 1, 1);
            wait(100);
            var night = grabImage(scene);
            verify(night.pixel(640, 180).r > base.pixel(640, 180).r + 0.4, "moon visible through open sky");
            var terrain = findChild(scene, "sceneryCache");
            var alpha = terrain.getContext("2d").getImageData(0, 0, 1280, 720).data;
            var checked = 0;
            for (var y = 400; y < 700; y += 20)
                for (var x = 20; x < 1260; x += 20) {
                    var i = (y * 1280 + x) * 4;
                    if (alpha[i + 3] > 250 && alpha[i + 7] > 250 && alpha[i + 5120 + 3] > 250 && alpha[i + 5120 + 7] > 250) {
                        var a = night.pixel(x, y), b = base.pixel(x, y);
                        verify(Math.abs(a.r - b.r) <= 6 / 255 && Math.abs(a.g - b.g) <= 6 / 255 && Math.abs(a.b - b.b) <= 6 / 255, "near-opaque source alpha covers star layer");
                        checked++;
                    }
                }
            verify(checked > 300, "near-opaque terrain samples: " + checked);
            // Move the composed moon onto the opaque foreground as a stronger
            // order check: it cannot punch through the existing source alpha.
            var behind = skyState(0.5, 1, 0);
            behind.moonX = 0.08;
            behind.moonY = 0.85;
            scene.celestial = behind;
            wait(100);
            var hidden = grabImage(scene).pixel(102, 612), original = base.pixel(102, 612);
            verify(Math.abs(hidden.r - original.r) <= 6 / 255 && Math.abs(hidden.g - original.g) <= 6 / 255 && Math.abs(hidden.b - original.b) <= 6 / 255, "near-opaque foreground alpha attenuates a moon placed behind it");
            scene.controls = controls(100, 100);
            scene.celestial = null;
            wait(150);
            var overcast = grabImage(scene);
            scene.celestial = skyState(0.5, 1, 1);
            wait(100);
            verify(grabImage(scene).equals(overcast), "fully dark overcast suppresses celestial light");
            // With partial cover, actual painted cloud alpha must cover the
            // layer as well as its global transmission attenuation.
            scene.controls = controls(60, 40);
            scene.celestial = null;
            wait(150);
            var cloudyBase = grabImage(scene);
            scene.celestial = skyState(0.5, 1, 0);
            wait(100);
            var cloudyMoon = grabImage(scene);
            var delta = cloudyMoon.pixel(640, 180).r - cloudyBase.pixel(640, 180).r;
            verify(delta >= 0 && delta < (night.pixel(640, 180).r - base.pixel(640, 180).r) * 0.7);
            // Find a cloud-covered, transparent sky pixel from the actual
            // cached PNG and the compositor's affine placement. A bright
            // moon placed there must also be masked by the cloud's alpha.
            var clouds = findChild(scene, "cloudCache");
            var cloudPixels = clouds.getContext("2d").getImageData(0, 0, 1280, 720).data;
            var placement = Landscape.cloudPlacements(1280, 720, scene.windTime)[0];
            var best = {
                x: 0,
                y: 0,
                alpha: 0
            };
            for (var sy = 40; sy < 240; sy += 10)
                for (var sx = 550; sx < 1200; sx += 10) {
                    var cx = Math.floor((sx - placement.x) / placement.width * 1280);
                    var cy = Math.floor((sy - placement.y) / placement.height * 720);
                    var opacity = cloudPixels[(cy * 1280 + cx) * 4 + 3] / 255;
                    if (alpha[(sy * 1280 + sx) * 4 + 3] === 0 && opacity > best.alpha)
                        best = {
                            x: sx,
                            y: sy,
                            alpha: opacity
                        };
                }
            verify(best.alpha > 0.8, "test samples real painted cloud cover");
            scene.controls = controls(100, 0);
            scene.celestial = null;
            wait(150);
            var coverBase = grabImage(scene);
            var covered = skyState(0.5, 1, 0);
            covered.moonX = best.x / 1280;
            covered.moonY = best.y / 720;
            scene.celestial = covered;
            wait(100);
            var coverDelta = grabImage(scene).pixel(best.x, best.y).r - coverBase.pixel(best.x, best.y).r;
            verify(coverDelta < 0.12, "painted cloud alpha blocks the moon beyond the 0.55 global transmission alone: " + coverDelta);
        }
        function test_real_clock_independent_of_particles_and_grade_cache() {
            clock.manualNight = true;
            clock.now = Date.parse("2026-10-19T03:00:00Z");
            scene.celestial = Qt.binding(() => clock.sky);
            wait(100);
            var cache = scene.celestialPaintCount, grades = scene.gradePaintCount;
            var skyCache = findChild(scene, "celestialCache");
            verify(skyCache.projectedCount > 30);
            for (var i = 0; i < 10; i++)
                scene.advanceAnimation(0.05);
            scene.speed = 20;
            wait(100);
            compare(scene.celestialPaintCount, cache, "particle steps and speed reuse celestial raster");
            compare(scene.gradePaintCount, grades);
            var minute = findChild(clock, "celestialMinuteClock");
            compare(minute.interval, 60000);
            compare(minute.running, true, "paused scene still has real sky clock");
            minute.triggered();
            wait(100);
            verify(clock.now > Date.parse("2026-10-19T03:00:00Z"));
            verify(scene.celestialPaintCount > cache);
            compare(scene.gradePaintCount, grades, "clock cannot regrade terrain/clouds");
            clock.manualNight = false;
            compare(minute.running, false);
        }
        function test_automatic_real_phase_location_and_daylight() {
            clock.manualNight = true;
            clock.manualPhase = 75;
            clock.automatic = true;
            clock.now = Date.parse("2026-10-19T03:00:00Z");
            compare(clock.fade, 1);
            verify(clock.moonPhase > 0.2 && clock.moonPhase < 0.4, "Automatic ignores saved Manual phase");
            clock.now = Date.parse("2026-10-19T17:00:00Z");
            compare(clock.fade, 0);
            clock.latitude = "bad";
            compare(clock.fade, 0);
            clock.automatic = false;
            compare(clock.moonPhase, 0.75, "Manual phase retained exactly");
            compare(clock.fade, 1);
        }
    }
}

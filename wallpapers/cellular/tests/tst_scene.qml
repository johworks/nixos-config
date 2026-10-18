import QtQuick
import QtQuick.Window
import QtTest
import "../contents/ui"
import "../contents/ui/controls.js" as Controls

Item {
    id: container
    width: 1280
    height: 720
    WeatherScene {
        id: scene
        anchors.fill: parent
        cellSize: 2
    }
    TestCase {
        name: "WeatherScene"
        when: windowShown
        function init() {
            container.width = 1280;
            container.height = 720;
            scene.visible = true;
            scene.animationEnabled = true;
            scene.paused = true;
            scene.speed = 10;
            scene.time = 12;
            scene.controls = Controls.preset("sunny");
            scene.windTime = 12;
            scene.cellSize = 2;
            tryCompare(scene, "assetsReady", true, 10000);
            wait(150);
        }
        function test_clock_controls() {
            var start = scene.time;
            scene.paused = false;
            tryVerify(function () {
                return scene.time > start;
            });
            scene.paused = true;
            var stopped = scene.time;
            wait(150);
            compare(scene.time, stopped);
            scene.paused = false;
            tryVerify(function () {
                return scene.time > stopped;
            });
            scene.visible = false;
            stopped = scene.time;
            wait(150);
            compare(scene.time, stopped);
            scene.visible = true;
            tryVerify(function () {
                return scene.time > stopped;
            });
            scene.animationEnabled = false;
            stopped = scene.time;
            wait(150);
            compare(scene.time, stopped);
        }
        function test_hidden_window() {
            var start = scene.time;
            scene.paused = false;
            tryVerify(function () {
                return scene.time > start;
            });
            var window = scene.Window.window;
            window.visible = false;
            try {
                var stopped = scene.time;
                wait(150);
                compare(scene.time, stopped);
            } finally {
                window.visible = true;
            }
        }
        function test_cached_source_and_final_sampling() {
            verify(scene.staticPaintCount >= 2);
            var cached = scene.staticPaintCount;
            var grades = scene.gradePaintCount;
            var sourceWidth = scene.sourceSize.columns;
            var sourceHeight = scene.sourceSize.rows;
            var fine = grabImage(scene);
            scene.cellSize = 10;
            wait(120);
            compare(scene.staticPaintCount, cached, "grid changes must not repaint source artwork");
            compare(scene.sourceSize.columns, sourceWidth);
            compare(scene.sourceSize.rows, sourceHeight);
            var coarse = grabImage(scene);
            var changed = 0;
            for (var y = 20; y < 700; y += 20) {
                for (var x = 20; x < 1260; x += 20) {
                    compare(coarse.pixel(x + 1, y + 1), coarse.pixel(x + 8, y + 8), "one final 10-pixel cell for every layer");
                    if (fine.pixel(x + 3, y + 3) !== coarse.pixel(x + 3, y + 3))
                        changed++;
                }
            }
            verify(changed > 200, "finer grid must expose existing scene detail");
            var composites = scene.compositePaintCount;
            scene.time += 3;
            tryVerify(function () {
                return scene.compositePaintCount > composites;
            });
            compare(scene.staticPaintCount, cached, "weather motion must reuse cached sky and scenery");
            compare(scene.gradePaintCount, grades, "no pixel grading/readback during animation or detail changes");
        }
        function setKnobs(changes) {
            var knobs = Controls.preset("sunny");
            for (var key in changes)
                knobs[key] = changes[key];
            scene.controls = knobs;
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
        }
        function test_mixed_controls_and_intermediates() {
            var images = [];
            var combinations = [
                {
                    RainIntensity: 65,
                    Wind: 0,
                    CloudAmount: 35
                },
                {
                    Brightness: 45,
                    Warmth: -70,
                    SunStrength: 0,
                    CloudAmount: 60,
                    CloudDarkness: 75,
                    RainIntensity: 0
                },
                {
                    Brightness: 110,
                    Warmth: -75,
                    SunX: 55,
                    SunY: 25,
                    SunStrength: 50,
                    CloudAmount: 0
                },
                {
                    Brightness: 105,
                    Warmth: 80,
                    SunStrength: 0,
                    CloudAmount: 100,
                    CloudDarkness: 65,
                    Wind: -35
                }
            ];
            for (var i = 0; i < combinations.length; i++) {
                setKnobs(combinations[i]);
                var image = grabImage(scene);
                for (var j = 0; j < images.length; j++)
                    verify(!image.equals(images[j]), "mixed conditions remain distinct");
                images.push(image);
            }
            var previous = -1;
            for (var level = 0; level <= 100; level += 25) {
                setKnobs({
                    Brightness: level,
                    SunStrength: 0,
                    CloudAmount: 0,
                    RainIntensity: 0
                });
                var color = grabImage(scene).pixel(100, 600);
                var sum = color.r + color.g + color.b;
                verify(sum > previous, "intermediate light values visibly interpolate");
                previous = sum;
            }
        }
        function test_layer_cache_invalidation() {
            var terrain = findChild(scene, "sceneryCache"), clouds = findChild(scene, "cloudCache");
            var terrainGrades = terrain.gradeCount, cloudGrades = clouds.gradeCount;
            setKnobs({
                SunX: 30,
                SunY: 20,
                SunStrength: 50,
                CloudAmount: 40,
                Wind: -40,
                RainIntensity: 50
            });
            compare(terrain.gradeCount, terrainGrades);
            compare(clouds.gradeCount, cloudGrades);
            setKnobs({
                CloudDarkness: 70
            });
            compare(terrain.gradeCount, terrainGrades, "cloud darkness cannot regrade terrain");
            verify(clouds.gradeCount > cloudGrades);
            cloudGrades = clouds.gradeCount;
            setKnobs({
                Brightness: 120,
                Warmth: 10,
                CloudDarkness: 70
            });
            verify(terrain.gradeCount > terrainGrades && clouds.gradeCount > cloudGrades, "lighting invalidates the affected assets");
        }
        function test_wind_and_rain_independence() {
            setKnobs({
                Wind: 0,
                RainIntensity: 100
            });
            var still = scene.windTime, falling = scene.time;
            var before = grabImage(scene);
            scene.paused = false;
            wait(200);
            scene.paused = true;
            compare(scene.windTime, still, "zero wind holds cloud phase");
            verify(scene.time > falling, "rain still falls");
            verify(!before.equals(grabImage(scene)));
            setKnobs({
                Wind: 0,
                RainIntensity: 0
            });
            before = grabImage(scene);
            scene.paused = false;
            wait(150);
            scene.paused = true;
            verify(before.equals(grabImage(scene)), "zero rain and zero wind leave a still frame");
            setKnobs({
                Wind: 50,
                RainIntensity: 0
            });
            before = grabImage(scene);
            var phase = scene.windTime;
            scene.paused = false;
            wait(150);
            scene.paused = true;
            verify(scene.windTime > phase);
            before = grabImage(scene);
            phase = scene.windTime;
            setKnobs({
                Wind: -50,
                RainIntensity: 0
            });
            compare(scene.windTime, phase);
            verify(before.equals(grabImage(scene)), "wind changes do not reset positions");
            scene.paused = false;
            wait(150);
            scene.paused = true;
            verify(scene.windTime < phase, "negative wind reverses motion");
        }
        function test_resize() {
            container.width = 1080;
            container.height = 1920;
            compare(scene.grid.rows, 600);
            verify(scene.sourceSize.rows <= 1000);
            verify(Math.abs(scene.grid.columns / scene.grid.rows - 1080 / 1920) < 0.01);
            container.width = 7680;
            container.height = 4320;
            compare(scene.grid.columns, 960);
            compare(scene.grid.rows, 540);
            compare(scene.sourceSize.columns, 1280);
            compare(scene.sourceSize.rows, 720);
        }
        function test_speed() {
            scene.speed = 2;
            scene.time = 0;
            scene.paused = false;
            wait(300);
            scene.paused = true;
            var slow = scene.time;
            scene.time = 0;
            scene.speed = 20;
            scene.paused = false;
            wait(300);
            scene.paused = true;
            verify(scene.time > slow * 4);
        }
        function test_composed_weather() {
            var images = [];
            var brightness = [];
            for (var weather = 0; weather < 3; weather++) {
                scene.controls = Controls.preset(["sunny", "cloudy", "rainy"][weather]);
                wait(150);
                var image = grabImage(scene);
                compare(image.width, 1280);
                compare(image.height, 720);
                verify(image.pixel(300, 365) !== image.pixel(50, 50), "left tree canopy must render");
                verify(image.pixel(1000, 220) !== image.pixel(50, 50), "textured sky must render");
                verify(image.pixel(100, 600) !== image.pixel(900, 600), "foreground overlook and river valley must differ");
                images.push(image);
                var color = image.pixel(100, 600);
                brightness.push(color.r + color.g + color.b);
            }
            verify(brightness[0] > brightness[1] && brightness[1] > brightness[2], "weather changes terrain lighting");
            verify(!images[0].equals(images[1]) && !images[1].equals(images[2]));
            var rainy = images[2];
            scene.time += 0.15;
            wait(150);
            var falling = grabImage(scene);
            var rainChanges = 0;
            for (var y = 520; y < 710; y += 3)
                for (var x = 20; x < 1240; x += 3)
                    if (rainy.pixel(x, y) !== falling.pixel(x, y))
                        rainChanges++;
            verify(rainChanges > 40, "rain must move across the foreground after compositing");
        }
    }
}

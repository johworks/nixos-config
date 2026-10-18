import QtQuick
import QtQuick.Window
import QtTest
import "../contents/ui"

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
            scene.weather = 0;
            scene.cellSize = 2;
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
                scene.weather = weather;
                wait(150);
                var image = grabImage(scene);
                compare(image.width, 1280);
                compare(image.height, 720);
                verify(image.pixel(300, 365) !== image.pixel(50, 50), "left tree canopy must render");
                verify(image.pixel(1000, 220) !== image.pixel(50, 50), "distant snow peak must render");
                verify(image.pixel(100, 600) !== image.pixel(900, 600), "foreground meadow and open lake must differ");
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

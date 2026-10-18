import QtQuick
import QtQuick.Window
import QtTest
import "../contents/ui"

Item {
    id: container
    width: 640
    height: 360
    WeatherScene {
        id: scene
        anchors.fill: parent
        cellSize: 2
    }
    TestCase {
        name: "WeatherScene"
        when: windowShown

        function init() {
            container.width = 640;
            container.height = 360;
            scene.visible = true;
            scene.animationEnabled = true;
            scene.paused = true;
            scene.speed = 10;
            scene.time = 0;
            scene.scene = 0;
            scene.weather = 0;
            scene.cellSize = 2;
        }
        function test_clock_controls() {
            scene.paused = false;
            tryVerify(function () {
                return scene.time > 0;
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
        function test_detail() {
            compare(scene.grid.columns, 320);
            compare(scene.grid.rows, 180);
            scene.cellSize = 8;
            compare(scene.grid.columns, 80);
            compare(scene.grid.rows, 45);
        }
        function test_hidden_window() {
            scene.paused = false;
            tryVerify(function () {
                return scene.time > 0;
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
        function test_resize() {
            container.width = 1080;
            container.height = 1920;
            compare(scene.grid.rows, 300);
            verify(Math.abs(scene.grid.columns / scene.grid.rows - 1080 / 1920) < 0.01);
            container.width = 7680;
            container.height = 4320;
            compare(scene.grid.columns, 480);
            compare(scene.grid.rows, 270);
        }
        function test_speed() {
            scene.speed = 2;
            scene.paused = false;
            wait(300);
            scene.paused = true;
            var slow = scene.time;
            scene.time = 0;
            scene.speed = 20;
            scene.paused = false;
            wait(300);
            scene.paused = true;
            verify(scene.time > slow * 4, "speed changes motion at a fixed frame rate");
        }
        function test_render_data() {
            return [
                {
                    tag: "hill-sunny",
                    landscape: 0,
                    weather: 0,
                    sky: "#77b5c8"
                },
                {
                    tag: "hill-cloudy",
                    landscape: 0,
                    weather: 1,
                    sky: "#829ba9"
                },
                {
                    tag: "hill-rainy",
                    landscape: 0,
                    weather: 2,
                    sky: "#475b70"
                },
                {
                    tag: "mountain-sunny",
                    landscape: 1,
                    weather: 0,
                    sky: "#77b5c8"
                },
                {
                    tag: "mountain-cloudy",
                    landscape: 1,
                    weather: 1,
                    sky: "#829ba9"
                },
                {
                    tag: "mountain-rainy",
                    landscape: 1,
                    weather: 2,
                    sky: "#475b70"
                }
            ];
        }
        function test_render(data) {
            scene.scene = data.landscape;
            scene.weather = data.weather;
            wait(100);
            var image = grabImage(scene);
            compare(image.width, 640);
            compare(image.height, 360);
            compare(image.pixel(10, 10), data.sky);
            verify(image.pixel(320, 340) !== image.pixel(10, 10));
        }
    }
}

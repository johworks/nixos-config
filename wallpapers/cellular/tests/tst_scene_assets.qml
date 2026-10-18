import QtQuick
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
        paused: true
        time: 12
    }
    Component {
        id: deferredArtwork
        WeatherScene {
            width: 1280
            height: 720
            scenerySource: ""
            cloudSource: ""
            paused: true
            time: 12
        }
    }
    TestCase {
        name: "ArtworkAssets"
        when: windowShown
        function init() {
            scene.controls = Controls.preset("sunny");
            scene.windTime = 12;
            scene.time = 12;
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
        }
        function pixels(item, name) {
            var layer = findChild(item, name);
            return layer.getContext("2d").getImageData(0, 0, layer.width, layer.height).data;
        }
        function test_loading_alpha_and_grading() {
            compare(scene.assetError, false);
            var before = pixels(scene, "sceneryCache");
            var width = scene.sourceSize.columns;
            compare(before[(100 * width + 1000) * 4 + 3], 0, "open sky stays transparent");
            verify(before[(600 * width + 100) * 4 + 3] > 240, "foreground asset pixel stays near-opaque");
            var red = before[(600 * width + 100) * 4];
            var cloudBefore = pixels(scene, "cloudCache");
            var gaps = 0, cloud = 0;
            for (var i = 3; i < cloudBefore.length; i += 44) {
                if (cloudBefore[i] === 0)
                    gaps++;
                else
                    cloud++;
            }
            verify(gaps > 100 && cloud > 100, "cloud artwork contains both clouds and alpha gaps");
            scene.controls = Controls.preset("rainy");
            tryCompare(scene, "assetsReady", true, 10000);
            var after = pixels(scene, "sceneryCache");
            verify(after[(600 * width + 100) * 4] < red * 0.8, "rain really grades asset pixels");
            var cloudAfter = pixels(scene, "cloudCache");
            var muted = 0;
            for (var j = 0; j < before.length; j += 116) {
                compare(after[j + 3], before[j + 3], "scenery grading preserves alpha");
                compare(cloudAfter[j + 3], cloudBefore[j + 3], "cloud grading preserves alpha");
                if (cloudAfter[j + 3] > 240 && cloudAfter[j] > 10) {
                    verify(Math.abs(cloudAfter[j] - cloudAfter[j + 2]) < 24, "rain clouds become grey");
                    muted++;
                }
            }
            verify(muted > 100);
            wait(100);
            var output = grabImage(scene);
            for (var y = 20; y < 700; y += 40)
                for (var x = 20; x < 1260; x += 40)
                    compare(output.pixel(x, y).a, 1, "sky fills every alpha gap in final frame");
        }
        function test_weather_during_loading() {
            var late = createTemporaryObject(deferredArtwork, container);
            verify(late !== null);
            verify(!late.assetsReady);
            late.controls = Controls.preset("cloudy");
            late.scenerySource = scene.scenerySource;
            late.cloudSource = scene.cloudSource;
            var custom = Controls.preset("rainy");
            custom.Brightness = 118;
            custom.Warmth = -23;
            custom.CloudDarkness = 51;
            custom.SunStrength = 63;
            late.controls = custom;
            late.windTime = 12;
            verify(!late.assetsReady, "no graded canvas has painted yet");
            tryCompare(late, "assetsReady", true, 10000);
            scene.controls = custom;
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
            verify(grabImage(late).equals(grabImage(scene)), "latest weather before load matches grading after load");
        }
        function test_clouds_behind_opaque_scenery() {
            var before = grabImage(scene);
            var artwork = pixels(scene, "sceneryCache");
            var cached = scene.staticPaintCount, grades = scene.gradePaintCount;
            scene.windTime = 87;
            wait(100);
            var after = grabImage(scene);
            var treePixels = 0, skyChanges = 0;
            for (var y = 20; y < 340; y += 5) {
                for (var x = 20; x < 420; x += 5) {
                    var i = (y * 1280 + x) * 4;
                    if (artwork[i + 3] > 250 && artwork[i + 7] > 250 && artwork[i + 1280 * 4 + 3] > 250 && artwork[i + 1280 * 4 + 7] > 250) {
                        var first = before.pixel(x, y), second = after.pixel(x, y);
                        verify(Math.abs(first.r - second.r) <= 6 / 255 && Math.abs(first.g - second.g) <= 6 / 255 && Math.abs(first.b - second.b) <= 6 / 255, "cloud drift is occluded by near-opaque tree pixels");
                        treePixels++;
                    }
                }
            }
            for (var sy = 20; sy < 250; sy += 5)
                for (var sx = 600; sx < 1260; sx += 5)
                    if (before.pixel(sx, sy) !== after.pixel(sx, sy))
                        skyChanges++;
            verify(treePixels > 200 && skyChanges > 100, "opaque tree samples " + treePixels + ", moving sky samples " + skyChanges);
            compare(scene.staticPaintCount, cached);
            compare(scene.gradePaintCount, grades, "motion never rereads/regrades static asset pixels");
        }
    }
}

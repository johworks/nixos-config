import QtQuick
import QtQuick.Window
import "contents/ui"
import "contents/ui/controls.js" as Controls
import "contents/ui/rain.js" as Rain

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Pixel Weather — canyon overlook"

    function option(name, fallback) {
        var args = Qt.application.arguments;
        for (var i = 0; i < args.length; i++)
            if (args[i].indexOf(name + "=") === 0)
                return args[i].slice(name.length + 1);
        return fallback;
    }
    WeatherScene {
        id: landscape
        anchors.fill: parent
        controls: {
            var knobs = Controls.preset(root.option("--preset", "sunny"));
            for (var i = 0; i < Controls.keys.length; i++) {
                var key = Controls.keys[i];
                knobs[key] = Number(root.option("--" + key, String(knobs[key])));
            }
            return knobs;
        }
        cellSize: Number(root.option("--cell", "2"))
        rainRandom: root.option("--seed", "") === "" ? Math.random : Rain.seededRandom(Number(root.option("--seed", "0")))
        paused: Qt.application.arguments.indexOf("--capture") >= 0
        time: 12
        windTime: 12
    }
    Timer {
        property int frames: Math.max(1, Math.min(40, Math.floor(Number(root.option("--frames", "1")) || 1)))
        property int frame: 0
        interval: frames > 1 ? 500 : 1500
        property int attempts: 0
        repeat: true
        running: Qt.application.arguments.indexOf("--capture") >= 0
        onTriggered: {
            attempts++;
            if (!landscape.assetsReady) {
                if (landscape.assetError || attempts >= 30)
                    Qt.exit(1);
                return;
            }
            if (frame >= frames)
                return;
            stop();
            frame++;
            var path = root.option("--output", "/tmp/pixel-weather-preview.png");
            if (frames > 1)
                path += "-" + ("00" + frame).slice(-2) + ".png";
            landscape.grabToImage(function (result) {
                if (!result.saveToFile(path)) {
                    Qt.exit(1);
                    return;
                }
                if (frame === frames) {
                    Qt.quit();
                    return;
                }
                // Capture a repeatable temporal sequence through the same
                // bounded simulation steps used by the live timer.
                for (var step = 0; step < 5; step++)
                    landscape.advanceAnimation(0.1);
                start();
            });
        }
    }
}

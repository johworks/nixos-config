import QtQuick
import QtQuick.Window
import "contents/ui"
import "contents/ui/controls.js" as Controls

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
        paused: Qt.application.arguments.indexOf("--capture") >= 0
        time: 12
        windTime: 12
    }
    Timer {
        interval: 1500
        property int attempts: 0
        repeat: true
        running: Qt.application.arguments.indexOf("--capture") >= 0
        onTriggered: {
            attempts++;
            if (!landscape.assetsReady) {
                if (landscape.assetError || attempts >= 10)
                    Qt.exit(1);
                return;
            }
            stop();
            landscape.grabToImage(function (result) {
                Qt.exit(result.saveToFile(root.option("--output", "/tmp/pixel-weather-preview.png")) ? 0 : 1);
            });
        }
    }
}

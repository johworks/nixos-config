import QtQuick
import QtQuick.Window
import "contents/ui"

Window {
    id: root
    width: 1280
    height: 720
    visible: true
    title: "Pixel Weather — foreground hill and distant mountains"

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
        weather: Number(root.option("--weather", "0"))
        cellSize: Number(root.option("--cell", "2"))
        paused: Qt.application.arguments.indexOf("--capture") >= 0
        time: 12
    }
    Timer {
        interval: 1500
        running: Qt.application.arguments.indexOf("--capture") >= 0
        onTriggered: landscape.grabToImage(function (result) {
            result.saveToFile(root.option("--output", "/tmp/pixel-weather-preview.png"));
            Qt.quit();
        })
    }
}

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Window
import "contents/ui"

Window {
    id: root
    width: 1440
    height: 588
    visible: true
    color: "#24333c"
    title: "Pixel Weather — simulated conditions"

    Grid {
        anchors.fill: parent
        columns: 3
        Repeater {
            model: 6
            delegate: Column {
                id: tile
                required property int index
                width: root.width / 3
                Text {
                    width: parent.width
                    height: 24
                    text: (tile.index < 3 ? "HILL & TREE / " : "MOUNTAIN LAKE / ") + ["SUNNY", "CLOUDY", "RAINY"][tile.index % 3]
                    color: "#e5e8e0"
                    font.pixelSize: 12
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignHCenter
                }
                WeatherScene {
                    width: parent.width
                    height: (root.height - 48) / 2
                    scene: Math.floor(tile.index / 3)
                    weather: tile.index % 3
                    cellSize: 2
                    paused: Qt.application.arguments.indexOf("--capture") >= 0
                    time: 12
                }
            }
        }
    }
    Timer {
        interval: 1200
        running: Qt.application.arguments.indexOf("--capture") >= 0
        onTriggered: root.contentItem.grabToImage(function (result) {
            result.saveToFile("/tmp/pixel-weather-preview.png");
            Qt.quit();
        })
    }
}

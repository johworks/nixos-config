import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    accentColor: "#8ba27c"
    contextualActions: [
        PlasmaCore.Action {
            text: root.configuration.Paused ? "Resume weather animation" : "Pause weather animation"
            icon.name: root.configuration.Paused ? "media-playback-start" : "media-playback-pause"
            onTriggered: root.configuration.Paused = !root.configuration.Paused
        },
        PlasmaCore.Action {
            text: "Sunny weather"
            icon.name: "weather-clear"
            onTriggered: root.configuration.Weather = 0
        },
        PlasmaCore.Action {
            text: "Cloudy weather"
            icon.name: "weather-clouds"
            onTriggered: root.configuration.Weather = 1
        },
        PlasmaCore.Action {
            text: "Rainy weather"
            icon.name: "weather-showers"
            onTriggered: root.configuration.Weather = 2
        }
    ]

    WeatherScene {
        anchors.fill: parent
        weather: root.configuration.Weather
        cellSize: root.configuration.CellSize
        speed: root.configuration.Speed
        paused: root.configuration.Paused
    }
}

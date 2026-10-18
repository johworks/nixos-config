import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root

    LiveConfig {
        id: liveConfig
        configuration: root.configuration
    }

    accentColor: "#8ba27c"
    contextualActions: [
        PlasmaCore.Action {
            text: root.configuration.Paused ? "Resume weather animation" : "Pause weather animation"
            icon.name: root.configuration.Paused ? "media-playback-start" : "media-playback-pause"
            onTriggered: liveConfig.togglePause()
        },
        PlasmaCore.Action {
            text: "Apply sunny preset"
            icon.name: "weather-clear"
            onTriggered: liveConfig.applyPreset("sunny")
        },
        PlasmaCore.Action {
            text: "Apply cloudy preset"
            icon.name: "weather-clouds"
            onTriggered: liveConfig.applyPreset("cloudy")
        },
        PlasmaCore.Action {
            text: "Apply rainy preset"
            icon.name: "weather-showers"
            onTriggered: liveConfig.applyPreset("rainy")
        }
    ]

    WeatherScene {
        anchors.fill: parent
        controls: ({
                Brightness: root.configuration.Brightness,
                Warmth: root.configuration.Warmth,
                SunX: root.configuration.SunX,
                SunY: root.configuration.SunY,
                SunStrength: root.configuration.SunStrength,
                CloudAmount: root.configuration.CloudAmount,
                CloudDarkness: root.configuration.CloudDarkness,
                Wind: root.configuration.Wind,
                RainIntensity: root.configuration.RainIntensity
            })
        cellSize: root.configuration.CellSize
        speed: root.configuration.Speed
        paused: root.configuration.Paused
    }
}

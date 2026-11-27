import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

WallpaperItem {
    id: root
    property alias automaticWeather: automaticController
    property alias celestialClock: skyClock

    LiveConfig {
        id: liveConfig
        configuration: root.configuration
    }
    AutomaticWeather {
        id: automaticController
        automatic: root.configuration.Automatic === true
        locationLabel: root.configuration.LocationLabel
        latitude: root.configuration.LocationLatitude
        longitude: root.configuration.LocationLongitude
    }

    CelestialClock {
        id: skyClock
        automatic: root.configuration.Automatic === true
        latitude: root.configuration.LocationLatitude
        longitude: root.configuration.LocationLongitude
        manualNight: root.configuration.ManualNight === true
        manualPhase: root.configuration.ManualMoonPhase
        starStrength: root.configuration.StarStrength
        moonStrength: root.configuration.MoonStrength
        moonX: root.configuration.MoonX
        moonY: root.configuration.MoonY
    }

    accentColor: "#8ba27c"
    contextualActions: [
        PlasmaCore.Action {
            text: root.configuration.Paused ? "Resume weather animation" : "Pause weather animation"
            icon.name: root.configuration.Paused ? "media-playback-start" : "media-playback-pause"
            onTriggered: liveConfig.togglePause()
        },
        PlasmaCore.Action {
            text: "Manual: apply sunny preset"
            icon.name: "weather-clear"
            onTriggered: liveConfig.applyPreset("sunny")
        },
        PlasmaCore.Action {
            text: "Manual: apply cloudy preset"
            icon.name: "weather-clouds"
            onTriggered: liveConfig.applyPreset("cloudy")
        },
        PlasmaCore.Action {
            text: "Manual: apply rainy preset"
            icon.name: "weather-showers"
            onTriggered: liveConfig.applyPreset("rainy")
        }
    ]

    WeatherScene {
        anchors.fill: parent
        celestial: skyClock.sky
        controls: automaticController.automatic && automaticController.output ? automaticController.output.controls : ({
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

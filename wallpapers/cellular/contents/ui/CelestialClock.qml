import QtQuick
import "celestial.js" as Sky
import "weather.js" as Weather

Item {
    id: root
    visible: false
    property bool automatic: false
    property string latitude: "42.35843"
    property string longitude: "-71.05977"
    property bool manualNight: false
    property int manualPhase: 25
    property int starStrength: 70
    property int moonStrength: 85
    property int moonX: 77
    property int moonY: 21
    property double now: Date.now()
    readonly property var place: Weather.location(latitude, longitude)
    readonly property real fade: automatic ? (place ? Sky.darkness(Weather.solar(now, place).altitude) : 0) : (manualNight ? 1 : 0)
    readonly property real moonPhase: automatic ? Sky.phase(now) : Sky.mod(manualPhase / 100, 1)
    readonly property var sky: ({
            now: now,
            place: place,
            fade: fade,
            phase: moonPhase,
            starStrength: Sky.clamp(starStrength / 100, 0, 1),
            moonStrength: Sky.clamp(moonStrength / 100, 0, 1),
            moonX: Sky.clamp(moonX / 100, 0, 1),
            moonY: Sky.clamp(moonY / 100, 0, 1)
        })
    readonly property string statusText: "Stars face true west (270°). Moon position is artistic; " + (automatic ? "approximate date phase: " : "Manual phase: ") + Sky.phaseName(moonPhase) + "."
    Timer {
        objectName: "celestialMinuteClock"
        interval: 60000
        repeat: true
        running: (root.automatic || root.manualNight) && (root.starStrength > 0 || root.moonStrength > 0)
        onRunningChanged: if (running)
            root.now = Date.now()
        onTriggered: root.now = Date.now()
    }
}

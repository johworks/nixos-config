import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "controls.js" as Controls
import "weather.js" as Weather

Kirigami.FormLayout {
    id: root
    // Plasma supplies these initial properties when creating the settings page.
    property var configDialog: null
    property var wallpaperConfiguration: null
    // The settings host attaches a Containment beyond the base Applet metadata,
    // using this same property in ConfigurationContainmentAppearance.qml.
    // qmllint disable missing-property
    property var runtimeWallpaper: Plasmoid ? Plasmoid.wallpaperGraphicsObject : null
    // qmllint enable missing-property
    readonly property var liveWeather: runtimeWallpaper && runtimeWallpaper.automaticWeather !== undefined ? runtimeWallpaper.automaticWeather : null
    // Plasma's wallpaper settings loader supplies this context property.
    // qmllint disable unqualified
    twinFormLayouts: parentLayout
    // qmllint enable unqualified
    // Keep migration metadata available when configuring before activation.
    property int cfg_Weather: 0
    property int cfg_ControlsVersion: 0
    property alias formLayout: root
    property alias cfg_Brightness: knobBrightness.value
    property alias cfg_Warmth: knobWarmth.value
    property alias cfg_SunX: knobSunX.value
    property alias cfg_SunY: knobSunY.value
    property alias cfg_SunStrength: knobSunStrength.value
    property alias cfg_CloudAmount: knobCloudAmount.value
    property alias cfg_CloudDarkness: knobCloudDarkness.value
    property alias cfg_Wind: knobWind.value
    property alias cfg_RainIntensity: knobRainIntensity.value
    property alias cfg_CellSize: cellSize.value
    property alias cfg_Speed: speed.value
    property alias cfg_Paused: paused.checked
    property alias cfg_Automatic: automatic.checked
    property alias cfg_LocationLabel: locationLabel.text
    property alias cfg_LocationLatitude: latitude.text
    property alias cfg_LocationLongitude: longitude.text
    function initializeControls() {
        Controls.migrate(root, "cfg_");
    }
    // The host injects saved cfg_* values after creating this component.
    Component.onCompleted: Qt.callLater(initializeControls)
    function applyPreset(name) {
        cfg_Automatic = false;
        Controls.writePreset(root, name, "cfg_");
    }

    Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 440
        text: "Choose Automatic or Manual and press Apply. Manual presets select Manual. Scroll down for saved manual controls, speed and pause. Unapplied edits do not change the wallpaper."
        wrapMode: Text.WordWrap
    }
    CheckBox {
        id: automatic
        objectName: "automaticControl"
        Kirigami.FormData.label: "Mode:"
        text: "Automatic (uncheck for Manual)"
    }
    TextField {
        id: locationLabel
        Kirigami.FormData.label: "Location name:"
        text: "Boston, Massachusetts, USA"
        enabled: automatic.checked
        Layout.fillWidth: true
        Layout.maximumWidth: 440
    }
    TextField {
        id: latitude
        Kirigami.FormData.label: "Latitude (−90 to 90):"
        text: "42.35843"
        enabled: automatic.checked
    }
    TextField {
        id: longitude
        Kirigami.FormData.label: "Longitude (−180 to 180):"
        text: "-71.05977"
        enabled: automatic.checked
    }
    Label {
        visible: automatic.checked && Weather.location(latitude.text, longitude.text) === null
        text: "Enter valid coordinates before applying. Invalid locations make no weather requests."
        Layout.fillWidth: true
        Layout.maximumWidth: 440
        wrapMode: Text.WordWrap
    }
    Label {
        objectName: "automaticStatus"
        Kirigami.FormData.label: "Active status:"
        text: root.liveWeather ? root.liveWeather.statusText : "No active controller for this wallpaper. Apply to activate the selected mode."
        textFormat: Text.PlainText
        Layout.fillWidth: true
        Layout.maximumWidth: 440
        wrapMode: Text.WordWrap
    }
    Label {
        text: "Weather: <a href='https://open-meteo.com/'>Open-Meteo</a> model estimates, refreshed about every 15 minutes. Fixed coordinates; no device tracking. Seasons change palette only. Snow is reported but not animated; no snow-only rain."
        textFormat: Text.RichText
        onLinkActivated: link => Qt.openUrlExternally(link)
        Layout.fillWidth: true
        Layout.maximumWidth: 440
        wrapMode: Text.WordWrap
    }
    RowLayout {
        Kirigami.FormData.label: "Manual presets:"
        Button {
            text: "Sunny"
            onClicked: root.applyPreset("sunny")
        }
        Button {
            text: "Cloudy"
            onClicked: root.applyPreset("cloudy")
        }
        Button {
            text: "Rainy"
            onClicked: root.applyPreset("rainy")
        }
    }
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Lighting"
    }
    SpinBox {
        id: knobBrightness
        enabled: !automatic.checked
        objectName: "brightnessControl"
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Scene brightness (%):"
        from: 0
        to: 150
        value: 100
        editable: true
    }
    SpinBox {
        id: knobWarmth
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Color warmth (−100 cool, +100 warm):"
        from: -100
        to: 100
        value: 100
        editable: true
    }
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Sun"
    }
    SpinBox {
        id: knobSunX
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Sun horizontal position (%):"
        from: 0
        to: 100
        value: 73
        editable: true
    }
    SpinBox {
        id: knobSunY
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Sun vertical position (0 = top):"
        from: 0
        to: 100
        value: 34
        editable: true
    }
    SpinBox {
        id: knobSunStrength
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Sun strength (0 = hidden):"
        from: 0
        to: 100
        value: 100
        editable: true
    }
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Clouds"
    }
    SpinBox {
        id: knobCloudAmount
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Cloud amount (%):"
        from: 0
        to: 100
        value: 100
        editable: true
    }
    SpinBox {
        id: knobCloudDarkness
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Cloud darkness (%):"
        from: 0
        to: 100
        value: 0
        editable: true
    }
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Wind and rain"
    }
    SpinBox {
        id: knobWind
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Wind (− left, 0 still, + right):"
        from: -100
        to: 100
        value: 35
        editable: true
    }
    SpinBox {
        id: knobRainIntensity
        enabled: !automatic.checked
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Rain intensity (%):"
        from: 0
        to: 100
        value: 0
        editable: true
    }
    Item {
        Kirigami.FormData.isSection: true
        Kirigami.FormData.label: "Detail and animation"
    }
    SpinBox {
        id: cellSize
        Kirigami.FormData.label: "Cell size (smaller = finer):"
        from: 2
        to: 20
        value: 2
        editable: true
    }
    SpinBox {
        id: speed
        Kirigami.FormData.label: "Animation speed (10 = normal):"
        from: 1
        to: 20
        value: 10
        editable: true
    }
    CheckBox {
        id: paused
        text: "Pause animation"
    }
    Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 400
        text: "Change any layer independently. Presets are starting points. Wind zero keeps clouds still while rain can fall vertically."
        wrapMode: Text.WordWrap
    }
}

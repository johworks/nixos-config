import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "controls.js" as Controls

Kirigami.FormLayout {
    id: root
    // Plasma supplies these initial properties when creating the settings page.
    property var configDialog: null
    property var wallpaperConfiguration: null
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
    function initializeControls() {
        Controls.migrate(root, "cfg_");
    }
    // The host injects saved cfg_* values after creating this component.
    Component.onCompleted: Qt.callLater(initializeControls)
    function applyPreset(name) {
        Controls.writePreset(root, name, "cfg_");
    }

    Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 440
        text: "Choose a preset or edit individual controls, then press Apply to see the result. Scroll down for wind, rain, speed and pause."
        wrapMode: Text.WordWrap
    }
    RowLayout {
        Kirigami.FormData.label: "Convenience presets:"
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
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Sun horizontal position (%):"
        from: 0
        to: 100
        value: 73
        editable: true
    }
    SpinBox {
        id: knobSunY
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Sun vertical position (0 = top):"
        from: 0
        to: 100
        value: 34
        editable: true
    }
    SpinBox {
        id: knobSunStrength
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
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Cloud amount (%):"
        from: 0
        to: 100
        value: 100
        editable: true
    }
    SpinBox {
        id: knobCloudDarkness
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
        onValueModified: root.cfg_ControlsVersion = 1
        Kirigami.FormData.label: "Wind (− left, 0 still, + right):"
        from: -100
        to: 100
        value: 35
        editable: true
    }
    SpinBox {
        id: knobRainIntensity
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

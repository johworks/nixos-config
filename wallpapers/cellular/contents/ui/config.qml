import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    // Plasma's wallpaper settings loader supplies this context property.
    // qmllint disable unqualified
    twinFormLayouts: parentLayout
    // qmllint enable unqualified

    property alias cfg_Scene: scene.currentIndex
    property alias cfg_Weather: weather.currentIndex
    property alias cfg_CellSize: cellSize.value
    property alias cfg_Speed: speed.value
    property alias cfg_Paused: paused.checked
    property alias formLayout: root

    ComboBox {
        id: scene
        Kirigami.FormData.label: "Landscape:"
        model: ["Hill and tree", "Mountain lake"]
    }
    ComboBox {
        id: weather
        Kirigami.FormData.label: "Simulated weather:"
        model: ["Sunny", "Cloudy", "Rainy"]
    }
    SpinBox {
        id: cellSize
        Kirigami.FormData.label: "Cell size (smaller = finer):"
        from: 2
        to: 20
    }
    SpinBox {
        id: speed
        Kirigami.FormData.label: "Animation speed (10 = normal):"
        from: 1
        to: 20
    }
    CheckBox {
        id: paused
        text: "Pause weather animation"
    }
    Label {
        Layout.fillWidth: true
        Layout.maximumWidth: 400
        text: "A shared pixel grid keeps every layer aligned. Detail is capped on large displays. Right-click the desktop for weather and pause actions."
        wrapMode: Text.WordWrap
    }
}

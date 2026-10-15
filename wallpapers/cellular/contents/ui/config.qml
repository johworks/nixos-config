import QtQuick
import QtQuick.Controls
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: root
    twinFormLayouts: parentLayout

    property alias cfg_CellSize: cellSize.value
    property alias cfg_Speed: speed.value
    property alias cfg_ReseedSeconds: reseed.value
    property alias formLayout: root

    SpinBox {
        id: cellSize
        Kirigami.FormData.label: "Cell size (pixels):"
        from: 8
        to: 32
    }

    SpinBox {
        id: speed
        Kirigami.FormData.label: "Generations per second:"
        from: 1
        to: 20
    }

    SpinBox {
        id: reseed
        Kirigami.FormData.label: "New random world after (seconds):"
        from: 15
        to: 600
        stepSize: 15
    }

    Label {
        text: "Quiet worlds restart early. Right-click the desktop to reseed or pause."
        wrapMode: Text.WordWrap
    }
}

import QtQuick
import QtQuick.Window
import "landscape.js" as Landscape

Item {
    id: root

    property int scene: 0
    property int weather: 0
    property int cellSize: 4
    property int speed: 10
    property bool paused: false
    property bool animationEnabled: true
    property real time: 0
    property double lastTick: 0
    readonly property var grid: Landscape.grid(width, height, cellSize)
    readonly property bool windowVisible: Window.window !== null && Window.window.visible && Window.window.visibility !== Window.Minimized
    readonly property bool animating: visible && windowVisible && animationEnabled && !paused && width > 0 && height > 0

    function repaint() {
        surface.requestPaint();
    }

    onSceneChanged: repaint()
    onWeatherChanged: repaint()
    onTimeChanged: repaint()
    onGridChanged: repaint()
    onVisibleChanged: if (visible)
        repaint()

    Canvas {
        id: surface
        width: root.grid.columns
        height: root.grid.rows
        smooth: false
        transform: Scale {
            xScale: root.width / surface.width
            yScale: root.height / surface.height
        }
        onPaint: Landscape.render(getContext("2d"), width, height, root.scene, root.weather, root.time)
    }

    Timer {
        interval: 50
        running: root.animating
        repeat: true
        onRunningChanged: root.lastTick = Date.now()
        onTriggered: {
            var now = Date.now();
            root.time = Landscape.advance(root.time, (now - root.lastTick) / 1000, root.speed);
            root.lastTick = now;
        }
    }
}

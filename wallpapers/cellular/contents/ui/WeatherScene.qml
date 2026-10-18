import QtQuick
import QtQuick.Window
import "landscape.js" as Landscape

Item {
    id: root
    clip: true

    property int weather: 0
    property int cellSize: 4
    property int speed: 10
    property bool paused: false
    property bool animationEnabled: true
    property real time: 0
    property double lastTick: 0
    readonly property var grid: Landscape.grid(width, height, cellSize)
    readonly property var sourceSize: Landscape.sourceSize(width, height)
    readonly property bool windowVisible: Window.window !== null && Window.window.visible && Window.window.visibility !== Window.Minimized
    readonly property bool animating: visible && windowVisible && animationEnabled && !paused && width > 0 && height > 0
    property int staticPaintCount: 0
    property int compositePaintCount: 0

    function repaintStatic() {
        sky.requestPaint();
        terrain.requestPaint();
    }
    onWeatherChanged: repaintStatic()
    onSourceSizeChanged: repaintStatic()
    onTimeChanged: composition.requestPaint()
    onGridChanged: output.requestPaint()
    onVisibleChanged: if (visible)
        composition.requestPaint()

    // Offscreen source canvases keep rich artwork cached, independent of the
    // final grid. Canvas drawImage's nine-argument overload samples their images.
    Item {
        opacity: 0
        Canvas {
            id: sky
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            onPaint: {
                Landscape.sky(getContext("2d"), width, height, root.weather);
                root.staticPaintCount++;
            }
            onPainted: composition.requestPaint()
        }
        Canvas {
            id: terrain
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            onPaint: {
                Landscape.scenery(getContext("2d"), width, height, root.weather);
                root.staticPaintCount++;
            }
            onPainted: composition.requestPaint()
        }
        Canvas {
            id: composition
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                ctx.drawImage(sky, 0, 0, width, height, 0, 0, width, height);
                Landscape.clouds(ctx, width, height, root.weather, root.time);
                ctx.resetTransform();
                ctx.drawImage(terrain, 0, 0, width, height, 0, 0, width, height);
                Landscape.rain(ctx, width, height, root.weather, root.time);
                root.compositePaintCount++;
            }
            onPainted: output.requestPaint()
        }
    }
    Canvas {
        id: output
        width: root.grid.columns
        height: root.grid.rows
        smooth: false
        antialiasing: false
        transform: Scale {
            xScale: root.width / output.width
            yScale: root.height / output.height
        }
        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.drawImage(composition, 0, 0, composition.width, composition.height, 0, 0, width, height);
        }
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

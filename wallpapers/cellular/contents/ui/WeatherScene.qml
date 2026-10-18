import QtQuick
import QtQuick.Window
import "landscape.js" as Landscape

Item {
    id: root
    clip: true

    property int weather: 0
    property int cellSize: 2
    property int speed: 10
    property bool paused: false
    property bool animationEnabled: true
    property real time: 0
    property double lastTick: 0
    property url scenerySource: Qt.resolvedUrl("../images/canyon-scenery-v1.png")
    property url cloudSource: Qt.resolvedUrl("../images/canyon-clouds-v1.png")
    readonly property bool assetsReady: terrain.cached && clouds.cached
    readonly property bool assetError: terrain.imageError || clouds.imageError
    readonly property var grid: Landscape.grid(width, height, cellSize)
    readonly property var sourceSize: Landscape.sourceSize(width, height)
    readonly property bool windowVisible: Window.window !== null && Window.window.visible && Window.window.visibility !== Window.Minimized
    readonly property bool animating: visible && windowVisible && assetsReady && animationEnabled && !paused && width > 0 && height > 0
    property int skyPaintCount: 0
    readonly property int staticPaintCount: skyPaintCount + terrain.paintCount + clouds.paintCount
    property int compositePaintCount: 0
    readonly property int gradePaintCount: terrain.gradeCount + clouds.gradeCount

    function repaintStatic() {
        sky.requestPaint();
    }
    onWeatherChanged: repaintStatic()
    onSourceSizeChanged: repaintStatic()
    onTimeChanged: composition.requestPaint()
    onGridChanged: output.requestPaint()
    onVisibleChanged: if (visible)
        composition.requestPaint()

    // Cached source images stay independent of the final sampling grid.
    Item {
        opacity: 0
        Canvas {
            id: sky
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            onPaint: {
                Landscape.sky(getContext("2d"), width, height, root.weather);
                root.skyPaintCount++;
            }
            onPainted: composition.requestPaint()
        }
        ArtworkLayer {
            id: terrain
            objectName: "sceneryCache"
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            imageSource: root.scenerySource
            weather: root.weather
            onPainted: composition.requestPaint()
        }
        ArtworkLayer {
            id: clouds
            objectName: "cloudCache"
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            imageSource: root.cloudSource
            weather: root.weather
            cloud: true
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
                var drift = Landscape.cloudPlacement(width, height, root.time);
                ctx.drawImage(clouds, 0, 0, width, height, drift.x, drift.y, drift.width, drift.height);
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

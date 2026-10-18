import QtQuick
import QtQuick.Window
import "landscape.js" as Landscape
import "controls.js" as Controls

Item {
    id: root
    clip: true

    property var controls: Controls.preset("sunny")
    readonly property var atmosphere: Controls.normalize(controls)
    property int cellSize: 2
    property int speed: 10
    property bool paused: false
    property bool animationEnabled: true
    property real time: 0
    property real windTime: 0
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

    onAtmosphereChanged: composition.requestPaint()
    onTimeChanged: composition.requestPaint()
    onWindTimeChanged: composition.requestPaint()
    onGridChanged: output.requestPaint()
    onVisibleChanged: if (visible)
        composition.requestPaint()

    // Cached source images stay independent of the final sampling grid.
    Item {
        opacity: 0
        Canvas {
            id: sky
            property real brightness: root.atmosphere.brightness
            property real warmth: root.atmosphere.warmth
            property real sunX: root.atmosphere.sunX
            property real sunY: root.atmosphere.sunY
            property real strength: root.atmosphere.sunStrength
            onBrightnessChanged: requestPaint()
            onWarmthChanged: requestPaint()
            onSunXChanged: requestPaint()
            onSunYChanged: requestPaint()
            onStrengthChanged: requestPaint()
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            onPaint: {
                Landscape.sky(getContext("2d"), width, height, root.atmosphere);
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
            brightness: root.atmosphere.brightness
            warmth: root.atmosphere.warmth
            onPainted: composition.requestPaint()
        }
        ArtworkLayer {
            id: clouds
            objectName: "cloudCache"
            width: root.sourceSize.columns
            height: root.sourceSize.rows
            imageSource: root.cloudSource
            brightness: root.atmosphere.brightness
            warmth: root.atmosphere.warmth
            cloud: true
            darkness: root.atmosphere.cloudDarkness
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
                var layers = Landscape.cloudPlacements(width, height, root.windTime);
                for (var i = 0; i < layers.length; i++) {
                    var layer = layers[i];
                    ctx.globalAlpha = root.atmosphere.cloudAmount * layer.opacity;
                    ctx.drawImage(clouds, 0, 0, width, height, layer.x, layer.y, layer.width, layer.height);
                }
                ctx.globalAlpha = 1;
                ctx.drawImage(terrain, 0, 0, width, height, 0, 0, width, height);
                Landscape.rain(ctx, width, height, root.atmosphere.rain, root.atmosphere.wind, root.time, root.windTime);
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
            var next = Landscape.advance(root.time, (now - root.lastTick) / 1000, root.speed);
            // Wind 35 keeps the original calm rate; integrate so reversing or
            // stopping wind preserves positions instead of resetting the phase.
            root.windTime += (next - root.time) * root.atmosphere.wind / 0.35;
            root.time = next;
            root.lastTick = now;
        }
    }
}

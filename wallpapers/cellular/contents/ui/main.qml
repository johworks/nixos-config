import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "life.js" as Life

WallpaperItem {
    id: root

    // Bound simulation and texture sizes even on large or high-DPI displays.
    readonly property int columns: Math.max(8, Math.min(240, Math.ceil(width / Math.max(8, configuration.CellSize))))
    readonly property int rows: Math.max(8, Math.min(160, Math.ceil(height / Math.max(8, configuration.CellSize))))
    readonly property int speed: Math.max(1, Math.min(20, configuration.Speed))
    property var world: null
    property bool paused: false
    property double seededAt: 0

    accentColor: "#83c9b3"

    function reseed() {
        if (width <= 0 || height <= 0)
            return;
        world = Life.create(columns, rows, Math.random);
        seededAt = Date.now();
        surface.requestPaint();
    }

    onColumnsChanged: reseed()
    onRowsChanged: reseed()
    Component.onCompleted: reseed()

    contextualActions: [
        PlasmaCore.Action {
            text: "New random life seed"
            icon.name: "view-refresh"
            onTriggered: root.reseed()
        },
        PlasmaCore.Action {
            text: root.paused ? "Resume cellular wallpaper" : "Pause cellular wallpaper"
            icon.name: root.paused ? "media-playback-start" : "media-playback-pause"
            onTriggered: root.paused = !root.paused
        }
    ]

    Rectangle {
        anchors.fill: parent
        color: "#101820"
    }

    Canvas {
        id: surface
        // Paint a small texture and scale it, rather than upload a full 4K image each tick.
        width: root.columns * 4
        height: root.rows * 4
        smooth: false
        transform: Scale {
            xScale: root.width / surface.width
            yScale: root.height / surface.height
        }

        onPaint: {
            if (!root.world)
                return;
            var ctx = getContext("2d");
            ctx.fillStyle = "#101820";
            ctx.fillRect(0, 0, width, height);
            var world = root.world;
            for (var y = 0; y < world.rows; ++y) {
                for (var x = 0; x < world.columns; ++x) {
                    var index = y * world.columns + x;
                    if (world.cells[index]) {
                        ctx.fillStyle = world.age[index] < 3 ? "#b8e0c8" : world.age[index] < 8 ? "#70b7aa" : "#457e87";
                    } else if (world.trail[index]) {
                        ctx.fillStyle = Qt.rgba(0.25, 0.55, 0.62, world.trail[index] / 22);
                    } else {
                        continue;
                    }
                    ctx.fillRect(x * 4, y * 4, 3, 3);
                }
            }
        }
    }

    Timer {
        interval: 1000 / root.speed
        running: root.visible && !root.paused && root.world !== null
        repeat: true
        onTriggered: {
            if (Date.now() - root.seededAt >= Math.max(15, root.configuration.ReseedSeconds) * 1000 || root.world.quiet >= root.speed * 10) {
                root.reseed();
            } else {
                Life.step(root.world);
                surface.requestPaint();
            }
        }
    }
}

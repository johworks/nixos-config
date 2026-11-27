import QtQuick
import "celestial.js" as Sky
import "star-catalog.js" as Catalog

Canvas {
    id: root
    objectName: "celestialCache"
    property var sky: null
    property int paintCount: 0
    property int projectedCount: 0
    onSkyChanged: requestPaint()
    onPaint: {
        projectedCount = Sky.draw(getContext("2d"), width, height, sky, Catalog.stars);
        paintCount++;
    }
}

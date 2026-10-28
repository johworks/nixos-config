import QtQuick
import "landscape.js" as Landscape

Canvas {
    id: root
    property url imageSource
    property real brightness: 1
    property real warmth: 1
    property real darkness: 0
    property bool cloud: false
    property bool imageReady: false
    property bool imageError: false
    property bool cached: false
    property int paintCount: 0
    property int gradeCount: 0
    property url loadedSource

    function reload() {
        imageReady = false;
        imageError = false;
        cached = false;
        if (!available)
            return;
        if (loadedSource.toString() && loadedSource !== imageSource)
            unloadImage(loadedSource);
        loadedSource = imageSource;
        if (!imageSource.toString()) {
            requestPaint();
            return;
        }
        loadImage(imageSource, Qt.size(1600, 1000));
        updateReady();
    }
    function updateReady() {
        imageReady = isImageLoaded(imageSource);
        imageError = isImageError(imageSource);
        requestPaint();
    }
    onImageSourceChanged: reload()
    onAvailableChanged: if (available)
        reload()
    onImageLoaded: updateReady()
    function regrade() {
        cached = false;
        requestPaint();
    }
    onBrightnessChanged: regrade()
    onWarmthChanged: regrade()
    onDarknessChanged: regrade()
    onWidthChanged: {
        cached = false;
        requestPaint();
    }
    onHeightChanged: {
        cached = false;
        requestPaint();
    }
    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        if (imageReady) {
            Landscape.asset(ctx, width, height, imageSource, brightness, warmth, cloud, darkness);
            gradeCount++;
        }
        paintCount++;
    }
    onPainted: cached = imageReady
}

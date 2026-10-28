import QtQuick
import "weather.js" as Weather

Item {
    id: root
    visible: false
    property bool automatic: false
    property string locationLabel: "Boston, Massachusetts, USA"
    property string latitude: "42.35843"
    property string longitude: "-71.05977"
    property var requestFactory: function () {
        return new XMLHttpRequest();
    }
    property double now: Date.now()
    readonly property var place: Weather.location(latitude, longitude)
    property var sample: null
    property double receivedAt: 0
    property string error: ""
    property var activeRequest: null
    property int generation: 0
    property bool ready: false
    property string sampleLocation: ""
    readonly property var output: place ? Weather.scene(sample, now, place) : null
    readonly property string statusText: {
        if (!automatic)
            return "Manual — saved controls. No weather requests.";
        if (!place)
            return "Automatic paused: invalid latitude/longitude. Using saved manual controls; no weather requests.";
        var text = "Automatic · " + locationLabel + " · " + place.key + "\nOpen-Meteo model estimate · " + output.phase + " · " + output.season;
        if (sample) {
            var age = Math.max(0, Math.floor((now - sample.time) / 60000));
            text += "\n" + sample.description + " · " + sample.temperature + " °C · " + sample.timezone;
            text += "\nEstimate age " + age + " min; fetched " + Math.max(0, Math.floor((now - receivedAt) / 60000)) + " min ago";
            if (age > 30)
                text += " (stale)";
            if (sample.snow > 0 || [71, 73, 75, 77, 85, 86].indexOf(sample.code) >= 0)
                text += "\nSnow reported; snow animation unsupported. Only liquid rain is drawn.";
        } else {
            text += "\nFallback: assumed partly cloudy, dry, calm; no weather estimate yet.";
        }
        if (activeRequest)
            text += "\nUpdating weather…";
        if (error)
            text += "\n" + error + (sample ? "; keeping last good estimate." : "; using fallback.");
        return text;
    }
    function cancelRequest() {
        generation++;
        timeout.stop();
        var old = activeRequest;
        activeRequest = null;
        if (old)
            old.abort();
    }
    function restart() {
        if (!ready)
            return;
        cancelRequest();
        var key = place ? place.key : "";
        if (key !== sampleLocation) {
            sample = null;
            receivedAt = 0;
            sampleLocation = key;
            error = "";
        }
        now = Date.now();
        if (automatic && place)
            // Plasma applies config keys in a batch; fetch the final location.
            Qt.callLater(refresh);
    }
    function refresh() {
        if (!ready || !automatic || !place || activeRequest)
            return;
        var request = requestFactory(), token = ++generation;
        activeRequest = request;
        request.onreadystatechange = function () {
            if (token !== root.generation || request.readyState !== 4)
                return;
            timeout.stop();
            root.activeRequest = null;
            root.now = Date.now();
            try {
                if (request.status !== 200)
                    throw new Error("Weather unavailable (HTTP " + request.status + ")");
                if (request.responseText.length > 64000)
                    throw new Error("Oversized weather response");
                root.sample = Weather.parse(JSON.parse(request.responseText), root.now);
                root.receivedAt = root.now;
                root.error = "";
            } catch (problem) {
                root.error = String(problem.message || problem).slice(0, 180);
            }
        };
        try {
            request.open("GET", Weather.url(place));
            timeout.start();
            request.send();
        } catch (problem) {
            cancelRequest();
            error = "Weather request failed";
        }
    }
    onAutomaticChanged: restart()
    onPlaceChanged: restart()
    Component.onCompleted: {
        ready = true;
        restart();
    }
    Component.onDestruction: cancelRequest()
    Timer {
        id: timeout
        objectName: "weatherRequestTimeout"
        interval: 15000
        onTriggered: {
            root.cancelRequest();
            root.error = "Weather request timed out";
            root.now = Date.now();
        }
    }
    Timer {
        interval: 900000
        running: root.ready && root.automatic && root.place !== null
        repeat: true
        onTriggered: root.refresh()
    }
    Timer {
        interval: 60000
        running: root.ready && root.automatic && root.place !== null
        repeat: true
        onTriggered: root.now = Date.now()
    }
}

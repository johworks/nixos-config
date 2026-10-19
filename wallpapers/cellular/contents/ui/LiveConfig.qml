import QtQuick
import "controls.js" as Controls

QtObject {
    id: root
    property var configuration: null

    // KConfigPropertyMap mutation updates live values; the runtime boundary
    // explicitly saves. The settings form uses Controls directly until Apply.
    function initialize() {
        if (configuration && Controls.migrate(configuration))
            configuration.writeConfig();
    }
    function applyPreset(name) {
        if (!configuration)
            return;
        configuration.Automatic = false;
        Controls.writePreset(configuration, name);
        configuration.writeConfig();
    }
    function togglePause() {
        if (!configuration)
            return;
        configuration.Paused = !configuration.Paused;
        configuration.writeConfig();
    }
    onConfigurationChanged: initialize()
    Component.onCompleted: initialize()
}

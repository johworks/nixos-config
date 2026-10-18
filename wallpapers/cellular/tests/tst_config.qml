import QtQuick
import QtTest

Item {
    width: 720
    height: 540
    // Match the layout context supplied by Plasma's wallpaper configuration host.
    property var parentLayout: []
    Loader {
        id: settings
        anchors.fill: parent
        source: "../contents/ui/config.qml"
    }
    TestCase {
        name: "WeatherSettings"
        when: windowShown
        function test_manual_controls() {
            compare(settings.status, Loader.Ready);
            // Loader exposes QObject statically; aliases are checked on the actual loaded form.
            // qmllint disable missing-property
            settings.item.cfg_Weather = 2;
            settings.item.cfg_CellSize = 2;
            settings.item.cfg_Speed = 20;
            settings.item.cfg_Paused = true;
            compare(settings.item.cfg_Weather, 2);
            compare(settings.item.cfg_CellSize, 2);
            compare(settings.item.cfg_Speed, 20);
            compare(settings.item.cfg_Paused, true);
            // qmllint enable missing-property
        }
    }
}

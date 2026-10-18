import QtQuick
import QtTest

Item {
    id: host
    width: 720
    height: 540
    // Match the layout context supplied by Plasma's wallpaper configuration host.
    property var parentLayout: []
    property QtObject wallpaperConfiguration: firstConfiguration
    QtObject {
        id: dialog
    }
    QtObject {
        id: firstConfiguration
    }
    QtObject {
        id: replacementConfiguration
    }
    Loader {
        id: settings
        anchors.fill: parent
        Component.onCompleted: setSource("../contents/ui/config.qml", {
            configDialog: dialog,
            wallpaperConfiguration: Qt.binding(() => host.wallpaperConfiguration),
            cfg_ControlsVersion: 1,
            cfg_Brightness: 112,
            cfg_Warmth: 55
        })
    }
    TestCase {
        name: "WeatherSettings"
        when: windowShown
        function test_host_initial_properties() {
            compare(settings.status, Loader.Ready);
            // qmllint disable missing-property
            compare(settings.item.configDialog, dialog);
            compare(settings.item.wallpaperConfiguration, firstConfiguration);
            compare(settings.item.cfg_Brightness, 112);
            compare(settings.item.cfg_Warmth, 55);
            compare(settings.item.cfg_ControlsVersion, 1);
            host.wallpaperConfiguration = replacementConfiguration;
            compare(settings.item.wallpaperConfiguration, replacementConfiguration, "retain the host's binding when its live configuration changes");
            // qmllint enable missing-property
        }
        function test_legacy_form_migration() {
            // qmllint disable missing-property
            settings.item.cfg_ControlsVersion = 0;
            settings.item.cfg_Weather = 2;
            settings.item.initializeControls();
            compare(settings.item.cfg_RainIntensity, 100);
            compare(settings.item.cfg_ControlsVersion, 1);
            settings.item.cfg_Brightness = 124;
            settings.item.initializeControls();
            compare(settings.item.cfg_Brightness, 124, "reopening honors manual values");
            // qmllint enable missing-property
        }
        function test_manual_edit_after_defaults_reset() {
            // User interaction must mark the new format even after Reset Defaults
            // has restored the schema's legacy migration marker to zero.
            // qmllint disable missing-property
            settings.item.cfg_ControlsVersion = 0;
            settings.item.cfg_Brightness = 123;
            var spin = findChild(settings.item, "brightnessControl");
            spin.forceActiveFocus();
            keyClick(Qt.Key_Up);
            compare(settings.item.cfg_Brightness, 124);
            compare(settings.item.cfg_ControlsVersion, 1);
            settings.item.initializeControls();
            compare(settings.item.cfg_Brightness, 124);
            // qmllint enable missing-property
        }
        function test_manual_controls() {
            compare(settings.status, Loader.Ready);
            // Loader exposes QObject statically; aliases are checked on the actual loaded form.
            // qmllint disable missing-property
            settings.item.applyPreset("rainy");
            settings.item.cfg_Brightness = 118;
            settings.item.cfg_SunStrength = 70;
            settings.item.cfg_Wind = 0;
            settings.item.cfg_CellSize = 2;
            settings.item.cfg_Speed = 20;
            settings.item.cfg_Paused = true;
            compare(settings.item.cfg_Brightness, 118);
            compare(settings.item.cfg_SunStrength, 70);
            compare(settings.item.cfg_Wind, 0);
            compare(settings.item.cfg_RainIntensity, 100);
            compare(settings.item.cfg_CloudDarkness, 85);
            compare(settings.item.cfg_CellSize, 2);
            compare(settings.item.cfg_Speed, 20);
            compare(settings.item.cfg_Paused, true);
            // qmllint enable missing-property
        }
    }
}

import QtQuick
import QtTest
import "../contents/ui"

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
        property var values: ({
                Automatic: false,
                LocationLatitude: "42.35843",
                LocationLongitude: "-71.05977"
            })
        property int writes: 0
        function writeConfig() {
            writes++;
        }
    }
    QtObject {
        id: replacementConfiguration
    }
    AutomaticWeather {
        id: formController
    }
    QtObject {
        id: wallpaper
        property var automaticWeather: formController
    }
    Loader {
        id: settings
        anchors.fill: parent
        Component.onCompleted: setSource(Qt.resolvedUrl("../contents/ui/config.qml"), {
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
        function init() {
            settings.source = "";
            host.wallpaperConfiguration = firstConfiguration;
            settings.setSource(Qt.resolvedUrl("../contents/ui/config.qml"), {
                configDialog: dialog,
                wallpaperConfiguration: Qt.binding(() => host.wallpaperConfiguration),
                cfg_ControlsVersion: 1,
                cfg_Brightness: 112,
                cfg_Warmth: 55
            });
            tryCompare(settings, "status", Loader.Ready);
            wait(0);
        }
        function test_automatic_drafts_and_manual_presets() {
            // qmllint disable missing-property
            settings.item.cfg_Automatic = true;
            settings.item.cfg_LocationLabel = "Sydney";
            settings.item.cfg_LocationLatitude = "-33.86";
            settings.item.cfg_LocationLongitude = "151.2";
            compare(firstConfiguration.values.Automatic, false, "form drafts leave the native map behind Apply");
            compare(firstConfiguration.values.LocationLatitude, "42.35843");
            compare(firstConfiguration.writes, 0);
            compare(settings.item.cfg_Brightness, 112, "mode selection preserves saved manual values");
            var brightness = findChild(settings.item, "brightnessControl");
            compare(brightness.enabled, false);
            settings.item.applyPreset("rainy");
            compare(settings.item.cfg_Automatic, false);
            compare(brightness.enabled, true);
            compare(settings.item.cfg_RainIntensity, 100);
            compare(firstConfiguration.writes, 0);
            // Reopen without Apply: discarded drafts cannot persist.
            init();
            compare(settings.item.cfg_Automatic, false);
            compare(settings.item.cfg_LocationLabel, "Boston, Massachusetts, USA");
            compare(settings.item.cfg_LocationLatitude, "42.35843");
            // qmllint enable missing-property
        }
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
        function test_sky_drafts_modes_and_cancel() {
            // qmllint disable missing-property
            settings.item.cfg_ManualNight = true;
            settings.item.cfg_ManualMoonPhase = 75;
            settings.item.cfg_MoonX = 82;
            settings.item.cfg_MoonY = 15;
            settings.item.cfg_StarStrength = 90;
            settings.item.cfg_MoonStrength = 63;
            settings.item.cfg_Automatic = true;
            compare(findChild(settings.item, "manualNightControl").enabled, false);
            compare(findChild(settings.item, "manualMoonPhaseControl").enabled, false);
            compare(settings.item.cfg_Brightness, 112);
            settings.item.applyPreset("cloudy");
            compare(settings.item.cfg_Automatic, false);
            compare(settings.item.cfg_ManualMoonPhase, 75);
            compare(settings.item.cfg_MoonX, 82);
            compare(settings.item.cfg_MoonY, 15);
            compare(settings.item.cfg_StarStrength, 90);
            compare(settings.item.cfg_MoonStrength, 63);
            compare(findChild(settings.item, "manualMoonPhaseControl").enabled, true);
            compare(firstConfiguration.writes, 0, "sky edits remain drafts behind Apply");
            init();
            compare(settings.item.cfg_ManualNight, false, "Cancel/reopen discards unapplied sky draft");
            compare(settings.item.cfg_ManualMoonPhase, 25);
            compare(settings.item.cfg_MoonX, 77);
            compare(settings.item.cfg_StarStrength, 70);
            // qmllint enable missing-property
        }
        function test_runtime_status_binding() {
            // qmllint disable missing-property
            settings.item.runtimeWallpaper = wallpaper;
            compare(settings.item.liveWeather, formController);
            var status = findChild(settings.item, "automaticStatus");
            compare(status.text, formController.statusText);
            formController.latitude = "";
            formController.automatic = true;
            compare(status.text, formController.statusText, "live status updates without a config write");
            verify(status.text.indexOf("invalid latitude") >= 0);
            compare(firstConfiguration.writes, 0);
            formController.automatic = false;
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

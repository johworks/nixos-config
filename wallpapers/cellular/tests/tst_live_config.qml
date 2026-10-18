import QtQuick
import QtTest
import "../contents/ui"
import "../contents/ui/controls.js" as Controls

TestCase {
    name: "LiveConfiguration"
    Component {
        id: boundary
        LiveConfig {}
    }
    function attach(configuration) {
        var runtime = createTemporaryObject(boundary, this);
        runtime.configuration = configuration;
        verify(runtime.configuration === configuration, "retain the non-autosaving map identity");
        return runtime;
    }
    function storedMap() {
        // A deliberately non-autosaving map: destruction/reload loses live
        // mutation unless the actual wrapper boundary calls writeConfig().
        var stored = {
            Weather: 2,
            ControlsVersion: 0,
            CellSize: 3,
            Speed: 7,
            Paused: false
        };
        var saves = [];
        function load() {
            var config = JSON.parse(JSON.stringify(stored));
            config.writeConfig = function () {
                stored = JSON.parse(JSON.stringify(config));
                saves.push(JSON.parse(JSON.stringify(stored)));
            };
            return config;
        }
        return {
            load: load,
            saves: saves
        };
    }
    function test_migration_save_and_reload() {
        var storage = storedMap();
        var live = storage.load();
        var runtime = attach(live);
        compare(storage.saves.length, 1);
        compare(storage.saves[0].ControlsVersion, 1);
        for (var i = 0; i < Controls.keys.length; i++) {
            var key = Controls.keys[i];
            compare(storage.saves[0][key], Controls.preset("rainy")[key], "save sees the complete migration");
        }
        runtime.initialize();
        compare(storage.saves.length, 1, "completed migration does not save on evaluation/reinitialization");
        runtime.destroy();
        var reloaded = storage.load();
        attach(reloaded);
        compare(storage.saves.length, 1);
        compare(reloaded.RainIntensity, 100);
        compare(reloaded.ControlsVersion, 1);
    }
    function test_context_preset_and_pause_save_once() {
        var storage = storedMap();
        var live = storage.load();
        var runtime = attach(live);
        // Reproduce an existing map being reset, then a desktop context preset.
        live.ControlsVersion = 0;
        live.Weather = 0;
        var before = storage.saves.length;
        runtime.applyPreset("rainy");
        compare(storage.saves.length, before + 1);
        var saved = storage.saves[storage.saves.length - 1];
        compare(saved.RainIntensity, 100);
        compare(saved.Brightness, 65);
        compare(saved.ControlsVersion, 1);
        compare(saved.CellSize, 3);
        compare(saved.Speed, 7);
        runtime.togglePause();
        compare(storage.saves.length, before + 2);
        compare(storage.saves[storage.saves.length - 1].Paused, true);
        runtime.destroy();
        var reloaded = storage.load();
        attach(reloaded);
        compare(storage.saves.length, before + 2);
        compare(reloaded.RainIntensity, 100);
        compare(reloaded.Paused, true);
    }
    function test_form_edits_do_not_save_live_config() {
        var storage = storedMap();
        var form = storage.load();
        Controls.migrate(form);
        Controls.writePreset(form, "sunny");
        compare(storage.saves.length, 0, "pure form helpers leave persistence to Apply");
        compare(storage.load().ControlsVersion, 0, "unapplied edits do not change stored config");
    }
}

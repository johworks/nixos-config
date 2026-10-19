import QtQuick
import QtTest
import "../contents/ui"
import "../contents/ui/controls.js" as Controls
import "../weather-fixtures.js" as Fixtures

Item {
    id: host
    width: 1280
    height: 720
    Component {
        id: controllerComponent
        AutomaticWeather {}
    }
    Component {
        id: sceneComponent
        WeatherScene {
            width: 1280
            height: 720
            paused: true
        }
    }
    TestCase {
        name: "AutomaticWeather"
        when: windowShown
        function client() {
            var controller = createTemporaryObject(controllerComponent, host);
            var requests = [];
            controller.requestFactory = function () {
                var request = {
                    readyState: 0,
                    status: 0,
                    responseText: "",
                    aborted: false,
                    open: function (method, url) {
                        this.url = url;
                    },
                    send: function () {},
                    abort: function () {
                        this.aborted = true;
                    }
                };
                requests.push(request);
                return request;
            };
            return {
                controller: controller,
                requests: requests
            };
        }
        function finish(request, response, status) {
            request.status = status === undefined ? 200 : status;
            request.responseText = JSON.stringify(response);
            request.readyState = 4;
            request.onreadystatechange();
        }
        function test_disabled_invalid_and_stale_location_callbacks() {
            var c = client(), controller = c.controller;
            compare(c.requests.length, 0);
            controller.latitude = "";
            controller.automatic = true;
            compare(c.requests.length, 0);
            controller.latitude = "42.35843";
            wait(0);
            compare(c.requests.length, 1);
            var first = c.requests[0];
            controller.refresh();
            compare(c.requests.length, 1, "no overlapping refresh");
            controller.longitude = "151.2";
            wait(0);
            compare(first.aborted, true);
            compare(c.requests.length, 2);
            finish(first, Fixtures.response(Date.now(), {
                rain: 5
            }));
            compare(controller.sample, null, "previous location response must be ignored");
            finish(c.requests[1], Fixtures.response(Date.now(), {
                cloud_cover: 100,
                weather_code: 3
            }));
            compare(controller.sample.cloud, 100);
            controller.refresh();
            compare(c.requests.length, 3);
            controller.automatic = false;
            compare(c.requests[2].aborted, true);
            var saved = controller.sample;
            finish(c.requests[2], Fixtures.response(Date.now(), {
                rain: 5
            }));
            compare(controller.sample, saved, "disabled callback cannot change state");
            controller.refresh();
            compare(c.requests.length, 3);
            controller.automatic = true;
            wait(0);
            compare(c.requests.length, 4);
            var last = c.requests[3];
            controller.destroy();
            wait(0);
            compare(last.aborted, true, "unload aborts active work");
        }
        function test_apply_batch_fetches_only_final_valid_location() {
            var c = client(), controller = c.controller;
            controller.automatic = true;
            controller.latitude = "-33.86";
            controller.longitude = "151.2";
            compare(c.requests.length, 0);
            wait(0);
            compare(c.requests.length, 1, "coalesce native Apply's per-key updates");
            verify(c.requests[0].url.indexOf("latitude=-33.86&longitude=151.2") >= 0);
            controller.automatic = false;
            controller.automatic = true;
            controller.latitude = "invalid";
            wait(0);
            compare(c.requests.length, 1, "invalid final location cannot make a queued request");
        }
        function test_last_good_error_and_real_clock() {
            var c = client(), controller = c.controller;
            controller.automatic = true;
            wait(0);
            finish(c.requests[0], Fixtures.response(Date.now(), {
                rain: 0.5,
                weather_code: 63
            }));
            var saved = controller.sample;
            controller.refresh();
            finish(c.requests[1], {}, 503);
            compare(controller.sample, saved);
            verify(controller.error.length > 0);
            controller.now = saved.time + 3600000;
            verify(controller.statusText.indexOf("stale") >= 0);
            verify(controller.statusText.indexOf("keeping last good") >= 0);
            var night = Date.parse("2026-10-19T02:00:00Z");
            controller.now = night;
            compare(controller.output.phase, "Night");
            compare(controller.output.controls.SunStrength, 0);
            controller.now = Date.parse("2026-10-19T16:45:00Z");
            compare(controller.output.phase, "Day");
            compare(c.requests.length, 2, "solar clock changes do not fetch weather");
            controller.refresh();
            finish(c.requests[2], Fixtures.response(Date.now(), {
                cloud_cover: null
            }));
            compare(controller.sample, saved);
            controller.refresh();
            var malformed = c.requests[3];
            malformed.responseText = "{broken json";
            malformed.status = 200;
            malformed.readyState = 4;
            malformed.onreadystatechange();
            compare(controller.sample, saved);
            verify(controller.error.length > 0);
            controller.latitude = "-33.86";
            compare(controller.sample, null, "last good is scoped to the location");
            verify(controller.statusText.indexOf("Fallback") >= 0);
        }
        function test_timeout_does_not_spin_or_accept_late_result() {
            var c = client(), controller = c.controller;
            // Shorten the real production timer for this test only.
            var timeout = findChild(controller, "weatherRequestTimeout");
            verify(timeout !== null);
            timeout.interval = 30;
            controller.automatic = true;
            tryVerify(function () {
                return controller.error.indexOf("timed out") >= 0;
            });
            compare(c.requests[0].aborted, true);
            compare(controller.activeRequest, null);
            finish(c.requests[0], Fixtures.response(Date.now(), {
                rain: 1
            }));
            compare(controller.sample, null);
            wait(100);
            compare(c.requests.length, 1, "error waits for scheduled refresh, without rapid retries");
        }
        function test_scene_clock_and_saved_manual_state() {
            var c = client(), controller = c.controller;
            var manual = Controls.preset("sunny");
            manual.Brightness = 123;
            manual.Warmth = 77;
            manual.Wind = 0;
            var saved = JSON.stringify(manual);
            var scene = createTemporaryObject(sceneComponent, host);
            scene.controls = Qt.binding(function () {
                return controller.automatic && controller.output ? controller.output.controls : manual;
            });
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
            var baseline = grabImage(scene);
            controller.automatic = true;
            wait(0);
            finish(c.requests[0], Fixtures.response(Date.now(), {
                rain: 0.5,
                cloud_cover: 100,
                weather_code: 63,
                wind_speed_10m: 0
            }));
            controller.now = Date.parse("2026-10-19T02:00:00Z");
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
            verify(!baseline.equals(grabImage(scene)));
            verify(scene.rainState.drops.length > 0);
            var grades = scene.gradePaintCount;
            for (var tick = 0; tick < 20; tick++)
                scene.advanceAnimation(0.05);
            wait(100);
            compare(scene.gradePaintCount, grades, "particle frames never regrade auto lighting");
            compare(c.requests.length, 1);
            compare(JSON.stringify(manual), saved, "automatic output cannot overwrite manual knobs");
            controller.automatic = false;
            tryCompare(scene, "assetsReady", true, 10000);
            wait(100);
            verify(baseline.equals(grabImage(scene)), "switching back restores exact manual rendering");
        }
    }
}

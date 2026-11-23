from datetime import datetime, time
import json
import logging
from pathlib import Path
import subprocess
import sys

import gi

gi.require_version("Gdk", "3.0")
gi.require_version("Gtk", "3.0")
from gi.repository import Gdk, GLib, Gtk

NEUTRAL = 6500
WARMEST = 2500
DAY_MINUTES = 24 * 60


def minute_of_day(clock):
    return clock.hour * 60 + clock.minute + clock.second / 60


def scheduled_temperature(schedule, now):
    start = minute_of_day(time.fromisoformat(schedule["start"]))
    end = minute_of_day(time.fromisoformat(schedule["end"]))
    duration = (end - start) % DAY_MINUTES
    elapsed = (minute_of_day(now) - start) % DAY_MINUTES
    if elapsed >= duration:
        return NEUTRAL

    fade = min(schedule["fadeMinutes"], duration / 2)
    fraction = min(1, elapsed / fade, (duration - elapsed) / fade) if fade else 1
    return round(NEUTRAL - fraction * (NEUTRAL - schedule["temperature"]))


class NightLight(Gtk.Application):
    def __init__(self, app_id, schedule, hyprctl):
        super().__init__(application_id=app_id)
        self.schedule = schedule
        self.hyprctl = hyprctl
        self.manual = None if schedule["enable"] else NEUTRAL
        self.window = None
        self.adjustment = None
        self.error = None
        self.slider_update = 0

    def do_startup(self):
        Gtk.Application.do_startup(self)
        # Keep the schedule running after the control window closes.
        self.hold()
        self.refresh()
        GLib.timeout_add_seconds(10, self.refresh)

    def do_activate(self):
        if self.window is None:
            self.build_window()
        self.refresh()
        self.window.present()

    def build_window(self):
        window = Gtk.ApplicationWindow(application=self, title="Night light")
        window.set_default_size(340, -1)
        window.set_resizable(False)
        header = Gtk.HeaderBar(title="Night light", show_close_button=True)
        window.set_titlebar(header)
        window.connect("destroy", self.window_closed)
        window.connect("key-press-event", self.key_pressed)
        self.window = window

        panel = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12, margin=16)
        window.add(panel)
        self.status = Gtk.Label(xalign=0)
        panel.pack_start(self.status, False, False, 0)

        slider = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        slider.set_draw_value(False)
        slider.get_accessible().set_name("Display warmth")
        self.adjustment = slider.get_adjustment()
        self.slider_handler = self.adjustment.connect("value-changed", self.slide)
        panel.pack_start(slider, False, False, 0)

        endpoints = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL)
        endpoints.pack_start(Gtk.Label(label="Neutral"), False, False, 0)
        endpoints.pack_end(Gtk.Label(label="Warmest"), False, False, 0)
        panel.pack_start(endpoints, False, False, 0)

        actions = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        self.off = Gtk.Button(label="Turn off")
        self.off.connect("clicked", lambda _: self.set_override(NEUTRAL))
        actions.pack_start(self.off, False, False, 0)
        if self.schedule["enable"]:
            self.follow = Gtk.Button(label="Follow schedule")
            self.follow.connect("clicked", lambda _: self.set_override(None))
            actions.pack_end(self.follow, False, False, 0)
        panel.pack_start(actions, False, False, 0)

        if self.schedule["enable"]:
            hours = f'{self.schedule["start"]}–{self.schedule["end"]}'
            summary = Gtk.Label(label=f"Scheduled hours · {hours}", xalign=0)
            panel.pack_start(summary, False, False, 0)
        window.show_all()

    def window_closed(self, _window):
        self.window = None
        self.adjustment = None

    def key_pressed(self, window, event):
        if event.keyval == Gdk.KEY_Escape:
            window.close()
            return True
        return False

    def slide(self, adjustment):
        self.manual = round(NEUTRAL - adjustment.get_value() * (NEUTRAL - WARMEST) / 100)
        if not self.slider_update:
            self.slider_update = GLib.timeout_add(80, self.apply_slider)

    def apply_slider(self):
        self.slider_update = 0
        self.refresh()
        return GLib.SOURCE_REMOVE

    def set_override(self, temperature):
        self.manual = temperature
        self.refresh()

    def sunset(self, *args):
        command = [self.hyprctl, "hyprsunset", *args]
        result = subprocess.run(command, capture_output=True, text=True, timeout=0.5)
        if result.returncode:
            raise RuntimeError(result.stderr.strip() or result.stdout.strip() or "hyprctl failed")
        return result.stdout.strip()

    def apply_temperature(self, temperature):
        # Query identity separately: hyprsunset remembers its previous temperature when off.
        identity = self.sunset("identity", "get")
        if identity not in ("true", "false"):
            raise RuntimeError(f"Unexpected hyprsunset reply: {identity}")
        if temperature == NEUTRAL:
            result = "ok" if identity == "true" else self.sunset("identity")
        elif identity == "false" and self.sunset("temperature") == str(temperature):
            result = "ok"
        else:
            result = self.sunset("temperature", str(temperature))
        if result != "ok":
            raise RuntimeError(f"Unexpected hyprsunset reply: {result}")

    def refresh(self):
        temperature = self.manual
        if temperature is None:
            temperature = scheduled_temperature(self.schedule, datetime.now().time())

        try:
            self.apply_temperature(temperature)
            self.error = None
        except (OSError, RuntimeError, subprocess.SubprocessError) as error:
            if str(error) != self.error:
                logging.warning("Could not apply night light: %s", error)
            self.error = str(error)

        if self.window is not None:
            mode = "Schedule" if self.manual is None else "Manual"
            warmth = "Off" if temperature == NEUTRAL else f"{temperature} K"
            self.status.set_text("Night light unavailable" if self.error else f"{mode} · {warmth}")
            self.off.set_sensitive(self.manual != NEUTRAL)
            if self.schedule["enable"]:
                self.follow.set_sensitive(self.manual is not None)
            with self.adjustment.handler_block(self.slider_handler):
                self.adjustment.set_value(100 * (NEUTRAL - temperature) / (NEUTRAL - WARMEST))

        return GLib.SOURCE_CONTINUE


if __name__ == "__main__":
    app_id, config_path, hyprctl = sys.argv[1:4]
    GLib.set_prgname(app_id)
    schedule = json.loads(Path(config_path).read_text())
    sys.exit(NightLight(app_id, schedule, hyprctl).run([app_id, *sys.argv[4:]]))

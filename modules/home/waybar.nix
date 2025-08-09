{ config, pkgs, lib, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    style = ''
      /* === Palette === */
      @define-color bg        #0b0f14;   /* near-black blue */
      @define-color bg-alt    #111827;   /* slightly lighter */
      @define-color fg        #e5e7eb;   /* soft white */
      @define-color muted     #9ca3af;   /* gray */
      @define-color purple    #7c3aed;   /* accent */
      @define-color blue      #2563eb;   /* accent */
      @define-color orange    #ff8c42;   /* dark orange accent */
      @define-color red       #ef4444;   /* alert */

      /* === Base === */
      * {
        font-family: Noto Sans, "JetBrainsMono Nerd Font", sans-serif;
        font-size: 12px;
        min-height: 0;
      }

      window#waybar {
        background: alpha(@bg, 0.70);
        border-bottom: 1px solid alpha(@purple, 0.25);
        color: @fg;
      }

      tooltip {
        background: @bg-alt;
        color: @fg;
        border: 1px solid alpha(@purple, 0.35);
      }

      /* === Module shell === */
      #workspaces button,
      #mode,
      #window,
      #network, #pulseaudio, #cpu, #memory, #temperature, #battery, #clock, #tray {
        padding: 4px 8px;
        margin: 4px 4px;
        border-radius: 8px;
        background: alpha(@bg-alt, 0.8);
      }

      /* Subtle separators via left border */
      #network, #pulseaudio, #cpu, #memory, #temperature, #battery, #clock, #tray {
        border-left: 1px solid alpha(@purple, 0.15);
      }

      /* === Workspaces === */
      #workspaces {
        padding-left: 4px;
      }
      #workspaces button {
        color: @muted;
        background: transparent;
        border: 1px solid transparent;
      }
      #workspaces button:hover {
        color: @fg;
        background: alpha(@purple, 0.12);
      }
      #workspaces button.active {
        color: @fg;
        background: alpha(@purple, 0.22);
        border-color: alpha(@purple, 0.35);
      }
      #workspaces button.urgent {
        color: @fg;
        background: alpha(@red, 0.22);
        border-color: alpha(@red, 0.5);
      }

      /* === Mode / Window title === */
      #mode {
        font-style: italic;
        color: @orange;
        border: 1px solid alpha(@orange, 0.35);
        background: alpha(@orange, 0.10);
      }
      #window {
        color: @fg;
      }

      /* === Status accents === */
      #network { border-color: alpha(@blue, 0.35); }
      #pulseaudio { border-color: alpha(@purple, 0.35); } /* base for both instances */
      #cpu { border-color: alpha(@blue, 0.25); }
      #memory { border-color: alpha(@purple, 0.25); }
      #temperature { border-color: alpha(@orange, 0.35); }
      #battery { border-color: alpha(@blue, 0.25); }
      #clock { border-color: alpha(@purple, 0.35); }

      /* PulseAudio states */
      #pulseaudio.muted {
        color: @muted;
        background: alpha(@bg-alt, 0.6);
        border-color: alpha(@purple, 0.15);
      }

      /* Distinguish sink vs source (instance names become classes) */
      #pulseaudio.sink   { /* speakers/headphones */ }
      #pulseaudio.source { /* microphone */ }

      /* Network states */
      #network.disconnected {
        color: @red;
        border-color: alpha(@red, 0.5);
        background: alpha(@red, 0.10);
      }

      /* Temperature states */
      #temperature.critical {
        color: @red;
        border-color: alpha(@red, 0.6);
        background: alpha(@red, 0.10);
      }

      /* Battery states */
      #battery.warning:not(.charging) {
        color: @orange;
        border-color: alpha(@orange, 0.6);
        background: alpha(@orange, 0.10);
      }
      #battery.critical:not(.charging) {
        color: @red;
        border-color: alpha(@red, 0.6);
        background: alpha(@red, 0.10);
      }
      #battery.charging {
        color: @fg;
        border-color: alpha(@blue, 0.45);
        background: linear-gradient(90deg, alpha(@blue, 0.18), transparent);
      }

      /* Tray tweaks */
      #tray > .passive { opacity: 0.7; }
      #tray > .active { opacity: 1.0; }
      #tray > .needs-attention {
        background: alpha(@red, 0.18);
        border-color: alpha(@red, 0.6);
      }
    '';

    settings = [{
      height = 30;
      layer = "top";
      position = "top";
      tray = { spacing = 10; };

      modules-center = [ "hyprland/window" ];
      modules-left   = [ "hyprland/workspaces" "hyprland/mode" ];
      modules-right  = [
        "pulseaudio#sink"      # speakers/headphones
        "network"
        "cpu"
        "memory"
        "temperature"
        "battery"
        "clock"
        "tray"
      ];

      battery = {
        format = "{capacity}% {icon}";
        format-alt = "{time} {icon}";
        format-charging = "{capacity}% ";
        format-icons = [ "" "" "" "" "" ];
        format-plugged = "{capacity}% ";
        states = { critical = 15; warning = 30; };
      };

      clock = {
        format = "{:%H:%M}";
        format-alt = "{:%Y-%m-%d}";
        tooltip-format = "{:%Y-%m-%d | %H:%M}";
      };

      cpu = { format = "{usage}% "; tooltip = false; };
      memory = { format = "{}% "; };

      network = {
        interval = 1;
        format-wifi = "{essid} ({signalStrength}%) ";
        format-ethernet = "{ifname}: {ipaddr}/{cidr}   up: {bandwidthUpBits} down: {bandwidthDownBits}";
        format-linked = "{ifname} (No IP) ";
        format-disconnected = "Disconnected ⚠";
        format-alt = "{ifname}: {ipaddr}/{cidr}";
      };


      /* === Audio: sink (output) only === */
      "pulseaudio#sink" = {
        format = "{volume}% {icon}";
        format-bluetooth = "{volume}% {icon}";
        format-bluetooth-muted = " {icon}";
        format-muted = "";
        format-icons = {
          default = [ "" "" "" ];
          headphones = "";
          headset = "";
          handsfree = "";
          phone = "";
          car = "";
          portable = "";
        };
        on-click = "pavucontrol";
      };


      "hyprland/mode" = { format = ''<span style="italic">{}</span>''; };

      temperature = {
        critical-threshold = 80;
        format = "{temperatureC}°C {icon}";
        format-icons = [ "" "" "" ];
      };
    }];
  };
}


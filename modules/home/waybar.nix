{ lib, config, ... }:
let
  cfg = config.desktop.waybar;
  colors = config.theme.colors;
  fonts = config.theme.fonts;
  hyprEnabled = config.desktop.hyprland.enable or false;
in
{
  options.desktop.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkMerge [
    {
      desktop.waybar.enable = lib.mkDefault hyprEnabled;
    }

    (lib.mkIf cfg.enable {
      programs.waybar = {
        enable = true;
        systemd.enable = true;

        settings = [{
          layer = "top";
          position = "top";
          height = 28;
          tray = { spacing = 8; };

          modules-left = [ "hyprland/workspaces" ];
          modules-center = [ "clock" ];
          modules-right = [ "network" "cpu" "memory" "battery" "tray" ];

          "hyprland/workspaces" = {
            disable-scroll = true;
            all-outputs = true;
          };

          clock = {
            format = "{:%a %H:%M}";
            format-alt = "{:%Y-%m-%d}";
            tooltip-format = "{:%A, %B %d %Y | %H:%M}";
          };

          cpu = {
            format = "{usage}% ";
            tooltip = false;
          };

          memory = {
            format = "{percentage}% ";
            interval = 5;
            tooltip-format = "{used} / {total}";
          };

          network = {
            format-wifi = "{essid} {signalStrength}% ";
            format-ethernet = "{ifname} {ipaddr}";
            format-disconnected = "Offline";
            tooltip-format = "{ifname} {ipaddr}";
            interval = 3;
          };

          battery = {
            format = "{capacity}% {icon}";
            format-charging = "{capacity}% ";
            format-plugged = "{capacity}% ";
            format-icons = [ "" "" "" "" "" ];
            states = {
              warning = 30;
              critical = 15;
            };
          };
        }];

        style = ''
          * {
            font-family: "Symbols Nerd Font Mono", "${fonts.monospace}", "${fonts.sansSerif}", sans-serif;
            font-size: ${builtins.toString fonts.size}px;
            color: ${colors.foreground};
            min-height: 0;
          }

          window#waybar {
            background: ${colors.surface};
            border-bottom: 1px solid ${colors.surfaceAlt};
          }

          tooltip {
            background: ${colors.surface};
            color: ${colors.foreground};
            border: 1px solid ${colors.accent};
          }

          #workspaces button,
          #clock,
          #network,
          #cpu,
          #memory,
          #battery,
          #tray {
            background: ${colors.surface};
            padding: 4px 10px;
            margin: 4px 6px;
            border-radius: 8px;
          }

          #workspaces button {
            border: 1px solid transparent;
            color: ${colors.muted};
          }

          #workspaces button.focused,
          #workspaces button.active {
            color: ${colors.background};
            background: ${colors.accent};
            border-color: ${colors.accent};
          }

          #clock {
            background: ${colors.accent};
            color: ${colors.background};
          }

          #battery.warning {
            color: ${colors.accent};
          }

          #battery.critical {
            color: ${colors.alert};
          }

          #network.disconnected {
            color: ${colors.alert};
          }
        '';
      };
    })
  ];
}

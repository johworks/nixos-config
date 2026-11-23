{
  lib,
  config,
  pkgs,
  osConfig ? { },
  ...
}:
let
  cfg = config.desktop.waybar;
  colors = config.theme.colors;
  fonts = config.theme.fonts;
  hyprEnabled = config.desktop.hyprland.enable or false;
  nightLight = cfg.nightLight;
  nightLightEnabled = cfg.enable && hyprEnabled && nightLight.enable;
  nightLightId = "org.nixos.WaybarNightLight";
  nightLightUnit = "waybar-night-light";
  hyprland = osConfig.programs.hyprland.package or pkgs.hyprland;
  python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
  nightLightConfig = pkgs.writeText "night-light.json" (builtins.toJSON nightLight.schedule);
  nightLightProgram = pkgs.stdenvNoCC.mkDerivation {
    pname = "waybar-night-light";
    version = "1";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.gobject-introspection
      pkgs.wrapGAppsHook3
    ];
    buildInputs = [ pkgs.gtk3 ];
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      cat > "$out/bin/waybar-night-light" <<'EOF'
      #! ${pkgs.runtimeShell}
      exec ${python}/bin/python3 ${./waybar-night-light.py} \
        ${nightLightId} ${nightLightConfig} ${lib.getExe' hyprland "hyprctl"} "$@"
      EOF
      chmod +x "$out/bin/waybar-night-light"
      runHook postInstall
    '';
  };
  openNightLight = pkgs.writeShellScript "open-night-light" ''
    ${lib.getExe' pkgs.systemd "systemctl"} --user start ${nightLightUnit}.service &&
      exec ${lib.getExe' pkgs.glib "gdbus"} call --session --dest ${nightLightId} \
        --object-path /org/nixos/WaybarNightLight \
        --method org.freedesktop.Application.Activate '{}'
  '';
  clockTime = lib.types.strMatching "([01][0-9]|2[0-3]):[0-5][0-9]";
in
{
  options.desktop.waybar = {
    enable = lib.mkEnableOption "Waybar status bar";
    nightLight = {
      enable = lib.mkEnableOption "the Hyprland night-light control" // {
        default = true;
      };
      schedule = {
        enable = lib.mkEnableOption "automatic night-light scheduling" // {
          default = true;
        };
        start = lib.mkOption {
          type = clockTime;
          default = "21:00";
          description = "Local time when the display begins warming.";
        };
        end = lib.mkOption {
          type = clockTime;
          default = "07:00";
          description = "Local time when the display has returned to neutral.";
        };
        fadeMinutes = lib.mkOption {
          type = lib.types.ints.unsigned;
          default = 30;
          description = "Minutes to fade in and out, capped at half the scheduled period. Set to zero for an immediate change.";
        };
        temperature = lib.mkOption {
          type = lib.types.ints.between 2500 6400;
          default = 4200;
          description = "Scheduled color temperature in kelvin. Lower values are warmer.";
        };
      };
    };
  };

  config = lib.mkMerge [
    {
      desktop.waybar.enable = lib.mkDefault hyprEnabled;
    }

    (lib.mkIf nightLightEnabled {
      assertions = [
        {
          assertion = !nightLight.schedule.enable || nightLight.schedule.start != nightLight.schedule.end;
          message = "Waybar night-light schedule must have different start and end times.";
        }
      ];

      wayland.windowManager.hyprland.settings.windowrule = [
        "match:class ^org[.]nixos[.]WaybarNightLight$, float on, move (monitor_w-window_w-16) 48"
      ];

      systemd.user.services.hyprsunset = {
        Unit = {
          Description = "Hyprland display color temperature";
          PartOf = [ "hyprland-session.target" ];
          After = [ "graphical-session-pre.target" ];
        };
        Service = {
          # The Waybar controller owns scheduling and manual overrides.
          Environment = "XDG_CONFIG_HOME=${pkgs.writeTextDir "hypr/hyprsunset.conf" ""}";
          ExecStart = "${lib.getExe pkgs.hyprsunset} --identity";
          Restart = "on-failure";
          RestartSec = "2s";
        };
      };

      systemd.user.services.${nightLightUnit} = {
        Unit = {
          Description = "Waybar night-light schedule and controls";
          PartOf = [ "hyprland-session.target" ];
          Wants = [ "hyprsunset.service" ];
          After = [ "hyprsunset.service" ];
        };
        Service = {
          Type = "dbus";
          BusName = nightLightId;
          ExecStart = "${nightLightProgram}/bin/waybar-night-light --gapplication-service";
          Restart = "on-failure";
        };
        Install.WantedBy = [ "hyprland-session.target" ];
      };
    })

    (lib.mkIf cfg.enable {
      programs.waybar = {
        enable = true;
        systemd.enable = true;

        settings = [
          {
            layer = "top";
            position = "top";
            height = 28;
            tray = {
              spacing = 8;
            };

            modules-left = [ "hyprland/workspaces" ];
            modules-center = [ "clock" ];
            modules-right = lib.optional nightLightEnabled "custom/night-light" ++ [
              "network"
              "cpu"
              "memory"
              "battery"
              "tray"
            ];

            "hyprland/workspaces" = {
              disable-scroll = true;
              all-outputs = true;
            };

            "custom/night-light" = lib.mkIf nightLightEnabled {
              format = "󰖔";
              tooltip-format = "Night light";
              on-click = "${openNightLight}";
            };

            clock = {
              format = "{:%a %I:%M %p}";
              format-alt = "{:%Y-%m-%d}";
              tooltip-format = "{:%A, %B %d %Y | %I:%M %p}";
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
              format-icons = [
                ""
                ""
                ""
                ""
                ""
              ];
              states = {
                warning = 30;
                critical = 15;
              };
            };
          }
        ];

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
          #custom-night-light,
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

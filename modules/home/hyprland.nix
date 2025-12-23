{ lib, config, pkgs, ... }:
let
  cfg = config.desktop.hyprland;
  colors = config.theme.colors;
  fonts = config.theme.fonts;
  inherit (builtins) toString;
  inherit (lib)
    mkOption
    types;

  hyprHex = color:
    if lib.hasPrefix "#" color then
      let
        body = lib.substring 1 ((lib.stringLength color) - 1) color;
      in
      "0xff${body}"
    else
      color;
in
{
  options.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland window manager";

    wallpaper = mkOption {
      type = with types; nullOr str;
      default = null;
      description = "Wallpaper path for swww; null disables wallpaper management.";
    };

    terminal = mkOption {
      type = types.str;
      default = "kitty";
      description = "Command launched by $terminal in Hyprland bindings.";
    };

    fileManager = mkOption {
      type = types.str;
      default = "nautilus";
      description = "Command launched by $fileManager in Hyprland bindings.";
    };

    menu = mkOption {
      type = types.str;
      default = "wofi --show drun --allow-images";
      description = "Command launched by $menu in Hyprland bindings.";
    };

    extraEnv = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Extra environment entries appended to the Hyprland env list.";
    };

    extraExecOnce = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional exec-once commands.";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      description = "Extra packages installed with the Hyprland profile.";
    };
  };

  config = lib.mkMerge [
    {
      desktop.hyprland.wallpaper = lib.mkDefault "${config.home.homeDirectory}/Pictures/Wallpapers/sunset-field.jpg";
    }

    (lib.mkIf cfg.enable {
      home.packages = with pkgs; [
        nautilus
        libnotify
        networkmanagerapplet
        brightnessctl
        swww
      ] ++ cfg.extraPackages;

      services.dunst = {
        enable = true;
        settings = {
          global = {
            frame_color = colors.accent;
            highlight = colors.accent;
            separator_height = 2;
            corner_radius = 6;
            font = "Noto Sans 11";
          };
          urgency_low = {
            background = colors.surface;
            foreground = colors.foreground;
          };
          urgency_normal = {
            background = colors.surfaceAlt;
            foreground = colors.foreground;
          };
          urgency_critical = {
            background = colors.surfaceAlt;
            foreground = colors.foreground;
            frame_color = colors.alert;
          };
        };
      };

      programs.kitty = {
        enable = true;
        font = {
          name = fonts.monospace;
          size = 12;
        };
        settings = {
          background = colors.background;
          foreground = colors.foreground;
          selection_background = colors.surfaceAlt;
          selection_foreground = colors.foreground;
          cursor = colors.accent;
          active_tab_background = colors.accent;
          active_tab_foreground = colors.background;
          inactive_tab_background = colors.surface;
          inactive_tab_foreground = colors.muted;
          color0 = colors.background;
          color8 = colors.surfaceAlt;
        };
      };

      programs.wofi = {
        enable = true;
        settings = {
          width = 420;
          height = 320;
          show = "drun";
          allow_images = true;
          prompt = "";
          hide_scroll = true;
          layer = "top";
        };
        style = ''
          * {
            font-family: ${fonts.sansSerif};
            font-size: ${toString fonts.size}px;
            color: ${colors.foreground};
          }

          window {
            background-color: ${colors.surface};
            border: 2px solid ${colors.accent};
            border-radius: 8px;
          }

          #input {
            background-color: ${colors.background};
            color: ${colors.foreground};
            border: none;
            padding: 10px;
          }

          #inner-box {
            padding: 4px;
          }

          #entry {
            padding: 6px;
            border-radius: 4px;
          }

          #entry:selected {
            background-color: ${colors.accent};
            color: ${colors.background};
          }
        '';
      };

      wayland.windowManager.hyprland = {
        enable = true;
        package = null;
        portalPackage = null;

        settings = {
          monitor = [ ",preferred,auto,auto" ];

          "$terminal" = cfg.terminal;
          "$fileManager" = cfg.fileManager;
          "$menu" = cfg.menu;

          env = [
            "XCURSOR_THEME,Bibata-Modern-Ice"
            "XCURSOR_SIZE,24"
            "HYPRCURSOR_THEME,Bibata-Modern-Ice"
            "HYPRCURSOR_SIZE,24"
          ] ++ cfg.extraEnv;

          general = {
            gaps_in = 2;
            gaps_out = 10;
            border_size = 2;
            "col.active_border" = hyprHex colors.accent;
            "col.inactive_border" = hyprHex colors.muted;
            resize_on_border = false;
            allow_tearing = false;
            layout = "dwindle";
          };

          decoration = {
            rounding = 5;
            rounding_power = 2;
            active_opacity = 1.0;
            inactive_opacity = 1.0;

            shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
              color = hyprHex colors.surfaceAlt;
            };

            blur = {
              enabled = true;
              size = 3;
              passes = 1;
              vibrancy = 0.17;
            };
          };

          animations = {
            enabled = true;
            bezier = [
              "easeOutQuint,0.23,1,0.32,1"
              "easeInOutCubic,0.65,0.05,0.36,1"
              "linear,0,0,1,1"
              "almostLinear,0.5,0.5,0.75,1.0"
              "quick,0.15,0,0.1,1"
            ];
            animation = [
              "global, 1, 10, default"
              "border, 1, 5.39, easeOutQuint"
              "windows, 1, 4.79, easeOutQuint"
              "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
              "windowsOut, 1, 1.49, linear, popin 87%"
              "fadeIn, 1, 1.73, almostLinear"
              "fadeOut, 1, 1.46, almostLinear"
              "fade, 1, 3.03, quick"
              "layers, 1, 3.81, easeOutQuint"
              "layersIn, 1, 4, easeOutQuint, fade"
              "layersOut, 1, 1.5, linear, fade"
              "fadeLayersIn, 1, 1.79, almostLinear"
              "fadeLayersOut, 1, 1.39, almostLinear"
              "workspaces, 1, 1.94, almostLinear, fade"
              "workspacesIn, 1, 1.21, almostLinear, fade"
              "workspacesOut, 1, 1.94, almostLinear, fade"
            ];
          };

          dwindle = {
            pseudotile = true;
            preserve_split = true;
          };

          master = {
            new_status = "master";
          };

          misc = {
            force_default_wallpaper = 1;
            disable_hyprland_logo = true;
          };

          input = {
            kb_layout = "us";
            kb_variant = "";
            kb_model = "";
            kb_options = "";
            kb_rules = "";

            follow_mouse = 1;
            sensitivity = 0;

            touchpad = {
              natural_scroll = true;
            };
          };

          gestures.workspace_swipe = false;

          device = {
            name = "epic-mouse-v1";
            sensitivity = -0.5;
          };

          "$mainMod" = "SUPER";

          bind = [
            "SUPER, Q, exec, $terminal"
            "SUPER, C, killactive"
            "SUPER, M, exit"
            "SUPER, E, exec, $fileManager"
            "SUPER, V, togglefloating"
            "SUPER, R, exec, $menu"
            "SUPER, P, pseudo, # dwindle"
            "SUPER, J, togglesplit, # dwindle"
            "SUPER, left, movefocus, l"
            "SUPER, right, movefocus, r"
            "SUPER, up, movefocus, u"
            "SUPER, down, movefocus, d"
            "SUPER, 1, workspace, 1"
            "SUPER, 2, workspace, 2"
            "SUPER, 3, workspace, 3"
            "SUPER, 4, workspace, 4"
            "SUPER, 5, workspace, 5"
            "SUPER, 6, workspace, 6"
            "SUPER, 7, workspace, 7"
            "SUPER, 8, workspace, 8"
            "SUPER, 9, workspace, 9"
            "SUPER, 0, workspace, 10"
            "SUPER+SHIFT, 1, movetoworkspace, 1"
            "SUPER+SHIFT, 2, movetoworkspace, 2"
            "SUPER+SHIFT, 3, movetoworkspace, 3"
            "SUPER+SHIFT, 4, movetoworkspace, 4"
            "SUPER+SHIFT, 5, movetoworkspace, 5"
            "SUPER+SHIFT, 6, movetoworkspace, 6"
            "SUPER+SHIFT, 7, movetoworkspace, 7"
            "SUPER+SHIFT, 8, movetoworkspace, 8"
            "SUPER+SHIFT, 9, movetoworkspace, 9"
            "SUPER+SHIFT, 0, movetoworkspace, 10"
            "SUPER, S, togglespecialworkspace, magic"
            "SUPER+SHIFT, S, movetoworkspace, special:magic"
            "SUPER, mouse_down, workspace, e+1"
            "SUPER, mouse_up, workspace, e-1"
          ];

          bindm = [
            "$mainMod, mouse:272, movewindow"
            "$mainMod, mouse:273, resizewindow"
          ];

          bindel = [
            ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
            ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
            ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
            ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
          ];

          bindl = [
            ",XF86AudioNext, exec, playerctl next"
            ",XF86AudioPause, exec, playerctl play-pause"
            ",XF86AudioPlay, exec, playerctl play-pause"
            ",XF86AudioPrev, exec, playerctl previous"
          ];

          windowrule = [
            "suppressevent maximize, class:.*"
            "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0"
          ];

          exec-once =
            [ "${pkgs.networkmanagerapplet}/bin/nm-applet --indicator" ]
            ++ lib.optional (cfg.wallpaper != null)
              ''${pkgs.swww}/bin/swww-daemon && ${pkgs.swww}/bin/swww img ${lib.escapeShellArg cfg.wallpaper}''
            ++ cfg.extraExecOnce;
        };
      };
    })
  ];
}

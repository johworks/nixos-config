{ config, pkgs, ... }: {

  #imports = [ ./waybar/waybar.nix ];
  imports = [ ./waybar.nix ];

  # This manages the ~/.config/hypr/hyprland.config file
  wayland.windowManager.hyprland = {
    
    # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
    package = null;
    portalPackage = null;

    enable = true;
    settings = {
      ################
      ### MONITORS ###
      ################

      # See https://wiki.hyprland.org/Configuring/Monitors/
      monitor = [ ",preferred,auto,auto" ];
      ###################
      ### MY PROGRAMS ###
      ###################

      # See https://wiki.hyprland.org/Configuring/Keywords/
      "$terminal" = "kitty";
      "$fileManager" = "nautilus";
      "$menu" = "wofi --show drun --allow-images";

      #############################
      ### ENVIRONMENT VARIABLES ###
      #############################

      # See https://wiki.hyprland.org/Configuring/Environment-variables/
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];
      ###################
      ### PERMISSIONS ###
      ###################

      # See https://wiki.hyprland.org/Configuring/Permissions/

      #####################
      ### LOOK AND FEEL ###
      #####################

      # https://wiki.hyprland.org/Configuring/Variables/#general
      general = {
        gaps_in = 2;
        gaps_out = 10;
        border_size = 2;
        # https://wiki.hyprland.org/Configuring/Variables/#variable-types for info about colors;
        # This has to be move to extraConfig for now
        "col.active_border" = "rgba(33ccffee) rgba(00ff99ee) 45deg";
        "col.inactive_border" = "rgba(595959aa)";
        # Set to true enable resizing windows by clicking and dragging on borders and gaps;
        resize_on_border = false;
        # Please see https://wiki.hyprland.org/Configuring/Tearing/ before you turn this on;
        allow_tearing = false;
        layout = "dwindle";
      };

      # https://wiki.hyprland.org/Configuring/Variables/#decoration
      decoration = {
          rounding = 5;
          rounding_power = 2;

          # Change transparency of focused and unfocused windows;
          # This is for all windows, even firefox. Don't change.
          active_opacity = 1.0;
          inactive_opacity = 1.0;

          shadow = {
              enabled = true;
              range = 4;
              render_power = 3;
              color = "rgba(1a1a1aee)";
          };

          # https://wiki.hyprland.org/Configuring/Variables/#blur;
          blur = {
              enabled = true;
              size = 3;
              passes = 1;

              vibrancy = 0.1696;
          };
      };

      # https://wiki.hyprland.org/Configuring/Variables/#animations
      animations = {
        enabled = "yes, please :)";
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

      # Ref https://wiki.hyprland.org/Configuring/Workspace-Rules/
      # "Smart gaps" / "No gaps when only"
      # uncomment all if you wish to use that.
      # workspace = w[tv1], gapsout:0, gapsin:0
      # workspace = f[1], gapsout:0, gapsin:0
      # windowrule = bordersize 0, floating:0, onworkspace:w[tv1]
      # windowrule = rounding 0, floating:0, onworkspace:w[tv1]
      # windowrule = bordersize 0, floating:0, onworkspace:f[1]
      # windowrule = rounding 0, floating:0, onworkspace:f[1]

      # See https://wiki.hyprland.org/Configuring/Dwindle-Layout/ for more
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # See https://wiki.hyprland.org/Configuring/Master-Layout/ for more
      master = {
        new_status = "master";
      };

      # https://wiki.hyprland.org/Configuring/Variables/#misc
      misc = {
        force_default_wallpaper = 1; # Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo = true; # If true disables the random hyprland logo / anime girl background. :(
      };

      #############
      ### INPUT ###
      #############

      # https://wiki.hyprland.org/Configuring/Variables/#input
      input = {
        kb_layout = "us";
        "kb_variant" ="";
        "kb_model" ="";
        "kb_options" ="";
        "kb_rules" ="";

        follow_mouse = 1;

        sensitivity = 0; # -1.0 - 1.0, 0 means no modification.

        touchpad = {
            natural_scroll = true;
        };
      };

      # https://wiki.hyprland.org/Configuring/Variables/#gestures
      gestures = {
          workspace_swipe = false;
      };

      # Example per-device config
      # See https://wiki.hyprland.org/Configuring/Keywords/#per-device-input-configs for more
      device = {
          name = "epic-mouse-v1";
          sensitivity = -0.5;
      };

      ###################
      ### KEYBINDINGS ###
      ###################


      # See https://wiki.hyprland.org/Configuring/Keywords/
      "$mainMod" = "SUPER"; # Sets "Windows" key as main modifier

      bind = [
        # Open to rofi launcher to launch apps
        # This only broke because there's another SUPER, S keybind :(
        # I'm an IDIOT
        #"SUPER, S, exec, rofi -show drun -show-icons -normal-window"
        
        # Example binds, see https://wiki.hyprland.org/Configuring/Binds/ for more
        "SUPER, Q, exec, $terminal"
        "SUPER, C, killactive"
        "SUPER, M, exit"
        "SUPER, E, exec, $fileManager"
        "SUPER, V, togglefloating"
        "SUPER, R, exec, $menu"
        "SUPER, P, pseudo, # dwindle"
        "SUPER, J, togglesplit, # dwindle"
        
        # Move focus with mainMod + arrow keys
        "SUPER, left, movefocus, l"
        "SUPER, right, movefocus, r"
        "SUPER, up, movefocus, u"
        "SUPER, down, movefocus, d"
        
        # Switch workspaces with mainMod + [0-9]
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
        
        # Move active window to a workspace with mainMod + SHIFT + [0-9]
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
        
        # Example special workspace (scratchpad)
        "SUPER, S, togglespecialworkspace, magic"
        "SUPER+SHIFT, S, movetoworkspace, special:magic"
        
        # Scroll through existing workspaces with mainMod + scroll
        "SUPER, mouse_down, workspace, e+1"
        "SUPER, mouse_up, workspace, e-1"
      ];

      # Mouse modifiers
      bindm = [
        "$mainMod, mouse:272, movewindow"      # LMB
        "$mainMod, mouse:273, resizewindow"    # RMB
      ];

      # Lazy keybinds with external input events (volume, brightness, etc.)
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      # Lazy (normal) keybinds (media playback)
      bindl = [
        ",XF86AudioNext, exec, playerctl next"
        ",XF86AudioPause, exec, playerctl play-pause"
        ",XF86AudioPlay, exec, playerctl play-pause"
        ",XF86AudioPrev, exec, playerctl previous"
      ];

      ##############################
      ### WINDOWS AND WORKSPACES ###
      ##############################

      # See https://wiki.hyprland.org/Configuring/Window-Rules/ for more
      # See https://wiki.hyprland.org/Configuring/Workspace-Rules/ for workspace rules
      
      # Example windowrule
      # windowrule = float,class:^(kitty)$,title:^(kitty)$
      

      windowrule = [
       # Ignore maximize requests from apps. You'll probably like this.
       "suppressevent maximize, class:.*"
       # Fix some dragging issues with XWayland
       "nofocus, class:^$, title:^$, xwayland:1, floating:1, fullscreen:0, pinned:0"
      ];
      #################
      ### AUTOSTART ###
      #################
      exec-once = [
        # Network manager
        "nm-applet --indicator &"
        # Wallpaper engine
        "swww-daemon && swww img /home/john/Pictures/Wallpapers/forest-3.jpg"
        #"swww-daemon && swww img /home/john/Pictures/Wallpapers/nix-gold.jpg"
        # Top bar
        "waybar &"
        # Notifications (requires libnotify)
        "dunst"
      ];
    };
  };


  # Hyprland packages
  home.packages = with pkgs; [
    #kdePackages.dolphin    # file manager (qt6)
    nautilus                # file manager (gtk3?)
    #pcmanfm                 # file manager (both?)
    waybar     # if workspaces don't work properly add the -Dexperimental=true flag
    dunst      # notification manager
    libnotify  # needed for libnotify
    swww       # wallpaper daemon (a bunch of others)
    kitty      # default (others: alacritty, wezterm, ...)
    #rofi-wayland         # app launcher (others: wofi, bemenu, fuzzel, tofi)
    wofi                  # native wayland rofi
    networkmanagerapplet # should give me a nice looking network manager
    brightnessctl        # control the brightness
  ];

}

{ config, pkgs, ... }: {

  # This manages the ~/.config/hypr/hyprland.config file
  wayland.windowManager.hyprland = {
    enable = true;
    settings = {
      input = {
        natural_scroll = true;  
      };
      bind = [
        # App launcher 
        "SUPER, S, exec, rofi -show drun -show-icons"
      ];
      exec-once = [
        # Wallpaper engine
        "swww init && swww img ~/.Wallpapers/gruvbox-mountain-village.png"
        # Network manager
        "nm-applet --indicator"
        # Top bar
        "wayland"
        # Notifications (requires libnotify)
        "dunst"
      ];
    };
  };


  # Hyprland packages
  home.packages = with pkgs; [
    waybar  # if workspaces don't work properly add the -Dexperimental=true flag
    dunst   # notification manager
    libnotify
    swww    # wallpaper daemon (a bunch of others)
    kitty   # default (others: alacritty, wezterm, ...)
    rofi-wayland # app launcher (others: wofi, bemenu, fuzzel, tofi)
    networkmanagerapplet # should give me a nice looking network manager
  ];
}

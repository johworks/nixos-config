{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:
let
  gruvboxPlus = import ../../modules/home/gruvbox-plus.nix { inherit pkgs; };
in
{

  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/desktop.nix
    ../../modules/home/profiles/wayland.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
  ];

  theme = {
    gtk.iconTheme = {
      package = gruvboxPlus;
      name = "GruvboxPlus";
    };
    fonts.size = 12;
  };

  desktop.hyprland = {
    enable = true;
    wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/sunset-field.jpg";
  };

  desktop.waybar.enable = lib.mkDefault true;

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 14;
  };

  gtk = {
    enable = true;
    theme = config.theme.gtk.theme;
    gtk4.theme = config.theme.gtk.theme;
    iconTheme = config.theme.gtk.iconTheme;
    font = {
      name = config.theme.fonts.sansSerif;
      size = config.theme.fonts.size;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };

  qt = {
    enable = true;
    platformTheme.name = config.theme.qt.platformTheme;
    style.name = config.theme.qt.style;
  };

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "25.05"; # Please read the comment before changing.

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = with pkgs; [
    kdePackages.breeze-icons # default used by gtk

    # Make Qt applications integrate with GNOME stylings
    adwaita-qt # Qt style that matches Adwaita
    qt6.qtwayland
    qt5.qtwayland

    # Compress videos before storage
    ffmpeg

    # Interact with iCloud photos
    icloudpd
    ripgrep

    # Full suite of tools (calc == excel)
    libreoffice
  ];

  home.file."Pictures/Wallpapers/sunset-field.jpg".source = import ../../wallpapers/sunset-field.nix {
    inherit pkgs;
  };
}

{ config, pkgs, inputs, lib, ... }:
let
  gruvboxPlus = import ../../modules/home/gruvbox-plus.nix { inherit pkgs; };
in 
{

  imports = [
    ../../modules/home/profiles/base.nix
    ../../modules/home/profiles/wayland.nix
    #../../modules/home/nvim/nvim.nix
    #../../modules/home/shared-nvim/home-manager/nvim.nix
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
    wallpaper = "${config.home.homeDirectory}/Pictures/Wallpapers/forest-3.jpg";
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
  home.packages = config.profiles.basePackages ++ (with pkgs; [
    kdePackages.breeze-icons  # default used by gtk

    # Make Qt applications integrate with GNOME stylings
    adwaita-qt           # Qt style that matches Adwaita
    qt6.qtwayland
    qt5.qtwayland

    # Compress videos before storage
    ffmpeg
    
    # Interact with iCloud photos
    icloudpd
    ripgrep

    # Full suite of tools (calc == excel)
    libreoffice
  ]);


  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = 
  let 
    forest-wallpaper = builtins.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/irl/forest-3.jpg";
      sha256 = "14l56mlia6ncpc8aj15z1cdpm38f8hn14c1p1js67d3b7k6rhbnz";
    };
    nix-wallpaper = builtins.fetchurl {
      url = "https://gruvbox-wallpapers.pages.dev/wallpapers/minimalistic/nix.png";
      sha256 = "0j5zz31fkmlkcbnj49a643vxdsvq486vf4l2r4hc6fdr43h8kzwc";
    };
  in {
    # Default wallpaper
    "Pictures/Wallpapers/forest-3.jpg".source = forest-wallpaper;
    "Pictures/Wallpapers/nix-gold.jpg".source = nix-wallpaper;

  };

  # Let Home Manager install and manage itself.
  # Moved to base.nix
  # programs.home-manager.enable = true;
}

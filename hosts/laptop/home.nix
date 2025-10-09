{ config, pkgs, inputs, ... }:
let
  gruvboxPlus = import ../../modules/home/gruvbox-plus.nix { inherit pkgs; };
in 
{

  imports = [ 
    ../../modules/home/hyprland.nix
    #../../modules/home/nvim/nvim.nix
    #../../modules/home/shared-nvim/home-manager/nvim.nix
    (inputs.shared-nvim + "/home-manager/nvim.nix")
    ../../modules/home/firefox.nix
    ../../modules/home/git.nix
    ../../modules/home/ssh.nix
  ];


  # Home Manager needs a bit of information about you and the paths it should
  # manage.
  home.username = "john";
  home.homeDirectory = "/home/john";

  home.pointerCursor = {
    gtk.enable = true;
    package = pkgs.bibata-cursors;
    name = "Bibata-Modern-Ice";
    size = 14;
  };

  ## Enable gtk (GNOME)
  #gtk = {
  #  enable = true;
  #    #cursorTheme = {
  #    #  package = pkgs.bibata-cursors;
  #    #  name = "Bibata-Modern-Ice";
  #    #};
  #  theme = {
  #    package = pkgs.adw-gtk3;
  #    name = "adw-gtk3";
  #  };
  #  iconTheme = {
  #    package = gruvboxPlus;
  #    name = "GruvboxPlus";
  #  };
  #  font = {
  #    name = "JetBrainsMono Nerd Font";
  #    size = 14;
  #  };
  #};


  gtk.theme = {
    package = pkgs.gnome-themes-extra;
    name = "Adwaita-dark";
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
  };


    #  gtk = {
    #    enable = true;
    #    theme = {
    #      package = pkgs.adw-gtk3;   # GTK3 apps
    #      name = "adw-gtk3";
    #    };
    #    iconTheme = {
    #      package = gruvboxPlus;
    #      name = "GruvboxPlus";
    #    };
    #    font = { name = "Noto Sans"; size = 11; };
    #  };
    #
    #  # libadwaita (GTK4) dark mode + fonts
    #  dconf.settings = {
    #    "org/gnome/desktop/interface" = {
    #      color-scheme = "prefer-dark";
    #      font-name = "Noto Sans 11";
    #      monospace-font-name = "JetBrainsMono Nerd Font 11";
    #      # optional: document-font-name, etc.
    #    };
    #  };


  qt = {
    enable = true;
    platformTheme.name = "gtk";   # sets QT_QPA_PLATFORMTHEME=gtk
    style.name = "adwaita-dark";  # used when available
  };
  
  # Remove this to avoid overriding/forcing a style:
  # home.sessionVariables.QT_STYLE_OVERRIDE = "adwaita-dark";

  ## Enable qt (KDE)
  #qt.enable = true;
  #qt.platformTheme.name = "gtk";
  #qt.style.name = "adwaita-dark";


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
    # Icons that GTK apps (like wofi) use
    #papirus-icon-theme
    kdePackages.breeze-icons  # default used by gtk

    # Make Qt applications integrate with GNOME stylings
    adwaita-qt           # Qt style that matches Adwaita
    qt6.qtwayland
    qt5.qtwayland

    # Compress videos before storage
    ffmpeg
    
    # Interact with iCloud photos
    icloudpd

    # I guess make isn't installed by default?
    gnumake
    tree
    ripgrep

    # Full suite of tools (calc == excel)
    libreoffice

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
  ];


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

    # Manage who we trust
    ".ssh/known_hosts".text = ''
        github.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl
        github.com ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=
        github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
      '';
  };

  # Home Manager can also manage your environment variables through
  # 'home.sessionVariables'. These will be explicitly sourced when using a
  # shell provided by Home Manager. If you don't want to manage your shell
  # through Home Manager then you have to manually source 'hm-session-vars.sh'
  # located at either
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/john/etc/profile.d/hm-session-vars.sh
  #
  home.sessionVariables = {
    EDITOR = "nvim";
    QT_QPA_PLATFORM = "wayland";   # prefer Wayland backend
    #QT_STYLE_OVERRIDE = "adwaita-dark";

    #STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${config.home.homeDirectory}/.steam/root/compatibilitytools.d";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
}

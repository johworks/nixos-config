{ lib, pkgs, ... }:
let
  inherit (lib) mkOption mkDefault types;

  themeRefType = types.submodule ({ ... }: {
    options = {
      package = mkOption {
        type = types.package;
        description = "Package providing the theme/icon files.";
      };
      name = mkOption {
        type = types.str;
        description = "Name of the theme/icon inside the package.";
      };
    };
  });
in {
  options.theme = {
    name = mkOption {
      type = types.str;
      default = "gruvbox-dark";
      description = "Identifier for the current UI palette.";
    };

    colors = {
      background = mkOption {
        type = types.str;
        description = "Primary background color.";
      };
      surface = mkOption {
        type = types.str;
        description = "Raised surface background.";
      };
      surfaceAlt = mkOption {
        type = types.str;
        description = "Alternate surface background.";
      };
      foreground = mkOption {
        type = types.str;
        description = "Primary foreground color.";
      };
      muted = mkOption {
        type = types.str;
        description = "Muted/disabled foreground color.";
      };
      accent = mkOption {
        type = types.str;
        description = "Primary accent color.";
      };
      accentAlt = mkOption {
        type = types.str;
        description = "Secondary accent color.";
      };
      alert = mkOption {
        type = types.str;
        description = "Alert color for warnings/criticals.";
      };
    };

    fonts = {
      monospace = mkOption {
        type = types.str;
        default = "JetBrainsMono Nerd Font";
        description = "Monospace font used for terminals and bars.";
      };
      sansSerif = mkOption {
        type = types.str;
        default = "Noto Sans";
        description = "Sans-serif font for UI/toolkit text.";
      };
      serif = mkOption {
        type = types.str;
        default = "Noto Serif";
        description = "Serif font fallback.";
      };
      emoji = mkOption {
        type = types.str;
        default = "Noto Color Emoji";
        description = "Emoji font fallback.";
      };
      size = mkOption {
        type = types.number;
        default = 11;
        description = "Default UI font size.";
      };
    };

    gtk = {
      theme = mkOption {
        type = themeRefType;
        description = "GTK theme package + name.";
      };
      iconTheme = mkOption {
        type = themeRefType;
        description = "Icon theme package + name.";
      };
    };

    qt = {
      platformTheme = mkOption {
        type = types.str;
        default = "gtk";
        description = "Value assigned to QT_QPA_PLATFORMTHEME.";
      };
      style = mkOption {
        type = types.str;
        default = "adwaita-dark";
        description = "Preferred Qt style name if available.";
      };
    };
  };

  config.theme = {
    name = mkDefault "gruvbox-dark";
    colors = {
      background = mkDefault "#1d2021";
      surface = mkDefault "#282828";
      surfaceAlt = mkDefault "#32302f";
      foreground = mkDefault "#ebdbb2";
      muted = mkDefault "#a89984";
      accent = mkDefault "#d79921";
      accentAlt = mkDefault "#83a598";
      alert = mkDefault "#fb4934";
    };

    gtk.theme = mkDefault {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita-dark";
    };

    gtk.iconTheme = mkDefault {
      package = pkgs.gnome-themes-extra;
      name = "Adwaita";
    };
  };
}

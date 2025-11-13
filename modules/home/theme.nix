{ lib, ... }:
let
  inherit (lib) mkOption mkDefault types;
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
  };
}

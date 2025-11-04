{ lib, ... }:
{
  imports = [
    ../hyprland.nix
  ];

  config = {
    home.sessionVariables.QT_QPA_PLATFORM = lib.mkDefault "wayland";
  };
}

{ lib, ... }:
{
  imports = [
    ../theme.nix
    ../hyprland.nix
    ../waybar.nix
  ];

  config = {
    home.sessionVariables.QT_QPA_PLATFORM = lib.mkDefault "wayland";
    home.sessionVariables.NIXOS_OZONE_WL = lib.mkDefault "1";
  };
}

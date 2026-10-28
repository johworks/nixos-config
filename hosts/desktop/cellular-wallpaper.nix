{ pkgs, ... }:
let
  selectWallpaper = pkgs.writeShellScript "select-cellular-wallpaper" ''
    exec ${pkgs.kdePackages.qttools}/bin/qdbus org.kde.plasmashell /PlasmaShell \
      org.kde.PlasmaShell.evaluateScript \
      'desktops().forEach(function (desktop) { desktop.wallpaperPlugin = "org.nixos.pixelweather"; });'
  '';
in
{
  xdg.dataFile."plasma/wallpapers/org.nixos.pixelweather".source = ../../wallpapers/pixel-weather;

  systemd.user.services.cellular-wallpaper = {
    Unit = {
      Description = "Select the cellular automata wallpaper";
      After = [ "plasma-plasmashell.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = selectWallpaper;
    };
    Install.WantedBy = [ "plasma-workspace.target" ];
  };
}

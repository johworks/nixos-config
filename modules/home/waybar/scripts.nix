# Copied from: https://github.com/vimjoyer/nixconf/blob/main/homeManagerModules/features/waybar/scripts.nix
{pkgs}: {
  battery = pkgs.writeShellScriptBin "script" ''
    cat /sys/class/power_supply/BAT0/capacity
  '';
}

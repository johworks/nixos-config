{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  home = config.home.homeDirectory;
  package = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.update-prepare;
in
{
  options.services.nixosUpdatePreparation.enable = lib.mkEnableOption "weekly build-only NixOS update preparation";

  config = lib.mkIf config.services.nixosUpdatePreparation.enable {
    home.packages = [ package ];

    systemd.user.services.nixos-update-prepare = {
      Unit = {
        Description = "Prepare NixOS update candidates and send a Signal build report";
        ConditionPathExists = [
          "${home}/nixos-config/.git"
          "${home}/.ssh/id_ed25519_nuc"
        ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${package}/bin/update-prepare --repo ${home}/nixos-config --base main --codex ${home}/.npm-global/bin/codex --vm-lab ${
          inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nixos-lab
        }/bin/nixos-lab --notify-signal";
        Environment = [
          "HOME=${home}"
          "PATH=/run/current-system/sw/bin"
        ];
        WorkingDirectory = "${home}/nixos-config";
        UMask = "0077";
        Nice = 10;
        IOSchedulingClass = "idle";
        TimeoutStartSec = "65min";
        KillMode = "control-group";
      };
    };

    systemd.user.timers.nixos-update-prepare = {
      Unit.Description = "Prepare reviewed local-main updates weekly";
      Timer = {
        OnCalendar = "Sun 03:00";
        RandomizedDelaySec = "20min";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}

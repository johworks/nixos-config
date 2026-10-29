{ config, pkgs, ... }: 
let
  configDir = "/var/lib/zurg";
  zurgConfig = ./config.yml;
in {

  ### This version uses podman, not the NixOS way

  # Make sure the relative config gets mapped to abs path
  environment.etc."zurg/config.yml".source = builtins.toPath zurgConfig;

  # Simple path where Zurg will store config
  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers = {

    zurg= {
      image = "ghcr.io/debridmediamanager/zurg-testing:v0.9.3-final";
      autoStart = true;
      ports = [ "9999:9999" ];
      volumes = [
        "${configDir}:/app/data"
        "/etc/zurg/config.yml:/app/config.yml"
      ];
    };
  };
}

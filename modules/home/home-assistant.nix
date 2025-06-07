{ config, pkgs, ... }: 
let
  configDir = "/var/lib/home-assistant";
in {

  ### This version uses podman, not the NixOS way

  # Simple path where Home Assistant will store config
  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable";
    autoStart = true;
    extraOptions = ["--pull=newer"];
    ports = [ "8123:8123" ];
    volumes = [
      "${configDir}:/config"
    ];
    environment = {
      TZ = "America/New_York";
    };

  };
}

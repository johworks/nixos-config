{ ... }:

let
  configDir = "/var/lib/esphome";
in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.esphome = {
    image = "ghcr.io/esphome/esphome:stable";
    autoStart = true;
    pull = "newer";
    volumes = [
      "${configDir}:/config"
    ];
    extraOptions = [
      "--network=host"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

  networking.firewall.allowedTCPPorts = [ 6052 ];
  networking.firewall.allowedUDPPorts = [ 5353 ];
}

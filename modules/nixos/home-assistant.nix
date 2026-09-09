{ config, ... }:

let
  configDir = "/var/lib/home-assistant";
  configurationFile = ./home-assistant/configuration.yaml;
  dashboardsDir = ./home-assistant/dashboards;
  packagesDir = ./home-assistant/packages;
in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:stable";
    autoStart = true;
    pull = "newer";
    privileged = true;
    environment.TZ = config.time.timeZone;
    volumes = [
      "${configDir}:/config"
      "${configurationFile}:/config/configuration.yaml:ro"
      "${dashboardsDir}:/config/dashboards:ro"
      "${packagesDir}:/config/packages:ro"
      "/run/dbus:/run/dbus:ro"
    ];
    extraOptions = [
      "--network=host"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 286 286 - -"
  ];

  networking.firewall.allowedTCPPorts = [ 8123 ];
}

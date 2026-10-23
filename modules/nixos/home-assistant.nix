{ config, ... }:

let
  configDir = "/var/lib/home-assistant";
  configurationFile = ./home-assistant/configuration.yaml;
  dashboardsDir = ./home-assistant/dashboards;
  packagesDir = ./home-assistant/packages;
  caBundle = config.environment.etc."ssl/certs/ca-certificates.crt".source;
in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.home-assistant = {
    image = "ghcr.io/home-assistant/home-assistant:2026.10.2@sha256:33afb0659d786213264c2211f8d91c5fe87461c56eba6a3a546eb05fc71e89f4";
    autoStart = true;
    pull = "newer";
    privileged = true;
    environment = {
      TZ = config.time.timeZone;
      SSL_CERT_FILE = "/run/nixos-certs/ca-bundle.crt";
      SSL_CERT_DIR = "/run/nixos-certs";
      REQUESTS_CA_BUNDLE = "/run/nixos-certs/ca-bundle.crt";
      PIP_CERT = "/run/nixos-certs/ca-bundle.crt";
    };
    volumes = [
      # The pinned image predates the incident; cover explicit certifi users too.
      "${builtins.dirOf caBundle}:/run/nixos-certs:ro"
      "${caBundle}:/usr/local/lib/python3.14/site-packages/certifi/cacert.pem:ro"
      "${caBundle}:/usr/local/lib/python3.14/site-packages/pip/_vendor/certifi/cacert.pem:ro"
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

}

{ config, ... }:

let
  configDir = "/var/lib/esphome";
  caBundle = config.environment.etc."ssl/certs/ca-certificates.crt".source;
in
{
  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers.esphome = {
    image = "ghcr.io/esphome/esphome:2026.10.0@sha256:1dff19a59070cdb523b76576cdc74d200f862d43c1407809088855920cf57145";
    autoStart = true;
    pull = "newer";
    # certifi is patched in this image, but its OS trust store still accepts bad chains.
    environment = {
      SSL_CERT_FILE = "/run/nixos-certs/ca-bundle.crt";
      SSL_CERT_DIR = "/run/nixos-certs";
      REQUESTS_CA_BUNDLE = "/run/nixos-certs/ca-bundle.crt";
      PIP_CERT = "/run/nixos-certs/ca-bundle.crt";
    };
    volumes = [
      "${builtins.dirOf caBundle}:/run/nixos-certs:ro"
      "${configDir}:/config"
    ];
    extraOptions = [
      "--network=host"
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${configDir} 0755 root root - -"
  ];

}

{ config, pkgs, inputs, ... }:

{

  imports = [
    inputs.nixarr.nixosModules.default
  ];

  nixarr = {
    enable = true;

    jellyfin.enable = true;
    jellyseerr.enable = true;

    # Arr apps
    radarr.enable = true;
    sonarr.enable = true;
    prowlarr.enable = true;

    #qbittorrent = {
    #  enable = true;
    #  # I'm pretty sure this is wrong
    #  # I need a Wire Gaurd config file
    #  vpn = {
    #    enable = true;
    #    provider = "nordvpn"; # optional
    #  };
    #};

    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";
    #downloadDir = "/data/torrents";

  };


}

{ config, pkgs, inputs, ... }:

{

  imports = [
    inputs.nixarr.nixosModules.default
  ];

  nixarr = {
    enable = true;

    jellyfin.enable = true;          # 8096
    jellyseerr.enable = true;        # 5055

    radarr.enable = true;            # 8989
    sonarr.enable = true;            # 7878
    prowlarr.enable = true;          # 9696
    readarr.enable = true;           # 8787

    # This is broken for some group reason
    #readarr-audiobook.enable = true; # 9494

    vpn = {
      enable = true;
      wgConf = "/data/.secret/wg.conf";
    };


    transmission = {
      enable = true;
      vpn.enable = true;
      peerPort = 1637;  # I think?
    };

    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";
    #downloadDir = "/data/torrents";

  };

}

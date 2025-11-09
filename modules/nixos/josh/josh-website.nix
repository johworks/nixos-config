{ config, pkgs, ... }:

let
  myDomain0 = "joshnaked.com";
  myDomain1 = "joshnaked.gay";
  myAcmeEmail = "viridianveil@protonmail.com";
in 
{
  #####################################################################
  # Ensure the directory exists on boot
  #####################################################################
  systemd.tmpfiles.rules = [
    "d /var/www/josh_website 0755 root root - -"
  ];

  #####################################################################
  # Nginx reverse‑proxy with ACME
  #####################################################################
  services.nginx = {
    enable = true;

    # Internal server serving the website on localhost:8223
    virtualHosts.static = {
      listen = [ { addr = "127.0.0.1"; port = 8223; } ];
      root   = "/var/www/josh_website";
      extraConfig = ''
        index index.html;
      '';
    };

    # Two domains:
    virtualHosts."${myDomain0}" = {
      forceSSL   = true;
      enableACME = true;

      locations."/" = {
        proxyPass       = "http://127.0.0.1:8223";
        proxyWebsockets = true;
      };
    };
    virtualHosts."${myDomain1}" = {
      forceSSL   = true;
      enableACME = true;

      locations."/" = {
        proxyPass       = "http://127.0.0.1:8223";
        proxyWebsockets = true;
      };
    };

  };


  #####################################################################
  # ACME global settings
  #####################################################################
  security.acme = {
    acceptTerms = true;
    # globally used for any host with enableACME = true
    defaults = {
      email  = "${myAcmeEmail}";
    };
  };

  #####################################################################
  # Firewall
  #####################################################################
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    enable = true;
  };

}

{ config, lib, pkgs, ... }:

let
  myDomain = "vault.goobhub.org";
  myAcmeEmail = "viridianveil@protonmail.com";
  backupDir = "/data/vaultwarden/backups";
in
{
  #####################################################################
  # 1. Vaultwarden service
  #####################################################################

  systemd.tmpfiles.rules = [
    "d ${backupDir} 0750 vaultwarden vaultwarden -"
  ];

  services.vaultwarden = {
    enable    = true;
    dbBackend = "sqlite";
    backupDir = "${backupDir}";
    config = {
      # Only listen on localhost; nginx will terminate TLS
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT    = 8222;

      # Tell users the external URL is HTTPS
      DOMAIN = "https://${myDomain}";

      SIGNUPS_ALLOWED = true;
      ADMIN_TOKEN = "$argon2id$v=19$m=65540,t=3,p=4$aRPjxTgv5LL3fD9Tv4cV+ksx1odV6IN7TA/leVyBQNQ$fHUzPUj6Vwgg6wToZSQLdm5GEp86G1eENPtr0wBFcSU";
    };
  };

  #####################################################################
  # 2. Nginx reverse‑proxy with ACME
  #####################################################################
  services.nginx = {
    enable = true;
    virtualHosts."${myDomain}" = {
      forceSSL   = true;
      enableACME = true;

      # 1) Admin only on localhost
      locations."/admin" = {
        # only allow 127.0.0.1 (and maybe your LAN) to hit /admin
        proxyPass       = "http://127.0.0.1:8222";
        proxyWebsockets = true;
        extraConfig = ''
          allow 127.0.0.1;
          deny all;
        '';
      };

      locations."/" = {
        proxyPass       = "http://127.0.0.1:8222";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host              $host;
          proxy_set_header X-Real-IP         $remote_addr;
          proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };


  #####################################################################
  # 3. ACME global settings
  #####################################################################
  security.acme = {
    acceptTerms = true;
    # globally used for any host with enableACME = true
    defaults = {
      email  = "${myAcmeEmail}";
      # Use the staging server for testing?
      # caServer = "https://acme-staging-v02.api.letsencrypt.org/directory";
    };
    # ensure the nginx challenge makes it through
    #webroot = "/var/lib/acme/acme-challenges";
  };

  #####################################################################
  # 4. Firewall
  #####################################################################
  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    # ensure nginx can bind
    enable = true;
  };

  #####################################################################
  # 5. CLI helpers (generate admin_token hash)
  #####################################################################
  environment.systemPackages = with pkgs; [ vaultwarden ];


  #####################################################################
  # 6. Make sure a sops file exists
  #####################################################################
  #sops.secrets."vaultwarden" = {
  #  path = "./secrets.default.vaultwarden.sops.yaml";
  #  type = "yaml";
  #};


}

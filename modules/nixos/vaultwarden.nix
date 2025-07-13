{ config, lib, pkgs, ... }:

{
  ## 1.  Password-manager service
  services.vaultwarden = {
    enable    = true;          # start the systemd unit
    dbBackend = "sqlite";      # simplest local database

    # Environment variables → /var/lib/vaultwarden.env
    config = {
      # Listen on all LAN addresses; change port if you like
      #ROCKET_ADDRESS = "0.0.0.0";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT    = 8222;

      # Internal URL the web-UI will report; adjust to your LAN name/IP
      DOMAIN = "http://vault.lan";

      # Sign-ups are disabled; you’ll create users from the admin panel
      SIGNUPS_ALLOWED = true;

      # Hash a long random string with:  `vaultwarden hash <your-token>`
      # then paste the resulting $argon2id… blob here
      ADMIN_TOKEN = "PASTE_HASH_HERE";

      # Leave all SMTP variables *unset* to disable e-mail entirely
    };
  };

  # Prob going to need to add pihole
  services.nginx = {
    enable = true;
    virtualHosts = {
      "vault.lan" = {
        forceSSL = true;
        enableACME = false;

        sslCertificate = "/etc/ssl/private/vaultwarden.crt";
        sslCertificateKey = "/etc/ssl/private/vaultwarden.key";

        locations."/" = {
          proxyPass = "http://localhost:8222";
          proxyWebsockets = true;
        };
      };
    };

  };

  #security.acme = {
  #  acceptTerms = true;
  #  defaults.email = "viridianveil@protonmail.com";
  #};

  networking.firewall.allowedTCPPorts = [ 80 443 ];

  ## 3.  Optional: ship the CLI so you can run `vaultwarden hash …`
  environment.systemPackages = with pkgs; [ vaultwarden ];
}

#{ config, pkgs, lib, ... }:
#{
#
#  # 2. Ensure .env exists outside the nix store for secrets
#  systemd.tmpfiles.rules = [
#    # Create a skeleton .env (600) for you to fill with ADMIN_TOKEN, etc.
#    "f /var/lib/vaultwarden/.env 0600 vaultwarden vaultwarden -"
#    # Ensure data folder
#    "d /var/lib/vaultwarden/data 0700 vaultwarden vaultwarden -"
#  ];
#
#  # 3. Vaultwarden service configuration
#  services.vaultwarden = {
#    enable = true;
#    package = pkgs.vaultwarden;
#    dbBackend = "sqlite";
#
#    # Core settings via env vars (omit SMTP_* to disable email)
#    config = {
#      DOMAIN = "https://vault.example.com";
#      #SIGNUPS_ALLOWED = false;
#      SIGNUPS_ALLOWED = true;
#      ROCKET_LOG = "critical";
#    };
#
#    # Mount your secret-filled .env (managed manually) at runtime
#    environmentFile = "/var/lib/vaultwarden/.env";
#  };
#
#  # 4. Nginx reverse proxy for HTTP and WebSockets
#  services.nginx = {
#    enable = true;
#    virtualHosts."vault.example.com" = {
#      listen = [ { addr = "0.0.0.0"; port = 80; } ];
#      enableACME = false;
#      forceSSL = false;
#
#      locations."/" = {
#        proxyPass = "http://127.0.0.1:8000";
#        proxyWebsockets = true;
#        extraConfig = ''
#          proxy_set_header Host            $host;
#          proxy_set_header X-Real-IP       $remote_addr;
#          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
#          proxy_set_header X-Forwarded-Proto $scheme;
#        '';
#      };
#    };
#  };
#
#  # 5. Open firewall for HTTP
#  networking.firewall.allowedTCPPorts = [ 80 ];
#}

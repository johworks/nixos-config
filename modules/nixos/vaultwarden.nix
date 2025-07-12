{ config, pkgs, lib, ... }:
{

  # 2. Ensure .env exists outside the nix store for secrets
  systemd.tmpfiles.rules = [
    # Create a skeleton .env (600) for you to fill with ADMIN_TOKEN, etc.
    "f /var/lib/vaultwarden/.env 0600 vaultwarden vaultwarden -"
    # Ensure data folder
    "d /var/lib/vaultwarden/data 0700 vaultwarden vaultwarden -"
  ];

  # 3. Vaultwarden service configuration
  services.vaultwarden = {
    enable = true;
    package = pkgs.vaultwarden;
    dbBackend = "sqlite";

    # Core settings via env vars (omit SMTP_* to disable email)
    config = {
      DOMAIN = "https://vault.example.com";
      #SIGNUPS_ALLOWED = false;
      SIGNUPS_ALLOWED = true;
      ROCKET_LOG = "critical";
    };

    # Mount your secret-filled .env (managed manually) at runtime
    environmentFile = "/var/lib/vaultwarden/.env";
  };

  # 4. Nginx reverse proxy for HTTP and WebSockets
  services.nginx = {
    enable = true;
    virtualHosts."vault.example.com" = {
      listen = [ { addr = "0.0.0.0"; port = 80; } ];
      enableACME = false;
      forceSSL = false;

      locations."/" = {
        proxyPass = "http://127.0.0.1:8000";
        proxyWebsockets = true;
        extraConfig = ''
          proxy_set_header Host            $host;
          proxy_set_header X-Real-IP       $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
        '';
      };
    };
  };

  # 5. Open firewall for HTTP
  networking.firewall.allowedTCPPorts = [ 80 ];
}

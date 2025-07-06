{ pkgs, ... }:
{
  services.bitwarden_rs = {
    enable = true;
    backupDir = "/mnt/bitwarden";
    config = {
      WEB_VAULT_FOLDER = "${pkgs.bitwarden_rs-vault}/share/bitwarden_rs/vault";
      WEB_VAULT_ENABLED = true;
      LOG_FILE = "/var/log/bitwarden";
      WEBSOCKET_ENABLED = true;
      WEBSOCKET_ADDRESS = "0.0.0.0";
      WEBSOCKET_PORT = 3012;
      SIGNUPS_VERIFY = true;
 #    ADMIN_TOKEN = (import /etc/nixos/secret/bitwarden.nix).ADMIN_TOKEN;
      DOMAIN = "https://vault.example.org";
      # HTTPS
      #ROCKET_PORT = 8812;

      # yubi key
 #    YUBICO_CLIENT_ID = (import /etc/nixos/secret/bitwarden.nix).YUBICO_CLIENT_ID;
 #    YUBICO_SECRET_KEY = (import /etc/nixos/secret/bitwarden.nix).YUBICO_SECRET_KEY;
      #     YUBICO_SERVER = "https://api.yubico.com/wsapi/2.0/verify";

      # Email notifications
      #SMTP_HOST = "mx.example.com";
      #SMTP_FROM = "bitwarden@example.com";
      #SMTP_FROM_NAME = "Bitwarden_RS";
      #SMTP_PORT = 587;
      #SMTP_SECURITY = starttls;
#     SMTP_USERNAME = (import /etc/nixos/secret/bitwarden.nix).SMTP_USERNAME;
#     SMTP_PASSWORD = (import /etc/nixos/secret/bitwarden.nix).SMTP_PASSWORD;
      #SMTP_TIMEOUT = 15;
    };
    environmentFile = "/etc/nixos/secret/bitwarden.env";
  };
}

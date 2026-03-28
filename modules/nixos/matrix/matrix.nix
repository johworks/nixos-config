{ config, lib, pkgs, ... }:

let
  domain = "goobhub.org";
  matrixDomain = "matrix.${domain}";
  myAcmeEmail = "viridianveil@protonmail.com";
  enableFederation = false;
  clientConfig = {
    "m.homeserver".base_url = "https://${matrixDomain}";
    "m.identity_server" = {};
  };
  serverConfig = {
    "m.server" = "${matrixDomain}:443";
  };
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    return 200 '${builtins.toJSON data}';
  '';
in {

  sops.secrets."matrix-registration-shared-secret" = {
    sopsFile = ./secrets/secrets.yaml;
    owner = "matrix-synapse";
    group = "matrix-synapse";
    mode = "0400";
    path = "/run/secrets/matrix-registration-shared-secret";
  };

  services.matrix-synapse = {
    enable = true;
    settings = {
      server_name = domain;
      public_baseurl = "https://${matrixDomain}";

      listeners = [
        {
          port = 8008;
          bind_addresses = [ "127.0.0.1" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = ["client" "federation"];
              compress = true;
            }
          ];
        }
      ];

      database = {
        name = "psycopg2";
        allow_unsafe_locale = true;
        args = {
          user = "matrix-synapse";
          database = "matrix-synapse";
          host = "/run/postgresql";
        };
      };

      max_upload_size = "100M";
      url_preview_enabled = true;
      enable_registration = false;
      enable_metrics = false;
      # Keep the server private for now; flip this when you want cross-server chat.
      federation_domain_whitelist = if enableFederation then null else [ ];

      registration_shared_secret_path = config.sops.secrets."matrix-registration-shared-secret".path;
      trusted_key_servers = [
        {
          server_name = "matrix.org";
        }
      ];
    };
  };

  services.postgresql = {
    enable = true;
    settings.listen_addresses = lib.mkForce "";
    ensureDatabases = [ "matrix-synapse" ];
    ensureUsers = [
      {
        name = "matrix-synapse";
        ensureDBOwnership = true;
      }
    ];
  };

  services.nginx = {
    enable = true;
    virtualHosts.${domain} = {
      enableACME = true;
      forceSSL = true;
      locations = {
        "= /.well-known/matrix/client".extraConfig = mkWellKnown clientConfig;
      } // lib.optionalAttrs enableFederation {
        "= /.well-known/matrix/server".extraConfig = mkWellKnown serverConfig;
      };
    };

    virtualHosts.${matrixDomain} = {
      enableACME = true;
      forceSSL = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:8008";
        extraConfig = ''
          proxy_set_header Host $host;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          client_max_body_size 100M;
        '';
      };
    };
  };

  security.acme = {
    acceptTerms = true;
    defaults.email = myAcmeEmail;
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 443 ];
    enable = true;
  };

}

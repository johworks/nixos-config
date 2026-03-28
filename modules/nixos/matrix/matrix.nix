{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  domain = "goobhub.org";
  matrixDomain = "matrix.${domain}";
  matrixRtcDomain = "matrix-rtc.${domain}";
  myAcmeEmail = "viridianveil@protonmail.com";
  enableFederation = false;
  latestPkgs = import inputs.nixpkgs-latest {
    inherit (pkgs) system;
  };
  clientConfig = {
    "m.homeserver".base_url = "https://${matrixDomain}";
    "m.identity_server" = { };
    "org.matrix.msc4143.rtc_foci" = [
      {
        type = "livekit";
        livekit_service_url = "https://${matrixRtcDomain}/livekit/jwt";
      }
    ];
  };
  serverConfig = {
    "m.server" = "${matrixDomain}:443";
  };
  mkWellKnown = data: ''
    default_type application/json;
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
    add_header Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization";
    return 200 '${builtins.toJSON data}';
  '';
in
{
  disabledModules = [ "services/matrix/synapse.nix" ];
  imports = [ (inputs.nixpkgs-latest.outPath + "/nixos/modules/services/matrix/synapse.nix") ];

  nixpkgs.overlays = [
    (final: prev: {
      matrix-synapse = latestPkgs.matrix-synapse;
      matrix-synapse-unwrapped = latestPkgs.matrix-synapse-unwrapped;
    })
  ];

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
              names = [
                "client"
                "federation"
              ];
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
      experimental_features = {
        msc3266_enabled = true;
        msc4222_enabled = true;
        msc4143_enabled = true;
      };
      matrix_rtc = {
        transports = [
          {
            type = "livekit";
            livekit_service_url = "https://${matrixRtcDomain}/livekit/jwt";
          }
        ];
      };
      max_event_delay_duration = "24h";
      rc_message = {
        per_second = 0.5;
        burst_count = 30;
      };
      rc_delayed_event_mgmt = {
        per_second = 1;
        burst_count = 20;
      };

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
        # MatrixRTC auth resolves homeserver OpenID APIs via the Matrix server name.
        # Keep the server discovery document published even while federation itself
        # remains blocked by the empty federation whitelist.
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
    allowedTCPPorts = [
      80
      443
    ];
    enable = true;
  };

}

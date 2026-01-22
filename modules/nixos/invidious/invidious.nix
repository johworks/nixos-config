{ config, pkgs, ... }:

let
  myDomain = "yt.goobhub.org";
  invidiousPort = 3000;
  dataDir = "/var/lib/invidious";
  pgDataDir = "${dataDir}/postgres";
  companionCacheDir = "${dataDir}/companion-cache";
  configFile = "${dataDir}/config.yml";

  invidiousSrc = pkgs.fetchFromGitHub {
    owner = "iv-org";
    repo = "invidious";
    rev = "7e36cfb6678770db8a55e575caddd981dce2d032";
    hash = "sha256-1fguGV7dkUtj6eRqFRQAXJTWAWhYjbO/j4o5D2jjr/I=";
  };

  sqlDir = "${invidiousSrc}/config/sql";
  initScript = "${invidiousSrc}/docker/init-invidious-db.sh";
in
{
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${pgDataDir} 0700 root root - -"
    "d ${companionCacheDir} 0755 root root - -"
  ];

  sops.secrets."invidious.env" = {
    sopsFile = ./secrets/invidious.env;
    format = "dotenv";
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [
      "invidious-config.service"
      "podman-invidious.service"
      "podman-companion.service"
    ];
  };

  systemd.services.invidious-config = {
    description = "Render Invidious config.yml";
    after = [ "sops-nix.service" ];
    before = [ "podman-invidious.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      EnvironmentFile = config.sops.secrets."invidious.env".path;
      UMask = "0022";
    };
    script = ''
      install -d -m 0750 ${dataDir}
      {
        printf '%s\n' \
          "db:" \
          "  dbname: invidious" \
          "  user: kemal" \
          "  password: kemal" \
          "  host: 127.0.0.1" \
          "  port: 5432" \
          "check_tables: true" \
          "invidious_companion:" \
          "  - private_url: \"http://127.0.0.1:8282/companion\"" \
          "invidious_companion_key: \"$INVIDIOUS_COMPANION_KEY\"" \
          "hmac_key: \"$HMAC_KEY\"" \
          "domain: \"${myDomain}\"" \
          "host_binding: 127.0.0.1" \
          "https_only: true" \
          "external_port: 443"
      } > ${configFile}
      chmod 0644 ${configFile}
    '';
  };

  virtualisation.podman.enable = true;

  virtualisation.oci-containers.containers = {
    "invidious-db" = {
      image = "docker.io/library/postgres:14";
      autoStart = true;
      extraOptions = [ "--network=host" ];
      volumes = [
        "${pgDataDir}:/var/lib/postgresql/data"
        "${sqlDir}:/config/sql:ro"
        "${initScript}:/docker-entrypoint-initdb.d/init-invidious-db.sh:ro"
      ];
      environment = {
        POSTGRES_DB = "invidious";
        POSTGRES_USER = "kemal";
        POSTGRES_PASSWORD = "kemal";
      };
    };

    companion = {
      image = "quay.io/invidious/invidious-companion:latest";
      autoStart = true;
      extraOptions = [ "--network=host" ];
      environmentFiles = [ config.sops.secrets."invidious.env".path ];
      volumes = [
        "${companionCacheDir}:/var/tmp/youtubei.js"
      ];
    };

    invidious = {
      image = "quay.io/invidious/invidious:latest";
      autoStart = true;
      extraOptions = [ "--network=host" ];
      volumes = [
        "${configFile}:/config/config.yml:ro"
      ];
      environment = {
        INVIDIOUS_CONFIG_FILE = "/config/config.yml";
      };
      dependsOn = [ "invidious-db" "companion" ];
    };
  };

  systemd.services."podman-invidious".requires = [ "invidious-config.service" ];
  systemd.services."podman-invidious".after = [ "invidious-config.service" ];

  services.nginx = {
    enable = true;
    virtualHosts."${myDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString invidiousPort}";
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
}

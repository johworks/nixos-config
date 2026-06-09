{ pkgs, ... }:

let
  domain = "search.goobhub.org";
  zoneName = "goobhub.org";
  stateDir = "/var/lib/searxng";
  environmentFile = "${stateDir}/searx.env";
  authDir = "/var/lib/nginx/searxng";
  htpasswdFile = "${authDir}/htpasswd";
  passwordFile = "${authDir}/password";
in
{
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 searx searx - -"
    "d ${authDir} 0750 root nginx - -"
  ];

  systemd.services.searxng-secret = {
    description = "Create SearXNG secret key";
    before = [ "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      UMask = "0077";
    };
    path = with pkgs; [
      coreutils
      openssl
    ];
    script = ''
      install -d -m 0750 -o searx -g searx ${stateDir}
      if [ ! -s ${environmentFile} ]; then
        printf 'SEARXNG_SECRET_KEY=%s\n' "$(openssl rand -hex 32)" > ${environmentFile}
        chown searx:searx ${environmentFile}
        chmod 0400 ${environmentFile}
      fi
    '';
  };

  systemd.services.searx-init = {
    requires = [ "searxng-secret.service" ];
    after = [ "searxng-secret.service" ];
  };

  systemd.services.searxng-basic-auth = {
    description = "Create SearXNG basic auth credentials";
    before = [ "nginx.service" ];
    requiredBy = [ "nginx.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "root";
      Group = "root";
      UMask = "0077";
    };
    path = with pkgs; [
      apacheHttpd
      coreutils
      openssl
    ];
    script = ''
      install -d -m 0750 -o root -g nginx ${authDir}
      if [ ! -s ${passwordFile} ]; then
        openssl rand -base64 36 > ${passwordFile}
        chown root:root ${passwordFile}
        chmod 0400 ${passwordFile}
      fi

      if [ ! -s ${htpasswdFile} ]; then
        htpasswd -B -i -c ${htpasswdFile} john < ${passwordFile}
        chown root:nginx ${htpasswdFile}
        chmod 0440 ${htpasswdFile}
      fi
    '';
  };

  services.searx = {
    enable = true;
    redisCreateLocally = true;
    inherit environmentFile;

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 8888;
        base_url = "https://${domain}/";
        secret_key = "$SEARXNG_SECRET_KEY";
        limiter = true;
        image_proxy = true;
        method = "POST";
      };

      search = {
        safe_search = 0;
        autocomplete = "";
        formats = [
          "html"
          "json"
        ];
      };

      engines = [
        {
          name = "duckduckgo";
          disabled = true;
        }
        {
          name = "google";
          disabled = true;
        }
      ];

      ui.static_use_hash = true;
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
    basicAuthFile = htpasswdFile;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8888";
      proxyWebsockets = true;
      recommendedProxySettings = true;
    };
    extraConfig = ''
      access_log off;
    '';
  };

  services.ddns.cloudflare.records = [
    {
      name = "searxng";
      inherit zoneName;
      recordName = domain;
    }
  ];
}

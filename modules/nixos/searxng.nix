{ pkgs, ... }:

let
  domain = "search.goobhub.org";
  zoneName = "goobhub.org";
  stateDir = "/var/lib/searxng";
  environmentFile = "${stateDir}/searx.env";
in
{
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0750 searx searx - -"
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

      ui.static_use_hash = true;
    };
  };

  services.nginx.virtualHosts."${domain}" = {
    forceSSL = true;
    enableACME = true;
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

{ config, pkgs, ... }:

let
  myDomain = "stream.goobhub.org";
  myZoneName = "goobhub.org";
  stremioPort = 11470;
  configDir = "/var/lib/stremio";
  caBundle = config.security.pki.caBundle;
  # Verify every TLS connection, including redirects and nested HLS resources.
  # GnuTLS does not select this bundle from SSL_CERT_FILE.
  ffmpeg = pkgs.ffmpeg_8-full.overrideAttrs (old: {
    postPatch = (old.postPatch or "") + ''
      substituteInPlace libavformat/tls.h \
        --replace-fail '#define TLS_VERIFY_DEFAULT 0' '#define TLS_VERIFY_DEFAULT 1' \
        --replace-fail 'offsetof(pstruct, options_field . ca_file),   AV_OPT_TYPE_STRING, .flags = TLS_OPTFL' \
          'offsetof(pstruct, options_field . ca_file),   AV_OPT_TYPE_STRING, { .str = "${caBundle}" }, .flags = TLS_OPTFL'
    '';
  });
  server = pkgs.runCommand "stremio-server-4.22.4" { } ''
    mkdir -p "$out"
    cp ${
      pkgs.fetchurl {
        url = "https://dl.strem.io/server/v4.22.4/desktop/server.js";
        sha256 = "0b5b0bfc0165dad7f6397335594050832aa5760d7098123f739292efb80794ba";
      }
    } "$out/server.js"
    substituteInPlace "$out/server.js" \
      --replace-fail 'server.listen(port), server.on("error"' 'server.listen(port, "127.0.0.1"), server.on("error"' \
      --replace-fail 'server.listen(port);' 'server.listen(port, "127.0.0.1");'
  '';

in
{
  # The upstream image still ships Node 14 and old FFmpeg; use maintained runtimes.
  users.groups.stremio = { };
  users.users.stremio = {
    isSystemUser = true;
    group = "stremio";
    home = configDir;
  };
  systemd.services.stremio = {
    description = "Stremio streaming server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment = {
      HOME = configDir;
      APP_PATH = configDir;
      CASTING_DISABLED = "1";
      NO_HTTPS_SERVER = "1";
      FFMPEG_BIN = "${ffmpeg.bin}/bin/ffmpeg";
      FFPROBE_BIN = "${ffmpeg.bin}/bin/ffprobe";
      SSL_CERT_FILE = toString caBundle;
    };
    # The old container persisted its internal path in the host-mounted settings.
    preStart = ''
      ${pkgs.nodejs_22}/bin/node <<'JS'
      const fs = require('node:fs');
      const file = '${configDir}/server-settings.json';
      if (fs.existsSync(file)) {
        const settings = JSON.parse(fs.readFileSync(file, 'utf8'));
        if (settings.cacheRoot === '/root/.stremio-server') {
          settings.cacheRoot = '${configDir}';
          fs.writeFileSync(file + '.migration', JSON.stringify(settings, null, 2), {mode: 0o600});
          fs.renameSync(file + '.migration', file);
        }
      }
      JS
    '';
    serviceConfig = {
      ExecStart = "${pkgs.nodejs_22}/bin/node ${server}/server.js";
      User = "stremio";
      Group = "stremio";
      StateDirectory = "stremio";
      StateDirectoryMode = "0700";
      WorkingDirectory = configDir;
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
      ProtectSystem = "strict";
      ReadWritePaths = [ configDir ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."${myDomain}" = {
      forceSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString stremioPort}";
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

  services.ddns.cloudflare.records = [
    {
      name = "stremio";
      zoneName = myZoneName;
      recordName = myDomain;
    }
  ];
}

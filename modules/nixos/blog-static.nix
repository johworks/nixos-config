{ ... }:

{
  #####################################################################
  # Ensure the directory exists on boot
  #####################################################################
  systemd.tmpfiles.rules = [
    "d /var/www/blog 0755 root root - -"
  ];

  #####################################################################
  # Nginx static blog
  #####################################################################
  services.nginx.virtualHosts."blog.goobhub.org" = {
    forceSSL = true;
    enableACME = true;
    root = "/var/www/blog";
    extraConfig = ''
      index index.html;
    '';
  };
}

{
  ...
}:

{
  sops.secrets."webapp_deploy_key" = {
    owner = "shinyapp";
    mode = "0400";
    path = "/run/secrets/webapp_deploy_key";
  };

  sops.secrets."google_ai" = {
    owner = "shinyapp";
    mode = "0400";
    path = "/run/secrets/google_ai";
  };

  sops.secrets."github_webhook" = {
    owner = "root";
    mode = "0400";
    path = "/run/secrets/github_webhook";
  };

  private.webapp = {
    enable = true;
    workDir = "/var/lib/shinyapp";
    port = 5000;

    reverseProxy = {
      enable = true;
      hostName = "kensfatcock.com";
      # ACME will fail until this is added as a CNAME.
      # serverAliases = [ "www.kensfatcock.com" ];
      enableACME = true;
      forceSSL = true;
    };

    environment = {
      GOOGLE_API_KEY = "/run/secrets/google_ai";
    };

    autoDeploy = {
      enable = true;
      repoUrl = "git+ssh://git@github.com/Cgilrein/super_secret_project.git";
      branch = "main";
      keyFile = /run/secrets/webapp_deploy_key;
      secretFile = /run/secrets/github_webhook;
      listenAddress = "127.0.0.1";
      listenPort = 9000;
    };
  };
}

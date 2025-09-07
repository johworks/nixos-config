{config, pkgs, ...}: 
let
  myDomain = "home.goobhub.org";
in 
{

  services.home-assistant = {
    enable = true;
    extraComponents = [
      #"analytics"
      "default_config"
      "esphome"
      #"my"
      "met"
      "radio_browser"
      "google_translate"  # Adding this because default_config needs it (remove later)
      #"shopping_list"
      #"wled"
    ];

    config = {
      default_config = {};

      # Turn W -> kWh
      sensor = [
        {
          platform = "integration";
          source = "sensor.ac_john_kauf_plug_power";
          name = "John AC Energy kWh";
          unit_prefix = "k";
          round = 3;
          method = "trapezoidal";
          unit_time = "h";
        }
      ];

      # Culumative counters
      utility_meter = {
        john_ac_energy_monthly = {
          source = "sensor.john_ac_energy_kwh";
          cycle = "monthly";
        };

        john_ac_energy_yearly = {
          source = "sensor.john_ac_energy_kwh";
          cycle = "yearly";
        };
      };


    };

    openFirewall = true;

  };

  # Let it through the firewall
  networking.firewall.allowedTCPPorts = [
    config.services.home-assistant.config.http.server_port
  ];


  ######################################################################
  ## Nginx reverse‑proxy with ACME
  ######################################################################
  #services.nginx = {
  #  enable = true;

  #  virtualHosts."${myDomain}" = {
  #    forceSSL   = true;
  #    enableACME = true;

  #    locations."/" = {
  #      proxyPass       = "http://127.0.0.1:8223";
  #      proxyWebsockets = true;
  #    };
  #  };

  #};


  ######################################################################
  ## ACME global settings
  ######################################################################
  #security.acme = {
  #  acceptTerms = true;
  #  # globally used for any host with enableACME = true
  #  defaults = {
  #    email  = "${myAcmeEmail}";
  #  };
  #};

  ######################################################################
  ## Firewall
  ######################################################################
  #networking.firewall = {
  #  allowedTCPPorts = [ 80 443 ];
  #  enable = true;
  #};


  # Make sure that we're connected before trying to start
  systemd.services.home-assistant.after = [ "network-online.target" ];
  systemd.services.home-assistant.wants = [ "network-online.target" ];

}

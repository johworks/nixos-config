{config, pkgs, ...}: 
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
    };

    openFirewall = true;

  };

  # Let it through the firewall
  networking.firewall.allowedTCPPorts = [
    config.services.home-assistant.config.http.server_port
  ];

  # Make sure that we're connected before trying to start
  systemd.services.home-assistant.after = [ "network-online.target" ];
  systemd.services.home-assistant.wants = [ "network-online.target" ];

}

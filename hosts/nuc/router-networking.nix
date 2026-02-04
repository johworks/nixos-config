{ pkgs, ... }:

{
  systemd.network.enable = true;

  networking = {
    networkmanager.enable = false; # use networkd for VLANs
    useNetworkd = true; # networkd handles VLANs + router config
    useDHCP = false;
    hostName = "john-nuc";
  };

  # Create VLAN interfaces on top of enp1s0
  systemd.network.netdevs = {
    # WAN
    "10-vlan10" = {
      netdevConfig = {
        Name = "vlan10";
        Kind = "vlan";
      };
      vlanConfig.Id = 10;
    };
    # LAN
    "20-vlan20" = {
      netdevConfig = {
        Name = "vlan20";
        Kind = "vlan";
      };
      vlanConfig.Id = 20;
    };
  };

  # Attach VLAN to parent NIC & assign addressing
  systemd.network.networks = {
    # Parent/trunk interface: no IP here, just carries VLANs
    "10-enp1s0" = {
      matchConfig.Name = "enp1s0";
      networkConfig = {
        VLAN = [ "vlan10" "vlan20" ];
        LinkLocalAddressing = "no"; # rely on VLAN interfaces
      };
    };

    # VLAN 10 interface (WAN)
    "20-vlan10" = {
      matchConfig.Name = "vlan10";
      DHCP = "yes"; # get IPv4 + IPv6 + PD from WAN
      networkConfig.IPv6AcceptRA = true;
      networkConfig.IPv6SendRA = false;
      networkConfig.IPv6PrivacyExtensions = true;
      # Required for RA/DHCPv6/PD to work.
      networkConfig.LinkLocalAddressing = "ipv6";
      dhcpV4Config.UseDNS = false; # ignore ISP DNS
      dhcpV6Config = {
        UseDNS = false; # ignore ISP DNS
        PrefixDelegationHint = "::/56";
        # Some ISPs don't set RA flags for DHCPv6-PD; solicit anyway.
        WithoutRA = "solicit";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    # VLAN 20 interface (LAN)
    "20-vlan20" = {
      matchConfig.Name = "vlan20";
      address = [ "192.168.10.1/24" ];
      networkConfig.IPv6AcceptRA = false;
      networkConfig.IPv6SendRA = true;
      networkConfig.DHCPPrefixDelegation = true;
      dhcpPrefixDelegationConfig = {
        SubnetId = "0x0";
        UplinkInterface = "vlan10";
      };
      # Required for RA to clients.
      networkConfig.LinkLocalAddressing = "ipv6";
      linkConfig.RequiredForOnline = "carrier";
    };
  };

  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = "1";
    # Prefer temporary IPv6 addresses for outbound connections (rotation).
    "net.ipv6.conf.vlan10.use_tempaddr" = 2;
  };

  # Enable IPv6 forwarding for routing.
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = 1;
  boot.kernel.sysctl."net.ipv6.conf.default.forwarding" = 1;

  # NAT between LAN (vlan20) and WAN (vlan10)
  networking.nat = {
    enable = true;
    externalInterface = "vlan10";
    internalInterfaces = [ "vlan20" ];
  };

  qos = {
    enable = true;
    wanInterface = "vlan10";
    downloadMbit = 900;
    uploadMbit = 780;
  };

  # DoH + DoT
  services.stubby = {
    enable = true;
    settings = pkgs.stubby.passthru.settingsExample // {
      appdata_dir = "/var/cache/stubby";
      upstream_recursive_servers = [
        # Cloudflare
        {
          address_data = "1.1.1.1";
          tls_auth_name = "cloudflare-dns.com";
        }
        # Quad9
        {
          address_data = "9.9.9.9";
          tls_auth_name = "dns.quad9.net";
        }
      ];
      listen_addresses = [
        "127.0.0.1@8053"
        "0::1@8053"
      ];
    };
  };

  # DNS + DHCP
  services.dnsmasq = {
    enable = true;
    settings = {
      # Include loopback so the host's resolver (127.0.0.1) works at boot.
      interface = [ "vlan20" "lo" ];
      bind-interfaces = true;

      # DNS config
      domain-needed = true;
      bogus-priv = true;
      no-resolv = true;
      server = [ "127.0.0.1#8053" ]; # -> stubby

      # DHCP pool for LAN
      dhcp-range = "192.168.10.50,192.168.10.200,24h";

      # Tell clients to send traffic to the router, and DNS here
      dhcp-option = [
        "option:router,192.168.10.1" # NUC LAN IP
        "option:dns-server,192.168.10.1" # NUC DNS
      ];

      # Make local names work
      domain = "lan";
      expand-hosts = true;
    };
  };

  networking.firewall.allowedTCPPorts = [ 53 ]; # DNS
  networking.firewall.allowedUDPPorts = [ 53 67 ]; # DNS + DHCP

  # Use stubby locally instead of ISP-provided resolvers
  networking.nameservers = [ "127.0.0.1" ];

  # Failed wireguard routing
  #wg-quick.interfaces = {
  #  wg0 = {
  #    configFile = "/etc/wireguard/wg0.conf";
  #    autostart = true;
  #  };
  #};
}

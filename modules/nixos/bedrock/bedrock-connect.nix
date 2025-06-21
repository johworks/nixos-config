{ ... }:
{
  virtualisation.oci-containers.containers = {
    bedrockconnect = {
      image = "strausmann/minecraft-bedrock-connect:latest";
      autoStart = true;

      ports = [
        "53:53/udp"
        "53:53/tcp"
        #"19132:19132/udp"  # your Bedrock server's port
      ];

      environment = {
        # Use your DDNS script with Cloudflare
        BEDROCK_SERVER_IP = "98.118.3.99";
        BEDROCK_SERVER_PORT = "19132";
      };

      extraOptions = [ 
        "--cap-add=NET_BIND_SERVICE"
        "--network=bedrockconnectnet"
      ];  # allow binding to port 53
    };
  };
}

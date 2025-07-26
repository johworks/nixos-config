{ ... }:
{
  virtualisation.oci-containers.containers = {
    bedrockconnect = {
      image = "strausmann/minecraft-bedrock-connect:latest";
      autoStart = true;

      ports = [
        "19132:19132/udp"  # Default minecraft server to trick bedrock
      ];

      environment = {
        CUSTOM_SERVERS = "";
      };
    };
  };
}

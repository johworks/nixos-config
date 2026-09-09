{ ... }:

{
  sops.secrets."home-assistant-mcp.env" = {
    sopsFile = ./home-assistant/secrets/mcp.env;
    format = "dotenv";
    owner = "john";
    group = "users";
    mode = "0400";
  };
}

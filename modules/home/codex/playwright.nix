{ lib, pkgs, ... }:
{
  # Nixpkgs supplies matching Playwright browsers with NixOS-compatible libraries.
  home.packages = [ pkgs.playwright-mcp ];

  codex.mcpServers.playwright = {
    command = lib.getExe pkgs.playwright-mcp;
    args = [
      "--headless"
      "--isolated"
    ];
    startup_timeout_sec = 30;
    default_tools_approval_mode = "approve";
  };
}

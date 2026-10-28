{ lib, ... }:
{
  boot.lanzaboote.enable = lib.mkForce false;
  boot.loader.systemd-boot.enable = lib.mkOverride 40 true;
  system.activationScripts.windows-boot-entry = lib.mkForce "";
}

{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostPkgs = config.virtualisation.host.pkgs;
  qemu =
    if hostPkgs.stdenv.hostPlatform.qemuArch == pkgs.stdenv.hostPlatform.qemuArch then
      hostPkgs.qemu_kvm
    else
      hostPkgs.qemu;
in
{
  # QEMU 11.1.2 tears down GBM before EGL, crashing on the desktop's Radeon.
  # Drop this backport once the selected nixpkgs includes the upstream fix:
  # https://github.com/qemu/qemu/commit/baca25172d8c195b9abbe6f8a3ab5915dba09a91
  virtualisation.qemu.package = lib.mkIf (qemu.version == "11.1.2") (
    lib.mkDefault (
      qemu.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./nixos-aj2-upstream.patch ];
      })
    )
  );
}

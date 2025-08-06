{ pkgs }:

pkgs.stdenv.mkDerivation {
  name = "gruvbox-plus";

  src = pkgs.fetchurl {
    url = "https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v6.2.0/gruvbox-plus-icon-pack-6.2.0.zip";
    sha256 = "0381sfksyff009654vky1dlj8jb8wx957cs9rxi88lq7wy38zr0g";
  };

  # We don't want it to unpack the .zip
  # That will happen in the installPhase below
  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    ${pkgs.unzip}/bin/unzip $src -d $out/
  '';
}

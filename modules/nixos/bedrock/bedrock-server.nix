{ pkgs, ... }:

pkgs.stdenv.mkDerivation {
  pname = "bedrock-server";
  version = "1.21.84.1";
  
  src = ./bedrock-server-1.21.84.1.zip;

  dontUnpack = true;

  installPhase = ''
    mkdir -p $out
    ${pkgs.unzip}/bin/unzip $src -d $out/
  '';

  meta = {
    description = "Minecraft Bedrock Dedicated Server";
    platforms = [ "x86_64-linux" ];
  };

}

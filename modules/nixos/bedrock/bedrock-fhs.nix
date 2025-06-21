{ pkgs }:

let
  wrapperScript = pkgs.writeShellScript "start-bedrock" ''
    cd /var/lib/bedrock
    exec ./bedrock_server
  '';
in
pkgs.buildFHSEnv {
  name = "bedrock-fhs";
  targetPkgs = pkgs: [
    pkgs.glibc
    pkgs.zlib
    pkgs.openssl
    pkgs.libuuid
    pkgs.curl
    pkgs.libsodium
  ];

  runScript = "${wrapperScript}";
}

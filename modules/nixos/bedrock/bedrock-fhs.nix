{ pkgs }:

let
  wrapperScript = pkgs.writeShellScript "start-bedrock" ''
    cd /var/lib/bedrock
    exec ./bedrock_server
  '';
in
pkgs.buildFHSUserEnv {
  name = "bedrock-fhs";
  targetPkgs = pkgs: [
    pkgs.glibc
    pkgs.zlib
    pkgs.openssl
    pkgs.libuuid
    pkgs.curl
    pkgs.libsodium
  ];

    #runScript = "${bedrock-server}/bedrock_server";
    #runScript = "cd /var/lib/bedrock && ./bedrock_server";
  runScript = "${wrapperScript}";
}

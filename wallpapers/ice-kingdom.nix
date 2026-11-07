{ pkgs }:
pkgs.runCommand "ice-kingdom.png" { nativeBuildInputs = [ pkgs.librsvg ]; } ''
  rsvg-convert -o "$out" ${./ice-kingdom.svg}
''

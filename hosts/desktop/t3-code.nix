{
  lib,
  appimageTools,
  codex,
  fetchurl,
  gh,
  git,
  makeWrapper,
}:

let
  pname = "t3code-desktop";
  version = "0.1.12";
  src = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/T3-Code-x86_64.AppImage";
    hash = "sha256-ZrkVUVcd9tKbVctZApXt9BHP+WyVqP6z9Bw8pZXXIuI=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  nativeBuildInputs = [ makeWrapper ];

  extraInstallCommands = ''
    wrapProgram "$out/bin/t3code-desktop" \
      --set T3CODE_DISABLE_AUTO_UPDATE 1 \
      --prefix PATH : ${
        lib.makeBinPath [
          codex
          gh
          git
        ]
      }
    # Use the same bundled server entry point as the upstream desktop CLI.
    makeWrapper "$out/bin/t3code-desktop" "$out/bin/t3" \
      --set ELECTRON_RUN_AS_NODE 1 \
      --add-flags ${contents}/resources/app.asar/apps/server/dist/bin.mjs

    install -Dm644 ${contents}/t3code.desktop "$out/share/applications/t3code.desktop"
    substituteInPlace "$out/share/applications/t3code.desktop" \
      --replace-fail "Exec=AppRun %U" "Exec=$out/bin/t3code-desktop %U"
    install -Dm644 ${contents}/t3code.png "$out/share/icons/hicolor/512x512/apps/t3code.png"
  '';

  meta = {
    description = "Desktop app for managing coding agents";
    homepage = "https://t3.codes/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = pname;
  };
}

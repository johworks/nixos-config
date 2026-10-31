{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "learnharness";
  version = "0.4.0";
  src = fetchurl {
    url = "https://github.com/amosblomqvist/learnharness/releases/download/v${version}/LearnHarness-${version}-x86_64.AppImage";
    hash = "sha256-LbsR4gEGf2Qu9a7isSKJDxEeFC3k6dZMtx5X765oDgM=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${contents}/learnharness.desktop $out/share/applications/learnharness.desktop
    substituteInPlace $out/share/applications/learnharness.desktop \
      --replace-fail "Exec=AppRun --no-sandbox %U" "Exec=$out/bin/learnharness %U"
    install -Dm644 ${contents}/learnharness.png $out/share/icons/hicolor/512x512/apps/learnharness.png
  '';

  meta = {
    description = "Adaptive teaching and practice with a persistent knowledge graph";
    homepage = "https://learnharness.ai/";
    license = lib.licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "learnharness";
  };
}

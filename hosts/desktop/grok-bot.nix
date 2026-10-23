{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "grok-bot";
  version = "0.75.5";
  # Release feed: https://api2.cursor.sh/updates/api/download/stable/linux-x64/sand
  src = fetchurl {
    url = "https://downloads.cursor.com/grokbot/stable/e4789bbe423912faa668dc29e013436280428fe6/linux/x64/Grok_Bot_${version}.AppImage";
    hash = "sha256-XF72qTA2xn/ualMMSjIl0eCvoWmV2CmXHq8K/sUJaaA=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    install -Dm644 ${contents}/grok-bot.desktop $out/share/applications/grok-bot.desktop
    substituteInPlace $out/share/applications/grok-bot.desktop \
      --replace-fail "Exec=AppRun --no-sandbox" "Exec=$out/bin/grok-bot"
    install -Dm644 ${contents}/grok-bot.png $out/share/icons/hicolor/512x512/apps/grok-bot.png
  '';

  meta = {
    description = "Grok Bot desktop agent";
    homepage = "https://x.ai/bot";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "grok-bot";
  };
}

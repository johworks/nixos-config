{
  inputs,
  pkgs,
  ...
}:

let
  voxtype = pkgs.voxtype-vulkan;
  overlay = inputs.voxtype.packages.${pkgs.stdenv.hostPlatform.system}.osd-gtk4;
  model = pkgs.fetchurl {
    url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo.bin";
    hash = "sha256-H8cPd0046xaZk6w5Huo1fvR8iHV+9y7llDh5t+jivGk=";
  };
  settings = pkgs.writeText "voxtype-config.toml" ''
    state_file = "auto"

    [hotkey]
    enabled = false

    [whisper]
    model = "${model}"

    [output]
    mode = "clipboard"

    [audio.feedback]
    enabled = true
  '';
in
{
  home.packages = [ voxtype ];

  programs.plasma.hotkeys.commands.voxtype = {
    name = "Toggle voice dictation";
    key = "Meta+Shift+D";
    command = "${voxtype}/bin/voxtype record toggle";
  };

  systemd.user.services.voxtype = {
    Unit = {
      Description = "Local voice dictation";
      PartOf = [ "graphical-session.target" ];
      After = [
        "graphical-session.target"
        "pipewire.service"
      ];
    };
    Service = {
      ExecStart = "${voxtype}/bin/voxtype --config ${settings} daemon";
      # wl-copy invokes cat to read piped transcripts from Voxtype.
      Environment = "PATH=${
        pkgs.lib.makeBinPath [
          overlay
          pkgs.wl-clipboard
          pkgs.coreutils
        ]
      }";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}

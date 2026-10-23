{
  lib,
  pkgs,
  pkgsUnstable,
  ...
}:
let
  # NixOS filters its system bundle, but certifi also references standalone cacert.
  blacklist = [
    "Comodo AAA Services root"
    "emSign ECC Root CA - G3"
    "emSign Root CA - C1"
    "emSign ECC Root CA - C3"
  ];
  packageSets = [ pkgs ] ++ lib.optional (pkgs.path != pkgsUnstable.path) pkgsUnstable;
  pipWheel = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl";
    sha256 = "fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70";
  };

  replacementsFor =
    packages:
    let
      cacert = packages.cacert.override { inherit blacklist; };
      pythonReplacements =
        python:
        let
          certifi = python.pkgs.certifi;
          pip = python.pkgs.pip;
        in
        [
          {
            # New venvs must not bootstrap pip from CPython's old bundled wheel.
            oldDependency = python;
            newDependency = python.overrideAttrs (old: {
              postInstall = (old.postInstall or "") + ''
                ensurepipDir="$out/lib/${python.libPrefix}/ensurepip"
                ensurepipWheel=$(basename "$ensurepipDir"/_bundled/pip-*.whl)
                ensurepipVersion="''${ensurepipWheel#pip-}"
                ensurepipVersion="''${ensurepipVersion%%-*}"
                if [ "$(printf '%s\n' "$ensurepipVersion" 26.2.2 | sort -V | head -n1)" != 26.2.2 ]; then
                  rm "$ensurepipDir"/_bundled/pip-*.whl
                  cp ${pipWheel} "$ensurepipDir/_bundled/pip-26.2.2-py3-none-any.whl"
                  sed -i 's/^_PIP_VERSION = .*/_PIP_VERSION = "26.2.2"/' "$ensurepipDir/__init__.py"
                fi
              '';
            });
          }
          {
            oldDependency = certifi;
            newDependency = certifi.override { inherit cacert; };
          }
          {
            oldDependency = pip;
            newDependency = pip.overridePythonAttrs (old: {
              postPatch = (old.postPatch or "") + ''
                cp ${cacert}/etc/ssl/certs/ca-bundle.crt src/pip/_vendor/certifi/cacert.pem
              '';
            });
          }
        ];
    in
    [
      {
        oldDependency = packages.cacert;
        newDependency = cacert;
      }
    ]
    ++
      lib.optional (packages ? electron_42 && lib.versionOlder packages.electron_42.version "42.11.16")
        {
          oldDependency = packages.electron_42.unwrapped;
          newDependency = packages.electron_42-bin.overrideAttrs (_: {
            # Reference rewriting requires the replacement name to keep its length.
            pname = packages.electron_42.unwrapped.pname;
            version = "42.11.16";
            src = packages.fetchurl {
              url = "https://github.com/electron/electron/releases/download/v42.11.16/electron-v42.11.16-linux-x64.zip";
              sha256 = "e27e9ec78d12edc83c817a1454b706530c000eedd217f65aed2a5d9657ec1be0";
            };
          });
        }
    ++ lib.concatMap pythonReplacements (
      lib.unique [
        packages.python3
        packages.python311
        packages.python313
      ]
    );
in
{
  # Temporary security hotfixes while upstream packages lag. Rewriting references
  # avoids recompiling the desktop's build toolchains for a CA-list change.
  system.replaceDependencies.replacements = lib.concatMap replacementsFor packageSets;
}

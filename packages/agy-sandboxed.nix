{ lib
, writeShellApplication
, bubblewrap
, coreutils
, agy-bin
, cacert
}:

writeShellApplication {
  name = "agy-sandboxed";

  runtimeInputs = [
    bubblewrap
    coreutils
  ];

  text = ''
    set -euo pipefail

    workspace="''${AGY_SANDBOX_WORKSPACE:-$PWD}"
    sandbox_root="''${AGY_SANDBOX_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/antigravity-cli-sandbox}"
    sandbox_home="$sandbox_root/home"
    sandbox_tmp="$sandbox_root/tmp"

    mkdir -p "$sandbox_home" "$sandbox_tmp"

    workspace="$(realpath "$workspace")"
    sandbox_home="$(realpath "$sandbox_home")"
    sandbox_tmp="$(realpath "$sandbox_tmp")"

    if [ ! -d "$workspace" ]; then
      echo "AGY_SANDBOX_WORKSPACE must point to a directory: $workspace" >&2
      exit 1
    fi

    env -i ${bubblewrap}/bin/bwrap \
      --die-with-parent \
      --unshare-all \
      --share-net \
      --proc /proc \
      --dev /dev \
      --ro-bind /nix/store /nix/store \
      --ro-bind /etc/resolv.conf /etc/resolv.conf \
      --ro-bind /etc/hosts /etc/hosts \
      --bind "$workspace" /workspace \
      --bind "$sandbox_home" /home/agy \
      --bind "$sandbox_tmp" /tmp \
      --chdir /workspace \
      --setenv HOME /home/agy \
      --setenv USER agy \
      --setenv LOGNAME agy \
      --setenv XDG_CONFIG_HOME /home/agy/.config \
      --setenv XDG_CACHE_HOME /home/agy/.cache \
      --setenv XDG_DATA_HOME /home/agy/.local/share \
      --setenv SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --setenv PATH ${lib.makeBinPath [ agy-bin coreutils ]} \
      ${lib.getExe agy-bin} "$@"
  '';

  meta = with lib; {
    description = "Hardened sandbox wrapper for the pinned Google Antigravity CLI binary";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = licenses.mit;
    mainProgram = "agy-sandboxed";
    platforms = platforms.linux;
  };
}

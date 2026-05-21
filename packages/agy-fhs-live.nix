{ lib
, stdenv
, buildFHSEnv
, writeShellScript
, bash
, cacert
, coreutils
, curl
, git
, gnugrep
, gnused
, gnutar
, gzip
, xdg-utils
}:

let
  runner = writeShellScript "agy-live-runner" ''
    set -euo pipefail

    installer_url="https://antigravity.google/cli/install.sh"
    install_dir="''${ANTIGRAVITY_CLI_HOME:-''${XDG_DATA_HOME:-$HOME/.local/share}/antigravity-cli}"
    mkdir -p "$install_dir"

    discover_download_base_url() {
      ${curl}/bin/curl -fsSL "$installer_url" \
        | sed -n 's/^DOWNLOAD_BASE_URL="\([^"]*\)"/\1/p'
    }

    parse_json_key() {
      local payload="$1"
      local key="$2"
      echo "$payload" | sed -n 's/.*"'"$key"'"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
    }

    detect_platform() {
      local os arch

      case "$(uname -s)" in
        Linux) os="linux" ;;
        *) echo "unsupported operating system: $(uname -s)" >&2; exit 1 ;;
      esac

      case "$(uname -m)" in
        x86_64|amd64) arch="amd64" ;;
        arm64|aarch64) arch="arm64" ;;
        *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;;
      esac

      echo "''${os}_''${arch}"
    }

    if [ ! -x "$install_dir/agy" ]; then
      platform="$(detect_platform)"
      download_base_url="$(discover_download_base_url)"

      if [ -z "$download_base_url" ]; then
        echo "failed to discover Antigravity CLI download base URL from $installer_url" >&2
        exit 1
      fi

      manifest="$(${curl}/bin/curl -fsSL "$download_base_url/manifests/$platform.json")"
      url="$(parse_json_key "$manifest" "url")"
      sha512="$(parse_json_key "$manifest" "sha512")"

      if [ -z "$url" ] || [ -z "$sha512" ]; then
        echo "failed to parse Antigravity CLI manifest for $platform" >&2
        exit 1
      fi

      staging_dir="$(mktemp -d "''${TMPDIR:-/tmp}/agy-live.XXXXXX")"
      cleanup() {
        rm -rf "$staging_dir"
      }
      trap cleanup EXIT

      payload="$staging_dir/agy.tar.gz"
      ${curl}/bin/curl -fsSL "$url" -o "$payload"

      actual_hash="$(sha512sum "$payload" | cut -d' ' -f1)"
      if [ "$actual_hash" != "$sha512" ]; then
        echo "checksum mismatch while downloading Antigravity CLI" >&2
        exit 1
      fi

      tar -xzf "$payload" -C "$staging_dir" antigravity
      install -m 0755 "$staging_dir/antigravity" "$install_dir/agy"
    fi

    exec "$install_dir/agy" "$@"
  '';
in
buildFHSEnv {
  name = "agy";

  targetPkgs = pkgs: [
    bash
    cacert
    coreutils
    curl
    git
    gnugrep
    gnused
    gnutar
    gzip
    xdg-utils
  ];

  runScript = runner;

  meta = with lib; {
    description = "Mutable FHS wrapper for Google Antigravity CLI";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = licenses.unfree;
    mainProgram = "agy";
    platforms = platforms.linux;
  };
}

#!/usr/bin/env bash
set -euo pipefail

installer_url="https://antigravity.google/cli/install.sh"

installer="$(curl -fsSL "$installer_url")"
download_base_url="$(sed -n 's/^DOWNLOAD_BASE_URL="\([^"]*\)"/\1/p' <<<"$installer")"

if [[ -z "$download_base_url" ]]; then
  echo "failed to discover DOWNLOAD_BASE_URL from $installer_url" >&2
  exit 1
fi

platforms=(
  "x86_64-linux:linux_amd64"
  "aarch64-linux:linux_arm64"
  "x86_64-darwin:darwin_amd64"
  "aarch64-darwin:darwin_arm64"
)

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

build_id=""
pin_json="{}"

for item in "${platforms[@]}"; do
  nix_system="${item%%:*}"
  manifest_platform="${item##*:}"
  manifest_url="${download_base_url}/manifests/${manifest_platform}.json"

  manifest="$(curl -fsSL "$manifest_url")"
  manifest_version="$(jq -r '.version' <<<"$manifest")"
  url="$(jq -r '.url' <<<"$manifest")"

  if [[ "$manifest_version" == "null" || "$url" == "null" ]]; then
    echo "failed to parse manifest: $manifest_url" >&2
    exit 1
  fi

  current_build_id="$(sed -E 's#^.*/antigravity-cli/([^/]+)/.*$#\1#' <<<"$url")"

  if [[ -z "$build_id" ]]; then
    build_id="$current_build_id"
    pin_json="$(jq -n --arg version "$build_id" '{version: $version, sources: {}}')"
  elif [[ "$build_id" != "$current_build_id" ]]; then
    echo "manifest build mismatch: expected $build_id, got $current_build_id for $nix_system" >&2
    exit 1
  fi

  payload="$tmp/agy-${nix_system}.tar.gz"
  curl -fsSL "$url" -o "$payload"
  hash="$(nix hash file --type sha256 "$payload")"

  pin_json="$(jq \
    --arg system "$nix_system" \
    --arg url "$url" \
    --arg hash "$hash" \
    '.sources[$system] = {url: $url, hash: $hash}' \
    <<<"$pin_json")"

  echo "processed $nix_system: $hash"
done

jq --sort-keys . <<<"$pin_json" > packages/pin.json
echo "updated packages/pin.json to version $build_id"

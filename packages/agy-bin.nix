{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeWrapper
, writeShellApplication
, cacert
, curl
, jq
, nix
}:

let
  pname = "agy-bin";
  pin = lib.importJSON ./pin.json;
  system = stdenv.hostPlatform.system;
  source = pin.sources.${system} or (throw "Unsupported system: ${system}");
in
stdenv.mkDerivation {
  inherit pname;
  version = pin.version;

  src = fetchurl {
    inherit (source) url hash;
  };

  nativeBuildInputs = [ makeWrapper ]
    ++ lib.optional stdenv.hostPlatform.isLinux autoPatchelfHook;

  buildInputs = lib.optional stdenv.hostPlatform.isLinux stdenv.cc.cc.lib;

  dontConfigure = true;
  dontBuild = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    install -m 0755 antigravity $out/bin/agy
    wrapProgram $out/bin/agy \
      --prefix SSL_CERT_FILE : ${cacert}/etc/ssl/certs/ca-bundle.crt

    runHook postInstall
  '';

  passthru.updateScript = [
    (lib.getExe (writeShellApplication {
      name = "update-agy";
      runtimeInputs = [
        curl
        jq
        nix
      ];
      text = builtins.readFile ./../scripts/update-pinned.sh;
    }))
  ];

  meta = with lib; {
    description = "Pinned binary package for Google Antigravity CLI";
    homepage = "https://antigravity.google/product/antigravity-cli";
    license = licenses.unfree;
    mainProgram = "agy";
    platforms = attrNames pin.sources;
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}

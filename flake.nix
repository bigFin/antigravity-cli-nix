{
  description = "Nix wrappers for the closed-source Google Antigravity CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          lib = pkgs.lib;
          agy-bin = pkgs.callPackage ./packages/agy-bin.nix { };
          agy-fhs-live = pkgs.callPackage ./packages/agy-fhs-live.nix { };
          agy-sandboxed = pkgs.callPackage ./packages/agy-sandboxed.nix {
            inherit agy-bin;
          };
        in
        {
          formatter = pkgs.nixpkgs-fmt;

          packages = {
            inherit agy-bin;
            default = if pkgs.stdenv.hostPlatform.isLinux then agy-fhs-live else agy-bin;
          } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            inherit agy-fhs-live agy-sandboxed;
          };

          apps = {
            default =
              if pkgs.stdenv.hostPlatform.isLinux
              then self.apps.${system}.agy-fhs-live
              else self.apps.${system}.agy-bin;
            agy-bin = {
              type = "app";
              program = "${self.packages.${system}.agy-bin}/bin/agy";
              meta.description = "Run the pinned Antigravity CLI binary";
            };
          } // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
            agy-fhs-live = {
              type = "app";
              program = "${self.packages.${system}.agy-fhs-live}/bin/agy";
              meta.description = "Run the mutable Antigravity CLI FHS wrapper";
            };
            agy-sandboxed = {
              type = "app";
              program = "${self.packages.${system}.agy-sandboxed}/bin/agy-sandboxed";
              meta.description = "Run the pinned Antigravity CLI in a stricter bubblewrap sandbox";
            };
          };

          devShells.default = pkgs.mkShell {
            packages = with pkgs; [
              curl
              jq
              nix
              nixpkgs-fmt
            ];
          };
        }) // {
      overlays.default = final: prev: {
        agy-bin = final.callPackage ./packages/agy-bin.nix { };
      } // prev.lib.optionalAttrs prev.stdenv.hostPlatform.isLinux {
        agy-fhs-live = final.callPackage ./packages/agy-fhs-live.nix { };
        agy-sandboxed = final.callPackage ./packages/agy-sandboxed.nix {
          agy-bin = final.agy-bin;
        };
      };
    };
}

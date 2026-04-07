{
  description = "OpenJKDF2 - Function-by-function reimplementation of Jedi Knight: Dark Forces II";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        crossPkgs = import nixpkgs {
          inherit system;
          crossSystem = { config = "x86_64-w64-mingw32"; };
        };

        version = "0.9.8";
        gitRev = if self ? rev then self.rev else "dirty";
        gitRevShort = builtins.substring 0 8 gitRev;

        commonBuildInputs = with pkgs; [
          cmake
          gnumake
          pkg-config
          python3
          python3Packages.cogapp
          bison
        ];

        linuxPackage = pkgs.stdenv.mkDerivation {
          pname = "openjkdf2";
          inherit version;

          src = self;

          nativeBuildInputs = commonBuildInputs ++ [ pkgs.clang ];

          buildInputs = with pkgs; [
            SDL2
            SDL2_mixer
            openal
            glew
            libpng
            zlib
            curl
            protobuf
            gtk3
            libGL
          ];

          # Submodules are needed for vendored deps
          # In a real flake, these would be fetched as separate inputs
          # For now, the source must include initialized submodules
          preConfigure = ''
            export OPENJKDF2_RELEASE_COMMIT="${gitRev}"
            export OPENJKDF2_RELEASE_COMMIT_SHORT="${gitRevShort}"
            export CC=clang
            export CXX=clang++
          '';

          cmakeFlags = [
            "-DPLAT_LINUX_64=TRUE"
          ];

          # Build protobuf first (vendored), then the main target
          buildPhase = ''
            make -j$NIX_BUILD_CORES PROTOBUF || make -j1 PROTOBUF
            make -j$NIX_BUILD_CORES openjkdf2
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib
            cp openjkdf2 $out/bin/
            # Copy shared libs if present
            for lib in *.so *.so.*; do
              [ -f "$lib" ] && cp "$lib" $out/lib/ || true
            done
          '';

          meta = with pkgs.lib; {
            description = "Open-source reimplementation of Star Wars Jedi Knight: Dark Forces II";
            homepage = "https://github.com/shinyquagsire23/OpenJKDF2";
            license = licenses.mit;
            platforms = [ "x86_64-linux" "aarch64-linux" ];
            mainProgram = "openjkdf2";
          };
        };

      in {
        packages = {
          default = linuxPackage;
          openjkdf2 = linuxPackage;

          # Win64 cross-compilation placeholder
          # Requires MinGW toolchain - complex due to vendored deps
          # Use: nix build .#openjkdf2-win64
          # openjkdf2-win64 = ...;
        };

        devShells.default = pkgs.mkShell {
          inputsFrom = [ linuxPackage ];
          packages = with pkgs; [
            gdb
            valgrind
            ghidra
          ];
          shellHook = ''
            export OPENJKDF2_RELEASE_COMMIT="$(git log -1 --format='%H' 2>/dev/null || echo dev)"
            export OPENJKDF2_RELEASE_COMMIT_SHORT="$(git rev-parse --short=8 HEAD 2>/dev/null || echo dev)"
            export CC=clang
            export CXX=clang++
            echo "OpenJKDF2 dev shell ready"
            echo "  Build: mkdir -p build && cd build && cmake .. && make -j\$(nproc) PROTOBUF && make -j\$(nproc) openjkdf2"
          '';
        };
      }
    );
}

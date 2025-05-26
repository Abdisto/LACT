{
  description = "A flake for the waypaper package";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    packages.x86_64-linux = let
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfree = true;
      };
    in {
      default = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lact";
        version = "unstable";

        src = ./.;

        useFetchCargoVendor = true;
        cargoHash = "sha256-ZCkPKFv3I8RGGiEZOqdFTyvG5UxLaDBhG1qYiBIUhG4=";
        doCheck = false;

        nativeBuildInputs = with pkgs; [
          blueprint-compiler
          pkg-config
          wrapGAppsHook4
          clang
          llvmPackages.libclang
          llvmPackages.bintools
          rustPlatform.bindgenHook
        ];

        buildInputs = with pkgs; [
          gdk-pixbuf
          gtk4
          libdrm
          vulkan-loader
          hwdata
          coreutils
          ocl-icd
          fuse3
        ];

        checkFlags = [
          # tries and fails to initialize gtk
          "--skip=app::pages::thermals_page::fan_curve_frame::tests::set_get_curve"
        ];

        postPatch = ''
          substituteInPlace lact-daemon/src/server/system.rs \
            --replace-fail 'Command::new("uname")' 'Command::new("${pkgs.coreutils}/bin/uname")'

          substituteInPlace res/lactd.service \
            --replace-fail ExecStart={lact,$out/bin/lact}

          if [ -f res/io.github.lact-linux.desktop ]; then
            substituteInPlace res/io.github.lact-linux.desktop \
              --replace-fail Exec={lact,$out/bin/lact}
          fi

          pushd $cargoDepsCopy/pciid-parser
          oldHash=$(sha256sum src/lib.rs | cut -d " " -f 1)
          substituteInPlace src/lib.rs --subst-var-by hwdata ${pkgs.hwdata}
          substituteInPlace .cargo-checksum.json \
            --replace $oldHash $(sha256sum src/lib.rs | cut -d " " -f 1)
          popd
        '';

        postInstall = ''
          install -Dm444 res/lactd.service -t $out/lib/systemd/system
          if [ -f res/io.github.lact-linux.desktop ]; then
            install -Dm444 res/io.github.lact-linux.desktop -t $out/share/applications
          fi
        '';

        postFixup = pkgs.lib.optionalString pkgs.stdenv.targetPlatform.isElf ''
          patchelf $out/bin/.lact-wrapped --add-needed libvulkan.so --add-rpath ${
            pkgs.lib.makeLibraryPath [ pkgs.vulkan-loader ]
          }
        '';

        meta = {
          description = "Linux GPU Configuration Tool for AMD and NVIDIA";
          homepage = "https://github.com/ilya-zlobintsev/LACT";
          license = pkgs.lib.licenses.mit;
          maintainers = with pkgs.lib.maintainers; [
            figsoda
            atemu
          ];
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "lact";
        };
      };
    };
  };
}
    
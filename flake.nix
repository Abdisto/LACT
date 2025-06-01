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
          vulkan-tools
          hwdata
          coreutils
          ocl-icd
          fuse3
          autoAddDriverRunpath
          nixosTests
          nix-update-script
          systemdMinimal
          lib
        ];

        checkFlags = [
          # tries and fails to initialize gtk
          "--skip=app::pages::thermals_page::fan_curve_frame::tests::set_get_curve"
        ];

        postPatch = ''
          substituteInPlace lact-daemon/src/server/system.rs \
            --replace-fail 'Command::new("uname")' 'Command::new("${pkgs.coreutils}/bin/uname")'
          substituteInPlace lact-daemon/src/server/profiles.rs \
            --replace-fail 'Command::new("uname")' 'Command::new("${pkgs.coreutils}/bin/uname")'
      
          substituteInPlace lact-daemon/src/server/handler.rs \
            --replace-fail 'Command::new("journalctl")' 'Command::new("${pkgs.systemdMinimal}/bin/journalctl")'
      
          substituteInPlace lact-daemon/src/server/vulkan.rs \
            --replace-fail 'Command::new("vulkaninfo")' 'Command::new("${pkgs.vulkan-tools}/bin/vulkaninfo")'
      
          substituteInPlace res/lactd.service \
            --replace-fail ExecStart={lact,$out/bin/lact}
      
          substituteInPlace res/io.github.ilya_zlobintsev.LACT.desktop \
            --replace-fail Exec={lact,$out/bin/lact}
      
          # read() looks for the database in /usr/share so we use read_from_file() instead
          substituteInPlace lact-daemon/src/server/handler.rs \
            --replace-fail 'Database::read()' 'Database::read_from_file("${pkgs.hwdata}/share/hwdata/pci.ids")'
        '';

        postInstall = ''
          install -Dm444 res/lactd.service -t $out/lib/systemd/system
          install -Dm444 res/io.github.ilya_zlobintsev.LACT.desktop -t $out/share/applications
          install -Dm444 res/io.github.ilya_zlobintsev.LACT.svg -t $out/share/pixmaps
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
            cything
            figsoda
            johnrtitor
            atemu
          ];
          platforms = pkgs.lib.platforms.linux;
          mainProgram = "lact";
        };
      };
    };
  };
}
    

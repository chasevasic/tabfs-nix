{
  description = "TabFS fuse module";
  inputs.nixpkgs.url = "nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
  let
    lastModifiedDate = self.lastModifiedDate or self.lastModified or "19700101";
    version = builtins.substring 0 8 lastModifiedDate;
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    src = pkgs.fetchFromGitHub {
          owner = "osnr";
          repo = "TabFS";
          rev = "master/HEAD";
          hash = "sha256-PEb2pk46PWzjA6Bo9aDhxc+vAC6q5l4iCI01U8HodvU=";
        };
  in
  rec {
    packages.x86_64-linux.default = tabfs-extension;

    tabfs-fuse =
      pkgs.stdenv.mkDerivation {
        pname = "tabfs-fuse";
        inherit version;
        src = src + "/fs";

        preBuild = with pkgs; ''
            export CFLAGS="-O2 -I${fuse}/include/fuse -L${fuse}/lib"
        '';

        installPhase = ''
            mkdir -p $out/bin
            cp tabfs $out/bin/.tabfs-wrapped
            cat <<-END_WRAPPER > $out/bin/tabfs
							#! ${pkgs.bash}/bin/bash -e
							export TABFS_MOUNT_DIR="/run/user/\$(id -u)/tabfs"
							mkdir -p "\$TABFS_MOUNT_DIR"
							exec -a "$0" "$out/bin/.tabfs-wrapped" "\$@"
						END_WRAPPER
            chmod +x $out/bin/*
            '';

      };
      tabfs-extension =
      pkgs.stdenv.mkDerivation {
        pname = "tabfs-extension";
        inherit version;
        inherit src;

        nativeBuildInputs = with pkgs; [ zip ];

        preBuild = with pkgs; ''
            export CFLAGS="-O2 -I${fuse}/include/fuse -L${fuse}/lib"
        '';

        # TODO: install native-messaging-host to /run/current-system/sw/lib/{browser}/native-messaging-hosts

        installPhase = ''
            mkdir -p $out/bin
            mkdir -p $out/lib/{firefox,librewolf}/browser/extensions
            mkdir -p $out/share/chromium/extensions
            find $out

            substitute ./install.sh $out/bin/tabfs-install-native-messaging-host \
              --replace 'EXE_PATH=$(pwd)/fs/tabfs' EXE_PATH="${tabfs-fuse}/bin/tabfs"
            chmod +x $out/bin/*

            cd extension

            cp -r . $out/tabfs

            zip -r $out/lib/firefox/browser/extensions/tabfs@rsnous.com.xpi ./*

            for target in  \
              $out/lib/{librewolf,firefox}/browser/extensions/tabfs@rsnous.com \
              $out/share/chromium/extensions/tabfs
            do
              ln -T -s $out/tabfs $target
            done
        '';

      };
    };
  }

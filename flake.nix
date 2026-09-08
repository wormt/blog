{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wormtpkgs.url = "github:wormt/nixpkgs";
    roc-overlay.url = "github:roc-lang/roc-overlay";
    roc-overlay.inputs.nixpkgs.follows = "nixpkgs";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "wormtpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "wormtpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "wormtpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
    nix-image.url = "path:./nix";
    osbuild-src = {
      url = "github:osbuild/osbuild/05d245c8e9a4615bc05b9bbcd79324625d24cfbc";
      flake = false;
    };
  };

  outputs =
    {
      wormtpkgs,
      roc-overlay,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
      nix-image,
      osbuild-src,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = wormtpkgs.legacyPackages.${system};

      sass = pkgs.dart-sass;

      vhdWorkspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = ./scripts/vhd;
      };
      vhdPythonBase = pkgs.callPackage pyproject-nix.build.packages {
        python = pkgs.python314;
      };
      vhdPython = vhdPythonBase.overrideScope (
        pkgs.lib.composeManyExtensions [
          pyproject-build-systems.overlays.wheel
          (vhdWorkspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          })
        ]
      );
      vhdEnv = vhdPython.mkVirtualEnv "vhd-env" vhdWorkspace.deps.default;
      vhdDevEnv = vhdPython.mkVirtualEnv "vhd-dev-env" vhdWorkspace.deps.all;
      bootcHostPrepareRoot = pkgs.writeText "bootc-host-prepare-root.conf" ''
        [composefs]
        enabled = yes
        [sysroot]
        readonly = true
      '';
      osbuildModules = pkgs.runCommand "osbuild-modules-193" { nativeBuildInputs = [ vhdEnv ]; } ''
        mkdir -p "$out"
        cp -R \
          ${osbuild-src}/devices \
          ${osbuild-src}/inputs \
          ${osbuild-src}/mounts \
          ${osbuild-src}/osbuild \
          ${osbuild-src}/runners \
          ${osbuild-src}/schemas \
          ${osbuild-src}/sources \
          ${osbuild-src}/stages \
          "$out/"
        chmod -R u+w "$out"
        patchShebangs "$out"
        substituteInPlace "$out/osbuild/buildroot.py" \
          --replace-fail \
            '        mounts = []' \
            '        mounts = ["--dir", "/nix", "--ro-bind", "/nix/store", "/nix/store"]' \
          --replace-fail \
            '            "PATH": "/usr/sbin:/usr/bin",' \
            '            "PATH": os.getenv("PATH", "/usr/sbin:/usr/bin"),' \
          --replace-fail \
            '        mounts += ["--dir", "/etc"]' \
            '        mounts += ["--dir", "/etc"]
        mounts += ["--dir", "/etc/ostree"]
        mounts += ["--ro-bind", "${bootcHostPrepareRoot}", "/etc/ostree/prepare-root.conf"]'

        test -f "$out/osbuild/__init__.py"
        grep -Fq -- '"--ro-bind", "/nix/store", "/nix/store"' "$out/osbuild/buildroot.py"
        grep -Fq -- '"PATH": os.getenv("PATH"' "$out/osbuild/buildroot.py"
        grep -Fq -- '"/etc/ostree/prepare-root.conf"' "$out/osbuild/buildroot.py"
      '';
      vhdRuntimeInputs = [
        vhdEnv
        pkgs.bootc
        pkgs.bubblewrap
        pkgs.coreutils
        pkgs.curl
        pkgs.e2fsprogs
        pkgs.qemu-utils
        pkgs.skopeo
        pkgs.util-linux
      ];
      imageTar = nix-image.packages.${system}.imageTar;
      vhd = pkgs.writeShellApplication {
        name = "blog-vhd";
        runtimeInputs = vhdRuntimeInputs;
        text = ''
          if (( EUID != 0 )); then
            echo "blog-vhd must run as root because osbuild needs loop devices and mount privileges" >&2
            exit 1
          fi
          if (( $# != 1 )); then
            echo "usage: blog-vhd OUTPUT.vhd" >&2
            exit 2
          fi

          export PYTHONPATH=${osbuildModules}''${PYTHONPATH:+:$PYTHONPATH}
          exec python ${./scripts/vhd/vhd.py} \
            --libdir ${osbuildModules} \
            --skopeo ${pkgs.skopeo}/bin/skopeo \
            ${imageTar}/image.tar \
            "$1"
        '';
      };
    in
    {
      packages.${system} = {
        default = vhd;
        inherit imageTar vhd;
      };

      apps.${system} = {
        vhd = {
          type = "app";
          program = "${vhd}/bin/blog-vhd";
        };

        build = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-build";
              runtimeInputs = [
                roc-overlay.packages.${system}.nightly
              ];
              text = ''
                echo "[blog] building renderer..."
                roc build package/Render.roc --output=render
              '';
            }
          }/bin/blog-build";
        };

        css = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-css";
              runtimeInputs = [
                sass
                pkgs.lightningcss
              ];
              text = ''
                echo "[blog] processing CSS..."
                sass --style=expanded --no-source-map package/styles/main.scss | lightningcss --minify -o www/css/site.css
                for f in article base home; do
                  sass --style=expanded --no-source-map package/styles/$f.scss | lightningcss --minify -o www/css/$f.css
                done
              '';
            }
          }/bin/blog-css";
        };

        ssg = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-ssg";
              runtimeInputs = [ pkgs.coreutils ];
              text = ''
                echo "[blog] rendering HTML..."
                exec ./render ./content/ ./www/
              '';
            }
          }/bin/blog-ssg";
        };

        render = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-render";
              runtimeInputs = [
                sass
                pkgs.coreutils
                pkgs.lightningcss
              ];
              text = ''
                echo "[blog] processing CSS..."
                sass --style=expanded --no-source-map package/styles/main.scss | lightningcss --minify -o www/css/site.css
                for f in article base home; do
                  sass --style=expanded --no-source-map package/styles/$f.scss | lightningcss --minify -o www/css/$f.css
                done
                echo "[blog] rendering HTML..."
                exec ./render ./content/ ./www/
              '';
            }
          }/bin/blog-render";
        };

        all = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-all";
              runtimeInputs = [
                roc-overlay.packages.${system}.nightly
                sass
                pkgs.coreutils
                pkgs.lightningcss
              ];
              text = ''
                echo "[blog] building renderer..."
                roc build package/Render.roc --output=render
                echo "[blog] processing CSS..."
                sass --style=expanded --no-source-map package/styles/main.scss | lightningcss --minify -o www/css/site.css
                for f in article base home; do
                  sass --style=expanded --no-source-map package/styles/$f.scss | lightningcss --minify -o www/css/$f.css
                done
                echo "[blog] rendering HTML..."
                exec ./render ./content/ ./www/
              '';
            }
          }/bin/blog-all";
        };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          roc-overlay.packages.${system}.nightly
          pkgs.nixd
          pkgs.nixfmt
          pkgs.racket
          pkgs.opentofu
          pkgs.tofu-ls
          pkgs.yamllint
          pkgs.just
          pkgs.just-lsp
          pkgs.nushell
          sass
          pkgs.lightningcss
          pkgs.javaPackages.compiler.temurin-bin.jdk-25
          pkgs.jdt-language-server
          pkgs.lombok
          pkgs.azure-cli
          pkgs.pulumi
          pkgs.pulumiPackages.pulumi-java
          pkgs.pulumiPackages.pulumi-azure-native
          pkgs.pulumiPackages.pulumi-random
          pkgs.google-java-format
          pkgs.gradle
          pkgs.uv
          vhdDevEnv
        ];

        shellHook = ''
          export LOMBOK_PATH="${pkgs.lombok}/share/java/lombok.jar"
          raco pkg install --auto --skip-installed --user racket-langserver
        '';
      };
    };
}

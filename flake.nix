{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wormtpkgs.url = "github:wormt/nixpkgs";
    roc-overlay.url = "github:roc-lang/roc-overlay";
    roc-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { wormtpkgs, roc-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = wormtpkgs.legacyPackages.${system};
      sass = pkgs.sass;
    in
    {
      apps.${system} = {
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
                sass --style=expanded --sourcemap=none package/styles/main.scss | lightningcss --minify -o www/site.css
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
                sass --style=expanded --sourcemap=none package/styles/main.scss | lightningcss --minify -o www/site.css
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
                sass --style=expanded --sourcemap=none package/styles/main.scss | lightningcss --minify -o www/site.css
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
          pkgs.opentofu
          pkgs.tofu-ls
          pkgs.just
          pkgs.just-lsp
          pkgs.nushell
          pkgs.sass
          pkgs.lightningcss
          pkgs.javaPackages.compiler.temurin-bin.jdk-25 
          pkgs.pulumi
          pkgs.pulumiPackages.pulumi-java
          pkgs.gradle
        ];
      };
    };
}

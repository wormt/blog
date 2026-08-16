{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    roc-overlay.url = "github:roc-lang/roc-overlay";
    roc-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    { nixpkgs, roc-overlay, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
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
              runtimeInputs = [ sass ];
              text = ''
                sass --style=expanded --sourcemap=none package/styles/main.scss > www/site.css
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
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          roc-overlay.packages.${system}.nightly
          pkgs.nixd
          pkgs.nixfmt
          pkgs.nushell
          pkgs.just
          pkgs.just-lsp
          pkgs.sass
          pkgs.lightningcss
        ];
      };
    };
}

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
        css = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-css";
              runtimeInputs = [ sass ];
              text = ''
                sass --style=expanded --sourcemap=none site.scss > www/site.css
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
                exec ./site ./content/ ./www/
              '';
            }
          }/bin/blog-ssg";
        };

        build = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-build";
              runtimeInputs = [
                sass
                pkgs.coreutils
                pkgs.lightningcss
              ];
              text = ''
                echo "[blog] building CSS..."
                sass --style=expanded --sourcemap=none site.scss | lightningcss --minify -o www/site.css
                echo "[blog] generating HTML..."
                exec ./site ./content/ ./www/
              '';
            }
          }/bin/blog-build";
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

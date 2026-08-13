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
      tailwind = pkgs.tailwindcss_4;
    in
    {
      apps.${system} = {
        css = {
          type = "app";
          program = "${
            pkgs.writeShellApplication {
              name = "blog-css";
              runtimeInputs = [ tailwind ];
              text = ''
                tailwindcss build -i site.css -o www/site.css -m
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
                tailwind
                pkgs.coreutils
              ];
              text = ''
                echo "[blog] building CSS..."
                tailwindcss build -i site.css -o www/site.css -m
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
          pkgs.tailwindcss_4
          pkgs.tailwindcss-language-server
        ];
      };
    };
}

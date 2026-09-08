{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "github:nix-caliga/nix-caliga";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    roc-overlay.url = "github:roc-lang/roc-overlay";
    roc-overlay.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs:
    let
      system = "x86_64-linux";
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      edge = inputs.nix-caliga.lib.makeCaligaConfigurations {
        inherit pkgs;
        specialArgs = { inherit inputs; };
        modules = [
          ./images/edge
          ./images/edge/users
          ./images/edge/services
        ];
      };
      imageTar = pkgs.runCommand "blog-image.tar" { } ''
        mkdir -p "$out"
        ${edge.config.build.image} > "$out/image.tar"
      '';
    in
    {
      caligaConfigurations.${system}.edge = edge;
      packages.${system} = {
        default = imageTar;
        inherit imageTar;
      };
    };
}

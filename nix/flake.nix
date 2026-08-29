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

  outputs = inputs: {
    caligaConfigurations.x86_64-linux = {
      edge = inputs.nix-caliga.lib.makeCaligaConfigurations {
        pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
        specialArgs = { inherit inputs; };
        modules = [
          ./images/edge
          ./images/edge/users
          ./images/edge/services
        ];
      };
    };
  };
}

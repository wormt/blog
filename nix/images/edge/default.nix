{ pkgs, ... }:

{
  config = {
    caliga.os = "fedora";
    caliga.core.enable = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/edge";
      tag = "latest";
      fromImage = pkgs.dockerTools.pullImage {
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:7b7db1d22fe0291fa7e05bc6aeece054b51be5f4857a8ecdb1e69cd368e129d6"; # registry hash
        sha256 = "sha256-T5ti61b611T3b7/2gD3bfDygIGcP0V2jZYSiKtkwOug=";                          # nix store hash
        finalImageTag = "44";
        arch = "amd64";
      };
    };

    environment.systemPackages = [ pkgs.nginx ];
  };
}

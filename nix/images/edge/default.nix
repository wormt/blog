{ pkgs, ... }:

{
  config = {
    caliga.os = "fedora";
    caliga.core.enable = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/edge";
      tag = "latest";
      config.Labels."org.opencontainers.image.source" = "https://github.com/wormt/blog";
      fromImage = pkgs.dockerTools.pullImage {
        imageName = "quay.io/fedora/fedora-bootc";
        imageDigest = "sha256:cc0e99fb83e3cf2bd34b073535cfa656dc817dfd29911a1c47546bb013e1c845"; # registry hash
        sha256 = "sha256-k2ddp1m1FoazicUCa7E8cKmrRlayn6zZPQcjE8qNMjA";                          # nix store hash
        finalImageTag = "44";
        arch = "amd64";
      };
    };

    environment.systemPackages = [ pkgs.nginx ];
  };
}

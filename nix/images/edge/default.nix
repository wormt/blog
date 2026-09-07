{ pkgs, ... }:

let
  acme-tiny = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/diafygi/acme-tiny/refs/tags/5.0.3/acme_tiny.py";
    sha256 = "sha256-uvNs3RSl0gaHX2VlOTJOTD7QmI0nmegDB6djLNHIT54=";
  };
  acme-tiny-bin = pkgs.runCommand "acme-tiny" { } ''
    install -Dm755 ${acme-tiny} $out/usr/local/bin/acme_tiny
  '';
  acme-racket = pkgs.runCommand "acme-racket" { } ''
    install -Dm755 ${../../../scripts/acme.rkt} $out/usr/local/libexec/acme.rkt
  '';
in
{
  config = {
    caliga.os = "fedora";
    caliga.core.enable = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/blog";
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

    environment.systemPackages = [
      pkgs.nginx
      pkgs.racket-minimal
    ];
    layeredImage.contents = [ acme-tiny-bin acme-racket ];
  };
}

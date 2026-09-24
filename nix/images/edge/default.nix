{ pkgs, inputs, ... }:

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
    nix.enable = true;
    bootc.ostree-prepare-root.createConf = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/blog";
      tag = "latest";
      config.Labels."org.opencontainers.image.source" = "https://github.com/wormt/blog";
      fromImage = pkgs.dockerTools.pullImage (
        (import "${inputs.bootc-image-prefetcher}/pins/fedora-bootc/44.nix")
        // {
          imageName = "registry.fedoraproject.org/fedora-bootc";
        }
      );
    };

    environment.systemPackages = [
      pkgs.nginx
      pkgs.racket-minimal
    ];
    layeredImage.contents = [
      acme-tiny-bin
      acme-racket
    ];
  };
}

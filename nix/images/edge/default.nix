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
    bootc.ostree-prepare-root.createConf = true;
    system.stateVersion = "26.05";

    layeredImage = {
      name = "ghcr.io/wormt/blog";
      tag = "latest";
      config.Labels."org.opencontainers.image.source" = "https://github.com/wormt/blog";
      fromImage =
        (pkgs.dockerTools.pullImage {
          imageName = "quay.io/fedora/fedora-bootc";
          imageDigest = "sha256:d4b9c5e156ab0a119962aad27c5394409094cc24348846a35c78acd8e9847a4d"; # registry hash
          sha256 = "sha256-1un+fQxPLYYvPsya9RQ8MuN3XcEhe4/lxTeIRXGoGQ0="; # nix store hash
          finalImageTag = "44";
          arch = "amd64";
        }).overrideAttrs
          {
            REGISTRY_AUTH_FILE = pkgs.writeText "empty-registry-auth.json" "{}";
          };
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

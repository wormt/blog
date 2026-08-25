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
        imageDigest = "sha256:b002637dc48abbb1f25f6ab0d8d0572c3b753a691d2917a3fb47a76a10d8b57d"; # registry hash
        sha256 = "sha256-C01WDuFVrskA+LFoHeBRLMto7AcY88af/qUGXHzz1XA=";                          # nix store hash
        finalImageTag = "44";
        arch = "amd64";
      };
    };

    environment.systemPackages = [ pkgs.nginx ];
  };
}

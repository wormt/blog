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
        imageDigest = "sha256:295dd6ecda23780e9babf6a889914762ae118c621819d777c879992884d2b681";
        sha256 = "sha256-wODwf4JGTuJoGjK/QRwZIM97D/abmFsKvQ5wISua7qM=";
        finalImageTag = "44";
        arch = "amd64";
      };
    };

    environment.systemPackages = [ pkgs.nginx ];
  };
}

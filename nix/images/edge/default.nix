# Copyright (C) 2026  wormt <209373679+wormt@users.noreply.github.com>
# SPDX-License-Identifier: AGPL-3.0-or-later
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

{ pkgs, inputs, ... }:

let
  acme-tiny = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/diafygi/acme-tiny/refs/tags/5.0.3/acme_tiny.py";
    sha256 = "sha256-uvNs3RSl0gaHX2VlOTJOTD7QmI0nmegDB6djLNHIT54=";
  };
  acme-tiny-bin = pkgs.runCommand "acme-tiny" { } ''
    install -Dm755 ${acme-tiny} $out/usr/local/bin/acme_tiny
    substituteInPlace $out/usr/local/bin/acme_tiny \
      --replace-fail "/usr/bin/env python3" "${pkgs.python3}/bin/python3"
  '';
  acme-racket = pkgs.runCommand "acme-racket" { } ''
    install -Dm755 ${../../../scripts/acme.rkt} $out/usr/local/libexec/acme.rkt
    substituteInPlace $out/usr/local/libexec/acme.rkt \
      --replace-fail '"openssl"' '"${pkgs.openssl}/bin/openssl"' \
      --replace-fail '"acme_tiny"' '"${acme-tiny-bin}/usr/local/bin/acme_tiny"' \
      --replace-fail '"nginx"' '"${pkgs.nginx}/bin/nginx"'
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

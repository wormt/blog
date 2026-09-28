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

{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nix-caliga = {
      url = "github:nix-caliga/nix-caliga/overlayfs-nix-store";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    roc-overlay.url = "github:roc-lang/roc-overlay";
    roc-overlay.inputs.nixpkgs.follows = "nixpkgs";
    bootc-image-prefetcher = {
      url = "github:nix-caliga/bootc-image-prefetcher";
      flake = false;
    };
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

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

{ pkgs, ... }:

{
  # this is necessary if /var/home doesnt exist on first boot.
  systemd.tmpfiles.settings."00-var-home"."/var/home".d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  users.users.wormt = {
    isNormalUser = true;
    uid = 6767;
    description = "the best";
    initialHashedPassword = "$y$j9T$ZHaXNt8NPMF5bJJasx.Kv.$qlWjFBN9dkc/4/CthvFbvjZ4QkmjEfkVWh9hpXaccS/";
    extraGroups = [ "wheel" ];
  };
}

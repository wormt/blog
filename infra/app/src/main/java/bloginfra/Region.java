// Copyright (C) 2026  wormt <209373679+wormt@users.noreply.github.com>
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

package bloginfra;

public record Region(String name, String label, String slug) {
  public static final Region US_EAST = new Region("eastus", "East US", "eus");
  public static final Region US_EAST2 = new Region("eastus2", "East US 2", "eus2");
  public static final Region US_EAST3 = new Region("eastus3", "East US 3", "eus3");
  public static final Region US_WEST = new Region("westus", "West US", "wus");
  public static final Region US_WEST2 = new Region("westus2", "West US 2", "wus2");
  public static final Region US_WEST3 = new Region("westus3", "West US 3", "wus3");
}

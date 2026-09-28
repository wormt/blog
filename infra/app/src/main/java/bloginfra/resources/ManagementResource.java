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

package bloginfra.resources;

import bloginfra.Region;
import com.pulumi.Context;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.azurenative.resources.ResourceGroupArgs;
import com.pulumi.core.*;

public final class ManagementResource {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  private final ResourceGroup rg;

  public record ManagementOutputs(Output<String> rgId) {
    public void exportOutputs(Context ctx) {
      ctx.export("rgId", rgId);
    }
  }

  public ManagementResource() {
    String name = "rg-" + APP_NAME + "-" + APP_REGION_PRIMARY.slug() + "-01";
    this.rg =
        new ResourceGroup(
            name, ResourceGroupArgs.builder().location(APP_REGION_PRIMARY.name()).build());
  }

  public ManagementOutputs outputs() {
    return new ManagementOutputs(rg.id());
  }

  public ResourceGroup resourceGroup() {
    return rg;
  }
}

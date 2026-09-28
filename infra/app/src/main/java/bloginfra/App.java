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

import bloginfra.resources.*;
import com.pulumi.Pulumi;
import com.pulumi.core.TypeShape;
import java.util.List;

public class App {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  public static void main(String[] args) {
    Pulumi.run(
        ctx -> {
          var config = ctx.config();

          List<String> sshAllowedSubnets =
              config.requireObject("sshAllowedSubnets", TypeShape.list(String.class));

          var mgmt = new ManagementResource();
          var network = new NetworkResource(mgmt.resourceGroup(), sshAllowedSubnets);
          var image =
              new ImageResource(
                  mgmt.resourceGroup(), config.require("vhdPath"), config.require("imageVersion"));
          var compute =
              new ComputeResource(
                  mgmt.resourceGroup(), network.outputs().nicId(), image.imageVersionId());

          mgmt.outputs().exportOutputs(ctx);
          network.outputs().exportOutputs(ctx);
          image.outputs().exportOutputs(ctx);
          compute.outputs().exportOutputs(ctx);
        });
  }
}

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
import com.pulumi.azurenative.compute.*;
import com.pulumi.azurenative.compute.enums.*;
import com.pulumi.azurenative.compute.inputs.HardwareProfileArgs;
import com.pulumi.azurenative.compute.inputs.ImageReferenceArgs;
import com.pulumi.azurenative.compute.inputs.ManagedDiskParametersArgs;
import com.pulumi.azurenative.compute.inputs.NetworkInterfaceReferenceArgs;
import com.pulumi.azurenative.compute.inputs.NetworkProfileArgs;
import com.pulumi.azurenative.compute.inputs.OSDiskArgs;
import com.pulumi.azurenative.compute.inputs.StorageProfileArgs;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.core.*;
import java.util.List;

public final class ComputeResource {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  private final VirtualMachine vm;

  public record ComputeOutputs(Output<String> vmId) {
    public void exportOutputs(Context ctx) {
      ctx.export("vmId", vmId);
    }
  }

  public ComputeResource(ResourceGroup rg, Output<String> nicId, Output<String> imageVersionId) {
    String baseName = APP_NAME + "-" + APP_REGION_PRIMARY.slug();

    this.vm =
        new VirtualMachine(
            "vm-" + baseName + "-01",
            VirtualMachineArgs.builder()
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .hardwareProfile(HardwareProfileArgs.builder().vmSize("Standard_B2ats_v2").build())
                .storageProfile(
                    StorageProfileArgs.builder()
                        .imageReference(ImageReferenceArgs.builder().id(imageVersionId).build())
                        .osDisk(
                            OSDiskArgs.builder()
                                .createOption(DiskCreateOptionTypes.FromImage)
                                .deleteOption(DiskDeleteOptionTypes.Delete)
                                .diskSizeGB(64)
                                .managedDisk(
                                    ManagedDiskParametersArgs.builder()
                                        .storageAccountType(StorageAccountTypes.Premium_LRS)
                                        .build())
                                .build())
                        .build())
                .networkProfile(
                    NetworkProfileArgs.builder()
                        .networkInterfaces(
                            List.of(
                                NetworkInterfaceReferenceArgs.builder()
                                    .id(nicId)
                                    .primary(true)
                                    .build()))
                        .build())
                .build());
  }

  public ComputeOutputs outputs() {
    return new ComputeOutputs(vm.id());
  }
}

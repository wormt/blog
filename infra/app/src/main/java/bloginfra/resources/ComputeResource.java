package bloginfra.resources;

import bloginfra.Region;
import com.pulumi.Context;
import com.pulumi.azurenative.compute.*;
import com.pulumi.azurenative.compute.enums.*;
import com.pulumi.azurenative.compute.inputs.HardwareProfileArgs;
import com.pulumi.azurenative.compute.inputs.ImageReferenceArgs;
import com.pulumi.azurenative.compute.inputs.LinuxConfigurationArgs;
import com.pulumi.azurenative.compute.inputs.ManagedDiskParametersArgs;
import com.pulumi.azurenative.compute.inputs.NetworkInterfaceReferenceArgs;
import com.pulumi.azurenative.compute.inputs.NetworkProfileArgs;
import com.pulumi.azurenative.compute.inputs.OSDiskArgs;
import com.pulumi.azurenative.compute.inputs.OSProfileArgs;
import com.pulumi.azurenative.compute.inputs.SshConfigurationArgs;
import com.pulumi.azurenative.compute.inputs.SshPublicKeyArgs;
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

  public ComputeResource(ResourceGroup rg, Output<String> nicId) {
    String baseName = APP_NAME + "-" + APP_REGION_PRIMARY.slug();

    this.vm =
        new VirtualMachine(
            "vm-" + baseName + "-01",
            VirtualMachineArgs.builder()
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .hardwareProfile(HardwareProfileArgs.builder().vmSize("Standard_B2ats_v2").build())
                .osProfile(
                    OSProfileArgs.builder()
                        .computerName("edge-" + baseName + "-01")
                        .adminUsername("asv")
                        .linuxConfiguration(
                            LinuxConfigurationArgs.builder()
                                .disablePasswordAuthentication(true)
                                .ssh(
                                    SshConfigurationArgs.builder()
                                        .publicKeys(
                                            List.of(
                                                SshPublicKeyArgs.builder()
                                                    .path("/home/asv/.ssh/authorized_keys")
                                                    .keyData(
                                                        "ssh-ed25519"
                                                            + " AAAAC3NzaC1lZDI1NTE5AAAAIOD62U1wf9DrvjWde2jV8rbi9DVThvZZyPleZVBIf5j4"
                                                            + " navi_blog")
                                                    .build()))
                                        .build())
                                .build())
                        .build())
                .storageProfile(
                    StorageProfileArgs.builder()
                        .imageReference(
                            ImageReferenceArgs.builder()
                                .publisher("canonical")
                                .offer("0001-com-ubuntu-server-jammy")
                                .sku("22_04-lts-gen2")
                                .version("latest")
                                .build())
                        .osDisk(
                            OSDiskArgs.builder()
                                .name("osdisk-" + baseName + "-01")
                                .createOption(DiskCreateOptionTypes.FromImage)
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

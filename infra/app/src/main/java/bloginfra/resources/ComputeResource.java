package bloginfra.resources;

import bloginfra.Region;
import com.pulumi.Context;
import com.pulumi.azurenative.batch.inputs.ImageReferenceArgs;
import com.pulumi.azurenative.batch.inputs.OSDiskArgs;
import com.pulumi.azurenative.compute.*;
import com.pulumi.azurenative.compute.enums.*;
import com.pulumi.azurenative.compute.inputs.BootDiagnosticsArgs;
import com.pulumi.azurenative.compute.inputs.DiagnosticsProfileArgs;
import com.pulumi.azurenative.compute.inputs.NetworkInterfaceReferenceArgs;
import com.pulumi.azurenative.compute.inputs.NetworkProfileArgs;
import com.pulumi.azurenative.compute.inputs.StorageProfileArgs;
import com.pulumi.azurenative.connectedvmwarevsphere.inputs.*;
import com.pulumi.azurenative.hybridnetwork.inputs.*;
import com.pulumi.azurenative.network.*;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.azurenative.workloads.inputs.OSProfileArgs;
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
                .resourceGroupName(rgName)
                .location(APP_REGION_PRIMARY.name())
                .vmSize("Standard_D2s_v5")
                .hardwareProfile(HardwareProfileArgs.builder().vmSize("Standard_D2s_v5").build())
                .osProfile(
                    OSProfileArgs.builder()
                        .computerName("edge-" + baseName + "-01")
                        .adminUsername("asv")
                        .customData(cloudInit)
                        .linuxConfiguration(
                            LinuxConfigurationArgs.builder()
                                .disablePasswordAuthentication(true)
                                .ssh(
                                    SshConfigurationArgs.builder()
                                        .publicKeys(
                                            List.of(
                                                SshPublicKeyArgs.builder()
                                                    .path("/home/asv/.ssh/authorized_keys")
                                                    .keyData("<your public key>")
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
                                .createOption(DiskCreateOption.FromImage)
                                .diskSizeGB(40)
                                .storageAccountType(StorageAccountTypes.Standard_LRS)
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
                .diagnosticsProfile(
                    DiagnosticsProfileArgs.builder()
                        .bootDiagnostics(BootDiagnosticsArgs.builder().enabled(true).build())
                        .build())
                .build());
  }

  public ComputeOutputs outputs() {
    return new ComputeOutputs(vm.id());
  }
}

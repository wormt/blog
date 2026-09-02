package bloginfra.resources;

import bloginfra.Region;
import com.pulumi.Context;
import com.pulumi.azurenative.compute.*;
import com.pulumi.azurenative.compute.inputs.NetworkProfileArgs;
import com.pulumi.azurenative.network.*;
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

  public ComputeResource(ResourceGroup rg, NetworkInterface nic) {
    String baseName = APP_NAME + "-" + APP_REGION_PRIMARY.slug();
    this.vm =
        new VirtualMachine(
            "vm-" + baseName + "-01",
            VirtualMachineArgs.builder()
                .resourceGroupName(rg.name())
                .networkProfile(NetworkProfileArgs.builder().networkInterfaces(List.of(nic)))
                .build());
  }

  public ComputeOutputs outputs() {
    return new ComputeOutputs(vm.id());
  }
}

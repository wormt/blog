package myproject.resources;

import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.azurenative.resources.ResourceGroupArgs;
import com.pulumi.core.*;
import myproject.Region;

public final class ManagementResource {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  private final ResourceGroup rg;

  public record ManagementOutputs(Output<String> rgId) {}

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

package bloginfra;

import bloginfra.resources.*;
import com.pulumi.Pulumi;

public class App {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  public static void main(String[] args) {
    Pulumi.run(
        ctx -> {
          var mgmt = new ManagementResource();
          var network = new NetworkResource(mgmt.resourceGroup());

          network.outputs().exportOutputs(ctx);
        });
  }
}

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

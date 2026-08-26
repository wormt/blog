package myproject;

import com.pulumi.Pulumi;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.azurenative.storage.StorageAccount;
import com.pulumi.azurenative.storage.StorageAccountArgs;
import com.pulumi.azurenative.storage.enums.Kind;
import com.pulumi.azurenative.storage.enums.SkuName;
import com.pulumi.azurenative.storage.inputs.SkuArgs;
import com.pulumi.core.*;
import com.pulumi.random.RandomString;
import com.pulumi.random.RandomStringArgs;

public class App {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  public static void main(String[] args) {
    Pulumi.run(
        ctx -> {
          var resourceGroup = resourceGroup();
          var storageAccount = storageAccount(resourceGroup);

          ctx.export("storageAccountName", storageAccount.name());
        });
  }

  private static ResourceGroup resourceGroup() {
    return new ResourceGroup("rg-" + APP_NAME + "-" + APP_REGION_PRIMARY.getSlug());
  }

  private static StorageAccount storageAccount(ResourceGroup rg) {
    var random_id =
        new RandomString(
            "random", RandomStringArgs.builder().length(8).special(false).upper(false).build());

    String baseName = "sa" + APP_NAME + APP_REGION_PRIMARY.getSlug();

    var name = Output.format("%s%s", baseName, random_id.result());

    StorageAccountArgs args =
        StorageAccountArgs.builder()
            .resourceGroupName(rg.name())
            .accountName(name)
            .sku(SkuArgs.builder().name(SkuName.Standard_LRS).build())
            .kind(Kind.StorageV2)
            .build();

    return new StorageAccount(baseName, args);
  }
}

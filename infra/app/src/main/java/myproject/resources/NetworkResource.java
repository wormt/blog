package myproject.resources;

import com.pulumi.Context;
import com.pulumi.azurenative.network.*;
import com.pulumi.azurenative.network.enums.IPAllocationMethod;
import com.pulumi.azurenative.network.enums.PublicIPAddressSkuName;
import com.pulumi.azurenative.network.enums.SecurityRuleAccess;
import com.pulumi.azurenative.network.enums.SecurityRuleDirection;
import com.pulumi.azurenative.network.inputs.AddressSpaceArgs;
import com.pulumi.azurenative.network.inputs.NetworkInterfaceIPConfigurationArgs;
import com.pulumi.azurenative.network.inputs.SecurityRuleArgs;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.core.*;
import java.util.List;
import myproject.Region;

public final class NetworkResource {
  public static final String APP_NAME = "blog";
  public static final Region APP_REGION_PRIMARY = Region.US_WEST2;

  private final VirtualNetwork vnet;
  private final NetworkSecurityGroup nsg;
  private final PublicIPAddress pip;
  private final NetworkInterface nic;
  private final Subnet snet;

  public record NetworkOutputs(
      Output<String> vnetId,
      Output<String> nsgId,
      Output<String> pipId,
      Output<String> nicId,
      Output<String> snetId) {
    public void exportOutputs(Context ctx) {
      ctx.export("vnetId", vnetId);
      ctx.export("nsgId", nsgId);
      ctx.export("pipId", pipId);
      ctx.export("nicId", nicId);
      ctx.export("snetId", snetId);
    }
  }

  public NetworkResource(ResourceGroup rg) {
    String baseName = APP_NAME + "-" + APP_REGION_PRIMARY.slug();
    this.vnet =
        new VirtualNetwork(
            "vnet-" + baseName + "-01",
            VirtualNetworkArgs.builder()
                .resourceGroupName(rg.name())
                .addressSpace(
                    AddressSpaceArgs.builder().addressPrefixes(List.of("10.0.0.0/16")).build())
                .build());
    this.nsg =
        new NetworkSecurityGroup(
            "nsg-" + baseName + "-01",
            NetworkSecurityGroupArgs.builder()
                .resourceGroupName(rg.name())
                .securityRules(
                    List.of(
                        SecurityRuleArgs.builder()
                            .name("allow-ssh-inbound")
                            .priority(100)
                            .access(SecurityRuleAccess.Allow)
                            .direction(SecurityRuleDirection.Inbound)
                            .protocol("Tcp")
                            .sourceAddressPrefix("67.67.67.67/32")
                            .sourcePortRange("*")
                            .destinationAddressPrefix("*")
                            .destinationPortRange("22")
                            .build(),
                        SecurityRuleArgs.builder()
                            .name("deny-all-inbound")
                            .priority(4096)
                            .access(SecurityRuleAccess.Deny)
                            .direction(SecurityRuleDirection.Inbound)
                            .protocol("*")
                            .sourceAddressPrefix("*")
                            .sourcePortRange("*")
                            .destinationAddressPrefix("*")
                            .destinationPortRange("*")
                            .build()))
                .build());
    this.snet =
        new Subnet(
            "snet-" + baseName + "-01",
            SubnetArgs.builder()
                .resourceGroupName(rg.name())
                .addressPrefixes(List.of("10.0.67.0/24"))
                .virtualNetworkName(vnet.name())
                .networkSecurityGroup(
                    com.pulumi.azurenative.network.inputs.NetworkSecurityGroupArgs.builder()
                        .id(nsg.id())
                        .build())
                .build());
    this.pip =
        new PublicIPAddress(
            "pip-" + baseName + "-01",
            PublicIPAddressArgs.builder()
                .resourceGroupName(rg.name())
                .publicIPAllocationMethod(IPAllocationMethod.Static)
                .sku(
                    com.pulumi.azurenative.network.inputs.PublicIPAddressSkuArgs.builder()
                        .name(PublicIPAddressSkuName.Standard)
                        .build())
                .build());
    this.nic =
        new NetworkInterface(
            "nic-" + baseName + "-01",
            NetworkInterfaceArgs.builder()
                .resourceGroupName(rg.name())
                .enableAcceleratedNetworking(true)
                .enableIPForwarding(false)
                .ipConfigurations(
                    NetworkInterfaceIPConfigurationArgs.builder()
                        .name("ipconfig1")
                        .primary(true)
                        .privateIPAllocationMethod(IPAllocationMethod.Dynamic)
                        .subnet(
                            com.pulumi.azurenative.network.inputs.SubnetArgs.builder()
                                .id(snet.id())
                                .build())
                        .publicIPAddress(
                            com.pulumi.azurenative.network.inputs.PublicIPAddressArgs.builder()
                                .id(pip.id())
                                .build())
                        .build())
                .build());
  }

  public NetworkOutputs outputs() {
    return new NetworkOutputs(vnet.id(), nsg.id(), pip.id(), nic.id(), snet.id());
  }
}

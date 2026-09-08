package bloginfra.resources;

import bloginfra.Region;
import com.pulumi.Context;
import com.pulumi.asset.FileAsset;
import com.pulumi.azure.storage.Account;
import com.pulumi.azure.storage.AccountArgs;
import com.pulumi.azure.storage.Blob;
import com.pulumi.azure.storage.BlobArgs;
import com.pulumi.azure.storage.Container;
import com.pulumi.azure.storage.ContainerArgs;
import com.pulumi.azurenative.compute.Gallery;
import com.pulumi.azurenative.compute.GalleryArgs;
import com.pulumi.azurenative.compute.GalleryImage;
import com.pulumi.azurenative.compute.GalleryImageArgs;
import com.pulumi.azurenative.compute.GalleryImageVersion;
import com.pulumi.azurenative.compute.GalleryImageVersionArgs;
import com.pulumi.azurenative.compute.enums.HostCaching;
import com.pulumi.azurenative.compute.enums.HyperVGeneration;
import com.pulumi.azurenative.compute.enums.OperatingSystemStateTypes;
import com.pulumi.azurenative.compute.enums.OperatingSystemTypes;
import com.pulumi.azurenative.compute.enums.StorageAccountType;
import com.pulumi.azurenative.compute.inputs.GalleryDiskImageSourceArgs;
import com.pulumi.azurenative.compute.inputs.GalleryImageIdentifierArgs;
import com.pulumi.azurenative.compute.inputs.GalleryImageVersionPublishingProfileArgs;
import com.pulumi.azurenative.compute.inputs.GalleryImageVersionStorageProfileArgs;
import com.pulumi.azurenative.compute.inputs.GalleryOSDiskImageArgs;
import com.pulumi.azurenative.compute.inputs.TargetRegionArgs;
import com.pulumi.azurenative.resources.ResourceGroup;
import com.pulumi.core.Output;
import com.pulumi.random.RandomString;
import com.pulumi.random.RandomStringArgs;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Map;

/** Uploads the bootc VHD and publishes it as an Azure Compute Gallery image version. */
public final class ImageResource {
  private static final String APP_NAME = "blog";
  private static final Region APP_REGION_PRIMARY = Region.US_WEST2;
  private static final String GALLERY_NAME = "gal_blog_westus2_01";
  private static final String IMAGE_DEFINITION_NAME = "blog-edge";

  private final Output<String> sourceVhdUrl;
  private final GalleryImageVersion imageVersion;

  public record ImageOutputs(Output<String> imageVersionId, Output<String> sourceVhdUrl) {
    public void exportOutputs(Context ctx) {
      ctx.export("imageVersionId", imageVersionId);
      ctx.export("sourceVhdUrl", sourceVhdUrl);
    }
  }

  public ImageResource(ResourceGroup rg, String vhdPath, String version) {
    validateInputs(vhdPath, version);
    var tags = Map.of("application", APP_NAME, "environment", "production");

    var storageSuffix =
        new RandomString(
            "image-storage-suffix",
            RandomStringArgs.builder().length(8).upper(false).special(false).build());
    Output<String> storageName =
        storageSuffix.result().applyValue(suffix -> "stblog" + suffix.toLowerCase());

    var storage =
        new Account(
            "image-storage",
            AccountArgs.builder()
                .name(storageName)
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .accountKind("StorageV2")
                .accountTier("Standard")
                .accountReplicationType("LRS")
                .allowNestedItemsToBePublic(false)
                .httpsTrafficOnlyEnabled(true)
                .minTlsVersion("TLS1_2")
                .tags(tags)
                .build());

    var container =
        new Container(
            "image-container",
            ContainerArgs.builder()
                .name("vhds")
                .storageAccountId(storage.id())
                .containerAccessType("private")
                .build());

    var sourceVhd =
        new Blob(
            "source-vhd",
            BlobArgs.builder()
                .name("blog-edge-" + version + ".vhd")
                .storageContainerId(container.id())
                .type("Page")
                .parallelism(8)
                .source(new FileAsset(vhdPath))
                .build());
    this.sourceVhdUrl = sourceVhd.url();

    var gallery =
        new Gallery(
            "image-gallery",
            GalleryArgs.builder()
                .galleryName(GALLERY_NAME)
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .description("Bootc images for the monoblog edge server")
                .tags(tags)
                .build());

    var imageDefinition =
        new GalleryImage(
            "edge-image-definition",
            GalleryImageArgs.builder()
                .galleryName(gallery.name())
                .galleryImageName(IMAGE_DEFINITION_NAME)
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .architecture("x64")
                .hyperVGeneration(HyperVGeneration.V1)
                .osType(OperatingSystemTypes.Linux)
                .osState(OperatingSystemStateTypes.Specialized)
                .identifier(
                    GalleryImageIdentifierArgs.builder()
                        .publisher("wormt")
                        .offer("monoblog")
                        .sku("edge")
                        .build())
                .description("Specialized Fedora bootc image for monoblog")
                .tags(tags)
                .build());

    this.imageVersion =
        new GalleryImageVersion(
            "edge-image-version",
            GalleryImageVersionArgs.builder()
                .galleryName(gallery.name())
                .galleryImageName(imageDefinition.name())
                .galleryImageVersionName(version)
                .resourceGroupName(rg.name())
                .location(APP_REGION_PRIMARY.name())
                .publishingProfile(
                    GalleryImageVersionPublishingProfileArgs.builder()
                        .excludeFromLatest(false)
                        .replicaCount(1)
                        .storageAccountType(StorageAccountType.Standard_LRS)
                        .targetRegions(
                            TargetRegionArgs.builder()
                                .name(APP_REGION_PRIMARY.name())
                                .regionalReplicaCount(1)
                                .storageAccountType(StorageAccountType.Standard_LRS)
                                .build())
                        .build())
                .storageProfile(
                    GalleryImageVersionStorageProfileArgs.builder()
                        .osDiskImage(
                            GalleryOSDiskImageArgs.builder()
                                .hostCaching(HostCaching.ReadWrite)
                                .source(
                                    GalleryDiskImageSourceArgs.builder()
                                        .uri(sourceVhdUrl)
                                        .storageAccountId(storage.id())
                                        .build())
                                .build())
                        .build())
                .tags(tags)
                .build());
  }

  public ImageOutputs outputs() {
    return new ImageOutputs(imageVersion.id(), sourceVhdUrl);
  }

  public Output<String> imageVersionId() {
    return imageVersion.id();
  }

  private static void validateInputs(String vhdPath, String version) {
    if (!Files.isRegularFile(Path.of(vhdPath))) {
      throw new IllegalArgumentException("blog:vhdPath is not a regular file: " + vhdPath);
    }
    if (!version.matches("[0-9]+\\.[0-9]+\\.[0-9]+")) {
      throw new IllegalArgumentException(
          "blog:imageVersion must use Azure's Major.Minor.Patch format: " + version);
    }
  }
}

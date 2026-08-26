package myproject;

public final class Region {
  public static final Region US_EAST = new Region("eastus", "East US", "eus");
  public static final Region US_EAST2 = new Region("eastus2", "East US 2", "eus2");
  public static final Region US_EAST3 = new Region("eastus3", "East US 3", "eus3");
  public static final Region US_WEST = new Region("westus", "West US", "wus");
  public static final Region US_WEST2 = new Region("westus2", "West US 2", "wus2");
  public static final Region US_WEST3 = new Region("westus3", "West US 3", "wus3");

  private final String name;
  private final String label;
  private final String slug;

  private Region(String name, String label, String slug) {
    this.name = name;
    this.label = label;
    this.slug = slug;
  }

  public String getName() {
    return this.name;
  }

  public String getLabel() {
    return this.label;
  }

  public String getSlug() {
    return this.slug;
  }
}

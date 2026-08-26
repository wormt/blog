{
  # this is necessary if /var/home doesnt exist on first boot.
  systemd.tmpfiles.settings."00-var-home"."/var/home".d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  users.users.admin = {
    isNormalUser = true;
    uid = 1000;
    description = "wormt";
    initialPassword = "astronomy-doorknob-amusing-brewery";
    createHome = true;
  };
}

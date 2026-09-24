{
  # this is necessary if /var/home doesnt exist on first boot.
  systemd.tmpfiles.settings."00-var-home"."/var/home".d = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  users.users.wormt = {
    isNormalUser = true;
    uid = 6767;
    description = "the best";
    initialHashedPassword = "$y$j9T$ZHaXNt8NPMF5bJJasx.Kv.$qlWjFBN9dkc/4/CthvFbvjZ4QkmjEfkVWh9hpXaccS/";
	extraGroups = ["wheel"];
  };
}

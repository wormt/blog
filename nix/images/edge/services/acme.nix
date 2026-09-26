{ pkgs, ... }:

{
  systemd.services.acme = {
    description = "ACME CSR for brainworm.homes";
    after = [
      "network-online.target"
      "nginx.service"
    ];
    wants = [ "network-online.target" ];
    requires = [ "nginx.service" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.racket-minimal}/bin/racket /usr/local/libexec/acme.rkt";
      Restart = "on-failure";
      RestartSec = "30s";
    };
  };
}

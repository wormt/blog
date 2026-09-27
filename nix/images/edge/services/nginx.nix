{ pkgs, inputs, ... }:

let
  blog =
    pkgs.runCommand "blog-www"
      {
        __noChroot = true;
        nativeBuildInputs = [
          inputs.roc-overlay.packages.x86_64-linux.nightly
          pkgs.dart-sass
          pkgs.lightningcss
        ];
      }
      ''
        cp -r ${../../../../package} package
        cp -r ${../../../../content} content

        # nix's behavior when using nativeBuildInputs sets HOME to a directory
        # that roc cant write to for its build cache.
        export HOME="$PWD"
        export ROC_CACHE_DIR="$HOME/roc-cache"
        mkdir -p "$ROC_CACHE_DIR"

        roc build package/Render.roc --output=render
        mkdir -p css
        sass --style=expanded --no-source-map package/styles/main.scss | lightningcss --minify -o css/site.css
        ./render ./content/ ./www/
        for f in article base home; do
          sass --style=expanded --no-source-map package/styles/$f.scss | lightningcss --minify -o css/$f.css
        done
        mkdir -p $out/var/www/blog
        cp -r www/. $out/var/www/blog/
        cp -r css $out/var/www/blog/css
      '';
  # nginx needs certs at start time, but also has to be running to serve /var/www/challenges
  # so start it with a fake cert.
  init-cert = pkgs.writeShellScript "nginx-init-cert" ''
    set -eu
    umask 077
    mkdir -p /etc/nginx/certs
    chmod 700 /etc/nginx/certs
    if [ ! -s /etc/nginx/certs/brainworm.homes.key ]; then
      ${pkgs.openssl}/bin/openssl genrsa -out /etc/nginx/certs/brainworm.homes.key 4096
    fi
    if [ ! -s /etc/nginx/certs/brainworm.homes.crt ]; then
      ${pkgs.openssl}/bin/openssl req -x509 -new \
        -key /etc/nginx/certs/brainworm.homes.key \
        -subj "/CN=brainworm.homes" \
        -days 2 \
        -out /etc/nginx/certs/brainworm.homes.crt
    fi
  '';

  init-cert-path = builtins.unsafeDiscardStringContext "${init-cert}";
  nginx-bin-path = builtins.unsafeDiscardStringContext "${pkgs.nginx}/bin/nginx";
in
{
  environment.systemPackages = [ pkgs.nginx ];

  layeredImage.contents = [ blog ];

  users.groups.nginx = { };
  users.users.nginx = {
    isSystemUser = true;
    group = "nginx";
    description = "NGINX web server";
    home = "/etc/nginx";
    createHome = true;
    shell = "${pkgs.shadow}/bin/nologin";
  };

  selinux.fileContexts = {
    "/var/www/blog(/.*)?" = "httpd_sys_content_t";
    "/var/www/challenges(/.*)?" = "httpd_sys_content_t";
    "/nix/store/[a-z0-9][^/]*-nginx-[^/]+/bin/nginx" = "httpd_exec_t";
    "/nix/store/[a-z0-9][^/]*-nginx-[^/]+/conf(/.*)?" = "httpd_config_t";
    "/etc/nginx(/.*)?" = "httpd_config_t";
    "/var/log/nginx(/.*)?" = "httpd_log_t";

    # writeShellScript outputs not covered by caliga
    "${init-cert-path}" = "bin_t";
  };

  systemd.tmpfiles.settings."20-nginx-etc" = {
    "/etc/nginx".d = {
      mode = "0700";
      user = "nginx";
      group = "nginx";
    };
    "/etc/nginx".Z = { };
  };

  systemd.tmpfiles.settings."20-nginx-var-log" = {
    "/var/log/nginx".d = {
      mode = "0700";
      user = "nginx";
      group = "nginx";
    };
    "/var/log/nginx".Z = { };
  };

  systemd.tmpfiles.settings."20-challenges-var-www" = {
    "/var/www/challenges".d = {
      mode = "0755";
      user = "root";
      group = "root";
    };
    "/var/www/challenges".Z = { };
  };

  systemd.tmpfiles.settings."20-blog-var-www"."/var/www/blog".Z = { };
  systemd.tmpfiles.settings."20-nginx-bin"."${nginx-bin-path}".Z = { };

  environment.etc."nginx/nginx.conf".text = ''
    user nginx nginx;
    worker_processes auto;
    error_log syslog:server=unix:/dev/log,nohostname error;
    pid /run/nginx.pid;
    daemon off;

    events {
      worker_connections 1024;
    }

    http {
      include ${pkgs.nginx}/conf/mime.types;
      default_type application/octet-stream;
      sendfile on;
      keepalive_timeout 65;
      access_log syslog:server=unix:/dev/log,nohostname info;

      server {
        listen 443 ssl;
        listen [::]:443 ssl;
        server_name _;
        http2 on;

        ssl_certificate /etc/nginx/certs/brainworm.homes.crt;
        ssl_certificate_key /etc/nginx/certs/brainworm.homes.key;

        client_max_body_size 16m;
        ignore_invalid_headers off;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $http_host;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        add_header Strict-Transport-Security "max-age=31536000";
        add_header Content-Security-Policy "default-src 'none';style-src 'self';img-src 'self';media-src 'self';base-uri 'none';sandbox allow-scripts;upgrade-insecure-requests;frame-ancestors 'none'";

        root /var/www/blog;
        index index.html;

        location / {
          try_files $uri $uri/ =404;
        }
      }

      server {
        listen 80;
        listen [::]:80;
        server_name _;

        root /var/www/blog;
        index index.html;

        location /.well-known/acme-challenge/ {
          default_type "text/plain";
          alias /var/www/challenges/;
        }
        location / {
          return 301 https://brainworm.homes$request_uri;
        }
      }
    }
  '';

  # environment.etc files are owned by root so we have to be world readable
  environment.etc."nginx/nginx.conf".mode = "0644";

  systemd.services.nginx = {
    description = "NGINX";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      ExecStartPre = [
        "+/usr/bin/mkdir -p /var/www/challenges"
        "+/usr/sbin/restorecon -RFv /etc/nginx /var/www/blog /var/www/challenges"
        init-cert
        "+/usr/sbin/restorecon -RFv /etc/nginx"
      ];
      ExecStart = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf";
      ExecReload = "${pkgs.nginx}/bin/nginx -s reload -c /etc/nginx/nginx.conf";
      ExecStop = "${pkgs.nginx}/bin/nginx -s quit -c /etc/nginx/nginx.conf";
      Restart = "on-failure";
      User = "nginx";
      Group = "nginx";
    };
  };
}

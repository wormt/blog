{ pkgs, inputs, ... }:

let
  blog = pkgs.runCommand "blog-www" {
    __noChroot = true;
    nativeBuildInputs = [
      inputs.roc-overlay.packages.x86_64-linux.nightly
      pkgs.dart-sass
      pkgs.lightningcss
    ];
  } ''
    cp -r ${../../../../package} package
    cp -r ${../../../../content} content

    # nix's behavior when using nativeBuildInputs sets HOME to a directory
    # that roc cant write to for its build cache.
    export HOME="$PWD"
    export ROC_CACHE_DIR="$HOME/roc-cache"
    mkdir -p "$ROC_CACHE_DIR"

    roc build package/Render.roc --output=render
    sass --style=expanded --no-source-map package/styles/main.scss | lightningcss --minify -o site.css
    ./render ./content/ ./www/
    mkdir -p $out/var/www/blog
    cp -r www/. $out/var/www/blog/
    cp site.css $out/var/www/blog/site.css
  '';
in
{
  environment.systemPackages = [ pkgs.nginx ];

  layeredImage.contents = [
    blog
  ];

  selinux.fileContexts = {
    "/var/www/blog(/.*)?" = "httpd_sys_content_t";
  };

  systemd.tmpfiles.settings."20-var-log-nginx"."/var/log/nginx".d = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  environment.etc."nginx/nginx.conf".text = ''
    user nobody nobody;
    worker_processes auto;
    error_log syslog:server=unix:/dev/log,nohostname;
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
      access_log syslog:server=unix:/dev/log,nohostname;
    
      server {
        listen 80;
        listen [::]:80;
        server_name _;
    
        root /var/www/blog;
        index index.html;
    
        location / {
          try_files $uri $uri/ =404;
        }
      }
    }
  '';

  systemd.services.nginx = {
    description = "NGINX";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.nginx}/bin/nginx -c /etc/nginx/nginx.conf";
      ExecReload = "${pkgs.nginx}/bin/nginx -s reload -c /etc/nginx/nginx.conf";
      ExecStop = "${pkgs.nginx}/bin/nginx -s quit -c /etc/nginx/nginx.conf";
      Restart = "on-failure";
    };
  };
}

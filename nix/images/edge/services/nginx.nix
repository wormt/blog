{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.nginx ];

  layeredImage.contents = [
    (pkgs.runCommand "blog-www" { } ''
      mkdir -p $out/var/www/blog
      cp -r ${../../../../www}/. $out/var/www/blog/
    '')
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

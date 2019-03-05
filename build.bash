#!/bin/bash

set -eu

read -d '' -r configuration <<'EOT' || true
user  nobody;
pid  /tmp/nginx/nginx.pid;
error_log  /tmp/nginx/error.log  debug;
worker_processes  1;
events {
    worker_connections  1024;
}
http {
    include  mime.types;
    default_type  application/octet-stream;
    access_log  /tmp/nginx/access.log;
    sendfile  on;
    keepalive_timeout  65;
    dav_ext_lock_zone zone=foo:10m;
    server {
        listen  80;
        server_name  localhost;
        location / {
            root  /tmp/nginx;
            autoindex  on;
            dav_access  user:rw  group:rw  all:r;
            dav_methods  PUT DELETE MKCOL COPY MOVE OPTIONS;
            dav_ext_methods  PROPFIND LOCK UNLOCK;
            dav_ext_lock zone=foo;
            create_full_put_path  off;
            min_delete_depth  0;
        }
    }
}
EOT

options=(
    --prefix=/opt/nginx
    --with-debug
    --with-http_auth_request_module
    --with-http_dav_module
    --with-http_ssl_module
    --add-module=../nginx-dav-ext-module
)

function header {
    echo -en "\e[1;31m"
    printf "%0.s#" $(seq 1 $(tput cols))
    echo -e "\e[0m"
    echo -e "\e[1;31m# ${*}\e[0m"
}

# header 'Configuring...'
# ./auto/configure ${options[*]} > /dev/null
header 'Building...'
make
header 'Installing...'
sudo make install
header 'Preparing...'
echo "${configuration}" | sudo tee /opt/nginx/conf/nginx.conf
sudo install --directory --owner=nobody --group=nobody /tmp/nginx
sudo truncate --size=0 /tmp/nginx/access.log
sudo truncate --size=0 /tmp/nginx/error.log
header 'Restarting...'
sudo killall nginx
sudo /opt/nginx/sbin/nginx
header 'Testing...'
litmus -k http://localhost/
# TESTS='basic copymove http' litmus -k http://localhost/

# https://gist.github.com/marijnh/4013062
# http://trac.nginx.org/nginx/ticket/242
# http://trac.nginx.org/nginx/ticket/604
# https://github.com/arut/nginx-dav-ext-module/tree/master
# https://github.com/arut/nginx-dav-ext-module/tree/locks

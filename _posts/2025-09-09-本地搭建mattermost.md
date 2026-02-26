---
layout: default
title: 本地搭建Mattermost
date: 2025-09-09 10:37 +0800
categories: mattermost
---

记录如何本地容器化搭建 Mattermost 并配置 SSL 证书。

1. 创建 Posgres database

[https://docs.mattermost.com/deployment-guide/server/preparations.html#database-preparation](https://docs.mattermost.com/deployment-guide/server/preparations.html#database-preparation)

```sql
CREATE DATABASE mattermost WITH ENCODING 'UTF8' LC_COLLATE='en_US.UTF-8' LC_CTYPE='en_US.UTF-8' TEMPLATE=template0;

CREATE USER mmuser WITH PASSWORD 'mmuser-password';

GRANT ALL PRIVILEGES ON DATABASE mattermost to mmuser;

ALTER DATABASE mattermost OWNER TO mmuser;
ALTER SCHEMA public OWNER TO mmuser;
GRANT USAGE, CREATE ON SCHEMA public TO mmuser;
```

2. 拉起 Docker 容器

```yaml
services:
  mattermost:
    image: mattermost/mattermost-enterprise-edition:10.11.8
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    # See https://docs.mattermost.com/administration-guide/scale/scaling-for-enterprise.html
    # for guidance on memory limits based on your deployment size.
    mem_limit: 4G
    read_only: false
    tmpfs:
      - /tmp
    volumes:
      - ./mattermost/config:/mattermost/config:rw
      - ./mattermost/data:/mattermost/data:rw
      - ./mattermost/logs:/mattermost/logs:rw
      - ./mattermost/plugins:/mattermost/plugins:rw
      - ./mattermost/client/plugins:/mattermost/client/plugins:rw
      - ./mattermost/bleve-indexes:/mattermost/bleve-indexes:rw
      # When you want to use SSO with GitLab, you have to add the cert pki chain of GitLab inside Alpine
      # to avoid Token request failed: certificate signed by unknown authority
      # (link: https://github.com/mattermost/mattermost-server/issues/13059 and https://github.com/mattermost/docker/issues/34)
      # - ${GITLAB_PKI_CHAIN_PATH}:/etc/ssl/certs/pki_chain.pem:ro
    environment:
      # timezone inside container
      - TZ=UTC

      # necessary Mattermost options/variables (see env.example)
      - MM_SQLSETTINGS_DRIVERNAME=postgres
      - MM_SQLSETTINGS_DATASOURCE=postgres://mmuser:mmuser@docker.host.internal:5432/mattermost?sslmode=disable&connect_timeout=10

      # necessary for bleve
      - MM_BLEVESETTINGS_INDEXDIR=/mattermost/bleve-indexes

      # additional settings
      - MM_SERVICESETTINGS_SITEURL=https://mattermost.local
    ports:
      - 8065:8065
      - 8443:8443/udp
      - 8443:8443/tcp
```

3. 生成自签证书

```sh
#!/bin/bash
set -e

# Default values
DOMAIN="mattermost.local"
OUTPUT_DIR="./volumes/web/cert"
CA_DIR="./certs"

usage() {
    echo "Usage: $0 [-d DOMAIN] [-o OUTPUT_DIR]"
    echo "  -d  Domain name (default: $DOMAIN)"
    echo "  -o  Output directory for server certs (default: $OUTPUT_DIR)"
    echo "  -h  Show this help message"
}

while getopts "d:o:h" opt; do
    case ${opt} in
        d) DOMAIN=$OPTARG ;;
        o) OUTPUT_DIR=$OPTARG ;;
        h) usage; exit 0 ;;
        *) usage; exit 1 ;;
    esac
done

echo "Generating certificates for domain: $DOMAIN"
echo "Server certificates will be placed in: $OUTPUT_DIR"
echo "Root CA will be placed in: $CA_DIR"

mkdir -p "$OUTPUT_DIR"
mkdir -p "$CA_DIR"

# 1. Generate Root CA if it doesn't exist
if [[ ! -f "$CA_DIR/rootCA.key" ]]; then
    echo "Generating Root CA..."
    openssl genrsa -out "$CA_DIR/rootCA.key" 4096
    openssl req -x509 -new -nodes -key "$CA_DIR/rootCA.key" -sha256 -days 3650 \
        -out "$CA_DIR/rootCA.crt" \
        -subj "/C=US/ST=Local/L=Local/O=Dev/OU=Mattermost/CN=MattermostLocalRootCA"
    echo "Root CA generated at $CA_DIR/rootCA.crt"
else
    echo "Using existing Root CA at $CA_DIR/rootCA.crt"
fi

# 2. Generate Server Key
echo "Generating Server Key..."
openssl genrsa -out "$OUTPUT_DIR/key-no-password.pem" 2048

# 3. Create CSR Configuration with SANs
# Try to detect local IP
LOCAL_IP=$(ipconfig getifaddr en0 2>/dev/null || echo "127.0.0.1")
echo "Detected Local IP: $LOCAL_IP"

cat > "$OUTPUT_DIR/server.csr.cnf" <<EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = Local
L = Local
O = Dev
OU = Mattermost
CN = $DOMAIN

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = $DOMAIN
DNS.2 = localhost
IP.1 = 127.0.0.1
IP.2 = $LOCAL_IP
EOF

# 4. Generate CSR
openssl req -new -key "$OUTPUT_DIR/key-no-password.pem" \
    -out "$OUTPUT_DIR/server.csr" \
    -config "$OUTPUT_DIR/server.csr.cnf"

# 5. Sign CSR with Root CA
echo "Signing Server Certificate..."
openssl x509 -req -in "$OUTPUT_DIR/server.csr" \
    -CA "$CA_DIR/rootCA.crt" -CAkey "$CA_DIR/rootCA.key" -CAcreateserial \
    -out "$OUTPUT_DIR/cert.pem" \
    -days 825 -sha256 \
    -extfile "$OUTPUT_DIR/server.csr.cnf" \
    -extensions req_ext

# Cleanup intermediate files
rm "$OUTPUT_DIR/server.csr" "$OUTPUT_DIR/server.csr.cnf"

echo "----------------------------------------------------------------"
echo "✅ Certificates generated successfully!"
echo "Server Certificate: $OUTPUT_DIR/cert.pem"
echo "Server Key:         $OUTPUT_DIR/key-no-password.pem"
echo "Root CA:            $CA_DIR/rootCA.crt"
echo "----------------------------------------------------------------"
echo "👉 NEXT STEPS FOR IPHONE:"
echo "1. Send '$CA_DIR/rootCA.crt' to your iPhone (AirDrop, Email, or Web Server)."
echo "   (You can run 'python3 -m http.server 8000' in the certs directory and download it)"
echo "2. on iPhone: Settings > General > VPN & Device Management > Install User Profile."
echo "3. on iPhone: Settings > General > About > Certificate Trust Settings > Enable full trust for 'MattermostLocalRootCA'."
echo "----------------------------------------------------------------"

```

4. 创建 Nginx 配置，把证书挂载进去

```conf
# mattermost
# config can be tested on https://www.ssllabs.com/ssltest/ and a good nginx config generator
# can be found at https://ssl-config.mozilla.org/

# upstream used in proxy_pass below
upstream backend {
    # ip where Mattermost is running; this relies on a working DNS inside the Docker network
    # and uses the hostname of the mattermost container (see service name in docker-compose.yml)
    server mattermost.local.orb.local:8065;
    keepalive 64;
}

# vhosts definitions
server {
    server_name mattermost.mbpm3;
    listen 80;
    listen [::]:80;

    # redirect all HTTP requests to HTTPS with a 301 Moved Permanently response.
    return 301 https://$host$request_uri;
}

server {
    server_name mattermost.mbpm3;
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;

    # logging
    access_log /var/log/nginx/mattermost-access.log;
    error_log /var/log/nginx/mattermost-error.log warn;

    # gzip for performance
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/rss+xml application/atom+xml image/svg+xml;

    ## ssl
    # ssl_dhparam /dhparams4096.pem; # Commented out as likely not generated
    ssl_session_timeout 1d;
    ssl_session_cache shared:MozSSL:10m;
    ssl_session_tickets off;

    # intermediate configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
    ssl_prefer_server_ciphers off;

    # certs sent to the client in SERVER HELLO are concatenated in ssl_certificate
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/key-no-password.pem;

    # enable TLSv1.3's 0-RTT. Use $ssl_early_data when reverse proxying to prevent replay attacks.
    # https://nginx.org/en/docs/http/ngx_http_ssl_module.html#ssl_early_data
    ssl_early_data on;

    # OCSP stapling
    # ssl_stapling on; # Disable OCSP stapling for self-signed certs or if connectivity is an issue
    # ssl_stapling_verify on;
    #resolver 1.1.1.1;

    # verify chain of trust of OCSP response using Root CA and Intermediate certs
    #ssl_trusted_certificate /etc/ssl/certs/ca-certificates.crt;

    ## security headers
    # https://securityheaders.com/
    # https://scotthelme.co.uk/tag/security-headers/
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy no-referrer;
    add_header Strict-Transport-Security "max-age=63072000" always;
    add_header Permissions-Policy "interest-cohort=()";

    ## locations
    # ACME-challenge
    location ^~ /.well-known {
        default_type "text/plain";
        root /usr/share/nginx/html;
        allow all;
    }

    # disable Google bots from indexing this site
    add_header X-Robots-Tag "noindex";

    location ~ /api/v[0-9]+/(users/)?websocket$ {
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        client_max_body_size 50M;
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_set_header Early-Data $ssl_early_data;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        client_body_timeout 60;
        send_timeout 300;
        lingering_timeout 5;
        proxy_connect_timeout 90;
        proxy_send_timeout 300;
        proxy_read_timeout 90s;
        proxy_http_version 1.1;
        proxy_pass http://backend;
    }

    location / {
        client_max_body_size 50M;
        proxy_set_header Connection "";
        proxy_set_header Host $http_host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Frame-Options SAMEORIGIN;
        proxy_set_header Early-Data $ssl_early_data;
        proxy_buffers 256 16k;
        proxy_buffer_size 16k;
        proxy_read_timeout 600s;
        # proxy_cache mattermost_cache; # cache zone not defined in global nginx.conf, commenting out
        # proxy_cache_revalidate on;
        # proxy_cache_min_uses 2;
        # proxy_cache_use_stale timeout;
        # proxy_cache_lock on;
        proxy_http_version 1.1;
        proxy_pass http://backend;
    }
}
```

5. iPhone 手机下载并信任这个证书，下载 Mattermost app 连上服务器试试
6. 配置 Pi Hole 里面的 local DNS record, 把 `mattermost.mbpm3`指向本机的 IP 地址。我这里指向的就是 Tailscale 里的 machine 地址。

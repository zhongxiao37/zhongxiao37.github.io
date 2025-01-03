---
layout: default
title: 如何在Kubernetes上搭建Dify
date: 2024-12-19 09:28 +0800
categories: llm
---

本文是基于[Winson-030的代码](https://github.com/Winson-030/dify-kubernetes/tree/feature/pvc-volume)部署的。


## 创建Namespace

```yaml
# Namespace
apiVersion: v1
kind: Namespace
metadata:
  name: dify  

```

## 创建PV

我用的PV+OSS部署的方式

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
    - kubernetes.io/pv-protection
  labels:
    alicloud-pvname: oss-dify
  name: pv-dify
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 20Gi
  flexVolume:
    driver: alicloud/oss
    options:
      akId: ALIYUN_ACCESS_KEY
      akSecret: ALIYUN_SECRET_KEY
      bucket: ALIYUN_OSS_BUCKET_NAME
      otherOpts: ""
      url: oss-cn-beijing-internal.aliyuncs.com
  persistentVolumeReclaimPolicy: Retain
  storageClassName: oss
  volumeMode: Filesystem
```

## 创建PVC绑定PV

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  finalizers:
    - kubernetes.io/pvc-protection
  name: pvc-dify
  namespace: dify
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  selector:
    matchLabels:
      alicloud-pvname: oss-dify
  storageClassName: oss
  volumeMode: Filesystem
  volumeName: pv-dify
```

## 部署向量数据库weaviate

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-weaviate
  namespace: dify
spec:
  selector:
    matchLabels:
      app: dify-weaviate
  replicas: 1
  template:
    metadata:
      labels:
        app: dify-weaviate
    spec:
      terminationGracePeriodSeconds: 10
      volumes:
        - name: volume-dify
          persistentVolumeClaim:
            claimName: pvc-dify
      containers:
        - name: dify-weaviate
          image: weaviate:1.19.0
          volumeMounts:
            - mountPath: /var/lib/weaviate
              name: volume-dify
              subPath: weaviate-data
          ports:
            - containerPort: 8080
              name: weaviate-p
          resources:
            limits:
              cpu: 500m
              memory: 1024Mi
            requests:
              cpu: 100m
              memory: 102Mi
          env:
            - name: QUERY_DEFAULTS_LIMIT
              value: "25"
            - name: AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED
              value: "false"
            - name: PERSISTENCE_DATA_PATH
              value: "/var/lib/weaviate"
            - name: "DEFAULT_VECTORIZER_MODULE"
              value: "none"
            - name: "AUTHENTICATION_APIKEY_ENABLED"
              value: "true"
            - name: "AUTHENTICATION_APIKEY_ALLOWED_KEYS"
              value: "WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"
            - name: "AUTHENTICATION_APIKEY_USERS"
              value: "hello@dify.ai"
            - name: "AUTHORIZATION_ADMINLIST_ENABLED"
              value: "true"
            - name: "AUTHORIZATION_ADMINLIST_USERS"
              value: "hello@dify.ai"

---
apiVersion: v1
kind: Service
metadata:
  name: dify-weaviate
  namespace: dify
spec:
  selector:
    app: dify-weaviate
  type: ClusterIP
  clusterIP: None
  ports:
  - name: weaviate
    protocol: TCP
    port: 8080
    targetPort: 8080
```

## 部署Sandbox

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-sandbox
  namespace: dify
  labels:
    app: dify-sandbox
spec:
  replicas: 1
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app: dify-sandbox
  template:
    metadata:
      labels:
        app: dify-sandbox
    spec:
      containers:
        - name: dify-sandbox
          image: dify-sandbox:0.2.10
          env:
          - name: API_KEY
            value: "dify-sandbox"
          - name: GIN_MODE
            value: "release"
          - name: WORKER_TIMEOUT
            value: "15"
          - name: ENABLE_NETWORK
            value: "true"
          - name: SANDBOX_PORT
            value: "8194"
            # uncomment if you want to use proxy
          - name: HTTP_PROXY
            value: 'http://dify-ssrf:3128'
          - name: HTTPS_PROXY
            value: 'http://dify-ssrf:3128'
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 1Gi
          ports:
          - containerPort: 8194
          imagePullPolicy: IfNotPresent

---
apiVersion: v1
kind: Service
metadata:
  name: dify-sandbox
  namespace: dify
spec:
  ports:
  - port: 8194
    targetPort: 8194
    protocol: TCP
    name: dify-sandbox
  type: ClusterIP
  clusterIP: None
  selector:
    app: dify-sandbox
```


## 部署ssrf

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssrf-proxy-config
  namespace: dify
data:
  squid.conf: |
    acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
    acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
    acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
    acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
    acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
    acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
    acl localnet src fc00::/7       	# RFC 4193 local private network range
    acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines
    acl SSL_ports port 443
    acl Safe_ports port 80		# http
    acl Safe_ports port 21		# ftp
    acl Safe_ports port 443		# https
    acl Safe_ports port 70		# gopher
    acl Safe_ports port 210		# wais
    acl Safe_ports port 1025-65535	# unregistered ports
    acl Safe_ports port 280		# http-mgmt
    acl Safe_ports port 488		# gss-http
    acl Safe_ports port 591		# filemaker
    acl Safe_ports port 777		# multiling http
    acl CONNECT method CONNECT
    http_access deny !Safe_ports
    http_access deny CONNECT !SSL_ports
    http_access allow localhost manager
    http_access deny manager
    http_access allow localhost
    http_access allow localnet
    http_access deny all

    ################################## Proxy Server ################################
    http_port 3128
    coredump_dir /var/spool/squid
    refresh_pattern ^ftp:		1440	20%	10080
    refresh_pattern ^gopher:	1440	0%	1440
    refresh_pattern -i (/cgi-bin/|\?) 0	0%	0
    refresh_pattern \/(Packages|Sources)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
    refresh_pattern \/Release(|\.gpg)$ 0 0% 0 refresh-ims
    refresh_pattern \/InRelease$ 0 0% 0 refresh-ims
    refresh_pattern \/(Translation-.*)(|\.bz2|\.gz|\.xz)$ 0 0% 0 refresh-ims
    refresh_pattern .		0	20%	4320
    

    # upstream proxy, set to your own upstream proxy IP to avoid SSRF attacks
    # cache_peer 172.1.1.1 parent 3128 0 no-query no-digest no-netdb-exchange default 


    ################################## Reverse Proxy To Sandbox ################################
    http_port 8194 accel vhost
    # Notice:
    # default is 'sandbox' in dify's github repo, here is 'dify-sandbox' because the service name of sandbox is 'dify-sandbox'
    # you can change it to your own service name
    cache_peer dify-sandbox parent 8194 0 no-query originserver
    acl src_all src all
    http_access allow src_all

---  
apiVersion: v1
kind: ConfigMap
metadata:
  name: ssrf-proxy-entrypoint
  namespace: dify
data:
  docker-entrypoint-mount.sh: |
    #!/bin/bash

    # Modified based on Squid OCI image entrypoint
    
    # This entrypoint aims to forward the squid logs to stdout to assist users of
    # common container related tooling (e.g., kubernetes, docker-compose, etc) to
    # access the service logs.
    
    # Moreover, it invokes the squid binary, leaving all the desired parameters to
    # be provided by the "command" passed to the spawned container. If no command
    # is provided by the user, the default behavior (as per the CMD statement in
    # the Dockerfile) will be to use Ubuntu's default configuration [1] and run
    # squid with the "-NYC" options to mimic the behavior of the Ubuntu provided
    # systemd unit.
    
    # [1] The default configuration is changed in the Dockerfile to allow local
    # network connections. See the Dockerfile for further information.
    
    echo "[ENTRYPOINT] re-create snakeoil self-signed certificate removed in the build process"
    if [ ! -f /etc/ssl/private/ssl-cert-snakeoil.key ]; then
        /usr/sbin/make-ssl-cert generate-default-snakeoil --force-overwrite > /dev/null 2>&1
    fi
    
    tail -F /var/log/squid/access.log 2>/dev/null &
    tail -F /var/log/squid/error.log 2>/dev/null &
    tail -F /var/log/squid/store.log 2>/dev/null &
    tail -F /var/log/squid/cache.log 2>/dev/null &
    
    # Replace environment variables in the template and output to the squid.conf
    echo "[ENTRYPOINT] replacing environment variables in the template"
    awk '{
        while(match($0, /\${[A-Za-z_][A-Za-z_0-9]*}/)) {
            var = substr($0, RSTART+2, RLENGTH-3)
            val = ENVIRON[var]
            $0 = substr($0, 1, RSTART-1) val substr($0, RSTART+RLENGTH)
        }
        print
    }' /etc/squid/squid.conf.template > /etc/squid/squid.conf
    
    /usr/sbin/squid -Nz
    echo "[ENTRYPOINT] starting squid"
    /usr/sbin/squid -f /etc/squid/squid.conf -NYC 1
   
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name:  dify-ssrf
  namespace: dify
  labels:
    app:  dify-ssrf
spec:
  selector:
    matchLabels:
      app: dify-ssrf
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app:  dify-ssrf
    spec:
      containers:
      - name:  dify-ssrf
        image: squid:6.6-24.04_edge
        env:
        - name: HTTP_PORT
          value: "3128"
        - name: COREDUMP_DIR
          value: "/var/spool/squid"    
        - name: REVERSE_PROXY_PORT
          value: "8194"
        - name: SANDBOX_HOST
          value: "dify-sandbox"
        - name: SANDBOX_PORT
          value: "8194"
        resources:
          requests:
            cpu: 100m
            memory: 100Mi
          limits:
            cpu: 300m
            memory: 300Mi
        ports:
        - containerPort:  3128
          name:  dify-ssrf
        volumeMounts:
        - name: ssrf-proxy-config
          mountPath: /etc/squid/
        - name: ssrf-proxy-entrypoint
          mountPath: /tmp/
        command: [ "sh", "-c", "cp /tmp/docker-entrypoint-mount.sh /docker-entrypoint.sh && sed -i 's/\r$$//' /docker-entrypoint.sh && chmod +x /docker-entrypoint.sh && /docker-entrypoint.sh" ]
      volumes:
        - name: ssrf-proxy-config
          configMap:
            name: ssrf-proxy-config
        - name: ssrf-proxy-entrypoint
          configMap:
            name: ssrf-proxy-entrypoint
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: dify-ssrf
  namespace: dify
spec:
  selector:
    app: dify-ssrf
  ports:
  - protocol: TCP
    port: 3128
    targetPort: 3128
```


## 部署API

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-api
  labels:
    app.kubernetes.io/instance: dify-api
    app: dify-api
  namespace: dify
spec:
  replicas: 1
  revisionHistoryLimit: 1
  minReadySeconds: 10
  selector:
    matchLabels:
      app: dify-api
  template:
    metadata:
      labels:
        app: dify-api
    spec:
      volumes:
      - name: volume-dify
        persistentVolumeClaim:
          claimName: pvc-dify
      containers:
        - name: dify-api
          image: dify-api:0.13.1
          env:
          - name: MODE
            value: api
          - name: LOG_LEVEL
            value: DEBUG
          - name: SECRET_KEY
            value: "sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U"
          - name: CONSOLE_WEB_URL
            value: ""
          - name: INIT_PASSWORD
            value: password
          - name: CONSOLE_API_URL
            value: ""
          - name: SERVICE_API_URL
            value: ""
          - name: APP_WEB_URL
            value: ""
          - name: FILES_URL
            value: ""
          - name: MIGRATION_ENABLED
            value: "true"
          - name: DB_USERNAME
            value: dify
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-username
          - name: DB_PASSWORD
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-password
          - name: DB_HOST
            value: dify-pg
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-host
          - name: DB_PORT
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-port
          - name: DB_DATABASE
            value: dify
          - name: REDIS_HOST
            value: dify-redis
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-host
          - name: REDIS_PORT
            value: '6379'
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-port
            # default redis username is empty
          - name: REDIS_USERNAME
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-username
          - name: REDIS_PASSWORD
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-password
          - name: REDIS_USE_SSL
            value: "false"
          - name: REDIS_DB
            value: "0"
          - name: CELERY_BROKER_URL
            value: >-
              redis://$(REDIS_USERNAME):$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/1
          - name: WEB_API_CORS_ALLOW_ORIGINS
            value: "*"
          - name: CONSOLE_CORS_ALLOW_ORIGINS
            value: "*"
          - name: STORAGE_TYPE
            value: "*"
          - name: STORAGE_LOCAL_PATH
            value: /app/api/storage
          - name: VECTOR_STORE
            value: weaviate
          - name: WEAVIATE_HOST
            value: dify-weaviate
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: weaviate-host
          - name: WEAVIATE_PORT
            value: '8080'
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: weaviate-port
          - name: WEAVIATE_ENDPOINT
            value: http://$(WEAVIATE_HOST):$(WEAVIATE_PORT)
          - name: WEAVIATE_API_KEY
            value: "WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"
          - name: CODE_EXECUTION_ENDPOINT
            value: http://dify-sandbox:8194
          - name: CODE_EXECUTION_API_KEY
            value: dify-sandbox
          - name: CODE_MAX_NUMBER
            value: "9223372036854775807"
          - name: CODE_MIN_NUMBER
            value: "-9223372036854775808"
          - name: CODE_MAX_STRING_LENGTH
            value: "80000"
          - name: TEMPLATE_TRANSFORM_MAX_LENGTH
            value: "80000"
          - name: CODE_MAX_STRING_ARRAY_LENGTH
            value: "30"
          - name: CODE_MAX_OBJECT_ARRAY_LENGTH
            value: "30"
          - name: CODE_MAX_NUMBER_ARRAY_LENGTH
            value: "1000"
          - name: INDEXING_MAX_SEGMENTATION_TOKENS_LENGTH
            value: "1000"
            # uncommect to enable SSRF
          - name: SSRF_PROXY_HTTP_URL
            value: 'http://dify-ssrf:3128'
          - name: SSRF_PROXY_HTTPS_URL
            value: 'http://dify-ssrf:3128'
          - name: 'SENTRY_DSN'
            value: ''
          - name: 'SENTRY_TRACES_SAMPLE_RATE'
            value: '1.0'
          - name: 'SENTRY_PROFILES_SAMPLE_RATE'
            value: '1.0'
          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 1000m
              memory: 2Gi
          ports:
            - containerPort: 5001
          imagePullPolicy: IfNotPresent
          volumeMounts:
            - mountPath: /app/api/storage
              name: volume-dify
              subPath: dify-api-storage
---
apiVersion: v1
kind: Service
metadata:
  name: dify-api
  namespace: dify
spec:
  ports:
  - port: 5001
    targetPort: 5001
    protocol: TCP
    name: dify-api
  type: ClusterIP
  selector:
    app: dify-api

```

## 创建Worker

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-worker
  namespace: dify
  labels:
    app: dify-worker
    app.kubernetes.io/instance: dify-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: dify-worker
  template:
    metadata:
      labels:
        app: dify-worker
    spec:
      volumes:
      - name: volume-dify
        persistentVolumeClaim:
          claimName: pvc-dify
      containers:
      - name: dify-worker
        image: dify-api:0.13.1
        ports:
        - containerPort: 5001
          protocol: TCP
        env:
          - name: CONSOLE_WEB_URL
            value: ""
          - name: MODE
            value: worker
          - name: LOG_LEVEL
            value: INFO
          - name: SECRET_KEY
            value: "sk-9f73s3ljTXVcMT3Blb3ljTqtsKiGHXVcMT3BlbkFJLK7U"
          - name: DB_USERNAME
            value: dify
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-username
          - name: DB_PASSWORD
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-password
          - name: DB_HOST
            value: dify-pg
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-host
          - name: DB_PORT
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: pg-port
          - name: DB_DATABASE
            value: dify
          - name: REDIS_HOST
            value: dify-redis
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-host
          - name: REDIS_PORT
            value: '6379'
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-port
            # default redis username is empty
          - name: REDIS_USERNAME
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-username
          - name: REDIS_PASSWORD
            value: ''
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: redis-password
          - name: REDIS_USE_SSL
            value: "false"
          - name: REDIS_DB
            value: "0"
          - name: CELERY_BROKER_URL
            value: >-
              redis://$(REDIS_USERNAME):$(REDIS_PASSWORD)@$(REDIS_HOST):$(REDIS_PORT)/1
          - name: WEB_API_CORS_ALLOW_ORIGINS
            value: "*"
          - name: CONSOLE_CORS_ALLOW_ORIGINS
            value: "*"
          - name: STORAGE_TYPE
            value: "*"
          - name: STORAGE_LOCAL_PATH
            value: /app/api/storage
          - name: VECTOR_STORE
            value: weaviate
          - name: WEAVIATE_HOST
            value: dify-weaviate
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: weaviate-host
          - name: WEAVIATE_PORT
            value: '8080'
            # valueFrom:
            #   secretKeyRef:
            #     name: dify-credentials
            #     key: weaviate-port
          - name: WEAVIATE_ENDPOINT
            value: http://$(WEAVIATE_HOST):$(WEAVIATE_PORT)
          - name: WEAVIATE_API_KEY
            value: "WVF5YThaHlkYwhGUSmCRgsX3tD5ngdN8pkih"
          - name: SSRF_PROXY_HTTP_URL
            value: 'http://dify-ssrf:3128'
          - name: SSRF_PROXY_HTTPS_URL
            value: 'http://dify-ssrf:3128'
          - name: 'SENTRY_DSN'
            value: ''
          - name: 'SENTRY_TRACES_SAMPLE_RATE'
            value: '1.0'
          - name: 'SENTRY_PROFILES_SAMPLE_RATE'
            value: '1.0'
        resources:
          requests:
            cpu: 200m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 2Gi
        volumeMounts:
          - mountPath: /app/api/storage
            name: volume-dify
            subPath: dify-api-storage
      restartPolicy: Always

---
apiVersion: v1
kind: Service
metadata:
  name: dify-worker
  namespace: dify
spec:
  ports:
  - protocol: TCP
    port: 5001
    targetPort: 5001
  selector:
    app: dify-worker
  type: ClusterIP
```

## 创建 Web

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-web
  namespace: dify
  labels:
    app: dify-web
spec:
  replicas: 1
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app: dify-web
  template:
    metadata:
      labels:
        app: dify-web
    spec:
      automountServiceAccountToken: false
      containers:
      - name: dify-web
        image: dify-web:0.13.1
        env:
        - name: EDITION
          value: SELF_HOSTED
        - name: CONSOLE_API_URL
          value: ""
        - name: APP_API_URL
          value: ""
        - name: SENTRY_DSN
          value: ""
        - name: NEXT_TELEMETRY_DISABLED
          value: "0"
        - name: TEXT_GENERATION_TIMEOUT_MS
          value: "60000"
        - name: CSP_WHITELIST
          value: ""
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 1Gi
        ports:
        - containerPort: 3000
        imagePullPolicy: IfNotPresent

---
apiVersion: v1
kind: Service
metadata:
  name: dify-web
  namespace: dify
spec:
  ports:
  - port: 3000
    targetPort: 3000
    protocol: TCP
    name: dify-web
  type: ClusterIP
  selector:
    app: dify-web
```

## 创建Nginx

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: dify-nginx
  namespace: dify
data:
  nginx.conf: |-
    user  nginx;
    worker_processes  auto;

    error_log  /var/log/nginx/error.log notice;
    pid        /var/run/nginx.pid;


    events {
        worker_connections  1024;
    }


    http {
        include       /etc/nginx/mime.types;
        default_type  application/octet-stream;

        log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                          '$status $body_bytes_sent "$http_referer" '
                          '"$http_user_agent" "$http_x_forwarded_for"';

        access_log  /var/log/nginx/access.log  main;

        sendfile        on;
        #tcp_nopush     on;

        keepalive_timeout  65;

        #gzip  on;
        client_max_body_size 15M;

        server {
        listen 80;
        server_name _;

        location /console/api {
          proxy_pass http://dify-api:5001;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        }

        location /api {
          proxy_pass http://dify-api:5001;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        }

        location /v1 {
          proxy_pass http://dify-api:5001;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        }

        location /files {
          proxy_pass http://dify-api:5001;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        }

        location / {
          proxy_pass http://dify-web:3000;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $scheme;
          proxy_http_version 1.1;
          proxy_set_header Connection "";
          proxy_buffering off;
          proxy_read_timeout 3600s;
          proxy_send_timeout 3600s;
        }

        # If you want to support HTTPS, please uncomment the code snippet below
        #listen 443 ssl;
        #ssl_certificate ./../ssl/your_cert_file.cer;
        #ssl_certificate_key ./../ssl/your_cert_key.key;
        #ssl_protocols TLSv1.1 TLSv1.2 TLSv1.3;
        #ssl_prefer_server_ciphers on;
        #ssl_session_cache shared:SSL:10m;
        #ssl_session_timeout 10m;
    }
    }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dify-nginx
  namespace: dify
  labels:
    app: dify-nginx
spec:
  replicas: 1
  revisionHistoryLimit: 1
  selector:
    matchLabels:
      app: dify-nginx
  template:
    metadata:
      labels:
        app: dify-nginx
    spec:
      automountServiceAccountToken: false
      containers:
      - name: dify-nginx
        image: nginx:latest
        resources:
          requests:
            cpu: 50m
            memory: 128Mi
          limits:
            cpu: 500m
            memory: 1Gi
        ports:
        - containerPort: 80
        volumeMounts:
        - name: dify-nginx
          mountPath: /etc/nginx/nginx.conf
          subPath: nginx.conf
        - name: dify-nginx-config
          mountPath: /etc/nginx/conf.d
        imagePullPolicy: IfNotPresent
      volumes:
        - name: dify-nginx
          configMap:
            name: dify-nginx
        # Persistent volume could be better
        - name: dify-nginx-config
          emptyDir: {}
---
kind: Service
apiVersion: v1
metadata:
  name: dify-nginx
  namespace: dify
spec:
  selector:
    app: dify-nginx
  type: ClusterIP
  ports:
  - name: dify-nginx
    port: 8080
    targetPort: 80
```

## 创建Ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: dify-ingress
  namespace: dify
spec:
  ingressClassName: nginx
  rules:
    - host: your.domain.name
      http:
        paths:
          - backend:
              service:
                name: dify-nginx
                port:
                  number: 8080
            path: /
            pathType: ImplementationSpecific
  tls:
    - hosts:
        - your.domain.name
      secretName: secret-tls

```

## FAQ

我们的阿里云ACK是Serverless的，默认是没有安装CoreDNS。需要安装CoreDNS，否则没法通过Service访问Pod.


## Demo

由于之前自己已经通过Bert部署了意图识别和意图处理两个微服务，我需要的就是调用这两个微服务，然后拼起来。

<img src="/images/dify_intent_classifier.png" width="1200px">

<img src="/images/dify_intent_processor.png" width="1200px">

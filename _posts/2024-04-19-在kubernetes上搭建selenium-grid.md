---
layout: default
title: 在Kubernetes上搭建Selenium Grid
date: 2024-04-19 13:27 +0800
categories: selenium
---

本文是基于 Kubernetes[官网的示例][1]搭建的，只是重新用 Kustomize 排版了一下。

```yml
# namespace-selenium.yml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: selenium
  name: selenium
```

```yml
# deployment-selenium-hum.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selenium-hub
  namespace: selenium
  labels:
    app: selenium-hub
spec:
  replicas: 1
  selector:
    matchLabels:
      app: selenium-hub
  template:
    metadata:
      labels:
        app: selenium-hub
    spec:
      containers:
        - name: selenium-hub
          image: selenium/hub:4.0
          ports:
            - containerPort: 4444
            - containerPort: 4443
            - containerPort: 4442
          resources:
            limits:
              memory: "1000Mi"
              cpu: ".5"
          livenessProbe:
            httpGet:
              path: /wd/hub/status
              port: 4444
            initialDelaySeconds: 30
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /wd/hub/status
              port: 4444
            initialDelaySeconds: 30
            timeoutSeconds: 5
```

```yml
# deployment-selenium-node-chrome.yml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: selenium-node-chrome
  namespace: selenium
  labels:
    app: selenium-node-chrome
spec:
  replicas: 2
  selector:
    matchLabels:
      app: selenium-node-chrome
  template:
    metadata:
      labels:
        app: selenium-node-chrome
    spec:
      volumes:
        - name: dshm
          emptyDir:
            medium: Memory
      containers:
        - name: selenium-node-chrome
          image: selenium/node-chrome:4.0
          ports:
            - containerPort: 5555
          volumeMounts:
            - mountPath: /dev/shm
              name: dshm
          env:
            - name: SE_EVENT_BUS_HOST
              value: "selenium-hub"
            - name: SE_EVENT_BUS_SUBSCRIBE_PORT
              value: "4443"
            - name: SE_EVENT_BUS_PUBLISH_PORT
              value: "4442"
          resources:
            limits:
              memory: "1000Mi"
              cpu: ".5"
```

```yml
# service-selenium-hub.yml
apiVersion: v1
kind: Service
metadata:
  name: selenium-hub
  namespace: selenium
  labels:
    app: selenium-hub
spec:
  ports:
    - port: 4444
      targetPort: 4444
      name: port0
    - port: 4443
      targetPort: 4443
      name: port1
    - port: 4442
      targetPort: 4442
      name: port2
  selector:
    app: selenium-hub
  type: NodePort
  sessionAffinity: None
```

```yml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
metadata:
  name: selenium-grid

resources:
  - namespace-selenium.yml
  - deployment-selenium-hub.yml
  - service-selenium-hub.yml
  - deployment-selenium-node-chrome.yml
```

最后`k apply -k .`一键拉起 Selenium Grid。

## Selenium dashboard

可以通过下面的命令，转发端口 4444，就可以登陆 Selenium Grid 查看运行的 session。还可以通过 VNC watch pod 内部的操作(密码 secret)。

```bash
k port-forward svc/selenium-hub -n selenium 4444:4444
```

[1]: https://github.com/kubernetes/examples/blob/master/staging/selenium/README.md

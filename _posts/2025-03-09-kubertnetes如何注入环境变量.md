---
layout: default
title: Kubertnetes如何注入环境变量
date: 2025-03-09 14:42 +0800
categories: kubernetes
---

需求是需要在Pod里面注入一些环境变量，比如VPC和NAT IP，还有镜像的tag方便health check的时候返回版本号。


## 确认Kubernetes 支持 Admission Webhook

```bash
kubectl api-versions | grep admissionregistration.k8s.io
```

输出`admissionregistration.k8s.io`即支持。

## 创建Webhook application

```python
from flask import Flask, request, jsonify
import json
import subprocess
import base64
import os

app = Flask(__name__)

@app.route('/mutate', methods=['POST'])
def mutate():

if request.content_type != 'application/json':
        return jsonify({"error": "Content-Type must be application/json"}), 400

    try:
        request_data = request.get_json()
        uid = request_data['request']['uid']
        resource_kind = request_data['request']['kind']['kind']
        resource_obj = request_data['request']['object']

        # 初始化 patch 数组
        patch = []

        if resource_kind == "Pod" or resource_kind == "Deployment":
            # 判断是 Pod 或 Deployment
            is_pod = resource_kind == "Pod"

            # 获取容器列表
            containers = (resource_obj.get('spec', {}).get('containers', [])
                          if is_pod
                          else resource_obj.get('spec', {}).get('template', {}).get('spec', {}).get('containers', []))

            if containers:
                if 'env' not in containers[0]:
                    patch.append({
                        "op": "add",
                        "path": f"/{'spec' if is_pod else 'spec/template/spec'}/containers/0/env",
                        "value": []
                    })

                # inject image tag
                image = containers[0]['image']
                if image is not None:
                    image_tag = image.split(':')[-1]
                    patch.append({
                        "op": "add",
                        "path": f"/{'spec' if is_pod else 'spec/template/spec'}/containers/0/env/-",
                        "value": {"name": "IMAGE_TAG", "value": image_tag}
                    })
        else:
            print(f"Unsupported resource kind: {resource_kind}")
            return jsonify({"error": "Unsupported resource kind"}), 400


        patch_str = json.dumps(patch)
        patch_base64 = base64.b64encode(patch_str.encode('utf-8')).decode('utf-8')
        response = {
            "apiVersion": "admission.k8s.io/v1",
            "kind": "AdmissionReview",
            "response": {
                "uid": uid,
                "allowed": True,
                "patchType": "JSONPatch",
                "patch": patch_base64
            }
        }

        return jsonify(response)

    except Exception as e:
        print(f"Error processing request: {e}")
        return jsonify({"error": "Internal server error"}), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=443, ssl_context=('server.crt', 'server.key'))
```

## 创建自签证书

注意subj是自己在Kubernetes里面定义的Service的名字，详见后续步骤

```bash
openssl req -x509 -newkey rsa:4096 -keyout server.key -out server.crt -days 365 -nodes -subj "/CN=env-injector.default.svc"
```

```bash
kubectl create secret generic env-injector-secret --from-file=server.crt --from-file=server.key
```


## 构建镜像

```Dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY webhook.py /app/
RUN pip install flask
CMD ["python", "webhook.py"]
```


## 部署到Kubernetes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: env-injector
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: env-injector
  template:
    metadata:
      labels:
        app: env-injector
    spec:
      containers:
      - name: env-injector
        image: myregistry/env-injector:latest
        ports:
        - containerPort: 443
        volumeMounts:
        - name: certs
          mountPath: /app
      volumes:
      - name: certs
        secret:
          secretName: env-injector-secret
---
apiVersion: v1
kind: Service
metadata:
  name: env-injector
  namespace: default
spec:
  ports:
    - port: 443
      targetPort: 443
    selector:
      app: env-injector
```

## 定义 MutatingWebhookConfiguration CRD

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: custom-env-injector
webhooks:
  - admissionReviewVersions:
      - v1
    clientConfig:
      caBundle: <base64 caBundle>
      service:
        name: env-injector
        namespace: default
        path: /mutate
        port: 443
    failurePolicy: Fail
    matchPolicy: Equivalent
    name: env-injector.default.svc
    namespaceSelector: {}
    objectSelector:
      matchLabels:
        env-injection: enabled
    reinvocationPolicy: Never
    rules:
      - apiGroups:
          - ''
        apiVersions:
          - v1
        operations:
          - CREATE
        resources:
          - pods
          - deployments
        scope: '*'
    sideEffects: None
    timeoutSeconds: 5
```

## 测试

创建一个带有label为`env-injection: enabled`的Deployment，镜像的tag就会自动被注入到Pod里面。


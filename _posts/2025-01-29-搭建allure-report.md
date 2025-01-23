---
layout: default
title: 搭建Allure Report
date: 2025-01-29 11:29 +0800
categories: allure
---

Allure Report是一个查看测试报告的Web application，我用来和PlayWright集成。

## 安装

```bash
brew install allure
```

## 和PlayWright集成

安装`allure-playwright`

```bash
yarn add allure-playwright
```

首先生成测试报告，并查看。

```bash
yarn test --reporter=line,allure-playwright
allure generate ./allure-results -o ./allure-report --clean
```

## 保留history

上面步骤生成的测试报告是没有历史信息的，需要在allure generate之前，把历史信息复制过来。


```bash
yarn test --reporter=line,allure-playwright
cp -rf allure-report/history allure-results/
allure generate ./allure-results -o ./allure-report --clean
```

## 容器化

其实生成的报告是静态HTML，所以可以直接通过`http-server`来搭建一个静态网页。唯一的问题是，`allure generate ./allure-results -o ./allure-report --clean`会删掉`index.html`文件，导致`http-server`容器挂掉。所以需要先生成到临时目录，再复制过去。

```bash
cp -rf allure-report/history allure-results/
allure generate ./allure-results -o ./allure-temp-report --clean
rsync -av --remove-source-files ./allure-temp-report/ ./allure-report/
```

我创建了一个docker容器，方便我合并报告和托管测试报告。

`allure`命令行需要Java运行环境，所以我安装了`openjdk`。

```docker
FROM node:22-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends vim curl tree ca-certificates rsync openjdk-17-jdk && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME /usr/lib/jvm/java-17-openjdk-amd64
ENV PATH $JAVA_HOME/bin:$PATH

WORKDIR /app

RUN npm install -g http-server allure-commandline
RUN curl https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz -o aliyun-cli-linux-3.0.16-amd64.tgz \
    && tar xzvf aliyun-cli-linux-3.0.16-amd64.tgz \
    && cp aliyun /usr/local/bin

EXPOSE 8080

CMD ["http-server", "--cors", "8080", "-c-1"]
```

## Kubernetes

将Allure Report部署到Kubernetes集群。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  labels:
    alicloud-pvname: pv-allure
  name: pv-allure
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 200Gi
  csi:
    driver: ossplugin.csi.alibabacloud.com
    nodePublishSecretRef:
      name: pv-allure-secret
      namespace: allure
    volumeAttributes:
      bucket: oss-allure
      otherOpts: '-o allow_other -o umask=002'
      url: oss-cn-beijing.aliyuncs.com
    volumeHandle: pv-allure
  persistentVolumeReclaimPolicy: Retain
  storageClassName: oss
  volumeMode: Filesystem

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pv-allure
  namespace: allure
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 200Gi
  selector:
    matchLabels:
      alicloud-pvname: pv-allure
  storageClassName: oss
  volumeMode: Filesystem
  volumeName: pv-allure

---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: allure-report
  name: allure-report
  namespace: allure
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: allure-report
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: allure-report
    spec:
      containers:
        - args:
            - '--cors'
            - '8080'
            - '-c-1'
            - './allure-report'
          command:
            - http-server
          image: 'allure:latest'
          imagePullPolicy: IfNotPresent
          name: allure-report
          ports:
            - containerPort: 8080
              name: web
              protocol: TCP
          resources:
            requests:
              cpu: 250m
              memory: 512Mi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /app/allure-report
              name: allure-report
              subPath: playwright_automation_test/allure-report
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
        - name: allure-report
          persistentVolumeClaim:
            claimName: pv-airflow

---
apiVersion: v1
kind: Service
metadata:
  name: allure-report-svc
  namespace: allure
spec:
  internalTrafficPolicy: Cluster
  ipFamilies:
    - IPv4
  ipFamilyPolicy: SingleStack
  ports:
    - name: http
      port: 8080
      protocol: TCP
      targetPort: 8080
  selector:
    app: allure-report
  sessionAffinity: None
  type: ClusterIP

```

## 通过Airflow调度

我又创建了一个Airflow job，这样可以从OSS读取测试用例，然后派发到3个pod里面去执行，然后再把结果收集起来合并。

```python
import airflow
from datetime import datetime, timedelta

import os
import json
import base64
import pathlib
import logging
import random
import string
from airflow import DAG
from airflow.decorators import task
from collections import namedtuple

from airflow.operators.trigger_dagrun import TriggerDagRunOperator
from kubernetes.client import models as k8s
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
import pandas as pd

dag_id = 'playwright-automation-test'
dag_file_path = pathlib.Path(__file__).parent.resolve()

@task
def generate_batch_id(length=4):
  run_time_stamp = datetime.now().strftime("%Y%m%d%H%M%S")
  letters_and_digits = string.ascii_letters + string.digits
  run_id = ''.join(random.choice(letters_and_digits) for i in range(length)) 

  return run_time_stamp + '_' + run_id


def playwright_job(batch_id, shard_idx):
    # start the pod

    return KubernetesPodOperator(
        namespace="allure",
        image="playwright-worker:0.0.2",
        cmds=["bash", "-cx"],
        arguments=[f"aliyun configure set --profile default --mode AK --region=cn-beijing --access-key-id=$OSS_ACCESS_KEY_ID --access-key-secret=$OSS_ACCESS_KEY_SECRET && aliyun oss cp oss://oss-allure/playwright_automation_test/tests/ /app/tests/ -r -f && npx playwright test --reporter=line,blob --shard={shard_idx}/3; aliyun oss cp /app/blob-report oss://oss-allure/playwright_automation_test/blob-report/{batch_id}/ -r -f"],
        env_from=[k8s.V1EnvFromSource(secret_ref=k8s.V1SecretEnvSource(name='oss-allure'))],
        name=f"{dag_id}-pod",
        task_id=f"playwright-automation-test-worker-{shard_idx}",
        on_finish_action="delete_succeeded_pod",
        kubernetes_conn_id='k8s-conn-id',
        do_xcom_push=True
    )


def merge_reports(batch_id):
    return KubernetesPodOperator(
        namespace="allure",
        image="playwright-worker:0.0.2",
        cmds=["bash", "-cx"],
        arguments=[f"aliyun configure set --profile default --mode AK --region=cn-beijing --access-key-id=$OSS_ACCESS_KEY_ID --access-key-secret=$OSS_ACCESS_KEY_SECRET && aliyun oss cp oss://oss-allure/playwright_automation_test/blob-report/{batch_id}/ /app/blob-report/ -r -f && npx playwright merge-reports ./blob-report/ --reporter allure-playwright ./allure-results && aliyun oss cp ./allure-results oss://oss-allure/playwright_automation_test/allure-results/ -r -f"],
        env_from=[k8s.V1EnvFromSource(secret_ref=k8s.V1SecretEnvSource(name='oss-allure'))],
        name=f"{dag_id}-pod",
        task_id='merge-reports',
        on_finish_action="delete_succeeded_pod",
        kubernetes_conn_id='k8s-conn-id',
        do_xcom_push=True
    )


def generate_reports(batch_id):
    return KubernetesPodOperator(
        namespace="allure",
        image="allure:0.0.2",
        cmds=["bash", "-cx"],
        arguments=[f"aliyun configure set --profile default --mode AK --region=cn-beijing --access-key-id=$OSS_ACCESS_KEY_ID --access-key-secret=$OSS_ACCESS_KEY_SECRET && aliyun oss cp oss://oss-allure/playwright_automation_test/blob-report/{batch_id}/ /app/blob-report/ -r -f && npx playwright merge-reports ./blob-report/ --reporter allure-playwright ./allure-results && aliyun oss cp ./allure-results oss://oss-allure/playwright_automation_test/allure-results/ -r -f"],
        env_from=[k8s.V1EnvFromSource(secret_ref=k8s.V1SecretEnvSource(name='oss-allure'))],
        name=f"{dag_id}-pod",
        task_id='merge-reports',
        on_finish_action="delete_succeeded_pod",
        kubernetes_conn_id='k8s-conn-id',
        do_xcom_push=True
    )


args = {
    'owner': 'airflow',
    'start_date': airflow.utils.dates.days_ago(0),
    'email': ['xxx@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'provide_context': True
}


with DAG(
    dag_id,
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=90),
    tags=[],
    default_args=args,
    catchup=False
) as dag:

    batch_id = generate_batch_id()
    upload_report = TriggerDagRunOperator(
        task_id="trigger_allure_report",
        trigger_dag_id="ai-automation-allure",
        wait_for_completion=False
    )

    batch_id >> [playwright_job(batch_id, i) for i in [1,2,3]] >> merge_reports(batch_id) >> upload_report

```

为了避免多个合并任务同时在跑，所以将这个job单独出来，设置上`max_active_runs=1`。 这个job会根据最新的测试结果，生成新的测试报告。

```python
import airflow
from datetime import datetime, timedelta

import pathlib
from airflow import DAG
from airflow.decorators import task
from collections import namedtuple

from kubernetes.client import models as k8s
from airflow.providers.cncf.kubernetes.operators.pod import KubernetesPodOperator
import pandas as pd

dag_id = 'playwright-automation-allure'
dag_file_path = pathlib.Path(__file__).parent.resolve()

def generate_reports():

    return KubernetesPodOperator(
        namespace="allure",
        image="allure:0.0.2",
        cmds=["bash", "-cx"],
        arguments=[f"aliyun configure set --profile default --mode AK --region=cn-beijing --access-key-id=$OSS_ACCESS_KEY_ID --access-key-secret=$OSS_ACCESS_KEY_SECRET && aliyun oss cp oss://oss-allure/playwright_automation_test/allure-results/ /app/allure-results/ -r -f && aliyun oss cp oss://oss-allure/playwright_automation_test/allure-report/ /app/allure-report/ -r -f && cp -rf /app/allure-report/history /app/allure-results/ && allure generate ./allure-results -o ./allure-report --clean && aliyun oss cp ./allure-report oss://oss-allure/playwright_automation_test/allure-report/ -r -f"],
        env_from=[k8s.V1EnvFromSource(secret_ref=k8s.V1SecretEnvSource(name='oss-allure'))],
        name=f"{dag_id}-pod",
        task_id='generate-reports',
        on_finish_action="delete_succeeded_pod",
        kubernetes_conn_id='k8s-conn-id',
        do_xcom_push=True
    )

args = {
    'owner': 'airflow',
    'start_date': airflow.utils.dates.days_ago(0),
    'email': ['xxx@example.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'provide_context': True
}


with DAG(
    dag_id,
    schedule_interval=None,
    dagrun_timeout=timedelta(minutes=90),
    tags=[],
    default_args=args,
    max_active_runs=1,
    catchup=False
) as dag:

    generate_reports()

```
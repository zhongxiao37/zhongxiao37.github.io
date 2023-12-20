---
layout: default
title: 在阿里云ASK部署Airflow KubernetesExecutor
date: 2023-12-20 17:57 +0800
categories: airflow kubernetes
---

Airflow 的部署上，可以让 airflow scheduler 既当任务派发，又当任务处理。就像下图一样，webserver 只是给用户展示的界面而已，scheduler 就是既要又要。

<img src="/images/Deploying-Apache-Airflow-on-a-Kubernetes-Cluster-07.png"  style="width: 800px">

也可以分布式部署，比如官网介绍的[Celery Executor](https://airflow.apache.org/docs/apache-airflow/stable/core-concepts/executor/celery.html)。还有一种就是利用 Kubernetes 创建动态创建 Pod 处理任务，优点就是可以利用 Kubernetes 的 auto-scaling 支持高并发，不用空闲很多机器，缺点就是每次 pod 拉起的速度慢。

## 前提

1. 用过 Kubernetes
2. 用过 Airflow

## 概览

<img src="/images/arch-diag-kubernetes.png" style="width: 800px">

## 创建 Namespace

创建 Namespace

```yaml
apiVersion: v1
kind: Namespace
metadata:
  labels:
    kubernetes.io/metadata.name: airflow
  name: airflow
```

## 创建 PV 和 PVC

需要去阿里云创建一个用户，能够访问 OSS，生成 AK/SK。再通过下面创建 PV 和 PVC。一共需要创建两个 buckets，一个是保存日志的，一个是用来保存 Airflow Dag 的。下面只提供了 dags 的配置文件，logs 的配置文件复制一下，改改就行了。

```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  finalizers:
    - kubernetes.io/pv-protection
  labels:
    alicloud-pvname: airflow-dags
  name: airflow-dags
spec:
  accessModes:
    - ReadWriteMany
  capacity:
    storage: 20Gi
  flexVolume:
    driver: alicloud/oss
    options:
      akId: #你的阿里云用户的AK
      akSecret: #你的阿里云用户的AK
      bucket: airflow-dags
      otherOpts: ""
      url: oss-cn-beijing-internal.aliyuncs.com
  persistentVolumeReclaimPolicy: Retain
  storageClassName: oss
  volumeMode: Filesystem
```

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  finalizers:
    - kubernetes.io/pvc-protection
  name: pcv-airflow-dags
  namespace: airflow
spec:
  accessModes:
    - ReadWriteMany
  resources:
    requests:
      storage: 20Gi
  selector:
    matchLabels:
      alicloud-pvname: airflow-dags
  storageClassName: oss
  volumeMode: Filesystem
  volumeName: airflow-dags
```

## 创建 Deployment

这个时候可以部署 webserver 和 scheduler 了。数据库我就直接利用阿里云的托管 RDS，本地提前连上去执行一下`airflow db init`和`airflow users create ...`。

我们先用 LocalExecutor，把 Airflow 拉起来测试一下。

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: airflow-webserver
  name: airflow-webserver
  namespace: airflow
spec:
  progressDeadlineSeconds: 600
  replicas: 0
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: airflow-webserver
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: airflow-webserver
    spec:
      containers:
        - command:
            - airflow
            - webserver
          env:
            - name: AIRFLOW__CORE__EXECUTOR
              value: LocalExecutor
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: #数据库连接
            - name: AIRFLOW__WEBSERVER__SECRET_KEY
              value: #
          image: apache/airflow:2.8.0-python3.9
          imagePullPolicy: IfNotPresent
          name: airflow-webserver
          ports:
            - containerPort: 8080
              name: web-server
              protocol: TCP
          resources:
            requests:
              cpu: "1"
              memory: 2Gi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /opt/airflow/dags
              name: volume-pv-airflow-dags
            - mountPath: /opt/airflow/logs
              name: volume-pv-airflow-logs
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
        - name: volume-pv-airflow-dags
          persistentVolumeClaim:
            claimName: pcv-airflow-dags
        - name: volume-pv-airflow-logs
          persistentVolumeClaim:
            claimName: pcv-airflow-logs
```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: airflow-scheduler
  name: airflow-scheduler
  namespace: airflow
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: airflow-scheduler
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: airflow-scheduler
    spec:
      containers:
        - command:
            - airflow
            - scheduler
          env:
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: #数据库连接
            - name: AIRFLOW__CORE__EXECUTOR
              value: LocalExecutor #KubernetesExecutor
            - name: AIRFLOW__WEBSERVER__SECRET_KEY
              value: #
          image: "apache/airflow:2.8.0-python3.9"
          imagePullPolicy: IfNotPresent
          name: airflow-scheduler
          ports:
            - containerPort: 8793
              protocol: TCP
          resources:
            requests:
              cpu: "1"
              memory: 2Gi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /opt/airflow/dags
              name: volume-pv-airflow-dags
            - mountPath: /opt/airflow/logs
              name: volume-pv-airflow-logs
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
        - name: volume-pv-airflow-dags
          persistentVolumeClaim:
            claimName: pcv-airflow-dags
        - name: volume-pv-airflow-logs
          persistentVolumeClaim:
            claimName: pcv-airflow-logs
```

## 创建 ServiceAccount

如果上面测试了没有问题，可以开始创建 ServiceAccount。创建 ServiceAccount 是为了让我们的 scheduler pod 能够有权限创建新的 worker pod 去处理任务。

```yaml
kind: ServiceAccount
apiVersion: v1
metadata:
  name: airflow-scheduler
  namespace: airflow
  labels:
    tier: airflow
    component: scheduler
```

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: airflow-worker-role
  namespace: airflow
rules:
  - apiGroups:
      - ""
    resources:
      - services
      - endpoints
      - pods
    verbs:
      - get
      - list
      - create
      - delete
      - watch
      - patch
  - apiGroups:
      - ""
    resources:
      - pods/logs
    verbs:
      - get
      - list
      - create
      - delete
      - watch
      - patch
  - apiGroups:
      - ""
    resources:
      - pods/exec
    verbs:
      - get
      - list
      - create
      - delete
      - watch
      - patch
  - apiGroups:
      - ""
    resources:
      - events
    verbs:
      - list
```

```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: "airflow"
  name: airflow-scheduler-rolebinding
  labels:
    tier: airflow
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: airflow-worker-role
subjects:
  - kind: ServiceAccount
    name: airflow-scheduler
    namespace: "airflow"
```

## 创建 Pod 模版文件

如果要动态地创建 Pod 处理任务，还需要创建一个模版文件，这样 Airflow 知道如何去启动这个 Pod。把下面的内容保存为`airflow-pod-creator.yml`，放到 scheduler pod 里面去。

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: airflow-worker
  namespace: airflow
spec:
  containers:
    - name: base
      imagePullPolicy: IfNotPresent
      image: "apache/airflow:2.8.0-python3.9"
      env:
        - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
          value: #数据库连接
        - name: AIRFLOW__CORE__EXECUTOR
          value: "LocalExecutor"
        - name: AIRFLOW__KUBERNETES__NAMESPACE
          value: "airflow"
        - name: AIRFLOW__CORE__DAGS_FOLDER
          value: "/opt/airflow/dags"
        - name: AIRFLOW__KUBERNETES__DELETE_WORKER_PODS
          value: "False"
        - name: AIRFLOW__KUBERNETES__DELETE_WORKER_PODS_ON_FAILURE
          value: "False"
      volumeMounts:
        - mountPath: /opt/airflow/dags
          name: volume-pv-airflow-dags
        - mountPath: /opt/airflow/logs
          name: volume-pv-airflow-logs
  restartPolicy: Never
  serviceAccountName: "airflow-scheduler"
  volumes:
    - name: volume-pv-airflow-dags
      persistentVolumeClaim:
        claimName: pcv-airflow-dags
    - name: volume-pv-airflow-logs
      persistentVolumeClaim:
        claimName: pcv-airflow-logs
```

## 迁移到 KubernetesExecutor

现在就可以修改 scheduler 的 Deployment 文件

1. 指定运行的`serviceAccountName: airflow-scheduler`
2. 修改 AIRFLOW**CORE**EXECUTOR 为 `KubernetesExecutor`
3. 新增 AIRFLOW**KUBERNETES_EXECUTOR**NAMESPACE 为`airflow`
4. 指定 Pod 模版文件 `AIRFLOW__KUBERNETES__POD_TEMPLATE_FILE`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  creationTimestamp: "2023-12-19T10:07:15Z"
  labels:
    app: airflow-scheduler
  name: airflow-scheduler
  namespace: airflow
spec:
  progressDeadlineSeconds: 600
  replicas: 1
  revisionHistoryLimit: 10
  selector:
    matchLabels:
      app: airflow-scheduler
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      labels:
        app: airflow-scheduler
    spec:
      serviceAccountName: airflow-scheduler
      containers:
        - command:
            - airflow
            - scheduler
          env:
            - name: AIRFLOW__DATABASE__SQL_ALCHEMY_CONN
              value: #数据库连接
            - name: AIRFLOW__CORE__EXECUTOR
              value: KubernetesExecutor
            - name: AIRFLOW__KUBERNETES_EXECUTOR__NAMESPACE
              value: airflow
            - name: AIRFLOW__KUBERNETES__POD_TEMPLATE_FILE
              value: /opt/airflow/airflow-pod-creator.yml
            - name: AIRFLOW__WEBSERVER__SECRET_KEY
              value: #
          image: "apache/airflow:2.8.0-python3.9"
          imagePullPolicy: IfNotPresent
          name: airflow-scheduler
          ports:
            - containerPort: 8793
              protocol: TCP
          resources:
            requests:
              cpu: "1"
              memory: 2Gi
          terminationMessagePath: /dev/termination-log
          terminationMessagePolicy: File
          volumeMounts:
            - mountPath: /opt/airflow/dags
              name: volume-pv-airflow-dags
            - mountPath: /opt/airflow/logs
              name: volume-pv-airflow-logs
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      schedulerName: default-scheduler
      securityContext: {}
      terminationGracePeriodSeconds: 30
      volumes:
        - name: volume-pv-airflow-dags
          persistentVolumeClaim:
            claimName: pcv-airflow-dags
        - name: volume-pv-airflow-logs
          persistentVolumeClaim:
            claimName: pcv-airflow-logs
```

## 最后

我没有配置域名和 Ingress，需要自己把 webserver 的端口 forward 出来，比如`k port-forward airflow-webserver-697b67bcb5-dv5bt -n airflow 8080:8080`。测试下来，原来可能需要 8 秒的任务，现在要一分钟才跑得完，中间很多时间都是在拉起 Pod 上了。

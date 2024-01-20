---
layout: default
title: 把OSS作为PVC挂载到airflow的日志卷
date: 2024-01-19 12:27 +0800
categories: airflow oss
---

有人曾说，人的一生不可能踏入同一条河两次，但是，我却可以两次用同样的姿势栽入坑里。用血泪教训告诉你，把 OSS 作为 PVC 挂载到 airflow 的日志卷，这样是不行的...

## 问题

在之前的测试用，我用创建了 OSS bucket，对应声明了 PVC，再把 PVC 挂载到 Deployment 里面去。当时测试的时候一切都还好，直到我把这个 bucket 挂载到了一个新的 Airflow 里面，导致 Dag 一直卡在 running 状态，最后超时被 kill 掉。

```yml
volumeMounts:
  - mountPath: /opt/airflow/logs
    name: volume-pv-airflow-logs
```

查看 scheduler pod 的日志，会看到下面的报错。查看代码，发现其实它实在尝试写入 log 而已。为啥写入 log 就卡住了呢？

```bash
Traceback (most recent call last):
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1087, in emit
    self.flush()
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1067, in flush
    self.stream.flush()
OSError: [Errno 5] Input/output error

During handling of the above exception, another exception occurred:

Traceback (most recent call last):
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/models/taskinstance.py", line 2335, in _run_raw_task
    self._execute_task_with_callbacks(context, test_mode, session=session)
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/models/taskinstance.py", line 2481, in _execute_task_with_callbacks
    self.log.info(
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1446, in info
    self._log(INFO, msg, args, **kwargs)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1589, in _log
    self.handle(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1599, in handle
    self.callHandlers(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1661, in callHandlers
    hdlr.handle(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 952, in handle
    self.emit(record)
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/file_task_handler.py", line 243, in emit
    self.handler.emit(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1187, in emit
    StreamHandler.emit(self, record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1091, in emit
    self.handleError(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1004, in handleError
    sys.stderr.write('--- Logging error ---\n')
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 200, in write
    self.flush()
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 207, in flush
    self._propagate_log(buf)
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 188, in _propagate_log
    self.logger.log(self.level, remove_escape_codes(message))
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1512, in log
    self._log(level, msg, args, **kwargs)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1589, in _log
    self.handle(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1599, in handle
    self.callHandlers(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1661, in callHandlers
    hdlr.handle(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 952, in handle
    self.emit(record)
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/file_task_handler.py", line 243, in emit
    self.handler.emit(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1187, in emit
    StreamHandler.emit(self, record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1091, in emit
    self.handleError(record)
  File "/usr/local/lib/python3.9/logging/__init__.py", line 1004, in handleError
    sys.stderr.write('--- Logging error ---\n')
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 200, in write
    self.flush()
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 207, in flush
    self._propagate_log(buf)
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 188, in _propagate_log
    self.logger.log(self.level, remove_escape_codes(message))
  File "/home/airflow/.local/lib/python3.9/site-packages/airflow/utils/log/logging_mixin.py", line 61, in remove_escape_codes
    return ANSI_ESCAPE.sub("", text)
  File "/home/airflow/.local/lib/python3.9/site-packages/re2.py", line 291, in sub
    joined_pieces, _ = self.subn(repl, text, count)
  File "/home/airflow/.local/lib/python3.9/site-packages/re2.py", line 286, in subn
    pieces, numsplit = self._split(cb, text, count)
  File "/home/airflow/.local/lib/python3.9/site-packages/re2.py", line 270, in _split
    for match in matchiter:
  File "/home/airflow/.local/lib/python3.9/site-packages/re2.py", line 173, in _match
    encoded_text = _encode(text)
  File "/home/airflow/.local/lib/python3.9/site-packages/re2.py", line 105, in _encode
    return t.encode(encoding='utf-8')
RecursionError: maximum recursion depth exceeded while calling a Python object
```

这个就要从 OSS 的限制说起了。

### 权限问题

当 OSS 作为 PVC 挂入 Kubernetes 的时候，如果 image 是以非 root 用户启动，需要注意挂载卷的时候，加上额外的参数，比如`-o uid 0 -o gid 0`意思就是将 PVC 的 owner 变更为`root:root`，`-o umask=002`则挂进去的文件权限是`775`。可以查看[文档](https://help.aliyun.com/zh/ack/ack-managed-and-ack-dedicated/user-guide/faq-about-oss-volumes-1)

### OSS 的使用限制

此外，OSS 还有一些[使用限制](https://www.alibabacloud.com/help/zh/oss/developer-reference/use-ossfs-to-mount-an-oss-bucket-to-the-local-directories-of-an-ecs-instance/)，比如并发。现在的情况看上去是多个 Airflow task 同时写入的时候报错了，而不是权限的错误。

## 解决方案

Airflow 支持[remote logging](https://airflow.apache.org/docs/apache-airflow/stable/administration-and-deployment/logging-monitoring/logging-tasks.html)，意思是可以把 log 上传到 OSS 或者 S3 上。

1. 安装 alibaba provider `pip install apache-airflow-providers-alibaba`
2. 创建 airflow connection `aliyun_oss_airflow_logging`

   ```json
   {
     "auth_type": "AK",
     "access_key_id": "LTAIxxxxxxxxxx",
     "access_key_secret": "",
     "region": "cn-beijing-internal"
   }
   ```

3. 设置 Pod 的环境变量，开启 remote logging。参考[Airflow 官网](https://airflow.apache.org/docs/apache-airflow/stable/configurations-ref.html)

   ```yaml
   - name: AIRFLOW__LOGGING__REMOTE_LOG_CONN_ID
     value: aliyun_oss_airflow_logging
   - name: AIRFLOW__LOGGING__REMOTE_LOGGING
     value: "True"
   - name: AIRFLOW__LOGGING__REMOTE_BASE_LOG_FOLDER
     value: oss://airflow-logs/logs
   ```

4. 更新 webserver 的 volumeMounts。webserver 这端，就可以通过挂载 PVC 的方式，读取到日志了。

   ```yaml
   volumeMounts:
     - mountPath: /opt/airflow/logs
       name: volume-pv-airflow-logs
       subPath: logs
   ```

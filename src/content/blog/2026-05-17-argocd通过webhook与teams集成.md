---
title: ArgoCD通过WebHook与Teams集成
date: 2026-05-17 21:06 +0800
categories: argocd gitops
---

## 起

前面 ArgoCD 跑得太丝滑了，以致于我们的 Pod 不停 Crash 我们都不知道，直到过了一个周末，测试说你写的代码没有工作的时候，才去看部署，已经挂了许久了。此外，生产上面 Pod OOM 了，我们也没有收到告警（其实是告警太多，就失去了告警的意义）。

## 承

ArgoCD 其实有一个通知功能，只是我们一直都没有开启。此外，最新版本的 ArgoCD 里面已经内置了[Teams](https://argo-cd.readthedocs.io/en/stable/operator-manual/notifications/services/teams-workflows/)。不过我们的版本还是老的 2.11，所以这里的配置不一样，只能够通过 WebHook 的方式实现。

### 配置 Application annotations

先在 Application 上添加下面的注解。这里的格式是 `notifications.argoproj.io/subscribe.<trigger-name>.<service-name>: ""`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  annotations:
    notifications.argoproj.io/subscribe.on-health-degraded.teams-workflows: ""
```

### 配置 Service、Trigger、Template

```yaml
data:
  service.webhook.teams-workflows: |
    url: $teams-workflows-url
    headers:
    - name: Content-Type
      value: application/json

  template.app-health-degraded: |
    webhook:
      teams-workflows:
        method: POST
        body: |
          {
            "attachments": [
              {
                "contentType": "application/vnd.microsoft.card.adaptive",
                "contentUrl": null,
                "content": {
                  "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
                  "type": "AdaptiveCard",
                  "version": "1.4",
                  "body": [
                    {
                      "type": "TextBlock",
                      "size": "Large",
                      "weight": "Bolder",
                      "text": "⚠️ 应用 {{.app.metadata.name}} 状态异常 (Degraded)",
                      "color": "Attention"
                    },
                    {
                      "type": "TextBlock",
                      "text": "应用 {{.app.metadata.name}} 的健康状态变为 Degraded。这通常意味着有 Pod 正在崩溃 (CrashLoopBackOff) 或者健康检查失败。",
                      "wrap": true
                    },
                    {
                      "type": "FactSet",
                      "facts": [
                        {
                          "title": "健康状态",
                          "value": "{{.app.status.health.status}}"
                        },
                        {
                          "title": "Namespace",
                          "value": "{{.app.metadata.namespace}}"
                        }
                      ]
                    }
                  ]
                }
              }
            ]
          }

  trigger.on-health-degraded: |-
    - when: app.status.health.status == 'Degraded'
      oncePer: app.status.health.status + app.status.sync.revision
      send:
        - app-health-degraded
```

### 配置 Teams workflow

在 Teams 里面添加一个新的 Workflow，获取到 WebHook URL，然后更新 Secret。

```yaml
apiVersion: v1
data:
  argocd-devops-workflows-url: <your_base64_webhook_url>
kind: Secret
```

## 转

这里略微坑的地方就是，AI 学习的是新的语法，大概率情况下是用最新的文档告诉你，然后就死活不对劲。直到最后它在某个概率下说了一句"service.webhook.teams-workflows" 这里的 service-name 是 teams-workflows，而不是 webhook.teams-workflows。

AI 知识的新旧也是一个头疼的问题，如果 Stack Overflow 或者 Google 上没有新的语料，这些 AI 改如何解决新旧知识的问题？

## 合

ArgoCD 是个很丝滑的工具，基本是我们的主力 GitOps 工具。所谓的 CI 就只是打镜像上传到 CR，CD 就变成了简单的更新 image tag。

只是在密码的管理上，实在太百花齐放了，他们自己也没有给出一个[最佳实践](https://github.com/argoproj/argo-cd/issues/1364)，反而是推荐用集群自己来管理密码，而不是 GitOps。

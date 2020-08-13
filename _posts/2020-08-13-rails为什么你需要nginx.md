---
layout: default
title: Rails为什么你需要Nginx
date: 2020-08-13 09:33 +0800
categories: rails nginx
---

一般我们都会用一个Web Server，放在Application Server(puma, thin, unicorn)等前面。用Nginx，可以满足下面这些条件：

1. 静态重定向。比如，将http全部转向到https，将某类URL重定向到其他服务器。
2. Host静态文件。比如css和js，放到public下面，避免这样的request到application server。
3. 也可以用来做负载均衡，支持多个Rails app。
4. Puma是基于Ruby的，性能没有Nginx高。如果Puma的资源占完了，就没法接受新的request了，但是Nginx可以先把request接进来并处于wait状态，等Puma有资源再进行转发。
5. 对于安装SSL证书，多个Rails app绑定到同一个IP，Nginx更善于处理这样的事情。


下图是一个Rails server通常的架构图，一般情况下，browser request会通过DNS找到对应的公网IP地址，然后在进入内网IP。通常内网IP是一个load balance，比如这里的Nginx。Nginx把静态文件的request直接处理掉，剩下的动态request就进入Puma。Puma是Rack based application server，会把http request按照一定的模式再转发给Rails的路由，再进入Controller。

![img](/images/rails_web_architecture.jpeg)

其中，Rack提供许多中间件，你可以执行`rake middleware`拿到所有的中间件。通过这些中间件，可以把Nginx和Rails server粘合在一起。


这些中间件都有同样的模式，即有一个`call`方法，返回`status code`, `header`, `content`。你还可以自己写一个中间件，比如写一个中间件，将所有的cookie都标记为secure true。[1][1][2][2]


[1]: [https://www.rubyguides.com/2019/08/puma-app-server/]
[2]: [https://makandracards.com/makandra/53693-rails-flagging-all-cookies-as-secure-only-to-pass-a-security-audit]
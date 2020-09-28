---
layout: default
title: 修改Host屏蔽MiBox广告
date: 2020-09-28 11:32 +0800
categories: xiaomi
---

越来越喜欢华硕路由了。

登陆华硕路由，网络监控 > 网页浏览历史 > 开启监控。

![img](/images/ausu_router_browser_history.png)


打开小米盒子，找个视频播放，坐等广告出现，退出。

等上1分钟，回来刷新监控页面，就可以看到小米盒子连接了哪些网站。比如，我看到了`openapi.vip.ptqy.gitv.tv`。

开启华硕路由的SSH功能，登陆上去，修改`/etc/hosts`文件，刷新网络`killall -SIGHUP dnsmasq`，完美！

```bash
127.0.0.1    api.cupid.ptqy.gitv.tv
127.0.0.1    openapi.vip.ptqy.gitv.tv
```

这样以后，针对小米资源的视频，就没有广告了，不用掏钱买VIP了。省了VIP的钱，打个赏呗~

![img](/images/alipay_receiver_qrcode.jpg)
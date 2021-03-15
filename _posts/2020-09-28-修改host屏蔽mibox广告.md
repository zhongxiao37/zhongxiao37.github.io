---
layout: default
title: 修改Host屏蔽MiBox广告
date: 2020-09-28 11:32 +0800
categories: xiaomi
---

越来越喜欢华硕路由了。

家里的小米盒子太老了，最初的1代，1G内存，CPU才400MHz的。最近给娃放《冰雪奇缘2》1080p直接无法播放。对比一下小米盒子4和4c，还是多出100块钱买2G内存的小米盒子4。家里有很多小米设备，绑定小爱同学也挺好玩的。但是这个新盒子的广告让人有点恶心了，看个视频，要看将近2分钟的广告，实在无法接受。

搜了一下，很多推荐root的。鬼知道root以后有没有给我留个后门啥的，又不是开源的，开源了我也看不懂。无意间发现可以通过修改Host文件达到同样的效果，不过网上的Host名单基本都是3年前的了，在我这里都失效了。折腾了一下华硕路由，发现效果满分。授人以鱼不如授人以渔，这样下次新的地址出来也可以用下面的方法。

登陆华硕路由，网络监控 > 网页浏览历史 > 开启监控。

![img](/images/ausu_router_browser_history.png)


打开小米盒子，找个视频播放，坐等广告出现，退出。

等上1分钟，回来刷新监控页面，就可以看到小米盒子连接了哪些网站。比如，我看到了`openapi.vip.ptqy.gitv.tv`。

开启华硕路由的SSH功能，登陆上去，修改`/etc/hosts`文件，刷新网络`killall -SIGHUP dnsmasq`，完美！

```bash
127.0.0.1    ad.mi.com
127.0.0.1    ad.xiaomi.com
127.0.0.1    api.ad.xiaomi.com
127.0.0.1    ad1.xiaomi.com
127.0.0.1    test.ad.xiaomi.com
127.0.0.1    new.api.ad.xiaomi.com
127.0.0.1    cdn.ad.xiaomi.com
127.0.0.1    e.ad.xiaomi.com
127.0.0.1    test.new.api.ad.xiaomi.com
127.0.0.1    ssp.ad.xiaomi.com
127.0.0.1    adv.sec.miui.com
127.0.0.1    o2o.api.xiaomi.com
127.0.0.1    api.cupid.ptqy.gitv.tv
127.0.0.1    openapi.vip.ptqy.gitv.tv
127.0.0.1    t7z.cupid.ptqy.gitv.tv
127.0.0.1    sdkconfig.ad.xiaomi.com
127.0.0.1    pd.ads.cn.miaozhen.com
127.0.0.1    rtb.ads.cn.miaozhen.com
127.0.0.1    qtsftl.m.cn.miaozhen.com
```

这样只是暂时工作而已，因为Hosts文件过一会儿就被重置。

这个时候需要创建一个`/jffs/configs/hosts`文件，内容如上。然后在添加`/jffs/dnsmasq.conf.add`，内容为`addn-hosts=/jffs/configs/hosts`。


这样以后，针对小米资源的视频，就没有广告了，不用掏钱买VIP了。省了VIP的钱，打个赏呗~

![img](/images/alipay_receiver_qrcode.jpg)
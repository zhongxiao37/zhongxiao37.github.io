---
layout: default
title: 通过阿里云SSO获取的STS token的有效时间
date: 2024-01-29 17:09 +0800
categories: aliyun sso
---

按照阿里云的[文档](https://help.aliyun.com/zh/cloudsso/user-guide/use-alibaba-cloud-cli-to-access-cloudsso-and-alibaba-cloud-resources)， 可以通过`acs-sso login --profile sso`来获取 SSO 角色的临时 STS token。但是发现这个 Token 的时间特别长，不是 assumeRole[文档](https://help.aliyun.com/zh/ram/developer-reference/api-sts-2015-04-01-assumerole?spm=5176.28426678.J_HeJR_wZokYt378dwP-lLl.37.6d4e5181BJnlS7&scm=20140722.S_help@@%E6%96%87%E6%A1%A3@@371864.S_BB1@bl+BB2@bl+RQW@ag0+os0.ID_371864-RL_assume%20role-LOC_search~UND~helpdoc~UND~item-OR_ser-V_3-P0_6)里面提到的 1 个小时，虽然两者都可以换取到 STS token。

其实，通过 SSO 获取的 STS token 有效时间，是在界面可以看到的。

<img src="/images/aliyun_role_sso.png" width="800px">

但在调查这个问题的时候，我却发现了有趣的东西。

`acs-sso` 这个命令行工具是用`javascript`写的，查看[源代码](https://github.com/aliyun/alibabacloud-sso-cli/tree/master)的`package.json`，发现它用了`httpx`这个包，再看`httpx`的`package.json`，发现还用了`debug`包。查看了一下`debug`的[源代码](https://github.com/debug-js/debug)，那这下想看日志就简单了，直接`DEBUG=* acs-sso login --profile sso --force`，就可以看到获取 STS token 的整个流程。

1. 申请`device-authorization`

```bash
  httpx:body {"PortalUrl":"https://signin-us-west-1.alibabacloudsso.com/xxx-sso/login","CodeChallenge":"Z8naQ2RM_suXH6LsDSMt-LuYv3O4ufXgCxsn1aa8QAc","ClientId":"app-vaz16tltdxs96audqf35","CodeChallengeMethod":"S256"} +0ms
  httpx:header > POST /device-authorization HTTP/1.1 +0ms
  httpx:header > accept: application/json +0ms
  httpx:header > content-type: application/json +0ms
  httpx:header > Host: signin-us-west-1.alibabacloudsso.com +0ms
  httpx:header > Connection: keep-alive +0ms
  httpx:header > Content-Length: 212 +0ms
  httpx:header >  +0ms
  httpx:header >  +0ms
  httpx:header < HTTP/1.1 200  +0ms
  httpx:header < date: Thu, 11 Jan 2024 08:02:45 GMT +1ms
  httpx:header < content-type: application/json +0ms
  httpx:header < content-length: 342 +0ms
  httpx:header < connection: keep-alive +0ms
  httpx:header < server: Tengine +0ms
  httpx:header < set-cookie: [ 'JSESSIONID=2FDDA8BA63E5A208581DF257D771644D; Path=/; HttpOnly' ] +0ms
  httpx:header < eagleeye-traceid: 0a3c5d4217049601653368762e1061 +2ms
  httpx:header < strict-transport-security: max-age=0 +0ms
  httpx:header < timing-allow-origin: * +0ms
  httpx:body  +1s
  httpx:body {"DeviceCode":"KeGiHDJgzcdMKscdcjREuPozoTeBLCw19Hvvx8BS","ExpiresIn":600,"Interval":5,"RequestId":"d1f9cdfe-2bab-4ccc-a732-7f95914c0610","UserCode":"KFFJ-LJXK","VerificationUri":"https://signin-us-west-1.alibabacloudsso.com/device/code","VerificationUriComplete":"https://signin-us-west-1.alibabacloudsso.com/device/code?user_code=KFFJ-LJXK"} +0ms
If your default browser is not opened automatically, please use the following URL to finish the signin process.

Signin URL: https://signin-us-west-1.alibabacloudsso.com/device/code
User Code: KFFJ-LJXK

And now you can login in your browser with you SSO account.
```

2. 查询用户是否在调起的浏览器登陆并确认授权

```bash
  httpx:body {"CodeVerifier":"f99e10a720a9fa85695e63afd692c8fc60cee042e20060a34477fb3fbd3c0696","ClientId":"app-vaz16tltdxs96audqf35","DeviceCode":"KeGiHDJgzcdMKscdcjREuPozoTeBLCw19Hvvx8BS","GrantType":"urn:ietf:params:oauth:grant-type:device_code"} +10ms
  httpx:header > POST /token HTTP/1.1 +258ms
  httpx:header > accept: application/json +1ms
  httpx:header > content-type: application/json +0ms
  httpx:header > Host: signin-us-west-1.alibabacloudsso.com +0ms
  httpx:header > Connection: keep-alive +0ms
  httpx:header > Content-Length: 236 +0ms
  httpx:header >  +0ms
  httpx:header >  +0ms
  httpx:header < HTTP/1.1 400  +0ms
  httpx:header < date: Thu, 11 Jan 2024 08:02:45 GMT +0ms
  httpx:header < content-type: application/json +0ms
  httpx:header < content-length: 127 +0ms
  httpx:header < connection: keep-alive +0ms
  httpx:header < server: Tengine +0ms
  httpx:header < set-cookie: [ 'JSESSIONID=B0F3BFCBF14B8DEFB0DD69C8E7CC5D18; Path=/; HttpOnly' ] +0ms
  httpx:body  +248ms
  httpx:body {"ErrorCode":"AuthorizationPending","ErrorMessage":"The device is pending.","RequestId":"71fb370b-f649-4ed0-bfc0-2e7e457a9bfc"} +0ms
```

3. 一旦用户在浏览器上确认授权，就可以获取到`AccessToken`

```bash
  httpx:body {"AccessToken":"xxxxxx","ExpiresIn":28800,"RequestId":"6407d68c-4230-4bb5-876e-da5ddbcd9d55","TokenType":"Bearer"} +0ms
You have logged in.
```

4. 接下来就是用`AccessToken`换取 STS Token

```bash
  httpx:body {"AccountId":"1432949406168187","AccessConfigurationId":"ac-01jpbjjez9lspbg18c61"} +2ms
  httpx:header > POST /cloud-credentials HTTP/1.1 +523ms
  httpx:header > accept: application/json +1ms
  httpx:header > content-type: application/json +0ms
  httpx:header > authorization: Bearer xxxxxx +0ms
  httpx:header > Host: signin-us-west-1.alibabacloudsso.com +0ms
  httpx:header > Connection: keep-alive +0ms
  httpx:header > Content-Length: 82 +0ms
  httpx:header >  +0ms
  httpx:header >  +0ms
  httpx:header < HTTP/1.1 200  +0ms
  httpx:header < date: Thu, 11 Jan 2024 08:02:51 GMT +0ms
  httpx:header < content-type: application/json +0ms
  httpx:header < content-length: 798 +0ms
  httpx:header < connection: keep-alive +0ms
  httpx:header < server: Tengine +0ms
  httpx:header < set-cookie: [ 'JSESSIONID=A7DB8BD2EC5715F3CDE8763302B67DD1; Path=/; HttpOnly' ] +0ms
  httpx:header < eagleeye-traceid: 0a3c5d4217049601712358818e1061 +0ms
  httpx:header < strict-transport-security: max-age=0 +0ms
  httpx:header < timing-allow-origin: * +0ms
  httpx:body  +523ms
  httpx:body {"CloudCredential":{"AccessKeyId":"STS.AK","AccessKeySecret":"SK","Expiration":"2024-01-11T20:02:51Z","SecurityToken":"STS.TOKEN"},"RequestId":"18dccaa8-730a-4309-b6b6-cdf8bb7f3f05"}
```

5. 最后，可以从 response 里面看到`Expiration`。这些信息会被写入`~/.alibabacloud_sso_sts`文件。只要这个 Token 不过期，`acs-sso login`就会先用这个文件里面的 STS Token，否则就需要重新授权一次。

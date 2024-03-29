---
layout: default
title: NextAuth与Azure AD集成
date: 2024-02-09 17:34 +0800
categories: sso nextjs
---

最近在做前后端分离，常见的有两种方案，一个是 bundle 打包成 js 文件，再嵌入 web 的某个页面；另外一个前端单独起一个服务器，用前端来负责页面和 SSO 相关的功能，后端只管提供 API 数据。这次用的是第二种方式，因为我想把后端作为纯的 API 服务器。

## NextAuth

安装 NextAuth 包 `yarn add next-auth`

## 引入 SessionProvider

```js
"use client";
import { SessionProvider } from "next-auth/react";

export default function RootLayout({
  children,
}: {
  children: React.ReactNode,
}) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  );
}
```

## 在 Azure 上注册 application

按照微软的[文档](https://learn.microsoft.com/en-us/entra/identity-platform/quickstart-register-app)，注册一个 application，获取到`client_id`和`client_secret`。

<img src="/images/azure_app_registration.png" width="800px">

留意设置好 callback URL 如下。

<img src="/images/azure_callback_url.png" width="800px">

## 配置环境变量

创建`.env.local`文件，配置好环境变量

```bash
AZURE_AD_CLIENT_ID=xxx-xxx-xxxx
AZURE_AD_CLIENT_SECRET=xxx-xxx-xxxx
AZURE_AD_TENANT_ID=xxx-xxx-xxxx
NEXTAUTH_SECRET=xxx-xxx-xxxx
NEXTAUTH_URL=http://localhost:3000
```

## 创建 route.ts

```javascript
// app/api/auth/[...nextauth]/route.ts
import NextAuth from "next-auth";
import AzureADProvider from "next-auth/providers/azure-ad";

const handler = NextAuth({
  session: {
    strategy: "jwt",
  },
  providers: [
    AzureADProvider({
      clientId: process.env.AZURE_AD_CLIENT_ID!,
      clientSecret: process.env.AZURE_AD_CLIENT_SECRET!,
      tenantId: process.env.AZURE_AD_TENANT_ID,
    }),
  ],
  callbacks: {
    jwt: async ({ token, account }) => {
      console.log("jwt");
      console.log("account", account);
      console.log("token", token);

      return token;
    },
    session: async ({ session, token }) => {
      console.log("session");
      console.log("session", session);
      console.log("token", token);

      return session;
    },
  },
});

export { handler as GET, handler as POST };

```

## 更新主页

因为用了`useSession`，需要先判断 session 获取完成了，在判断是否登陆。如果是 loading，就先给一个空页面，直到获取到 session。

```javascript
"use client";
import Home from "../components/Home";
import { useSession, signIn } from "next-auth/react";

const Page = () => {
  const { data: session, status: status } = useSession();
  console.log("browser session", session);
  console.log("browser status", status);
  if (status === "loading") {
    return <div />;
  } else if (session) {
    return <Home />;
  } else {
    signIn();
  }
};
export default Page;
```

## Reference

1. [https://next-auth.js.org/providers/azure-ad](https://next-auth.js.org/providers/azure-ad)

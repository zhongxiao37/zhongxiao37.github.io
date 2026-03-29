---
layout: default
title: 在Cloudflare上免费打造零成本的 Scrum Poker
date: 2026-02-19 22:08 +0800
categories: cloudflare
---

<img src="/images/cloudpoker.jpg" style="width: 100%;" />

作为开发者，我们每两周都要进行一次 Sprint Planning。每次估点时，找一个免费、好用、不用注册的 Scrum Poker 工具简直像是在寻宝。市面上的工具要么广告满天飞，要么强制你注册账号。

我之前用过 [poker4fun](https://just4fun.github.io/projects/poker4fun/)，体验不错，但我决定用现代技术栈自己造一个轮子，并且**一分钱都不花**。今天，我将带你利用 Cloudflare 的免费层级（Pages + Workers + Durable Objects），部署一个属于你自己的实时多人敏捷估点工具——[CloudPoker](https://poker-11s.pages.dev/)。

## 1. 什么是 CloudPoker？

简单来说，[CloudPoker](https://poker-11s.pages.dev/) 是一个无服务器（Serverless）的实时估点应用。

如果把传统的 WebSocket 服务器比作一家**24 小时营业、灯火通明但大部分时间没客人的餐厅**（你需要为闲置的服务器付费），那么 [CloudPoker](https://poker-11s.pages.dev/) 就像是一个**魔法帐篷**：当你们团队开始估点时，帐篷瞬间在离你们最近的边缘节点搭好；估点结束大家离开后，帐篷立刻折叠消失，不消耗任何计算资源。

## 2. 为什么我们需要这种架构？

在过去，如果你想实现一个实时的多人投票房间，你通常会怎么做？

- 租一台 VPS（比如 AWS EC2 或轻量应用服务器）。
- 跑一个 Node.js + Socket.io 的后端。
- 也许还要配个 Redis 来存房间状态。

**痛点很明显**：

1. **成本浪费**：估点会议通常每两周才开一次，每次一小时。剩下的 335 个小时，你的服务器都在“傻乎乎地空转”，但你依然要为它付钱。
2. **运维心智负担**：你需要操心 SSL 证书、进程守护（PM2）、服务器安全。

通过切换到 **Cloudflare Workers + Durable Objects**，我们完美解决了这些问题。Durable Objects 提供了强一致性的状态存储，而 WebSocket Hibernation（Hibernation API）让连接在空闲时完全不计费。真正的即开即用，零成本运维。

## 3. 它是如何工作的？

这个系统的运转逻辑非常清晰，我们可以把它拆解为以下几个步骤：

1. **静态资源分发 (Cloudflare Pages)**：
   用户的浏览器首先访问由 React + Vite 构建的前端页面。Pages 会将这些静态文件缓存在全球 CDN 节点上，加载速度极快。
2. **WebSocket 握手 (Workers 路由)**：
   当前端发起 `wss://.../ws/:roomId` 连接时，请求会打到 Cloudflare Worker。Worker 会根据 `roomId`，将请求路由到对应的 Durable Object 实例。
3. **房间状态管理 (Durable Objects)**：
   每个房间对应一个独立的 Durable Object（DO）。你可以把 DO 想象成一个驻留在内存中的单例微服务，它负责保存当前房间里有哪些玩家、每个人投了什么点数。
4. **Hibernation 机制 (WebSocket Hibernation)**：
   这是省钱的核心。当大家都在思考点数，没有任何 WebSocket 消息传递时，DO 会自动“休眠”，将状态持久化到 SQLite 中。一旦有人点击了投票，DO 会在几毫秒内被唤醒并处理消息。

## 4. 优缺点分析

在决定采用这套架构前，我们需要客观评估一下它的利弊：

**优点：**

- **极致的成本控制**：完全白嫖 Cloudflare 免费额度（Workers 每天 10 万次请求，DO 每月 100 万次请求），对于团队内部工具来说根本用不完。
- **全球低延迟**：Cloudflare 的边缘网络让分布在不同国家的远程团队也能享受丝滑的实时同步。
- **免运维**：没有服务器需要打补丁，没有 SSL 证书需要续期。

**缺点：**

- **严重的厂商锁定 (Vendor Lock-in)**：Durable Objects 是 Cloudflare 独有的概念，你的后端代码很难直接迁移到 AWS 或自建机房。
- **本地开发体验**：虽然 Wrangler 模拟器已经很强大，但调试分布式的 DO 状态有时依然让人头疼。
- **冷启动延迟**：当 DO 从休眠中唤醒时，会有轻微的延迟（通常在几十到几百毫秒），但在估点这种场景下几乎无感。

## 5. 真实世界的验证：动手部署

让我们用实际的命令来验证这套架构的部署过程。

### 步骤 1：启动本地开发环境

首先，我们需要启动后端的 Worker。

```bash
cd worker
npm install
# 启动本地 Wrangler 开发服务器，模拟 Cloudflare 环境
npm run dev
```

**预期输出：**

```text
 ⛅️ wrangler 3.x.x
-------------------
⬣ Listening at http://localhost:8787
- http://127.0.0.1:8787
```

接着，配置并启动前端：

```bash
cd frontend
npm install
# 将本地 Worker 地址配置为环境变量
echo "VITE_API_URL=http://localhost:8787" > .env.local
npm run dev
```

### 步骤 2：配置与部署

在部署后端时，我们需要在 `wrangler.toml` 中声明 Durable Objects 的绑定。这是一个典型的配置片段：

```toml
# worker/wrangler.toml
name = "poker-worker"
main = "src/index.ts"
compatibility_date = "2024-02-19"

# 绑定 Durable Object
[[durable_objects.bindings]]
name = "POKER_ROOM" # 代码中通过 env.POKER_ROOM 访问
class_name = "PokerRoom" # 对应的 TypeScript 类名

# 告诉 Cloudflare 哪些类需要被实例化为 DO
[[migrations]]
tag = "v1"
new_classes = ["PokerRoom"]
```

使用 CLI 一键部署后端：

```bash
npx wrangler deploy
```

部署前端到 Cloudflare Pages：

```bash
cd frontend
npm run build
# 将 dist 目录发布到 Pages
npx wrangler pages deploy dist --project-name poker-frontend
```

## 6. 排错 / 常见冲突

在实际开发和运行中，你可能会遇到以下边缘情况：

### 1. WebSocket 频繁断开与重连

**症状**：由于网络波动或 DO 实例迁移，前端的 WebSocket 连接可能会意外断开。
**解决方案**：不要依赖单一的连接。前端必须实现**指数退避重连**机制。

```typescript
// 简单的指数退避重连逻辑示例
let retryCount = 0;
function connect() {
  const ws = new WebSocket(WS_URL);
  ws.onclose = () => {
    const delay = Math.min(1000 * Math.pow(2, retryCount), 10000); // 最大延迟 10 秒
    setTimeout(connect, delay);
    retryCount++;
  };
  ws.onopen = () => {
    retryCount = 0;
  }; // 连接成功重置计数
}
```

### 2. 本地开发时的 CORS 跨域问题

**症状**：前端跑在 `localhost:5173`，后端跑在 `localhost:8787`，发起 HTTP 请求时浏览器报错 CORS。
**解决方案**：在 Worker 的 `fetch` 处理函数中，显式返回 CORS Headers。

```typescript
// worker/src/index.ts
const corsHeaders = {
  "Access-Control-Allow-Origin": "*", // 本地开发允许所有，生产环境建议限制域名
  "Access-Control-Allow-Methods": "GET,HEAD,POST,OPTIONS",
  "Access-Control-Max-Age": "86400",
};

if (request.method === "OPTIONS") {
  return new Response(null, { headers: corsHeaders });
}
```

### 3. DO 状态未及时持久化

**症状**：Worker 崩溃或重启后，房间内的投票数据丢失。
**解决方案**：确保在修改内存状态后，调用 `ctx.storage.put()`。对于关键操作，使用 `ctx.waitUntil()` 确保异步存储操作在请求结束后依然能执行完毕。

---

通过这套架构，我们不仅白嫖了 Cloudflare 的全球网络，还顺便学习了现代 Serverless WebSocket 的最佳实践。下次 Sprint Planning 时，直接丢给团队一个你专属的 [CloudPoker](https://poker-11s.pages.dev/) 链接吧！

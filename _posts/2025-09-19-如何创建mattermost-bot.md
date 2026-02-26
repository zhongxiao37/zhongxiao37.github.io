---
layout: default
title: 如何创建Mattermost Bot
date: 2025-09-19 18:21 +0800
categories: mattermost
---

首先去 System Console > Integrations > Bot Accounts 开启创建机器人。

<img src="/images/mattermost_enable_bot_account_creation.png" style="width: 800px;" />

然后去 Integration > Bot Accounts 下面创建机器人。

<img src="/images/mattermost_create_bot_account.png" style="width: 800px;" />

就会生成一个机器人的 Token。

回到一个 Team，添加这个机器人。

用下面的代码，就可以往一个 Channel 发消息，或者回复消息了。

```python
async def send_mattermost_reply(channel_id: str, message: str, root_id: str = "", props: dict = None, token: str = None):
    """
    Send a message proactively using Mattermost REST API (/api/v4/posts).
    """
    if not settings.mattermost_url:
        print("Warning: mattermost_url not configured, cannot send reply.")
        return {}

    url = f"{settings.mattermost_url.rstrip('/')}/api/v4/posts"
    headers = {
        "Authorization": f"Bearer {token}"
    }
    payload = {
        "channel_id": channel_id,
        "message": message,
    }
    if root_id:
        payload["root_id"] = root_id
    if props:
        payload["props"] = props

    async with httpx.AsyncClient(trust_env=False) as client:
        try:
            response = await client.post(url, headers=headers, json=payload)
            response.raise_for_status()
            return response.json()
        except httpx.HTTPError as e:
            print(f"Error sending reply to Mattermost: {e}")
            return {}

```

### Reference

1. [https://developers.mattermost.com/api-documentation/#/operations/CreatePost](https://developers.mattermost.com/api-documentation/#/operations/CreatePost)

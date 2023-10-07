---
layout: default
title: Debug Rails in VS Code (Ruby 3)
date: 2023-10-07 16:53 +0800
categories: rails
---

本来没有什么好说的，直到自己一直用的[vscode-ruby](https://github.com/rubyide/vscode-ruby)被标记为归档了，然后 Ruby 3.1 上好像用不了这个插件了。搜了一圈，发现 2021 年发布了一个新的插件。

## 安装 VSCode rdbg Ruby Debugger

[https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg](https://marketplace.visualstudio.com/items?itemName=KoichiSasada.vscode-rdbg)

## 修改配置文件

```json
{
  // Use IntelliSense to learn about possible attributes.
  // Hover to view descriptions of existing attributes.
  // For more information, visit: https://go.microsoft.com/fwlink/?linkid=830387
  "version": "0.2.0",
  "configurations": [
    {
      "type": "rdbg",
      "name": "Debug Rails",
      "request": "launch",
      "command": "bin/rails",
      "script": "server",
      "useBundler": true,
      "cwd": "${workspaceFolder}"
    }
  ]
}
```

## 不需要修改 config/puma.rb

本来这样就好了，但是一篇[文章](https://techblog.shippio.io/efficiency-at-your-fingertips-a-guide-to-local-ruby-on-rails-ide-setup-e2e203b48a0)里面提到要修改`config/puma.rb`文件，搞得我老是遇到 debugger 自动断开的错误。

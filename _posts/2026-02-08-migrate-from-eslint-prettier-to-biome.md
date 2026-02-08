---
layout: default
title: Migrate from ESLint/Prettier to Biome
date: 2026-02-08 22:08 +0800
categories: biome
---

什么是 Biome?

基于 Rust，实现 Prettier 一样的 format，和 ESLint 一样的代码检查。

安装 Biome

```bash
npm install --save-dev --save-exact @biomejs/biome
```

Format

```bash
npx biome format index.js
npx biome format index.js --write
```

Lint

```bash
npx biome lint index.js
npx biome lint index.js --write
```

集成 VS Code

安装 Biome 插件即可

配置

创建配置文件

```bash
npx biome init
```

从 Prettier 和 ESLint 迁移

```bash
biome migrate eslint --write
biome migrate prettier --write

```

PreCommit

```bash
# .husky/pre-commit
npm run lint:staged

```

## Reference

[https://blog.appsignal.com/2025/05/07/migrating-a-javascript-project-from-prettier-and-eslint-to-biomejs.html](https://blog.appsignal.com/2025/05/07/migrating-a-javascript-project-from-prettier-and-eslint-to-biomejs.html)

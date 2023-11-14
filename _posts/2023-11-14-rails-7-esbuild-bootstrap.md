---
layout: post
title: Rails 7 + esbuild + BootStrap
date: 2023-11-14 16:24 +0800
categories: rails esbuild boostrap
---

创建一个新项目

```bash
rails new myblog
```

```bash
bundle add cssbundling-rails jsbundling-rails
```

```bash
./bin/rails css:install:bootstrap
```

```bash
./bin/rails javascript:install:esbuild
```

安装 Stimulus 和 Turbo Rails

```bash
yarn add @hotwired/stimulus @hotwired/turbo-rails
```

并且移除 Gemfile 中的 importmap，turbo-rails。

更新 `app/javascript/application.js`

```javascript
import "@hotwired/turbo-rails";
import "./controllers";
```

更新 `app/javascript/controllers/index.js`

```javascript
import { application } from "./application";

import HelloController from "./hello_controller";

application.register("hello", HelloController);
```

测试 js build

```bash
yarn build
```

删除`javascript_importmap_tag`

更新 `app/assets/config/manifest.js`

```text
//= link_tree ../images
//= link_tree ../builds
```

测试 asset pipeline

```bash
bundle exec rails assets:clobber assets:precompile
```

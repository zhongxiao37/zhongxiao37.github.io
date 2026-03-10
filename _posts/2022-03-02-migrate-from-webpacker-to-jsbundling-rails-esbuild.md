---
layout: default
title: Migrate from webpacker to jsbundling-rails(esbuild)
date: 2022-03-02 14:00 +0800
categories: rails esbuild
---

## Install jsbunding-rails

Update the Gemfile

```ruby
gem 'jsbunding-rails'
```

Run following commands

```bash
bundle install
rails javascript:install:esbuild
```

这个命令会做几件事，其中

1. 安装 foreman。具体可以查看 bin/dev 和 Procfile.dev 这两个文件。项目目录下执行`bin/dev`就可以运行项目。
2. 安装 esbuild。可以在 package.json 里面找到。

## Swap javascript_pack_tag to javascript_include_tag

## Install stimulus

```bash
rails stimulus:install
```

## Remove webpack

1. remove `gem 'webpacker', '~> 5.4'` from Gemfile
2. remove webpack related package in package.json

## Test stimulus

create hello_controller.js file

```javascript
import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  greet() {
    console.log("Hello Stimulus...");
  }
}
```

create html file

```slim
h1[data-controller='hello']
  #stimulus[data-action="click->hello#greet"]
    <svg xmlns="http://www.w3.org/2000/svg" width="12" height="20" viewBox="0 0 12 20" fill="none">
      <path d="M0.375 10L9.75 0.625L11.0625 1.9375L3 10L11.0625 18.0625L9.75 19.375L0.375 10Z" fill="black" fill-opacity="0.94"/>
    </svg>
```

然后启动项目，点击按钮，在 console 里面就可以看到 log 了。

### Reference

1. [https://dev.to/thomasvanholder/how-to-migrate-from-webpacker-to-jsbundling-rails-esbuild-5f2](https://dev.to/thomasvanholder/how-to-migrate-from-webpacker-to-jsbundling-rails-esbuild-5f2)
2. [https://makandracards.com/makandra/509498-add-esbuild-rails-asset-pipeline](https://makandracards.com/makandra/509498-add-esbuild-rails-asset-pipeline)

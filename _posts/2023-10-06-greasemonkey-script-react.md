---
layout: default
title: GreaseMonkey script + React
date: 2023-10-06 10:42 +0800
categories: react greasemonkey
---

突然来了一个需求，需要修改某个页面，做一个 Demo。如果是单纯做 PPT，简单修改 HTML 元素，调整 CSS 即可。如果需要进一步，需要录制视频，可能需要搭一个 app。我在想，如果用 GreaseMonkey 脚本，加上已经打包好的 React，是不是可以介于两者之间呢？

## 创建 React 项目

都 2023 年，用 Vite 创建 React 项目不香么？实际上是 create-react-app 脚本卡了一个多小时还没有创建上，即使我全局翻墙了。执行`yarn create vite`直接创建好一个 react 项目，`yarn dev`看看跑起来如何，再`yarn build`直接打包。

## 编写油猴脚本

一种想法就是直接把打包好的 js 文件放到油猴里面，直接就可以用。加上`GM_addStyle`可以修改样式。

```javascript
// ==UserScript==
// @name         React Demo
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  A quick demo on using react with Tampermonkey
// @author       zhongxiao37
// @match        https://zhongxiao37.github.io/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        GM_addStyle
// ==/UserScript==

GM_addStyle("body { color: white; background-color: black } img { border: 0 }");

// index.js
```

## 引用远程 js

另外一种方法就是，把打包好的 js 文件托管到云上，然后通过添加`script`标签的方式，如下。不过这里会有 CORS 的问题，比如我放到 github 上的话，是不行的，我得放到自己的 github.io 项目下面。

```javascript
// ==UserScript==
// @name         React Demo
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  A quick demo on using react with Tampermonkey
// @author       zhongxiao37
// @match        https://zhongxiao37.github.io/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        GM_addStyle
// ==/UserScript==

(function () {
  const script_div = document.createElement("script");
  const main_content = document.getElementById("main_content");
  script_div.type = "text/javascript";
  script_div.defer = "defer";
  script_div.src = "https://zhongxiao37.github.io/assets/index-b1533ac2.js";

  main_content.appendChild(script_div);
})();
```

## Reference

[https://github.com/zhongxiao37/react-vite](https://github.com/zhongxiao37/react-vite)

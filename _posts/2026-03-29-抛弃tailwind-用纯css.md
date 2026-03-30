---
layout: default
title: 抛弃Tailwind, 用纯CSS?
date: 2026-03-29 15:38 +0800
categories: css
---

最近我读了一篇[文章](https://www.zolkos.com/2025/12/03/vanilla-css-is-all-you-need)，解读了 37signals 的新产品 Fizzy 的 CSS 架构。看完后我深有感触：他们竟然抛弃了 Tailwind，完全拥抱了纯 CSS（Vanilla CSS）。

在前端领域，我们经常开玩笑说“技术就是个圈”，但仔细拆解这十几年的技术演进，你会发现这其实是一个**螺旋上升**的过程。今天，我们就来聊聊，为什么在 2026 年，回归纯 CSS 可能是你做出的最明智的技术决策。

## 1. 什么是现代原生 CSS？

如果把写网页比作造房子，早期的 CSS 就像是给你一堆泥巴，你得自己捏砖头（还要处理 IE 浏览器的各种兼容性黑洞）。后来的 Bootstrap 像是给你建好的预制板房，而 Tailwind 则是给你一卡车形状各异的乐高积木。

那么现代原生 CSS 是什么？它就像是**一台直接内置在浏览器里的 3D 打印机**。你不再需要依赖外部的加工厂（构建工具），只要输入指令，浏览器就能原生、高效地渲染出你想要的任何复杂样式。

## 2. 为什么我们需要回归纯 CSS？

在解释为什么要回归之前，我们先看看我们是怎么走到今天的，以及我们正在忍受什么痛点。

- **Bootstrap 时代 (2011-2017)：** 解决了“标准化”与“浏览器兼容性”。但代价是所有的网站看起来都一模一样（Bootstrap 脸），而且 CSS 文件极其臃肿。
- **Tailwind 时代 (2017-2024)：** 解决了“命名恐惧”与“样式冗余”。它把 CSS 拆解成了原子类。但痛点随之而来：HTML 变得极其丑陋（类名满天飞，像 `class="w-full h-full flex items-center justify-center bg-blue-500 hover:bg-blue-600 rounded-lg shadow-md..."`），而且你必须依赖一套复杂的 Node.js 构建链（PostCSS, JIT 引擎）。

**为什么现在要抛弃 Tailwind？**
因为我们正面临着严重的**“构建疲劳”**。开发者开始反思：_“为什么我为了画一个简单的按钮，得先装 500MB 的 `node_modules`，还得等 Webpack/Vite 跑半天？”_ 当原生能力足够强时，框架和工具就成了多余的“抽象税”。

## 3. 现代原生 CSS 是如何工作的？

现在的 Vanilla CSS 早就不是 2010 年那个连垂直居中都要写黑魔法的残疾语言了。它已经吸收了 Sass 和 Tailwind 90% 的优秀特性，直接在内核里实现了。

以下是现代 CSS 改变游戏规则的核心机制：

1. **原生嵌套 (Nesting)：** 告别 Sass，直接在 CSS 中书写层级。
2. **级联层 (`@layer`)：** 彻底解决样式冲突和权重（Specificity）地狱。你可以明确定义哪些样式的优先级更高，而不用再写 `!important`。
3. **CSS 变量 (Custom Properties)：** 运行时的动态主题切换变得轻而易举，不再需要在构建时编译。
4. **强大的伪类 (如 `:has()`)：** 父选择器终于来了！你可以根据子元素的状态来改变父元素的样式，这在以前必须用 JavaScript 才能实现。

## 4. 优缺点分析

在决定是否在你的下一个项目中采用纯 CSS 之前，我们需要客观评估一下：

**优点：**

- **零构建成本：** 不需要 PostCSS，不需要 Tailwind 配置文件，保存即刷新，极致的开发体验。
- **干净的 HTML：** 告别长达几百个字符的 `class` 属性，让 HTML 回归语义化。
- **更小的体积：** 现代浏览器对原生 CSS 的解析速度极快，且没有框架运行时的开销。
- **长久保值：** 框架会过时，但 W3C 标准永远有效。

**缺点：**

- **需要重新学习：** 很多习惯了 Tailwind 的开发者可能已经忘记了怎么写标准的 CSS 布局。
- **缺乏现成的设计系统：** Tailwind 提供了一套非常优秀的默认间距、颜色和排版比例，用纯 CSS 你需要自己从头定义这些设计令牌（Design Tokens）。
- **作用域管理：** 如果不使用 CSS Modules 或 Web Components，全局样式污染依然是一个需要注意的问题。

## 5. 真实世界的验证

让我们用具体的代码来看看，从 Tailwind 迁移到现代纯 CSS 是什么体验。

**Tailwind 版本（HTML 臃肿）：**

```html
<button
  class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded shadow-md transition duration-300 ease-in-out"
>
  提交
</button>
```

**现代原生 CSS 版本（语义化 HTML + 强大 CSS）：**

```html
<button class="btn-primary">提交</button>
```

```css
/* 使用 @layer 管理权重，定义变量 */
@layer theme, components;

@layer theme {
  :root {
    --color-primary: #3b82f6;
    --color-primary-hover: #1d4ed8;
    --spacing-sm: 0.5rem;
    --spacing-md: 1rem;
    --radius: 0.25rem;
  }
}

@layer components {
  .btn-primary {
    /* 原生嵌套与变量 */
    background-color: var(--color-primary);
    color: white;
    font-weight: bold;
    padding: var(--spacing-sm) var(--spacing-md);
    border-radius: var(--radius);
    box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
    transition: all 0.3s ease-in-out;
    border: none;
    cursor: pointer;

    &:hover {
      background-color: var(--color-primary-hover);
    }
  }
}
```

**总结**

现在的“回归纯 CSS”，其实是“回归进化的标准”。在经历了一圈工具链的轰炸后，我们终于可以脱离辅助轮，直接在浏览器上优雅地起舞了。如果你想追求极致的加载速度和更纯粹的代码结构，可以开始尝试 Vanilla CSS。

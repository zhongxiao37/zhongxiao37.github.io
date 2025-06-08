---
layout: default
title: 使用bun + rsbuild构建React项目
date: 2025-06-09 09:37 +0800
categories: rsbuild
---

之前用过Vite创建一个React项目，后来又遇到了rsbuild，赶紧记录一下。尝试用Cursor初始化一个项目，在引入TailwindCSS的时候就翻车了。

## Rsbuild

### 初始化rsbuild项目

```bash
bun create rsbuild@latest
```

<img src="/images/rsbuild_instruction.png" style="width: 800px;" />

```bash
cd rsbuild-project
bun install
bun run dev
```

### 引入TailwindCSS

```bash
bun add tailwindcss @tailwindcss/postcss -D
```

```javascript
// postcss.config.mjs
export default {
  plugins: {
    '@tailwindcss/postcss': {},
  },
};
```

### 修改文件

修改`App.css`文件

```css
@import 'tailwindcss';
```

修改`App.tsx`文件

```typescript
import './App.css';

const App = () => {
  return (
    <div className="min-h-screen bg-white">
      <div className='w-[80%] min-h-screen mx-auto px-4 py-4 flex flex-col justify-center items-center'>
        <div className='w-full text-center'>
          <h1 className='text-2xl'>Rsbuild with React</h1>
        </div>
        <div className='w-full text-center'>
          <p>Start building amazing things with Rsbuild.</p>
        </div>
      </div>
    </div>
  );
};

export default App;

```

再次运行服务器

```bash
bun run dev
```

<img src="/images/rsbuild_react.png" style="width: 800px;" />


### 引入Redux

在团队比较小的时候，不推荐引入Redux。但如果为了学习(炫技)，可以参考下面的repo，引入Redux Toolkit。其实，在只有一个计数器组件或者单个页面的情况下，`useState`都够用了。

[https://github.com/zhongxiao37/from-react-to-aggressive](https://github.com/zhongxiao37/from-react-to-aggressive)

## Vite

### 初始化 Vite 项目

```bash
bun create vite
```

<img src="/images/vite_instruction.png" style="width: 800px;" />


```bash
cd vite-quick-start
bun install
```

### 添加Tailwind CSS

```bash
bun add tailwindcss @tailwindcss/vite -D
```

修改 vite.config.ts

```javascript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import tailwindcss from '@tailwindcss/vite';

// https://vite.dev/config/
export default defineConfig({
  plugins: [
    react(),
    tailwindcss()
  ],
});
```

修改 `App.css`

```css
@import "tailwindcss";
```

修改 `App.tsx`

```typescript
import './App.css';

function App() {

  return (
    <>
      <div className="min-h-screen bg-white">
        <div className='w-[80%] min-h-screen mx-auto px-4 py-4 flex flex-col justify-center items-center'>
          <div className='w-full text-center'>
            <h1 className='text-2xl'>Rsbuild with React</h1>
          </div>
          <div className='w-full text-center'>
            <p>Start building amazing things with Rsbuild.</p>
          </div>
        </div>
      </div>
    </>
  );
}

export default App;

```

再次运行服务

```bash
bun run dev
```


## Reference

[https://rsbuild.dev/zh/guide/basic/tailwindcss](https://rsbuild.dev/zh/guide/basic/tailwindcss)
[https://tailwindcss.com/docs/installation/using-vite](https://tailwindcss.com/docs/installation/using-vite)

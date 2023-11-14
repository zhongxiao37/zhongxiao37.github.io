---
layout: default
title: Rails 7 + esbuild + React
date: 2023-11-15 17:15 +0800
categories: rails react
---

基本上和前一篇文章一样，支持剥离了 Stimulus 和 BootStrap，换成了 React+MUI。

```bash
yarn add react react-dom @types/react @types/react-dom typescript
```

再把 Stimulus 相关的全部删掉。

创建 `app/javascript/application.tsx`

```javascript
import React from "react";
import ReactDOM from "react-dom/client";
import Counter from "./components/Counter";

const App = () => {
  return (
    <div className="App">
      <Counter />
    </div>
  );
};

const root = ReactDOM.createRoot(
  document.getElementById("root") as HTMLElement
);

root.render(<App />);

```

创建 `app/javascript/components/Counter.tsx`

```javascript
import React, { useState } from "react";

const Counter: React.FC = () => {
  const [count, setCount] = useState(0);

  const handleIncrement = () => {
    setCount(count + 1);
  };

  const handleDecrement = () => {
    setCount(count - 1);
  };

  return (
    <div>
      <div>
        <button onClick={handleDecrement}>-</button>
        <h5>Count is {count}</h5>
        <button onClick={handleIncrement}>+</button>
      </div>
      <button onClick={() => setCount(0)}>Reset</button>
    </div>
  );
};

export default Counter;
```

---
layout: default
title: React useMemo
date: 2025-12-19 15:02 +0800
categories: react
---

<img src="/images/react_use_memo.jpg" style="width: 100%;" />

# 为什么 `React.memo` 和 `useMemo` 能解决重复渲染问题

## 核心问题：React 默认会重复渲染

React 的默认行为非常简单：**只要组件的状态发生改变，它及其所有子组件都会重新渲染**，无论子组件的 props 是否真的发生了变化。

这种默认机制是合理的——React 无法在不执行子组件的情况下知道其输出是否会改变。但对于高开销的组件或庞大的组件树来说，这会成为性能瓶颈。

---

## 一个具体的例子

看看项目中的 `Gallery.tsx`：

```tsx
function Gallery() {
  const [title, setTitle] = useState("我的相册");
  const [photos] = useState([
    { id: 1, url: "img1.jpg" },
    { id: 2, url: "img2.jpg" },
  ]);

  return (
    <div>
      <input value={title} onChange={(e) => setTitle(e.target.value)} />
      {photos.map((photo) => (
        // ❌ 每次 setTitle 都会触发 Gallery 重新渲染，
        //    进而导致每个 PhotoItem 重新渲染 —— 即使 photos 根本没变。
        <PhotoItem key={photo.id} photo={photo} />
      ))}
    </div>
  );
}

function PhotoItem({ photo }: { photo: { id: number; url: string } }) {
  console.log(`渲染照片: ${photo.id}`);
  return <div className="draggable">photo id: {photo.id}</div>;
}
```

**在输入框打字时会发生什么？**

1. 调用 `setTitle(...)` → `Gallery` 重新渲染
2. React 在新的输出中看到了 `<PhotoItem photo={photo} />`
3. 即使 `photos` 没变，React 依然会重新渲染每一个 `PhotoItem`
4. 每次按键，控制台都会打印所有照片的渲染日志

这种无意义的性能损耗，会随着子组件数量和单个组件渲染开销的增加而放大。

---

### 常见误区：加了 `key` 为什么还会重新渲染？

这是一个非常经典且常见的 React 误区。很多人会疑惑：**我已经给 `<PhotoItem key={photo.id} />` 加了 `key`，为什么它还是重新渲染了？**

简单来说：**`key` 的作用是“避免组件被销毁和重建”，而不是“阻止组件重新渲染（Re-render）”。**

- **重新渲染（Re-render）**：React 调用了组件的函数，生成了新的 Virtual DOM（虚拟 DOM）。
- **DOM 更新**：React 将新的 Virtual DOM 和旧的对比，发现差异后，去修改浏览器里真实的 HTML DOM。

因为有 `key` 的存在，React 在对比新旧 Virtual DOM 时，发现这个 `PhotoItem` 还是原来的那个，所以它**不会去操作真实的浏览器 DOM**（避免了昂贵的 DOM 销毁和重建，也保留了组件内部的 state）。
但是，在父组件更新时，**`PhotoItem` 这个 JavaScript 函数本身还是被徒劳地执行了一遍**。

| 工具 | 它的作用是告诉 React... | 解决的问题 |
| --- | --- | --- |
| **`key`** | “这是同一个组件，请保留它的状态，**不要销毁重建**它。” | 解决列表项顺序错乱、状态丢失、DOM 频繁销毁重建的问题。 |
| **`React.memo`** | “既然传给我的 props 没变，请**连我的函数都不要重新执行**。” | 解决父组件更新导致子组件无意义的重复执行（Re-render）问题。 |

所以，`key` 是列表渲染的**必需品**（保证正确性），而 `React.memo` 是阻止重复执行的**优化品**（提升性能）。

---

## 根本原因：每次渲染都产生新引用

React 使用**引用相等性**（`===`）来比较 props。当 `Gallery` 重新渲染时，它调用 `photos.map(...)` 并生成了新的 JSX（新的对象引用）。即使数据内容一模一样，React 也无法分辨，因此默认重新渲染子组件。

这里存在两个独立的问题：

| 问题                                        | 工具         |
| ------------------------------------------- | ------------ |
| 即使 props 没变，子组件依然重新渲染         | `React.memo` |
| 即使依赖没变，高开销的值/对象依然被重新计算 | `useMemo`    |

---

## 方案一：`React.memo` — 跳过未改变的子组件

`React.memo` 用于包裹组件并缓存其最后一次渲染结果。在重新渲染前，React 会对新旧 props 进行**浅比较**。如果相同，则直接跳过渲染，复用上一次的输出。

```tsx
const PhotoItem = React.memo(function PhotoItem({
  photo,
}: {
  photo: { id: number; url: string };
}) {
  console.log(`渲染照片: ${photo.id}`);
  return <div className="draggable">photo id: {photo.id}</div>;
});
```

现在，当 `Gallery` 因为 `setTitle` 重新渲染时：

- React 检查：`PhotoItem` 的 `photo` prop 变了吗？
- `photo` 依然是来自 `useState` 的同一个对象引用 → **没有变化**
- React **完全跳过** `PhotoItem` 的重新渲染 ✅

> **核心洞察：** `React.memo` 只有在 props 引用稳定时才有效。
> 如果父组件每次渲染都创建新的对象或数组字面量作为 prop 传入，`React.memo` 依然会触发重新渲染，因为 `{} !== {}`。

---

## 方案二：`useMemo` — 稳定昂贵的值

`useMemo` 用于缓存**计算结果**。它只在依赖项数组发生变化时才会重新执行计算函数。

```tsx
function Gallery() {
  const [title, setTitle] = useState("我的相册");
  const [photos] = useState([
    { id: 1, url: "img1.jpg" },
    { id: 2, url: "img2.jpg" },
  ]);

  // 假设我们需要从 photos 派生出一个过滤/排序后的列表
  const visiblePhotos = useMemo(
    () => photos.filter((p) => p.url.endsWith(".jpg")),
    [photos] // 只有当 `photos` 改变时才重新计算
  );

  return (
    <div>
      <input value={title} onChange={(e) => setTitle(e.target.value)} />
      {visiblePhotos.map((photo) => (
        <PhotoItem key={photo.id} photo={photo} />
      ))}
    </div>
  );
}
```

如果没有 `useMemo`，每次 `setTitle` 都会执行 `photos.filter(...)` 并产生一个**新的数组引用**，这会让 `PhotoItem` 上的 `React.memo` 失效。使用了 `useMemo` 后，只要 `photos` 没变，就会返回相同的数组引用，从而顺利通过 `PhotoItem` 的 memo 检查。

> `useMemo` 是 `React.memo` 的最佳拍档：
> 它稳定了向下传递的值，从而让子组件内部的 memo 检查能够成功。

---

## 它们如何协同工作

```text
父组件重新渲染（例如 title 改变）
        │
        ▼
React.memo 检查：PhotoItem 的 props 变了吗？
        │
        ├─ props 引用稳定（useMemo 保持了引用） ──► 跳过重新渲染 ✅
        │
        └─ props 改变（产生了新引用） ───────────► 正常重新渲染
```

这两个工具解决了同一个问题的不同方面：

- **`useMemo`** 避免不必要的重复计算，并保持引用稳定。
- **`React.memo`** 通过比较这些引用，避免不必要的重新渲染。

---

## 何时使用这些工具

使用 `React.memo` 的场景：

- 组件是**纯组件**（相同的 props 产生相同的输出）
- 组件**频繁**渲染，但其 props **极少改变**
- 组件渲染**开销很大**（如长列表、复杂图表）

使用 `useMemo` 的场景：

- 计算**开销很大**（如过滤/排序大型数据集）
- 需要一个**稳定的对象/数组引用**作为 prop 传递给 memo 化的子组件
- 该值被用作 `useEffect` 或另一个 `useMemo` 的依赖项

> **切勿滥用。** 任何缓存机制都有开销——比较操作本身也消耗时间和内存。
> 先进行性能分析；只有当重新渲染的开销明显大于比较开销时，才添加 memo。
> 对于大多数小型组件，React 的默认行为已经足够快了。

---

## 总结

|                                          | 未使用缓存           | 使用缓存                      |
| ---------------------------------------- | -------------------- | ----------------------------- |
| `PhotoItem` 在 title 改变时重新渲染      | 是 —— 每次按键都会   | 否 —— 被 `React.memo` 跳过    |
| `photos.filter(...)` 在 title 改变时执行 | 是 —— 每次产生新引用 | 否 —— `useMemo` 返回缓存结果  |
| Props 比较结果                           | —                    | 相同引用，memo 跳过子组件渲染 |

React 的重新渲染模型在设计上简单且可预测。
`React.memo` 和 `useMemo` 是精准的手动优化工具，它们在告诉 React：
**“我保证输出不会改变——你可以跳过这项工作。”**

---
layout: default
title: Superpowers 是如何工作的
date: 2026-01-19 12:28 +0800
categories: superpowers claude-code
---

<img src="/images/superpowers.jpg" style="width: 100%;" />

我最近在折腾 AI 编程助手的工程化落地，遇到了一个非常有意思的框架：**Superpowers**。

## 1. 什么是 Superpowers？

简单来说，Superpowers 是一个为 AI 编程助手（如 Claude Code、Cursor、Gemini）设计的**智能体技能框架与软件开发方法论**。

如果把原生的 AI 助手比作一个“极其聪明但随性妄为的天才实习生”，那么 Superpowers 就是给这个实习生发了一本**“资深架构师的 SOP 手册”**。它通过一套可组合的自动化技能（Skills），强制 AI 遵循严格的工程规范，把随性的“盲盒式”代码生成，变成了严谨的工业级软件工程实践。

## 2. 为什么我们需要 Superpowers？

在日常使用 AI 写代码时，你肯定遇到过这种痛点：你丢给 AI 一个稍微复杂点的需求，它二话不说直接开始“狂飙”代码。结果写了几百行之后你发现，它完全理解错了你的意图，或者漏掉了关键的边界条件。这时候你只能让它推倒重来，不仅浪费 Token，还让人血压飙升。

相比于传统的“一语成谶”式 Prompt，Superpowers 解决了以下问题：

- **拒绝盲目开工**：强制 AI 在写代码前先和你对齐需求。
- **流程约束替代随机猜测**：用标准的软件工程流程（需求 -> 设计 -> 计划 -> TDD）来兜底代码质量。
- **高自主性与低返工率**：通过子智能体（Sub-agents）分工，让 AI 自己 Review 自己的产出。

## 3. Superpowers 是如何工作的？

Superpowers 的核心工作流完全模拟了真实世界中高级研发团队的开发节奏。我们可以把它拆解为以下几个关键步骤：

### 步骤 1：需求头脑风暴 (Brainstorming)

当你抛出一个需求时，Superpowers 不会立刻写代码，而是调用 `brainstorm` 技能。它会像一个资深产品经理一样，反问你几个关键问题，探索不同的技术方案。
这其实就是在**对齐需求**，避免最后做出来的东西不是你想要的。

<img src="/images/superpowers_1.png" style="width: 100%;" />
<img src="/images/superpowers_2.png" style="width: 100%;" />
<img src="/images/superpowers_3.png" style="width: 100%;" />

### 步骤 2：编写与确认 Spec

需求对齐后，Agent 会自己去起草一份详细的技术规格说明书（Spec）。它会自我 Review 这份 Spec，直到你最终 `Approve`。白纸黑字，绝不含糊。

<img src="/images/superpowers_4.png" style="width: 100%;" />
<img src="/images/superpowers_5.png" style="width: 100%;" />
<img src="/images/superpowers_6.png" style="width: 100%;" />

### 步骤 3：制定执行计划 (Plan)

Spec 完成后，AI 会将其拆解为可执行的步骤，生成一份 Plan。同样，这份 Plan 需要经过 Review 和你的 Approve。

<img src="/images/superpowers_7.png" style="width: 100%;" />

### 步骤 4：TDD 驱动的自治开发

确定 Plan 之后，基本就不需要人为介入了。Superpowers 会基于测试驱动开发（TDD）的原则，自己写测试用例，自己写业务代码，自己跑测试，陷入“红-绿-重构”的循环，直到最后所有测试通过。

<img src="/images/superpowers_8.png" style="width: 100%;" />

## 4. 优缺点

客观来说，Superpowers 并不是银弹，它有明确的适用场景：

- **优点**：
  - **极高的代码可靠性**：通过 TDD 和严格的 Spec 约束，产出的代码质量远超普通对话。
  - **解放开发者精力**：在 Plan 确认后，你可以去喝杯咖啡，让 AI 自己去折腾测试和实现。
  - **可组合性极强**：技能（Skills）可以像乐高积木一样自由组合。
- **缺点**：
  - **前期沟通成本高**：如果你只是想写个 20 行的 Python 脚本，走这套流程纯属杀鸡用牛刀。
  - **Token 消耗大户**：反复的 Review 和 TDD 循环会消耗海量的上下文 Token。200K 的上下文窗口，一下就占据了 120K。

## 5. 真实世界的验证：它是如何串联的？

我最初非常惊讶于这套复杂的工程方法是如何串联起来的。通常我们会认为，这需要像 Airflow、Dify 或 n8n 那样用复杂的 DAG（有向无环图）去编排。

但当我打开它的 `SKILL.md` 源码时，我才恍然大悟：**它纯靠 Prompt 里的上下文交接（Handoff）来驱动下一步。**

每个 Skill 在执行完毕时，都会明确告诉 AI 下一步该调用哪个 Skill。比如下面这段截取自 Plan 完成后的交接配置：

```markdown
## Execution Handoff

After saving the plan, offer execution choice:

"Plan complete and saved to docs/superpowers/plans/<filename>.md. Two execution options:

1. Subagent-Driven (recommended) - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. Inline Execution - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?"

If Subagent-Driven chosen:
REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
Fresh subagent per task + two-stage review

If Inline Execution chosen:
REQUIRED SUB-SKILL: Use superpowers:executing-plans
Batch execution with checkpoints for review
```

这就好比流水线上的工人，干完自己的活后，直接把工单和下一步的指令贴在产品上递给下一个人，极其优雅且轻量。

## 6. 排错 / 常见冲突

在实际使用 Superpowers 时，你可能会遇到以下边缘情况：

- **TDD 死循环**：有时候 AI 会卡在某个无法通过的测试用例上，反复修改代码但依然报错（比如遇到了底层依赖的 Bug）。
  - **解决方案**：及时介入，输入 `Stop` 中断执行。手动检查测试用例是否合理，或者引导 AI 换一种实现思路，甚至允许它暂时跳过该测试（`skip test`）。
- **上下文爆炸 (Context Limit)**：由于流程极长，如果项目较大，很容易触碰模型上下文上限。
  - **解决方案**：强烈建议使用 **Subagent-Driven** 模式（如上文代码块所示）。这种模式会为每个子任务派发一个全新的子智能体（Subagent），从而有效隔离上下文，避免主会话被垃圾信息撑爆。

---
layout: default
title: 如何用AI做code review
date: 2026-01-24 18:02 +0800
categories: llm
---


Cursor 有一篇很棒的[文章](https://cursor.com/docs/cli/cookbook/code-review)介绍了如何做Code Review，虽然我对于提示词工程不是很感兴趣，但还是决定试一试，因为Code Review占据了我相当多的时间，而我又不希望自己成为一个Baby sister一样去教别人101课程。

## 创建 bb cli

因为使用的是Bitbucket 作为代码仓库，而Bitbucket又没有像github一样，有`gh` cli工具。作为第一步，先着重在PR相关的命令上，比如`bb pr list`、`bb pr diff`、`bb pr show`等。

所以，刚开始的时候，主要是实现`bb pr`相关的命令。

## 创建 bb pr review

`bb pr review`才是和LLM集合起来做code review的命令。所需要做的就是把提示词所需要的东西全部拼起来，然后一股脑丢给Cursor CLI `agent`，就完事了。因为Scope比较清晰，不会让AI去发挥，所以我并不用特别担心翻车和幻觉。

## 自定义Review 规则

我定义了一个自定义Review 规则的文件 `.cursor/code_review_rules.md`，如果发现，就合并到提示词里面去，这样实现了自定义的Review规则。

## 更多

可能需要支持PR URL为参数，但是有一个问题是如何让Cursor知道整个代码仓库，而不是只Review一个`git diff`。


## Codes

上面的代码已经放到Github了，如果有兴趣，可以自己试一试。
[https://github.com/zhongxiao37/bitbucket-cli](https://github.com/zhongxiao37/bitbucket-cli)
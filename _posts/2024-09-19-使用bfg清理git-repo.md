---
layout: default
title: 使用bfg清理git repo
date: 2024-09-19 13:21 +0800
categories: git
---

如果你需要从一个 repo 里面，彻底清理掉一个大文件、密码文件，你可以考虑使用 [bfg](https://rtyley.github.io/bfg-repo-cleaner/)。

我有一个同事，误把`node_modules`文件夹提交到了 git repo，虽然可以再提交一个 commit 清理掉这个文件夹，但是整个历史里面还保留这个文件，导致 git history 异常庞大。

```bash
bfg --delete-folers node_modules  my-repo.git
```

又比如，我的另外一个同事不小心把一个数据库的 dump 文件提交到 repo 了，你可以使用 rebase。但是如果历史比较久，rebase 就很无力了，除非你想修复无数个冲突。这个时候你也可以使用`bfg`达到同样的目的。

## But...

但是，我想说的是，这样可能导致整个分支的 commit hash 被重写，其他分支需要重新基于这个分支拉去一次，否则会导致合并的时候发现许多额外的 commit。我遇到的情况就是，一位同事`bfg`操作之后，导致我的 PR 里面多了额外 600 多个 commit，完全没法做 code review。

如果分支比较简单，一直都只有一个分支，没有多人协作，就不会有这样的困扰。

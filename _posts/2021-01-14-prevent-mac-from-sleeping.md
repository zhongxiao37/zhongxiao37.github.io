---
layout: default
title: Prevent Mac from sleeping
date: 2021-01-14 13:47 +0800
categories: mac
---

来点咖啡因

```bash
# 禁止显示器睡眠
caffeinate -d
# 禁止系统睡眠
caffeinate -is
# 当1000号进程存在时不睡眠
caffeinate -w 1000
# 1小时内不睡眠
caffeinate -t 3600
```


```bash
-d      Create an assertion to prevent the display from sleeping.
-i      Create an assertion to prevent the system from idle sleeping.
-m      Create an assertion to prevent the disk from idle sleeping.
-s      Create an assertion to prevent the system from sleeping. This assertion is valid only when system is running on AC power.
-u      Create an assertion to declare that user is active. If the display is off, this option turns the display on and prevents the display from going
        into idle sleep. If a timeout is not specified with '-t' option, then this assertion is taken with a default of 5 second timeout.

```
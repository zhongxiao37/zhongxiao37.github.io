---
layout: default
title: Google colab + Stable Diffusion
date: 2023-03-01 17:31 +0800
categories: machine_learning aigc
---

# 薅谷歌的羊毛来AIGC


## 免费拥有GPU的机器

访问[Google Colab](https://colab.research.google.com/), 在`修改 > 笔记本设置`里面选择GPU，你就拥有一个15G显存的GPU.


## 尝试模型

随便选择一个模型[Stable Diffusion 1.4](https://huggingface.co/CompVis/stable-diffusion-v1-4?text=A+small+cabin+on+top+of+a+snowy+mountain+in+the+style+of+Disney%2C+artstation), 直接将实例代码复制到笔记本中，就可以开始绘图了。

效果还不错，基本30秒出图。而在自己的2021版的i9 MBP上，6分钟才出一幅图，而且系统巨卡，没法做其他的操作。

<img src="/images/sd_example.png" width="800" />

<img src="/images/google_colab.png" width="800" />

## 只是尝试

如果只是尝试一下，可以访问[Demo](https://huggingface.co/spaces/stabilityai/stable-diffusion)来尝试。

## 本地搭建

本地可以用[开源项目](https://github.com/AUTOMATIC1111/stable-diffusion-webui), 就可以搭建一个Stable Diffusion Web UI。但是最好你有一个显卡，否则会很慢很卡。对于苹果用户，可以按照[文档](https://github.com/AUTOMATIC1111/stable-diffusion-webui/wiki/Installation-on-Apple-Silicon)搭建环境。
---
layout: default
title: 如何将Pytorch模型转换为ONNX格式
date: 2024-11-09 11:37 +0800
categories: onnx
---

我将Bert模型训练出来之后，又将其容器化，但是遇到新的问题是镜像太大。

刚开始，我的`Dockerfile`如下，打出来的镜像有近8个G。

```dockerfile
FROM python:3.11.8
RUN apt-get update && apt install -y libglib2.0-0 libgl1-mesa-dev
RUN pip install uwsgi --no-cache-dir
RUN pip install torch==2.2.2 transformers==4.41.0 seqeval==1.2.2 pytorch-crf==0.7.2 flask flask-cors --no-cache-dir
RUN pip install kubernetes --no-cache-dir
ENV HF_HUB_CACHE=.cache
COPY . .
```

将模型转换为ONNX格式之后，镜像缩小为2个G。去掉不需要的torch和transformers包，再加入onnx即可。

```diff
- RUN pip install torch==2.2.2 transformers==4.41.0 seqeval==1.2.2 pytorch-crf==0.7.2 --no-cache-dir
+ RUN pip install onnx onnxruntime --no-cache-dir
```

## 什么是ONNX

`pytorch`是专门为了训练模型而生的，但是模型的部署却不需要那么多功能。相反，ONNX是标准描述计算图的一种格式，支持多种深度学习模型框架，可以部署在各种边缘设备上。

比如`pytorch`可以通过下面的代码导出成为ONNX格式。

```python
x = torch.randn(1, 3, 256, 256) 
 
with torch.no_grad(): 
    torch.onnx.export( 
        model, 
        x, 
        "srcnn.onnx", 
        opset_version=11, 
        input_names=['input'], 
        output_names=['output'])
```

至于为什么要喂入`x`，才可以生成ONNX，主要是要让模型运行一次，然后把跟踪计算图，进而保存成ONNX格式。

ONNX格式文件可以通过[Netron](https://netron.app/)打开，可以看到整个计算图。

<img src="/images/onnx_diagram.png" style="width:800px">
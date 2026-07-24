---
title: 从 PaddleOCR 到 RapidOCR
date: 2026-07-09 14:44 +0800
categories: ocr
---

之前一直听说 PaddleOCR 的中文识别效果不错，但始终没有找到一个机会去试它。刚好最近好奇识别食品包装袋背面的文字：营养成分表、配料、保质期、生产许可证、条形码...

这类图片很适合拿来检验 OCR：把一张排版规整的扫描件认出来不算难，能把手机随手拍的包装袋认出来，才更接近真实业务。

我一开始选择了 PaddleOCR，识别结果确实不错，但部署以后遇到了两个很现实的问题：

- CPU 推理一次需要将近 **30 秒**；
- Docker 镜像接近 **3 GB**。

于是我又把同一套流程迁移到了 RapidOCR。最终，同一张图片仍然检测出 42 行文字，结构化结果基本不变，但推理时间从 **28.2 秒降到 2.0 秒左右**，Docker 镜像也从 **3 GB 降到 1.4 GB**。

这篇文章记录完整的迁移和验证过程。所有耗时都来自同一张图片、同一台机器、CPU 模式和 4 个线程，不是拿两组不同环境的数据硬凑出来的。

## 什么是 PaddleOCR？

PaddleOCR 是 PaddlePaddle 生态中的 OCR 工具箱。它并不是一个“把图片扔进去就吐文字”的单模型，而是一条由多个模型组成的流水线：

1. **检测模型**先找出图片里哪些区域有文字；
2. **方向分类模型**判断文字行是否倒置；
3. **识别模型**把裁剪后的文字图片转换成字符串；
4. 可选的文档方向和展平模型，负责处理整页旋转、弯曲和透视变形。

可以把它想象成工厂流水线：一个工人找货物，一个工人把货物摆正，最后一个工人读取标签。每个工人都更专业，但每增加一道工序，也会增加模型体积和运行成本。

### PP-OCRv6 和 PaddleOCR-VL 有什么区别？

这两个名字容易让人以为只是“大模型”和“小模型”的区别，实际上它们解决问题的方式不同：

- **PP-OCRv6** 是传统 OCR 流水线，核心任务是文字检测和识别。输出是文字、坐标和置信度，速度和资源占用相对可控。
- **PaddleOCR-VL** 是视觉语言模型路线，更关注复杂文档理解，例如表格、公式、图表和版面语义。它不只是“看见文字”，还要理解文档结构，因此通常更重。

我的目标只是从食品包装中取出文字，再交给自己的规则做结构化处理。这个场景用 PP-OCRv6 更直接，没必要让视觉语言模型扛着一整套文档理解能力上场。

## PaddleOCR 到底加载了哪些模型？

初始化 PaddleOCR 时，经常会看到一长串模型下载日志。下面这五个名字最容易让人迷糊：

| 模型                         | 作用                                   | 本次是否启用 |
| ---------------------------- | -------------------------------------- | ------------ |
| `PP-LCNet_x1_0_doc_ori`      | 判断整张文档是 0°、90°、180° 还是 270° | 否           |
| `PP-LCNet_x1_0_textline_ori` | 判断单行文字是否为 0° 或 180°          | 是           |
| `PP-OCRv6_medium_det`        | 找出文字框的位置                       | 是           |
| `PP-OCRv6_medium_rec`        | 把文字框识别成字符串                   | 是           |
| `UVDoc`                      | 对弯曲、透视变形的文档进行展平         | 否           |

这次输入是手机照片，但图片带有正确的 EXIF 方向信息。我在预处理阶段先校正整图方向，因此关闭了文档方向分类和文档展平，只保留检测、识别和文字行方向分类：

```python
PADDLE_CONFIG = {
    "lang": "ch",
    "use_doc_orientation_classify": False,
    "use_doc_unwarping": False,
    "use_textline_orientation": True,
    "device": "cpu",
    "enable_mkldnn": False,
    "cpu_threads": 4,
}
```

实际初始化日志也证明只加载了三个模型：

```text
PP-LCNet_x1_0_textline_ori
PP-OCRv6_medium_det
PP-OCRv6_medium_rec
```

这里有一个容易踩的坑：**文字行方向分类不负责把横着的整张照片转正**。它只处理单行文字的 0°/180° 方向。图片整体旋转 90° 时，要么先处理 EXIF，要么开启 `use_doc_orientation_classify`。

## 用 PaddleOCR 跑通完整流程

### 1. 安装依赖

Notebook 本身使用已经准备好的虚拟环境，没有固定依赖版本。下面是最小安装方式，生产环境则应该把实际验证过的版本锁进项目的依赖文件：

```bash
uv add paddlepaddle paddleocr pillow numpy
```

PaddleOCR 第一次初始化时会联网下载模型，并缓存到 `~/.paddlex/official_models/`。后续启动可以复用缓存；如果容器每次启动都重新下载，启动时间和稳定性都会变得很难看。

### 2. 校正 EXIF 并缩放图片

测试图片的原始像素尺寸是 `4032 × 3024`，EXIF Orientation 为 `6`。如果直接把像素交给 OCR，看到的图片会横着躺下。`ImageOps.exif_transpose()` 会按照 EXIF 信息真正旋转像素：

```python
from pathlib import Path

import numpy as np
from PIL import Image, ImageOps

MAX_SIDE = 3000
image = Image.open(Path("data/test_2.jpeg"))
image = ImageOps.exif_transpose(image).convert("RGB")

width, height = image.size
scale = min(1.0, MAX_SIDE / max(width, height))
if scale < 1:
    image = image.resize(
        (round(width * scale), round(height * scale)),
        Image.Resampling.LANCZOS,
    )

ocr_input = np.asarray(image)
```

实际预处理输出如下：

```text
原始像素尺寸 (宽, 高): (4032, 3024)
EXIF Orientation: 6
校正后尺寸 (宽, 高): (3024, 4032)

shape (高, 宽, 通道): (3000, 2250, 3)
dtype: uint8
缩放比例: 0.744
```

最长边限制为 3000，是识别率和推理速度之间的折中。包装上的小字很多，缩得太狠会让笔画糊成一团；完全不缩，CPU 又要在 1200 多万像素上慢慢找字。

### 3. 初始化并执行识别

```python
from time import perf_counter
from paddleocr import PaddleOCR

started = perf_counter()
ocr = PaddleOCR(**PADDLE_CONFIG)
model_init_ms = (perf_counter() - started) * 1000

started = perf_counter()
raw_results = list(ocr.predict(ocr_input))
paddle_inference_ms = (perf_counter() - started) * 1000
```

输出结果是一个 `OCRResult`，常用字段有：

- `rec_polys`：文字框坐标；
- `rec_texts`：识别文本；
- `rec_scores`：每行文字的置信度；
- `textline_orientation_angles`：文字行方向。

这次实测结果：

```text
模型类型: PaddleOCR
初始化耗时: 1724.5 ms
页面结果数量: 1
推理耗时: 28185.9 ms

rec_polys: len=42
rec_texts: len=42
rec_scores: len=42
textline_orientation_angles: len=42
平均置信度: 0.9993
```

识别内容已经相当完整，例如：

```text
2026年05月07日合格
品名：扁桃仁粉
配料表：扁桃仁粉
产品标准代号：GB 19300
保质期：18个月
食品生产许可证编号：SC12336098200173
条形码：6951181105326
```

问题不在于能不能认出来，而在于 **28 秒的 CPU 延迟很难放进在线接口**。一次调试等半分钟还能忍，用户每上传一张图片都等半分钟就不行了。

## 什么是 RapidOCR？

RapidOCR 的思路是把 OCR 模型转换到 ONNX 等更通用的推理格式，再使用 ONNX Runtime、OpenVINO 等后端执行。

它和 PaddleOCR 的关系有点像“整套开发平台”和“轻量运行时”：

- PaddleOCR 提供完整的训练、模型管理和文档处理生态；
- RapidOCR 更专注于把已有 OCR 模型轻量地跑起来；
- 对只需要 CPU 推理的服务来说，RapidOCR 少带了不少训练和框架层依赖。

这不代表 RapidOCR 在所有场景都更强。它的优势恰好击中了我的需求：模型固定、CPU 部署、只做推理，并且后处理逻辑已经掌握在自己手里。

## 把调用替换成 RapidOCR

### 1. 安装和配置

```bash
uv add rapidocr onnxruntime pillow numpy
```

本次使用 ONNX Runtime CPU 后端，并把线程数和 PaddleOCR 保持一致：

```python
RAPIDOCR_CONFIG = {
    "EngineConfig.onnxruntime.intra_op_num_threads": 4,
    "EngineConfig.onnxruntime.inter_op_num_threads": 1,
    "Global.max_side_len": 3000,
    "Global.log_level": "warning",
}
```

### 2. 注意 RGB 和 BGR 的区别

这是迁移时最容易被忽略的一刀：

- PaddleOCR 的这段调用接收 **RGB** 数组；
- RapidOCR 的 NumPy 图片按 OpenCV 习惯使用 **BGR**。

如果通道顺序传反，代码不一定报错，但模型看到的红色会变成蓝色，识别率可能悄悄下降。最麻烦的 bug 往往不是直接爆炸，而是“还能跑，只是结果有点怪”。

```python
rgb_input = np.asarray(image)
ocr_input = rgb_input[:, :, ::-1].copy()  # RGB -> BGR
```

转换后的输入仍然是：

```text
shape (高, 宽, 通道): (3000, 2250, 3)
dtype: uint8
像素范围: 0 ~ 255
通道顺序: BGR
```

### 3. 初始化和推理

RapidOCR 使用可调用对象，不是 PaddleOCR 的 `predict()`：

```python
from time import perf_counter
from rapidocr import RapidOCR

started = perf_counter()
ocr = RapidOCR(params=RAPIDOCR_CONFIG)
model_init_ms = (perf_counter() - started) * 1000

started = perf_counter()
raw_result = ocr(ocr_input)
total_ms = (perf_counter() - started) * 1000

boxes = raw_result.boxes
texts = raw_result.txts
scores = raw_result.scores
```

`RapidOCROutput` 中的核心字段是 `boxes`、`txts` 和 `scores`，正好可以映射到原有的坐标、文字和置信度数组。因此迁移并没有推翻后处理代码，只是换掉了最前面的 OCR 引擎。

实测输出：

```text
模型类型: RapidOCR
初始化耗时: 221.1 ms
端到端耗时: 1954.3 ms

文字检测耗时: 1409.0 ms
文字行方向分类耗时: 27.8 ms
文字识别耗时: 509.2 ms

检测数量: 42
平均置信度: 0.9974
```

从分阶段数据也能看出，RapidOCR 的主要耗时在文字检测，约占 OCR 内核耗时的 72%。如果还要继续优化，优先考虑输入尺寸和检测模型，而不是盯着只花了 27.8 ms 的方向分类器。

## 识别结果是否缩水？

只看速度没有意义。如果快了十几倍，却漏掉一半文字，那只是更快地产生错误。

同一张包装图片，两套引擎都检测到 **42 行文字**，条形码、品名、配料、生产许可证、产地、厂商等最终结构化字段完全一致：

```json
{
  "barcode": {
    "number": "6951181105326"
  },
  "label_info": {
    "package_printed_date": "2026年05月07日",
    "inspection_result": "合格",
    "product_name": "扁桃仁粉",
    "ingredients": "扁桃仁粉",
    "product_standard": "GB 19300",
    "product_category": "生干坚果",
    "shelf_life": "18个月",
    "storage_condition": "请存放阴凉干燥处，密封存放",
    "food_production_license": "SC12336098200173",
    "origin": "江西省宜春市"
  }
}
```

不过原始 OCR 结果并非逐字完全相同：

- PaddleOCR 的平均置信度是 `0.9993`，RapidOCR 是 `0.9974`；
- PaddleOCR 识别出 `每100克(g)`，RapidOCR 是 `每100克`；
- 个别营养成分行的检测坐标和排序略有不同；
- RapidOCR 不暴露每一行的具体方向角。

这些差异对当前标签字段没有影响，但如果业务要求原样还原单位、标点或版面，就不能只比较“有没有认出大概意思”。

<img src="/images/ocr.png" style="width: 100%;" />

### 一个不能甩锅给 OCR 的错误

两套引擎最终都把营养成分表的部分数值错配了，例如把蛋白质的值放到了能量后面。由于两个引擎的错误模式完全一样，而原始文字又都识别正确，问题显然在后续表格行列匹配逻辑，不在 OCR。

这点很重要：**OCR 负责把字和坐标交出来，不等于它已经理解了表格**。如果结构化结果有问题，要沿着“检测框 → 阅读顺序 → 行列聚类 → 字段映射”逐层排查，不能看到最终 JSON 错了就立刻换模型。

## 性能和部署体积对比

下面的数据来自同一张 `3000 × 2250` 图片、同一台机器、CPU 模式和 4 个线程：

| 指标               |  PaddleOCR |  RapidOCR |                变化 |
| ------------------ | ---------: | --------: | ------------------: |
| 模型初始化         |  1724.5 ms |  221.1 ms |         约快 7.8 倍 |
| 端到端推理         | 28185.9 ms | 1954.3 ms |        约快 14.4 倍 |
| 检测数量           |         42 |        42 |                相同 |
| 平均置信度         |     0.9993 |    0.9974 |            略有下降 |
| 实际启用的模型大小 |  约 139 MB |  约 30 MB | 减少约 109 MB / 78% |
| Docker 镜像        |    约 3 GB | 约 1.4 GB | 减少约 1.6 GB / 53% |

### 模型文件有多大？

RapidOCR 默认把下载的模型放在 Python 包的 `rapidocr/models/` 目录。本次实际使用了三个 ONNX 模型：

```text
572K  ch_ppocr_mobile_v2.0_cls_mobile.onnx
9.5M  PP-OCRv6_det_small.onnx
20M   PP-OCRv6_rec_small.onnx
```

三者合计约 **30 MB**。PaddleOCR 的模型位于 `~/.paddlex/official_models/`，本次启用的三个模型分别是：

```text
6.6M  PP-LCNet_x1_0_textline_ori
59M   PP-OCRv6_medium_det
73M   PP-OCRv6_medium_rec
```

合计约 **139 MB**，约为 RapidOCR 模型的 **4.6 倍**。PaddleOCR 缓存目录里还有本次已经关闭的两个模型：

```text
6.6M  PP-LCNet_x1_0_doc_ori
31M   UVDoc
177M  official_models 总计
```

这里不能简单得出“ONNX 模型一定比 Paddle 模型小 4.6 倍”的结论，因为两边使用的模型规格并不相同：PaddleOCR 是 `PP-OCRv6_medium`，RapidOCR 是 `PP-OCRv6_small`。这组数字反映的是**本次两套实际部署配置**的差异，其中既有推理格式的影响，也有 medium 和 small 模型规格的影响。

可以用下面的命令在部署环境中复核：

```bash
# RapidOCR
RAPID_MODELS=$(python -c \
  'import rapidocr; from pathlib import Path; print(Path(rapidocr.__file__).resolve().parent / "models")')
du -sh "$RAPID_MODELS"
du -h "$RAPID_MODELS"/* | sort -h

# PaddleOCR
du -sh ~/.paddlex/official_models
du -sh ~/.paddlex/official_models/*
```

Docker 镜像从 3 GB 降到 1.4 GB，不只是磁盘数字好看：

- CI 构建和推送的数据量更少；
- 新节点拉取镜像更快；
- 扩容和故障恢复等待时间更短；
- 镜像中的依赖更少，潜在的漏洞和依赖冲突面也更小。

这里也要诚实一点：Notebook 没有测量峰值内存，所以我没有把“内存降低多少”写进表格。镜像小不等于运行时内存一定按同比例减少，两个指标不能混为一谈。

## 常见问题与排错

### 图片在相册里是正的，OCR 读到的却是横的

手机照片经常只在 EXIF 中记录方向，原始像素并没有旋转。先检查并应用 EXIF：

```python
from PIL import Image, ImageOps

image = Image.open("data/test_2.jpeg")
print(image.getexif().get(274))  # 6
image = ImageOps.exif_transpose(image)
```

如果图片没有可靠的 EXIF，再考虑开启 PaddleOCR 的文档方向分类。

### RapidOCR 能运行，但识别结果莫名下降

先检查颜色通道。PIL 通常是 RGB，OpenCV 和 RapidOCR 的 NumPy 输入通常是 BGR：

```python
bgr = np.asarray(pil_image)[:, :, ::-1].copy()
```

然后确认输入没有被重复缩放。外部预处理和 `Global.max_side_len` 同时缩放时，小字可能在不知不觉中被压扁。

### PaddleOCR 第一次启动特别慢

第一次运行需要下载并初始化模型。确认 `~/.paddlex/official_models/` 是否有缓存；在 Docker 中可以在构建阶段提前下载模型，避免每个新容器启动后再临时联网。

`IProgress not found` 和 `No ccache found` 是这次实验中出现的非致命警告，分别影响 Notebook 进度条和本地编译缓存，不影响 CPU OCR 推理结果。

### 为什么两边都是 42 行，结构化表格仍然错？

“识别数量相同”只能证明文字大致都找到了，不能证明阅读顺序和表格关系正确。建议把每个文字框画回原图，并同时输出排序后的索引：

1. 检查框是否覆盖了正确文字；
2. 检查同一行的框是否被分到一起；
3. 检查营养成分表的列边界；
4. 最后再检查字段映射。

## 最后怎么选？

如果需要训练模型、处理复杂文档，或者深度依赖 Paddle 生态，PaddleOCR 仍然是一套完整且成熟的方案。它的能力上限和可调范围都更大。

但如果场景和我一样：

- 模型固定，只做推理；
- 服务部署在 CPU；
- 关注接口延迟和镜像体积；
- 已经有自己的版面与字段后处理；

那么 RapidOCR 更像一把合手的小刀。它没有把整间工具房都塞进容器，却完成了这里真正需要的工作。

这次迁移最有价值的地方，不只是从 28 秒变成 2 秒，也不是省下 1.6 GB 镜像，而是验证了一件事：**OCR 引擎和业务后处理应该尽量解耦**。只要中间统一成 `boxes + texts + scores`，底层引擎就可以替换，业务代码不必跟着推倒重来。

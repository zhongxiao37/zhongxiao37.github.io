---
layout: default
title: Javascript下载多个文件并打zip包
date: 2023-11-14 15:38 +0800
categories: javascript
---

需求是，连接阿里云的 OSS，批量下载多个文件并打包。

页面上有一个 link，绑定了 click 事件，触发 download 函数。

先用`event.preventDefault()`防止页面跳转，然后请求`event.target`获取文件列表的地址。

```javascript
console.log("downloaing files", event);
event.preventDefault();
const zip = new JsZip();
const url = event.target.href;
const type = event.params.type;

const urls = await fetch(url)
  .then((res) => res.json())
  .then((data) => data.urls);
```

然后是下载所有的文件。通过`Promise.all`可以保证所有文件都下载完成以后，再继续执行下面的语句。

```javascript
const blobs = await Promise.all(
  urls.map((url) => {
    const fileName = new URL(url).pathname.split("/").pop();
    const blobs = fetch(url)
      .then((res) => res.blob())
      .then((blob) => [blob, fileName]);
    return blobs;
  })
);
```

最后是打包

```javascript
blobs.map(([blob, fileName]) => {
  zip.file(fileName, blob);
});

zip.generateAsync({ type: "blob" }).then((zipFile) => {
  const currentDate = new Date().getTime();
  const fileName = `${type}-${currentDate}.zip`;
  return saveAs(zipFile, fileName);
});
```

完整代码

```javascript
  async download(event) {
    console.log("downloaing files", event);
    event.preventDefault();
    const zip = new JsZip();
    const url = event.target.href;
    const type = event.params.type;

    const urls = await fetch(url)
      .then((res) => res.json())
      .then((data) => data.urls);


    const blobs = await Promise.all(
      urls.map((url) => {
        const fileName = new URL(url).pathname.split("/").pop();
        const blobs = fetch(url)
          .then((res) => res.blob())
          .then((blob) => [blob, fileName]);
        return blobs;
      })
    );

    blobs.map(([blob, fileName]) => {
      zip.file(fileName, blob);
    });

    zip.generateAsync({ type: "blob" }).then((zipFile) => {
      const currentDate = new Date().getTime();
      const fileName = `${type}-${currentDate}.zip`;
      return saveAs(zipFile, fileName);
    });
  }
```

## Reference

1. [https://huynvk.dev/blog/download-files-and-zip-them-in-your-browsers-using-javascript](https://huynvk.dev/blog/download-files-and-zip-them-in-your-browsers-using-javascript)

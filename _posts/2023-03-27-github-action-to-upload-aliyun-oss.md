---
layout: default
title: Github Action to upload Aliyun OSS
date: 2023-03-27 09:31 +0800
categories: github_action
---

通过Github Action上传OSS。需要注意的是`-r -f`需要写在末尾，否则会有一些莫可名状的行为。

Secret是设置在项目上面的。

```yaml
name: Upload to Ali OSS on Main Merge

on:
  push:
    branches:
      - main

jobs:
  upload-to-oss:
    runs-on: ubuntu-latest
    steps:
    - name: Checkout code
      uses: actions/checkout@v2

    - name: Install AWS CLI
      run: |
        sudo apt-get update
        sudo curl https://aliyuncli.alicdn.com/aliyun-cli-linux-latest-amd64.tgz -o aliyun-cli-linux-3.0.16-amd64.tgz
        sudo tar xzvf aliyun-cli-linux-3.0.16-amd64.tgz
        sudo cp aliyun /usr/local/bin
        
    - name: Upload to S3
      env:
        ACCESS_KEY_ID: ${{ secrets.ALI_ACCESS_KEY_ID }}
        SECRET_ACCESS_KEY: ${{ secrets.ALI_SECRET_ACCESS_KEY }}
        REGION: cn-beijing
      run: |
        aliyun oss cp ./{your_folder}/ oss://{bucket} -r -f
```
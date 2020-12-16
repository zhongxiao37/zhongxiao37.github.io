---
layout: default
title: Build Jenkins on Docker, install rvm and test pipeline
date: 2020-12-16 15:40 +0800
categories: docker, jenkins
---

原生的Jenkins镜像里面没有rvm，虽然说有rvm插件，但是依旧不好用，而且好几年没有maintain，也不知道现在还有人用没有。基于Jenkins的centos7镜像，安装rvm，并安装Ruby 2.6.6。版本号可以根据自己的需求改。

```bash
FROM jenkins/jenkins:2.270-centos7
ENV PATH $PATH:/usr/local/rvm/bin

USER root

# change default bash
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

# Install mysql client (no server)
RUN yum update -y \
  && yum install -y mysql mysql-devel \
  && yum clean all

# Download RVM as root
COPY rvm-installer.sh /
RUN bash rvm-installer.sh

# Install RVM requirements
RUN /bin/bash -lc "rvm requirements"

# Add jenkins to rvm group
RUN usermod -a -G rvm jenkins

# Use China mirror
RUN echo "ruby_url=https://cache.ruby-china.com/pub/ruby" > /usr/local/rvm/user/db
RUN rvm install 2.6.6
```

下面是docker-compose文件。networks不是必须的，但是我想隔离自己本地环境和jenkins相关的网络，就单独创建一个jenkins桥接网络。这样，jenkins和mysql_jenkins就可以互联了。

```yaml
version: '2'
services:
  jenkins:
    image: zhongxiao37/jenkins_rvm
    user: root
    environment:
      - DOCKER_TLS_CERTDIR=certs
    ports:
      - 8083:8080
      - 50003:50000
    volumes:
      - ./tmp/jenkins-docker-certs:/certs/client
      - ./tmp/jenkins-data:/var/jenkins_home
    networks:
      - jenkins

  mysql_jenkins:
    image: mysql:5.7
    restart: always
    environment:
      - MYSQL_ALLOW_EMPTY_PASSWORD=yes
    ports:
      - 3308:3306
    volumes:
      - ./tmp/mysql_jenkins:/var/lib/mysql
    networks:
      - jenkins

networks:
  jenkins:
```

运行docker-compose up jenkins，初始化Jenkins。在console里面你可以看到下面一段。

```txt
jenkins_1        | *************************************************************
jenkins_1        | *************************************************************
jenkins_1        | *************************************************************
jenkins_1        |
jenkins_1        | Jenkins initial setup is required. An admin user has been created and a password generated.
jenkins_1        | Please use the following password to proceed to installation:
jenkins_1        |
jenkins_1        | a7351aee503742ffbb1919dace8458d5
jenkins_1        |
jenkins_1        | This may also be found at: /var/jenkins_home/secrets/initialAdminPassword
jenkins_1        |
jenkins_1        | *************************************************************
jenkins_1        | *************************************************************
jenkins_1        | *************************************************************
```

把password复制下来，访问localhost:8083。

![img](/images/unlock_jenkins.png)

稍等一会儿，就可以开始了。随便选，失败也无所谓。

![img](/images/jenkins_get_started.png)

安装插件

![img](/images/installing_plugins.png)

创建用户

![img](/images/jenkins_create_admin.png)

配置镜像加速 https://mirrors.tuna.tsinghua.edu.cn/jenkins/updates/update-center.json

系统管理 - 管理插件 - 高级 - 升级站点

![img](/images/jenkins_update_center.png)

访问Github, Personal Settings, Developer Settings, Personal Access Token。勾选repo和admin:repo_hook，生成token。找个地方记录下来，后面再也不会显示了。

![img](/images/github_access_token.png)

回到Jenkins，创建一个pipeline job。

![img](/images/jenkins_create_a_job.png)

创建一个Credential，输入用户名和access token，就好了。

![img](/images/jenkins_access_token.png)

最后是创建Jenkinsfile。

```txt
pipeline {
  agent any

  stages {
    stage('Checkout') {
      steps {
        parallel (
          helloworld: {
            echo 'Hello World'
          },
          checkout: {
            echo "Checking out branch"
          } 
        )
      }
    }
  }
}
```


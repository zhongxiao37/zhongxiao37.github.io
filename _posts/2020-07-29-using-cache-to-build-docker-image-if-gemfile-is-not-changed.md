---
layout: default
title: Using cache to build docker image if Gemfile is not changed
date: 2020-07-29 08:47 +0800
categories: docker
---

如果Gemfile没有改动，我们可以使用warm cache，而不是每次都需要重新build。这里的一个trick就是需要先添加Gemfile，再`bundle install`, 而不是先`ADD . $APP_HOME`，再`bundle install`。因为通常代码会有改动，一旦有改动，docker就不会使用cache。这种方式在[这篇文章][docker_gemfile_cache]里面有详细介绍。

{% highlight docker %}
FROM ruby:2.5.7

RUN apt-get update -qq
RUN apt-get install -y build-essential nodejs net-tools freetds-bin freetds-dev

ENV APP_HOME /zhongyifunds
RUN mkdir -p $APP_HOME
WORKDIR $APP_HOME

ADD Gemfile* $APP_HOME/
RUN bundle install

ADD . $APP_HOME
{% endhighlight %}

另外一种策略就是用bundle自身的cache策略。使用`bundle install --local`就可以使用`vendor/cache`目录下面的gem，而不再需要从远程获取。[这里][bundle_cache]介绍了这种方法。


[docker_gemfile_cache]: http://ilikestuffblog.com/2014/01/06/how-to-skip-bundle-install-when-deploying-a-rails-app-to-docker/
[bundle_cache]: https://blog.bigbinary.com/2018/07/25/speeding-up-docker-image-build-process-of-a-rails-application.html
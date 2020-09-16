---
layout: default
title: Migrate from DelayedJob to Sidekiq
date: 2020-09-11 13:33 +0800
categories: rails sidekiq
---


## Steps

Update Gemfile

```ruby
gem 'delayed_job_active_record'
```

```ruby
gem 'sidekiq'
```

Change ActiveJob queue adapter in `config/application.rb`

```ruby
config.active_job.queue_adapter = :delayed_job
```

```ruby
config.active_job.queue_adapter = :sidekiq
```

Add `config/sidekiq.yml` file

```yml
:queues:
  - [default, 1]
  - [mailer, 5]
```

Configure routes.rb

```ruby
Rails.application.routes.draw do
  #...
  # sidekiq
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
end
```

## Add workers

Add two workers in `app/workers` directory.

```ruby
class MailerWorker
  include Sidekiq::Worker

  sidekiq_options :queue => :mailer

  def perform
    puts 'Running in MailerWorker'
  end
end
```

```ruby
class TestWorker
  include Sidekiq::Worker

  def perform
    puts 'Running in TestWorker'
  end
end
```

Call these two workers via `MailerWorker.perform_async` & `TestWorker.perform_async`. 这样，就可以有两个job，分别在两个queue里面。


## 启动 Sidekiq

Start `sidekiq` by running `sidekiq`.

## Check the Sidekiq webui

启动app以后，就可以通过[http://localhost:3000/sidekiq/][1]访问Sidekiq webui了。


## Check in console

```ruby
Sidekiq::Stats.new
 => #<Sidekiq::Stats:0x00007fa1518b1790 @stats={:processed=>5, :failed=>0, :scheduled_size=>0, :retry_size=>0, :dead_size=>0, :processes_size=>0, :default_queue_latency=>23.061033964157104, :workers_size=>0, :enqueued=>2}>
Sidekiq::Stats::History.new(2).processed
 => {"2020-09-11"=>5, "2020-09-10"=>0}
Sidekiq::Queue.all
 => [#<Sidekiq::Queue:0x00007fa14a6c1f68 @name="default", @rname="queue:default">, #<Sidekiq::Queue:0x00007fa14a6c1ea0 @name="mailer", @rname="queue:mailer">]
```

## Check Redis

进入Redis

```bash
redis-cli
```

列举所有的keys

```bash
127.0.0.1:6379> KEYS *
1) "stat:failed:2020-09-11"
2) "stat:failed"
3) "stat:processed:2020-09-11"
4) "queue:mailer"
5) "stat:processed"
6) "queue:default"
7) "queues"
```

其中`queues`是`Set`类型，里面包含了所有的queues。

```bash
127.0.0.1:6379> smembers queues
1) "default"
2) "mailer"
```

`queue:mailer`和`queue:default`是`List`类型，里面有所有enqueued的jobs。

```bash
127.0.0.1:6379> lrange queue:default 0 -1
1) "{\"retry\":true,\"queue\":\"default\",\"class\":\"TestWorker\",\"args\":[],\"jid\":\"881e52743188bd352b604d8c\",\"created_at\":1599802279.164949,\"enqueued_at\":1599802279.165004}"
2) "{\"retry\":true,\"queue\":\"default\",\"class\":\"TestWorker\",\"args\":[],\"jid\":\"595f08b0229eec7c1a211aa8\",\"created_at\":1599800764.4104939,\"enqueued_at\":1599800764.410542}"
```

可以访问[https://redis.io/commands][2]查看所有的`redis-cli` commands。


## Compared with DJ

DJ和Rails集成很好，一般开始阶段都会用DJ，加上本来Rails就会用数据库，所以DJ几乎不需要额外的工作。但是DJ没有一个WebUI，很多时候自己还需要build一个WebUI去查看当前队列里面有多少Job没有处理。在持久化上面，因为用的是数据库，所以不会有数据丢失。性能上比Sidekiq差。在自己的项目里面，我们有两个单独的server去跑DJ，速度还是很慢。

Sidekiq默认就有WebUI，直接就可以查看，很方便，少了额外的开发工作。加上背后用Redis，处理速度比DJ快了不少。此外还提供API。唯一的缺点就是因为用了Redis，可能会导致Job的丢失情况。大不了再跑一次Job就行了。

## Redis VS Memcahced

|   |Redis|Memcached|
|---|---|---|
|持久化|支持持久化|重启以后数据丢失|
|数据类型|多种数据类型|简单的Key-Value|
|数据清理|非临时数据不会被清理|根据LRU去清理数据|
|分布式|支持分布式存储|只能够通过一致性hash算法实现|

如果需要更多的数据类型，以及不要主动清理数据，可以用Redis。简单的缓存，用Memcache就足够了。



[1]: http://localhost:3000/sidekiq/
[2]: https://redis.io/commands

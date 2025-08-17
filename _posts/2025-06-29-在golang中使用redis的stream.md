---
layout: default
title: 在Golang中使用Redis的Stream
date: 2025-06-29 10:46 +0800
categories: redis
---

Reids 中有一个功能叫 Stream，可以实现类似于 Kafka 的功能，即消息可以持久化，有消费组且通过 ACK 确认消费成功。

快速写一段代码，创建一个 stream `my-stream` 和消费组 `my-group` 。然后消费组 `consumer-1` 就开始消费消息。

```go
package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/go-redis/redis/v8"
)

var (
	ctx        = context.Background()
	rdb        *redis.Client
	streamName = "my-stream"
	groupName  = "my-group"
)

func main() {
	rdb = redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})

	_, err := rdb.Ping(ctx).Result()
	if err != nil {
		log.Fatalf("Could not connect to Redis: %v", err)
	}

	// Create a consumer group. This will error if the group already exists,
	// but for this example, we'll ignore the error.
	rdb.XGroupCreateMkStream(ctx, streamName, groupName, "0").Err()

	var wg sync.WaitGroup
	wg.Add(1)

	go func() {
		defer wg.Done()
		consumer("consumer-1")
	}()

	wg.Wait()
}

func consumer(consumerName string) {
	for {
		streams, err := rdb.XReadGroup(ctx, &redis.XReadGroupArgs{
			Group:    groupName,
			Consumer: consumerName,
			Streams:  []string{streamName, ">"},
			Count:    1,
			Block:    0,
		}).Result()

		if err != nil {
			log.Printf("Error reading from stream: %v", err)
			continue
		}

		for _, stream := range streams {
			for _, message := range stream.Messages {
				fmt.Printf("Consumer %s received message: %v\n", consumerName, message.Values)
				// Acknowledge the message
				rdb.XAck(ctx, streamName, groupName, message.ID)
			}
		}
	}
}

```

通过 `redis-cli` `XADD my-stream '*' message "hello from cli"` 就可以往 stream 里面塞消息了。然后脚本里面的消费者就开始消费消息，并打印出日志。

通过 `XREADGROUP GROUP my-group consumer-checker COUNT 1000 STREAMS my-stream > ` 就可以查看 `my-stream` 里面有多少消息未被消费。

```bash
GROUP my-group consumer-checker: 我们以一个临时的消费者身份 consumer-checker (名字可以随便起) 来检查。
COUNT 1000: 我们尝试一次性读取最多 1000 条新消息 (可以设一个较大的数字确保能读完)。
STREAMS my-stream >: 这是关键，我们只读取 my-stream 中所有的新消息。
```

通过 `XPENDING my-stream my-group` 可以查看有多少消息是已读未回。

通过 `XINFO GROUPS my-stream` 查看所有的消费组以及消费的堆积量。

```bash
1)  1) "name"                 # 字段名: 消费组名称
    2) "my-group"             # 字段值: "my-group"

    3) "consumers"            # 字段名: 消费者数量
    4) (integer) 2             # 字段值: 组内有 2 个活动的消费者 (比如 go 程序里的 consumer-1 和我们 cli 里的 consumer-cli)

    5) "pending"              # 字段名: 待处理消息数
    6) (integer) 0             # 字段值: 有 0 条消息被投递但未确认 (XACK)

    7) "last-delivered-id"    # 字段名: 最后投递的 ID  <-- 这就是你想要的“偏移量”！
    8) "1754186688588-0"      # 字段值: 这是被投递到本组的最后一个消息的 ID

    9) "entries-read"         # 字段名: 已读取的条目总数 (较新版 Redis 提供)
   10) (integer) 7             # 字段值: 组内的消费者总共从流中读取了 7 个条目

   11) "lag"                  # 字段名: 积压量 (较新版 Redis 提供)
   12) (integer) 0             # 字段值: 有 0 条新消息在本组最后投递 ID 之后，等待被消费
```

通过 `XRANGE my-stream - +` 可以查看到 Stream 里面的所有未消费的信息。

如果有消息未回，这些消息会进入 PENDING 列表，可以通过 `redis-cli XPENDING my-stream my-group - + 100` 进行查看。

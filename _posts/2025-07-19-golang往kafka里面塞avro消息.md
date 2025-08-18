---
layout: default
title: Golang往Kafka里面塞Avro消息
date: 2025-08-18 13:41 +0800
categories: golang kafka
---

项目用到了 Kafka，我想要一个定时任务，往 Kafka 里面塞 Avro 格式的消息。

首先，定义一下配置和数据类型

```golang
type bizEvent struct {
	EventId   string    `avro:"eventId"`
	BizType   string    `avro:"bizType"`
	Payload   string    `avro:"payload"`
	EventTime time.Time `avro:"eventTime"`
}

type inviteRegistrationEvent struct {
	UserId int64 `json:"userId"`
}

// --------------------- 运行时配置 -------------------------

type cfg struct {
	pgURL                  string
	databaseUsername       string
	databasePassword       string
	kafkaBroker            string
	kafkaUsername          string
	kafkaPassword          string
	kafkaSecurityProtocol  string
	schemaRegistryUsername string
	schemaRegistryPassword string
	topic                  string
	schemaRegistry         string
	userQuery              string
}
```

然后从环境变量或者.env 文件从读取环境变量

```golang

func loadCfg() cfg {
	// Initialize Viper to read from .env (if present) and environment variables
	viper.SetConfigFile(".env")
	viper.SetConfigType("env") // Treat .env as simple KEY=VALUE
	viper.AutomaticEnv()       // Override with real environment variables if set
	if err := viper.ReadInConfig(); err != nil {
		log.Printf("Warning: unable to read .env file (it may be absent): %v", err)
	}

	return cfg{
		pgURL:                  getenv("DATABASE_URL", ""),
		databaseUsername:       getenv("DATABASE_USERNAME", ""),
		databasePassword:       getenv("DATABASE_PASSWORD", ""),
		kafkaBroker:            getenv("KAFKA_SERVER", ""),
		kafkaUsername:          getenv("KAFKA_USERNAME", ""),
		kafkaPassword:          getenv("KAFKA_PASSWORD", ""),
		kafkaSecurityProtocol:  getenv("KAFKA_SECURITY_PROTOCOL", ""),
		schemaRegistryUsername: getenv("KAFKA_USERNAME", ""),
		schemaRegistryPassword: getenv("KAFKA_PASSWORD", ""),
		topic:                  getenv("KAFKA_BIZ_EVENT_TOPIC", ""),
		schemaRegistry:         getenv("KAFKA_SCHEMA_REGISTRY_URL", ""),
		userQuery:            getenv("USER_QUERY", `SELECT id FROM users`),
	}
}

```

接着就是连接 Postgres 数据库，查询需要处理的 userId.

```golang
cfg := loadCfg()
	ctx := context.Background()

	log.Printf("cfg: %+v\n", cfg)

	// format the pg url from jdbc format to postgres:
	cfg.pgURL = strings.Replace(cfg.pgURL, "jdbc:postgresql://", fmt.Sprintf("postgres://%s:%s@", cfg.databaseUsername, cfg.databasePassword), 1)

	// 1. 打开数据库
	db, err := sql.Open("pgx", cfg.pgURL)
	must(err)
	defer db.Close()

	rows, err := db.QueryContext(ctx, cfg.userQuery)
	must(err)
	defer rows.Close()

	var userIDs []int64
	for rows.Next() {
		var id int64
		must(rows.Scan(&id))
		userIDs = append(userIDs, id)
	}
	must(rows.Err())

	log.Printf("Fetched %d user ids\n", len(userIDs))
```

从 Schema registry 里面获取 Schema 的信息

```golang
insecureHTTPClient := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true}, // nolint:gosec
		},
	}

	sr := srclient.NewSchemaRegistryClient(cfg.schemaRegistry, srclient.WithClient(insecureHTTPClient))
	if cfg.schemaRegistryUsername != "" {
		// Different versions of srclient have either SetCredentials or SetBasicAuth.
		type authWithCredentials interface {
			SetCredentials(string, string)
		}
		type authWithBasicAuth interface {
			SetBasicAuth(string, string)
		}
		switch v := interface{}(sr).(type) {
		case authWithCredentials:
			v.SetCredentials(cfg.schemaRegistryUsername, cfg.schemaRegistryPassword)
		case authWithBasicAuth:
			v.SetBasicAuth(cfg.schemaRegistryUsername, cfg.schemaRegistryPassword)
		default:
			log.Println("Warning: srclient does not support basic auth methods; proceeding without authentication")
		}
	}

	subject := fmt.Sprintf("%s-value", cfg.topic)
	schema, err := sr.GetLatestSchema(subject)
	must(err)

	codec, err := avro.Parse(schema.Schema())
	must(err)
```

接下来就是组装 Payload，往 Kafka 里面发送消息了。

```golang
prod, err := kafka.NewProducer(&kafka.ConfigMap{
		"bootstrap.servers": cfg.kafkaBroker,
		"security.protocol": cfg.kafkaSecurityProtocol,
		"sasl.mechanisms":   "PLAIN",
		"sasl.username":     cfg.kafkaUsername,
		"sasl.password":     cfg.kafkaPassword,
		"ssl.ca.location":   "/etc/ssl/certs",
		"acks":              "all",
	})
	must(err)
	defer prod.Close()

	// 4. 逐条发送
	for _, uid := range userIDs {
		payloadObj := inviteRegistrationEvent{UserId: uid}
		payloadBytes, _ := json.Marshal(payloadObj)

		event := bizEvent{
			EventId:   uuid.New().String(),
			BizType:   "TEST_EVENT_TYPE",
			Payload:   string(payloadBytes),
			EventTime: time.Now(),
		}

		// Avro 编码
		avroBytes, err := avro.Marshal(codec, event)
		must(err)

		// Confluent wire-format 构造
		value := make([]byte, 1+4+len(avroBytes))
		value[0] = 0 // magic-byte
		binary.BigEndian.PutUint32(value[1:], uint32(schema.ID()))
		copy(value[5:], avroBytes)

		// 发送
		deliveryChan := make(chan kafka.Event, 1)
		err = prod.Produce(&kafka.Message{
			TopicPartition: kafka.TopicPartition{Topic: &cfg.topic, Partition: kafka.PartitionAny},
			Key:            []byte(fmt.Sprint(uid)),
			Value:          value,
		}, deliveryChan)
		must(err)

		// 同步等待结果（也可以批量异步）
		e := <-deliveryChan
		m := e.(*kafka.Message)
		if m.TopicPartition.Error != nil {
			log.Fatalf("Delivery failed: %v\n", m.TopicPartition.Error)
		} else {
			log.Printf("Delivered to %v [offset %d]\n", m.TopicPartition, m.TopicPartition.Offset)
		}
		close(deliveryChan)

		time.Sleep(time.Duration(cfg.sendIntervalMs) * time.Millisecond)
	}

	log.Println("All messages delivered, flushing …")
	prod.Flush(10_000)
}

```

最后再打一个 Docker 镜像

```dockerfile
# syntax=docker/dockerfile:1

# ---------- Builder stage ----------
FROM golang:1.24.5-bookworm AS builder

# Enable CGO (required by confluent-kafka-go) and set target platform
ENV CGO_ENABLED=1 GOOS=linux GOARCH=amd64

# Install build dependencies and librdkafka for confluent-kafka-go
RUN apt-get update && apt-get install -y gcc g++ librdkafka-dev pkgconf git

# Create and set working directory
WORKDIR /app

# Copy go.mod and go.sum first to leverage Docker layer caching
COPY go.mod go.sum ./
RUN go mod download

# Copy the rest of the source code
COPY test_kafka_avro.go ./

# Build the test_kafka_avro binary
RUN go build -o test_kafka_avro test_kafka_avro.go

# ---------- Runtime stage ----------
FROM debian:bookworm-slim AS runtime

# Install CA certificates for TLS connections used by librdkafka
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && rm -rf /var/lib/apt/lists/*

# Install tzdata if timezone support is needed (optional)
# RUN apk --no-cache add tzdata

WORKDIR /app

# Copy binary from the builder stage
COPY --from=builder /app/test_kafka_avro ./

# Expose any ports if the application listens on them (none in this case)

# Set executable permissions (usually already executable, but ensure)
RUN chmod +x /app/test_kafka_avro

# Define entrypoint
ENTRYPOINT ["/app/test_kafka_avro"]

```

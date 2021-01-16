---
layout: default
title: memcached
date: 2021-01-16 12:05 +0800
categories: memcached
---


## Docker-compose

通过docker来安装memcached。下面是docker-compose.yml文件。

```yml
version: '2'
services:
  cache:
    image: memcached:1.6.9
    expose:
      - 11211
    ports:
      - 11211:11211
```

然后直接启动即可使用

```bash
docker-compose up -d cache
```

## Telnet

### 连接

```bash
telnet localhost 11211
```

### Set

比较恶心的是，设置的bytes要和输入的value长度一致，否则存不进去。

```bash
set key flags exptime bytes 
value
```

```bash
set k 0 0 26
abcdefJJ2yG206gwh77nDyjE8d
```

### Get


```bash
get k
```

会输出

```bash
abcdefJJ2yG206gwh77nDyjE8d
```


### Flush all

清楚所有字段

```bash
flush_all
```

### 退出

```bash
quit
```


## Ruby

通过Ruby连接memcached

```ruby
require 'net/telnet'
telnet = Net::Telnet.new("Host" => '127.0.0.1' ,
  "Port" => "11211",
  "Timeout" => 10,
  "Prompt" => /.*/)

telnet.cmd("flush_all")
telnet.close
```

### 打印所有的key

```ruby
require 'net/telnet'
require 'csv'

headings = %w(id expires bytes key)
rows = []

host = '127.0.0.1'
port = 11211
dump_file = "memcache_dump_#{Time.now.strftime('%Y-%m-%d_%H%M%S')}.csv"

connection = Net::Telnet::new("Host" => host, "Port" => port, "Timeout" => 3)
matches = connection.cmd("String" => "stats items", "Match" => /^END/).scan(/STAT items:(\d+):number (\d+)/)

p matches

slabs = matches.inject([]) { |items, item| items << Hash[*['id','items'].zip(item).flatten]; items }
longest_key_len = 0

p slabs

CSV.open(dump_file, "w") do |csv|
  csv << headings
  slabs.each do |slab|
    connection.cmd("String" => "stats cachedump #{slab['id']} #{slab['items']}", "Match" => /^END/) do |c|
      matches = c.scan(/^ITEM (.+?) \[(\d+) b; (\d+) s\]$/).each do |key_data|
        cache_key, bytes, expires_time = key_data
        csv << [slab['id'], Time.at(expires_time.to_i), bytes, cache_key]
        rows << [slab['id'], Time.at(expires_time.to_i), bytes, cache_key]
        longest_key_len = [longest_key_len,cache_key.length].max
      end
    end
  end

end

row_format = %Q(|%8s | %28s | %12s | %-#{longest_key_len}s |)
puts row_format%headings
rows.each{|row| puts row_format%row}

puts "\n############# successfully dumped in #{dump_file} ##############"
connection.close
```

### 用Dalli

```ruby
require 'dalli'
options = { :namespace => "app_v1", :compress => true }
dc = Dalli::Client.new('localhost:11211', options)
dc.set('abc', 123)
value = dc.get('abc')

dc.stats
dc.stats(:items)
dc.flush_all
```





---
layout: default
title: ActiveRecord Cache
date: 2021-07-22 14:04 +0800
categories: rails activerecord cache
---

## ActiveRecord Cache

ActiveRecord有两种Cache，一种是relation cache，一般通过`reload`可以实现DB hit。另外一种是sql cache，这个就需要用一个block去避免。

```ruby
Post.uncached do
  Post.all.to_a
end
```

1. [https://www.honeybadger.io/blog/rails-activerecord-caching/](https://www.honeybadger.io/blog/rails-activerecord-caching/)

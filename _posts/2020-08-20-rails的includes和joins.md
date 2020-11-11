---
layout: default
title: Rails的includes和joins
date: 2020-08-20 12:06 +0800
categories: rails
---

很老的话题了，再看看Rails 5.2中的behavior吧。

### joins

会导致N+1问题，即针对每一条fund的fund_price_histories，会触发额外的query加载所有记录。用`joins`只会对`Fund`做过滤，不会加载关联数据。

```ruby
funds = Fund.joins(:fund_price_histories).where(fund_price_histories: {cal_date: '2020-07-08'})
```

```bash
Fund Load (8.9ms)  EXEC sp_executesql N'SELECT  [funds].* FROM [funds] INNER JOIN [fund_price_histories] ON [fund_price_histories].[fund_id] = [funds].[id] WHERE [fund_price_histories].[cal_date] = @0  ORDER BY [funds].[id] ASC OFFSET 0 ROWS FETCH NEXT @1 ROWS ONLY', N'@0 datetime, @1 int', @0 = '07-08-2020 00:00:00.0', @1 = 11  [["cal_date", nil], ["LIMIT", nil]]
```

继续执行

```ruby
funds.first.fund_bonus_histories
```

会触发sql去加载关联数据。

```bash
FundBonusHistory Load (19.1ms)  EXEC sp_executesql N'SELECT  [fund_bonus_histories].* FROM [fund_bonus_histories] WHERE [fund_bonus_histories].[fund_id] = @0  ORDER BY [fund_bonus_histories].[id] ASC OFFSET 0 ROWS FETCH NEXT @1 ROWS ONLY', N'@0 int, @1 int', @0 = 1, @1 = 11  [["fund_id", nil], ["LIMIT", nil]]
```

## includes

会加载关联数据，并放入memory中。会自动判断是用`preload`还是`eager_load`两种方式。`preload`默认用一个QUERY取得所有数据，再派发另外一个QUERY去加载关联数据。`eager_load`会用一个`LEFT JOIN`去加载数据以及关联数据。

```ruby
funds = Fund.includes(:fund_price_histories).where(fund_price_histories: {cal_date: '2020-07-08'})
```

```bash
SQL (6.5ms)  EXEC sp_executesql N'SELECT  DISTINCT [funds].[id] FROM [funds] LEFT OUTER JOIN [fund_price_histories] ON [fund_price_histories].[fund_id] = [funds].[id] WHERE [fund_price_histories].[cal_date] = @0  ORDER BY [funds].[id] ASC OFFSET 0 ROWS FETCH NEXT @1 ROWS ONLY', N'@0 datetime, @1 int', @0 = '07-08-2020 00:00:00.0', @1 = 11  [["cal_date", nil], ["LIMIT", nil]]

SQL (10.4ms)  EXEC sp_executesql N'SELECT [funds].[id] AS t0_r0, [funds].[name] AS t0_r1, [funds].[number] AS t0_r2, [funds].[risk] AS t0_r3, [funds].[star] AS t0_r4, [funds].[unit_price] AS t0_r5, [funds].[change_rate] AS t0_r6, [funds].[acc_price] AS t0_r7, [funds].[fund_size] AS t0_r8, [funds].[agency] AS t0_r9, [funds].[manager] AS t0_r10, [funds].[creation_dt] AS t0_r11, [funds].[flags] AS t0_r12, [funds].[deleted] AS t0_r13, [funds].[created_at] AS t0_r14, [funds].[updated_at] AS t0_r15, [funds].[fee_setting_id] AS t0_r16, [fund_price_histories].[id] AS t1_r0, [fund_price_histories].[fund_id] AS t1_r1, [fund_price_histories].[cal_date] AS t1_r2, [fund_price_histories].[unit_price] AS t1_r3, [fund_price_histories].[acc_price] AS t1_r4, [fund_price_histories].[rate] AS t1_r5, [fund_price_histories].[created_at] AS t1_r6, [fund_price_histories].[updated_at] AS t1_r7 FROM [funds] LEFT OUTER JOIN [fund_price_histories] ON [fund_price_histories].[fund_id] = [funds].[id] WHERE [fund_price_histories].[cal_date] = @0 AND [funds].[id] IN (@1, @2, @3, @4, @5)', N'@0 datetime, @1 bigint, @2 bigint, @3 bigint, @4 bigint, @5 bigint', @0 = '07-08-2020 00:00:00.0', @1 = 1, @2 = 2, @3 = 3, @4 = 4, @5 = 5  [["cal_date", nil], ["id", nil], ["id", nil], ["id", nil], ["id", nil], ["id", nil]]
```

因为放到内存中了，下面的语句不会触发额外的query，只会查找`cal_date`是`2020-07-08`的记录。

```ruby
funds.each { |f| p f.fund_price_histories }
```

```ruby
#<ActiveRecord::Associations::CollectionProxy [#<FundPriceHistory id: 2562, fund_id: 1, cal_date: "2020-07-08 00:00:00", unit_price: 0.783e0, acc_price: 0.5773e1, rate: 0.182e1, created_at: "2020-07-28 13:39:29", updated_at: "2020-07-28 13:39:29">]>
#<ActiveRecord::Associations::CollectionProxy [#<FundPriceHistory id: 5138, fund_id: 2, cal_date: "2020-07-08 00:00:00", unit_price: 0.1799e1, acc_price: 0.28361e1, rate: 0.135e1, created_at: "2020-07-29 10:21:05", updated_at: "2020-07-29 10:21:05">]>
#<ActiveRecord::Associations::CollectionProxy [#<FundPriceHistory id: 6974, fund_id: 3, cal_date: "2020-07-08 00:00:00", unit_price: 0.1996e1, acc_price: 0.3468e1, rate: 0.158e1, created_at: "2020-07-29 12:48:24", updated_at: "2020-07-29 12:48:24">]>
#<ActiveRecord::Associations::CollectionProxy [#<FundPriceHistory id: 9552, fund_id: 4, cal_date: "2020-07-08 00:00:00", unit_price: 0.9523e0, acc_price: 0.106954e2, rate: 0.22e1, created_at: "2020-07-29 14:21:34", updated_at: "2020-07-29 14:21:34">]>
#<ActiveRecord::Associations::CollectionProxy [#<FundPriceHistory id: 12128, fund_id: 5, cal_date: "2020-07-08 00:00:00", unit_price: 0.65485e1, acc_price: 0.74385e1, rate: -0.27e0, created_at: "2020-07-30 06:33:52", updated_at: "2020-07-30 06:33:52">]>
```

就不能够一次性查到需要的数据么？试图用`eager_load`可以合并成一个query。

```ruby
Fund.includes(:fund_price_histories).references(:fund_price_histories).where(fund_price_histories: {cal_date: '2020-07-08'}).to_sql
```

```ruby
Fund.includes(:fund_price_histories).references(:fund_price_histories).to_sql
```

```ruby
Fund.eager_load(:fund_price_histories).to_sql
```


[1]: http://www.arkhitech.com/services/rails-joins-preload-eager-load-and-includes/
---
layout: default
title: Scope in Rails
date: 2020-09-08 15:21 +0800
categories: scope
---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [ActiveRecord::Relation](#activerecordrelation)
- [#all](#all)
- [default_scope](#default_scope)
- [#scope 方法](#scope-%E6%96%B9%E6%B3%95)
  - [对new、create的影响](#%E5%AF%B9newcreate%E7%9A%84%E5%BD%B1%E5%93%8D)
- [链式scope](#%E9%93%BE%E5%BC%8Fscope)
  - [generate_relation_method](#generate_relation_method)
- [传入参数](#%E4%BC%A0%E5%85%A5%E5%8F%82%E6%95%B0)
- [Reference](#reference)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

Rails的ActiveRecord中有一个非常重要的模块，就是`Scope`。

## ActiveRecord::Relation

Rails中，`where`返回的对象其实是ActiveRecord::Relation.


```bash
Fund.where(deleted: false).class
  SQL (2.4ms)  USE [zhongyifunds_development]
 => Fund::ActiveRecord_Relation
```

有趣的是，许多类方法实际上都是delegate给`all`了。

```ruby
module ActiveRecord
  module Querying

    delegate :select, :group, :order, :except, :reorder, :limit, :offset, :joins, :left_joins, :left_outer_joins, :or,
             :where, :rewhere, :preload, :eager_load, :includes, :from, :lock, :readonly, :extending,
             :having, :create_with, :distinct, :references, :none, :unscope, :merge, to: :all
```

所以，下面几个都是等效的：

```ruby
Fund.all.where(deleted: false)
Fund.where(deleted: false)
```

## #all

下面的`all`方法的定义。

如果`current_scope`为空，就返回`default_scoped`，否则就是`current_scope`的clone。

```ruby

module ActiveRecord
  module Scoping
    module Named

      module ClassMethods

        def all
          current_scope = self.current_scope

          if current_scope
            if self == current_scope.klass
              current_scope.clone
            else
              relation.merge!(current_scope)
            end
          else
            default_scoped
          end
        end
```

`current_scope`位于线程变量`ScopeRegistry`中，其实相当于查询上下文。

```ruby

def current_scope(skip_inherited_scope = false)
  ScopeRegistry.value_for(:current_scope, self, skip_inherited_scope)
end

def current_scope=(scope)
  ScopeRegistry.set_value_for(:current_scope, self, scope)
end

```

## default_scope

在第一次执行的时候，`current_scope`肯定为空，返回`default_scoped`。`default_scoped`第一次会build_default_scope，会查询`default_scopes`是否为空。不为空，就返回该scope。

```ruby

def default_scoped(scope = relation) # :nodoc:
  build_default_scope(scope) || scope
end

def build_default_scope(base_rel = nil)
  #...

  if default_scope_override
    #...
  elsif default_scopes.any?
    base_rel ||= relation
    evaluate_default_scope do
      default_scopes.inject(base_rel) do |default_scope, scope|
        scope = scope.respond_to?(:to_proc) ? scope : scope.method(:call)
        default_scope.merge!(base_rel.instance_exec(&scope))
      end
    end
  end
end
```

所以, `default_scope`方法就比较简单，就是单纯往`default_scopes`里面存入当前scope就行了。

```ruby

def default_scope(scope = nil, &block) # :doc:
  scope = block if block_given?
  #...
  self.default_scopes += [scope]
end
```

此外，这个default会影响新建的实例，即`Fund.new`创建的实例`deleted`为`false`。如果是软删除，可以用这种方法，这样新建的就默认是未删除的。

```ruby
class Fund < ApplicationRecord
  default_scope { where deleted: false }
end
```


## #scope 方法

看完default_scope，来看看scope。scope传入的body要求是callable的，即可以是一个拥有#call方法的Module，或者代码块。比如这里是代码块，支持`to_proc`，就在Fund的单件类上面创建了一个`active`的方法。和`where`一样，是建立在`all`的基础上。


```ruby
class Fund < ApplicationRecord
  scope :active, -> { where(deleted: false) }
end
```

```ruby
def scope(name, body, &block)
  #...
  extension = Module.new(&block) if block

  if body.respond_to?(:to_proc)
    singleton_class.send(:define_method, name) do |*args|
      scope = all
      scope = scope._exec_scope(*args, &body)
      scope = scope.extending(extension) if extension
      scope
    end
  else
    singleton_class.send(:define_method, name) do |*args|
      scope = all
      scope = scope.scoping { body.call(*args) || scope }
      scope = scope.extending(extension) if extension
      scope
    end
  end

  generate_relation_method(name)
end
```

`scoping`会存储当前上下文的current_scope，执行完成以后再恢复。
`_exec_scope`就直接执行block，不再存储current_scope。

```ruby
def scoping
  previous, klass.current_scope = klass.current_scope(true), self unless @delegate_to_klass
  yield
ensure
  klass.current_scope = previous unless @delegate_to_klass
end

def _exec_scope(*args, &block) # :nodoc:
  @delegate_to_klass = true
  instance_exec(*args, &block) || self
ensure
  @delegate_to_klass = false
end
```

### 对new、create的影响

和default_scope一样，也会对new和create有影响。

```ruby
Fund.active.new.deleted => false
```

## 链式scope

正是因为`scope`方法返回的是Relation，这样可以实现链式scope，即多个scope可以串在一起使用。虽然说，scope生成的方法，类似于类方法。下面的方式也可以支持链式，只是通过method_missing这种钩子方法来实现的。

```ruby
class Fund < ApplicationRecord
  def self.active
    where(deleted: false)
  end

  def self.inactive
    where(deleted: true)
  end
end
```

### generate_relation_method

Rails 5.2.4 中比 5.1 多了`generate_relation_method`，从名字上可以看出实际上就是给Relation上生成方法。其实注释掉这个方法也是可以的，只是这样就会走method_missing那种方式，这样非常不利于debug。所以这里显式的定义方法，这样`Fund.active.method(:base).source_location`就可以找到方法的定义了。


## 传入参数

如下例中，lambda中传入`time`参数。

```ruby
scope :created_before, ->(time) { where("created_at < ?", time) }
```

## callable Module

[http://craftingruby.com/posts/2015/06/29/query-objects-through-scopes.html][2] 中创建了一个拥有call方法的Module来自定义scope。


## Reference

1. [https://draveness.me/activerecord/][1]


[1]: https://draveness.me/activerecord/
[2]: http://craftingruby.com/posts/2015/06/29/query-objects-through-scopes.html

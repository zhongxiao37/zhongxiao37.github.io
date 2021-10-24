---
layout: default
title: 'Ruby: #dup vs #clone'
date: 2021-10-24 22:11 +0800
categories: ruby
---

Ruby中`dup`和`clone`的区别只有一点，即`clone`会复制singleton class和维持fronze状态。其实`clone`是原对象的一个复制，而`dup`是通过原对象的类重新创建出来的一个新的对象。


[https://gist.github.com/ysorigin/3247021](https://gist.github.com/ysorigin/3247021)


```ruby
#clone do two more things when create a shallow copy of an object than #dup


## 1.copy the singleton class of the copied object

#dup
a = Object.new
def a.foo; :foo end
p a.foo
# => :foo
b = a.dup
p b.foo
# => undefined method `foo' for #<Object:0x007f8bc395ff00> (NoMethodError)

#clone
a = Object.new
def a.foo; :foo end
p a.foo
# => :foo
b = a.clone
p b.foo
# => :foo

## 2.maintain the frozen status of the copied object
a = Object.new
a.freeze
p a.frozen?
# => true
b = a.dup
p b.frozen?
# => false
c = a.clone
p c.frozen?
# => true
```
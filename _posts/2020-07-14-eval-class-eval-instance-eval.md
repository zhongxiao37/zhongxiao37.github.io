---
layout: post
title: 从eval, class_eval, instance_eval 和 singleton_class 说起
date: 2020-07-14 00:00:00 +0800
categories: ruby
---

最近在刷 CodeWar，整理来说，比 exercism.io 难多了。因为选择的是快速升级，所以没有刷几道题，难度就蹭蹭蹭地往上窜，有时候发现之前一晃而过的地方，啪啪地被打脸，原来真的就是一晃而过。

### eval

```ruby
class A
  attr_reader :x

  def initialize(x)
    @x = x
  end

  def get_binding
    binding
  end
end

a = A.new(1)
b = A.new(2)

eval 'p @x', a.get_binding
eval 'p @x', b.get_binding
```

我们可以用 `eval str, binding` 这种方式，执行一段字符串，同时切换上下文 context。我们还可以用 `instance_eval` 来实现达到同样的目的。

### instance_eval

```ruby
class A
  attr_reader :x

  def initialize(x)
    @x = x
  end

  def get_binding
    binding
  end
end

a = A.new(1)
b = A.new(2)

a.instance_eval 'p @x'
b.instance_eval 'p @x'
```

`instance_eval` 还可以执行代码块。

```ruby
p a.instance_eval { @x }
p b.instance_eval { @x }
```

还可以单独给实例创建方法，这个方法不在 class 上，反而是在 singleton_class 上。同样的逻辑，我们也可以给 class 上执行 instance_eval，这样创建的就是 class method 了。

```ruby
a.instance_eval do
  def speak
    puts 'ya ya ya!'
  end
end

a.speak

b.instance_eval do
  def speak
    puts 'bia bia bia!'
  end
end

b.speak

p a.methods # => [:speak, :x, :get_binding, ...]
p a.class.instance_methods(false) # => [:x, :get_binding]
p a.singleton_class.instance_methods(false) # => [:speak]
```

### class_eval

相当比较简单，只能够在 class 上面执行 class_eval, 创建出来的实例方法。比如在 [yield](http://zhongxiao37.blogspot.com/2020/06/yield.html) 中，将 yield 换成 class_eval，context 就变成了 class，而不再是 main 了。

### instance_exec & class_exec

`instance_exec` 和 `class_exec` 相比 `_eval`，多了可以传入参数的功能。可以参考 [The difference between instance_eval and instance_exec](https://www.saturnflyer.com/blog/the-difference-between-instanceeval-and-instanceexec)

比如下面这个例子，如果不需要考虑引用实例的方法，变量，用 yield 就行了。

```ruby
class C
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def build(m, &block)
    self.singleton_class.define_method(m) do |v|
      yield v
    end
    self
  end
end

a = C.new('jack').build(:speak) do |word|
  "says #{word}"
end
b = C.new('jane').build(:speak) do |word|
  "yells #{word}"
end

p a.speak('hello')
p b.speak('bye')
```

如果还需要用到实例自己的方法，变量，比如这里的 name，那就需要用 `instance_exec`，第一个 v 其实就是 speak 传入的参数，进而在传入 block 的 word 变量。

```ruby
class B
  attr_reader :name

  def initialize(name)
    @name = name
  end

  def build(m, &block)
    self.singleton_class.define_method(m) do |v|
      instance_exec v, &block
    end
    self
  end
end

a = B.new('jack').build(:speak) do |word|
  "#{name} says #{word}"
end
b = B.new('jane').build(:speak) do |word|
  "#{name} yells #{word}"
end

p a.speak('hello')
p b.speak('bye')
```

### extend

还有另外一种方法去扩展实例方法，即 extend。像下面这种方法，实际上也会在 singleton_class 上面创建实例方法。这里需要注意的是，用到了 instance_eval，这样的话，最后一段就不需要像其他 each 方法一样，还要写 `{|e| puts e.name}`，自动绑定到每个元素上执行了。

```ruby
module InstanceEach
  def each(&block)
    self.size.times { |i| self[i].instance_eval &block }
    self
  end
end

t = Array.new(@cnt) { A.new('') }.extend(InstanceEach)

t.each { puts name }
```

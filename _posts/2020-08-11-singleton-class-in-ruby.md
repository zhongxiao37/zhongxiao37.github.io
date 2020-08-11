---
layout: default
title: singleton_class in Ruby
date: 2020-08-11 13:46 +0800
categories: ruby
---

### Singleton Class 元类
元类其实也是一个Class，在《Ruby原理剖析》里面，元类和类的关系如下图。

![img](/images/singleton_class.png)

实例`euler`，可以通过`class`得到它对应的类`Mathematician`。`Mathematician`可以通过`superclass`找到父类，也可以通过`singleton_class`找到元类。实例方法是在`superclass`这个继承链中查找的，类方法是在`singleton_class`这条继承链中查找的。

下图是《Ruby元编程》中描述的方法查找过程。

![img](/images/class_method_research.png)

感觉学习Ruby，只需要看完这两本书，就对Ruby有非常深的理解了。
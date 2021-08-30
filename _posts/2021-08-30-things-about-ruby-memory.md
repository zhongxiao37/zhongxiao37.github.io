---
layout: default
title: Things about Ruby Memory
date: 2021-08-30 22:31 +0800
categories: ruby
---

## 从Ruby的内存碎片化说起

Ruby的栈空间是当前运行栈的RVALUE的指针和值，而Heap里面存放的就是RAVLUE的值了。Ruby启动时会向系统通过malloc申请一片内存，即malloc heap。OS heap又会被划分一部分给Ruby成为Ruby heap。一个ruby heap page大概是16KB，拥有408个slots。每个slot保存一个RVALUE的值，大小固定为40 bytes（根据操作系统而不同）。Aaron Patterson在一个[视频][aaron_patterson]里面介绍了这部分知识。

![img](/images/ruby_heap.png)

Ruby heap的fragmentation是一个一直存在的问题，据说是所有动态语言都会有的问题。简单来说，就是GC回收释放的空间不够新的对象，导致Ruby继续向操作系统申请内存。在Rails里面，内存一般像一个log函数一样，刚开始涨得很快，因为需要require一堆公用包，后面就慢慢变缓了。

![img](/images/ruby_heap_memory_grows.png)

Aaron Patterson 用磁盘碎片整理的图片来介绍Heap的碎片化，就非常形象了。其实内存的随机读是很快的，Ruby 2.7里面引入GC compact其实单纯是为了Memory不至于涨得那么多。

![img](/images/hard_disk_defrag.png)

此外，Fragmentation不仅仅发生在Ruby heap上，同时也会发生在malloc heap上。对于malloc heap，Facebook开发了一个叫jmalloc heap的工具来解决/缓解这样的问题。对于ruby heap，目前看来只能够通过Ruby 2.7以上的版本来解决。同时他也展示了GC前后的对比。其中白色是free space，黑色是被占用的，红色是不可以挪动的。

![img](/images/rails_heap_memory_without_gc_compact.png)
![img](/images/rails_heap_memory_with_gc_compact.png)


## 分析Heap dump

除了依赖GC compact之位，有些问题是可以通过分析heap dump来解决的。Frederick Cheung介绍了通过`rbtrace`和`heapy`来分析heap dump[视频][frederick_cheung_1][文章][frederick_cheung_2]。不过分析起来 *颇为* *相当* *非常* 麻烦。

1. 你需要在你的项目里面引入`rbtrace`并且`require 'rbtrace'`。当然你也可以通过路由来开启`require 'rbtrace'`
2. 你需要开启`trace_object_allocations_start`
3. 接下来你就可以在production操作了。编写一段ruby code，然后执行这段ruby代码`bundle exec rbtrace --pid 1 -e 'load("tmp/rbcode.rb")'`，就可以生成heap dump文件了。
```ruby
Thread.new{GC.start;require "objspace";io=File.open("tmp/ruby-heap.dump", "w"); ObjectSpace.dump_all(output: io); io.close}
```
4. 然后就可以通过`heapy read tmp/ruby-heap.dump`来分析heap memory的使用情况。Richard Scheneeman也是通过`heapy`找到rails的一个issue。

### 案例

[1][richard_schneeman_1]
[2][richard_schneeman_2]
[3](https://www.tefter.io/bookmarks/42241/readable)

内存问题，既有memory leak，也有fragmentation。
在Ruby里面更多的是内存碎片化，both ruby heap and malloc heap。
而在Rails里面，没有深刻地领悟Rails的工作原理和lifecycle，很随意就可能导致leak了。


## 只有Heap memory有问题？

如果去分析Heap的时候，有趣的是，发现Heap并不知道它占用了太多的内存。Heap dump说，自己只占了大概170MB的样子。但是你`cat /proc/1/status | grep VmRSS`，或者`top`却发现它占用了1.3G的内存。能够解释的就是，malloc heap没有被释放回去。Hongli Lai的一篇[文章][hongli_lai]引起了大家的关注，甚至还开了[issue](https://bugs.ruby-lang.org/issues/15667)。所以，就是系统认为你既然之前要了那么多内存过去，以后可能还需要那么多内存，我这儿的内存还挺多的，暂时就不用还给我了。他也提到，用`malloc_trim`可以强制回收这些空间，看上去非常的exciting，但是就算有这么多空间，依旧是碎片化的，依旧没法容下一个稍微大一点的对象。里面提到的一个[工具](https://github.com/FooBarWidget/heap_dumper_visualizer)能够可视化ruby的heap，仅限于ubuntu 18.04。我在docker上面试过了，的确可以用。不过没有细究里面的代码，因为觉得上面的理论已经够我理解碎片化了。



## 其他

1. 我尝试过`derailed_benchmarks`，但它对于我分析内存问题来说帮助有限。它可以分析加载的gem包需要多少内存，或者访问某个URL导致的内存变化，或者一直开启内存监控。个人觉得没有瑞士军刀的感觉。
2. `GC.stat`也是一个非常有用的信息。具体参数含义可以看[https://www.speedshop.co/2017/03/09/a-guide-to-gc-stat.html](https://www.speedshop.co/2017/03/09/a-guide-to-gc-stat.html)
3. 一些文章单纯分析ruby的memory问题，比如[https://www.toptal.com/ruby/hunting-ruby-memory-issues](https://www.toptal.com/ruby/hunting-ruby-memory-issues)，个人觉得没有太多的帮助。单纯就语言而言，内存和CPU就是一个trade-off问题。如果能够把所有数据都加载到内存里面，理论上时间最短，但是现实就是，你需要妥协。
4. 另外一个可视化heap的工具，[https://tenderlovemaking.com/2017/09/27/visualizing-your-ruby-heap.html](https://tenderlovemaking.com/2017/09/27/visualizing-your-ruby-heap.html),可以直接可视化heap dump文件。


[aaron_patterson]: https://www.youtube.com/watch?v=H8iWLoarTZc
[richard_schneeman_1]: https://www.cloudbees.com/blog/the-definitive-guide-to-ruby-heap-dumps-part-i
[richard_schneeman_2]: https://www.cloudbees.com/blog/the-definitive-guide-to-ruby-heap-dumps-part-ii
[frederick_cheung_1]: https://www.youtube.com/watch?v=UCJsjr8ksDc
[frederick_cheung_2]: https://www.spacevatican.org/2019/5/4/debugging-a-memory-leak-in-a-rails-app/
[hongli_lai]: https://www.joyfulbikeshedding.com/blog/2019-03-14-what-causes-ruby-memory-bloat.html


### Reference

1. [https://www.youtube.com/watch?v=kZcqyuPeDao](https://www.youtube.com/watch?v=kZcqyuPeDao)

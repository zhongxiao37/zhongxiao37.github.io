---
layout: post
title: "Include & Prepend"
date: 2017-10-17 00:00:00 +0800
categories: ruby
---

Ruby的include和prepend有一个重要的知识点，就是多重包含的时候，后面的Module会被ignore掉，只会包含一次。

```ruby
module C
  
end

module M
  
end

class B
  include M
  include C
end

p B.ancestors
# [B, C, M, Object, Kernel, BasicObject]

class A
  prepend M
  prepend C
end

p A.ancestors
# [C, M, A, Object, Kernel, BasicObject]


class D
  include M
  prepend C
end

p D.ancestors
# [C, D, M, Object, Kernel, BasicObject]

module M
  include C
end

class E
  prepend C
  include M
end

p E.ancestors
# [C, E, M, Object, Kernel, BasicObject]
```

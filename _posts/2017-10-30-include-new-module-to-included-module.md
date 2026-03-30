---
layout: post
title: "Include a new Module to included Module won't add methods"
date: 2017-10-30 00:00:00 +0800
categories: ruby
---

故事是这样的，如果我在创建一个实例以后，再去编辑类并增加一个方法，这个实例是能够发现新的方法的。

```ruby
class Dog
  def name
    
  end
end

a_dog = Dog.new

p a_dog.methods

class Dog
  def age
    
  end
end

p a_dog.methods
```

同理，在已经included 的module里增加一个新的方法。

```ruby
module Professor
  def lectures
    
  end
  
end

class Mathematician
  attr_accessor :first_name, :last_name
  include Professor
end

fett = Mathematician.new

p fett.methods


module Professor
  def primary_classroom
    
  end
  
end

p fett.methods # this will have new method
```

但是，如果在已经included的module里面include一个新的module，这样就不行了。

```ruby
module Employee
  def hired_date
    
  end
  
end

module Professor
  include Employee
end

p fett.methods # this will not have hired_date method until Mathematician included Professor again
```

原因在于，前两者影响的是方法表而已，而实例对应的klass里面留下的只是方法表pointer，而不是具体的方法。所以，在方法表里面增加方法是可行的。

但是，include 一个新的module，是会改变super pointer。在第一次include的时候，就已经“复制”好module并设置好了super pointer，不会再次改变。除非，重新打开类再include一次。

---
layout: default
title: From Ruby To Python/Javascript/Go
date: 2020-07-28 17:04 +0800
categories: ruby python javascript golang
---

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [From Ruby To Python, Javascript, Go](#from-ruby-to-python-javascript-go)
  - [Data types](#data-types)
    - [Boolean](#boolean)
    - [Hash](#hash)
    - [Array > List](#array--list)
  - [Control flow](#control-flow)
    - [If...else](#ifelse)
    - [Loop](#loop)
  - [Methods/Functions](#methodsfunctions)
    - [puts](#puts)
    - [sort](#sort)
    - [custom sort](#custom-sort)
    - [shift/unshift/pop/push](#shiftunshiftpoppush)
    - [regex](#regex)
    - [find](#find)
    - [concat two arrays](#concat-two-arrays)
    - [id](#id)
    - [class](#class)
    - [uniq](#uniq)
    - [map](#map)
    - [select > filter](#select--filter)
    - [reduce](#reduce)
    - [any?](#any)
    - [merge](#merge)
    - [group_by > Counter](#group_by--counter)
  - [Exception Handle](#exception-handle)
  - [Dynanmic methods](#dynanmic-methods)
  - [Others](#others)
    - [List all small characters](#list-all-small-characters)
    - [concat list](#concat-list)
    - [Convert number to binary](#convert-number-to-binary)
    - [Convert binary to number](#convert-binary-to-number)
    - [transalate](#transalate)
    - [permutations](#permutations)
    - [zip](#zip)
    - [unzip](#unzip)
    - [sleep](#sleep)
    - [Not supporting method chaining](#not-supporting-method-chaining)
    - [Return data](#return-data)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->




# From Ruby To Python, Javascript, Go
{: .-row}

{: .col-3}
## Ruby

{: .col-3}
## Python

{: .col-3}
## Javascript

{: .col-3}
## Go

## 概述
{: .-row}

{: .col-3}
```
Ruby
```

{: .col-3}
```
Python
```

{: .col-3}
```
Javascript
```

{: .col-3}
```
Go
```


## Version manager
{: .-row}

{: .col-3}
```bash
brew install rbenv
rbenv versions
rbenv use 2.7.2
```

{: .col-3}
```bash
brew install pyenv
pyenv versions
pyenv global
pyenv local
```

{: .col-3}
```bash
yarn global add n
n
```

{: .col-3}
```go
```




## Data types

### Boolean
{: .-row}

{: .col-3}
```ruby
true
false
```

{: .col-3}
```python
True
False
```

{: .col-3}
```javascript
true
false
```

{: .col-3}
```go
true
false
```

### Hash
{: .-row}

{: .col-3}
```ruby
# Hash
{a: 1, b: 2, c: 3}
```

{: .col-3}
```python
# Dictionary
{'a': 1, 'b': 2, 'c': 3}
```

{: .col-3}
```javascript
// Object
{'a': 1, 'b': 2, 'c': 3}

// ES6 Map
const mapper = new Map([['1', 'a'], ['2', 'b']]);
```

{: .col-3}
```go
// Map
ages := make(map[string]int) // 不能够初始化为nil，否则不能够赋值了
ages := map[string]int{
    "alice":   31,
    "charlie": 34,
}
```


### Array
{: .-row}

{: .col-3}
```ruby
arr = [1,2,3]
arr[1..]  # [2, 3]
arr[-1]   # [3]
arr[1..2] # [2, 3]
# 但是不支持 arr[::2]这样的操作

arr + [4, 5, 6] # [1,2,3,4,5,6]
```

{: .col-3}
```python
arr = [1,2,3]
arr[1:]  # [2, 3]
arr[:2]  # [1, 2]
arr[::2] # [1, 3]
arr + [4, 5, 6] # [1,2,3,4,5,6]
```

{: .col-3}
```javascript
var arr = [1,2,3]
arr.slice(0, 2) // [1, 2]

[...arr, ...arr] // [1,2,3,1,2,3]
```

{: .col-3}
```go
// Go语言里面很少使用数组，因为是固定长度的。
q := [...]int{1, 2, 3}
fmt.Printf("%T\n", q) // "[3]int"
fmt.Printf("%v\n", q) // "[1,2,3]"
// 相对应的是Slice，动态序列，和Python一样，支持各种切片操作
data := []string{"one", "", "three"}

fmt.Printf("%q\n", data)           // `["one" "three" "three"]`
fmt.Printf("%q\n", data[:2])      // `["one" ""]`

numbers := []int{1,2}
numbers = append(numbers, 3, 4)  // [1,2,3,4]
fmt.Printf("%v\n", numbers) // "[1,2,3,4]"  
```

## Variables

### Declare
{: .-row}



### Copy Array/Slice
{: .-row}

{: .col-3}
```ruby
2.6.6 :027 > a = [1,2,3]
 => [1, 2, 3]
2.6.6 :028 > b = a
 => [1, 2, 3]

```

{: .col-3}
```python
>>> a = [1,2,3]
>>> b = a
>>> id(b)
4315631168
>>> id(a)
4315631168
>>> a[2] = 4
>>> a
[1, 2, 4]
>>> b
[1, 2, 4]

```

{: .col-3}
```javascript

```


{: .col-3}
```go
a := []int{1,2,3}
b := a

fmt.Printf("%v\n", a)  // [1,2,3]
fmt.Printf("%v\n", b)  // [1,2,3]

a = append(a, 4)

fmt.Printf("%v\n", a)  // [1,2,3,4]
fmt.Printf("%v\n", b)  // [1,2,3]
```


## Control flow

### If...else
{: .-row}

{: .col-3}
```ruby
if true
    puts 'yes'
else
    puts 'no'
end
```

{: .col-3}
```python
if True:
    print('yes')
elif False:
    print('no')
else:
    print('n/a')
```

{: .col-3}
```javascript
if (true) {
    console.log('yes');
} else {
    console.log('no');
}
```

{: .col-3}
```go
s := "bingo"

if s != "" {
  fmt.Println("yes")
} else {
  fmt.Println("no")
}
```


### Loop
{: .-row}

{: .col-3}
```ruby
(0..10).each do |i|
    puts i
end
```

{: .col-3}
```python
for i in range(10):
    print(i)

for i in count(start=0, step=1):
    print(i)

while True:
    quotient = num // output_base
    remainder = num % output_base

    output.append(remainder)
    num = quotient
    
    if quotient == 0:
        break
```

{: .col-3}
```javascript
let arr = ['a', 'b', 'c'];
for (let [k, v] of arr.entries()) {
  console.log(k);
  console.log(v);
}

let dict = {a: 1, b: 2, c: 3}
for (let [k, v] of Object.entries(dict)) {
  console.log(k);
  console.log(v);
}
```

{: .col-3}
```go
// Only for loop in Go

sum := 1
for sum < 100 {
  sum += 1
}
fmt.Println(sum)

// Infinite loop
// while true in Ruby

for {
  // do something
}

// each
kvs := map[string]string{"name": "Amy", "lastName": "Amy"}
for k, v := range kvs {
  fmt.Printf("%s -> %s\n", k, v)
}

// 如果是数组，第一个就是index
arr := []string{"a", "b", "c", "d", "e"}
for i, v := range arr {
  fmt.Println(i, v)
}
```



## Methods/Functions

### in general
{: .-row}

{: .col-3}
```ruby
# 在Ruby里面，函数和方法一般是同一个东西。
# 在英语里面，Function是独立的，可以调用的。Method是在类里面定义的函数，需要通过实例才可以调用它。

# 函数不是第一公民
# 这就意味着你不能够把函数赋值给变量，当作参数传入或者返回。
# 虽然可以通过symbol，或者lambda的方式来实现，但是总觉得是剑走偏锋了，一般都不这么用

```

{: .col-3}
```python
# 函数是第一公民
# 在Python里面最典型的例子就是装饰器。装饰器其实就是把被修饰的函数B当做参数传入装饰器函数A，然后在返回一个新的函数C。
# 这样在执行函数B的时候，实际上是执行函数C，所以你可以在C里面定义额外的操作，比如给方法计时
# 你还可以嵌套多次装饰器，实现参数化的装饰器

```

{: .col-3}
```javascript
// 一般没有提第一公民这事，但是的确存在
// 最显然的例子就是函数定义有两种方式，一种是函数声明，另外一种就是函数表达式

```

{: .col-3}
```go
// 函数是第一公民
// 这就意味着函数可以当做值一样地处理
// 可以当作参数传入其他函数，也可以赋值给变量
// 甚至可以把一个实例的方法绑定给某个变量，调用这个变量其实就是调用这个实例的方法


p := Point{1, 2}
q := Point{4, 6}

distanceFromP := p.Distance        // method value
fmt.Println(distanceFromP(q))      // "5"

// 如果你是绑定struct里面的方法，那就需要第一个参数需要指定receiver
// 就像Python里面定义方法的时候，第一个参数是`self`或者`cls`

distance := Point.Distance   // method expression
fmt.Println(distance(p, q))  // "5"




```

### 类方法
{: .-row}

{: .col-3}
```ruby
# 如果理解透，其实每个类是Class的一个实例

class A
end
a = A.new # <A:0x00007fb508870018>
a.class # A
A.class # Class

# 所以，所谓的类方法，实际上其实也是实例（Class的一个实例A）方法

# 定义类方法，有好几种方法
class A
  def self.m1
    puts 'm1'
  end

  class << self
    def m2
      puts 'm2'
    end
  end

end

A.instance_eval do
  def m3
    puts 'm3'
  end
end

module M4
  def m4
    puts 'm4'
  end
end

# A.extend M4

# 或者像下面那样，记住隐式的self
class A
  extend M4
end

# 调用的时候直接A.m1就行了
# 记住，A其实也是一个实例
```

{: .col-3}
```python

```

{: .col-3}
```javascript
class Robot {
  name: string;
  static availableNames: string[];

  constructor() {
    this.name = Robot.generateName();
  }

  public resetName(): void {
    this.name = Robot.generateName();
  }

  public static releaseNames(): void {
    Robot.availableNames = [];
  }

  public static generateName(): string {
    if (
      Robot.availableNames === undefined ||
      Robot.availableNames.length === 0
    ) {
      Robot.availableNames = [];
      let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");
      let numbers = "0123456789".split("");
      for (const a of letters) {
        for (const b of letters) {
          for (const x of numbers) {
            for (const y of numbers) {
              for (const z of numbers) {
                Robot.availableNames.push([a, b, x, y, z].join(""));
              }
            }
          }
        }
      }
      // shuffle the array list
      for (let i = Robot.availableNames.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [Robot.availableNames[i], Robot.availableNames[j]] = [
          Robot.availableNames[j],
          Robot.availableNames[i],
        ];
      }
    }

    return Robot.availableNames.pop() as string;
  }
}
// https://googlechrome.github.io/samples/classes-es6/
```

{: .col-3}
```go


```

### 动态方法
{: .-row}

{: .col-3}
```ruby
# method_missing
# define_method
# include / included
# prepend / prepended
# extend / extended

```

{: .col-3}
```python

```

{: .col-3}
```javascript

```

{: .col-3}
```go


```

### puts
{: .-row}

{: .col-3}
```ruby
puts 's'
```

{: .col-3}
```python
print('s')
```

{: .col-3}
```javascript
console.log('s')
```

{: .col-3}
```go
s := "s"
fmt.Println(s)
```

### sort
{: .-row}

{: .col-3}
```ruby
[3,2,1].sort => [1,2,3]
```

{: .col-3}
```python
a_list = [3,2,1]
a_list.sort() # None
a_list # [1,2,3]
```

{: .col-3}
```javascript
const arr = [
  'peach',
  'straw',
  'apple',
  'spork'
];
arr.sort()
```

{: .col-3}
```go
import "sort"

strs := []string{"c", "a", "b"}
sort.Strings(strs)
fmt.Println("Strings:", strs)

ints := []int{7, 2, 4}
sort.Ints(ints)
fmt.Println("Ints:   ", ints)
```


### custom sort
{: .-row}

{: .col-3}
```ruby
[['a', 7], ['b', 2]].sort_by { |k, v| v }  => [["b", 2], ["a", 7]]

# Ruby的类里面如果include了Enumerable并定义了<=>方法，那他们的实例就是可以比较的
# 具体的比较方法通过定义的<=>来实现的
# 比如下面的就是一个简单的二叉树节点的比较

class Bst

  include Enumerable

  attr_reader :left, :right, :data

  def initialize(new_data)
    @data = new_data
  end

  def insert(new_data)
    if new_data <= @data
      @left ? @left.insert(new_data) : @left = Bst.new(new_data)
    else
      @right ? @right.insert(new_data) : @right = Bst.new(new_data)
    end
    self
  end

  def each(&block)
    return to_enum unless block_given?

    @left&.each(&block)
    yield @data
    @right&.each(&block)

    self
  end

  def <=>(other)
    @data <=> other.data
  end

  def predecessor(key)
    self.each_cons(2).select { |e| e.last == key }.map(&:first)[0]
  end

  def successor(key)
    self.each_cons(2).select { |e| e.first == key }.map(&:last)[0]
  end

end
```

{: .col-3}
```python
>>> a = [['a', 7], ['b', 2]]
>>> a.sort(key=lambda e: (e[1], e[0]), reverse=True)
>>> a
[['b', 2], ['a', 7]]

# Python 好像不屑于Ruby的spaceship operator
# 如果需要排序，用自定义排序就可以搞定了

```

{: .col-3}
```javascript
// 如果记得Ruby中的宇宙飞船符的话，下面的通过函数自定义排序其实也是类似的
var items = [
  { name: 'Edward', value: 21 },
  { name: 'Sharpe', value: 37 },
  { name: 'And', value: 45 },
  { name: 'The', value: -12 },
  { name: 'Magnetic', value: 13 },
  { name: 'Zeros', value: 37 }
];

// sort by value
items.sort(function (a, b) {
  return a.value - b.value;
});

// sort by name
items.sort(function(a, b) {
  var nameA = a.name.toUpperCase(); // ignore upper and lowercase
  var nameB = b.name.toUpperCase(); // ignore upper and lowercase
  if (nameA < nameB) {
    return -1;
  }
  if (nameA > nameB) {
    return 1;
  }

  // names must be equal
  return 0;
});
```

{: .col-3}
```go
// Need to implement sort.Interface - Len, Less, and Swap on type byLength

type byLength []string

func (s byLength) Len() int {
    return len(s)
}
func (s byLength) Swap(i, j int) {
    s[i], s[j] = s[j], s[i]
}
func (s byLength) Less(i, j int) bool {
    return len(s[i]) < len(s[j])
}

func main() {
    fruits := []string{"peach", "banana", "kiwi"}
    sort.Sort(byLength(fruits))
    fmt.Println(fruits)
}
```


### shift/unshift/pop/push
{: .-row}

{: .col-3}
```ruby
arr = []        # => []
arr.push(1)     # => [1]
arr.unshift(2)  # => [2, 1]
arr.shift       # => 2
arr.pop         # => 1
```

{: .col-3}
```python
arr = []
arr.append(1)
arr.insert(0, 2) # => [2, 1]
arr.pop(0)      # => 2
arr.pop()       # => 1
```

{: .col-3}
```javascript
var arr1 = [0, 1, 2]
arr1.push(3)
var arr2 = [4, 5, 6]
arr1.push(...arr2)
arr1.pop()
arr1.shift()
```


{: .col-3}
```go
// go 没有pop方法，只能够自己写

func pop(alist *[]int) int {
   f:=len(*alist)
   rv:=(*alist)[f-1]
   *alist=append((*alist)[:f-1])
   return rv
}

func main() {
  n:=[]int{1,2,3,4,5}
  fmt.Println(n)
  last:=pop(&n)
  fmt.Println("last is",last)
  fmt.Printf("list of n is now %v\n", n)
}
```


### regex
{: .-row}

{: .col-3}
```ruby
'13243432432'.scan(/\d/) => ["1", "3", "2", "4", "3", "4", "3", "2", "4", "3", "2"]

m = /\A(\d{3})(\d)/.match('13243432432') => #<MatchData "1324" 1:"132" 2:"4">
m[0] # "1324"
m[1] # "132"
```

{: .col-3}
```python
import re
re.findall(r'\d', '1234232432')
# ['1', '2', '3', '4', '2', '3', '2', '4', '3', '2']

import re
s = 'a1b2c3'
s = 'a1b#2c3'
m = re.match(r'([^#]*)#(.*)', s)
m.group() # => 'a1b#2c3'
m.group(1) # => 'a1b'
m.group(2) # => '2c3'
```

{: .col-3}
```javascript
const regex = /[a-zA-Z]/g;
const matched_chars = 'abcdefg'.match(regex);
// ['a', 'b', 'c', 'd', 'e', 'f', 'g']
```

{: .col-3}
```go

```

### find
{: .-row}

{: .col-3}
```ruby
lst.find { |e| e == i }
```

{: .col-3}
```python
next(x for x in seq if predicate(x))
```

{: .col-3}
```javascript
const array1 = [5, 12, 8, 130, 44];
const found = array1.find(element => element > 10);
// 12
```


### concat two arrays
{: .-row}

{: .col-3}
```ruby
[1,2,3] + [4, 5, 6]
```

{: .col-3}
```python
b = [1,2,3]
b.extend([5,4,6])
b + [7,8,9]
```

{: .col-3}
```javascript
var a = [1,2,3]
// don't use + as it will return '1,2,34,5,6'
a.push(...[4,5,6])
a //[1,2,3,4,5,6]
```

{: .col-3}
```go

```

### id
{: .-row}

{: .col-3}
```ruby
a.object_id
```

{: .col-3}
```python
id(a)
```

{: .col-3}
```javascript
// no such method
```

{: .col-3}
```go

```

### class
{: .-row}

{: .col-3}
```ruby
'str'.class
```

{: .col-3}
```python
type('123')
'123'.__class__
```

{: .col-3}
```javascript
var a = '1,2,3'
a.__prop__.constructor
```
`Javascript`详见[继承关系]({% post_url 2020-12-04-es6中的继承和mixin %})

{: .col-3}
```go

```

### uniq
{: .-row}

{: .col-3}
```ruby
[1,1,1].uniq => [1]
```

{: .col-3}
```python
list(set([1,1,1]))
```

{: .col-3}
```javascript
let arr = [1,2,3,1,2,3]
[...new Set(arr)]
// [1, 2, 3]
```

{: .col-3}
```
```


### map
{: .-row}

{: .col-3}
```ruby
[1,2,3].map { |e| e * 3 }
```

{: .col-3}
```python
list(map(lambda x: x * 3, [1,2,3]))
[i * 3 for i in [1,2,3]]
```

{: .col-3}
```javascript
[1,2,3,4,5].map( x => x * 2);
```

### select > filter
{: .-row}

{: .col-3}
```ruby
(-5..5).select { |x| x < 0 }
```

{: .col-3}
```python
less_than_zero = list(filter(lambda x: x < 0, range(-5, 5)))
[e for e in range(-5, 5) if e < 0]
```

{: .col-3}
```javascript
Array.from({length: 5}, (v, i) => i).filter( x => x % 2 === 0);
// [0, 2, 4]
```


### reduce
{: .-row}

{: .col-3}
```ruby
[1,2,3].reduce(0) { |sum, x| sum + x }
```

{: .col-3}
```python
from functools import reduce
reduce(lambda sum, x: sum + x, [1,2,3], 0)
```

{: .col-3}
```javascript
const array1 = [1, 2, 3, 4];
array1.reduce((sum, x) => sum + x);
```


### all
{: .-row}

{: .col-3}
```ruby
[1,2,3].all { |e| e.even? }
```

{: .col-3}
```python
all(len(g) % 2 == 0 for g in groups)
```

{: .col-3}
```javascript
[2,4,6].every( x => x % 2 === 0)
```


### any?
{: .-row}

{: .col-3}
```ruby
[1,2,3].any? { |e| e > 1 } => true
```

{: .col-3}
```python
any(x > 3 for x in [1,2,3]) # False
```

{: .col-3}
```javascript
[2,4,6].some( x => x % 2 === 0)
```

### merge
{: .-row}

{: .col-3}
```ruby
a = {name: 'phx', age: 12}
a.merge({gender: 'male'})
```

{: .col-3}
```python
In [51]: a = {'name': 'phx', 'age': 12 }

In [52]: a
Out[52]: {'name': 'phx', 'age': 12}

In [53]: a.update({'gender': 'male'})

In [54]: a
Out[54]: {'name': 'phx', 'age': 12, 'gender': 'male'}
```

{: .col-3}
```javascript
var a = { a: 1 }
var b = Object.assign(a, { b: 2 })
// {a: 1, b: 2}
```

### group_by > Counter
{: .-row}

{: .col-3}
```ruby
[1,2,3,4,5,6,7,1,3].group_by {|e| e}.map { |k, v| [k, v.size]}.to_h
```

{: .col-3}
```python
import collections
dict(collections.Counter([1,2,3,4,5,6,7,1,3]))

```

{: .col-3}
```javascript
[1,2,3,4,5,6,7,1,3].reduce((acc, x) => {
    if (!acc[x]) acc[x] = 0;
    acc[x] += 1;
    return acc;
}, {});
```

### range
{: .-row}

{: .col-3}
```ruby
(1..5).to_a
```

{: .col-3}
```python
list(range(10))
# [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
list(range(1, 10))
# [1, 2, 3, 4, 5, 6, 7, 8, 9]
```

{: .col-3}
```javascript
Array.from({length: 5}, (v, i) => i);
// [0, 1, 2, 3, 4]
```

### chars
{: .-row}

{: .col-3}
```ruby
'foo'.chars
```

{: .col-3}
```python
[char for char in 'foo']
```

{: .col-3}
```javascript
Array.from('foo')
```


### with


## Interface
{: .-row}

{: .col-3}
```
```

{: .col-3}
```
```

{: .col-3}
```
```

{: .col-3}
```go
// 接口类型 抽象的类型。对应到Python的ABCMeta和@abstractmethod。不会暴露对象内部值的结构，只会暴露自己的方法。
```




## Exception Handle
{: .-row}

{: .col-3}
```ruby
begin
    1/0
rescue Exception => e
    p e
end
```

{: .col-3}
```python
try:
    y = ALPHABET.index(char)
except ValueError:
    return char
```


## Dynanmic methods
{: .-row}

{: .col-3}
```ruby
self.send(k)
```

{: .col-3}
```python
getattr(self, k)()
```

## Others

### List all small characters
{: .-row}

{: .col-3}
```ruby
('a'..'z').to_a
```

{: .col-3}
```python
from string import ascii_lowercase
ALPHABET = list(ascii_lowercase)
```

### concat list
{: .-row}

{: .col-3}
```ruby
[1,2,3].join('')
```

{: .col-3}
```python
''.join([1,2,3])
```

{: .col-3}
```javascript
[1,2,3].join('')
```

### Convert number to binary
{: .-row}

{: .col-3}
```ruby
7.to_s(2)
```

{: .col-3}
```python
"{0:b}".format(7 % 256)
```

{: .col-3}
```javascript
10..toString(2)
```

### Convert binary to number
{: .-row}

{: .col-3}
```ruby
'101'.to_i(2)
```

{: .col-3}
```python
int('101', 2)
```

{: .col-3}
```javascript
parseInt('101', 2)
```


### transalate
{: .-row}

{: .col-3}
```ruby
"hello".tr('el', 'ip')      #=> "hippo"
"hello".tr('aeiou', '*')    #=> "h*ll*"
"hello".tr('aeiou', 'AA*')  #=> "hAll*"
```

{: .col-3}
```python
ALPHABETS = list(chr(x) for x in range(ord('a'), ord('z')+1))
TRANSLATION_TABLE = str.maketrans(''.join(ALPHABETS), ''.join(reversed(ALPHABETS)))
[ch.translate(TRANSLATION_TABLE) for ch in 'aeiou']
```


### permutations
{: .-row}

{: .col-3}
```ruby
(1..3).to_a.permutation(2).to_a
 => [[1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 2]]
```

{: .col-3}
```python
>>> [i for i in itertools.permutations([1,2,3], 2)]
[(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)]
```

### zip
{: .-row}

{: .col-3}
```ruby
a = [ 4, 5, 6 ]
b = [ 7, 8, 9 ]
[1, 2, 3].zip(a, b)   #=> [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
[1, 2].zip(a, b)      #=> [[1, 4, 7], [2, 5, 8]]
a.zip([1, 2], [8])    #=> [[4, 1, 8], [5, 2, nil], [6, nil, nil]]
```

{: .col-3}
```python
# Python code to demonstrate the working of  
# zip() 
  
# initializing lists 
name = [ "Manjeet", "Nikhil", "Shambhavi", "Astha" ] 
roll_no = [ 4, 1, 3, 2 ] 
marks = [ 40, 50, 60, 70 ] 
  
# using zip() to map values 
mapped = zip(name, roll_no, marks) 
  
# converting values to print as set 
mapped = set(mapped) 
  
# printing resultant values  
print ("The zipped result is : ",end="") 
print (mapped)
```



### unzip
{: .-row}

{: .col-3}
```ruby
```

{: .col-3}
```python
# unzipping values 
namz, roll_noz, marksz = zip(*mapped) 
  
print ("The unzipped result: \n",end="") 
  
# printing initial lists 
print ("The name list is : ",end="") 
print (namz) 
```


### sleep
{: .-row}

{: .col-3}
```ruby
sleep 1
```

{: .col-3}
```javascript
import time
time.sleep(2)
```

{: .col-3}
```javascript
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

console.log("Hello");
sleep(2000).then(() => { console.log("World!"); });
```




### format
{: .-row}

{: .col-3}
```ruby
"%02d:%02d" % exact_time
format("%02d", 7) #有点不像ruby代码耶
```

```python
'{:02d}:{:02d}'.format(7, 8)
```

```javascript
```

```go
```

### delete
{: .-row}

{: .col-3}
```ruby
```

{: .col-3}
```python
'{:02d}:{:02d}'.format(7, 8)
```

{: .col-3}
```javascript
```

{: .col-3}
```go
```

### replace
{: .-row}

{: .col-3}
```ruby
```

{: .col-3}
```python
'{:02d}:{:02d}'.format(7, 8)
```

{: .col-3}
```javascript
```

{: .col-3}
```go
```











### template
{: .-row}

{: .col-3}
```ruby
```

{: .col-3}
```python
'{:02d}:{:02d}'.format(7, 8)
```

{: .col-3}
```javascript
```

{: .col-3}
```go
```




### Not supporting method chaining
{: .-row}

I have a string and need to convert it to ascii codes. That should be done via `map`. Later, I want to sum the values, thing will be different in `ruby` and `python`.

{: .col-3}
```ruby
'abcd'.to_a.map { |e| e.bytes }.sum
```

{: .col-3}
```python
sum(map(lambda x: ord(x), list('abcd')))
```

In above example, you could achieve the purpose by simply add `.method` to convert the previous result into a new format in `ruby`. However, you need to wrap another function like `sum()` to achieve this. IMHO, this is not easy for human reading. You need to figure out the flow from inside to outside, that's `list` > `map` > `sum`.

### Return data
{: .-row}

By default, `python` return `None` unless you specify the return value. `ruby` will return the last value of the method. A simple example is `sort()` returns `None`, while `.sort` returns sorted array/list.

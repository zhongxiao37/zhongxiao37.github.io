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
  - [Ruby](#ruby)
  - [Python](#python)
  - [Javascript](#javascript)
  - [Go](#go)
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

{: .col-3.secondary}
## Ruby

{: .col-3}
## Python

{: .col-3}
## Javascript

{: .col-3}
## Go


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
```

{: .col-3}
```go
// Map
ages := make(map[string]int)
ages := map[string]int{
    "alice":   31,
    "charlie": 34,
}
```


### Array > List
{: .-row}

```ruby
[1,2,3]
```

```python
[1,2,3]
```

```javascript
var a = [1,2,3]
```


## Control flow

### If...else
{: .-row}

```ruby
if true
    puts 'yes'
else
    puts 'no'
end
```

```python
if True:
    print('yes')
elif False:
    print('no')
else:
    print('n/a')
```

```javascript
if (true) {
    console.log('yes');
} else {
    console.log('no');
}
```


### Loop
{: .-row}

```ruby
(0..10).each do |i|
    puts i
end
```

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



## Methods/Functions

### puts
{: .-row}

```ruby
puts 's'
```

```python
print('s')
```

```javascript
console.log('s')
```

### sort
{: .-row}

```ruby
[3,2,1].sort => [1,2,3]
```

```python
a_list = [3,2,1]
a_list.sort() # None
a_list # [1,2,3]
```

```javascript
const arr = [
  'peach',
  'straw',
  'apple',
  'spork'
];
arr.sort()
```


### custom sort
{: .-row}

```ruby
[['a', 7], ['b', 2]].sort_by { |k, v| v }  => [["b", 2], ["a", 7]]
```

```python
>>> a = [['a', 7], ['b', 2]]
>>> a.sort(key=lambda e: (e[1], e[0]), reverse=True)
>>> a
[['b', 2], ['a', 7]]
```

### shift/unshift/pop/push
{: .-row}

```ruby
arr = []        # => []
arr.push(1)     # => [1]
arr.unshift(2)  # => [2, 1]
arr.shift       # => 2
arr.pop         # => 1
```

```python
arr = []
arr.append(1)
arr.insert(0, 2) # => [2, 1]
arr.pop(0)      # => 2
arr.pop()       # => 1
```


### regex
{: .-row}

```ruby
'13243432432'.scan(/\d/) => ["1", "3", "2", "4", "3", "4", "3", "2", "4", "3", "2"]
```

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

### find
{: .-row}

```ruby
lst.find { |e| e == i }
```

```python
next(x for x in seq if predicate(x))
```

### concat two arrays
{: .-row}

```ruby
[1,2,3] + [4, 5, 6]
```

```python
b = [1,2,3]
b.extend([5,4,6])
b + [7,8,9]
```

```javascript
var a = [1,2,3]
// don't use + as it will return '1,2,34,5,6'
a.push(...[4,5,6])
a //[1,2,3,4,5,6]
```

### id
{: .-row}

```ruby
a.object_id
```

```python
id(a)
```

### class
{: .-row}

```ruby
'str'.class
```

```python
type('123')
'123'.__class__
```

```javascript
var a = '1,2,3'
a.__prop__.constructor
```
详见[继承关系]({% post_url 2020-12-04-es6中的继承和mixin %})

### uniq
{: .-row}

```ruby
[1,1,1].uniq => [1]
```

```python
list(set([1,1,1]))
```

### map
{: .-row}

```ruby
[1,2,3].map { |e| e * 3 }
```

```python
list(map(lambda x: x * 3, [1,2,3]))
[i * 3 for i in [1,2,3]]
```

### select > filter
{: .-row}

```ruby
(-5..5).select { |x| x < 0 }
```

```python
less_than_zero = list(filter(lambda x: x < 0, range(-5, 5)))
[e for e in range(-5, 5) if e < 0]
```

### reduce
{: .-row}

```ruby
[1,2,3].reduce(0) { |sum, x| sum + x }
```

```python
from functools import reduce
reduce(lambda sum, x: sum + x, [1,2,3], 0)
```

### any?
{: .-row}

```ruby
[1,2,3].any? { |e| e > 1 } => true
```

```python
any(x > 3 for x in [1,2,3]) # False
```

### merge
{: .-row}

```ruby
a = {name: 'phx', age: 12}
a.merge({gender: 'male'})
```

```python
In [51]: a = {'name': 'phx', 'age': 12 }

In [52]: a
Out[52]: {'name': 'phx', 'age': 12}

In [53]: a.update({'gender': 'male'})

In [54]: a
Out[54]: {'name': 'phx', 'age': 12, 'gender': 'male'}
```

```javascript
var a = { a: 1 }
var b = Object.assign(a, { b: 2 })
// {a: 1, b: 2}
```

### group_by > Counter
{: .-row}

```ruby
[1,2,3,4,5,6,7,1,3].group_by {|e| e}.map { |k, v| [k, v.size]}.to_h
```

```python
import collections
dict(collections.Counter([1,2,3,4,5,6,7,1,3]))

```


## Exception Handle

```ruby
begin
    1/0
rescue Exception => e
    p e
end
```



```python
try:
    y = ALPHABET.index(char)
except ValueError:
    return char
```


## Dynanmic methods

```python
getattr(self, k)()
```

```ruby
self.send(k)
```


## Others

### List all small characters
{: .-row}

```ruby
('a'..'z').to_a
```

```python
from string import ascii_lowercase
ALPHABET = list(ascii_lowercase)
```

### concat list
{: .-row}

```ruby
[1,2,3].join('')
```

```python
''.join([1,2,3])
```

### Convert number to binary
{: .-row}

```ruby
7.to_s(2)
```


```python
"{0:b}".format(7 % 256)
```

### Convert binary to number
{: .-row}

```ruby
'101'.to_i(2)
```

```python
int('101', 2)
```


### transalate
{: .-row}

```ruby
"hello".tr('el', 'ip')      #=> "hippo"
"hello".tr('aeiou', '*')    #=> "h*ll*"
"hello".tr('aeiou', 'AA*')  #=> "hAll*"
```

```python
ALPHABETS = list(chr(x) for x in range(ord('a'), ord('z')+1))
TRANSLATION_TABLE = str.maketrans(''.join(ALPHABETS), ''.join(reversed(ALPHABETS)))
[ch.translate(TRANSLATION_TABLE) for ch in 'aeiou']
```


### permutations
{: .-row}

```ruby
(1..3).to_a.permutation(2).to_a
 => [[1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 2]]
```

```python
>>> [i for i in itertools.permutations([1,2,3], 2)]
[(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)]
```

### zip
{: .-row}

```ruby
a = [ 4, 5, 6 ]
b = [ 7, 8, 9 ]
[1, 2, 3].zip(a, b)   #=> [[1, 4, 7], [2, 5, 8], [3, 6, 9]]
[1, 2].zip(a, b)      #=> [[1, 4, 7], [2, 5, 8]]
a.zip([1, 2], [8])    #=> [[4, 1, 8], [5, 2, nil], [6, nil, nil]]
```


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

```javascript
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

console.log("Hello");
sleep(2000).then(() => { console.log("World!"); });
```




### Not supporting method chaining
{: .-row}

I have a string and need to convert it to ascii codes. That should be done via `map`. Later, I want to sum the values, thing will be different in `ruby` and `python`.

```ruby
'abcd'.to_a.map { |e| e.bytes }.sum
```

```python
sum(map(lambda x: ord(x), list('abcd')))
```

In above example, you could achieve the purpose by simply add `.method` to convert the previous result into a new format in `ruby`. However, you need to wrap another function like `sum()` to achieve this. IMHO, this is not easy for human reading. You need to figure out the flow from inside to outside, that's `list` > `map` > `sum`.

### Return data
{: .-row}

By default, `python` return `None` unless you specify the return value. `ruby` will return the last value of the method. A simple example is `sort()` returns `None`, while `.sort` returns sorted array/list.

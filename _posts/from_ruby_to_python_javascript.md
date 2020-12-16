<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [From Ruby To Python](#from-ruby-to-python)
  - [Data types](#data-types)
    - [Boolean](#boolean)
    - [Hash > Dictionary](#hash--dictionary)
    - [Array > List](#array--list)
  - [Control flow](#control-flow)
    - [If...else](#ifelse)
    - [Loop](#loop)
  - [Methods/Functions](#methodsfunctions)
    - [puts](#puts)
    - [sort](#sort)
    - [custom sort](#custom-sort)
    - [regex](#regex)
    - [uniq](#uniq)
    - [map](#map)
    - [select > filter](#select--filter)
    - [reduce](#reduce)
    - [any?](#any)
    - [group_by > Counter](#group_by--counter)
  - [Exception Handle](#exception-handle)
  - [Others](#others)
    - [List all small characters](#list-all-small-characters)
    - [Convert number to binary](#convert-number-to-binary)
    - [permutations](#permutations)
    - [zip](#zip)
    - [unzip](#unzip)
    - [Not supporting method chaining](#not-supporting-method-chaining)
    - [Return data](#return-data)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->




# From Ruby To Python, Javascript

## Data types

### Boolean

```ruby
true
false
```

```python
True
False
```

```javascript
true
false
```

### Hash > Dictionary

```ruby
{a: 1, b: 2, c: 3}
```

```python
{'a': 1, 'b': 2, 'c': 3}
```

In javascript, it should be Object
```javascript
{'a': 1, 'b': 2, 'c': 3}
```


### Array > List

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

```ruby
(0..10).each do |i|
    puts i
end
```

```python
for i in range(10):
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

for (const key in dict) {
  console.log(`${key}: ${dict[key]}`);
}
```



## Methods/Functions

### puts

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

```ruby
[['a', 7], ['b', 2]].sort_by { |k, v| v }  => [["b", 2], ["a", 7]]
```

```python
>>> a = [['a', 7], ['b', 2]]
>>> a.sort(key=lambda e: e[1])
>>> a
[['b', 2], ['a', 7]]
```

```javascript
var points = [40, 100, 1, 5, 25, 10];
points.sort(function(a, b){return a - b}); 
```

### regex

```ruby
'13243432432'.scan(/\d/) => ["1", "3", "2", "4", "3", "4", "3", "2", "4", "3", "2"]
```

```python
import re
re.findall(r'\d', '1234232432')
# ['1', '2', '3', '4', '2', '3', '2', '4', '3', '2']
```

### concat two arrays

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

```ruby
a.object_id
```

```python
id(a)
```


### uniq

```ruby
[1,1,1].uniq => [1]
```

```python
list(set([1,1,1]))
```

### map

```ruby
[1,2,3].map { |e| e * 3 }
```

```python
list(map(lambda x: x * 3, [1,2,3]))
[i * 3 for i in [1,2,3]]
```

### select > filter

```ruby
(-5..5).select { |x| x < 0 }
```

```python
less_than_zero = list(filter(lambda x: x < 0, range(-5, 5)))
[e for e in range(-5, 5) if e < 0]
```

### reduce

```ruby
[1,2,3].reduce(0) { |sum, x| sum + x }
```

```python
from functools import reduce
reduce(lambda sum, x: sum + x, [1,2,3], 0)
```

### any?

```ruby
[1,2,3].any? { |e| e > 1 } => true
```

```python
any(x > 3 for x in [1,2,3]) # False
```

### merge

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


```

### group_by > Counter

```ruby
[1,2,3,4,5,6,7,1,3].group_by {|e| e}.map { |k, v| [k, v.size]}.to_h
```

```python
import collection
dict(collection.Counter([1,2,3,4,5,6,7,1,3]))
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

```ruby
('a'..'z').to_a
```

```python
from string import ascii_lowercase
ALPHABET = list(ascii_lowercase)
```

### concat list

```ruby
[1,2,3].join('')
```

```python
''.join([1,2,3])
```

### Convert number to binary

```ruby
7.to_s(2)
```


```python
"{0:b}".format(7 % 256)
```

### transalate

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

```ruby
(1..3).to_a.permutation(2).to_a
 => [[1, 2], [1, 3], [2, 1], [2, 3], [3, 1], [3, 2]]
```

```python
>>> [i for i in itertools.permutations([1,2,3], 2)]
[(1, 2), (1, 3), (2, 1), (2, 3), (3, 1), (3, 2)]
```

### zip

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


```python
# unzipping values 
namz, roll_noz, marksz = zip(*mapped) 
  
print ("The unzipped result: \n",end="") 
  
# printing initial lists 
print ("The name list is : ",end="") 
print (namz) 
```

### sleep

```javascript
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

console.log("Hello");
sleep(2000).then(() => { console.log("World!"); });
```




### Not supporting method chaining

I have a string and need to convert it to ascii codes. That should be done via `map`. Later, I want to sum the values, thing will be different in `ruby` and `python`.

```ruby
'abcd'.to_a.map { |e| e.bytes }.sum
```

```python
sum(map(lambda x: ord(x), list('abcd')))
```

In above example, you could achieve the purpose by simply add `.method` to convert the previous result into a new format in `ruby`. However, you need to wrap another function like `sum()` to achieve this. IMHO, this is not easy for human reading. You need to figure out the flow from inside to outside, that's `list` > `map` > `sum`.

### Return data
By default, `python` return `None` unless you specify the return value. `ruby` will return the last value of the method. A simple example is `sort()` returns `None`, while `.sort` returns sorted array/list.









---
layout: default
title: Nightwatch初探
date: 2021-02-07 16:09 +0800
categories: nightwatch
---

看到测试组在用ES6的async/await，莫名激动。想看看async/await怎么实现的，试玩一下，觉得没有什么意思。


## 安装

```bash
npm install nightwatch --save-dev
npm install chromedriver --save-dev
```

## 配置nightwatch.conf.js

我把默认的浏览器改成chrome，并配置了一下server_path

```js
const chromedriver = require('chromedriver');

module.exports = {
  // ...
  test_settings: {
    default: {
      disable_error_log: false,
      launch_url: 'https://nightwatchjs.org',

      desiredCapabilities: {
        browserName : 'chrome'
      },

      webdriver: {
        start_process: true,
        server_path: (Services.chromedriver ? Services.chromedriver.path : '')
      }
    }
  }
}
```

## 测试脚本
写了两个简单的测试脚本，async的是仿造公司项目写的，但实际上因为是单线程，没啥卵用，该idle的还是idle着，也不会干其他的事情。个人觉得还没有第二个看着简洁些。

```js
// asycn_test.js
module.exports = {
  tags: ['google'],
  '@disabled': false,

  '通过http代理加速MySQL连接' : async function (browser) {
    await browser.url('http://zhongxiao37.github.io/proxy/mysql/2021/01/21/%E9%80%9A%E8%BF%87http%E4%BB%A3%E7%90%86%E5%8A%A0%E9%80%9Fmysql%E8%BF%9E%E6%8E%A5.html');
    await browser.waitForElementVisible('body header h1');
    await browser.assert.visible('body footer');
  },
  '通过ssh加速MySQL连接' : function (browser) {
    browser.url('http://zhongxiao37.github.io/ssh/2021/01/19/ssh-%E5%8A%A0%E9%80%9F.html')
           .waitForElementVisible('body header h1')
           .assert.visible('body footer')
           .end();
  }
};
```

## 起飞

```bash
./node_modules/.bin/nightwatch async_test.js
```

输出还是相当简洁

```bash

[Async Test] Test Suite
=======================
ℹ Connected to localhost on port 9515 (1072ms).
  Using: chrome (88.0.4324.150) on Mac OS X platform.

Running:  通过http代理加速MySQL连接

✔ Element <body header h1> was visible after 28 milliseconds.
✔ Testing if element <body footer> is visible (20ms)

OK. 2 assertions passed. (2.335s)
Running:  通过ssh加速MySQL连接

✔ Element <body header h1> was visible after 21 milliseconds.
✔ Testing if element <body footer> is visible (18ms)

OK. 2 assertions passed. (3.334s)

OK. 4  total assertions passed (7.027s)
```

个人感觉测试框架都是大同小异。比如和Ruby的测试对比起来，基本的`mock`，`before`，`after`都是一样的。

## 对比Ruby RSpec

创建Gemfile

```ruby
# Gemfile
source 'https://gems.ruby-china.com'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '2.6.6'

gem "rspec"
gem "selenium-webdriver"
```

安装Gem包并生成Gemfile.lock

```bash
bundle install
```

创建测试文件

```ruby
# spec/quick_rspec.rb
require "selenium-webdriver"
require 'active_support/core_ext/time'

def driver
  opts = Selenium::WebDriver::Chrome::Options.new
  opts.add_argument('--ignore-certificate-errors')
  opts.add_argument('--disable-popup-blocking')
  opts.add_argument('--disable-translate')
  opts.add_argument('--headless')
  @driver ||= Selenium::WebDriver.for :chrome, options: opts
end

def waitor
  @waitor ||= Selenium::WebDriver::Wait.new(timeout: 30)
end

describe 'Ruby Selenium Test' do
  describe "zhongxiao37.github.io" do
    it "通过http代理加速MySQL连接" do
      driver.navigate.to 'http://zhongxiao37.github.io/proxy/mysql/2021/01/21/%E9%80%9A%E8%BF%87http%E4%BB%A3%E7%90%86%E5%8A%A0%E9%80%9Fmysql%E8%BF%9E%E6%8E%A5.html'
      waitor.until { driver.find_element(:css, 'body header h1').displayed? }
      expect(driver.find_element(:css, 'body footer').displayed?).to be_truthy
    end
    it "通过ssh加速MySQL连接" do
      driver.navigate.to 'http://zhongxiao37.github.io/ssh/2021/01/19/ssh-%E5%8A%A0%E9%80%9F.html'
      waitor.until { driver.find_element(:css, 'body header h1').displayed? }
      expect(driver.find_element(:css, 'body footer').displayed?).to be_truthy
    end
  end
end
```

测试

```bash
rspec
```

## 对比Ruby Minitest

```ruby
# test/quick_test.rb
require 'minitest/autorun'
require "selenium-webdriver"

class QuickTest < Minitest::Test
  def test_one
    driver.navigate.to 'http://zhongxiao37.github.io/proxy/mysql/2021/01/21/%E9%80%9A%E8%BF%87http%E4%BB%A3%E7%90%86%E5%8A%A0%E9%80%9Fmysql%E8%BF%9E%E6%8E%A5.html'
    waitor.until { driver.find_element(:css, 'body header h1').displayed? }
    assert driver.find_element(:css, 'body footer').displayed?
  end

  def test_two
    driver.navigate.to 'http://zhongxiao37.github.io/ssh/2021/01/19/ssh-%E5%8A%A0%E9%80%9F.html'
    waitor.until { driver.find_element(:css, 'body header h1').displayed? }
    assert driver.find_element(:css, 'body footer').displayed?
  end

  private

  def driver
    opts = Selenium::WebDriver::Chrome::Options.new
    opts.add_argument('--ignore-certificate-errors')
    opts.add_argument('--disable-popup-blocking')
    opts.add_argument('--disable-translate')
    opts.add_argument('--headless')
    @driver ||= Selenium::WebDriver.for :chrome, options: opts
  end

  def waitor
    @waitor ||= Selenium::WebDriver::Wait.new(timeout: 30)
  end
end

```

测试

```bash
bundle exec ruby test/quick_test.rb
```



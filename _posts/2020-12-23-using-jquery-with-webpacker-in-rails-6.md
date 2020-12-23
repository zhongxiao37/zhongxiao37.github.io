---
layout: default
title: using JQuery with webpacker in Rails 6
date: 2020-12-23 10:59 +0800
categories: rails webpack
---

Rails升级到6以后引入了webpack，个人觉得对纯后端开发来说，真的实在太恶心了。但是，你们不是叫着满天飞的全局变量不好么？

### npm

Javascript的包管理器，类似于gem。下载package到./node_modules，同时更新package.json。

### yarn

又一个JavaScript的包管理器，比npm快，同时类似Gemfile.lock，指定需要的package版本。

### ES6

新的JavaScript标准，目前大部分浏览器已经支持了。浏览器的支持情况可以参见[这里][2]。

### Babel

把ES6转换成ES5格式，向后兼容。

### Webpack

把yarn、babel、各种配置、编译自动化起来。

### Webpacker

针对Webpack的Rails gem包，可以开箱即用。有两个配置文件，一个是config/webpacker.yml，另外一个是config/webpack/environment.js。一般情况下，只是需要把webpacker.yml中的extract_css改为true，其他保持不动。environment.js是针对所有环境的pack的配置。某种程度上来说，也可以在javascript/packs/application.js中达到同样的效果。

### Sprockets 4
针对CSS，你可以继续沿用Sprockets。配置文件为 app/assets/config/manifest.js。

以上部分基本是[这篇文章][1]的前半部分。剩下就是如何在Rails 6中使用JQuery。

如果你是Rails 5之前升级过来的，为了减少你的工作量，而且你也不需要做一个类似app的网站，继续沿用Sprockets。
如果你打算改成类似app的网站，比如大量使用React，你可以开始尝试webpack。

## 添加JQuery

### Solution 1

按照[https://inopinatus.org/2019/09/14/webpacker-jquery-and-jquery-plugins/][3]的方法，你可以用`externals`，如果你的项目通过sprockets引入了JQuery。

```javascript
// config/webpack/environment.js
environment.config.merge({
  externals: {
    jquery: 'jQuery'
  }
})
```

### Solution 2

在`layouts/application.html.erb`中`<%= javascript_pack_tag 'application', 'data-turbolinks-track': 'reload' %>`导致所有的页面都默认加载了application.js，所以可以在application.js中引入JQuery即可。

```javascript
// app/javascript/packs/application.js
import $ from 'jquery'
```

*但是*，我需要强调的是，这个改动会让所有的packs都可以使用JQuery，但是在html页面里面直接调用`$`是会报错的。这个是因为webpack里面有一个namespace的概念，即这个`$`只在所有的packs里面可以使用，但全局变量里面你找不到它。

如果你希望它全局可用，再多加一行`window.$ = $;`即可。

但我总觉得，你都用webpack了，所有的事情都按照webpack的pattern啊。这样总觉得不伦不类。

这个时候，你就可以把html里面的JavaScript移到pack里面去。比如增加下面一行。

```javascript
// app/javascript/packs/application.js
$( () => {
  $('#example').DataTable();
})

```

### Solution 3

除了在`app/javascript/packs/application.js`里面引入JQuery，还有一个办法是在 `config/webpack/environment.js`中引入JQuery。

```javascript
// config/webpack/environment.js
const { environment } = require('@rails/webpacker')
const webpack = require('webpack')

environment.plugins.append('Provide',
  new webpack.ProvidePlugin({
    $: 'jquery',
    jQuery: 'jquery',
    jquery: 'jquery'
  })
)

module.exports = environment
```

这个等效于你在`app/javascript/packs/application.js`里面`import $ from 'jquery'`。

[https://aarvy.me/blog/2019/09/21/datatables-with-bootstrap-4-minimal-setup-in-rails-6/][4]创建了一个demo的repo，可以自己clone下来试试上面的方法。

## 添加DataTables

在需要用datatables的packs最上面`require( 'datatables.net-bs4')`就可以在pack中使用`$().DataTable()`了。

## More about Webpack

下面更多的是关于webpack，已经超过了这个标题所描述的范围了。

通过rails升级过来的，还需要运行`rails webpacker:install`来安装webpacker。安装完以后，就会多出这样的配置文件。

```bash
// config/webpack/
config
│   ...
├── webpack
│   ├── development.js
│   ├── environment.js
│   ├── production.js
│   └── test.js
└── webpacker.yml
```

webpacker.yml 不仅是`webpacker`gem包使用，还被`@rails/webpacker`使用。webpacker.yml里面配置了pack的源文件，输出文件等配置信息。

```yml
# config/webpacker.yml
default: &default
  source_path: app/javascript
  source_entry_path: packs
  public_root_path: public
  public_output_path: packs
  cache_path: tmp/cache/webpacker
```

`webpack/*.js` 等效于 `webpack.config.js`，其中`config/webpack/environment.js`是给各个环境共享。


[1]: https://blog.capsens.eu/how-to-write-javascript-in-rails-6-webpacker-yarn-and-sprockets-cdf990387463
[2]: https://kangax.github.io/compat-table/es6/
[3]: https://inopinatus.org/2019/09/14/webpacker-jquery-and-jquery-plugins/
[4]: https://aarvy.me/blog/2019/09/21/datatables-with-bootstrap-4-minimal-setup-in-rails-6/
[5]: https://rossta.net/blog/how-to-use-webpacker-yml.html
[6]: https://rossta.net/blog/how-to-customize-webpack-for-rails-apps.html

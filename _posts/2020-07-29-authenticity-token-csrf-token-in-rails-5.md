---
layout: default
title: Authenticity_token & csrf_token in Rails 5
date: 2020-07-29 16:34 +0800
categories: rails
---
**Table of Contents**

- [Environment](#environment)
- [基础知识](#%E5%9F%BA%E7%A1%80%E7%9F%A5%E8%AF%86)
- [csrf-token的生成](#csrf-token%E7%9A%84%E7%94%9F%E6%88%90)
- [Form authenticity_token的生成](#form-authenticity_token%E7%9A%84%E7%94%9F%E6%88%90)
- [csrf_token的验证](#csrf_token%E7%9A%84%E9%AA%8C%E8%AF%81)
- [Decode Session Cookie](#decode-session-cookie)
  - [secret_key_base](#secret_key_base)


这边文章是基于[深入 Rails 中的 CSRF Protection][中文帖子]和[A Deep Dive into CSRF Protection in Rails][rails_csrf_token]写的。

## Environment
这篇文章是基于Rails 5.2 默认配置，如果是从Rails 4 升级过来的，可能会有出入。

## 基础知识
Rails的CSRF会被存到3个地方，一个是`session cookie`中，一个是`meta`标签中，最后一个是表单的`authenticity_token`中。当发送`POST`请求，表单的`authenticity_token`会被发送到服务器。`Rails`会验证`session`中的`csrf_token`和传过来的`authenticity_token`。如果是`Javascript`，则会取`meta`中的`csrf_token`，同样发送到后端去验证。[深入 Rails 中的 CSRF Protection][中文帖子]好像只提到了`meta`中`csrf_token`的情况，没有提及表单中的`authenticity_token`这种情况。

## csrf-token的生成
在`application_controller.rb`中加入`protect_from_forgery`即可。

```ruby
class ApplicationController < ActionController::Base
  protect_from_forgery
end
```

在`application.html.erb`会有如下的文件

```erb
<%= csrf_meta_tags %>
```

这里就会调用`csrf_meta_tags`方法。
```ruby
# actionview-5.2.4.1/lib/action_view/helpers/csrf_helper.rb
def csrf_meta_tags
  if protect_against_forgery?
    [
      tag("meta", name: "csrf-param", content: request_forgery_protection_token),
      tag("meta", name: "csrf-token", content: form_authenticity_token)
    ].join("\n").html_safe
  end
end
```

进而调用`form_authenticity_token`。在meta标签中，`action`和`method`都是`nil`。所以，直接调用`real_csrf_token`。注意，这里就会把`_csrf_token`写入session cookie中。后面会有代码去把整个cookie decrypt出来，就可以看到了。

```ruby
# actionpack-5.2.4.1/lib/action_controller/metal/request_forgery_protection.rb
# Sets the token value for the current session.
def form_authenticity_token(form_options: {})
  masked_authenticity_token(session, form_options: form_options)
end

def masked_authenticity_token(session, form_options: {}) # :doc:
  action, method = form_options.values_at(:action, :method)

  raw_token = if per_form_csrf_tokens && action && method
    action_path = normalize_action_path(action)
    per_form_csrf_token(session, action_path, method)
  else
    real_csrf_token(session)
  end

  one_time_pad = SecureRandom.random_bytes(AUTHENTICITY_TOKEN_LENGTH)
  encrypted_csrf_token = xor_byte_strings(one_time_pad, raw_token)
  masked_token = one_time_pad + encrypted_csrf_token
  Base64.strict_encode64(masked_token)
end

def real_csrf_token(session) # :doc:
  session[:_csrf_token] ||= SecureRandom.base64(AUTHENTICITY_TOKEN_LENGTH)
  Base64.strict_decode64(session[:_csrf_token])
end
```

这里生成的`raw_token`是32位长的。后续就是加密工作了，具体可以参考[深入 Rails 中的 CSRF Protection][中文帖子]。简单来说，需要再生成一个`one_time_pad`，然后和`raw_token`做异或操作，再把`one_time_pad`拼到前面去，最后再做一个Base64 encode。


## Form authenticity_token的生成
和meta标签类似，在生成form的时候，会调`token_tag`。

```ruby
# actionview-5.2.4.1/lib/action_view/helpers/form_tag_helper.rb
def form_tag_html(html_options)
  extra_tags = extra_tags_for_form(html_options)
  tag(:form, html_options, true) + extra_tags
end

def extra_tags_for_form(html_options)
  authenticity_token = html_options.delete("authenticity_token")
  method = html_options.delete("method").to_s.downcase

  method_tag = \
    case method
    when "get"
      # ...
    when "post", ""
      html_options["method"] = "post"
      token_tag(authenticity_token, form_options: {
        action: html_options["action"],
        method: "post"
      })
    else
      html_options["method"] = "post"
      method_tag(method) + token_tag(authenticity_token, form_options: {
        action: html_options["action"],
        method: method
      })
    end

  if html_options.delete("enforce_utf8") { true }
    # ...
  else
    method_tag
  end
end
```

同样，又跑到`form_authenticity_token`方法里面了，这次不同的地方就是，有了`action`和`method`。

```ruby
# actionview-5.2.4.1/lib/action_view/helpers/url_helper.rb
def token_tag(token = nil, form_options: {})
  if token != false && protect_against_forgery?
    token ||= form_authenticity_token(form_options: form_options)
    tag(:input, type: "hidden", name: request_forgery_protection_token.to_s, value: token)
  else
    "".freeze
  end
end
```

在Rails 5中，默认是开启`per_form_csrf_tokens`。如果是Rails 4升级过来的，就是`false`。与meta生成的token不同的地方就是，这里会把`real_csrf_token`和`action`与`method`放在一起，做一次加密，赋值给`raw_token`。后面就和上面meta标签中生成的token的逻辑一样，生成一个`one_time_pad`，然后和`raw_token`做异或操作，再把`one_time_pad`拼到前面去，最后再做一个Base64 encode。

```ruby
# actionpack-5.2.4.1/lib/action_controller/metal/request_forgery_protection.rb
def masked_authenticity_token(session, form_options: {}) # :doc:
  action, method = form_options.values_at(:action, :method)

  raw_token = if per_form_csrf_tokens && action && method
    action_path = normalize_action_path(action)
    per_form_csrf_token(session, action_path, method)
  else
    # ...
  end
  # ...
end

def per_form_csrf_token(session, action_path, method) # :doc:
  OpenSSL::HMAC.digest(
    OpenSSL::Digest::SHA256.new,
    real_csrf_token(session),
    [action_path, method.downcase].join("#")
  )
end
```

## csrf_token的验证
无论是HTML POST请求，还是JavaScript的XHR请求，都会传入`authenticity_token`，拿这个和session cookie中的`csrf_token`做对比就行了。

再看看当初在`application_controller.rb`里面加入的`protect_from_forgery`，它会加入一个`before_action`的`verify_authenticity_token`。

```ruby
# actionpack-5.2.4.1/lib/action_controller/metal/request_forgery_protection.rb
def protect_from_forgery(options = {})
  options = options.reverse_merge(prepend: false)

  self.forgery_protection_strategy = protection_method_class(options[:with] || :null_session)
  self.request_forgery_protection_token ||= :authenticity_token
  before_action :verify_authenticity_token, options
  append_after_action :verify_same_origin_request
end
```

验证开始了。`verify_authenticity_token`中我们需要真正关注的是`any_authenticity_token_valid?`.

```ruby
def verify_authenticity_token # :doc:
  # ...

  if !verified_request?
    # ...
  end
end

def verified_request? # :doc:
  !protect_against_forgery? || request.get? || request.head? ||
    (valid_request_origin? && any_authenticity_token_valid?)
end
```

由参数传过来的`authenticity_token`和request header中的`X-CSRF-TOKEN`,只要有一个验证通过即可。

```ruby
def any_authenticity_token_valid? # :doc:
  request_authenticity_tokens.any? do |token|
    valid_authenticity_token?(session, token)
  end
end

def request_authenticity_tokens # :doc:
  [form_authenticity_param, request.x_csrf_token]
end
```
真正的验证开始了，其实就是将生成的步骤反过来一次。先将`authenticity_token`用Base64 decode一次，取前32位位`one_time_pad`，再和后32位做异或操作，取回`csrf_token`。这个`csrf_token`可能是meta 标签中的`csrf_token`，也可能是表单中的`authenticity_token`。所以要判断两次，一次`compare_with_real_token(csrf_token, session)`，另外一次`valid_per_form_csrf_token?(csrf_token, session)`。

```ruby
def valid_authenticity_token?(session, encoded_masked_token) # :doc:
  # ...

  begin
    masked_token = Base64.strict_decode64(encoded_masked_token)
  rescue ArgumentError # encoded_masked_token is invalid Base64
    return false
  end

  # See if it's actually a masked token or not. In order to
  # deploy this code, we should be able to handle any unmasked
  # tokens that we've issued without error.

  if masked_token.length == AUTHENTICITY_TOKEN_LENGTH
    # ...
  elsif masked_token.length == AUTHENTICITY_TOKEN_LENGTH * 2
    csrf_token = unmask_token(masked_token)

    compare_with_real_token(csrf_token, session) ||
      valid_per_form_csrf_token?(csrf_token, session)
  else
    false # Token is malformed.
  end
end

def unmask_token(masked_token) # :doc:
  # Split the token into the one-time pad and the encrypted
  # value and decrypt it.
  one_time_pad = masked_token[0...AUTHENTICITY_TOKEN_LENGTH]
  encrypted_csrf_token = masked_token[AUTHENTICITY_TOKEN_LENGTH..-1]
  xor_byte_strings(one_time_pad, encrypted_csrf_token)
end
```

对于`compare_with_real_token`，直接把`csrf_token`和`session`中的`csrf_token`对比即可。

对于`valid_per_form_csrf_token?`，用`session`中的`csrf_token`和`action`与`method`放在一起加密，再把生成的密文和`csrf_token`做对比。

```ruby
def compare_with_real_token(token, session) # :doc:
  ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, real_csrf_token(session))
end

def valid_per_form_csrf_token?(token, session) # :doc:
  if per_form_csrf_tokens
    correct_token = per_form_csrf_token(
      session,
      normalize_action_path(request.fullpath),
      request.request_method
    )

    ActiveSupport::SecurityUtils.fixed_length_secure_compare(token, correct_token)
  else
    false
  end
end
```

## Decode Session Cookie
基于Rails 5.2, 可以用下面的方法decrypt session cookie。
<script src="https://gist.github.com/inopinatus/e523f36b468f94cf6d34410b73fef15e.js"></script>

### secret_key_base

对于`secret_key_base`, Rails 5.2是保存在`config/credentials.yml.enc`中。该文件是加密的，加密的`key`是保存在`config/master.key`中。可以用`EDITOR='vi' rails credentials:edit`查看。也可以用`secrets.yml`的方式。还可以用`config/initializers/secret_token.rb`，直接设置`Rails.application.config.secret_key_base = ''`。参见Stack Overflow上的[回答][so_secret_key_base]。

## FAQ

Q: 为什么同时开多个页面，它们的`authenticity_token`都是不同的，但是都是有效的？

A: 每次打开新的页面，`session`中的`csrf_token`是一样的，但是每次的`one_time_pad`是不一样的，所以每个`authenticity_token`都不一样。


[中文帖子]: https://ruby-china.org/topics/35199
[rails_csrf_token]: https://medium.com/rubyinside/a-deep-dive-into-csrf-protection-in-rails-19fa0a42c0ef
[so_secret_key_base]: https://stackoverflow.com/questions/49782241/separate-secret-key-base-in-rails-5-2

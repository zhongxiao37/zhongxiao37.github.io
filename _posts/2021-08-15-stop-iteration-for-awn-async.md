---
layout: default
title: Stop iteration for AWN.async
date: 2021-08-15 23:19 +0800
categories: javascript
---

自己在用[awesome-notification](https://f3oall.github.io/awesome-notifications/docs/toasts/async)作为自己项目的notification，但是遇到一个问题。在循环中想要通过`onReject`来中断循环，但是发现不可行。原因是代码中在处理`onReject`的时候，返回的其实是一个promise，即下一个循环开始以后，才会回来执行`onReject`。这样就导致没法中断下一个循环。

```javascript
async (promise, onResolve, onReject, msg, options) {
    let asyncToast = this._addToast(msg, "async", options)
    return this._afterAsync(promise, onResolve, onReject, options, asyncToast)
  }

_afterAsync(promise, onResolve, onReject, options, oldElement) {
    return promise.then(
      this._responseHandler(onResolve, "success", options, oldElement),
      this._responseHandler(onReject, "alert", options, oldElement)
    )
  }

_responseHandler(payload, toastName, options, oldElement) {
  return result => {
    switch (typeof payload) {
      case 'undefined':
      case 'string':
        let msg = toastName === 'alert' ? payload || result : payload
        this._addToast(msg, toastName, options, oldElement)
        break
      default:
        oldElement.delete().then(() => {
          if (payload) payload(result)
        })
    }
  }
}

_addToast(msg, type, options, old) {
  options = this.options.override(options)
  let newToast = new Toast(msg, type, options, this.container)
  if (old) {
    if (old instanceof Popup) return old.delete().then(() => newToast.insert())
    let i = old.replace(newToast)
    return i
  }
  return newToast.insert()
}
```

解决方法是，`catch`住第一个`promise`，然后额外处理，然后再重新返回`Promise.reject`。在下面例子中，我对`fetch()`加了额外的`.catch((err) => handleReject(err, flags))`来做特殊处理。

```javascript
import AWN from "awesome-notifications";
let notifier = new AWN();

async function handleReject(err, flags) {
  console.log(err);
  flags.stop_iter = true;
  await Promise.reject("Something got wrong, contact tech support");
}

async function onRefreshAllClick(e) {
  e.preventDefault();
  await notifier.async(
        fetch(elements[table_name].href, {
          method: "POST",
          body: JSON.stringify(data),
          headers: {
            "Content-Type": "application/json",
          },
        }).catch((err) => handleReject(err, flags)),
        handleResult,
        undefined,
        `Refreshing ${table_name}`
      );
}
```
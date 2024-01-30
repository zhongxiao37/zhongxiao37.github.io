---
layout: default
title: async in python/javascript/golang/ruby
date: 2022-09-04 16:35 +0800
categories: async python go javascript
---

最近在看 Golang，看到了协程调度器的时候，突然想起 Javascript 的 event loop，觉得把这些东西对比起来的时候，真是有趣。顺手把 Python 的`asyncio`也看了一遍，发现在并发上面，`Golang`真的是炸天的存在。

我也不能够免俗，故事还是要从头开始。

## 单线程

下面的例子显示了，如果只有一个线程，那么就会处理完一个以后才会处理另外一个。所以第一个`delay_message`消耗了 2 秒，第二个`delay_message`消耗了 3 秒。

```python
import logging
import time
logger_format = '%(asctime)s:%(threadName)s:%(message)s'
logging.basicConfig(format=logger_format, level=logging.INFO, datefmt="%H:%M:%S")

num_word_mapping = {1: 'ONE', 2: 'TWO', 3: "THREE", 4: "FOUR", 5: "FIVE", 6: "SIX", 7: "SEVEN", 8: "EIGHT",
                   9: "NINE", 10: "TEN"}

def delay_message(delay, message):
    logging.info(f"{message} received")
    time.sleep(delay)
    logging.info(f"Printing {message}")

def main():
    logging.info("Main started")
    delay_message(2, num_word_mapping[2])
    delay_message(3, num_word_mapping[3])
    logging.info("Main Ended")

main()
```

输出

```bash
20:05:41:MainThread:Main started
20:05:41:MainThread:TWO received
20:05:43:MainThread:Printing TWO
20:05:43:MainThread:THREE received
20:05:46:MainThread:Printing THREE
20:05:46:MainThread:Main Ended
```

## 多线程

如果我们启多个线程，那么就可以节约时间了。

```python
import logging
import time
import threading

logger_format = '%(asctime)s:%(threadName)s:%(message)s'
logging.basicConfig(format=logger_format, level=logging.INFO, datefmt="%H:%M:%S")

num_word_mapping = {1: 'ONE', 2: 'TWO', 3: "THREE", 4: "FOUR", 5: "FIVE", 6: "SIX", 7: "SEVEN", 8: "EIGHT",
                   9: "NINE", 10: "TEN"}

def delay_message(delay, message):
    logging.info(f"{message} received")
    time.sleep(delay)
    logging.info(f"Printing {message}")

def main():
    logging.info("Main started")
    threads = [threading.Thread(target=delay_message, args=(delay, message)) for delay, message in zip([2, 3],
                                                                            [num_word_mapping[2], num_word_mapping[3]])]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join() # waits for thread to complete its task
    logging.info("Main Ended")
main()
```

```bash
20:28:48:MainThread:Main started
20:28:48:Thread-1:TWO received
20:28:48:Thread-2:THREE received
20:28:50:Thread-1:Printing TWO
20:28:51:Thread-2:Printing THREE
20:28:51:MainThread:Main Ended
```

由于 GIL 的存在，一次只有一个线程在执行，中间线程的切换会有一定的开销。此外，如果你的 CPU 内核支持多线程，但是由于 GIL 的存在，始终还是只有一个内核线程被占用着。
至于 GIL 的存在，是因为 2000 年前，那个时候 CPU 厂商都努力在提升单个 CPU 的频率上。2000 年之后才转为多核发展，但是 Python 是 1991 年出现的语言，显然没有办法预见到多核的情况。

## 线程池

因为线程的创建和销毁会消耗一些时间，可以提前创建一些线程备用，用完还回来。

```python
import concurrent.futures as cf
import logging
import time

logger_format = '%(asctime)s:%(threadName)s:%(message)s'
logging.basicConfig(format=logger_format, level=logging.INFO, datefmt="%H:%M:%S")

num_word_mapping = {1: 'ONE', 2: 'TWO', 3: "THREE", 4: "FOUR", 5: "FIVE", 6: "SIX", 7: "SEVEN", 8: "EIGHT",
                    9: "NINE", 10: "TEN"}


def delay_message(delay, message):
    logging.info(f"{message} received")
    time.sleep(delay)
    logging.info(f"Printing {message}")
    return message


if __name__ == '__main__':
    with cf.ThreadPoolExecutor(max_workers=2) as executor:
        future_to_mapping = {executor.submit(delay_message, i, num_word_mapping[i]): num_word_mapping[i] for i in
                             range(2, 4)}
        for future in cf.as_completed(future_to_mapping):
            logging.info(f"{future.result()} Done")

```

输出

```bash
21:55:58:ThreadPoolExecutor-0_0:TWO received
21:55:58:ThreadPoolExecutor-0_1:THREE received
21:56:00:ThreadPoolExecutor-0_0:Printing TWO
21:56:00:MainThread:TWO Done
21:56:01:ThreadPoolExecutor-0_1:Printing THREE
21:56:01:MainThread:THREE Done
```

## 单线程可以达到这样的效果么？

这个时候`asyncio`就出场了。像下面输出的一样，一直都只有一个线程，效果却和多线程一样快。这是因为协程的存在。Python 的实现和 Javascript 很类似，`await`背后实际上是把这个放到 event loop 里面去，等 ready 了以后再回来执行。比如你可以通过 https://jishuin.proginn.com/p/763bfbd571d2 获取到 event loop，并且执行一个个的 task。

```python
import asyncio
import logging
import time

logger_format = '%(asctime)s:%(threadName)s:%(message)s'
logging.basicConfig(format=logger_format, level=logging.INFO, datefmt="%H:%M:%S")

num_word_mapping = {1: 'ONE', 2: 'TWO', 3: "THREE", 4: "FOUR", 5: "FIVE", 6: "SIX", 7: "SEVEN", 8: "EIGHT",
                   9: "NINE", 10: "TEN"}

async def delay_message(delay, message):
    logging.info(f"{message} received")
    await asyncio.sleep(delay) # time.sleep is blocking call. Hence, it cannot be awaited and we have to use asyncio.sleep
    logging.info(f"Printing {message}")

async def main():
    logging.info("Main started")
    logging.info("Creating multiple tasks with asyncio.gather")
    await asyncio.gather(*[delay_message(i+1, num_word_mapping[i+1]) for i in range(5)]) # awaits completion of all tasks
    logging.info("Main Ended")

if __name__ == '__main__':

    asyncio.run(main()) # creats an envent loop

```

```bash
21:58:48:MainThread:Main started
21:58:48:MainThread:Creating multiple tasks with asyncio.gather
21:58:48:MainThread:ONE received
21:58:48:MainThread:TWO received
21:58:48:MainThread:THREE received
21:58:48:MainThread:FOUR received
21:58:48:MainThread:FIVE received
21:58:49:MainThread:Printing ONE
21:58:50:MainThread:Printing TWO
21:58:51:MainThread:Printing THREE
21:58:52:MainThread:Printing FOUR
21:58:53:MainThread:Printing FIVE
21:58:53:MainThread:Main Ended
```

此外，协程也避免了多线程编程里面的线程安全问题，因为只有一个线程在跑。

## 多进程

对于 CPU 密集型的计算，可以用多进程来提高效率。理论上，两个进程可以*并行*执行。

## Javascript 的 async & await

Javascript 是单线程语言，注定没法像 Python 那样玩多线程，所以它需要用类似于协程一样的方式来加快速度。

https://www.bilibili.com/video/BV1K4411D7Jb?spm_id_from=333.999.0.0&vd_source=ccb844cf1abcd244b61c04c8b5ac741c

Javascript 里面有 event loop 和微任务。callback 算是 event loop；promise 和 await 是微任务。微任务只在堆栈(包括 tasks 队列，Animation callback 队列)被清空的时候执行。微任务也可能阻塞页面的渲染。

下面两个例子可以帮助你理解微任务是什么时候执行的。

<img src="/images/javascript_micro_task_queue.png" width="800px">
<img src="/images/javascript_micro_task_queue2.png" width="800px">

### Javascript 的 event loop, API, V8

https://www.bilibili.com/video/BV1oV411k7XY/?spm_id_from=333.788.recommend_more_video.0&vd_source=ccb844cf1abcd244b61c04c8b5ac741c

WebAPI 提供了 SetTimeout API，通过调用这个 API，在适当的时间点，callback 会出现在 event loop 里面，即使之前 stack 已经空掉了。

<img src="/images/javascript_web_api_event_loop.png" width="800px">

## Golang 的协程

Golang 的协程又是另外一种实现方式。

如下图，有多个线程，一个逻辑处理器 P 绑定一个线程 M。一般 P 设置为 CPU 内核数，即同时可以有多少个线程并行执行。当其中 G1 阻塞的时候，就会创建新的线程 M2，然后把 G2 给新的线程 M2。原来的 M1 还是继续执行 G1，直到结束。

这个时候，就不再是单线程了，而是多线程，并且通过通道的方式来避免线程安全问题。加上没有 GIL 的存在，可以充分的利用 CPU 的资源了。

![img](/images/golang-gpm.png)

# Reference

1. https://medium.com/analytics-vidhya/asyncio-threading-and-multiprocessing-in-python-4f5ff6ca75e8

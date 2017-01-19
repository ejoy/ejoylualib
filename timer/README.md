时间轮定时器
============

这个定时器并不直接取系统时钟，而需要外部驱动。这个库是系统无关的。其实现在 skynet 中已经得到了长时间的使用。这里只是单独拿出来封装成一个 lua 库。

编译
====

这个库由 C 和 Lua 两部分构成，Lua 部分 timer.lua 依赖 C 库。

独立库用 `gcc --shared -o timer.dll timer.c` 并加上 lua 的头文件及库文件依赖。

嵌入应用直接包含 timer.c 文件，然后在 host 中调用 `luaL_requiref(L, "timer.core", luaopen_timer_core, 0);`

API
===

C 库的接口包含在 timer.core 中，并不直接调用。C 库可以通过 create 创建一个 userdata 管理定时器，用 release 销毁。add 用于添加一个 session 到管理器，session 必须为 32bit 整数，且调用者保证不重复。update 可让定时器管理器步进若干个心跳。

Lua 封装库构造了唯一一个 C 管理器对象，由 __gc 销毁它，使用时不用关心。

`timer.timeout(obj, message, interval, arg)` 用于创建一个一次性的定时消息。obj 应该为一个 table 或 full userdata ，message 为一个字符串， interval 是一个浮点数，单位是秒。定时器内部精度为 1/100 秒。arg 将被传入 update 函数。这个函数会返回一个数字 id 用于 cancel 。

`timer.timeloop(obj, message, interval, arg)` 用于创建一个持续触发的定时消息。参数和 timer.timeout 含义相同。

`timer.cancel_message(obj, message)` 取消附着在 obj 上的所有 message 定时器消息。

`timer.cancel_id(obj, id)` 取消指定 id 的消息，需要传入创建时相同的 object 。

`timer.stop(obj)` 取消当前附着在 obj 上所有的定时器消息。

`timer.update(elapse, func, err_handle)` 由框架驱动，执行之前订阅的定时消息。elapse 是一个单位为秒的浮点数，表示从当前时间开始流逝了多长时间。这此期间内的定时消息会依次调用 func(obj, message, arg) 。在 func 函数中，可以调用 timer.* 其它函数去订阅/取消消息。 err_handle(errstr) 默认为 print ，输出错误信息。

`timer.now()` 可以取得当前时间。

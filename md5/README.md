编译
====

独立库用 `gcc --shared -o md5.dll md5.c` 并加上 lua 的头文件及库文件依赖。

嵌入应用直接包含 md5.c 文件，然后在 host 中调用 `luaL_requiref(L, "md5", luaopen_md5, 0);`

API
===

md5(string)  传入一个字符串，以小写 16 进制可读形式返回字符串的 md5 。

md5(function) 传入一个函数，不断调用这个函数，取得字符串返回值，一直到函数返回 nil 停止。将这一系列返回值连接起来计算 md5 。

使用
====

```lua
local md5 = require "md5"

print(md5 "")	-- d41d8cd98f00b204e9800998ecf8427e
print(md5 "abc") -- 900150983cd24fb0d6963f7d28e17f72

local f = io.open "README.md"	-- 对文件流做 md5
print(md5(function() return f:read(64) end))	-- 每次读 64 字节返回，最后返回 nil
f:close()
```

测试
====

test.lua 里有一系列测试串，test.lua 不需要包含在最终工程中。




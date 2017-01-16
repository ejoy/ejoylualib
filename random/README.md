伪随机数发生器
==============

算法来自于 http://marc-b-reynolds.github.io/shf/2016/04/19/prns.html

编译
====

独立库用 `gcc --shared -o random.dll random.c` 并加上 lua 的头文件及库文件依赖。

嵌入应用直接包含 random.c 文件，然后在 host 中调用 `luaL_requiref(L, "random", luaopen_random, 0);`

API
===

使用 g = random(seed) 获得一个随机数发生器函数，之后可以调用这个函数 g 产生伪随机数。g 的参数和 math.random 相同。seed 必须为一个整数。

在不带参数时，产生一个 [0,1) 间的浮点随机数，带一个整数参数时，产生 [1, n] 的整数随机数，带两个整数参数时，产生 [m,n] 的整数随机数。

同时，这个模块支持 C 接口（仅兼容整数版本），可以在 C 里直接调用，获得和 Lua API 一致的结果：

`void random_init(struct random_t *rd, uint64_t seed)` 用 seed 初始化一个随机数发生器。

`uint64_t random_get(struct random_t *rd)` 获得一个 64 位随机数。

`int random_range(struct random_t *rd, int range)` 获得 [0, range) 间的一个随机数。

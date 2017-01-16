local md5 = require "md5"

local testfile = "README.md"

-- test some known sums
assert(md5("") == "d41d8cd98f00b204e9800998ecf8427e")
assert(md5("a") == "0cc175b9c0f1b6a831c399e269772661")
assert(md5("abc") == "900150983cd24fb0d6963f7d28e17f72")
assert(md5("message digest") == "f96b697d7cb7938d525a2f31aaf161d0")
assert(md5("abcdefghijklmnopqrstuvwxyz") == "c3fcd3d76192e4007dfb496cca67e13b")
assert(md5("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
 == "d174ab98d277d9f5a5611c2c9f419d9f")

-- test padding borders
assert(md5(string.rep('a',53)) == "e9e7e260dce84ffa6e0e7eb5fd9d37fc")
assert(md5(string.rep('a',54)) == "eced9e0b81ef2bba605cbc5e2e76a1d0")
assert(md5(string.rep('a',55)) == "ef1772b6dff9a122358552954ad0df65")
assert(md5(string.rep('a',56)) == "3b0c8ac703f828b04c6c197006d17218")
assert(md5(string.rep('a',57)) == "652b906d60af96844ebd21b674f35e93")
assert(md5(string.rep('a',63)) == "b06521f39153d618550606be297466d5")
assert(md5(string.rep('a',64)) == "014842d480b571495a4a0363793f7367")
assert(md5(string.rep('a',65)) == "c743a45e0d2e6a95cb859adae0248435")
assert(md5(string.rep('a',255)) == "46bc249a5a8fc5d622cf12c42c463ae0")
assert(md5(string.rep('a',256)) == "81109eec5aa1a284fb5327b10e9c16b9")

assert(md5(function() return nil end) == md5 "")

local f = io.open(testfile, "rb")
local result = md5(f:read"a")
f:close()

local function foo(bytes)
	local f = io.open(testfile, "rb")
	local r = md5(function() return f:read(bytes) end)
	assert(result == r)
	f:close()
end

foo(1)
foo(2)
foo(3)
foo(63)
foo(64)
foo(65)

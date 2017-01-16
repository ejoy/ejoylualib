local random = require "random"

local r = random(0)	-- random generator with seed 0
local r2 = random(0)

for i=1,10 do
	local x = r()
	assert(x == r2())
	print(x)
end

for i=1,10 do
	local x = r(2)
	assert(x == r2(2))
	print(x)
end

for i=1,10 do
	local x = r(0,3)
	assert(x == r2(0,3))
	print(x)
end

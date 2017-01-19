local timer = require "timer"

local function create_obj(name)
	local obj = setmetatable({} , { __tostring = function(self) return self.__name end })
	obj.__name = name
	return obj
end

local obj_A = create_obj "A"
local obj_B = create_obj "B"

timer.timeloop(obj_A, "timerA", 0.7)
timer.timeout(obj_B, "stopA", 3.6)
timer.timeout(obj_B, "cancel", 3.7)
timer.timeout(obj_B, "timerB", 4)

local function execute(obj, message)
	if obj == obj_A then
		print(timer.now(), obj, message)
	elseif obj == obj_B then
		if message == "stopA" then
			print(message, timer.now())
			timer.stop(obj_A)
		elseif message == "cancel" then
			print(message, timer.now())
			timer.cancel(obj_B, "timerB")
		else
			print(timer.now(), obj, message)
		end
	end
end

timer.update(2.9, execute)
timer.update(0.5, execute)
timer.update(0.6, execute)

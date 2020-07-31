local timer = require "timer"

local function create_obj(name)
	local obj = setmetatable({} , { __tostring = function(self) return self.__name end })
	obj.__name = name
	return obj
end

local obj_A = create_obj "A"
local obj_B = create_obj "B"

local loop_id = timer.timeloop(obj_A, "timerA", 0.7)
timer.timeout(obj_B, "stop", 3.6 , obj_A)
timer.timeout(obj_B, "cancel", 3.7, "timerB")
timer.timeout(obj_B, "timerB", 4)
local id = timer.timeout(obj_B, "timer", 2)

local function execute(obj, message, arg)
	if obj == obj_A then
		print(timer.now(), obj, message)
	elseif obj == obj_B then
		if message == "stop" then
			print(message, timer.now())
			timer.stop(arg)
		elseif message == "cancel" then
			print(message, timer.now())
			timer.cancel_message(obj_B, arg)
		else
			print(timer.now(), obj, message)
		end
	end
end

timer.cancel_id(obj_B, id)
timer.update(2.9, execute)
timer.cancel_id(obj_A, loop_id)
timer.update(0.5, execute)
timer.update(0.6, execute)

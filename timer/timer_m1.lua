-- 兼容 m1 客户端的 timer 接口

local timer = require "timer"

local DUMMY = {}	-- dummy object

local function wrap(cb, ...)
	local args = table.pack(...)
	return function()
		cb(table.unpack(args,1,args.n))
	end
end

function timer.set_timeout(interval, cb, ...)
	return timer.timeout(DUMMY, "timeout", interval, wrap(cb, ...))
end

function timer:begin(...)
	return self.set_timeout(...)
end

local loop_id = 0
function timer:begin_loop(interval, cb, ...)
	loop_id = loop_id + 1
	local name = "timeloop:" .. loop_id
	timer.timeloop(DUMMY, name, interval, wrap(cb, ...))
	return name
end

function timer:cancel(id)
	if type(id) == "string" then
		timer.cancel_message(id)
	else
		timer.cancel_id(id)
	end
end

function timer:counter(start_sec, interval, cb, ...)
	local id
	local name = "timecount:" .. loop_id
	local args = table.pack(...)
	local function f()
		cb(table.unpack(args,1,args.n))
		start_sec = start_sec - interval
		if start_sec > 0 then
			id = timer.timeout(DUMMY, name, interval, f)
		end
	end
	id = timer.timeout(DUMMY, name, interval, f)
	return { id = id }
end

function timer:uncounter(c)
	timer.cancel_id(c.id)
end

function timer:frame_timer(frame_cnt, cb, ...)
	local time = frame_cnt * 0.033
	return timer.set_timeout(time, cb, ...)
end

local function m1_update(obj, message, args)
	if obj == DUMMY then
		assert(type(args) == "function")
		args()
	else
		-- todo: dispatch other messages to obj with args
	end
end

function timer:update_m1(elapse)
	timer.update(elapse, m1_update, print)
end





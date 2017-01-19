local core = require "timer.core"

local cobj = core.create()
local timer = setmetatable({}, { __gc = function() core.release(cobj) end })

local precision = 100
local time = 0
local floor = math.floor

function timer.now()
	return time
end

local function new_object(self, k)
	local t = type(k)
	if t == "number" then
		return nil
	end
	-- k is object
	assert(t == "table" or t == "userdata")
	local id = #self + 1
	self[id] = k
	self[k] = id
	return id
end

local objects = setmetatable({} , { __mode = "kv", __index = new_object })

local session = {}
local session_id = 0

local function add_timer(ti)
	repeat
		session_id = (session_id + 1) & 0xffffffff
	until session[session_id] == nil
	core.add(cobj, session_id, ti)
	return session_id
end

function timer.timeout(obj, message, ti)
	local timer_id = add_timer(floor(ti * precision))
	local obj_id = objects[obj]
	session[timer_id] = { id = obj_id, message = message }
end

function timer.timeloop(obj, message, interval)
	local timer_id = add_timer(floor(interval * precision))
	local obj_id = objects[obj]
	session[timer_id] = { id = obj_id, message = message, start = time, interval = interval, tick = 1 }
end

function timer.cancel(obj, message)
	-- It's O(n) , optimize when need
	local obj_id = objects[obj]
	for _, t in pairs(session) do
		if t.id == obj_id and t.message == message then
			t.message = nil
		end
	end
end

function timer.stop(obj)
	local obj_id = objects[obj]
	objects[obj] = nil
	objects[obj_id] = nil

	-- It's O(n) , optimize when need
	local obj_id = objects[obj]
	for _, t in pairs(session) do
		if t.id == obj_id then
			t.id = nil
		end
	end
end

local traceback = debug.traceback
local tmp = {}
-- elapse is a real number, 1 for a second. precision is 0.01s
function timer.update(elapse, func, err_handle)
	err_handle = err_handle or print
	local lasttime = floor(time * precision)
	local end_time = time + elapse
	local currenttime = floor(end_time * precision)
	local tick = currenttime - lasttime
	local pp = 1 / precision
	repeat
		local n, e = core.update(cobj, tick, tmp)
		time = time + e * pp
		tick = tick - e
		for i=1,n do
			local id = tmp[i]
			local t = session[id]
			session[id] = nil
			local obj = objects[t.id]
			if obj and t.message then
				local ok, err = xpcall(func, traceback, obj, t.message)
				if not ok then
					err_handle(err)
				end
				if t.interval then
					t.tick = t.tick + 1
					local next_time = t.start + t.tick * t.interval
					local new_id = add_timer(floor((next_time - time) * precision))
					session[new_id] = t
				end
			end
		end
	until tick == 0
	time = end_time
end

return timer

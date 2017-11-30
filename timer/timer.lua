local core = require "timer.core"

local cobj = core.create()
local timer = setmetatable({}, { __gc = function() core.release(cobj) end })

local precision = 100
local time = 0
local floor = math.floor

function timer.now()
	return time
end

local objects = {}
local objects_id = 0

local function new_object(self, k)
	if k == nil then
		return nil
	end
	local t = type(k)
	if t == "number" then
		return nil
	end
	-- k is object
	assert(t == "table" or t == "userdata")
	-- max objects_id 2^52
	objects_id = objects_id + 1
	self[objects_id] = k
	self[k] = objects_id
	return objects_id
end

setmetatable(objects , { __mode = "kv", __index = new_object })

local session = {}
local session_id = 0

local function add_timer(ti)
	repeat
		session_id = (session_id + 1) & 0xffffffff
	until session[session_id] == nil
	core.add(cobj, session_id, ti)
	return session_id
end

function timer.timeout(obj, message, ti, arg)
	local timer_id = add_timer(floor(ti * precision))
	local obj_id = objects[obj]
	session[timer_id] = { id = obj_id, message = message, arg = arg }
	return timer_id
end

function timer.timeloop(obj, message, interval, arg)
	local timer_id = add_timer(floor(interval * precision))
	local obj_id = objects[obj]
	session[timer_id] = { id = obj_id, message = message, start = time, interval = interval, tick = 1 , arg = arg }
	return timer_id
end

function timer.cancel_message(obj, message)
	-- It's O(n) , optimize when need
	local obj_id = objects[obj]
	for _, t in pairs(session) do
		if t.id == obj_id and t.message == message then
			t.id = nil
			t.message = nil
			t.arg = nil
			t.interval = nil
		end
	end
end

function timer.cancel_id(obj, id)
	assert(type(id) == "number")
	local t = session[id]
	if objects[t.id] == obj then
		t.id = nil
		t.message = nil
		t.arg = nil
		t.interval = nil
	end
end

function timer.stop(obj)
	local obj_id = objects[obj]
	objects[obj] = nil
	objects[obj_id] = nil
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
			local obj = objects[t.id]
			if obj then
				local ok, err = xpcall(func, traceback, obj, t.message, t.arg)
				if t.interval then
					t.tick = t.tick + 1
					local next_time = t.start + t.tick * t.interval
					core.add(cobj, id, floor((next_time - time) * precision))
				else
					session[id] = nil
				end
				if not ok then
					err_handle(err)
				end
			else
				session[id] = nil
			end
		end
	until tick == 0
	time = end_time
end

return timer

local routineHandlerMethods = {
	Add = function(self, func, ...)
		if type(func) == "function" and (not self.maxRoutines or #self.list >= self.maxRoutines) then
			local routineID
			repeat
				routineID = math.random(0, 9999)
			until not self.list[routineID]

			local routine = {
				name = false,
				thread = coroutine.create(func),
				filter = nil,
			}

			local ok, passback = coroutine.resume(routine.thread, ...)
			if not ok then
				printError("routineHandler - Add: "..passback)
				return false
			elseif coroutine.status(routine.thread) == "dead" then
				return true
			else
				routine.filter = passback
			end

			self.list[routineID] = routine
			table.insert(self.orderedList, routineID)

			return routineID
		end
		return false
	end,
	Check = function(self, routineID)
		if routineID and self.list[routineID] then
			return coroutine.status(self.list[routineID].thread)
		end
		return false
	end,
	Remove = function(self, routineID)
		if routineID and self.list[routineID] then
			if self.list[routineID].name then
				self.names[self.list[routineID].name] = nil
			end
			self.list[routineID] = nil
			return true
		end
		return false
	end,

	GetName = function(self, routineID)
		if routineID and self.list[routineID] then
			return self.list[routineID].name
		end
		return false
	end,
	SetName = function(self, routineID, name)
		if not (routineID and self.list[routineID]) then
			return false
		elseif type(name) == "string" and not self.names[name] then
			if self.list[routineID].name then
				self.names[self.list[routineID].name] = nil
			end
			self.list[routineID].name = name
			self.names[name] = routineID
			return true
		elseif name == false and self.list[routineID].name then
			self.names[self.list[routineID].name] = nil
			self.list[routineID].name = false
			return true
		end
		return false
	end,
	NameToID = function(self, name)
		return self.names[name] or false
	end,

	HandleEvent = function(self, eventType, ...)
		local newOrderedList = {}
		for _, routineID in ipairs(self.orderedList) do
			local routine = self.list[routineID]
			if routine then
				if routine.filter == nil or routine.filter == eventType or eventType == "terminate" then
					local ok, passback = coroutine.resume(routine.thread, eventType, ...)
					if not ok then
						printError("routineHandler - Run: "..passback)
						self:Remove(routineID)
					elseif coroutine.status(routine.thread) == "dead" then
						self:Remove(routineID)
					else
						routine.filter = passback
						table.insert(newOrderedList, routineID)
					end
				else
					table.insert(newOrderedList, routineID)
				end
			end
		end
		self.orderedList = newOrderedList
	end,

	Run = function(self)
		self.running = true
		while self.running do
			self:HandleEvent(os.pullEvent())
		end
	end,
	Stop = function(self)
		if self.running then
			self.running = false
			return true
		end
		return false
	end,
}
local routineHandlerMetatable = {__index = routineHandlerMethods}

function new(maxRoutines)
	if maxRoutines ~= nil and type(maxRoutines) ~= "number" then
		error("new: number expected for 'maxRoutines'", 2)
	end
	local routineHandler = {
		list = {},
		orderedList = {},
		names = {},
		maxRoutines = maxRoutines and math.floor(maxRoutines),
		running = false,
	}
	return setmetatable(routineHandler, routineHandlerMetatable)
end

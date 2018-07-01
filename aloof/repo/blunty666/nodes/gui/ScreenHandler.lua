package = "blunty666.nodes.gui"

imports = "blunty666.nodes.MasterNode"

class = "ScreenHandler"

local mainTerminalEvents = {
	char = true,
	key = true,
	key_up = true,
	mouse_click = true,
	mouse_drag = true,
	mouse_scroll = true,
	mouse_up = true,
	paste = true,
	term_resize = true,
	terminate = true,
}

variables = {
	masterNode = false,
	handler = false,

	monitors = {},
	timers = {},

	clickTime = 0.05,

	running = false,
}

methods = {
	AddMonitor = function(self, monitorName, backgroundColour, scale)
		if type(monitorName) == "string" and peripheral.getType(monitorName) == "monitor" then
			local monitor = peripheral.wrap(monitorName)
			monitor.setTextScale(scale)
			local masterNode = MasterNode(monitor, backgroundColour)
			local handler = GuiHandler(masterNode)
			self.monitors[monitorName] = {
				masterNode = masterNode,
				handler = handler,
			}
			return masterNode
		end
		return false
	end,
	GetMonitorMasterNode = function(self, monitorName)
		if self.monitors[monitorName] then
			return self.monitors[monitorName].masterNode
		end
		return false
	end,
	GetMonitorHandler = function(self, monitorName)
		if self.monitors[monitorName] then
			return self.monitors[monitorName].handler
		end
		return false
	end,
	RemoveMonitor = function(self, monitorName)
		if self.monitors[monitorName] then
			self.monitors[monitorName] = nil
			return true
		end
		return false
	end,

	HandleEvent = function(self, event)
		if type(event) == "table" then
			local eventType = event[1]
			if mainTerminalEvents[eventType] then
				-- pass event to mainTerminal
				self.handler:HandleEvent(event)
			elseif eventType == "monitor_touch" then
				local monitorName = event[2]
				local monitorData = self.monitors[monitorName]
				if monitorData then
					if monitorData.timer then -- check for previous monitor_touch
						-- clear timer
						self.timers[monitorData.timer] = nil
						monitorData.timer = false
						-- pass mouse_up event to monitor handler
						if monitorData.handler then
							monitorData.handler:HandleEvent({"mouse_up", 1, monitorData.lastX, monitorData.lastY})
						end
						monitorData.lastX, monitorData.lastY = false, false
					end

					-- pass mouse_click event to correct monitor
					if monitorData.handler then
						monitorData.handler:HandleEvent({"mouse_click", 1, event[3], event[4]})
						monitorData.lastX, monitorData.lastY = event[3], event[4]
						monitorData.timer = os.startTimer(self.clickTime)
						self.timers[monitorData.timer] = monitorName
					end
				end
			elseif eventType == "timer" then
				local timer = event[2]
				local monitorName = self.timers[timer]
				if monitorName then
					self.timers[timer] = nil
					local monitorData = self.monitors[monitorName]
					if monitorData then
						monitorData.timer = false
						if monitorData.handler then
							monitorData.handler:HandleEvent({"mouse_up", 1, monitorData.lastX, monitorData.lastY})
						end
						monitorData.lastX, monitorData.lastY = false, false
					end
				end
			end
		end
		return false
	end,
	Run = function(self)
		self.running = true
		local event
		local terminated = false

		while self.running do
			-- push buffer updates to screens
			self.masterNode:DrawChanges()
			for _, monitorData in pairs(self.monitors) do
				local monitorTerminal = monitorData.masterNode
				if monitorTerminal then
					monitorTerminal:DrawChanges()
				end
			end

			-- handle event
			event = {coroutine.yield()}
			if event[1] == "terminate" then
				self.running = false
				terminated = true
			end
			self:HandleEvent(event)
		end

		-- push buffer updates to screens
		self.masterNode:DrawChanges()
		for _, monitorData in pairs(self.monitors) do
			local monitorTerminal = monitorData.masterNode
			if monitorTerminal then
				monitorTerminal:DrawChanges()
			end
		end

		return terminated
	end,
	Stop = function(self)
		if self.running then
			self.running = false
			return true
		end
		return false
	end,
}

constructor = function(self, mainTerminal, mainTerminalBackgroundColour)
	local masterNode = MasterNode((type(mainTerminal) == "table" and mainTerminal) or term.current(), mainTerminalBackgroundColour)
	local handler = GuiHandler(masterNode)

	self.masterNode = masterNode
	self.handler = handler
end

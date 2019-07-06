local parent = {
	term = term.current(),
}
parent.width, parent.height = parent.term.getSize()

local process = {}
local menu = {}
local modems = {}
local multishell = {}
local oldPeripheralCall = peripheral.call

process.list = {}
process.orderedList = {}
process.selected = nil
process.running = nil
process.getID = function()
	local processID
	repeat
		processID = math.random(0, 9999)
	until not process.list[processID]
	return processID
end
process.select = function(processID)
	if process.selected ~= processID then
		if not processID then
			process.selected = nil
		else
			local newProcess = process.list[processID]
			if newProcess and newProcess.isVisible then
				if process.selected and process.list[process.selected] then
					process.list[process.selected].window.setVisible(false)
				end
				process.selected = processID
				newProcess.window.setVisible(true)
				newProcess.interactedWith = true
			end
		end
	end
end
process.resume = function(processID, event, ...)
	local proc = process.list[processID]
	if proc and ((not proc.filters) or proc.filters[event] or event == "terminate") then
		proc.filters = nil
		local previousRunning = process.running
		process.running = processID
		term.redirect(proc.terminal)
		local result = {coroutine.resume(proc.thread, event, ...)}
		proc.terminal = term.current()
		if result[1] then
			if result[2] then
				if type(result[2]) == "string" or type(result[2]) == "number" then
					proc.filters = {}
					proc.filters[result[2]] = true
				elseif type(result[2]) == "table" then
					proc.filters = {}
					for _, filter in ipairs(result[2]) do
						if type(filter) == "string" or type(filter) == "number" then
							proc.filters[filter] = true
						end
					end
				end
			end
		else
			printError(result[2])
		end
		process.running = previousRunning
	end
end
process.launch = function(programEnv, programPath, ...)
	local progArgs = {...}
	local processID = process.getID()
	local proc = {}
	proc.title = fs.getName(programPath)
	if menu.isVisible then
		proc.window = window.create(parent.term, 1, 2, parent.width, parent.height - 1, false)
	else
		proc.window = window.create(parent.term, 1, 1, parent.width, parent.height, false)
	end
	proc.thread = coroutine.create(
		function()
			os.run(programEnv, programPath, unpack(progArgs))
			if not proc.isVisible then
				process.setVisible(processID, true)
			end
			--redraw menu or create popup to alert to failure
			if not proc.interactedWith then
				term.setCursorBlink(false)
				print("Press any key to continue")
				os.pullEvent("key")
			end
		end
	)
	proc.filters = nil
	proc.terminal = proc.window
	proc.isVisible = true
	proc.interactedWith = false
	process.list[processID] = proc
	table.insert(process.orderedList, processID)
	process.resume(processID)
	return processID
end
process.cull = function(processID, override)
	local proc = process.list[processID]
	if proc and (coroutine.status(proc.thread) == "dead" or override == true) then
		for _, side in ipairs(rs.getSides()) do
			modems.closeAll(side, processID)
		end
		process.list[processID] = false
		local procOrder
		for n = 1, #process.orderedList do
			if process.orderedList[n] == processID then
				procOrder = n
				table.remove(process.orderedList, n)
				break
			end
		end
		if process.selected == processID then
			local newSelected
			for n = math.max(procOrder - 1, 1), 1, -1 do
				if process.list[process.orderedList[n]] and process.list[process.orderedList[n]].isVisible then
					newSelected = process.orderedList[n]
					break
				end
			end
			if not newSelected then
				for n = math.min(#process.orderedList, procOrder), #process.orderedList do
					if process.list[process.orderedList[n]] and process.list[process.orderedList[n]].isVisible then
						newSelected = process.orderedList[n]
						break
					end
				end
			end
			process.select(newSelected)
		end
		return true
	end
	return false
end
process.cullAll = function()
	local culled = false
	for processID, proc in pairs(process.list) do
		if proc then
			culled = culled or process.cull(processID)
		end
	end
	return culled
end
process.resizeWindows = function()
	local windowY, windowHeight
	if menu.isVisible then
		windowY = 2
		windowHeight = parent.height - 1
	else
		windowY = 1
		windowHeight = parent.height
	end
	for n = 1, #process.orderedList do
		local proc = process.list[process.orderedList[n]]
		if proc then
			local window = proc.window
			local x, y = window.getCursorPos()
			if y > windowHeight then
				window.scroll(y - windowHeight)
				window.setCursorPos(x, windowHeight)
			end
			window.reposition(1, windowY, parent.width, windowHeight)
		end
	end
	process.windowsResized = true
end
process.totalVisible = function()
	local visibleProcesses = 0
	for n = 1, #process.orderedList do
		if process.list[process.orderedList[n]] and process.list[process.orderedList[n]].isVisible then
			visibleProcesses = visibleProcesses + 1
		end
	end
	return visibleProcesses
end

if parent.term.isColour() then
	menu.mainTextColour = colours.yellow
	menu.mainBackgroundColour = colours.black
	menu.otherTextColour = colours.black
	menu.otherBackgroundColour = colours.grey
else
	menu.mainTextColour = colours.white
	menu.mainBackgroundColour = colours.black
	menu.otherTextColour = colours.black
	menu.otherBackgroundColour = colours.white
end
menu.redraw = function()
	if menu.isVisible then
		parent.term.setCursorPos(1, 1)
		parent.term.setBackgroundColour(menu.otherBackgroundColour)
		parent.term.clearLine()
		for n = 1, #process.orderedList do
			local proc = process.list[process.orderedList[n]]
			if proc and proc.isVisible then
				if process.selected == process.orderedList[n] then
					parent.term.setTextColour(menu.mainTextColour)
					parent.term.setBackgroundColour(menu.mainBackgroundColour)
				else
					parent.term.setTextColour(menu.otherTextColour)
					parent.term.setBackgroundColour(menu.otherBackgroundColour)
				end
				parent.term.write(" "..proc.title.." ")
			end
		end
		local selectedProc = process.list[process.selected]
		if selectedProc then
			selectedProc.window.restoreCursor()
		end
	end
end
menu.setVisible = function(visible)
	if menu.isVisible ~= visible then
		menu.isVisible = visible
		process.resizeWindows()
		menu.redraw()
	end
end

multishell.getFocus = function()
	return process.selected
end
multishell.setFocus = function(processID)
	if process.list[processID] and process.list[processID].isVisible then
		process.select(processID)
		menu.redraw()
		return true
	end
	return false
end
multishell.getTitle = function(processID)
	if process.list[processID] then
		return process.list[processID].title
	end
end
multishell.setTitle = function(processID, title)
	if process.list[processID] and type(title) == "string" then
		process.list[processID].title = title
		menu.redraw()
		return true
	end
	return false
end
multishell.getCurrent = function()
	return process.running
end
multishell.launch = function(programEnv, programPath, ...)
	local prevTerm = term.current()
	menu.setVisible(process.totalVisible() + 1 >= 2)
	local result = process.launch(programEnv, programPath, ...)
	menu.redraw()
	term.redirect(prevTerm)
	return result
end
multishell.setVisible = function(processID, visible)
	local proc = process.list[processID]
	if proc then
		if visible == true and not proc.isVisible then
			proc.isVisible = true
			menu.setVisible(process.totalVisible() >= 2)
			menu.redraw()
		elseif visible == false and proc.isVisible then
			if process.totalVisible() > 1 then
				if process.selected == processID then
					local procOrder
					for n = 1, #process.orderedList do
						if process.orderedList[n] == processID then
							procOrder = n
							break
						end
					end
					if process.selected == processID then
						local newSelected
						for n = math.max(procOrder - 1, 1), 1, -1 do
							if process.list[process.orderedList[n]].isVisible then
								newSelected = process.orderedList[n]
								break
							end
						end
						if not newSelected then
							for n = math.min(#process.orderedList, procOrder + 1), #process.orderedList do
								if process.list[process.orderedList[n]].isVisible then
									newSelected = process.orderedList[n]
									break
								end
							end
						end
						process.select(newSelected)
					end
				end
				proc.isVisible = false
				menu.setVisible(process.totalVisible() >= 2)
				menu.redraw()
			end
		end
	end
end

modems.open = function(side, channel, processID)
	if not processID or not process.list[processID] then return oldPeripheralCall(side, "open", channel) end
	if not modems[side] then modems[side] = {} end
	if not modems[side][channel] then modems[side][channel] = {} end
	modems[side][channel][processID] = true
	return oldPeripheralCall(side, "open", channel)
end
modems.close = function(side, channel, processID)
	if processID and process.list[processID] then
		if not modems[side] then return end
		if not modems[side][channel] then return end
		if not modems[side][channel][processID] then return end
		modems[side][channel][processID] = nil
		if not next(modems[side][channel]) then
			return oldPeripheralCall(side, "close", channel)
		end
	else
		if not modems[side] or not modems[side][channel] or not next(modems[side][channel]) then
			return oldPeripheralCall(side, "close", channel)
		end
	end
end
modems.isOpen = function(side, channel, processID)
	if not processID or not process.list[processID] then return oldPeripheralCall(side, "isOpen", channel) end
	if not modems[side] then return false end
	if not modems[side][channel] then return false end
	if not modems[side][channel][processID] then return false end
	return true
end
modems.closeAll = function(side, processID)
	if modems[side] then
		for channel, processes in pairs(modems[side]) do
			modems.close(side, channel, processID)
		end
	end
end

function peripheral.call(side, func, ...)
	if peripheral.getType(side) == "modem" then
		if func == "open" then
			local channel = (...)
			if tonumber(channel) and channel >= 0 and channel <= 65535 then
				return modems.open(side, channel, process.running)
			end
		elseif func == "close" then
			local channel = (...)
			return modems.close(side, channel, process.running)
		elseif func == "isOpen" then
			local channel = (...)
			return modems.isOpen(side, channel, process.running)
		elseif func == "closeAll" then
			return modems.closeAll(side, process.running)
		else
			return oldPeripheralCall(side, func, ...)
		end
	else
		return oldPeripheralCall(side, func, ...)
	end
end

parent.term.clear()
menu.setVisible(false)
process.select(
	process.launch(
		{
			["shell"] = shell,
			["multishell"] = multishell,
		},
		"/rom/programs/shell"
	)
)
menu.redraw()
local event, eventType
while process.totalVisible() > 0 do
	if process.windowsResized then
		local limit = #process.orderedList
		for n = 1, limit do
			process.resume(process.orderedList[n], "term_resize")
		end
		process.windowsResized = false
		if process.cullAll() then
			menu.setVisible(process.totalVisible() >= 2)
			menu.redraw()
		end
	end
	event = {os.pullEventRaw()}
	eventType = event[1]
	if eventType == "term_resize" then
		parent.width, parent.height = parent.term.getSize()
		process.resizeWindows()
		menu.redraw()
	elseif eventType == "char" or eventType == "key" or eventType == "paste" or eventType == "terminate" then
		process.resume(process.selected, unpack(event))
		if process.cull(process.selected) then
			menu.setVisible(process.totalVisible() >= 2)
			menu.redraw()
		end
	elseif eventType == "mouse_click" then
		local button, x, y = event[2], event[3], event[4]
		if menu.isVisible and y == 1 then
			local tabStart, tabEnd = 1, 1
			for n = 1, #process.orderedList do
				local proc = process.list[process.orderedList[n]]
				if proc and proc.isVisible then
					tabEnd = tabStart + string.len(proc.title) + 1
					if x >= tabStart and x <= tabEnd then
						if button == 2 and process.selected == process.orderedList[n] then
							process.resume(process.selected, "terminate")
							process.cull(process.orderedList[n], true)
							menu.setVisible(process.totalVisible() >= 2)
							menu.redraw()
						else
							process.select(process.orderedList[n])
							menu.redraw()
						end
						break
					end
					tabStart = tabEnd + 1
				end
			end
		else
			process.resume(process.selected, eventType, button, x, (menu.isVisible and y - 1) or y)
			if process.cull(process.selected) then
				menu.setVisible(process.totalVisible() >= 2)
				menu.redraw()
			end
		end
	elseif eventType == "mouse_drag" or eventType == "mouse_scroll" then
		local button, x, y = event[2], event[3], event[4]
		if not (menu.isVisible and y == 1) then
			process.resume(process.selected, eventType, button, x, (menu.isVisible and y - 1) or y)
			if process.cull(process.selected) then
				menu.setVisible(process.totalVisible() >= 2)
				menu.redraw()
			end
		end
	else
		local limit = #process.orderedList
		for n = 1, limit do
			process.resume(process.orderedList[n], unpack(event))
		end
		if process.cullAll() then
			menu.setVisible(process.totalVisible() >= 2)
			menu.redraw()
		end
	end
end

term.redirect(parent.term)

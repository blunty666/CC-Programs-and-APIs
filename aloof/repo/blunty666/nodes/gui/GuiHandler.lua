package = "blunty666.nodes.gui"

imports = "blunty666.nodes.gui.events.*"

class = "GuiHandler"

local function sendEventToCallbacks(object, callback, ...)
	local funcs = object:GetCallbacks(callback)
	if funcs then
		for id, func in pairs(funcs) do
			func(...)
		end
	end
end

local function findChain(drawable)
	local chain = {}
	local node = drawable.parent
	while node.ID ~= false do
		chain[node.ID] = true
		node = node.parent
	end
	return chain
end

local function passEventUpChain(masterNode, drawable, chain, event)
	sendEventToCallbacks(drawable, event.name, drawable, event)
	local node
	for nodeID in pairs(chain) do
		node = masterNode:GetSubNode(nodeID)
		if node then
			sendEventToCallbacks(node, event.name, node, drawable, event)
		end
	end
end

local function calculateOffset(drawable, xPos, yPos)
	return xPos - drawable.absX, yPos - drawable.absY
end

local surfaceEventHandlers = {
	char = function(handler, masterNode, event)
		if handler.selectedID then
			local drawable = masterNode:GetSubNode(handler.selectedID)
			if drawable then
				passEventUpChain(masterNode, drawable, findChain(drawable), CharEvent(event[2]))
			end
		end
	end,
	key = function(handler, masterNode, event)
		if handler.selectedID then
			local drawable = masterNode:GetSubNode(handler.selectedID)
			if drawable then
				passEventUpChain(masterNode, drawable, findChain(drawable), KeyEvent(event[2], event[3]))
			end
		end
	end,
	key_up = function(handler, masterNode, event)
		if handler.selectedID then
			local drawable = masterNode:GetSubNode(handler.selectedID)
			if drawable then
				passEventUpChain(masterNode, drawable, findChain(drawable), KeyUpEvent(event[2]))
			end
		end
	end,
	paste = function(handler, masterNode, event)
		if handler.selectedID then
			local drawable = masterNode:GetSubNode(handler.selectedID)
			if drawable then
				passEventUpChain(masterNode, drawable, findChain(drawable), PasteEvent(event[2]))
			end
		end
	end,
	mouse_click = function(handler, masterNode, event)
		-- pass mouse_up event to lastClickID drawable in case we missed it before
		if handler.lastClickID then
			local drawable = masterNode:GetSubNode(handler.lastClickID)
			if drawable then
				local mouseUpEvent = MouseUpEvent(handler.lastClickX, handler.lastClickY, handler.lastClickActualX, handler.lastClickActualY, handler.lastClickButton)
				sendEventToCallbacks(drawable, mouseUpEvent.name, drawable, mouseUpEvent)
			end
		end

		-- update selected and deselected nodes and drawables
		local newSelectedID = masterNode:GetClickableAt(event[3], event[4])
		if not handler.selectedID or newSelectedID ~= handler.selectedID then
			local newDrawable = newSelectedID and masterNode:GetSubNode(newSelectedID)
			local selectedChain = (newDrawable and findChain(newDrawable)) or {}
			if handler.selectedID then
				local drawable = masterNode:GetSubNode(handler.selectedID)
				if drawable then
					local deselectedChain = findChain(drawable)
					for nodeID in pairs(selectedChain) do
						deselectedChain[nodeID] = nil
					end
					drawable.active = false
					passEventUpChain(masterNode, drawable, deselectedChain, DeselectEvent())
				end
			end
			handler.selectedID = newSelectedID
			if newDrawable then
				newDrawable.active = true
				passEventUpChain(masterNode, newDrawable, selectedChain, SelectEvent())
			end
		end

		-- pass mouse_click event to drawable
		local drawable = newSelectedID and masterNode:GetSubNode(newSelectedID)
		if drawable then
			handler.lastClickID, handler.lastClickButton = newSelectedID, event[2]
			handler.lastClickX, handler.lastClickY = calculateOffset(drawable, event[3], event[4])
			handler.lastClickActualX, handler.lastClickActualY = event[3], event[4]
			local mouseClickEvent = MouseClickEvent(handler.lastClickX, handler.lastClickY, handler.lastClickActualX, handler.lastClickActualY, handler.lastClickButton)
			sendEventToCallbacks(drawable, mouseClickEvent.name, drawable, mouseClickEvent)
		else
			handler.lastClickID, handler.lastClickButton = false, false
			handler.lastClickX, handler.lastClickY = false, false
			handler.lastClickActualX, handler.lastClickActualY = false, false
		end
	end,
	mouse_drag = function(handler, masterNode, event)
		if handler.lastClickID then
			local drawable = masterNode:GetSubNode(handler.lastClickID)
			if drawable then
				local deltaX, deltaY = event[3] - handler.lastClickActualX, event[4] - handler.lastClickActualY
				handler.lastClickX, handler.lastClickY = calculateOffset(drawable, event[3], event[4])
				handler.lastClickActualX, handler.lastClickActualY = event[3], event[4]
				local mouseDragEvent = MouseDragEvent(handler.lastClickX, handler.lastClickY, handler.lastClickActualX, handler.lastClickActualY, handler.lastClickButton, deltaX, deltaY)
				sendEventToCallbacks(drawable, mouseDragEvent.name, drawable, mouseDragEvent)
			end
		end
	end,
	mouse_up = function(handler, masterNode, event)
		if handler.lastClickID then
			local drawable = masterNode:GetSubNode(handler.lastClickID)
			if drawable then
				local xPos, yPos = calculateOffset(drawable, event[3], event[4])
				local mouseUpEvent = MouseUpEvent(xPos, yPos, event[3], event[4], event[2])
				sendEventToCallbacks(drawable, mouseUpEvent.name, drawable, mouseUpEvent)
			end
		end
		handler.lastClickID, handler.lastClickButton = false, false
		handler.lastClickX, handler.lastClickY = false, false
		handler.lastClickActualX, handler.lastClickActualY = false, false
	end,
	mouse_scroll = function(handler, masterNode, event)
		local drawableID = masterNode:GetClickableAt(event[3], event[4])
		local drawable = drawableID and masterNode:GetSubNode(drawableID)
		if drawable then
			local xPos, yPos = calculateOffset(drawable, event[3], event[4])
			local mouseScrollEvent = MouseScrollEvent(xPos, yPos, event[3], event[4], event[2])
			sendEventToCallbacks(drawable, mouseScrollEvent.name, drawable, mouseScrollEvent)
		end
	end,
	terminate = function(self)
		self.running = false
	end,
}

variables = {
	masterNode = NIL,
	selectedID = false,

	lastClickID = false,
	lastClickButton = false,
	lastClickX = false,
	lastClickY = false,
	lastClickActualX = false,
	lastClickActualY = false,

	running = false,
}

methods = {
	HandleEvent = function(self, event)
		if type(event) == "table" then
			local eventType = event[1]
			local handler = surfaceEventHandlers[eventType]
			if handler then
				handler(self, self.masterNode, event)
				return true
			end
		end
		return false
	end,
	Run = function(self)
		self.running = true
		self.masterNode:DrawChanges()

		local event
		while self.running do
			event = {coroutine.yield()}
			if self:HandleEvent(event) then
				self.masterNode:DrawChanges()
			end
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

constructor = function(self, masterNode)
	self.masterNode = masterNode
end

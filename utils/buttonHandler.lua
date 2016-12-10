--===== LIST =====--
local function getName(list, buttonName)
	return "list:"..list.name..":"..buttonName
end

local listMethods = {
	GetOffset = function(self)
		return self.offset
	end,
	SetOffset = function(self, offset)
		if type(offset) == "number" and offset == 0 or (0 < offset and self.listHeight - 2 + offset <= #self.values) then
			self.offset = offset
			for y = 1, self.listHeight - 2 do
				self.buttonInstance:SetText(getName(self, y), self.values[y + self.offset] or "")
			end
			self.buttonInstance:SetOffTextCol(getName(self, "Scroll Up"), (self.offset == 0 and colours.green) or colours.white)
			self.buttonInstance:SetOffTextCol(getName(self, "Scroll Down"), (self.listHeight - 2 + self.offset >= #self.values and colours.green) or colours.white)
			return true
		end
		return false
	end,

	GetHandlerFunc = function(self)
		return self.handlerFunc
	end,
	SetHandlerFunc = function(self, handlerFunc)
		if type(handlerFunc) == "function" then
			self.handlerFunc = handlerFunc
			return true
		end
		return false
	end,

	GetValues = function(self)
		return self.values
	end,
	SetValues = function(self, values)
		if type(values) == "table" then
			local offset = self:GetOffset()
			self.values = values
			if #values < self.listHeight - 2 then
				offset = 0
			elseif self.listHeight - 2 + offset > #values then
				offset = #values - self.listHeight + 2
			end
			self:SetOffset(offset)
			return true
		end
		return false
	end,
}
local listMetatable = {__index = listMethods}

local function newList(buttonInstance, listName, values, handlerFunc, listX, listY, listWidth, listHeight)
	local list = {
		buttonInstance = buttonInstance,
		name = listName,
		values = values,
		handlerFunc = handlerFunc,
		listHeight = listHeight,
		offset = 0,
	}

	for i = 1, list.listHeight - 2 do
		local function func()
			if list.values[i + list.offset] then
				buttonInstance:Flash(getName(list, i))
				list.handlerFunc(list.values[i + list.offset])
			end
		end
		buttonInstance:Add(getName(list, i), func, listX, listY + i, listWidth, 1, list.values[i + list.offset] or "", (i % 2 == 1 and colours.grey) or colours.lightGrey, colours.cyan)
	end

	local function scrollUp()
		if list.offset > 0 then
			list:SetOffset(list.offset - 1)
			buttonInstance:Flash(getName(list, "Scroll Up"))
		end
	end
	buttonInstance:Add(getName(list, "Scroll Up"), scrollUp, listX, listY, listWidth, 1, "Scroll Up", colours.green, colours.red)

	local function scrollDown()
		if list.listHeight + list.offset - 1 <= #list.values then
			list:SetOffset(list.offset + 1)
			list.buttonInstance:Flash(getName(list, "Scroll Down"))
		end
	end
	buttonInstance:Add(getName(list, "Scroll Down"), scrollDown, listX, listY + listHeight - 1, listWidth, 1, "Scroll Down", colours.green, colours.red)

	setmetatable(list, listMetatable)
	list:SetOffset(0)
	return list
end

--===== BUTTON HANDLER =====--
local function setupLabel(text, width, height)
	local labelTable = {}
	if #text > width then
		text = string.sub(text, 1, math.max(0, width - 3))..string.rep(".", math.min(width, 3))
	else
		local delta = width - #text
		text = string.rep(" ", math.floor(delta/2))..text..string.rep(" ", math.ceil(delta/2))
	end
	for i = 1, height do
		if i == math.floor((height - 1)/2) + 1 then
			labelTable[i] = text
		else
			labelTable[i] = string.rep(" ", width)
		end
	end
	return labelTable
end

local function drawButton(terminal, buttonData)
	if buttonData.active then
		terminal.setBackgroundColor(buttonData.onBgCol)
		terminal.setTextColor(buttonData.onTextCol)
	else
		terminal.setBackgroundColor(buttonData.offBgCol)
		terminal.setTextColor(buttonData.offTextCol)
	end
	local y
	for i = 1, buttonData.height do
		y = buttonData.yPos + i - 1
		terminal.setCursorPos(buttonData.xPos, y)
		terminal.write(buttonData.label[i])
	end
end

local buttonHandlerMethods = {
	Draw = function(self)
		for name, buttonData in pairs(self.list) do
			drawButton(self.term, buttonData)
		end
	end,

	Add = function(self, name, func, xPos, yPos, width, height, text, offBgCol, onBgCol, offTextCol, onTextCol)
		if self.list[name] then error("buttonHandler:Add - name already in use: "..tostring(name), 2) end
		local label = setupLabel(text, width, height)
		self.list[name] = {
			func = func,
			xPos = xPos,
			yPos = yPos,
			width = width,
			height = height,
			text = text,
			active = false,
			offBgCol = offBgCol or colours.red,
			onBgCol = onBgCol or colours.lime,
			offTextCol = offTextCol or colours.white,
			onTextCol = onTextCol or colours.white,
			label = label,
		}
		for x = xPos, xPos + width - 1 do
			if self.map[x] then
				for y = yPos, yPos + height - 1 do
					if y >= 1 and y <= self.height then

						if self.map[x][y] ~= nil then
							for x2 = xPos, xPos + width - 1 do
								if self.map[x2] then
									for y2 = yPos, yPos + height - 1 do
										if self.map[x2][y2] == name then
											self.map[x2][y2] = nil
										end
									end
								end
							end
							self.list[name] = nil
							error("buttonHandler:Add - overlapping button: "..x..":"..y, 2)
						end

						self.map[x][y] = name
					end
				end
			end
		end
	end,
	GetText = function(self, name)
		local buttonData = self.list[name]
		if buttonData then
			return buttonData.text
		end
		return false
	end,
	SetText = function(self, name, text, noDraw)
		local buttonData = self.list[name]
		if buttonData then
			buttonData.text = text
			buttonData.label = setupLabel(text, buttonData.width, buttonData.height)
			if noDraw ~= true then
				drawButton(self.term, buttonData)
			end
			return true
		end
		return false
	end,
	Remove = function(self, name)
		local buttonData = self.list[name]
		if buttonData then
			for x = buttonData.xPos, buttonData.xPos + buttonData.width - 1 do
				if self.map[x] then
					for y = buttonData.yPos, buttonData.yPos + buttonData.height - 1 do
						if y >= 1 and y <= self.height then
							if self.map[x][y] == name then
								self.map[x][y] = nil
							end
						end
					end
				end
			end
			self.term.setBackgroundColor(colours.black)
			for y = buttonData.yPos, buttonData.yPos + buttonData.height - 1 do
				self.term.setCursorPos(buttonData.xPos, y)
				self.term.write(string.rep(" ", buttonData.width))
			end
			self.list[name] = nil
			return true
		end
		return false
	end,

	Toggle = function(self, name, noDraw)
		local buttonData = self.list[name]
		if buttonData then
			buttonData.active = not buttonData.active
			if noDraw ~= true then
				drawButton(self.term, buttonData)
			end
			return true
		end
		return false
	end,
	Flash = function(self, name, duration)
		if self:Toggle(name) then
			sleep(tonumber(duration) or 0.15)
			self:Toggle(name)
		end
	end,

	AddList = newList,

	HandleClick = function(self, xPos, yPos)
		local clicked = self.map[xPos] and self.map[xPos][yPos]
		if clicked and self.list[clicked] then
			self.list[clicked].func()
		end
	end,
}
local buttonHandlerMetatable = {__index = buttonHandlerMethods}

local function makeGetter(key)
	return function(self, name)
		local buttonData = self.list[name]
		if buttonData then
			return buttonData[key]
		end
		return false
	end
end
local function makeSetter(key)
	return function(self, name, value, noDraw)
		local buttonData = self.list[name]
		if buttonData then
			buttonData[key] = value
			if noDraw ~= true then
				drawButton(self.term, buttonData)
			end
			return true
		end
		return false
	end
end
local keys = {
	OffBgCol = "offBgCol",
	OnBgCol = "onBgCol",
	OffTextCol = "offTextCol",
	OnTextCol = "onTextCol",
}
for name, key in pairs(keys) do
	buttonHandlerMethods["Get"..name] = makeGetter(key)
	buttonHandlerMethods["Set"..name] = makeSetter(key)
end

function new(terminal)
	local width, height = terminal.getSize()
	local buttonHandler = {
		term = terminal,
		list = {},
		map = {},
		width = width,
		height = height,
	}
	for xPos = 1, width do
		buttonHandler.map[xPos] = {}
	end
	return setmetatable(buttonHandler, buttonHandlerMetatable)
end

package = "blunty666.nodes.gui.objects"

imports = {
	"blunty666.nodes.*",
	"aloof.TypeChecker",
}

class = "TextBox"
extends = "Drawable"

local function redrawTextBox(textBox, width, mask, text, cursorPosition)
	if mask then
		text = string.rep(mask, string.len(text))
	end
	if cursorPosition + 1 < textBox.startPos then
		textBox.startPos = cursorPosition + 1
	elseif cursorPosition - textBox.startPos + 2 > width then
		textBox.startPos = cursorPosition - width + 2
	end
	local pos
	for offset = 1, width do
		pos = textBox.startPos + offset - 1
		if pos <= text:len() then
			textBox:SetCoord(offset, 1, text:sub(pos, pos), textBox.textColour, textBox.backgroundColour)
		else
			textBox:SetCoord(offset, 1, " ", textBox.textColour, textBox.backgroundColour)
		end
	end
	textBox.cursorPos = {cursorPosition - textBox.startPos + 2, 1}
end

local function textBoxOnSelect(textBox)
	textBox.cursorBlink = true
end

local function textBoxOnDeselect(textBox)
	textBox.cursorBlink = false
end

local function textBoxOnChar(textBox, charEvent)
	textBox.text = string.sub(textBox.text, 1, textBox.cursorPosition)..charEvent.char..string.sub(textBox.text, textBox.cursorPosition + 1)
	textBox.cursorPosition = textBox.cursorPosition + 1
end

local function textBoxOnKey(textBox, keyEvent)
	local key = keyEvent.key
	if key == keys.enter then
		if textBox.onEnter then
			textBox.onEnter(textBox.text)
		end
		if textBox.resetOnEnter then
			textBox.text = ""
		end

	elseif key == keys.left then
		if textBox.cursorPosition > 0 then
			textBox.cursorPosition = textBox.cursorPosition - 1
		end
	elseif key == keys.right then
		if textBox.cursorPosition < string.len(textBox.text) then
			textBox.cursorPosition = textBox.cursorPosition + 1
		end

	elseif key == keys.backspace then
		if textBox.cursorPosition > 0 then
			textBox.cursorPosition = textBox.cursorPosition - 1
			textBox.text = string.sub(textBox.text, 1, textBox.cursorPosition)..string.sub(textBox.text, textBox.cursorPosition + 2)
		end
	elseif key == keys.delete then
		if textBox.cursorPosition < string.len(textBox.text) then
			textBox.text = string.sub(textBox.text, 1, textBox.cursorPosition)..string.sub(textBox.text, textBox.cursorPosition + 2)
		end

	elseif key == keys.home then
		if textBox.cursorPosition > 0 then
			textBox.cursorPosition = 0
		end
	elseif key == keys["end"] then
		if textBox.cursorPosition < string.len(textBox.text) then
			textBox.cursorPosition = string.len(textBox.text)
		end
	end
end

local function textBoxOnMouseClick(textBox, mouseClickEvent)
	local button = mouseClickEvent.button
	if button == 1 then
		textBox.cursorPosition = math.min(string.len(textBox.text), textBox.startPos + mouseClickEvent.x - 2)
	elseif button == 2 then
		textBox.text = ""
	end
end		

variables = {
	startPos = 1,
	text = "",
	cursorPosition = 0,
	mask = false,
	onEnter = false,
	resetOnEnter = false,
}

setters = {
	width = function(self, width)
		if TypeChecker.non_negative_integer(width) then
			self.size = {width, self.height}
			return self.width
		end
		return error("TextBox - setters - width: non_negative_integer expected, got <"..type(width).."> "..tostring(width), 2)
	end,
	height = function(self, height)
		if TypeChecker.non_negative_integer(height) then
			self.size = {self.width, height}
			return self.height
		end
		return error("TextBox - setters - height: non_negative_integer expected, got <"..type(height).."> "..tostring(height), 2)
	end,
	size = function(self, size)
		if TypeChecker.non_negative_integer_double(size) then
			if size[1] ~= self.width or size[2] ~= self.height then
				self.super.size = size
				redrawTextBox(self, self.width, self.mask, self.text, self.cursorPosition)
			end
			return self.super.width
		end
		return error("TextBox - setters - pos: non_negative_integer_double expected, got <"..type(size).."> "..tostring(size), 2)
	end,

	backgroundColour = function(self, backgroundColour)
		if TypeChecker.colour(backgroundColour) then
			if self.backgroundColour ~= backgroundColour then
				self.super.backgroundColour = backgroundColour
				self:_Update(nil, nil, backgroundColour)
			end
			return self.super.backgroundColour
		end
		return self.backgroundColour
	end,
	textColour = function(self, textColour)
		if TypeChecker.colour(textColour) then
			if self.textColour ~= textColour then
				self.super.textColour = textColour
				self:_Update(nil, textColour, nil)
			end
			return self.super.textColour
		end
		return self.textColour
	end,

	mask = function(self, mask)
		if type(mask) == "string" and mask:len() > 0 then
			mask = mask:sub(1, 1)
			if self.mask ~= mask then
				redrawTextBox(self, self.width, mask, self.text, self.cursorPosition)
			end
			return mask
		elseif mask == false then
			if self.mask ~= mask then
				redrawTextBox(self, self.width, mask, self.text, self.cursorPosition)
			end
			return mask
		end
		return self.mask
	end,
	text = function(self, text)
		if type(text) == "string" then
			if self.text ~= text then
				self.cursorPosition = math.min(self.cursorPosition, string.len(text))
				redrawTextBox(self, self.width, self.mask, text, self.cursorPosition)
			end
			return text
		end
		return self.text
	end,
	cursorPosition = function(self, cursorPosition)
		if TypeChecker.non_negative_integer(cursorPosition) then
			cursorPosition = math.min(cursorPosition, string.len(self.text))
			if self.cursorPosition ~= cursorPosition then
				redrawTextBox(self, self.width, self.mask, self.text, cursorPosition)
			end
			return cursorPosition
		end
		return self.cursorPosition
	end,

	onEnter = function(self, onEnter)
		return ((onEnter == nil or type(onEnter) == "function") and onEnter) or self.onEnter
	end,
	resetOnEnter = function(self, resetOnEnter)
		return (type(resetOnEnter) == "boolean" and resetOnEnter) or self.resetOnEnter
	end,
}

constructor = function(self, node, xPos, yPos, order, width, onEnter, mask)
	self.super(node, xPos, yPos, order)
	self.size = {width, 1}
	self.onEnter = onEnter
	self.mask = mask

	self:SetCallback("select", "textBox", textBoxOnSelect)
	self:SetCallback("deselect", "textBox", textBoxOnDeselect)
	self:SetCallback("char", "textBox", textBoxOnChar)
	self:SetCallback("key", "textBox", textBoxOnKey)
	self:SetCallback("mouse_click", "textBox", textBoxOnMouseClick)
end

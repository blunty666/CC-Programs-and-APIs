package = "blunty666.nodes.gui.objects"

imports = "aloof.TypeChecker"

class = "Button"
extends = "Label"

local function isWithinBounds(button, xPos, yPos)
	return xPos >= 1 and xPos <= button.width and yPos >= 1 and yPos <= button.height
end

local buttonToVariable = {
	[1] = "leftClickEnabled",
	[2] = "rightClickEnabled",
	[3] = "middleClickEnabled",
}
local function buttonMouseClick(button, mouseClickEvent)
	local mouseButton = mouseClickEvent.button
	if not button.isClicked and button[ buttonToVariable[mouseButton] ] then
		if button.clickedMainColour then button.backgroundColour = button.clickedMainColour end
		if button.clickedTextColour then button.textColour = button.clickedTextColour end
		if button.clickedText then button.text = button.clickedText end
		button.isClicked = true
		if button.onClick then
			button.onClick(mouseButton, button.isActive)
		end
	end
end
local function buttonMouseUp(button, mouseUpEvent)
	local withinBounds = isWithinBounds(button, mouseUpEvent.x, mouseUpEvent.y)
	if button.isClicked then
		button.isClicked = false
		
		-- update isActive
		local wasActive = button.isActive
		if button.isToggle then
			if not button.requireBoundsOnRelease or withinBounds then
				button.isActive = not button.isActive
			end
		else
			button.isActive = false
		end
		
		-- update colours
		if button.isActive then
			button.backgroundColour = button.activeMainColour
			button.textColour = button.activeTextColour
			button.text = button.activeText
		else
			button.backgroundColour = button.inactiveMainColour
			button.textColour = button.inactiveTextColour
			button.text = button.inactiveText
		end
		
		-- trigger onRelease if needed
		if not button.requireBoundsOnRelease or withinBounds then
			local mouseButton = mouseUpEvent.button
			if button[ buttonToVariable[mouseButton] ] and button.onRelease then
				button.onRelease(mouseButton, button.isActive, wasActive)
			end
		end
	end
end

variables = {
	inactiveMainColour = colours.red,
	clickedMainColour = false,
	activeMainColour = colours.lime,

	inactiveTextColour = colours.orange,
	clickedTextColour = false,
	activeTextColour = colours.green,

	inactiveText = "",
	clickedText = false,
	activeText = "",

	leftClickEnabled = true,
	middleClickEnabled = true,
	rightClickEnabled = true,

	onClick = false,
	onRelease = false,

	isActive = false,
	isClicked = false,
	requireBoundsOnRelease = true,

	isToggle = false,
}

setters = {
	inactiveMainColour = function(self, inactiveMainColour)
		if TypeChecker.colour(inactiveMainColour) then
			if self.inactiveMainColour ~= inactiveMainColour then
				if not self.isActive and not self.isClicked then
					self.backgroundColour = inactiveMainColour
				end
			end
			return inactiveMainColour
		end
		return self.inactiveMainColour
	end,
	clickedMainColour = function(self, clickedMainColour)
		if TypeChecker.colour(clickedMainColour) or clickedMainColour == false then
			if self.clickedMainColour ~= clickedMainColour then
				if self.isClicked then
					if clickedMainColour == false then
						if self.isActive then
							self.backgroundColour = self.activeMainColour
						else
							self.backgroundColour = self.inactiveMainColour
						end
					else
						self.backgroundColour = clickedMainColour
					end
				end
			end
			return clickedMainColour
		end
		return self.clickedMainColour
	end,
	activeMainColour = function(self, activeMainColour)
		if TypeChecker.colour(activeMainColour) then
			if self.activeMainColour ~= activeMainColour then
				if self.isActive and not self.isClicked then
					self.backgroundColour = activeMainColour
				end
			end
			return activeMainColour
		end
		return self.activeMainColour
	end,

	inactiveTextColour = function(self, inactiveTextColour)
		if TypeChecker.colour(inactiveTextColour) then
			if self.inactiveTextColour ~= inactiveTextColour then
				if not self.isActive and not self.isClicked then
					self.textColour = inactiveTextColour
				end
			end
			return inactiveTextColour
		end
		return self.inactiveTextColour
	end,
	clickedTextColour = function(self, clickedTextColour)
		if TypeChecker.colour(clickedTextColour) or clickedTextColour == false then
			if self.clickedTextColour ~= clickedTextColour then
				if self.isClicked then
					if clickedTextColour == false then
						if self.isActive then
							self.textColour = self.activeTextColour
						else
							self.textColour = self.inactiveTextColour
						end
					else
						self.textColour = clickedTextColour
					end
				end
			end
			return clickedTextColour
		end
		return self.clickedTextColour
	end,
	activeTextColour = function(self, activeTextColour)
		if TypeChecker.colour(activeTextColour) then
			if self.activeTextColour ~= activeTextColour then
				if self.isActive and not self.isClicked then
					self.textColour = activeTextColour
				end
			end
			return activeTextColour
		end
		return self.activeTextColour
	end,

	inactiveText = function(self, inactiveText)
		if type(inactiveText) == "string" then
			if self.inactiveText ~= inactiveText then
				if not self.isActive and not self.isClicked then
					self.text = inactiveText
				end
			end
			return inactiveText
		end
		return self.inactiveText
	end,
	clickedText = function(self, clickedText)
		if type(clickedText) == "string" or clickedText == false then
			if self.clickedText ~= clickedText then
				if self.isClicked then
					if clickedText == false then
						if self.isActive then
							self.text = self.activeText
						else
							self.text = self.inactiveText
						end
					else
						self.text = clickedText
					end
				end
			end
			return clickedText
		end
		return self.clickedText
	end,
	activeText = function(self, activeText)
		if type(activeText) == "string" then
			if self.activeText ~= activeText then
				if self.isActive and not self.isClicked then
					self.text = activeText
				end
			end
			return activeText
		end
		return self.activeText
	end,

	leftClickEnabled = function(self, leftClickEnabled)
		if type(leftClickEnabled) == "boolean" then
			return leftClickEnabled
		end
		return self.leftClickEnabled
	end,
	middleClickEnabled = function(self, middleClickEnabled)
		if type(middleClickEnabled) == "boolean" then
			return middleClickEnabled
		end
		return self.middleClickEnabled
	end,
	rightClickEnabled = function(self, rightClickEnabled)
		if type(rightClickEnabled) == "boolean" then
			return rightClickEnabled
		end
		return self.rightClickEnabled
	end,

	onClick = function(self, onClick)
		if onClick == false or type(onClick) == "function" then
			return onClick
		end
		return self.onClick
	end,
	onRelease = function(self, onRelease)
		if onRelease == false or type(onRelease) == "function" then
			return onRelease
		end
		return self.onRelease
	end,

	isActive = function(self, isActive)
		if type(isActive) == "boolean" then
			if self.isActive ~= isActive then
				if self.isActive then
					-- update coords here
					self.backgroundColour = self.inactiveMainColour
					self.textColour = self.inactiveTextColour
					self.text = self.inactiveText
				else
					-- update coords here
					self.backgroundColour = self.activeMainColour
					self.textColour = self.activeTextColour
					self.text = self.activeText
				end
			end
			return isActive
		end
		return self.isActive
	end,
	requireBoundsOnRelease = function(self, requireBoundsOnRelease)
		if type(requireBoundsOnRelease) == "boolean" then
			return requireBoundsOnRelease
		end
		return self.requireBoundsOnRelease
	end,

	isToggle = function(self, isToggle)
		if type(isToggle) == "boolean" then
			return isToggle
		end
		return self.isToggle
	end,
}

constructor = function(self, node, x, y, order, text, inactiveMainColour, inactiveTextColour, width, height)
	self.super(node, x, y, order, text, width, height, inactiveTextColour, inactiveMainColour)

	self.inactiveMainColour = inactiveMainColour
	self.inactiveTextColour = inactiveTextColour
	self.inactiveText = text

	self:SetCallback("mouse_click", "button", buttonMouseClick)
	self:SetCallback("mouse_up", "button", buttonMouseUp)
end

package = "blunty666.nodes.gui.events"

class = "ButtonCoordEvent"
extends = "CoordEvent"

variables = {
	button = NIL,
}

local BUTTONS = {
	[1] = true,
	[2] = true,
	[3] = true,
}

local function checkButton(button)
	return (BUTTONS[button] and button) or error("button: button_number expected, got - <"..type(button).."> "..tostring(button))
end

constructor = function(self, eventType, x, y, abs_x, abs_y, button)
	self.super(eventType, x, y, abs_x, abs_y)
	self.raw.button = checkButton(button)
end

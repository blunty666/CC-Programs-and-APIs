package = "blunty666.nodes.gui.events"

imports = "aloof.TypeChecker"

class = "CoordEvent"
extends = "BaseEvent"

variables = {
	x = NIL,
	y = NIL,
	abs_x = NIL,
	abs_y = NIL,
}

local function checkPosition(pos, varName)
	return (TypeChecker.integer(pos) and pos) or error(varName..": integer expected, got - <"..type(pos).."> "..tostring(pos))
end

constructor = function(self, eventType, x, y, abs_x, abs_y)
	self.super(eventType)
	self.raw.x = checkPosition(x, "x")
	self.raw.y = checkPosition(y, "y")
	self.raw.abs_x = checkPosition(abs_x, "abs_x")
	self.raw.abs_y = checkPosition(abs_y, "abs_y")
end

package = "blunty666.nodes.gui.events"

imports = "aloof.TypeChecker"

class = "MouseDragEvent"
extends = "ButtonCoordEvent"

variables = {
	delta_x = NIL,
	delta_y = NIL,
}

local function checkDelta(delta, deltaName)
	return (TypeChecker.integer(delta) and delta) or error(deltaName..": integer expected, got - <"..type(delta).."> "..tostring(delta))
end

constructor = function(self, x, y, abs_x, abs_y, button, delta_x, delta_y)
	self.super("mouse_drag", x, y, abs_x, abs_y, button)
	self.raw.delta_x = checkDelta(delta_x, "delta_x")
	self.raw.delta_y = checkDelta(delta_y, "delta_y")
end

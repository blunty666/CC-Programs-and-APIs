package = "blunty666.nodes.gui.events"

class = "MouseUpEvent"
extends = "ButtonCoordEvent"

constructor = function(self, x, y, abs_x, abs_y, button)
	self.super("mouse_up", x, y, abs_x, abs_y, button)
end

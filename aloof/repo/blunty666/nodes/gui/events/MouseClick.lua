package = "blunty666.nodes.gui.events"

class = "MouseClickEvent"
extends = "ButtonCoordEvent"

constructor = function(self, x, y, abs_x, abs_y, button)
	self.super("mouse_click", x, y, abs_x, abs_y, button)
end

package = "blunty666.nodes.gui.events"

class = "MouseScrollEvent"
extends = "CoordEvent"

variables = {
	scroll_dir = NIL,
}

local function checkScrollDir(scroll_dir)
	return scroll_dir -- TODO
end

constructor = function(self, x, y, abs_x, abs_y, scroll_dir)
	self.super("mouse_scroll", x, y, abs_x, abs_y)
	self.raw.scroll_dir = checkScrollDir(scroll_dir)
end

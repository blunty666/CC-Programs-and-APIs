package = "blunty666.nodes_demo.views"

imports = {
	"blunty666.nodes.Node",
	"blunty666.nodes.Drawable",
}

class = "BaseView"
extends = "Node"
implements = "IView"

variables = {
	background = NIL,
	size = NIL,
	width = NIL,
	height = NIL,
	backgroundColour = NIL,
}

getters = {
	size = function(self)
		return self.background.size
	end,
	width = function(self)
		return self.background.width
	end,
	height = function(self)
		return self.background.height
	end,
	backgroundColour = function(self)
		return self.background.backgroundColour
	end,
}

setters = {
	size = function(self, size)
		self.background.size = size
	end,
	width = function(self, width)
		self.background.width = width
	end,
	height = function(self, height)
		self.background.height = height
	end,
	backgroundColour = function(self, backgroundColour)
		self.background.backgroundColour = backgroundColour
	end,
}

methods = {
	HandleEvent = function(self)
	end,
}

constructor = function(self, node, x, y, order, width, height, backgroundColour)
	self.super(node, x, y, order)

	self.background = Drawable(self, 0, 0, 1)
	self.backgroundColour = backgroundColour
	self.size = {width, height}
end

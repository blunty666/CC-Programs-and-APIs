package = "blunty666.nodes.gui.objects"

class = "CheckBox"
extends = "Button"

constructor = function(self, node, x, y, order)
	self.super(node, x, y, order, " ", colours.white, colours.black, 1, 1)
	self.isToggle = true
	self.activeMainColour = colours.white
	self.activeTextColour = colours.black
	self.activeText = "X"
end

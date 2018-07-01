package = "blunty666.nodes.gui.events"

class = "CharEvent"
extends = "BaseEvent"

variables = {
	char = NIL,
}

local function checkChar(char)
	return char -- TODO
end

constructor = function(self, char)
	self.super("char")
	self.raw.char = checkChar(char)
end

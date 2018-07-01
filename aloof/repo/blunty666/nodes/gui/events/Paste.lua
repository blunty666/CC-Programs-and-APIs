package = "blunty666.nodes.gui.events"

class = "PasteEvent"
extends = "BaseEvent"

variables = {
	data = NIL,
}

local function checkData(data)
	return data -- TODO
end

constructor = function(self, data)
	self.super("paste")
	self.raw.data = checkData(data)
end

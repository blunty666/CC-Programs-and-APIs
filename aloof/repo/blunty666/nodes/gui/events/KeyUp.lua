package = "blunty666.nodes.gui.events"

class = "KeyUpEvent"
extends = "BaseEvent"

variables = {
	key = NIL,
}

local function checkKey(key)
	return key -- TODO
end

constructor = function(self, key)
	self.super("key_up")
	self.raw.key = checkKey(key)
end

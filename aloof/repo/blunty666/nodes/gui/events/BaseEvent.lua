package = "blunty666.nodes.gui.events"

class = "BaseEvent"

variables = {
	name = NIL,
}

local function checkName(name)
	return (type(name) == "string" and name) or error("name : string expected, got - <"..type(name).."> "..tostring(name))
end

constructor = function(self, name)
	self.raw.name = checkName(name)
end

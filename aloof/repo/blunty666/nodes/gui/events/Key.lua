package = "blunty666.nodes.gui.events"

class = "KeyEvent"
extends = "BaseEvent"

variables = {
	key = NIL,
	isRepeat = false,
}

local function checkKey(key)
	return key -- TODO
end

local function checkIsRepeat(isRepeat)
	return isRepeat -- TODO
end

constructor = function(self, key, isRepeat)
	self.super("key")
	self.raw.key = checkKey(key)
	self.raw.isRepeat = checkIsRepeat(isRepeat)
end

package = "blunty666.nodes_demo"

class = "ItemList"

local ITEM_TEXT = 1
local ITEM_CAN_UPDATE = 2
local ITEM_CAN_REMOVE = 3

static = {
	variables = {
		ITEM_TEXT = ITEM_TEXT,
		ITEM_CAN_UPDATE = ITEM_CAN_UPDATE,
		ITEM_CAN_REMOVE = ITEM_CAN_REMOVE,
	},
}

variables = {
	nextID = 1,
	items = {},
}

getters = {
	nextID = function(self, nextID)
		self.nextID = nextID + 1
		return nextID
	end,
}

methods = {
	Add = function(self, text, canUpdate, canRemove)
		if type(text) == "string" then
			local ID = self.nextID
			local item = {
				[ITEM_TEXT] = text,
				[ITEM_CAN_UPDATE] = (canUpdate ~= nil and canUpdate) or true,
				[ITEM_CAN_REMOVE] = (canRemove ~= nil and canRemove) or true,
			}
			self.items[ID] = item
			os.queueEvent("nodes_demo", "item_add", ID)
			return ID
		end
		return false
	end,
	Get = function(self, ID)
		local item = self.items[ID]
		if item then
			return {item[1], item[2], item[3]}
		end
		return false
	end,
	GetAll = function(self)
		local items = {}
		for ID, item in pairs(self.items) do
			items[ID] = self:Get(ID)
		end
		return items
	end,
	Update = function(self, ID, text, canUpdate, canRemove)
		local item = self.items[ID]
		if item then
			if type(text) == "string" then item[ITEM_TEXT] = text end
			if type(canUpdate) == "boolean" then item[ITEM_CAN_UPDATE] = canUpdate end
			if type(canRemove) == "boolean" then item[ITEM_CAN_REMOVE] = canRemove end
			os.queueEvent("nodes_demo", "item_update", ID)
			return true
		end
		return false
	end,
	Remove = function(self, ID)
		if self.items[ID] then
			self.items[ID] = false
			os.queueEvent("nodes_demo", "item_remove", ID)
		end
		return false
	end,
}

constructor = function(self, items)
	for _, item in ipairs(items) do
		self:Add(unpack(item))
	end
end

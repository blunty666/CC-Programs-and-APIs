package = "blunty666.nodes"

imports = "aloof.TypeChecker"

class = "BaseNode"

variables = {
	ID = NIL, -- unique ID of this node - is set by master node
	parent = NIL, -- parent node of this node
	masterNode = NIL, -- master node for all other nodes

	map = {},

	x = 0, -- x position relative to parent node
	y = 0, -- y position relative to parent node
	pos = NIL, -- used as a variable to allow setting x and y at the same time

	absX = NIL, -- x position relative to main term
	absY = NIL, -- y position relative to main term
	absPos = NIL,

	order = NIL, -- the order of this node in the parent node - tracked by the parent node 

	drawn = NIL, -- true if and only if visible AND clickable
	visible = true, -- whether this node is visible on screen
	clickable = true, -- whether this node should be clickable on screen

	active = NIL, -- whether this node is in the active chain

	callbacks = {},
	userdata = NIL,
}

getters = {
	pos = function(self)
		return {self.x, self.y}
	end,

	absPos = function(self)
		return {self.absX, self.absY}
	end,

	order = function(self)
		return self.parent:GetOrder(self.ID)
	end,

	drawn = function(self)
		return self.visible and self.clickable
	end,

	active = function(self)
		return self.parent:GetActiveSubNode(self.ID)
	end,
}

setters = {
	x = function(self, x)
		if TypeChecker.integer(x) then
			self.pos = {x, self.y}
			return self.x
		end
		return error("BaseNode - setters - x: integer expected, got <"..type(x).."> "..tostring(x), 2)
	end,
	y = function(self, y)
		if TypeChecker.integer(y) then
			self.pos = {self.x, y}
			return self.y
		end
		return error("BaseNode - setters - y: integer expected, got <"..type(y).."> "..tostring(y), 2)
	end,
	pos = function(self, pos)
		if TypeChecker.integer_double(pos) then

			local oldX, oldY = self.raw.x, self.raw.y
			local newX, newY = pos[1], pos[2]
			if newX ~= oldX or newY ~= oldY then -- position has changed

				self.raw.x, self.raw.y = newX, newY -- update values of x and y variables
				self.absPos = {self.parent.absX + newX, self.parent.absY + newY}
				if self:_IsDrawn() then

					local parent, deltaX, deltaY = self.parent, newX - oldX, newY - oldY
					for xPos, yPos in self:_CoordIter() do

						if self:_CoordExists(xPos + deltaX, yPos + deltaY) then
							-- no need to update parent node coord
							-- need to check if coord is drawn on main term
								-- redraw if it is
							self:_RedrawCoord(xPos, yPos)
						else
							parent:_CheckCoordDrawn(newX + xPos, newY + yPos)
						end
						if not self:_CoordExists(xPos - deltaX, yPos - deltaY) then
							parent:_CheckCoordDrawn(oldX + xPos, oldY + yPos)
						end
					end
					self.masterNode:_CheckCursor()
				end
			end
			return nil
		end
		return error("BaseNode - setters - pos: integer_double expected, got <"..type(pos).."> "..tostring(pos), 2)
	end,

	absPos = function(self, absPos)
		if TypeChecker.integer_double(absPos) then
			self.absX, self.absY = absPos[1], absPos[2]
			return nil
		end
		return error("BaseNode - setters - absPos: integer_double expected, got <"..type(absPos).."> "..tostring(absPos), 2)
	end,

	order = function(self, order)
		if TypeChecker.positive_integer(order) then
			self.parent:SetOrder(self.ID, order)
			return nil
		end
		return error("BaseNode - setters - order: positive_integer expected, got <"..type(order).."> "..tostring(order), 2)
	end,

	drawn = function(self, drawn)
		if type(drawn) == "boolean" then
			if self.visible ~= drawn and self.clickable ~= drawn then
				self.raw.visible, self.raw.clickable = drawn, drawn
				local parent, x, y = self.parent, self.x, self.y
				for xPos, yPos in self:_CoordIter() do
					parent:_CheckCoordDrawn(x + xPos, y + yPos)
				end
				self.masterNode:_CheckCursor()
			elseif self.visible ~= drawn then
				self.visible = drawn
			elseif self.clickable ~= drawn then
				self.clickable = drawn
			end
			return nil
		end
		return error("BaseNode - setters - drawn: boolean expected, got <"..type(drawn).."> "..tostring(drawn), 2)
	end,
	visible = function(self, visible)
		if type(visible) == "boolean" then
			if visible ~= self.visible then
				self.raw.visible = visible
				local parent, x, y = self.parent, self.x, self.y
				for xPos, yPos in self:_CoordIter() do
					parent:_CheckCoordVisible(x + xPos, y + yPos)
				end
				self.masterNode:_CheckCursor()
			end
			return self.visible
		end
		return error("BaseNode - setters - visible: boolean expected, got <"..type(visible).."> "..tostring(visible), 2)
	end,
	clickable = function(self, clickable)
		if type(clickable) == "boolean" then
			if clickable ~= self.clickable then
				self.raw.clickable = clickable
				local parent, x, y = self.parent, self.x, self.y
				for xPos, yPos in self:_CoordIter() do
					parent:_CheckCoordClickable(x + xPos, y + yPos) -- false for no redraw needed
				end
				self.masterNode:_CheckCursor()
			end
			return self.clickable
		end
		return error("BaseNode - setters - clickable: boolean expected, got <"..type(clickable).."> "..tostring(clickable), 2)
	end,

	active = function(self, active)
		if type(active) == "boolean" then
			self.parent:SetActiveSubNode(self.ID, active)
			return nil
		end
		return error("BaseNode - setters - active: boolean expected, got <"..type(active).."> "..tostring(active), 2)
	end,
}

methods = {
	_IsDrawn = function(self)
		if self.visible == false and self.clickable == false then
			return false
		end
		return true
	end,

	GetActive = function(self, localOnly)
		return self.parent:GetActiveSubNode(self.ID, localOnly)
	end,
	SetActive = function(self, active, localOnly)
		if type(active) == "boolean" then
			return self.parent:SetActiveSubNode(self.ID, active, localOnly)
		end
		return error("BaseNode - methods - SetActive: boolean expected, got <"..type(active).."> "..tostring(active), 2)
	end,

	GetCallbacks = function(self, callback)
		if type(callback) == "string" then
			if self.callbacks[callback] then
				local callbacks = {}
				for id, value in pairs(self.callbacks[callback]) do
					callbacks[id] = value
				end
				return callbacks
			end
		end
		return false
	end,
	GetCallback = function(self, callback, id)
		if type(callback) == "string" and type(id) == "string" then
			if self.callbacks[callback] then
				return self.callbacks[callback][id]
			end
		end
		return nil
	end,
	SetCallback = function(self, callback, id, value)
		if type(callback) == "string" and type(id) == "string" and (value == nil or type(value) == "function") then
			if value == nil and self.callbacks[callback] then
				self.callbacks[callback][id] = nil
				if not next(self.callbacks[callback]) then
					self.callbacks[callback] = nil
				end
			elseif value then
				if not self.callbacks[callback] then
					self.callbacks[callback] = {
						[id] = value,
					}
				else
					self.callbacks[callback][id] = value
				end
			end
			return true
		end
		return false
	end,

	Delete = function(self)
		self.drawn = false -- clears coords in chain
		self.active = false -- clears active data in chain

		self.masterNode.allSubNodes[self.ID] = nil
		self.parent.subNodes[self.ID] = nil
		for order, subNodeID in ipairs(self.parent.orderedList) do
			if subNodeID == self.ID then
				table.remove(self.parent.orderedList, order)
				break
			end
		end
	end,
}

constructor = function(self, parent, x, y, order)
	self.ID = parent.masterNode.nextID

	-- add to subNode lists
	parent.masterNode.allSubNodes[self.ID] = self
	parent.subNodes[self.ID] = self
	table.insert(parent.orderedList, order and math.min(order, #parent.orderedList + 1) or 1, self.ID)

	self.masterNode = parent.masterNode
	self.parent = parent

	-- check x y
	self.absPos = {parent.absX + self.x, parent.absY + self.y}
	self.pos = {x or 0, y or 0}
end

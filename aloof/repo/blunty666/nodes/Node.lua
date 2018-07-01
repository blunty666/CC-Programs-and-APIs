package = "blunty666.nodes"

imports = "aloof.TypeChecker"

class = "Node"
extends = "BaseNode"
implements = {
	"INodeController",
	"ISubNode",
}

local TEXT = 1
local TEXT_COLOUR = 2
local BACKGROUND_COLOUR = 3

local VISIBLE_ID = 1
local CLICKABLE_ID = 2
local NODE_VISIBLE_ID = 3
local NODE_CLICKABLE_ID = 4

local function findNextLine(map, yPos)
	local retX, retY = nil, next(map, yPos)
	if retY then retX = next(map[retY]) end
	return retX, retY
end

local function newCoord(visibleID, visibleNodeID, clickableID, clickableNodeID)
	return {
		[VISIBLE_ID] = visibleID,
		[NODE_VISIBLE_ID] = visibleNodeID,
		[CLICKABLE_ID] = clickableID,
		[NODE_CLICKABLE_ID] = clickableNodeID,
	}
end

--===== VISIBLE CHANGES =====--
local function addVisibleCoord(node, xPos, yPos, foundVisible, foundVisibleNode)
	local coord = newCoord(foundVisible, foundVisibleNode, false, false)
	if not node.map[yPos] then
		node.map[yPos] = { [xPos] = coord }
	else
		node.map[yPos][xPos] = coord
	end
	if node.visible then node.parent:_CheckCoordVisible(node.x + xPos, node.y + yPos) end -- push changes
end

local function updateVisibleCoord(node, xPos, yPos, coord, foundVisible, foundVisibleNode)
	if coord[VISIBLE_ID] ~= foundVisible then -- visible drawable has changed
		coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = foundVisible, foundVisibleNode -- update coord
		if node.visible then node.parent:_CheckCoordVisible(node.x + xPos, node.y + yPos) end -- push changes
	end
end

local function clearVisibleCoord(node, xPos, yPos, coord)
	if not coord[CLICKABLE_ID] then
		node.map[yPos][xPos] = nil -- delete coord
		if not next(node.map[yPos]) then node.map[yPos] = nil end -- delete line
	else -- just clear visible IDs
		coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = false, false
	end
	if node.visible then node.parent:_CheckCoordVisible(node.x + xPos, node.y + yPos) end -- push changes
end

local function checkSubNodeVisible(xPos, yPos, subNodeID, subNode)
	if subNode.visible then -- only check if this subNode is visible
		local relX, relY = xPos - subNode.x, yPos - subNode.y
		local subNodeCoord = subNode:_GetCoord(relX, relY)
		if subNodeCoord then -- skip if subNode doesnt have coord here
			if subNode:InstanceOf(Drawable) then
				return subNodeID, false
			elseif subNodeCoord[VISIBLE_ID] then
				return subNodeCoord[VISIBLE_ID], subNodeID
			end
		end
	end
	return false, false
end

--===== CLICKABLE CHANGES =====--
local function addClickableCoord(node, xPos, yPos, foundClickable, foundClickableNode)
	local coord = newCoord(false, false, foundClickable, foundClickableNode)
	if not node.map[yPos] then
		node.map[yPos] = { [xPos] = coord }
	else
		node.map[yPos][xPos] = coord
	end
	if node.clickable then node.parent:_CheckCoordClickable(node.x + xPos, node.y + yPos) end -- push changes
end

local function updateClickableCoord(node, xPos, yPos, coord, foundClickable, foundClickableNode)
	if coord[CLICKABLE_ID] ~= foundClickable then -- clickable drawable has changed
		coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = foundClickable, foundClickableNode -- update coord
		if node.clickable then node.parent:_CheckCoordClickable(node.x + xPos, node.y + yPos) end --push changes
	end
end

local function clearClickableCoord(node, xPos, yPos, coord)
	if not coord[VISIBLE_ID] then
		node.map[yPos][xPos] = nil -- delete coord
		if not next(node.map[yPos]) then node.map[yPos] = nil end -- delete line
	else -- just clear visible IDs
		coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = false, false
	end
	if node.clickable then node.parent:_CheckCoordClickable(node.x + xPos, node.y + yPos) end -- push changes
end

local function checkSubNodeClickable(xPos, yPos, subNodeID, subNode)
	if subNode.clickable then -- only check if this subNode is visible
		local relX, relY = xPos - subNode.x, yPos - subNode.y
		local subNodeCoord = subNode:_GetCoord(relX, relY)
		if subNodeCoord then -- skip if subNode doesnt have coord here
			if subNode:InstanceOf(Drawable) then
				return subNodeID, false
			else
				return subNodeCoord[CLICKABLE_ID], subNodeID
			end
		end
	end
	return false, false
end

--===== DRAWN CHANGES =====--
local function pushDrawnChanges(node, xPos, yPos)
	local visible, clickable = node.visible, node.clickable
	if visible and clickable then
		node.parent:_CheckCoordDrawn(node.x + xPos, node.y + yPos)
	elseif visible then
		node.parent:_CheckCoordVisible(node.x + xPos, node.y + yPos)
	elseif clickable then
		node.parent:_CheckCoordClickable(node.x + xPos, node.y + yPos)
	end
end

local function addDrawnCoord(node, xPos, yPos, foundVisible, foundVisibleNode, foundClickable, foundClickableNode)
	local coord = newCoord(foundVisible, foundVisibleNode, foundClickable, foundClickableNode)
	if not node.map[yPos] then
		node.map[yPos] = { [xPos] = coord }
	else
		node.map[yPos][xPos] = coord
	end
	pushDrawnChanges(node, xPos, yPos)
end

local function clearDrawnCoord(node, xPos, yPos)
	node.map[yPos][xPos] = nil -- delete coord
	if not next(node.map[yPos]) then node.map[yPos] = nil end -- delete line
	pushDrawnChanges(node, xPos, yPos)
end

local function checkSubNodeDrawn(xPos, yPos, subNodeID, subNode)
	local relX, relY = xPos - subNode.x, yPos - subNode.y
	local subNodeCoord = subNode:_GetCoord(relX, relY)
	if subNodeCoord then -- skip if subNode doesnt have coord here
		local visible, clickable = subNode.visible, subNode.clickable
		if visible and clickable then
			if subNode:InstanceOf(Drawable) then
				return subNodeID, false, subNodeID, false
			else
				return subNodeCoord[VISIBLE_ID], subNodeID, subNodeCoord[CLICKABLE_ID], subNodeID
			end
		elseif visible then -- not clickable
			if subNode:InstanceOf(Drawable) then
				return subNodeID, false, false, false
			else
				return subNodeCoord[VISIBLE_ID], subNodeID, false, false
			end
		elseif clickable then -- not visible
			if subNode:InstanceOf(Drawable) then
				return false, false, subNodeID, false
			else
				return false, false, subNodeCoord[CLICKABLE_ID], subNodeID
			end
		end
	end
	return false, false, false, false
end

--===== CHECK ACTIVE =====--
local function checkActiveDrawable(node, subNodeID, subNode, active, localOnly)
	if active then
		if localOnly == true then
			if node.activeDrawable ~= subNodeID then
				node.activeDrawable = subNodeID
				node.activeSubNode = false
				if node.parent.activeSubNode == node.ID then
					node.parent:_CheckActiveSubNode()
				end
			end
		else
			if node.masterNode.activeDrawable ~= subNodeID then
				node.activeDrawable = subNodeID
				node.activeSubNode = false
				node.parent:SetActiveSubNode(node.ID, true)
			end
		end
	else
		if node.activeDrawable == subNodeID then
			node.activeDrawable = false
			node.activeSubNode = false
			if node.parent.activeSubNode == node.ID then
				node.parent:_CheckActiveSubNode()
			end
		end
	end
end

local function checkActiveSubNode(node, subNodeID, subNode, active, localOnly)
	if active then
		if localOnly == true then
			if node.activeSubNode ~= subNodeID then
				node.activeDrawable = subNode.activeDrawable
				node.activeSubNode = subNodeID
				if node.parent.activeSubNode == node.ID then
					node.parent:_CheckActiveSubNode()
				end
			end
		else
			if node.masterNode.activeDrawable ~= subNode.activeDrawable then
				node.activeDrawable = subNode.activeDrawable
				node.activeSubNode = subNodeID
				node.parent:SetActiveSubNode(node.ID, true)
			end
		end
	else
		if node.activeDrawable == subNode.activeDrawable then
			node.activeDrawable = false
			node.activeSubNode = false
			if node.parent.activeSubNode == node.ID then
				node.parent:_CheckActiveSubNode()
			end
		end
	end
end

variables = {
	subNodes = {},
	orderedList = {},

	activeSubNode = NIL,
	activeDrawable = NIL,
}

getters = {}

setters = {
	absPos = function(self, absPos)
		if TypeChecker.integer_double(absPos) then

			local absX, absY = absPos[1], absPos[2]
			self.absX, self.absY = absX, absY

			for _, subNode in pairs(self.subNodes) do
				subNode.absPos = {absX + subNode.x, absY + subNode.y}
			end

			return nil
		end
		return error("Node - setters - absPos: integer_double expected, got <"..type(absPos).."> "..tostring(absPos), 2)
	end,
}

methods = {
	_CheckCoordVisible = function(self, xPos, yPos)
		local foundVisible, foundVisibleNode = false, false
		for _, subNodeID in ipairs(self.orderedList) do
			foundVisible, foundVisibleNode = checkSubNodeVisible(xPos, yPos, subNodeID, self.subNodes[subNodeID])
			if foundVisible then break end
		end

		local coord = self:_GetCoord(xPos, yPos)
		if coord then
			if foundVisible then
				updateVisibleCoord(self, xPos, yPos, coord, foundVisible, foundVisibleNode)
			elseif coord[VISIBLE_ID] then -- coord no longer visible
				clearVisibleCoord(self, xPos, yPos, coord)
			end
		elseif foundVisible then
			addVisibleCoord(self, xPos, yPos, foundVisible, foundVisibleNode)
		end
	end,
	_CheckCoordClickable = function(self, xPos, yPos)
		local foundClickable, foundClickableNode = false, false
		for _, subNodeID in ipairs(self.orderedList) do
			foundClickable, foundClickableNode = checkSubNodeClickable(xPos, yPos, subNodeID, self.subNodes[subNodeID])
			if foundClickable then break end
		end

		local coord = self:_GetCoord(xPos, yPos)
		if coord then
			if foundClickable then
				updateClickableCoord(self, xPos, yPos, coord, foundClickable, foundClickableNode)
			elseif coord[CLICKABLE_ID] then -- coord no longer clickable
				clearClickableCoord(self, xPos, yPos, coord)
			end
		elseif foundClickable then
			addClickableCoord(self, xPos, yPos, foundClickable, foundClickableNode)
		end
	end,
	_CheckCoordDrawn = function(self, xPos, yPos)
		local foundVisible, foundVisibleNode, foundClickable, foundClickableNode = false, false, false, false
		for _, subNodeID in ipairs(self.orderedList) do
			if not (foundVisible or foundClickable) then
				foundVisible, foundVisibleNode, foundClickable, foundClickableNode = checkSubNodeDrawn(xPos, yPos, subNodeID, self.subNodes[subNodeID])
			elseif not foundVisible then
				foundVisible, foundVisibleNode = checkSubNodeVisible(xPos, yPos, subNodeID, self.subNodes[subNodeID])
			elseif not foundClickable then
				foundClickable, foundClickableNode = checkSubNodeClickable(xPos, yPos, subNodeID, self.subNodes[subNodeID])
			end
			if foundVisible and foundClickable then
				break
			end
		end

		local coord = self:_GetCoord(xPos, yPos)
		if coord then
			if foundVisible and foundClickable then
				if coord[VISIBLE_ID] and coord[CLICKABLE_ID] then
					local visibleChanged, clickableChanged = false, false
					if coord[VISIBLE_ID] ~= foundVisible then
						coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = foundVisible, foundVisibleNode
						visibleChanged = true
					end
					if coord[CLICKABLE_ID] ~= foundClickable then
						coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = foundClickable, foundClickableNode
						clickableChanged = true
					end
					if visibleChanged and clickableChanged then
						pushDrawnChanges(self, xPos, yPos)
					elseif visibleChanged then
						if self.visible then self.parent:_CheckCoordVisible(self.x + xPos, self.y + yPos) end
					elseif clickableChanged then
						if self.clickable then self.parent:_CheckCoordClickable(self.x + xPos, self.y + yPos) end
					end
				elseif coord[VISIBLE_ID] then
					coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = foundClickable, foundClickableNode -- add clickable
					if coord[VISIBLE_ID] ~= foundVisible then-- check for visible changes
						coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = foundVisible, foundVisibleNode
						pushDrawnChanges(self, xPos, yPos) -- both changed
					else
						if self.clickable then self.parent:_CheckCoordClickable(self.x + xPos, self.y + yPos) end -- only clickable has changed
					end
				elseif coord[CLICKABLE_ID] then
					coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = foundVisible, foundVisibleNode -- add visible
					if coord[CLICKABLE_ID] ~= foundClickable then-- check for clickable changes
						coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = foundClickable, foundClickableNode
						pushDrawnChanges(self, xPos, yPos) -- both changed
					else
						if self.visible then self.parent:_CheckCoordVisible(self.x + xPos, self.y + yPos) end -- only visible has changed
					end
				else -- this coord shouldnt be here ???
					printError("empty coord!!!")
					addDrawnCoord(self, xPos, yPos, foundVisible, foundVisibleNode, foundClickable, foundClickableNode)
				end
			elseif foundVisible then
				if coord[VISIBLE_ID] and coord[CLICKABLE_ID] then
					coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = false, false -- clear clickable
					if coord[VISIBLE_ID] ~= foundVisible then-- check for visible changes
						coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = foundVisible, foundVisibleNode
						pushDrawnChanges(self, xPos, yPos) -- both changed
					else
						if self.clickable then self.parent:_CheckCoordClickable(self.x + xPos, self.y + yPos) end -- only clickable has changed
					end
				elseif coord[VISIBLE_ID] then
					updateVisibleCoord(self, xPos, yPos, coord, foundVisible, foundVisibleNode)
				elseif coord[CLICKABLE_ID] then
					-- clear clickable
					-- add visible
					-- both changed so just addDrawnCoord
					addDrawnCoord(self, xPos, yPos, foundVisible, foundVisibleNode, false, false)
				else
					addVisibleCoord(self, xPos, yPos, foundVisible, foundVisibleNode)
				end
			elseif foundClickable then
				if coord[VISIBLE_ID] and coord[CLICKABLE_ID] then
					coord[VISIBLE_ID], coord[NODE_VISIBLE_ID] = false, false -- clear visible
					if coord[CLICKABLE_ID] ~= foundClickable then-- check for clickable changes
						coord[CLICKABLE_ID], coord[NODE_CLICKABLE_ID] = foundClickable, foundClickableNode
						pushDrawnChanges(self, xPos, yPos) -- both changed
					else
						if self.visible then self.parent:_CheckCoordVisible(self.x + xPos, self.y + yPos) end -- only visible has changed
					end
				elseif coord[VISIBLE_ID] then
					-- clear visible
					-- add clickable
					-- both changed so just addDrawnCoord
					addDrawnCoord(self, xPos, yPos, false, false, foundClickable, foundClickableNode)
				elseif coord[CLICKABLE_ID] then
					updateClickableCoord(self, xPos, yPos, coord, foundClickable, foundClickableNode)
				else
					addClickableCoord(self, xPos, yPos, foundClickable, foundClickableNode)
				end
			else
				clearDrawnCoord(self, xPos, yPos)
			end
		else
			if foundVisible and foundClickable then
				addDrawnCoord(self, xPos, yPos, foundVisible, foundVisibleNode, foundClickable, foundClickableNode)
			elseif foundVisible then
				addVisibleCoord(self, xPos, yPos, foundVisible, foundVisibleNode)
			elseif foundClickable then
				addClickableCoord(self, xPos, yPos, foundClickable, foundClickableNode)
			else
				-- do nothing
			end
		end
	end,
	_GetCoord = function(self, xPos, yPos)
		return self.map[yPos] and self.map[yPos][xPos] or false
	end,

	_CoordIter = function(self)
		local map = self.map
		local xPos, yPos = findNextLine(map)
		return function()
			local retX, retY = xPos, yPos
			if yPos then
				if not xPos then -- this line is done
					xPos, yPos = findNextLine(map, yPos)
				else -- keep iterating current line
					xPos = next(map[yPos], xPos) -- get next xPos in the line
					if not xPos then -- start next line
						xPos, yPos = findNextLine(map, yPos)
					end
				end
			else -- no more lines
				xPos = nil
			end
			return retX, retY
		end
	end,
	_CoordExists = function(self, xPos, yPos)
		return self.map[yPos] and self.map[yPos][xPos] ~= nil or false
	end,
	_RedrawCoord = function(self, xPos, yPos)
		local coord = self:_GetCoord(xPos, yPos)
		if coord then
			local parX, parY = self.x + xPos, self.y + yPos
			local parentCoord = self.parent:_GetCoord(parX, parY)
			local checkVisible = false
			if parentCoord then
				if parentCoord[NODE_VISIBLE_ID] ~= self.ID or parentCoord[VISIBLE_ID] ~= coord[VISIBLE_ID] then
					checkVisible = true
				else
					-- redraw coord
					local masX, masY = self.absX + xPos, self.absY + yPos
					local masterNode, drawableID = self.masterNode, coord[VISIBLE_ID]
					local masterNodeCoord = masterNode:_GetCoord(masX, masY)
					if masterNodeCoord and masterNodeCoord[VISIBLE_ID] == drawableID then
						local drawable = masterNode.allSubNodes[drawableID]
						local draX, draY = masX - drawable.absX, masY - drawable.absY
						local drawableCoord = drawable:_GetCoord(draX, draY)
						masterNode:_DrawCoord(masX, masY, drawableCoord[TEXT], drawableCoord[TEXT_COLOUR], drawableCoord[BACKGROUND_COLOUR])
					end
				end
				local checkClickable = false
				if parentCoord[NODE_CLICKABLE_ID] ~= self.ID or parentCoord[CLICKABLE_ID] ~= coord[CLICKABLE_ID] then
					checkClickable = true
				end
				if (checkVisible and self.visible) and (checkClickable and self.clickable) then
					self.parent:_CheckCoordDrawn(self.x + xPos, self.y + yPos)
				elseif checkVisible and self.visible then
					self.parent:_CheckCoordVisible(self.x + xPos, self.y + yPos)
				elseif checkClickable and self.clickable then
					self.parent:_CheckCoordClickable(self.x + xPos, self.y + yPos)
				end
			end
		end
	end,

	GetOrder = function(self, subNodeID)
		for order, _subNodeID in ipairs(self.orderedList) do
			if _subNodeID == subNodeID then
				return order
			end
		end
		return false
	end,
	SetOrder = function(self, subNodeID, order)
		local subNode = self.subNodes[subNodeID]
		if subNode then
			if TypeChecker.positive_integer(order) then

				order = math.min(order, #self.orderedList)
				for _order, _subNodeID in ipairs(self.orderedList) do
					if _subNodeID == subNodeID then
						if _order ~= order then
							table.insert(self.orderedList, order, table.remove(self.orderedList, _order))
							if subNode:_IsDrawn() then
								local x, y = subNode.x, subNode.y
								for xPos, yPos in subNode:_CoordIter() do
									self:_CheckCoordDrawn(x + xPos, y + yPos)
								end
								subNode.masterNode:_CheckCursor()
							end
						end
						return order
					end
				end

			end
			return error("Node - methods - SetOrder: positive_integer expected, got <"..type(order).."> "..tostring(order), 2)
		end
		return false
	end,

	_CheckActiveSubNode = function(self)
		local subNode = self.subNodes[self.activeSubNode]
		if subNode and self.activeDrawable ~= subNode.activeDrawable then
			self.activeDrawable = subNode.activeDrawable
			if self.parent.activeSubNode == self.ID then
				self.parent:_CheckActiveSubNode()
			end
		end
	end,
	GetActiveSubNode = function(self, subNodeID, localOnly)
		local subNode = self.subNodes[subNodeID]
		if subNode then
			if localOnly == true then
				if subNode:InstanceOf(Drawable) then
					return self.activeDrawable == subNodeID
				else
					return self.activeSubNode == subNodeID
				end
			else
				if subNode:InstanceOf(Drawable) then
					return self.masterNode.activeDrawable == subNodeID
				else
					return self.masterNode.activeSubNode == subNodeID
				end
			end
		end
		return error("Node - methods - GetActiveSubNode: subNodeID expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,
	SetActiveSubNode = function(self, subNodeID, active, localOnly)
		-- localOnly ONLY applies if not activeDrawable or activeSubNode in masterNode or if c
		local subNode = self.subNodes[subNodeID]
		if subNode then -- update activeDrawable and activeSubNode
			if type(active) == "boolean" then
				if subNode:InstanceOf(Drawable) then
					checkActiveDrawable(self, subNodeID, subNode, active, localOnly)
				else
					checkActiveSubNode(self, subNodeID, subNode, active, localOnly)
				end
				return
			end
			return error("Node - methods - SetActiveSubNode: boolean expected, got <"..type(active).."> "..tostring(active), 1)
		elseif subNodeID == false then -- clear activeDrawable and activeSubNode
			self.activeSubNode = false
			self.activeDrawable = false
			if self.parent.activeSubNode == self.ID then
				self.parent:_CheckActiveSubNode()
			end
			return
		end
		return error("Node - methods - SetActiveSubNode: subNodeID or false expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,

	GetVisibleAt = function(self, xPos, yPos)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				return coord[VISIBLE_ID]
			end
			return false
		end
		return error("Node - methods - GetVisibleAt: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos))
	end,
	GetClickableAt = function(self, xPos, yPos)
		if TypeChecker.integer(xPos) and TypeChecker.integer(yPos) then
			local coord = self:_GetCoord(xPos, yPos)
			if coord then
				return coord[CLICKABLE_ID]
			end
			return false
		end
		return error("Node - methods - GetClickableAt: integer, integer expected, got <"..type(xPos).."> "..tostring(xPos))
	end,

	AddNode = function(self, x, y, order)
		return Node(self, x, y, order)
	end,
	AddDrawable = function(self, x, y, order)
		return Drawable(self, x, y, order)
	end,

	GetSubNode = function(self, subNodeID)
		if TypeChecker.positive_integer(subNodeID) then
			return self.subNodes[subNodeID] or false
		end
		return error("Node - methods - GetSubNode: positive_integer expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,
	DeleteSubNode = function(self, subNodeID)
		if TypeChecker.positive_integer(subNodeID) then
			local subNode = self.subNodes[subNodeID]
			if subNode then
				return subNode:Delete()
			end
			return false
		end
		return error("Node - methods - DeleteSubNode: positive_integer expected, got <"..type(subNodeID).."> "..tostring(subNodeID), 1)
	end,

	GetAllSubNodes = function(self)
		local subNodes = {}
		for subNodeID, subNode in pairs(self.subNodes) do
			subNodes[subNodeID] = subNode
		end
		return subNodes
	end,
	DeleteAllSubNodes = function(self)
		local subNodes = self:GetAllSubNodes()
		for _, subNode in pairs(subNodes) do
			subNode:Delete()
		end
	end,

	Delete = function(self)
		self:DeleteAllSubNodes()
		self.super:Delete()
	end,
}

constructor = function(self, parent, x, y, order)
	self.super(parent, x, y, order)
end

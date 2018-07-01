package = "blunty666.nodes.gui.objects"

imports = "blunty666.nodes.*"

class = "RadioButtonGroup"
extends = "Node"

variables = {
	selected = false,
	onSelectedChanged = false,
	buttons = NIL,
}

methods = {
	AddRadioButton = function(self, index, itemData) -- TODO
		if Utils.isIntegerWithinBounds(index, 1, #self.items + 1) then

			local widthChanged, itemWidth = updateSlider(self, #self.items + 1)

			table.insert(self.items, index, itemData)
			table.insert(self.itemNodes, newItem(self, self.itemsNode, #self.itemNodes + 1, itemWidth, {"", ""}))

			updateItemNodes(self, (widthChanged and 1) or index, itemWidth)
			redrawItemsNode(self, self.startIndex)

			if index == self.highlighted then
				self:SetHighlighted(self.highlighted + 1)
			end
			if index == self.selected then
				self:SetSelected(self.selected + 1, true)
			end

			return true
		end
		return false
	end,
	GetRadioButton = function(self, index) -- TODO
		if Utils.isIntegerWithinBounds(index, 1, #self.items) then
			return self.items[index]
		end
	end,
	RemoveRadioButton = function(self, index) -- TODO
		if Utils.isIntegerWithinBounds(index, 1, #self.items) then

			if index == self.highlighted then
				self:SetHighlighted(false)
			end
			if index == self.selected then
				self:SetSelected(false)
			end

			local widthChanged, itemWidth = updateSlider(self, #self.items - 1)

			table.remove(self.items, index)
			local itemNode = table.remove(self.itemNodes, #self.itemNodes)
			itemNode:Delete()

			updateItemNodes(self, (widthChanged and 1) or index, itemWidth)
			redrawItemsNode(self, self.startIndex)

			return true
		end
		return false
	end,

	SetSelected = function(self, index, noUpdate)
		if Utils.isIntegerWithinBounds(index, 1, #self.buttons) then
			-- deselect current selected if different
			if self.selected and self.selected ~= index then
				local currSelected = self.buttons[self.selected]
				if currSelected then
					currSelected.button.isActive = false
				end
			end

			-- select new radio button
			local newSelected = self.buttons[index]
			if newSelected then
				newSelected.button.isActive = true
				self.selected = index
			else
				self.selected = false
			end

			-- pass update to onSelectedChanged function
			if not noUpdate and self.onSelectedChanged then
				self.onSelectedChanged(self.selected)
			end

			return true
		end
		return false
	end,

	SetOnSelectedChanged = function(self, func)
		if func == false or type(func) == "function" then
			self.onSelectedChanged = func
			return true
		end
		return false
	end,
}

constructor = function(self, node, xPos, yPos, order, items)
	self.super(node, xPos, yPos, order)

	local buttons = {}
	for buttonNum, buttonData in ipairs(items) do
		buttons[buttonNum] = RadioButton(self, self, buttonData.xPos, buttonData.yPos, buttonData.order, buttonData.text, buttonData.textColour, buttonData.backgroundColour)
	end
	self.buttons = buttons
end

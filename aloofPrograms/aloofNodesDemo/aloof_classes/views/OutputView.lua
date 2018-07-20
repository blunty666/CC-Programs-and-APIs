package = "blunty666.nodes_demo.views"

imports = "blunty666.nodes.gui.objects.*"

class = "OutputView"
extends = "BaseView"

variables = {
	itemList = NIL,
	selectedID = false,

	selectedItemLabel = NIL,
	choiceBox = NIL,

	canUpdateLabel = NIL,
	canUpdateCheckBox = NIL,

	canRemoveLabel = NIL,
	canRemoveCheckBox = NIL,
}

setters = {
	selectedID = function(self, selectedID)
		if selectedID then
			local item = self.itemList:Get(selectedID)
			if item then
				self.canUpdateCheckBox.isActive = item[2]
				self.canRemoveCheckBox.isActive = item[3]
			end
		else
			self.canUpdateCheckBox.isActive = false
			self.canRemoveCheckBox.isActive = false
		end
		return selectedID
	end,
}

methods = {
	HandleEvent = function(self, event)
		if event[1] == "nodes_demo" then
			if event[2] == "item_add" then
				local itemID = event[3]
				local item = self.itemList:Get(itemID)
				if item then
					self.choiceBox.list:AddItem(math.huge, {itemID, itemID.." - "..item[1]})
				end
			elseif event[2] == "item_update" then
				local itemID = event[3]
				local item = self.itemList:Get(itemID)
				if item then
					for index, listItem in ipairs(self.choiceBox.list.items) do
						if listItem[1] == itemID then
							self.choiceBox.list:SetItem(index, {itemID, itemID.." - "..item[1]})
							break
						end
					end
					if itemID == self.selectedID then
						self.canUpdateCheckBox.isActive = item[2]
						self.canRemoveCheckBox.isActive = item[3]
					end
				end
			elseif event[2] == "item_remove" then
				local itemID = event[3]
				for index, listItem in ipairs(self.choiceBox.list.items) do
					if listItem[1] == itemID then
						self.choiceBox.list:RemoveItem(index)
						if itemID == self.selectedID then
							self.choiceBox.label.text = ""
							self.selectedID = false
						end
						break
					end
				end
			end
		end
	end,
}

constructor = function(self, node, x, y, order, width, height, itemList)
	self.super(node, x, y, order, width, height, colours.white)

	self.itemList = itemList

	self.selectedItemLabel = Label(self, 1, 1, 1, "Selected Item:", width - 2, 1, colours.black, colours.blue)

	self.choiceBox = ChoiceBox(self, 1, 2, 1, width - 2, {}, height - 4)
	self.choiceBox.label.backgroundColour = colours.black
	self.choiceBox.label.textColour = colours.white
	self.choiceBox.onSelectedChanged = function(index, itemID)
		self.selectedID = itemID
	end

	self.canUpdateLabel = Label(self, 1, 4, 2, "Can update:", nil, 1, colours.black, colours.blue)
	self.canUpdateCheckBox = CheckBox(self, 12, 4, 2)
	self.canUpdateCheckBox.width = 3
	self.canUpdateCheckBox.horizontalAlignment = "RIGHT"
	self.canUpdateCheckBox.inactiveMainColour = colours.red
	self.canUpdateCheckBox.inactiveText = "No"
	self.canUpdateCheckBox.activeMainColour = colours.green
	self.canUpdateCheckBox.activeText = "Yes"
	self.canUpdateCheckBox.onRelease = function(button, isActive, wasActive)
		if self.selectedID then
			self.itemList:Update(self.selectedID, nil, isActive, nil)
		else
			self.canUpdateCheckBox.isActive = wasActive
		end
	end

	self.canRemoveLabel = Label(self, 1, 6, 2, "Can remove:", nil, 1, colours.black, colours.blue)
	self.canRemoveCheckBox = CheckBox(self, 12, 6, 2)
	self.canRemoveCheckBox.width = 3
	self.canRemoveCheckBox.horizontalAlignment = "RIGHT"
	self.canRemoveCheckBox.inactiveMainColour = colours.red
	self.canRemoveCheckBox.inactiveText = "No"
	self.canRemoveCheckBox.activeMainColour = colours.green
	self.canRemoveCheckBox.activeText = "Yes"
	self.canRemoveCheckBox.onRelease = function(button, isActive, wasActive)
		if self.selectedID then
			self.itemList:Update(self.selectedID, nil, nil, isActive)
		else
			self.canRemoveCheckBox.isActive = wasActive
		end
	end
end

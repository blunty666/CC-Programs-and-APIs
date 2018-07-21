package = "blunty666.nodes_demo.views"

imports = {
	"blunty666.nodes_demo.ItemList",
	"blunty666.nodes.gui.objects.*",
	"blunty666.log.Logger",
}

class = "InputView"
extends = "BaseView"

variables = {
	itemList = NIL,
	selectedID = false,

	listLabel = NIL,
	list = NIL,
	selectedLabel = NIL,
	selectedItemIDLabel = NIL,
	selectedItemID = NIL,
	selectedItemTextLabel = NIL,
	selectedItemText = NIL,
	textBoxLabel = NIL,
	textBox = NIL,
	addButton = NIL,
	updateButton = NIL,
	removeButton = NIL,
}

setters = {
	selectedID = function(self, selectedID)
		if selectedID then
			local item = self.itemList:Get(selectedID)
			if item then
				self.selectedItemID.text = tostring(selectedID)
				self.selectedItemText.text = tostring(item[ItemList.ITEM_TEXT])
				self.textBox.text = item[ItemList.ITEM_TEXT]
			end
		else
			self.selectedItemID.text = ""
			self.selectedItemText.text = ""
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
					self.list:AddItem(math.huge, {itemID, item[ItemList.ITEM_TEXT]})
				end
			elseif event[2] == "item_update" then
				local itemID = event[3]
				local item = self.itemList:Get(itemID)
				if item then
					for index, listItem in ipairs(self.list.items) do
						if listItem[1] == itemID then
							self.list:SetItem(index, {itemID, item[ItemList.ITEM_TEXT]})
							break
						end
					end
					if itemID == self.selectedID then
						self.selectedItemText.text = tostring(item[ItemList.ITEM_TEXT])
					end
				end
			elseif event[2] == "item_remove" then
				local itemID = event[3]
				for index, listItem in ipairs(self.list.items) do
					if listItem[1] == itemID then
						self.list:RemoveItem(index)
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

	--===== LIST =====--
	self.listLabel = Label(self, 1, 1, 1, "Items:", width - 2, 1, colours.black, colours.blue)

	self.list = List(self, 1, 2, 1, width - 2, height - 11, {})
	self.list.onSelectedChanged = function(index, itemID, itemText)
		self.selectedID = itemID
	end

	--===== SELECTED =====--
	self.selectedLabel = Label(self, 1, height - 8, 1, "Selected Item:", width - 2, 1, colours.black, colours.blue)

	self.selectedItemIDLabel = Label(self, 1, height - 7, 1, "ID:", nil, 1, colours.black, colours.cyan)

	self.selectedItemID = Label(self, 4, height - 7, 1, "", width - 5, 1, colours.white, colours.black)
	self.selectedItemID.horizontalAlignment = "RIGHT"

	self.selectedItemTextLabel = Label(self, 1, height - 6, 1, "Text:", nil, 1, colours.black, colours.cyan)

	self.selectedItemText = Label(self, 6, height - 6, 1, "", width - 7, 1, colours.white, colours.black)
	self.selectedItemText.horizontalAlignment = "RIGHT"

	--===== EDITOR =====--
	self.textBoxLabel = Label(self, 1, height - 4, 1, "Text Entry:", width - 2, 1, colours.black, colours.blue)

	self.textBox = TextBox(self, 1, height - 3, 1, width - 2)
	self.textBox.onEnter = function(text)
		if #text > 0 then
			self.itemList:Add(text)
		end
	end

	self.addButton = Button(self, 1, height - 2, 1, "Add", colours.lime, colours.black, nil, 1)
	self.addButton.clickedMainColour = colours.green
	self.addButton.onRelease = function()
		if #self.textBox.text > 0 then
			self.itemList:Add(self.textBox.text)
		end
	end

	self.updateButton = Button(self, 5, height - 2, 1, "Update", colours.cyan, colours.black, nil, 1)
	self.updateButton.clickedMainColour = colours.blue
	self.updateButton.onRelease = function()
		if self.selectedID then
			local item = self.itemList:Get(self.selectedID)
			if item[ItemList.ITEM_CAN_UPDATE] == true then
				if #self.textBox.text > 0 then
					self.itemList:Update(self.selectedID, self.textBox.text)
				end
			end
		end
	end

	self.removeButton = Button(self, 12, height - 2, 1, "Remove", colours.orange, colours.black, nil, 1)
	self.removeButton.clickedMainColour = colours.red
	self.removeButton.onRelease = function()
		if self.selectedID then
			local item = self.itemList:Get(self.selectedID)
			if item[ItemList.ITEM_CAN_REMOVE] == true then
				self.itemList:Remove(self.selectedID)
				self.selectedID = false
			end
		end
	end
end

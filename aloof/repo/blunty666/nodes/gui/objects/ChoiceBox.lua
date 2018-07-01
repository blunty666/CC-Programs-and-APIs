package = "blunty666.nodes.gui.objects"

imports = "blunty666.nodes.*"

class = "ChoiceBox"
extends = "Node"

variables = {
	label = NIL,
	list = NIL,
	onSelectedChanged = false,
}

setters = {
	onSelectedChanged = function(self, onSelectedChanged)
		if onSelectedChanged == false or type(onSelectedChanged) == "function" then
			return onSelectedChanged
		end
		return self.onSelectedChanged
	end,
}

constructor = function(self, node, xPos, yPos, order, boxWidth, listItems, listHeight)

	self.super(node, xPos, yPos, order)

	local label = Label(self, 0, 0, 1, "", boxWidth, 1, colours.black, colours.white)
	label.horizontalAlignment = "LEFT"

	local list = List(self, 0, 1, 2, boxWidth, listHeight, listItems)
	list.drawn = false

	local function labelClick()
		list.drawn = true
	end
	label:SetCallback("mouse_click", "choiceBox", labelClick)

	local function listSelect(index, itemID, itemText)
		label.text = itemText
		list.drawn = false
		if self.onSelectedChanged then
			self.onSelectedChanged(index, itemID, itemText)
		end
	end
	list.onSelectedChanged = listSelect

	local function nodeDeselect()
		list.drawn = false
	end
	self:SetCallback("deselect", "choiceBox", nodeDeselect)

	self.label = label
	self.list = list
end

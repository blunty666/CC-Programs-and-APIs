package = "blunty666.nodes.gui.objects"

imports = "blunty666.nodes.*"

class = "RadioButton"
extends = "Node"

variables = {
	group = NIL,
	button = NIL,
	label = NIL,
}

getters = {
	index = function(self)
		for index, radioButton in ipairs(self.group.buttons) do
			if radioButton == self then
				return index
			end
		end
		return false
	end,
}

constructor = function(self, node, group, xPos, yPos, order, labelText, labelTextColour, labelBackgroundColour)
	self.super(node, xPos, yPos, order)
	self.group = group

	local button = CheckBox(self, 0, 0, 1)
	button.activeText = "O"

	local label = Label(self, 2, 0, 1, labelText, nil, 1, labelTextColour, labelBackgroundColour)

	local function radioButtonOnRelease()
		group.selected = self.index
	end
	button.onRelease = radioButtonOnRelease
	label:SetCallback("mouse_up", "radioButton", radioButtonOnRelease)

	self.button = button
	self.label = label
end

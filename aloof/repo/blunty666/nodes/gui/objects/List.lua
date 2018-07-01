package = "blunty666.nodes.gui.objects"

imports = {
	"blunty666.nodes.*",
	"blunty666.log.Logger",
	"aloof.TypeChecker",
}

class = "List"
extends = "Node"

local function indexToItemLabel(index, scrollPosition)
	return index - scrollPosition
end

local function itemLabelToIndex(itemLabel, scrollPosition)
	return itemLabel + scrollPosition
end

local function isEven(integer)
	return integer % 2 == 0
end

local function setItemLabelColours(list, itemLabel, index, backgroundColour, textColour)
	itemLabel.backgroundColour = backgroundColour or (isEven(index) and list.evenBackgroundColour) or list.oddBackgroundColour
	itemLabel.textColour = textColour or (isEven(index) and list.evenTextColour) or list.oddTextColour
end

local function getItemID(item)
	if type(item) == "table" then
		return item[1]
	end
	return item
end

local function getItemText(item)
	if type(item) == "table" then
		return item[2]
	end
	return item
end

local function refreshItemLabels(list, scrollPosition, width, updateSlider)
	local itemIndex = itemLabelToIndex(1, scrollPosition)
	for index, itemLabel in ipairs(list.itemLabels) do
		if itemIndex == list.highlighted then
			setItemLabelColours(list, itemLabel, index, list.highlightedBackgroundColour, list.highlightedTextColour)
		elseif itemIndex == list.selected then
			setItemLabelColours(list, itemLabel, index, list.selectedBackgroundColour, list.selectedTextColour)
		else
			setItemLabelColours(list, itemLabel, index)
		end
		local item = list.raw.items[itemIndex]
		Logger:Info("  item = "..tostring(item))
		if item then
			itemLabel.text = getItemText(item)
		else
			itemLabel.text = ""
		end
		if width then
			itemLabel.width = width
		end
		itemIndex = itemIndex + 1
	end
	if updateSlider then
		list.slider:SetPercent(scrollPosition / (#list.raw.items - list.height), false)
	end
	list.raw.scrollPosition = scrollPosition
end

local function checkScrollPosition(list, index)
	if index - 1 < list.scrollPosition then
		return index - 1
	elseif index - list.height > list.scrollPosition then
		return index - list.height
	end
	return list.scrollPosition
end

local function setHighlighted(list, highlighted, updateScrollPosition, sendOnHighlightedChanged, mouseClickEvent)
	list.raw.highlighted = highlighted

	local scrollPosition = list.scrollPosition
	if highlighted and updateScrollPosition then
		scrollPosition = checkScrollPosition(list, highlighted)
	end

	refreshItemLabels(list, scrollPosition, false, list.scrollPosition ~= scrollPosition)

	if sendOnHighlightedChanged and list.onHighlightedChanged then
		local item = list.raw.items[highlighted] or false
		list.onHighlightedChanged(highlighted, getItemID(item), getItemText(item), mouseClickEvent)
	end
end

local function setSelected(list, selected, updateScrollPosition, sendOnSelectedChanged, mouseUpEvent)
	list.raw.selected = selected

	local scrollPosition = list.scrollPosition
	if selected and updateScrollPosition then
		scrollPosition = checkScrollPosition(list, selected)
	end

	refreshItemLabels(list, scrollPosition, false, list.scrollPosition ~= scrollPosition)

	if sendOnSelectedChanged and list.onSelectedChanged then
		local item = list.raw.items[selected] or false
		list.onSelectedChanged(selected, getItemID(item), getItemText(item), mouseUpEvent)
	end
end

local function itemLabelOnMouseClick(itemLabel, mouseClickEvent)
	local list, itemLabelIndex = unpack(itemLabel.userdata)
	local index = itemLabelToIndex(itemLabelIndex, list.scrollPosition)
	if list.raw.items[index] then
		setHighlighted(list, index, false, true, mouseClickEvent)
	end
end

local function itemLabelOnMouseUp(itemLabel, mouseUpEvent)
	local list, itemLabelIndex = unpack(itemLabel.userdata)
	local xPos, yPos = mouseUpEvent.x, mouseUpEvent.y
	if xPos >= 1 and xPos <= itemLabel.width and yPos == 1 then
		local index = itemLabelToIndex(itemLabelIndex, list.scrollPosition)
		if list.raw.items[index] then
			setHighlighted(list, false, false, true, false)
			setSelected(list, index, false, true, mouseUpEvent)
		end
	end
end

local function checkScrollPosition(list, scrollPosition)
	return math.max(0, math.min(#list.raw.items - list.height, scrollPosition))
end

local function itemLabelOnMouseScroll(itemLabel, mouseScrollEvent)
	local list, itemLabelIndex = unpack(itemLabel.userdata)
	local scrollPosition = checkScrollPosition(list, list.scrollPosition + mouseScrollEvent.scroll_dir)
	if scrollPosition ~= list.scrollPosition then
		refreshItemLabels(list, checkScrollPosition(list, scrollPosition), false, true)
	end
end

local function listNodeOnKey(list, object, keyEvent) -- check
	local key = keyEvent.key
	if key == keys.up then
		if list.highlighted then
			list.highlighted = math.max(1, list.highlighted - 1)
		elseif list.selected then
			list.highlighted = math.max(1, list.selected - 1)
		elseif #list.raw.items > 0 then
			list.highlighted = #list.raw.items
		end
	elseif key == keys.down then
		if list.highlighted then
			list.highlighted = math.min(#list.raw.items, list.highlighted + 1)
		elseif list.selected then
			list.highlighted = math.min(#list.raw.items, list.selected + 1)
		elseif list.raw.items[1] then
			list.highlighted = 1
		end
	elseif key == keys.enter then
		if list.highlighted then
			local highlighted = list.highlighted
			list.highlighted = false
			list.selected = highlighted
		elseif list.selected then
			if list.onSelectedChanged then
				local item = list.raw.items[list.selected] or false
				list.onSelectedChanged(list.selected, getItemID(item), getItemText(item))
			end
		end
	end
end

local function newItemLabel(list, index, width)
	local itemLabel = Label(list.itemsNode, 0, index - 1, 1, "", width, 1, list.evenTextColour, list.evenBackgroundColour)
	itemLabel.horizontalAlignment = "LEFT"
	itemLabel:SetCallback("mouse_click", "list", itemLabelOnMouseClick)
	itemLabel:SetCallback("mouse_up", "list", itemLabelOnMouseUp)
	itemLabel:SetCallback("mouse_scroll", "list", itemLabelOnMouseScroll)
	itemLabel.userdata = {list, index}
	return itemLabel
end

variables = {
	itemsNode = NIL,
	slider = NIL,

	width = 0,
	height = 0,
	size = NIL,

	itemLabels = {},
	items = {},
	scrollPosition = 0,

	highlighted = false,
	selected = false,

	onHighlightedChanged = false,
	onSelectedChanged = false,

	oddBackgroundColour = colours.grey,
	oddTextColour = colours.black,

	evenBackgroundColour = colours.lightGrey,
	evenTextColour = colours.black,

	highlightedBackgroundColour = colours.lime,
	highlightedTextColour = colours.black,

	selectedBackgroundColour = colours.green,
	selectedTextColour = colours.black,
}

getters = {
	items = function(self, items)
		local _items = {}
		for index, item in ipairs(items) do
			_items[index] = item
		end
		return _items
	end,
}

setters = {
	width = function(self, width)
		if TypeChecker.non_negative_integer(width) then
			self.size = {width, self.height}
			return self.width
		end
		return error("List - setters - width: non_negative_integer expected, got <"..type(width).."> "..tostring(width), 2)
	end,
	height = function(self, height)
		if TypeChecker.non_negative_integer(height) then
			self.size = {self.width, height}
			return self.height
		end
		return error("List - setters - height: non_negative_integer expected, got <"..type(height).."> "..tostring(height), 2)
	end,
	size = function(self, size)
		if TypeChecker.non_negative_integer_double(size) then

			local oldWidth, oldHeight = self.width, self.height
			local newWidth, newHeight = size[1], size[2]

			if oldWidth ~= newWidth or oldHeight ~= newHeight then

				-- update width and height variables
				self.raw.width, self.raw.height = newWidth, newHeight

				-- capture current values to check for changes
				local sliderDrawn = self.slider.drawn
				local scrollPosition = self.scrollPosition

				-- check height
				if oldHeight ~= newHeight then

					-- check slider
					self.slider:SetLength(math.max(1, newHeight))
					self.slider.drawn = newHeight > 0 and #self.raw.items > newHeight

					-- check scroll
					if newHeight >= #self.raw.items then
						scrollPosition = 0
					elseif self.scrollPosition + newHeight > #self.raw.items then
						scrollPosition = #self.raw.items - newHeight
					end

					-- check itemLabels
					if newHeight > oldHeight then -- add itemLabels
						for index = oldHeight + 1, newHeight do
							-- add itemLabel
							self.itemLabels[index] = newItemLabel(self, index, oldWidth)
						end
					elseif newHeight < oldHeight then -- remove itemLabels
						for index = newHeight + 1, oldHeight do
							-- remove itemLabel
							self.itemLabels[index]:Delete()
							self.itemLabels[index] = nil
						end
					end
				end

				-- check width
				local checkWidth = false
				if oldWidth ~= newWidth or sliderDrawn ~= self.slider.drawn then
					self.slider.x = newWidth - 1 -- update slider position
					checkWidth = (self.slider.drawn and newWidth - 1) or newWidth
					if checkWidth == oldWidth then
						checkWidth = false
					end
				end

				-- refresh itemLabels
				refreshItemLabels(self, scrollPosition, checkWidth)
			end
			return nil
		end
		return error("List - setters - size: non_negative_integer_double expected, got <"..type(height).."> "..tostring(height), 2)
	end,

	items = function(self, items)
		-- if checkItems(items) then
			self.raw.highlighted = false
			self.raw.selected = false
			self.raw.items = items
			refreshItemLabels(self, 0, false, true)
		-- end
		return self.items
	end,
	scrollPosition = function(self, scrollPosition)
		if TypeChecker.non_negative_integer(scrollPosition) and scrollPosition <= #self.raw.items - self.height then
			refreshItemLabels(self, scrollPosition, false, true)
		end
		return self.scrollPosition
	end,

	highlighted = function(self, highlighted)
		if TypeChecker.positive_integer(highlighted) and highlighted <= #self.raw.items or highlighted == false then
			setHighlighted(self, highlighted, true, true)
		end
		return self.highlighted
	end,
	selected = function(self, selected)
		if TypeChecker.positive_integer(selected) and selected <= #self.raw.items or selected == false then
			setSelected(self, selected, true, true)
		end
		return self.selected
	end,

	onHighlightedChanged = function(self, onHighlightedChanged)
		if onHighlightedChanged == false or type(onHighlightedChanged) == "function" then
			return onHighlightedChanged
		end
		return self.onHighlightedChanged
	end,
	onSelectedChanged = function(self, onSelectedChanged)
		if onSelectedChanged == false or type(onSelectedChanged) == "function" then
			return onSelectedChanged
		end
		return self.onSelectedChanged
	end,

	oddBackgroundColour = function(self, oddBackgroundColour)
		if TypeChecker.colour(oddBackgroundColour) then
			if oddBackgroundColour ~= self.oddBackgroundColour then
				self.raw.oddBackgroundColour = oddBackgroundColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.oddBackgroundColour
	end,
	oddTextColour = function(self, oddTextColour)
		if TypeChecker.colour(oddTextColour) then
			if oddTextColour ~= self.oddTextColour then
				self.raw.oddTextColour = oddTextColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.oddTextColour
	end,

	evenBackgroundColour = function(self, evenBackgroundColour)
		if TypeChecker.colour(evenBackgroundColour) then
			if evenBackgroundColour ~= self.evenBackgroundColour then
				self.raw.evenBackgroundColour = evenBackgroundColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.evenBackgroundColour
	end,
	evenTextColour = function(self, evenTextColour)
		if TypeChecker.colour(evenTextColour) then
			if evenTextColour ~= self.evenTextColour then
				self.raw.evenTextColour = evenTextColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.evenTextColour
	end,

	highlightedBackgroundColour = function(self, highlightedBackgroundColour)
		if TypeChecker.colour(highlightedBackgroundColour) then
			if highlightedBackgroundColour ~= self.highlightedBackgroundColour then
				self.raw.highlightedBackgroundColour = highlightedBackgroundColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.highlightedBackgroundColour
	end,
	highlightedTextColour = function(self, highlightedTextColour)
		if TypeChecker.colour(highlightedTextColour) then
			if highlightedTextColour ~= self.highlightedTextColour then
				self.raw.highlightedTextColour = highlightedTextColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.highlightedTextColour
	end,

	selectedBackgroundColour = function(self, selectedBackgroundColour)
		if TypeChecker.colour(selectedBackgroundColour) then
			if selectedBackgroundColour ~= self.selectedBackgroundColour then
				self.raw.selectedBackgroundColour = selectedBackgroundColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.selectedBackgroundColour
	end,
	selectedTextColour = function(self, selectedTextColour)
		if TypeChecker.colour(selectedTextColour) then
			if selectedTextColour ~= self.selectedTextColour then
				self.raw.selectedTextColour = selectedTextColour
				refreshItemLabels(self, self.scrollPosition, false, false)
			end
		end
		return self.selectedTextColour
	end,
}

methods = {
	SetHighlighted = function(self, highlighted, updateScrollPosition, sendOnHighlightedChanged)
		if TypeChecker.positive_integer(highlighted) and highlighted <= #self.raw.items or highlighted == false then
			setHighlighted(self, highlighted, updateScrollPosition, sendOnHighlightedChanged)
			return true
		end
		return false
	end,
	SetSelected = function(self, selected, updateScrollPosition, sendOnSelectedChanged)
		if TypeChecker.positive_integer(selected) and selected <= #self.raw.items or selected == false then
			setSelected(self, selected, updateScrollPosition, sendOnSelectedChanged)
			return true
		end
		return false
	end,

	AddItem = function(self, index, item)
		--if checkIndex(index) and checkItem(item) then
			-- check index
			index = math.min(index, #self.raw.items + 1)
			Logger:Info("AddItem = "..index)
			-- add item to self.items
			table.insert(self.raw.items, index, item)
			-- check highlighted
			if self.highlighted == index then
				self.raw.highlighted = index + 1
			end
			-- check selected
			if self.selected == index then
				self.raw.selected = index + 1
			end
			-- check slider
			local checkWidth = false
			if #self.raw.items == self.height + 1 then
				self.slider.drawn = true
				checkWidth = self.width - 1
			end
			-- refreshItemLabels
			refreshItemLabels(self, self.scrollPosition, checkWidth, true)
		--end
	end,
	SetItem = function(self, index, item, sendOnHighlightedChanged, sendOnSelectedChanged)
		--if self.items[index] and checkItem(item) then
			-- update item
			self.raw.items[index] = item
			-- check highlighted
			if self.highlighted == index and sendOnHighlightedChanged then
				self.highlighted = false
			end
			-- check selected
			if self.selected == index and sendOnSelectedChanged then
				self.selected = false
			end
			-- refreshItemLabels
			refreshItemLabels(self, self.scrollPosition, false, false)
		--end
	end,
	GetItem = function(self, index)
		return self.raw.items[index] or false
	end,
	RemoveItem = function(self, index)
		if self.raw.items[index] then
			-- remove from self.items
			table.remove(self.raw.items, index)
			-- check highlighted
			if self.highlighted == index then
				self.raw.highlighted = false
			end
			-- check selected
			if self.selected == index then
				self.raw.selected = false
			end
			-- check slider
			local scrollPosition, checkWidth = self.scrollPosition, false
			if #self.raw.items == self.height then
				self.slider.drawn = false
				checkWidth = self.width
				scrollPosition = 0
			end
			-- refreshItemLabels
			refreshItemLabels(self, scrollPosition, checkWidth, false)
		end
	end,

	Scroll = function(self, scrollDir)
		if TypeChecker.integer(scrollDir) then
			local scrollPosition = checkScrollPosition(self, self.scrollPosition + scrollDir)
			if scrollPosition ~= self.scrollPosition then
				local previousScrollPosition = self.scrollPosition
				refreshItemLabels(self, scrollPosition, false, true)
				return self.scrollPosition - previousScrollPosition
			end
		end
		return 0
	end,
	CanScroll = function(self, scrollDir)
		if TypeChecker.integer(scrollDir) then
			return self.scrollPosition + scrollDir == checkScrollPosition(self, self.scrollPosition + scrollDir)
		end
		return false
	end,
}

constructor = function(self, node, x, y, order, width, height, items)
	self.super(node, x, y, order)

	self.itemsNode = self:AddNode(0, 0, 1)

	self.slider = Slider.vertical(self, width - 1, 0, 2, height)
	self.slider.userdata = self
	local function listSliderOnChanged(percent)
		if self.slider.drawn and self.height < #self.raw.items then
			local intervalLength = 1/(#self.raw.items - self.height)
			local scrollPosition = math.max(math.floor((percent/intervalLength) + 0.5), 0)
			if scrollPosition ~= self.scrollPosition then
				refreshItemLabels(self, TypeChecker.non_negative_integer(scrollPosition) and scrollPosition or 0, false, false)
			end
		end
	end
	self.slider.onChanged = listSliderOnChanged

	self:SetCallback("key", "list", listNodeOnKey)

	self.items = items

	self.size = {width, height}
end

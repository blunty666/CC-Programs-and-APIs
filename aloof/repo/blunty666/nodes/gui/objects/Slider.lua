package = "blunty666.nodes.gui.objects"

imports = {
	"blunty666.nodes.Node",
	"aloof.TypeChecker",
}

class = "Slider"
extends = "Node"

local function posToPercent(sliderLength, currPos)
	return (currPos - 1) / (sliderLength - 1)
end
local function percentToPos(sliderLength, percent)
	return math.floor(percent*(sliderLength - 1) + 1 + 0.5)
end

local function runnerClick(runner, mouseClickEvent)
	local slider = runner.userdata
	if slider.orientation == "VERTICAL" then
		slider.currPos = mouseClickEvent.y
	elseif slider.orientation == "HORIZONTAL" then
		slider.currPos = mouseClickEvent.x
	end
	slider.handlePosition = slider.currPos
end

local function runnerDrag(runner, mouseDragEvent)
	local slider = runner.userdata
	if slider.orientation == "VERTICAL" then
		slider.currPos = slider.currPos + mouseDragEvent.delta_y
	elseif slider.orientation == "HORIZONTAL" then
		slider.currPos = slider.currPos + mouseDragEvent.delta_x
	end
	local handlePos = math.max(1, math.min(slider.length, slider.currPos))
	slider.handlePosition = handlePos
end

local function runnerScroll(runner, mouseScrollEvent)
	local slider = runner.userdata
	slider.handlePosition = slider.handlePosition + mouseScrollEvent.scroll_dir
end

local function updatePosition(slider, handlePosition, sendOnChange)
	if slider.orientation == "VERTICAL" then
		slider.handle.y = handlePosition - 1
	elseif slider.orientation == "HORIZONTAL" then
		slider.handle.x = handlePosition - 1
	end
	slider.raw.handlePosition = handlePosition
	if sendOnChange ~= false and slider.onChanged then
		slider.onChanged(posToPercent(slider.length, handlePosition))
	end
end

local function setLength(slider, length, sendOnChange)
	if slider.orientation == "VERTICAL" then
		slider.runner.size = {1, length}
	elseif slider.orientation == "HORIZONTAL" then
		slider.runner.size = {length, 1}
	end
	slider.runner:_Update(slider.runnerChar, nil, nil)
	slider.raw.length = length
	updatePosition(slider, percentToPos(length, slider.percent), sendOnChange)
end

static = {
	methods = {
		vertical = function(node, xPos, yPos, order, length)
			return Slider(node, xPos, yPos, order, length, "VERTICAL")
		end,
		horizontal = function(node, xPos, yPos, order, length)
			return Slider(node, xPos, yPos, order, length, "HORIZONTAL")
		end
	},
}

variables = {
	currPos = 1,
	orientation = NIL,
	length = NIL,
	percent = 0,

	onChanged = false,

	runnerBackgroundColour = colours.white,
	runnerTextColour = colours.black,
	runnerChar = NIL,

	handlePosition = 1,
	handleBackgroundColour = colours.white,
	handleTextColour = colours.black,
	handleChar = "O",

	handle = NIL,
	runner = NIL,
}

setters = {
	length = function(self, length)
		if TypeChecker.positive_integer(length) then
			if self.length ~= length then
				setLength(self, length)
			end
			return length
		end
		return self.length
	end,

	percent = function(self, percent)
		if type(percent) == "number" and percent >= 0 and percent <= 1 then
			if self.percent ~= percent then
				local handlePosition = percentToPos(self.length, percent)
				updatePosition(self, handlePosition)
			end
			return percent
		end
		return self.percent
	end,

	handlePosition = function(self, handlePosition)
		if TypeChecker.positive_integer(handlePosition) and handlePosition <= self.length then
			if self.handlePosition ~= handlePosition then
				updatePosition(self, handlePosition)
				self.raw.percent = posToPercent(self.length, handlePosition)
			end
			return handlePosition
		end
		return self.handlePosition
	end,
	handleBackgroundColour = function(self, handleBackgroundColour)
		if TypeChecker.colour(handleBackgroundColour) then
			if self.handleBackgroundColour ~= handleBackgroundColour then
				self.handle:SetCoord(1, 1, nil, nil, handleBackgroundColour)
			end
			return handleBackgroundColour
		end
		return self.handleBackgroundColour
	end,
	handleTextColour = function(self, handleTextColour)
		if TypeChecker.colour(handleTextColour) then
			if self.handleTextColour ~= handleTextColour then
				self.handle:SetCoord(1, 1, nil, handleTextColour, nil)
			end
			return handleTextColour
		end
		return self.handleTextColour
	end,
	handleChar = function(self, handleChar)
		if type(handleChar) == "string" and handleChar:len() > 0 then
			handleChar = handleChar:sub(1, 1)
			if self.handleChar ~= handleChar then
				self.handle:SetCoord(1, 1, handleChar, nil, nil)
			end
			return handleChar
		end
		return self.handleChar
	end,

	onChanged = function(self, onChanged)
		if onChanged == false or type(onChanged) == "function" then
			return onChanged
		end
		return self.onChanged
	end,

	runnerBackgroundColour = function(self, runnerBackgroundColour)
		if TypeChecker.colour(runnerBackgroundColour) then
			if self.runnerBackgroundColour ~= runnerBackgroundColour then
				self.runner.backgroundColour = runnerBackgroundColour
				self.runner:_Update(nil, nil, runnerBackgroundColour)					
			end
			return runnerBackgroundColour
		end
		return self.runnerBackgroundColour
	end,
	runnerTextColour = function(self, runnerTextColour)
		if TypeChecker.colour(runnerTextColour) then
			if self.runnerTextColour ~= runnerTextColour then
				self.runner.textColour = runnerTextColour
				self.runner:_Update(nil, runnerTextColour, nil)					
			end
			return runnerTextColour
		end
		return self.runnerTextColour
	end,
	runnerChar = function(self, runnerChar)
		if type(runnerChar) == "string" and runnerChar:len() > 0 then
			runnerChar = runnerChar:sub(1, 1)
			if self.runnerChar ~= runnerChar then
				self.runner:_Update(runnerChar, nil, nil)		
			end
			return runnerChar
		end
		return self.runnerChar
	end,
}

methods = {
	SetLength = function(self, length, sendOnChange)
		if TypeChecker.positive_integer(length) then
			if self.length ~= length then
				setLength(self, length, sendOnChange)
			end
			return true
		end
		return false
	end,

	SetPercent = function(self, percent, sendOnChange)
		if type(percent) == "number" and percent >= 0 and percent <= 1 then
			if self.percent ~= percent then
				local handlePosition = percentToPos(self.length, percent)
				updatePosition(self, handlePosition, sendOnChange)
				self.raw.percent = percent
			end
			return true
		end
		return false
	end,
}

constructor = function(self, node, xPos, yPos, order, length, orientation)
	self.super(node, xPos, yPos, order)

	self.orientation = orientation

	local handle = self:AddDrawable(0, 0, 1)
	handle.clickable = false
	handle.size = {1, 1}
	handle:SetCoord(1, 1, self.handleChar, self.handleTextColour, self.handleBackgroundColour)
	self.handle = handle

	local runner = self:AddDrawable(0, 0, 2)
	runner:SetCallback("mouse_click", "slider", runnerClick)
	runner:SetCallback("mouse_drag", "slider", runnerDrag)
	runner:SetCallback("mouse_scroll", "slider", runnerScroll)
	runner.userdata = self
	self.runner = runner

	self.runnerChar = (orientation == "HORIZONTAL" and "-") or "|"
	self.length = length
end

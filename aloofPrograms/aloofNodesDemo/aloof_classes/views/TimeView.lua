package = "blunty666.nodes_demo.views"

imports = {
	"blunty666.nodes.gui.objects.Button",
	"blunty666.nodes.gui.objects.Label",
}

class = "TimeView"
extends = "BaseView"

local WIDTH, HEIGHT = 10, 4

local function drawableDrag(drawable, mouseDragEvent)
	local xPos, yPos = unpack(drawable.pos)
	drawable.pos = {xPos + mouseDragEvent.delta_x, yPos + mouseDragEvent.delta_y}
end

local function getTime()
	return textutils.formatTime(os.time(), false)
end

variables = {
	startX = NIL,
	startY = NIL,

	topLabel = NIL,
	closeButton = NIL,
	timeLabel = NIL,
}

methods = {
	Update = function(self)
		self.timeLabel.text = getTime()
	end,
	ResetPos = function(self)
		self.pos = {self.startX, self.startY}
	end,
}

constructor = function(self, node, x, y, order)
	self.startX = x - math.ceil(WIDTH/2)
	self.startY = y - math.ceil(HEIGHT/2)

	self.super(node, self.startX, self.startY, order, WIDTH, HEIGHT, colours.grey)

	-- make draggable
	local function backgroundDrag(_, mouseDragEvent)
		local xPos, yPos = unpack(self.pos)
		self.pos = {xPos + mouseDragEvent.delta_x, yPos + mouseDragEvent.delta_y}
	end
	self.background:SetCallback("mouse_drag", "time_view_drag", backgroundDrag)

	-- add top label
	self.topLabel = Label(self, 0, 0, 1, "Time", WIDTH - 1, 1, colours.white, colours.cyan)
	self.topLabel.horizontalAlignment = "LEFT"
	self.topLabel.clickable = false -- so we can still drag the background

	-- add closeButton
	self.closeButton = Button(self, WIDTH - 1, 0, 1, "X", colours.red, colours.white, 1, 1)
	self.closeButton.clickedMainColour = colours.orange
	self.closeButton.onRelease = function()
		self.drawn = false
	end

	-- add time label
	self.timeLabel = Label(self, 1, 2, 1, getTime(), WIDTH - 2, 1, colours.white, colours.grey)
	self.timeLabel.horizontalAlignment = "RIGHT"
	self.timeLabel.clickable = false -- so we can still drag the background
end

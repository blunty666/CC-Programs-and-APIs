package = "blunty666.nodes_demo.views"

imports = "blunty666.nodes.gui.objects.Button"

class = "NavView"
extends = "BaseView"

variables = {
	screenHandler = NIL,
	inputView = NIL,
	outputView = NIL,
	timeView = NIL,

	inputViewButton = NIL,
	outputViewButton = NIL,
	timeViewButton = NIL,
	exitButton = NIL,
}

constructor = function(self, node, width, screenHandler, inputView, outputView, timeView)
	self.super(node, 0, 0, 1, width, 1, colours.cyan)

	self.screenHandler = screenHandler
	self.inputView = inputView
	self.outputView = outputView
	self.timeView = timeView

	self.inputViewButton = Button(self, 0, 0, 1, "Input", colours.grey, colours.white)
	self.inputViewButton.clickedMainColour = colours.green
	self.inputViewButton.activeMainColour = colours.blue
	self.inputViewButton.activeTextColour = colours.white
	self.inputViewButton.activeText = "Input"
	self.inputViewButton.onRelease = function()
		self.inputView.order = 3
		self.inputViewButton.isActive = true
		self.outputViewButton.isActive = false
	end

	self.outputViewButton = Button(self, 5, 0, 1, "Output", colours.grey, colours.white)
	self.outputViewButton.clickedMainColour = colours.green
	self.outputViewButton.activeMainColour = colours.blue
	self.outputViewButton.activeTextColour = colours.white
	self.outputViewButton.activeText = "Output"
	self.outputViewButton.onRelease = function()
		self.outputView.order = 3
		self.inputViewButton.isActive = false
		self.outputViewButton.isActive = true
	end

	self.timeViewButton = Button(self, width - 5, 0, 1, "Time", colours.blue, colours.white)
	self.timeViewButton.clickedMainColour = colours.magenta
	self.timeViewButton.onRelease = function(button)
		if button == 2 then
			self.timeView:ResetPos()
			self.timeView.drawn = true
		else
			self.timeView.drawn = not self.timeView.drawn
		end
	end

	self.exitButton = Button(self, width - 1, 0, 1, "X", colours.red, colours.white, 1, 1)
	self.exitButton.clickedMainColour = colours.orange
	self.exitButton.onRelease = function()
		self.screenHandler:Stop()
	end

	self.inputView.order = 3
	self.inputViewButton.isActive = true
end

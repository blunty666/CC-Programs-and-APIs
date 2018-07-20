package = "blunty666.nodes_demo"

imports = {
	"blunty666.nodes_demo.views.*",
	"blunty666.nodes.gui.ScreenHandler",
	"blunty666.log.*",
}

class = "Main"
extends = "ViewHandler"

static = {
	methods = {
		Sleep = function(self)
			os.startTimer(self.updateInterval)
			local timeIn = os.clock()
			repeat
				os.pullEvent()
			until os.clock() - timeIn >= self.updateInterval
		end,
	}
}

variables = {
	mainTerm = NIL,
	screenHandler = NIL,
	masterNode = NIL,

	itemList = NIL,

	updateInterval = 1,
}

methods = {
	Update = function(self)
		while true do
			self:Sleep()
			self:GetView("time_view"):Update()
		end
	end,
	HandleEvents = function(self)
		while true do
			self:HandleEvent({os.pullEvent()})
		end
	end,
	Main = function(self)
		parallel.waitForAny(
			function() self:Update() end,
			function() self:HandleEvents() end,
			function() self.screenHandler:Run() end
		)

		self.mainTerm.setCursorPos(1, 1)
		self.mainTerm.setBackgroundColour(colours.black)
		self.mainTerm.setTextColour(colours.white)
		self.mainTerm.clear()
	end,
}

constructor = function(self)

	-- setup file log output
	local fileLogOutput = FileLogOutput("log.txt", "overwrite")
	Logger:AddOutput(fileLogOutput)
	Logger.level = Level.INFO
	Logger:Severe("=============== BEGIN LOG ===============")

	self.mainTerm = term.current()
	self.screenHandler = ScreenHandler(self.mainTerm, colours.white)
	self.masterNode = self.screenHandler.masterNode

	-- create program itemList
	local items = {
		{"list"},
		{"of"},
		{"test"},
		{"items"},
	}
	self.itemList = ItemList(items)

	-- calculate view positions based on term size
	local width, height = self.mainTerm.getSize()

	self:AddView("output_view", OutputView(self.masterNode, 0, 1, 1, width, height - 1, self.itemList))
	self:AddView("input_view", InputView(self.masterNode, 0, 1, 1, width, height - 1, self.itemList))
	self:AddView("time_view", TimeView(self.masterNode, math.floor(width/2), math.floor((height - 1)/2), 1))
	self:AddView("nav_view", NavView(self.masterNode, width, self.screenHandler, self:GetView("input_view"), self:GetView("output_view"), self:GetView("time_view")))
end

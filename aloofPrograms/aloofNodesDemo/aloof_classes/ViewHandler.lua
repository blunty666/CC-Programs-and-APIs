package = "blunty666.nodes_demo"

imports = "blunty666.nodes_demo.views.IView"

class = "ViewHandler"

variables = {
	views = {},
}

methods = {
	HandleEvent = function(self, event)
		for _, view in pairs(self.views) do
			view:HandleEvent(event)
		end
	end,

	AddView = function(self, name, view)
		if self.views[name] then
			return error("view name already in use: "..tostring(name), 2)
		end
		if not view:Implements(IView) then
			return error("view must implement IView interface", 2)
		end
		self.views[name] = view
	end,
	GetView = function(self, name)
		return self.views[name] or false
	end,
	RemoveView = function(self, name)
		if self.views[name] then
			self.views[name] = false
			return true
		end
		return false
	end,
}

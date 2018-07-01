package = "blunty666.log"

class = "ConsoleLogOutput"
implements = "ILogOutput"

variables = {
	terminal = NIL,
}

methods = {
	Append = function(self, message)
		local previousTerminal = term.redirect(self.terminal)
		print(message)
		term.redirect(previousTerminal)
	end,
}

constructor = function(self, terminal)
	-- check terminal
	self.terminal = terminal
end

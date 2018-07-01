package = "blunty666.log"

class = "Logger"

local function formatMessage(timestamp, level, message)
	local formattedMessage = ""
	if timestamp then
		formattedMessage = formattedMessage.."\["..os.day().."-"..textutils.formatTime(os.time(), true).."\]"
	end
	formattedMessage = formattedMessage.."\["..level.."\]"
	formattedMessage = formattedMessage..": "..message
	return formattedMessage
end

static = {
	variables = {
		outputs = {},
		level = 2, -- default to Level.WARNING
		timestamp = false,
	},
	setters = {
		level = function(self, level)
			if Level.fromIndex(level) then
				return level
			end
			return self.level
		end,
		timestamp = function(self, timestamp)
			if type(timestamp) == "boolean" then
				return timestamp
			end
			return self.timestamp
		end,
	},
	methods = {
		AddOutput = function(self, logOutput)
			if logOutput:Implements(ILogOutput) then
				for _, _logOutput in ipairs(self.outputs) do
					if logOutput == _logOutput then
						return true
					end
				end
				table.insert(self.outputs, logOutput)
				return true
			end
			return error("logOutput must implement ILogOutput", 2)
		end,
		RemoveOutput = function(self, logOutput)
			if logOutput:Implements(ILogOutput) then
				for index, _logOutput in ipairs(self.outputs) do
					if logOutput == _logOutput then
						table.remove(self.outputs, index)
						return true
					end
				end
				return false
			end
			return error("logOutput must implement ILogOutput", 2)
		end,

		Log = function(self, level, message)
			local levelString = Level.fromIndex(level)
			if levelString then
				if level <= self.level then
					if type(message) == "string" then
						local formattedMessage = formatMessage(self.timestamp, levelString, message)
						for _, logOutput in ipairs(self.outputs) do
							logOutput:Append(formattedMessage)
						end
						return true
					end
					return error("invalid message - string expected, got: <"..type(message).."> "..tostring(level), 2)
				end
				return false
			end
			return error("invalid level: "..tostring(level), 2)
		end,

		Severe = function(self, message)
			return self:Log(Level.SEVERE, message)
		end,
		Warning = function(self, message)
			return self:Log(Level.WARNING, message)
		end,
		Info = function(self, message)
			return self:Log(Level.INFO, message)
		end,
		Config = function(self, message)
			return self:Log(Level.CONFIG, message)
		end,
		Fine = function(self, message)
			return self:Log(Level.FINE, message)
		end,
		Finer = function(self, message)
			return self:Log(Level.FINER, message)
		end,
		Finest = function(self, message)
			return self:Log(Level.FINEST, message)
		end,

		concat = function(...)
			local output = ""
			for _, input in ipairs({...}) do
				output = output..tostring(input)
			end
			return output
		end,
	},
}
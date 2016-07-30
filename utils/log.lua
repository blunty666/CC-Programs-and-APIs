local function appendToLog(log, level, text)
	local out = ""
	if log.time then
		out = out.."\["..os.day().."-"..textutils.formatTime(os.time(), true).."\]"
	end
	if log.name then
		out = out.."\["..log.name.."\]"
	end
	out = out.."\["..level.."\]"
	out = out..": "..text
	log.append(out)
end

local logMethods = {
	Debug = function(self, text)
		if type(text) == "string" and self.enabled and self.levels.DEBUG then
			appendToLog(self, "DEBUG", text)
			return true
		end
		return false
	end,
	Info = function(self, text)
		if type(text) == "string" and self.enabled and self.levels.INFO then
			appendToLog(self, "INFO", text)
			return true
		end
		return false
	end,
	Warn = function(self, text)
		if type(text) == "string" and self.enabled and self.levels.WARN then
			appendToLog(self, "WARN", text)
			return true
		end
		return false
	end,
	Error = function(self, text)
		if type(text) == "string" and self.enabled and self.levels.ERROR then
			appendToLog(self, "ERROR", text)
			return true
		end
		return false
	end,
	Fatal = function(self, text)
		if type(text) == "string" and self.enabled and self.levels.FATAL then
			appendToLog(self, "FATAL", text)
			return true
		end
		return false
	end,
	
	SetLevelEnabled = function(self, level, enabled)
		if self.levels[level] and type(enabled) == "boolean" then
			self.levels[level] = enabled
			return true
		end
		return false
	end,
	GetLevelEnabled = function(self, level)
		return self.levels[level]
	end,
	
	SetEnabled = function(self, enabled)
		if type(enabled) == "boolean" then
			self.enabled = enabled
			return true
		end
		return false
	end,
	GetEnabled = function(self)
		return self.enabled
	end,
	
	SetName = function(self, name)
		if type(name) == "boolean" or type(name) == "string" then
			self.name = name
			return true
		end
		return false
	end,
	GetName = function(self)
		return self.name
	end,
	
	SetTimeEnabled = function(self, enabled)
		if type(enabled) == "boolean" then
			self.time = enabled
			return true
		end
		return false
	end,
	GetTimeEnabled = function(self)
		return self.time
	end,
}
local logMetatable = {__index = logMethods}

function new(append)
	if type(append) ~= "function" then
		error("new: function expected, got "..type(append))
	end
	local log = {
		levels = {
			DEBUG = true,
			INFO = true,
			WARN = true,
			ERROR = true,
			FATAL = true,
		},
		enabled = true,
		append = append,
		time = false,
		name = false,
	}
	return setmetatable(log, logMetatable)
end

function newConsoleLogger(console)
	local function append(text)
		local prevTerm = term.redirect(console)
		print(text)
		term.redirect(prevTerm)
	end
	return new(append)
end

function newFileLogger(path)
	if type(path) ~= "string" then
		error("newFileLogger: string expected, got "..type(path))
	end
	if fs.exists(path) and fs.isDir(path) then
		error("newFileLogger: invalid file path - "..path)
	end
	local file = fs.open(path, "a")
	if not file then
		error("newFileLogger: could not open file")
	end
	local function append(text)
		file.writeLine(text)
		file.flush()
	end
	return new(append)
end

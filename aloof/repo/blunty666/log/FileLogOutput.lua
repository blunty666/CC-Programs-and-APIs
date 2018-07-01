package = "blunty666.log"

class = "FileLogOutput"
implements = "ILogOutput"

variables = {
	handle = NIL,
}

methods = {
	Append = function(self, message)
		self.handle.writeLine(message)
		self.handle.flush()
	end,
}

constructor = function(self, path, mode)
	-- check path
	if type(path) ~= "string" then
		return error("FileLogOutput: string expected, got "..type(path), 2)
	end
	if fs.exists(path) and fs.isDir(path) then
		error("FileLogOutput: invalid file path - "..path)
	end

	-- check mode
	local fileMode
	if mode == "append" then
		fileMode = "a"
	elseif mode == "overwrite" then
		fileMode = "w"
	else
		return error("FileLogOutput: invalid file read mode - "..tostring(mode), 2)
	end

	-- open file handle
	local handle = fs.open(path, fileMode)
	if not handle then
		error("FileLogOutput: could not open file")
	end
	self.handle = handle
end

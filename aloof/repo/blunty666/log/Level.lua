package = "blunty666.log"

class = "Level"

local LEVELS = {
	"SEVERE",
	"WARNING",
	"INFO",
	"CONFIG",
	"FINE",
	"FINER",
	"FINEST",
}

static = {
	variables = {},
	methods = {
		fromIndex = function(index)
			return LEVELS[index]
		end,
	}
}

for levelIndex, levelString in ipairs(LEVELS) do
	static.variables[levelString] = levelIndex
end

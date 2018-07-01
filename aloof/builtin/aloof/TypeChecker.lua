package = "aloof"

class = "TypeChecker"

static = {
	methods = {
		integer = function(value)
			return type(value) == "number" and (value % 1 == 0 or value == math.huge)
		end,
		positive_integer = function(value)
			return TypeChecker.integer(value) and value > 0
		end,
		non_negative_integer = function(value)
			return TypeChecker.integer(value) and value >= 0
		end,
		integer_double = function(value)
			return type(value) == "table" and TypeChecker.integer(value[1]) and TypeChecker.integer(value[2])
		end,
		non_negative_integer_double = function(value)
			return type(value) == "table" and TypeChecker.non_negative_integer(value[1]) and TypeChecker.non_negative_integer(value[2])
		end,
		colour = function(value)
			return TypeChecker.positive_integer(value) and value <= 32768 and (value == 1 or math.log(value, 2) / math.log(value) == 1)
		end,
	}
}

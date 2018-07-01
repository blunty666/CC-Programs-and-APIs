local check, _check = {}, {}

--===== UTILS =====--
local function typeError(expectedType, actualType, additionalInfo)
	local exception = "expected <"..expectedType..">, got: <"..actualType..">"
	if additionalInfo then
		exception = exception.." "..additionalInfo
	end
	return exception
end

local function throwTypeError(expectedType, actualType, additionalInfo)
	return error(typeError(expectedType, actualType, additionalInfo))
end

local function checkArray(array, expectedType)
	local output = {}
	for index, value in ipairs(array) do
		local ok, err = _check[expectedType](value)
		if ok then
			output[index] = value
		else
			return false, "invalid value at index "..tostring(index).." - "..err
		end
	end
	return output
end

local function checkTable(table, expectedKeyType, expectedValueType)
	local output = {}
	for key, value in pairs(table) do
		local ok, err = _check[expectedKeyType](key)
		if not ok then
			return false, "invalid key "..tostring(key).." - "..err
		end
		local ok, err = _check[expectedValueType](value)
		if not ok then
			return false, "invalid value at key "..tostring(key).." - "..err
		end
		output[key] = value
	end
	return output
end

local function splitFullName(full_name)
	return full_name:match("(.*)%.") or "", full_name:match("([^%.]*)$")
end

--===== INTERNAL CHECKING FUNCTIONS =====--
_check.any = function(value)
	return true
end

_check.string = function(value)
	if type(value) ~= "string" then return false, typeError("string", type(value), tostring(value)) end
	return true
end

_check["function"] = function(value)
	if type(value) ~= "function" then return false, typeError("function", type(value), tostring(value)) end
	return true
end

_check.sub_package_string = function(value)
	if value:len() == 0 then return false, "zero length sub_package_string not allowed" end
	if value:match("[^%l%d_]") then return false, "only lowercase alphanumeric characters + underscores allowed in sub_package_string" end
	return true
end

_check.package_string = function(value)
	if type(value) ~= "string" then return false, typeError("package_string", type(value), tostring(value)) end
	local length = value:len()
	if length == 0 then return value end
	local sub_package_string, seek = nil, 0
	while seek <= length do
		sub_package_string, seek = value:match("([^.]*).-()", seek + 1)
		local ok, err = _check.sub_package_string(sub_package_string)
		if not ok then
			return false, typeError("package_string", type(value), tostring(value).." - "..err)
		end
	end
	return value
end

_check.class_name = function(value)
	if type(value) ~= "string" then return false, typeError("class_name", type(value), tostring(value)) end
	if value:len() == 0 then return false, typeError("class_name", type(value), tostring(value).." - zero length class_name not allowed") end
	if value:find("[^%w_]") then return false, typeError("class_name", type(value), tostring(value).." - class_name must only contain alphanumeric characters + underscores") end
	if value:find("%u") ~= 1 then return false, typeError("class_name", type(value), tostring(value).." - class_name must start with capital letter") end
	if _check.interface_name(value) then return false, typeError("class_name", type(value), tostring(value).." - class_name cannot have the same format as interface_name") end
	return true
end

_check.full_class_name = function(value)
	if type(value) ~= "string" then return false, typeError("full_class_name", type(value), tostring(value)) end
	
	local package_string, class_name = splitFullName(value)

	local ok, err = _check.package_string(package_string)
	if not ok then
		return false, typeError("full_class_name", type(value), tostring(value).." - "..err)
	end

	local ok, err = _check.class_name(class_name)
	if not ok then
		return false, typeError("full_class_name", type(value), tostring(value).." - "..err)
	end

	return true
end

_check.interface_name = function(value)
	if type(value) ~= "string" then return false, typeError("interface_name", type(value), tostring(value)) end
	if value:len() < 1 then return false, typeError("interface_name", type(value), tostring(value).." - interface_name too short") end
	if value:find("[^%w_]") then return false, typeError("interface_name", type(value), tostring(value).." - interface_name must only contain alphanumeric characters + underscores") end
	if value:find("I") ~= 1 then return false, typeError("interface_name", type(value), tostring(value).." - interface_name must start with capital letter 'I'") end
	if value:find("%u", 2) ~= 2 then return false, typeError("interface_name", type(value), tostring(value).." - interface_name must start with capital letter 'I' then a capital letter") end
	return true
end

_check.full_interface_name = function(value)
	if type(value) ~= "string" then return false, typeError("full_interface_name", type(value), tostring(value)) end
	
	local package_string, interface_name = splitFullName(value)

	local ok, err = _check.package_string(package_string)
	if not ok then
		return false, typeError("full_interface_name", type(value), tostring(value).." - "..err)
	end

	local ok, err = _check.interface_name(interface_name)
	if not ok then
		return false, typeError("full_interface_name", type(value), tostring(value).." - "..err)
	end

	return true
end

_check.import_string = function(value)
	if type(value) ~= "string" then return false, typeError("import_string", type(value), tostring(value)) end
	
	local package_string, name = splitFullName(value)

	local ok, err = _check.package_string(package_string)
	if not ok then
		return false, typeError("import_package_string", type(value), tostring(value).." - "..err)
	end

	if not (_check.class_name(name) or _check.interface_name(name) or name == "*") then
		local err = "expected class_name / interface_name / wildcard at end of import_string"
		return false, typeError("import_name_string", type(value), tostring(value).." - "..err)
	end

	return true
end

--===== ERROR THROWING FUNCTIONS =====--
check.package_string_or_nil = function(value)
	if value == nil then
		return ""
	elseif type(value) == "string" then
		local ok, err = _check.package_string(value)
		if not ok then
			return throwTypeError("package_string_or_nil", type(value), "'"..tostring(value).."' - "..err)
		end
		return value
	end
	return throwTypeError("package_string_or_nil", type(value), tostring(value))
end

check.import_string_array_or_import_string_or_nil = function(value)
	if value == nil then
		return {}
	elseif type(value) == "string" then
		local ok, err = _check.import_string(value)
		if not ok then
			return throwTypeError("import_string_array_or_import_string_or_nil", type(value), tostring(value).." "..err)
		end
		return {value}
	elseif type(value) == "table" then
		local array, err = checkArray(value, "import_string")
		if err then
			return throwTypeError("import_string_array_or_import_string_or_nil", type(value), tostring(value).." "..err)
		end
		return array
	end
	return throwTypeError("import_string_array_or_import_string_or_nil", type(value), tostring(value))
end

check.class_name = function(value)
	local ok, err = _check.class_name(value)
	if not ok then
		return error(err)
	end
	return value
end

check.full_class_name_or_nil = function(value)
	if value == nil then
		return nil
	elseif type(value) == "string" then
		local ok, err = _check.full_class_name(value)
		if not ok then
			return throwTypeError("full_class_name_or_nil", type(value), " - "..err)
		end
		return value
	end
	return throwTypeError("full_class_name_or_nil", type(value), tostring(value))
end

check.full_interface_name_array_or_full_interface_name_or_nil = function(value)
	if value == nil then
		return {}
	elseif type(value) == "string" then
		local ok, err = _check.full_interface_name(value)
		if not ok then
			return throwTypeError("full_interface_name_array_or_full_interface_name_or_nil", type(value), " - "..err)
		end
		return {value}
	elseif type(value) == "table" then
		local array, err = checkArray(value, "full_interface_name")
		if err then
			return throwTypeError("full_interface_name_array_or_full_interface_name_or_nil", type(value), tostring(value).." "..err)
		end
		return array
	end
	return throwTypeError("full_interface_name_array_or_full_interface_name_or_nil", type(value), tostring(value))
end

check.string_indexed_table_or_nil = function(value)
	if value == nil then
		return {}
	elseif type(value) == "table" then
		local output, err = checkTable(value, "string", "any")
		if err then
			return throwTypeError("string_indexed_table_or_nil", type(value), tostring(value).." "..err)
		end
		return output
	end
	return throwTypeError("string_indexed_table_or_nil", type(value), tostring(value))
end

check.string_to_function_table_or_nil = function(value)
	if value == nil then
		return {}
	elseif type(value) == "table" then
		local output, err = checkTable(value, "string", "function")
		if err then
			return throwTypeError("string_to_function_table_or_nil", type(value), tostring(value).." "..err)
		end
		return output
	end
	return throwTypeError("string_to_function_table_or_nil", type(value), tostring(value))
end

check.function_or_nil = function(value)
	if value == nil then
		return nil
	elseif type(value) == "function" then
		return value
	end
	return throwTypeError("function_or_nil", type(value), tostring(value))
end

check.interface_name = function(value)
	local ok, err = _check.interface_name(value)
	if not ok then
		return error(err)
	end
	return value
end

check.full_interface_name_or_nil = function(value)
	if value == nil then
		return nil
	elseif type(value) == "string" then
		local ok, err = _check.full_interface_name(value)
		if not ok then
			return throwTypeError("full_interface_name_or_nil", type(value), " - "..err)
		end
		return value
	end
	return throwTypeError("full_interface_name_or_nil", type(value), tostring(value))
end

check.string_array_or_nil = function(value)
	if value == nil then
		return {}
	elseif type(value) == "table" then
		local array, err = checkArray(value, "string")
		if err then
			return throwTypeError("string_array_or_nil", type(value), tostring(value).." "..err)
		end
		return array
	end
	return throwTypeError("string_array_or_nil", type(value), tostring(value))
end

check.static = function(object)
	if object.static ~= nil and type(object.static) ~= "table" then
		throwTypeError("static_table", type(object.static), tostring(object.static))
	end
	local objectStatic = object.static or {}
	local static = {
		variables = check.string_indexed_table_or_nil(objectStatic.variables),
		getters = check.string_to_function_table_or_nil(objectStatic.getters),
		setters = check.string_to_function_table_or_nil(objectStatic.setters),
		methods = check.string_to_function_table_or_nil(objectStatic.methods),
		pre_constructor = check.function_or_nil(objectStatic.pre_constructor),
		constructor = check.function_or_nil(objectStatic.constructor),
		post_constructor = check.function_or_nil(objectStatic.post_constructor),
	}
	return static
end

check.instance = function(object)
	local instance = {
		variables = check.string_indexed_table_or_nil(object.variables),
		getters = check.string_to_function_table_or_nil(object.getters),
		setters = check.string_to_function_table_or_nil(object.setters),
		methods = check.string_to_function_table_or_nil(object.methods),
		constructor = check.function_or_nil(object.constructor),
	}
	return instance
end

check.full_name = function(class)
	if class.package == "" then
		return class.name
	else
		return class.package.."."..class.name
	end
end

check.constructor = function(class, object)
	if not class.instance.constructor then
		local constructor
		if class.extends then
			constructor = function(self, ...)
				if not self.super then
					print("NO super = ", class.fullName)
				end
				self.super(...)
			end
		else
			constructor = function(self, ...)
			end
		end
		setfenv(constructor, object)
		class.instance.constructor = constructor
	end
end

local duplicatesToCheck = {
	static = { methods = { static = {"variables", "getters", "setters"} } },
	instance = {
		variables = { static = {"variables", "getters", "setters", "methods"} },
		getters = { static = {"variables", "getters", "setters", "methods"} },
		setters = { static = {"variables", "getters", "setters", "methods"} },
		methods = {
			static = {"variables", "getters", "setters", "methods"},
			instance = {"variables", "getters", "setters"},
		},
	},
}
check.class_duplicates = function(class)
	local checkingData, otherData
	for checkingClassType, checkingDataTypes in pairs(duplicatesToCheck) do
		for checkingDataType, otherClassTypes in pairs(checkingDataTypes) do
			checkingData = class[checkingClassType][checkingDataType]
			for otherClassType, otherDataTypes in pairs(otherClassTypes) do
				for _, otherDataType in ipairs(otherDataTypes) do
					otherData = class[otherClassType][otherDataType]
					for key, _ in pairs(otherData) do
						if checkingData[key] then
							error("class "..checkingClassType.." "..checkingDataType.." already defined in "..otherClassType.." "..otherDataType..": "..key)
						end
					end
				end
			end
		end
	end
end

check.class = function(object, package_string, imports)
	local class = {
		package = package_string,
		imports = imports,

		name = check.class_name(object.class),
		extends = check.full_class_name_or_nil(object.extends),
		implements = check.full_interface_name_array_or_full_interface_name_or_nil(object.implements),

		static = check.static(object),

		instance = check.instance(object),

		extendedBy = {},
	}
	class.fullName = check.full_name(class)
	check.constructor(class, object)
	check.class_duplicates(class)
	return class, "class"
end

check.interface_duplicates = function(interface)
	for _, method_key in ipairs(interface.methods) do
		for _, static_method_key in ipairs(interface.static_methods) do
			if method_key == static_method_key then
				error("interface method already defined in static_methods: "..method_key)
			end
		end
	end
end

check.interface = function(object, package_string, imports)
	local interface = {
		package = package_string,
		imports = imports,

		name = check.interface_name(object.interface),
		extends = check.full_interface_name_or_nil(object.extends),
		static_methods = check.string_array_or_nil(object.static_methods),
		methods = check.string_array_or_nil(object.methods),

		extendedBy = {},
	}
	interface.fullName = check.full_name(interface)
	check.interface_duplicates(interface)
	return interface, "interface"
end

check.object = function(object)

	local package = check.package_string_or_nil(object.package)
	local imports = check.import_string_array_or_import_string_or_nil(object.imports)

	if object.class ~= nil and object.interface ~= nil then
		return error("cannot have class declaration and interface declaration in same file")
	elseif object.class ~= nil then
		return check.class(object, package, imports)
	elseif object.interface ~= nil then
		return check.interface(object, package, imports)
	else
		return error("no class or interface declaration in file")
	end
end

return check

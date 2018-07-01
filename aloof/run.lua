local tArgs = {...}
local paths = tArgs[1]
local mainClass = tArgs[2]

local aloofPath = fs.getDir(shell.getRunningProgram())
local aloofInstance = {}
local classes, interfaces = {}, {}
local metatables = {}
local loadingClasses, loadingInterfaces = {}, {}
local globalLock = false
local mainEnv = _ENV
local mainClassEnvironment = {}
local global = {}
local NIL = {}
local loadedFiles = {}

local interfaceFrom = setmetatable({}, {__mode = "k"})

local classFrom = setmetatable({}, {__mode = "k"})
local staticFrom = setmetatable({}, {__mode = "k"})
local instanceFrom = setmetatable({}, {__mode = "k"})
local mainInstanceFrom = setmetatable({}, {__mode = "k"})

local staticRawProxyFrom = setmetatable({}, {__mode = "k"})

local instanceMainProxyFrom = setmetatable({}, {__mode = "k"})
local instanceProxyFrom = setmetatable({}, {__mode = "k"})
local instanceRawProxyFrom = setmetatable({}, {__mode = "k"})
local instanceSuperProxyFrom = setmetatable({}, {__mode = "k"})

local environmentFrom = setmetatable({}, {__mode = "k"})
local classNameFrom = {}

local check = dofile(fs.combine(aloofPath, "check.lua"))

local typeFrom = setmetatable({}, {__mode = "k"})
local nameFrom = setmetatable({}, {__mode = "k"})

--===== UTILS =====--
local function printTable(t)
	for key, value in pairs(t) do
		print(key, " = ", value)
	end
end

local function splitFullName(full_name)
	return full_name:match("(.*)%.") or "", full_name:match("([^%.]*)$")
end

local function deepcopy(orig)
    if type(orig) == "table" then
		if orig == NIL then return orig end
        local copy = {}
        for orig_key, orig_value in next, orig, nil do
            copy[deepcopy(orig_key)] = deepcopy(orig_value)
        end
        setmetatable(copy, deepcopy(getmetatable(orig)))
		return copy
	end
    return orig -- string, number, boolean, function
end

global = {
	static = {
		variables = {
			raw = NIL,
			super = NIL,
			className = NIL,
		},
		getters = {
			raw = function(proxy)
				return staticRawProxyFrom[proxy]
			end,
			super = function()
				return error("cannot get super for static")
			end,
			className = function(proxy)
				local class = classFrom[proxy]
				return class.name
			end,
		},
		setters = {},
		methods = {
			Extends = function(proxy, className)
			end,
			ExtendedBy = function(proxy)
				local class = classFrom[proxy]
				local extendedBy = {}
				for _, className in ipairs(classFrom[proxy].extendedBy) do
					table.insert(extendedBy, className)
				end
				return extendedBy
			end,
			Implements = function(proxy, interfaceStaticProxy)
				if type(interfaceStaticProxy) == "string" then
					error("HERE", 2)
				end
				local interface = interfaceFrom[interfaceStaticProxy]
				for _, interfaceName in ipairs(classFrom[proxy].implements) do
					if interfaceName == interface.fullName then
						return true
					end
				end
				return false
			end,
		},
	},
	instance = {
		variables = {
			raw = NIL,
			super = NIL,
		},
		getters = {
			raw = function(proxy)
				return instanceRawProxyFrom[proxy]
			end,
			super = function(proxy)
				local className = classNameFrom[getfenv(3)]
				if not className then
					return error("unable to access className from here")
				end
				local superProxy = mainInstanceFrom[proxy].supers[className]
				if not superProxy then
					if superProxy == false then
						return error("attempt to access super for non-extended class - "..className, 2)
					else
						local instanceMainProxy = instanceMainProxyFrom[proxy]
						local class = classFrom[instanceMainProxy]
						return error("attempt to access super from invalid location for class instance - "..class.fullName, 2)
					end
				end
				return superProxy
			end,
		},
		setters = {},
		methods = {
			InstanceOf = function(proxy, classStaticProxy) -- check - pass in class static proxy and get className from that
				if type(classStaticProxy) == "string" then
					error("HERE", 2)
				end
				local class = classFrom[classStaticProxy]
				local className = classFrom[proxy].fullName
				while className do
					if className == class.fullName then
						return true
					end
					className = classes[className].extends
				end
				return false
			end,
		},
	},
}
-- create getters and setters for global variables
for subObjectType, subObject in pairs(global) do
	for variableName, _ in pairs(subObject.variables) do
		if not subObject.getters[variableName] then
			subObject.getters[variableName] = function(proxy, value)
				return value
			end
		end
		if not subObject.setters[variableName] then
			subObject.setters[variableName] = function()
				return error("attempt to overwrite global "..subObjectType.." variable: "..variableName)
			end
		end
	end
end

local function preInit(class, instanceRawProxy, instanceSuperProxy, variables, mainClass, mainInstance, instanceMainProxy)

	typeFrom[instanceRawProxy] = "instanceRawProxy"
	typeFrom[instanceSuperProxy] = "instanceSuperProxy"

	nameFrom[instanceRawProxy] = class.fullName
	nameFrom[instanceSuperProxy] = class.fullName

	setmetatable(instanceRawProxy, metatables.instanceRaw)
	setmetatable(instanceSuperProxy, metatables.instanceSuper)

	local instance = {
		variables = variables,
		getters = class.instance.getters,
		setters = class.instance.setters,
		methods = class.instance.methods,
		initRequired = true,
	}

	if not mainClass then
		mainClass = class
		mainInstance = instance
		instanceMainProxy = instanceSuperProxy
		mainInstance.supers = {}
	end

	classFrom[instanceRawProxy], classFrom[instanceSuperProxy] = class, class
	staticFrom[instanceRawProxy], staticFrom[instanceSuperProxy] = class.static, class.static
	instanceFrom[instanceRawProxy], instanceFrom[instanceSuperProxy] = instance, instance
	mainInstanceFrom[instanceRawProxy], mainInstanceFrom[instanceSuperProxy] = mainInstance, mainInstance

	instanceMainProxyFrom[instanceRawProxy], instanceMainProxyFrom[instanceSuperProxy] = instanceMainProxy, instanceMainProxy
	instanceRawProxyFrom[instanceSuperProxy] = instanceRawProxy

	if class.extends then
		local superRawProxy, superSuperProxy = {}, {}
		mainInstance.supers[class.fullName] = superSuperProxy
		instance.superProxy = superSuperProxy
		return preInit(classes[class.extends], superRawProxy, superSuperProxy, variables, mainClass, mainInstance, instanceMainProxy)
	else
		mainInstance.supers[class.fullName] = false
	end
end

local function postInit(proxy, ...)
	if proxy then
		local instance = instanceFrom[proxy]
		if instance.initRequired then
			instance.initRequired = nil
			classFrom[proxy].instance.constructor(instanceMainProxyFrom[proxy], ...)
		end
		local superProxy = instance.superProxy
		if superProxy then
			instance.superProxy = nil
			return postInit(superProxy)
		end
	end
end

metatables = {
	static = {
		__index = function(proxy, key)
			local static = staticFrom[proxy]
			local value = static.variables[key]
			if value ~= nil then
				if value == NIL then
					value = nil
				end
				local getter = static.getters[key]
				if getter then
					value = getter(proxy, value)
				end
				return value
			else
				return static.methods[key] or error("static __index: attempt to get an undefined key - "..tostring(key), 2)
			end
		end,
		__newindex = function(proxy, key, value)
			local static = staticFrom[proxy]
			if static.variables[key] ~= nil then
				local setter = static.setters[key]
				if setter then
					value = setter(proxy, value)
				end
				static.variables[key] = (value == nil and NIL) or value
			elseif static.methods[key] then
				return error("static __newindex: attempt to overwrite static method - "..tostring(key), 2)
			else
				return error("static __newindex: attempt to set an undefined key - "..tostring(key), 2)
			end
		end,
		__call = function(proxy, ...)
			local class = classFrom[proxy]
			local instanceRawProxy, instanceSuperProxy = {}, {}
			local variables = deepcopy(class.instance.variables)
			
			-- create proxies for all super instances with initRequired flag set
			preInit(class, instanceRawProxy, instanceSuperProxy, variables)

			-- set metatable for instanceSuperProxy as this will become the instanceMainProxy
			setmetatable(instanceSuperProxy, metatables.instanceMain)

			-- call constructor method for all super instances with initRequired flag set
			postInit(instanceSuperProxy, ...)

			return instanceSuperProxy
		end,
	},
	rawStatic = {
		__index = function(rawProxy, key)
			local static = staticFrom[rawProxy]
			local value = static.variables[key]
			if value ~= nil then
				return (value == NIL and nil) or value
			else
				return static.methods[key] or error("rawStatic __index: attempt to get an undefined key - "..tostring(key), 2)
			end
		end,
		__newindex = function(rawProxy, key, value)
			local static = staticFrom[rawProxy]
			if static.variables[key] ~= nil then
				static.variables[key] = (value == nil and NIL) or value
			elseif static.methods[key] then
				return error("rawStatic __newindex: attempt to overwrite static method - "..tostring(key), 2)
			else
				return error("rawStatic __newindex: attempt to set an undefined key - "..tostring(key), 2)
			end
		end,
		__call = function(rawProxy, ...)
			return error("rawStatic __call: attempt to call rawProxy", 2)
		end,
	},

	instanceMain = {
		__index = function(proxy, key)
			local instance = instanceFrom[proxy]
			local value = instance.variables[key]
			if value ~= nil then
				if value == NIL then
					value = nil
				end
				local getter = instance.getters[key]
				if getter then
					value = getter(proxy, value)
				end
				return value
			end
			local method = instance.methods[key]
			if method then
				return method
			end

			local static = staticFrom[proxy]
			value = static.variables[key]
			if value ~= nil then
				if value == NIL then
					value = nil
				end
				local getter = static.getters[key]
				if getter then
					value = getter(static.proxy, value)
				end
				return value
			else
				return static.methods[key] or error("instance __index: attempt to get an undefined key - "..tostring(key), 2)
			end
		end,
		__newindex = function(proxy, key, value)
			local instance = instanceFrom[proxy]
			if instance.variables[key] ~= nil then
				local setter = instance.setters[key]
				if setter then
					value = setter(proxy, value)
				end
				instance.variables[key] = (value == nil and NIL) or value
				return
			elseif instance.methods[key] then
				return error("instance __newindex: attempt to overwrite instance method - "..tostring(key), 2)
			end

			local static = staticFrom[proxy]
			if static.variables[key] ~= nil then
				local setter = static.setters[key]
				if setter then
					value = setter(static.proxy, value)
				end
				static.variables[key] = (value == nil and NIL) or value
			elseif static.methods[key] then
				return error("instance __newindex: attempt to overwrite static method - "..tostring(key), 2)
			else
				return error("instance __newindex: attempt to set an undefined key - "..tostring(key), 1)
			end
		end,
		__call = function(proxy, ...)
			return error("instance __call:  cannot call constructor for instance", 2)
		end,
	},
	instanceSuper = {
		__index = function(proxy, key)
			local instance = instanceFrom[proxy]
			local value = instance.variables[key]
			if value ~= nil then
				if value == NIL then
					value = nil
				end
				local getter = instance.getters[key]
				if getter then
					value = getter(instanceMainProxyFrom[proxy], value)
				end
				return value
			end
			local method = instance.methods[key]
			if method then
				return method
			end

			local static = staticFrom[proxy]
			value = static.variables[key]
			if value ~= nil then
				if value == NIL then
					value = nil
				end
				local getter = static.getters[key]
				if getter then
					value = getter(static.proxy, value)
				end
				return value
			else
				return static.methods[key] or error("instance __index: attempt to get an undefined key - "..tostring(key), 2)
			end
		end,
		__newindex = function(proxy, key, value)
			local instance = instanceFrom[proxy]
			if instance.variables[key] ~= nil then
				local setter = instance.setters[key]
				if setter then
					value = setter(instanceMainProxyFrom[proxy], value)
				end
				instance.variables[key] = (value == nil and NIL) or value
				return
			elseif instance.methods[key] then
				return error("instance __newindex: attempt to overwrite instance method - "..tostring(key), 2)
			end

			local static = staticFrom[proxy]
			if static.variables[key] ~= nil then
				local setter = static.setters[key]
				if setter then
					value = setter(static.proxy, value)
				end
				static.variables[key] = (value == nil and NIL) or value
			elseif static.methods[key] then
				return error("instance __newindex: attempt to overwrite static method - "..tostring(key), 2)
			else
				return error("instance __newindex: attempt to set an undefined key - "..tostring(key), 1)
			end
		end,
		__call = function(proxy, ...)
			local instance = instanceFrom[proxy]
			if instance.initRequired then
				instance.initRequired = nil
				classFrom[proxy].instance.constructor(instanceMainProxyFrom[proxy], ...)
				return
			end
			return error("instance __call: instance already initialised", 2)
		end,
	},
	instanceRaw = {
		__index = function(proxy, key)
			local instance = instanceFrom[proxy]
			local value = instance.variables[key]
			if value ~= nil then
				return (value == NIL and nil) or value
			end
			local method = instance.methods[key]
			if method then
				return error("rawInstance __index: attempt to access instance method from raw instance - ", tostring(key), 2)
			end

			local static = staticFrom[proxy]
			value = static.variables[key]
			if value ~= nil then
				return (value == NIL and nil) or value
			elseif static.methods[key] then
				return error("rawInstance __index: attempt to access static method from raw instance - ", tostring(key), 2)
			else
				return error("rawInstance __index: attempt to get an undefined key - "..tostring(key), 2)
			end
		end,
		__newindex = function(proxy, key, value)
			local instance = instanceFrom[proxy]
			if instance.variables[key] ~= nil then
				instance.variables[key] = (value == nil and NIL) or value
				return
			elseif instance.methods[key] then
				return error("rawInstance __newindex: attempt to overwrite instance method - "..tostring(key), 2)
			end

			local static = staticFrom[proxy]
			if static.variables[key] ~= nil then
				static.variables[key] = (value == nil and NIL) or value
			elseif static.methods[key] then
				return error("rawInstance __newindex: attempt to overwrite static method - "..tostring(key), 2)
			else
				return error("rawInstance __newindex: attempt to set an undefined key - "..tostring(key), 2)
			end
		end,
		__call = function(proxy, ...)
			return error("rawInstance __call:  rawInstance cannot be initialised", 2)
		end,
	},

	classEnvironment = {
		__index = function(proxy, key)
			return environmentFrom[proxy][key] or mainClassEnvironment[key] or mainEnv[key]
		end,
	},

	environment = {
		__index = function(proxy, key)
			if not environmentFrom[proxy] then
				error("HERE", 2)
			end
			return environmentFrom[proxy][key]
		end,
		__newindex = function(proxy, key, value)
			return error("attempt to overwrite aloof object environment", 2)
		end,
	},
}

local function getFileExtension(path)
  return path:match("^.+(%..+)$")
end

local extensionBlacklist = {
	[".txt"] = true,
}
local function findFiles(path, files)
	local files = files or {}
	if fs.exists(path) then
		if fs.isDir(path) then
			for _, file in ipairs(fs.list(path)) do
				findFiles(fs.combine(path, file), files)
			end
		else
			if not extensionBlacklist[getFileExtension(path)] then
				table.insert(files, path)
			end
		end
	end
	return files
end

local function checkLoadedObject(object)
	local result = {pcall(check.object, object)}
	if not result[1] then
		return false, result[2]:match("^[^:]*:[%d]*:(.*)")
	end
	return unpack(result, 2)
end

local function preprocess(data)
	return data:gsub("super:([%w_]+)%(%s*%)", "super.%1(self)"):gsub("super:([%w_]+)%(%s*", "super.%1(self, ")
end

local function loadAndPreprocessFile( _sFile, _tEnv )
    if type( _sFile ) ~= "string" then
        error( "bad argument #1 (expected string, got " .. type( _sFile ) .. ")", 2 ) 
    end
    if _tEnv ~= nil and type( _tEnv ) ~= "table" then
        error( "bad argument #2 (expected table, got " .. type( _tEnv ) .. ")", 2 ) 
    end
    local file = fs.open( _sFile, "r" )
    if file then
		local data = preprocess(file.readAll())
        local func, err = load( data, fs.getName( _sFile ), "t", _tEnv )
        file.close()
        return func, err
    end
    return nil, "File not found"
end

local function loadFile(path)

	-- check if path has already been loaded
	if loadedFiles[path] then
		return
	end
	loadedFiles[path] = true

	local environment = {}
	
	local environmentProxy = {
		NIL = NIL,
	}
	environmentFrom[environmentProxy] = environment
	setmetatable(environmentProxy, metatables.classEnvironment)

	local file, err = loadAndPreprocessFile(path, environmentProxy)
	if file then
		local ok, err = pcall(file)
		if not ok then
			-- error running file xxx
			printError("error running file '"..path.."' - "..err)
			return false
		end
	else
		-- error loading file xxx
		printError("error loading file '"..path.."' - "..err)
		return false
	end

	local object, objectType = checkLoadedObject(environmentProxy)
	if object then
		object.environment = environment
		object.environmentProxy = environmentProxy
		if objectType == "class" then
			--setfenv(object.instance.constructor, object.environmentProxy)
			if classes[object.fullName] then
				return printError("error checking file '"..path.."' - ".."class already exists = ", object.fullName)
			elseif loadingClasses[object.fullName] then
				return printError("error checking file '"..path.."' - ".."class already loading = ", object.fullName)
			else
				object.path = path
				loadingClasses[object.fullName] = object
			end
		elseif objectType == "interface" then
			if interfaces[object.fullName] then
				return printError("error checking file '"..path.."' - ".."interface already exists = ", object.fullName)
			elseif loadingInterfaces[object.fullName] then
				return printError("error checking file '"..path.."' - ".."interface already loading = ", object.fullName)
			else
				object.path = path
				loadingInterfaces[object.fullName] = object
			end
		end
	else
		return printError("error checking file '"..path.."' - "..objectType)
	end

	-- check package + imports and load files
end

local function checkInterfaceForGlobals(interface)
	for _, method in ipairs(interface.methods) do
		for subObjectType, subObject in pairs(global) do -- static / instance
			for _, variableType in ipairs({"variables", "methods"}) do
				for variableName, _ in pairs(subObject[variableType]) do
					if variableName == method then
						interface.error = "attempt to overwrite global "..subObjectType.." "..variableType.." with interface method: "..variableName
						return
					end
				end
			end
		end
	end
end

local function checkClassForGlobals(class)
	for _, classSubObjectType in ipairs({"static", "instance"}) do
		for _, classDataType in ipairs({"variables", "getters", "setters", "methods"}) do
			for classKey, _ in pairs(class[classSubObjectType][classDataType]) do

				for globalSubObjectType, globalSubObject in pairs(global) do
					for _, globalDataType in ipairs({"variables", "methods"}) do
						for globalKey, _ in pairs(globalSubObject[globalDataType]) do
							if globalKey == classKey then
								class.error = "attempt to overwrite global "..globalSubObjectType.." "..globalDataType.." with class "..classSubObjectType.." "..classDataType..": "..classKey
								return
							end
						end
					end
				end

			end
		end
	end
end

local objectFinders = {
	function(name, object, objects, loadingObjects) -- same package
		local objectFullName = object.package.."."..name
		return objects[objectFullName] or loadingObjects[objectFullName] or false
	end,
	function(name, object, objects, loadingObjects) -- imports
		for _, import in ipairs(object.imports) do
			local package, _name = splitFullName(import)
			if _name == "*" then -- check if name is in this package
				local objectFullName = package.."."..name
				local _object = objects[objectFullName] or loadingObjects[objectFullName]
				if _object then return _object end
			elseif _name == name then -- check if this import is the one
				local _object = objects[import] or loadingObjects[import]
				if _object then return _object end
			end
		end
		return false
	end,
	function(name, object, objects, loadingObjects) -- empty package
		return objects[name] or loadingObjects[name] or false
	end,
}

local function checkClassInterfacesExist(class) -- need to check package interfaces and imports interfaces
	for index, interfaceName in ipairs(class.implements) do
		local interface = false
		local package, name = splitFullName(interfaceName)
		if package:len() > 0 then
			-- is full name so just check
			interface = interfaces[interfaceName]
		else -- package == ""
			for _, finder in ipairs(objectFinders) do
				interface = finder(name, class, interfaces, loadingInterfaces)
				if interface then break end
			end
		end
		if not interface then
			-- non-existent
			if not class.error then
				class.error = "attempt to implement non-existent interface: "..interfaceName
				return
			end
		elseif loadingInterfaces[interface.fullName] and not interfaces[interface.fullName] then
			-- errored
			if not loadingInterfaces[interface.fullName].error then
				error("this should be in live interfaces??? - "..interface.fullName)
			end
			if not class.error then
				class.error = "attempt to implement errored interface: "..interface.fullName
				return
			end
		else
			-- update interface name
			class.implements[index] = interface.fullName
		end
	end
end

local function checkInheritanceExists(objectType, object, objects, loadingObjects) -- need to check package classes then imports classes
	if object.extends then
		local extendedObject = false
		local package, name = splitFullName(object.extends)
		if package:len() > 0 then
			-- is full name so just check
			extendedObject = objects[object.extends] or loadingObjects[object.extends] or false
		else -- package == ""
			for _, finder in ipairs(objectFinders) do
				extendedObject = finder(name, object, objects, loadingObjects)
				if extendedObject then break end
			end
		end
		if not extendedObject then
			if not object.error then
				object.error = "attempt to extend non-existent "..objectType.." - "..object.extends
			end
		else
			object.extends = extendedObject.fullName
			table.insert(extendedObject.extendedBy, object.fullName)
		end
	end
end

local function checkCircularInheritance(objectType, object, objects, loadingObjects)
	local object, seen = object, {}
	while true do
		local name = object.fullName
		if seen[name] then
			if not object.error then
				object.error = "circular inheritance found when trying to extend "..objectType.." - "..object.extends
			end
			return false
		end
		seen[name] = true
		local extendedName = object.extends
		if extendedName then
			if objects[extendedName] then -- we are extending an already loaded and validated object
				return true
			else
				object = loadingObjects[extendedName]
				if not object or object.error then -- we are attempting to extend an errored object
					return false
				end
			end
		else
			return true
		end
	end
end

local function propagateErrors(objectType, loadingObjects)
	local continue = true
	while continue do
		continue = false
		for objectName, object in pairs(loadingObjects) do
			if object.error then
				for _, extendingObjectName in ipairs(object.extendedBy) do
					local extendingObject = loadingObjects[extendingObjectName]
					if extendingObject and not extendingObject.error then
						extendingObject.error = "attempt to extend an errored "..objectType.." - "..objectName
						continue = true
					end
				end
			end
		end
	end
end

local function arrayContainsValue(array, value)
	for _, _value in ipairs(array) do
		if _value == value then
			return true
		end
	end
	return false
end

local function buildInterfaceMethodInheritance(pending)
	local newPending = {}
	for _, interfaceName in ipairs(pending) do
		local interface = loadingInterfaces[interfaceName]
		if not interface.error then
			local extendedInterface = interfaces[interface.extends] or loadingInterfaces[interface.extends] -- find extended interface
			-- add methods from extended interface
			for _, method in ipairs(extendedInterface.methods) do
				if not arrayContainsValue(interface.methods, method) then
					table.insert(interface.methods, method)
				end
			end
			-- add extending interfaces to new pending list
			for _, extendingInterfaceName in ipairs(interface.extendedBy) do
				table.insert(newPending, extendingInterfaceName)
			end
		end
	end
	return newPending
end

local function buildClassInheritanceFromExtendedClass(class, extendedClass)
	for _, extendedClassSubObjectType in ipairs({"static", "instance"}) do
		for _, extendedClassDataType in ipairs({"variables", "getters", "setters", "methods"}) do
			for extendedClassKey, extendedClassValue in pairs(extendedClass[extendedClassSubObjectType][extendedClassDataType]) do

				-- checks
				for _, classSubObjectType in ipairs({"static", "instance"}) do
					for _, classDataType in ipairs({"variables", "getters", "setters", "methods"}) do
						for classKey, _ in pairs(class[classSubObjectType][classDataType]) do

							if classKey == extendedClassKey and not global[extendedClassSubObjectType][extendedClassDataType][extendedClassKey] then
								if classSubObjectType == extendedClassSubObjectType then
									if (classDataType == "methods" and extendedClassDataType ~= "methods") or (classDataType ~= "methods" and extendedClassDataType == "methods") then
										class.error = "attempt to overwrite "..extendedClassSubObjectType.." "..extendedClassDataType.." in "..extendedClass.fullName.." with "..classSubObjectType.." "..classDataType..": "..classKey
										return false
									end
								else
									if classDataType ~= extendedClassDataType then
										class.error = "attempt to overwrite "..extendedClassSubObjectType.." "..extendedClassDataType.." in "..extendedClass.fullName.." with "..classSubObjectType.." "..classDataType..": "..classKey
										return false
									end
								end
							end

						end
					end
				end

				-- adding inherited values
				if not class[extendedClassSubObjectType][extendedClassDataType][extendedClassKey] then
					class[extendedClassSubObjectType][extendedClassDataType][extendedClassKey] = deepcopy(extendedClassValue)
				end

			end
		end
	end
end

local function checkClassInterfaceImplementation(class) -- include static_methods
	for _, interfaceName in ipairs(class.implements) do
		for _, method in ipairs(interfaces[interfaceName].methods) do
			if not (class.static.methods[method] or class.instance.methods[method]) then
				class.error = "method "..method.." not defined for interface "..interfaceName
				return false
			end
		end
	end
end

local function buildClassInheritance(pending)
	local newPending = {}
	for _, className in ipairs(pending) do
		local class = loadingClasses[className]
		if not class.error then
			if class.extends then
				local extendedClass = classes[class.extends] or loadingClasses[class.extends] -- find extended class
				if not extendedClass then
					error("here = "..class.extends)
				end
				buildClassInheritanceFromExtendedClass(class, extendedClass)

				-- add interfaces
				if not class.error then
					for _, interfaceName in ipairs(extendedClass.implements) do
						if not arrayContainsValue(class.implements, interfaceName) then
							table.insert(class.implements, interfaceName)
						end
					end
				end
			else
				-- add in globals
				for subObjectType, subObject in pairs(global) do -- static / instance
					for dataType, data in pairs(subObject) do -- variables/getters/setters/methods
						for key, value in pairs(data) do
							class[subObjectType][dataType][key] = value
						end
					end
				end
			end

			-- check interface implementation
			if not class.error then
				checkClassInterfaceImplementation(class)

				-- add extending classes to new pending list
				if not class.error then
					for _, extendingClassName in ipairs(class.extendedBy) do
						table.insert(newPending, extendingClassName)
					end
				end
			end
		end
	end
	return newPending
end

local function checkObjectReferences(objectType, object, objects, loadingObjects)
	if object.error then -- remove references to errored object in loaded objects
		if object.extends and objects[object.extends] then
			local extendedBy = objects[object.extends].extendedBy
			for index = 1, #extendedBy do
				if extendedBy[index] == object.fullName then
					table.remove(extendedBy, index)
					break
				end
			end
		end
		printError(objectType.." - "..object.fullName.." - ERROR = "..object.error)
	else
		local newExtendedBy = {}
		for _, extendingObjectName in ipairs(object.extendedBy) do
			if not (loadingObjects[extendingObjectName] and loadingObjects[extendingObjectName].error) then
				table.insert(newExtendedBy, extendingObjectName)
			end
		end
		object.extendedBy = newExtendedBy
	end
end

local function addToMainEnvironment(object)
	classNameFrom[object.environmentProxy] = object.fullName
	local fullName = object.fullName
	local length, subName, seek = fullName:len(), nil, 0
	local currentEnvironment = mainClassEnvironment
	while seek <= length do
		subName, seek = fullName:match("([^.]*).-()", seek + 1)
		if seek > length then
			-- add static proxy
			currentEnvironment[subName] = object.staticProxy
		else
			-- create sub name proxy
			if not currentEnvironment[subName] then
				local newEnvironment, newEnvironmentProxy = {}, setmetatable({}, metatables.environment)
				environmentFrom[newEnvironmentProxy] = newEnvironment
				currentEnvironment[subName] = newEnvironmentProxy
				currentEnvironment = newEnvironment
			else
				currentEnvironment = environmentFrom[ currentEnvironment[subName] ]
			end
		end
	end
end

local function addInterface(interface)
	interfaces[interface.fullName] = interface

	local staticProxy = setmetatable({}, metatables.interface)

	interfaceFrom[staticProxy] = interface

	interface.staticProxy = staticProxy

	addToMainEnvironment(interface)
end

local function addClass(class)
	classes[class.fullName] = class

	local staticProxy = setmetatable({}, metatables.static)
	local staticRawProxy = setmetatable({}, metatables.rawStatic)

	classFrom[staticProxy] = class
	classFrom[staticRawProxy] = class

	staticFrom[staticProxy] = class.static
	staticFrom[staticRawProxy] = class.static

	staticRawProxyFrom[staticProxy] = staticRawProxy

	-- add class static proxy
	class.staticProxy = staticProxy
	class.static.proxy = staticProxy

	addToMainEnvironment(class)
end

local function addFromPackage(environment, package)
	-- add classes in same package
	for _, class in pairs(classes) do
		if class.package == package and not environment[class.name] then
			environment[class.name] = class.staticProxy
		end
	end
	-- add interfaces in same package
	for _, interface in pairs(interfaces) do
		if interface.package == package and not environment[interface.name] then
			environment[interface.name] = interface.staticProxy
		end
	end
end

local function addImports(class)
	local environment = class.environment
	addFromPackage(environment, class.package)

	for _, import in ipairs(class.imports) do
		local package, name = splitFullName(import)
		if name == "*" then
			addFromPackage(environment, package)
		else
			local object = classes[import] or interfaces[import]
			if object and not environment[object.name] then
				environment[object.name] = object.staticProxy
			end
		end
	end
end

function loadFrom(path)
	-- check path
	local isDir = false
	if type(path) ~= "string" then
		return false, "path must be string"
	elseif not fs.exists(path) then
		return false, "file / directory not found at path: "..path
	end
	if fs.isDir(path) then
		isDir = true
	end

	-- check global lock
	local currentLock = {}
	if not globalLock then
		globalLock = currentLock
	end

	-- load files
	if isDir then
		for _, file in ipairs(findFiles(path)) do
			loadFile(file)
		end
	else
		loadFile(path)
	end

	-- check global lock
	if globalLock == currentLock then -- we were the original load call so finish up
		--============================--
		--===== CHECK INTERFACES =====--
		--============================--
		for _, interface in pairs(loadingInterfaces) do
			-- check for references to global methods / variables
			checkInterfaceForGlobals(interface)
			-- check if the interface it is extending exists
			checkInheritanceExists("interface", interface, interfaces, loadingInterfaces)
			-- check for circular inheritance
			checkCircularInheritance("interface", interface, interfaces, loadingInterfaces)
		end
		-- pass on errors to extended interfaces
		propagateErrors("interface", loadingInterfaces)

		-- build interface method inheritance
		-- do not need to do this for interfaces not extending another interface
		-- start at interfaces extending live interfaces
		-- then work through any interfaces extending those
		local pending = {}
		for interfaceName, interface in pairs(loadingInterfaces) do
			if not interface.error then
				if interface.extends and interfaces[interface.extends] then
					table.insert(pending, interfaceName)
				end
			end
		end
		while #pending > 0 do
			pending = buildInterfaceMethodInheritance(pending)
		end

		-- remove references to errored interfaces
		for interfaceName, interface in pairs(loadingInterfaces) do
			checkObjectReferences("interface", interface, interfaces, loadingInterfaces)
			-- add non errored interfaces to live interfaces
			if not interface.error then
				addInterface(interface)
				--interfaces[interfaceName] = interface
			end
		end

		--=========================--
		--===== CHECK CLASSES =====--
		--=========================--
		for _, class in pairs(loadingClasses) do
			-- check for references to global methods / variables
			checkClassForGlobals(class)
			-- check if the class it is extending exists
			checkInheritanceExists("class", class, classes, loadingClasses)
			-- check implemented interfaces exist and are not errored
			checkClassInterfacesExist(class)
			-- check for circular inheritance
			checkCircularInheritance("class", class, classes, loadingClasses)
		end
		-- pass on errors to extended classes
		propagateErrors("class", loadingClasses)

		-- start at classes not extending anything or extending live classes
		-- then work through any classes extending those
		local pending = {}
		for className, class in pairs(loadingClasses) do
			if not class.error then
				if not class.extends or classes[class.extends] then
					table.insert(pending, className)
				end
			end
		end
		while #pending > 0 do
			pending = buildClassInheritance(pending)
		end
		-- pass on errors to extended classes
		propagateErrors("class", loadingClasses)

		-- remove references to errored classes
		for className, class in pairs(loadingClasses) do
			checkObjectReferences("class", class, classes, loadingClasses)
			-- add non errored classes to live classes
			if not class.error then
				addClass(class)
			end
		end

		-- build class environment here
		for className, class in pairs(loadingClasses) do
			if not class.error then
				addImports(class)
			end
		end

		--===========================--
		--===== RESET VARIABLES =====--
		--===========================--
		loadingClasses, loadingInterfaces = {}, {}
		globalLock = false
	end
	return true
end

--==============================--
--===== SETUP LOADER CLASS =====--
--==============================--
local loaderClass = {
	class = "Load",
	static = {
		methods = {
			loadFrom = loadFrom,
		},
	},
}
local err
loaderClass, err = checkLoadedObject(loaderClass)
if not loaderClass then
	printError(err)
	error("could not load the loader!")
end
loaderClass.environmentProxy = _ENV
addClass(loaderClass)
--[[
--==============================--
--===== SETUP CLASSES CLASS =====--
--==============================--
local function get(class)
end
local classesClass = {
	class = "Class",
	static = {
		methods = {
			get = get,
		},
	},
}
local err
loaderClass, err = checkLoadedObject(loaderClass)
if not loaderClass then
	printError(err)
	error("could not load the loader!")
end
addClass(loaderClass)
]]

local function getSize(t)
	local size = 0
	if next(t) then
		for key, value in pairs(t) do
			size = size + 1
		end
	end
	return size
end

aloofInstance.getCounts = function()
	return {
		interfaceFrom = getSize(interfaceFrom),
		classFrom = getSize(classFrom),
		staticFrom = getSize(staticFrom),
		instanceFrom = getSize(instanceFrom),
		staticRawProxyFrom = getSize(staticRawProxyFrom),
		instanceRawProxyFrom = getSize(instanceRawProxyFrom),
		instanceSuperProxyFrom = getSize(instanceSuperProxyFrom),
		environmentFrom = getSize(environmentFrom),
	}
end

environmentFrom[aloofInstance] = mainClassEnvironment
setmetatable(aloofInstance, metatables.environment)

-- load builtin aloof classes
loadFrom(fs.combine(aloofPath, "builtin"))

for path in string.gmatch(paths, "[^;]+") do
	print("Loading Aloof classes at path = ")
	print("  ", path)
	local ok, err = loadFrom(path)
	if not ok then
		printError(err)
	end
end
print("Locating Main class = ")
print("  ", mainClass)
local MainClass = classes[mainClass]
if MainClass then
	print("Found Main class")
	print("Constructing with args = ")
	print("  ", unpack(tArgs, 3))
	local main = MainClass.staticProxy(unpack(tArgs, 3))
	print("Running Main()")
	main:Main()
else
	printError("Could not find Main class = ", mainClass)
end

local REDNET_PROTOCOL = "REMOTE_PERIPHERAL"
local UPDATE_INTERVAL = 1

--===== OPEN REDNET =====--
for _, side in ipairs(redstone.getSides()) do
	if peripheral.getType(side) == "modem" then
		rednet.open(side)
	end
end

if not rednet.isOpen() then
	printError("could not open rednet")
	return
end

--===== PERIPHERALS =====--
local peripheralMethods = {
	--[[
	peripheralType = {
		method = arguments,
	}
	]]
	["BigReactors-Reactor"] = {
		getConnected = {},
		getActive = {},
		isActivelyCooled = {},

		getFuelConsumedLastTick = {},
		getFuelAmount = {},
		getFuelAmountMax = {},
		getFuelReactivity = {},
		getWasteAmount = {},

		getFuelTemperature = {},
		getCasingTemperature = {},

		getCoolantAmount = {},
		getCoolantAmountMax = {},
		getCoolantType = {},

		getEnergyStored = {},
		getEnergyProducedLastTick = {},

		getHotFluidAmount = {},
		getHotFluidAmountMax = {},
		getHotFluidType = {},
		getHotFluidProducedLastTick = {},
	},
	["BigReactors-Turbine"] = {
		getConnected = {},

		getActive = {},
		getInductorEngaged = {},

		getFluidFlowRate = {},
		getFluidFlowRateMax = {},

		getInputType = {},
		getInputAmount = {},
		getOutputType = {},
		getOutputAmount = {},
		getFluidAmountMax = {},

		getRotorSpeed = {},
		getBladeEfficiency = {},

		getEnergyStored = {},
		getEnergyProducedLastTick = {},
	},
}
local peripheralHandlers = {}
for peripheralType, methods in pairs(peripheralMethods) do
	peripheralHandlers[peripheralType] = function(peripheralName)
		local data = {}
		for method, arguments in pairs(methods) do
			data[method] = peripheral.call(peripheralName, method, unpack(arguments))
		end
		return data
	end
end

local function checkPeripheral(peripheralType, peripheralName)
	if peripheralHandlers[peripheralType] then
		return peripheralHandlers[peripheralType](peripheralName)
	end
	return false
end

--===== SOURCES =====--
local sourceMethods = {
	--[[
	source = {
		method = arguments,
	}
	]]
	fluid_handler = {
		getTankInfo = {"unknown"},
	},
	fluid_tank = {
		getInfo = {},
	},
	inventory = {
		getInventoryName = {},
		getInventorySize = {},
		getAllStacks = {false}
	},
	rf_info = {
		getEnergyPerTickInfo = {},
		getMaxEnergyPerTickInfo = {},
		getEnergyInfo = {},
		getMaxEnergyInfo = {},
	},
	rf_receiver = {
		getEnergyStored = {"unknown"},
		getMaxEnergyStored = {"unknown"},
	},
	vanilla_comparator = {
		getOutputSignal = {},
	},
	vanilla_daylight_sensor = {
		hasSky = {},
		getSkyLight = {},
		getBlockLight = {},
		getCelestialAngle = {},
	},
	vanilla_furnace = {
		getBurnTime = {},
		getCookTime = {},
		getCurrentItemBurnTime = {},
		isBurning = {},
	},
}
local sourceHandlers = {}
for source, methods in pairs(sourceMethods) do
	sourceHandlers[source] = function(peripheralName)
		local data = {}
		for method, arguments in pairs(methods) do
			data[method] = peripheral.call(peripheralName, method, unpack(arguments))
		end
		return data
	end
end

local function getSources(peripheralName)
	local peripheralSources = peripheral.call(peripheralName, "listSources")
	local sourcesData = {}
	for peripheralSource, _ in pairs(peripheralSources) do
		if sourceHandlers[peripheralSource] then
			sourcesData[peripheralSource] = sourceHandlers[peripheralSource](peripheralName)
		end
	end
	return sourcesData
end

local function checkSources(peripheralName)
	local peripheralMethods = peripheral.getMethods(peripheralName)
	if peripheralMethods then
		for _, peripheralMethod in ipairs(peripheralMethods) do
			if peripheralMethod == "listSources" then
				return getSources(peripheralName)
			end
		end
	end
	return false
end

--===== MAIN =====--
local function checkPeripherals()
	local peripheralsData = {}
	for _, peripheralName in ipairs(peripheral.getNames()) do

		local peripheralType = peripheral.getType(peripheralName)
		local peripheralData = {
			type = peripheralType,
			main = checkPeripheral(peripheralType, peripheralName),
			sources = checkSources(peripheralName),
		}
		
		peripheralsData[peripheralName] = peripheralData
	end
	
	rednet.broadcast(peripheralsData, REDNET_PROTOCOL)
	rednet.send(os.getComputerID(), peripheralsData, REDNET_PROTOCOL) -- loop back to ourself
end

local updateTime
while true do
	updateTime = os.clock()
	checkPeripherals()
	sleep(math.max(0, UPDATE_INTERVAL + updateTime - os.clock()))
end

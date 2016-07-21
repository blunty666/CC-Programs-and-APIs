--===== CHECK START ARGS =====--
local serverName = (...) or false
if serverName then
	serverName = "ENDER_ITEM:"..tostring(serverName)
else
	serverName = "ENDER_ITEM"
end

--===== LOAD API(S) =====--
if not messageHandlerServer then
	if not os.loadAPI("messageHandlerServer") then
		error("Could not load API: messageHandlerServer")
	end
end

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

--===== DEFINE CONSTANTS =====--
local ID_TO_TYPE = {
	"QUERY",

	"GET_CONTENTS",
	"SET_CONTENTS",

	"GET_AMOUNT",
	"SET_AMOUNT",

	"FILL",
	"EMPTY",

	"EMPTY_ALL",
}
local TYPE_TO_ID = {}
for id, requestType in ipairs(ID_TO_TYPE) do
	TYPE_TO_ID[requestType] = id
end

--===== DEFINE VARIABLES =====--
local interfaceSide = "tileinterface_0"
local enderChestSide = "ender_chest_0"
local interfaceToChestDir = "EAST"

--===== DEFINE UTILITY FUNCTION =====--
local function checkColours(colours)
	if type(colours) ~= "table" then
		return false
	end
	for i = 1, 3 do
		local colour = colours[i]
		if type(colour) ~= "number" then
			return false
		elseif colour < 1 then
			return false
		elseif colour > 32768 then
			return false
		elseif bit.band(colour, colour - 1) ~= 0 then
			return false
		end
	end
	return true
end

local function checkItemID(itemID)
	return type(itemID) == "string"
end

local function checkItemDmg(dmg)
	return dmg == nil or (type(dmg) == "number" and dmg >= 0)
end

local function checkFingerprint(fingerprint)
	if type(fingerprint) ~= "table" then
		return false
	end
	return checkItemID(fingerprint.id) and checkItemDmg(fingerprint.dmg)
end

local function fingerprintsEqual(fingerprint_1, fingerprint_2)
	return fingerprint_1.id == fingerprint_2.id and fingerprint_1.dmg == fingerprint_2.dmg
end

local function checkAmount(amount)
	return type(amount) == "number" and amount >= 0
end

local function checkStackNum(stackNum, inventorySize)
	return type(stackNum) == "number" and stackNum >= 1 and stackNum <= inventorySize and stackNum % 1 == 0
end

local function emptySlot(stackNum, amount)
	return amount == peripheral.call(interfaceSide, "pullItem", interfaceToChestDir, stackNum, amount)
end

--===== DEFINE REQUEST HANDLER FUNCTIONS =====--
local requestHandlers
requestHandlers = {
	[TYPE_TO_ID.QUERY] = function()
		return true, serverName
	end,

	[TYPE_TO_ID.GET_CONTENTS] = function()
		return true, peripheral.call(enderChestSide, "getAllStacks", false)
	end,
	[TYPE_TO_ID.SET_CONTENTS] = function(contents)
		if type(contents) ~= "table" then
			return false, "invalid contents"
		end
		
		local inventorySize = peripheral.call(enderChestSide, "getInventorySize")
		local currentStacks = peripheral.call(enderChestSide, "getAllStacks")
		local currentStack
		
		for stackNum, stack in pairs(contents) do
			if not checkStackNum(stackNum, inventorySize) then
				break
			end
			currentStack = currentStacks[stackNum]
			if stack == false then
				if currentStack then
					emptySlot(stackNum, currentStack.basic().qty)
				end
			elseif checkFingerprint(stack) and checkAmount(stack.qty) then
				local quantityRequired
				if currentStack then -- there is something currently in the slot
					currentStack = currentStack.basic()
					if fingerprintsEqual(stack, currentStack) then -- is the same stack as being requested
						quantityRequired = stack.qty - currentStack.qty
					else -- is a different stack
						if emptySlot(stackNum, currentStack.qty) then -- is different stack so empty slot
							quantityRequired = stack.qty
						else -- failed to empty the slot
							quantityRequired = 0
						end
					end
				else -- slot is currently empty
					quantityRequired = stack.qty
				end
				
				-- move quantityRequired into stackNum
				if quantityRequired > 0 then
					local storedItems = peripheral.call(interfaceSide, "getItemDetail", stack)
					if storedItems then
						peripheral.call(interfaceSide, "exportItem", stack, interfaceToChestDir, quantityRequired, stackNum)
					end
				elseif quantityRequired < 0 then
					emptySlot(stackNum, -quantityRequired)
				end
			end
		end
		return true, peripheral.call(enderChestSide, "getAllStacks", false)
	end,

	[TYPE_TO_ID.GET_AMOUNT] = function(fingerprint)
		if not checkFingerprint(fingerprint) then
			return false, "invalid fingerprint"
		end
		local amount = 0
		local stacks = peripheral.call(enderChestSide, "getAllStacks", false)
		for _, stack in pairs(stacks) do
			if fingerprintsEqual(fingerprint, stack) then
				amount = amount + stack.qty
			end
		end
		return true, amount
	end,
	[TYPE_TO_ID.SET_AMOUNT] = function(fingerprint, amount)
		if not checkFingerprint(fingerprint) then
			return false, "invalid fingerprint"
		elseif not checkAmount(amount) then
			return false, "invalid amount"
		end
		local success, currentAmount = requestHandlers[TYPE_TO_ID.GET_AMOUNT](fingerprint)
		local moved = 0
		if currentAmount < amount then
			success, moved = requestHandlers[TYPE_TO_ID.FILL](fingerprint, amount - currentAmount)
		elseif currentAmount > amount then
			success, moved = requestHandlers[TYPE_TO_ID.EMPTY](fingerprint, currentAmount - amount)
			if success then
				moved = -moved
			end
		end
		return success, success and currentAmount + moved or moved
	end,

	[TYPE_TO_ID.FILL] = function(fingerprint, optional_amount)
		if not checkFingerprint(fingerprint) then
			return false, "invalid fingerprint"
		elseif optional_amount ~= nil and not checkAmount(optional_amount) then
			return false, "invalid amount"
		end

		local amount = optional_amount or math.huge
		local moved, movedAmount = false, 0

		repeat
			local storedItems = peripheral.call(interfaceSide, "getItemDetail", fingerprint)
			if storedItems then
				moved = peripheral.call(interfaceSide, "exportItem", fingerprint, interfaceToChestDir, amount - movedAmount)
				moved = moved.size
			else
				moved = 0
			end
			movedAmount = movedAmount + moved
		until movedAmount >= amount or moved == 0

		return true, movedAmount
	end,
	[TYPE_TO_ID.EMPTY] = function(fingerprint, optional_amount)
		if not checkFingerprint(fingerprint) then
			return false, "invalid fingerprint"
		elseif optional_amount ~= nil and not checkAmount(optional_amount) then
			return false, "invalid amount"
		end

		local amount = optional_amount or math.huge
		local moved, movedAmount = false, 0

		local stacks = peripheral.call(enderChestSide, "getAllStacks", false)
		for stackNum, stack in pairs(stacks) do
			if fingerprintsEqual(fingerprint, stack) then
				moved = peripheral.call(interfaceSide, "pullItem", interfaceToChestDir, stackNum, amount - movedAmount)
				movedAmount = movedAmount + moved
				if movedAmount >= amount or moved == 0 then
					break
				end
			end
		end

		return true, movedAmount
	end,

	[TYPE_TO_ID.EMPTY_ALL] = function()
		for stackNum = 1, peripheral.call(enderChestSide, "getInventorySize") do
			peripheral.call(interfaceSide, "pullItem", interfaceToChestDir, stackNum)
		end
		return true
	end,
}

local function handleRequest(request)
	if type(request) ~= "table" then
		return false, "invalid request"
	elseif not requestHandlers[ request[1] ] then
		return false, "invalid request type"
	elseif not checkColours(request[2]) and request[1] ~= TYPE_TO_ID.QUERY then
		return false, "invalid colours"
	end
	if request[1] ~= TYPE_TO_ID.QUERY then
		peripheral.call(enderChestSide, "setColours", unpack(request[2], 1, 3))
	end
	return requestHandlers[ request[1] ](unpack(request, 3))
end

for requestID, requestType in ipairs(ID_TO_TYPE) do
	if not requestHandlers[requestID] then
		printError("No request handler provided for request type: ", requestType)
	end
end

--===== CREATE AND RUN MESSAGE HANDLER =====--
local messageHandler = messageHandlerServer.new(handleRequest, "ENDER_ITEM")
messageHandler:Run()

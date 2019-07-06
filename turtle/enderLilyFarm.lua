local ENDER_LILLY_PLANT_STRING = "ExtraUtilities:plant/ender_lilly"
local ENDER_LILLY_MATURE_METADATA = 7

local ENDER_CHEST_STRING = "EnderStorage:enderChest"
local ENDER_CHEST_EMPTY_COLOUR = {colours.black, colours.black, colours.black}
local ENDER_CHEST_REFUEL_COLOUR = {colours.grey, colours.grey, colours.grey}

local FUEL_ITEM_NAME = "minecraft:coal"
local FUEL_ITEM_AMOUNT = 80

local function emptyInventory()
	for slotNum = 1, 16 do
		local slotData = turtle.getItemDetail(slotNum)
		if slotData and slotData.name == ENDER_CHEST_STRING then
			turtle.select(slotNum)
			if turtle.placeUp() then
				local chest = peripheral.wrap("top")
				if chest and chest.setColours then
					chest.setColours(unpack(ENDER_CHEST_EMPTY_COLOUR))
				end
				for i = 1, 16 do
					turtle.select(i)
					turtle.dropUp()
				end
				turtle.select(1)
				turtle.digUp()
			end
			break
		end
	end
end

local function plantSeed()
	for slotNum = 1, 16 do
		local slotData = turtle.getItemDetail(slotNum)
		if slotData and slotData.name == ENDER_LILLY_PLANT_STRING then
			turtle.select(slotNum)
			turtle.placeDown()
			break
		end
	end
end

local function checkEnderPlant()
	local isBlock, blockData = turtle.inspectDown()
	if isBlock then
		if blockData.name == ENDER_LILLY_PLANT_STRING and blockData.metadata >= ENDER_LILLY_MATURE_METADATA then
			if turtle.digDown() then
				plantSeed()
			end
		end
	else
		plantSeed()
	end
end

local function refuel()
	for slotNum = 1, 16 do
		local slotData = turtle.getItemDetail(slotNum)
		if slotData and slotData.name == ENDER_CHEST_STRING then
			turtle.select(slotNum)
			if turtle.placeUp() then
				local chest = peripheral.wrap("top")
				if chest then
					if chest.setColours then
						chest.setColours(unpack(ENDER_CHEST_REFUEL_COLOUR))
					end
					local fuelAmountNeeded = math.ceil((turtle.getFuelLimit() - turtle.getFuelLevel()) / FUEL_ITEM_AMOUNT)
					if chest.getAllStacks then
						local stacks = chest.getAllStacks()
						for slotNum, slotInfo in pairs(stacks) do
							if slotInfo.id == FUEL_ITEM_NAME then
								local number = math.min(fuelAmountNeeded, slotInfo.qty)
								number = chest.pushItemIntoSlot("down", slotNum, number)
								fuelAmountNeeded = fuelAmountNeeded - number
							end
							if fuelAmountNeeded <= 0 then
								break
							end
						end
						for slotNum = 1, 16 do
							turtle.select(slotNum)
							turtle.refuel()
						end
					end
				end
				turtle.select(1)
				turtle.digUp()
			end		
			break
		end
	end
end

emptyInventory()

local numCorners = 0
local turnLeft = true
while true do
	if numCorners >= 2 then
		numCorners = 0
		emptyInventory()
		sleep(600)
	end
	if turtle.getFuelLevel() <= 500 then
		emptyInventory()
		refuel()
	end
	checkEnderPlant()
	if turtle.detect() then
		if turnLeft then
			turtle.turnLeft()
			if turtle.detect() then
				turtle.turnLeft()
				numCorners = numCorners + 1
			else
				turtle.forward()
				checkEnderPlant()
				turtle.turnLeft()
				turnLeft = not turnLeft
			end
		else
			turtle.turnRight()
			if turtle.detect() then
				turtle.turnRight()
				numCorners = numCorners + 1
			else
				turtle.forward()
				checkEnderPlant()
				turtle.turnRight()
				turnLeft = not turnLeft
			end
		end
	end
	turtle.forward()
end

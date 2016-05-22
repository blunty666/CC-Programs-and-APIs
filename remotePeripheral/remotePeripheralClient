local REMOTE_PERIPHERAL_PROTOCOL = "REMOTE_PERIPHERAL"

local remotePeripheralClientMethods = {
	GetAllData = function(self, peripheralName)
		return self.list[peripheralName] or false
	end,
	GetMainData = function(self, peripheralName)
		local allData = self:GetAllData(peripheralName)
		return (allData and allData.main) or false
	end,
	GetSourceData = function(self, peripheralName, sourceType)
		local allData = self:GetAllData(peripheralName)
		return (allData and allData.sources and allData.sources[sourceType]) or false
	end,
	GetTimeoutInterval = function(self)
		return self.timeoutInterval
	end,
	SetTimeoutInterval = function(self, timeoutInterval)
		if type(timeoutInterval) == "number" and timeoutInterval >= 0 then
			self.timeoutInterval = timeoutInterval
			return true
		end
		return false
	end,
	Run = function(self)
	
		-- open rednet
		for _, side in ipairs(redstone.getSides()) do
			if peripheral.getType(side) == "modem" then
				rednet.open(side)
			end
		end
		if not rednet.isOpen() then
			printError("could not open rednet")
			return
		end

		-- main loop
		local timer = os.startTimer(self.timeoutInterval)
		local event, eventType
		while true do
			event = {os.pullEvent()}
			eventType = event[1]
			if eventType == "rednet_message" then
				local senderID, message, protocol = unpack(event, 2)
				if protocol == REMOTE_PERIPHERAL_PROTOCOL and type(message) == "table" then
					for peripheralName, peripheralData in pairs(message) do
						if not self.list[peripheralName] then
							peripheralData.ID = senderID
							peripheralData.timeout = 0
							self.list[peripheralName] = peripheralData
							os.queueEvent("remote_peripheral_add", peripheralName)
						elseif self.list[peripheralName].ID == senderID then
							self.list[peripheralName].main = peripheralData.main
							self.list[peripheralName].sources = peripheralData.sources
							self.list[peripheralName].timeout = 0
						end
					end
				end
			elseif eventType == "timer" and event[2] == timer then
				local toDelete = {}
				for peripheralName, peripheralData in pairs(self.list) do
					peripheralData.timeout = peripheralData.timeout + 1
					if peripheralData.timeout >= 3 then
						table.insert(toDelete, peripheralName)
					end
				end
				for _, peripheralName in ipairs(toDelete) do
					self.list[peripheralName] = nil
					os.queueEvent("remote_peripheral_remove", peripheralName)
				end
				timer = os.startTimer(self.timeoutInterval)
			end
		end
	end,
}
local remotePeripheralClientMetatable = {__index = remotePeripheralClientMethods}

function new()
	local remotePeripheralClient = {
		list = {},
		timeoutInterval = 20,
	}
	
	return setmetatable(remotePeripheralClient, remotePeripheralClientMetatable)
end

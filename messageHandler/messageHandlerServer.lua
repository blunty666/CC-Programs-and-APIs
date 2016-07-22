local MESSAGE_HANDLER_PROTOCOL = "MESSAGE_HANDLER"

local messageHandlerServerMethods = {
	GetMessageHandlerFunc = function(self)
		return self.messageHandlerFunc
	end,
	SetMessageHandlerFunc = function(self, messageHandlerFunc)
		if type(messageHandlerFunc) == "function" then
			self.messageHandlerFunc = messageHandlerFunc
			return true
		end
		return false
	end,
	Run = function(self)
		local event
		while true do
			event = {os.pullEvent()}
			if event[1] == "rednet_message" then
				local senderID, message, protocol = event[2], event[3], event[4]
				if protocol == self.protocol then
					if type(message) == "table" and type(message.ID) == "number" and message.type == "request" then
						local reply
						if self.resultList[message.ID] then
							reply = {
								ID = message.ID,
								type = "result",
								body = self.resultList[message.ID],
							}
						else
							if not self.queuedList[message.ID] then
								self.queuedList[message.ID] = {
									senderID = senderID,
									body = message.body,
								}
								table.insert(self.orderedQueue, message.ID)
								os.queueEvent("message_handler_server_queued")
							end
							reply = {
								ID = message.ID,
								type = "queued",
							}
						end
						rednet.send(senderID, reply, self.protocol)
					end
				end
			elseif event[1] == "timer" then
				local timer = event[2]
				if self.resultTimers[timer] then
					self.resultList[self.resultTimers[timer]] = nil
					self.resultTimers[timer] = nil
				end
			elseif event[1] == "message_handler_server_queued" then
				if #self.orderedQueue > 0 then
					local messageID = table.remove(self.orderedQueue, 1)
					local message = self.queuedList[messageID]
					self.queuedList[messageID] = nil
					
					local result = {self.messageHandlerFunc(message.body)}
					
					self.resultList[messageID] = result
					self.resultTimers[os.startTimer(5)] = messageID
					
					local reply = {
						ID = messageID,
						type = "result",
						body = result,
					}
					rednet.send(message.senderID, reply, self.protocol)
					
					if #self.orderedQueue > 0 then
						os.queueEvent("message_handler_server_queued")
					end
				end
			end
		end
	end,
}
local messageHandlerServerMetatable = {__index = messageHandlerServerMethods}

function new(messageHandlerFunc, optional_protocol)
	if type(messageHandlerFunc) ~= "function" then
		error("new: messageHandlerFunc - function expected")
	end
	if optional_protocol ~= nil and type(optional_protocol) ~= "string" then
		error("new: optional_protocol - string expected")
	end
	local messageHandlerServer = {
		messageHandlerFunc = messageHandlerFunc,
		protocol = MESSAGE_HANDLER_PROTOCOL,
		orderedQueue = {},
		queuedList = {},
		resultList = {},
		resultTimers = {},
	}
	if optional_protocol then
		messageHandlerServer.protocol = MESSAGE_HANDLER_PROTOCOL..":"..optional_protocol
	end
	rednet.host(messageHandlerServer.protocol, "SERVER"..os.getComputerID())
	return setmetatable(messageHandlerServer, messageHandlerServerMetatable)
end

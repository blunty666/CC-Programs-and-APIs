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
		local function queueMessages()
			while true do
				local senderID, message = rednet.receive(self.protocol)
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
		end
		local function clearResults()
			while true do
				local _, timer = os.pullEvent("timer")
				if self.resultTimers[timer] then
					self.resultList[self.resultTimers[timer]] = nil
					self.resultTimers[timer] = nil
				end
			end
		end
		local function processMessages()
			while true do
				os.pullEvent("message_handler_server_queued")
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
		parallel.waitForAny(queueMessages, clearResults, processMessages)
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
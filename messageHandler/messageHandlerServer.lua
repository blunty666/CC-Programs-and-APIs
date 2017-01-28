local MESSAGE_HANDLER_PROTOCOL = "MESSAGE_HANDLER"

local messageHandlerServerMethods = {
	GetRequestHandler = function(self)
		return self.requestHandler
	end,
	SetRequestHandler = function(self, requestHandler)
		if type(requestHandler) == "function" or requestHandler == false then
			self.requestHandler = requestHandler
			return true
		end
		return false
	end,
	GetBroadcastHandler = function(self)
		return self.broadcastHandler
	end,
	SetBroadcastHandler = function(self, broadcastHandler)
		if type(broadcastHandler) == "function" or broadcastHandler == false then
			self.broadcastHandler = broadcastHandler
			return true
		end
		return false
	end,
	Run = function(self)
		local function queueHandler()
			local event
			while true do
				event = {os.pullEvent()}
				if event[1] == "rednet_message" then
					local senderID, message, protocol = event[2], event[3], event[4]
					if protocol == self.protocol and type(message) == "table" and type(message.ID) == "number" then
						if message.type == "request" then
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
										type = "request",
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
						elseif message.type == "broadcast" then
							if not self.queuedList[message.ID] then
								self.queuedList[message.ID] = {
									type = "broadcast",
									senderID = senderID,
									body = message.body,
								}
								table.insert(self.orderedQueue, message.ID)
								os.queueEvent("message_handler_server_queued")
							end
						end
					end
				elseif event[1] == "timer" then
					local timer = event[2]
					if self.resultTimers[timer] then
						self.resultList[self.resultTimers[timer]] = nil
						self.resultTimers[timer] = nil
					end
				end
			end
		end
			
		local function messageHandler()
			while true do
				if #self.orderedQueue > 0 then
					local messageID = table.remove(self.orderedQueue, 1)
					local message = self.queuedList[messageID]
					self.queuedList[messageID] = nil
					
					if message.type == "request" then
						local result
						if self.requestHandler then
							result = {self.requestHandler(message.body, message.senderID)}
						else
							result = false
						end
					
						self.resultList[messageID] = result
						self.resultTimers[os.startTimer(5)] = messageID
						
						local reply = {
							ID = messageID,
							type = "result",
							body = result,
						}
						rednet.send(message.senderID, reply, self.protocol)
					elseif message.type == "broadcast" and self.broadcastHandler then
						self.broadcastHandler(message.body, message.senderID)
					end
					
					if #self.orderedQueue > 0 then
						os.queueEvent("message_handler_server_queued")
					end
				end
				coroutine.yield()
			end
		end

		parallel.waitForAny(queueHandler, messageHandler)
	end,
}
local messageHandlerServerMetatable = {__index = messageHandlerServerMethods}

function new(requestHandler, broadcastHandler, optional_protocol)
	if requestHandler ~= nil and type(requestHandler) ~= "function" then
		error("new: requestHandler - function expected", 2)
	elseif broadcastHandler ~= nil and type(broadcastHandler) ~= "function" then
		error("new: broadcastHandler - function expected", 2)
	elseif optional_protocol ~= nil and type(optional_protocol) ~= "string" then
		error("new: optional_protocol - string expected", 2)
	end
	local messageHandlerServer = {
		requestHandler = requestHandler or false,
		broadcastHandler = broadcastHandler or false,
		protocol = MESSAGE_HANDLER_PROTOCOL,
		orderedQueue = {},
		queuedList = {},
		resultList = {},
		resultTimers = {},
	}
	if optional_protocol then
		messageHandlerServer.protocol = MESSAGE_HANDLER_PROTOCOL..":"..optional_protocol
	end
	rednet.host(messageHandlerServer.protocol, "SERVER_"..os.getComputerID())
	return setmetatable(messageHandlerServer, messageHandlerServerMetatable)
end

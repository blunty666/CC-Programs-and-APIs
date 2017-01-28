local MESSAGE_HANDLER_PROTOCOL = "MESSAGE_HANDLER"

local function check(response, packet)
	if not type(response) == "table" then
		return false
	elseif response.ID ~= packet.ID then
		return false
	end
	return true
end

local function waitForResponse(recipientID, packet, protocol, timeout)
	local currentTimeout = timeout
	local startTime = os.clock()
	while true do
		local senderID, response = rednet.receive(protocol, currentTimeout)
		if senderID then
			if senderID == recipientID and check(response, packet) then
				return response
			else
				currentTimeout = math.max(0, timeout - (os.clock() - startTime))
			end
		else
			return false
		end
	end
end

local function sendAndWaitForResponse(recipientID, packet, protocol)
	local attempt = 1
	rednet.send(recipientID, packet, protocol)
	while true do
		local response = waitForResponse(recipientID, packet, protocol, 3)
		if response then
			return response
		elseif attempt < 3 then
			rednet.send(recipientID, packet, protocol)
			attempt = attempt + 1
		else
			return false
		end
	end
end

local function sendPacket(serverID, packet, protocol)
	local response = sendAndWaitForResponse(serverID, packet, protocol)
	if response then
		if response.type == "result" then
			return true, response.body
		elseif response.type == "queued" then
			while true do
				local response = waitForResponse(serverID, packet, protocol, 15)
				if response and response.type == "result" then
					return true, response.body
				else
					return sendPacket(serverID, packet)
				end
			end
		end
	end
	return false
end

local function newPacket(message, packetType, optional_protocol)
	if optional_protocol ~= nil and type(optional_protocol) ~= "string" then
		error("send: optional_protocol - string expected", 2)
	end
	local packet = {
		ID = math.random(0, 2^24),
		type = packetType,
		body = message,
	}
	local protocol = MESSAGE_HANDLER_PROTOCOL
	if optional_protocol then
		protocol = protocol..":"..optional_protocol
	end
	return packet, protocol
end

function send(serverID, message, optional_protocol)
	local packet, protocol = newPacket(message, "request", optional_protocol)
	return sendPacket(serverID, packet, protocol)
end

function broadcast(message, optional_protocol)
	local packet, protocol = newPacket(message, "broadcast", optional_protocol)
	return rednet.broadcast(packet, protocol)
end

function findServer(optional_protocol)
	if optional_protocol ~= nil and type(optional_protocol) ~= "string" then
		error("findServer: optional_protocol - string expected")
	end
	local protocol = MESSAGE_HANDLER_PROTOCOL
	if optional_protocol then
		protocol = protocol..":"..optional_protocol
	end
	return rednet.lookup(protocol)
end

--===== LOAD API(S) =====--
if not messageHandlerClient then
	if not os.loadAPI("messageHandlerClient") then
		error("Could not load API: messageHandlerClient")
	end
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

--===== DEFINE UTIL FUNCTIONS =====--
local function createRequest(requestType, colours, arg1, arg2)
	return {
		requestType,
		colours,
		arg1,
		arg2,
	}
end

local function sendRequest(serverID, request)
	local ok, response = messageHandlerClient.send(serverID, request, "ENDER_ITEM")
	if ok then
		return unpack(response)
	end
	return false
end

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

local function checkPositiveInteger(value)
	return type(value) == "number" and value >= 0 and value % 1 == 0
end

local function checkMainArguments(serverID, colours)
	if not checkPositiveInteger(serverID) then
		return false, "positive integer expected: serverID"
	end
	if not checkColours(colours) then
		return false, "triplet of colours expected: colours"
	end
	return true
end

--===== DEFINE MAIN FUNCTIONS =====--
function query(serverID)
	if not checkPositiveInteger(serverID) then
		error("query - positive integer expected: serverID")
	end
	local request = createRequest(TYPE_TO_ID.QUERY)
	return sendRequest(serverID, request)
end

function getContents(serverID, colours)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("getContents - "..err)
	end
	local request = createRequest(TYPE_TO_ID.GET_CONTENTS, colours)
	return sendRequest(serverID, request)
end

function setContents(serverID, colours, contents)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("setContents - "..err)
	end
	local request = createRequest(TYPE_TO_ID.SET_CONTENTS, colours, contents)
	return sendRequest(serverID, request)
end

function getAmount(serverID, colours, fingerprint)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("getAmount - "..err)
	end
	local request = createRequest(TYPE_TO_ID.GET_AMOUNT, colours, fingerprint)
	return sendRequest(serverID, request)
end

function setAmount(serverID, colours, fingerprint, amount)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("setAmount - "..err)
	end
	local request = createRequest(TYPE_TO_ID.SET_AMOUNT, colours, fingerprint, amount)
	return sendRequest(serverID, request)
end

function fill(serverID, colours, fingerprint, optional_amount)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("fill - "..err)
	end
	local request = createRequest(TYPE_TO_ID.FILL, colours, fingerprint, optional_amount)
	return sendRequest(serverID, request)
end

function empty(serverID, colours, fingerprint, optional_amount)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("empty - "..err)
	end
	local request = createRequest(TYPE_TO_ID.EMPTY, colours, fingerprint, optional_amount)
	return sendRequest(serverID, request)
end

function emptyAll(serverID, colours)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("emptyAll - "..err)
	end
	local request = createRequest(TYPE_TO_ID.EMPTY_ALL, colours)
	return sendRequest(serverID, request)
end

--===== DEFINE ENDER CHEST HANDLER =====--
local enderChestHandlerMethods = {
	GetContents = function(self)
		return getContents(self.serverID, self.colours)
	end,
	SetContents = function(self, contents)
		return setContents(self.serverID, self.colours, contents)
	end,
	GetAmount = function(self, fingerprint)
		return getAmount(self.serverID, self.colours, fingerprint)
	end,
	SetAmount = function(self, fingerprint, amount)
		return setAmount(self.serverID, self.colours, fingerprint, amount)
	end,
	Fill = function(self, fingerprint, optional_amount)
		return fill(self.serverID, self.colours, fingerprint, optional_amount)
	end,
	Empty = function(self, fingerprint, optional_amount)
		return empty(self.serverID, self.colours, fingerprint, optional_amount)
	end,
	EmptyAll = function(self)
		return emptyAll(self.serverID, self.colours)
	end,
}
local enderChestHandlerMetatable = {__index = enderChestHandlerMethods}

function newEnderChestHandler(serverID, colours)
	local ok, err = checkMainArguments(serverID, colours)
	if not ok then
		error("newEnderChestHandler - "..err)
	end
	local enderChestHandler = {
		serverID = serverID,
		colours = colours,
	}
	return setmetatable(enderChestHandler, enderChestHandlerMetatable)
end

--===== DEFINE HELPER FUNCTIONS =====--
function findServers(optional_serverName)
	if optional_serverName ~= nil and type(optional_serverName) ~= "string" then
		error("find - string expected: optional_serverName")
	end
	local servers = {messageHandlerClient.findServer("ENDER_ITEM")}
	if optional_serverName then
		local updatedServers = {}
		local serverName = "ENDER_ITEM:"..optional_serverName
		for _, serverID in ipairs(servers) do
			local ok, response = query(serverID)
			if ok and response == serverName then
				table.insert(updatedServers, serverID)
			end
		end
		return updatedServers
	else
		return servers
	end
end

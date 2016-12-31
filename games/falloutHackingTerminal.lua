local tArgs = {...}

local function printUsage()
	print("Usage:")
	print(fs.getName(shell.getRunningProgram()).." <word_length> <can_terminate> <difficulty> <script_path> <password>")
end

local wordLength = tonumber(tArgs[1])
if not wordLength or wordLength < 4 then
	printError("wordLength must be a number greater than 3")
	printUsage()
	return
end
local gapSize
local difficulties = {20, 15, 10, 5}
local difficulty = tonumber(tArgs[2])
if difficulties[difficulty] then
	gapSize = difficulties[difficulty]
else
	printError("difficulty must be a number between 1 and 4")
	printUsage()
	return
end

local canTerminate = tArgs[3] == "true"

local successScriptPath = tArgs[4]

local password
if type(tArgs[5]) == "string" and string.len(tArgs[5]) == wordLength then
	password = string.upper(tArgs[5])
end

local clickCatcher

local START_POS = 1
local END_POS = 2
local TYPE = 3
local WORD = 4
local LIKENESS = 5
local REMOVED = 6
local HACK_TYPE = 5
local clickableMap = {
	--[[
	{ -- Clickable ID - uses array indices
		"startPos",
		"endPos",
		"word_or_hack",
		
		-- word
		"word",
		"likeness",
		"removed",
		
		-- hack
		"text",
		"hack_type",
	},
	]]
}

local X_POS = 1
local Y_POS = 2
local CHAR = 3
local CLICKABLE_ID = 4
local map = {
	--[[
	{ -- map pos - uses array indices
		"xPos",
		"yPos",
		"char",
		"clickableID_or_false",
	},
	]]
}


local coordToPos = {
	--[xPos..":"..yPos] = "mapPos",
}

local directions = {
	[keys.up]    = { 0, -1},
	[keys.down]  = { 0,  1},
	[keys.left]  = {-1,  0},
	[keys.right] = { 1,  0},
	
	[keys.w] = { 0, -1},
	[keys.s] = { 0,  1},
	[keys.a] = {-1,  0},
	[keys.d] = { 1,  0},
}

--===== WINDOWS =====--
term.setBackgroundColour(colours.black)
term.clear()

local terminalColour = (term.isColour() and colours.green) or colours.white

local width, height = term.getSize()

local headerWindow = window.create(term.current(), 1, 1, width, 5, true)
headerWindow.setTextColour(terminalColour)

local hackerWindow = window.create(term.current(), 1, 6, width - 14, height - 6, true)
hackerWindow.setTextColour(terminalColour)

local outputWindow = window.create(term.current(), width - 14 + 1, 6, 14, height - 6, true)
outputWindow.setTextColour(terminalColour)

--===== FUNCTIONS =====--
local function calcNumColumns(width)
	return math.ceil(width/21)
end

local function calcRowBaseWidth(width, numColumns)
	return math.floor((width - (numColumns*6))/numColumns)
end

local function calcExtraThreshold(width, numColumns, rowBaseWidth)
	return width - (numColumns*6) - (numColumns*rowBaseWidth)
end

local function calcDimensions(width)
	width = width - 1
	local dimensions, totalRowLength = {}, nil
	if width < 6 then
		return false
	elseif width < 11 then
		dimensions[1] = {
			width - 1,
			2,
		}
		useHex = false
		totalRowLength = width - 1
	else
		local numColumns = calcNumColumns(width)
		local rowBaseWidth = calcRowBaseWidth(width, numColumns)
		local extraThreshold = calcExtraThreshold(width, numColumns, rowBaseWidth)
		totalRowLength = 0
		local currentLength = 2
		for column = 1, numColumns do
			local rowLength = (column <= extraThreshold and rowBaseWidth + 1) or rowBaseWidth
			totalRowLength = totalRowLength + rowLength
			dimensions[column] = {
				rowLength,
				currentLength,
			}
			currentLength = currentLength + rowLength + 6
		end
		useHex = true
	end
	return dimensions, useHex, totalRowLength
end

local hexChars = {
	"0", "1", "2", "3", "4", "5", "6", "7",
	"8", "9", "A", "B", "C", "D", "E", "F",
}
local function numToHex(num)
	local char1 = hexChars[math.floor(num/16) + 1]
	local char2 = hexChars[(num % 16) + 1]
	return "0x"..char1..char2
end

local function buildExternalMap(dimensions, height, useHex, internalMap)
	local externalMap = {}
	local clickCatcher = {}
	local pos, coordOffset, rowLength, rowOffset = 1, 0, nil, nil
	local hexStart = math.random(1, 255 - (#dimensions*height))
	for column, rowData in ipairs(dimensions) do
		rowLength, rowOffset = rowData[1], rowData[2]
		for row = 1, height do
			if useHex then
				hackerWindow.setCursorPos(rowOffset, row)
				hackerWindow.write(numToHex(hexStart))
				hexStart = hexStart + 1
			end
			for rowPos = 1, rowLength do
				local posData = internalMap[pos]
				posData[X_POS], posData[Y_POS] = rowOffset + rowPos - 1, row
				if useHex then
					posData[X_POS] = posData[X_POS] + 5
				end
				clickCatcher[tostring(posData[X_POS])..":"..tostring(posData[Y_POS])] = {coordOffset + rowPos, row}
				
				hackerWindow.setCursorPos(posData[X_POS], posData[Y_POS])
				hackerWindow.write(posData[CHAR])
				
				externalMap[tostring(coordOffset + rowPos)..":"..tostring(row)] = pos
				pos = pos + 1
			end
		end
		coordOffset = coordOffset + rowLength
	end
	return externalMap, clickCatcher
end

local function buildInternalMap(internalMapString, clickableMap)
	local internalMap = {}
	for pos = 1, internalMapString:len() do
		internalMap[pos] = {
			[X_POS] = 0,
			[Y_POS] = 0,
			[CHAR] = string.sub(internalMapString, pos, pos),
			[CLICKABLE_ID] = false,
		}
	end
	for clickableID, clickableData in ipairs(clickableMap) do
		if clickableData[TYPE] == "WORD" then
			for pos = clickableData[START_POS], clickableData[END_POS] do
				internalMap[pos][CLICKABLE_ID] = clickableID
			end
		elseif clickableData[TYPE] == "HACK" then
			internalMap[clickableData[START_POS]][CLICKABLE_ID] = clickableID
		end
	end
	return internalMap
end

local function fetchWordList(wordLength, amount)
	local url = "http://www.setgetgo.com/randomword/get.php?len="..tostring(wordLength)
	for i = 1, amount do
		http.request(url)
	end
	local wordList = {}
	local timer = os.startTimer(1)
	local event
	while true do
		event = {os.pullEventRaw()}
		if event[1] == "timer" and event[2] == timer then
			break
		elseif event[1] == "http_success" and event[2] == url then
			table.insert(wordList, event[3].readAll():upper())
		end
	end
	return wordList
end

local function compareStrings(string1, string2)
	local likeness = 0
	for i = 1, string1:len() do
		if string1:sub(i, i) == string2:sub(i, i) then
			likeness = likeness + 1
		end
	end
	return likeness
end

local function wordListSorter(word1, word2)
	return compareStrings(password, word1) > compareStrings(password, word2)
end

local function findHack(hacks, str, offset, startChar, endChar)
	local curPos = 1
	while curPos and curPos <= str:len() do
		local startPos = str:find("["..startChar.."]", curPos)
		if startPos and startPos < str:len() then
			local endPos = str:find("["..endChar.."]", startPos + 1)
			if endPos then
				table.insert(hacks, {startPos + offset, endPos + offset})
				curPos = startPos + 1
			else
				curPos = false
			end
		else
			curPos = false
		end
	end
end

local hackChars = {
	{"%[", "%]"},
	{"%(", "%)"},
	{"%{", "%}"},
	{"%<", "%>"},
}
local function findHacks(hacks, str, offset)
	for _, chars in ipairs(hackChars) do
		findHack(hacks, str, offset, unpack(chars))
	end
end

local chars = {
	"!", "@", "#", "$", "%", "^", "@", "\/",
	"*", "(", ")", "_", "-", "+", "=", "\\",
	"[", "{", "]", "|", ",", "\'", "\"",
	"}", ";", ":", ".", ">", "<", "?",
}
local charsSize = #chars
local function buildInternalMapString(totalLength, wordLength)
	local internalMapString = ""
	for char = 1, totalLength do
		internalMapString = internalMapString..chars[math.random(1, charsSize)]
	end
	local clickableMap = {}

	-- add words
	local wordList = fetchWordList(wordLength, 50)
	if not password then
		password = table.remove(wordList, 1)
	end
	table.sort(wordList, wordListSorter)
	local wordCount = math.floor(totalLength/(wordLength + gapSize))
	local passwordPosition = math.random(1, wordCount)
	for i = 1, wordCount do
		local thisWord
		if i == passwordPosition then
			thisWord = password
		else
			thisWord = table.remove(wordList, 1)
		end
		if thisWord then
			local startPos = (i - 1)*(wordLength + gapSize)
			startPos = startPos + math.random(1, gapSize)
			internalMapString = internalMapString:sub(1, startPos - 1)..thisWord..internalMapString:sub(startPos + wordLength, totalLength)
			local clickableData = {
				startPos,
				startPos + wordLength - 1,
				"WORD",
				thisWord,
				compareStrings(password, thisWord),
			}
			table.insert(clickableMap, clickableData)
		end
	end

	-- add hacks
	local hacks = {}
	local curPos = 1
	while curPos and curPos <= totalLength do
		local startPos, endPos = string.find(internalMapString, "[^%a]+", curPos)
		if startPos then
			local curStr = string.sub(internalMapString, startPos, endPos)
			
			findHacks(hacks, curStr, startPos - 1)
			
			curPos = endPos + 1
		else
			curPos = false
		end
	end
	for _, hack in ipairs(hacks) do
		local clickableData = {
			hack[1],
			hack[2],
			"HACK",
			internalMapString:sub(hack[1], hack[2]),
			(math.random(1, 10) > 8 and "RESET") or "REMOVE",
		}
		table.insert(clickableMap, clickableData)
	end

	return internalMapString, clickableMap
end

local headerDrawn = false
local function buildMaps(width, height, wordLength)
	local dimensions, useHex, totalRowLength = calcDimensions(width)
	local internalMapString, clickableMap = buildInternalMapString(totalRowLength*height, wordLength)
	local internalMap = buildInternalMap(internalMapString, clickableMap)
	while not headerDrawn do
		os.pullEventRaw()
	end
	local externalMap, clickCatcher = buildExternalMap(dimensions, height, useHex, internalMap)
	return internalMap, externalMap, clickableMap, clickCatcher
end	

local function draw(win, xPos, yPos, backgroundColour, textColour, text)
	win.setCursorPos(xPos, yPos)
	win.setBackgroundColour(backgroundColour)
	win.setTextColour(textColour)
	win.write(text)
end

local function drawOutput(text, doScroll)
	outputWindow.setCursorPos(1, height - 6)
	if doScroll then
		outputWindow.scroll(1)
	else
		outputWindow.clearLine()
	end
	outputWindow.write(">"..text)
end

local function dehighlightClickable(cursorX, cursorY)
	local posData = map[coordToPos[tostring(cursorX)..":"..tostring(cursorY)]]
	outputWindow.setCursorBlink(false)
	if posData[CLICKABLE_ID] then
		local clickableData = clickableMap[posData[CLICKABLE_ID]]
		for pos = clickableData[START_POS], clickableData[END_POS] do
			local curPos = map[pos]
			draw(hackerWindow, curPos[X_POS], curPos[Y_POS], colours.black, terminalColour, curPos[CHAR])
		end
		drawOutput(">")
	else
		draw(hackerWindow, posData[X_POS], posData[Y_POS], colours.black, terminalColour, posData[CHAR])
		drawOutput(">")
	end
end

local function findCoords(cursorX, cursorY, deltaX, deltaY)
	local curPos = coordToPos[tostring(cursorX)..":"..tostring(cursorY)]
	local curData = map[curPos]
	
	local logSession = math.random()
	
	local newCursorX, newCursorY = cursorX, cursorY
	local newPos, newData
	while true do
		newPos = coordToPos[tostring(newCursorX + deltaX)..":"..tostring(newCursorY + deltaY)]
		if not newPos then
			if deltaX ~= 0 then
				newPos = coordToPos[tostring(newCursorX)..":"..tostring(newCursorY)] + deltaX
				newData = map[newPos]
				if newData then
					local posData = clickCatcher[tostring(newData[X_POS])..":"..tostring(newData[Y_POS])]
					if newData[CLICKABLE_ID] == false or newData[CLICKABLE_ID] ~= curData[CLICKABLE_ID] then
						return posData[1], posData[2]
					end
					newCursorX, newCursorY = posData[1] - deltaX, posData[2] - deltaY
				else
					return newCursorX, newCursorY
				end
			else
				return newCursorX, newCursorY
			end
		else
			newData = map[newPos]
			if newData[CLICKABLE_ID] == false or newData[CLICKABLE_ID] ~= curData[CLICKABLE_ID] then
				return newCursorX + deltaX, newCursorY + deltaY
			end
		end
		newCursorX, newCursorY = newCursorX + deltaX, newCursorY + deltaY
	end
end

local function highlightClickable(cursorX, cursorY)
	local posData = map[coordToPos[tostring(cursorX)..":"..tostring(cursorY)]]
	if posData[CLICKABLE_ID] then
		local clickableData = clickableMap[posData[CLICKABLE_ID]]
		for pos = clickableData[START_POS], clickableData[END_POS] do
			local curPos = map[pos]
			draw(hackerWindow, curPos[X_POS], curPos[Y_POS], terminalColour, colours.black, curPos[CHAR])
		end
		drawOutput(clickableData[WORD])
	else
		draw(hackerWindow, posData[X_POS], posData[Y_POS], terminalColour, colours.black, posData[CHAR])
		drawOutput(posData[CHAR])
	end
	outputWindow.setCursorBlink(true)
end

local function findWord(wordLength)
	local clickableIDs = {}
	for i = 1, #clickableMap do
		table.insert(clickableIDs, i)
	end
	while #clickableIDs > 0 do
		local clickableID = table.remove(clickableIDs, math.random(1, #clickableIDs))
		local clickableData = clickableMap[clickableID]
		if clickableData[TYPE] == "WORD" and clickableData[LIKENESS] ~= wordLength and not clickableData[REMOVED] then
			return clickableData
		end
	end
	return false
end

local function selectClickable(cursorX, cursorY, wordLength, attempts)
	local posData = map[coordToPos[tostring(cursorX)..":"..tostring(cursorY)]]
	if posData[CLICKABLE_ID] then
		local clickableData = clickableMap[posData[CLICKABLE_ID]]
		if clickableData[TYPE] == "WORD" then
			if clickableData[LIKENESS] == wordLength then
				-- success
				return false, attempts
			else
				drawOutput(clickableData[WORD])
				if clickableData[REMOVED] == true then
					drawOutput("Error", true)
				else
					drawOutput("Entry denied.", true)
					drawOutput("LIKENESS="..tostring(clickableData[LIKENESS]), true)
					attempts = attempts - 1
				end
			end
		elseif clickableData[TYPE] == "HACK" then
			posData[CLICKABLE_ID] = false
			drawOutput(clickableData[WORD])
			if clickableData[HACK_TYPE] == "REMOVE" then
				drawOutput("Dud removed.", true)
				local wordData = findWord(wordLength)
				if wordData then
					wordData[REMOVED] = true
					wordData[WORD] = string.rep(".", wordData[END_POS] - wordData[START_POS] + 1)
				end
				for pos = wordData[START_POS], wordData[END_POS] do
					local wordPos = map[pos]
					wordPos[CHAR] = "."
					draw(hackerWindow, wordPos[X_POS], wordPos[Y_POS], colours.black, terminalColour, ".")
				end
			elseif clickableData[HACK_TYPE] == "RESET" then
				drawOutput("Tries reset.", true)
				attempts = 4
			end
		end
	else
		drawOutput(posData[CHAR])
		drawOutput("Error", true)
	end
	drawOutput("", true)
	return attempts > 0, attempts
end

local function drawAttempts(attempts)
	headerWindow.setCursorPos(1, 4)
	draw(headerWindow, 1, 4, colours.black, terminalColour, tostring(attempts))
	for i = 1, 4 do
		draw(headerWindow, 18 + 2*i, 4, (i <= attempts and terminalColour) or colours.black, colours.black, " ")
	end
end

--===== INITIALISATION =====--
local eventKey = {}
local function setupMaps()
	local width, height = hackerWindow.getSize()
	map, coordToPos, clickableMap, clickCatcher = buildMaps(width, height, wordLength)
end

local function drawHeader()
	local prevTerm = term.redirect(headerWindow)
	textutils.slowPrint("ROBCO INDUSTRIES (TM) TERMLINK PROTOCOL", 20)
	textutils.slowPrint("ENTER PASSWORD NOW", 20)
	term.redirect(prevTerm)
	headerWindow.setCursorPos(3, 4)
	headerWindow.write("ATTEMPT(S) LEFT:")
	headerDrawn = true
	os.queueEvent("header_drawn")
end

parallel.waitForAll(setupMaps, drawHeader)

--===== MAIN LOOP =====--
local cursorX, cursorY = 1, 1
highlightClickable(cursorX, cursorY)
local running, attempts = true, 4
drawAttempts(attempts)
outputWindow.setCursorBlink(true)
while running do
	local event = {os.pullEventRaw()}
	if event[1] == "key" then
		local key = event[2]
		local delta = directions[key]
		if delta then
			dehighlightClickable(cursorX, cursorY)
			cursorX, cursorY = findCoords(cursorX, cursorY, delta[1], delta[2])
			highlightClickable(cursorX, cursorY)
		elseif key == keys.enter then
			dehighlightClickable(cursorX, cursorY)
			running, attempts = selectClickable(cursorX, cursorY, wordLength, attempts)
			drawAttempts(attempts)
			highlightClickable(cursorX, cursorY)
		elseif key == keys.backspace then
			break
		end
	elseif event[1] == "mouse_click" then
		local xPos, yPos = event[3], event[4] - 5
		local pos = clickCatcher[tostring(xPos)..":"..tostring(yPos)]
		if pos then
			dehighlightClickable(cursorX, cursorY)
			cursorX, cursorY = unpack(pos)
			running, attempts = selectClickable(cursorX, cursorY, wordLength, attempts)
			drawAttempts(attempts)
			highlightClickable(cursorX, cursorY)
		end
	elseif event[1] == "terminate" and canTerminate then
		break
	end
end

term.setBackgroundColour(colours.black)
term.setTextColour(terminalColour)
term.clear()

local width, height = term.getSize()
term.setCursorPos(1, height)
if attempts > 0 then
	textutils.slowWrite("> PASSWORD ACCEPTED.")
	sleep(1)
else
	textutils.slowWrite("> TERMINAL LOCKED.")
	term.scroll(1)
	term.setCursorPos(1, height)
	textutils.slowWrite("> PLEASE CONTACT AN ADMINISTRATOR.")
	while true do
		local event = os.pullEventRaw()
		if event == "terminate" and canTerminate then
			break
		end
	end
end

term.setBackgroundColour(colours.black)
term.setTextColour(colours.white)
term.clear()
term.setCursorPos(1, 1)
term.setCursorBlink(false)
shell.run(successScriptPath)

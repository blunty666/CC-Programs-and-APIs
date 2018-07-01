package = "blunty666.nodes"

class = "WindowBuffer"

local string_sub = string.sub
local string_rep = string.rep
local string_gsub = string.gsub
local string_find = string.find
local table_concat = table.concat
local table_insert = table.insert

local nullChar = "\000"
local nullPattern = "[^\000]+"

local HEX_COLOUR = {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a", "b", "c", "d", "e", "f"}
local CCC_TO_HEX = {}
local HEX_TO_CCC = {}
for i = 1, 16 do
	CCC_TO_HEX[2^(i-1)] = HEX_COLOUR[i]
	HEX_TO_CCC[HEX_COLOUR[i]] = 2^(i-1)
end

local function new(terminal)

	-- check args

	local terminal = terminal
	local width, height = 0, 0
	
	local updateLines = {}
	local updateCursorX = 1
	local updateCursorY = 1
	local updateCursorBlink = false
	local updateTextColour = CCC_TO_HEX[colours.white]
	local updateBackgroundColour = CCC_TO_HEX[colours.black]
	
	local activeLines = {}
	local activeCursorX = 1
	local activeCursorY = 1
	local activeCursorBlink = false
	local activeTextColour = CCC_TO_HEX[colours.white]
	local activeBackgroundColour = CCC_TO_HEX[colours.black]
	
	local hasUpdates = false
	
	local nullLine
	local emptySpaceLine
	local emptyColourLines = {}
	
	local function updateCursor()
		activeCursorX, activeCursorY, activeCursorBlink = updateCursorX, updateCursorY, updateCursorBlink
		activeTextColour, activeBackgroundColour = updateTextColour, updateBackgroundColour
		terminal.setCursorPos(activeCursorX, activeCursorY)
		terminal.setCursorBlink(activeCursorBlink)
		terminal.setTextColour(HEX_TO_CCC[activeTextColour])
	end
	
	local endX, line, clippedText, clippedTextColour, clippedBackgroundColour
	local clipStartX, clipEndX
	local oldText, oldTextColour, oldBackgroundColour
	local newText, newTextColour, newBackgroundColour
	local oldEndX, oldStartX
	local function updateBlit(text, textColour, backgroundColour, length)
		endX = updateCursorX + length - 1
		if updateCursorY >= 1 and updateCursorY <= height then
			if updateCursorX <= width and endX >= 1 then
				-- Modify line
				line = updateLines[updateCursorY]
				if updateCursorX == 1 and endX == width then
					line[1] = text
					line[2] = textColour
					line[3] = backgroundColour
				else
					if updateCursorX < 1 then
						clipStartX = 1 - updateCursorX + 1
						clipEndX = width - updateCursorX + 1
						clippedText = string_sub(text, clipStartX, clipEndX)
						clippedTextColour = string_sub(textColour, clipStartX, clipEndX)
						clippedBackgroundColour = string_sub(backgroundColour, clipStartX, clipEndX)
					elseif endX > width then
						clipEndX = width - updateCursorX + 1
						clippedText = string_sub(text, 1, clipEndX)
						clippedTextColour = string_sub(textColour, 1, clipEndX)
						clippedBackgroundColour = string_sub(backgroundColour, 1, clipEndX)
					else
						clippedText = text
						clippedTextColour = textColour
						clippedBackgroundColour = backgroundColour
					end

					oldText, oldTextColour, oldBackgroundColour = line[1], line[2], line[3]
					if updateCursorX > 1 then
						oldEndX = updateCursorX - 1
						newText = string_sub(oldText, 1, oldEndX)..clippedText
						newTextColour = string_sub(oldTextColour, 1, oldEndX)..clippedTextColour
						newBackgroundColour = string_sub(oldBackgroundColour, 1, oldEndX)..clippedBackgroundColour
					else
						newText = clippedText
						newTextColour = clippedTextColour
						newBackgroundColour = clippedBackgroundColour
					end
					if endX < width then
						oldStartX = endX + 1
						newText = newText..string_sub(oldText, oldStartX, width)
						newTextColour = newTextColour..string_sub(oldTextColour, oldStartX, width)
						newBackgroundColour = newBackgroundColour..string_sub(oldBackgroundColour, oldStartX, width)
					end

					line[1] = newText
					line[2] = newTextColour
					line[3] = newBackgroundColour
				end
			end
		end

		-- Move and redraw cursor
		updateCursorX = updateCursorX + length
		hasUpdates = true
	end

	local function combineLines(updateLine, activeLine)
		local segments = {}
		local currentX = 1
		local startX, endX = string_find(updateLine, nullPattern, currentX)
		while startX do
			if startX > currentX then
				table_insert(segments, string_sub(activeLine, currentX, startX - 1))
			end
			table_insert(segments, string_sub(updateLine, startX, endX))
			currentX = endX + 1
			startX, endX = string_find(updateLine, nullPattern, currentX)
		end
		if currentX <= width then
			table_insert(segments, string_sub(activeLine, currentX, width))
		end
		return table_concat(segments)
	end
	
	local isLocked = false
	local windowBuffer
	windowBuffer = {
		getSize = function()
			return width, height
		end,
		setSize = function(newWidth, newHeight)
			local newWidth = math.max(0, math.floor(tonumber(newWidth) or width))
			local newHeight = math.max(0, math.floor(tonumber(newHeight) or height))
			if newWidth ~= width or newHeight ~= height then
				nullLine = string_rep(nullChar, newWidth)
				emptySpaceLine = string_rep(" ", newWidth)
				for _, hex in pairs(CCC_TO_HEX) do
					emptyColourLines[hex] = string_rep(hex, newWidth)
				end
				
				if newHeight < height then
					-- remove excess lines
					for yPos = newHeight + 1, height do
						updateLines[yPos] = nil
						activeLines[yPos] = nil
					end
				elseif newHeight > height then
					-- add new lines
					for yPos = height + 1, newHeight do
						updateLines[yPos] = {
							emptySpaceLine,
							emptyColourLines[updateTextColour],
							emptyColourLines[updateBackgroundColour],
						}
						activeLines[yPos] = {
							emptySpaceLine,
							emptyColourLines[updateTextColour],
							emptyColourLines[updateBackgroundColour],
						}
					end
				end
				
				if newWidth < width then
					-- reduce line length for existing lines only
					local updateLine, activeLine
					for yPos = 1, math.min(height, newHeight) do
						updateLine, activeLine = updateLines[yPos], activeLines[yPos]
						updateLines[yPos] = {
							string_sub(updateLine[1], 1, newWidth),
							string_sub(updateLine[2], 1, newWidth),
							string_sub(updateLine[3], 1, newWidth),
						}
						activeLines[yPos] = {
							string_sub(activeLine[1], 1, newWidth),
							string_sub(activeLine[2], 1, newWidth),
							string_sub(activeLine[3], 1, newWidth),
						}
					end
				elseif newWidth > width then
					-- extend line length for existing lines only
					local updateLine, activeLine
					
					local partialEmptySpaceLine = string_rep(" ", newWidth - width)
					local partialEmptyTextColourLine = string_rep(updateTextColour, newWidth - width)
					local partialEmptyBackgroundColourLine = string_rep(updateBackgroundColour, newWidth - width)
					
					for yPos = 1, math.min(height, newHeight) do
						updateLine, activeLine = updateLines[yPos], activeLines[yPos]
						updateLines[yPos] = {
							updateLine[1]..partialEmptySpaceLine,
							updateLine[2]..partialEmptyTextColourLine,
							updateLine[3]..partialEmptyBackgroundColourLine,
						}
						activeLines[yPos] = {
							activeLine[1]..partialEmptySpaceLine,
							activeLine[2]..partialEmptyTextColourLine,
							activeLine[3]..partialEmptyBackgroundColourLine,
						}
					end
				end

				hasUpdates = true				
				width, height = newWidth, newHeight

				return true
			end
			return false
		end,
	
		hasUpdates = function()
			return hasUpdates
		end,
		pushUpdates = function()
			if hasUpdates then
				local currentX = 1
				local startX, endX
				local updateLine, activeLine
				local updateTextLine, updateTextColourLine, updateBackgroundColourLine
				local activeTextLine, activeTextColourLine, activeBackgroundColourLine
				local textSegments, textColourSegments, backgroundColourSegments
				local newText, newTextColour, newBackgroundColour
				for yPos = 1, height do
					updateLine = updateLines[yPos]
					updateTextLine = updateLine[1]
					startX, endX = string_find(updateTextLine, nullPattern, currentX) -- find first modified segment in this update line
					if startX then -- if we have one then proceed to push the updates to active
						activeLine = activeLines[yPos]
						textSegments, textColourSegments, backgroundColourSegments = {}, {}, {}
						updateTextColourLine, updateBackgroundColourLine = updateLine[2], updateLine[3]
						activeTextLine, activeTextColourLine, activeBackgroundColourLine = activeLine[1], activeLine[2], activeLine[3]
						repeat
							if startX > currentX then
								table_insert(textSegments, string_sub(activeTextLine, currentX, startX - 1))
								table_insert(textColourSegments, string_sub(activeTextColourLine, currentX, startX - 1))
								table_insert(backgroundColourSegments, string_sub(activeBackgroundColourLine, currentX, startX - 1))
							end
							
							newText = string_sub(updateTextLine, startX, endX)
							newTextColour = string_sub(updateTextColourLine, startX, endX)
							newBackgroundColour = string_sub(updateBackgroundColourLine, startX, endX)
							
							--push changes to parent
							terminal.setCursorPos(startX, yPos)
							terminal.blit(newText, newTextColour, newBackgroundColour)
							
							table_insert(textSegments, newText)
							table_insert(textColourSegments, newTextColour)
							table_insert(backgroundColourSegments, newBackgroundColour)
							
							currentX = endX + 1
							startX, endX = string_find(updateTextLine, nullPattern, currentX)
						until not startX
						if currentX <= width then
							table_insert(textSegments, string_sub(activeTextLine, currentX, width))
							table_insert(textColourSegments, string_sub(activeTextColourLine, currentX, width))
							table_insert(backgroundColourSegments, string_sub(activeBackgroundColourLine, currentX, width))
						end
						activeLines[yPos] = {
							table_concat(textSegments),
							table_concat(textColourSegments),
							table_concat(backgroundColourSegments),
						}
						updateLines[yPos] = {
							nullLine,
							nullLine,
							nullLine,
						}
						currentX = 1
					end
				end
				updateCursor()
				hasUpdates = false
				return true
			end
			return false
		end,

		getTerminal = function()
			return terminal
		end,
		setTerminal = function(newTerminal)
			terminal = newTerminal
			windowBuffer.setSize(terminal.getSize())
			windowBuffer.redraw()
		end,

		redraw = function()
			local activeLine
			for yPos = 1, height do
				activeLine = activeLines[yPos]
				terminal.setCursorPos(1, yPos)
				terminal.blit(activeLine[1], activeLine[2], activeLine[3])
			end
			updateCursor()
		end,
	}
	
	local windowBufferTerm = {
		write = function(text)
			local textType = type(text)
			if textType == "string" or textType == "number" then
				text = string_gsub(tostring(text), "%c", " ")
				local length = #text
				updateBlit(text, string_rep(updateTextColour, length), string_rep(updateBackgroundColour, length), length)
			end
		end,
		blit = function(text, textColour, backgroundColour)
			if type(text) ~= "string" or type(textColour) ~= "string" or type(backgroundColour) ~= "string" then
				error( "Expected string, string, string", 2 )
			end
			text = string_gsub(tostring(text), "%c", " ")
			local length = #text
			if #textColour ~= length or #backgroundColour ~= length then
				error( "Arguments must be the same length", 2 )
			end
			updateBlit(text, textColour, backgroundColour, length)
		end,
		clear = function()
			local emptyTextColour = emptyColourLines[updateTextColour]
			local emptyBackgroundColour = emptyColourLines[updateBackgroundColour]
			for yPos = 1, height do
				updateLines[yPos] = {
					emptySpaceLine,
					emptyTextColour,
					emptyBackgroundColour,
				}
			end
			hasUpdates = true
		end,
		clearLine = function()
			if updateLines[updateCursorY] then
				updateLines[updateCursorY] = {
					emptySpaceLine,
					emptyColourLines[updateTextColour],
					emptyColourLines[updateBackgroundColour],
				}
				hasUpdates = true
			end
		end,
		getCursorPos = function()
			return updateCursorX, updateCursorY
		end,
		setCursorPos = function(xPos, yPos)
			updateCursorX = math.floor(tonumber(xPos) or updateCursorX)
			updateCursorY = math.floor(tonumber(yPos) or updateCursorY)
			hasUpdates = true
		end,
		setCursorBlink = function(blink)
			if type(blink) == "boolean" then
				updateCursorBlink = blink
				hasUpdates = true
			end
		end,
		isColour = function()
			return true
		end,
		getSize = function()
			return width, height
		end,
		scroll = function(noOfLines)
			local n = math.floor(tonumber(noOfLines) or 0)
			if n ~= 0 and height > 0 then
				local emptyTextColour = emptyColourLines[updateTextColour]
				local emptyBackgroundColour = emptyColourLines[updateBackgroundColour]
				local updateLine, activeLine
				for yPos = (n > 0 and 1) or height, (n < 0 and 1) or height, n/math.abs(n) do
					updateLine = updateLines[yPos + n]
					activeLine = activeLines[yPos + n]
					if updateLine then
						updateLines[yPos] = {
							combineLines(updateLine[1], activeLine[1]),
							combineLines(updateLine[2], activeLine[2]),
							combineLines(updateLine[3], activeLine[3]),
						}
					else
						updateLines[yPos] = {
							emptySpaceLine,
							emptyTextColour,
							emptyBackgroundColour,
						}
					end
				end
				hasUpdates = true
			end
		end,
		setTextColour = function(colour)
			local newColour = CCC_TO_HEX[tonumber(colour)]
			if newColour then
				updateTextColour = newColour
				hasUpdates = true
			end
		end,
		getTextColour = function()
			return HEX_TO_CCC[updateTextColour]
		end,
		setBackgroundColour = function(colour)
			local newColour = CCC_TO_HEX[tonumber(colour)]
			if newColour then
				updateBackgroundColour = newColour
			end
		end,
		getBackgroundColour = function()
			return HEX_TO_CCC[updateBackgroundColour]
		end,
	}
	windowBufferTerm.isColor = windowBufferTerm.isColour
	windowBufferTerm.setTextColor = windowBufferTerm.setTextColour
	windowBufferTerm.getTextColor = windowBufferTerm.getTextColour
	windowBufferTerm.setBackgroundColor = windowBufferTerm.setBackgroundColour
	windowBufferTerm.getBackgroundColor = windowBufferTerm.getBackgroundColour
	
	windowBuffer.term = windowBufferTerm
	
	windowBuffer.setSize(terminal.getSize())
	
	return windowBuffer
	
end

static = {
	methods = {
		new = new,
	},
}

--------------------------------------------------------------------------
-------------------------------- map API ---------------------------------
--------------------------------------------------------------------------
local mapMethods = {
	get = function(self, tVector)
		if self.map[tVector.x] then
			return self.map[tVector.x][tVector.y]
		end
	end,
	set = function(self, tVector, value)
		if not self.map[tVector.x] then
			self.map[tVector.x] = {}
		end
		self.map[tVector.x][tVector.y] = value
		return self.map[tVector.x][tVector.y]
	end,
	getOrSet = function(self, tVector, value)
		if self.map[tVector.x] and self.map[tVector.x][tVector.y] ~= nil then
			return self.map[tVector.x][tVector.y], false
		else
			return self:set(tVector, value), true
		end
	end,
}
local mapMetatable = {__index = mapMethods}

local function newMap()
	return setmetatable({map = {}}, mapMetatable)
end

--------------------------------------------------------------------------
------------------------------- maze API ---------------------------------
--------------------------------------------------------------------------
local WALL_CELL = 1
local FRONTIER_CELL = 2
local PASSAGE_CELL = 3

local function adjacent(cell)
	return {
		cell + vector.new(1, 0, 0),
		cell + vector.new(-1, 0, 0),
		cell + vector.new(0, 1, 0),
		cell + vector.new(0, -1, 0),
	}
end

local function compareFunc(a, b)
	return a[2] < b[2]
end

local function addWalls(maze, frontierQueue, cell)
	for _, adjacentCell in ipairs(adjacent(cell)) do
		local cellValue = maze:get(adjacentCell)
		if cellValue and cellValue == WALL_CELL then
			maze:set(adjacentCell, FRONTIER_CELL)
			table.insert(frontierQueue, {adjacentCell, math.random()})
			table.sort(frontierQueue, compareFunc)
		end
	end
end

local function findOpposite(maze, wallCell)
	for _, adjacentCell in ipairs(adjacent(wallCell)) do
		local cellValue = maze:get(adjacentCell)
		if cellValue and cellValue == PASSAGE_CELL then
			return wallCell + (wallCell - adjacentCell)
		end
	end
end

local function newMaze(width, height)
	local mazeWidth, mazeHeight = 2*math.ceil(width/2) - 1, 2*math.ceil(height/2) - 1
	
	local maze = newMap()
	for xPos = 1, mazeWidth do
		for yPos = 1, mazeHeight do
			maze:set(vector.new(xPos, yPos, 0), WALL_CELL)
		end
	end
	
	local startX = math.random(1, (mazeWidth - 1)/2)*2
	local startY = math.random(1, (mazeHeight - 1)/2)*2
	local start = vector.new(startX, startY, 0)
	maze:set(start, PASSAGE_CELL)
	
	local frontierQueue = {}
	addWalls(maze, frontierQueue, start)
	
	while #frontierQueue > 0 do
		local frontierCell = table.remove(frontierQueue, 1)[1]
		local oppositeCell = findOpposite(maze, frontierCell)
		local oppositeValue = maze:get(oppositeCell)
		if oppositeValue and oppositeValue == WALL_CELL then
			maze:set(frontierCell, PASSAGE_CELL)
			maze:set(oppositeCell, PASSAGE_CELL)
			addWalls(maze, frontierQueue, oppositeCell)
		end
	end
	
	return maze
end

--------------------------------------------------------------------------
--------------------------- helper functions -----------------------------
--------------------------------------------------------------------------
local termWidth, termHeight = term.getSize()
local function drawMaze(maze)
	--clear the screen first
	term.setBackgroundColour(colours.black)
	term.clear()
	--draw in the maze passages
	term.setBackgroundColour(colours.white)
	for xPos = 1, termWidth do
		for yPos = 1, termHeight do
			if maze:get(vector.new(xPos, yPos, 0)) == PASSAGE_CELL then
				term.setCursorPos(xPos, yPos)
				term.write(" ")
			end
		end
	end
end

local function checkMove(maze, currPos, direction)
	if maze:get(currPos + direction) == PASSAGE_CELL then
		term.setCursorPos(currPos.x, currPos.y)
		term.write(" ")
		return currPos + direction
	end
	return currPos
end

--------------------------------------------------------------------------
---------------------------- main game loop ------------------------------
--------------------------------------------------------------------------
term.setTextColour(colours.white) --just in case

--===== START SCREEN =====--

--draw a maze in the background
local maze = newMaze(termWidth, termHeight)
drawMaze(maze)

--draw the title screen objects
local title = {
	"+-----------------------+",
	"|      Maze Runner      |",
	"|                       |",
	"| Press enter to start! |",
	"+-----------------------+",
}
local success = {
	"+-------------------+",
	"|      Success      |",
	"|                   |",
	"| Time:             |",
	"| Completed:        |",
	"|                   |",
	"|    Press enter    |",
	"|   to play again   |",
	"+-------------------+",
}
local exitBar = {
	"+-------------------+",
	"| Backspace to exit |",
}
term.setBackgroundColour(colours.black)
for i = 1, #title do
	term.setCursorPos(math.ceil((termWidth/2)-(#title[i]/2)), math.floor(termHeight/2) - 3 + i)
	term.write(title[i])
end
for i = 1, #exitBar do
	term.setCursorPos(math.ceil((termWidth/2)-(#exitBar[i]/2)), termHeight - 2 + i)
	term.write(exitBar[i])
end

--wait for user input
local event, startTime, completionTime
while true do
	event = {os.pullEvent("key")}
	if event[2] == keys.enter then
		--continue to game
		break
	elseif event[2] == keys.backspace then
		--exit to shell
		term.setCursorPos(1, 1)
		term.clear()
		return
	end
end

--===== RUN GAME =====--
local mazesCompleted = 0
local exit = false
while not exit do

	term.setTextColour(colours.black)

	--calculate maze side, must be odd number
	termWidth, termHeight = term.getSize()
	local mazeWidth, mazeHeight = 2*math.ceil(termWidth/2) - 1, 2*math.ceil(termHeight/2) - 1

	--create the maze
	local maze = newMaze(mazeWidth, mazeHeight)

	--add the start cell to the maze
	local currPos = vector.new(2, 1, 0)
	maze:set(currPos, PASSAGE_CELL)

	--add the exit to the maze
	local goal = vector.new(mazeWidth - 1, mazeHeight, 0)
	maze:set(goal, PASSAGE_CELL)
	if termHeight > mazeHeight then --some trickery involved when height is an even number
		-- extend the exit one more cell downwards
		goal = vector.new(mazeWidth - 1, termHeight, 0)
		maze:set(goal, PASSAGE_CELL)
	end

	--draw the maze
	drawMaze(maze)
	
	local icon = "v"
	startTime = os.clock()
	while not exit do
	
		-- draw the current player position
		term.setCursorPos(currPos.x, currPos.y)
		term.write(icon)
		
		-- if at the exit the continue to success screen
		if currPos.x == goal.x and currPos.y == goal.y then
			mazesCompleted = mazesCompleted + 1
			break
		end
		
		--wait for player input
		event = {os.pullEvent("key")}
		if event[2] == keys.up then
			icon = "^"
			currPos = checkMove(maze, currPos, vector.new(0, -1, 0))
		elseif event[2] == keys.down then
			icon = "v"
			currPos = checkMove(maze, currPos, vector.new(0, 1, 0))
		elseif event[2] == keys.left then
			icon = "<"
			currPos = checkMove(maze, currPos, vector.new(-1, 0, 0))
		elseif event[2] == keys.right then
			icon = ">"
			currPos = checkMove(maze, currPos, vector.new(1, 0, 0))
		elseif event[2] == keys.enter then
			break
		elseif event[2] == keys.backspace then
			exit = true
		end
	end
	completionTime = os.clock() - startTime
	
	
	--===== SUCCESS SCREEN =====--
	--clear the screen
	term.setBackgroundColour(colours.black)
	term.setTextColour(colours.white)
	term.clear()
	
	--draw the base success screen
	for i = 1, #success do
		term.setCursorPos(math.ceil((termWidth/2)-(#success[i]/2)), math.floor(termHeight/2) - 6 + i)
		term.write(success[i])
	end
	
	--add the time taken to the success screen
	completionTime = math.floor(completionTime*100)/100
	term.setCursorPos(math.ceil((termWidth/2)+(#success[1]/2)) - string.len(completionTime) - 2, math.floor(termHeight/2) - 2)
	term.write(completionTime)
	
	--add the total number of completed mazes to the screen
	term.setCursorPos(math.ceil((termWidth/2)+(#success[1]/2)) - string.len(mazesCompleted) - 2, math.floor(termHeight/2) - 1)
	term.write(mazesCompleted)
	
	--draw the exit bar
	for i = 1, #exitBar do
		term.setCursorPos(math.ceil((termWidth/2)-(#exitBar[i]/2)), termHeight - 2 + i)
		term.write(exitBar[i])
	end
	
	--wait for player input
	while not exit do
		event = {os.pullEvent("key")}
		if event[2] == keys.enter then
			break
		elseif event[2] == keys.backspace then
			exit = true
		end
	end
end

term.setBackgroundColour(colours.black)
term.clear()
term.setCursorPos(1, 1)

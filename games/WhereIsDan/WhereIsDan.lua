local BOX = {
	WIDTH = 20,
	HEIGHT = 9,
}

local BUTTON = {
	WIDTH = 18,
}

local TIMEOUT = 300 -- cache quotes for 5 minutes

local URL = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/games/WhereIsDan/quotes.lua"

local WIDTH, HEIGHT = term.getSize()
local CENTER_X, CENTER_Y = math.ceil(WIDTH/2), math.ceil(HEIGHT/2)

do
	local DELTA_X, DELTA_Y = math.floor(BOX.WIDTH/2), math.floor(BOX.HEIGHT/2)
	
	BOX.X_MIN = CENTER_X - DELTA_X
	BOX.X_MAX = BOX.X_MIN + BOX.WIDTH - 1
	
	BOX.Y_MIN = CENTER_Y - DELTA_Y
	BOX.Y_MAX = BOX.Y_MIN + BOX.HEIGHT - 1

	BOX.BUTTON_TEXT = {
		X = CENTER_X,
		Y = BOX.Y_MIN + 2,
	}

	BOX.BUTTON = {
		X_MIN = CENTER_X - math.floor(BUTTON.WIDTH/2),
		X_MAX = CENTER_X - math.floor(BUTTON.WIDTH/2) + BUTTON.WIDTH - 1,

		Y_MIN = BOX.Y_MIN + 1,
		Y_MAX = BOX.Y_MIN + 3,
	}

	BOX.TEXT = {
		X = CENTER_X,
		Y = BOX.Y_MIN + 5,
	}
end

local CHANGE_PROBABILITY = 0.15

local particles = {}

local function randomColour()
	return 2^(math.random(0, 14))
end

local directions = {
	[0] = vector.new(0, -1, 0),
	[1] = vector.new(1, 0, 0),
	[2] = vector.new(0, 1, 0),
	[3] = vector.new(-1, 0, 0),
}

local function newParticle(x, y, colour, directionIndex)
	return {
		position = vector.new(x, y, 0),
		colour = colour,
		directionIndex = directionIndex,
		direction = directions[directionIndex],
		distanceTravelled = 0,
	}
end

local function isInTerm(x, y)
	return 1 <= x and x <= WIDTH and 1 <= y and y <= HEIGHT
end

local function shouldChangeDirection(particle)
	return math.random() < CHANGE_PROBABILITY
end

local function shouldDraw(particle)
	local x, y = particle.position.x, particle.position.y
	return not (BOX.X_MIN <= x and x <= BOX.X_MAX and BOX.Y_MIN <= y and y <= BOX.Y_MAX)
end

local function draw(particle)
	term.setCursorPos(particle.position.x, particle.position.y)
	term.setBackgroundColour(particle.colour)
	term.write(" ")
end

local function updateParticles()
	while true do
		for _, particle in ipairs(particles) do
			local nextPosition = particle.position + particle.direction
			if not isInTerm(nextPosition.x, nextPosition.y) or shouldChangeDirection(particle) then

				local directionDelta = (math.random() > 0.5 and 1) or -1
				local newDirectionIndex, newDirection = particle.directionIndex, nil
				repeat
					newDirectionIndex = (newDirectionIndex + directionDelta) % 4
					newDirection = directions[newDirectionIndex]
					nextPosition = particle.position + newDirection
				until isInTerm(nextPosition.x, nextPosition.y)
				
				-- update direction
				particle.directionIndex = newDirectionIndex
				particle.direction = newDirection

				-- reset distanceTravelled
				particle.distanceTravelled = 0
			end

			-- move particle
			particle.position = nextPosition

			-- increase distanceTravelled
			particle.distanceTravelled = particle.distanceTravelled + 1

			-- check if should draw particle and draw
			if shouldDraw(particle) then
				draw(particle)
			end
		end
		sleep(0.05)
	end
end

local function writeText(xPos, yPos, text, bgCol, textCol)
	if bgCol then term.setBackgroundColour(bgCol) end
	if textCol then term.setTextColour(textCol) end
	term.setCursorPos(xPos, yPos)
	term.write(text)
end

local function writeTextAligned(text, xPos, yPos, bgCol, textCol)
	local startX = xPos - math.ceil(#text/2)
	writeText(startX, yPos, text, bgCol, textCol)
end

local function drawButton(colour)
	paintutils.drawFilledBox(BOX.BUTTON.X_MIN, BOX.BUTTON.Y_MIN, BOX.BUTTON.X_MAX, BOX.BUTTON.Y_MAX, colour)
	writeTextAligned("WHERE IS DAN?", BOX.BUTTON_TEXT.X, BOX.BUTTON_TEXT.Y, colour, colours.white)
end

local function searchBarTimer()
	return math.random() / 4
end

local function handleEvents()
	local quotes = {
	}
	local requested = false
	local cachedTime = -(math.huge)

	local clicked = false

	local updateTimer = false
	local counter = 1

	local event = {os.pullEventRaw()}
	while true do
		if event[1] == "terminate" or (event[1] == "char" and string.lower(event[2]) == "q") then
			break
		elseif event[1] == "mouse_click" then
			if event[2] == 1 and (BOX.BUTTON.X_MIN <= event[3] and event[3] <= BOX.BUTTON.X_MAX) and (BOX.BUTTON.Y_MIN <= event[4] and event[4] <= BOX.BUTTON.Y_MAX) then
				clicked = true
				drawButton(colours.red)
			end
		elseif event[1] == "mouse_up" then
			if clicked then
				drawButton(colours.green)
				if os.clock() - cachedTime > TIMEOUT then
					if not requested then
						http.request(URL)
						requested = true
					end
				end
				if not updateTimer then
					updateTimer = os.startTimer(searchBarTimer())
					writeText(BOX.X_MIN, BOX.TEXT.Y, string.rep(" ", BOX.WIDTH), colours.black)
					writeTextAligned("Searching for Dan...", BOX.TEXT.X, BOX.TEXT.Y + 1, colours.black, colours.white)
				end
				clicked = false
			end
		elseif event[1] == "http_success" and event[2] == URL then

			quotes = textutils.unserialise(event[3].readAll())
			requested = false
			cachedTime = os.clock()
		
		elseif event[1] == "timer" then
			if event[2] == updateTimer then
				if counter <= BOX.WIDTH - 2 then
					writeText(BOX.X_MIN + 1, BOX.TEXT.Y, string.rep(" ", counter), colours.cyan)
					updateTimer = os.startTimer(searchBarTimer())
					counter = counter + 1
				else
					writeText(BOX.X_MIN, BOX.TEXT.Y, string.rep(" ", BOX.WIDTH), colours.black)
					writeText(BOX.X_MIN, BOX.TEXT.Y + 1, string.rep(" ", BOX.WIDTH), colours.black)
					writeTextAligned(quotes[math.random(1, #quotes)], BOX.TEXT.X, BOX.TEXT.Y, colours.black, colours.white)
					updateTimer = false
					counter = 1
				end
			end
		end
		event = {os.pullEventRaw()}
	end
end

term.setBackgroundColour(colours.black)
term.clear()

drawButton(colours.green)
writeTextAligned("Press 'q' to Quit", BOX.TEXT.X, BOX.TEXT.Y + 3, colours.black, colours.white)

for i = 1, 25 do
	local x = math.random(1, WIDTH)
	local y = math.random(1, HEIGHT)
	local colour = randomColour()
	local directionIndex = math.random(0, 3)
	table.insert(particles, newParticle(x, y, colour, directionIndex))
end

parallel.waitForAny(handleEvents, updateParticles)

term.setBackgroundColour(colours.black)
term.setTextColour(colours.white)
term.setCursorPos(1, 1)
term.clear()

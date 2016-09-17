local function run(func, ...)
	local arguments = {...}

	-- save original versions of functions we are overriding
	local oldOsShutdown, oldCoroutineStatus = os.shutdown, coroutine.status

	local function clearScreen()
		term.redirect(type(term.native) == "function" and term.native() or term.native)
		term.setBackgroundColour(colours.black)
		term.setTextColour(colours.white)
		term.setCursorPos(1, 1)
		term.setCursorBlink(false)
		term.clear()
	end

	local function coroutineStatusOverride()
		return "dead"
	end

	local function osShutdownOverride()
		clearScreen()

		-- reload rednet API as already running
		rednet.close()
		os.unloadAPI("rednet")
		os.loadAPI("/rom/apis/rednet")

		-- replace original functions
		rawset(os, "shutdown", oldOsShutdown)
		rawset(coroutine, "status", oldCoroutineStatus)

		-- run the function provided
		local ok, err = pcall(func, unpack(arguments))

		-- print any errors
		if not ok then
			pcall(
				function()
					clearScreen()
					printError(err)
					print("Press any key to continue")
					os.pullEvent("key")
				end
			)
		end

		os.shutdown()
	end

	-- override functions with modified version
	rawset(os, "shutdown", osShutdownOverride)
	rawset(coroutine, "status", coroutineStatusOverride)

	-- start the override process
	coroutine.yield()	
end

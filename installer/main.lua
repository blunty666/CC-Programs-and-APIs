local rootURL = "https://raw.githubusercontent.com"
local fileListRepoUrl = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/installer/file_list/"

local function get(url)
	local response = http.get(url)			
	if response then
		local fileData = response.readAll()
		response.close()
		return fileData
	end
	return false
end

local function save(fileData, path)
	local handle = fs.open(path, "w")
	if handle then
		handle.write(fileData)
		handle.close()
		return true
	else
		return false
	end
end

local function install(fileList, overwrite, hideDebug)

	local success = true

	for localPath, remotePathDetails in pairs(fileList) do

		table.insert(remotePathDetails, 1, rootURL)
		local url = table.concat(remotePathDetails, "/")
		local path = fs.combine(localPath, "")

		if fs.exists(path) and fs.isDir(path) then
			if not hideDebug then
				printError("Cannot overwrite directory: "..path)
				print("Skipping: ", path, " - ", url)
			end
			success = false
		elseif fs.exists(path) and overwrite == false then
			if not hideDebug then
				printError("Cannot overwrite existing file: "..path)
				print("Skipping: ", path, " - ", url)
			end
		else
			local fileData = get(url)			
			if fileData then
				if save(fileData, path) then
					if not hideDebug then
						print("Download successful: ", path)
					end
				else
					if not hideDebug then
						printError("Save failed: ", path)
						print("Skipping: ", path, " - ", url)
					end
					success = false
				end
			else
				if not hideDebug then
					printError("Download failed: ", url)
					print("Skipping: ", path, " - ", url)
				end
				success = false
			end
		end
	end

	if not hideDebug then
		if success then
			print("All files installed successfully")
		else
			printError("Install failed, some files could not be installed")
		end
	end

	return success
end

local tArgs = {...}

-- check and download file list
local listName = string.lower(tostring(tArgs[1]))
local fileListUrl = fileListRepoUrl..listName
local ok, err = http.checkURL(fileListUrl)
if not ok then
	printError("Invalid package name: "..listName)
	printError("Got error: "..err)
	return
end
local fileList = get(fileListUrl)
if not fileList then
	printError("Unable to download file list")
	return
end
fileList = textutils.unserialise(fileList)
if type(fileList) ~= "table" then
	printError("Invalid file list, unable to proceed")
	return
end

-- check overwrite args
local overwrite = string.lower(tostring(tArgs[2]))
overwrite = overwrite == "true"

-- check debug args
local hideDebug = string.lower(tostring(tArgs[3]))
hideDebug = hideDebug == "true"

install(fileList, overwrite, hideDebug)

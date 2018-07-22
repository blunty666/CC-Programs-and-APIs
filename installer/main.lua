local tArgs = {...}

local PACKAGE_REPO_URL = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/installer/packages/"

local DOWNLOADER_URLS = {
	raw = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/installer/downloaders/raw.lua",
	github = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/installer/downloaders/github.lua",
}

local INSTALLER, downloaders = {}, {}
local success, filesToDownload, foldersToDelete = true, {}, {}

--===== CONFIG =====--
INSTALLER.CONFIG = {
	root = "", --dir:<root dir>
	delete_old = false, -- set by package data
	overwrite = true, --nooverwrite
	debug = false, --debug
}

--===== DEFINE UTILITY FUNCTIONS =====--
local function debug(...)
	if INSTALLER.CONFIG.debug then
		print(...)
	end
end

local function copy(data)
	local copied = {}
	for key, value in pairs(data) do
		copied[key] = value
	end
	return copied
end

INSTALLER.UTILS = {
	debug = debug,
	checkDirectory = function(dir)
		if type(dir) ~= "string" then return false, "expected string, got: "..type(dir) end -- must be string
		local dir = dir:match("^/*(.*)") -- strip leading slashes
		for pos = dir:len(), 1, -1 do
			if dir:sub(pos, pos) ~= "/" then dir = dir:sub(1, pos) break end -- strip trailing slashes
		end
		if dir ~= fs.combine("", dir) then return false, "invalid directory: "..dir end -- check for invalid characters
		return dir
	end,
	get = function(url)
		local response = http.get(url)			
		if response then
			local fileData = response.readAll()
			response.close()
			return fileData
		end
		return false
	end,
	load = function(data, name, ...)
		local env = setmetatable({}, {__index = _G})
		local loaded, err = load(data, name, "t", env)
		if loaded then
			loaded, err = pcall(loaded, ...)
			if loaded then
				return copy(env)
			end
		end
		return false, err
	end,
	getAndLoad = function(url, name, ...)
		local data = INSTALLER.UTILS.get(url)
		if not data then return false, "unable to download file" end
		local loaded, err = INSTALLER.UTILS.load(data, name, ...)
		if not loaded then return false, "unable to load file, got error: "..err end
		return loaded
	end,
}

--===== DOWNLOADING FUNCTIONS =====--
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

local function download(files)
	local success = true
	for localPath, remoteURL in pairs(files) do
		local path = fs.combine(INSTALLER.CONFIG.root, localPath)
		local fileExists = fs.exists(path)
		if fileExists and fs.isDir(path) then
			printError("Cannot save to '"..path.."', cannot overwrite directory")
			success = false
		elseif fileExists and INSTALLER.CONFIG.overwrite == false then
			debug("Skipping '"..path.."', file already exists")
		else
			local fileData = INSTALLER.UTILS.get(remoteURL)			
			if fileData then
				if save(fileData, path) then
					debug("File download successful '"..path.."'")
				else
					printError("Failed to write to '"..path.."'")
					success = false
				end
			else
				printError("Download failed for '"..path.."'")
				success = false
			end
		end
	end
	return success
end

--===== CHECK PACKAGE NAME =====--
if not tArgs[1] then return printError("No package name provided") end
local pack = string.lower(tostring(tArgs[1]))
if pack:len() == 0 then return printError("No package name provided") end
if pack:find("%W") then return printError("Illegal package name provided, got: "..pack) end
print("Installing package '"..pack.."'")

--===== CHECK CONFIG =====--
for index = 2, #tArgs do
	local arg = tArgs[index]
	if arg == "--nooverwrite" then
		INSTALLER.CONFIG.overwrite = false
	elseif arg == "--debug" then
		INSTALLER.CONFIG.debug = true
	elseif arg == "--deleteold" then
		INSTALLER.CONFIG.delete_old = true
	elseif arg:find("^%-%-dir:") then
		local dir = arg:match("^%-%-dir:(.*)")
		local root, err = INSTALLER.UTILS.checkDirectory(dir)
		if not root then printError("Invalid root directory provided '"..dir.."', got error: "..err) end
		INSTALLER.CONFIG.root = root
	end
end

--===== GET APP DATA =====--
local packageData = INSTALLER.UTILS.get(PACKAGE_REPO_URL..pack)
if not packageData then printError("Unable to download package data for: "..pack) return end

--===== CHECK APP DATA
local ok, err = pcall(function() packageData = textutils.unserialise(packageData) end)
if not ok then return printError("Unable to process package data, got error: "..err) end
if type(packageData) ~= "table" then printError("Invalid package data, unable to proceed") return end

if packageData.root ~= nil then
	local root, err = INSTALLER.UTILS.checkDirectory(packageData.root)
	if not root then printError("Invalid package data root directory, unable to proceed, got error: "..err) return end
	packageData.root = root
else
	packageData.root = ""
end

if (INSTALLER.CONFIG.delete_old == true or packageData.delete_old == true) and fs.combine(INSTALLER.CONFIG.root, packageData.root) ~= "" then
	INSTALLER.CONFIG.delete_old = true
	table.insert(foldersToDelete, fs.combine(INSTALLER.CONFIG.root, packageData.root))
else
	INSTALLER.CONFIG.delete_old = false
end

--===== GET APP FILES =====--
local function getDownloader(downloaderType)
	local loaded, err = INSTALLER.UTILS.getAndLoad(DOWNLOADER_URLS[downloaderType], downloaderType, INSTALLER)
	if loaded then
		if type(loaded.check) == "function" and type(loaded.list) == "function" then
			downloaders[downloaderType] = loaded
			return loaded
		else
			printError("Unable to add downloader '"..downloaderType.."', missing required functions")
		end
	else
		printError("Unable to load downloader '"..downloaderType.."', got error: "..err)
	end
	return false
end

for index, downloadData in ipairs(packageData) do
	if type(downloadData) == "table" then
		local downloadType = downloadData.type
		if DOWNLOADER_URLS[downloadType] then
			local downloader = downloaders[downloadType] or getDownloader(downloadType)
			if downloader then
				local ok, err = downloader.check(downloadData)
				if ok then
					local currentSuccess, currentFiles, currentFolders = downloader.list(packageData.root, downloadData)
					success = currentSuccess and success
					for path, url in pairs(currentFiles) do
						if filesToDownload[path] then
							printError("Duplicate file path '"..path.."'")
							success = false
						else
							filesToDownload[path] = url
						end
					end
				else
					printError("Invalid downloadData, got error: "..err)
					success = false
				end
			end
		else
			printError("Invalid download type at index - "..tostring(index)..", got type:"..tostring(downloadType))
			success = false
		end
	else
		printError("Invalid download data at index: "..tostring(index))
		success = false
	end
end

--===== DELETE OLD FILES =====--
-- TODO

--===== DOWNLOAD FILES =====--
success = download(filesToDownload) and success
if success then
	print("All files installed successfully")
else
	printError("Install failed, some files could not be installed")
end

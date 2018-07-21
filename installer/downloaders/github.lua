--===== GITHUB DOWNLOADER =====--
local INSTALLER = (...)

local JSON_URL = "https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/utils/json.lua"
local GITHUB_API_URL = "https://api.github.com"
local GITHUB_RAW_URL = "https://raw.githubusercontent.com"

if not INSTALLER.UTILS.JSON then
	local loaded, err = INSTALLER.UTILS.getAndLoad(JSON_URL, "json.lua")
	if not loaded then error("unable to fetch json library, got error: "..err) end
	INSTALLER.UTILS.JSON = loaded
end

local function getFileList(author, repository, branch, directory)

	local success = true
	local rootDirectory = directory
	local directories, files = {}, {}
	table.insert(directories, rootDirectory)

	while #directories > 0 do
		local directory = table.remove(directories, #directories)
		local response = INSTALLER.UTILS.get(GITHUB_API_URL.."/repos/"..author.."/"..repository.."/contents/"..directory.."?ref="..branch)
		if response then
			local decoded = INSTALLER.UTILS.JSON.decode(response)
			for _, data in ipairs(decoded) do
				if data.type == "file" then
					local path = data.path
					local fileData = {
						path:sub(path:match(rootDirectory.."/*()")), -- adjusted to rootDirectory
						data.download_url,
						data.name,
					}
					table.insert(files, fileData)
				elseif data.type == "dir" then
					table.insert(directories, data.path)
				end
			end
		else
			printError("could not get response for directory: "..directory)
			success = false
		end
	end
	return success, files
end

function check(downloadData)
	-- check for required args
		-- check for author
		-- check for repository
		-- check for branch
	-- check for optional args
		-- check for repo_directory
		-- check for root
		-- check for directory
		-- check for delete_old
		-- check for whitelist
		-- check for blacklist
	return true
end

function list(root, downloadData)
	local success, gitFiles = getFileList(downloadData.author, downloadData.repository, downloadData.branch, downloadData.repo_directory or "")
	local dir
	if downloadData.root then -- if root is specified in downloadData then overwrite appData root
		dir = downloadData.root
	else -- else use appData root with downloadData directory if it exists
		dir = fs.combine(root, downloadData.directory or "")
	end
	local files = {}
	for _, fileData in ipairs(gitFiles) do
		-- check fileData[3] against blacklist then whitelist
		local shouldDownload = true
		if downloadData.whitelist then
			shouldDownload = false
			local fileName = fileData[3]
			for _, extension in ipairs(downloadData.whitelist) do
				if fileData[3]:match(extension.."$") then
					shouldDownload = true
				end
			end
		elseif downloadData.blacklist then
			local fileName = fileData[3]
			for _, extension in ipairs(downloadData.blacklist) do
				if fileData[3]:match(extension.."$") then
					shouldDownload = false
				end
			end
		end
		if shouldDownload then
			local path = fs.combine(dir, fileData[1])
			files[path] = fileData[2]
		end
	end
	return success, files, {}
end

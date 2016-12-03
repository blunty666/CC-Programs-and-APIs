local rootURL = "https://raw.githubusercontent.com"

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

local function install(fileList, noOverwrite, noDebug)

	local success = true

	for localPath, remotePathDetails in pairs(fileList) do

		table.insert(remotePathDetails, 1, rootURL)
		local url = table.concat(remotePathDetails, "/")
		local path = fs.combine(localPath, "")

		if fs.exists(path) and fs.isDir(path) then
			if not noDebug then
				printError("Cannot overwrite directory: "..path)
				print("Skipping: ", path, " - ", url)
			end
			success = false
		elseif fs.exists(path) and noOverwrite == true then
			if not noDebug then
				printError("Cannot overwrite existing file: "..path)
				print("Skipping: ", path, " - ", url)
			end
		else
			local fileData = get(url)			
			if fileData then
				if save(fileData, path) then
					if not noDebug then
						print("Download successful: ", path)
					end
				else
					if not noDebug then
						printError("Save failed: ", path)
						print("Skipping: ", path, " - ", url)
					end
					success = false
				end
			else
				if not noDebug then
					printError("Download failed: ", url)
					print("Skipping: ", path, " - ", url)
				end
				success = false
			end
		end
	end

	if not noDebug then
		if success then
			print("All files installed successfully")
		else
			printError("Install failed, some files could not be installed")
		end
	end

	return success
end

return install

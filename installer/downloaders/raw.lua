--===== RAW DOWNLOADER =====--
local INSTALLER = (...)

local function check(downloadData)
	-- check for required args
		-- check for url
		-- check for name
	-- check for optional args
		-- check for root
		-- check for directory
		-- check for delete_old
	return true
end

local function list(root, downloadData)
	local dir
	if downloadData.root then -- if root is specified in downloadData then overwrite packageData root
		dir = downloadData.root
	else -- else use packageData root with downloadData directory if it exists
		dir = fs.combine(root, downloadData.directory or "")
	end
	local path = fs.combine(dir, downloadData.name)
	return true, {[path] = downloadData.url}, {}
end

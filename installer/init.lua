local tArgs, installer, err = {...}, nil, nil
local response = http.get("https://raw.githubusercontent.com/blunty666/CC-Programs-and-APIs/master/installer/main.lua")			
if response then installer = response.readAll() response.close() else printError("Failed to download installer script") return end
installer, err = load(installer, "githubInstaller", "t", _G)
if not installer then printError("Error loading installer script: "..err) return end
installer, err = pcall(installer, unpack(tArgs))
if not installer then printError(err) end

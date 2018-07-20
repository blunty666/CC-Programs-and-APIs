local ALOOF_PATH = "rom/aloof"
local PROGRAM_PATH = fs.getDir(shell.getRunningProgram())
local pathList = {
	fs.combine(ALOOF_PATH, "repo/blunty666/log"),
	fs.combine(ALOOF_PATH, "repo/blunty666/nodes"),
	fs.combine(PROGRAM_PATH, "aloof_classes"),
}
local paths = table.concat(pathList, ";")
shell.run(fs.combine(ALOOF_PATH, "run.lua"), paths, "blunty666.nodes_demo.Main")

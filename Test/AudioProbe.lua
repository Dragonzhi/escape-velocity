-- [ts]: AudioProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local App = ____Dora.App -- 2
local Content = ____Dora.Content -- 2
local Path = ____Dora.Path -- 2
local threadLoop = ____Dora.threadLoop -- 2
local root = Path(Content.writablePath, "escape-velocity") -- 3
do -- 3
	local i = 0 -- 4
	while i < #Content.searchPaths do -- 4
		local p = Content.searchPaths[i + 1] -- 5
		if Content:exist(Path(p, "game", "Sound.lua")) and Content:exist(Path(p, "init.lua")) then -- 5
			root = p -- 6
			break -- 6
		end -- 6
		i = i + 1 -- 4
	end -- 4
end -- 4
Content:addSearchPath(root) -- 8
local Sound = require("game.Sound") -- 9
local marker = Path(root, ".agent", "test-results", "audio-probe.txt") -- 10
local lines = {"phase=running"} -- 11
Content:save( -- 12
	marker, -- 12
	table.concat(lines, "\n") -- 12
) -- 12
Sound.startBackgroundMusic() -- 13
local elapsed = 0 -- 14
local stage = 0 -- 14
local failed = false -- 14
threadLoop(function() -- 15
	elapsed = elapsed + App.deltaTime -- 16
	local deadlines = {1, 30, 176} -- 17
	if elapsed < deadlines[stage + 1] then -- 17
		return false -- 18
	end -- 18
	local state = Sound.backgroundMusicState() -- 19
	lines[#lines + 1] = (("t=" .. __TS__NumberToFixed(elapsed, 2)) .. " ") .. state -- 20
	if state ~= "playing=true loop=true volume=0.5 starts=1" then -- 20
		failed = true -- 21
	end -- 21
	if stage == 0 then -- 21
		Sound.startBackgroundMusic() -- 22
		Sound.startBackgroundMusic() -- 22
	end -- 22
	stage = stage + 1 -- 23
	if stage < #deadlines then -- 23
		Content:save( -- 24
			marker, -- 24
			table.concat(lines, "\n") -- 24
		) -- 24
		return false -- 24
	end -- 24
	lines[#lines + 1] = "RESULT=" .. (failed and "FAIL" or "PASS") -- 25
	lines[#lines + 1] = "phase=done" -- 25
	Content:save( -- 26
		marker, -- 26
		table.concat(lines, "\n") -- 26
	) -- 26
	return true -- 26
end) -- 15
return ____exports -- 15
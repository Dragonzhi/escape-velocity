-- [ts]: WebFeasibility.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 6
local Content = ____Dora.Content -- 6
local Path = ____Dora.Path -- 6
local lines = {} -- 8
lines[#lines + 1] = "=== Content.searchPaths ===" -- 10
do -- 10
	local i = 0 -- 11
	while i < #Content.searchPaths do -- 11
		lines[#lines + 1] = (("  [" .. tostring(i)) .. "] ") .. Content.searchPaths[i + 1] -- 12
		i = i + 1 -- 11
	end -- 11
end -- 11
lines[#lines + 1] = "writablePath = " .. Content.writablePath -- 14
local engineScript = Content.searchPaths[2] -- 17
local engineRoot = Path(engineScript, "..") -- 18
lines[#lines + 1] = "engineRoot = " .. engineRoot -- 19
local probes = { -- 21
	Path(engineRoot, "Tools"), -- 22
	Path(engineRoot, "Tools/build-scripts"), -- 23
	Path(engineRoot, "Tools/build-scripts/build_web.sh"), -- 24
	Path(engineRoot, "Projects"), -- 25
	Path(engineRoot, "Projects/Web/toolchain.env"), -- 26
	Path(engineRoot, "Source"), -- 27
	Path(engineRoot, "xmake.lua"), -- 28
	Path(engineRoot, "CMakeLists.txt") -- 29
} -- 29
lines[#lines + 1] = "=== engine-root probes ===" -- 32
for ____, p in ipairs(probes) do -- 33
	do -- 33
		local function ____catch(err) -- 33
			lines[#lines + 1] = ("  " .. p) .. " -> exception" -- 39
		end -- 39
		local ____try, ____hasReturned = pcall(function() -- 39
			local e = Content:exist(p) -- 35
			local ____e_0 -- 36
			if e then -- 36
				____e_0 = Content:isdir(p) -- 36
			else -- 36
				____e_0 = false -- 36
			end -- 36
			local d = ____e_0 -- 36
			lines[#lines + 1] = (((("  " .. p) .. " -> exist=") .. tostring(e)) .. " isdir=") .. tostring(d) -- 37
		end) -- 37
		if not ____try then -- 37
			____catch(____hasReturned) -- 37
		end -- 37
	end -- 37
end -- 37
lines[#lines + 1] = "=== engine-root listing ===" -- 43
do -- 43
	local function ____catch(err) -- 43
		lines[#lines + 1] = "  <listing failed>" -- 49
	end -- 49
	local ____try, ____hasReturned = pcall(function() -- 49
		for ____, name in ipairs(Content:getFiles(engineRoot)) do -- 45
			lines[#lines + 1] = "  " .. name -- 46
		end -- 46
	end) -- 46
	if not ____try then -- 46
		____catch(____hasReturned) -- 46
	end -- 46
end -- 46
local out = Path(Content.searchPaths[1], ".agent", "test-results", "s0-webprobe.txt") -- 52
Content:save( -- 53
	out, -- 53
	table.concat(lines, "\n") -- 53
) -- 53
return ____exports -- 53
-- [ts]: SolarHubTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____SolarHub = require("game.SolarHub") -- 4
local HUB_STATIONS = ____SolarHub.HUB_STATIONS -- 5
local LEVEL_TO_STATION_INDEX = ____SolarHub.LEVEL_TO_STATION_INDEX -- 6
local formatRocketsString = ____SolarHub.formatRocketsString -- 7
local ____LevelData = require("game.LevelData") -- 9
local getLevel = ____LevelData.getLevel -- 9
local levelCount = ____LevelData.levelCount -- 9
local failures = {} -- 16
local checks = 0 -- 17
local function check(name, ok, detail) -- 19
	checks = checks + 1 -- 20
	if not ok then -- 20
		failures[#failures + 1] = {name = name, detail = detail} -- 21
	end -- 21
end -- 19
local function testFormatRockets() -- 24
	check( -- 25
		"rockets-0", -- 25
		formatRocketsString(0) == "☆  ☆  ☆", -- 25
		"0 枚火箭显示错误" -- 25
	) -- 25
	check( -- 26
		"rockets-1", -- 26
		formatRocketsString(1) == "★  ☆  ☆", -- 26
		"1 枚火箭显示错误" -- 26
	) -- 26
	check( -- 27
		"rockets-2", -- 27
		formatRocketsString(2) == "★  ★  ☆", -- 27
		"2 枚火箭显示错误" -- 27
	) -- 27
	check( -- 28
		"rockets-3", -- 28
		formatRocketsString(3) == "★  ★  ★", -- 28
		"3 枚火箭显示错误" -- 28
	) -- 28
	check( -- 29
		"rockets-clamp-neg", -- 29
		formatRocketsString(-1) == "☆  ☆  ☆", -- 29
		"负数火箭显示错误" -- 29
	) -- 29
	check( -- 30
		"rockets-clamp-over", -- 30
		formatRocketsString(5) == "★  ★  ★", -- 30
		"超出火箭显示错误" -- 30
	) -- 30
end -- 24
local function testStationMappings() -- 33
	local count = levelCount() -- 34
	check("mission-count-match", #LEVEL_TO_STATION_INDEX == count, "映射关卡数量与 levelCount 不一致") -- 35
	do -- 35
		local i = 0 -- 37
		while i < count do -- 37
			local stIndex = LEVEL_TO_STATION_INDEX[i + 1] -- 38
			check( -- 39
				("lv" .. tostring(i + 1)) .. "-station-index-valid", -- 39
				stIndex >= 0 and stIndex < #HUB_STATIONS, -- 39
				("stIndex=" .. tostring(stIndex)) .. " 越界" -- 39
			) -- 39
			local st = HUB_STATIONS[stIndex + 1] -- 40
			check( -- 41
				("lv" .. tostring(i + 1)) .. "-station-orbit>0", -- 41
				st.orbit > 0, -- 41
				"orbit=" .. tostring(st.orbit) -- 41
			) -- 41
			check( -- 42
				("lv" .. tostring(i + 1)) .. "-station-radius>0", -- 42
				st.radius > 0, -- 42
				"radius=" .. tostring(st.radius) -- 42
			) -- 42
			check( -- 43
				("lv" .. tostring(i + 1)) .. "-station-model-present", -- 43
				#st.model > 0, -- 43
				"模型名称为空" -- 43
			) -- 43
			local def = getLevel(i) -- 45
			check( -- 46
				("lv" .. tostring(i + 1)) .. "-def-exists", -- 46
				def ~= nil, -- 46
				"关卡定义缺失" -- 46
			) -- 46
			if def ~= nil and def.mission ~= nil then -- 46
				check( -- 48
					("lv" .. tostring(i + 1)) .. "-mission-matches", -- 48
					def.mission.id == "L" .. __TS__NumberToFixed(i + 1, 0), -- 48
					"mission.id=" .. def.mission.id -- 48
				) -- 48
			end -- 48
			i = i + 1 -- 37
		end -- 37
	end -- 37
end -- 33
function ____exports.runTests() -- 53
	testFormatRockets() -- 54
	testStationMappings() -- 55
	local lines = {} -- 57
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 58
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 59
	local limit = #failures < 12 and #failures or 12 -- 60
	do -- 60
		local i = 0 -- 61
		while i < limit do -- 61
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 62
			i = i + 1 -- 61
		end -- 61
	end -- 61
	return table.concat(lines, "\n") -- 64
end -- 53
return ____exports -- 53
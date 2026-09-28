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
	check("l2-mariner10-targets-mercury", LEVEL_TO_STATION_INDEX[2] == 0, "水手10号必须锚定在水星 (Station 0)") -- 38
	check("l3-voyager2-targets-neptune", LEVEL_TO_STATION_INDEX[3] == 7, "旅行者2号必须锚定在海王星 (Station 7)") -- 40
	do -- 40
		local i = 0 -- 42
		while i < count do -- 42
			local stIndex = LEVEL_TO_STATION_INDEX[i + 1] -- 43
			if stIndex == -1 then -- 43
				check( -- 45
					("lv" .. tostring(i + 1)) .. "-station-sun-valid", -- 45
					true, -- 45
					"" -- 45
				) -- 45
			else -- 45
				check( -- 47
					("lv" .. tostring(i + 1)) .. "-station-index-valid", -- 47
					stIndex >= 0 and stIndex < #HUB_STATIONS, -- 47
					("stIndex=" .. tostring(stIndex)) .. " 越界" -- 47
				) -- 47
				local st = HUB_STATIONS[stIndex + 1] -- 48
				check( -- 49
					("lv" .. tostring(i + 1)) .. "-station-orbit>0", -- 49
					st.orbit > 0, -- 49
					"orbit=" .. tostring(st.orbit) -- 49
				) -- 49
				check( -- 50
					("lv" .. tostring(i + 1)) .. "-station-radius>0", -- 50
					st.radius > 0, -- 50
					"radius=" .. tostring(st.radius) -- 50
				) -- 50
				check( -- 51
					("lv" .. tostring(i + 1)) .. "-station-model-present", -- 51
					#st.model > 0, -- 51
					"模型名称为空" -- 51
				) -- 51
			end -- 51
			local def = getLevel(i) -- 54
			check( -- 55
				("lv" .. tostring(i + 1)) .. "-def-exists", -- 55
				def ~= nil, -- 55
				"关卡定义缺失" -- 55
			) -- 55
			if def ~= nil and def.mission ~= nil then -- 55
				check( -- 57
					("lv" .. tostring(i + 1)) .. "-mission-matches", -- 57
					def.mission.id == "L" .. __TS__NumberToFixed(i + 1, 0), -- 57
					"mission.id=" .. def.mission.id -- 57
				) -- 57
			end -- 57
			i = i + 1 -- 42
		end -- 42
	end -- 42
end -- 33
function ____exports.runTests() -- 62
	testFormatRockets() -- 63
	testStationMappings() -- 64
	local lines = {} -- 66
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 67
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 68
	local limit = #failures < 12 and #failures or 12 -- 69
	do -- 69
		local i = 0 -- 70
		while i < limit do -- 70
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 71
			i = i + 1 -- 70
		end -- 70
	end -- 70
	return table.concat(lines, "\n") -- 73
end -- 62
return ____exports -- 62
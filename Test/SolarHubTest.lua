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
local installArcadeLevels = ____LevelData.installArcadeLevels -- 9
local levelCount = ____LevelData.levelCount -- 9
local ____Dora = require("Dora") -- 10
local Content = ____Dora.Content -- 10
local json = ____Dora.json -- 10
local failures = {} -- 17
local checks = 0 -- 18
local function check(name, ok, detail) -- 20
	checks = checks + 1 -- 21
	if not ok then -- 21
		failures[#failures + 1] = {name = name, detail = detail} -- 22
	end -- 22
end -- 20
local function testFormatRockets() -- 25
	check( -- 26
		"rockets-0", -- 26
		formatRocketsString(0) == "☆  ☆  ☆", -- 26
		"0 枚火箭显示错误" -- 26
	) -- 26
	check( -- 27
		"rockets-1", -- 27
		formatRocketsString(1) == "★  ☆  ☆", -- 27
		"1 枚火箭显示错误" -- 27
	) -- 27
	check( -- 28
		"rockets-2", -- 28
		formatRocketsString(2) == "★  ★  ☆", -- 28
		"2 枚火箭显示错误" -- 28
	) -- 28
	check( -- 29
		"rockets-3", -- 29
		formatRocketsString(3) == "★  ★  ★", -- 29
		"3 枚火箭显示错误" -- 29
	) -- 29
	check( -- 30
		"rockets-clamp-neg", -- 30
		formatRocketsString(-1) == "☆  ☆  ☆", -- 30
		"负数火箭显示错误" -- 30
	) -- 30
	check( -- 31
		"rockets-clamp-over", -- 31
		formatRocketsString(5) == "★  ★  ★", -- 31
		"超出火箭显示错误" -- 31
	) -- 31
end -- 25
local function testStationMappings() -- 34
	local count = levelCount() -- 35
	check("mission-count-match", #LEVEL_TO_STATION_INDEX == count, "映射关卡数量与 levelCount 不一致") -- 36
	check("l2-mariner10-targets-mercury", LEVEL_TO_STATION_INDEX[2] == 0, "水手10号必须锚定在水星 (Station 0)") -- 39
	check("l3-voyager2-targets-neptune", LEVEL_TO_STATION_INDEX[3] == 7, "旅行者2号必须锚定在海王星 (Station 7)") -- 41
	do -- 41
		local i = 0 -- 43
		while i < count do -- 43
			local stIndex = LEVEL_TO_STATION_INDEX[i + 1] -- 44
			if stIndex == -1 then -- 44
				check( -- 46
					("lv" .. tostring(i + 1)) .. "-station-sun-valid", -- 46
					true, -- 46
					"" -- 46
				) -- 46
			else -- 46
				check( -- 48
					("lv" .. tostring(i + 1)) .. "-station-index-valid", -- 48
					stIndex >= 0 and stIndex < #HUB_STATIONS, -- 48
					("stIndex=" .. tostring(stIndex)) .. " 越界" -- 48
				) -- 48
				local st = HUB_STATIONS[stIndex + 1] -- 49
				check( -- 50
					("lv" .. tostring(i + 1)) .. "-station-orbit>0", -- 50
					st.orbit > 0, -- 50
					"orbit=" .. tostring(st.orbit) -- 50
				) -- 50
				check( -- 51
					("lv" .. tostring(i + 1)) .. "-station-radius>0", -- 51
					st.radius > 0, -- 51
					"radius=" .. tostring(st.radius) -- 51
				) -- 51
				check( -- 52
					("lv" .. tostring(i + 1)) .. "-station-model-present", -- 52
					#st.model > 0, -- 52
					"模型名称为空" -- 52
				) -- 52
			end -- 52
			local def = getLevel(i) -- 55
			check( -- 56
				("lv" .. tostring(i + 1)) .. "-def-exists", -- 56
				def ~= nil, -- 56
				"关卡定义缺失" -- 56
			) -- 56
			if def ~= nil and def.mission ~= nil then -- 56
				check( -- 58
					("lv" .. tostring(i + 1)) .. "-mission-matches", -- 58
					def.mission.id == "L" .. __TS__NumberToFixed(i + 1, 0), -- 58
					"mission.id=" .. def.mission.id -- 58
				) -- 58
			end -- 58
			i = i + 1 -- 43
		end -- 43
	end -- 43
end -- 34
function ____exports.runTests() -- 63
	local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 64
	local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 65
	installArcadeLevels( -- 66
		levelsText, -- 66
		bodiesText, -- 66
		function(text) -- 66
			local decoded = {json.decode(text)} -- 67
			if decoded[2] ~= nil then -- 67
				return nil -- 68
			end -- 68
			return decoded[1] -- 69
		end -- 66
	) -- 66
	testFormatRockets() -- 71
	testStationMappings() -- 72
	local lines = {} -- 74
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 75
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 76
	local limit = #failures < 12 and #failures or 12 -- 77
	do -- 77
		local i = 0 -- 78
		while i < limit do -- 78
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 79
			i = i + 1 -- 78
		end -- 78
	end -- 78
	return table.concat(lines, "\n") -- 81
end -- 63
return ____exports -- 63
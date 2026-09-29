-- [ts]: SolarHubTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____SolarHub = require("game.SolarHub") -- 4
local HUB_STATIONS = ____SolarHub.HUB_STATIONS -- 5
local LEVEL_TO_STATION_INDEX = ____SolarHub.LEVEL_TO_STATION_INDEX -- 6
local formatRocketsString = ____SolarHub.formatRocketsString -- 7
local formatProgressSummary = ____SolarHub.formatProgressSummary -- 8
local ____LevelData = require("game.LevelData") -- 10
local getLevel = ____LevelData.getLevel -- 10
local installArcadeLevels = ____LevelData.installArcadeLevels -- 10
local levelCount = ____LevelData.levelCount -- 10
local ____Dora = require("Dora") -- 11
local Content = ____Dora.Content -- 11
local json = ____Dora.json -- 11
local failures = {} -- 18
local checks = 0 -- 19
local function check(name, ok, detail) -- 21
	checks = checks + 1 -- 22
	if not ok then -- 22
		failures[#failures + 1] = {name = name, detail = detail} -- 23
	end -- 23
end -- 21
local function testFormatRockets() -- 26
	check( -- 27
		"rockets-0", -- 27
		formatRocketsString(0) == "☆  ☆  ☆", -- 27
		"0 枚火箭显示错误" -- 27
	) -- 27
	check( -- 28
		"rockets-1", -- 28
		formatRocketsString(1) == "★  ☆  ☆", -- 28
		"1 枚火箭显示错误" -- 28
	) -- 28
	check( -- 29
		"rockets-2", -- 29
		formatRocketsString(2) == "★  ★  ☆", -- 29
		"2 枚火箭显示错误" -- 29
	) -- 29
	check( -- 30
		"rockets-3", -- 30
		formatRocketsString(3) == "★  ★  ★", -- 30
		"3 枚火箭显示错误" -- 30
	) -- 30
	check( -- 31
		"rockets-clamp-neg", -- 31
		formatRocketsString(-1) == "☆  ☆  ☆", -- 31
		"负数火箭显示错误" -- 31
	) -- 31
	check( -- 32
		"rockets-clamp-over", -- 32
		formatRocketsString(5) == "★  ★  ★", -- 32
		"超出火箭显示错误" -- 32
	) -- 32
end -- 26
local function testStationMappings() -- 35
	local count = levelCount() -- 36
	check("mission-count-match", #LEVEL_TO_STATION_INDEX == count, "映射关卡数量与 levelCount 不一致") -- 37
	check("l2-mariner10-targets-mercury", LEVEL_TO_STATION_INDEX[2] == 0, "水手10号必须锚定在水星 (Station 0)") -- 40
	check("l3-voyager2-targets-neptune", LEVEL_TO_STATION_INDEX[3] == 7, "旅行者2号必须锚定在海王星 (Station 7)") -- 42
	do -- 42
		local i = 0 -- 44
		while i < count do -- 44
			local stIndex = LEVEL_TO_STATION_INDEX[i + 1] -- 45
			if stIndex == -1 then -- 45
				check( -- 47
					("lv" .. tostring(i + 1)) .. "-station-sun-valid", -- 47
					true, -- 47
					"" -- 47
				) -- 47
			else -- 47
				check( -- 49
					("lv" .. tostring(i + 1)) .. "-station-index-valid", -- 49
					stIndex >= 0 and stIndex < #HUB_STATIONS, -- 49
					("stIndex=" .. tostring(stIndex)) .. " 越界" -- 49
				) -- 49
				local st = HUB_STATIONS[stIndex + 1] -- 50
				check( -- 51
					("lv" .. tostring(i + 1)) .. "-station-orbit>0", -- 51
					st.orbit > 0, -- 51
					"orbit=" .. tostring(st.orbit) -- 51
				) -- 51
				check( -- 52
					("lv" .. tostring(i + 1)) .. "-station-radius>0", -- 52
					st.radius > 0, -- 52
					"radius=" .. tostring(st.radius) -- 52
				) -- 52
				check( -- 53
					("lv" .. tostring(i + 1)) .. "-station-model-present", -- 53
					#st.model > 0, -- 53
					"模型名称为空" -- 53
				) -- 53
			end -- 53
			local def = getLevel(i) -- 56
			check( -- 57
				("lv" .. tostring(i + 1)) .. "-def-exists", -- 57
				def ~= nil, -- 57
				"关卡定义缺失" -- 57
			) -- 57
			if def ~= nil and def.mission ~= nil then -- 57
				check( -- 59
					("lv" .. tostring(i + 1)) .. "-mission-matches", -- 59
					def.mission.id == "L" .. __TS__NumberToFixed(i + 1, 0), -- 59
					"mission.id=" .. def.mission.id -- 59
				) -- 59
			end -- 59
			i = i + 1 -- 44
		end -- 44
	end -- 44
end -- 35
function ____exports.runTests() -- 64
	local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 65
	local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 66
	installArcadeLevels( -- 67
		levelsText, -- 67
		bodiesText, -- 67
		function(text) -- 67
			local decoded = {json.decode(text)} -- 68
			if decoded[2] ~= nil then -- 68
				return nil -- 69
			end -- 69
			return decoded[1] -- 70
		end -- 67
	) -- 67
	testFormatRockets() -- 72
	testStationMappings() -- 73
	check( -- 74
		"completion-empty", -- 74
		formatProgressSummary({unlocked = 0}) == "任务完成: 0 / 3", -- 74
		"新存档不得显示三星计数" -- 74
	) -- 74
	check( -- 75
		"completion-legacy-unlocked", -- 75
		formatProgressSummary({unlocked = 2}) == "任务完成: 2 / 3", -- 75
		"旧解锁存档应保留通关" -- 75
	) -- 75
	check( -- 76
		"completion-old-multiple-rockets", -- 76
		formatProgressSummary({unlocked = 0, rockets = {L1 = 3, L2 = 2, L3 = 0}}) == "任务完成: 2 / 3", -- 76
		"历史火箭数不能多算通关数量" -- 76
	) -- 76
	check( -- 77
		"completion-all", -- 77
		formatProgressSummary({unlocked = 2, rockets = {L1 = 1, L2 = 1, L3 = 1}}) == "任务完成: 3 / 3", -- 77
		"最终关完成应计入统计" -- 77
	) -- 77
	local lines = {} -- 79
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 80
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 81
	local limit = #failures < 12 and #failures or 12 -- 82
	do -- 82
		local i = 0 -- 83
		while i < limit do -- 83
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 84
			i = i + 1 -- 83
		end -- 83
	end -- 83
	return table.concat(lines, "\n") -- 86
end -- 64
return ____exports -- 64
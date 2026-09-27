-- [ts]: ProgressTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 13
local Content = ____Dora.Content -- 13
local ____Game = require("game.Game") -- 14
local coreBackToSelect = ____Game.coreBackToSelect -- 14
local coreLaunch = ____Game.coreLaunch -- 14
local coreUpdate = ____Game.coreUpdate -- 14
local createCore = ____Game.createCore -- 14
local ____LevelData = require("game.LevelData") -- 15
local getLevel = ____LevelData.getLevel -- 15
local scaledPlanets = ____LevelData.scaledPlanets -- 15
local ____Progress = require("game.Progress") -- 16
local advanceUnlocked = ____Progress.advanceUnlocked -- 16
local clampUnlocked = ____Progress.clampUnlocked -- 16
local getMissionRockets = ____Progress.getMissionRockets -- 16
local getTotalRockets = ____Progress.getTotalRockets -- 16
local loadProgress = ____Progress.loadProgress -- 16
local progressFilePath = ____Progress.progressFilePath -- 16
local recordMissionResult = ____Progress.recordMissionResult -- 16
local saveProgress = ____Progress.saveProgress -- 16
local failures = {} -- 23
local checks = 0 -- 24
local function check(name, ok, detail) -- 26
	checks = checks + 1 -- 27
	if not ok then -- 27
		failures[#failures + 1] = {name = name, detail = detail} -- 28
	end -- 28
end -- 26
--- 测试关：直接用第一关的数据（真实数据比自造数字更能守住回归）。
local function testLevel() -- 32
	local def = getLevel(0) -- 33
	if def == nil then -- 33
		return nil -- 34
	end -- 34
	return { -- 35
		bodies = scaledPlanets(def), -- 36
		probeStart = def.probeStart, -- 37
		goal = def.goal, -- 38
		escapeRadius = def.escapeRadius, -- 39
		maxSteps = def.maxSteps -- 40
	} -- 40
end -- 32
--- 1) clampUnlocked：边界与非法输入。
local function testClamp() -- 45
	check( -- 46
		"clamp-zero", -- 46
		clampUnlocked(0, 6) == 0, -- 46
		"got " .. tostring(clampUnlocked(0, 6)) -- 46
	) -- 46
	check( -- 47
		"clamp-max", -- 47
		clampUnlocked(5, 6) == 5, -- 47
		"got " .. tostring(clampUnlocked(5, 6)) -- 47
	) -- 47
	check( -- 48
		"clamp-over", -- 48
		clampUnlocked(9, 6) == 5, -- 48
		"超过上限必须夹到 levelCount-1" -- 48
	) -- 48
	check( -- 49
		"clamp-negative", -- 49
		clampUnlocked(-1, 6) == 0, -- 49
		"负数归 0" -- 49
	) -- 49
	check( -- 50
		"clamp-nan", -- 50
		clampUnlocked(0 / 0, 6) == 0, -- 50
		"NaN 归 0" -- 50
	) -- 50
	check( -- 51
		"clamp-inf", -- 51
		clampUnlocked(math.huge, 6) == 0, -- 51
		"Infinity 归 0" -- 51
	) -- 51
	check( -- 52
		"clamp-neg-inf", -- 52
		clampUnlocked(-math.huge, 6) == 0, -- 52
		"-Infinity 归 0" -- 52
	) -- 52
	check( -- 53
		"clamp-fraction", -- 53
		clampUnlocked(2.7, 6) == 2, -- 53
		"非整数向下取整" -- 53
	) -- 53
	check( -- 54
		"clamp-no-levels", -- 54
		clampUnlocked(3, 0) == 0, -- 54
		"关卡数为 0 时只能给 0" -- 54
	) -- 54
	check( -- 55
		"clamp-negative-levels", -- 55
		clampUnlocked(3, -2) == 0, -- 55
		"关卡数为负时只能给 0" -- 55
	) -- 55
end -- 45
--- 2) advanceUnlocked：只有 success 解锁下一关，且不越界、不回退。
local function testAdvance() -- 59
	check( -- 60
		"advance-first-success", -- 60
		advanceUnlocked(0, "success", 0, 6) == 1, -- 60
		"通关第 1 关应解锁第 2 关" -- 60
	) -- 60
	check( -- 61
		"advance-mid-success", -- 61
		advanceUnlocked(2, "success", 2, 6) == 3, -- 61
		"通关第 3 关应解锁第 4 关" -- 61
	) -- 61
	check( -- 62
		"advance-missed", -- 62
		advanceUnlocked(1, "missed", 1, 6) == 1, -- 62
		"错过不解锁" -- 62
	) -- 62
	check( -- 63
		"advance-crashed", -- 63
		advanceUnlocked(1, "crashed", 1, 6) == 1, -- 63
		"撞毁不解锁" -- 63
	) -- 63
	check( -- 64
		"advance-missed-zero", -- 64
		advanceUnlocked(0, "missed", 0, 6) == 0, -- 64
		"错过不该凭空解锁" -- 64
	) -- 64
	check( -- 65
		"advance-last-level", -- 65
		advanceUnlocked(5, "success", 5, 6) == 5, -- 65
		"最后一关通关不越界（仍是 5）" -- 65
	) -- 65
	check( -- 66
		"advance-no-downgrade", -- 66
		advanceUnlocked(3, "success", 0, 6) == 3, -- 66
		"重玩旧关不回退进度" -- 66
	) -- 66
	check( -- 67
		"advance-clamps-junk", -- 67
		advanceUnlocked(99, "missed", 0, 6) == 5, -- 67
		"非法入参也要夹紧" -- 67
	) -- 67
	check( -- 68
		"advance-nan-input", -- 68
		advanceUnlocked(0 / 0, "success", 0, 6) == 1, -- 68
		"NaN 进度 + 通关 = 解锁第 2 关" -- 68
	) -- 68
end -- 59
--- 3) 存档往返（真实读写 writablePath 下的文件）。
-- 
-- 会**先读后还原**：单测不该把玩家进度改掉。测试期间会临时写入
-- `unlocked=3`、垃圾内容等，最后恢复测试前的值。
local function testPersistence() -- 77
	local levelCountForSave = 6 -- 78
	local file = progressFilePath() -- 79
	local before = loadProgress(levelCountForSave) -- 81
	saveProgress({unlocked = 3}) -- 84
	local raw = Content:exist(file) and Content:load(file) or "" -- 85
	check("save-format", raw == "unlocked=3", ("文件内容应为单行 unlocked=3，实际 \"" .. raw) .. "\"") -- 86
	check( -- 87
		"load-roundtrip", -- 87
		loadProgress(levelCountForSave).unlocked == 3, -- 87
		"存 3 读回来应是 3" -- 87
	) -- 87
	saveProgress({unlocked = 99}) -- 90
	check( -- 91
		"load-clamps", -- 91
		loadProgress(levelCountForSave).unlocked == 5, -- 91
		"存档里的越界值读回应夹到 5" -- 91
	) -- 91
	Content:save(file, "garbage") -- 94
	check( -- 95
		"load-garbage", -- 95
		loadProgress(levelCountForSave).unlocked == 0, -- 95
		"垃圾内容应视为 0" -- 95
	) -- 95
	Content:save(file, "unlocked=abc") -- 96
	check( -- 97
		"load-nonnumeric", -- 97
		loadProgress(levelCountForSave).unlocked == 0, -- 97
		"非数字值应视为 0" -- 97
	) -- 97
	Content:save(file, "") -- 98
	check( -- 99
		"load-empty", -- 99
		loadProgress(levelCountForSave).unlocked == 0, -- 99
		"空文件应视为 0" -- 99
	) -- 99
	Content:save(file, "other=4\nunlocked=2\n") -- 100
	check( -- 101
		"load-extra-lines", -- 101
		loadProgress(levelCountForSave).unlocked == 2, -- 101
		"多行时应取 unlocked 行" -- 101
	) -- 101
	saveProgress(before) -- 104
	check( -- 105
		"restore", -- 105
		loadProgress(levelCountForSave).unlocked == before.unlocked, -- 105
		(("还原失败：before=" .. __TS__NumberToFixed(before.unlocked, 0)) .. " after=") .. __TS__NumberToFixed( -- 106
			loadProgress(levelCountForSave).unlocked, -- 106
			0 -- 106
		) -- 106
	) -- 106
end -- 77
--- 4) coreBackToSelect：只有 Result 态可切，且切换后清空飞行/结算数据。
local function testBackToSelect() -- 110
	local level = testLevel() -- 111
	if level == nil then -- 111
		check("back-level", false, "无法取得第一关数据") -- 113
		return -- 114
	end -- 114
	local core = createCore() -- 118
	check( -- 119
		"back-guard-aiming", -- 119
		coreBackToSelect(core) == false and core.phase == "Aiming", -- 119
		"Aiming 态应拒绝并保持相态，实际 phase=" .. core.phase -- 120
	) -- 120
	coreLaunch(core, {x = 6, y = -12}, level) -- 123
	check( -- 124
		"back-guard-flying", -- 124
		coreBackToSelect(core) == false and core.phase == "Flying", -- 124
		"Flying 态应拒绝并保持相态，实际 phase=" .. core.phase -- 125
	) -- 125
	local guard = 0 -- 128
	while core.phase ~= "Result" and guard < 100000 do -- 128
		coreUpdate(core, 1 / 60) -- 130
		guard = guard + 1 -- 131
	end -- 131
	check("back-reached-result", core.phase == "Result", "未能进入 Result，phase=" .. core.phase) -- 133
	check( -- 134
		"back-from-result", -- 134
		coreBackToSelect(core) == true and core.phase == "LevelSelect", -- 134
		"Result 态应成功切到 LevelSelect，实际 phase=" .. core.phase -- 135
	) -- 135
	check("back-clears-flight", core.flight == nil, "返回后应清空飞行轨迹") -- 136
	check("back-clears-result", core.result == nil, "返回后应清空结算") -- 137
	check("back-clears-goal", core.goalIndex == -1, "返回后应清空目标索引") -- 138
	check( -- 139
		"back-clears-time", -- 139
		core.flightTime == 0, -- 139
		"返回后应清零回放时间，实际 " .. tostring(core.flightTime) -- 139
	) -- 139
	check( -- 142
		"back-twice", -- 142
		coreBackToSelect(core) == false and core.phase == "LevelSelect", -- 142
		"重复返回应被拒绝且相态不变，实际 phase=" .. core.phase -- 143
	) -- 143
end -- 110
--- 5) testRockets：多火箭记录、不降级、统计与兼容性
local function testRockets() -- 147
	local p0 = {unlocked = 0} -- 148
	check( -- 149
		"rocket-empty-l0", -- 149
		getMissionRockets(p0, 0) == 0, -- 149
		"未解锁关卡应为 0 颗火箭" -- 149
	) -- 149
	local p1 = recordMissionResult(p0, 0, 2, 6) -- 150
	check( -- 151
		"rocket-record-l0", -- 151
		getMissionRockets(p1, 0) == 2, -- 151
		"达成 2 枚火箭应返回 2" -- 151
	) -- 151
	check("rocket-advance-unlocked", p1.unlocked == 1, "达成火箭应同时推进解锁") -- 152
	local p2 = recordMissionResult(p1, 0, 1, 6) -- 153
	check( -- 154
		"rocket-no-downgrade", -- 154
		getMissionRockets(p2, 0) == 2, -- 154
		"低分不应覆盖高分" -- 154
	) -- 154
	local p3 = recordMissionResult(p2, 1, 3, 6) -- 155
	check( -- 156
		"rocket-record-l1", -- 156
		getMissionRockets(p3, 1) == 3, -- 156
		"L2 达成 3 枚火箭应返回 3" -- 156
	) -- 156
	check( -- 157
		"rocket-total", -- 157
		getTotalRockets(p3, 6) == 5, -- 157
		"总火箭数应为 2+3=5" -- 157
	) -- 157
	local pLegacy = {unlocked = 2} -- 160
	check( -- 161
		"rocket-legacy-l0", -- 161
		getMissionRockets(pLegacy, 0) == 1, -- 161
		"旧存档第 1 关应兜底 1" -- 161
	) -- 161
	check( -- 162
		"rocket-legacy-l1", -- 162
		getMissionRockets(pLegacy, 1) == 1, -- 162
		"旧存档第 2 关应兜底 1" -- 162
	) -- 162
	check( -- 163
		"rocket-legacy-l2", -- 163
		getMissionRockets(pLegacy, 2) == 0, -- 163
		"旧存档未通关的关卡应为 0" -- 163
	) -- 163
	local levelCountForSave = 6 -- 166
	local before = loadProgress(levelCountForSave) -- 167
	saveProgress(p3) -- 168
	local reloaded = loadProgress(levelCountForSave) -- 169
	check( -- 170
		"rocket-save-roundtrip-l0", -- 170
		getMissionRockets(reloaded, 0) == 2, -- 170
		"写盘读回 L1 应为 2" -- 170
	) -- 170
	check( -- 171
		"rocket-save-roundtrip-l1", -- 171
		getMissionRockets(reloaded, 1) == 3, -- 171
		"写盘读回 L2 应为 3" -- 171
	) -- 171
	check("rocket-save-roundtrip-unlocked", reloaded.unlocked == 2, "写盘读回 unlocked 应为 2") -- 172
	saveProgress(before) -- 173
end -- 147
function ____exports.runTests() -- 176
	testClamp() -- 177
	testAdvance() -- 178
	testPersistence() -- 179
	testBackToSelect() -- 180
	testRockets() -- 181
	local lines = {} -- 183
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 184
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 185
	local limit = #failures < 12 and #failures or 12 -- 186
	do -- 186
		local i = 0 -- 187
		while i < limit do -- 187
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 188
			i = i + 1 -- 187
		end -- 187
	end -- 187
	return table.concat(lines, "\n") -- 190
end -- 176
return ____exports -- 176
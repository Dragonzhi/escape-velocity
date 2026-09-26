-- [ts]: GameTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Config = require("game.Config") -- 8
local FlightPlayback = ____Config.FlightPlayback -- 8
local PhysicsStep = ____Config.PhysicsStep -- 8
local ____Game = require("game.Game") -- 10
local coreArm = ____Game.coreArm -- 11
local coreCancelArm = ____Game.coreCancelArm -- 11
local coreLaunch = ____Game.coreLaunch -- 11
local coreProbeIndex = ____Game.coreProbeIndex -- 11
local coreRetry = ____Game.coreRetry -- 11
local coreUpdate = ____Game.coreUpdate -- 11
local createCore = ____Game.createCore -- 11
local resolveResult = ____Game.resolveResult -- 11
local failures = {} -- 19
local checks = 0 -- 20
local function check(name, ok, detail) -- 22
	checks = checks + 1 -- 23
	if not ok then -- 23
		failures[#failures + 1] = {name = name, detail = detail} -- 24
	end -- 24
end -- 22
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。
local function testLevel() -- 28
	local bodies = {{ -- 29
		gm = 900, -- 30
		radius = 2.2, -- 30
		orbitCenter = {x = 0, y = 0}, -- 31
		orbitRadius = 0, -- 31
		orbitPeriod = 0, -- 32
		phase0 = 0, -- 32
		orbitDirection = 1 -- 32
	}} -- 32
	return { -- 34
		bodies = bodies, -- 35
		probeStart = {x = 0, y = 16}, -- 36
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 37
		escapeRadius = 400, -- 38
		maxSteps = 1500 -- 39
	} -- 39
end -- 28
--- 1) 结算判定（手册 §5.8）。
local function testResolveResult() -- 44
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 45
	local planetGoal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 46
	check( -- 49
		"resolve-goal-first", -- 49
		resolveResult("crashed", 5, planetGoal) == "success", -- 49
		"到达目标应优先于撞毁（轨迹在到达点截断）" -- 49
	) -- 49
	check( -- 50
		"resolve-goal-running", -- 50
		resolveResult("running", 3, planetGoal) == "success", -- 50
		"到达目标即成功" -- 50
	) -- 50
	check( -- 53
		"resolve-escape-success", -- 53
		resolveResult("escaped", -1, escapeGoal) == "success", -- 53
		"逃逸目标达成 = 成功" -- 53
	) -- 53
	check( -- 54
		"resolve-escape-timeout", -- 54
		resolveResult("running", -1, escapeGoal) == "missed", -- 54
		"超时 = 错过" -- 54
	) -- 54
	check( -- 57
		"resolve-planet-escaped", -- 57
		resolveResult("escaped", -1, planetGoal) == "missed", -- 57
		"飞出边界但未到达目标 = 错过" -- 57
	) -- 57
	check( -- 58
		"resolve-planet-crashed", -- 58
		resolveResult("crashed", -1, planetGoal) == "crashed", -- 58
		"撞毁 = 撞毁" -- 58
	) -- 58
end -- 44
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 62
	local level = testLevel() -- 63
	local core = createCore() -- 64
	coreLaunch(core, {x = 6, y = -12}, level) -- 66
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 67
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 68
	check( -- 69
		"launch-time-zero", -- 69
		core.flightTime == 0, -- 69
		"flightTime=" .. tostring(core.flightTime) -- 69
	) -- 69
	local before = core.flight ~= nil and #core.flight.points or 0 -- 72
	coreLaunch(core, {x = 0, y = -20}, level) -- 73
	local after = core.flight ~= nil and #core.flight.points or 0 -- 74
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 75
end -- 62
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 79
	local level = testLevel() -- 80
	local core = createCore() -- 81
	coreLaunch(core, {x = 6, y = -12}, level) -- 82
	local flight = core.flight -- 83
	if flight == nil then -- 83
		check("playback-flight", false, "no flight") -- 84
		return -- 84
	end -- 84
	local total = #flight.points - 1 -- 86
	check( -- 87
		"playback-start-index", -- 87
		coreProbeIndex(core) == 0, -- 87
		"idx=" .. tostring(coreProbeIndex(core)) -- 87
	) -- 87
	local entered = false -- 90
	local frames = 0 -- 91
	while not entered and frames < 100000 do -- 91
		entered = coreUpdate(core, 1 / 60) -- 93
		frames = frames + 1 -- 94
		if core.phase == "Result" then -- 94
			break -- 95
		end -- 95
	end -- 95
	check( -- 98
		"playback-enters-result", -- 98
		entered and core.phase == "Result", -- 98
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 98
	) -- 98
	check( -- 99
		"playback-final-index", -- 99
		coreProbeIndex(core) == total, -- 99
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 99
	) -- 99
	check( -- 100
		"playback-result-kind", -- 100
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 100
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 100
	) -- 100
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 103
	local actualRealSeconds = frames / 60 -- 104
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 105
	check( -- 106
		"playback-duration", -- 106
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 106
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 106
	) -- 106
end -- 79
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 111
	local level = testLevel() -- 112
	local core = createCore() -- 113
	coreRetry(core) -- 116
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 117
	coreLaunch(core, {x = 6, y = -12}, level) -- 119
	local entered = false -- 120
	local guard = 0 -- 121
	while not entered and guard < 100000 do -- 121
		entered = coreUpdate(core, 1 / 60) -- 123
		guard = guard + 1 -- 124
	end -- 124
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 126
	coreRetry(core) -- 128
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 129
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 130
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 131
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 132
	check( -- 133
		"retry-time-reset", -- 133
		core.flightTime == 0, -- 133
		"flightTime=" .. tostring(core.flightTime) -- 133
	) -- 133
	coreLaunch(core, {x = 0, y = -20}, level) -- 136
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 137
end -- 111
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 141
	local level = testLevel() -- 142
	local core = createCore() -- 143
	coreLaunch(core, {x = 6, y = -12}, level) -- 144
	local flight = core.flight -- 145
	if flight == nil then -- 145
		check("clamp-flight", false, "no flight") -- 146
		return -- 146
	end -- 146
	core.flightTime = -100 -- 148
	check( -- 149
		"clamp-negative", -- 149
		coreProbeIndex(core) == 0, -- 149
		"idx=" .. tostring(coreProbeIndex(core)) -- 149
	) -- 149
	core.flightTime = 1000000000 -- 151
	check( -- 152
		"clamp-huge", -- 152
		coreProbeIndex(core) == #flight.points - 1, -- 152
		"idx=" .. tostring(coreProbeIndex(core)) -- 152
	) -- 152
end -- 141
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 156
	local level = testLevel() -- 157
	local results = {} -- 158
	do -- 158
		local run = 0 -- 159
		while run < 2 do -- 159
			local core = createCore() -- 160
			coreLaunch(core, {x = 6, y = -12}, level) -- 161
			local guard = 0 -- 162
			while core.phase ~= "Result" and guard < 100000 do -- 162
				coreUpdate(core, 1 / 60) -- 164
				guard = guard + 1 -- 165
			end -- 165
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 167
			run = run + 1 -- 159
		end -- 159
	end -- 159
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 169
end -- 156
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 173
	local bodies = {{ -- 175
		gm = 0, -- 176
		radius = 1.2, -- 176
		orbitCenter = {x = 0, y = -20}, -- 176
		orbitRadius = 0, -- 176
		orbitPeriod = 0, -- 176
		phase0 = 0, -- 176
		orbitDirection = 1 -- 176
	}} -- 176
	local level = { -- 178
		bodies = bodies, -- 179
		probeStart = {x = 0, y = 16}, -- 180
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 181
		escapeRadius = 400, -- 182
		maxSteps = 1500 -- 183
	} -- 183
	local core = createCore() -- 186
	coreLaunch(core, {x = 0, y = -10}, level) -- 187
	check( -- 189
		"goal-found", -- 189
		core.goalIndex >= 0, -- 189
		"goalIndex=" .. tostring(core.goalIndex) -- 189
	) -- 189
	check( -- 190
		"goal-result-at-launch", -- 190
		core.result == "success", -- 190
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 190
	) -- 190
	local flight = core.flight -- 192
	if flight == nil or core.goalIndex < 0 then -- 192
		check("goal-flight", false, "no flight") -- 193
		return -- 193
	end -- 193
	local guard = 0 -- 196
	while core.phase ~= "Result" and guard < 100000 do -- 196
		coreUpdate(core, 1 / 60) -- 198
		guard = guard + 1 -- 199
	end -- 199
	check( -- 201
		"goal-ends-early", -- 201
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 201
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 201
	) -- 201
	check( -- 203
		"goal-still-success", -- 203
		core.result == "success", -- 203
		"result=" .. tostring(core.result) -- 203
	) -- 203
end -- 173
--- 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
-- 
-- 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
-- 状态机这一路必须自己站稳。
local function testArmed() -- 212
	local level = testLevel() -- 213
	local core = createCore() -- 214
	check( -- 215
		"arm-from-aiming", -- 215
		coreArm(core) == true and core.phase == "Armed", -- 215
		"phase=" .. core.phase -- 215
	) -- 215
	check( -- 216
		"arm-idempotent", -- 216
		coreArm(core) == false, -- 216
		"已在 Armed 时 coreArm 应返回 false（不能重复 arm）" -- 216
	) -- 216
	coreLaunch(core, {x = 0, y = -20}, level) -- 218
	check("launch-from-armed", core.phase == "Flying", "phase=" .. core.phase) -- 219
	local core2 = createCore() -- 221
	check( -- 222
		"cancel-guard", -- 222
		coreCancelArm(core2) == false, -- 222
		"Aiming 态调用 coreCancelArm 应返回 false" -- 222
	) -- 222
	coreArm(core2) -- 223
	check( -- 224
		"cancel-armed", -- 224
		coreCancelArm(core2) == true and core2.phase == "Aiming", -- 224
		"phase=" .. core2.phase -- 224
	) -- 224
	local core3 = createCore() -- 226
	coreArm(core3) -- 227
	coreRetry(core3) -- 228
	check("retry-clears-armed", core3.phase == "Aiming", "phase=" .. core3.phase) -- 229
end -- 212
function ____exports.runTests() -- 232
	testResolveResult() -- 233
	testLaunch() -- 234
	testArmed() -- 235
	testPlayback() -- 236
	testRetry() -- 237
	testIndexClamp() -- 238
	testDeterministicCycle() -- 239
	testGoalTruncation() -- 240
	local lines = {} -- 242
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 243
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 244
	local limit = #failures < 12 and #failures or 12 -- 245
	do -- 245
		local i = 0 -- 246
		while i < limit do -- 246
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 247
			i = i + 1 -- 246
		end -- 246
	end -- 246
	return table.concat(lines, "\n") -- 249
end -- 232
return ____exports -- 232
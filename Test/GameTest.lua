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
local coreTimeWarpAllowed = ____Game.coreTimeWarpAllowed -- 11
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
	local chainedEscape = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 0, tolerance = 4, label = "A"}, {planetIndex = 1, tolerance = 4, label = "B"}}} -- 61
	check( -- 65
		"resolve-escape-chain-both", -- 65
		resolveResult("escaped", 7, chainedEscape) == "success", -- 65
		"逃逸关：走完航线 + 越界 = 成功" -- 65
	) -- 65
	check( -- 66
		"resolve-escape-chain-no-route", -- 66
		resolveResult("escaped", -1, chainedEscape) == "missed", -- 66
		"逃逸关：只有越界、没走完航线 = 错过" -- 66
	) -- 66
	check( -- 67
		"resolve-escape-chain-no-escape", -- 67
		resolveResult("running", 7, chainedEscape) == "missed", -- 67
		"逃逸关：只走完航线、没越界 = 错过" -- 67
	) -- 67
	check( -- 68
		"resolve-escape-chain-crashed", -- 68
		resolveResult("crashed", -1, chainedEscape) == "crashed", -- 68
		"逃逸关：撞毁 = 撞毁" -- 68
	) -- 68
end -- 44
--- 1b) 时间流的相态守卫（S3.11）。
-- 
-- 为什么要有它：飞行用的是 tWorld = t0 + flightTime，飞行途中改 t0 等于把参考系整个挪走，
-- 行星会在飞行路径底下跳位。所以"能不能改日期"必须由**相态**决定，而不是由按钮决定。
local function testTimeWarpGuard() -- 77
	local level = testLevel() -- 78
	local core = createCore() -- 79
	check( -- 80
		"time-warp-aiming", -- 80
		coreTimeWarpAllowed(core), -- 80
		"Aiming 应允许改日期：phase=" .. core.phase -- 80
	) -- 80
	coreArm(core) -- 81
	check( -- 82
		"time-warp-armed", -- 82
		coreTimeWarpAllowed(core), -- 82
		"Armed 也应允许（瞄好了再挑日期）：phase=" .. core.phase -- 82
	) -- 82
	coreCancelArm(core) -- 83
	coreLaunch(core, {x = 6, y = -12}, level) -- 85
	check( -- 86
		"time-warp-flying", -- 86
		not coreTimeWarpAllowed(core), -- 86
		"Flying 必须禁止改日期：phase=" .. core.phase -- 86
	) -- 86
	local entered = false -- 88
	local frames = 0 -- 89
	while not entered and frames < 100000 do -- 89
		entered = coreUpdate(core, 1 / 60) -- 91
		frames = frames + 1 -- 92
		if core.phase == "Result" then -- 92
			break -- 93
		end -- 93
	end -- 93
	check( -- 95
		"time-warp-result", -- 95
		not coreTimeWarpAllowed(core), -- 95
		"Result 必须禁止改日期：phase=" .. core.phase -- 95
	) -- 95
end -- 77
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 99
	local level = testLevel() -- 100
	local core = createCore() -- 101
	coreLaunch(core, {x = 6, y = -12}, level) -- 103
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 104
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 105
	check( -- 106
		"launch-time-zero", -- 106
		core.flightTime == 0, -- 106
		"flightTime=" .. tostring(core.flightTime) -- 106
	) -- 106
	local before = core.flight ~= nil and #core.flight.points or 0 -- 109
	coreLaunch(core, {x = 0, y = -20}, level) -- 110
	local after = core.flight ~= nil and #core.flight.points or 0 -- 111
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 112
end -- 99
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 116
	local level = testLevel() -- 117
	local core = createCore() -- 118
	coreLaunch(core, {x = 6, y = -12}, level) -- 119
	local flight = core.flight -- 120
	if flight == nil then -- 120
		check("playback-flight", false, "no flight") -- 121
		return -- 121
	end -- 121
	local total = #flight.points - 1 -- 123
	check( -- 124
		"playback-start-index", -- 124
		coreProbeIndex(core) == 0, -- 124
		"idx=" .. tostring(coreProbeIndex(core)) -- 124
	) -- 124
	local entered = false -- 127
	local frames = 0 -- 128
	while not entered and frames < 100000 do -- 128
		entered = coreUpdate(core, 1 / 60) -- 130
		frames = frames + 1 -- 131
		if core.phase == "Result" then -- 131
			break -- 132
		end -- 132
	end -- 132
	check( -- 135
		"playback-enters-result", -- 135
		entered and core.phase == "Result", -- 135
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 135
	) -- 135
	check( -- 136
		"playback-final-index", -- 136
		coreProbeIndex(core) == total, -- 136
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 136
	) -- 136
	check( -- 137
		"playback-result-kind", -- 137
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 137
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 137
	) -- 137
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 140
	local actualRealSeconds = frames / 60 -- 141
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 142
	check( -- 143
		"playback-duration", -- 143
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 143
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 143
	) -- 143
end -- 116
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 148
	local level = testLevel() -- 149
	local core = createCore() -- 150
	coreRetry(core) -- 153
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 154
	coreLaunch(core, {x = 6, y = -12}, level) -- 156
	local entered = false -- 157
	local guard = 0 -- 158
	while not entered and guard < 100000 do -- 158
		entered = coreUpdate(core, 1 / 60) -- 160
		guard = guard + 1 -- 161
	end -- 161
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 163
	coreRetry(core) -- 165
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 166
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 167
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 168
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 169
	check( -- 170
		"retry-time-reset", -- 170
		core.flightTime == 0, -- 170
		"flightTime=" .. tostring(core.flightTime) -- 170
	) -- 170
	coreLaunch(core, {x = 0, y = -20}, level) -- 173
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 174
end -- 148
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 178
	local level = testLevel() -- 179
	local core = createCore() -- 180
	coreLaunch(core, {x = 6, y = -12}, level) -- 181
	local flight = core.flight -- 182
	if flight == nil then -- 182
		check("clamp-flight", false, "no flight") -- 183
		return -- 183
	end -- 183
	core.flightTime = -100 -- 185
	check( -- 186
		"clamp-negative", -- 186
		coreProbeIndex(core) == 0, -- 186
		"idx=" .. tostring(coreProbeIndex(core)) -- 186
	) -- 186
	core.flightTime = 1000000000 -- 188
	check( -- 189
		"clamp-huge", -- 189
		coreProbeIndex(core) == #flight.points - 1, -- 189
		"idx=" .. tostring(coreProbeIndex(core)) -- 189
	) -- 189
end -- 178
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 193
	local level = testLevel() -- 194
	local results = {} -- 195
	do -- 195
		local run = 0 -- 196
		while run < 2 do -- 196
			local core = createCore() -- 197
			coreLaunch(core, {x = 6, y = -12}, level) -- 198
			local guard = 0 -- 199
			while core.phase ~= "Result" and guard < 100000 do -- 199
				coreUpdate(core, 1 / 60) -- 201
				guard = guard + 1 -- 202
			end -- 202
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 204
			run = run + 1 -- 196
		end -- 196
	end -- 196
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 206
end -- 193
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 210
	local bodies = {{ -- 212
		gm = 0, -- 213
		radius = 1.2, -- 213
		orbitCenter = {x = 0, y = -20}, -- 213
		orbitRadius = 0, -- 213
		orbitPeriod = 0, -- 213
		phase0 = 0, -- 213
		orbitDirection = 1 -- 213
	}} -- 213
	local level = { -- 215
		bodies = bodies, -- 216
		probeStart = {x = 0, y = 16}, -- 217
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 218
		escapeRadius = 400, -- 219
		maxSteps = 1500 -- 220
	} -- 220
	local core = createCore() -- 223
	coreLaunch(core, {x = 0, y = -10}, level) -- 224
	check( -- 226
		"goal-found", -- 226
		core.goalIndex >= 0, -- 226
		"goalIndex=" .. tostring(core.goalIndex) -- 226
	) -- 226
	check( -- 227
		"goal-result-at-launch", -- 227
		core.result == "success", -- 227
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 227
	) -- 227
	local flight = core.flight -- 229
	if flight == nil or core.goalIndex < 0 then -- 229
		check("goal-flight", false, "no flight") -- 230
		return -- 230
	end -- 230
	local guard = 0 -- 233
	while core.phase ~= "Result" and guard < 100000 do -- 233
		coreUpdate(core, 1 / 60) -- 235
		guard = guard + 1 -- 236
	end -- 236
	check( -- 238
		"goal-ends-early", -- 238
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 238
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 238
	) -- 238
	check( -- 240
		"goal-still-success", -- 240
		core.result == "success", -- 240
		"result=" .. tostring(core.result) -- 240
	) -- 240
end -- 210
--- 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
-- 
-- 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
-- 状态机这一路必须自己站稳。
local function testArmed() -- 249
	local level = testLevel() -- 250
	local core = createCore() -- 251
	check( -- 252
		"arm-from-aiming", -- 252
		coreArm(core) == true and core.phase == "Armed", -- 252
		"phase=" .. core.phase -- 252
	) -- 252
	check( -- 253
		"arm-idempotent", -- 253
		coreArm(core) == false, -- 253
		"已在 Armed 时 coreArm 应返回 false（不能重复 arm）" -- 253
	) -- 253
	coreLaunch(core, {x = 0, y = -20}, level) -- 255
	check("launch-from-armed", core.phase == "Flying", "phase=" .. core.phase) -- 256
	local core2 = createCore() -- 258
	check( -- 259
		"cancel-guard", -- 259
		coreCancelArm(core2) == false, -- 259
		"Aiming 态调用 coreCancelArm 应返回 false" -- 259
	) -- 259
	coreArm(core2) -- 260
	check( -- 261
		"cancel-armed", -- 261
		coreCancelArm(core2) == true and core2.phase == "Aiming", -- 261
		"phase=" .. core2.phase -- 261
	) -- 261
	local core3 = createCore() -- 263
	coreArm(core3) -- 264
	coreRetry(core3) -- 265
	check("retry-clears-armed", core3.phase == "Aiming", "phase=" .. core3.phase) -- 266
end -- 249
function ____exports.runTests() -- 269
	testResolveResult() -- 270
	testTimeWarpGuard() -- 271
	testLaunch() -- 272
	testArmed() -- 273
	testPlayback() -- 274
	testRetry() -- 275
	testIndexClamp() -- 276
	testDeterministicCycle() -- 277
	testGoalTruncation() -- 278
	local lines = {} -- 280
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 281
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 282
	local limit = #failures < 12 and #failures or 12 -- 283
	do -- 283
		local i = 0 -- 284
		while i < limit do -- 284
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 285
			i = i + 1 -- 284
		end -- 284
	end -- 284
	return table.concat(lines, "\n") -- 287
end -- 269
return ____exports -- 269
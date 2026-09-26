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
local coreHandoffDate = ____Game.coreHandoffDate -- 11
local coreLaunch = ____Game.coreLaunch -- 11
local coreProbeIndex = ____Game.coreProbeIndex -- 11
local coreRetry = ____Game.coreRetry -- 11
local coreTimeWarpAllowed = ____Game.coreTimeWarpAllowed -- 11
local coreUpdate = ____Game.coreUpdate -- 11
local createCore = ____Game.createCore -- 12
local resolveResult = ____Game.resolveResult -- 12
local failures = {} -- 20
local checks = 0 -- 21
local function check(name, ok, detail) -- 23
	checks = checks + 1 -- 24
	if not ok then -- 24
		failures[#failures + 1] = {name = name, detail = detail} -- 25
	end -- 25
end -- 23
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。
local function testLevel() -- 29
	local bodies = {{ -- 30
		gm = 900, -- 31
		radius = 2.2, -- 31
		orbitCenter = {x = 0, y = 0}, -- 32
		orbitRadius = 0, -- 32
		orbitPeriod = 0, -- 33
		phase0 = 0, -- 33
		orbitDirection = 1 -- 33
	}} -- 33
	return { -- 35
		bodies = bodies, -- 36
		probeStart = {x = 0, y = 16}, -- 37
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 38
		escapeRadius = 400, -- 39
		maxSteps = 1500 -- 40
	} -- 40
end -- 29
--- 1) 结算判定（手册 §5.8）。
local function testResolveResult() -- 45
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 46
	local planetGoal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 47
	check( -- 50
		"resolve-goal-first", -- 50
		resolveResult("crashed", 5, planetGoal) == "success", -- 50
		"到达目标应优先于撞毁（轨迹在到达点截断）" -- 50
	) -- 50
	check( -- 51
		"resolve-goal-running", -- 51
		resolveResult("running", 3, planetGoal) == "success", -- 51
		"到达目标即成功" -- 51
	) -- 51
	check( -- 54
		"resolve-escape-success", -- 54
		resolveResult("escaped", -1, escapeGoal) == "success", -- 54
		"逃逸目标达成 = 成功" -- 54
	) -- 54
	check( -- 55
		"resolve-escape-timeout", -- 55
		resolveResult("running", -1, escapeGoal) == "missed", -- 55
		"超时 = 错过" -- 55
	) -- 55
	check( -- 58
		"resolve-planet-escaped", -- 58
		resolveResult("escaped", -1, planetGoal) == "missed", -- 58
		"飞出边界但未到达目标 = 错过" -- 58
	) -- 58
	check( -- 59
		"resolve-planet-crashed", -- 59
		resolveResult("crashed", -1, planetGoal) == "crashed", -- 59
		"撞毁 = 撞毁" -- 59
	) -- 59
	local chainedEscape = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 0, tolerance = 4, label = "A"}, {planetIndex = 1, tolerance = 4, label = "B"}}} -- 62
	check( -- 66
		"resolve-escape-chain-both", -- 66
		resolveResult("escaped", 7, chainedEscape) == "success", -- 66
		"逃逸关：走完航线 + 越界 = 成功" -- 66
	) -- 66
	check( -- 67
		"resolve-escape-chain-no-route", -- 67
		resolveResult("escaped", -1, chainedEscape) == "missed", -- 67
		"逃逸关：只有越界、没走完航线 = 错过" -- 67
	) -- 67
	check( -- 68
		"resolve-escape-chain-no-escape", -- 68
		resolveResult("running", 7, chainedEscape) == "missed", -- 68
		"逃逸关：只走完航线、没越界 = 错过" -- 68
	) -- 68
	check( -- 69
		"resolve-escape-chain-crashed", -- 69
		resolveResult("crashed", -1, chainedEscape) == "crashed", -- 69
		"逃逸关：撞毁 = 撞毁" -- 69
	) -- 69
end -- 45
--- 1b) 时间流的相态守卫（S3.11）。
-- 
-- 为什么要有它：飞行用的是 tWorld = t0 + flightTime，飞行途中改 t0 等于把参考系整个挪走，
-- 行星会在飞行路径底下跳位。所以"能不能改日期"必须由**相态**决定，而不是由按钮决定。
local function testTimeWarpGuard() -- 78
	local level = testLevel() -- 79
	local core = createCore() -- 80
	check( -- 81
		"time-warp-aiming", -- 81
		coreTimeWarpAllowed(core), -- 81
		"Aiming 应允许改日期：phase=" .. core.phase -- 81
	) -- 81
	coreArm(core) -- 82
	check( -- 83
		"time-warp-armed", -- 83
		coreTimeWarpAllowed(core), -- 83
		"Armed 也应允许（瞄好了再挑日期）：phase=" .. core.phase -- 83
	) -- 83
	coreCancelArm(core) -- 84
	coreLaunch(core, {x = 6, y = -12}, level) -- 86
	check( -- 87
		"time-warp-flying", -- 87
		not coreTimeWarpAllowed(core), -- 87
		"Flying 必须禁止改日期：phase=" .. core.phase -- 87
	) -- 87
	local entered = false -- 89
	local frames = 0 -- 90
	while not entered and frames < 100000 do -- 90
		entered = coreUpdate(core, 1 / 60) -- 92
		frames = frames + 1 -- 93
		if core.phase == "Result" then -- 93
			break -- 94
		end -- 94
	end -- 94
	check( -- 96
		"time-warp-result", -- 96
		not coreTimeWarpAllowed(core), -- 96
		"Result 必须禁止改日期：phase=" .. core.phase -- 96
	) -- 96
end -- 78
--- 1c) 发射日期交棒（S3.12 修 bug：L4/L6 按下「发射」后行星跳回原位）。
-- 
-- 守两件事：① 交棒方向对（发射 clock→t0 / 重试 t0→clock）；
-- ② **`t0 + clock` 守恒** —— 这是"交棒瞬间画面不跳"的数学表述。
-- 引擎侧的端到端证据见 PROGRESS 会话 44（发射前后两张截图的像素差）。
local function testDateHandoff() -- 106
	local launch = coreHandoffDate(0, 180, true) -- 107
	check( -- 108
		"handoff-launch-t0", -- 108
		launch.t0 == 180 and launch.clock == 0, -- 108
		(("发射应交棒成 t0=" .. tostring(launch.t0)) .. " clock=") .. tostring(launch.clock) -- 108
	) -- 108
	local retry = coreHandoffDate(180, 0, false) -- 109
	check( -- 110
		"handoff-retry-clock", -- 110
		retry.t0 == 0 and retry.clock == 180, -- 110
		(("重试应交棒成 t0=" .. tostring(retry.t0)) .. " clock=") .. tostring(retry.clock) -- 110
	) -- 110
	check("handoff-sum-preserved-launch", 0 + 180 == launch.t0 + launch.clock, "交棒前后 t0+clock 必须守恒（发射）") -- 111
	check("handoff-sum-preserved-retry", 180 + 0 == retry.t0 + retry.clock, "交棒前后 t0+clock 必须守恒（重试）") -- 112
	local T = 400 -- 115
	local bodies = {{ -- 116
		gm = 0, -- 117
		radius = 1.4, -- 117
		orbitCenter = {x = 0, y = 0}, -- 118
		orbitRadius = 40, -- 118
		orbitPeriod = T, -- 118
		phase0 = 0, -- 119
		orbitDirection = 1 -- 119
	}} -- 119
	local level = { -- 121
		bodies = bodies, -- 122
		probeStart = {x = 0, y = 16}, -- 123
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 124
		escapeRadius = 900, -- 125
		maxSteps = 1500 -- 126
	} -- 126
	local ang = -20.1 * math.pi / 180 -- 129
	local burn = { -- 130
		x = math.cos(ang) * 19.8, -- 130
		y = math.sin(ang) * 19.8 -- 130
	} -- 130
	local a = createCore() -- 131
	a.t0 = 0 -- 132
	coreLaunch(a, burn, level) -- 133
	check( -- 134
		"launch-date-hits-at-zero", -- 134
		a.goalIndex >= 0, -- 134
		"t0=0 应命中：goalIndex=" .. tostring(a.goalIndex) -- 134
	) -- 134
	local b = createCore() -- 135
	b.t0 = T / 2 -- 136
	coreLaunch(b, burn, level) -- 137
	check( -- 138
		"launch-date-misses-at-half", -- 138
		b.goalIndex < 0, -- 138
		(("t0=" .. tostring(T / 2)) .. " 应打空：goalIndex=") .. tostring(b.goalIndex) -- 138
	) -- 138
end -- 106
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 142
	local level = testLevel() -- 143
	local core = createCore() -- 144
	coreLaunch(core, {x = 6, y = -12}, level) -- 146
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 147
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 148
	check( -- 149
		"launch-time-zero", -- 149
		core.flightTime == 0, -- 149
		"flightTime=" .. tostring(core.flightTime) -- 149
	) -- 149
	local before = core.flight ~= nil and #core.flight.points or 0 -- 152
	coreLaunch(core, {x = 0, y = -20}, level) -- 153
	local after = core.flight ~= nil and #core.flight.points or 0 -- 154
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 155
end -- 142
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 159
	local level = testLevel() -- 160
	local core = createCore() -- 161
	coreLaunch(core, {x = 6, y = -12}, level) -- 162
	local flight = core.flight -- 163
	if flight == nil then -- 163
		check("playback-flight", false, "no flight") -- 164
		return -- 164
	end -- 164
	local total = #flight.points - 1 -- 166
	check( -- 167
		"playback-start-index", -- 167
		coreProbeIndex(core) == 0, -- 167
		"idx=" .. tostring(coreProbeIndex(core)) -- 167
	) -- 167
	local entered = false -- 170
	local frames = 0 -- 171
	while not entered and frames < 100000 do -- 171
		entered = coreUpdate(core, 1 / 60) -- 173
		frames = frames + 1 -- 174
		if core.phase == "Result" then -- 174
			break -- 175
		end -- 175
	end -- 175
	check( -- 178
		"playback-enters-result", -- 178
		entered and core.phase == "Result", -- 178
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 178
	) -- 178
	check( -- 179
		"playback-final-index", -- 179
		coreProbeIndex(core) == total, -- 179
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 179
	) -- 179
	check( -- 180
		"playback-result-kind", -- 180
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 180
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 180
	) -- 180
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 183
	local actualRealSeconds = frames / 60 -- 184
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 185
	check( -- 186
		"playback-duration", -- 186
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 186
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 186
	) -- 186
end -- 159
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 191
	local level = testLevel() -- 192
	local core = createCore() -- 193
	coreRetry(core) -- 196
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 197
	coreLaunch(core, {x = 6, y = -12}, level) -- 199
	local entered = false -- 200
	local guard = 0 -- 201
	while not entered and guard < 100000 do -- 201
		entered = coreUpdate(core, 1 / 60) -- 203
		guard = guard + 1 -- 204
	end -- 204
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 206
	coreRetry(core) -- 208
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 209
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 210
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 211
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 212
	check( -- 213
		"retry-time-reset", -- 213
		core.flightTime == 0, -- 213
		"flightTime=" .. tostring(core.flightTime) -- 213
	) -- 213
	coreLaunch(core, {x = 0, y = -20}, level) -- 216
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 217
end -- 191
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 221
	local level = testLevel() -- 222
	local core = createCore() -- 223
	coreLaunch(core, {x = 6, y = -12}, level) -- 224
	local flight = core.flight -- 225
	if flight == nil then -- 225
		check("clamp-flight", false, "no flight") -- 226
		return -- 226
	end -- 226
	core.flightTime = -100 -- 228
	check( -- 229
		"clamp-negative", -- 229
		coreProbeIndex(core) == 0, -- 229
		"idx=" .. tostring(coreProbeIndex(core)) -- 229
	) -- 229
	core.flightTime = 1000000000 -- 231
	check( -- 232
		"clamp-huge", -- 232
		coreProbeIndex(core) == #flight.points - 1, -- 232
		"idx=" .. tostring(coreProbeIndex(core)) -- 232
	) -- 232
end -- 221
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 236
	local level = testLevel() -- 237
	local results = {} -- 238
	do -- 238
		local run = 0 -- 239
		while run < 2 do -- 239
			local core = createCore() -- 240
			coreLaunch(core, {x = 6, y = -12}, level) -- 241
			local guard = 0 -- 242
			while core.phase ~= "Result" and guard < 100000 do -- 242
				coreUpdate(core, 1 / 60) -- 244
				guard = guard + 1 -- 245
			end -- 245
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 247
			run = run + 1 -- 239
		end -- 239
	end -- 239
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 249
end -- 236
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 253
	local bodies = {{ -- 255
		gm = 0, -- 256
		radius = 1.2, -- 256
		orbitCenter = {x = 0, y = -20}, -- 256
		orbitRadius = 0, -- 256
		orbitPeriod = 0, -- 256
		phase0 = 0, -- 256
		orbitDirection = 1 -- 256
	}} -- 256
	local level = { -- 258
		bodies = bodies, -- 259
		probeStart = {x = 0, y = 16}, -- 260
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 261
		escapeRadius = 400, -- 262
		maxSteps = 1500 -- 263
	} -- 263
	local core = createCore() -- 266
	coreLaunch(core, {x = 0, y = -10}, level) -- 267
	check( -- 269
		"goal-found", -- 269
		core.goalIndex >= 0, -- 269
		"goalIndex=" .. tostring(core.goalIndex) -- 269
	) -- 269
	check( -- 270
		"goal-result-at-launch", -- 270
		core.result == "success", -- 270
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 270
	) -- 270
	local flight = core.flight -- 272
	if flight == nil or core.goalIndex < 0 then -- 272
		check("goal-flight", false, "no flight") -- 273
		return -- 273
	end -- 273
	local guard = 0 -- 276
	while core.phase ~= "Result" and guard < 100000 do -- 276
		coreUpdate(core, 1 / 60) -- 278
		guard = guard + 1 -- 279
	end -- 279
	check( -- 281
		"goal-ends-early", -- 281
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 281
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 281
	) -- 281
	check( -- 283
		"goal-still-success", -- 283
		core.result == "success", -- 283
		"result=" .. tostring(core.result) -- 283
	) -- 283
end -- 253
--- 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
-- 
-- 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
-- 状态机这一路必须自己站稳。
local function testArmed() -- 292
	local level = testLevel() -- 293
	local core = createCore() -- 294
	check( -- 295
		"arm-from-aiming", -- 295
		coreArm(core) == true and core.phase == "Armed", -- 295
		"phase=" .. core.phase -- 295
	) -- 295
	check( -- 296
		"arm-idempotent", -- 296
		coreArm(core) == false, -- 296
		"已在 Armed 时 coreArm 应返回 false（不能重复 arm）" -- 296
	) -- 296
	coreLaunch(core, {x = 0, y = -20}, level) -- 298
	check("launch-from-armed", core.phase == "Flying", "phase=" .. core.phase) -- 299
	local core2 = createCore() -- 301
	check( -- 302
		"cancel-guard", -- 302
		coreCancelArm(core2) == false, -- 302
		"Aiming 态调用 coreCancelArm 应返回 false" -- 302
	) -- 302
	coreArm(core2) -- 303
	check( -- 304
		"cancel-armed", -- 304
		coreCancelArm(core2) == true and core2.phase == "Aiming", -- 304
		"phase=" .. core2.phase -- 304
	) -- 304
	local core3 = createCore() -- 306
	coreArm(core3) -- 307
	coreRetry(core3) -- 308
	check("retry-clears-armed", core3.phase == "Aiming", "phase=" .. core3.phase) -- 309
end -- 292
function ____exports.runTests() -- 312
	testResolveResult() -- 313
	testTimeWarpGuard() -- 314
	testDateHandoff() -- 315
	testLaunch() -- 316
	testArmed() -- 317
	testPlayback() -- 318
	testRetry() -- 319
	testIndexClamp() -- 320
	testDeterministicCycle() -- 321
	testGoalTruncation() -- 322
	local lines = {} -- 324
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 325
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 326
	local limit = #failures < 12 and #failures or 12 -- 327
	do -- 327
		local i = 0 -- 328
		while i < limit do -- 328
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 329
			i = i + 1 -- 328
		end -- 328
	end -- 328
	return table.concat(lines, "\n") -- 331
end -- 312
return ____exports -- 312
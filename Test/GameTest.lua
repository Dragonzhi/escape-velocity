-- [ts]: GameTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Config = require("game.Config") -- 8
local FlightPlayback = ____Config.FlightPlayback -- 8
local PhysicsStep = ____Config.PhysicsStep -- 8
local SlowMoFloorDist = ____Config.SlowMoFloorDist -- 8
local SlowMoRadiusFactor = ____Config.SlowMoRadiusFactor -- 8
local ____Game = require("game.Game") -- 10
local anchorBodyIndex = ____Game.anchorBodyIndex -- 11
local calcFlightTelemetry = ____Game.calcFlightTelemetry -- 11
local coreArm = ____Game.coreArm -- 11
local coreBackToSelect = ____Game.coreBackToSelect -- 11
local coreCancelArm = ____Game.coreCancelArm -- 11
local coreHandoffDate = ____Game.coreHandoffDate -- 11
local coreLaunch = ____Game.coreLaunch -- 11
local coreProbeIndex = ____Game.coreProbeIndex -- 12
local coreRetry = ____Game.coreRetry -- 12
local coreTimeWarpAllowed = ____Game.coreTimeWarpAllowed -- 12
local coreToggleView = ____Game.coreToggleView -- 12
local coreUpdate = ____Game.coreUpdate -- 12
local createCore = ____Game.createCore -- 13
local resolveResult = ____Game.resolveResult -- 13
local shiftSpeedPow = ____Game.shiftSpeedPow -- 13
local slowMotionBody = ____Game.slowMotionBody -- 13
local speedRateOf = ____Game.speedRateOf -- 13
local failures = {} -- 21
local checks = 0 -- 22
local function check(name, ok, detail) -- 24
	checks = checks + 1 -- 25
	if not ok then -- 25
		failures[#failures + 1] = {name = name, detail = detail} -- 26
	end -- 26
end -- 24
local function testTimeControlBounds() -- 29
	check( -- 30
		"speed-min-step", -- 30
		shiftSpeedPow(0, -1, 1, -1) == -1, -- 30
		"慢速按钮应能从默认档降一级" -- 30
	) -- 30
	check( -- 31
		"speed-min-clamp", -- 31
		shiftSpeedPow(-1, -1, 1, -1) == -1, -- 31
		"最慢档不可继续降低" -- 31
	) -- 31
	check( -- 32
		"speed-max-step", -- 32
		shiftSpeedPow(0, -1, 1, 1) == 1, -- 32
		"加速按钮应能从默认档升一级" -- 32
	) -- 32
	check( -- 33
		"speed-max-clamp", -- 33
		shiftSpeedPow(1, -1, 1, 1) == 1, -- 33
		"最快档不可继续提升" -- 33
	) -- 33
	check( -- 34
		"speed-slow-real-rate", -- 34
		math.abs(speedRateOf(-1, 1) * 0.25 - 0.025) < 1e-9, -- 34
		"待机慢档应为 0.025×" -- 34
	) -- 34
	check( -- 35
		"speed-fast-real-rate", -- 35
		math.abs(speedRateOf(1, 1) * 0.25 - 2.5) < 1e-9, -- 35
		"待机快档应为 2.5×" -- 35
	) -- 35
end -- 29
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。
local function testLevel() -- 39
	local bodies = {{ -- 40
		gm = 900, -- 41
		radius = 2.2, -- 41
		orbitCenter = {x = 0, y = 0}, -- 42
		orbitRadius = 0, -- 42
		orbitPeriod = 0, -- 43
		phase0 = 0, -- 43
		orbitDirection = 1 -- 43
	}} -- 43
	return { -- 45
		bodies = bodies, -- 46
		probeStart = {x = 0, y = 16}, -- 47
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 48
		escapeRadius = 400, -- 49
		maxSteps = 1500 -- 50
	} -- 50
end -- 39
--- 1) 结算判定（手册 §5.8）。
local function testResolveResult() -- 55
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 56
	local planetGoal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 57
	check( -- 60
		"resolve-goal-first", -- 60
		resolveResult("crashed", 5, planetGoal) == "success", -- 60
		"到达目标应优先于撞毁（轨迹在到达点截断）" -- 60
	) -- 60
	check( -- 61
		"resolve-goal-running", -- 61
		resolveResult("running", 3, planetGoal) == "success", -- 61
		"到达目标即成功" -- 61
	) -- 61
	check( -- 64
		"resolve-escape-success", -- 64
		resolveResult("escaped", -1, escapeGoal) == "success", -- 64
		"逃逸目标达成 = 成功" -- 64
	) -- 64
	check( -- 65
		"resolve-escape-timeout", -- 65
		resolveResult("running", -1, escapeGoal) == "missed", -- 65
		"超时 = 错过" -- 65
	) -- 65
	check( -- 68
		"resolve-planet-escaped", -- 68
		resolveResult("escaped", -1, planetGoal) == "missed", -- 68
		"飞出边界但未到达目标 = 错过" -- 68
	) -- 68
	check( -- 69
		"resolve-planet-crashed", -- 69
		resolveResult("crashed", -1, planetGoal) == "crashed", -- 69
		"撞毁 = 撞毁" -- 69
	) -- 69
	local chainedEscape = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 0, tolerance = 4, label = "A"}, {planetIndex = 1, tolerance = 4, label = "B"}}} -- 72
	check( -- 76
		"resolve-escape-chain-both", -- 76
		resolveResult("escaped", 7, chainedEscape) == "success", -- 76
		"逃逸关：走完航线 + 越界 = 成功" -- 76
	) -- 76
	check( -- 77
		"resolve-escape-chain-no-route", -- 77
		resolveResult("escaped", -1, chainedEscape) == "missed", -- 77
		"逃逸关：只有越界、没走完航线 = 错过" -- 77
	) -- 77
	check( -- 78
		"resolve-escape-chain-no-escape", -- 78
		resolveResult("running", 7, chainedEscape) == "missed", -- 78
		"逃逸关：只走完航线、没越界 = 错过" -- 78
	) -- 78
	check( -- 79
		"resolve-escape-chain-crashed", -- 79
		resolveResult("crashed", -1, chainedEscape) == "crashed", -- 79
		"逃逸关：撞毁 = 撞毁" -- 79
	) -- 79
end -- 55
--- 1b) 时间流的相态守卫（S3.11）。
-- 
-- 为什么要有它：飞行用的是 tWorld = t0 + flightTime，飞行途中改 t0 等于把参考系整个挪走，
-- 行星会在飞行路径底下跳位。所以"能不能改日期"必须由**相态**决定，而不是由按钮决定。
local function testTimeWarpGuard() -- 88
	local level = testLevel() -- 89
	local core = createCore() -- 90
	check( -- 91
		"time-warp-aiming", -- 91
		coreTimeWarpAllowed(core), -- 91
		"Aiming 应允许改日期：phase=" .. core.phase -- 91
	) -- 91
	coreArm(core) -- 92
	check( -- 93
		"time-warp-armed", -- 93
		coreTimeWarpAllowed(core), -- 93
		"Armed 也应允许（瞄好了再挑日期）：phase=" .. core.phase -- 93
	) -- 93
	coreCancelArm(core) -- 94
	coreLaunch(core, {x = 6, y = -12}, level) -- 96
	check( -- 97
		"time-warp-flying", -- 97
		not coreTimeWarpAllowed(core), -- 97
		"Flying 必须禁止改日期：phase=" .. core.phase -- 97
	) -- 97
	local entered = false -- 99
	local frames = 0 -- 100
	while not entered and frames < 100000 do -- 100
		entered = coreUpdate(core, 1 / 60) -- 102
		frames = frames + 1 -- 103
		if core.phase == "Result" then -- 103
			break -- 104
		end -- 104
	end -- 104
	check( -- 106
		"time-warp-result", -- 106
		not coreTimeWarpAllowed(core), -- 106
		"Result 必须禁止改日期：phase=" .. core.phase -- 106
	) -- 106
end -- 88
--- 1c) 发射日期交棒（S3.12 修 bug：L4/L6 按下「发射」后行星跳回原位）。
-- 
-- 守两件事：① 交棒方向对（发射 clock→t0 / 重试 t0→clock）；
-- ② **`t0 + clock` 守恒** —— 这是"交棒瞬间画面不跳"的数学表述。
-- 引擎侧的端到端证据见 PROGRESS 会话 44（发射前后两张截图的像素差）。
local function testDateHandoff() -- 116
	local launch = coreHandoffDate(0, 180, true) -- 117
	check( -- 118
		"handoff-launch-t0", -- 118
		launch.t0 == 180 and launch.clock == 0, -- 118
		(("发射应交棒成 t0=" .. tostring(launch.t0)) .. " clock=") .. tostring(launch.clock) -- 118
	) -- 118
	local retry = coreHandoffDate(180, 0, false) -- 119
	check( -- 120
		"handoff-retry-clock", -- 120
		retry.t0 == 0 and retry.clock == 180, -- 120
		(("重试应交棒成 t0=" .. tostring(retry.t0)) .. " clock=") .. tostring(retry.clock) -- 120
	) -- 120
	check("handoff-sum-preserved-launch", 0 + 180 == launch.t0 + launch.clock, "交棒前后 t0+clock 必须守恒（发射）") -- 121
	check("handoff-sum-preserved-retry", 180 + 0 == retry.t0 + retry.clock, "交棒前后 t0+clock 必须守恒（重试）") -- 122
	local T = 400 -- 125
	local bodies = {{ -- 126
		gm = 0, -- 127
		radius = 1.4, -- 127
		orbitCenter = {x = 0, y = 0}, -- 128
		orbitRadius = 40, -- 128
		orbitPeriod = T, -- 128
		phase0 = 0, -- 129
		orbitDirection = 1 -- 129
	}} -- 129
	local level = { -- 131
		bodies = bodies, -- 132
		probeStart = {x = 0, y = 16}, -- 133
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 134
		escapeRadius = 900, -- 135
		maxSteps = 1500 -- 136
	} -- 136
	local ang = -20.1 * math.pi / 180 -- 139
	local burn = { -- 140
		x = math.cos(ang) * 19.8, -- 140
		y = math.sin(ang) * 19.8 -- 140
	} -- 140
	local a = createCore() -- 141
	a.t0 = 0 -- 142
	coreLaunch(a, burn, level) -- 143
	check( -- 144
		"launch-date-hits-at-zero", -- 144
		a.goalIndex >= 0, -- 144
		"t0=0 应命中：goalIndex=" .. tostring(a.goalIndex) -- 144
	) -- 144
	local b = createCore() -- 145
	b.t0 = T / 2 -- 146
	coreLaunch(b, burn, level) -- 147
	check( -- 148
		"launch-date-misses-at-half", -- 148
		b.goalIndex < 0, -- 148
		(("t0=" .. tostring(T / 2)) .. " 应打空：goalIndex=") .. tostring(b.goalIndex) -- 148
	) -- 148
end -- 116
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 152
	local level = testLevel() -- 153
	local core = createCore() -- 154
	coreLaunch(core, {x = 6, y = -12}, level) -- 156
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 157
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 158
	check( -- 159
		"launch-time-zero", -- 159
		core.flightTime == 0, -- 159
		"flightTime=" .. tostring(core.flightTime) -- 159
	) -- 159
	local before = core.flight ~= nil and #core.flight.points or 0 -- 162
	coreLaunch(core, {x = 0, y = -20}, level) -- 163
	local after = core.flight ~= nil and #core.flight.points or 0 -- 164
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 165
end -- 152
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 169
	local level = testLevel() -- 170
	local core = createCore() -- 171
	coreLaunch(core, {x = 6, y = -12}, level) -- 172
	local flight = core.flight -- 173
	if flight == nil then -- 173
		check("playback-flight", false, "no flight") -- 174
		return -- 174
	end -- 174
	local total = #flight.points - 1 -- 176
	check( -- 177
		"playback-start-index", -- 177
		coreProbeIndex(core) == 0, -- 177
		"idx=" .. tostring(coreProbeIndex(core)) -- 177
	) -- 177
	local entered = false -- 180
	local frames = 0 -- 181
	while not entered and frames < 100000 do -- 181
		entered = coreUpdate(core, 1 / 60) -- 183
		frames = frames + 1 -- 184
		if core.phase == "Result" then -- 184
			break -- 185
		end -- 185
	end -- 185
	check( -- 188
		"playback-enters-result", -- 188
		entered and core.phase == "Result", -- 188
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 188
	) -- 188
	check( -- 189
		"playback-final-index", -- 189
		coreProbeIndex(core) == total, -- 189
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 189
	) -- 189
	check( -- 190
		"playback-result-kind", -- 190
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 190
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 190
	) -- 190
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 193
	local actualRealSeconds = frames / 60 -- 194
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 195
	check( -- 196
		"playback-duration", -- 196
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 196
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 196
	) -- 196
end -- 169
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 201
	local level = testLevel() -- 202
	local core = createCore() -- 203
	coreRetry(core) -- 206
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 207
	coreLaunch(core, {x = 6, y = -12}, level) -- 209
	local entered = false -- 210
	local guard = 0 -- 211
	while not entered and guard < 100000 do -- 211
		entered = coreUpdate(core, 1 / 60) -- 213
		guard = guard + 1 -- 214
	end -- 214
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 216
	coreRetry(core) -- 218
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 219
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 220
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 221
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 222
	check( -- 223
		"retry-time-reset", -- 223
		core.flightTime == 0, -- 223
		"flightTime=" .. tostring(core.flightTime) -- 223
	) -- 223
	coreLaunch(core, {x = 0, y = -20}, level) -- 226
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 227
end -- 201
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 231
	local level = testLevel() -- 232
	local core = createCore() -- 233
	coreLaunch(core, {x = 6, y = -12}, level) -- 234
	local flight = core.flight -- 235
	if flight == nil then -- 235
		check("clamp-flight", false, "no flight") -- 236
		return -- 236
	end -- 236
	core.flightTime = -100 -- 238
	check( -- 239
		"clamp-negative", -- 239
		coreProbeIndex(core) == 0, -- 239
		"idx=" .. tostring(coreProbeIndex(core)) -- 239
	) -- 239
	core.flightTime = 1000000000 -- 241
	check( -- 242
		"clamp-huge", -- 242
		coreProbeIndex(core) == #flight.points - 1, -- 242
		"idx=" .. tostring(coreProbeIndex(core)) -- 242
	) -- 242
end -- 231
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 246
	local level = testLevel() -- 247
	local results = {} -- 248
	do -- 248
		local run = 0 -- 249
		while run < 2 do -- 249
			local core = createCore() -- 250
			coreLaunch(core, {x = 6, y = -12}, level) -- 251
			local guard = 0 -- 252
			while core.phase ~= "Result" and guard < 100000 do -- 252
				coreUpdate(core, 1 / 60) -- 254
				guard = guard + 1 -- 255
			end -- 255
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 257
			run = run + 1 -- 249
		end -- 249
	end -- 249
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 259
end -- 246
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 263
	local bodies = {{ -- 265
		gm = 0, -- 266
		radius = 1.2, -- 266
		orbitCenter = {x = 0, y = -20}, -- 266
		orbitRadius = 0, -- 266
		orbitPeriod = 0, -- 266
		phase0 = 0, -- 266
		orbitDirection = 1 -- 266
	}} -- 266
	local level = { -- 268
		bodies = bodies, -- 269
		probeStart = {x = 0, y = 16}, -- 270
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 271
		escapeRadius = 400, -- 272
		maxSteps = 1500 -- 273
	} -- 273
	local core = createCore() -- 276
	coreLaunch(core, {x = 0, y = -10}, level) -- 277
	check( -- 279
		"goal-found", -- 279
		core.goalIndex >= 0, -- 279
		"goalIndex=" .. tostring(core.goalIndex) -- 279
	) -- 279
	check( -- 280
		"goal-result-at-launch", -- 280
		core.result == "success", -- 280
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 280
	) -- 280
	local flight = core.flight -- 282
	if flight == nil or core.goalIndex < 0 then -- 282
		check("goal-flight", false, "no flight") -- 283
		return -- 283
	end -- 283
	local guard = 0 -- 286
	while core.phase ~= "Result" and guard < 100000 do -- 286
		coreUpdate(core, 1 / 60) -- 288
		guard = guard + 1 -- 289
	end -- 289
	check( -- 291
		"goal-ends-early", -- 291
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 291
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 291
	) -- 291
	check( -- 293
		"goal-still-success", -- 293
		core.result == "success", -- 293
		"result=" .. tostring(core.result) -- 293
	) -- 293
end -- 263
--- 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
-- 
-- 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
-- 状态机这一路必须自己站稳。
local function testArmed() -- 302
	local level = testLevel() -- 303
	local core = createCore() -- 304
	check( -- 305
		"arm-from-aiming", -- 305
		coreArm(core) == true and core.phase == "Armed", -- 305
		"phase=" .. core.phase -- 305
	) -- 305
	check( -- 306
		"arm-idempotent", -- 306
		coreArm(core) == false, -- 306
		"已在 Armed 时 coreArm 应返回 false（不能重复 arm）" -- 306
	) -- 306
	coreLaunch(core, {x = 0, y = -20}, level) -- 308
	check("launch-from-armed", core.phase == "Flying", "phase=" .. core.phase) -- 309
	local core2 = createCore() -- 311
	check( -- 312
		"cancel-guard", -- 312
		coreCancelArm(core2) == false, -- 312
		"Aiming 态调用 coreCancelArm 应返回 false" -- 312
	) -- 312
	coreArm(core2) -- 313
	check( -- 314
		"cancel-armed", -- 314
		coreCancelArm(core2) == true and core2.phase == "Aiming", -- 314
		"phase=" .. core2.phase -- 314
	) -- 314
	local core3 = createCore() -- 316
	coreArm(core3) -- 317
	coreRetry(core3) -- 318
	check("retry-clears-armed", core3.phase == "Aiming", "phase=" .. core3.phase) -- 319
end -- 302
--- 12) 视图模式（S3.15）：2D 规划 ⇄ 3D 观赏。
-- 
-- 设计稿第 4 条的自动切换**必须是相态流转的副产品**，不是 UI 的补丁：
--   Aiming/Armed → 2D；coreLaunch → 3D；Result 留 3D；coreRetry → 2D；coreBackToSelect → 2D。
-- 手动切换（右下角按钮）走 `coreToggleView`，状态仍然只有一个（`GameCore.viewMode`）。
-- 
-- 引擎侧端到端证据（截图 + 日志行）见 PROGRESS 会话 47。
local function testViewMode() -- 331
	local level = testLevel() -- 332
	local core = createCore() -- 333
	check("view-aiming-2d", core.viewMode == "2D", "进关应为 2D：viewMode=" .. core.viewMode) -- 334
	coreArm(core) -- 336
	check("view-armed-2d", core.viewMode == "2D", "Armed（还没发射）应留 2D：viewMode=" .. core.viewMode) -- 337
	local flipped = coreToggleView(core) -- 340
	check("view-toggle-to-3d", flipped == "3D" and core.viewMode == "3D", (("flip=" .. flipped) .. " viewMode=") .. core.viewMode) -- 341
	check( -- 342
		"view-toggle-back", -- 342
		coreToggleView(core) == "2D" and core.viewMode == "2D", -- 342
		"viewMode=" .. core.viewMode -- 342
	) -- 342
	coreToggleView(core) -- 345
	coreLaunch(core, {x = 6, y = -12}, level) -- 346
	check("view-launch-3d", core.viewMode == "3D" and core.phase == "Flying", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 347
	local guard = 0 -- 350
	while core.phase ~= "Result" and guard < 100000 do -- 350
		coreUpdate(core, 1 / 60) -- 352
		guard = guard + 1 -- 353
	end -- 353
	check("view-result-3d", core.viewMode == "3D" and core.phase == "Result", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 355
	coreRetry(core) -- 358
	check("view-retry-2d", core.viewMode == "2D" and core.phase == "Aiming", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 359
	local core2 = createCore() -- 364
	coreLaunch(core2, {x = 0, y = -20}, level) -- 365
	local guard2 = 0 -- 366
	while core2.phase ~= "Result" and guard2 < 100000 do -- 366
		coreUpdate(core2, 1 / 60) -- 368
		guard2 = guard2 + 1 -- 369
	end -- 369
	check( -- 371
		"view-back-to-select-2d", -- 371
		coreBackToSelect(core2) == true and core2.viewMode == "2D", -- 371
		(("viewMode=" .. core2.viewMode) .. " phase=") .. core2.phase -- 371
	) -- 371
end -- 331
--- 13) 掠过自动慢动作（S3.17）：触发口径「最近接近任何天体」+ 播放倍速。
-- 
-- 守四件事：① 阈值 = max(半径 × 5, 8)，锚点（太阳）不参与；② 阈值内取**最近**的天体；
-- ③ 慢动作 = 手动档 × 1/4（默认 2× ⇒ 0.5× 实时，不是 0.25× 实时也不是 1.5×）；
-- ④ **同样帧数下推进的世界时间更少** —— 这是"真的放慢了"的确定性表述。
local function testSlowMotion() -- 382
	local bodies = {{ -- 384
		gm = 72000, -- 385
		radius = 28, -- 385
		orbitCenter = {x = 0, y = 0}, -- 385
		orbitRadius = 0, -- 385
		orbitPeriod = 0, -- 385
		phase0 = 0, -- 385
		orbitDirection = 1 -- 385
	}, { -- 385
		gm = 0, -- 386
		radius = 4.63, -- 386
		orbitCenter = {x = 0, y = 0}, -- 386
		orbitRadius = 60, -- 386
		orbitPeriod = 600, -- 386
		phase0 = 0, -- 386
		orbitDirection = 1 -- 386
	}} -- 386
	local anchor = anchorBodyIndex(bodies) -- 388
	check( -- 389
		"slowmo-anchor-sun", -- 389
		anchor == 0, -- 389
		("anchor=" .. tostring(anchor)) .. "（没有 host 链 ⇒ 不绕转且 gm 最大的太阳）" -- 389
	) -- 389
	local hostChain = {bodies[1], { -- 392
		gm = 2162, -- 394
		radius = 0.0034, -- 394
		orbitCenter = {x = 0, y = 0}, -- 394
		orbitRadius = 80, -- 394
		orbitPeriod = 16.755, -- 394
		phase0 = math.pi / 2, -- 394
		orbitDirection = 1 -- 394
	}, { -- 394
		gm = 2.66, -- 395
		radius = 0.00093, -- 395
		orbitCenter = {x = 0, y = 0}, -- 395
		orbitRadius = 0.2056, -- 395
		orbitPeriod = 1.2593, -- 395
		phase0 = 0, -- 395
		orbitDirection = 1, -- 395
		host = nil -- 395
	}} -- 395
	hostChain[3].host = hostChain[2] -- 398
	check( -- 399
		"anchor-prefers-host", -- 399
		anchorBodyIndex(hostChain) == 1, -- 399
		("anchor=" .. tostring(anchorBodyIndex(hostChain))) .. "（L1：月球 host = 地球 ⇒ 锚点必须是地球，不能是太阳）" -- 400
	) -- 400
	check( -- 401
		"anchor-host-beats-sun", -- 401
		anchorBodyIndex(hostChain) ~= 0, -- 401
		"锚点不能是太阳（太阳 gm 更大但不在宿主链上）" -- 402
	) -- 402
	local threshold = math.max(4.63 * SlowMoRadiusFactor, SlowMoFloorDist) -- 405
	check( -- 406
		"slowmo-threshold-value", -- 406
		math.abs(threshold - 23.15) < 1e-9, -- 406
		"threshold=" .. tostring(threshold) -- 406
	) -- 406
	check( -- 407
		"slowmo-outside", -- 407
		slowMotionBody(bodies, {x = 30, y = 0}, 0, anchor) == -1, -- 407
		"距行星 30 > 23.15 不该触发" -- 407
	) -- 407
	check( -- 408
		"slowmo-inside", -- 408
		slowMotionBody(bodies, {x = 50, y = 0}, 0, anchor) == 1, -- 408
		"距行星 10 < 23.15 应触发" -- 408
	) -- 408
	check( -- 410
		"slowmo-anchor-excluded", -- 410
		slowMotionBody(bodies, {x = 20, y = 0}, 0, anchor) == -1, -- 410
		"太阳（锚点）即使在阈值内也不触发" -- 411
	) -- 411
	local tiny = {bodies[1], { -- 413
		gm = 0, -- 415
		radius = 1, -- 415
		orbitCenter = {x = 0, y = 0}, -- 415
		orbitRadius = 60, -- 415
		orbitPeriod = 600, -- 415
		phase0 = 0, -- 415
		orbitDirection = 1 -- 415
	}} -- 415
	check( -- 417
		"slowmo-floor-in", -- 417
		slowMotionBody(tiny, {x = 55, y = 0}, 0, anchor) == 1, -- 417
		"距 5 < 地板 8 ⇒ 触发" -- 417
	) -- 417
	check( -- 418
		"slowmo-floor-out", -- 418
		slowMotionBody(tiny, {x = 50, y = 0}, 0, anchor) == -1, -- 418
		"距 10 > 地板 8 ⇒ 不触发" -- 418
	) -- 418
	local two = {bodies[1], { -- 420
		gm = 0, -- 422
		radius = 4.63, -- 422
		orbitCenter = {x = 0, y = 0}, -- 422
		orbitRadius = 60, -- 422
		orbitPeriod = 600, -- 422
		phase0 = 0, -- 422
		orbitDirection = 1 -- 422
	}, { -- 422
		gm = 0, -- 423
		radius = 3.04, -- 423
		orbitCenter = {x = 0, y = 0}, -- 423
		orbitRadius = 60, -- 423
		orbitPeriod = 600, -- 423
		phase0 = 20 * math.pi / 180, -- 423
		orbitDirection = 1 -- 423
	}} -- 423
	check( -- 425
		"slowmo-nearest-a", -- 425
		slowMotionBody(two, {x = 58, y = 10}, 0, anchor) == 1, -- 425
		"离 1 号更近 ⇒ 选 1 号" -- 425
	) -- 425
	check( -- 426
		"slowmo-nearest-b", -- 426
		slowMotionBody(two, {x = 57, y = 15}, 0, anchor) == 2, -- 426
		"离 2 号更近 ⇒ 选 2 号" -- 426
	) -- 426
end -- 382
--- 13b) 播放倍速：手动档 1/2/4 × 慢动作 1/4；同样帧数下世界时间更少。
local function testPlaybackSpeed() -- 430
	local level = testLevel() -- 431
	local core = createCore() -- 434
	check( -- 435
		"playback-default", -- 435
		core.playback == FlightPlayback and core.playback == 2, -- 435
		"playback=" .. tostring(core.playback) -- 435
	) -- 435
	coreLaunch(core, {x = 6, y = -12}, level) -- 436
	core.playback = 4 -- 437
	local t0 = core.flightTime -- 438
	do -- 438
		local i = 0 -- 439
		while i < 60 do -- 439
			coreUpdate(core, 1 / 60) -- 439
			i = i + 1 -- 439
		end -- 439
	end -- 439
	check( -- 440
		"playback-4x", -- 440
		math.abs(core.flightTime - t0 - 4) < 1e-9, -- 440
		"60 帧 × 1/60 秒 × 4× = 4.000，实际 Δt=" .. __TS__NumberToFixed(core.flightTime - t0, 3) -- 441
	) -- 441
	core.slowmo = true -- 444
	local t1 = core.flightTime -- 445
	do -- 445
		local i = 0 -- 446
		while i < 60 do -- 446
			coreUpdate(core, 1 / 60) -- 446
			i = i + 1 -- 446
		end -- 446
	end -- 446
	check( -- 447
		"playback-slowmo-quarter", -- 447
		math.abs(core.flightTime - t1 - 1) < 1e-9, -- 447
		"4× 慢动作 60 帧应推进 1.000，实际 Δt=" .. __TS__NumberToFixed(core.flightTime - t1, 3) -- 448
	) -- 448
	local core2 = createCore() -- 451
	coreLaunch(core2, {x = 6, y = -12}, level) -- 452
	core2.slowmo = true -- 453
	local t2 = core2.flightTime -- 454
	do -- 454
		local i = 0 -- 455
		while i < 60 do -- 455
			coreUpdate(core2, 1 / 60) -- 455
			i = i + 1 -- 455
		end -- 455
	end -- 455
	check( -- 456
		"playback-default-slowmo-half", -- 456
		math.abs(core2.flightTime - t2 - 0.5) < 1e-9, -- 456
		"2× 慢动作 60 帧应推进 0.500（≈0.5× 实时），实际 Δt=" .. __TS__NumberToFixed(core2.flightTime - t2, 3) -- 457
	) -- 457
	local core3 = createCore() -- 460
	coreLaunch(core3, {x = 6, y = -12}, level) -- 461
	do -- 461
		local i = 0 -- 462
		while i < 30 do -- 462
			coreUpdate(core3, 1 / 60) -- 462
			i = i + 1 -- 462
		end -- 462
	end -- 462
	check( -- 463
		"playback-no-level", -- 463
		not core3.slowmo and core3.slowmoBody == -1, -- 463
		(("slowmo=" .. tostring(core3.slowmo)) .. " body=") .. tostring(core3.slowmoBody) -- 463
	) -- 463
	local bodies = {{ -- 466
		gm = 72000, -- 467
		radius = 28, -- 467
		orbitCenter = {x = 0, y = 0}, -- 467
		orbitRadius = 0, -- 467
		orbitPeriod = 0, -- 467
		phase0 = 0, -- 467
		orbitDirection = 1 -- 467
	}, { -- 467
		gm = 0, -- 468
		radius = 4.63, -- 468
		orbitCenter = {x = 0, y = 0}, -- 468
		orbitRadius = 60, -- 468
		orbitPeriod = 600, -- 468
		phase0 = 0, -- 468
		orbitDirection = 1 -- 468
	}} -- 468
	local nearLevel = { -- 470
		bodies = bodies, -- 471
		probeStart = {x = 50, y = 0}, -- 472
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 473
		escapeRadius = 400, -- 474
		maxSteps = 600 -- 475
	} -- 475
	local core4 = createCore() -- 477
	coreLaunch(core4, {x = 0, y = 5}, nearLevel) -- 478
	local t3 = core4.flightTime -- 479
	do -- 479
		local i = 0 -- 480
		while i < 60 do -- 480
			coreUpdate(core4, 1 / 60, nearLevel) -- 480
			i = i + 1 -- 480
		end -- 480
	end -- 480
	check( -- 481
		"playback-level-driven", -- 481
		core4.slowmo and core4.slowmoBody == 1 and math.abs(core4.flightTime - t3 - 0.5) < 1e-9, -- 481
		((((("slowmo=" .. tostring(core4.slowmo)) .. " body=") .. tostring(core4.slowmoBody)) .. " Δt=") .. __TS__NumberToFixed(core4.flightTime - t3, 3)) .. " 期望 0.500" -- 482
	) -- 482
end -- 430
--- 15) 街机星尘收集与重置（纯函数 / 状态机判定）。
local function testArcadeStars() -- 486
	local stars = {{x = 0, y = 10}, {x = 0, y = 5}, {x = 100, y = 100}} -- 487
	local level = { -- 492
		bodies = {{ -- 493
			gm = 0, -- 493
			radius = 1, -- 493
			orbitCenter = {x = 0, y = 0}, -- 493
			orbitRadius = 0, -- 493
			orbitPeriod = 0, -- 493
			phase0 = 0, -- 493
			orbitDirection = 1 -- 493
		}}, -- 493
		probeStart = {x = 0, y = 15}, -- 494
		goal = {kind = "planet", planetIndex = 0, tolerance = 2}, -- 495
		escapeRadius = 200, -- 496
		maxSteps = 1000, -- 497
		stars = stars -- 498
	} -- 498
	local core = createCore(0.016, stars) -- 501
	check("arcade-stars-initial-uncollected", #core.collectedStars == 3 and not core.collectedStars[1] and not core.collectedStars[2], "开局所有星尘未收集") -- 502
	coreLaunch(core, {x = 0, y = -10}, level) -- 505
	check("arcade-launch-flying", core.phase == "Flying", "进入飞行相态") -- 506
	do -- 506
		local i = 0 -- 509
		while i < 40 do -- 509
			coreUpdate(core, 0.016, level) -- 510
			i = i + 1 -- 509
		end -- 509
	end -- 509
	check("arcade-star-0-collected", core.collectedStars[1] == true, "第1颗星尘应被收集") -- 512
	check("arcade-star-1-collected", core.collectedStars[2] == true, "第2颗星尘应被收集") -- 513
	check("arcade-star-2-missed", core.collectedStars[3] == false, "第3颗远处的星不应被收集") -- 514
	local telem = calcFlightTelemetry(core, level) -- 516
	check( -- 517
		"arcade-telemetry-stars", -- 517
		telem.starsCollected == 2, -- 517
		"遥测星数应为 2，实际为 " .. tostring(telem.starsCollected) -- 517
	) -- 517
	coreRetry(core) -- 520
	check("arcade-retry-stars-reset", not core.collectedStars[1] and not core.collectedStars[2] and not core.collectedStars[3], "重试后星尘必须全重置") -- 521
end -- 486
function ____exports.runTests() -- 524
	testTimeControlBounds() -- 525
	testResolveResult() -- 526
	testTimeWarpGuard() -- 527
	testDateHandoff() -- 528
	testLaunch() -- 529
	testArmed() -- 530
	testPlayback() -- 531
	testRetry() -- 532
	testIndexClamp() -- 533
	testDeterministicCycle() -- 534
	testGoalTruncation() -- 535
	testViewMode() -- 536
	testSlowMotion() -- 537
	testPlaybackSpeed() -- 538
	testArcadeStars() -- 539
	local lines = {} -- 541
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 542
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 543
	local limit = #failures < 12 and #failures or 12 -- 544
	do -- 544
		local i = 0 -- 545
		while i < limit do -- 545
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 546
			i = i + 1 -- 545
		end -- 545
	end -- 545
	return table.concat(lines, "\n") -- 548
end -- 524
return ____exports -- 524
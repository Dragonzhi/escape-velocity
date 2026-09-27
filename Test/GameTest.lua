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
local slowMotionBody = ____Game.slowMotionBody -- 13
local failures = {} -- 21
local checks = 0 -- 22
local function check(name, ok, detail) -- 24
	checks = checks + 1 -- 25
	if not ok then -- 25
		failures[#failures + 1] = {name = name, detail = detail} -- 26
	end -- 26
end -- 24
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。
local function testLevel() -- 30
	local bodies = {{ -- 31
		gm = 900, -- 32
		radius = 2.2, -- 32
		orbitCenter = {x = 0, y = 0}, -- 33
		orbitRadius = 0, -- 33
		orbitPeriod = 0, -- 34
		phase0 = 0, -- 34
		orbitDirection = 1 -- 34
	}} -- 34
	return { -- 36
		bodies = bodies, -- 37
		probeStart = {x = 0, y = 16}, -- 38
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 39
		escapeRadius = 400, -- 40
		maxSteps = 1500 -- 41
	} -- 41
end -- 30
--- 1) 结算判定（手册 §5.8）。
local function testResolveResult() -- 46
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 47
	local planetGoal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 48
	check( -- 51
		"resolve-goal-first", -- 51
		resolveResult("crashed", 5, planetGoal) == "success", -- 51
		"到达目标应优先于撞毁（轨迹在到达点截断）" -- 51
	) -- 51
	check( -- 52
		"resolve-goal-running", -- 52
		resolveResult("running", 3, planetGoal) == "success", -- 52
		"到达目标即成功" -- 52
	) -- 52
	check( -- 55
		"resolve-escape-success", -- 55
		resolveResult("escaped", -1, escapeGoal) == "success", -- 55
		"逃逸目标达成 = 成功" -- 55
	) -- 55
	check( -- 56
		"resolve-escape-timeout", -- 56
		resolveResult("running", -1, escapeGoal) == "missed", -- 56
		"超时 = 错过" -- 56
	) -- 56
	check( -- 59
		"resolve-planet-escaped", -- 59
		resolveResult("escaped", -1, planetGoal) == "missed", -- 59
		"飞出边界但未到达目标 = 错过" -- 59
	) -- 59
	check( -- 60
		"resolve-planet-crashed", -- 60
		resolveResult("crashed", -1, planetGoal) == "crashed", -- 60
		"撞毁 = 撞毁" -- 60
	) -- 60
	local chainedEscape = {kind = "escape", planetIndex = -1, tolerance = 0, chain = {{planetIndex = 0, tolerance = 4, label = "A"}, {planetIndex = 1, tolerance = 4, label = "B"}}} -- 63
	check( -- 67
		"resolve-escape-chain-both", -- 67
		resolveResult("escaped", 7, chainedEscape) == "success", -- 67
		"逃逸关：走完航线 + 越界 = 成功" -- 67
	) -- 67
	check( -- 68
		"resolve-escape-chain-no-route", -- 68
		resolveResult("escaped", -1, chainedEscape) == "missed", -- 68
		"逃逸关：只有越界、没走完航线 = 错过" -- 68
	) -- 68
	check( -- 69
		"resolve-escape-chain-no-escape", -- 69
		resolveResult("running", 7, chainedEscape) == "missed", -- 69
		"逃逸关：只走完航线、没越界 = 错过" -- 69
	) -- 69
	check( -- 70
		"resolve-escape-chain-crashed", -- 70
		resolveResult("crashed", -1, chainedEscape) == "crashed", -- 70
		"逃逸关：撞毁 = 撞毁" -- 70
	) -- 70
end -- 46
--- 1b) 时间流的相态守卫（S3.11）。
-- 
-- 为什么要有它：飞行用的是 tWorld = t0 + flightTime，飞行途中改 t0 等于把参考系整个挪走，
-- 行星会在飞行路径底下跳位。所以"能不能改日期"必须由**相态**决定，而不是由按钮决定。
local function testTimeWarpGuard() -- 79
	local level = testLevel() -- 80
	local core = createCore() -- 81
	check( -- 82
		"time-warp-aiming", -- 82
		coreTimeWarpAllowed(core), -- 82
		"Aiming 应允许改日期：phase=" .. core.phase -- 82
	) -- 82
	coreArm(core) -- 83
	check( -- 84
		"time-warp-armed", -- 84
		coreTimeWarpAllowed(core), -- 84
		"Armed 也应允许（瞄好了再挑日期）：phase=" .. core.phase -- 84
	) -- 84
	coreCancelArm(core) -- 85
	coreLaunch(core, {x = 6, y = -12}, level) -- 87
	check( -- 88
		"time-warp-flying", -- 88
		not coreTimeWarpAllowed(core), -- 88
		"Flying 必须禁止改日期：phase=" .. core.phase -- 88
	) -- 88
	local entered = false -- 90
	local frames = 0 -- 91
	while not entered and frames < 100000 do -- 91
		entered = coreUpdate(core, 1 / 60) -- 93
		frames = frames + 1 -- 94
		if core.phase == "Result" then -- 94
			break -- 95
		end -- 95
	end -- 95
	check( -- 97
		"time-warp-result", -- 97
		not coreTimeWarpAllowed(core), -- 97
		"Result 必须禁止改日期：phase=" .. core.phase -- 97
	) -- 97
end -- 79
--- 1c) 发射日期交棒（S3.12 修 bug：L4/L6 按下「发射」后行星跳回原位）。
-- 
-- 守两件事：① 交棒方向对（发射 clock→t0 / 重试 t0→clock）；
-- ② **`t0 + clock` 守恒** —— 这是"交棒瞬间画面不跳"的数学表述。
-- 引擎侧的端到端证据见 PROGRESS 会话 44（发射前后两张截图的像素差）。
local function testDateHandoff() -- 107
	local launch = coreHandoffDate(0, 180, true) -- 108
	check( -- 109
		"handoff-launch-t0", -- 109
		launch.t0 == 180 and launch.clock == 0, -- 109
		(("发射应交棒成 t0=" .. tostring(launch.t0)) .. " clock=") .. tostring(launch.clock) -- 109
	) -- 109
	local retry = coreHandoffDate(180, 0, false) -- 110
	check( -- 111
		"handoff-retry-clock", -- 111
		retry.t0 == 0 and retry.clock == 180, -- 111
		(("重试应交棒成 t0=" .. tostring(retry.t0)) .. " clock=") .. tostring(retry.clock) -- 111
	) -- 111
	check("handoff-sum-preserved-launch", 0 + 180 == launch.t0 + launch.clock, "交棒前后 t0+clock 必须守恒（发射）") -- 112
	check("handoff-sum-preserved-retry", 180 + 0 == retry.t0 + retry.clock, "交棒前后 t0+clock 必须守恒（重试）") -- 113
	local T = 400 -- 116
	local bodies = {{ -- 117
		gm = 0, -- 118
		radius = 1.4, -- 118
		orbitCenter = {x = 0, y = 0}, -- 119
		orbitRadius = 40, -- 119
		orbitPeriod = T, -- 119
		phase0 = 0, -- 120
		orbitDirection = 1 -- 120
	}} -- 120
	local level = { -- 122
		bodies = bodies, -- 123
		probeStart = {x = 0, y = 16}, -- 124
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 125
		escapeRadius = 900, -- 126
		maxSteps = 1500 -- 127
	} -- 127
	local ang = -20.1 * math.pi / 180 -- 130
	local burn = { -- 131
		x = math.cos(ang) * 19.8, -- 131
		y = math.sin(ang) * 19.8 -- 131
	} -- 131
	local a = createCore() -- 132
	a.t0 = 0 -- 133
	coreLaunch(a, burn, level) -- 134
	check( -- 135
		"launch-date-hits-at-zero", -- 135
		a.goalIndex >= 0, -- 135
		"t0=0 应命中：goalIndex=" .. tostring(a.goalIndex) -- 135
	) -- 135
	local b = createCore() -- 136
	b.t0 = T / 2 -- 137
	coreLaunch(b, burn, level) -- 138
	check( -- 139
		"launch-date-misses-at-half", -- 139
		b.goalIndex < 0, -- 139
		(("t0=" .. tostring(T / 2)) .. " 应打空：goalIndex=") .. tostring(b.goalIndex) -- 139
	) -- 139
end -- 107
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 143
	local level = testLevel() -- 144
	local core = createCore() -- 145
	coreLaunch(core, {x = 6, y = -12}, level) -- 147
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 148
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 149
	check( -- 150
		"launch-time-zero", -- 150
		core.flightTime == 0, -- 150
		"flightTime=" .. tostring(core.flightTime) -- 150
	) -- 150
	local before = core.flight ~= nil and #core.flight.points or 0 -- 153
	coreLaunch(core, {x = 0, y = -20}, level) -- 154
	local after = core.flight ~= nil and #core.flight.points or 0 -- 155
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 156
end -- 143
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 160
	local level = testLevel() -- 161
	local core = createCore() -- 162
	coreLaunch(core, {x = 6, y = -12}, level) -- 163
	local flight = core.flight -- 164
	if flight == nil then -- 164
		check("playback-flight", false, "no flight") -- 165
		return -- 165
	end -- 165
	local total = #flight.points - 1 -- 167
	check( -- 168
		"playback-start-index", -- 168
		coreProbeIndex(core) == 0, -- 168
		"idx=" .. tostring(coreProbeIndex(core)) -- 168
	) -- 168
	local entered = false -- 171
	local frames = 0 -- 172
	while not entered and frames < 100000 do -- 172
		entered = coreUpdate(core, 1 / 60) -- 174
		frames = frames + 1 -- 175
		if core.phase == "Result" then -- 175
			break -- 176
		end -- 176
	end -- 176
	check( -- 179
		"playback-enters-result", -- 179
		entered and core.phase == "Result", -- 179
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 179
	) -- 179
	check( -- 180
		"playback-final-index", -- 180
		coreProbeIndex(core) == total, -- 180
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 180
	) -- 180
	check( -- 181
		"playback-result-kind", -- 181
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 181
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 181
	) -- 181
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 184
	local actualRealSeconds = frames / 60 -- 185
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 186
	check( -- 187
		"playback-duration", -- 187
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 187
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 187
	) -- 187
end -- 160
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 192
	local level = testLevel() -- 193
	local core = createCore() -- 194
	coreRetry(core) -- 197
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 198
	coreLaunch(core, {x = 6, y = -12}, level) -- 200
	local entered = false -- 201
	local guard = 0 -- 202
	while not entered and guard < 100000 do -- 202
		entered = coreUpdate(core, 1 / 60) -- 204
		guard = guard + 1 -- 205
	end -- 205
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 207
	coreRetry(core) -- 209
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 210
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 211
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 212
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 213
	check( -- 214
		"retry-time-reset", -- 214
		core.flightTime == 0, -- 214
		"flightTime=" .. tostring(core.flightTime) -- 214
	) -- 214
	coreLaunch(core, {x = 0, y = -20}, level) -- 217
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 218
end -- 192
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 222
	local level = testLevel() -- 223
	local core = createCore() -- 224
	coreLaunch(core, {x = 6, y = -12}, level) -- 225
	local flight = core.flight -- 226
	if flight == nil then -- 226
		check("clamp-flight", false, "no flight") -- 227
		return -- 227
	end -- 227
	core.flightTime = -100 -- 229
	check( -- 230
		"clamp-negative", -- 230
		coreProbeIndex(core) == 0, -- 230
		"idx=" .. tostring(coreProbeIndex(core)) -- 230
	) -- 230
	core.flightTime = 1000000000 -- 232
	check( -- 233
		"clamp-huge", -- 233
		coreProbeIndex(core) == #flight.points - 1, -- 233
		"idx=" .. tostring(coreProbeIndex(core)) -- 233
	) -- 233
end -- 222
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 237
	local level = testLevel() -- 238
	local results = {} -- 239
	do -- 239
		local run = 0 -- 240
		while run < 2 do -- 240
			local core = createCore() -- 241
			coreLaunch(core, {x = 6, y = -12}, level) -- 242
			local guard = 0 -- 243
			while core.phase ~= "Result" and guard < 100000 do -- 243
				coreUpdate(core, 1 / 60) -- 245
				guard = guard + 1 -- 246
			end -- 246
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 248
			run = run + 1 -- 240
		end -- 240
	end -- 240
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 250
end -- 237
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 254
	local bodies = {{ -- 256
		gm = 0, -- 257
		radius = 1.2, -- 257
		orbitCenter = {x = 0, y = -20}, -- 257
		orbitRadius = 0, -- 257
		orbitPeriod = 0, -- 257
		phase0 = 0, -- 257
		orbitDirection = 1 -- 257
	}} -- 257
	local level = { -- 259
		bodies = bodies, -- 260
		probeStart = {x = 0, y = 16}, -- 261
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 262
		escapeRadius = 400, -- 263
		maxSteps = 1500 -- 264
	} -- 264
	local core = createCore() -- 267
	coreLaunch(core, {x = 0, y = -10}, level) -- 268
	check( -- 270
		"goal-found", -- 270
		core.goalIndex >= 0, -- 270
		"goalIndex=" .. tostring(core.goalIndex) -- 270
	) -- 270
	check( -- 271
		"goal-result-at-launch", -- 271
		core.result == "success", -- 271
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 271
	) -- 271
	local flight = core.flight -- 273
	if flight == nil or core.goalIndex < 0 then -- 273
		check("goal-flight", false, "no flight") -- 274
		return -- 274
	end -- 274
	local guard = 0 -- 277
	while core.phase ~= "Result" and guard < 100000 do -- 277
		coreUpdate(core, 1 / 60) -- 279
		guard = guard + 1 -- 280
	end -- 280
	check( -- 282
		"goal-ends-early", -- 282
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 282
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 282
	) -- 282
	check( -- 284
		"goal-still-success", -- 284
		core.result == "success", -- 284
		"result=" .. tostring(core.result) -- 284
	) -- 284
end -- 254
--- 11) Armed 状态（S3.10）：松手进 Armed、点「发射」才真的打出去。
-- 
-- 这几条是"松手不发射"这条交互的**纯逻辑证据** —— 合成鼠标那一路受引擎丢事件影响，
-- 状态机这一路必须自己站稳。
local function testArmed() -- 293
	local level = testLevel() -- 294
	local core = createCore() -- 295
	check( -- 296
		"arm-from-aiming", -- 296
		coreArm(core) == true and core.phase == "Armed", -- 296
		"phase=" .. core.phase -- 296
	) -- 296
	check( -- 297
		"arm-idempotent", -- 297
		coreArm(core) == false, -- 297
		"已在 Armed 时 coreArm 应返回 false（不能重复 arm）" -- 297
	) -- 297
	coreLaunch(core, {x = 0, y = -20}, level) -- 299
	check("launch-from-armed", core.phase == "Flying", "phase=" .. core.phase) -- 300
	local core2 = createCore() -- 302
	check( -- 303
		"cancel-guard", -- 303
		coreCancelArm(core2) == false, -- 303
		"Aiming 态调用 coreCancelArm 应返回 false" -- 303
	) -- 303
	coreArm(core2) -- 304
	check( -- 305
		"cancel-armed", -- 305
		coreCancelArm(core2) == true and core2.phase == "Aiming", -- 305
		"phase=" .. core2.phase -- 305
	) -- 305
	local core3 = createCore() -- 307
	coreArm(core3) -- 308
	coreRetry(core3) -- 309
	check("retry-clears-armed", core3.phase == "Aiming", "phase=" .. core3.phase) -- 310
end -- 293
--- 12) 视图模式（S3.15）：2D 规划 ⇄ 3D 观赏。
-- 
-- 设计稿第 4 条的自动切换**必须是相态流转的副产品**，不是 UI 的补丁：
--   Aiming/Armed → 2D；coreLaunch → 3D；Result 留 3D；coreRetry → 2D；coreBackToSelect → 2D。
-- 手动切换（右下角按钮）走 `coreToggleView`，状态仍然只有一个（`GameCore.viewMode`）。
-- 
-- 引擎侧端到端证据（截图 + 日志行）见 PROGRESS 会话 47。
local function testViewMode() -- 322
	local level = testLevel() -- 323
	local core = createCore() -- 324
	check("view-aiming-2d", core.viewMode == "2D", "进关应为 2D：viewMode=" .. core.viewMode) -- 325
	coreArm(core) -- 327
	check("view-armed-2d", core.viewMode == "2D", "Armed（还没发射）应留 2D：viewMode=" .. core.viewMode) -- 328
	local flipped = coreToggleView(core) -- 331
	check("view-toggle-to-3d", flipped == "3D" and core.viewMode == "3D", (("flip=" .. flipped) .. " viewMode=") .. core.viewMode) -- 332
	check( -- 333
		"view-toggle-back", -- 333
		coreToggleView(core) == "2D" and core.viewMode == "2D", -- 333
		"viewMode=" .. core.viewMode -- 333
	) -- 333
	coreToggleView(core) -- 336
	coreLaunch(core, {x = 6, y = -12}, level) -- 337
	check("view-launch-3d", core.viewMode == "3D" and core.phase == "Flying", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 338
	local guard = 0 -- 341
	while core.phase ~= "Result" and guard < 100000 do -- 341
		coreUpdate(core, 1 / 60) -- 343
		guard = guard + 1 -- 344
	end -- 344
	check("view-result-3d", core.viewMode == "3D" and core.phase == "Result", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 346
	coreRetry(core) -- 349
	check("view-retry-2d", core.viewMode == "2D" and core.phase == "Aiming", (("viewMode=" .. core.viewMode) .. " phase=") .. core.phase) -- 350
	local core2 = createCore() -- 355
	coreLaunch(core2, {x = 0, y = -20}, level) -- 356
	local guard2 = 0 -- 357
	while core2.phase ~= "Result" and guard2 < 100000 do -- 357
		coreUpdate(core2, 1 / 60) -- 359
		guard2 = guard2 + 1 -- 360
	end -- 360
	check( -- 362
		"view-back-to-select-2d", -- 362
		coreBackToSelect(core2) == true and core2.viewMode == "2D", -- 362
		(("viewMode=" .. core2.viewMode) .. " phase=") .. core2.phase -- 362
	) -- 362
end -- 322
--- 13) 掠过自动慢动作（S3.17）：触发口径「最近接近任何天体」+ 播放倍速。
-- 
-- 守四件事：① 阈值 = max(半径 × 5, 8)，锚点（太阳）不参与；② 阈值内取**最近**的天体；
-- ③ 慢动作 = 手动档 × 1/4（默认 2× ⇒ 0.5× 实时，不是 0.25× 实时也不是 1.5×）；
-- ④ **同样帧数下推进的世界时间更少** —— 这是"真的放慢了"的确定性表述。
local function testSlowMotion() -- 373
	local bodies = {{ -- 375
		gm = 72000, -- 376
		radius = 28, -- 376
		orbitCenter = {x = 0, y = 0}, -- 376
		orbitRadius = 0, -- 376
		orbitPeriod = 0, -- 376
		phase0 = 0, -- 376
		orbitDirection = 1 -- 376
	}, { -- 376
		gm = 0, -- 377
		radius = 4.63, -- 377
		orbitCenter = {x = 0, y = 0}, -- 377
		orbitRadius = 60, -- 377
		orbitPeriod = 600, -- 377
		phase0 = 0, -- 377
		orbitDirection = 1 -- 377
	}} -- 377
	local anchor = anchorBodyIndex(bodies) -- 379
	check( -- 380
		"slowmo-anchor-sun", -- 380
		anchor == 0, -- 380
		("anchor=" .. tostring(anchor)) .. "（没有 host 链 ⇒ 不绕转且 gm 最大的太阳）" -- 380
	) -- 380
	local hostChain = {bodies[1], { -- 383
		gm = 2162, -- 385
		radius = 0.0034, -- 385
		orbitCenter = {x = 0, y = 0}, -- 385
		orbitRadius = 80, -- 385
		orbitPeriod = 16.755, -- 385
		phase0 = math.pi / 2, -- 385
		orbitDirection = 1 -- 385
	}, { -- 385
		gm = 2.66, -- 386
		radius = 0.00093, -- 386
		orbitCenter = {x = 0, y = 0}, -- 386
		orbitRadius = 0.2056, -- 386
		orbitPeriod = 1.2593, -- 386
		phase0 = 0, -- 386
		orbitDirection = 1, -- 386
		host = nil -- 386
	}} -- 386
	hostChain[3].host = hostChain[2] -- 389
	check( -- 390
		"anchor-prefers-host", -- 390
		anchorBodyIndex(hostChain) == 1, -- 390
		("anchor=" .. tostring(anchorBodyIndex(hostChain))) .. "（L1：月球 host = 地球 ⇒ 锚点必须是地球，不能是太阳）" -- 391
	) -- 391
	check( -- 392
		"anchor-host-beats-sun", -- 392
		anchorBodyIndex(hostChain) ~= 0, -- 392
		"锚点不能是太阳（太阳 gm 更大但不在宿主链上）" -- 393
	) -- 393
	local threshold = math.max(4.63 * SlowMoRadiusFactor, SlowMoFloorDist) -- 396
	check( -- 397
		"slowmo-threshold-value", -- 397
		math.abs(threshold - 23.15) < 1e-9, -- 397
		"threshold=" .. tostring(threshold) -- 397
	) -- 397
	check( -- 398
		"slowmo-outside", -- 398
		slowMotionBody(bodies, {x = 30, y = 0}, 0, anchor) == -1, -- 398
		"距行星 30 > 23.15 不该触发" -- 398
	) -- 398
	check( -- 399
		"slowmo-inside", -- 399
		slowMotionBody(bodies, {x = 50, y = 0}, 0, anchor) == 1, -- 399
		"距行星 10 < 23.15 应触发" -- 399
	) -- 399
	check( -- 401
		"slowmo-anchor-excluded", -- 401
		slowMotionBody(bodies, {x = 20, y = 0}, 0, anchor) == -1, -- 401
		"太阳（锚点）即使在阈值内也不触发" -- 402
	) -- 402
	local tiny = {bodies[1], { -- 404
		gm = 0, -- 406
		radius = 1, -- 406
		orbitCenter = {x = 0, y = 0}, -- 406
		orbitRadius = 60, -- 406
		orbitPeriod = 600, -- 406
		phase0 = 0, -- 406
		orbitDirection = 1 -- 406
	}} -- 406
	check( -- 408
		"slowmo-floor-in", -- 408
		slowMotionBody(tiny, {x = 55, y = 0}, 0, anchor) == 1, -- 408
		"距 5 < 地板 8 ⇒ 触发" -- 408
	) -- 408
	check( -- 409
		"slowmo-floor-out", -- 409
		slowMotionBody(tiny, {x = 50, y = 0}, 0, anchor) == -1, -- 409
		"距 10 > 地板 8 ⇒ 不触发" -- 409
	) -- 409
	local two = {bodies[1], { -- 411
		gm = 0, -- 413
		radius = 4.63, -- 413
		orbitCenter = {x = 0, y = 0}, -- 413
		orbitRadius = 60, -- 413
		orbitPeriod = 600, -- 413
		phase0 = 0, -- 413
		orbitDirection = 1 -- 413
	}, { -- 413
		gm = 0, -- 414
		radius = 3.04, -- 414
		orbitCenter = {x = 0, y = 0}, -- 414
		orbitRadius = 60, -- 414
		orbitPeriod = 600, -- 414
		phase0 = 20 * math.pi / 180, -- 414
		orbitDirection = 1 -- 414
	}} -- 414
	check( -- 416
		"slowmo-nearest-a", -- 416
		slowMotionBody(two, {x = 58, y = 10}, 0, anchor) == 1, -- 416
		"离 1 号更近 ⇒ 选 1 号" -- 416
	) -- 416
	check( -- 417
		"slowmo-nearest-b", -- 417
		slowMotionBody(two, {x = 57, y = 15}, 0, anchor) == 2, -- 417
		"离 2 号更近 ⇒ 选 2 号" -- 417
	) -- 417
end -- 373
--- 13b) 播放倍速：手动档 1/2/4 × 慢动作 1/4；同样帧数下世界时间更少。
local function testPlaybackSpeed() -- 421
	local level = testLevel() -- 422
	local core = createCore() -- 425
	check( -- 426
		"playback-default", -- 426
		core.playback == FlightPlayback and core.playback == 2, -- 426
		"playback=" .. tostring(core.playback) -- 426
	) -- 426
	coreLaunch(core, {x = 6, y = -12}, level) -- 427
	core.playback = 4 -- 428
	local t0 = core.flightTime -- 429
	do -- 429
		local i = 0 -- 430
		while i < 60 do -- 430
			coreUpdate(core, 1 / 60) -- 430
			i = i + 1 -- 430
		end -- 430
	end -- 430
	check( -- 431
		"playback-4x", -- 431
		math.abs(core.flightTime - t0 - 4) < 1e-9, -- 431
		"60 帧 × 1/60 秒 × 4× = 4.000，实际 Δt=" .. __TS__NumberToFixed(core.flightTime - t0, 3) -- 432
	) -- 432
	core.slowmo = true -- 435
	local t1 = core.flightTime -- 436
	do -- 436
		local i = 0 -- 437
		while i < 60 do -- 437
			coreUpdate(core, 1 / 60) -- 437
			i = i + 1 -- 437
		end -- 437
	end -- 437
	check( -- 438
		"playback-slowmo-quarter", -- 438
		math.abs(core.flightTime - t1 - 1) < 1e-9, -- 438
		"4× 慢动作 60 帧应推进 1.000，实际 Δt=" .. __TS__NumberToFixed(core.flightTime - t1, 3) -- 439
	) -- 439
	local core2 = createCore() -- 442
	coreLaunch(core2, {x = 6, y = -12}, level) -- 443
	core2.slowmo = true -- 444
	local t2 = core2.flightTime -- 445
	do -- 445
		local i = 0 -- 446
		while i < 60 do -- 446
			coreUpdate(core2, 1 / 60) -- 446
			i = i + 1 -- 446
		end -- 446
	end -- 446
	check( -- 447
		"playback-default-slowmo-half", -- 447
		math.abs(core2.flightTime - t2 - 0.5) < 1e-9, -- 447
		"2× 慢动作 60 帧应推进 0.500（≈0.5× 实时），实际 Δt=" .. __TS__NumberToFixed(core2.flightTime - t2, 3) -- 448
	) -- 448
	local core3 = createCore() -- 451
	coreLaunch(core3, {x = 6, y = -12}, level) -- 452
	do -- 452
		local i = 0 -- 453
		while i < 30 do -- 453
			coreUpdate(core3, 1 / 60) -- 453
			i = i + 1 -- 453
		end -- 453
	end -- 453
	check( -- 454
		"playback-no-level", -- 454
		not core3.slowmo and core3.slowmoBody == -1, -- 454
		(("slowmo=" .. tostring(core3.slowmo)) .. " body=") .. tostring(core3.slowmoBody) -- 454
	) -- 454
	local bodies = {{ -- 457
		gm = 72000, -- 458
		radius = 28, -- 458
		orbitCenter = {x = 0, y = 0}, -- 458
		orbitRadius = 0, -- 458
		orbitPeriod = 0, -- 458
		phase0 = 0, -- 458
		orbitDirection = 1 -- 458
	}, { -- 458
		gm = 0, -- 459
		radius = 4.63, -- 459
		orbitCenter = {x = 0, y = 0}, -- 459
		orbitRadius = 60, -- 459
		orbitPeriod = 600, -- 459
		phase0 = 0, -- 459
		orbitDirection = 1 -- 459
	}} -- 459
	local nearLevel = { -- 461
		bodies = bodies, -- 462
		probeStart = {x = 50, y = 0}, -- 463
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 464
		escapeRadius = 400, -- 465
		maxSteps = 600 -- 466
	} -- 466
	local core4 = createCore() -- 468
	coreLaunch(core4, {x = 0, y = 5}, nearLevel) -- 469
	local t3 = core4.flightTime -- 470
	do -- 470
		local i = 0 -- 471
		while i < 60 do -- 471
			coreUpdate(core4, 1 / 60, nearLevel) -- 471
			i = i + 1 -- 471
		end -- 471
	end -- 471
	check( -- 472
		"playback-level-driven", -- 472
		core4.slowmo and core4.slowmoBody == 1 and math.abs(core4.flightTime - t3 - 0.5) < 1e-9, -- 472
		((((("slowmo=" .. tostring(core4.slowmo)) .. " body=") .. tostring(core4.slowmoBody)) .. " Δt=") .. __TS__NumberToFixed(core4.flightTime - t3, 3)) .. " 期望 0.500" -- 473
	) -- 473
end -- 421
function ____exports.runTests() -- 476
	testResolveResult() -- 477
	testTimeWarpGuard() -- 478
	testDateHandoff() -- 479
	testLaunch() -- 480
	testArmed() -- 481
	testPlayback() -- 482
	testRetry() -- 483
	testIndexClamp() -- 484
	testDeterministicCycle() -- 485
	testGoalTruncation() -- 486
	testViewMode() -- 487
	testSlowMotion() -- 488
	testPlaybackSpeed() -- 489
	local lines = {} -- 491
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 492
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 493
	local limit = #failures < 12 and #failures or 12 -- 494
	do -- 494
		local i = 0 -- 495
		while i < limit do -- 495
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 496
			i = i + 1 -- 495
		end -- 495
	end -- 495
	return table.concat(lines, "\n") -- 498
end -- 476
return ____exports -- 476
-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local simulate = ____Gravity.simulate -- 28
local sub = ____Gravity.sub -- 28
local ____Scene = require("game.Scene") -- 29
local planeToWorld = ____Scene.planeToWorld -- 29
local ____Projection = require("game.Projection") -- 32
local FLIP_Y = ____Projection.FLIP_Y -- 32
local HANDEDNESS = ____Projection.HANDEDNESS -- 32
local prepareCamera = ____Projection.prepareCamera -- 32
local projectPrepared = ____Projection.projectPrepared -- 32
local ____LevelData = require("game.LevelData") -- 33
local findGoalIndex = ____LevelData.findGoalIndex -- 33
local goalWaypoints = ____LevelData.goalWaypoints -- 33
local waypointProgress = ____LevelData.waypointProgress -- 33
local ____Config = require("game.Config") -- 35
local AimMinSpeed = ____Config.AimMinSpeed -- 36
local BrakeShare = ____Config.BrakeShare -- 36
local CameraFramingBudget = ____Config.CameraFramingBudget -- 36
local CameraTiltMax = ____Config.CameraTiltMax -- 36
local CameraTiltMin = ____Config.CameraTiltMin -- 36
local FlightPlayback = ____Config.FlightPlayback -- 36
local IntroCloseDist = ____Config.IntroCloseDist -- 36
local IntroDurationSec = ____Config.IntroDurationSec -- 37
local PhysicsStep = ____Config.PhysicsStep -- 37
local PredictSteps = ____Config.PredictSteps -- 37
local SlowMoCloseDist = ____Config.SlowMoCloseDist -- 37
local SlowMoFactor = ____Config.SlowMoFactor -- 37
local SlowMoFloorDist = ____Config.SlowMoFloorDist -- 37
local SlowMoRadiusFactor = ____Config.SlowMoRadiusFactor -- 38
local TimeWarpStep = ____Config.TimeWarpStep -- 38
local FinaleCamDist = ____Config.FinaleCamDist -- 39
local FinaleCamTiltDeg = ____Config.FinaleCamTiltDeg -- 39
local PlaneToWorldX = ____Config.PlaneToWorldX -- 39
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 39
--- 结算三态判定（手册 §5.8）。
-- 
-- 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
-- （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
-- 
-- ⚠️ **逃逸关 + 航线（chain）**：两个条件**都要**满足 —— 既走完航线，又真的越界（S3.11）。
-- L6「单程」用的就是这条：终章是"综合"，不能只朝任何方向猛推一下就赢。
-- 只走完航线没出去、或只出去没走航线，都是「错过」。
-- 
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 72
	if goal.kind == "escape" then -- 72
		local wps = goalWaypoints(goal) -- 74
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 74
			return "success" -- 75
		end -- 75
	elseif goalIndex >= 0 then -- 75
		return "success" -- 77
	end -- 77
	if outcome == "crashed" then -- 77
		return "crashed" -- 79
	end -- 79
	return "missed" -- 80
end -- 72
function ____exports.createCore(dt) -- 155
	return { -- 156
		phase = "Aiming", -- 157
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 158
		flight = nil, -- 159
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 160
		brakeMode = false, -- 161
		t0 = 0, -- 162
		flightTime = 0, -- 163
		goalIndex = -1, -- 164
		result = nil, -- 165
		viewMode = "2D", -- 167
		playback = FlightPlayback, -- 169
		slowmo = false, -- 170
		slowmoBody = -1 -- 171
	} -- 171
end -- 155
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 183
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 184
	return core.viewMode -- 185
end -- 183
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 203
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 209
	local share = brakeMode and BrakeShare or 1 -- 210
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 211
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 212
	local brake = brakeMode and mag > 0 and ({ -- 213
		dv = mag * (1 - share), -- 214
		startStep = math.floor(maxSteps / 2) -- 214
	}) or nil -- 214
	return {init = init, brake = brake} -- 216
end -- 203
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 225
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 225
		return -- 227
	end -- 227
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 228
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 229
	local p0 = from ~= nil and from or level.probeStart -- 230
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 231
		steps = level.maxSteps, -- 234
		dt = core.dt, -- 234
		sampleEvery = 1, -- 234
		escapeRadius = level.escapeRadius, -- 234
		t0 = core.t0, -- 234
		brake = motion.brake -- 234
	}) -- 234
	core.flight = flight -- 236
	core.goalIndex = findGoalIndex( -- 237
		flight.points, -- 237
		level.bodies, -- 237
		level.goal, -- 237
		core.dt, -- 237
		core.t0, -- 237
		flight.velocities -- 237
	) -- 237
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 238
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 241
	core.flightTime = 0 -- 246
	core.slowmo = false -- 248
	core.slowmoBody = -1 -- 249
	core.phase = "Flying" -- 250
	core.viewMode = "3D" -- 252
end -- 225
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 261
	if core.phase ~= "Aiming" then -- 261
		return false -- 262
	end -- 262
	core.phase = "Armed" -- 263
	return true -- 264
end -- 261
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 268
	if core.phase ~= "Armed" then -- 268
		return false -- 269
	end -- 269
	core.phase = "Aiming" -- 270
	return true -- 271
end -- 268
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 285
	return core.phase == "Aiming" or core.phase == "Armed" -- 286
end -- 285
--- 发射日期的**交棒**（S3.12 修 bug①，纯算术、可单测）。
-- 
-- 事实来源只有一个：`tWorld = core.t0 + core.flightTime`。发射前玩家用「加速 / 回退」
-- 拨出来的是瞄准期的世界时钟 `clock`，而 `coreLaunch` 是纯函数、只认 `core.t0` ——
-- 两者之间过去**没有人接**，于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"。
-- 
-- - `toT0 = true`（发射）：`clock → t0`；
-- - `toT0 = false`（重试）：`t0 → clock`（保留玩家挑好的日期，才能就着它继续调）。
-- 
-- ⚠️ 两种方向的 `t0 + clock` **都守恒** —— 这正是"交棒时画面不跳"的数学表述
-- （`dateNow()` 与瞄准期的 `tNow` 都等于 `t0 + clock`）。
function ____exports.coreHandoffDate(t0, clock, toT0) -- 302
	if toT0 then -- 302
		return {t0 = clock, clock = 0} -- 303
	end -- 303
	return {t0 = 0, clock = t0} -- 304
end -- 302
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 316
	local best = -1 -- 317
	do -- 317
		local i = 0 -- 318
		while i < #bodies do -- 318
			do -- 318
				local b = bodies[i + 1] -- 319
				if b.orbitRadius ~= 0 then -- 319
					goto __continue21 -- 320
				end -- 320
				if best < 0 or b.gm > bodies[best + 1].gm then -- 320
					best = i -- 321
				end -- 321
			end -- 321
			::__continue21:: -- 321
			i = i + 1 -- 318
		end -- 318
	end -- 318
	return best -- 323
end -- 316
--- S3.17 慢动作触发判定（纯函数，可单测）：「**最近接近任何天体**」。
-- 
-- 探测器与某个天体的距离进入阈值即算数 —— 抵达月球与掠过木星因此共用同一套手感。
-- 阈值 = `max(天体半径 × SlowMoRadiusFactor, SlowMoFloorDist)`（世界单位，理由见 Config）：
--   - 半径 × 系数：木星 23.2 / 土星 21.5 / 月球 8（地板）；
--   - **锚点天体（太阳）不参与**：它半径 28，乘出来比探测器出发距离（80）还大，
--     不排除就是六关全程慢动作。掠过景由取景里的锚点预算负责，不由慢动作负责。
-- 
-- @param anchor 锚点天体索引（-1 = 没有锚点）；传 anchorBodyIndex(bodies) 的结果。
-- @returns 触发的天体索引（**最近**的那个）；-1 = 不在任何天体的阈值内。
function ____exports.slowMotionBody(bodies, probe, t, anchor) -- 338
	local best = -1 -- 339
	local bestD = 1000000000 -- 340
	do -- 340
		local i = 0 -- 341
		while i < #bodies do -- 341
			do -- 341
				if i == anchor then -- 341
					goto __continue26 -- 342
				end -- 342
				local b = bodies[i + 1] -- 343
				local threshold = math.max(b.radius * SlowMoRadiusFactor, SlowMoFloorDist) -- 344
				local d = distance( -- 345
					probe, -- 345
					bodyPositionAt(b, t) -- 345
				) -- 345
				if d < threshold and d < bestD then -- 345
					bestD = d -- 347
					best = i -- 348
				end -- 348
			end -- 348
			::__continue26:: -- 348
			i = i + 1 -- 341
		end -- 341
	end -- 341
	return best -- 351
end -- 338
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 355
	if core.flight == nil then -- 355
		return 0 -- 356
	end -- 356
	local idx = math.floor(core.flightTime / core.dt) -- 357
	local last = #core.flight.points - 1 -- 358
	if idx > last then -- 358
		idx = last -- 359
	end -- 359
	if idx < 0 then -- 359
		idx = 0 -- 360
	end -- 360
	return idx -- 361
end -- 355
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
-- 
-- ===== S3.17 掠过自动慢动作：全项目**唯一**的播放速度入口 =====
-- 
-- `level` 给了才判定（天体位置随时间动，需要 bodies + tWorld；测试与旧路径省略 = 不触发）。
-- 判定写在**推进之前**（用这一帧起始位置的探测器），结果落回 `core.slowmo` / `core.slowmoBody`
-- —— 相机取景与 HUD 读的就是这两个字段，全项目只有这一个地方写它们。
-- 有效倍速 = 手动档（1×/2×/4×）× (慢动作 ? SlowMoFactor : 1)，只改「每帧推进多少模拟时间」：
-- **不重算物理、不动确定性、不引入第二套时钟**（轨迹在发射那刻就已算完）。
function ____exports.coreUpdate(core, dt, level) -- 378
	if core.phase ~= "Flying" or core.flight == nil then -- 378
		return false -- 379
	end -- 379
	if level ~= nil then -- 379
		local idx = ____exports.coreProbeIndex(core) -- 383
		core.slowmoBody = ____exports.slowMotionBody( -- 384
			level.bodies, -- 384
			core.flight.points[idx + 1], -- 384
			core.t0 + core.flightTime, -- 384
			____exports.anchorBodyIndex(level.bodies) -- 384
		) -- 384
		core.slowmo = core.slowmoBody >= 0 -- 385
	end -- 385
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 388
	core.flightTime = core.flightTime + dt * speed -- 389
	local naturalEnd = #core.flight.points - 1 -- 390
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 391
	if ____exports.coreProbeIndex(core) >= endIdx then -- 391
		core.flightTime = endIdx * core.dt -- 394
		core.phase = "Result" -- 395
		return true -- 396
	end -- 396
	return false -- 398
end -- 378
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 402
	core.phase = "Aiming" -- 403
	core.viewMode = "2D" -- 405
	core.flight = nil -- 406
	core.flightTime = 0 -- 407
	core.goalIndex = -1 -- 408
	core.result = nil -- 409
	core.slowmo = false -- 410
	core.slowmoBody = -1 -- 411
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 412
end -- 402
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 426
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 426
		return false -- 428
	end -- 428
	core.phase = "LevelSelect" -- 429
	core.viewMode = "2D" -- 431
	core.flight = nil -- 432
	core.flightTime = 0 -- 433
	core.goalIndex = -1 -- 434
	core.result = nil -- 435
	core.slowmo = false -- 436
	core.slowmoBody = -1 -- 437
	return true -- 438
end -- 426
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 467
	if core.phase ~= "Result" then -- 467
		return false -- 468
	end -- 468
	core.phase = "Finale" -- 469
	return true -- 470
end -- 467
--- 终章的相机机位（纯函数，可单测）。
-- 
-- 「相机拉到尽可能远，回望整条太阳系」：机位在**探测器逃逸方向**上、距太阳
-- `distance` 处抬起 `tiltDeg`，注视太阳（世界原点）。于是
--   - 太阳缩成一个亮点（半径 28 @ 1000 ≈ 1.6°）；
--   - 地球按真实比例缩成一个点（半径 1.76 @ ~1000 ≈ 0.10°，直径约 5 px）——
--     **不放大**（用户否掉过「为画面放大行星」，docs/关卡舞台表.md 第二节第 9 条）。
-- 
-- ⚠️ 这是唯一一处**绕开 CameraRig** 的取景：机架的距离夹在 [CameraMinDistance, CameraMaxDistance]
-- （60–300）里，装不下「尽可能远」。绕开的代价是机架内部的平滑状态会停在 1000 上，
-- 所以进关时（Game.startLevel）必须 `deps.rig.reset()`，否则下一关的相机会从 1000 一路 lerp 回去。
-- 
-- @param probe 探测器**当前**位置（平面坐标）；只在逃逸方向上有意义，零向量时退回 +Y。
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 488
	local dist = distance > 1 and distance or 1 -- 489
	local ux = probe.x -- 491
	local uy = probe.y -- 492
	local len = math.sqrt(ux * ux + uy * uy) -- 493
	if len < 0.000001 then -- 493
		ux = 0 -- 494
		uy = 1 -- 494
	else -- 494
		ux = ux / len -- 494
		uy = uy / len -- 494
	end -- 494
	local tilt = tiltDeg * math.pi / 180 -- 495
	local flat = math.cos(tilt) * dist -- 496
	return { -- 497
		target = Vec3(0, 0, 0), -- 499
		eye = Vec3( -- 500
			ux * flat * PlaneToWorldX, -- 500
			math.sin(tilt) * dist, -- 500
			uy * flat * PlaneToWorldZ -- 500
		) -- 500
	} -- 500
end -- 488
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 605
	local core = ____exports.createCore(level.physicsStep) -- 606
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 609
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 612
	--- **视图切换的唯一落点**（S3.15）。
	-- 
	-- 设计稿第 4 条："进关/瞄准在 2D → 按下发射自动切 3D → 飞行与结算留 3D → 重试回 2D"，
	-- 右下角再给一颗手动按钮兜底。这里读的是 `core.viewMode`（状态），**不读按钮**：
	-- 于是自动切换与手动切换走的是同一条路，也不会有"按钮显示的与画出来的分家"。
	-- 
	-- - 2D：收起 3D 世界 + 收起 3D 轨迹层（`trajectory.root`，它就是投影出来的预测线/尾迹/到达环），
	--   打开 2D 规划层，并让瞄准层**整屏**都能瞄（2D 里没有"自由观察"可做，"探测器附近"那条分区
	--   规则会把大半屏变成死区）；
	-- - 3D：反过来。两边的 DrawNode 都挂在关卡 2D 层上，**隐藏时必须清空**（硬约束 8）。
	-- 
	-- 每帧调用一次是**幂等**的：`mode === appliedMode` 直接早退（不动节点、不刷日志）。
	local function applyView() -- 627
		local mode = core.viewMode -- 628
		if mode == appliedMode then -- 628
			return -- 629
		end -- 629
		appliedMode = mode -- 630
		local is2D = mode == "2D" -- 631
		deps.plan:setVisible(is2D) -- 632
		deps.trajectory.root.visible = not is2D -- 633
		deps:setWorldVisible(not is2D) -- 634
		deps.aim:setFullScreenAim(is2D) -- 635
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 636
	end -- 627
	local function makeBasis(frame) -- 639
		return prepareCamera({ -- 640
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 642
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 643
			up = {x = 0, y = 1, z = 0}, -- 644
			fovYDeg = deps.fovYDeg, -- 645
			aspect = deps.aspect, -- 646
			viewW = deps.viewW, -- 647
			viewH = deps.viewH -- 648
		}, HANDEDNESS, FLIP_Y) -- 648
	end -- 639
	local predKey = "" -- 657
	local predPoints = {} -- 658
	local introT = IntroDurationSec -- 660
	local introLogged = false -- 661
	local clock = 0 -- 667
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 669
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 671
	local obsYawDeg = 0 -- 675
	local obsPitchDeg = 0 -- 676
	local obsZoom = 1 -- 677
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 679
	local idlePath = nil -- 680
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 691
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 693
	local lastSlowmoBody = -1 -- 694
	local flightLogT = 0 -- 695
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 697
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 698
	local function prepareIdle() -- 699
		clock = 0 -- 701
		core.t0 = 0 -- 702
		if level.probeVel0 == nil then -- 702
			idlePath = nil -- 704
			return -- 705
		end -- 705
		local idleSteps = level.maxSteps -- 713
		local v0x = level.probeVel0.x -- 714
		local v0y = level.probeVel0.y -- 715
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 716
		if v0 > 0.000001 then -- 716
			local bestD = 1000000000 -- 718
			for ____, b in ipairs(level.bodies) do -- 719
				do -- 719
					if b.gm <= 0 then -- 719
						goto __continue52 -- 720
					end -- 720
					local dx = b.orbitCenter.x - level.probeStart.x -- 721
					local dy = b.orbitCenter.y - level.probeStart.y -- 722
					local d = math.sqrt(dx * dx + dy * dy) -- 723
					if d < bestD then -- 723
						bestD = d -- 724
					end -- 724
				end -- 724
				::__continue52:: -- 724
			end -- 724
			if bestD > 0.000001 and bestD < 100000000 then -- 724
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 727
				if n > 60 and n < 40000 then -- 727
					idleSteps = n -- 728
				end -- 728
			end -- 728
		end -- 728
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 731
			steps = idleSteps, -- 734
			dt = core.dt, -- 734
			sampleEvery = 1, -- 734
			escapeRadius = level.escapeRadius, -- 734
			t0 = core.t0 -- 734
		}) -- 734
	end -- 699
	local function idleIndex() -- 737
		if idlePath == nil then -- 737
			return 0 -- 738
		end -- 738
		local n = #idlePath.points -- 739
		if n <= 1 then -- 739
			return 0 -- 740
		end -- 740
		local i = math.floor(orbitClock / core.dt) % n -- 741
		if i < 0 then -- 741
			i = 0 -- 742
		end -- 742
		return i -- 743
	end -- 737
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 753
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 754
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 757
		local wps = goalWaypoints(level.goal) -- 758
		if #wps == 0 then -- 758
			return nil -- 759
		end -- 759
		local passed = 0 -- 760
		if core.flight ~= nil then -- 760
			local upto = math.floor(core.flightTime / core.dt) -- 762
			passed = waypointProgress( -- 763
				core.flight.points, -- 763
				level.bodies, -- 763
				level.goal, -- 763
				core.dt, -- 763
				core.t0, -- 763
				upto, -- 763
				core.flight.velocities -- 763
			).passed -- 763
		end -- 763
		if passed >= #wps then -- 763
			return nil -- 765
		end -- 765
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 766
	end -- 757
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 777
		local corePts = {probe} -- 780
		local coreRadii = {deps.scene.probeRadius} -- 781
		local next = nextStationBody() -- 782
		local nextTol = 0 -- 783
		if next ~= nil then -- 783
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 785
			local wps = goalWaypoints(level.goal) -- 786
			local passed = 0 -- 787
			if core.flight ~= nil then -- 787
				passed = waypointProgress( -- 789
					core.flight.points, -- 789
					level.bodies, -- 789
					level.goal, -- 789
					core.dt, -- 789
					core.t0, -- 789
					math.floor(core.flightTime / core.dt), -- 789
					core.flight.velocities -- 789
				).passed -- 789
			end -- 789
			if passed < #wps then -- 789
				nextTol = wps[passed + 1].tolerance -- 791
			end -- 791
			local r = nextTol > next.radius and nextTol or next.radius -- 792
			coreRadii[#coreRadii + 1] = r -- 793
		end -- 793
		if anchorDef == nil then -- 793
			return {pts = corePts, radii = coreRadii} -- 796
		end -- 796
		local withAnchorPts = { -- 797
			probe, -- 797
			bodyPositionAt(anchorDef, t) -- 797
		} -- 797
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 798
		do -- 798
			local i = 1 -- 799
			while i < #corePts do -- 799
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 800
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 801
				i = i + 1 -- 799
			end -- 799
		end -- 799
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 803
		if want <= CameraFramingBudget then -- 803
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 804
		end -- 804
		return {pts = corePts, radii = coreRadii} -- 805
	end -- 777
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 809
		local wps = goalWaypoints(level.goal) -- 810
		if #wps == 0 then -- 810
			return {} -- 811
		end -- 811
		local passed = 0 -- 812
		if upto ~= nil and core.flight ~= nil then -- 812
			passed = waypointProgress( -- 814
				core.flight.points, -- 814
				level.bodies, -- 814
				level.goal, -- 814
				core.dt, -- 814
				core.t0, -- 814
				upto, -- 814
				core.flight.velocities -- 814
			).passed -- 814
		end -- 814
		if passed >= #wps then -- 814
			return {} -- 819
		end -- 819
		local nextWp = wps[passed + 1] -- 820
		local body = level.bodies[nextWp.planetIndex + 1] -- 821
		if body == nil then -- 821
			return {} -- 822
		end -- 822
		return {{ -- 823
			center = bodyPositionAt(body, t), -- 823
			radius = nextWp.tolerance, -- 823
			passed = false -- 823
		}} -- 823
	end -- 809
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 827
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 827
			return f -- 828
		end -- 828
		local dx = f.eye.x - f.target.x -- 829
		local dy = f.eye.y - f.target.y -- 830
		local dz = f.eye.z - f.target.z -- 831
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 832
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 833
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 834
		local lo = CameraTiltMin * math.pi / 180 -- 835
		local hi = CameraTiltMax * math.pi / 180 -- 836
		if pitch < lo then -- 836
			pitch = lo -- 837
		end -- 837
		if pitch > hi then -- 837
			pitch = hi -- 838
		end -- 838
		local cp = math.cos(pitch) -- 839
		return { -- 840
			target = f.target, -- 841
			eye = Vec3( -- 842
				f.target.x + r * cp * math.sin(yaw), -- 843
				f.target.y + r * math.sin(pitch), -- 844
				f.target.z + r * cp * math.cos(yaw) -- 845
			) -- 845
		} -- 845
	end -- 827
	local function updateAiming(dt) -- 850
		deps.aim:setEnabled(true) -- 851
		local dragging = deps.aim:isDragging() -- 853
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 853
			clock = clock + dt * (level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1) -- 859
			orbitClock = orbitClock + dt -- 860
		end -- 860
		local idx = idleIndex() -- 862
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 863
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 864
		local tNow = core.t0 + clock -- 867
		deps.scene.syncBodies(tNow) -- 869
		deps.scene.syncProbe(probePos) -- 870
		if idlePath ~= nil and idx > 0 then -- 870
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 871
		end -- 871
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 873
		deps.plan:syncProbe(probePos, probeVel) -- 874
		local fr = framingPoints(probePos, tNow) -- 877
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 878
		if introT < IntroDurationSec then -- 878
			introT = introT + dt -- 882
			local k = introT / IntroDurationSec -- 883
			if k > 1 then -- 883
				k = 1 -- 884
			end -- 884
			if k >= 1 and not introLogged then -- 884
				introLogged = true -- 886
				print("[escape-velocity] intro camera done") -- 887
			end -- 887
			local wps0 = goalWaypoints(level.goal) -- 889
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 890
			local wide = frame -- 891
			local from = wide -- 892
			local to = wide -- 893
			local e = 0 -- 894
			if k < 0.35 then -- 894
				local pw = planeToWorld(probePos, 0) -- 896
				local dx = wide.eye.x - wide.target.x -- 897
				local dy = wide.eye.y - wide.target.y -- 898
				local dz = wide.eye.z - wide.target.z -- 899
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 900
				if len > 0.000001 then -- 900
					local s = IntroCloseDist / len -- 902
					dx = dx * s -- 903
					dy = dy * s -- 903
					dz = dz * s -- 903
				end -- 903
				from = { -- 905
					target = Vec3(pw.x, pw.y, pw.z), -- 905
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 905
				} -- 905
				e = k / 0.35 -- 906
			elseif k < 0.72 and wpBody ~= nil then -- 906
				local c = planeToWorld( -- 909
					bodyPositionAt(wpBody, tNow), -- 909
					0 -- 909
				) -- 909
				local dx = wide.eye.x - wide.target.x -- 910
				local dy = wide.eye.y - wide.target.y -- 911
				local dz = wide.eye.z - wide.target.z -- 912
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 913
				local want = math.max(24, wpBody.radius * 6) -- 914
				if len > 0.000001 then -- 914
					local s = want / len -- 916
					dx = dx * s -- 917
					dy = dy * s -- 917
					dz = dz * s -- 917
				end -- 917
				to = { -- 919
					target = Vec3(c.x, c.y, c.z), -- 919
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 919
				} -- 919
				e = (k - 0.35) / 0.37 -- 920
			elseif wpBody ~= nil then -- 920
				local c = planeToWorld( -- 923
					bodyPositionAt(wpBody, tNow), -- 923
					0 -- 923
				) -- 923
				local dx = wide.eye.x - wide.target.x -- 924
				local dy = wide.eye.y - wide.target.y -- 925
				local dz = wide.eye.z - wide.target.z -- 926
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 927
				local want = math.max(24, wpBody.radius * 6) -- 928
				if len > 0.000001 then -- 928
					local s = want / len -- 930
					dx = dx * s -- 931
					dy = dy * s -- 931
					dz = dz * s -- 931
				end -- 931
				from = { -- 933
					target = Vec3(c.x, c.y, c.z), -- 933
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 933
				} -- 933
				e = (k - 0.72) / 0.28 -- 934
			end -- 934
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 936
			frame = { -- 937
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 938
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 943
			} -- 943
		end -- 943
		frame = applyObserve(frame) -- 951
		deps.rig.apply(deps.camera, frame) -- 952
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 953
		local basis = makeBasis(frame) -- 954
		if core.viewMode == "2D" then -- 954
			local sp = deps.plan:probeScreen() -- 960
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 961
		else -- 961
			local pp = projectPrepared( -- 963
				planeToWorld(probePos, 0), -- 963
				basis -- 963
			) -- 963
			if pp ~= nil then -- 963
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 964
			end -- 964
		end -- 964
		if not aimed then -- 964
			deps.trajectory:clearPrediction() -- 977
			deps.plan:clearPrediction() -- 978
			predKey = "" -- 979
		else -- 979
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 983
			if key ~= predKey then -- 983
				predKey = key -- 987
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 990
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 991
					steps = PredictSteps, -- 994
					dt = core.dt, -- 994
					sampleEvery = 4, -- 994
					escapeRadius = level.escapeRadius, -- 994
					t0 = tNow, -- 994
					brake = motion.brake -- 994
				}).points -- 994
			end -- 994
			deps.trajectory:setPrediction(predPoints, basis) -- 997
			deps.plan:setPrediction(predPoints) -- 999
		end -- 999
		local rings = goalRingsAt(tNow) -- 1001
		deps.trajectory:setGoalRings(rings, basis) -- 1002
		deps.trajectory:clearTrail() -- 1003
		deps.plan:setGoalRings(rings) -- 1005
		deps.plan:clearTrail() -- 1006
		deps.plan:flush() -- 1007
	end -- 850
	--- 终章「暗淡蓝点」（S3.18）：一屏，不做动画分镜、不做第二段文案（砍线顺序里终章细节是第一项）。
	-- 
	-- 画面 = 复用现有 3D 场景与星空背板，相机拉到**尽可能远**回望太阳系：
	--   - 太阳缩成一个亮点；
	--   - 地球按**真实比例**缩成一个点（半径 1.76 @ ~1000 单位，直径约 5 px）——
	--     **不放大**（用户当初否掉过「为画面放大行星」，docs/关卡舞台表.md 第二节第 9 条）。
	-- 
	-- 世界时刻仍然只有一个事实来源：`tWorld = core.t0 + core.flightTime`（硬约束 7）。
	-- ⚠️ 地球此时是 L6 planets 里的 `homeEarth()`（gm = 0 的布景天体，位置随日期变）⇒
	--    必须按 tWorld 取它，写死 t = 0 会让地球跳回相位 0（物理对、画面错）。
	local function updateFinale() -- 1022
		deps.aim:setEnabled(false) -- 1023
		if core.flight == nil then -- 1023
			return -- 1024
		end -- 1024
		local idx = ____exports.coreProbeIndex(core) -- 1025
		local pos = core.flight.points[idx + 1] -- 1026
		local tWorld = core.t0 + core.flightTime -- 1027
		deps.scene.syncBodies(tWorld) -- 1030
		deps.scene.syncProbe(pos) -- 1031
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1032
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1035
		deps.camera:lookAt( -- 1036
			frame.eye, -- 1036
			frame.target, -- 1036
			Vec3(0, 1, 0) -- 1036
		) -- 1036
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1037
		local trail = {} -- 1040
		do -- 1040
			local i = 0 -- 1041
			while i <= idx do -- 1041
				trail[#trail + 1] = core.flight.points[i + 1] -- 1041
				i = i + 1 -- 1041
			end -- 1041
		end -- 1041
		local rings = goalRingsAt(tWorld, idx) -- 1042
		local basis = makeBasis(frame) -- 1043
		deps.trajectory:setTrail(trail, basis) -- 1044
		deps.trajectory:setGoalRings(rings, basis) -- 1045
		deps.plan:clearPrediction() -- 1046
		deps.plan:setGoalRings(rings) -- 1047
		deps.plan:flush() -- 1048
	end -- 1022
	local function updateFlying(dt) -- 1050
		deps.aim:setEnabled(false) -- 1051
		local entered = ____exports.coreUpdate(core, dt, level) -- 1054
		if core.flight == nil then -- 1054
			return entered -- 1055
		end -- 1055
		local idx = ____exports.coreProbeIndex(core) -- 1057
		local pos = core.flight.points[idx + 1] -- 1058
		local tWorld = core.t0 + core.flightTime -- 1062
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1062
			lastSlowmo = core.slowmo -- 1066
			lastSlowmoBody = core.slowmoBody -- 1067
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1068
			local nearD = near ~= nil and distance( -- 1069
				pos, -- 1069
				bodyPositionAt(near, tWorld) -- 1069
			) or 0 -- 1069
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1070
		end -- 1070
		flightLogT = flightLogT + dt -- 1077
		if flightLogT >= 0.5 then -- 1077
			flightLogT = 0 -- 1079
			local total = (#core.flight.points - 1) * core.dt -- 1080
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1081
		end -- 1081
		deps.scene.syncBodies(tWorld) -- 1087
		deps.scene.syncProbe(pos) -- 1088
		if idx > 0 then -- 1088
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1090
		end -- 1090
		local fr -- 1097
		local closeDist = nil -- 1098
		if core.slowmo and core.slowmoBody >= 0 then -- 1098
			local near = level.bodies[core.slowmoBody + 1] -- 1100
			fr = { -- 1101
				pts = { -- 1101
					pos, -- 1101
					bodyPositionAt(near, tWorld) -- 1101
				}, -- 1101
				radii = {deps.scene.probeRadius, near.radius} -- 1101
			} -- 1101
			closeDist = SlowMoCloseDist -- 1102
		else -- 1102
			fr = framingPoints(pos, tWorld) -- 1104
		end -- 1104
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1106
		deps.rig.apply(deps.camera, frame) -- 1107
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1108
		local basis = makeBasis(frame) -- 1109
		local trail = {} -- 1112
		do -- 1112
			local i = 0 -- 1113
			while i <= idx do -- 1113
				trail[#trail + 1] = core.flight.points[i + 1] -- 1113
				i = i + 1 -- 1113
			end -- 1113
		end -- 1113
		local rings = goalRingsAt(tWorld, idx) -- 1114
		deps.trajectory:setTrail(trail, basis) -- 1115
		deps.trajectory:setGoalRings(rings, basis) -- 1116
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1119
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1120
		deps.plan:setTrail(trail) -- 1121
		deps.plan:clearPrediction() -- 1122
		deps.plan:setGoalRings(rings) -- 1123
		deps.plan:flush() -- 1124
		return entered -- 1126
	end -- 1050
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1140
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1141
		core.t0 = next.t0 -- 1142
		clock = next.clock -- 1143
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1144
	end -- 1140
	local function update(dt) -- 1147
		applyView() -- 1150
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1150
			updateAiming(dt) -- 1152
		elseif core.phase == "Flying" then -- 1152
			local entered = updateFlying(dt) -- 1154
			if entered and core.result ~= nil then -- 1154
				local toFinale = deps.finale == true and core.result == "success" -- 1157
				if toFinale then -- 1157
					____exports.coreEnterFinale(core) -- 1158
				end -- 1158
				deps:onResult(core.result) -- 1160
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1160
					local ____end = #core.flight.points - 1 -- 1162
					deps:onFinale({ -- 1163
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1164
						time = core.flightTime, -- 1165
						tWorld = core.t0 + core.flightTime -- 1166
					}) -- 1166
				end -- 1166
				deps:onPhase(toFinale and "Finale" or "Result") -- 1169
			end -- 1169
		elseif core.phase == "Finale" then -- 1169
			updateFinale() -- 1172
		end -- 1172
	end -- 1147
	return { -- 1177
		phase = function() return core.phase end, -- 1178
		result = function() return core.result end, -- 1179
		onAimDrag = function(____, a) -- 1180
			core.aim = a -- 1181
			aimed = true -- 1182
			introT = IntroDurationSec -- 1183
		end, -- 1180
		aimReady = function() -- 1185
			if not ____exports.coreArm(core) then -- 1185
				return -- 1186
			end -- 1186
			applyView() -- 1187
			deps:onPhase("Armed") -- 1188
		end, -- 1185
		launchArmed = function() -- 1190
			if core.phase ~= "Armed" then -- 1190
				return -- 1192
			end -- 1192
			handoffDate(true) -- 1193
			____exports.coreLaunch( -- 1194
				core, -- 1194
				core.aim.velocity, -- 1194
				level, -- 1194
				probePos, -- 1194
				probeVel -- 1194
			) -- 1194
			deps.trajectory:clearPrediction() -- 1195
			deps.plan:clearPrediction() -- 1196
			applyView() -- 1197
			deps:onPhase("Flying") -- 1198
		end, -- 1190
		armed = function() return core.phase == "Armed" end, -- 1200
		viewMode = function() return core.viewMode end, -- 1201
		toggleViewMode = function() -- 1202
			____exports.coreToggleView(core) -- 1204
			applyView() -- 1205
		end, -- 1202
		observeDrag = function(____, dx, dy) -- 1207
			introT = IntroDurationSec -- 1208
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1209
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1210
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1211
			if obsPitchDeg > 40 then -- 1211
				obsPitchDeg = 40 -- 1212
			end -- 1212
			if obsPitchDeg < -40 then -- 1212
				obsPitchDeg = -40 -- 1213
			end -- 1213
		end, -- 1207
		observeZoom = function(____, deltaDist) -- 1215
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1216
			if obsZoom < 0.4 then -- 1216
				obsZoom = 0.4 -- 1217
			end -- 1217
			if obsZoom > 1.8 then -- 1217
				obsZoom = 1.8 -- 1218
			end -- 1218
		end, -- 1215
		launch = function(____, v) -- 1220
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1220
				return -- 1221
			end -- 1221
			handoffDate(true) -- 1222
			____exports.coreLaunch( -- 1224
				core, -- 1224
				v, -- 1224
				level, -- 1224
				probePos, -- 1224
				probeVel -- 1224
			) -- 1224
			deps.trajectory:clearPrediction() -- 1225
			deps.plan:clearPrediction() -- 1226
			applyView() -- 1227
			deps:onPhase("Flying") -- 1228
		end, -- 1220
		retry = function() -- 1230
			if core.phase ~= "Result" then -- 1230
				return -- 1231
			end -- 1231
			handoffDate(false) -- 1232
			aimed = false -- 1233
			____exports.coreRetry(core) -- 1234
			deps.trajectory:clearTrail() -- 1235
			deps.trajectory:clearPrediction() -- 1236
			deps.trajectory:clearGoalRings() -- 1237
			deps.plan:clearTrail() -- 1238
			deps.plan:clearPrediction() -- 1239
			deps.plan:clearGoalRings() -- 1240
			applyView() -- 1241
			deps:onPhase("Aiming") -- 1242
		end, -- 1230
		backToSelect = function() -- 1244
			if not ____exports.coreBackToSelect(core) then -- 1244
				return false -- 1245
			end -- 1245
			deps.aim:setEnabled(false) -- 1247
			deps.trajectory:clearTrail() -- 1248
			deps.trajectory:clearPrediction() -- 1249
			deps.trajectory:clearGoalRings() -- 1250
			deps.plan:clearTrail() -- 1251
			deps.plan:clearPrediction() -- 1252
			deps.plan:clearGoalRings() -- 1253
			applyView() -- 1254
			deps:onPhase("LevelSelect") -- 1255
			return true -- 1256
		end, -- 1244
		startLevel = function() -- 1258
			aimed = false -- 1261
			____exports.coreRetry(core) -- 1262
			deps.rig.reset() -- 1265
			introT = 0 -- 1266
			introLogged = false -- 1267
			prepareIdle() -- 1268
			deps.trajectory:clearTrail() -- 1269
			deps.trajectory:clearPrediction() -- 1270
			deps.trajectory:clearGoalRings() -- 1271
			deps.plan:clearTrail() -- 1272
			deps.plan:clearPrediction() -- 1273
			deps.plan:clearGoalRings() -- 1274
			appliedMode = "" -- 1277
			applyView() -- 1278
			deps:onPhase("Aiming") -- 1279
		end, -- 1258
		stepTime = function(____, dir, span) -- 1281
			if not ____exports.coreTimeWarpAllowed(core) then -- 1281
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1285
				return -- 1286
			end -- 1286
			local span0 = span > 0 and span or 0 -- 1288
			clock = clock + dir * TimeWarpStep -- 1289
			if clock < 0 then -- 1289
				clock = 0 -- 1290
			end -- 1290
			if span0 > 0 and clock > span0 then -- 1290
				clock = span0 -- 1291
			end -- 1291
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1293
		end, -- 1281
		dateNow = function() return core.t0 + clock end, -- 1295
		setBrakeMode = function(____, on) -- 1296
			core.brakeMode = on -- 1297
		end, -- 1296
		brakeMode = function() return core.brakeMode end, -- 1300
		setPlaybackSpeed = function(____, speed) -- 1301
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1301
				return -- 1303
			end -- 1303
			core.playback = speed -- 1304
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1305
		end, -- 1301
		playbackSpeed = function() return core.playback end, -- 1307
		update = function(____, frameDt) return update(frameDt) end -- 1309
	} -- 1309
end -- 605
return ____exports -- 605
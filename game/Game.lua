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
			local aimRate = level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1 -- 864
			clock = clock + dt * aimRate -- 865
			orbitClock = orbitClock + dt * aimRate -- 866
		end -- 866
		local idx = idleIndex() -- 868
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 869
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 870
		local tNow = core.t0 + clock -- 873
		deps.scene.syncBodies(tNow) -- 875
		deps.scene.syncProbe(probePos) -- 876
		if idlePath ~= nil and idx > 0 then -- 876
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 877
		end -- 877
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 879
		deps.plan:syncProbe(probePos, probeVel) -- 880
		local fr = framingPoints(probePos, tNow) -- 883
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 884
		if introT < IntroDurationSec then -- 884
			introT = introT + dt -- 888
			local k = introT / IntroDurationSec -- 889
			if k > 1 then -- 889
				k = 1 -- 890
			end -- 890
			if k >= 1 and not introLogged then -- 890
				introLogged = true -- 892
				print("[escape-velocity] intro camera done") -- 893
			end -- 893
			local wps0 = goalWaypoints(level.goal) -- 895
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 896
			local wide = frame -- 897
			local from = wide -- 898
			local to = wide -- 899
			local e = 0 -- 900
			if k < 0.35 then -- 900
				local pw = planeToWorld(probePos, 0) -- 902
				local dx = wide.eye.x - wide.target.x -- 903
				local dy = wide.eye.y - wide.target.y -- 904
				local dz = wide.eye.z - wide.target.z -- 905
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 906
				if len > 0.000001 then -- 906
					local s = IntroCloseDist / len -- 908
					dx = dx * s -- 909
					dy = dy * s -- 909
					dz = dz * s -- 909
				end -- 909
				from = { -- 911
					target = Vec3(pw.x, pw.y, pw.z), -- 911
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 911
				} -- 911
				e = k / 0.35 -- 912
			elseif k < 0.72 and wpBody ~= nil then -- 912
				local c = planeToWorld( -- 915
					bodyPositionAt(wpBody, tNow), -- 915
					0 -- 915
				) -- 915
				local dx = wide.eye.x - wide.target.x -- 916
				local dy = wide.eye.y - wide.target.y -- 917
				local dz = wide.eye.z - wide.target.z -- 918
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 919
				local want = math.max(24, wpBody.radius * 6) -- 920
				if len > 0.000001 then -- 920
					local s = want / len -- 922
					dx = dx * s -- 923
					dy = dy * s -- 923
					dz = dz * s -- 923
				end -- 923
				to = { -- 925
					target = Vec3(c.x, c.y, c.z), -- 925
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 925
				} -- 925
				e = (k - 0.35) / 0.37 -- 926
			elseif wpBody ~= nil then -- 926
				local c = planeToWorld( -- 929
					bodyPositionAt(wpBody, tNow), -- 929
					0 -- 929
				) -- 929
				local dx = wide.eye.x - wide.target.x -- 930
				local dy = wide.eye.y - wide.target.y -- 931
				local dz = wide.eye.z - wide.target.z -- 932
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 933
				local want = math.max(24, wpBody.radius * 6) -- 934
				if len > 0.000001 then -- 934
					local s = want / len -- 936
					dx = dx * s -- 937
					dy = dy * s -- 937
					dz = dz * s -- 937
				end -- 937
				from = { -- 939
					target = Vec3(c.x, c.y, c.z), -- 939
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 939
				} -- 939
				e = (k - 0.72) / 0.28 -- 940
			end -- 940
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 942
			frame = { -- 943
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 944
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 949
			} -- 949
		end -- 949
		frame = applyObserve(frame) -- 957
		deps.rig.apply(deps.camera, frame) -- 958
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 959
		local basis = makeBasis(frame) -- 960
		if core.viewMode == "2D" then -- 960
			local sp = deps.plan:probeScreen() -- 966
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 967
		else -- 967
			local pp = projectPrepared( -- 969
				planeToWorld(probePos, 0), -- 969
				basis -- 969
			) -- 969
			if pp ~= nil then -- 969
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 970
			end -- 970
		end -- 970
		if not aimed then -- 970
			deps.trajectory:clearPrediction() -- 983
			deps.plan:clearPrediction() -- 984
			predKey = "" -- 985
		else -- 985
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 989
			if key ~= predKey then -- 989
				predKey = key -- 993
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 996
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 997
					steps = PredictSteps, -- 1000
					dt = core.dt, -- 1000
					sampleEvery = 4, -- 1000
					escapeRadius = level.escapeRadius, -- 1000
					t0 = tNow, -- 1000
					brake = motion.brake -- 1000
				}).points -- 1000
			end -- 1000
			deps.trajectory:setPrediction(predPoints, basis) -- 1003
			deps.plan:setPrediction(predPoints) -- 1005
		end -- 1005
		local rings = goalRingsAt(tNow) -- 1007
		deps.trajectory:setGoalRings(rings, basis) -- 1008
		deps.trajectory:clearTrail() -- 1009
		deps.plan:setGoalRings(rings) -- 1011
		deps.plan:clearTrail() -- 1012
		deps.plan:flush() -- 1013
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
	local function updateFinale() -- 1028
		deps.aim:setEnabled(false) -- 1029
		if core.flight == nil then -- 1029
			return -- 1030
		end -- 1030
		local idx = ____exports.coreProbeIndex(core) -- 1031
		local pos = core.flight.points[idx + 1] -- 1032
		local tWorld = core.t0 + core.flightTime -- 1033
		deps.scene.syncBodies(tWorld) -- 1036
		deps.scene.syncProbe(pos) -- 1037
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1038
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1041
		deps.camera:lookAt( -- 1042
			frame.eye, -- 1042
			frame.target, -- 1042
			Vec3(0, 1, 0) -- 1042
		) -- 1042
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1043
		local trail = {} -- 1046
		do -- 1046
			local i = 0 -- 1047
			while i <= idx do -- 1047
				trail[#trail + 1] = core.flight.points[i + 1] -- 1047
				i = i + 1 -- 1047
			end -- 1047
		end -- 1047
		local rings = goalRingsAt(tWorld, idx) -- 1048
		local basis = makeBasis(frame) -- 1049
		deps.trajectory:setTrail(trail, basis) -- 1050
		deps.trajectory:setGoalRings(rings, basis) -- 1051
		deps.plan:clearPrediction() -- 1052
		deps.plan:setGoalRings(rings) -- 1053
		deps.plan:flush() -- 1054
	end -- 1028
	local function updateFlying(dt) -- 1056
		deps.aim:setEnabled(false) -- 1057
		local entered = ____exports.coreUpdate(core, dt, level) -- 1060
		if core.flight == nil then -- 1060
			return entered -- 1061
		end -- 1061
		local idx = ____exports.coreProbeIndex(core) -- 1063
		local pos = core.flight.points[idx + 1] -- 1064
		local tWorld = core.t0 + core.flightTime -- 1068
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1068
			lastSlowmo = core.slowmo -- 1072
			lastSlowmoBody = core.slowmoBody -- 1073
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1074
			local nearD = near ~= nil and distance( -- 1075
				pos, -- 1075
				bodyPositionAt(near, tWorld) -- 1075
			) or 0 -- 1075
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1076
		end -- 1076
		flightLogT = flightLogT + dt -- 1083
		if flightLogT >= 0.5 then -- 1083
			flightLogT = 0 -- 1085
			local total = (#core.flight.points - 1) * core.dt -- 1086
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1087
		end -- 1087
		deps.scene.syncBodies(tWorld) -- 1093
		deps.scene.syncProbe(pos) -- 1094
		if idx > 0 then -- 1094
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1096
		end -- 1096
		local fr -- 1103
		local closeDist = nil -- 1104
		if core.slowmo and core.slowmoBody >= 0 then -- 1104
			local near = level.bodies[core.slowmoBody + 1] -- 1106
			fr = { -- 1107
				pts = { -- 1107
					pos, -- 1107
					bodyPositionAt(near, tWorld) -- 1107
				}, -- 1107
				radii = {deps.scene.probeRadius, near.radius} -- 1107
			} -- 1107
			closeDist = SlowMoCloseDist -- 1108
		else -- 1108
			fr = framingPoints(pos, tWorld) -- 1110
		end -- 1110
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1112
		deps.rig.apply(deps.camera, frame) -- 1113
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1114
		local basis = makeBasis(frame) -- 1115
		local trail = {} -- 1118
		do -- 1118
			local i = 0 -- 1119
			while i <= idx do -- 1119
				trail[#trail + 1] = core.flight.points[i + 1] -- 1119
				i = i + 1 -- 1119
			end -- 1119
		end -- 1119
		local rings = goalRingsAt(tWorld, idx) -- 1120
		deps.trajectory:setTrail(trail, basis) -- 1121
		deps.trajectory:setGoalRings(rings, basis) -- 1122
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1125
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1126
		deps.plan:setTrail(trail) -- 1127
		deps.plan:clearPrediction() -- 1128
		deps.plan:setGoalRings(rings) -- 1129
		deps.plan:flush() -- 1130
		return entered -- 1132
	end -- 1056
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1146
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1147
		core.t0 = next.t0 -- 1148
		clock = next.clock -- 1149
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1150
	end -- 1146
	local function update(dt) -- 1153
		applyView() -- 1156
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1156
			updateAiming(dt) -- 1158
		elseif core.phase == "Flying" then -- 1158
			local entered = updateFlying(dt) -- 1160
			if entered and core.result ~= nil then -- 1160
				local toFinale = deps.finale == true and core.result == "success" -- 1163
				if toFinale then -- 1163
					____exports.coreEnterFinale(core) -- 1164
				end -- 1164
				deps:onResult(core.result) -- 1166
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1166
					local ____end = #core.flight.points - 1 -- 1168
					deps:onFinale({ -- 1169
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1170
						time = core.flightTime, -- 1171
						tWorld = core.t0 + core.flightTime -- 1172
					}) -- 1172
				end -- 1172
				deps:onPhase(toFinale and "Finale" or "Result") -- 1175
			end -- 1175
		elseif core.phase == "Finale" then -- 1175
			updateFinale() -- 1178
		end -- 1178
	end -- 1153
	return { -- 1183
		phase = function() return core.phase end, -- 1184
		result = function() return core.result end, -- 1185
		onAimDrag = function(____, a) -- 1186
			core.aim = a -- 1187
			aimed = true -- 1188
			introT = IntroDurationSec -- 1189
		end, -- 1186
		aimReady = function() -- 1191
			if not ____exports.coreArm(core) then -- 1191
				return -- 1192
			end -- 1192
			applyView() -- 1193
			deps:onPhase("Armed") -- 1194
		end, -- 1191
		launchArmed = function() -- 1196
			if core.phase ~= "Armed" then -- 1196
				return -- 1198
			end -- 1198
			handoffDate(true) -- 1199
			____exports.coreLaunch( -- 1200
				core, -- 1200
				core.aim.velocity, -- 1200
				level, -- 1200
				probePos, -- 1200
				probeVel -- 1200
			) -- 1200
			deps.trajectory:clearPrediction() -- 1201
			deps.plan:clearPrediction() -- 1202
			applyView() -- 1203
			deps:onPhase("Flying") -- 1204
		end, -- 1196
		armed = function() return core.phase == "Armed" end, -- 1206
		viewMode = function() return core.viewMode end, -- 1207
		toggleViewMode = function() -- 1208
			____exports.coreToggleView(core) -- 1210
			applyView() -- 1211
		end, -- 1208
		observeDrag = function(____, dx, dy) -- 1213
			introT = IntroDurationSec -- 1214
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1215
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1216
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1217
			if obsPitchDeg > 40 then -- 1217
				obsPitchDeg = 40 -- 1218
			end -- 1218
			if obsPitchDeg < -40 then -- 1218
				obsPitchDeg = -40 -- 1219
			end -- 1219
		end, -- 1213
		observeZoom = function(____, deltaDist) -- 1221
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1222
			if obsZoom < 0.4 then -- 1222
				obsZoom = 0.4 -- 1223
			end -- 1223
			if obsZoom > 1.8 then -- 1223
				obsZoom = 1.8 -- 1224
			end -- 1224
		end, -- 1221
		launch = function(____, v) -- 1226
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1226
				return -- 1227
			end -- 1227
			handoffDate(true) -- 1228
			____exports.coreLaunch( -- 1230
				core, -- 1230
				v, -- 1230
				level, -- 1230
				probePos, -- 1230
				probeVel -- 1230
			) -- 1230
			deps.trajectory:clearPrediction() -- 1231
			deps.plan:clearPrediction() -- 1232
			applyView() -- 1233
			deps:onPhase("Flying") -- 1234
		end, -- 1226
		retry = function() -- 1236
			if core.phase ~= "Result" then -- 1236
				return -- 1237
			end -- 1237
			handoffDate(false) -- 1238
			aimed = false -- 1239
			____exports.coreRetry(core) -- 1240
			deps.trajectory:clearTrail() -- 1241
			deps.trajectory:clearPrediction() -- 1242
			deps.trajectory:clearGoalRings() -- 1243
			deps.plan:clearTrail() -- 1244
			deps.plan:clearPrediction() -- 1245
			deps.plan:clearGoalRings() -- 1246
			applyView() -- 1247
			deps:onPhase("Aiming") -- 1248
		end, -- 1236
		backToSelect = function() -- 1250
			if not ____exports.coreBackToSelect(core) then -- 1250
				return false -- 1251
			end -- 1251
			deps.aim:setEnabled(false) -- 1253
			deps.trajectory:clearTrail() -- 1254
			deps.trajectory:clearPrediction() -- 1255
			deps.trajectory:clearGoalRings() -- 1256
			deps.plan:clearTrail() -- 1257
			deps.plan:clearPrediction() -- 1258
			deps.plan:clearGoalRings() -- 1259
			applyView() -- 1260
			deps:onPhase("LevelSelect") -- 1261
			return true -- 1262
		end, -- 1250
		startLevel = function() -- 1264
			aimed = false -- 1267
			____exports.coreRetry(core) -- 1268
			deps.rig.reset() -- 1271
			introT = 0 -- 1272
			introLogged = false -- 1273
			prepareIdle() -- 1274
			deps.trajectory:clearTrail() -- 1275
			deps.trajectory:clearPrediction() -- 1276
			deps.trajectory:clearGoalRings() -- 1277
			deps.plan:clearTrail() -- 1278
			deps.plan:clearPrediction() -- 1279
			deps.plan:clearGoalRings() -- 1280
			appliedMode = "" -- 1283
			applyView() -- 1284
			deps:onPhase("Aiming") -- 1285
		end, -- 1264
		stepTime = function(____, dir, span) -- 1287
			if not ____exports.coreTimeWarpAllowed(core) then -- 1287
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1291
				return -- 1292
			end -- 1292
			local span0 = span > 0 and span or 0 -- 1294
			clock = clock + dir * TimeWarpStep -- 1295
			if clock < 0 then -- 1295
				clock = 0 -- 1296
			end -- 1296
			if span0 > 0 and clock > span0 then -- 1296
				clock = span0 -- 1297
			end -- 1297
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1299
		end, -- 1287
		dateNow = function() return core.t0 + clock end, -- 1301
		setBrakeMode = function(____, on) -- 1302
			core.brakeMode = on -- 1303
		end, -- 1302
		brakeMode = function() return core.brakeMode end, -- 1306
		setPlaybackSpeed = function(____, speed) -- 1307
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1307
				return -- 1309
			end -- 1309
			core.playback = speed -- 1310
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1311
		end, -- 1307
		playbackSpeed = function() return core.playback end, -- 1313
		update = function(____, frameDt) return update(frameDt) end -- 1315
	} -- 1315
end -- 605
return ____exports -- 605
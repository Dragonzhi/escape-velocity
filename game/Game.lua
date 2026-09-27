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
function ____exports.createCore() -- 142
	return { -- 143
		phase = "Aiming", -- 144
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 145
		flight = nil, -- 146
		dt = PhysicsStep, -- 147
		brakeMode = false, -- 148
		t0 = 0, -- 149
		flightTime = 0, -- 150
		goalIndex = -1, -- 151
		result = nil, -- 152
		viewMode = "2D", -- 154
		playback = FlightPlayback, -- 156
		slowmo = false, -- 157
		slowmoBody = -1 -- 158
	} -- 158
end -- 142
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 170
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 171
	return core.viewMode -- 172
end -- 170
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 190
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 196
	local share = brakeMode and BrakeShare or 1 -- 197
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 198
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 199
	local brake = brakeMode and mag > 0 and ({ -- 200
		dv = mag * (1 - share), -- 201
		startStep = math.floor(maxSteps / 2) -- 201
	}) or nil -- 201
	return {init = init, brake = brake} -- 203
end -- 190
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 212
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 212
		return -- 214
	end -- 214
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 215
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 216
	local p0 = from ~= nil and from or level.probeStart -- 217
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 218
		steps = level.maxSteps, -- 221
		dt = core.dt, -- 221
		sampleEvery = 1, -- 221
		escapeRadius = level.escapeRadius, -- 221
		t0 = core.t0, -- 221
		brake = motion.brake -- 221
	}) -- 221
	core.flight = flight -- 223
	core.goalIndex = findGoalIndex( -- 224
		flight.points, -- 224
		level.bodies, -- 224
		level.goal, -- 224
		core.dt, -- 224
		core.t0, -- 224
		flight.velocities -- 224
	) -- 224
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 225
	core.flightTime = 0 -- 226
	core.slowmo = false -- 228
	core.slowmoBody = -1 -- 229
	core.phase = "Flying" -- 230
	core.viewMode = "3D" -- 232
end -- 212
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 241
	if core.phase ~= "Aiming" then -- 241
		return false -- 242
	end -- 242
	core.phase = "Armed" -- 243
	return true -- 244
end -- 241
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 248
	if core.phase ~= "Armed" then -- 248
		return false -- 249
	end -- 249
	core.phase = "Aiming" -- 250
	return true -- 251
end -- 248
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 265
	return core.phase == "Aiming" or core.phase == "Armed" -- 266
end -- 265
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 282
	if toT0 then -- 282
		return {t0 = clock, clock = 0} -- 283
	end -- 283
	return {t0 = 0, clock = t0} -- 284
end -- 282
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 296
	local best = -1 -- 297
	do -- 297
		local i = 0 -- 298
		while i < #bodies do -- 298
			do -- 298
				local b = bodies[i + 1] -- 299
				if b.orbitRadius ~= 0 then -- 299
					goto __continue21 -- 300
				end -- 300
				if best < 0 or b.gm > bodies[best + 1].gm then -- 300
					best = i -- 301
				end -- 301
			end -- 301
			::__continue21:: -- 301
			i = i + 1 -- 298
		end -- 298
	end -- 298
	return best -- 303
end -- 296
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
function ____exports.slowMotionBody(bodies, probe, t, anchor) -- 318
	local best = -1 -- 319
	local bestD = 1000000000 -- 320
	do -- 320
		local i = 0 -- 321
		while i < #bodies do -- 321
			do -- 321
				if i == anchor then -- 321
					goto __continue26 -- 322
				end -- 322
				local b = bodies[i + 1] -- 323
				local threshold = math.max(b.radius * SlowMoRadiusFactor, SlowMoFloorDist) -- 324
				local d = distance( -- 325
					probe, -- 325
					bodyPositionAt(b, t) -- 325
				) -- 325
				if d < threshold and d < bestD then -- 325
					bestD = d -- 327
					best = i -- 328
				end -- 328
			end -- 328
			::__continue26:: -- 328
			i = i + 1 -- 321
		end -- 321
	end -- 321
	return best -- 331
end -- 318
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 335
	if core.flight == nil then -- 335
		return 0 -- 336
	end -- 336
	local idx = math.floor(core.flightTime / core.dt) -- 337
	local last = #core.flight.points - 1 -- 338
	if idx > last then -- 338
		idx = last -- 339
	end -- 339
	if idx < 0 then -- 339
		idx = 0 -- 340
	end -- 340
	return idx -- 341
end -- 335
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
function ____exports.coreUpdate(core, dt, level) -- 358
	if core.phase ~= "Flying" or core.flight == nil then -- 358
		return false -- 359
	end -- 359
	if level ~= nil then -- 359
		local idx = ____exports.coreProbeIndex(core) -- 363
		core.slowmoBody = ____exports.slowMotionBody( -- 364
			level.bodies, -- 364
			core.flight.points[idx + 1], -- 364
			core.t0 + core.flightTime, -- 364
			____exports.anchorBodyIndex(level.bodies) -- 364
		) -- 364
		core.slowmo = core.slowmoBody >= 0 -- 365
	end -- 365
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 368
	core.flightTime = core.flightTime + dt * speed -- 369
	local naturalEnd = #core.flight.points - 1 -- 370
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 371
	if ____exports.coreProbeIndex(core) >= endIdx then -- 371
		core.flightTime = endIdx * core.dt -- 374
		core.phase = "Result" -- 375
		return true -- 376
	end -- 376
	return false -- 378
end -- 358
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 382
	core.phase = "Aiming" -- 383
	core.viewMode = "2D" -- 385
	core.flight = nil -- 386
	core.flightTime = 0 -- 387
	core.goalIndex = -1 -- 388
	core.result = nil -- 389
	core.slowmo = false -- 390
	core.slowmoBody = -1 -- 391
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 392
end -- 382
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 406
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 406
		return false -- 408
	end -- 408
	core.phase = "LevelSelect" -- 409
	core.viewMode = "2D" -- 411
	core.flight = nil -- 412
	core.flightTime = 0 -- 413
	core.goalIndex = -1 -- 414
	core.result = nil -- 415
	core.slowmo = false -- 416
	core.slowmoBody = -1 -- 417
	return true -- 418
end -- 406
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 447
	if core.phase ~= "Result" then -- 447
		return false -- 448
	end -- 448
	core.phase = "Finale" -- 449
	return true -- 450
end -- 447
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 468
	local dist = distance > 1 and distance or 1 -- 469
	local ux = probe.x -- 471
	local uy = probe.y -- 472
	local len = math.sqrt(ux * ux + uy * uy) -- 473
	if len < 0.000001 then -- 473
		ux = 0 -- 474
		uy = 1 -- 474
	else -- 474
		ux = ux / len -- 474
		uy = uy / len -- 474
	end -- 474
	local tilt = tiltDeg * math.pi / 180 -- 475
	local flat = math.cos(tilt) * dist -- 476
	return { -- 477
		target = Vec3(0, 0, 0), -- 479
		eye = Vec3( -- 480
			ux * flat * PlaneToWorldX, -- 480
			math.sin(tilt) * dist, -- 480
			uy * flat * PlaneToWorldZ -- 480
		) -- 480
	} -- 480
end -- 468
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 585
	local core = ____exports.createCore() -- 586
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 589
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
	local function applyView() -- 604
		local mode = core.viewMode -- 605
		if mode == appliedMode then -- 605
			return -- 606
		end -- 606
		appliedMode = mode -- 607
		local is2D = mode == "2D" -- 608
		deps.plan:setVisible(is2D) -- 609
		deps.trajectory.root.visible = not is2D -- 610
		deps:setWorldVisible(not is2D) -- 611
		deps.aim:setFullScreenAim(is2D) -- 612
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 613
	end -- 604
	local function makeBasis(frame) -- 616
		return prepareCamera({ -- 617
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 619
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 620
			up = {x = 0, y = 1, z = 0}, -- 621
			fovYDeg = deps.fovYDeg, -- 622
			aspect = deps.aspect, -- 623
			viewW = deps.viewW, -- 624
			viewH = deps.viewH -- 625
		}, HANDEDNESS, FLIP_Y) -- 625
	end -- 616
	local predKey = "" -- 634
	local predPoints = {} -- 635
	local introT = IntroDurationSec -- 637
	local introLogged = false -- 638
	local clock = 0 -- 644
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 646
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 648
	local obsYawDeg = 0 -- 652
	local obsPitchDeg = 0 -- 653
	local obsZoom = 1 -- 654
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 656
	local idlePath = nil -- 657
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 668
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 670
	local lastSlowmoBody = -1 -- 671
	local flightLogT = 0 -- 672
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 674
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 675
	local function prepareIdle() -- 676
		clock = 0 -- 678
		core.t0 = 0 -- 679
		if level.probeVel0 == nil then -- 679
			idlePath = nil -- 681
			return -- 682
		end -- 682
		local idleSteps = level.maxSteps -- 690
		local v0x = level.probeVel0.x -- 691
		local v0y = level.probeVel0.y -- 692
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 693
		if v0 > 0.000001 then -- 693
			local bestD = 1000000000 -- 695
			for ____, b in ipairs(level.bodies) do -- 696
				do -- 696
					if b.gm <= 0 then -- 696
						goto __continue52 -- 697
					end -- 697
					local dx = b.orbitCenter.x - level.probeStart.x -- 698
					local dy = b.orbitCenter.y - level.probeStart.y -- 699
					local d = math.sqrt(dx * dx + dy * dy) -- 700
					if d < bestD then -- 700
						bestD = d -- 701
					end -- 701
				end -- 701
				::__continue52:: -- 701
			end -- 701
			if bestD > 0.000001 and bestD < 100000000 then -- 701
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 704
				if n > 60 and n < 40000 then -- 704
					idleSteps = n -- 705
				end -- 705
			end -- 705
		end -- 705
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 708
			steps = idleSteps, -- 711
			dt = core.dt, -- 711
			sampleEvery = 1, -- 711
			escapeRadius = level.escapeRadius, -- 711
			t0 = core.t0 -- 711
		}) -- 711
	end -- 676
	local function idleIndex() -- 714
		if idlePath == nil then -- 714
			return 0 -- 715
		end -- 715
		local n = #idlePath.points -- 716
		if n <= 1 then -- 716
			return 0 -- 717
		end -- 717
		local i = math.floor(orbitClock / core.dt) % n -- 718
		if i < 0 then -- 718
			i = 0 -- 719
		end -- 719
		return i -- 720
	end -- 714
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 730
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 731
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 734
		local wps = goalWaypoints(level.goal) -- 735
		if #wps == 0 then -- 735
			return nil -- 736
		end -- 736
		local passed = 0 -- 737
		if core.flight ~= nil then -- 737
			local upto = math.floor(core.flightTime / core.dt) -- 739
			passed = waypointProgress( -- 740
				core.flight.points, -- 740
				level.bodies, -- 740
				level.goal, -- 740
				core.dt, -- 740
				core.t0, -- 740
				upto, -- 740
				core.flight.velocities -- 740
			).passed -- 740
		end -- 740
		if passed >= #wps then -- 740
			return nil -- 742
		end -- 742
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 743
	end -- 734
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 754
		local corePts = {probe} -- 757
		local coreRadii = {deps.scene.probeRadius} -- 758
		local next = nextStationBody() -- 759
		local nextTol = 0 -- 760
		if next ~= nil then -- 760
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 762
			local wps = goalWaypoints(level.goal) -- 763
			local passed = 0 -- 764
			if core.flight ~= nil then -- 764
				passed = waypointProgress( -- 766
					core.flight.points, -- 766
					level.bodies, -- 766
					level.goal, -- 766
					core.dt, -- 766
					core.t0, -- 766
					math.floor(core.flightTime / core.dt), -- 766
					core.flight.velocities -- 766
				).passed -- 766
			end -- 766
			if passed < #wps then -- 766
				nextTol = wps[passed + 1].tolerance -- 768
			end -- 768
			local r = nextTol > next.radius and nextTol or next.radius -- 769
			coreRadii[#coreRadii + 1] = r -- 770
		end -- 770
		if anchorDef == nil then -- 770
			return {pts = corePts, radii = coreRadii} -- 773
		end -- 773
		local withAnchorPts = { -- 774
			probe, -- 774
			bodyPositionAt(anchorDef, t) -- 774
		} -- 774
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 775
		do -- 775
			local i = 1 -- 776
			while i < #corePts do -- 776
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 777
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 778
				i = i + 1 -- 776
			end -- 776
		end -- 776
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 780
		if want <= CameraFramingBudget then -- 780
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 781
		end -- 781
		return {pts = corePts, radii = coreRadii} -- 782
	end -- 754
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 786
		local wps = goalWaypoints(level.goal) -- 787
		if #wps == 0 then -- 787
			return {} -- 788
		end -- 788
		local passed = 0 -- 789
		if upto ~= nil and core.flight ~= nil then -- 789
			passed = waypointProgress( -- 791
				core.flight.points, -- 791
				level.bodies, -- 791
				level.goal, -- 791
				core.dt, -- 791
				core.t0, -- 791
				upto, -- 791
				core.flight.velocities -- 791
			).passed -- 791
		end -- 791
		if passed >= #wps then -- 791
			return {} -- 796
		end -- 796
		local nextWp = wps[passed + 1] -- 797
		local body = level.bodies[nextWp.planetIndex + 1] -- 798
		if body == nil then -- 798
			return {} -- 799
		end -- 799
		return {{ -- 800
			center = bodyPositionAt(body, t), -- 800
			radius = nextWp.tolerance, -- 800
			passed = false -- 800
		}} -- 800
	end -- 786
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 804
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 804
			return f -- 805
		end -- 805
		local dx = f.eye.x - f.target.x -- 806
		local dy = f.eye.y - f.target.y -- 807
		local dz = f.eye.z - f.target.z -- 808
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 809
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 810
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 811
		local lo = CameraTiltMin * math.pi / 180 -- 812
		local hi = CameraTiltMax * math.pi / 180 -- 813
		if pitch < lo then -- 813
			pitch = lo -- 814
		end -- 814
		if pitch > hi then -- 814
			pitch = hi -- 815
		end -- 815
		local cp = math.cos(pitch) -- 816
		return { -- 817
			target = f.target, -- 818
			eye = Vec3( -- 819
				f.target.x + r * cp * math.sin(yaw), -- 820
				f.target.y + r * math.sin(pitch), -- 821
				f.target.z + r * cp * math.cos(yaw) -- 822
			) -- 822
		} -- 822
	end -- 804
	local function updateAiming(dt) -- 827
		deps.aim:setEnabled(true) -- 828
		local dragging = deps.aim:isDragging() -- 830
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 830
			clock = clock + dt -- 833
			orbitClock = orbitClock + dt -- 834
		end -- 834
		local idx = idleIndex() -- 836
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 837
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 838
		local tNow = core.t0 + clock -- 841
		deps.scene.syncBodies(tNow) -- 843
		deps.scene.syncProbe(probePos) -- 844
		if idlePath ~= nil and idx > 0 then -- 844
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 845
		end -- 845
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 847
		deps.plan:syncProbe(probePos, probeVel) -- 848
		local fr = framingPoints(probePos, tNow) -- 851
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 852
		if introT < IntroDurationSec then -- 852
			introT = introT + dt -- 856
			local k = introT / IntroDurationSec -- 857
			if k > 1 then -- 857
				k = 1 -- 858
			end -- 858
			if k >= 1 and not introLogged then -- 858
				introLogged = true -- 860
				print("[escape-velocity] intro camera done") -- 861
			end -- 861
			local wps0 = goalWaypoints(level.goal) -- 863
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 864
			local wide = frame -- 865
			local from = wide -- 866
			local to = wide -- 867
			local e = 0 -- 868
			if k < 0.35 then -- 868
				local pw = planeToWorld(probePos, 0) -- 870
				local dx = wide.eye.x - wide.target.x -- 871
				local dy = wide.eye.y - wide.target.y -- 872
				local dz = wide.eye.z - wide.target.z -- 873
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 874
				if len > 0.000001 then -- 874
					local s = IntroCloseDist / len -- 876
					dx = dx * s -- 877
					dy = dy * s -- 877
					dz = dz * s -- 877
				end -- 877
				from = { -- 879
					target = Vec3(pw.x, pw.y, pw.z), -- 879
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 879
				} -- 879
				e = k / 0.35 -- 880
			elseif k < 0.72 and wpBody ~= nil then -- 880
				local c = planeToWorld( -- 883
					bodyPositionAt(wpBody, tNow), -- 883
					0 -- 883
				) -- 883
				local dx = wide.eye.x - wide.target.x -- 884
				local dy = wide.eye.y - wide.target.y -- 885
				local dz = wide.eye.z - wide.target.z -- 886
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 887
				local want = math.max(24, wpBody.radius * 6) -- 888
				if len > 0.000001 then -- 888
					local s = want / len -- 890
					dx = dx * s -- 891
					dy = dy * s -- 891
					dz = dz * s -- 891
				end -- 891
				to = { -- 893
					target = Vec3(c.x, c.y, c.z), -- 893
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 893
				} -- 893
				e = (k - 0.35) / 0.37 -- 894
			elseif wpBody ~= nil then -- 894
				local c = planeToWorld( -- 897
					bodyPositionAt(wpBody, tNow), -- 897
					0 -- 897
				) -- 897
				local dx = wide.eye.x - wide.target.x -- 898
				local dy = wide.eye.y - wide.target.y -- 899
				local dz = wide.eye.z - wide.target.z -- 900
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 901
				local want = math.max(24, wpBody.radius * 6) -- 902
				if len > 0.000001 then -- 902
					local s = want / len -- 904
					dx = dx * s -- 905
					dy = dy * s -- 905
					dz = dz * s -- 905
				end -- 905
				from = { -- 907
					target = Vec3(c.x, c.y, c.z), -- 907
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 907
				} -- 907
				e = (k - 0.72) / 0.28 -- 908
			end -- 908
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 910
			frame = { -- 911
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 912
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 917
			} -- 917
		end -- 917
		frame = applyObserve(frame) -- 925
		deps.rig.apply(deps.camera, frame) -- 926
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 927
		local basis = makeBasis(frame) -- 928
		if core.viewMode == "2D" then -- 928
			local sp = deps.plan:probeScreen() -- 934
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 935
		else -- 935
			local pp = projectPrepared( -- 937
				planeToWorld(probePos, 0), -- 937
				basis -- 937
			) -- 937
			if pp ~= nil then -- 937
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 938
			end -- 938
		end -- 938
		if not aimed then -- 938
			deps.trajectory:clearPrediction() -- 951
			deps.plan:clearPrediction() -- 952
			predKey = "" -- 953
		else -- 953
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 957
			if key ~= predKey then -- 957
				predKey = key -- 961
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 964
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 965
					steps = PredictSteps, -- 968
					dt = core.dt, -- 968
					sampleEvery = 4, -- 968
					escapeRadius = level.escapeRadius, -- 968
					t0 = tNow, -- 968
					brake = motion.brake -- 968
				}).points -- 968
			end -- 968
			deps.trajectory:setPrediction(predPoints, basis) -- 971
			deps.plan:setPrediction(predPoints) -- 973
		end -- 973
		local rings = goalRingsAt(tNow) -- 975
		deps.trajectory:setGoalRings(rings, basis) -- 976
		deps.trajectory:clearTrail() -- 977
		deps.plan:setGoalRings(rings) -- 979
		deps.plan:clearTrail() -- 980
		deps.plan:flush() -- 981
	end -- 827
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
	local function updateFinale() -- 996
		deps.aim:setEnabled(false) -- 997
		if core.flight == nil then -- 997
			return -- 998
		end -- 998
		local idx = ____exports.coreProbeIndex(core) -- 999
		local pos = core.flight.points[idx + 1] -- 1000
		local tWorld = core.t0 + core.flightTime -- 1001
		deps.scene.syncBodies(tWorld) -- 1004
		deps.scene.syncProbe(pos) -- 1005
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1006
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1009
		deps.camera:lookAt( -- 1010
			frame.eye, -- 1010
			frame.target, -- 1010
			Vec3(0, 1, 0) -- 1010
		) -- 1010
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1011
		local trail = {} -- 1014
		do -- 1014
			local i = 0 -- 1015
			while i <= idx do -- 1015
				trail[#trail + 1] = core.flight.points[i + 1] -- 1015
				i = i + 1 -- 1015
			end -- 1015
		end -- 1015
		local rings = goalRingsAt(tWorld, idx) -- 1016
		local basis = makeBasis(frame) -- 1017
		deps.trajectory:setTrail(trail, basis) -- 1018
		deps.trajectory:setGoalRings(rings, basis) -- 1019
		deps.plan:clearPrediction() -- 1020
		deps.plan:setGoalRings(rings) -- 1021
		deps.plan:flush() -- 1022
	end -- 996
	local function updateFlying(dt) -- 1024
		deps.aim:setEnabled(false) -- 1025
		local entered = ____exports.coreUpdate(core, dt, level) -- 1028
		if core.flight == nil then -- 1028
			return entered -- 1029
		end -- 1029
		local idx = ____exports.coreProbeIndex(core) -- 1031
		local pos = core.flight.points[idx + 1] -- 1032
		local tWorld = core.t0 + core.flightTime -- 1036
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1036
			lastSlowmo = core.slowmo -- 1040
			lastSlowmoBody = core.slowmoBody -- 1041
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1042
			local nearD = near ~= nil and distance( -- 1043
				pos, -- 1043
				bodyPositionAt(near, tWorld) -- 1043
			) or 0 -- 1043
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1044
		end -- 1044
		flightLogT = flightLogT + dt -- 1051
		if flightLogT >= 0.5 then -- 1051
			flightLogT = 0 -- 1053
			local total = (#core.flight.points - 1) * core.dt -- 1054
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1055
		end -- 1055
		deps.scene.syncBodies(tWorld) -- 1061
		deps.scene.syncProbe(pos) -- 1062
		if idx > 0 then -- 1062
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1064
		end -- 1064
		local fr -- 1071
		local closeDist = nil -- 1072
		if core.slowmo and core.slowmoBody >= 0 then -- 1072
			local near = level.bodies[core.slowmoBody + 1] -- 1074
			fr = { -- 1075
				pts = { -- 1075
					pos, -- 1075
					bodyPositionAt(near, tWorld) -- 1075
				}, -- 1075
				radii = {deps.scene.probeRadius, near.radius} -- 1075
			} -- 1075
			closeDist = SlowMoCloseDist -- 1076
		else -- 1076
			fr = framingPoints(pos, tWorld) -- 1078
		end -- 1078
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1080
		deps.rig.apply(deps.camera, frame) -- 1081
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1082
		local basis = makeBasis(frame) -- 1083
		local trail = {} -- 1086
		do -- 1086
			local i = 0 -- 1087
			while i <= idx do -- 1087
				trail[#trail + 1] = core.flight.points[i + 1] -- 1087
				i = i + 1 -- 1087
			end -- 1087
		end -- 1087
		local rings = goalRingsAt(tWorld, idx) -- 1088
		deps.trajectory:setTrail(trail, basis) -- 1089
		deps.trajectory:setGoalRings(rings, basis) -- 1090
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1093
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1094
		deps.plan:setTrail(trail) -- 1095
		deps.plan:clearPrediction() -- 1096
		deps.plan:setGoalRings(rings) -- 1097
		deps.plan:flush() -- 1098
		return entered -- 1100
	end -- 1024
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1114
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1115
		core.t0 = next.t0 -- 1116
		clock = next.clock -- 1117
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1118
	end -- 1114
	local function update(dt) -- 1121
		applyView() -- 1124
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1124
			updateAiming(dt) -- 1126
		elseif core.phase == "Flying" then -- 1126
			local entered = updateFlying(dt) -- 1128
			if entered and core.result ~= nil then -- 1128
				local toFinale = deps.finale == true and core.result == "success" -- 1131
				if toFinale then -- 1131
					____exports.coreEnterFinale(core) -- 1132
				end -- 1132
				deps:onResult(core.result) -- 1134
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1134
					local ____end = #core.flight.points - 1 -- 1136
					deps:onFinale({ -- 1137
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1138
						time = core.flightTime, -- 1139
						tWorld = core.t0 + core.flightTime -- 1140
					}) -- 1140
				end -- 1140
				deps:onPhase(toFinale and "Finale" or "Result") -- 1143
			end -- 1143
		elseif core.phase == "Finale" then -- 1143
			updateFinale() -- 1146
		end -- 1146
	end -- 1121
	return { -- 1151
		phase = function() return core.phase end, -- 1152
		result = function() return core.result end, -- 1153
		onAimDrag = function(____, a) -- 1154
			core.aim = a -- 1155
			aimed = true -- 1156
			introT = IntroDurationSec -- 1157
		end, -- 1154
		aimReady = function() -- 1159
			if not ____exports.coreArm(core) then -- 1159
				return -- 1160
			end -- 1160
			applyView() -- 1161
			deps:onPhase("Armed") -- 1162
		end, -- 1159
		launchArmed = function() -- 1164
			if core.phase ~= "Armed" then -- 1164
				return -- 1166
			end -- 1166
			handoffDate(true) -- 1167
			____exports.coreLaunch( -- 1168
				core, -- 1168
				core.aim.velocity, -- 1168
				level, -- 1168
				probePos, -- 1168
				probeVel -- 1168
			) -- 1168
			deps.trajectory:clearPrediction() -- 1169
			deps.plan:clearPrediction() -- 1170
			applyView() -- 1171
			deps:onPhase("Flying") -- 1172
		end, -- 1164
		armed = function() return core.phase == "Armed" end, -- 1174
		viewMode = function() return core.viewMode end, -- 1175
		toggleViewMode = function() -- 1176
			____exports.coreToggleView(core) -- 1178
			applyView() -- 1179
		end, -- 1176
		observeDrag = function(____, dx, dy) -- 1181
			introT = IntroDurationSec -- 1182
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1183
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1184
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1185
			if obsPitchDeg > 40 then -- 1185
				obsPitchDeg = 40 -- 1186
			end -- 1186
			if obsPitchDeg < -40 then -- 1186
				obsPitchDeg = -40 -- 1187
			end -- 1187
		end, -- 1181
		observeZoom = function(____, deltaDist) -- 1189
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1190
			if obsZoom < 0.4 then -- 1190
				obsZoom = 0.4 -- 1191
			end -- 1191
			if obsZoom > 1.8 then -- 1191
				obsZoom = 1.8 -- 1192
			end -- 1192
		end, -- 1189
		launch = function(____, v) -- 1194
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1194
				return -- 1195
			end -- 1195
			handoffDate(true) -- 1196
			____exports.coreLaunch( -- 1198
				core, -- 1198
				v, -- 1198
				level, -- 1198
				probePos, -- 1198
				probeVel -- 1198
			) -- 1198
			deps.trajectory:clearPrediction() -- 1199
			deps.plan:clearPrediction() -- 1200
			applyView() -- 1201
			deps:onPhase("Flying") -- 1202
		end, -- 1194
		retry = function() -- 1204
			if core.phase ~= "Result" then -- 1204
				return -- 1205
			end -- 1205
			handoffDate(false) -- 1206
			aimed = false -- 1207
			____exports.coreRetry(core) -- 1208
			deps.trajectory:clearTrail() -- 1209
			deps.trajectory:clearPrediction() -- 1210
			deps.trajectory:clearGoalRings() -- 1211
			deps.plan:clearTrail() -- 1212
			deps.plan:clearPrediction() -- 1213
			deps.plan:clearGoalRings() -- 1214
			applyView() -- 1215
			deps:onPhase("Aiming") -- 1216
		end, -- 1204
		backToSelect = function() -- 1218
			if not ____exports.coreBackToSelect(core) then -- 1218
				return false -- 1219
			end -- 1219
			deps.aim:setEnabled(false) -- 1221
			deps.trajectory:clearTrail() -- 1222
			deps.trajectory:clearPrediction() -- 1223
			deps.trajectory:clearGoalRings() -- 1224
			deps.plan:clearTrail() -- 1225
			deps.plan:clearPrediction() -- 1226
			deps.plan:clearGoalRings() -- 1227
			applyView() -- 1228
			deps:onPhase("LevelSelect") -- 1229
			return true -- 1230
		end, -- 1218
		startLevel = function() -- 1232
			aimed = false -- 1235
			____exports.coreRetry(core) -- 1236
			deps.rig.reset() -- 1239
			introT = 0 -- 1240
			introLogged = false -- 1241
			prepareIdle() -- 1242
			deps.trajectory:clearTrail() -- 1243
			deps.trajectory:clearPrediction() -- 1244
			deps.trajectory:clearGoalRings() -- 1245
			deps.plan:clearTrail() -- 1246
			deps.plan:clearPrediction() -- 1247
			deps.plan:clearGoalRings() -- 1248
			appliedMode = "" -- 1251
			applyView() -- 1252
			deps:onPhase("Aiming") -- 1253
		end, -- 1232
		stepTime = function(____, dir, span) -- 1255
			if not ____exports.coreTimeWarpAllowed(core) then -- 1255
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1259
				return -- 1260
			end -- 1260
			local span0 = span > 0 and span or 0 -- 1262
			clock = clock + dir * TimeWarpStep -- 1263
			if clock < 0 then -- 1263
				clock = 0 -- 1264
			end -- 1264
			if span0 > 0 and clock > span0 then -- 1264
				clock = span0 -- 1265
			end -- 1265
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1267
		end, -- 1255
		dateNow = function() return core.t0 + clock end, -- 1269
		setBrakeMode = function(____, on) -- 1270
			core.brakeMode = on -- 1271
		end, -- 1270
		brakeMode = function() return core.brakeMode end, -- 1274
		setPlaybackSpeed = function(____, speed) -- 1275
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1275
				return -- 1277
			end -- 1277
			core.playback = speed -- 1278
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1279
		end, -- 1275
		playbackSpeed = function() return core.playback end, -- 1281
		update = function(____, frameDt) return update(frameDt) end -- 1283
	} -- 1283
end -- 585
return ____exports -- 585
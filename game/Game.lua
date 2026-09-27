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
function ____exports.createCore(dt) -- 150
	return { -- 151
		phase = "Aiming", -- 152
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 153
		flight = nil, -- 154
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 155
		brakeMode = false, -- 156
		t0 = 0, -- 157
		flightTime = 0, -- 158
		goalIndex = -1, -- 159
		result = nil, -- 160
		viewMode = "2D", -- 162
		playback = FlightPlayback, -- 164
		slowmo = false, -- 165
		slowmoBody = -1 -- 166
	} -- 166
end -- 150
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 178
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 179
	return core.viewMode -- 180
end -- 178
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 198
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 204
	local share = brakeMode and BrakeShare or 1 -- 205
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 206
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 207
	local brake = brakeMode and mag > 0 and ({ -- 208
		dv = mag * (1 - share), -- 209
		startStep = math.floor(maxSteps / 2) -- 209
	}) or nil -- 209
	return {init = init, brake = brake} -- 211
end -- 198
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 220
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 220
		return -- 222
	end -- 222
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 223
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 224
	local p0 = from ~= nil and from or level.probeStart -- 225
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 226
		steps = level.maxSteps, -- 229
		dt = core.dt, -- 229
		sampleEvery = 1, -- 229
		escapeRadius = level.escapeRadius, -- 229
		t0 = core.t0, -- 229
		brake = motion.brake -- 229
	}) -- 229
	core.flight = flight -- 231
	core.goalIndex = findGoalIndex( -- 232
		flight.points, -- 232
		level.bodies, -- 232
		level.goal, -- 232
		core.dt, -- 232
		core.t0, -- 232
		flight.velocities -- 232
	) -- 232
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 233
	core.flightTime = 0 -- 234
	core.slowmo = false -- 236
	core.slowmoBody = -1 -- 237
	core.phase = "Flying" -- 238
	core.viewMode = "3D" -- 240
end -- 220
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 249
	if core.phase ~= "Aiming" then -- 249
		return false -- 250
	end -- 250
	core.phase = "Armed" -- 251
	return true -- 252
end -- 249
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 256
	if core.phase ~= "Armed" then -- 256
		return false -- 257
	end -- 257
	core.phase = "Aiming" -- 258
	return true -- 259
end -- 256
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 273
	return core.phase == "Aiming" or core.phase == "Armed" -- 274
end -- 273
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 290
	if toT0 then -- 290
		return {t0 = clock, clock = 0} -- 291
	end -- 291
	return {t0 = 0, clock = t0} -- 292
end -- 290
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 304
	local best = -1 -- 305
	do -- 305
		local i = 0 -- 306
		while i < #bodies do -- 306
			do -- 306
				local b = bodies[i + 1] -- 307
				if b.orbitRadius ~= 0 then -- 307
					goto __continue21 -- 308
				end -- 308
				if best < 0 or b.gm > bodies[best + 1].gm then -- 308
					best = i -- 309
				end -- 309
			end -- 309
			::__continue21:: -- 309
			i = i + 1 -- 306
		end -- 306
	end -- 306
	return best -- 311
end -- 304
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
function ____exports.slowMotionBody(bodies, probe, t, anchor) -- 326
	local best = -1 -- 327
	local bestD = 1000000000 -- 328
	do -- 328
		local i = 0 -- 329
		while i < #bodies do -- 329
			do -- 329
				if i == anchor then -- 329
					goto __continue26 -- 330
				end -- 330
				local b = bodies[i + 1] -- 331
				local threshold = math.max(b.radius * SlowMoRadiusFactor, SlowMoFloorDist) -- 332
				local d = distance( -- 333
					probe, -- 333
					bodyPositionAt(b, t) -- 333
				) -- 333
				if d < threshold and d < bestD then -- 333
					bestD = d -- 335
					best = i -- 336
				end -- 336
			end -- 336
			::__continue26:: -- 336
			i = i + 1 -- 329
		end -- 329
	end -- 329
	return best -- 339
end -- 326
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 343
	if core.flight == nil then -- 343
		return 0 -- 344
	end -- 344
	local idx = math.floor(core.flightTime / core.dt) -- 345
	local last = #core.flight.points - 1 -- 346
	if idx > last then -- 346
		idx = last -- 347
	end -- 347
	if idx < 0 then -- 347
		idx = 0 -- 348
	end -- 348
	return idx -- 349
end -- 343
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
function ____exports.coreUpdate(core, dt, level) -- 366
	if core.phase ~= "Flying" or core.flight == nil then -- 366
		return false -- 367
	end -- 367
	if level ~= nil then -- 367
		local idx = ____exports.coreProbeIndex(core) -- 371
		core.slowmoBody = ____exports.slowMotionBody( -- 372
			level.bodies, -- 372
			core.flight.points[idx + 1], -- 372
			core.t0 + core.flightTime, -- 372
			____exports.anchorBodyIndex(level.bodies) -- 372
		) -- 372
		core.slowmo = core.slowmoBody >= 0 -- 373
	end -- 373
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 376
	core.flightTime = core.flightTime + dt * speed -- 377
	local naturalEnd = #core.flight.points - 1 -- 378
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 379
	if ____exports.coreProbeIndex(core) >= endIdx then -- 379
		core.flightTime = endIdx * core.dt -- 382
		core.phase = "Result" -- 383
		return true -- 384
	end -- 384
	return false -- 386
end -- 366
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 390
	core.phase = "Aiming" -- 391
	core.viewMode = "2D" -- 393
	core.flight = nil -- 394
	core.flightTime = 0 -- 395
	core.goalIndex = -1 -- 396
	core.result = nil -- 397
	core.slowmo = false -- 398
	core.slowmoBody = -1 -- 399
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 400
end -- 390
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 414
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 414
		return false -- 416
	end -- 416
	core.phase = "LevelSelect" -- 417
	core.viewMode = "2D" -- 419
	core.flight = nil -- 420
	core.flightTime = 0 -- 421
	core.goalIndex = -1 -- 422
	core.result = nil -- 423
	core.slowmo = false -- 424
	core.slowmoBody = -1 -- 425
	return true -- 426
end -- 414
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 455
	if core.phase ~= "Result" then -- 455
		return false -- 456
	end -- 456
	core.phase = "Finale" -- 457
	return true -- 458
end -- 455
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 476
	local dist = distance > 1 and distance or 1 -- 477
	local ux = probe.x -- 479
	local uy = probe.y -- 480
	local len = math.sqrt(ux * ux + uy * uy) -- 481
	if len < 0.000001 then -- 481
		ux = 0 -- 482
		uy = 1 -- 482
	else -- 482
		ux = ux / len -- 482
		uy = uy / len -- 482
	end -- 482
	local tilt = tiltDeg * math.pi / 180 -- 483
	local flat = math.cos(tilt) * dist -- 484
	return { -- 485
		target = Vec3(0, 0, 0), -- 487
		eye = Vec3( -- 488
			ux * flat * PlaneToWorldX, -- 488
			math.sin(tilt) * dist, -- 488
			uy * flat * PlaneToWorldZ -- 488
		) -- 488
	} -- 488
end -- 476
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 593
	local core = ____exports.createCore(level.physicsStep) -- 594
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 597
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 600
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
	local function applyView() -- 615
		local mode = core.viewMode -- 616
		if mode == appliedMode then -- 616
			return -- 617
		end -- 617
		appliedMode = mode -- 618
		local is2D = mode == "2D" -- 619
		deps.plan:setVisible(is2D) -- 620
		deps.trajectory.root.visible = not is2D -- 621
		deps:setWorldVisible(not is2D) -- 622
		deps.aim:setFullScreenAim(is2D) -- 623
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 624
	end -- 615
	local function makeBasis(frame) -- 627
		return prepareCamera({ -- 628
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 630
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 631
			up = {x = 0, y = 1, z = 0}, -- 632
			fovYDeg = deps.fovYDeg, -- 633
			aspect = deps.aspect, -- 634
			viewW = deps.viewW, -- 635
			viewH = deps.viewH -- 636
		}, HANDEDNESS, FLIP_Y) -- 636
	end -- 627
	local predKey = "" -- 645
	local predPoints = {} -- 646
	local introT = IntroDurationSec -- 648
	local introLogged = false -- 649
	local clock = 0 -- 655
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 657
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 659
	local obsYawDeg = 0 -- 663
	local obsPitchDeg = 0 -- 664
	local obsZoom = 1 -- 665
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 667
	local idlePath = nil -- 668
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 679
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 681
	local lastSlowmoBody = -1 -- 682
	local flightLogT = 0 -- 683
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 685
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 686
	local function prepareIdle() -- 687
		clock = 0 -- 689
		core.t0 = 0 -- 690
		if level.probeVel0 == nil then -- 690
			idlePath = nil -- 692
			return -- 693
		end -- 693
		local idleSteps = level.maxSteps -- 701
		local v0x = level.probeVel0.x -- 702
		local v0y = level.probeVel0.y -- 703
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 704
		if v0 > 0.000001 then -- 704
			local bestD = 1000000000 -- 706
			for ____, b in ipairs(level.bodies) do -- 707
				do -- 707
					if b.gm <= 0 then -- 707
						goto __continue52 -- 708
					end -- 708
					local dx = b.orbitCenter.x - level.probeStart.x -- 709
					local dy = b.orbitCenter.y - level.probeStart.y -- 710
					local d = math.sqrt(dx * dx + dy * dy) -- 711
					if d < bestD then -- 711
						bestD = d -- 712
					end -- 712
				end -- 712
				::__continue52:: -- 712
			end -- 712
			if bestD > 0.000001 and bestD < 100000000 then -- 712
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 715
				if n > 60 and n < 40000 then -- 715
					idleSteps = n -- 716
				end -- 716
			end -- 716
		end -- 716
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 719
			steps = idleSteps, -- 722
			dt = core.dt, -- 722
			sampleEvery = 1, -- 722
			escapeRadius = level.escapeRadius, -- 722
			t0 = core.t0 -- 722
		}) -- 722
	end -- 687
	local function idleIndex() -- 725
		if idlePath == nil then -- 725
			return 0 -- 726
		end -- 726
		local n = #idlePath.points -- 727
		if n <= 1 then -- 727
			return 0 -- 728
		end -- 728
		local i = math.floor(orbitClock / core.dt) % n -- 729
		if i < 0 then -- 729
			i = 0 -- 730
		end -- 730
		return i -- 731
	end -- 725
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 741
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 742
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 745
		local wps = goalWaypoints(level.goal) -- 746
		if #wps == 0 then -- 746
			return nil -- 747
		end -- 747
		local passed = 0 -- 748
		if core.flight ~= nil then -- 748
			local upto = math.floor(core.flightTime / core.dt) -- 750
			passed = waypointProgress( -- 751
				core.flight.points, -- 751
				level.bodies, -- 751
				level.goal, -- 751
				core.dt, -- 751
				core.t0, -- 751
				upto, -- 751
				core.flight.velocities -- 751
			).passed -- 751
		end -- 751
		if passed >= #wps then -- 751
			return nil -- 753
		end -- 753
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 754
	end -- 745
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 765
		local corePts = {probe} -- 768
		local coreRadii = {deps.scene.probeRadius} -- 769
		local next = nextStationBody() -- 770
		local nextTol = 0 -- 771
		if next ~= nil then -- 771
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 773
			local wps = goalWaypoints(level.goal) -- 774
			local passed = 0 -- 775
			if core.flight ~= nil then -- 775
				passed = waypointProgress( -- 777
					core.flight.points, -- 777
					level.bodies, -- 777
					level.goal, -- 777
					core.dt, -- 777
					core.t0, -- 777
					math.floor(core.flightTime / core.dt), -- 777
					core.flight.velocities -- 777
				).passed -- 777
			end -- 777
			if passed < #wps then -- 777
				nextTol = wps[passed + 1].tolerance -- 779
			end -- 779
			local r = nextTol > next.radius and nextTol or next.radius -- 780
			coreRadii[#coreRadii + 1] = r -- 781
		end -- 781
		if anchorDef == nil then -- 781
			return {pts = corePts, radii = coreRadii} -- 784
		end -- 784
		local withAnchorPts = { -- 785
			probe, -- 785
			bodyPositionAt(anchorDef, t) -- 785
		} -- 785
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 786
		do -- 786
			local i = 1 -- 787
			while i < #corePts do -- 787
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 788
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 789
				i = i + 1 -- 787
			end -- 787
		end -- 787
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 791
		if want <= CameraFramingBudget then -- 791
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 792
		end -- 792
		return {pts = corePts, radii = coreRadii} -- 793
	end -- 765
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 797
		local wps = goalWaypoints(level.goal) -- 798
		if #wps == 0 then -- 798
			return {} -- 799
		end -- 799
		local passed = 0 -- 800
		if upto ~= nil and core.flight ~= nil then -- 800
			passed = waypointProgress( -- 802
				core.flight.points, -- 802
				level.bodies, -- 802
				level.goal, -- 802
				core.dt, -- 802
				core.t0, -- 802
				upto, -- 802
				core.flight.velocities -- 802
			).passed -- 802
		end -- 802
		if passed >= #wps then -- 802
			return {} -- 807
		end -- 807
		local nextWp = wps[passed + 1] -- 808
		local body = level.bodies[nextWp.planetIndex + 1] -- 809
		if body == nil then -- 809
			return {} -- 810
		end -- 810
		return {{ -- 811
			center = bodyPositionAt(body, t), -- 811
			radius = nextWp.tolerance, -- 811
			passed = false -- 811
		}} -- 811
	end -- 797
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 815
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 815
			return f -- 816
		end -- 816
		local dx = f.eye.x - f.target.x -- 817
		local dy = f.eye.y - f.target.y -- 818
		local dz = f.eye.z - f.target.z -- 819
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 820
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 821
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 822
		local lo = CameraTiltMin * math.pi / 180 -- 823
		local hi = CameraTiltMax * math.pi / 180 -- 824
		if pitch < lo then -- 824
			pitch = lo -- 825
		end -- 825
		if pitch > hi then -- 825
			pitch = hi -- 826
		end -- 826
		local cp = math.cos(pitch) -- 827
		return { -- 828
			target = f.target, -- 829
			eye = Vec3( -- 830
				f.target.x + r * cp * math.sin(yaw), -- 831
				f.target.y + r * math.sin(pitch), -- 832
				f.target.z + r * cp * math.cos(yaw) -- 833
			) -- 833
		} -- 833
	end -- 815
	local function updateAiming(dt) -- 838
		deps.aim:setEnabled(true) -- 839
		local dragging = deps.aim:isDragging() -- 841
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 841
			clock = clock + dt -- 844
			orbitClock = orbitClock + dt -- 845
		end -- 845
		local idx = idleIndex() -- 847
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 848
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 849
		local tNow = core.t0 + clock -- 852
		deps.scene.syncBodies(tNow) -- 854
		deps.scene.syncProbe(probePos) -- 855
		if idlePath ~= nil and idx > 0 then -- 855
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 856
		end -- 856
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 858
		deps.plan:syncProbe(probePos, probeVel) -- 859
		local fr = framingPoints(probePos, tNow) -- 862
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 863
		if introT < IntroDurationSec then -- 863
			introT = introT + dt -- 867
			local k = introT / IntroDurationSec -- 868
			if k > 1 then -- 868
				k = 1 -- 869
			end -- 869
			if k >= 1 and not introLogged then -- 869
				introLogged = true -- 871
				print("[escape-velocity] intro camera done") -- 872
			end -- 872
			local wps0 = goalWaypoints(level.goal) -- 874
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 875
			local wide = frame -- 876
			local from = wide -- 877
			local to = wide -- 878
			local e = 0 -- 879
			if k < 0.35 then -- 879
				local pw = planeToWorld(probePos, 0) -- 881
				local dx = wide.eye.x - wide.target.x -- 882
				local dy = wide.eye.y - wide.target.y -- 883
				local dz = wide.eye.z - wide.target.z -- 884
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 885
				if len > 0.000001 then -- 885
					local s = IntroCloseDist / len -- 887
					dx = dx * s -- 888
					dy = dy * s -- 888
					dz = dz * s -- 888
				end -- 888
				from = { -- 890
					target = Vec3(pw.x, pw.y, pw.z), -- 890
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 890
				} -- 890
				e = k / 0.35 -- 891
			elseif k < 0.72 and wpBody ~= nil then -- 891
				local c = planeToWorld( -- 894
					bodyPositionAt(wpBody, tNow), -- 894
					0 -- 894
				) -- 894
				local dx = wide.eye.x - wide.target.x -- 895
				local dy = wide.eye.y - wide.target.y -- 896
				local dz = wide.eye.z - wide.target.z -- 897
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 898
				local want = math.max(24, wpBody.radius * 6) -- 899
				if len > 0.000001 then -- 899
					local s = want / len -- 901
					dx = dx * s -- 902
					dy = dy * s -- 902
					dz = dz * s -- 902
				end -- 902
				to = { -- 904
					target = Vec3(c.x, c.y, c.z), -- 904
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 904
				} -- 904
				e = (k - 0.35) / 0.37 -- 905
			elseif wpBody ~= nil then -- 905
				local c = planeToWorld( -- 908
					bodyPositionAt(wpBody, tNow), -- 908
					0 -- 908
				) -- 908
				local dx = wide.eye.x - wide.target.x -- 909
				local dy = wide.eye.y - wide.target.y -- 910
				local dz = wide.eye.z - wide.target.z -- 911
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 912
				local want = math.max(24, wpBody.radius * 6) -- 913
				if len > 0.000001 then -- 913
					local s = want / len -- 915
					dx = dx * s -- 916
					dy = dy * s -- 916
					dz = dz * s -- 916
				end -- 916
				from = { -- 918
					target = Vec3(c.x, c.y, c.z), -- 918
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 918
				} -- 918
				e = (k - 0.72) / 0.28 -- 919
			end -- 919
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 921
			frame = { -- 922
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 923
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 928
			} -- 928
		end -- 928
		frame = applyObserve(frame) -- 936
		deps.rig.apply(deps.camera, frame) -- 937
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 938
		local basis = makeBasis(frame) -- 939
		if core.viewMode == "2D" then -- 939
			local sp = deps.plan:probeScreen() -- 945
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 946
		else -- 946
			local pp = projectPrepared( -- 948
				planeToWorld(probePos, 0), -- 948
				basis -- 948
			) -- 948
			if pp ~= nil then -- 948
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 949
			end -- 949
		end -- 949
		if not aimed then -- 949
			deps.trajectory:clearPrediction() -- 962
			deps.plan:clearPrediction() -- 963
			predKey = "" -- 964
		else -- 964
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 968
			if key ~= predKey then -- 968
				predKey = key -- 972
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 975
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 976
					steps = PredictSteps, -- 979
					dt = core.dt, -- 979
					sampleEvery = 4, -- 979
					escapeRadius = level.escapeRadius, -- 979
					t0 = tNow, -- 979
					brake = motion.brake -- 979
				}).points -- 979
			end -- 979
			deps.trajectory:setPrediction(predPoints, basis) -- 982
			deps.plan:setPrediction(predPoints) -- 984
		end -- 984
		local rings = goalRingsAt(tNow) -- 986
		deps.trajectory:setGoalRings(rings, basis) -- 987
		deps.trajectory:clearTrail() -- 988
		deps.plan:setGoalRings(rings) -- 990
		deps.plan:clearTrail() -- 991
		deps.plan:flush() -- 992
	end -- 838
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
	local function updateFinale() -- 1007
		deps.aim:setEnabled(false) -- 1008
		if core.flight == nil then -- 1008
			return -- 1009
		end -- 1009
		local idx = ____exports.coreProbeIndex(core) -- 1010
		local pos = core.flight.points[idx + 1] -- 1011
		local tWorld = core.t0 + core.flightTime -- 1012
		deps.scene.syncBodies(tWorld) -- 1015
		deps.scene.syncProbe(pos) -- 1016
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1017
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1020
		deps.camera:lookAt( -- 1021
			frame.eye, -- 1021
			frame.target, -- 1021
			Vec3(0, 1, 0) -- 1021
		) -- 1021
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1022
		local trail = {} -- 1025
		do -- 1025
			local i = 0 -- 1026
			while i <= idx do -- 1026
				trail[#trail + 1] = core.flight.points[i + 1] -- 1026
				i = i + 1 -- 1026
			end -- 1026
		end -- 1026
		local rings = goalRingsAt(tWorld, idx) -- 1027
		local basis = makeBasis(frame) -- 1028
		deps.trajectory:setTrail(trail, basis) -- 1029
		deps.trajectory:setGoalRings(rings, basis) -- 1030
		deps.plan:clearPrediction() -- 1031
		deps.plan:setGoalRings(rings) -- 1032
		deps.plan:flush() -- 1033
	end -- 1007
	local function updateFlying(dt) -- 1035
		deps.aim:setEnabled(false) -- 1036
		local entered = ____exports.coreUpdate(core, dt, level) -- 1039
		if core.flight == nil then -- 1039
			return entered -- 1040
		end -- 1040
		local idx = ____exports.coreProbeIndex(core) -- 1042
		local pos = core.flight.points[idx + 1] -- 1043
		local tWorld = core.t0 + core.flightTime -- 1047
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1047
			lastSlowmo = core.slowmo -- 1051
			lastSlowmoBody = core.slowmoBody -- 1052
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1053
			local nearD = near ~= nil and distance( -- 1054
				pos, -- 1054
				bodyPositionAt(near, tWorld) -- 1054
			) or 0 -- 1054
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1055
		end -- 1055
		flightLogT = flightLogT + dt -- 1062
		if flightLogT >= 0.5 then -- 1062
			flightLogT = 0 -- 1064
			local total = (#core.flight.points - 1) * core.dt -- 1065
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1066
		end -- 1066
		deps.scene.syncBodies(tWorld) -- 1072
		deps.scene.syncProbe(pos) -- 1073
		if idx > 0 then -- 1073
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1075
		end -- 1075
		local fr -- 1082
		local closeDist = nil -- 1083
		if core.slowmo and core.slowmoBody >= 0 then -- 1083
			local near = level.bodies[core.slowmoBody + 1] -- 1085
			fr = { -- 1086
				pts = { -- 1086
					pos, -- 1086
					bodyPositionAt(near, tWorld) -- 1086
				}, -- 1086
				radii = {deps.scene.probeRadius, near.radius} -- 1086
			} -- 1086
			closeDist = SlowMoCloseDist -- 1087
		else -- 1087
			fr = framingPoints(pos, tWorld) -- 1089
		end -- 1089
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1091
		deps.rig.apply(deps.camera, frame) -- 1092
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1093
		local basis = makeBasis(frame) -- 1094
		local trail = {} -- 1097
		do -- 1097
			local i = 0 -- 1098
			while i <= idx do -- 1098
				trail[#trail + 1] = core.flight.points[i + 1] -- 1098
				i = i + 1 -- 1098
			end -- 1098
		end -- 1098
		local rings = goalRingsAt(tWorld, idx) -- 1099
		deps.trajectory:setTrail(trail, basis) -- 1100
		deps.trajectory:setGoalRings(rings, basis) -- 1101
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1104
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1105
		deps.plan:setTrail(trail) -- 1106
		deps.plan:clearPrediction() -- 1107
		deps.plan:setGoalRings(rings) -- 1108
		deps.plan:flush() -- 1109
		return entered -- 1111
	end -- 1035
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1125
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1126
		core.t0 = next.t0 -- 1127
		clock = next.clock -- 1128
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1129
	end -- 1125
	local function update(dt) -- 1132
		applyView() -- 1135
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1135
			updateAiming(dt) -- 1137
		elseif core.phase == "Flying" then -- 1137
			local entered = updateFlying(dt) -- 1139
			if entered and core.result ~= nil then -- 1139
				local toFinale = deps.finale == true and core.result == "success" -- 1142
				if toFinale then -- 1142
					____exports.coreEnterFinale(core) -- 1143
				end -- 1143
				deps:onResult(core.result) -- 1145
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1145
					local ____end = #core.flight.points - 1 -- 1147
					deps:onFinale({ -- 1148
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1149
						time = core.flightTime, -- 1150
						tWorld = core.t0 + core.flightTime -- 1151
					}) -- 1151
				end -- 1151
				deps:onPhase(toFinale and "Finale" or "Result") -- 1154
			end -- 1154
		elseif core.phase == "Finale" then -- 1154
			updateFinale() -- 1157
		end -- 1157
	end -- 1132
	return { -- 1162
		phase = function() return core.phase end, -- 1163
		result = function() return core.result end, -- 1164
		onAimDrag = function(____, a) -- 1165
			core.aim = a -- 1166
			aimed = true -- 1167
			introT = IntroDurationSec -- 1168
		end, -- 1165
		aimReady = function() -- 1170
			if not ____exports.coreArm(core) then -- 1170
				return -- 1171
			end -- 1171
			applyView() -- 1172
			deps:onPhase("Armed") -- 1173
		end, -- 1170
		launchArmed = function() -- 1175
			if core.phase ~= "Armed" then -- 1175
				return -- 1177
			end -- 1177
			handoffDate(true) -- 1178
			____exports.coreLaunch( -- 1179
				core, -- 1179
				core.aim.velocity, -- 1179
				level, -- 1179
				probePos, -- 1179
				probeVel -- 1179
			) -- 1179
			deps.trajectory:clearPrediction() -- 1180
			deps.plan:clearPrediction() -- 1181
			applyView() -- 1182
			deps:onPhase("Flying") -- 1183
		end, -- 1175
		armed = function() return core.phase == "Armed" end, -- 1185
		viewMode = function() return core.viewMode end, -- 1186
		toggleViewMode = function() -- 1187
			____exports.coreToggleView(core) -- 1189
			applyView() -- 1190
		end, -- 1187
		observeDrag = function(____, dx, dy) -- 1192
			introT = IntroDurationSec -- 1193
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1194
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1195
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1196
			if obsPitchDeg > 40 then -- 1196
				obsPitchDeg = 40 -- 1197
			end -- 1197
			if obsPitchDeg < -40 then -- 1197
				obsPitchDeg = -40 -- 1198
			end -- 1198
		end, -- 1192
		observeZoom = function(____, deltaDist) -- 1200
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1201
			if obsZoom < 0.4 then -- 1201
				obsZoom = 0.4 -- 1202
			end -- 1202
			if obsZoom > 1.8 then -- 1202
				obsZoom = 1.8 -- 1203
			end -- 1203
		end, -- 1200
		launch = function(____, v) -- 1205
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1205
				return -- 1206
			end -- 1206
			handoffDate(true) -- 1207
			____exports.coreLaunch( -- 1209
				core, -- 1209
				v, -- 1209
				level, -- 1209
				probePos, -- 1209
				probeVel -- 1209
			) -- 1209
			deps.trajectory:clearPrediction() -- 1210
			deps.plan:clearPrediction() -- 1211
			applyView() -- 1212
			deps:onPhase("Flying") -- 1213
		end, -- 1205
		retry = function() -- 1215
			if core.phase ~= "Result" then -- 1215
				return -- 1216
			end -- 1216
			handoffDate(false) -- 1217
			aimed = false -- 1218
			____exports.coreRetry(core) -- 1219
			deps.trajectory:clearTrail() -- 1220
			deps.trajectory:clearPrediction() -- 1221
			deps.trajectory:clearGoalRings() -- 1222
			deps.plan:clearTrail() -- 1223
			deps.plan:clearPrediction() -- 1224
			deps.plan:clearGoalRings() -- 1225
			applyView() -- 1226
			deps:onPhase("Aiming") -- 1227
		end, -- 1215
		backToSelect = function() -- 1229
			if not ____exports.coreBackToSelect(core) then -- 1229
				return false -- 1230
			end -- 1230
			deps.aim:setEnabled(false) -- 1232
			deps.trajectory:clearTrail() -- 1233
			deps.trajectory:clearPrediction() -- 1234
			deps.trajectory:clearGoalRings() -- 1235
			deps.plan:clearTrail() -- 1236
			deps.plan:clearPrediction() -- 1237
			deps.plan:clearGoalRings() -- 1238
			applyView() -- 1239
			deps:onPhase("LevelSelect") -- 1240
			return true -- 1241
		end, -- 1229
		startLevel = function() -- 1243
			aimed = false -- 1246
			____exports.coreRetry(core) -- 1247
			deps.rig.reset() -- 1250
			introT = 0 -- 1251
			introLogged = false -- 1252
			prepareIdle() -- 1253
			deps.trajectory:clearTrail() -- 1254
			deps.trajectory:clearPrediction() -- 1255
			deps.trajectory:clearGoalRings() -- 1256
			deps.plan:clearTrail() -- 1257
			deps.plan:clearPrediction() -- 1258
			deps.plan:clearGoalRings() -- 1259
			appliedMode = "" -- 1262
			applyView() -- 1263
			deps:onPhase("Aiming") -- 1264
		end, -- 1243
		stepTime = function(____, dir, span) -- 1266
			if not ____exports.coreTimeWarpAllowed(core) then -- 1266
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1270
				return -- 1271
			end -- 1271
			local span0 = span > 0 and span or 0 -- 1273
			clock = clock + dir * TimeWarpStep -- 1274
			if clock < 0 then -- 1274
				clock = 0 -- 1275
			end -- 1275
			if span0 > 0 and clock > span0 then -- 1275
				clock = span0 -- 1276
			end -- 1276
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1278
		end, -- 1266
		dateNow = function() return core.t0 + clock end, -- 1280
		setBrakeMode = function(____, on) -- 1281
			core.brakeMode = on -- 1282
		end, -- 1281
		brakeMode = function() return core.brakeMode end, -- 1285
		setPlaybackSpeed = function(____, speed) -- 1286
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1286
				return -- 1288
			end -- 1288
			core.playback = speed -- 1289
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1290
		end, -- 1286
		playbackSpeed = function() return core.playback end, -- 1292
		update = function(____, frameDt) return update(frameDt) end -- 1294
	} -- 1294
end -- 593
return ____exports -- 593
-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
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
--- 中性瞄准（没拖过时的姿态）：朝目标、力度取这一关的下限。
local function neutralAim(minSpeed) -- 164
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 165
end -- 164
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 169
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 170
end -- 169
function ____exports.createCore(dt) -- 173
	return { -- 174
		phase = "Aiming", -- 175
		aim = neutralAim(AimMinSpeed), -- 176
		flight = nil, -- 177
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 178
		brakeMode = false, -- 179
		t0 = 0, -- 180
		flightTime = 0, -- 181
		goalIndex = -1, -- 182
		result = nil, -- 183
		viewMode = "2D", -- 185
		playback = FlightPlayback, -- 187
		slowmo = false, -- 188
		slowmoBody = -1 -- 189
	} -- 189
end -- 173
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 201
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 202
	return core.viewMode -- 203
end -- 201
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 221
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 227
	local share = brakeMode and BrakeShare or 1 -- 228
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 229
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 230
	local brake = brakeMode and mag > 0 and ({ -- 231
		dv = mag * (1 - share), -- 232
		startStep = math.floor(maxSteps / 2) -- 232
	}) or nil -- 232
	return {init = init, brake = brake} -- 234
end -- 221
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 243
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 243
		return -- 245
	end -- 245
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 246
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 247
	local p0 = from ~= nil and from or level.probeStart -- 248
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 249
		steps = level.maxSteps, -- 252
		dt = core.dt, -- 252
		sampleEvery = 1, -- 252
		escapeRadius = level.escapeRadius, -- 252
		t0 = core.t0, -- 252
		brake = motion.brake -- 252
	}) -- 252
	core.flight = flight -- 254
	core.goalIndex = findGoalIndex( -- 255
		flight.points, -- 255
		level.bodies, -- 255
		level.goal, -- 255
		core.dt, -- 255
		core.t0, -- 255
		flight.velocities -- 255
	) -- 255
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 256
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 259
	core.flightTime = 0 -- 264
	core.slowmo = false -- 266
	core.slowmoBody = -1 -- 267
	core.phase = "Flying" -- 268
	core.viewMode = "3D" -- 270
end -- 243
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 279
	if core.phase ~= "Aiming" then -- 279
		return false -- 280
	end -- 280
	core.phase = "Armed" -- 281
	return true -- 282
end -- 279
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 286
	if core.phase ~= "Armed" then -- 286
		return false -- 287
	end -- 287
	core.phase = "Aiming" -- 288
	return true -- 289
end -- 286
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 303
	return core.phase == "Aiming" or core.phase == "Armed" -- 304
end -- 303
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 320
	if toT0 then -- 320
		return {t0 = clock, clock = 0} -- 321
	end -- 321
	return {t0 = 0, clock = t0} -- 322
end -- 320
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 334
	local host = -1 -- 344
	do -- 344
		local i = 0 -- 345
		while i < #bodies do -- 345
			do -- 345
				local b = bodies[i + 1] -- 346
				local isHost = false -- 347
				do -- 347
					local j = 0 -- 348
					while j < #bodies do -- 348
						do -- 348
							local h = bodies[j + 1].host -- 349
							if h == nil then -- 349
								goto __continue25 -- 350
							end -- 350
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 350
								isHost = true -- 351
								break -- 351
							end -- 351
						end -- 351
						::__continue25:: -- 351
						j = j + 1 -- 348
					end -- 348
				end -- 348
				if not isHost then -- 348
					goto __continue23 -- 353
				end -- 353
				if host < 0 or b.gm > bodies[host + 1].gm then -- 353
					host = i -- 354
				end -- 354
			end -- 354
			::__continue23:: -- 354
			i = i + 1 -- 345
		end -- 345
	end -- 345
	if host >= 0 then -- 345
		return host -- 356
	end -- 356
	local best = -1 -- 358
	do -- 358
		local i = 0 -- 359
		while i < #bodies do -- 359
			do -- 359
				local b = bodies[i + 1] -- 360
				if b.orbitRadius ~= 0 then -- 360
					goto __continue32 -- 361
				end -- 361
				if best < 0 or b.gm > bodies[best + 1].gm then -- 361
					best = i -- 362
				end -- 362
			end -- 362
			::__continue32:: -- 362
			i = i + 1 -- 359
		end -- 359
	end -- 359
	return best -- 364
end -- 334
--- S3.17 慢动作触发判定（纯函数，可单测）：「**最近接近任何天体**」。
-- 
-- 探测器与某个天体的距离进入阈值即算数 —— 抵达月球与掠过木星因此共用同一套手感。
-- 阈值 = `max(天体半径 × SlowMoRadiusFactor, SlowMoFloorDist)`（世界单位，理由见 Config）：
--   - 半径 × 系数：木星 23.2 / 土星 21.5 / 月球 8（地板）；
--   - **锚点天体（太阳）不参与**：它半径 28，乘出来比探测器出发距离（80）还大，
--     不排除就是六关全程慢动作。掠过景由取景里的锚点预算负责，不由慢动作负责。
-- 
-- @param anchor 锚点天体索引（-1 = 没有锚点）；传 anchorBodyIndex(bodies) 的结果。
-- @param floor 阈值的地板（世界单位）。**必须按关卡给**：L1 的世界只有 0.6 单位宽，
-- 用全局的 8 会让"整段飞行 100% 处于慢动作特写"（用户实测「发射后屏幕被探测器占满」）。
-- 省略 = Config.SlowMoFloorDist（L2–L6 的历史行为）。
-- @returns 触发的天体索引（**最近**的那个）；-1 = 不在任何天体的阈值内。
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 382
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 383
	local best = -1 -- 384
	local bestD = 1000000000 -- 385
	do -- 385
		local i = 0 -- 386
		while i < #bodies do -- 386
			do -- 386
				if i == anchor then -- 386
					goto __continue37 -- 387
				end -- 387
				local b = bodies[i + 1] -- 388
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 389
				local d = distance( -- 390
					probe, -- 390
					bodyPositionAt(b, t) -- 390
				) -- 390
				if d < threshold and d < bestD then -- 390
					bestD = d -- 392
					best = i -- 393
				end -- 393
			end -- 393
			::__continue37:: -- 393
			i = i + 1 -- 386
		end -- 386
	end -- 386
	return best -- 396
end -- 382
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 400
	if core.flight == nil then -- 400
		return 0 -- 401
	end -- 401
	local idx = math.floor(core.flightTime / core.dt) -- 402
	local last = #core.flight.points - 1 -- 403
	if idx > last then -- 403
		idx = last -- 404
	end -- 404
	if idx < 0 then -- 404
		idx = 0 -- 405
	end -- 405
	return idx -- 406
end -- 400
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
function ____exports.coreUpdate(core, dt, level) -- 423
	if core.phase ~= "Flying" or core.flight == nil then -- 423
		return false -- 424
	end -- 424
	if level ~= nil then -- 424
		local idx = ____exports.coreProbeIndex(core) -- 428
		core.slowmoBody = ____exports.slowMotionBody( -- 429
			level.bodies, -- 429
			core.flight.points[idx + 1], -- 429
			core.t0 + core.flightTime, -- 429
			____exports.anchorBodyIndex(level.bodies), -- 429
			level.slowMoFloor -- 429
		) -- 429
		core.slowmo = core.slowmoBody >= 0 -- 430
	end -- 430
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 433
	core.flightTime = core.flightTime + dt * speed -- 434
	local naturalEnd = #core.flight.points - 1 -- 435
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 436
	if ____exports.coreProbeIndex(core) >= endIdx then -- 436
		core.flightTime = endIdx * core.dt -- 439
		core.phase = "Result" -- 440
		return true -- 441
	end -- 441
	return false -- 443
end -- 423
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 447
	core.phase = "Aiming" -- 448
	core.viewMode = "2D" -- 450
	core.flight = nil -- 451
	core.flightTime = 0 -- 452
	core.goalIndex = -1 -- 453
	core.result = nil -- 454
	core.slowmo = false -- 455
	core.slowmoBody = -1 -- 456
	core.aim = neutralAim(levelAimMin(aimMin)) -- 457
end -- 447
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 471
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 471
		return false -- 473
	end -- 473
	core.phase = "LevelSelect" -- 474
	core.viewMode = "2D" -- 476
	core.flight = nil -- 477
	core.flightTime = 0 -- 478
	core.goalIndex = -1 -- 479
	core.result = nil -- 480
	core.slowmo = false -- 481
	core.slowmoBody = -1 -- 482
	return true -- 483
end -- 471
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 512
	if core.phase ~= "Result" then -- 512
		return false -- 513
	end -- 513
	core.phase = "Finale" -- 514
	return true -- 515
end -- 512
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 533
	local dist = distance > 1 and distance or 1 -- 534
	local ux = probe.x -- 536
	local uy = probe.y -- 537
	local len = math.sqrt(ux * ux + uy * uy) -- 538
	if len < 0.000001 then -- 538
		ux = 0 -- 539
		uy = 1 -- 539
	else -- 539
		ux = ux / len -- 539
		uy = uy / len -- 539
	end -- 539
	local tilt = tiltDeg * math.pi / 180 -- 540
	local flat = math.cos(tilt) * dist -- 541
	return { -- 542
		target = Vec3(0, 0, 0), -- 544
		eye = Vec3( -- 545
			ux * flat * PlaneToWorldX, -- 545
			math.sin(tilt) * dist, -- 545
			uy * flat * PlaneToWorldZ -- 545
		) -- 545
	} -- 545
end -- 533
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 657
	local core = ____exports.createCore(level.physicsStep) -- 658
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 661
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 664
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
	local function applyView() -- 679
		local mode = core.viewMode -- 680
		if mode == appliedMode then -- 680
			return -- 681
		end -- 681
		appliedMode = mode -- 682
		local is2D = mode == "2D" -- 683
		deps.plan:setVisible(is2D) -- 684
		deps.trajectory.root.visible = not is2D -- 685
		deps:setWorldVisible(not is2D) -- 686
		deps.aim:setFullScreenAim(is2D) -- 687
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 688
	end -- 679
	local function makeBasis(frame) -- 691
		return prepareCamera({ -- 692
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 694
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 695
			up = {x = 0, y = 1, z = 0}, -- 696
			fovYDeg = deps.fovYDeg, -- 697
			aspect = deps.aspect, -- 698
			viewW = deps.viewW, -- 699
			viewH = deps.viewH -- 700
		}, HANDEDNESS, FLIP_Y) -- 700
	end -- 691
	local predKey = "" -- 709
	local predPoints = {} -- 710
	local introT = IntroDurationSec -- 712
	local introLogged = false -- 713
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 715
	local clock = 0 -- 721
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 723
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 725
	local obsYawDeg = 0 -- 729
	local obsPitchDeg = 0 -- 730
	local obsZoom = 1 -- 731
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 733
	local idlePath = nil -- 734
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 745
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 747
	local lastSlowmoBody = -1 -- 748
	local flightLogT = 0 -- 749
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 751
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 752
	local function prepareIdle() -- 753
		clock = 0 -- 755
		core.t0 = 0 -- 756
		if level.probeVel0 == nil then -- 756
			idlePath = nil -- 758
			return -- 759
		end -- 759
		local idleSteps = level.maxSteps -- 767
		local v0x = level.probeVel0.x -- 768
		local v0y = level.probeVel0.y -- 769
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 770
		if v0 > 0.000001 then -- 770
			local bestD = 1000000000 -- 772
			for ____, b in ipairs(level.bodies) do -- 773
				do -- 773
					if b.gm <= 0 then -- 773
						goto __continue63 -- 774
					end -- 774
					local dx = b.orbitCenter.x - level.probeStart.x -- 775
					local dy = b.orbitCenter.y - level.probeStart.y -- 776
					local d = math.sqrt(dx * dx + dy * dy) -- 777
					if d < bestD then -- 777
						bestD = d -- 778
					end -- 778
				end -- 778
				::__continue63:: -- 778
			end -- 778
			if bestD > 0.000001 and bestD < 100000000 then -- 778
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 781
				if n > 60 and n < 40000 then -- 781
					idleSteps = n -- 782
				end -- 782
			end -- 782
		end -- 782
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 785
			steps = idleSteps, -- 788
			dt = core.dt, -- 788
			sampleEvery = 1, -- 788
			escapeRadius = level.escapeRadius, -- 788
			t0 = core.t0 -- 788
		}) -- 788
	end -- 753
	local function idleIndex() -- 791
		if idlePath == nil then -- 791
			return 0 -- 792
		end -- 792
		local n = #idlePath.points -- 793
		if n <= 1 then -- 793
			return 0 -- 794
		end -- 794
		local i = math.floor(orbitClock / core.dt) % n -- 795
		if i < 0 then -- 795
			i = 0 -- 796
		end -- 796
		return i -- 797
	end -- 791
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 810
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 811
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 814
		local wps = goalWaypoints(level.goal) -- 815
		if #wps == 0 then -- 815
			return nil -- 816
		end -- 816
		local passed = 0 -- 817
		if core.flight ~= nil then -- 817
			local upto = math.floor(core.flightTime / core.dt) -- 819
			passed = waypointProgress( -- 820
				core.flight.points, -- 820
				level.bodies, -- 820
				level.goal, -- 820
				core.dt, -- 820
				core.t0, -- 820
				upto, -- 820
				core.flight.velocities -- 820
			).passed -- 820
		end -- 820
		if passed >= #wps then -- 820
			return nil -- 822
		end -- 822
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 823
	end -- 814
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 834
		local corePts = {probe} -- 837
		local coreRadii = {deps.scene.probeRadius} -- 838
		local next = nextStationBody() -- 839
		local nextTol = 0 -- 840
		if next ~= nil then -- 840
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 842
			local wps = goalWaypoints(level.goal) -- 843
			local passed = 0 -- 844
			if core.flight ~= nil then -- 844
				passed = waypointProgress( -- 846
					core.flight.points, -- 846
					level.bodies, -- 846
					level.goal, -- 846
					core.dt, -- 846
					core.t0, -- 846
					math.floor(core.flightTime / core.dt), -- 846
					core.flight.velocities -- 846
				).passed -- 846
			end -- 846
			if passed < #wps then -- 846
				nextTol = wps[passed + 1].tolerance -- 848
			end -- 848
			local r = nextTol > next.radius and nextTol or next.radius -- 849
			coreRadii[#coreRadii + 1] = r -- 850
		end -- 850
		if anchorDef == nil then -- 850
			return {pts = corePts, radii = coreRadii} -- 853
		end -- 853
		local anchorR = anchorDef.radius -- 858
		do -- 858
			local i = 0 -- 859
			while i < #level.bodies do -- 859
				local b = level.bodies[i + 1] -- 860
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 860
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 860
						anchorR = deps.visuals[i + 1].displayRadius -- 862
					end -- 862
					break -- 863
				end -- 863
				i = i + 1 -- 859
			end -- 859
		end -- 859
		local withAnchorPts = { -- 866
			probe, -- 866
			bodyPositionAt(anchorDef, t) -- 866
		} -- 866
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 867
		do -- 867
			local i = 1 -- 868
			while i < #corePts do -- 868
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 869
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 870
				i = i + 1 -- 868
			end -- 868
		end -- 868
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 872
		if want <= CameraFramingBudget then -- 872
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 873
		end -- 873
		return {pts = corePts, radii = coreRadii} -- 874
	end -- 834
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 878
		local wps = goalWaypoints(level.goal) -- 879
		if #wps == 0 then -- 879
			return {} -- 880
		end -- 880
		local passed = 0 -- 881
		if upto ~= nil and core.flight ~= nil then -- 881
			passed = waypointProgress( -- 883
				core.flight.points, -- 883
				level.bodies, -- 883
				level.goal, -- 883
				core.dt, -- 883
				core.t0, -- 883
				upto, -- 883
				core.flight.velocities -- 883
			).passed -- 883
		end -- 883
		if passed >= #wps then -- 883
			return {} -- 888
		end -- 888
		local nextWp = wps[passed + 1] -- 889
		local body = level.bodies[nextWp.planetIndex + 1] -- 890
		if body == nil then -- 890
			return {} -- 891
		end -- 891
		return {{ -- 892
			center = bodyPositionAt(body, t), -- 892
			radius = nextWp.tolerance, -- 892
			passed = false -- 892
		}} -- 892
	end -- 878
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 896
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 896
			return f -- 897
		end -- 897
		local dx = f.eye.x - f.target.x -- 898
		local dy = f.eye.y - f.target.y -- 899
		local dz = f.eye.z - f.target.z -- 900
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 901
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 902
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 903
		local lo = CameraTiltMin * math.pi / 180 -- 904
		local hi = CameraTiltMax * math.pi / 180 -- 905
		if pitch < lo then -- 905
			pitch = lo -- 906
		end -- 906
		if pitch > hi then -- 906
			pitch = hi -- 907
		end -- 907
		local cp = math.cos(pitch) -- 908
		return { -- 909
			target = f.target, -- 910
			eye = Vec3( -- 911
				f.target.x + r * cp * math.sin(yaw), -- 912
				f.target.y + r * math.sin(pitch), -- 913
				f.target.z + r * cp * math.cos(yaw) -- 914
			) -- 914
		} -- 914
	end -- 896
	local function updateAiming(dt) -- 919
		deps.aim:setEnabled(true) -- 920
		local dragging = deps.aim:isDragging() -- 922
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 922
			local aimRate = level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1 -- 933
			clock = clock + dt * aimRate -- 934
			orbitClock = orbitClock + dt * aimRate -- 935
		end -- 935
		local idx = idleIndex() -- 937
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 938
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 939
		local tNow = core.t0 + clock -- 942
		deps.scene.syncBodies(tNow) -- 944
		deps.scene.syncProbe(probePos) -- 945
		if idlePath ~= nil and idx > 0 then -- 945
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 946
		end -- 946
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 948
		deps.plan:syncProbe(probePos, probeVel) -- 949
		local fr = framingPoints(probePos, tNow) -- 952
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 953
		if frameLogged < 6 then -- 953
			frameLogged = frameLogged + 1 -- 957
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 958
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 962
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 963
				__TS__ArrayMap( -- 969
					fr.pts, -- 969
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 969
				), -- 969
				" " -- 969
			)) .. "]") -- 969
		end -- 969
		if introT < IntroDurationSec then -- 969
			introT = introT + dt -- 974
			local k = introT / IntroDurationSec -- 975
			if k > 1 then -- 975
				k = 1 -- 976
			end -- 976
			if k >= 1 and not introLogged then -- 976
				introLogged = true -- 978
				print("[escape-velocity] intro camera done") -- 979
			end -- 979
			local wps0 = goalWaypoints(level.goal) -- 981
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 982
			local wide = frame -- 983
			local from = wide -- 984
			local to = wide -- 985
			local e = 0 -- 986
			if k < 0.35 then -- 986
				local pw = planeToWorld(probePos, 0) -- 988
				local dx = wide.eye.x - wide.target.x -- 989
				local dy = wide.eye.y - wide.target.y -- 990
				local dz = wide.eye.z - wide.target.z -- 991
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 992
				if len > 0.000001 then -- 992
					local s = IntroCloseDist / len -- 994
					dx = dx * s -- 995
					dy = dy * s -- 995
					dz = dz * s -- 995
				end -- 995
				from = { -- 997
					target = Vec3(pw.x, pw.y, pw.z), -- 997
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 997
				} -- 997
				e = k / 0.35 -- 998
			elseif k < 0.72 and wpBody ~= nil then -- 998
				local c = planeToWorld( -- 1001
					bodyPositionAt(wpBody, tNow), -- 1001
					0 -- 1001
				) -- 1001
				local dx = wide.eye.x - wide.target.x -- 1002
				local dy = wide.eye.y - wide.target.y -- 1003
				local dz = wide.eye.z - wide.target.z -- 1004
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1005
				local want = math.max(24, wpBody.radius * 6) -- 1006
				if len > 0.000001 then -- 1006
					local s = want / len -- 1008
					dx = dx * s -- 1009
					dy = dy * s -- 1009
					dz = dz * s -- 1009
				end -- 1009
				to = { -- 1011
					target = Vec3(c.x, c.y, c.z), -- 1011
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1011
				} -- 1011
				e = (k - 0.35) / 0.37 -- 1012
			elseif wpBody ~= nil then -- 1012
				local c = planeToWorld( -- 1015
					bodyPositionAt(wpBody, tNow), -- 1015
					0 -- 1015
				) -- 1015
				local dx = wide.eye.x - wide.target.x -- 1016
				local dy = wide.eye.y - wide.target.y -- 1017
				local dz = wide.eye.z - wide.target.z -- 1018
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1019
				local want = math.max(24, wpBody.radius * 6) -- 1020
				if len > 0.000001 then -- 1020
					local s = want / len -- 1022
					dx = dx * s -- 1023
					dy = dy * s -- 1023
					dz = dz * s -- 1023
				end -- 1023
				from = { -- 1025
					target = Vec3(c.x, c.y, c.z), -- 1025
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1025
				} -- 1025
				e = (k - 0.72) / 0.28 -- 1026
			end -- 1026
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 1028
			frame = { -- 1029
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 1030
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 1035
			} -- 1035
		end -- 1035
		frame = applyObserve(frame) -- 1043
		deps.rig.apply(deps.camera, frame) -- 1044
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1045
		local basis = makeBasis(frame) -- 1046
		if core.viewMode == "2D" then -- 1046
			local sp = deps.plan:probeScreen() -- 1052
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1053
		else -- 1053
			local pp = projectPrepared( -- 1055
				planeToWorld(probePos, 0), -- 1055
				basis -- 1055
			) -- 1055
			if pp ~= nil then -- 1055
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1056
			end -- 1056
		end -- 1056
		if not aimed then -- 1056
			deps.trajectory:clearPrediction() -- 1069
			deps.plan:clearPrediction() -- 1070
			predKey = "" -- 1071
		else -- 1071
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 1075
			if key ~= predKey then -- 1075
				predKey = key -- 1079
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1082
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1083
					steps = PredictSteps, -- 1086
					dt = core.dt, -- 1086
					sampleEvery = 4, -- 1086
					escapeRadius = level.escapeRadius, -- 1086
					t0 = tNow, -- 1086
					brake = motion.brake -- 1086
				}).points -- 1086
			end -- 1086
			deps.trajectory:setPrediction(predPoints, basis) -- 1089
			deps.plan:setPrediction(predPoints) -- 1091
		end -- 1091
		local rings = goalRingsAt(tNow) -- 1093
		deps.trajectory:setGoalRings(rings, basis) -- 1094
		deps.trajectory:clearTrail() -- 1095
		deps.plan:setGoalRings(rings) -- 1097
		deps.plan:clearTrail() -- 1098
		deps.plan:flush() -- 1099
	end -- 919
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
	local function updateFinale() -- 1114
		deps.aim:setEnabled(false) -- 1115
		if core.flight == nil then -- 1115
			return -- 1116
		end -- 1116
		local idx = ____exports.coreProbeIndex(core) -- 1117
		local pos = core.flight.points[idx + 1] -- 1118
		local tWorld = core.t0 + core.flightTime -- 1119
		deps.scene.syncBodies(tWorld) -- 1122
		deps.scene.syncProbe(pos) -- 1123
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1124
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1127
		deps.camera:lookAt( -- 1128
			frame.eye, -- 1128
			frame.target, -- 1128
			Vec3(0, 1, 0) -- 1128
		) -- 1128
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1129
		local trail = {} -- 1132
		do -- 1132
			local i = 0 -- 1133
			while i <= idx do -- 1133
				trail[#trail + 1] = core.flight.points[i + 1] -- 1133
				i = i + 1 -- 1133
			end -- 1133
		end -- 1133
		local rings = goalRingsAt(tWorld, idx) -- 1134
		local basis = makeBasis(frame) -- 1135
		deps.trajectory:setTrail(trail, basis) -- 1136
		deps.trajectory:setGoalRings(rings, basis) -- 1137
		deps.plan:clearPrediction() -- 1138
		deps.plan:setGoalRings(rings) -- 1139
		deps.plan:flush() -- 1140
	end -- 1114
	local function updateFlying(dt) -- 1142
		deps.aim:setEnabled(false) -- 1143
		local entered = ____exports.coreUpdate(core, dt, level) -- 1146
		if core.flight == nil then -- 1146
			return entered -- 1147
		end -- 1147
		local idx = ____exports.coreProbeIndex(core) -- 1149
		local pos = core.flight.points[idx + 1] -- 1150
		local tWorld = core.t0 + core.flightTime -- 1154
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1154
			lastSlowmo = core.slowmo -- 1158
			lastSlowmoBody = core.slowmoBody -- 1159
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1160
			local nearD = near ~= nil and distance( -- 1161
				pos, -- 1161
				bodyPositionAt(near, tWorld) -- 1161
			) or 0 -- 1161
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1162
		end -- 1162
		flightLogT = flightLogT + dt -- 1169
		if flightLogT >= 0.5 then -- 1169
			flightLogT = 0 -- 1171
			local total = (#core.flight.points - 1) * core.dt -- 1172
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1173
		end -- 1173
		deps.scene.syncBodies(tWorld) -- 1179
		deps.scene.syncProbe(pos) -- 1180
		if idx > 0 then -- 1180
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1182
		end -- 1182
		local fr -- 1189
		local closeDist = nil -- 1190
		if core.slowmo and core.slowmoBody >= 0 then -- 1190
			local near = level.bodies[core.slowmoBody + 1] -- 1192
			local nearR = near.radius -- 1194
			do -- 1194
				local i = 0 -- 1195
				while i < #level.bodies do -- 1195
					local b = level.bodies[i + 1] -- 1196
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1196
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1196
							nearR = deps.visuals[i + 1].displayRadius -- 1198
						end -- 1198
						break -- 1199
					end -- 1199
					i = i + 1 -- 1195
				end -- 1195
			end -- 1195
			fr = { -- 1202
				pts = { -- 1202
					pos, -- 1202
					bodyPositionAt(near, tWorld) -- 1202
				}, -- 1202
				radii = {deps.scene.probeRadius, nearR} -- 1202
			} -- 1202
			closeDist = SlowMoCloseDist -- 1203
		else -- 1203
			fr = framingPoints(pos, tWorld) -- 1205
		end -- 1205
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1207
		deps.rig.apply(deps.camera, frame) -- 1208
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1209
		local basis = makeBasis(frame) -- 1210
		local trail = {} -- 1213
		do -- 1213
			local i = 0 -- 1214
			while i <= idx do -- 1214
				trail[#trail + 1] = core.flight.points[i + 1] -- 1214
				i = i + 1 -- 1214
			end -- 1214
		end -- 1214
		local rings = goalRingsAt(tWorld, idx) -- 1215
		deps.trajectory:setTrail(trail, basis) -- 1216
		deps.trajectory:setGoalRings(rings, basis) -- 1217
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1220
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1221
		deps.plan:setTrail(trail) -- 1222
		deps.plan:clearPrediction() -- 1223
		deps.plan:setGoalRings(rings) -- 1224
		deps.plan:flush() -- 1225
		return entered -- 1227
	end -- 1142
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1241
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1242
		core.t0 = next.t0 -- 1243
		clock = next.clock -- 1244
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1245
	end -- 1241
	local function update(dt) -- 1248
		applyView() -- 1251
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1251
			updateAiming(dt) -- 1253
		elseif core.phase == "Flying" then -- 1253
			local entered = updateFlying(dt) -- 1255
			if entered and core.result ~= nil then -- 1255
				local toFinale = deps.finale == true and core.result == "success" -- 1258
				if toFinale then -- 1258
					____exports.coreEnterFinale(core) -- 1259
				end -- 1259
				deps:onResult(core.result) -- 1261
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1261
					local ____end = #core.flight.points - 1 -- 1263
					deps:onFinale({ -- 1264
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1265
						time = core.flightTime, -- 1266
						tWorld = core.t0 + core.flightTime -- 1267
					}) -- 1267
				end -- 1267
				deps:onPhase(toFinale and "Finale" or "Result") -- 1270
			end -- 1270
		elseif core.phase == "Finale" then -- 1270
			updateFinale() -- 1273
		end -- 1273
	end -- 1248
	return { -- 1278
		phase = function() return core.phase end, -- 1279
		result = function() return core.result end, -- 1280
		onAimDrag = function(____, a) -- 1281
			core.aim = a -- 1282
			aimed = true -- 1283
			introT = IntroDurationSec -- 1284
		end, -- 1281
		aimReady = function() -- 1286
			if not ____exports.coreArm(core) then -- 1286
				return -- 1287
			end -- 1287
			applyView() -- 1288
			deps:onPhase("Armed") -- 1289
		end, -- 1286
		launchArmed = function() -- 1291
			if core.phase ~= "Armed" then -- 1291
				return -- 1293
			end -- 1293
			handoffDate(true) -- 1294
			____exports.coreLaunch( -- 1295
				core, -- 1295
				core.aim.velocity, -- 1295
				level, -- 1295
				probePos, -- 1295
				probeVel -- 1295
			) -- 1295
			deps.trajectory:clearPrediction() -- 1296
			deps.plan:clearPrediction() -- 1297
			applyView() -- 1298
			deps:onPhase("Flying") -- 1299
		end, -- 1291
		armed = function() return core.phase == "Armed" end, -- 1301
		viewMode = function() return core.viewMode end, -- 1302
		toggleViewMode = function() -- 1303
			____exports.coreToggleView(core) -- 1305
			applyView() -- 1306
		end, -- 1303
		observeDrag = function(____, dx, dy) -- 1308
			introT = IntroDurationSec -- 1309
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1310
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1311
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1312
			if obsPitchDeg > 40 then -- 1312
				obsPitchDeg = 40 -- 1313
			end -- 1313
			if obsPitchDeg < -40 then -- 1313
				obsPitchDeg = -40 -- 1314
			end -- 1314
		end, -- 1308
		observeZoom = function(____, deltaDist) -- 1316
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1317
			if obsZoom < 0.4 then -- 1317
				obsZoom = 0.4 -- 1318
			end -- 1318
			if obsZoom > 1.8 then -- 1318
				obsZoom = 1.8 -- 1319
			end -- 1319
		end, -- 1316
		launch = function(____, v) -- 1321
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1321
				return -- 1322
			end -- 1322
			handoffDate(true) -- 1323
			____exports.coreLaunch( -- 1325
				core, -- 1325
				v, -- 1325
				level, -- 1325
				probePos, -- 1325
				probeVel -- 1325
			) -- 1325
			deps.trajectory:clearPrediction() -- 1326
			deps.plan:clearPrediction() -- 1327
			applyView() -- 1328
			deps:onPhase("Flying") -- 1329
		end, -- 1321
		retry = function() -- 1331
			if core.phase ~= "Result" then -- 1331
				return -- 1332
			end -- 1332
			handoffDate(false) -- 1333
			aimed = false -- 1334
			____exports.coreRetry(core, level.aimMin) -- 1335
			deps.trajectory:clearTrail() -- 1336
			deps.trajectory:clearPrediction() -- 1337
			deps.trajectory:clearGoalRings() -- 1338
			deps.plan:clearTrail() -- 1339
			deps.plan:clearPrediction() -- 1340
			deps.plan:clearGoalRings() -- 1341
			applyView() -- 1342
			deps:onPhase("Aiming") -- 1343
		end, -- 1331
		backToSelect = function() -- 1345
			if not ____exports.coreBackToSelect(core) then -- 1345
				return false -- 1346
			end -- 1346
			deps.aim:setEnabled(false) -- 1348
			deps.trajectory:clearTrail() -- 1349
			deps.trajectory:clearPrediction() -- 1350
			deps.trajectory:clearGoalRings() -- 1351
			deps.plan:clearTrail() -- 1352
			deps.plan:clearPrediction() -- 1353
			deps.plan:clearGoalRings() -- 1354
			applyView() -- 1355
			deps:onPhase("LevelSelect") -- 1356
			return true -- 1357
		end, -- 1345
		startLevel = function() -- 1359
			aimed = false -- 1362
			____exports.coreRetry(core, level.aimMin) -- 1363
			deps.rig.reset() -- 1366
			introT = 0 -- 1367
			introLogged = false -- 1368
			prepareIdle() -- 1369
			deps.trajectory:clearTrail() -- 1370
			deps.trajectory:clearPrediction() -- 1371
			deps.trajectory:clearGoalRings() -- 1372
			deps.plan:clearTrail() -- 1373
			deps.plan:clearPrediction() -- 1374
			deps.plan:clearGoalRings() -- 1375
			appliedMode = "" -- 1378
			applyView() -- 1379
			deps:onPhase("Aiming") -- 1380
		end, -- 1359
		stepTime = function(____, dir, span) -- 1382
			if not ____exports.coreTimeWarpAllowed(core) then -- 1382
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1386
				return -- 1387
			end -- 1387
			local span0 = span > 0 and span or 0 -- 1389
			clock = clock + dir * TimeWarpStep -- 1390
			if clock < 0 then -- 1390
				clock = 0 -- 1391
			end -- 1391
			if span0 > 0 and clock > span0 then -- 1391
				clock = span0 -- 1392
			end -- 1392
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1394
		end, -- 1382
		dateNow = function() return core.t0 + clock end, -- 1396
		setBrakeMode = function(____, on) -- 1397
			core.brakeMode = on -- 1398
		end, -- 1397
		brakeMode = function() return core.brakeMode end, -- 1401
		setPlaybackSpeed = function(____, speed) -- 1402
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1402
				return -- 1404
			end -- 1404
			core.playback = speed -- 1405
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1406
		end, -- 1402
		playbackSpeed = function() return core.playback end, -- 1408
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1409
		update = function(____, frameDt) return update(frameDt) end -- 1411
	} -- 1411
end -- 657
return ____exports -- 657
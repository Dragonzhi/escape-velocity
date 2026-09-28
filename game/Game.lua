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
local bodyVelocityAt = ____LevelData.bodyVelocityAt -- 33
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
local function neutralAim(minSpeed) -- 173
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 174
end -- 173
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 178
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 179
end -- 178
function ____exports.createCore(dt) -- 182
	return { -- 183
		phase = "Aiming", -- 184
		aim = neutralAim(AimMinSpeed), -- 185
		flight = nil, -- 186
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 187
		brakeMode = false, -- 188
		t0 = 0, -- 189
		flightTime = 0, -- 190
		goalIndex = -1, -- 191
		result = nil, -- 192
		viewMode = "2D", -- 194
		playback = FlightPlayback, -- 196
		slowmo = false, -- 197
		slowmoBody = -1 -- 198
	} -- 198
end -- 182
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 210
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 211
	return core.viewMode -- 212
end -- 210
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 230
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 236
	local share = brakeMode and BrakeShare or 1 -- 237
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 238
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 239
	local brake = brakeMode and mag > 0 and ({ -- 240
		dv = mag * (1 - share), -- 241
		startStep = math.floor(maxSteps / 2) -- 241
	}) or nil -- 241
	return {init = init, brake = brake} -- 243
end -- 230
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 252
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 252
		return -- 254
	end -- 254
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 255
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 256
	local p0 = from ~= nil and from or level.probeStart -- 257
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 258
		steps = level.maxSteps, -- 261
		dt = core.dt, -- 261
		sampleEvery = 1, -- 261
		escapeRadius = level.escapeRadius, -- 261
		t0 = core.t0, -- 261
		brake = motion.brake -- 261
	}) -- 261
	core.flight = flight -- 263
	core.goalIndex = findGoalIndex( -- 264
		flight.points, -- 264
		level.bodies, -- 264
		level.goal, -- 264
		core.dt, -- 264
		core.t0, -- 264
		flight.velocities -- 264
	) -- 264
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 265
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 268
	core.flightTime = 0 -- 273
	core.slowmo = false -- 275
	core.slowmoBody = -1 -- 276
	core.phase = "Flying" -- 277
	core.viewMode = "3D" -- 279
end -- 252
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 288
	if core.phase ~= "Aiming" then -- 288
		return false -- 289
	end -- 289
	core.phase = "Armed" -- 290
	return true -- 291
end -- 288
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 295
	if core.phase ~= "Armed" then -- 295
		return false -- 296
	end -- 296
	core.phase = "Aiming" -- 297
	return true -- 298
end -- 295
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 312
	return core.phase == "Aiming" or core.phase == "Armed" -- 313
end -- 312
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 329
	if toT0 then -- 329
		return {t0 = clock, clock = 0} -- 330
	end -- 330
	return {t0 = 0, clock = t0} -- 331
end -- 329
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 343
	local host = -1 -- 353
	do -- 353
		local i = 0 -- 354
		while i < #bodies do -- 354
			do -- 354
				local b = bodies[i + 1] -- 355
				local isHost = false -- 356
				do -- 356
					local j = 0 -- 357
					while j < #bodies do -- 357
						do -- 357
							local h = bodies[j + 1].host -- 358
							if h == nil then -- 358
								goto __continue25 -- 359
							end -- 359
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 359
								isHost = true -- 360
								break -- 360
							end -- 360
						end -- 360
						::__continue25:: -- 360
						j = j + 1 -- 357
					end -- 357
				end -- 357
				if not isHost then -- 357
					goto __continue23 -- 362
				end -- 362
				if host < 0 or b.gm > bodies[host + 1].gm then -- 362
					host = i -- 363
				end -- 363
			end -- 363
			::__continue23:: -- 363
			i = i + 1 -- 354
		end -- 354
	end -- 354
	if host >= 0 then -- 354
		return host -- 365
	end -- 365
	local best = -1 -- 367
	do -- 367
		local i = 0 -- 368
		while i < #bodies do -- 368
			do -- 368
				local b = bodies[i + 1] -- 369
				if b.orbitRadius ~= 0 then -- 369
					goto __continue32 -- 370
				end -- 370
				if best < 0 or b.gm > bodies[best + 1].gm then -- 370
					best = i -- 371
				end -- 371
			end -- 371
			::__continue32:: -- 371
			i = i + 1 -- 368
		end -- 368
	end -- 368
	return best -- 373
end -- 343
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 391
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 392
	local best = -1 -- 393
	local bestD = 1000000000 -- 394
	do -- 394
		local i = 0 -- 395
		while i < #bodies do -- 395
			do -- 395
				if i == anchor then -- 395
					goto __continue37 -- 396
				end -- 396
				local b = bodies[i + 1] -- 397
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 398
				local d = distance( -- 399
					probe, -- 399
					bodyPositionAt(b, t) -- 399
				) -- 399
				if d < threshold and d < bestD then -- 399
					bestD = d -- 401
					best = i -- 402
				end -- 402
			end -- 402
			::__continue37:: -- 402
			i = i + 1 -- 395
		end -- 395
	end -- 395
	return best -- 405
end -- 391
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 409
	if core.flight == nil then -- 409
		return 0 -- 410
	end -- 410
	local idx = math.floor(core.flightTime / core.dt) -- 411
	local last = #core.flight.points - 1 -- 412
	if idx > last then -- 412
		idx = last -- 413
	end -- 413
	if idx < 0 then -- 413
		idx = 0 -- 414
	end -- 414
	return idx -- 415
end -- 409
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
function ____exports.coreUpdate(core, dt, level) -- 432
	if core.phase ~= "Flying" or core.flight == nil then -- 432
		return false -- 433
	end -- 433
	if level ~= nil then -- 433
		local idx = ____exports.coreProbeIndex(core) -- 437
		core.slowmoBody = ____exports.slowMotionBody( -- 438
			level.bodies, -- 438
			core.flight.points[idx + 1], -- 438
			core.t0 + core.flightTime, -- 438
			____exports.anchorBodyIndex(level.bodies), -- 438
			level.slowMoFloor -- 438
		) -- 438
		core.slowmo = core.slowmoBody >= 0 -- 439
	end -- 439
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 442
	core.flightTime = core.flightTime + dt * speed -- 443
	local naturalEnd = #core.flight.points - 1 -- 444
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 445
	if ____exports.coreProbeIndex(core) >= endIdx then -- 445
		core.flightTime = endIdx * core.dt -- 448
		core.phase = "Result" -- 449
		return true -- 450
	end -- 450
	return false -- 452
end -- 432
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 458
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 462
	local maxSpeed = 0 -- 463
	local closestDist = 1000000000 -- 464
	local eccentricity = nil -- 465
	if core.flight ~= nil then -- 465
		local pts = core.flight.points -- 468
		local vels = core.flight.velocities -- 469
		local ____end = ____exports.coreProbeIndex(core) -- 470
		local targetIdx = level.goal.planetIndex -- 471
		local targetBody = targetIdx >= 0 and targetIdx < #level.bodies and level.bodies[targetIdx + 1] or nil -- 472
		do -- 472
			local k = 0 -- 474
			while k <= ____end and k < #pts do -- 474
				local p = pts[k + 1] -- 475
				if vels ~= nil and k < #vels then -- 475
					local v = vels[k + 1] -- 477
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 478
					if spd > maxSpeed then -- 478
						maxSpeed = spd -- 479
					end -- 479
				end -- 479
				if targetBody ~= nil then -- 479
					local t = core.t0 + k * core.dt -- 482
					local tp = bodyPositionAt(targetBody, t) -- 483
					local d = distance(p, tp) -- 484
					if d < closestDist then -- 484
						closestDist = d -- 485
					end -- 485
				end -- 485
				k = k + 1 -- 474
			end -- 474
		end -- 474
		if targetBody ~= nil and targetBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 474
			local tEnd = core.t0 + ____end * core.dt -- 490
			local tpEnd = bodyPositionAt(targetBody, tEnd) -- 491
			local tvEnd = bodyVelocityAt(targetBody, tEnd) -- 492
			local rx = pts[____end + 1].x - tpEnd.x -- 493
			local ry = pts[____end + 1].y - tpEnd.y -- 494
			local vx = vels[____end + 1].x - tvEnd.x -- 495
			local vy = vels[____end + 1].y - tvEnd.y -- 496
			local r = math.sqrt(rx * rx + ry * ry) -- 497
			local v2 = vx * vx + vy * vy -- 498
			local mu = targetBody.gm -- 499
			if r > 0 and mu > 0 then -- 499
				local energy = v2 / 2 - mu / r -- 501
				local h = rx * vy - ry * vx -- 502
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 503
				if term >= 0 then -- 503
					eccentricity = math.sqrt(term) -- 505
				end -- 505
			end -- 505
		end -- 505
	end -- 505
	return { -- 511
		burnDv = burnDv, -- 512
		flightTime = core.flightTime, -- 513
		closestDist = closestDist < 100000000 and closestDist or 0, -- 514
		maxSpeed = maxSpeed, -- 515
		eccentricity = eccentricity -- 516
	} -- 516
end -- 458
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 521
	core.phase = "Aiming" -- 522
	core.viewMode = "2D" -- 524
	core.flight = nil -- 525
	core.flightTime = 0 -- 526
	core.goalIndex = -1 -- 527
	core.result = nil -- 528
	core.slowmo = false -- 529
	core.slowmoBody = -1 -- 530
	core.aim = neutralAim(levelAimMin(aimMin)) -- 531
end -- 521
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 545
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 545
		return false -- 547
	end -- 547
	core.phase = "LevelSelect" -- 548
	core.viewMode = "2D" -- 550
	core.flight = nil -- 551
	core.flightTime = 0 -- 552
	core.goalIndex = -1 -- 553
	core.result = nil -- 554
	core.slowmo = false -- 555
	core.slowmoBody = -1 -- 556
	return true -- 557
end -- 545
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 586
	if core.phase ~= "Result" then -- 586
		return false -- 587
	end -- 587
	core.phase = "Finale" -- 588
	return true -- 589
end -- 586
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 607
	local dist = distance > 1 and distance or 1 -- 608
	local ux = probe.x -- 610
	local uy = probe.y -- 611
	local len = math.sqrt(ux * ux + uy * uy) -- 612
	if len < 0.000001 then -- 612
		ux = 0 -- 613
		uy = 1 -- 613
	else -- 613
		ux = ux / len -- 613
		uy = uy / len -- 613
	end -- 613
	local tilt = tiltDeg * math.pi / 180 -- 614
	local flat = math.cos(tilt) * dist -- 615
	return { -- 616
		target = Vec3(0, 0, 0), -- 618
		eye = Vec3( -- 619
			ux * flat * PlaneToWorldX, -- 619
			math.sin(tilt) * dist, -- 619
			uy * flat * PlaneToWorldZ -- 619
		) -- 619
	} -- 619
end -- 607
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 731
	local core = ____exports.createCore(level.physicsStep) -- 732
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 735
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 738
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
	local function applyView() -- 753
		local mode = core.viewMode -- 754
		if mode == appliedMode then -- 754
			return -- 755
		end -- 755
		appliedMode = mode -- 756
		local is2D = mode == "2D" -- 757
		deps.plan:setVisible(is2D) -- 758
		deps.trajectory.root.visible = not is2D -- 759
		deps:setWorldVisible(not is2D) -- 760
		deps.aim:setFullScreenAim(is2D) -- 761
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 762
	end -- 753
	local function makeBasis(frame) -- 765
		return prepareCamera({ -- 766
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 768
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 769
			up = {x = 0, y = 1, z = 0}, -- 770
			fovYDeg = deps.fovYDeg, -- 771
			aspect = deps.aspect, -- 772
			viewW = deps.viewW, -- 773
			viewH = deps.viewH -- 774
		}, HANDEDNESS, FLIP_Y) -- 774
	end -- 765
	local predKey = "" -- 783
	local predPoints = {} -- 784
	local introT = IntroDurationSec -- 786
	local introLogged = false -- 787
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 789
	local clock = 0 -- 795
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 797
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 799
	local obsYawDeg = 0 -- 803
	local obsPitchDeg = 0 -- 804
	local obsZoom = 1 -- 805
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 807
	local idlePath = nil -- 808
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 819
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 821
	local lastSlowmoBody = -1 -- 822
	local flightLogT = 0 -- 823
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 825
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 826
	local function prepareIdle() -- 827
		clock = 0 -- 829
		core.t0 = 0 -- 830
		if level.probeVel0 == nil then -- 830
			idlePath = nil -- 832
			return -- 833
		end -- 833
		local idleSteps = level.maxSteps -- 841
		local v0x = level.probeVel0.x -- 842
		local v0y = level.probeVel0.y -- 843
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 844
		if v0 > 0.000001 then -- 844
			local bestD = 1000000000 -- 846
			for ____, b in ipairs(level.bodies) do -- 847
				do -- 847
					if b.gm <= 0 then -- 847
						goto __continue74 -- 848
					end -- 848
					local dx = b.orbitCenter.x - level.probeStart.x -- 849
					local dy = b.orbitCenter.y - level.probeStart.y -- 850
					local d = math.sqrt(dx * dx + dy * dy) -- 851
					if d < bestD then -- 851
						bestD = d -- 852
					end -- 852
				end -- 852
				::__continue74:: -- 852
			end -- 852
			if bestD > 0.000001 and bestD < 100000000 then -- 852
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 855
				if n > 60 and n < 40000 then -- 855
					idleSteps = n -- 856
				end -- 856
			end -- 856
		end -- 856
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 859
			steps = idleSteps, -- 862
			dt = core.dt, -- 862
			sampleEvery = 1, -- 862
			escapeRadius = level.escapeRadius, -- 862
			t0 = core.t0 -- 862
		}) -- 862
	end -- 827
	local function idleIndex() -- 865
		if idlePath == nil then -- 865
			return 0 -- 866
		end -- 866
		local n = #idlePath.points -- 867
		if n <= 1 then -- 867
			return 0 -- 868
		end -- 868
		local i = math.floor(orbitClock / core.dt) % n -- 869
		if i < 0 then -- 869
			i = 0 -- 870
		end -- 870
		return i -- 871
	end -- 865
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 884
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 885
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 888
		local wps = goalWaypoints(level.goal) -- 889
		if #wps == 0 then -- 889
			return nil -- 890
		end -- 890
		local passed = 0 -- 891
		if core.flight ~= nil then -- 891
			local upto = math.floor(core.flightTime / core.dt) -- 893
			passed = waypointProgress( -- 894
				core.flight.points, -- 894
				level.bodies, -- 894
				level.goal, -- 894
				core.dt, -- 894
				core.t0, -- 894
				upto, -- 894
				core.flight.velocities -- 894
			).passed -- 894
		end -- 894
		if passed >= #wps then -- 894
			return nil -- 896
		end -- 896
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 897
	end -- 888
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 908
		local corePts = {probe} -- 911
		local coreRadii = {deps.scene.probeRadius} -- 912
		local next = nextStationBody() -- 913
		local nextTol = 0 -- 914
		if next ~= nil then -- 914
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 916
			local wps = goalWaypoints(level.goal) -- 917
			local passed = 0 -- 918
			if core.flight ~= nil then -- 918
				passed = waypointProgress( -- 920
					core.flight.points, -- 920
					level.bodies, -- 920
					level.goal, -- 920
					core.dt, -- 920
					core.t0, -- 920
					math.floor(core.flightTime / core.dt), -- 920
					core.flight.velocities -- 920
				).passed -- 920
			end -- 920
			if passed < #wps then -- 920
				nextTol = wps[passed + 1].tolerance -- 922
			end -- 922
			local r = nextTol > next.radius and nextTol or next.radius -- 923
			coreRadii[#coreRadii + 1] = r -- 924
		end -- 924
		if anchorDef == nil then -- 924
			return {pts = corePts, radii = coreRadii} -- 927
		end -- 927
		local anchorR = anchorDef.radius -- 932
		do -- 932
			local i = 0 -- 933
			while i < #level.bodies do -- 933
				local b = level.bodies[i + 1] -- 934
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 934
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 934
						anchorR = deps.visuals[i + 1].displayRadius -- 936
					end -- 936
					break -- 937
				end -- 937
				i = i + 1 -- 933
			end -- 933
		end -- 933
		local withAnchorPts = { -- 940
			probe, -- 940
			bodyPositionAt(anchorDef, t) -- 940
		} -- 940
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 941
		do -- 941
			local i = 1 -- 942
			while i < #corePts do -- 942
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 943
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 944
				i = i + 1 -- 942
			end -- 942
		end -- 942
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 946
		if want <= CameraFramingBudget then -- 946
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 947
		end -- 947
		return {pts = corePts, radii = coreRadii} -- 948
	end -- 908
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 952
		local wps = goalWaypoints(level.goal) -- 953
		if #wps == 0 then -- 953
			return {} -- 954
		end -- 954
		local passed = 0 -- 955
		if upto ~= nil and core.flight ~= nil then -- 955
			passed = waypointProgress( -- 957
				core.flight.points, -- 957
				level.bodies, -- 957
				level.goal, -- 957
				core.dt, -- 957
				core.t0, -- 957
				upto, -- 957
				core.flight.velocities -- 957
			).passed -- 957
		end -- 957
		if passed >= #wps then -- 957
			return {} -- 962
		end -- 962
		local nextWp = wps[passed + 1] -- 963
		local body = level.bodies[nextWp.planetIndex + 1] -- 964
		if body == nil then -- 964
			return {} -- 965
		end -- 965
		return {{ -- 966
			center = bodyPositionAt(body, t), -- 966
			radius = nextWp.tolerance, -- 966
			passed = false -- 966
		}} -- 966
	end -- 952
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 970
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 970
			return f -- 971
		end -- 971
		local dx = f.eye.x - f.target.x -- 972
		local dy = f.eye.y - f.target.y -- 973
		local dz = f.eye.z - f.target.z -- 974
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 975
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 976
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 977
		local lo = CameraTiltMin * math.pi / 180 -- 978
		local hi = CameraTiltMax * math.pi / 180 -- 979
		if pitch < lo then -- 979
			pitch = lo -- 980
		end -- 980
		if pitch > hi then -- 980
			pitch = hi -- 981
		end -- 981
		local cp = math.cos(pitch) -- 982
		return { -- 983
			target = f.target, -- 984
			eye = Vec3( -- 985
				f.target.x + r * cp * math.sin(yaw), -- 986
				f.target.y + r * math.sin(pitch), -- 987
				f.target.z + r * cp * math.cos(yaw) -- 988
			) -- 988
		} -- 988
	end -- 970
	local function updateAiming(dt) -- 993
		deps.aim:setEnabled(true) -- 994
		local dragging = deps.aim:isDragging() -- 996
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 996
			local aimRate = level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1 -- 1007
			clock = clock + dt * aimRate -- 1008
			orbitClock = orbitClock + dt * aimRate -- 1009
		end -- 1009
		local idx = idleIndex() -- 1011
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 1012
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 1013
		local tNow = core.t0 + clock -- 1016
		deps.scene.syncBodies(tNow) -- 1018
		deps.scene.syncProbe(probePos) -- 1019
		if idlePath ~= nil and idx > 0 then -- 1019
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 1020
		end -- 1020
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1022
		deps.plan:syncProbe(probePos, probeVel) -- 1023
		local fr = framingPoints(probePos, tNow) -- 1026
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1027
		if frameLogged < 6 then -- 1027
			frameLogged = frameLogged + 1 -- 1031
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1032
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1036
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1037
				__TS__ArrayMap( -- 1043
					fr.pts, -- 1043
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1043
				), -- 1043
				" " -- 1043
			)) .. "]") -- 1043
		end -- 1043
		if introT < IntroDurationSec then -- 1043
			introT = introT + dt -- 1048
			local k = introT / IntroDurationSec -- 1049
			if k > 1 then -- 1049
				k = 1 -- 1050
			end -- 1050
			if k >= 1 and not introLogged then -- 1050
				introLogged = true -- 1052
				print("[escape-velocity] intro camera done") -- 1053
			end -- 1053
			local wps0 = goalWaypoints(level.goal) -- 1055
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 1056
			local wide = frame -- 1057
			local from = wide -- 1058
			local to = wide -- 1059
			local e = 0 -- 1060
			if k < 0.35 then -- 1060
				local pw = planeToWorld(probePos, 0) -- 1062
				local dx = wide.eye.x - wide.target.x -- 1063
				local dy = wide.eye.y - wide.target.y -- 1064
				local dz = wide.eye.z - wide.target.z -- 1065
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1066
				if len > 0.000001 then -- 1066
					local s = IntroCloseDist / len -- 1068
					dx = dx * s -- 1069
					dy = dy * s -- 1069
					dz = dz * s -- 1069
				end -- 1069
				from = { -- 1071
					target = Vec3(pw.x, pw.y, pw.z), -- 1071
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 1071
				} -- 1071
				e = k / 0.35 -- 1072
			elseif k < 0.72 and wpBody ~= nil then -- 1072
				local c = planeToWorld( -- 1075
					bodyPositionAt(wpBody, tNow), -- 1075
					0 -- 1075
				) -- 1075
				local dx = wide.eye.x - wide.target.x -- 1076
				local dy = wide.eye.y - wide.target.y -- 1077
				local dz = wide.eye.z - wide.target.z -- 1078
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1079
				local want = math.max(24, wpBody.radius * 6) -- 1080
				if len > 0.000001 then -- 1080
					local s = want / len -- 1082
					dx = dx * s -- 1083
					dy = dy * s -- 1083
					dz = dz * s -- 1083
				end -- 1083
				to = { -- 1085
					target = Vec3(c.x, c.y, c.z), -- 1085
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1085
				} -- 1085
				e = (k - 0.35) / 0.37 -- 1086
			elseif wpBody ~= nil then -- 1086
				local c = planeToWorld( -- 1089
					bodyPositionAt(wpBody, tNow), -- 1089
					0 -- 1089
				) -- 1089
				local dx = wide.eye.x - wide.target.x -- 1090
				local dy = wide.eye.y - wide.target.y -- 1091
				local dz = wide.eye.z - wide.target.z -- 1092
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1093
				local want = math.max(24, wpBody.radius * 6) -- 1094
				if len > 0.000001 then -- 1094
					local s = want / len -- 1096
					dx = dx * s -- 1097
					dy = dy * s -- 1097
					dz = dz * s -- 1097
				end -- 1097
				from = { -- 1099
					target = Vec3(c.x, c.y, c.z), -- 1099
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1099
				} -- 1099
				e = (k - 0.72) / 0.28 -- 1100
			end -- 1100
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 1102
			frame = { -- 1103
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 1104
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 1109
			} -- 1109
		end -- 1109
		frame = applyObserve(frame) -- 1117
		deps.rig.apply(deps.camera, frame) -- 1118
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1119
		local basis = makeBasis(frame) -- 1120
		if core.viewMode == "2D" then -- 1120
			local sp = deps.plan:probeScreen() -- 1126
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1127
		else -- 1127
			local pp = projectPrepared( -- 1129
				planeToWorld(probePos, 0), -- 1129
				basis -- 1129
			) -- 1129
			if pp ~= nil then -- 1129
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1130
			end -- 1130
		end -- 1130
		if not aimed then -- 1130
			deps.trajectory:clearPrediction() -- 1143
			deps.plan:clearPrediction() -- 1144
			predKey = "" -- 1145
		else -- 1145
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 1149
			if key ~= predKey then -- 1149
				predKey = key -- 1153
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1156
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1157
					steps = PredictSteps, -- 1160
					dt = core.dt, -- 1160
					sampleEvery = 4, -- 1160
					escapeRadius = level.escapeRadius, -- 1160
					t0 = tNow, -- 1160
					brake = motion.brake -- 1160
				}).points -- 1160
			end -- 1160
			deps.trajectory:setPrediction(predPoints, basis) -- 1163
			deps.plan:setPrediction(predPoints) -- 1165
		end -- 1165
		local rings = goalRingsAt(tNow) -- 1167
		deps.trajectory:setGoalRings(rings, basis) -- 1168
		deps.trajectory:clearTrail() -- 1169
		deps.plan:setGoalRings(rings) -- 1171
		deps.plan:clearTrail() -- 1172
		deps.plan:flush() -- 1173
	end -- 993
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
	local function updateFinale() -- 1188
		deps.aim:setEnabled(false) -- 1189
		if core.flight == nil then -- 1189
			return -- 1190
		end -- 1190
		local idx = ____exports.coreProbeIndex(core) -- 1191
		local pos = core.flight.points[idx + 1] -- 1192
		local tWorld = core.t0 + core.flightTime -- 1193
		deps.scene.syncBodies(tWorld) -- 1196
		deps.scene.syncProbe(pos) -- 1197
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1198
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1201
		deps.camera:lookAt( -- 1202
			frame.eye, -- 1202
			frame.target, -- 1202
			Vec3(0, 1, 0) -- 1202
		) -- 1202
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1203
		local trail = {} -- 1206
		do -- 1206
			local i = 0 -- 1207
			while i <= idx do -- 1207
				trail[#trail + 1] = core.flight.points[i + 1] -- 1207
				i = i + 1 -- 1207
			end -- 1207
		end -- 1207
		local rings = goalRingsAt(tWorld, idx) -- 1208
		local basis = makeBasis(frame) -- 1209
		deps.trajectory:setTrail(trail, basis) -- 1210
		deps.trajectory:setGoalRings(rings, basis) -- 1211
		deps.plan:clearPrediction() -- 1212
		deps.plan:setGoalRings(rings) -- 1213
		deps.plan:flush() -- 1214
	end -- 1188
	local function updateFlying(dt) -- 1216
		deps.aim:setEnabled(false) -- 1217
		local entered = ____exports.coreUpdate(core, dt, level) -- 1220
		if core.flight == nil then -- 1220
			return entered -- 1221
		end -- 1221
		local idx = ____exports.coreProbeIndex(core) -- 1223
		local pos = core.flight.points[idx + 1] -- 1224
		local tWorld = core.t0 + core.flightTime -- 1228
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1228
			lastSlowmo = core.slowmo -- 1232
			lastSlowmoBody = core.slowmoBody -- 1233
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1234
			local nearD = near ~= nil and distance( -- 1235
				pos, -- 1235
				bodyPositionAt(near, tWorld) -- 1235
			) or 0 -- 1235
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1236
		end -- 1236
		flightLogT = flightLogT + dt -- 1243
		if flightLogT >= 0.5 then -- 1243
			flightLogT = 0 -- 1245
			local total = (#core.flight.points - 1) * core.dt -- 1246
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1247
		end -- 1247
		deps.scene.syncBodies(tWorld) -- 1253
		deps.scene.syncProbe(pos) -- 1254
		if idx > 0 then -- 1254
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1256
		end -- 1256
		local fr -- 1263
		local closeDist = nil -- 1264
		if core.slowmo and core.slowmoBody >= 0 then -- 1264
			local near = level.bodies[core.slowmoBody + 1] -- 1266
			local nearR = near.radius -- 1268
			do -- 1268
				local i = 0 -- 1269
				while i < #level.bodies do -- 1269
					local b = level.bodies[i + 1] -- 1270
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1270
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1270
							nearR = deps.visuals[i + 1].displayRadius -- 1272
						end -- 1272
						break -- 1273
					end -- 1273
					i = i + 1 -- 1269
				end -- 1269
			end -- 1269
			fr = { -- 1276
				pts = { -- 1276
					pos, -- 1276
					bodyPositionAt(near, tWorld) -- 1276
				}, -- 1276
				radii = {deps.scene.probeRadius, nearR} -- 1276
			} -- 1276
			closeDist = SlowMoCloseDist -- 1277
		else -- 1277
			fr = framingPoints(pos, tWorld) -- 1279
		end -- 1279
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1281
		deps.rig.apply(deps.camera, frame) -- 1282
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1283
		local basis = makeBasis(frame) -- 1284
		local trail = {} -- 1287
		do -- 1287
			local i = 0 -- 1288
			while i <= idx do -- 1288
				trail[#trail + 1] = core.flight.points[i + 1] -- 1288
				i = i + 1 -- 1288
			end -- 1288
		end -- 1288
		local rings = goalRingsAt(tWorld, idx) -- 1289
		deps.trajectory:setTrail(trail, basis) -- 1290
		deps.trajectory:setGoalRings(rings, basis) -- 1291
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1294
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1295
		deps.plan:setTrail(trail) -- 1296
		deps.plan:clearPrediction() -- 1297
		deps.plan:setGoalRings(rings) -- 1298
		deps.plan:flush() -- 1299
		return entered -- 1301
	end -- 1216
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1315
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1316
		core.t0 = next.t0 -- 1317
		clock = next.clock -- 1318
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1319
	end -- 1315
	local function update(dt) -- 1322
		applyView() -- 1325
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1325
			updateAiming(dt) -- 1327
		elseif core.phase == "Flying" then -- 1327
			local entered = updateFlying(dt) -- 1329
			if entered and core.result ~= nil then -- 1329
				local toFinale = deps.finale == true and core.result == "success" -- 1332
				if toFinale then -- 1332
					____exports.coreEnterFinale(core) -- 1333
				end -- 1333
				local telem = ____exports.calcFlightTelemetry(core, level) -- 1335
				deps:onResult(core.result, telem) -- 1336
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1336
					local ____end = #core.flight.points - 1 -- 1338
					deps:onFinale({ -- 1339
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1340
						time = core.flightTime, -- 1341
						tWorld = core.t0 + core.flightTime -- 1342
					}) -- 1342
				end -- 1342
				deps:onPhase(toFinale and "Finale" or "Result") -- 1345
			end -- 1345
		elseif core.phase == "Finale" then -- 1345
			updateFinale() -- 1348
		end -- 1348
	end -- 1322
	return { -- 1353
		phase = function() return core.phase end, -- 1354
		result = function() return core.result end, -- 1355
		onAimDrag = function(____, a) -- 1356
			core.aim = a -- 1357
			aimed = true -- 1358
			introT = IntroDurationSec -- 1359
		end, -- 1356
		aimReady = function() -- 1361
			if not ____exports.coreArm(core) then -- 1361
				return -- 1362
			end -- 1362
			applyView() -- 1363
			deps:onPhase("Armed") -- 1364
		end, -- 1361
		launchArmed = function() -- 1366
			if core.phase ~= "Armed" then -- 1366
				return -- 1368
			end -- 1368
			handoffDate(true) -- 1369
			____exports.coreLaunch( -- 1370
				core, -- 1370
				core.aim.velocity, -- 1370
				level, -- 1370
				probePos, -- 1370
				probeVel -- 1370
			) -- 1370
			deps.trajectory:clearPrediction() -- 1371
			deps.plan:clearPrediction() -- 1372
			applyView() -- 1373
			deps:onPhase("Flying") -- 1374
		end, -- 1366
		armed = function() return core.phase == "Armed" end, -- 1376
		viewMode = function() return core.viewMode end, -- 1377
		toggleViewMode = function() -- 1378
			____exports.coreToggleView(core) -- 1380
			applyView() -- 1381
		end, -- 1378
		observeDrag = function(____, dx, dy) -- 1383
			introT = IntroDurationSec -- 1384
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1385
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1386
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1387
			if obsPitchDeg > 40 then -- 1387
				obsPitchDeg = 40 -- 1388
			end -- 1388
			if obsPitchDeg < -40 then -- 1388
				obsPitchDeg = -40 -- 1389
			end -- 1389
		end, -- 1383
		observeZoom = function(____, deltaDist) -- 1391
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1392
			if obsZoom < 0.4 then -- 1392
				obsZoom = 0.4 -- 1393
			end -- 1393
			if obsZoom > 1.8 then -- 1393
				obsZoom = 1.8 -- 1394
			end -- 1394
		end, -- 1391
		launch = function(____, v) -- 1396
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1396
				return -- 1397
			end -- 1397
			handoffDate(true) -- 1398
			____exports.coreLaunch( -- 1400
				core, -- 1400
				v, -- 1400
				level, -- 1400
				probePos, -- 1400
				probeVel -- 1400
			) -- 1400
			deps.trajectory:clearPrediction() -- 1401
			deps.plan:clearPrediction() -- 1402
			applyView() -- 1403
			deps:onPhase("Flying") -- 1404
		end, -- 1396
		retry = function() -- 1406
			if core.phase ~= "Result" then -- 1406
				return -- 1407
			end -- 1407
			handoffDate(false) -- 1408
			aimed = false -- 1409
			____exports.coreRetry(core, level.aimMin) -- 1410
			deps.trajectory:clearTrail() -- 1411
			deps.trajectory:clearPrediction() -- 1412
			deps.trajectory:clearGoalRings() -- 1413
			deps.plan:clearTrail() -- 1414
			deps.plan:clearPrediction() -- 1415
			deps.plan:clearGoalRings() -- 1416
			applyView() -- 1417
			deps:onPhase("Aiming") -- 1418
		end, -- 1406
		backToSelect = function() -- 1420
			if not ____exports.coreBackToSelect(core) then -- 1420
				return false -- 1421
			end -- 1421
			deps.aim:setEnabled(false) -- 1423
			deps.trajectory:clearTrail() -- 1424
			deps.trajectory:clearPrediction() -- 1425
			deps.trajectory:clearGoalRings() -- 1426
			deps.plan:clearTrail() -- 1427
			deps.plan:clearPrediction() -- 1428
			deps.plan:clearGoalRings() -- 1429
			applyView() -- 1430
			deps:onPhase("LevelSelect") -- 1431
			return true -- 1432
		end, -- 1420
		startLevel = function() -- 1434
			aimed = false -- 1437
			____exports.coreRetry(core, level.aimMin) -- 1438
			deps.rig.reset() -- 1441
			introT = 0 -- 1442
			introLogged = false -- 1443
			prepareIdle() -- 1444
			deps.trajectory:clearTrail() -- 1445
			deps.trajectory:clearPrediction() -- 1446
			deps.trajectory:clearGoalRings() -- 1447
			deps.plan:clearTrail() -- 1448
			deps.plan:clearPrediction() -- 1449
			deps.plan:clearGoalRings() -- 1450
			appliedMode = "" -- 1453
			applyView() -- 1454
			deps:onPhase("Aiming") -- 1455
		end, -- 1434
		stepTime = function(____, dir, span) -- 1457
			if not ____exports.coreTimeWarpAllowed(core) then -- 1457
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1461
				return -- 1462
			end -- 1462
			local span0 = span > 0 and span or 0 -- 1464
			clock = clock + dir * TimeWarpStep -- 1465
			if clock < 0 then -- 1465
				clock = 0 -- 1466
			end -- 1466
			if span0 > 0 and clock > span0 then -- 1466
				clock = span0 -- 1467
			end -- 1467
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1469
		end, -- 1457
		dateNow = function() return core.t0 + clock end, -- 1471
		setBrakeMode = function(____, on) -- 1472
			core.brakeMode = on -- 1473
		end, -- 1472
		brakeMode = function() return core.brakeMode end, -- 1476
		setPlaybackSpeed = function(____, speed) -- 1477
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1477
				return -- 1479
			end -- 1479
			core.playback = speed -- 1480
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1481
		end, -- 1477
		playbackSpeed = function() return core.playback end, -- 1483
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1484
		update = function(____, frameDt) return update(frameDt) end -- 1486
	} -- 1486
end -- 731
return ____exports -- 731
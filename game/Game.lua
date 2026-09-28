-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
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
local function neutralAim(minSpeed) -- 182
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 183
end -- 182
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 187
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 188
end -- 187
function ____exports.createCore(dt) -- 191
	return { -- 192
		phase = "Aiming", -- 193
		aim = neutralAim(AimMinSpeed), -- 194
		flight = nil, -- 195
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 196
		brakeMode = false, -- 197
		t0 = 0, -- 198
		flightTime = 0, -- 199
		goalIndex = -1, -- 200
		result = nil, -- 201
		viewMode = "2D", -- 203
		playback = FlightPlayback, -- 205
		slowmo = false, -- 206
		slowmoBody = -1, -- 207
		hasBraked = false, -- 208
		brakePointIndex = -1 -- 209
	} -- 209
end -- 191
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 221
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 222
	return core.viewMode -- 223
end -- 221
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 241
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 247
	local share = brakeMode and BrakeShare or 1 -- 248
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 249
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 250
	local brake = brakeMode and mag > 0 and ({ -- 251
		dv = mag * (1 - share), -- 252
		startStep = math.floor(maxSteps / 2) -- 252
	}) or nil -- 252
	return {init = init, brake = brake} -- 254
end -- 241
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 263
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 263
		return -- 265
	end -- 265
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 266
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 267
	local p0 = from ~= nil and from or level.probeStart -- 268
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 269
		steps = level.maxSteps, -- 272
		dt = core.dt, -- 272
		sampleEvery = 1, -- 272
		escapeRadius = level.escapeRadius, -- 272
		t0 = core.t0, -- 272
		brake = motion.brake -- 272
	}) -- 272
	core.flight = flight -- 274
	core.goalIndex = findGoalIndex( -- 275
		flight.points, -- 275
		level.bodies, -- 275
		level.goal, -- 275
		core.dt, -- 275
		core.t0, -- 275
		flight.velocities -- 275
	) -- 275
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 276
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 279
	core.flightTime = 0 -- 284
	core.slowmo = false -- 286
	core.slowmoBody = -1 -- 287
	core.hasBraked = false -- 288
	core.brakePointIndex = -1 -- 289
	core.phase = "Flying" -- 290
	core.viewMode = "3D" -- 292
end -- 263
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 301
	if core.phase ~= "Aiming" then -- 301
		return false -- 302
	end -- 302
	core.phase = "Armed" -- 303
	return true -- 304
end -- 301
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 308
	if core.phase ~= "Armed" then -- 308
		return false -- 309
	end -- 309
	core.phase = "Aiming" -- 310
	return true -- 311
end -- 308
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 325
	return core.phase == "Aiming" or core.phase == "Armed" -- 326
end -- 325
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 342
	if toT0 then -- 342
		return {t0 = clock, clock = 0} -- 343
	end -- 343
	return {t0 = 0, clock = t0} -- 344
end -- 342
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 356
	local host = -1 -- 366
	do -- 366
		local i = 0 -- 367
		while i < #bodies do -- 367
			do -- 367
				local b = bodies[i + 1] -- 368
				local isHost = false -- 369
				do -- 369
					local j = 0 -- 370
					while j < #bodies do -- 370
						do -- 370
							local h = bodies[j + 1].host -- 371
							if h == nil then -- 371
								goto __continue25 -- 372
							end -- 372
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 372
								isHost = true -- 373
								break -- 373
							end -- 373
						end -- 373
						::__continue25:: -- 373
						j = j + 1 -- 370
					end -- 370
				end -- 370
				if not isHost then -- 370
					goto __continue23 -- 375
				end -- 375
				if host < 0 or b.gm > bodies[host + 1].gm then -- 375
					host = i -- 376
				end -- 376
			end -- 376
			::__continue23:: -- 376
			i = i + 1 -- 367
		end -- 367
	end -- 367
	if host >= 0 then -- 367
		return host -- 378
	end -- 378
	local best = -1 -- 380
	do -- 380
		local i = 0 -- 381
		while i < #bodies do -- 381
			do -- 381
				local b = bodies[i + 1] -- 382
				if b.orbitRadius ~= 0 then -- 382
					goto __continue32 -- 383
				end -- 383
				if best < 0 or b.gm > bodies[best + 1].gm then -- 383
					best = i -- 384
				end -- 384
			end -- 384
			::__continue32:: -- 384
			i = i + 1 -- 381
		end -- 381
	end -- 381
	return best -- 386
end -- 356
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 404
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 405
	local best = -1 -- 406
	local bestD = 1000000000 -- 407
	do -- 407
		local i = 0 -- 408
		while i < #bodies do -- 408
			do -- 408
				if i == anchor then -- 408
					goto __continue37 -- 409
				end -- 409
				local b = bodies[i + 1] -- 410
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 411
				local d = distance( -- 412
					probe, -- 412
					bodyPositionAt(b, t) -- 412
				) -- 412
				if d < threshold and d < bestD then -- 412
					bestD = d -- 414
					best = i -- 415
				end -- 415
			end -- 415
			::__continue37:: -- 415
			i = i + 1 -- 408
		end -- 408
	end -- 408
	return best -- 418
end -- 404
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 422
	if core.flight == nil then -- 422
		return 0 -- 423
	end -- 423
	local idx = math.floor(core.flightTime / core.dt) -- 424
	local last = #core.flight.points - 1 -- 425
	if idx > last then -- 425
		idx = last -- 426
	end -- 426
	if idx < 0 then -- 426
		idx = 0 -- 427
	end -- 427
	return idx -- 428
end -- 422
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
function ____exports.coreUpdate(core, dt, level) -- 445
	if core.phase ~= "Flying" or core.flight == nil then -- 445
		return false -- 446
	end -- 446
	if level ~= nil then -- 446
		local idx = ____exports.coreProbeIndex(core) -- 450
		core.slowmoBody = ____exports.slowMotionBody( -- 451
			level.bodies, -- 451
			core.flight.points[idx + 1], -- 451
			core.t0 + core.flightTime, -- 451
			____exports.anchorBodyIndex(level.bodies), -- 451
			level.slowMoFloor -- 451
		) -- 451
		core.slowmo = core.slowmoBody >= 0 -- 452
	end -- 452
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 455
	core.flightTime = core.flightTime + dt * speed -- 456
	local naturalEnd = #core.flight.points - 1 -- 457
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 458
	if ____exports.coreProbeIndex(core) >= endIdx then -- 458
		core.flightTime = endIdx * core.dt -- 461
		core.phase = "Result" -- 462
		return true -- 463
	end -- 463
	return false -- 465
end -- 445
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 471
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 475
	local maxSpeed = 0 -- 476
	local closestDist = 1000000000 -- 477
	local eccentricity = nil -- 478
	if core.flight ~= nil then -- 478
		local pts = core.flight.points -- 481
		local vels = core.flight.velocities -- 482
		local ____end = ____exports.coreProbeIndex(core) -- 483
		local targetIdx = level.goal.planetIndex -- 484
		local targetBody = targetIdx >= 0 and targetIdx < #level.bodies and level.bodies[targetIdx + 1] or nil -- 485
		do -- 485
			local k = 0 -- 487
			while k <= ____end and k < #pts do -- 487
				local p = pts[k + 1] -- 488
				if vels ~= nil and k < #vels then -- 488
					local v = vels[k + 1] -- 490
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 491
					if spd > maxSpeed then -- 491
						maxSpeed = spd -- 492
					end -- 492
				end -- 492
				if targetBody ~= nil then -- 492
					local t = core.t0 + k * core.dt -- 495
					local tp = bodyPositionAt(targetBody, t) -- 496
					local d = distance(p, tp) -- 497
					if d < closestDist then -- 497
						closestDist = d -- 498
					end -- 498
				end -- 498
				k = k + 1 -- 487
			end -- 487
		end -- 487
		if targetBody ~= nil and targetBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 487
			local tEnd = core.t0 + ____end * core.dt -- 503
			local tpEnd = bodyPositionAt(targetBody, tEnd) -- 504
			local tvEnd = bodyVelocityAt(targetBody, tEnd) -- 505
			local rx = pts[____end + 1].x - tpEnd.x -- 506
			local ry = pts[____end + 1].y - tpEnd.y -- 507
			local vx = vels[____end + 1].x - tvEnd.x -- 508
			local vy = vels[____end + 1].y - tvEnd.y -- 509
			local r = math.sqrt(rx * rx + ry * ry) -- 510
			local v2 = vx * vx + vy * vy -- 511
			local mu = targetBody.gm -- 512
			if r > 0 and mu > 0 then -- 512
				local energy = v2 / 2 - mu / r -- 514
				local h = rx * vy - ry * vx -- 515
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 516
				if term >= 0 then -- 516
					eccentricity = math.sqrt(term) -- 518
				end -- 518
			end -- 518
		end -- 518
	end -- 518
	return { -- 524
		burnDv = burnDv, -- 525
		flightTime = core.flightTime, -- 526
		closestDist = closestDist < 100000000 and closestDist or 0, -- 527
		maxSpeed = maxSpeed, -- 528
		eccentricity = eccentricity -- 529
	} -- 529
end -- 471
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 534
	core.phase = "Aiming" -- 535
	core.viewMode = "2D" -- 537
	core.flight = nil -- 538
	core.flightTime = 0 -- 539
	core.goalIndex = -1 -- 540
	core.result = nil -- 541
	core.slowmo = false -- 542
	core.slowmoBody = -1 -- 543
	core.hasBraked = false -- 544
	core.brakePointIndex = -1 -- 545
	core.aim = neutralAim(levelAimMin(aimMin)) -- 546
end -- 534
--- 判定当前飞行状态下是否处于可逆喷制动窗口。
-- 纯函数，可单测。
function ____exports.isBrakeWindowActive(core, level) -- 553
	if core.phase ~= "Flying" or core.flight == nil or core.hasBraked then -- 553
		return false -- 554
	end -- 554
	local curIdx = ____exports.coreProbeIndex(core) -- 555
	local pts = core.flight.points -- 556
	if curIdx < 0 or curIdx >= #pts then -- 556
		return false -- 557
	end -- 557
	local targetIdx = level.goal.planetIndex -- 559
	if targetIdx < 0 or targetIdx >= #level.bodies then -- 559
		return false -- 560
	end -- 560
	local targetBody = level.bodies[targetIdx + 1] -- 561
	local tNow = core.t0 + core.flightTime -- 562
	local targetPos = bodyPositionAt(targetBody, tNow) -- 563
	local dist = distance(pts[curIdx + 1], targetPos) -- 564
	local floorD = level.slowMoFloor ~= nil and level.slowMoFloor > 0 and level.slowMoFloor or SlowMoFloorDist -- 567
	local brakeDistLimit = math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD) -- 568
	return dist <= brakeDistLimit and dist > targetBody.radius -- 569
end -- 553
--- 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
-- 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
-- 返回 true 表示制动成功应用。
function ____exports.applyInFlightBrake(core, level) -- 577
	if not ____exports.isBrakeWindowActive(core, level) then -- 577
		return false -- 578
	end -- 578
	if core.flight == nil then -- 578
		return false -- 579
	end -- 579
	local curIdx = ____exports.coreProbeIndex(core) -- 581
	local curPos = core.flight.points[curIdx + 1] -- 582
	local curVel = core.flight.velocities ~= nil and curIdx < #core.flight.velocities and core.flight.velocities[curIdx + 1] or ({x = 0, y = 0}) -- 583
	local tNow = core.t0 + core.flightTime -- 586
	local targetIdx = level.goal.planetIndex -- 588
	local targetBody = level.bodies[targetIdx + 1] -- 589
	local targetPos = bodyPositionAt(targetBody, tNow) -- 590
	local targetVel = bodyVelocityAt(targetBody, tNow) -- 591
	local relVel = {x = curVel.x - targetVel.x, y = curVel.y - targetVel.y} -- 594
	local relSpeed = math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y) -- 595
	local dist = distance(curPos, targetPos) -- 596
	if relSpeed <= 0.000001 or dist <= 0.000001 then -- 596
		return false -- 598
	end -- 598
	local vCirc = math.sqrt(targetBody.gm / dist) -- 601
	local targetRelSpeed = vCirc * 0.98 -- 604
	local reductionFactor = targetRelSpeed / relSpeed -- 605
	local clampedFactor = math.min(0.95, reductionFactor) -- 606
	local newRelVel = {x = relVel.x * clampedFactor, y = relVel.y * clampedFactor} -- 608
	local newVel = {x = targetVel.x + newRelVel.x, y = targetVel.y + newRelVel.y} -- 612
	local remainingSteps = math.max(1000, level.maxSteps - curIdx) -- 618
	local postBrakeSim = simulate({pos = curPos, vel = newVel}, level.bodies, { -- 619
		steps = remainingSteps, -- 623
		dt = core.dt, -- 624
		sampleEvery = 1, -- 625
		escapeRadius = level.escapeRadius, -- 626
		t0 = tNow -- 627
	}) -- 627
	local mergedPoints = __TS__ArraySlice(core.flight.points, 0, curIdx) -- 632
	do -- 632
		local i = 0 -- 633
		while i < #postBrakeSim.points do -- 633
			mergedPoints[#mergedPoints + 1] = postBrakeSim.points[i + 1] -- 634
			i = i + 1 -- 633
		end -- 633
	end -- 633
	local mergedVelocities = __TS__ArraySlice(core.flight.velocities or ({}), 0, curIdx) -- 636
	if postBrakeSim.velocities ~= nil then -- 636
		do -- 636
			local i = 0 -- 638
			while i < #postBrakeSim.velocities do -- 638
				mergedVelocities[#mergedVelocities + 1] = postBrakeSim.velocities[i + 1] -- 639
				i = i + 1 -- 638
			end -- 638
		end -- 638
	end -- 638
	core.flight = { -- 643
		outcome = postBrakeSim.outcome, -- 644
		points = mergedPoints, -- 645
		velocities = mergedVelocities, -- 646
		state = postBrakeSim.state, -- 647
		hitIndex = postBrakeSim.hitIndex, -- 648
		stepsRun = curIdx + postBrakeSim.stepsRun -- 649
	} -- 649
	core.hasBraked = true -- 652
	core.brakePointIndex = curIdx -- 653
	core.goalIndex = findGoalIndex( -- 656
		mergedPoints, -- 656
		level.bodies, -- 656
		level.goal, -- 656
		core.dt, -- 656
		core.t0, -- 656
		mergedVelocities -- 656
	) -- 656
	core.result = ____exports.resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal) -- 657
	print((((((((((("[escape-velocity] in-flight brake applied at t=" .. __TS__NumberToFixed(tNow, 2)) .. " curIdx=") .. __TS__NumberToFixed(curIdx, 0)) .. " relSpeed=") .. __TS__NumberToFixed(relSpeed, 3)) .. " -> ") .. __TS__NumberToFixed( -- 659
		math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y), -- 661
		3 -- 661
	)) .. " vCirc=") .. __TS__NumberToFixed(vCirc, 3)) .. " result=") .. core.result) -- 661
	return true -- 665
end -- 577
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 679
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 679
		return false -- 681
	end -- 681
	core.phase = "LevelSelect" -- 682
	core.viewMode = "2D" -- 684
	core.flight = nil -- 685
	core.flightTime = 0 -- 686
	core.goalIndex = -1 -- 687
	core.result = nil -- 688
	core.slowmo = false -- 689
	core.slowmoBody = -1 -- 690
	return true -- 691
end -- 679
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 720
	if core.phase ~= "Result" then -- 720
		return false -- 721
	end -- 721
	core.phase = "Finale" -- 722
	return true -- 723
end -- 720
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 741
	local dist = distance > 1 and distance or 1 -- 742
	local ux = probe.x -- 744
	local uy = probe.y -- 745
	local len = math.sqrt(ux * ux + uy * uy) -- 746
	if len < 0.000001 then -- 746
		ux = 0 -- 747
		uy = 1 -- 747
	else -- 747
		ux = ux / len -- 747
		uy = uy / len -- 747
	end -- 747
	local tilt = tiltDeg * math.pi / 180 -- 748
	local flat = math.cos(tilt) * dist -- 749
	return { -- 750
		target = Vec3(0, 0, 0), -- 752
		eye = Vec3( -- 753
			ux * flat * PlaneToWorldX, -- 753
			math.sin(tilt) * dist, -- 753
			uy * flat * PlaneToWorldZ -- 753
		) -- 753
	} -- 753
end -- 741
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 875
	local IntroTourDuration, introTourActive, introTourT -- 875
	local core = ____exports.createCore(level.physicsStep) -- 876
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 879
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 882
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
	local function applyView() -- 897
		local mode = core.viewMode -- 898
		if mode == appliedMode then -- 898
			return -- 899
		end -- 899
		appliedMode = mode -- 900
		local is2D = mode == "2D" -- 901
		deps.plan:setVisible(is2D) -- 902
		deps.trajectory.root.visible = not is2D -- 903
		deps:setWorldVisible(not is2D) -- 904
		deps.aim:setFullScreenAim(is2D) -- 905
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 906
	end -- 897
	local function finishIntroTour() -- 909
		if not introTourActive then -- 909
			return -- 910
		end -- 910
		introTourActive = false -- 911
		introTourT = IntroTourDuration -- 912
		core.viewMode = "2D" -- 913
		applyView() -- 914
		print("[escape-velocity] intro tour completed -> enter 2D") -- 915
	end -- 909
	local function makeBasis(frame) -- 918
		return prepareCamera({ -- 919
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 921
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 922
			up = {x = 0, y = 1, z = 0}, -- 923
			fovYDeg = deps.fovYDeg, -- 924
			aspect = deps.aspect, -- 925
			viewW = deps.viewW, -- 926
			viewH = deps.viewH -- 927
		}, HANDEDNESS, FLIP_Y) -- 927
	end -- 918
	local PredMinIntervalSec = 0.08 -- 939
	local predAimKey = "" -- 940
	local predPosKey = "" -- 941
	local predAccum = 1 -- 942
	local predForce = true -- 943
	local predPoints = {} -- 944
	IntroTourDuration = 3.2 -- 946
	introTourActive = false -- 947
	introTourT = IntroTourDuration -- 948
	local introLogged = false -- 949
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 951
	local clock = 0 -- 957
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 959
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 961
	local obsYawDeg = 0 -- 965
	local obsPitchDeg = 0 -- 966
	local obsZoom = 1 -- 967
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 969
	local idleOrbit = nil -- 971
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 982
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 984
	local lastSlowmoBody = -1 -- 985
	local flightLogT = 0 -- 986
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 988
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 989
	--- 进关 / 重新进关：把待机轨道的**解析模型**算出来。
	-- 
	-- 为什么必须是解析的（B1，2026-09-28）：待机轨是相对**宿主天体**（L1 = 地球）的圆轨，
	-- 而宿主自己在动 —— 地球在一个停泊周期（88.4 分钟）里沿日心轨道走
	-- `30 × 2.8145e-3 = 0.0844` 单位，是停泊轨半径（3.514e-3）的 **24 倍**。
	-- 旧实现把"惯性系里的一段轨迹"按点数取模循环播放，于是每绕一圈探测器就相对地球跳一次；
	-- 冻结时钟的时代（aimClockRate = 0）看不出来，时间一流动就现形。
	-- 现在写成「宿主位置 + 相对圆轨」：接缝天然连续，且就是真实二体圆轨
	-- （太阳潮汐在 L1 只是地球引力的 0.004%，忽略 —— 正是用户说的「能感受到就行」）。
	-- 
	-- ⚠️ 圆轨速度取的是**相对宿主**的速度，不是含地球公转的总速度（旧代码拿错了总速度，
	--    推出来的周期是错的）。
	local function prepareIdle() -- 1004
		clock = 0 -- 1006
		core.t0 = 0 -- 1007
		idleOrbit = nil -- 1008
		if level.probeVel0 == nil then -- 1008
			return -- 1009
		end -- 1009
		local hostIndex = -1 -- 1011
		local bestD = 1000000000 -- 1012
		do -- 1012
			local i = 0 -- 1013
			while i < #level.bodies do -- 1013
				do -- 1013
					local b = level.bodies[i + 1] -- 1014
					if b.gm <= 0 then -- 1014
						goto __continue89 -- 1015
					end -- 1015
					local d = distance( -- 1016
						bodyPositionAt(b, 0), -- 1016
						level.probeStart -- 1016
					) -- 1016
					if d < bestD then -- 1016
						bestD = d -- 1018
						hostIndex = i -- 1019
					end -- 1019
				end -- 1019
				::__continue89:: -- 1019
				i = i + 1 -- 1013
			end -- 1013
		end -- 1013
		if hostIndex < 0 or bestD < 1e-9 then -- 1013
			return -- 1022
		end -- 1022
		local host = level.bodies[hostIndex + 1] -- 1023
		local hp = bodyPositionAt(host, 0) -- 1024
		local hv = bodyVelocityAt(host, 0) -- 1025
		local rx = level.probeStart.x - hp.x -- 1027
		local ry = level.probeStart.y - hp.y -- 1028
		local vx = level.probeVel0.x - hv.x -- 1029
		local vy = level.probeVel0.y - hv.y -- 1030
		local r = math.sqrt(rx * rx + ry * ry) -- 1031
		if r < 1e-12 then -- 1031
			return -- 1032
		end -- 1032
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1034
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1035
		idleOrbit = { -- 1036
			hostIndex = hostIndex, -- 1036
			r = r, -- 1036
			phase0 = math.atan(ry, rx), -- 1036
			omega = dir * omega -- 1036
		} -- 1036
	end -- 1004
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1040
		if idleOrbit == nil then -- 1040
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1042
		end -- 1042
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1047
		local hp = bodyPositionAt(host, tWorld) -- 1048
		local hv = bodyVelocityAt(host, tWorld) -- 1049
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1050
		local ca = math.cos(a) -- 1051
		local sa = math.sin(a) -- 1052
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1053
	end -- 1040
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1070
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1071
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1074
		local wps = goalWaypoints(level.goal) -- 1075
		if #wps == 0 then -- 1075
			return nil -- 1076
		end -- 1076
		local passed = 0 -- 1077
		if core.flight ~= nil then -- 1077
			local upto = math.floor(core.flightTime / core.dt) -- 1079
			passed = waypointProgress( -- 1080
				core.flight.points, -- 1080
				level.bodies, -- 1080
				level.goal, -- 1080
				core.dt, -- 1080
				core.t0, -- 1080
				upto, -- 1080
				core.flight.velocities -- 1080
			).passed -- 1080
		end -- 1080
		if passed >= #wps then -- 1080
			return nil -- 1082
		end -- 1082
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1083
	end -- 1074
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1094
		local corePts = {probe} -- 1097
		local coreRadii = {deps.scene.probeRadius} -- 1098
		local next = nextStationBody() -- 1099
		local nextTol = 0 -- 1100
		if next ~= nil then -- 1100
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1102
			local wps = goalWaypoints(level.goal) -- 1103
			local passed = 0 -- 1104
			if core.flight ~= nil then -- 1104
				passed = waypointProgress( -- 1106
					core.flight.points, -- 1106
					level.bodies, -- 1106
					level.goal, -- 1106
					core.dt, -- 1106
					core.t0, -- 1106
					math.floor(core.flightTime / core.dt), -- 1106
					core.flight.velocities -- 1106
				).passed -- 1106
			end -- 1106
			if passed < #wps then -- 1106
				nextTol = wps[passed + 1].tolerance -- 1108
			end -- 1108
			local r = nextTol > next.radius and nextTol or next.radius -- 1109
			coreRadii[#coreRadii + 1] = r -- 1110
		end -- 1110
		if anchorDef == nil then -- 1110
			return {pts = corePts, radii = coreRadii} -- 1113
		end -- 1113
		local anchorR = anchorDef.radius -- 1118
		do -- 1118
			local i = 0 -- 1119
			while i < #level.bodies do -- 1119
				local b = level.bodies[i + 1] -- 1120
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1120
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1120
						anchorR = deps.visuals[i + 1].displayRadius -- 1122
					end -- 1122
					break -- 1123
				end -- 1123
				i = i + 1 -- 1119
			end -- 1119
		end -- 1119
		local withAnchorPts = { -- 1126
			probe, -- 1126
			bodyPositionAt(anchorDef, t) -- 1126
		} -- 1126
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1127
		do -- 1127
			local i = 1 -- 1128
			while i < #corePts do -- 1128
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1129
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1130
				i = i + 1 -- 1128
			end -- 1128
		end -- 1128
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1132
		if want <= CameraFramingBudget then -- 1132
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1133
		end -- 1133
		return {pts = corePts, radii = coreRadii} -- 1134
	end -- 1094
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1138
		local wps = goalWaypoints(level.goal) -- 1139
		if #wps == 0 then -- 1139
			return {} -- 1140
		end -- 1140
		local passed = 0 -- 1141
		if upto ~= nil and core.flight ~= nil then -- 1141
			passed = waypointProgress( -- 1143
				core.flight.points, -- 1143
				level.bodies, -- 1143
				level.goal, -- 1143
				core.dt, -- 1143
				core.t0, -- 1143
				upto, -- 1143
				core.flight.velocities -- 1143
			).passed -- 1143
		end -- 1143
		if passed >= #wps then -- 1143
			return {} -- 1148
		end -- 1148
		local nextWp = wps[passed + 1] -- 1149
		local body = level.bodies[nextWp.planetIndex + 1] -- 1150
		if body == nil then -- 1150
			return {} -- 1151
		end -- 1151
		return {{ -- 1152
			center = bodyPositionAt(body, t), -- 1152
			radius = nextWp.tolerance, -- 1152
			passed = false -- 1152
		}} -- 1152
	end -- 1138
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1156
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1156
			return f -- 1157
		end -- 1157
		local dx = f.eye.x - f.target.x -- 1158
		local dy = f.eye.y - f.target.y -- 1159
		local dz = f.eye.z - f.target.z -- 1160
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1161
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1162
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1163
		local lo = CameraTiltMin * math.pi / 180 -- 1164
		local hi = CameraTiltMax * math.pi / 180 -- 1165
		if pitch < lo then -- 1165
			pitch = lo -- 1166
		end -- 1166
		if pitch > hi then -- 1166
			pitch = hi -- 1167
		end -- 1167
		local cp = math.cos(pitch) -- 1168
		return { -- 1169
			target = f.target, -- 1170
			eye = Vec3( -- 1171
				f.target.x + r * cp * math.sin(yaw), -- 1172
				f.target.y + r * math.sin(pitch), -- 1173
				f.target.z + r * cp * math.cos(yaw) -- 1174
			) -- 1174
		} -- 1174
	end -- 1156
	local function updateAiming(dt) -- 1179
		deps.aim:setEnabled(true) -- 1180
		local dragging = deps.aim:isDragging() -- 1182
		if core.phase == "Aiming" and not dragging and idleOrbit ~= nil then -- 1182
			local aimRate = level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1 -- 1193
			clock = clock + dt * aimRate -- 1194
			orbitClock = orbitClock + dt * aimRate -- 1195
		end -- 1195
		local tNow = core.t0 + clock -- 1197
		local idleState = idleProbeAt(tNow) -- 1199
		probePos = idleState.pos -- 1200
		probeVel = idleState.vel -- 1201
		deps.scene.syncBodies(tNow) -- 1203
		deps.scene.syncProbe(probePos) -- 1204
		if idleOrbit ~= nil then -- 1204
			deps.scene.faceVelocity(probeVel) -- 1205
		end -- 1205
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1207
		deps.plan:syncProbe(probePos, probeVel) -- 1208
		local fr = framingPoints(probePos, tNow) -- 1211
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1212
		if frameLogged < 6 then -- 1212
			frameLogged = frameLogged + 1 -- 1216
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1217
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1221
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1222
				__TS__ArrayMap( -- 1228
					fr.pts, -- 1228
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1228
				), -- 1228
				" " -- 1228
			)) .. "]") -- 1228
		end -- 1228
		if introTourActive and introTourT < IntroTourDuration then -- 1228
			introTourT = introTourT + dt -- 1232
			local k = introTourT / IntroTourDuration -- 1233
			if k >= 1 then -- 1233
				finishIntroTour() -- 1235
			else -- 1235
				if k >= 0.95 and not introLogged then -- 1235
					introLogged = true -- 1238
					print("[escape-velocity] intro camera finishing") -- 1239
				end -- 1239
				local targetBody = nil -- 1241
				local wps = goalWaypoints(level.goal) -- 1242
				if #wps > 0 then -- 1242
					targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1244
				elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1244
					targetBody = level.bodies[level.goal.planetIndex + 1] -- 1246
				end -- 1246
				if targetBody == nil and #level.bodies > 0 then -- 1246
					targetBody = level.bodies[#level.bodies] -- 1249
				end -- 1249
				if targetBody ~= nil then -- 1249
					local pwTarget = planeToWorld( -- 1253
						bodyPositionAt(targetBody, tNow), -- 1253
						0 -- 1253
					) -- 1253
					local pwProbe = planeToWorld(probePos, 0) -- 1254
					local isMicroSystem = targetBody.orbitRadius < 2 -- 1255
					local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1256
					local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1257
					if k < 0.35 then -- 1257
						local e1 = k / 0.35 -- 1261
						local az = (0.2 + e1 * 0.15) * math.pi -- 1262
						local tilt = 0.35 * math.pi -- 1263
						local eye = Vec3( -- 1264
							pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1265
							pwTarget.y + math.sin(tilt) * distTarget, -- 1266
							pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1267
						) -- 1267
						frame = {target = pwTarget, eye = eye} -- 1269
					elseif k < 0.72 then -- 1269
						local e2 = (k - 0.35) / 0.37 -- 1272
						local ease2 = e2 * e2 * (3 - 2 * e2) -- 1273
						local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1274
						local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1275
						local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1276
						local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1277
						local eye = Vec3( -- 1282
							targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1283
							targetCenter.y + curDist * 0.8, -- 1284
							targetCenter.z + math.cos(az) * 0.5 * curDist -- 1285
						) -- 1285
						frame = {target = targetCenter, eye = eye} -- 1287
					else -- 1287
						local e3 = (k - 0.72) / 0.28 -- 1290
						local ease3 = 1 - (1 - e3) * (1 - e3) -- 1291
						local az = 0.25 * math.pi -- 1292
						local tilt = 0.36 * math.pi -- 1293
						local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1294
						local eye = Vec3( -- 1295
							pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1296
							pwProbe.y + math.sin(tilt) * curDist, -- 1297
							pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1298
						) -- 1298
						frame = {target = pwProbe, eye = eye} -- 1300
					end -- 1300
				end -- 1300
			end -- 1300
		end -- 1300
		frame = applyObserve(frame) -- 1306
		deps.rig.apply(deps.camera, frame) -- 1307
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1308
		local basis = makeBasis(frame) -- 1309
		if core.viewMode == "2D" then -- 1309
			local sp = deps.plan:probeScreen() -- 1315
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1316
		else -- 1316
			local pp = projectPrepared( -- 1318
				planeToWorld(probePos, 0), -- 1318
				basis -- 1318
			) -- 1318
			if pp ~= nil then -- 1318
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1319
			end -- 1319
		end -- 1319
		if not aimed then -- 1319
			deps.trajectory:clearPrediction() -- 1332
			deps.plan:clearPrediction() -- 1333
			predForce = true -- 1334
		else -- 1334
			local aimKey = (((__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4)) .. "|") .. (core.brakeMode and "B" or "C") -- 1340
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1341
			predAccum = predAccum + dt -- 1342
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1343
			if needIt then -- 1343
				predForce = false -- 1345
				predAccum = 0 -- 1346
				predAimKey = aimKey -- 1347
				predPosKey = posKey -- 1348
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1351
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1352
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1355
					dt = core.dt, -- 1355
					sampleEvery = 4, -- 1355
					escapeRadius = level.escapeRadius, -- 1355
					t0 = tNow, -- 1355
					brake = motion.brake -- 1355
				}).points -- 1355
			end -- 1355
			deps.trajectory:setPrediction(predPoints, basis) -- 1358
			deps.plan:setPrediction(predPoints) -- 1360
		end -- 1360
		local rings = goalRingsAt(tNow) -- 1362
		deps.trajectory:setGoalRings(rings, basis) -- 1363
		deps.trajectory:clearTrail() -- 1364
		deps.plan:setGoalRings(rings) -- 1366
		deps.plan:clearTrail() -- 1367
		deps.plan:flush() -- 1368
	end -- 1179
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
	local function updateFinale() -- 1383
		deps.aim:setEnabled(false) -- 1384
		if core.flight == nil then -- 1384
			return -- 1385
		end -- 1385
		local idx = ____exports.coreProbeIndex(core) -- 1386
		local pos = core.flight.points[idx + 1] -- 1387
		local tWorld = core.t0 + core.flightTime -- 1388
		deps.scene.syncBodies(tWorld) -- 1391
		deps.scene.syncProbe(pos) -- 1392
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1393
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1396
		deps.camera:lookAt( -- 1397
			frame.eye, -- 1397
			frame.target, -- 1397
			Vec3(0, 1, 0) -- 1397
		) -- 1397
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1398
		local trail = {} -- 1401
		do -- 1401
			local i = 0 -- 1402
			while i <= idx do -- 1402
				trail[#trail + 1] = core.flight.points[i + 1] -- 1402
				i = i + 1 -- 1402
			end -- 1402
		end -- 1402
		local rings = goalRingsAt(tWorld, idx) -- 1403
		local basis = makeBasis(frame) -- 1404
		deps.trajectory:setTrail(trail, basis) -- 1405
		deps.trajectory:setGoalRings(rings, basis) -- 1406
		deps.plan:clearPrediction() -- 1407
		deps.plan:setGoalRings(rings) -- 1408
		deps.plan:flush() -- 1409
	end -- 1383
	local function updateFlying(dt) -- 1411
		deps.aim:setEnabled(false) -- 1412
		local entered = ____exports.coreUpdate(core, dt, level) -- 1415
		if core.flight == nil then -- 1415
			return entered -- 1416
		end -- 1416
		local idx = ____exports.coreProbeIndex(core) -- 1418
		local pos = core.flight.points[idx + 1] -- 1419
		local tWorld = core.t0 + core.flightTime -- 1423
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1423
			lastSlowmo = core.slowmo -- 1427
			lastSlowmoBody = core.slowmoBody -- 1428
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1429
			local nearD = near ~= nil and distance( -- 1430
				pos, -- 1430
				bodyPositionAt(near, tWorld) -- 1430
			) or 0 -- 1430
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1431
		end -- 1431
		flightLogT = flightLogT + dt -- 1438
		if flightLogT >= 0.5 then -- 1438
			flightLogT = 0 -- 1440
			local total = (#core.flight.points - 1) * core.dt -- 1441
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1442
		end -- 1442
		deps.scene.syncBodies(tWorld) -- 1448
		deps.scene.syncProbe(pos) -- 1449
		if idx > 0 then -- 1449
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1451
		end -- 1451
		local fr -- 1458
		local closeDist = nil -- 1459
		if core.slowmo and core.slowmoBody >= 0 then -- 1459
			local near = level.bodies[core.slowmoBody + 1] -- 1461
			local nearR = near.radius -- 1463
			do -- 1463
				local i = 0 -- 1464
				while i < #level.bodies do -- 1464
					local b = level.bodies[i + 1] -- 1465
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1465
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1465
							nearR = deps.visuals[i + 1].displayRadius -- 1467
						end -- 1467
						break -- 1468
					end -- 1468
					i = i + 1 -- 1464
				end -- 1464
			end -- 1464
			fr = { -- 1471
				pts = { -- 1471
					pos, -- 1471
					bodyPositionAt(near, tWorld) -- 1471
				}, -- 1471
				radii = {deps.scene.probeRadius, nearR} -- 1471
			} -- 1471
			closeDist = SlowMoCloseDist -- 1472
		else -- 1472
			fr = framingPoints(pos, tWorld) -- 1474
		end -- 1474
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1476
		deps.rig.apply(deps.camera, frame) -- 1477
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1478
		local basis = makeBasis(frame) -- 1479
		local trail = {} -- 1482
		do -- 1482
			local i = 0 -- 1483
			while i <= idx do -- 1483
				trail[#trail + 1] = core.flight.points[i + 1] -- 1483
				i = i + 1 -- 1483
			end -- 1483
		end -- 1483
		local rings = goalRingsAt(tWorld, idx) -- 1484
		deps.trajectory:setTrail(trail, basis) -- 1485
		deps.trajectory:setGoalRings(rings, basis) -- 1486
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1489
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1490
		deps.plan:setTrail(trail) -- 1491
		deps.plan:clearPrediction() -- 1492
		deps.plan:setGoalRings(rings) -- 1493
		deps.plan:flush() -- 1494
		return entered -- 1496
	end -- 1411
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1510
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1511
		core.t0 = next.t0 -- 1512
		clock = next.clock -- 1513
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1514
	end -- 1510
	local function update(dt) -- 1517
		applyView() -- 1520
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1520
			updateAiming(dt) -- 1522
		elseif core.phase == "Flying" then -- 1522
			local entered = updateFlying(dt) -- 1524
			if entered and core.result ~= nil then -- 1524
				local toFinale = deps.finale == true and core.result == "success" -- 1527
				if toFinale then -- 1527
					____exports.coreEnterFinale(core) -- 1528
				end -- 1528
				local telem = ____exports.calcFlightTelemetry(core, level) -- 1530
				deps:onResult(core.result, telem) -- 1531
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1531
					local ____end = #core.flight.points - 1 -- 1533
					deps:onFinale({ -- 1534
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1535
						time = core.flightTime, -- 1536
						tWorld = core.t0 + core.flightTime -- 1537
					}) -- 1537
				end -- 1537
				deps:onPhase(toFinale and "Finale" or "Result") -- 1540
			end -- 1540
		elseif core.phase == "Finale" then -- 1540
			updateFinale() -- 1543
		end -- 1543
	end -- 1517
	return { -- 1548
		phase = function() return core.phase end, -- 1549
		result = function() return core.result end, -- 1550
		onAimDrag = function(____, a) -- 1551
			if introTourActive then -- 1551
				finishIntroTour() -- 1552
			end -- 1552
			core.aim = a -- 1553
			aimed = true -- 1554
		end, -- 1551
		aimReady = function() -- 1556
			predForce = true -- 1558
			if not ____exports.coreArm(core) then -- 1558
				return -- 1559
			end -- 1559
			applyView() -- 1560
			deps:onPhase("Armed") -- 1561
		end, -- 1556
		launchArmed = function() -- 1563
			if core.phase ~= "Armed" then -- 1563
				return -- 1565
			end -- 1565
			handoffDate(true) -- 1566
			____exports.coreLaunch( -- 1567
				core, -- 1567
				core.aim.velocity, -- 1567
				level, -- 1567
				probePos, -- 1567
				probeVel -- 1567
			) -- 1567
			deps.trajectory:clearPrediction() -- 1568
			deps.plan:clearPrediction() -- 1569
			applyView() -- 1570
			deps:onPhase("Flying") -- 1571
		end, -- 1563
		armed = function() return core.phase == "Armed" end, -- 1573
		viewMode = function() return core.viewMode end, -- 1574
		toggleViewMode = function() -- 1575
			____exports.coreToggleView(core) -- 1577
			applyView() -- 1578
		end, -- 1575
		skipIntroTour = function() -- 1580
			finishIntroTour() -- 1581
		end, -- 1580
		isIntroTourActive = function() return introTourActive end, -- 1583
		observeDrag = function(____, dx, dy) -- 1584
			if introTourActive then -- 1584
				finishIntroTour() -- 1586
				return -- 1587
			end -- 1587
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1589
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1590
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1591
			if obsPitchDeg > 40 then -- 1591
				obsPitchDeg = 40 -- 1592
			end -- 1592
			if obsPitchDeg < -40 then -- 1592
				obsPitchDeg = -40 -- 1593
			end -- 1593
		end, -- 1584
		observeZoom = function(____, deltaDist) -- 1595
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1596
			if obsZoom < 0.4 then -- 1596
				obsZoom = 0.4 -- 1597
			end -- 1597
			if obsZoom > 1.8 then -- 1597
				obsZoom = 1.8 -- 1598
			end -- 1598
		end, -- 1595
		launch = function(____, v) -- 1600
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1600
				return -- 1601
			end -- 1601
			handoffDate(true) -- 1602
			____exports.coreLaunch( -- 1604
				core, -- 1604
				v, -- 1604
				level, -- 1604
				probePos, -- 1604
				probeVel -- 1604
			) -- 1604
			deps.trajectory:clearPrediction() -- 1605
			deps.plan:clearPrediction() -- 1606
			applyView() -- 1607
			deps:onPhase("Flying") -- 1608
		end, -- 1600
		retry = function() -- 1610
			if core.phase ~= "Result" then -- 1610
				return -- 1611
			end -- 1611
			handoffDate(false) -- 1612
			aimed = false -- 1613
			introTourActive = false -- 1614
			____exports.coreRetry(core, level.aimMin) -- 1615
			deps.trajectory:clearTrail() -- 1616
			deps.trajectory:clearPrediction() -- 1617
			deps.trajectory:clearGoalRings() -- 1618
			deps.plan:clearTrail() -- 1619
			deps.plan:clearPrediction() -- 1620
			deps.plan:clearGoalRings() -- 1621
			applyView() -- 1622
			deps:onPhase("Aiming") -- 1623
		end, -- 1610
		backToSelect = function() -- 1625
			if not ____exports.coreBackToSelect(core) then -- 1625
				return false -- 1626
			end -- 1626
			deps.aim:setEnabled(false) -- 1628
			deps.trajectory:clearTrail() -- 1629
			deps.trajectory:clearPrediction() -- 1630
			deps.trajectory:clearGoalRings() -- 1631
			deps.plan:clearTrail() -- 1632
			deps.plan:clearPrediction() -- 1633
			deps.plan:clearGoalRings() -- 1634
			applyView() -- 1635
			deps:onPhase("LevelSelect") -- 1636
			return true -- 1637
		end, -- 1625
		startLevel = function() -- 1639
			aimed = false -- 1640
			____exports.coreRetry(core, level.aimMin) -- 1641
			deps.rig.reset() -- 1642
			introTourActive = true -- 1644
			introTourT = 0 -- 1645
			introLogged = false -- 1646
			core.viewMode = "3D" -- 1647
			appliedMode = "" -- 1648
			applyView() -- 1649
			prepareIdle() -- 1650
			deps.trajectory:clearTrail() -- 1651
			deps.trajectory:clearPrediction() -- 1652
			deps.trajectory:clearGoalRings() -- 1653
			deps.plan:clearTrail() -- 1654
			deps.plan:clearPrediction() -- 1655
			deps.plan:clearGoalRings() -- 1656
			deps:onPhase("Aiming") -- 1657
		end, -- 1639
		stepTime = function(____, dir, span) -- 1659
			if not ____exports.coreTimeWarpAllowed(core) then -- 1659
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1663
				return -- 1664
			end -- 1664
			local span0 = span > 0 and span or 0 -- 1666
			clock = clock + dir * TimeWarpStep -- 1667
			if clock < 0 then -- 1667
				clock = 0 -- 1668
			end -- 1668
			if span0 > 0 and clock > span0 then -- 1668
				clock = span0 -- 1669
			end -- 1669
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1671
		end, -- 1659
		dateNow = function() return core.t0 + clock end, -- 1673
		setBrakeMode = function(____, on) -- 1674
			core.brakeMode = on -- 1675
		end, -- 1674
		brakeMode = function() return core.brakeMode end, -- 1678
		setPlaybackSpeed = function(____, speed) -- 1679
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1679
				return -- 1681
			end -- 1681
			core.playback = speed -- 1682
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1683
		end, -- 1679
		playbackSpeed = function() return core.playback end, -- 1685
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1686
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 1687
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 1688
		hasBraked = function() return core.hasBraked end, -- 1689
		update = function(____, frameDt) return update(frameDt) end -- 1691
	} -- 1691
end -- 875
return ____exports -- 875
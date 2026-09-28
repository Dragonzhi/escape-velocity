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
local function neutralAim(minSpeed) -- 177
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 178
end -- 177
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 182
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 183
end -- 182
function ____exports.createCore(dt) -- 186
	return { -- 187
		phase = "Aiming", -- 188
		aim = neutralAim(AimMinSpeed), -- 189
		flight = nil, -- 190
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 191
		brakeMode = false, -- 192
		t0 = 0, -- 193
		flightTime = 0, -- 194
		goalIndex = -1, -- 195
		result = nil, -- 196
		viewMode = "2D", -- 198
		playback = FlightPlayback, -- 200
		slowmo = false, -- 201
		slowmoBody = -1, -- 202
		hasBraked = false, -- 203
		brakePointIndex = -1 -- 204
	} -- 204
end -- 186
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 216
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 217
	return core.viewMode -- 218
end -- 216
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 236
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 242
	local share = brakeMode and BrakeShare or 1 -- 243
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 244
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 245
	local brake = brakeMode and mag > 0 and ({ -- 246
		dv = mag * (1 - share), -- 247
		startStep = math.floor(maxSteps / 2) -- 247
	}) or nil -- 247
	return {init = init, brake = brake} -- 249
end -- 236
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 258
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 258
		return -- 260
	end -- 260
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 261
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 262
	local p0 = from ~= nil and from or level.probeStart -- 263
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 264
		steps = level.maxSteps, -- 267
		dt = core.dt, -- 267
		sampleEvery = 1, -- 267
		escapeRadius = level.escapeRadius, -- 267
		t0 = core.t0, -- 267
		brake = motion.brake -- 267
	}) -- 267
	core.flight = flight -- 269
	core.goalIndex = findGoalIndex( -- 270
		flight.points, -- 270
		level.bodies, -- 270
		level.goal, -- 270
		core.dt, -- 270
		core.t0, -- 270
		flight.velocities -- 270
	) -- 270
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 271
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 274
	core.flightTime = 0 -- 279
	core.slowmo = false -- 281
	core.slowmoBody = -1 -- 282
	core.hasBraked = false -- 283
	core.brakePointIndex = -1 -- 284
	core.phase = "Flying" -- 285
	core.viewMode = "3D" -- 287
end -- 258
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 296
	if core.phase ~= "Aiming" then -- 296
		return false -- 297
	end -- 297
	core.phase = "Armed" -- 298
	return true -- 299
end -- 296
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 303
	if core.phase ~= "Armed" then -- 303
		return false -- 304
	end -- 304
	core.phase = "Aiming" -- 305
	return true -- 306
end -- 303
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 320
	return core.phase == "Aiming" or core.phase == "Armed" -- 321
end -- 320
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 337
	if toT0 then -- 337
		return {t0 = clock, clock = 0} -- 338
	end -- 338
	return {t0 = 0, clock = t0} -- 339
end -- 337
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 351
	local host = -1 -- 361
	do -- 361
		local i = 0 -- 362
		while i < #bodies do -- 362
			do -- 362
				local b = bodies[i + 1] -- 363
				local isHost = false -- 364
				do -- 364
					local j = 0 -- 365
					while j < #bodies do -- 365
						do -- 365
							local h = bodies[j + 1].host -- 366
							if h == nil then -- 366
								goto __continue25 -- 367
							end -- 367
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 367
								isHost = true -- 368
								break -- 368
							end -- 368
						end -- 368
						::__continue25:: -- 368
						j = j + 1 -- 365
					end -- 365
				end -- 365
				if not isHost then -- 365
					goto __continue23 -- 370
				end -- 370
				if host < 0 or b.gm > bodies[host + 1].gm then -- 370
					host = i -- 371
				end -- 371
			end -- 371
			::__continue23:: -- 371
			i = i + 1 -- 362
		end -- 362
	end -- 362
	if host >= 0 then -- 362
		return host -- 373
	end -- 373
	local best = -1 -- 375
	do -- 375
		local i = 0 -- 376
		while i < #bodies do -- 376
			do -- 376
				local b = bodies[i + 1] -- 377
				if b.orbitRadius ~= 0 then -- 377
					goto __continue32 -- 378
				end -- 378
				if best < 0 or b.gm > bodies[best + 1].gm then -- 378
					best = i -- 379
				end -- 379
			end -- 379
			::__continue32:: -- 379
			i = i + 1 -- 376
		end -- 376
	end -- 376
	return best -- 381
end -- 351
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 399
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 400
	local best = -1 -- 401
	local bestD = 1000000000 -- 402
	do -- 402
		local i = 0 -- 403
		while i < #bodies do -- 403
			do -- 403
				if i == anchor then -- 403
					goto __continue37 -- 404
				end -- 404
				local b = bodies[i + 1] -- 405
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 406
				local d = distance( -- 407
					probe, -- 407
					bodyPositionAt(b, t) -- 407
				) -- 407
				if d < threshold and d < bestD then -- 407
					bestD = d -- 409
					best = i -- 410
				end -- 410
			end -- 410
			::__continue37:: -- 410
			i = i + 1 -- 403
		end -- 403
	end -- 403
	return best -- 413
end -- 399
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 417
	if core.flight == nil then -- 417
		return 0 -- 418
	end -- 418
	local idx = math.floor(core.flightTime / core.dt) -- 419
	local last = #core.flight.points - 1 -- 420
	if idx > last then -- 420
		idx = last -- 421
	end -- 421
	if idx < 0 then -- 421
		idx = 0 -- 422
	end -- 422
	return idx -- 423
end -- 417
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
function ____exports.coreUpdate(core, dt, level) -- 440
	if core.phase ~= "Flying" or core.flight == nil then -- 440
		return false -- 441
	end -- 441
	if level ~= nil then -- 441
		local idx = ____exports.coreProbeIndex(core) -- 445
		core.slowmoBody = ____exports.slowMotionBody( -- 446
			level.bodies, -- 446
			core.flight.points[idx + 1], -- 446
			core.t0 + core.flightTime, -- 446
			____exports.anchorBodyIndex(level.bodies), -- 446
			level.slowMoFloor -- 446
		) -- 446
		core.slowmo = core.slowmoBody >= 0 -- 447
	end -- 447
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 450
	core.flightTime = core.flightTime + dt * speed -- 451
	local naturalEnd = #core.flight.points - 1 -- 452
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 453
	if ____exports.coreProbeIndex(core) >= endIdx then -- 453
		core.flightTime = endIdx * core.dt -- 456
		core.phase = "Result" -- 457
		return true -- 458
	end -- 458
	return false -- 460
end -- 440
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 466
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 470
	local maxSpeed = 0 -- 471
	local closestDist = 1000000000 -- 472
	local eccentricity = nil -- 473
	if core.flight ~= nil then -- 473
		local pts = core.flight.points -- 476
		local vels = core.flight.velocities -- 477
		local ____end = ____exports.coreProbeIndex(core) -- 478
		local targetIdx = level.goal.planetIndex -- 479
		local targetBody = targetIdx >= 0 and targetIdx < #level.bodies and level.bodies[targetIdx + 1] or nil -- 480
		do -- 480
			local k = 0 -- 482
			while k <= ____end and k < #pts do -- 482
				local p = pts[k + 1] -- 483
				if vels ~= nil and k < #vels then -- 483
					local v = vels[k + 1] -- 485
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 486
					if spd > maxSpeed then -- 486
						maxSpeed = spd -- 487
					end -- 487
				end -- 487
				if targetBody ~= nil then -- 487
					local t = core.t0 + k * core.dt -- 490
					local tp = bodyPositionAt(targetBody, t) -- 491
					local d = distance(p, tp) -- 492
					if d < closestDist then -- 492
						closestDist = d -- 493
					end -- 493
				end -- 493
				k = k + 1 -- 482
			end -- 482
		end -- 482
		if targetBody ~= nil and targetBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 482
			local tEnd = core.t0 + ____end * core.dt -- 498
			local tpEnd = bodyPositionAt(targetBody, tEnd) -- 499
			local tvEnd = bodyVelocityAt(targetBody, tEnd) -- 500
			local rx = pts[____end + 1].x - tpEnd.x -- 501
			local ry = pts[____end + 1].y - tpEnd.y -- 502
			local vx = vels[____end + 1].x - tvEnd.x -- 503
			local vy = vels[____end + 1].y - tvEnd.y -- 504
			local r = math.sqrt(rx * rx + ry * ry) -- 505
			local v2 = vx * vx + vy * vy -- 506
			local mu = targetBody.gm -- 507
			if r > 0 and mu > 0 then -- 507
				local energy = v2 / 2 - mu / r -- 509
				local h = rx * vy - ry * vx -- 510
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 511
				if term >= 0 then -- 511
					eccentricity = math.sqrt(term) -- 513
				end -- 513
			end -- 513
		end -- 513
	end -- 513
	return { -- 519
		burnDv = burnDv, -- 520
		flightTime = core.flightTime, -- 521
		closestDist = closestDist < 100000000 and closestDist or 0, -- 522
		maxSpeed = maxSpeed, -- 523
		eccentricity = eccentricity -- 524
	} -- 524
end -- 466
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 529
	core.phase = "Aiming" -- 530
	core.viewMode = "2D" -- 532
	core.flight = nil -- 533
	core.flightTime = 0 -- 534
	core.goalIndex = -1 -- 535
	core.result = nil -- 536
	core.slowmo = false -- 537
	core.slowmoBody = -1 -- 538
	core.hasBraked = false -- 539
	core.brakePointIndex = -1 -- 540
	core.aim = neutralAim(levelAimMin(aimMin)) -- 541
end -- 529
--- 判定当前飞行状态下是否处于可逆喷制动窗口。
-- 纯函数，可单测。
function ____exports.isBrakeWindowActive(core, level) -- 548
	if core.phase ~= "Flying" or core.flight == nil or core.hasBraked then -- 548
		return false -- 549
	end -- 549
	local curIdx = ____exports.coreProbeIndex(core) -- 550
	local pts = core.flight.points -- 551
	if curIdx < 0 or curIdx >= #pts then -- 551
		return false -- 552
	end -- 552
	local targetIdx = level.goal.planetIndex -- 554
	if targetIdx < 0 or targetIdx >= #level.bodies then -- 554
		return false -- 555
	end -- 555
	local targetBody = level.bodies[targetIdx + 1] -- 556
	local tNow = core.t0 + core.flightTime -- 557
	local targetPos = bodyPositionAt(targetBody, tNow) -- 558
	local dist = distance(pts[curIdx + 1], targetPos) -- 559
	local floorD = level.slowMoFloor ~= nil and level.slowMoFloor > 0 and level.slowMoFloor or SlowMoFloorDist -- 562
	local brakeDistLimit = math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD) -- 563
	return dist <= brakeDistLimit and dist > targetBody.radius -- 564
end -- 548
--- 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
-- 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
-- 返回 true 表示制动成功应用。
function ____exports.applyInFlightBrake(core, level) -- 572
	if not ____exports.isBrakeWindowActive(core, level) then -- 572
		return false -- 573
	end -- 573
	if core.flight == nil then -- 573
		return false -- 574
	end -- 574
	local curIdx = ____exports.coreProbeIndex(core) -- 576
	local curPos = core.flight.points[curIdx + 1] -- 577
	local curVel = core.flight.velocities ~= nil and curIdx < #core.flight.velocities and core.flight.velocities[curIdx + 1] or ({x = 0, y = 0}) -- 578
	local tNow = core.t0 + core.flightTime -- 581
	local targetIdx = level.goal.planetIndex -- 583
	local targetBody = level.bodies[targetIdx + 1] -- 584
	local targetPos = bodyPositionAt(targetBody, tNow) -- 585
	local targetVel = bodyVelocityAt(targetBody, tNow) -- 586
	local relVel = {x = curVel.x - targetVel.x, y = curVel.y - targetVel.y} -- 589
	local relSpeed = math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y) -- 590
	local dist = distance(curPos, targetPos) -- 591
	if relSpeed <= 0.000001 or dist <= 0.000001 then -- 591
		return false -- 593
	end -- 593
	local vCirc = math.sqrt(targetBody.gm / dist) -- 596
	local targetRelSpeed = vCirc * 0.98 -- 599
	local reductionFactor = targetRelSpeed / relSpeed -- 600
	local clampedFactor = math.min(0.95, reductionFactor) -- 601
	local newRelVel = {x = relVel.x * clampedFactor, y = relVel.y * clampedFactor} -- 603
	local newVel = {x = targetVel.x + newRelVel.x, y = targetVel.y + newRelVel.y} -- 607
	local remainingSteps = math.max(1000, level.maxSteps - curIdx) -- 613
	local postBrakeSim = simulate({pos = curPos, vel = newVel}, level.bodies, { -- 614
		steps = remainingSteps, -- 618
		dt = core.dt, -- 619
		sampleEvery = 1, -- 620
		escapeRadius = level.escapeRadius, -- 621
		t0 = tNow -- 622
	}) -- 622
	local mergedPoints = __TS__ArraySlice(core.flight.points, 0, curIdx) -- 627
	do -- 627
		local i = 0 -- 628
		while i < #postBrakeSim.points do -- 628
			mergedPoints[#mergedPoints + 1] = postBrakeSim.points[i + 1] -- 629
			i = i + 1 -- 628
		end -- 628
	end -- 628
	local mergedVelocities = __TS__ArraySlice(core.flight.velocities or ({}), 0, curIdx) -- 631
	if postBrakeSim.velocities ~= nil then -- 631
		do -- 631
			local i = 0 -- 633
			while i < #postBrakeSim.velocities do -- 633
				mergedVelocities[#mergedVelocities + 1] = postBrakeSim.velocities[i + 1] -- 634
				i = i + 1 -- 633
			end -- 633
		end -- 633
	end -- 633
	core.flight = { -- 638
		outcome = postBrakeSim.outcome, -- 639
		points = mergedPoints, -- 640
		velocities = mergedVelocities, -- 641
		state = postBrakeSim.state, -- 642
		hitIndex = postBrakeSim.hitIndex, -- 643
		stepsRun = curIdx + postBrakeSim.stepsRun -- 644
	} -- 644
	core.hasBraked = true -- 647
	core.brakePointIndex = curIdx -- 648
	core.goalIndex = findGoalIndex( -- 651
		mergedPoints, -- 651
		level.bodies, -- 651
		level.goal, -- 651
		core.dt, -- 651
		core.t0, -- 651
		mergedVelocities -- 651
	) -- 651
	core.result = ____exports.resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal) -- 652
	print((((((((((("[escape-velocity] in-flight brake applied at t=" .. __TS__NumberToFixed(tNow, 2)) .. " curIdx=") .. __TS__NumberToFixed(curIdx, 0)) .. " relSpeed=") .. __TS__NumberToFixed(relSpeed, 3)) .. " -> ") .. __TS__NumberToFixed( -- 654
		math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y), -- 656
		3 -- 656
	)) .. " vCirc=") .. __TS__NumberToFixed(vCirc, 3)) .. " result=") .. core.result) -- 656
	return true -- 660
end -- 572
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 674
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 674
		return false -- 676
	end -- 676
	core.phase = "LevelSelect" -- 677
	core.viewMode = "2D" -- 679
	core.flight = nil -- 680
	core.flightTime = 0 -- 681
	core.goalIndex = -1 -- 682
	core.result = nil -- 683
	core.slowmo = false -- 684
	core.slowmoBody = -1 -- 685
	return true -- 686
end -- 674
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 715
	if core.phase ~= "Result" then -- 715
		return false -- 716
	end -- 716
	core.phase = "Finale" -- 717
	return true -- 718
end -- 715
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 736
	local dist = distance > 1 and distance or 1 -- 737
	local ux = probe.x -- 739
	local uy = probe.y -- 740
	local len = math.sqrt(ux * ux + uy * uy) -- 741
	if len < 0.000001 then -- 741
		ux = 0 -- 742
		uy = 1 -- 742
	else -- 742
		ux = ux / len -- 742
		uy = uy / len -- 742
	end -- 742
	local tilt = tiltDeg * math.pi / 180 -- 743
	local flat = math.cos(tilt) * dist -- 744
	return { -- 745
		target = Vec3(0, 0, 0), -- 747
		eye = Vec3( -- 748
			ux * flat * PlaneToWorldX, -- 748
			math.sin(tilt) * dist, -- 748
			uy * flat * PlaneToWorldZ -- 748
		) -- 748
	} -- 748
end -- 736
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 866
	local core = ____exports.createCore(level.physicsStep) -- 867
	core.playback = level.playback ~= nil and level.playback > 0 and level.playback or FlightPlayback -- 870
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 873
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
	local function applyView() -- 888
		local mode = core.viewMode -- 889
		if mode == appliedMode then -- 889
			return -- 890
		end -- 890
		appliedMode = mode -- 891
		local is2D = mode == "2D" -- 892
		deps.plan:setVisible(is2D) -- 893
		deps.trajectory.root.visible = not is2D -- 894
		deps:setWorldVisible(not is2D) -- 895
		deps.aim:setFullScreenAim(is2D) -- 896
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 897
	end -- 888
	local function makeBasis(frame) -- 900
		return prepareCamera({ -- 901
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 903
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 904
			up = {x = 0, y = 1, z = 0}, -- 905
			fovYDeg = deps.fovYDeg, -- 906
			aspect = deps.aspect, -- 907
			viewW = deps.viewW, -- 908
			viewH = deps.viewH -- 909
		}, HANDEDNESS, FLIP_Y) -- 909
	end -- 900
	local predKey = "" -- 918
	local predPoints = {} -- 919
	local introT = IntroDurationSec -- 921
	local introLogged = false -- 922
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 924
	local clock = 0 -- 930
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 932
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 934
	local obsYawDeg = 0 -- 938
	local obsPitchDeg = 0 -- 939
	local obsZoom = 1 -- 940
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 942
	local idlePath = nil -- 943
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 954
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 956
	local lastSlowmoBody = -1 -- 957
	local flightLogT = 0 -- 958
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 960
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 961
	local function prepareIdle() -- 962
		clock = 0 -- 964
		core.t0 = 0 -- 965
		if level.probeVel0 == nil then -- 965
			idlePath = nil -- 967
			return -- 968
		end -- 968
		local idleSteps = level.maxSteps -- 976
		local v0x = level.probeVel0.x -- 977
		local v0y = level.probeVel0.y -- 978
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 979
		if v0 > 0.000001 then -- 979
			local bestD = 1000000000 -- 981
			for ____, b in ipairs(level.bodies) do -- 982
				do -- 982
					if b.gm <= 0 then -- 982
						goto __continue87 -- 983
					end -- 983
					local dx = b.orbitCenter.x - level.probeStart.x -- 984
					local dy = b.orbitCenter.y - level.probeStart.y -- 985
					local d = math.sqrt(dx * dx + dy * dy) -- 986
					if d < bestD then -- 986
						bestD = d -- 987
					end -- 987
				end -- 987
				::__continue87:: -- 987
			end -- 987
			if bestD > 0.000001 and bestD < 100000000 then -- 987
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 990
				if n > 60 and n < 40000 then -- 990
					idleSteps = n -- 991
				end -- 991
			end -- 991
		end -- 991
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 994
			steps = idleSteps, -- 997
			dt = core.dt, -- 997
			sampleEvery = 1, -- 997
			escapeRadius = level.escapeRadius, -- 997
			t0 = core.t0 -- 997
		}) -- 997
	end -- 962
	local function idleIndex() -- 1000
		if idlePath == nil then -- 1000
			return 0 -- 1001
		end -- 1001
		local n = #idlePath.points -- 1002
		if n <= 1 then -- 1002
			return 0 -- 1003
		end -- 1003
		local i = math.floor(orbitClock / core.dt) % n -- 1004
		if i < 0 then -- 1004
			i = 0 -- 1005
		end -- 1005
		return i -- 1006
	end -- 1000
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1019
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1020
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1023
		local wps = goalWaypoints(level.goal) -- 1024
		if #wps == 0 then -- 1024
			return nil -- 1025
		end -- 1025
		local passed = 0 -- 1026
		if core.flight ~= nil then -- 1026
			local upto = math.floor(core.flightTime / core.dt) -- 1028
			passed = waypointProgress( -- 1029
				core.flight.points, -- 1029
				level.bodies, -- 1029
				level.goal, -- 1029
				core.dt, -- 1029
				core.t0, -- 1029
				upto, -- 1029
				core.flight.velocities -- 1029
			).passed -- 1029
		end -- 1029
		if passed >= #wps then -- 1029
			return nil -- 1031
		end -- 1031
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1032
	end -- 1023
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1043
		local corePts = {probe} -- 1046
		local coreRadii = {deps.scene.probeRadius} -- 1047
		local next = nextStationBody() -- 1048
		local nextTol = 0 -- 1049
		if next ~= nil then -- 1049
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1051
			local wps = goalWaypoints(level.goal) -- 1052
			local passed = 0 -- 1053
			if core.flight ~= nil then -- 1053
				passed = waypointProgress( -- 1055
					core.flight.points, -- 1055
					level.bodies, -- 1055
					level.goal, -- 1055
					core.dt, -- 1055
					core.t0, -- 1055
					math.floor(core.flightTime / core.dt), -- 1055
					core.flight.velocities -- 1055
				).passed -- 1055
			end -- 1055
			if passed < #wps then -- 1055
				nextTol = wps[passed + 1].tolerance -- 1057
			end -- 1057
			local r = nextTol > next.radius and nextTol or next.radius -- 1058
			coreRadii[#coreRadii + 1] = r -- 1059
		end -- 1059
		if anchorDef == nil then -- 1059
			return {pts = corePts, radii = coreRadii} -- 1062
		end -- 1062
		local anchorR = anchorDef.radius -- 1067
		do -- 1067
			local i = 0 -- 1068
			while i < #level.bodies do -- 1068
				local b = level.bodies[i + 1] -- 1069
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1069
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1069
						anchorR = deps.visuals[i + 1].displayRadius -- 1071
					end -- 1071
					break -- 1072
				end -- 1072
				i = i + 1 -- 1068
			end -- 1068
		end -- 1068
		local withAnchorPts = { -- 1075
			probe, -- 1075
			bodyPositionAt(anchorDef, t) -- 1075
		} -- 1075
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1076
		do -- 1076
			local i = 1 -- 1077
			while i < #corePts do -- 1077
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1078
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1079
				i = i + 1 -- 1077
			end -- 1077
		end -- 1077
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1081
		if want <= CameraFramingBudget then -- 1081
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1082
		end -- 1082
		return {pts = corePts, radii = coreRadii} -- 1083
	end -- 1043
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1087
		local wps = goalWaypoints(level.goal) -- 1088
		if #wps == 0 then -- 1088
			return {} -- 1089
		end -- 1089
		local passed = 0 -- 1090
		if upto ~= nil and core.flight ~= nil then -- 1090
			passed = waypointProgress( -- 1092
				core.flight.points, -- 1092
				level.bodies, -- 1092
				level.goal, -- 1092
				core.dt, -- 1092
				core.t0, -- 1092
				upto, -- 1092
				core.flight.velocities -- 1092
			).passed -- 1092
		end -- 1092
		if passed >= #wps then -- 1092
			return {} -- 1097
		end -- 1097
		local nextWp = wps[passed + 1] -- 1098
		local body = level.bodies[nextWp.planetIndex + 1] -- 1099
		if body == nil then -- 1099
			return {} -- 1100
		end -- 1100
		return {{ -- 1101
			center = bodyPositionAt(body, t), -- 1101
			radius = nextWp.tolerance, -- 1101
			passed = false -- 1101
		}} -- 1101
	end -- 1087
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1105
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1105
			return f -- 1106
		end -- 1106
		local dx = f.eye.x - f.target.x -- 1107
		local dy = f.eye.y - f.target.y -- 1108
		local dz = f.eye.z - f.target.z -- 1109
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1110
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1111
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1112
		local lo = CameraTiltMin * math.pi / 180 -- 1113
		local hi = CameraTiltMax * math.pi / 180 -- 1114
		if pitch < lo then -- 1114
			pitch = lo -- 1115
		end -- 1115
		if pitch > hi then -- 1115
			pitch = hi -- 1116
		end -- 1116
		local cp = math.cos(pitch) -- 1117
		return { -- 1118
			target = f.target, -- 1119
			eye = Vec3( -- 1120
				f.target.x + r * cp * math.sin(yaw), -- 1121
				f.target.y + r * math.sin(pitch), -- 1122
				f.target.z + r * cp * math.cos(yaw) -- 1123
			) -- 1123
		} -- 1123
	end -- 1105
	local function updateAiming(dt) -- 1128
		deps.aim:setEnabled(true) -- 1129
		local dragging = deps.aim:isDragging() -- 1131
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 1131
			local aimRate = level.aimClockRate ~= nil and level.aimClockRate >= 0 and level.aimClockRate or 1 -- 1142
			clock = clock + dt * aimRate -- 1143
			orbitClock = orbitClock + dt * aimRate -- 1144
		end -- 1144
		local idx = idleIndex() -- 1146
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 1147
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 1148
		local tNow = core.t0 + clock -- 1151
		deps.scene.syncBodies(tNow) -- 1153
		deps.scene.syncProbe(probePos) -- 1154
		if idlePath ~= nil and idx > 0 then -- 1154
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 1155
		end -- 1155
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1157
		deps.plan:syncProbe(probePos, probeVel) -- 1158
		local fr = framingPoints(probePos, tNow) -- 1161
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1162
		if frameLogged < 6 then -- 1162
			frameLogged = frameLogged + 1 -- 1166
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1167
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1171
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1172
				__TS__ArrayMap( -- 1178
					fr.pts, -- 1178
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1178
				), -- 1178
				" " -- 1178
			)) .. "]") -- 1178
		end -- 1178
		if introT < IntroDurationSec then -- 1178
			introT = introT + dt -- 1183
			local k = introT / IntroDurationSec -- 1184
			if k > 1 then -- 1184
				k = 1 -- 1185
			end -- 1185
			if k >= 1 and not introLogged then -- 1185
				introLogged = true -- 1187
				print("[escape-velocity] intro camera done") -- 1188
			end -- 1188
			local wps0 = goalWaypoints(level.goal) -- 1190
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 1191
			local wide = frame -- 1192
			local from = wide -- 1193
			local to = wide -- 1194
			local e = 0 -- 1195
			if k < 0.35 then -- 1195
				local pw = planeToWorld(probePos, 0) -- 1197
				local dx = wide.eye.x - wide.target.x -- 1198
				local dy = wide.eye.y - wide.target.y -- 1199
				local dz = wide.eye.z - wide.target.z -- 1200
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1201
				if len > 0.000001 then -- 1201
					local s = IntroCloseDist / len -- 1203
					dx = dx * s -- 1204
					dy = dy * s -- 1204
					dz = dz * s -- 1204
				end -- 1204
				from = { -- 1206
					target = Vec3(pw.x, pw.y, pw.z), -- 1206
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 1206
				} -- 1206
				e = k / 0.35 -- 1207
			elseif k < 0.72 and wpBody ~= nil then -- 1207
				local c = planeToWorld( -- 1210
					bodyPositionAt(wpBody, tNow), -- 1210
					0 -- 1210
				) -- 1210
				local dx = wide.eye.x - wide.target.x -- 1211
				local dy = wide.eye.y - wide.target.y -- 1212
				local dz = wide.eye.z - wide.target.z -- 1213
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1214
				local want = math.max(24, wpBody.radius * 6) -- 1215
				if len > 0.000001 then -- 1215
					local s = want / len -- 1217
					dx = dx * s -- 1218
					dy = dy * s -- 1218
					dz = dz * s -- 1218
				end -- 1218
				to = { -- 1220
					target = Vec3(c.x, c.y, c.z), -- 1220
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1220
				} -- 1220
				e = (k - 0.35) / 0.37 -- 1221
			elseif wpBody ~= nil then -- 1221
				local c = planeToWorld( -- 1224
					bodyPositionAt(wpBody, tNow), -- 1224
					0 -- 1224
				) -- 1224
				local dx = wide.eye.x - wide.target.x -- 1225
				local dy = wide.eye.y - wide.target.y -- 1226
				local dz = wide.eye.z - wide.target.z -- 1227
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 1228
				local want = math.max(24, wpBody.radius * 6) -- 1229
				if len > 0.000001 then -- 1229
					local s = want / len -- 1231
					dx = dx * s -- 1232
					dy = dy * s -- 1232
					dz = dz * s -- 1232
				end -- 1232
				from = { -- 1234
					target = Vec3(c.x, c.y, c.z), -- 1234
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 1234
				} -- 1234
				e = (k - 0.72) / 0.28 -- 1235
			end -- 1235
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 1237
			frame = { -- 1238
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 1239
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 1244
			} -- 1244
		end -- 1244
		frame = applyObserve(frame) -- 1252
		deps.rig.apply(deps.camera, frame) -- 1253
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1254
		local basis = makeBasis(frame) -- 1255
		if core.viewMode == "2D" then -- 1255
			local sp = deps.plan:probeScreen() -- 1261
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1262
		else -- 1262
			local pp = projectPrepared( -- 1264
				planeToWorld(probePos, 0), -- 1264
				basis -- 1264
			) -- 1264
			if pp ~= nil then -- 1264
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1265
			end -- 1265
		end -- 1265
		if not aimed then -- 1265
			deps.trajectory:clearPrediction() -- 1278
			deps.plan:clearPrediction() -- 1279
			predKey = "" -- 1280
		else -- 1280
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 1284
			if key ~= predKey then -- 1284
				predKey = key -- 1288
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1291
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1292
					steps = PredictSteps, -- 1295
					dt = core.dt, -- 1295
					sampleEvery = 4, -- 1295
					escapeRadius = level.escapeRadius, -- 1295
					t0 = tNow, -- 1295
					brake = motion.brake -- 1295
				}).points -- 1295
			end -- 1295
			deps.trajectory:setPrediction(predPoints, basis) -- 1298
			deps.plan:setPrediction(predPoints) -- 1300
		end -- 1300
		local rings = goalRingsAt(tNow) -- 1302
		deps.trajectory:setGoalRings(rings, basis) -- 1303
		deps.trajectory:clearTrail() -- 1304
		deps.plan:setGoalRings(rings) -- 1306
		deps.plan:clearTrail() -- 1307
		deps.plan:flush() -- 1308
	end -- 1128
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
	local function updateFinale() -- 1323
		deps.aim:setEnabled(false) -- 1324
		if core.flight == nil then -- 1324
			return -- 1325
		end -- 1325
		local idx = ____exports.coreProbeIndex(core) -- 1326
		local pos = core.flight.points[idx + 1] -- 1327
		local tWorld = core.t0 + core.flightTime -- 1328
		deps.scene.syncBodies(tWorld) -- 1331
		deps.scene.syncProbe(pos) -- 1332
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1333
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1336
		deps.camera:lookAt( -- 1337
			frame.eye, -- 1337
			frame.target, -- 1337
			Vec3(0, 1, 0) -- 1337
		) -- 1337
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1338
		local trail = {} -- 1341
		do -- 1341
			local i = 0 -- 1342
			while i <= idx do -- 1342
				trail[#trail + 1] = core.flight.points[i + 1] -- 1342
				i = i + 1 -- 1342
			end -- 1342
		end -- 1342
		local rings = goalRingsAt(tWorld, idx) -- 1343
		local basis = makeBasis(frame) -- 1344
		deps.trajectory:setTrail(trail, basis) -- 1345
		deps.trajectory:setGoalRings(rings, basis) -- 1346
		deps.plan:clearPrediction() -- 1347
		deps.plan:setGoalRings(rings) -- 1348
		deps.plan:flush() -- 1349
	end -- 1323
	local function updateFlying(dt) -- 1351
		deps.aim:setEnabled(false) -- 1352
		local entered = ____exports.coreUpdate(core, dt, level) -- 1355
		if core.flight == nil then -- 1355
			return entered -- 1356
		end -- 1356
		local idx = ____exports.coreProbeIndex(core) -- 1358
		local pos = core.flight.points[idx + 1] -- 1359
		local tWorld = core.t0 + core.flightTime -- 1363
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1363
			lastSlowmo = core.slowmo -- 1367
			lastSlowmoBody = core.slowmoBody -- 1368
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1369
			local nearD = near ~= nil and distance( -- 1370
				pos, -- 1370
				bodyPositionAt(near, tWorld) -- 1370
			) or 0 -- 1370
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1371
		end -- 1371
		flightLogT = flightLogT + dt -- 1378
		if flightLogT >= 0.5 then -- 1378
			flightLogT = 0 -- 1380
			local total = (#core.flight.points - 1) * core.dt -- 1381
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1382
		end -- 1382
		deps.scene.syncBodies(tWorld) -- 1388
		deps.scene.syncProbe(pos) -- 1389
		if idx > 0 then -- 1389
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1391
		end -- 1391
		local fr -- 1398
		local closeDist = nil -- 1399
		if core.slowmo and core.slowmoBody >= 0 then -- 1399
			local near = level.bodies[core.slowmoBody + 1] -- 1401
			local nearR = near.radius -- 1403
			do -- 1403
				local i = 0 -- 1404
				while i < #level.bodies do -- 1404
					local b = level.bodies[i + 1] -- 1405
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1405
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1405
							nearR = deps.visuals[i + 1].displayRadius -- 1407
						end -- 1407
						break -- 1408
					end -- 1408
					i = i + 1 -- 1404
				end -- 1404
			end -- 1404
			fr = { -- 1411
				pts = { -- 1411
					pos, -- 1411
					bodyPositionAt(near, tWorld) -- 1411
				}, -- 1411
				radii = {deps.scene.probeRadius, nearR} -- 1411
			} -- 1411
			closeDist = SlowMoCloseDist -- 1412
		else -- 1412
			fr = framingPoints(pos, tWorld) -- 1414
		end -- 1414
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1416
		deps.rig.apply(deps.camera, frame) -- 1417
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1418
		local basis = makeBasis(frame) -- 1419
		local trail = {} -- 1422
		do -- 1422
			local i = 0 -- 1423
			while i <= idx do -- 1423
				trail[#trail + 1] = core.flight.points[i + 1] -- 1423
				i = i + 1 -- 1423
			end -- 1423
		end -- 1423
		local rings = goalRingsAt(tWorld, idx) -- 1424
		deps.trajectory:setTrail(trail, basis) -- 1425
		deps.trajectory:setGoalRings(rings, basis) -- 1426
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1429
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1430
		deps.plan:setTrail(trail) -- 1431
		deps.plan:clearPrediction() -- 1432
		deps.plan:setGoalRings(rings) -- 1433
		deps.plan:flush() -- 1434
		return entered -- 1436
	end -- 1351
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1450
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1451
		core.t0 = next.t0 -- 1452
		clock = next.clock -- 1453
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1454
	end -- 1450
	local function update(dt) -- 1457
		applyView() -- 1460
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1460
			updateAiming(dt) -- 1462
		elseif core.phase == "Flying" then -- 1462
			local entered = updateFlying(dt) -- 1464
			if entered and core.result ~= nil then -- 1464
				local toFinale = deps.finale == true and core.result == "success" -- 1467
				if toFinale then -- 1467
					____exports.coreEnterFinale(core) -- 1468
				end -- 1468
				local telem = ____exports.calcFlightTelemetry(core, level) -- 1470
				deps:onResult(core.result, telem) -- 1471
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1471
					local ____end = #core.flight.points - 1 -- 1473
					deps:onFinale({ -- 1474
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1475
						time = core.flightTime, -- 1476
						tWorld = core.t0 + core.flightTime -- 1477
					}) -- 1477
				end -- 1477
				deps:onPhase(toFinale and "Finale" or "Result") -- 1480
			end -- 1480
		elseif core.phase == "Finale" then -- 1480
			updateFinale() -- 1483
		end -- 1483
	end -- 1457
	return { -- 1488
		phase = function() return core.phase end, -- 1489
		result = function() return core.result end, -- 1490
		onAimDrag = function(____, a) -- 1491
			core.aim = a -- 1492
			aimed = true -- 1493
			introT = IntroDurationSec -- 1494
		end, -- 1491
		aimReady = function() -- 1496
			if not ____exports.coreArm(core) then -- 1496
				return -- 1497
			end -- 1497
			applyView() -- 1498
			deps:onPhase("Armed") -- 1499
		end, -- 1496
		launchArmed = function() -- 1501
			if core.phase ~= "Armed" then -- 1501
				return -- 1503
			end -- 1503
			handoffDate(true) -- 1504
			____exports.coreLaunch( -- 1505
				core, -- 1505
				core.aim.velocity, -- 1505
				level, -- 1505
				probePos, -- 1505
				probeVel -- 1505
			) -- 1505
			deps.trajectory:clearPrediction() -- 1506
			deps.plan:clearPrediction() -- 1507
			applyView() -- 1508
			deps:onPhase("Flying") -- 1509
		end, -- 1501
		armed = function() return core.phase == "Armed" end, -- 1511
		viewMode = function() return core.viewMode end, -- 1512
		toggleViewMode = function() -- 1513
			____exports.coreToggleView(core) -- 1515
			applyView() -- 1516
		end, -- 1513
		observeDrag = function(____, dx, dy) -- 1518
			introT = IntroDurationSec -- 1519
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1520
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1521
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1522
			if obsPitchDeg > 40 then -- 1522
				obsPitchDeg = 40 -- 1523
			end -- 1523
			if obsPitchDeg < -40 then -- 1523
				obsPitchDeg = -40 -- 1524
			end -- 1524
		end, -- 1518
		observeZoom = function(____, deltaDist) -- 1526
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1527
			if obsZoom < 0.4 then -- 1527
				obsZoom = 0.4 -- 1528
			end -- 1528
			if obsZoom > 1.8 then -- 1528
				obsZoom = 1.8 -- 1529
			end -- 1529
		end, -- 1526
		launch = function(____, v) -- 1531
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1531
				return -- 1532
			end -- 1532
			handoffDate(true) -- 1533
			____exports.coreLaunch( -- 1535
				core, -- 1535
				v, -- 1535
				level, -- 1535
				probePos, -- 1535
				probeVel -- 1535
			) -- 1535
			deps.trajectory:clearPrediction() -- 1536
			deps.plan:clearPrediction() -- 1537
			applyView() -- 1538
			deps:onPhase("Flying") -- 1539
		end, -- 1531
		retry = function() -- 1541
			if core.phase ~= "Result" then -- 1541
				return -- 1542
			end -- 1542
			handoffDate(false) -- 1543
			aimed = false -- 1544
			____exports.coreRetry(core, level.aimMin) -- 1545
			deps.trajectory:clearTrail() -- 1546
			deps.trajectory:clearPrediction() -- 1547
			deps.trajectory:clearGoalRings() -- 1548
			deps.plan:clearTrail() -- 1549
			deps.plan:clearPrediction() -- 1550
			deps.plan:clearGoalRings() -- 1551
			applyView() -- 1552
			deps:onPhase("Aiming") -- 1553
		end, -- 1541
		backToSelect = function() -- 1555
			if not ____exports.coreBackToSelect(core) then -- 1555
				return false -- 1556
			end -- 1556
			deps.aim:setEnabled(false) -- 1558
			deps.trajectory:clearTrail() -- 1559
			deps.trajectory:clearPrediction() -- 1560
			deps.trajectory:clearGoalRings() -- 1561
			deps.plan:clearTrail() -- 1562
			deps.plan:clearPrediction() -- 1563
			deps.plan:clearGoalRings() -- 1564
			applyView() -- 1565
			deps:onPhase("LevelSelect") -- 1566
			return true -- 1567
		end, -- 1555
		startLevel = function() -- 1569
			aimed = false -- 1572
			____exports.coreRetry(core, level.aimMin) -- 1573
			deps.rig.reset() -- 1576
			introT = 0 -- 1577
			introLogged = false -- 1578
			prepareIdle() -- 1579
			deps.trajectory:clearTrail() -- 1580
			deps.trajectory:clearPrediction() -- 1581
			deps.trajectory:clearGoalRings() -- 1582
			deps.plan:clearTrail() -- 1583
			deps.plan:clearPrediction() -- 1584
			deps.plan:clearGoalRings() -- 1585
			appliedMode = "" -- 1588
			applyView() -- 1589
			deps:onPhase("Aiming") -- 1590
		end, -- 1569
		stepTime = function(____, dir, span) -- 1592
			if not ____exports.coreTimeWarpAllowed(core) then -- 1592
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1596
				return -- 1597
			end -- 1597
			local span0 = span > 0 and span or 0 -- 1599
			clock = clock + dir * TimeWarpStep -- 1600
			if clock < 0 then -- 1600
				clock = 0 -- 1601
			end -- 1601
			if span0 > 0 and clock > span0 then -- 1601
				clock = span0 -- 1602
			end -- 1602
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1604
		end, -- 1592
		dateNow = function() return core.t0 + clock end, -- 1606
		setBrakeMode = function(____, on) -- 1607
			core.brakeMode = on -- 1608
		end, -- 1607
		brakeMode = function() return core.brakeMode end, -- 1611
		setPlaybackSpeed = function(____, speed) -- 1612
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1612
				return -- 1614
			end -- 1614
			core.playback = speed -- 1615
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1616
		end, -- 1612
		playbackSpeed = function() return core.playback end, -- 1618
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1619
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 1620
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 1621
		hasBraked = function() return core.hasBraked end, -- 1622
		update = function(____, frameDt) return update(frameDt) end -- 1624
	} -- 1624
end -- 866
return ____exports -- 866
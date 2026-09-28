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
local GameSecondsPerRealSecond = ____LevelData.GameSecondsPerRealSecond -- 33
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
--- **档位 → 世界时钟速率**（游戏秒 / 真实秒，B3，2026-09-28）。
-- 
-- 口径（用户 2026-09-28）：「1X 就是模拟的真实情况下的地月系的 1 秒」—— 也就是
-- `pow = 0` 时速率 = 1/SecPerGameSec（现实 1 秒走 1 秒；挂机一天，地球自转一圈）。
-- 加速 = pow + 1（**后面加个 0**），减速 = pow − 1（下限 0）。纯函数、可单测；物理层一行不动。
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 202
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 203
	local n = math.floor(pow) -- 204
	while n > 0 do -- 204
		rate = rate * 10 -- 206
		n = n - 1 -- 207
	end -- 207
	while n < 0 do -- 207
		rate = rate / 10 -- 210
		n = n + 1 -- 211
	end -- 211
	return rate -- 213
end -- 202
local function neutralAim(minSpeed) -- 216
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 217
end -- 216
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 221
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 222
end -- 221
function ____exports.createCore(dt) -- 225
	return { -- 226
		phase = "Aiming", -- 227
		aim = neutralAim(AimMinSpeed), -- 228
		flight = nil, -- 229
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 230
		brakeMode = false, -- 231
		t0 = 0, -- 232
		flightTime = 0, -- 233
		goalIndex = -1, -- 234
		result = nil, -- 235
		viewMode = "2D", -- 237
		playback = FlightPlayback, -- 239
		slowmo = false, -- 240
		slowmoBody = -1, -- 241
		hasBraked = false, -- 242
		brakePointIndex = -1 -- 243
	} -- 243
end -- 225
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 255
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 256
	return core.viewMode -- 257
end -- 255
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 275
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 281
	local share = brakeMode and BrakeShare or 1 -- 282
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 283
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 284
	local brake = brakeMode and mag > 0 and ({ -- 285
		dv = mag * (1 - share), -- 286
		startStep = math.floor(maxSteps / 2) -- 286
	}) or nil -- 286
	return {init = init, brake = brake} -- 288
end -- 275
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 297
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 297
		return -- 299
	end -- 299
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 300
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 301
	local p0 = from ~= nil and from or level.probeStart -- 302
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 303
		steps = level.maxSteps, -- 306
		dt = core.dt, -- 306
		sampleEvery = 1, -- 306
		escapeRadius = level.escapeRadius, -- 306
		t0 = core.t0, -- 306
		brake = motion.brake -- 306
	}) -- 306
	core.flight = flight -- 308
	core.goalIndex = findGoalIndex( -- 309
		flight.points, -- 309
		level.bodies, -- 309
		level.goal, -- 309
		core.dt, -- 309
		core.t0, -- 309
		flight.velocities -- 309
	) -- 309
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 310
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 313
	core.flightTime = 0 -- 318
	core.slowmo = false -- 320
	core.slowmoBody = -1 -- 321
	core.hasBraked = false -- 322
	core.brakePointIndex = -1 -- 323
	core.phase = "Flying" -- 324
	core.viewMode = "3D" -- 326
end -- 297
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 335
	if core.phase ~= "Aiming" then -- 335
		return false -- 336
	end -- 336
	core.phase = "Armed" -- 337
	return true -- 338
end -- 335
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 342
	if core.phase ~= "Armed" then -- 342
		return false -- 343
	end -- 343
	core.phase = "Aiming" -- 344
	return true -- 345
end -- 342
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 359
	return core.phase == "Aiming" or core.phase == "Armed" -- 360
end -- 359
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 376
	if toT0 then -- 376
		return {t0 = clock, clock = 0} -- 377
	end -- 377
	return {t0 = 0, clock = t0} -- 378
end -- 376
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 390
	local host = -1 -- 400
	do -- 400
		local i = 0 -- 401
		while i < #bodies do -- 401
			do -- 401
				local b = bodies[i + 1] -- 402
				local isHost = false -- 403
				do -- 403
					local j = 0 -- 404
					while j < #bodies do -- 404
						do -- 404
							local h = bodies[j + 1].host -- 405
							if h == nil then -- 405
								goto __continue28 -- 406
							end -- 406
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 406
								isHost = true -- 407
								break -- 407
							end -- 407
						end -- 407
						::__continue28:: -- 407
						j = j + 1 -- 404
					end -- 404
				end -- 404
				if not isHost then -- 404
					goto __continue26 -- 409
				end -- 409
				if host < 0 or b.gm > bodies[host + 1].gm then -- 409
					host = i -- 410
				end -- 410
			end -- 410
			::__continue26:: -- 410
			i = i + 1 -- 401
		end -- 401
	end -- 401
	if host >= 0 then -- 401
		return host -- 412
	end -- 412
	local best = -1 -- 414
	do -- 414
		local i = 0 -- 415
		while i < #bodies do -- 415
			do -- 415
				local b = bodies[i + 1] -- 416
				if b.orbitRadius ~= 0 then -- 416
					goto __continue35 -- 417
				end -- 417
				if best < 0 or b.gm > bodies[best + 1].gm then -- 417
					best = i -- 418
				end -- 418
			end -- 418
			::__continue35:: -- 418
			i = i + 1 -- 415
		end -- 415
	end -- 415
	return best -- 420
end -- 390
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 438
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 439
	local best = -1 -- 440
	local bestD = 1000000000 -- 441
	do -- 441
		local i = 0 -- 442
		while i < #bodies do -- 442
			do -- 442
				if i == anchor then -- 442
					goto __continue40 -- 443
				end -- 443
				local b = bodies[i + 1] -- 444
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 445
				local d = distance( -- 446
					probe, -- 446
					bodyPositionAt(b, t) -- 446
				) -- 446
				if d < threshold and d < bestD then -- 446
					bestD = d -- 448
					best = i -- 449
				end -- 449
			end -- 449
			::__continue40:: -- 449
			i = i + 1 -- 442
		end -- 442
	end -- 442
	return best -- 452
end -- 438
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 456
	if core.flight == nil then -- 456
		return 0 -- 457
	end -- 457
	local idx = math.floor(core.flightTime / core.dt) -- 458
	local last = #core.flight.points - 1 -- 459
	if idx > last then -- 459
		idx = last -- 460
	end -- 460
	if idx < 0 then -- 460
		idx = 0 -- 461
	end -- 461
	return idx -- 462
end -- 456
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
function ____exports.coreUpdate(core, dt, level) -- 479
	if core.phase ~= "Flying" or core.flight == nil then -- 479
		return false -- 480
	end -- 480
	if level ~= nil then -- 480
		local idx = ____exports.coreProbeIndex(core) -- 484
		core.slowmoBody = ____exports.slowMotionBody( -- 485
			level.bodies, -- 485
			core.flight.points[idx + 1], -- 485
			core.t0 + core.flightTime, -- 485
			____exports.anchorBodyIndex(level.bodies), -- 485
			level.slowMoFloor -- 485
		) -- 485
		core.slowmo = core.slowmoBody >= 0 -- 486
	end -- 486
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 489
	core.flightTime = core.flightTime + dt * speed -- 490
	local naturalEnd = #core.flight.points - 1 -- 491
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 492
	if ____exports.coreProbeIndex(core) >= endIdx then -- 492
		core.flightTime = endIdx * core.dt -- 495
		core.phase = "Result" -- 496
		return true -- 497
	end -- 497
	return false -- 499
end -- 479
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 505
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 509
	local maxSpeed = 0 -- 510
	local closestDist = 1000000000 -- 511
	local eccentricity = nil -- 512
	if core.flight ~= nil then -- 512
		local pts = core.flight.points -- 515
		local vels = core.flight.velocities -- 516
		local ____end = ____exports.coreProbeIndex(core) -- 517
		local targetIdx = level.goal.planetIndex -- 518
		local targetBody = targetIdx >= 0 and targetIdx < #level.bodies and level.bodies[targetIdx + 1] or nil -- 519
		do -- 519
			local k = 0 -- 521
			while k <= ____end and k < #pts do -- 521
				local p = pts[k + 1] -- 522
				if vels ~= nil and k < #vels then -- 522
					local v = vels[k + 1] -- 524
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 525
					if spd > maxSpeed then -- 525
						maxSpeed = spd -- 526
					end -- 526
				end -- 526
				if targetBody ~= nil then -- 526
					local t = core.t0 + k * core.dt -- 529
					local tp = bodyPositionAt(targetBody, t) -- 530
					local d = distance(p, tp) -- 531
					if d < closestDist then -- 531
						closestDist = d -- 532
					end -- 532
				end -- 532
				k = k + 1 -- 521
			end -- 521
		end -- 521
		if targetBody ~= nil and targetBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 521
			local tEnd = core.t0 + ____end * core.dt -- 537
			local tpEnd = bodyPositionAt(targetBody, tEnd) -- 538
			local tvEnd = bodyVelocityAt(targetBody, tEnd) -- 539
			local rx = pts[____end + 1].x - tpEnd.x -- 540
			local ry = pts[____end + 1].y - tpEnd.y -- 541
			local vx = vels[____end + 1].x - tvEnd.x -- 542
			local vy = vels[____end + 1].y - tvEnd.y -- 543
			local r = math.sqrt(rx * rx + ry * ry) -- 544
			local v2 = vx * vx + vy * vy -- 545
			local mu = targetBody.gm -- 546
			if r > 0 and mu > 0 then -- 546
				local energy = v2 / 2 - mu / r -- 548
				local h = rx * vy - ry * vx -- 549
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 550
				if term >= 0 then -- 550
					eccentricity = math.sqrt(term) -- 552
				end -- 552
			end -- 552
		end -- 552
	end -- 552
	return { -- 558
		burnDv = burnDv, -- 559
		flightTime = core.flightTime, -- 560
		closestDist = closestDist < 100000000 and closestDist or 0, -- 561
		maxSpeed = maxSpeed, -- 562
		eccentricity = eccentricity -- 563
	} -- 563
end -- 505
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 568
	core.phase = "Aiming" -- 569
	core.viewMode = "2D" -- 571
	core.flight = nil -- 572
	core.flightTime = 0 -- 573
	core.goalIndex = -1 -- 574
	core.result = nil -- 575
	core.slowmo = false -- 576
	core.slowmoBody = -1 -- 577
	core.hasBraked = false -- 578
	core.brakePointIndex = -1 -- 579
	core.aim = neutralAim(levelAimMin(aimMin)) -- 580
end -- 568
--- 判定当前飞行状态下是否处于可逆喷制动窗口。
-- 纯函数，可单测。
function ____exports.isBrakeWindowActive(core, level) -- 587
	if core.phase ~= "Flying" or core.flight == nil or core.hasBraked then -- 587
		return false -- 588
	end -- 588
	local curIdx = ____exports.coreProbeIndex(core) -- 589
	local pts = core.flight.points -- 590
	if curIdx < 0 or curIdx >= #pts then -- 590
		return false -- 591
	end -- 591
	local targetIdx = level.goal.planetIndex -- 593
	if targetIdx < 0 or targetIdx >= #level.bodies then -- 593
		return false -- 594
	end -- 594
	local targetBody = level.bodies[targetIdx + 1] -- 595
	local tNow = core.t0 + core.flightTime -- 596
	local targetPos = bodyPositionAt(targetBody, tNow) -- 597
	local dist = distance(pts[curIdx + 1], targetPos) -- 598
	local floorD = level.slowMoFloor ~= nil and level.slowMoFloor > 0 and level.slowMoFloor or SlowMoFloorDist -- 601
	local brakeDistLimit = math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD) -- 602
	return dist <= brakeDistLimit and dist > targetBody.radius -- 603
end -- 587
--- 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
-- 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
-- 返回 true 表示制动成功应用。
function ____exports.applyInFlightBrake(core, level) -- 611
	if not ____exports.isBrakeWindowActive(core, level) then -- 611
		return false -- 612
	end -- 612
	if core.flight == nil then -- 612
		return false -- 613
	end -- 613
	local curIdx = ____exports.coreProbeIndex(core) -- 615
	local curPos = core.flight.points[curIdx + 1] -- 616
	local curVel = core.flight.velocities ~= nil and curIdx < #core.flight.velocities and core.flight.velocities[curIdx + 1] or ({x = 0, y = 0}) -- 617
	local tNow = core.t0 + core.flightTime -- 620
	local targetIdx = level.goal.planetIndex -- 622
	local targetBody = level.bodies[targetIdx + 1] -- 623
	local targetPos = bodyPositionAt(targetBody, tNow) -- 624
	local targetVel = bodyVelocityAt(targetBody, tNow) -- 625
	local relVel = {x = curVel.x - targetVel.x, y = curVel.y - targetVel.y} -- 628
	local relSpeed = math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y) -- 629
	local dist = distance(curPos, targetPos) -- 630
	if relSpeed <= 0.000001 or dist <= 0.000001 then -- 630
		return false -- 632
	end -- 632
	local vCirc = math.sqrt(targetBody.gm / dist) -- 635
	local targetRelSpeed = vCirc * 0.98 -- 638
	local reductionFactor = targetRelSpeed / relSpeed -- 639
	local clampedFactor = math.min(0.95, reductionFactor) -- 640
	local newRelVel = {x = relVel.x * clampedFactor, y = relVel.y * clampedFactor} -- 642
	local newVel = {x = targetVel.x + newRelVel.x, y = targetVel.y + newRelVel.y} -- 646
	local remainingSteps = math.max(1000, level.maxSteps - curIdx) -- 652
	local postBrakeSim = simulate({pos = curPos, vel = newVel}, level.bodies, { -- 653
		steps = remainingSteps, -- 657
		dt = core.dt, -- 658
		sampleEvery = 1, -- 659
		escapeRadius = level.escapeRadius, -- 660
		t0 = tNow -- 661
	}) -- 661
	local mergedPoints = __TS__ArraySlice(core.flight.points, 0, curIdx) -- 666
	do -- 666
		local i = 0 -- 667
		while i < #postBrakeSim.points do -- 667
			mergedPoints[#mergedPoints + 1] = postBrakeSim.points[i + 1] -- 668
			i = i + 1 -- 667
		end -- 667
	end -- 667
	local mergedVelocities = __TS__ArraySlice(core.flight.velocities or ({}), 0, curIdx) -- 670
	if postBrakeSim.velocities ~= nil then -- 670
		do -- 670
			local i = 0 -- 672
			while i < #postBrakeSim.velocities do -- 672
				mergedVelocities[#mergedVelocities + 1] = postBrakeSim.velocities[i + 1] -- 673
				i = i + 1 -- 672
			end -- 672
		end -- 672
	end -- 672
	core.flight = { -- 677
		outcome = postBrakeSim.outcome, -- 678
		points = mergedPoints, -- 679
		velocities = mergedVelocities, -- 680
		state = postBrakeSim.state, -- 681
		hitIndex = postBrakeSim.hitIndex, -- 682
		stepsRun = curIdx + postBrakeSim.stepsRun -- 683
	} -- 683
	core.hasBraked = true -- 686
	core.brakePointIndex = curIdx -- 687
	core.goalIndex = findGoalIndex( -- 690
		mergedPoints, -- 690
		level.bodies, -- 690
		level.goal, -- 690
		core.dt, -- 690
		core.t0, -- 690
		mergedVelocities -- 690
	) -- 690
	core.result = ____exports.resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal) -- 691
	print((((((((((("[escape-velocity] in-flight brake applied at t=" .. __TS__NumberToFixed(tNow, 2)) .. " curIdx=") .. __TS__NumberToFixed(curIdx, 0)) .. " relSpeed=") .. __TS__NumberToFixed(relSpeed, 3)) .. " -> ") .. __TS__NumberToFixed( -- 693
		math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y), -- 695
		3 -- 695
	)) .. " vCirc=") .. __TS__NumberToFixed(vCirc, 3)) .. " result=") .. core.result) -- 695
	return true -- 699
end -- 611
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 713
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 713
		return false -- 715
	end -- 715
	core.phase = "LevelSelect" -- 716
	core.viewMode = "2D" -- 718
	core.flight = nil -- 719
	core.flightTime = 0 -- 720
	core.goalIndex = -1 -- 721
	core.result = nil -- 722
	core.slowmo = false -- 723
	core.slowmoBody = -1 -- 724
	return true -- 725
end -- 713
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 754
	if core.phase ~= "Result" then -- 754
		return false -- 755
	end -- 755
	core.phase = "Finale" -- 756
	return true -- 757
end -- 754
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 775
	local dist = distance > 1 and distance or 1 -- 776
	local ux = probe.x -- 778
	local uy = probe.y -- 779
	local len = math.sqrt(ux * ux + uy * uy) -- 780
	if len < 0.000001 then -- 780
		ux = 0 -- 781
		uy = 1 -- 781
	else -- 781
		ux = ux / len -- 781
		uy = uy / len -- 781
	end -- 781
	local tilt = tiltDeg * math.pi / 180 -- 782
	local flat = math.cos(tilt) * dist -- 783
	return { -- 784
		target = Vec3(0, 0, 0), -- 786
		eye = Vec3( -- 787
			ux * flat * PlaneToWorldX, -- 787
			math.sin(tilt) * dist, -- 787
			uy * flat * PlaneToWorldZ -- 787
		) -- 787
	} -- 787
end -- 775
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 925
	local IntroTourDuration, introTourActive, introTourT -- 925
	local core = ____exports.createCore(level.physicsStep) -- 926
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 932
	local paused = false -- 933
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 934
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 936
	local function applySpeedRate() -- 937
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 938
	end -- 937
	applySpeedRate() -- 944
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 947
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
	local function applyView() -- 962
		local mode = core.viewMode -- 963
		if mode == appliedMode then -- 963
			return -- 964
		end -- 964
		appliedMode = mode -- 965
		local is2D = mode == "2D" -- 966
		deps.plan:setVisible(is2D) -- 967
		deps.trajectory.root.visible = not is2D -- 968
		deps:setWorldVisible(not is2D) -- 969
		deps.aim:setFullScreenAim(is2D) -- 970
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 971
	end -- 962
	local function finishIntroTour() -- 974
		if not introTourActive then -- 974
			return -- 975
		end -- 975
		introTourActive = false -- 976
		introTourT = IntroTourDuration -- 977
		core.viewMode = "2D" -- 978
		applyView() -- 979
		print("[escape-velocity] intro tour completed -> enter 2D") -- 980
	end -- 974
	local function makeBasis(frame) -- 983
		return prepareCamera({ -- 984
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 986
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 987
			up = {x = 0, y = 1, z = 0}, -- 988
			fovYDeg = deps.fovYDeg, -- 989
			aspect = deps.aspect, -- 990
			viewW = deps.viewW, -- 991
			viewH = deps.viewH -- 992
		}, HANDEDNESS, FLIP_Y) -- 992
	end -- 983
	local PredMinIntervalSec = 0.08 -- 1004
	local predAimKey = "" -- 1005
	local predPosKey = "" -- 1006
	local predAccum = 1 -- 1007
	local predForce = true -- 1008
	local predPoints = {} -- 1009
	IntroTourDuration = 3.2 -- 1011
	introTourActive = false -- 1012
	introTourT = IntroTourDuration -- 1013
	local introLogged = false -- 1014
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1016
	local clock = 0 -- 1022
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1024
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1026
	local obsYawDeg = 0 -- 1030
	local obsPitchDeg = 0 -- 1031
	local obsZoom = 1 -- 1032
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1034
	local idleOrbit = nil -- 1036
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1047
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1049
	local lastSlowmoBody = -1 -- 1050
	local flightLogT = 0 -- 1051
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1053
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1054
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
	local function prepareIdle() -- 1069
		clock = 0 -- 1071
		core.t0 = 0 -- 1072
		idleOrbit = nil -- 1073
		if level.probeVel0 == nil then -- 1073
			return -- 1074
		end -- 1074
		local hostIndex = -1 -- 1076
		local bestD = 1000000000 -- 1077
		do -- 1077
			local i = 0 -- 1078
			while i < #level.bodies do -- 1078
				do -- 1078
					local b = level.bodies[i + 1] -- 1079
					if b.gm <= 0 then -- 1079
						goto __continue93 -- 1080
					end -- 1080
					local d = distance( -- 1081
						bodyPositionAt(b, 0), -- 1081
						level.probeStart -- 1081
					) -- 1081
					if d < bestD then -- 1081
						bestD = d -- 1083
						hostIndex = i -- 1084
					end -- 1084
				end -- 1084
				::__continue93:: -- 1084
				i = i + 1 -- 1078
			end -- 1078
		end -- 1078
		if hostIndex < 0 or bestD < 1e-9 then -- 1078
			return -- 1087
		end -- 1087
		local host = level.bodies[hostIndex + 1] -- 1088
		local hp = bodyPositionAt(host, 0) -- 1089
		local hv = bodyVelocityAt(host, 0) -- 1090
		local rx = level.probeStart.x - hp.x -- 1092
		local ry = level.probeStart.y - hp.y -- 1093
		local vx = level.probeVel0.x - hv.x -- 1094
		local vy = level.probeVel0.y - hv.y -- 1095
		local r = math.sqrt(rx * rx + ry * ry) -- 1096
		if r < 1e-12 then -- 1096
			return -- 1097
		end -- 1097
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1099
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1100
		idleOrbit = { -- 1101
			hostIndex = hostIndex, -- 1101
			r = r, -- 1101
			phase0 = math.atan(ry, rx), -- 1101
			omega = dir * omega -- 1101
		} -- 1101
	end -- 1069
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1105
		if idleOrbit == nil then -- 1105
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1107
		end -- 1107
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1112
		local hp = bodyPositionAt(host, tWorld) -- 1113
		local hv = bodyVelocityAt(host, tWorld) -- 1114
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1115
		local ca = math.cos(a) -- 1116
		local sa = math.sin(a) -- 1117
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1118
	end -- 1105
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1135
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1136
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1139
		local wps = goalWaypoints(level.goal) -- 1140
		if #wps == 0 then -- 1140
			return nil -- 1141
		end -- 1141
		local passed = 0 -- 1142
		if core.flight ~= nil then -- 1142
			local upto = math.floor(core.flightTime / core.dt) -- 1144
			passed = waypointProgress( -- 1145
				core.flight.points, -- 1145
				level.bodies, -- 1145
				level.goal, -- 1145
				core.dt, -- 1145
				core.t0, -- 1145
				upto, -- 1145
				core.flight.velocities -- 1145
			).passed -- 1145
		end -- 1145
		if passed >= #wps then -- 1145
			return nil -- 1147
		end -- 1147
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1148
	end -- 1139
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1159
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1159
			local hr = anchorDef.radius -- 1163
			do -- 1163
				local i = 0 -- 1164
				while i < #level.bodies do -- 1164
					local b = level.bodies[i + 1] -- 1165
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1165
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1165
							hr = deps.visuals[i + 1].displayRadius -- 1167
						end -- 1167
						break -- 1168
					end -- 1168
					i = i + 1 -- 1164
				end -- 1164
			end -- 1164
			return { -- 1171
				pts = { -- 1171
					probe, -- 1171
					bodyPositionAt(anchorDef, t) -- 1171
				}, -- 1171
				radii = {deps.scene.probeRadius, hr} -- 1171
			} -- 1171
		end -- 1171
		local corePts = {probe} -- 1175
		local coreRadii = {deps.scene.probeRadius} -- 1176
		local next = nextStationBody() -- 1177
		local nextTol = 0 -- 1178
		if next ~= nil then -- 1178
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1180
			local wps = goalWaypoints(level.goal) -- 1181
			local passed = 0 -- 1182
			if core.flight ~= nil then -- 1182
				passed = waypointProgress( -- 1184
					core.flight.points, -- 1184
					level.bodies, -- 1184
					level.goal, -- 1184
					core.dt, -- 1184
					core.t0, -- 1184
					math.floor(core.flightTime / core.dt), -- 1184
					core.flight.velocities -- 1184
				).passed -- 1184
			end -- 1184
			if passed < #wps then -- 1184
				nextTol = wps[passed + 1].tolerance -- 1186
			end -- 1186
			local r = nextTol > next.radius and nextTol or next.radius -- 1187
			coreRadii[#coreRadii + 1] = r -- 1188
		end -- 1188
		if anchorDef == nil then -- 1188
			return {pts = corePts, radii = coreRadii} -- 1191
		end -- 1191
		local anchorR = anchorDef.radius -- 1196
		do -- 1196
			local i = 0 -- 1197
			while i < #level.bodies do -- 1197
				local b = level.bodies[i + 1] -- 1198
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1198
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1198
						anchorR = deps.visuals[i + 1].displayRadius -- 1200
					end -- 1200
					break -- 1201
				end -- 1201
				i = i + 1 -- 1197
			end -- 1197
		end -- 1197
		local withAnchorPts = { -- 1204
			probe, -- 1204
			bodyPositionAt(anchorDef, t) -- 1204
		} -- 1204
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1205
		do -- 1205
			local i = 1 -- 1206
			while i < #corePts do -- 1206
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1207
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1208
				i = i + 1 -- 1206
			end -- 1206
		end -- 1206
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1210
		if want <= CameraFramingBudget then -- 1210
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1211
		end -- 1211
		return {pts = corePts, radii = coreRadii} -- 1212
	end -- 1159
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1216
		local wps = goalWaypoints(level.goal) -- 1217
		if #wps == 0 then -- 1217
			return {} -- 1218
		end -- 1218
		local passed = 0 -- 1219
		if upto ~= nil and core.flight ~= nil then -- 1219
			passed = waypointProgress( -- 1221
				core.flight.points, -- 1221
				level.bodies, -- 1221
				level.goal, -- 1221
				core.dt, -- 1221
				core.t0, -- 1221
				upto, -- 1221
				core.flight.velocities -- 1221
			).passed -- 1221
		end -- 1221
		if passed >= #wps then -- 1221
			return {} -- 1226
		end -- 1226
		local nextWp = wps[passed + 1] -- 1227
		local body = level.bodies[nextWp.planetIndex + 1] -- 1228
		if body == nil then -- 1228
			return {} -- 1229
		end -- 1229
		return {{ -- 1230
			center = bodyPositionAt(body, t), -- 1230
			radius = nextWp.tolerance, -- 1230
			passed = false -- 1230
		}} -- 1230
	end -- 1216
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1234
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1234
			return f -- 1235
		end -- 1235
		local dx = f.eye.x - f.target.x -- 1236
		local dy = f.eye.y - f.target.y -- 1237
		local dz = f.eye.z - f.target.z -- 1238
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1239
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1240
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1241
		local lo = CameraTiltMin * math.pi / 180 -- 1242
		local hi = CameraTiltMax * math.pi / 180 -- 1243
		if pitch < lo then -- 1243
			pitch = lo -- 1244
		end -- 1244
		if pitch > hi then -- 1244
			pitch = hi -- 1245
		end -- 1245
		local cp = math.cos(pitch) -- 1246
		return { -- 1247
			target = f.target, -- 1248
			eye = Vec3( -- 1249
				f.target.x + r * cp * math.sin(yaw), -- 1250
				f.target.y + r * math.sin(pitch), -- 1251
				f.target.z + r * cp * math.cos(yaw) -- 1252
			) -- 1252
		} -- 1252
	end -- 1234
	local function updateAiming(dt) -- 1257
		deps.aim:setEnabled(true) -- 1258
		local dragging = deps.aim:isDragging() -- 1260
		if (core.phase == "Aiming" or core.phase == "Armed") and not dragging and idleOrbit ~= nil then -- 1260
			clock = clock + dt * core.playback -- 1274
			orbitClock = orbitClock + dt * core.playback -- 1275
		end -- 1275
		local tNow = core.t0 + clock -- 1277
		local idleState = idleProbeAt(tNow) -- 1279
		probePos = idleState.pos -- 1280
		probeVel = idleState.vel -- 1281
		deps.scene.syncBodies(tNow) -- 1283
		deps.scene.syncProbe(probePos) -- 1284
		if idleOrbit ~= nil then -- 1284
			deps.scene.faceVelocity(probeVel) -- 1285
		end -- 1285
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1287
		deps.plan:syncProbe(probePos, probeVel) -- 1288
		local fr = framingPoints(probePos, tNow) -- 1291
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1292
		if frameLogged < 6 then -- 1292
			frameLogged = frameLogged + 1 -- 1296
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1297
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1301
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1302
				__TS__ArrayMap( -- 1308
					fr.pts, -- 1308
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1308
				), -- 1308
				" " -- 1308
			)) .. "]") -- 1308
		end -- 1308
		if introTourActive and introTourT < IntroTourDuration then -- 1308
			introTourT = introTourT + dt -- 1312
			local k = introTourT / IntroTourDuration -- 1313
			if k >= 1 then -- 1313
				finishIntroTour() -- 1315
			else -- 1315
				if k >= 0.95 and not introLogged then -- 1315
					introLogged = true -- 1318
					print("[escape-velocity] intro camera finishing") -- 1319
				end -- 1319
				local targetBody = nil -- 1321
				local wps = goalWaypoints(level.goal) -- 1322
				if #wps > 0 then -- 1322
					targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1324
				elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1324
					targetBody = level.bodies[level.goal.planetIndex + 1] -- 1326
				end -- 1326
				if targetBody == nil and #level.bodies > 0 then -- 1326
					targetBody = level.bodies[#level.bodies] -- 1329
				end -- 1329
				if targetBody ~= nil then -- 1329
					local pwTarget = planeToWorld( -- 1333
						bodyPositionAt(targetBody, tNow), -- 1333
						0 -- 1333
					) -- 1333
					local pwProbe = planeToWorld(probePos, 0) -- 1334
					local isMicroSystem = targetBody.orbitRadius < 2 -- 1335
					local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1336
					local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1337
					if k < 0.35 then -- 1337
						local e1 = k / 0.35 -- 1341
						local az = (0.2 + e1 * 0.15) * math.pi -- 1342
						local tilt = 0.35 * math.pi -- 1343
						local eye = Vec3( -- 1344
							pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1345
							pwTarget.y + math.sin(tilt) * distTarget, -- 1346
							pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1347
						) -- 1347
						frame = {target = pwTarget, eye = eye} -- 1349
					elseif k < 0.72 then -- 1349
						local e2 = (k - 0.35) / 0.37 -- 1352
						local ease2 = e2 * e2 * (3 - 2 * e2) -- 1353
						local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1354
						local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1355
						local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1356
						local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1357
						local eye = Vec3( -- 1362
							targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1363
							targetCenter.y + curDist * 0.8, -- 1364
							targetCenter.z + math.cos(az) * 0.5 * curDist -- 1365
						) -- 1365
						frame = {target = targetCenter, eye = eye} -- 1367
					else -- 1367
						local e3 = (k - 0.72) / 0.28 -- 1370
						local ease3 = 1 - (1 - e3) * (1 - e3) -- 1371
						local az = 0.25 * math.pi -- 1372
						local tilt = 0.36 * math.pi -- 1373
						local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1374
						local eye = Vec3( -- 1375
							pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1376
							pwProbe.y + math.sin(tilt) * curDist, -- 1377
							pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1378
						) -- 1378
						frame = {target = pwProbe, eye = eye} -- 1380
					end -- 1380
				end -- 1380
			end -- 1380
		end -- 1380
		frame = applyObserve(frame) -- 1386
		deps.rig.apply(deps.camera, frame) -- 1387
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1388
		local basis = makeBasis(frame) -- 1389
		if core.viewMode == "2D" then -- 1389
			local sp = deps.plan:probeScreen() -- 1395
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1396
		else -- 1396
			local pp = projectPrepared( -- 1398
				planeToWorld(probePos, 0), -- 1398
				basis -- 1398
			) -- 1398
			if pp ~= nil then -- 1398
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1399
			end -- 1399
		end -- 1399
		if not aimed then -- 1399
			deps.trajectory:clearPrediction() -- 1412
			deps.plan:clearPrediction() -- 1413
			predForce = true -- 1414
		else -- 1414
			local aimKey = (((__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4)) .. "|") .. (core.brakeMode and "B" or "C") -- 1420
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1421
			predAccum = predAccum + dt -- 1422
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1423
			if needIt then -- 1423
				predForce = false -- 1425
				predAccum = 0 -- 1426
				predAimKey = aimKey -- 1427
				predPosKey = posKey -- 1428
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1431
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1432
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1435
					dt = core.dt, -- 1435
					sampleEvery = 4, -- 1435
					escapeRadius = level.escapeRadius, -- 1435
					t0 = tNow, -- 1435
					brake = motion.brake -- 1435
				}).points -- 1435
			end -- 1435
			deps.trajectory:setPrediction(predPoints, basis) -- 1438
			deps.plan:setPrediction(predPoints) -- 1440
		end -- 1440
		if idleOrbit ~= nil then -- 1440
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1444
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1445
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1446
		end -- 1446
		local rings = goalRingsAt(tNow) -- 1448
		deps.trajectory:setGoalRings(rings, basis) -- 1449
		deps.trajectory:clearTrail() -- 1450
		deps.plan:setGoalRings(rings) -- 1452
		deps.plan:clearTrail() -- 1453
		deps.plan:flush() -- 1454
	end -- 1257
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
	local function updateFinale() -- 1469
		deps.aim:setEnabled(false) -- 1470
		if core.flight == nil then -- 1470
			return -- 1471
		end -- 1471
		local idx = ____exports.coreProbeIndex(core) -- 1472
		local pos = core.flight.points[idx + 1] -- 1473
		local tWorld = core.t0 + core.flightTime -- 1474
		deps.scene.syncBodies(tWorld) -- 1477
		deps.scene.syncProbe(pos) -- 1478
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1479
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1482
		deps.camera:lookAt( -- 1483
			frame.eye, -- 1483
			frame.target, -- 1483
			Vec3(0, 1, 0) -- 1483
		) -- 1483
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1484
		local trail = {} -- 1487
		do -- 1487
			local i = 0 -- 1488
			while i <= idx do -- 1488
				trail[#trail + 1] = core.flight.points[i + 1] -- 1488
				i = i + 1 -- 1488
			end -- 1488
		end -- 1488
		local rings = goalRingsAt(tWorld, idx) -- 1489
		local basis = makeBasis(frame) -- 1490
		deps.trajectory:clearOrbitRing() -- 1492
		deps.plan:clearProbeOrbit() -- 1493
		deps.trajectory:setTrail(trail, basis) -- 1494
		deps.trajectory:setGoalRings(rings, basis) -- 1495
		deps.plan:clearPrediction() -- 1496
		deps.plan:setGoalRings(rings) -- 1497
		deps.plan:flush() -- 1498
	end -- 1469
	local function updateFlying(dt) -- 1500
		deps.aim:setEnabled(false) -- 1501
		local entered = ____exports.coreUpdate(core, dt, level) -- 1504
		if core.flight == nil then -- 1504
			return entered -- 1505
		end -- 1505
		local idx = ____exports.coreProbeIndex(core) -- 1507
		local pos = core.flight.points[idx + 1] -- 1508
		local tWorld = core.t0 + core.flightTime -- 1512
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1512
			lastSlowmo = core.slowmo -- 1516
			lastSlowmoBody = core.slowmoBody -- 1517
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1518
			local nearD = near ~= nil and distance( -- 1519
				pos, -- 1519
				bodyPositionAt(near, tWorld) -- 1519
			) or 0 -- 1519
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1520
		end -- 1520
		flightLogT = flightLogT + dt -- 1527
		if flightLogT >= 0.5 then -- 1527
			flightLogT = 0 -- 1529
			local total = (#core.flight.points - 1) * core.dt -- 1530
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1531
		end -- 1531
		deps.scene.syncBodies(tWorld) -- 1537
		deps.scene.syncProbe(pos) -- 1538
		if idx > 0 then -- 1538
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1540
		end -- 1540
		local fr -- 1547
		local closeDist = nil -- 1548
		if core.slowmo and core.slowmoBody >= 0 then -- 1548
			local near = level.bodies[core.slowmoBody + 1] -- 1550
			local nearR = near.radius -- 1552
			do -- 1552
				local i = 0 -- 1553
				while i < #level.bodies do -- 1553
					local b = level.bodies[i + 1] -- 1554
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1554
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1554
							nearR = deps.visuals[i + 1].displayRadius -- 1556
						end -- 1556
						break -- 1557
					end -- 1557
					i = i + 1 -- 1553
				end -- 1553
			end -- 1553
			fr = { -- 1560
				pts = { -- 1560
					pos, -- 1560
					bodyPositionAt(near, tWorld) -- 1560
				}, -- 1560
				radii = {deps.scene.probeRadius, nearR} -- 1560
			} -- 1560
			closeDist = SlowMoCloseDist -- 1561
		else -- 1561
			fr = framingPoints(pos, tWorld) -- 1563
		end -- 1563
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1565
		deps.rig.apply(deps.camera, frame) -- 1566
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1567
		local basis = makeBasis(frame) -- 1568
		local trail = {} -- 1571
		do -- 1571
			local i = 0 -- 1572
			while i <= idx do -- 1572
				trail[#trail + 1] = core.flight.points[i + 1] -- 1572
				i = i + 1 -- 1572
			end -- 1572
		end -- 1572
		local rings = goalRingsAt(tWorld, idx) -- 1573
		deps.trajectory:clearOrbitRing() -- 1575
		deps.plan:clearProbeOrbit() -- 1576
		deps.trajectory:setTrail(trail, basis) -- 1577
		deps.trajectory:setGoalRings(rings, basis) -- 1578
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1581
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1582
		deps.plan:setTrail(trail) -- 1583
		deps.plan:clearPrediction() -- 1584
		deps.plan:setGoalRings(rings) -- 1585
		deps.plan:flush() -- 1586
		return entered -- 1588
	end -- 1500
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1602
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1603
		core.t0 = next.t0 -- 1604
		clock = next.clock -- 1605
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1606
	end -- 1602
	local function update(dt) -- 1609
		applyView() -- 1612
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1612
			updateAiming(dt) -- 1614
		elseif core.phase == "Flying" then -- 1614
			local entered = updateFlying(dt) -- 1616
			if entered and core.result ~= nil then -- 1616
				local toFinale = deps.finale == true and core.result == "success" -- 1619
				if toFinale then -- 1619
					____exports.coreEnterFinale(core) -- 1620
				end -- 1620
				local telem = ____exports.calcFlightTelemetry(core, level) -- 1622
				deps:onResult(core.result, telem) -- 1623
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1623
					local ____end = #core.flight.points - 1 -- 1625
					deps:onFinale({ -- 1626
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1627
						time = core.flightTime, -- 1628
						tWorld = core.t0 + core.flightTime -- 1629
					}) -- 1629
				end -- 1629
				deps:onPhase(toFinale and "Finale" or "Result") -- 1632
			end -- 1632
		elseif core.phase == "Finale" then -- 1632
			updateFinale() -- 1635
		end -- 1635
	end -- 1609
	return { -- 1640
		phase = function() return core.phase end, -- 1641
		speedPow = function() return speedPow end, -- 1642
		speedMaxPow = function() return speedMaxPow end, -- 1643
		isPaused = function() return paused end, -- 1644
		speedRate = function() return core.playback end, -- 1645
		missionSeconds = function() -- 1646
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 1647
			return speedUnit > 0 and w / speedUnit or 0 -- 1648
		end, -- 1646
		speedUp = function() -- 1650
			if speedPow >= speedMaxPow then -- 1650
				return -- 1651
			end -- 1651
			speedPow = speedPow + 1 -- 1652
			paused = false -- 1653
			applySpeedRate() -- 1654
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1655
		end, -- 1650
		speedDown = function() -- 1657
			if speedPow <= 0 then -- 1657
				return -- 1658
			end -- 1658
			speedPow = speedPow - 1 -- 1659
			paused = false -- 1660
			applySpeedRate() -- 1661
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1662
		end, -- 1657
		togglePause = function() -- 1664
			paused = not paused -- 1665
			applySpeedRate() -- 1666
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 1667
		end, -- 1664
		result = function() return core.result end, -- 1669
		onAimDrag = function(____, a) -- 1670
			if introTourActive then -- 1670
				finishIntroTour() -- 1671
			end -- 1671
			core.aim = a -- 1672
			aimed = true -- 1673
		end, -- 1670
		aimReady = function() -- 1675
			predForce = true -- 1677
			if not ____exports.coreArm(core) then -- 1677
				return -- 1678
			end -- 1678
			applyView() -- 1679
			deps:onPhase("Armed") -- 1680
		end, -- 1675
		launchArmed = function() -- 1682
			if core.phase ~= "Armed" then -- 1682
				return -- 1684
			end -- 1684
			handoffDate(true) -- 1685
			____exports.coreLaunch( -- 1686
				core, -- 1686
				core.aim.velocity, -- 1686
				level, -- 1686
				probePos, -- 1686
				probeVel -- 1686
			) -- 1686
			deps.trajectory:clearPrediction() -- 1687
			deps.plan:clearPrediction() -- 1688
			applyView() -- 1689
			deps:onPhase("Flying") -- 1690
		end, -- 1682
		armed = function() return core.phase == "Armed" end, -- 1692
		viewMode = function() return core.viewMode end, -- 1693
		toggleViewMode = function() -- 1694
			____exports.coreToggleView(core) -- 1696
			applyView() -- 1697
		end, -- 1694
		skipIntroTour = function() -- 1699
			finishIntroTour() -- 1700
		end, -- 1699
		isIntroTourActive = function() return introTourActive end, -- 1702
		observeDrag = function(____, dx, dy) -- 1703
			if introTourActive then -- 1703
				finishIntroTour() -- 1705
				return -- 1706
			end -- 1706
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1708
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1709
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1710
			if obsPitchDeg > 40 then -- 1710
				obsPitchDeg = 40 -- 1711
			end -- 1711
			if obsPitchDeg < -40 then -- 1711
				obsPitchDeg = -40 -- 1712
			end -- 1712
		end, -- 1703
		observeZoom = function(____, deltaDist) -- 1714
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1715
			if obsZoom < 0.4 then -- 1715
				obsZoom = 0.4 -- 1716
			end -- 1716
			if obsZoom > 1.8 then -- 1716
				obsZoom = 1.8 -- 1717
			end -- 1717
		end, -- 1714
		launch = function(____, v) -- 1719
			if level.flightSpeedPow ~= nil and level.flightSpeedPow > speedPow then -- 1719
				speedPow = level.flightSpeedPow -- 1723
				paused = false -- 1724
				applySpeedRate() -- 1725
				print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 1726
			end -- 1726
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1726
				return -- 1728
			end -- 1728
			handoffDate(true) -- 1729
			____exports.coreLaunch( -- 1731
				core, -- 1731
				v, -- 1731
				level, -- 1731
				probePos, -- 1731
				probeVel -- 1731
			) -- 1731
			deps.trajectory:clearPrediction() -- 1732
			deps.plan:clearPrediction() -- 1733
			applyView() -- 1734
			deps:onPhase("Flying") -- 1735
		end, -- 1719
		retry = function() -- 1737
			if core.phase ~= "Result" then -- 1737
				return -- 1738
			end -- 1738
			handoffDate(false) -- 1739
			aimed = false -- 1740
			introTourActive = false -- 1741
			____exports.coreRetry(core, level.aimMin) -- 1742
			deps.trajectory:clearTrail() -- 1743
			deps.trajectory:clearPrediction() -- 1744
			deps.trajectory:clearGoalRings() -- 1745
			deps.plan:clearTrail() -- 1746
			deps.plan:clearPrediction() -- 1747
			deps.plan:clearGoalRings() -- 1748
			applyView() -- 1749
			deps:onPhase("Aiming") -- 1750
		end, -- 1737
		backToSelect = function() -- 1752
			if not ____exports.coreBackToSelect(core) then -- 1752
				return false -- 1753
			end -- 1753
			deps.aim:setEnabled(false) -- 1755
			deps.trajectory:clearTrail() -- 1756
			deps.trajectory:clearPrediction() -- 1757
			deps.trajectory:clearGoalRings() -- 1758
			deps.plan:clearTrail() -- 1759
			deps.plan:clearPrediction() -- 1760
			deps.plan:clearGoalRings() -- 1761
			applyView() -- 1762
			deps:onPhase("LevelSelect") -- 1763
			return true -- 1764
		end, -- 1752
		startLevel = function() -- 1766
			aimed = false -- 1767
			____exports.coreRetry(core, level.aimMin) -- 1768
			deps.rig.reset() -- 1769
			introTourActive = true -- 1771
			introTourT = 0 -- 1772
			introLogged = false -- 1773
			core.viewMode = "3D" -- 1774
			appliedMode = "" -- 1775
			applyView() -- 1776
			prepareIdle() -- 1777
			deps.trajectory:clearTrail() -- 1778
			deps.trajectory:clearPrediction() -- 1779
			deps.trajectory:clearGoalRings() -- 1780
			deps.plan:clearTrail() -- 1781
			deps.plan:clearPrediction() -- 1782
			deps.plan:clearGoalRings() -- 1783
			deps:onPhase("Aiming") -- 1784
		end, -- 1766
		stepTime = function(____, dir, span) -- 1786
			if not ____exports.coreTimeWarpAllowed(core) then -- 1786
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1790
				return -- 1791
			end -- 1791
			local span0 = span > 0 and span or 0 -- 1793
			clock = clock + dir * TimeWarpStep -- 1794
			if clock < 0 then -- 1794
				clock = 0 -- 1795
			end -- 1795
			if span0 > 0 and clock > span0 then -- 1795
				clock = span0 -- 1796
			end -- 1796
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1798
		end, -- 1786
		dateNow = function() return core.t0 + clock end, -- 1800
		setBrakeMode = function(____, on) -- 1801
			core.brakeMode = on -- 1802
		end, -- 1801
		brakeMode = function() return core.brakeMode end, -- 1805
		setPlaybackSpeed = function(____, speed) -- 1806
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1806
				return -- 1808
			end -- 1808
			core.playback = speed -- 1809
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1810
		end, -- 1806
		playbackSpeed = function() return core.playback end, -- 1812
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1813
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 1814
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 1815
		hasBraked = function() return core.hasBraked end, -- 1816
		update = function(____, frameDt) return update(frameDt) end -- 1818
	} -- 1818
end -- 925
return ____exports -- 925
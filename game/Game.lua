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
local evaluateCollectedStars = ____Gravity.evaluateCollectedStars -- 28
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
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 214
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 215
	local n = math.floor(pow) -- 216
	while n > 0 do -- 216
		rate = rate * 10 -- 218
		n = n - 1 -- 219
	end -- 219
	while n < 0 do -- 219
		rate = rate / 10 -- 222
		n = n + 1 -- 223
	end -- 223
	return rate -- 225
end -- 214
local function neutralAim(minSpeed) -- 228
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 229
end -- 228
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 233
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 234
end -- 233
function ____exports.createCore(dt, stars) -- 237
	local stList = stars ~= nil and stars or ({}) -- 238
	local colList = {} -- 239
	do -- 239
		local i = 0 -- 240
		while i < #stList do -- 240
			colList[#colList + 1] = false -- 240
			i = i + 1 -- 240
		end -- 240
	end -- 240
	return { -- 241
		phase = "Aiming", -- 242
		aim = neutralAim(AimMinSpeed), -- 243
		flight = nil, -- 244
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 245
		brakeMode = false, -- 246
		t0 = 0, -- 247
		flightTime = 0, -- 248
		goalIndex = -1, -- 249
		result = nil, -- 250
		viewMode = "2D", -- 252
		playback = FlightPlayback, -- 254
		slowmo = false, -- 255
		slowmoBody = -1, -- 256
		hasBraked = false, -- 257
		brakePointIndex = -1, -- 258
		stars = stList, -- 259
		collectedStars = colList, -- 260
		previewStarsCount = 0 -- 261
	} -- 261
end -- 237
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 273
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 274
	return core.viewMode -- 275
end -- 273
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 293
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 299
	local share = brakeMode and BrakeShare or 1 -- 300
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 301
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 302
	local brake = brakeMode and mag > 0 and ({ -- 303
		dv = mag * (1 - share), -- 304
		startStep = math.floor(maxSteps / 2) -- 304
	}) or nil -- 304
	return {init = init, brake = brake} -- 306
end -- 293
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 315
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 315
		return -- 317
	end -- 317
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 318
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 319
	local p0 = from ~= nil and from or level.probeStart -- 320
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 321
		steps = level.maxSteps, -- 324
		dt = core.dt, -- 324
		sampleEvery = 1, -- 324
		escapeRadius = level.escapeRadius, -- 324
		t0 = core.t0, -- 324
		brake = motion.brake -- 324
	}) -- 324
	core.flight = flight -- 326
	core.goalIndex = findGoalIndex( -- 327
		flight.points, -- 327
		level.bodies, -- 327
		level.goal, -- 327
		core.dt, -- 327
		core.t0, -- 327
		flight.velocities -- 327
	) -- 327
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 328
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. core.result) -- 331
	core.flightTime = 0 -- 336
	core.slowmo = false -- 338
	core.slowmoBody = -1 -- 339
	core.hasBraked = false -- 340
	core.brakePointIndex = -1 -- 341
	core.phase = "Flying" -- 342
	core.viewMode = "3D" -- 344
end -- 315
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 353
	if core.phase ~= "Aiming" then -- 353
		return false -- 354
	end -- 354
	core.phase = "Armed" -- 355
	return true -- 356
end -- 353
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 360
	if core.phase ~= "Armed" then -- 360
		return false -- 361
	end -- 361
	core.phase = "Aiming" -- 362
	return true -- 363
end -- 360
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 377
	return core.phase == "Aiming" or core.phase == "Armed" -- 378
end -- 377
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 394
	if toT0 then -- 394
		return {t0 = clock, clock = 0} -- 395
	end -- 395
	return {t0 = 0, clock = t0} -- 396
end -- 394
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 408
	local host = -1 -- 418
	do -- 418
		local i = 0 -- 419
		while i < #bodies do -- 419
			do -- 419
				local b = bodies[i + 1] -- 420
				local isHost = false -- 421
				do -- 421
					local j = 0 -- 422
					while j < #bodies do -- 422
						do -- 422
							local h = bodies[j + 1].host -- 423
							if h == nil then -- 423
								goto __continue30 -- 424
							end -- 424
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 424
								isHost = true -- 425
								break -- 425
							end -- 425
						end -- 425
						::__continue30:: -- 425
						j = j + 1 -- 422
					end -- 422
				end -- 422
				if not isHost then -- 422
					goto __continue28 -- 427
				end -- 427
				if host < 0 or b.gm > bodies[host + 1].gm then -- 427
					host = i -- 428
				end -- 428
			end -- 428
			::__continue28:: -- 428
			i = i + 1 -- 419
		end -- 419
	end -- 419
	if host >= 0 then -- 419
		return host -- 430
	end -- 430
	local best = -1 -- 432
	do -- 432
		local i = 0 -- 433
		while i < #bodies do -- 433
			do -- 433
				local b = bodies[i + 1] -- 434
				if b.orbitRadius ~= 0 then -- 434
					goto __continue37 -- 435
				end -- 435
				if best < 0 or b.gm > bodies[best + 1].gm then -- 435
					best = i -- 436
				end -- 436
			end -- 436
			::__continue37:: -- 436
			i = i + 1 -- 433
		end -- 433
	end -- 433
	return best -- 438
end -- 408
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 456
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 457
	local best = -1 -- 458
	local bestD = 1000000000 -- 459
	do -- 459
		local i = 0 -- 460
		while i < #bodies do -- 460
			do -- 460
				if i == anchor then -- 460
					goto __continue42 -- 461
				end -- 461
				local b = bodies[i + 1] -- 462
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 463
				local d = distance( -- 464
					probe, -- 464
					bodyPositionAt(b, t) -- 464
				) -- 464
				if d < threshold and d < bestD then -- 464
					bestD = d -- 466
					best = i -- 467
				end -- 467
			end -- 467
			::__continue42:: -- 467
			i = i + 1 -- 460
		end -- 460
	end -- 460
	return best -- 470
end -- 456
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 474
	if core.flight == nil then -- 474
		return 0 -- 475
	end -- 475
	local idx = math.floor(core.flightTime / core.dt) -- 476
	local last = #core.flight.points - 1 -- 477
	if idx > last then -- 477
		idx = last -- 478
	end -- 478
	if idx < 0 then -- 478
		idx = 0 -- 479
	end -- 479
	return idx -- 480
end -- 474
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
function ____exports.coreUpdate(core, dt, level) -- 497
	if core.phase ~= "Flying" or core.flight == nil then -- 497
		return false -- 498
	end -- 498
	if level ~= nil then -- 498
		local idx = ____exports.coreProbeIndex(core) -- 502
		core.slowmoBody = ____exports.slowMotionBody( -- 503
			level.bodies, -- 503
			core.flight.points[idx + 1], -- 503
			core.t0 + core.flightTime, -- 503
			____exports.anchorBodyIndex(level.bodies), -- 503
			level.slowMoFloor -- 503
		) -- 503
		core.slowmo = core.slowmoBody >= 0 -- 504
	end -- 504
	local speed = core.playback * (core.slowmo and SlowMoFactor or 1) -- 507
	core.flightTime = core.flightTime + dt * speed -- 508
	if core.stars ~= nil and #core.stars > 0 then -- 508
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 512
		do -- 512
			local s = 0 -- 513
			while s < #core.stars do -- 513
				if not core.collectedStars[s + 1] then -- 513
					local stPos = core.stars[s + 1] -- 515
					local dx = curPos.x - stPos.x -- 516
					local dy = curPos.y - stPos.y -- 517
					if dx * dx + dy * dy <= 30 * 30 then -- 517
						core.collectedStars[s + 1] = true -- 519
					end -- 519
				end -- 519
				s = s + 1 -- 513
			end -- 513
		end -- 513
	end -- 513
	local naturalEnd = #core.flight.points - 1 -- 525
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 526
	if ____exports.coreProbeIndex(core) >= endIdx then -- 526
		core.flightTime = endIdx * core.dt -- 529
		core.phase = "Result" -- 530
		return true -- 531
	end -- 531
	return false -- 533
end -- 497
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 539
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 543
	local maxSpeed = 0 -- 544
	local closestDist = 1000000000 -- 545
	local eccentricity = nil -- 546
	if core.flight ~= nil then -- 546
		local pts = core.flight.points -- 549
		local vels = core.flight.velocities -- 550
		local ____end = ____exports.coreProbeIndex(core) -- 551
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 552
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 553
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 554
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 555
		do -- 555
			local k = 0 -- 557
			while k <= ____end and k < #pts do -- 557
				local p = pts[k + 1] -- 558
				if vels ~= nil and k < #vels then -- 558
					local v = vels[k + 1] -- 560
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 561
					if spd > maxSpeed then -- 561
						maxSpeed = spd -- 562
					end -- 562
				end -- 562
				if distTargetBody ~= nil then -- 562
					local t = core.t0 + k * core.dt -- 565
					local tp = bodyPositionAt(distTargetBody, t) -- 566
					local d = distance(p, tp) -- 567
					if d < closestDist then -- 567
						closestDist = d -- 568
					end -- 568
				end -- 568
				k = k + 1 -- 557
			end -- 557
		end -- 557
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 557
			local tEnd = core.t0 + ____end * core.dt -- 573
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 574
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 575
			local rx = pts[____end + 1].x - tpEnd.x -- 576
			local ry = pts[____end + 1].y - tpEnd.y -- 577
			local vx = vels[____end + 1].x - tvEnd.x -- 578
			local vy = vels[____end + 1].y - tvEnd.y -- 579
			local r = math.sqrt(rx * rx + ry * ry) -- 580
			local v2 = vx * vx + vy * vy -- 581
			local mu = goalBody.gm -- 582
			if r > 0 and mu > 0 then -- 582
				local energy = v2 / 2 - mu / r -- 584
				local h = rx * vy - ry * vx -- 585
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 586
				if term >= 0 then -- 586
					eccentricity = math.sqrt(term) -- 588
				end -- 588
			end -- 588
		end -- 588
	end -- 588
	local starsCollectedCount = 0 -- 594
	do -- 594
		local i = 0 -- 595
		while i < #core.collectedStars do -- 595
			if core.collectedStars[i + 1] then -- 595
				starsCollectedCount = starsCollectedCount + 1 -- 596
			end -- 596
			i = i + 1 -- 595
		end -- 595
	end -- 595
	return { -- 599
		burnDv = burnDv, -- 600
		flightTime = core.flightTime, -- 601
		closestDist = closestDist < 100000000 and closestDist or 0, -- 602
		maxSpeed = maxSpeed, -- 603
		eccentricity = eccentricity, -- 604
		starsCollected = starsCollectedCount -- 605
	} -- 605
end -- 539
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 610
	core.phase = "Aiming" -- 611
	core.viewMode = "2D" -- 613
	core.flight = nil -- 614
	core.flightTime = 0 -- 615
	core.goalIndex = -1 -- 616
	core.result = nil -- 617
	core.slowmo = false -- 618
	core.slowmoBody = -1 -- 619
	core.hasBraked = false -- 620
	core.brakePointIndex = -1 -- 621
	do -- 621
		local i = 0 -- 622
		while i < #core.collectedStars do -- 622
			core.collectedStars[i + 1] = false -- 622
			i = i + 1 -- 622
		end -- 622
	end -- 622
	core.previewStarsCount = 0 -- 623
	core.aim = neutralAim(levelAimMin(aimMin)) -- 624
end -- 610
--- 判定当前飞行状态下是否处于可逆喷制动窗口。
-- 纯函数，可单测。
function ____exports.isBrakeWindowActive(core, level) -- 631
	if core.phase ~= "Flying" or core.flight == nil or core.hasBraked then -- 631
		return false -- 632
	end -- 632
	local curIdx = ____exports.coreProbeIndex(core) -- 633
	local pts = core.flight.points -- 634
	if curIdx < 0 or curIdx >= #pts then -- 634
		return false -- 635
	end -- 635
	local targetIdx = level.goal.planetIndex -- 637
	if targetIdx < 0 or targetIdx >= #level.bodies then -- 637
		return false -- 638
	end -- 638
	local targetBody = level.bodies[targetIdx + 1] -- 639
	local tNow = core.t0 + core.flightTime -- 640
	local targetPos = bodyPositionAt(targetBody, tNow) -- 641
	local dist = distance(pts[curIdx + 1], targetPos) -- 642
	local floorD = level.slowMoFloor ~= nil and level.slowMoFloor > 0 and level.slowMoFloor or SlowMoFloorDist -- 645
	local brakeDistLimit = math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD) -- 646
	return dist <= brakeDistLimit and dist > targetBody.radius -- 647
end -- 631
--- 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
-- 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
-- 返回 true 表示制动成功应用。
function ____exports.applyInFlightBrake(core, level) -- 655
	if not ____exports.isBrakeWindowActive(core, level) then -- 655
		return false -- 656
	end -- 656
	if core.flight == nil then -- 656
		return false -- 657
	end -- 657
	local curIdx = ____exports.coreProbeIndex(core) -- 659
	local curPos = core.flight.points[curIdx + 1] -- 660
	local curVel = core.flight.velocities ~= nil and curIdx < #core.flight.velocities and core.flight.velocities[curIdx + 1] or ({x = 0, y = 0}) -- 661
	local tNow = core.t0 + core.flightTime -- 664
	local targetIdx = level.goal.planetIndex -- 666
	local targetBody = level.bodies[targetIdx + 1] -- 667
	local targetPos = bodyPositionAt(targetBody, tNow) -- 668
	local targetVel = bodyVelocityAt(targetBody, tNow) -- 669
	local relVel = {x = curVel.x - targetVel.x, y = curVel.y - targetVel.y} -- 672
	local relSpeed = math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y) -- 673
	local dist = distance(curPos, targetPos) -- 674
	if relSpeed <= 0.000001 or dist <= 0.000001 then -- 674
		return false -- 676
	end -- 676
	local vCirc = math.sqrt(targetBody.gm / dist) -- 679
	local targetRelSpeed = vCirc * 0.98 -- 682
	local reductionFactor = targetRelSpeed / relSpeed -- 683
	local clampedFactor = math.min(0.95, reductionFactor) -- 684
	local newRelVel = {x = relVel.x * clampedFactor, y = relVel.y * clampedFactor} -- 686
	local newVel = {x = targetVel.x + newRelVel.x, y = targetVel.y + newRelVel.y} -- 690
	local remainingSteps = math.max(1000, level.maxSteps - curIdx) -- 696
	local postBrakeSim = simulate({pos = curPos, vel = newVel}, level.bodies, { -- 697
		steps = remainingSteps, -- 701
		dt = core.dt, -- 702
		sampleEvery = 1, -- 703
		escapeRadius = level.escapeRadius, -- 704
		t0 = tNow -- 705
	}) -- 705
	local mergedPoints = __TS__ArraySlice(core.flight.points, 0, curIdx) -- 710
	do -- 710
		local i = 0 -- 711
		while i < #postBrakeSim.points do -- 711
			mergedPoints[#mergedPoints + 1] = postBrakeSim.points[i + 1] -- 712
			i = i + 1 -- 711
		end -- 711
	end -- 711
	local mergedVelocities = __TS__ArraySlice(core.flight.velocities or ({}), 0, curIdx) -- 714
	if postBrakeSim.velocities ~= nil then -- 714
		do -- 714
			local i = 0 -- 716
			while i < #postBrakeSim.velocities do -- 716
				mergedVelocities[#mergedVelocities + 1] = postBrakeSim.velocities[i + 1] -- 717
				i = i + 1 -- 716
			end -- 716
		end -- 716
	end -- 716
	core.flight = { -- 721
		outcome = postBrakeSim.outcome, -- 722
		points = mergedPoints, -- 723
		velocities = mergedVelocities, -- 724
		state = postBrakeSim.state, -- 725
		hitIndex = postBrakeSim.hitIndex, -- 726
		stepsRun = curIdx + postBrakeSim.stepsRun -- 727
	} -- 727
	core.hasBraked = true -- 730
	core.brakePointIndex = curIdx -- 731
	core.goalIndex = findGoalIndex( -- 734
		mergedPoints, -- 734
		level.bodies, -- 734
		level.goal, -- 734
		core.dt, -- 734
		core.t0, -- 734
		mergedVelocities -- 734
	) -- 734
	core.result = ____exports.resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal) -- 735
	print((((((((((("[escape-velocity] in-flight brake applied at t=" .. __TS__NumberToFixed(tNow, 2)) .. " curIdx=") .. __TS__NumberToFixed(curIdx, 0)) .. " relSpeed=") .. __TS__NumberToFixed(relSpeed, 3)) .. " -> ") .. __TS__NumberToFixed( -- 737
		math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y), -- 739
		3 -- 739
	)) .. " vCirc=") .. __TS__NumberToFixed(vCirc, 3)) .. " result=") .. core.result) -- 739
	return true -- 743
end -- 655
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 757
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 757
		return false -- 759
	end -- 759
	core.phase = "LevelSelect" -- 760
	core.viewMode = "2D" -- 762
	core.flight = nil -- 763
	core.flightTime = 0 -- 764
	core.goalIndex = -1 -- 765
	core.result = nil -- 766
	core.slowmo = false -- 767
	core.slowmoBody = -1 -- 768
	return true -- 769
end -- 757
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 798
	if core.phase ~= "Result" then -- 798
		return false -- 799
	end -- 799
	core.phase = "Finale" -- 800
	return true -- 801
end -- 798
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 819
	local dist = distance > 1 and distance or 1 -- 820
	local ux = probe.x -- 822
	local uy = probe.y -- 823
	local len = math.sqrt(ux * ux + uy * uy) -- 824
	if len < 0.000001 then -- 824
		ux = 0 -- 825
		uy = 1 -- 825
	else -- 825
		ux = ux / len -- 825
		uy = uy / len -- 825
	end -- 825
	local tilt = tiltDeg * math.pi / 180 -- 826
	local flat = math.cos(tilt) * dist -- 827
	return { -- 828
		target = Vec3(0, 0, 0), -- 830
		eye = Vec3( -- 831
			ux * flat * PlaneToWorldX, -- 831
			math.sin(tilt) * dist, -- 831
			uy * flat * PlaneToWorldZ -- 831
		) -- 831
	} -- 831
end -- 819
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 969
	local introTourActive, introTourT -- 969
	local core = ____exports.createCore(level.physicsStep, level.stars) -- 970
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 976
	local paused = false -- 977
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 978
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 980
	local function applySpeedRate() -- 981
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 982
	end -- 981
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 995
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 995
			return -- 996
		end -- 996
		speedPow = level.flightSpeedPow -- 997
		paused = false -- 998
		applySpeedRate() -- 999
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 1000
	end -- 995
	applySpeedRate() -- 1006
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 1009
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
	local function applyView() -- 1024
		local mode = core.viewMode -- 1025
		if mode == appliedMode then -- 1025
			return -- 1026
		end -- 1026
		appliedMode = mode -- 1027
		local is2D = mode == "2D" -- 1028
		deps.plan:setVisible(is2D) -- 1029
		deps.trajectory.root.visible = not is2D -- 1030
		deps:setWorldVisible(not is2D) -- 1031
		deps.aim:setFullScreenAim(is2D) -- 1032
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 1033
	end -- 1024
	local ____temp_0 -- 1036
	if level.mission ~= nil then -- 1036
		____temp_0 = level.mission.introTour -- 1036
	else -- 1036
		____temp_0 = nil -- 1036
	end -- 1036
	local tourDef = ____temp_0 -- 1036
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 1037
	local function finishIntroTour() -- 1039
		if not introTourActive then -- 1039
			return -- 1040
		end -- 1040
		introTourActive = false -- 1041
		introTourT = tourDuration -- 1042
		core.viewMode = "2D" -- 1043
		applyView() -- 1044
		deps.aim:setIntroTourBannerVisible(false) -- 1045
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1046
	end -- 1039
	local function makeBasis(frame) -- 1049
		return prepareCamera({ -- 1050
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1052
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1053
			up = {x = 0, y = 1, z = 0}, -- 1054
			fovYDeg = deps.fovYDeg, -- 1055
			aspect = deps.aspect, -- 1056
			viewW = deps.viewW, -- 1057
			viewH = deps.viewH -- 1058
		}, HANDEDNESS, FLIP_Y) -- 1058
	end -- 1049
	local PredMinIntervalSec = 0.08 -- 1070
	local predAimKey = "" -- 1071
	local predPosKey = "" -- 1072
	local predAccum = 1 -- 1073
	local predForce = true -- 1074
	local predPoints = {} -- 1075
	introTourActive = false -- 1077
	introTourT = tourDuration -- 1078
	local introLogged = false -- 1079
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1081
	local clock = 0 -- 1087
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1089
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1091
	local obsYawDeg = 0 -- 1095
	local obsPitchDeg = 0 -- 1096
	local obsZoom = 1 -- 1097
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1099
	local idleOrbit = nil -- 1101
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1112
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1114
	local lastSlowmoBody = -1 -- 1115
	local flightLogT = 0 -- 1116
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1118
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1119
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
	local function prepareIdle() -- 1134
		clock = 0 -- 1136
		core.t0 = 0 -- 1137
		idleOrbit = nil -- 1138
		if level.probeVel0 == nil then -- 1138
			return -- 1139
		end -- 1139
		local hostIndex = -1 -- 1141
		local bestD = 1000000000 -- 1142
		do -- 1142
			local i = 0 -- 1143
			while i < #level.bodies do -- 1143
				do -- 1143
					local b = level.bodies[i + 1] -- 1144
					if b.gm <= 0 then -- 1144
						goto __continue107 -- 1145
					end -- 1145
					local d = distance( -- 1146
						bodyPositionAt(b, 0), -- 1146
						level.probeStart -- 1146
					) -- 1146
					if d < bestD then -- 1146
						bestD = d -- 1148
						hostIndex = i -- 1149
					end -- 1149
				end -- 1149
				::__continue107:: -- 1149
				i = i + 1 -- 1143
			end -- 1143
		end -- 1143
		if hostIndex < 0 or bestD < 1e-9 then -- 1143
			return -- 1152
		end -- 1152
		local host = level.bodies[hostIndex + 1] -- 1153
		local hp = bodyPositionAt(host, 0) -- 1154
		local hv = bodyVelocityAt(host, 0) -- 1155
		local rx = level.probeStart.x - hp.x -- 1157
		local ry = level.probeStart.y - hp.y -- 1158
		local vx = level.probeVel0.x - hv.x -- 1159
		local vy = level.probeVel0.y - hv.y -- 1160
		local r = math.sqrt(rx * rx + ry * ry) -- 1161
		if r < 1e-12 then -- 1161
			return -- 1162
		end -- 1162
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1164
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1165
		idleOrbit = { -- 1166
			hostIndex = hostIndex, -- 1166
			r = r, -- 1166
			phase0 = math.atan(ry, rx), -- 1166
			omega = dir * omega -- 1166
		} -- 1166
	end -- 1134
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1170
		if idleOrbit == nil then -- 1170
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1172
		end -- 1172
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1177
		local hp = bodyPositionAt(host, tWorld) -- 1178
		local hv = bodyVelocityAt(host, tWorld) -- 1179
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1180
		local ca = math.cos(a) -- 1181
		local sa = math.sin(a) -- 1182
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1183
	end -- 1170
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1200
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1201
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1204
		local wps = goalWaypoints(level.goal) -- 1205
		if #wps == 0 then -- 1205
			return nil -- 1206
		end -- 1206
		local passed = 0 -- 1207
		if core.flight ~= nil then -- 1207
			local upto = math.floor(core.flightTime / core.dt) -- 1209
			passed = waypointProgress( -- 1210
				core.flight.points, -- 1210
				level.bodies, -- 1210
				level.goal, -- 1210
				core.dt, -- 1210
				core.t0, -- 1210
				upto, -- 1210
				core.flight.velocities -- 1210
			).passed -- 1210
		end -- 1210
		if passed >= #wps then -- 1210
			return nil -- 1212
		end -- 1212
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1213
	end -- 1204
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1224
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1224
			local hr = anchorDef.radius -- 1228
			do -- 1228
				local i = 0 -- 1229
				while i < #level.bodies do -- 1229
					local b = level.bodies[i + 1] -- 1230
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1230
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1230
							hr = deps.visuals[i + 1].displayRadius -- 1232
						end -- 1232
						break -- 1233
					end -- 1233
					i = i + 1 -- 1229
				end -- 1229
			end -- 1229
			return { -- 1236
				pts = { -- 1236
					probe, -- 1236
					bodyPositionAt(anchorDef, t) -- 1236
				}, -- 1236
				radii = {deps.scene.probeRadius, hr} -- 1236
			} -- 1236
		end -- 1236
		local corePts = {probe} -- 1240
		local coreRadii = {deps.scene.probeRadius} -- 1241
		local next = nextStationBody() -- 1242
		local nextTol = 0 -- 1243
		if next ~= nil then -- 1243
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1245
			local wps = goalWaypoints(level.goal) -- 1246
			local passed = 0 -- 1247
			if core.flight ~= nil then -- 1247
				passed = waypointProgress( -- 1249
					core.flight.points, -- 1249
					level.bodies, -- 1249
					level.goal, -- 1249
					core.dt, -- 1249
					core.t0, -- 1249
					math.floor(core.flightTime / core.dt), -- 1249
					core.flight.velocities -- 1249
				).passed -- 1249
			end -- 1249
			if passed < #wps then -- 1249
				nextTol = wps[passed + 1].tolerance -- 1251
			end -- 1251
			local r = nextTol > next.radius and nextTol or next.radius -- 1252
			coreRadii[#coreRadii + 1] = r -- 1253
		end -- 1253
		if anchorDef == nil then -- 1253
			return {pts = corePts, radii = coreRadii} -- 1256
		end -- 1256
		local anchorR = anchorDef.radius -- 1261
		do -- 1261
			local i = 0 -- 1262
			while i < #level.bodies do -- 1262
				local b = level.bodies[i + 1] -- 1263
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1263
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1263
						anchorR = deps.visuals[i + 1].displayRadius -- 1265
					end -- 1265
					break -- 1266
				end -- 1266
				i = i + 1 -- 1262
			end -- 1262
		end -- 1262
		local withAnchorPts = { -- 1269
			probe, -- 1269
			bodyPositionAt(anchorDef, t) -- 1269
		} -- 1269
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1270
		do -- 1270
			local i = 1 -- 1271
			while i < #corePts do -- 1271
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1272
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1273
				i = i + 1 -- 1271
			end -- 1271
		end -- 1271
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1275
		if want <= CameraFramingBudget then -- 1275
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1276
		end -- 1276
		return {pts = corePts, radii = coreRadii} -- 1277
	end -- 1224
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1281
		local wps = goalWaypoints(level.goal) -- 1282
		if #wps == 0 then -- 1282
			return {} -- 1283
		end -- 1283
		local passed = 0 -- 1284
		if upto ~= nil and core.flight ~= nil then -- 1284
			passed = waypointProgress( -- 1286
				core.flight.points, -- 1286
				level.bodies, -- 1286
				level.goal, -- 1286
				core.dt, -- 1286
				core.t0, -- 1286
				upto, -- 1286
				core.flight.velocities -- 1286
			).passed -- 1286
		end -- 1286
		if passed >= #wps then -- 1286
			return {} -- 1291
		end -- 1291
		local nextWp = wps[passed + 1] -- 1292
		local body = level.bodies[nextWp.planetIndex + 1] -- 1293
		if body == nil then -- 1293
			return {} -- 1294
		end -- 1294
		return {{ -- 1295
			center = bodyPositionAt(body, t), -- 1295
			radius = nextWp.tolerance, -- 1295
			passed = false -- 1295
		}} -- 1295
	end -- 1281
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1299
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1299
			return f -- 1300
		end -- 1300
		local dx = f.eye.x - f.target.x -- 1301
		local dy = f.eye.y - f.target.y -- 1302
		local dz = f.eye.z - f.target.z -- 1303
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1304
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1305
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1306
		local lo = CameraTiltMin * math.pi / 180 -- 1307
		local hi = CameraTiltMax * math.pi / 180 -- 1308
		if pitch < lo then -- 1308
			pitch = lo -- 1309
		end -- 1309
		if pitch > hi then -- 1309
			pitch = hi -- 1310
		end -- 1310
		local cp = math.cos(pitch) -- 1311
		return { -- 1312
			target = f.target, -- 1313
			eye = Vec3( -- 1314
				f.target.x + r * cp * math.sin(yaw), -- 1315
				f.target.y + r * math.sin(pitch), -- 1316
				f.target.z + r * cp * math.cos(yaw) -- 1317
			) -- 1317
		} -- 1317
	end -- 1299
	local function updateAiming(dt) -- 1322
		deps.aim:setEnabled(true) -- 1323
		local dragging = deps.aim:isDragging() -- 1325
		if (core.phase == "Aiming" or core.phase == "Armed") and not dragging and idleOrbit ~= nil then -- 1325
			clock = clock + dt * core.playback -- 1339
			orbitClock = orbitClock + dt * core.playback -- 1340
		end -- 1340
		local tNow = core.t0 + clock -- 1342
		local idleState = idleProbeAt(tNow) -- 1344
		probePos = idleState.pos -- 1345
		probeVel = idleState.vel -- 1346
		deps.scene.syncBodies(tNow) -- 1348
		deps.scene.syncProbe(probePos) -- 1349
		if idleOrbit ~= nil then -- 1349
			deps.scene.faceVelocity(probeVel) -- 1350
		end -- 1350
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1352
		deps.plan:syncProbe(probePos, probeVel) -- 1353
		local fr = framingPoints(probePos, tNow) -- 1356
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1357
		if frameLogged < 6 then -- 1357
			frameLogged = frameLogged + 1 -- 1361
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1362
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1366
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1367
				__TS__ArrayMap( -- 1373
					fr.pts, -- 1373
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1373
				), -- 1373
				" " -- 1373
			)) .. "]") -- 1373
		end -- 1373
		if introTourActive and introTourT < tourDuration then -- 1373
			introTourT = introTourT + dt -- 1377
			local k = introTourT / tourDuration -- 1378
			if k >= 1 then -- 1378
				finishIntroTour() -- 1380
			else -- 1380
				if k >= 0.95 and not introLogged then -- 1380
					introLogged = true -- 1383
					print("[escape-velocity] intro camera finishing") -- 1384
				end -- 1384
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1384
					local elapsed = introTourT -- 1388
					local segIndex = 0 -- 1389
					local segStart = 0 -- 1390
					do -- 1390
						local s = 0 -- 1391
						while s < #tourDef.segments do -- 1391
							local seg = tourDef.segments[s + 1] -- 1392
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1392
								segIndex = s -- 1394
								break -- 1395
							end -- 1395
							elapsed = elapsed - seg.duration -- 1397
							segStart = segStart + seg.duration -- 1398
							s = s + 1 -- 1391
						end -- 1391
					end -- 1391
					local curSeg = tourDef.segments[segIndex + 1] -- 1400
					local segK = math.max( -- 1401
						0, -- 1401
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1401
					) -- 1401
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1403
					deps.aim:setIntroTourBannerVisible(true) -- 1404
					local pwProbe = planeToWorld(probePos, 0) -- 1406
					local function getTargetPosAndDist(targetIdx, userDist) -- 1407
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1407
							local b = level.bodies[targetIdx + 1] -- 1409
							local isMicro = b.orbitRadius < 2 -- 1410
							local p = planeToWorld( -- 1411
								bodyPositionAt(b, tNow), -- 1411
								0 -- 1411
							) -- 1411
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1412
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1413
						end -- 1413
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1415
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1416
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1417
					end -- 1407
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1420
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1421
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1422
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1424
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1425
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1426
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1427
					if segIndex == 0 then -- 1427
						local az = curAz + segK * (18 * math.pi / 180) -- 1431
						local tilt = curTilt -- 1432
						local d = curKey.dist -- 1433
						local eye = Vec3( -- 1434
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1435
							curKey.pos.y + math.sin(tilt) * d, -- 1436
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1437
						) -- 1437
						frame = {target = curKey.pos, eye = eye} -- 1439
					else -- 1439
						local ease = segK * segK * (3 - 2 * segK) -- 1442
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1443
						local az = prevAz + (curAz - prevAz) * ease -- 1448
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1449
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1450
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1451
						local eye = Vec3( -- 1452
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1453
							target.y + math.sin(tilt) * d, -- 1454
							target.z + math.cos(az) * math.cos(tilt) * d -- 1455
						) -- 1455
						frame = {target = target, eye = eye} -- 1457
					end -- 1457
				else -- 1457
					local targetBody = nil -- 1460
					local wps = goalWaypoints(level.goal) -- 1461
					if #wps > 0 then -- 1461
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1463
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1463
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1465
					end -- 1465
					if targetBody == nil and #level.bodies > 0 then -- 1465
						targetBody = level.bodies[#level.bodies] -- 1468
					end -- 1468
					if targetBody ~= nil then -- 1468
						local pwTarget = planeToWorld( -- 1472
							bodyPositionAt(targetBody, tNow), -- 1472
							0 -- 1472
						) -- 1472
						local pwProbe = planeToWorld(probePos, 0) -- 1473
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1474
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1475
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1476
						if k < 0.35 then -- 1476
							local e1 = k / 0.35 -- 1479
							local az = (0.2 + e1 * 0.15) * math.pi -- 1480
							local tilt = 0.35 * math.pi -- 1481
							local eye = Vec3( -- 1482
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1483
								pwTarget.y + math.sin(tilt) * distTarget, -- 1484
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1485
							) -- 1485
							frame = {target = pwTarget, eye = eye} -- 1487
						elseif k < 0.72 then -- 1487
							local e2 = (k - 0.35) / 0.37 -- 1489
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1490
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1491
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1492
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1493
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1494
							local eye = Vec3( -- 1499
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1500
								targetCenter.y + curDist * 0.8, -- 1501
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1502
							) -- 1502
							frame = {target = targetCenter, eye = eye} -- 1504
						else -- 1504
							local e3 = (k - 0.72) / 0.28 -- 1506
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1507
							local az = 0.25 * math.pi -- 1508
							local tilt = 0.36 * math.pi -- 1509
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1510
							local eye = Vec3( -- 1511
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1512
								pwProbe.y + math.sin(tilt) * curDist, -- 1513
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1514
							) -- 1514
							frame = {target = pwProbe, eye = eye} -- 1516
						end -- 1516
					end -- 1516
				end -- 1516
			end -- 1516
		end -- 1516
		frame = applyObserve(frame) -- 1523
		deps.rig.apply(deps.camera, frame) -- 1524
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1525
		local basis = makeBasis(frame) -- 1526
		if core.viewMode == "2D" then -- 1526
			local sp = deps.plan:probeScreen() -- 1532
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1533
		else -- 1533
			local pp = projectPrepared( -- 1535
				planeToWorld(probePos, 0), -- 1535
				basis -- 1535
			) -- 1535
			if pp ~= nil then -- 1535
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1536
			end -- 1536
		end -- 1536
		if not aimed then -- 1536
			deps.trajectory:clearPrediction() -- 1549
			deps.plan:clearPrediction() -- 1550
			predForce = true -- 1551
		else -- 1551
			local aimKey = (((__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4)) .. "|") .. (core.brakeMode and "B" or "C") -- 1557
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1558
			predAccum = predAccum + dt -- 1559
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1560
			if needIt then -- 1560
				predForce = false -- 1562
				predAccum = 0 -- 1563
				predAimKey = aimKey -- 1564
				predPosKey = posKey -- 1565
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 1568
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1569
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1572
					dt = core.dt, -- 1572
					sampleEvery = 4, -- 1572
					escapeRadius = level.escapeRadius, -- 1572
					t0 = tNow, -- 1572
					brake = motion.brake -- 1572
				}).points -- 1572
			end -- 1572
			deps.trajectory:setPrediction(predPoints, basis) -- 1575
			deps.plan:setPrediction(predPoints) -- 1577
			if #core.stars > 0 then -- 1577
				local stEval = evaluateCollectedStars(predPoints, core.stars, 30) -- 1580
				core.previewStarsCount = stEval.count -- 1581
				deps.plan:setStars(core.stars, stEval.collected) -- 1582
			end -- 1582
		end -- 1582
		if idleOrbit ~= nil then -- 1582
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1587
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1588
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1589
		end -- 1589
		local rings = goalRingsAt(tNow) -- 1591
		deps.trajectory:setGoalRings(rings, basis) -- 1592
		deps.trajectory:clearTrail() -- 1593
		deps.plan:setGoalRings(rings) -- 1595
		deps.plan:clearTrail() -- 1596
		deps.plan:flush() -- 1597
	end -- 1322
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
	local function updateFinale() -- 1612
		deps.aim:setEnabled(false) -- 1613
		if core.flight == nil then -- 1613
			return -- 1614
		end -- 1614
		local idx = ____exports.coreProbeIndex(core) -- 1615
		local pos = core.flight.points[idx + 1] -- 1616
		local tWorld = core.t0 + core.flightTime -- 1617
		deps.scene.syncBodies(tWorld) -- 1620
		deps.scene.syncProbe(pos) -- 1621
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1622
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1625
		deps.camera:lookAt( -- 1626
			frame.eye, -- 1626
			frame.target, -- 1626
			Vec3(0, 1, 0) -- 1626
		) -- 1626
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1627
		local trail = {} -- 1630
		do -- 1630
			local i = 0 -- 1631
			while i <= idx do -- 1631
				trail[#trail + 1] = core.flight.points[i + 1] -- 1631
				i = i + 1 -- 1631
			end -- 1631
		end -- 1631
		local rings = goalRingsAt(tWorld, idx) -- 1632
		local basis = makeBasis(frame) -- 1633
		deps.trajectory:clearOrbitRing() -- 1635
		deps.plan:clearProbeOrbit() -- 1636
		deps.trajectory:setTrail(trail, basis) -- 1637
		deps.trajectory:setGoalRings(rings, basis) -- 1638
		deps.plan:clearPrediction() -- 1639
		deps.plan:setGoalRings(rings) -- 1640
		deps.plan:flush() -- 1641
	end -- 1612
	local function updateFlying(dt) -- 1643
		deps.aim:setEnabled(false) -- 1644
		local entered = ____exports.coreUpdate(core, dt, level) -- 1647
		if core.flight == nil then -- 1647
			return entered -- 1648
		end -- 1648
		local idx = ____exports.coreProbeIndex(core) -- 1650
		local pos = core.flight.points[idx + 1] -- 1651
		local tWorld = core.t0 + core.flightTime -- 1655
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1655
			lastSlowmo = core.slowmo -- 1659
			lastSlowmoBody = core.slowmoBody -- 1660
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1661
			local nearD = near ~= nil and distance( -- 1662
				pos, -- 1662
				bodyPositionAt(near, tWorld) -- 1662
			) or 0 -- 1662
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1663
		end -- 1663
		flightLogT = flightLogT + dt -- 1670
		if flightLogT >= 0.5 then -- 1670
			flightLogT = 0 -- 1672
			local total = (#core.flight.points - 1) * core.dt -- 1673
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed(core.playback * (core.slowmo and SlowMoFactor or 1), 2)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1674
		end -- 1674
		deps.scene.syncBodies(tWorld) -- 1680
		deps.scene.syncProbe(pos) -- 1681
		if idx > 0 then -- 1681
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1683
		end -- 1683
		do -- 1683
			local s = 0 -- 1687
			while s < #core.stars do -- 1687
				if not core.collectedStars[s + 1] then -- 1687
					local stPos = core.stars[s + 1] -- 1689
					local dx = pos.x - stPos.x -- 1690
					local dy = pos.y - stPos.y -- 1691
					if dx * dx + dy * dy <= 30 * 30 then -- 1691
						core.collectedStars[s + 1] = true -- 1693
						if deps.scene.setStarCollected ~= nil then -- 1693
							deps.scene.setStarCollected(s) -- 1695
						end -- 1695
						deps.plan:setStars(core.stars, core.collectedStars) -- 1697
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1698
					end -- 1698
				end -- 1698
				s = s + 1 -- 1687
			end -- 1687
		end -- 1687
		local fr -- 1707
		local closeDist = nil -- 1708
		if core.slowmo and core.slowmoBody >= 0 then -- 1708
			local near = level.bodies[core.slowmoBody + 1] -- 1710
			local nearR = near.radius -- 1712
			do -- 1712
				local i = 0 -- 1713
				while i < #level.bodies do -- 1713
					local b = level.bodies[i + 1] -- 1714
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1714
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1714
							nearR = deps.visuals[i + 1].displayRadius -- 1716
						end -- 1716
						break -- 1717
					end -- 1717
					i = i + 1 -- 1713
				end -- 1713
			end -- 1713
			fr = { -- 1720
				pts = { -- 1720
					pos, -- 1720
					bodyPositionAt(near, tWorld) -- 1720
				}, -- 1720
				radii = {deps.scene.probeRadius, nearR} -- 1720
			} -- 1720
			closeDist = SlowMoCloseDist -- 1721
		else -- 1721
			fr = framingPoints(pos, tWorld) -- 1723
		end -- 1723
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1725
		deps.rig.apply(deps.camera, frame) -- 1726
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1727
		local basis = makeBasis(frame) -- 1728
		local trail = {} -- 1731
		do -- 1731
			local i = 0 -- 1732
			while i <= idx do -- 1732
				trail[#trail + 1] = core.flight.points[i + 1] -- 1732
				i = i + 1 -- 1732
			end -- 1732
		end -- 1732
		local rings = goalRingsAt(tWorld, idx) -- 1733
		deps.trajectory:clearOrbitRing() -- 1735
		deps.plan:clearProbeOrbit() -- 1736
		deps.trajectory:setTrail(trail, basis) -- 1737
		deps.trajectory:setGoalRings(rings, basis) -- 1738
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1741
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1742
		deps.plan:setTrail(trail) -- 1743
		deps.plan:clearPrediction() -- 1744
		deps.plan:setGoalRings(rings) -- 1745
		deps.plan:flush() -- 1746
		return entered -- 1748
	end -- 1643
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1762
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1763
		core.t0 = next.t0 -- 1764
		clock = next.clock -- 1765
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1766
	end -- 1762
	local function update(dt) -- 1769
		applyView() -- 1772
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1772
			updateAiming(dt) -- 1774
		elseif core.phase == "Flying" then -- 1774
			local entered = updateFlying(dt) -- 1776
			if entered and core.result ~= nil then -- 1776
				local toFinale = deps.finale == true and core.result == "success" -- 1779
				if toFinale then -- 1779
					____exports.coreEnterFinale(core) -- 1780
				end -- 1780
				local telem = ____exports.calcFlightTelemetry(core, level) -- 1782
				deps:onResult(core.result, telem) -- 1783
				if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1783
					local ____end = #core.flight.points - 1 -- 1785
					deps:onFinale({ -- 1786
						distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1787
						time = core.flightTime, -- 1788
						tWorld = core.t0 + core.flightTime -- 1789
					}) -- 1789
				end -- 1789
				deps:onPhase(toFinale and "Finale" or "Result") -- 1792
			end -- 1792
		elseif core.phase == "Finale" then -- 1792
			updateFinale() -- 1795
		end -- 1795
	end -- 1769
	return { -- 1800
		phase = function() return core.phase end, -- 1801
		speedPow = function() return speedPow end, -- 1802
		speedMaxPow = function() return speedMaxPow end, -- 1803
		isPaused = function() return paused end, -- 1804
		speedRate = function() return core.playback end, -- 1805
		missionSeconds = function() -- 1806
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 1807
			return speedUnit > 0 and w / speedUnit or 0 -- 1808
		end, -- 1806
		speedUp = function() -- 1810
			if speedPow >= speedMaxPow then -- 1810
				return -- 1811
			end -- 1811
			speedPow = speedPow + 1 -- 1812
			paused = false -- 1813
			applySpeedRate() -- 1814
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1815
		end, -- 1810
		speedDown = function() -- 1817
			if speedPow <= 0 then -- 1817
				return -- 1818
			end -- 1818
			speedPow = speedPow - 1 -- 1819
			paused = false -- 1820
			applySpeedRate() -- 1821
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1822
		end, -- 1817
		togglePause = function() -- 1824
			paused = not paused -- 1825
			applySpeedRate() -- 1826
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 1827
		end, -- 1824
		result = function() return core.result end, -- 1829
		onAimDrag = function(____, a) -- 1830
			if introTourActive then -- 1830
				finishIntroTour() -- 1831
			end -- 1831
			core.aim = a -- 1832
			aimed = true -- 1833
		end, -- 1830
		aimReady = function() -- 1835
			predForce = true -- 1837
			if not ____exports.coreArm(core) then -- 1837
				return -- 1838
			end -- 1838
			applyView() -- 1839
			deps:onPhase("Armed") -- 1840
		end, -- 1835
		launchArmed = function() -- 1842
			if core.phase ~= "Armed" then -- 1842
				return -- 1844
			end -- 1844
			applyFlightSpeed() -- 1845
			handoffDate(true) -- 1846
			____exports.coreLaunch( -- 1847
				core, -- 1847
				core.aim.velocity, -- 1847
				level, -- 1847
				probePos, -- 1847
				probeVel -- 1847
			) -- 1847
			deps.trajectory:clearPrediction() -- 1848
			deps.plan:clearPrediction() -- 1849
			applyView() -- 1850
			deps:onPhase("Flying") -- 1851
		end, -- 1842
		armed = function() return core.phase == "Armed" end, -- 1853
		viewMode = function() return core.viewMode end, -- 1854
		toggleViewMode = function() -- 1855
			____exports.coreToggleView(core) -- 1857
			applyView() -- 1858
		end, -- 1855
		skipIntroTour = function() -- 1860
			finishIntroTour() -- 1861
		end, -- 1860
		isIntroTourActive = function() return introTourActive end, -- 1863
		observeDrag = function(____, dx, dy) -- 1864
			if introTourActive then -- 1864
				finishIntroTour() -- 1866
				return -- 1867
			end -- 1867
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 1869
			obsYawDeg = obsYawDeg + dx * 0.35 -- 1870
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 1871
			if obsPitchDeg > 40 then -- 1871
				obsPitchDeg = 40 -- 1872
			end -- 1872
			if obsPitchDeg < -40 then -- 1872
				obsPitchDeg = -40 -- 1873
			end -- 1873
		end, -- 1864
		observeZoom = function(____, deltaDist) -- 1875
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 1876
			if obsZoom < 0.4 then -- 1876
				obsZoom = 0.4 -- 1877
			end -- 1877
			if obsZoom > 1.8 then -- 1877
				obsZoom = 1.8 -- 1878
			end -- 1878
		end, -- 1875
		launch = function(____, v) -- 1880
			applyFlightSpeed() -- 1881
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 1881
				return -- 1882
			end -- 1882
			handoffDate(true) -- 1883
			____exports.coreLaunch( -- 1885
				core, -- 1885
				v, -- 1885
				level, -- 1885
				probePos, -- 1885
				probeVel -- 1885
			) -- 1885
			deps.trajectory:clearPrediction() -- 1886
			deps.plan:clearPrediction() -- 1887
			applyView() -- 1888
			deps:onPhase("Flying") -- 1889
		end, -- 1880
		retry = function() -- 1891
			handoffDate(false) -- 1892
			aimed = false -- 1893
			introTourActive = false -- 1894
			____exports.coreRetry(core, level.aimMin) -- 1895
			if deps.scene.resetStars ~= nil then -- 1895
				deps.scene.resetStars() -- 1897
			end -- 1897
			deps.plan:setStars(core.stars, core.collectedStars) -- 1899
			deps.trajectory:clearTrail() -- 1900
			deps.trajectory:clearPrediction() -- 1901
			deps.trajectory:clearGoalRings() -- 1902
			deps.plan:clearTrail() -- 1903
			deps.plan:clearPrediction() -- 1904
			deps.plan:clearGoalRings() -- 1905
			applyView() -- 1906
			deps:onPhase("Aiming") -- 1907
		end, -- 1891
		backToSelect = function() -- 1909
			if not ____exports.coreBackToSelect(core) then -- 1909
				return false -- 1910
			end -- 1910
			deps.aim:setEnabled(false) -- 1912
			deps.trajectory:clearTrail() -- 1913
			deps.trajectory:clearPrediction() -- 1914
			deps.trajectory:clearGoalRings() -- 1915
			deps.plan:clearTrail() -- 1916
			deps.plan:clearPrediction() -- 1917
			deps.plan:clearGoalRings() -- 1918
			applyView() -- 1919
			deps:onPhase("LevelSelect") -- 1920
			return true -- 1921
		end, -- 1909
		startLevel = function() -- 1923
			aimed = false -- 1924
			____exports.coreRetry(core, level.aimMin) -- 1925
			if deps.scene.resetStars ~= nil then -- 1925
				deps.scene.resetStars() -- 1927
			end -- 1927
			deps.plan:setStars(core.stars, core.collectedStars) -- 1929
			deps.rig.reset() -- 1930
			introTourActive = false -- 1932
			core.viewMode = "2D" -- 1933
			appliedMode = "" -- 1934
			applyView() -- 1935
			prepareIdle() -- 1936
			deps.trajectory:clearTrail() -- 1937
			deps.trajectory:clearPrediction() -- 1938
			deps.trajectory:clearGoalRings() -- 1939
			deps.plan:clearTrail() -- 1940
			deps.plan:clearPrediction() -- 1941
			deps.plan:clearGoalRings() -- 1942
			deps:onPhase("Aiming") -- 1943
		end, -- 1923
		stepTime = function(____, dir, span) -- 1945
			if not ____exports.coreTimeWarpAllowed(core) then -- 1945
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 1949
				return -- 1950
			end -- 1950
			local span0 = span > 0 and span or 0 -- 1952
			clock = clock + dir * TimeWarpStep -- 1953
			if clock < 0 then -- 1953
				clock = 0 -- 1954
			end -- 1954
			if span0 > 0 and clock > span0 then -- 1954
				clock = span0 -- 1955
			end -- 1955
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 1957
		end, -- 1945
		dateNow = function() return core.t0 + clock end, -- 1959
		setBrakeMode = function(____, on) -- 1960
			core.brakeMode = on -- 1961
		end, -- 1960
		brakeMode = function() return core.brakeMode end, -- 1964
		setPlaybackSpeed = function(____, speed) -- 1965
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 1965
				return -- 1967
			end -- 1967
			core.playback = speed -- 1968
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 1969
		end, -- 1965
		playbackSpeed = function() return core.playback end, -- 1971
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 1972
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 1973
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 1974
		hasBraked = function() return core.hasBraked end, -- 1975
		update = function(____, frameDt) return update(frameDt) end -- 1977
	} -- 1977
end -- 969
return ____exports -- 969
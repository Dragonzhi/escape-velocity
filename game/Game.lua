-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local __TS__ArrayPush = ____lualib.__TS__ArrayPush -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__SparseArrayNew = ____lualib.__TS__SparseArrayNew -- 1
local __TS__SparseArrayPush = ____lualib.__TS__SparseArrayPush -- 1
local __TS__SparseArraySpread = ____lualib.__TS__SparseArraySpread -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
local distance = ____Gravity.distance -- 28
local evaluateCollectedStars = ____Gravity.evaluateCollectedStars -- 28
local simulate = ____Gravity.simulate -- 28
local starPositionAt = ____Gravity.starPositionAt -- 28
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
local goalPositionAt = ____LevelData.goalPositionAt -- 33
local goalWaypoints = ____LevelData.goalWaypoints -- 33
local waypointProgress = ____LevelData.waypointProgress -- 33
local ____Transfer = require("game.Transfer") -- 34
local advanceTransferPlayback = ____Transfer.advanceTransferPlayback -- 34
local analyzeTransfer = ____Transfer.analyzeTransfer -- 34
local nextCameraFocus = ____Transfer.nextCameraFocus -- 34
local orbitalShotAt = ____Transfer.orbitalShotAt -- 34
local planTransfer = ____Transfer.planTransfer -- 34
local successMarkerFrame = ____Transfer.successMarkerFrame -- 34
local transferCinematic = ____Transfer.transferCinematic -- 34
local transferPlaybackRate = ____Transfer.transferPlaybackRate -- 34
local transferShotAt = ____Transfer.transferShotAt -- 34
local ____Config = require("game.Config") -- 36
local AimMinSpeed = ____Config.AimMinSpeed -- 37
local BrakeShare = ____Config.BrakeShare -- 37
local CameraFramingBudget = ____Config.CameraFramingBudget -- 37
local CameraTiltMax = ____Config.CameraTiltMax -- 37
local CameraTiltMin = ____Config.CameraTiltMin -- 37
local FlightPlayback = ____Config.FlightPlayback -- 37
local PhysicsStep = ____Config.PhysicsStep -- 38
local PredictSteps = ____Config.PredictSteps -- 38
local SlowMoCloseDist = ____Config.SlowMoCloseDist -- 38
local SlowMoFactor = ____Config.SlowMoFactor -- 38
local SlowMoFloorDist = ____Config.SlowMoFloorDist -- 38
local SlowMoRadiusFactor = ____Config.SlowMoRadiusFactor -- 39
local TimeWarpStep = ____Config.TimeWarpStep -- 39
local FinaleCamDist = ____Config.FinaleCamDist -- 40
local FinaleCamTiltDeg = ____Config.FinaleCamTiltDeg -- 40
local PlaneToWorldX = ____Config.PlaneToWorldX -- 40
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 40
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
function ____exports.resolveResult(outcome, goalIndex, goal) -- 73
	if goal.kind == "escape" then -- 73
		local wps = goalWaypoints(goal) -- 75
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 75
			return "success" -- 76
		end -- 76
	elseif goalIndex >= 0 then -- 76
		return "success" -- 78
	end -- 78
	if outcome == "crashed" then -- 78
		return "crashed" -- 80
	end -- 80
	return "missed" -- 81
end -- 73
--- **档位 → 世界时钟速率**（游戏秒 / 真实秒，B3，2026-09-28）。
-- 
-- 口径（用户 2026-09-28）：「1X 就是模拟的真实情况下的地月系的 1 秒」—— 也就是
-- `pow = 0` 时速率 = 1/SecPerGameSec（现实 1 秒走 1 秒；挂机一天，地球自转一圈）。
-- 加速 = pow + 1（**后面加个 0**），减速 = pow − 1（下限 0）。纯函数、可单测；物理层一行不动。
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 227
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 228
	local n = math.floor(pow) -- 229
	while n > 0 do -- 229
		rate = rate * 10 -- 231
		n = n - 1 -- 232
	end -- 232
	while n < 0 do -- 232
		rate = rate / 10 -- 235
		n = n + 1 -- 236
	end -- 236
	return rate -- 238
end -- 227
local function neutralAim(minSpeed) -- 241
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 242
end -- 241
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 246
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 247
end -- 246
--- 星尘在时刻 t 的位置（没有轨道就用静态坐标）。
local function starPositionsNow(orbits, fallback, t) -- 251
	local out = {} -- 252
	do -- 252
		local i = 0 -- 253
		while i < #fallback do -- 253
			local orbit = i < #orbits and orbits[i + 1] or nil -- 254
			out[#out + 1] = starPositionAt(orbit, fallback[i + 1], t) -- 255
			i = i + 1 -- 253
		end -- 253
	end -- 253
	return out -- 257
end -- 251
function ____exports.createCore(dt, stars, starOrbits) -- 260
	local stList = stars ~= nil and stars or ({}) -- 261
	local colList = {} -- 262
	do -- 262
		local i = 0 -- 263
		while i < #stList do -- 263
			colList[#colList + 1] = false -- 263
			i = i + 1 -- 263
		end -- 263
	end -- 263
	local orbits = starOrbits ~= nil and starOrbits or ({}) -- 264
	return { -- 265
		phase = "Aiming", -- 266
		aim = neutralAim(AimMinSpeed), -- 267
		flight = nil, -- 268
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 269
		brakeMode = false, -- 270
		burnDuration = 0, -- 271
		t0 = 0, -- 272
		flightTime = 0, -- 273
		missionCompleted = false, -- 274
		flyby = nil, -- 275
		goalIndex = -1, -- 276
		result = nil, -- 277
		viewMode = "2D", -- 279
		playback = FlightPlayback, -- 281
		slowmo = false, -- 282
		slowmoBody = -1, -- 283
		hasBraked = false, -- 284
		brakePointIndex = -1, -- 285
		stars = stList, -- 286
		starOrbits = orbits, -- 287
		collectedStars = colList, -- 288
		previewStarsCount = 0 -- 289
	} -- 289
end -- 260
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 301
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 302
	return core.viewMode -- 303
end -- 301
--- 教学关显式指定中心宿主；旧关卡仍按最近的有引力天体选择。
function ____exports.selectIdleHost(bodies, start, preferred) -- 307
	if preferred ~= nil and bodies[preferred + 1] ~= nil and bodies[preferred + 1].gm > 0 then -- 307
		return preferred -- 308
	end -- 308
	local index = -1 -- 309
	local nearest = 1000000000 -- 310
	do -- 310
		local i = 0 -- 311
		while i < #bodies do -- 311
			do -- 311
				if bodies[i + 1].gm <= 0 then -- 311
					goto __continue22 -- 312
				end -- 312
				local d = distance( -- 313
					bodyPositionAt(bodies[i + 1], 0), -- 313
					start -- 313
				) -- 313
				if d < nearest then -- 313
					nearest = d -- 314
					index = i -- 314
				end -- 314
			end -- 314
			::__continue22:: -- 314
			i = i + 1 -- 311
		end -- 311
	end -- 311
	return index -- 316
end -- 307
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 334
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 340
	local share = brakeMode and BrakeShare or 1 -- 341
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 342
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 343
	local brake = brakeMode and mag > 0 and ({ -- 344
		dv = mag * (1 - share), -- 345
		startStep = math.floor(maxSteps / 2) -- 345
	}) or nil -- 345
	return {init = init, brake = brake} -- 347
end -- 334
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 356
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 356
		return -- 358
	end -- 358
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 359
	local motion = ____exports.burnToMotion(burn, base, level.transfer == nil and core.brakeMode, level.maxSteps) -- 360
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 361
	core.burnDuration = level.transfer ~= nil and mag / level.transfer.thrustAcceleration or 0 -- 362
	local thrust = core.burnDuration > 0 and ({acceleration = {x = burn.x / core.burnDuration, y = burn.y / core.burnDuration}, duration = core.burnDuration}) or nil -- 363
	local p0 = from ~= nil and from or level.probeStart -- 364
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = level.transfer ~= nil and base ~= nil and base or motion.init}, level.bodies, { -- 365
		steps = level.maxSteps, -- 368
		dt = core.dt, -- 368
		sampleEvery = 1, -- 368
		escapeRadius = level.escapeRadius, -- 368
		t0 = core.t0, -- 368
		brake = motion.brake, -- 368
		initialBurn = thrust -- 368
	}) -- 368
	core.flight = flight -- 370
	core.missionCompleted = false -- 371
	local ____core_1 = core -- 372
	local ____temp_0 -- 372
	if level.transfer ~= nil then -- 372
		____temp_0 = analyzeTransfer( -- 372
			flight, -- 372
			level.bodies, -- 372
			level.goal.planetIndex, -- 372
			level.transfer, -- 372
			core.dt, -- 372
			core.t0 -- 372
		) -- 372
	else -- 372
		____temp_0 = nil -- 372
	end -- 372
	____core_1.flyby = ____temp_0 -- 372
	core.goalIndex = core.flyby ~= nil and core.flyby.completionIndex or findGoalIndex( -- 373
		flight.points, -- 373
		level.bodies, -- 373
		level.goal, -- 373
		core.dt, -- 373
		core.t0, -- 373
		flight.velocities -- 373
	) -- 373
	local ____core_3 = core -- 374
	local ____temp_2 -- 374
	if core.flyby ~= nil and core.goalIndex >= 0 then -- 374
		____temp_2 = nil -- 374
	else -- 374
		____temp_2 = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 374
	end -- 374
	____core_3.result = ____temp_2 -- 374
	if core.flyby ~= nil then -- 374
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 375
	end -- 375
	if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 375
		for ____, e in ipairs(core.flyby.encounters) do -- 378
			print((((((((("[escape-velocity] encounter body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " energy=") .. __TS__NumberToFixed(e.energyChange, 2)) .. " work=") .. __TS__NumberToFixed(e.work, 2)) .. " passed=") .. (e.passed and "1" or "0")) -- 378
		end -- 378
	end -- 378
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.init.x, 5)) .. ",") .. __TS__NumberToFixed(motion.init.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. (core.result ~= nil and core.result or "pending")) -- 381
	core.flightTime = 0 -- 386
	core.slowmo = false -- 388
	core.slowmoBody = -1 -- 389
	core.hasBraked = false -- 390
	core.brakePointIndex = -1 -- 391
	core.phase = "Flying" -- 392
	core.viewMode = "3D" -- 394
end -- 356
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 403
	if core.phase ~= "Aiming" then -- 403
		return false -- 404
	end -- 404
	core.phase = "Armed" -- 405
	return true -- 406
end -- 403
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 410
	if core.phase ~= "Armed" then -- 410
		return false -- 411
	end -- 411
	core.phase = "Aiming" -- 412
	return true -- 413
end -- 410
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 427
	return core.phase == "Aiming" or core.phase == "Armed" -- 428
end -- 427
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 444
	if toT0 then -- 444
		return {t0 = clock, clock = 0} -- 445
	end -- 445
	return {t0 = 0, clock = t0} -- 446
end -- 444
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 458
	local host = -1 -- 468
	do -- 468
		local i = 0 -- 469
		while i < #bodies do -- 469
			do -- 469
				local b = bodies[i + 1] -- 470
				local isHost = false -- 471
				do -- 471
					local j = 0 -- 472
					while j < #bodies do -- 472
						do -- 472
							local h = bodies[j + 1].host -- 473
							if h == nil then -- 473
								goto __continue43 -- 474
							end -- 474
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 474
								isHost = true -- 475
								break -- 475
							end -- 475
						end -- 475
						::__continue43:: -- 475
						j = j + 1 -- 472
					end -- 472
				end -- 472
				if not isHost then -- 472
					goto __continue41 -- 477
				end -- 477
				if host < 0 or b.gm > bodies[host + 1].gm then -- 477
					host = i -- 478
				end -- 478
			end -- 478
			::__continue41:: -- 478
			i = i + 1 -- 469
		end -- 469
	end -- 469
	if host >= 0 then -- 469
		return host -- 480
	end -- 480
	local best = -1 -- 482
	do -- 482
		local i = 0 -- 483
		while i < #bodies do -- 483
			do -- 483
				local b = bodies[i + 1] -- 484
				if b.orbitRadius ~= 0 then -- 484
					goto __continue50 -- 485
				end -- 485
				if best < 0 or b.gm > bodies[best + 1].gm then -- 485
					best = i -- 486
				end -- 486
			end -- 486
			::__continue50:: -- 486
			i = i + 1 -- 483
		end -- 483
	end -- 483
	return best -- 488
end -- 458
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 506
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 507
	local best = -1 -- 508
	local bestD = 1000000000 -- 509
	do -- 509
		local i = 0 -- 510
		while i < #bodies do -- 510
			do -- 510
				if i == anchor then -- 510
					goto __continue55 -- 511
				end -- 511
				local b = bodies[i + 1] -- 512
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 513
				local d = distance( -- 514
					probe, -- 514
					bodyPositionAt(b, t) -- 514
				) -- 514
				if d < threshold and d < bestD then -- 514
					bestD = d -- 516
					best = i -- 517
				end -- 517
			end -- 517
			::__continue55:: -- 517
			i = i + 1 -- 510
		end -- 510
	end -- 510
	return best -- 520
end -- 506
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 524
	if core.flight == nil then -- 524
		return 0 -- 525
	end -- 525
	local idx = math.floor(core.flightTime / core.dt) -- 526
	local last = #core.flight.points - 1 -- 527
	if idx > last then -- 527
		idx = last -- 528
	end -- 528
	if idx < 0 then -- 528
		idx = 0 -- 529
	end -- 529
	return idx -- 530
end -- 524
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
function ____exports.coreUpdate(core, dt, level) -- 547
	if core.phase ~= "Flying" or core.flight == nil then -- 547
		return false -- 548
	end -- 548
	if level ~= nil and level.transfer == nil then -- 548
		local idx = ____exports.coreProbeIndex(core) -- 552
		core.slowmoBody = ____exports.slowMotionBody( -- 553
			level.bodies, -- 553
			core.flight.points[idx + 1], -- 553
			core.t0 + core.flightTime, -- 553
			____exports.anchorBodyIndex(level.bodies), -- 553
			level.slowMoFloor -- 553
		) -- 553
		core.slowmo = core.slowmoBody >= 0 -- 554
	end -- 554
	if level ~= nil and level.transfer ~= nil then -- 554
		core.flightTime = advanceTransferPlayback( -- 558
			core.flightTime, -- 558
			dt, -- 558
			core.playback, -- 558
			core.burnDuration, -- 558
			level.transfer, -- 558
			core.flyby, -- 558
			core.dt -- 558
		) -- 558
	else -- 558
		core.flightTime = core.flightTime + dt * core.playback * (core.slowmo and SlowMoFactor or 1) -- 560
	end -- 560
	if core.flyby ~= nil and not core.missionCompleted and core.flyby.completionIndex >= 0 and ____exports.coreProbeIndex(core) >= core.flyby.completionIndex then -- 560
		core.missionCompleted = true -- 563
		core.result = "success" -- 564
	end -- 564
	if core.stars ~= nil and #core.stars > 0 then -- 564
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 569
		do -- 569
			local s = 0 -- 570
			while s < #core.stars do -- 570
				if not core.collectedStars[s + 1] then -- 570
					local orbit = s < #core.starOrbits and core.starOrbits[s + 1] or nil -- 572
					local stPos = starPositionAt(orbit, core.stars[s + 1], core.t0 + core.flightTime) -- 573
					local dx = curPos.x - stPos.x -- 574
					local dy = curPos.y - stPos.y -- 575
					if dx * dx + dy * dy <= 30 * 30 then -- 575
						core.collectedStars[s + 1] = true -- 577
					end -- 577
				end -- 577
				s = s + 1 -- 570
			end -- 570
		end -- 570
	end -- 570
	local naturalEnd = #core.flight.points - 1 -- 583
	local endIdx = core.flyby ~= nil and core.flyby.viewEndIndex or (core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd) -- 584
	if ____exports.coreProbeIndex(core) >= endIdx then -- 584
		core.flightTime = endIdx * core.dt -- 587
		core.phase = "Result" -- 588
		return true -- 589
	end -- 589
	return false -- 591
end -- 547
--- 已完成的教学关可提前结束观赏，不能用该操作跳过掠月判定。
function ____exports.coreEndViewing(core) -- 595
	if core.phase ~= "Flying" or not core.missionCompleted then -- 595
		return false -- 596
	end -- 596
	core.flightTime = ____exports.coreProbeIndex(core) * core.dt -- 597
	core.phase = "Result" -- 598
	return true -- 599
end -- 595
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 605
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 609
	local maxSpeed = 0 -- 610
	local closestDist = 1000000000 -- 611
	local eccentricity = nil -- 612
	if core.flight ~= nil then -- 612
		local pts = core.flight.points -- 615
		local vels = core.flight.velocities -- 616
		local ____end = ____exports.coreProbeIndex(core) -- 617
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 618
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 619
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 620
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 621
		do -- 621
			local k = 0 -- 623
			while k <= ____end and k < #pts do -- 623
				local p = pts[k + 1] -- 624
				if vels ~= nil and k < #vels then -- 624
					local v = vels[k + 1] -- 626
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 627
					if spd > maxSpeed then -- 627
						maxSpeed = spd -- 628
					end -- 628
				end -- 628
				if distTargetBody ~= nil then -- 628
					local t = core.t0 + k * core.dt -- 631
					local tp = bodyPositionAt(distTargetBody, t) -- 632
					local d = distance(p, tp) -- 633
					if d < closestDist then -- 633
						closestDist = d -- 634
					end -- 634
				end -- 634
				k = k + 1 -- 623
			end -- 623
		end -- 623
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 623
			local tEnd = core.t0 + ____end * core.dt -- 639
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 640
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 641
			local rx = pts[____end + 1].x - tpEnd.x -- 642
			local ry = pts[____end + 1].y - tpEnd.y -- 643
			local vx = vels[____end + 1].x - tvEnd.x -- 644
			local vy = vels[____end + 1].y - tvEnd.y -- 645
			local r = math.sqrt(rx * rx + ry * ry) -- 646
			local v2 = vx * vx + vy * vy -- 647
			local mu = goalBody.gm -- 648
			if r > 0 and mu > 0 then -- 648
				local energy = v2 / 2 - mu / r -- 650
				local h = rx * vy - ry * vx -- 651
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 652
				if term >= 0 then -- 652
					eccentricity = math.sqrt(term) -- 654
				end -- 654
			end -- 654
		end -- 654
	end -- 654
	local starsCollectedCount = 0 -- 660
	do -- 660
		local i = 0 -- 661
		while i < #core.collectedStars do -- 661
			if core.collectedStars[i + 1] then -- 661
				starsCollectedCount = starsCollectedCount + 1 -- 662
			end -- 662
			i = i + 1 -- 661
		end -- 661
	end -- 661
	return { -- 665
		burnDv = burnDv, -- 666
		flightTime = core.flightTime, -- 667
		closestDist = closestDist < 100000000 and closestDist or 0, -- 668
		maxSpeed = maxSpeed, -- 669
		eccentricity = eccentricity, -- 670
		starsCollected = starsCollectedCount -- 671
	} -- 671
end -- 605
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 676
	core.phase = "Aiming" -- 677
	core.viewMode = "2D" -- 679
	core.flight = nil -- 680
	core.flightTime = 0 -- 681
	core.missionCompleted = false -- 682
	core.flyby = nil -- 683
	core.goalIndex = -1 -- 684
	core.result = nil -- 685
	core.burnDuration = 0 -- 686
	core.slowmo = false -- 687
	core.slowmoBody = -1 -- 688
	core.hasBraked = false -- 689
	core.brakePointIndex = -1 -- 690
	do -- 690
		local i = 0 -- 691
		while i < #core.collectedStars do -- 691
			core.collectedStars[i + 1] = false -- 691
			i = i + 1 -- 691
		end -- 691
	end -- 691
	core.previewStarsCount = 0 -- 692
	core.aim = neutralAim(levelAimMin(aimMin)) -- 693
end -- 676
--- 判定当前飞行状态下是否处于可逆喷制动窗口。
-- 纯函数，可单测。
function ____exports.isBrakeWindowActive(core, level) -- 700
	if level.transfer ~= nil then -- 700
		return false -- 701
	end -- 701
	if core.phase ~= "Flying" or core.flight == nil or core.hasBraked then -- 701
		return false -- 702
	end -- 702
	local curIdx = ____exports.coreProbeIndex(core) -- 703
	local pts = core.flight.points -- 704
	if curIdx < 0 or curIdx >= #pts then -- 704
		return false -- 705
	end -- 705
	local targetIdx = level.goal.planetIndex -- 707
	if targetIdx < 0 or targetIdx >= #level.bodies then -- 707
		return false -- 708
	end -- 708
	local targetBody = level.bodies[targetIdx + 1] -- 709
	local tNow = core.t0 + core.flightTime -- 710
	local targetPos = bodyPositionAt(targetBody, tNow) -- 711
	local dist = distance(pts[curIdx + 1], targetPos) -- 712
	local floorD = level.slowMoFloor ~= nil and level.slowMoFloor > 0 and level.slowMoFloor or SlowMoFloorDist -- 715
	local brakeDistLimit = math.max(level.goal.tolerance * 1.5, targetBody.radius * SlowMoRadiusFactor, floorD) -- 716
	return dist <= brakeDistLimit and dist > targetBody.radius -- 717
end -- 700
--- 飞行中逆喷制动（L4 伽利略号等轨道器核心玩法）。
-- 纯函数逻辑，更新 core.flight 及其后续轨迹，并重新判定目标与结果。
-- 返回 true 表示制动成功应用。
function ____exports.applyInFlightBrake(core, level) -- 725
	if not ____exports.isBrakeWindowActive(core, level) then -- 725
		return false -- 726
	end -- 726
	if core.flight == nil then -- 726
		return false -- 727
	end -- 727
	local curIdx = ____exports.coreProbeIndex(core) -- 729
	local curPos = core.flight.points[curIdx + 1] -- 730
	local curVel = core.flight.velocities ~= nil and curIdx < #core.flight.velocities and core.flight.velocities[curIdx + 1] or ({x = 0, y = 0}) -- 731
	local tNow = core.t0 + core.flightTime -- 734
	local targetIdx = level.goal.planetIndex -- 736
	local targetBody = level.bodies[targetIdx + 1] -- 737
	local targetPos = bodyPositionAt(targetBody, tNow) -- 738
	local targetVel = bodyVelocityAt(targetBody, tNow) -- 739
	local relVel = {x = curVel.x - targetVel.x, y = curVel.y - targetVel.y} -- 742
	local relSpeed = math.sqrt(relVel.x * relVel.x + relVel.y * relVel.y) -- 743
	local dist = distance(curPos, targetPos) -- 744
	if relSpeed <= 0.000001 or dist <= 0.000001 then -- 744
		return false -- 746
	end -- 746
	local vCirc = math.sqrt(targetBody.gm / dist) -- 749
	local targetRelSpeed = vCirc * 0.98 -- 752
	local reductionFactor = targetRelSpeed / relSpeed -- 753
	local clampedFactor = math.min(0.95, reductionFactor) -- 754
	local newRelVel = {x = relVel.x * clampedFactor, y = relVel.y * clampedFactor} -- 756
	local newVel = {x = targetVel.x + newRelVel.x, y = targetVel.y + newRelVel.y} -- 760
	local remainingSteps = math.max(1000, level.maxSteps - curIdx) -- 766
	local postBrakeSim = simulate({pos = curPos, vel = newVel}, level.bodies, { -- 767
		steps = remainingSteps, -- 771
		dt = core.dt, -- 772
		sampleEvery = 1, -- 773
		escapeRadius = level.escapeRadius, -- 774
		t0 = tNow -- 775
	}) -- 775
	local mergedPoints = __TS__ArraySlice(core.flight.points, 0, curIdx) -- 780
	do -- 780
		local i = 0 -- 781
		while i < #postBrakeSim.points do -- 781
			mergedPoints[#mergedPoints + 1] = postBrakeSim.points[i + 1] -- 782
			i = i + 1 -- 781
		end -- 781
	end -- 781
	local mergedVelocities = __TS__ArraySlice(core.flight.velocities or ({}), 0, curIdx) -- 784
	if postBrakeSim.velocities ~= nil then -- 784
		do -- 784
			local i = 0 -- 786
			while i < #postBrakeSim.velocities do -- 786
				mergedVelocities[#mergedVelocities + 1] = postBrakeSim.velocities[i + 1] -- 787
				i = i + 1 -- 786
			end -- 786
		end -- 786
	end -- 786
	core.flight = { -- 791
		outcome = postBrakeSim.outcome, -- 792
		points = mergedPoints, -- 793
		velocities = mergedVelocities, -- 794
		state = postBrakeSim.state, -- 795
		hitIndex = postBrakeSim.hitIndex, -- 796
		stepsRun = curIdx + postBrakeSim.stepsRun -- 797
	} -- 797
	core.hasBraked = true -- 800
	core.brakePointIndex = curIdx -- 801
	core.goalIndex = findGoalIndex( -- 804
		mergedPoints, -- 804
		level.bodies, -- 804
		level.goal, -- 804
		core.dt, -- 804
		core.t0, -- 804
		mergedVelocities -- 804
	) -- 804
	core.result = ____exports.resolveResult(postBrakeSim.outcome, core.goalIndex, level.goal) -- 805
	print((((((((((("[escape-velocity] in-flight brake applied at t=" .. __TS__NumberToFixed(tNow, 2)) .. " curIdx=") .. __TS__NumberToFixed(curIdx, 0)) .. " relSpeed=") .. __TS__NumberToFixed(relSpeed, 3)) .. " -> ") .. __TS__NumberToFixed( -- 807
		math.sqrt(newRelVel.x * newRelVel.x + newRelVel.y * newRelVel.y), -- 809
		3 -- 809
	)) .. " vCirc=") .. __TS__NumberToFixed(vCirc, 3)) .. " result=") .. core.result) -- 809
	return true -- 813
end -- 725
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 827
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 827
		return false -- 829
	end -- 829
	core.phase = "LevelSelect" -- 830
	core.viewMode = "2D" -- 832
	core.flight = nil -- 833
	core.flightTime = 0 -- 834
	core.goalIndex = -1 -- 835
	core.result = nil -- 836
	core.slowmo = false -- 837
	core.slowmoBody = -1 -- 838
	return true -- 839
end -- 827
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 868
	if core.phase ~= "Result" then -- 868
		return false -- 869
	end -- 869
	core.phase = "Finale" -- 870
	return true -- 871
end -- 868
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 889
	local dist = distance > 1 and distance or 1 -- 890
	local ux = probe.x -- 892
	local uy = probe.y -- 893
	local len = math.sqrt(ux * ux + uy * uy) -- 894
	if len < 0.000001 then -- 894
		ux = 0 -- 895
		uy = 1 -- 895
	else -- 895
		ux = ux / len -- 895
		uy = uy / len -- 895
	end -- 895
	local tilt = tiltDeg * math.pi / 180 -- 896
	local flat = math.cos(tilt) * dist -- 897
	return { -- 898
		target = Vec3(0, 0, 0), -- 900
		eye = Vec3( -- 901
			ux * flat * PlaneToWorldX, -- 901
			math.sin(tilt) * dist, -- 901
			uy * flat * PlaneToWorldZ -- 901
		) -- 901
	} -- 901
end -- 889
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 1052
	local introTourActive, introTourT -- 1052
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 1053
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 1059
	local paused = false -- 1060
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 1061
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 1063
	local function applySpeedRate() -- 1064
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 1065
	end -- 1064
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 1078
		if level.transfer ~= nil then -- 1078
			paused = false -- 1079
			speedPow = 0 -- 1079
			applySpeedRate() -- 1079
			return -- 1079
		end -- 1079
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 1079
			return -- 1080
		end -- 1080
		speedPow = level.flightSpeedPow -- 1081
		paused = false -- 1082
		applySpeedRate() -- 1083
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 1084
	end -- 1078
	applySpeedRate() -- 1090
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 1093
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
	local function applyView() -- 1108
		local mode = core.viewMode -- 1109
		if mode == appliedMode then -- 1109
			return -- 1110
		end -- 1110
		appliedMode = mode -- 1111
		local is2D = mode == "2D" -- 1112
		deps.plan:setVisible(is2D) -- 1113
		deps.trajectory.root.visible = not is2D -- 1114
		deps:setWorldVisible(not is2D) -- 1115
		deps.aim:setFullScreenAim(is2D) -- 1116
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 1117
	end -- 1108
	local ____temp_4 -- 1120
	if level.mission ~= nil then -- 1120
		____temp_4 = level.mission.introTour -- 1120
	else -- 1120
		____temp_4 = nil -- 1120
	end -- 1120
	local tourDef = ____temp_4 -- 1120
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 1121
	local function finishIntroTour() -- 1123
		if not introTourActive then -- 1123
			return -- 1124
		end -- 1124
		introTourActive = false -- 1125
		introTourT = tourDuration -- 1126
		core.viewMode = "2D" -- 1127
		applyView() -- 1128
		deps.aim:setIntroTourBannerVisible(false) -- 1129
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1130
	end -- 1123
	local function makeBasis(frame) -- 1133
		return prepareCamera({ -- 1134
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1136
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1137
			up = {x = 0, y = 1, z = 0}, -- 1138
			fovYDeg = deps.fovYDeg, -- 1139
			aspect = deps.aspect, -- 1140
			viewW = deps.viewW, -- 1141
			viewH = deps.viewH -- 1142
		}, HANDEDNESS, FLIP_Y) -- 1142
	end -- 1133
	local PredMinIntervalSec = 0.08 -- 1154
	local predAimKey = "" -- 1155
	local predPosKey = "" -- 1156
	local predAccum = 1 -- 1157
	local predForce = true -- 1158
	local predPoints = {} -- 1159
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 1161
	introTourActive = false -- 1163
	introTourT = tourDuration -- 1164
	local introLogged = false -- 1165
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1167
	local clock = 0 -- 1173
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1175
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1177
	local obsYawDeg = 0 -- 1181
	local obsPitchDeg = 0 -- 1182
	local obsZoom = 1 -- 1183
	local focusMode = "Auto" -- 1184
	local markerElapsed = -1 -- 1185
	local cineKey = "" -- 1186
	local cineFrame = nil -- 1187
	local cineFrom = nil -- 1188
	local cineTransition = 0 -- 1189
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1191
	local idleOrbit = nil -- 1193
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1204
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1206
	local lastSlowmoBody = -1 -- 1207
	local flightLogT = 0 -- 1208
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1210
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1211
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
	local function prepareIdle() -- 1226
		clock = 0 -- 1228
		core.t0 = 0 -- 1229
		idleOrbit = nil -- 1230
		if level.probeVel0 == nil then -- 1230
			return -- 1231
		end -- 1231
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1233
		if hostIndex < 0 then -- 1233
			return -- 1234
		end -- 1234
		local host = level.bodies[hostIndex + 1] -- 1235
		local hp = bodyPositionAt(host, 0) -- 1236
		local hv = bodyVelocityAt(host, 0) -- 1237
		local rx = level.probeStart.x - hp.x -- 1239
		local ry = level.probeStart.y - hp.y -- 1240
		local vx = level.probeVel0.x - hv.x -- 1241
		local vy = level.probeVel0.y - hv.y -- 1242
		local r = math.sqrt(rx * rx + ry * ry) -- 1243
		if r < 1e-12 then -- 1243
			return -- 1244
		end -- 1244
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1246
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1247
		idleOrbit = { -- 1248
			hostIndex = hostIndex, -- 1248
			r = r, -- 1248
			phase0 = math.atan(ry, rx), -- 1248
			omega = dir * omega -- 1248
		} -- 1248
	end -- 1226
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1252
		if idleOrbit == nil then -- 1252
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1254
		end -- 1254
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1259
		local hp = bodyPositionAt(host, tWorld) -- 1260
		local hv = bodyVelocityAt(host, tWorld) -- 1261
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1262
		local ca = math.cos(a) -- 1263
		local sa = math.sin(a) -- 1264
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1265
	end -- 1252
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1282
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1283
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1286
		local wps = goalWaypoints(level.goal) -- 1287
		if #wps == 0 then -- 1287
			return nil -- 1288
		end -- 1288
		local passed = 0 -- 1289
		if core.flight ~= nil then -- 1289
			local upto = math.floor(core.flightTime / core.dt) -- 1291
			passed = waypointProgress( -- 1292
				core.flight.points, -- 1292
				level.bodies, -- 1292
				level.goal, -- 1292
				core.dt, -- 1292
				core.t0, -- 1292
				upto, -- 1292
				core.flight.velocities -- 1292
			).passed -- 1292
		end -- 1292
		if passed >= #wps then -- 1292
			return nil -- 1294
		end -- 1294
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1295
	end -- 1286
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1306
		if level.transfer ~= nil then -- 1306
			return { -- 1308
				pts = { -- 1308
					probe, -- 1308
					bodyPositionAt(level.bodies[1], t), -- 1308
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1308
					goalPositionAt(level.goal.marker ~= nil and level.goal.marker or level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1308
				}, -- 1308
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1309
			} -- 1309
		end -- 1309
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1309
			local hr = anchorDef.radius -- 1314
			do -- 1314
				local i = 0 -- 1315
				while i < #level.bodies do -- 1315
					local b = level.bodies[i + 1] -- 1316
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1316
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1316
							hr = deps.visuals[i + 1].displayRadius -- 1318
						end -- 1318
						break -- 1319
					end -- 1319
					i = i + 1 -- 1315
				end -- 1315
			end -- 1315
			return { -- 1322
				pts = { -- 1322
					probe, -- 1322
					bodyPositionAt(anchorDef, t) -- 1322
				}, -- 1322
				radii = {deps.scene.probeRadius, hr} -- 1322
			} -- 1322
		end -- 1322
		local corePts = {probe} -- 1326
		local coreRadii = {deps.scene.probeRadius} -- 1327
		local next = nextStationBody() -- 1328
		local nextTol = 0 -- 1329
		if next ~= nil then -- 1329
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1331
			local wps = goalWaypoints(level.goal) -- 1332
			local passed = 0 -- 1333
			if core.flight ~= nil then -- 1333
				passed = waypointProgress( -- 1335
					core.flight.points, -- 1335
					level.bodies, -- 1335
					level.goal, -- 1335
					core.dt, -- 1335
					core.t0, -- 1335
					math.floor(core.flightTime / core.dt), -- 1335
					core.flight.velocities -- 1335
				).passed -- 1335
			end -- 1335
			if passed < #wps then -- 1335
				nextTol = wps[passed + 1].tolerance -- 1337
			end -- 1337
			local r = nextTol > next.radius and nextTol or next.radius -- 1338
			coreRadii[#coreRadii + 1] = r -- 1339
		end -- 1339
		if anchorDef == nil then -- 1339
			return {pts = corePts, radii = coreRadii} -- 1342
		end -- 1342
		local anchorR = anchorDef.radius -- 1347
		do -- 1347
			local i = 0 -- 1348
			while i < #level.bodies do -- 1348
				local b = level.bodies[i + 1] -- 1349
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1349
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1349
						anchorR = deps.visuals[i + 1].displayRadius -- 1351
					end -- 1351
					break -- 1352
				end -- 1352
				i = i + 1 -- 1348
			end -- 1348
		end -- 1348
		local withAnchorPts = { -- 1355
			probe, -- 1355
			bodyPositionAt(anchorDef, t) -- 1355
		} -- 1355
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1356
		do -- 1356
			local i = 1 -- 1357
			while i < #corePts do -- 1357
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1358
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1359
				i = i + 1 -- 1357
			end -- 1357
		end -- 1357
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1361
		if want <= CameraFramingBudget then -- 1361
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1362
		end -- 1362
		return {pts = corePts, radii = coreRadii} -- 1363
	end -- 1306
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1367
		local marker = successMarkerFrame(markerElapsed) -- 1368
		if level.transfer ~= nil and not marker.visible then -- 1368
			return {} -- 1369
		end -- 1369
		local wps = goalWaypoints(level.goal) -- 1370
		if #wps == 0 then -- 1370
			return {} -- 1371
		end -- 1371
		local passed = 0 -- 1372
		if upto ~= nil and core.flight ~= nil then -- 1372
			passed = waypointProgress( -- 1374
				core.flight.points, -- 1374
				level.bodies, -- 1374
				level.goal, -- 1374
				core.dt, -- 1374
				core.t0, -- 1374
				upto, -- 1374
				core.flight.velocities -- 1374
			).passed -- 1374
		end -- 1374
		if transferCinematic(level.transfer) then -- 1374
			passed = 0 -- 1376
		end -- 1376
		if passed >= #wps then -- 1376
			return {} -- 1380
		end -- 1380
		local nextWp = wps[passed + 1] -- 1381
		local body = level.goal.marker ~= nil and level.goal.marker or level.bodies[nextWp.planetIndex + 1] -- 1382
		if body == nil then -- 1382
			return {} -- 1383
		end -- 1383
		local planning = aimed and (core.phase == "Aiming" or core.phase == "Armed") -- 1384
		local ____temp_5 -- 1385
		if level.transfer ~= nil then -- 1385
			____temp_5 = level.transfer.orbital -- 1385
		else -- 1385
			____temp_5 = nil -- 1385
		end -- 1385
		local orbital = ____temp_5 -- 1385
		local rings = {{ -- 1386
			center = goalPositionAt(body, t, nextWp.offset), -- 1386
			radius = nextWp.tolerance, -- 1386
			passed = false, -- 1386
			point = level.transfer ~= nil, -- 1387
			showRange = level.transfer == nil or orbital == nil and planning, -- 1387
			pulse = (1 + 0.1 * math.sin(t * 4)) * marker.scale, -- 1388
			pointAlpha = marker.alpha, -- 1388
			burstRadius = marker.ring -- 1388
		}} -- 1388
		if orbital ~= nil and planning then -- 1388
			local center = bodyPositionAt(level.bodies[1], t) -- 1390
			__TS__ArrayPush(rings, {center = center, radius = orbital.region.minRadius, passed = false}, {center = center, radius = orbital.region.maxRadius, passed = false}) -- 1391
		end -- 1391
		return rings -- 1393
	end -- 1367
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1397
		if level.transfer ~= nil and not transferCinematic(level.transfer) then -- 1397
			local basis = makeBasis(f) -- 1399
			local dx = f.eye.x - f.target.x -- 1400
			local dy = f.eye.y - f.target.y -- 1400
			local dz = f.eye.z - f.target.z -- 1400
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1401
			f = { -- 1402
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1402
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1403
			} -- 1403
		end -- 1403
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1403
			return f -- 1405
		end -- 1405
		local dx = f.eye.x - f.target.x -- 1406
		local dy = f.eye.y - f.target.y -- 1407
		local dz = f.eye.z - f.target.z -- 1408
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1409
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1410
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1411
		local lo = CameraTiltMin * math.pi / 180 -- 1412
		local hi = CameraTiltMax * math.pi / 180 -- 1413
		if pitch < lo then -- 1413
			pitch = lo -- 1414
		end -- 1414
		if pitch > hi then -- 1414
			pitch = hi -- 1415
		end -- 1415
		local cp = math.cos(pitch) -- 1416
		return { -- 1417
			target = f.target, -- 1418
			eye = Vec3( -- 1419
				f.target.x + r * cp * math.sin(yaw), -- 1420
				f.target.y + r * math.sin(pitch), -- 1421
				f.target.z + r * cp * math.cos(yaw) -- 1422
			) -- 1422
		} -- 1422
	end -- 1397
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1428
		local cfg = level.transfer.flyby -- 1429
		local autoShot = transferShotAt( -- 1430
			core.flightTime, -- 1430
			core.burnDuration, -- 1430
			core.flyby, -- 1430
			cfg, -- 1430
			core.dt -- 1430
		) -- 1430
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1431
		local key = (focusMode .. ":") .. shot -- 1432
		local earth = bodyPositionAt(level.bodies[1], t) -- 1433
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1434
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1435
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1436
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1437
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1438
		local moonAz = launchAz -- 1439
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1439
			local at = core.flyby.entryIndex -- 1441
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1442
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1444
		end -- 1444
		local pts = {pos} -- 1446
		local radii = {deps.scene.probeRadius} -- 1446
		local az = launchAz -- 1447
		local tilt = 28 -- 1447
		local minDist = 130 -- 1447
		if shot == "Cruise" then -- 1447
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 32 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 32 / vmag or 0)} -- 1449
			radii[#radii + 1] = 0 -- 1450
			minDist = 180 -- 1450
			tilt = 35 -- 1450
		elseif shot == "Moon" then -- 1450
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1452
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1453
			az = moonAz -- 1454
			tilt = 45 -- 1454
			minDist = 160 -- 1454
		elseif shot == "Earth" then -- 1454
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1456
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1457
			az = moonAz + 35 -- 1458
			tilt = 42 -- 1458
			minDist = 180 -- 1458
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1458
				local at = math.min( -- 1460
					#core.flight.points - 1, -- 1460
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1460
				) -- 1460
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1461
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1463
			end -- 1463
		elseif shot == "Overview" then -- 1463
			pts = {pos, earth, moon} -- 1466
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1466
			az = moonAz -- 1467
			tilt = 60 -- 1467
			minDist = 200 -- 1467
		end -- 1467
		if key ~= cineKey then -- 1467
			cineFrom = cineFrame -- 1470
			cineTransition = 0 -- 1471
			if cineKey == "" or shot == "Launch" then -- 1471
				cineFrom = nil -- 1473
			end -- 1473
			cineKey = key -- 1474
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1475
		end -- 1475
		local want = deps.rig.step( -- 1477
			pts, -- 1477
			deps.scene.probeRadius, -- 1477
			radii, -- 1477
			minDist, -- 1477
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1477
		) -- 1477
		local frame = want -- 1478
		if cineFrom ~= nil then -- 1478
			cineTransition = cineTransition + wallDt -- 1480
			local u = math.min(1, cineTransition / 0.6) -- 1481
			local k = u * u * (3 - 2 * u) -- 1482
			frame = { -- 1483
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1483
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1484
			} -- 1484
			if u >= 1 then -- 1484
				cineFrom = nil -- 1485
			end -- 1485
		end -- 1485
		cineFrame = frame -- 1487
		return applyObserve(frame) -- 1488
	end -- 1428
	--- 日心关卡按配置逐站取景，手动选择保持到回到自动。
	local function orbitalCamera(pos, t, wallDt) -- 1492
		local cfg = level.transfer.orbital -- 1493
		local autoShot = orbitalShotAt( -- 1494
			core.flightTime, -- 1494
			core.burnDuration, -- 1494
			core.flyby, -- 1494
			cfg, -- 1494
			core.dt -- 1494
		) -- 1494
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1495
		local key = (focusMode .. ":") .. shot -- 1496
		local velocity = core.flight.velocities[____exports.coreProbeIndex(core) + 1] -- 1497
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1498
		local pts = {pos} -- 1499
		local radii = {deps.scene.probeRadius} -- 1499
		local az = math.atan(core.flight.velocities[1].x, core.flight.velocities[1].y) * 180 / math.pi + 100 -- 1500
		local tilt = 28 -- 1501
		local minDist = 130 -- 1501
		if shot == "Cruise" then -- 1501
			pts[#pts + 1] = {x = pos.x + (speed > 0 and velocity.x * 32 / speed or 0), y = pos.y + (speed > 0 and velocity.y * 32 / speed or 0)} -- 1503
			radii[#radii + 1] = 0 -- 1504
			tilt = 35 -- 1504
			minDist = 180 -- 1504
		elseif shot == "Overview" then -- 1504
			pts[#pts + 1] = bodyPositionAt(level.bodies[1], t) -- 1506
			radii[#radii + 1] = level.bodies[1].radius -- 1506
			for ____, e in ipairs(cfg.encounters) do -- 1507
				pts[#pts + 1] = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1507
				radii[#radii + 1] = level.bodies[e.planetIndex + 1].radius -- 1507
			end -- 1507
			az = math.atan(pos.x, pos.y) * 180 / math.pi -- 1508
			tilt = 60 -- 1508
			minDist = 300 -- 1508
		elseif shot == "Sun" then -- 1508
			pts = {bodyPositionAt(level.bodies[1], t)} -- 1510
			radii = {level.bodies[1].radius} -- 1510
			tilt = 42 -- 1510
			minDist = 200 -- 1510
		elseif shot ~= "Launch" then -- 1510
			do -- 1510
				local i = 0 -- 1512
				while i < #cfg.encounters do -- 1512
					do -- 1512
						local e = cfg.encounters[i + 1] -- 1513
						if e.focus ~= shot then -- 1513
							goto __continue184 -- 1514
						end -- 1514
						local bp = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1515
						pts = focusMode == "Auto" and ({pos, bp}) or ({bp}) -- 1516
						radii = focusMode == "Auto" and ({deps.scene.probeRadius, level.bodies[e.planetIndex + 1].radius}) or ({level.bodies[e.planetIndex + 1].radius}) -- 1517
						local stage = core.flyby ~= nil and core.flyby.encounters ~= nil and core.flyby.encounters[i + 1] or nil -- 1518
						local at = stage ~= nil and stage.entryIndex >= 0 and stage.entryIndex or 0 -- 1519
						local near = bodyPositionAt(level.bodies[e.planetIndex + 1], core.t0 + at * core.dt) -- 1520
						local probe = core.flight.points[at + 1] -- 1520
						az = math.atan(probe.x - near.x, probe.y - near.y) * 180 / math.pi + 90 -- 1521
						tilt = 45 -- 1522
						minDist = 180 -- 1522
						break -- 1522
					end -- 1522
					::__continue184:: -- 1522
					i = i + 1 -- 1512
				end -- 1512
			end -- 1512
		end -- 1512
		if key ~= cineKey then -- 1512
			cineFrom = cineFrame -- 1526
			cineTransition = 0 -- 1526
			if cineKey == "" or shot == "Launch" then -- 1526
				cineFrom = nil -- 1527
			end -- 1527
			cineKey = key -- 1528
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1529
		end -- 1529
		local want = deps.rig.step( -- 1531
			pts, -- 1531
			deps.scene.probeRadius, -- 1531
			radii, -- 1531
			minDist, -- 1531
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1531
		) -- 1531
		local frame = want -- 1532
		if cineFrom ~= nil then -- 1532
			cineTransition = cineTransition + wallDt -- 1534
			local u = math.min(1, cineTransition / 0.6) -- 1535
			local k = u * u * (3 - 2 * u) -- 1535
			frame = { -- 1536
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1536
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1537
			} -- 1537
			if u >= 1 then -- 1537
				cineFrom = nil -- 1538
			end -- 1538
		end -- 1538
		cineFrame = frame -- 1540
		return applyObserve(frame) -- 1541
	end -- 1492
	local function resetCinematic() -- 1544
		markerElapsed = -1 -- 1545
		focusMode = "Auto" -- 1546
		cineKey = "" -- 1546
		cineFrame = nil -- 1546
		cineFrom = nil -- 1546
		obsYawDeg = 0 -- 1547
		obsPitchDeg = 0 -- 1547
		obsZoom = 1 -- 1547
	end -- 1544
	local function updateAiming(dt) -- 1550
		if deps.plan.setBurn ~= nil then -- 1550
			deps.plan:setBurn(core.aim.velocity, false) -- 1551
		end -- 1551
		deps.aim:setEnabled(true) -- 1552
		local dragging = deps.aim:isDragging() -- 1554
		local clockFrozen = dragging or core.phase == "Armed" or transferCinematic(level.transfer) and introTourActive -- 1559
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1559
			local rate = core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1570
			clock = clock + dt * rate -- 1571
			orbitClock = orbitClock + dt * rate -- 1572
		end -- 1572
		local tNow = core.t0 + clock -- 1574
		local idleState = idleProbeAt(tNow) -- 1576
		probePos = idleState.pos -- 1577
		probeVel = idleState.vel -- 1578
		deps.scene.syncBodies(tNow) -- 1580
		if deps.scene.syncStars ~= nil then -- 1580
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1581
		end -- 1581
		deps.scene.syncProbe(probePos) -- 1582
		if idleOrbit ~= nil then -- 1582
			deps.scene.faceVelocity(probeVel) -- 1583
		end -- 1583
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1585
		deps.plan:syncProbe(probePos, probeVel) -- 1586
		if not aimed and #core.stars > 0 then -- 1586
			deps.plan:setStars( -- 1588
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1588
				core.collectedStars -- 1588
			) -- 1588
		end -- 1588
		local fr = framingPoints(probePos, tNow) -- 1592
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1593
		if frameLogged < 6 then -- 1593
			frameLogged = frameLogged + 1 -- 1597
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1598
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1602
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1603
				__TS__ArrayMap( -- 1609
					fr.pts, -- 1609
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1609
				), -- 1609
				" " -- 1609
			)) .. "]") -- 1609
		end -- 1609
		if introTourActive and introTourT < tourDuration then -- 1609
			introTourT = introTourT + dt -- 1613
			local k = introTourT / tourDuration -- 1614
			if k >= 1 then -- 1614
				finishIntroTour() -- 1616
			else -- 1616
				if k >= 0.95 and not introLogged then -- 1616
					introLogged = true -- 1619
					print("[escape-velocity] intro camera finishing") -- 1620
				end -- 1620
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1620
					local elapsed = introTourT -- 1624
					local segIndex = 0 -- 1625
					local segStart = 0 -- 1626
					do -- 1626
						local s = 0 -- 1627
						while s < #tourDef.segments do -- 1627
							local seg = tourDef.segments[s + 1] -- 1628
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1628
								segIndex = s -- 1630
								break -- 1631
							end -- 1631
							elapsed = elapsed - seg.duration -- 1633
							segStart = segStart + seg.duration -- 1634
							s = s + 1 -- 1627
						end -- 1627
					end -- 1627
					local curSeg = tourDef.segments[segIndex + 1] -- 1636
					local segK = math.max( -- 1637
						0, -- 1637
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1637
					) -- 1637
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1639
					deps.aim:setIntroTourBannerVisible(true) -- 1640
					local pwProbe = planeToWorld(probePos, 0) -- 1642
					local function getTargetPosAndDist(targetIdx, userDist) -- 1643
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1643
							local b = level.bodies[targetIdx + 1] -- 1645
							local isMicro = b.orbitRadius < 2 -- 1646
							local p = planeToWorld( -- 1647
								bodyPositionAt(b, tNow), -- 1647
								0 -- 1647
							) -- 1647
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1648
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1649
						end -- 1649
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1651
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1652
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1653
					end -- 1643
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1656
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1657
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1658
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1660
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1661
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1662
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1663
					if segIndex == 0 then -- 1663
						local az = curAz + segK * (18 * math.pi / 180) -- 1667
						local tilt = curTilt -- 1668
						local d = curKey.dist -- 1669
						local eye = Vec3( -- 1670
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1671
							curKey.pos.y + math.sin(tilt) * d, -- 1672
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1673
						) -- 1673
						frame = {target = curKey.pos, eye = eye} -- 1675
					else -- 1675
						local ease = segK * segK * (3 - 2 * segK) -- 1678
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1679
						local az = prevAz + (curAz - prevAz) * ease -- 1684
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1685
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1686
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1687
						local eye = Vec3( -- 1688
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1689
							target.y + math.sin(tilt) * d, -- 1690
							target.z + math.cos(az) * math.cos(tilt) * d -- 1691
						) -- 1691
						frame = {target = target, eye = eye} -- 1693
					end -- 1693
				else -- 1693
					local targetBody = nil -- 1696
					local wps = goalWaypoints(level.goal) -- 1697
					if #wps > 0 then -- 1697
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1699
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1699
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1701
					end -- 1701
					if targetBody == nil and #level.bodies > 0 then -- 1701
						targetBody = level.bodies[#level.bodies] -- 1704
					end -- 1704
					if targetBody ~= nil then -- 1704
						local pwTarget = planeToWorld( -- 1708
							bodyPositionAt(targetBody, tNow), -- 1708
							0 -- 1708
						) -- 1708
						local pwProbe = planeToWorld(probePos, 0) -- 1709
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1710
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1711
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1712
						if k < 0.35 then -- 1712
							local e1 = k / 0.35 -- 1715
							local az = (0.2 + e1 * 0.15) * math.pi -- 1716
							local tilt = 0.35 * math.pi -- 1717
							local eye = Vec3( -- 1718
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1719
								pwTarget.y + math.sin(tilt) * distTarget, -- 1720
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1721
							) -- 1721
							frame = {target = pwTarget, eye = eye} -- 1723
						elseif k < 0.72 then -- 1723
							local e2 = (k - 0.35) / 0.37 -- 1725
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1726
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1727
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1728
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1729
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1730
							local eye = Vec3( -- 1735
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1736
								targetCenter.y + curDist * 0.8, -- 1737
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1738
							) -- 1738
							frame = {target = targetCenter, eye = eye} -- 1740
						else -- 1740
							local e3 = (k - 0.72) / 0.28 -- 1742
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1743
							local az = 0.25 * math.pi -- 1744
							local tilt = 0.36 * math.pi -- 1745
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1746
							local eye = Vec3( -- 1747
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1748
								pwProbe.y + math.sin(tilt) * curDist, -- 1749
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1750
							) -- 1750
							frame = {target = pwProbe, eye = eye} -- 1752
						end -- 1752
					end -- 1752
				end -- 1752
			end -- 1752
		end -- 1752
		frame = applyObserve(frame) -- 1759
		deps.rig.apply(deps.camera, frame) -- 1760
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1761
		local basis = makeBasis(frame) -- 1762
		if core.viewMode == "2D" then -- 1762
			local sp = deps.plan:probeScreen() -- 1768
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1769
		else -- 1769
			local pp = projectPrepared( -- 1771
				planeToWorld(probePos, 0), -- 1771
				basis -- 1771
			) -- 1771
			if pp ~= nil then -- 1771
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1772
			end -- 1772
		end -- 1772
		if not aimed then -- 1772
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1772
				deps.aim:setTransferInfo( -- 1782
					distance( -- 1782
						probePos, -- 1782
						bodyPositionAt(level.bodies[1], tNow) -- 1782
					) - level.bodies[1].radius, -- 1782
					0 -- 1782
				) -- 1782
			end -- 1782
			deps.trajectory:clearPrediction() -- 1786
			deps.plan:clearPrediction() -- 1787
			predForce = true -- 1788
		else -- 1788
			local aimKey = (((__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4)) .. "|") .. (core.brakeMode and "B" or "C") -- 1794
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1795
			predAccum = predAccum + dt -- 1796
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1797
			if needIt then -- 1797
				predForce = false -- 1799
				predAccum = 0 -- 1800
				predAimKey = aimKey -- 1801
				predPosKey = posKey -- 1802
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, level.transfer == nil and core.brakeMode, level.maxSteps) -- 1805
				local predictSample = level.transfer ~= nil and 1 or 4 -- 1806
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1807
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1810
					dt = core.dt, -- 1810
					sampleEvery = predictSample, -- 1810
					escapeRadius = level.escapeRadius, -- 1810
					t0 = tNow, -- 1810
					brake = motion.brake -- 1810
				}) -- 1810
				predPoints = sim.points -- 1812
				if level.transfer ~= nil then -- 1812
					local analysis = analyzeTransfer( -- 1814
						sim, -- 1814
						level.bodies, -- 1814
						level.goal.planetIndex, -- 1814
						level.transfer, -- 1814
						core.dt * predictSample, -- 1814
						tNow -- 1814
					) -- 1814
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1815
						sim.points, -- 1815
						level.bodies, -- 1815
						level.goal, -- 1815
						core.dt * predictSample, -- 1815
						tNow, -- 1815
						sim.velocities -- 1815
					) -- 1815
					if analysis ~= nil then -- 1815
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1816
					elseif gi >= 0 then -- 1816
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1817
					end -- 1817
					local radius = distance( -- 1818
						probePos, -- 1818
						bodyPositionAt(level.bodies[1], tNow) -- 1818
					) -- 1818
					local plan = planTransfer( -- 1819
						level.bodies[1].gm, -- 1819
						radius, -- 1819
						probeVel, -- 1819
						core.aim.power, -- 1819
						level.transfer.apoapsisMax, -- 1819
						level.transfer.mode, -- 1819
						level.transfer.periapsisMin -- 1819
					) -- 1819
					if deps.aim.setTransferInfo ~= nil then -- 1819
						deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1820
					end -- 1820
				end -- 1820
				predTimes = {} -- 1822
				do -- 1822
					local pi = 0 -- 1823
					while pi < #predPoints do -- 1823
						predTimes[#predTimes + 1] = tNow + pi * core.dt * predictSample -- 1823
						pi = pi + 1 -- 1823
					end -- 1823
				end -- 1823
			end -- 1823
			deps.trajectory:setPrediction(predPoints, basis) -- 1825
			deps.plan:setPrediction(predPoints) -- 1827
			if #core.stars > 0 then -- 1827
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1830
				local stEval = evaluateCollectedStars( -- 1831
					predPoints, -- 1831
					core.stars, -- 1831
					30, -- 1831
					core.starOrbits, -- 1831
					predTimes -- 1831
				) -- 1831
				core.previewStarsCount = stEval.count -- 1832
				deps.plan:setStars(live, stEval.collected) -- 1833
			end -- 1833
		end -- 1833
		if idleOrbit ~= nil then -- 1833
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1838
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1839
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1840
		end -- 1840
		local rings = goalRingsAt(tNow) -- 1842
		deps.trajectory:setGoalRings(rings, basis) -- 1843
		deps.trajectory:clearTrail() -- 1844
		deps.plan:setGoalRings(rings) -- 1846
		deps.plan:clearTrail() -- 1847
		deps.plan:flush() -- 1848
	end -- 1550
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
	local function updateFinale() -- 1863
		deps.aim:setEnabled(false) -- 1864
		if core.flight == nil then -- 1864
			return -- 1865
		end -- 1865
		local idx = ____exports.coreProbeIndex(core) -- 1866
		local pos = core.flight.points[idx + 1] -- 1867
		local tWorld = core.t0 + core.flightTime -- 1868
		deps.scene.syncBodies(tWorld) -- 1871
		deps.scene.syncProbe(pos) -- 1872
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1873
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1876
		deps.camera:lookAt( -- 1877
			frame.eye, -- 1877
			frame.target, -- 1877
			Vec3(0, 1, 0) -- 1877
		) -- 1877
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1878
		local trail = {} -- 1881
		do -- 1881
			local i = 0 -- 1882
			while i <= idx do -- 1882
				trail[#trail + 1] = core.flight.points[i + 1] -- 1882
				i = i + 1 -- 1882
			end -- 1882
		end -- 1882
		local rings = goalRingsAt(tWorld, idx) -- 1883
		local basis = makeBasis(frame) -- 1884
		if deps.trajectory.setBurn ~= nil then -- 1884
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1886
		end -- 1886
		deps.trajectory:clearOrbitRing() -- 1887
		deps.plan:clearProbeOrbit() -- 1888
		deps.trajectory:setTrail(trail, basis) -- 1889
		deps.trajectory:setGoalRings(rings, basis) -- 1890
		deps.plan:clearPrediction() -- 1891
		deps.plan:setGoalRings(rings) -- 1892
		deps.plan:flush() -- 1893
	end -- 1863
	local function updateFlying(dt) -- 1895
		deps.aim:setEnabled(false) -- 1896
		local wasCompleted = core.missionCompleted -- 1899
		local entered = ____exports.coreUpdate(core, dt, level) -- 1900
		if not wasCompleted and core.missionCompleted then -- 1900
			markerElapsed = 0 -- 1902
			print("[escape-velocity] success marker triggered once") -- 1903
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1904
			if deps.onMissionCompleted ~= nil then -- 1904
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1905
			end -- 1905
		end -- 1905
		if core.flight == nil then -- 1905
			return entered -- 1907
		end -- 1907
		local idx = ____exports.coreProbeIndex(core) -- 1909
		local pos = core.flight.points[idx + 1] -- 1910
		local tWorld = core.t0 + core.flightTime -- 1914
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1914
			lastSlowmo = core.slowmo -- 1918
			lastSlowmoBody = core.slowmoBody -- 1919
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1920
			local nearD = near ~= nil and distance( -- 1921
				pos, -- 1921
				bodyPositionAt(near, tWorld) -- 1921
			) or 0 -- 1921
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1922
		end -- 1922
		flightLogT = flightLogT + dt -- 1929
		if flightLogT >= 0.5 then -- 1929
			flightLogT = 0 -- 1931
			local total = (#core.flight.points - 1) * core.dt -- 1932
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1933
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1935
					core.flightTime, -- 1935
					core.burnDuration, -- 1935
					level.transfer, -- 1935
					core.flyby, -- 1935
					core.dt -- 1935
				) or (core.slowmo and SlowMoFactor or 1)), -- 1935
				2 -- 1935
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1935
		end -- 1935
		deps.scene.syncBodies(tWorld) -- 1939
		if deps.scene.syncStars ~= nil then -- 1939
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1940
		end -- 1940
		deps.scene.syncProbe(pos) -- 1941
		if idx > 0 then -- 1941
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1943
		end -- 1943
		do -- 1943
			local s = 0 -- 1947
			while s < #core.stars do -- 1947
				if not core.collectedStars[s + 1] then -- 1947
					local fromLevel = level.starOrbits -- 1949
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1950
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1951
					local dx = pos.x - stPos.x -- 1952
					local dy = pos.y - stPos.y -- 1953
					if dx * dx + dy * dy <= 30 * 30 then -- 1953
						core.collectedStars[s + 1] = true -- 1955
						if deps.scene.setStarCollected ~= nil then -- 1955
							deps.scene.setStarCollected(s) -- 1957
						end -- 1957
						deps.plan:setStars(core.stars, core.collectedStars) -- 1959
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1960
					end -- 1960
				end -- 1960
				s = s + 1 -- 1947
			end -- 1947
		end -- 1947
		local fr -- 1969
		local closeDist = nil -- 1970
		if core.slowmo and core.slowmoBody >= 0 then -- 1970
			local near = level.bodies[core.slowmoBody + 1] -- 1972
			local nearR = near.radius -- 1974
			do -- 1974
				local i = 0 -- 1975
				while i < #level.bodies do -- 1975
					local b = level.bodies[i + 1] -- 1976
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1976
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1976
							nearR = deps.visuals[i + 1].displayRadius -- 1978
						end -- 1978
						break -- 1979
					end -- 1979
					i = i + 1 -- 1975
				end -- 1975
			end -- 1975
			fr = { -- 1982
				pts = { -- 1982
					pos, -- 1982
					bodyPositionAt(near, tWorld) -- 1982
				}, -- 1982
				radii = {deps.scene.probeRadius, nearR} -- 1982
			} -- 1982
			closeDist = SlowMoCloseDist -- 1983
		else -- 1983
			fr = framingPoints(pos, tWorld) -- 1985
		end -- 1985
		local baseFrame = level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalCamera(pos, tWorld, dt) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist)) -- 1987
		local frame = level.transfer ~= nil and not transferCinematic(level.transfer) and applyObserve(baseFrame) or baseFrame -- 1988
		deps.rig.apply(deps.camera, frame) -- 1989
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1990
		local basis = makeBasis(frame) -- 1991
		if deps.trajectory.setBurn ~= nil then -- 1991
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1994
		end -- 1994
		if deps.plan.setBurn ~= nil then -- 1994
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1995
		end -- 1995
		local trail = {} -- 1996
		do -- 1996
			local i = 0 -- 1997
			while i <= idx do -- 1997
				trail[#trail + 1] = core.flight.points[i + 1] -- 1997
				i = i + 1 -- 1997
			end -- 1997
		end -- 1997
		local rings = goalRingsAt(tWorld, idx) -- 1998
		deps.trajectory:clearOrbitRing() -- 2000
		deps.plan:clearProbeOrbit() -- 2001
		deps.trajectory:setTrail(trail, basis) -- 2002
		deps.trajectory:setGoalRings(rings, basis) -- 2003
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 2006
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 2007
		deps.plan:setStars( -- 2008
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 2008
			core.collectedStars -- 2008
		) -- 2008
		deps.plan:setTrail(trail) -- 2009
		deps.plan:clearPrediction() -- 2010
		deps.plan:setGoalRings(rings) -- 2011
		deps.plan:flush() -- 2012
		return entered -- 2014
	end -- 1895
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 2028
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 2029
		core.t0 = next.t0 -- 2030
		clock = next.clock -- 2031
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 2032
	end -- 2028
	local function finishFlight() -- 2035
		if core.result == nil then -- 2035
			return -- 2036
		end -- 2036
		local toFinale = deps.finale == true and core.result == "success" -- 2037
		if toFinale then -- 2037
			____exports.coreEnterFinale(core) -- 2038
		end -- 2038
		deps:onResult( -- 2039
			core.result, -- 2039
			____exports.calcFlightTelemetry(core, level) -- 2039
		) -- 2039
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 2039
			local ____end = #core.flight.points - 1 -- 2041
			deps:onFinale({ -- 2042
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 2042
				time = core.flightTime, -- 2042
				tWorld = core.t0 + core.flightTime -- 2042
			}) -- 2042
		end -- 2042
		deps:onPhase(toFinale and "Finale" or "Result") -- 2044
	end -- 2035
	local function update(dt) -- 2047
		if markerElapsed >= 0 and markerElapsed < 0.6 then -- 2047
			markerElapsed = math.min(0.6, markerElapsed + dt) -- 2048
		end -- 2048
		applyView() -- 2051
		if core.phase == "Aiming" or core.phase == "Armed" then -- 2051
			updateAiming(dt) -- 2053
		elseif core.phase == "Flying" then -- 2053
			local entered = updateFlying(dt) -- 2055
			if entered then -- 2055
				finishFlight() -- 2056
			end -- 2056
		elseif core.phase == "Finale" then -- 2056
			updateFinale() -- 2058
		elseif core.phase == "Result" and core.missionCompleted and level.transfer ~= nil then -- 2058
			local rings = goalRingsAt( -- 2061
				core.t0 + core.flightTime, -- 2061
				____exports.coreProbeIndex(core) -- 2061
			) -- 2061
			deps.plan:setGoalRings(rings) -- 2062
			deps.plan:flush() -- 2062
			if cineFrame ~= nil then -- 2062
				deps.trajectory:setGoalRings( -- 2063
					rings, -- 2063
					makeBasis(cineFrame) -- 2063
				) -- 2063
			end -- 2063
		end -- 2063
	end -- 2047
	return { -- 2068
		phase = function() return core.phase end, -- 2069
		speedPow = function() return speedPow end, -- 2070
		speedMaxPow = function() return speedMaxPow end, -- 2071
		isPaused = function() return paused end, -- 2072
		speedRate = function() -- 2073
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 2073
				return core.playback * transferPlaybackRate( -- 2074
					core.flightTime, -- 2074
					core.burnDuration, -- 2074
					level.transfer, -- 2074
					core.flyby, -- 2074
					core.dt -- 2074
				) -- 2074
			end -- 2074
			return core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 2075
		end, -- 2073
		missionSeconds = function() -- 2077
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 2078
			return speedUnit > 0 and w / speedUnit or 0 -- 2079
		end, -- 2077
		speedUp = function() -- 2081
			if speedPow >= speedMaxPow then -- 2081
				return -- 2082
			end -- 2082
			speedPow = speedPow + 1 -- 2083
			paused = false -- 2084
			applySpeedRate() -- 2085
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2086
		end, -- 2081
		speedDown = function() -- 2088
			if speedPow <= 0 then -- 2088
				return -- 2089
			end -- 2089
			speedPow = speedPow - 1 -- 2090
			paused = false -- 2091
			applySpeedRate() -- 2092
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2093
		end, -- 2088
		togglePause = function() -- 2095
			paused = not paused -- 2096
			applySpeedRate() -- 2097
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 2098
		end, -- 2095
		result = function() return core.result end, -- 2100
		onAimDrag = function(____, a) -- 2101
			if introTourActive then -- 2101
				finishIntroTour() -- 2102
			end -- 2102
			core.aim = a -- 2103
			if level.transfer ~= nil then -- 2103
				local radius = distance( -- 2105
					probePos, -- 2105
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 2105
				) -- 2105
				local plan = planTransfer( -- 2106
					level.bodies[1].gm, -- 2106
					radius, -- 2106
					probeVel, -- 2106
					a.power, -- 2106
					level.transfer.apoapsisMax, -- 2106
					level.transfer.mode, -- 2106
					level.transfer.periapsisMin -- 2106
				) -- 2106
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 2107
				if deps.aim.setTransferInfo ~= nil then -- 2107
					deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 2108
				end -- 2108
			end -- 2108
			aimed = true -- 2110
		end, -- 2101
		aimReady = function() -- 2112
			predForce = true -- 2114
			if not ____exports.coreArm(core) then -- 2114
				return -- 2115
			end -- 2115
			if level.transfer ~= nil then -- 2115
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 2116
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 2116
					4 -- 2116
				)) -- 2116
			end -- 2116
			applyView() -- 2117
			deps:onPhase("Armed") -- 2118
		end, -- 2112
		cancelAim = function() -- 2120
			if not ____exports.coreCancelArm(core) then -- 2120
				return -- 2121
			end -- 2121
			aimed = false -- 2122
			predForce = true -- 2123
			deps.trajectory:clearPrediction() -- 2124
			deps.plan:clearPrediction() -- 2125
			applyView() -- 2126
			deps:onPhase("Aiming") -- 2127
			print("[escape-velocity] aim cancelled") -- 2128
		end, -- 2120
		launchArmed = function() -- 2130
			if core.phase ~= "Armed" then -- 2130
				return -- 2132
			end -- 2132
			resetCinematic() -- 2133
			applyFlightSpeed() -- 2134
			handoffDate(true) -- 2135
			____exports.coreLaunch( -- 2136
				core, -- 2136
				core.aim.velocity, -- 2136
				level, -- 2136
				probePos, -- 2136
				probeVel -- 2136
			) -- 2136
			deps.trajectory:clearPrediction() -- 2137
			deps.plan:clearPrediction() -- 2138
			applyView() -- 2139
			deps:onPhase("Flying") -- 2140
		end, -- 2130
		armed = function() return core.phase == "Armed" end, -- 2142
		viewMode = function() return core.viewMode end, -- 2143
		toggleViewMode = function() -- 2144
			____exports.coreToggleView(core) -- 2146
			applyView() -- 2147
		end, -- 2144
		cameraFocus = function() return focusMode end, -- 2149
		flightStage = function() return level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalShotAt( -- 2150
			core.flightTime, -- 2150
			core.burnDuration, -- 2150
			core.flyby, -- 2150
			level.transfer.orbital, -- 2150
			core.dt -- 2150
		) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 2150
			core.flightTime, -- 2151
			core.burnDuration, -- 2151
			core.flyby, -- 2151
			level.transfer.flyby, -- 2151
			core.dt -- 2151
		) or nil) end, -- 2151
		cycleCameraFocus = function() -- 2152
			if not transferCinematic(level.transfer) or core.phase ~= "Flying" then -- 2152
				return -- 2153
			end -- 2153
			local ____temp_7 -- 2154
			if level.transfer ~= nil and level.transfer.orbital ~= nil then -- 2154
				local ____array_6 = __TS__SparseArrayNew( -- 2154
					"Auto", -- 2154
					"Probe", -- 2154
					table.unpack(__TS__ArrayMap( -- 2154
						level.transfer.orbital.encounters, -- 2154
						function(____, e) return e.focus end -- 2154
					)) -- 2154
				) -- 2154
				__TS__SparseArrayPush(____array_6, "Sun", "Overview") -- 2154
				____temp_7 = {__TS__SparseArraySpread(____array_6)} -- 2154
			else -- 2154
				____temp_7 = nil -- 2154
			end -- 2154
			local modes = ____temp_7 -- 2154
			focusMode = nextCameraFocus(focusMode, modes) -- 2155
			obsYawDeg = 0 -- 2156
			obsPitchDeg = 0 -- 2156
			obsZoom = 1 -- 2156
			print("[escape-velocity] camera focus -> " .. focusMode) -- 2157
		end, -- 2152
		missionCompleted = function() return core.missionCompleted end, -- 2159
		markerElapsed = function() return markerElapsed end, -- 2160
		endViewing = function() -- 2161
			if not ____exports.coreEndViewing(core) then -- 2161
				return -- 2162
			end -- 2162
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 2163
			finishFlight() -- 2164
		end, -- 2161
		skipIntroTour = function() -- 2166
			finishIntroTour() -- 2167
		end, -- 2166
		isIntroTourActive = function() return introTourActive end, -- 2169
		observeDrag = function(____, dx, dy) -- 2170
			if introTourActive then -- 2170
				finishIntroTour() -- 2172
				return -- 2173
			end -- 2173
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2175
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2176
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2177
			if obsPitchDeg > 40 then -- 2177
				obsPitchDeg = 40 -- 2178
			end -- 2178
			if obsPitchDeg < -40 then -- 2178
				obsPitchDeg = -40 -- 2179
			end -- 2179
		end, -- 2170
		observeZoom = function(____, deltaDist) -- 2181
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2182
			if obsZoom < 0.4 then -- 2182
				obsZoom = 0.4 -- 2183
			end -- 2183
			if obsZoom > 1.8 then -- 2183
				obsZoom = 1.8 -- 2184
			end -- 2184
		end, -- 2181
		launch = function(____, v) -- 2186
			applyFlightSpeed() -- 2187
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2187
				return -- 2188
			end -- 2188
			resetCinematic() -- 2189
			handoffDate(true) -- 2190
			____exports.coreLaunch( -- 2192
				core, -- 2192
				v, -- 2192
				level, -- 2192
				probePos, -- 2192
				probeVel -- 2192
			) -- 2192
			deps.trajectory:clearPrediction() -- 2193
			deps.plan:clearPrediction() -- 2194
			applyView() -- 2195
			deps:onPhase("Flying") -- 2196
		end, -- 2186
		retry = function() -- 2198
			resetCinematic() -- 2199
			handoffDate(false) -- 2200
			aimed = false -- 2201
			introTourActive = false -- 2202
			____exports.coreRetry(core, level.aimMin) -- 2203
			if deps.scene.resetStars ~= nil then -- 2203
				deps.scene.resetStars() -- 2205
			end -- 2205
			deps.plan:setStars(core.stars, core.collectedStars) -- 2207
			deps.trajectory:clearTrail() -- 2208
			deps.trajectory:clearPrediction() -- 2209
			deps.trajectory:clearGoalRings() -- 2210
			deps.plan:clearTrail() -- 2211
			deps.plan:clearPrediction() -- 2212
			deps.plan:clearGoalRings() -- 2213
			applyView() -- 2214
			deps:onPhase("Aiming") -- 2215
		end, -- 2198
		backToSelect = function() -- 2217
			if not ____exports.coreBackToSelect(core) then -- 2217
				return false -- 2218
			end -- 2218
			deps.aim:setEnabled(false) -- 2220
			deps.trajectory:clearTrail() -- 2221
			deps.trajectory:clearPrediction() -- 2222
			deps.trajectory:clearGoalRings() -- 2223
			deps.plan:clearTrail() -- 2224
			deps.plan:clearPrediction() -- 2225
			deps.plan:clearGoalRings() -- 2226
			applyView() -- 2227
			deps:onPhase("LevelSelect") -- 2228
			return true -- 2229
		end, -- 2217
		startLevel = function() -- 2231
			resetCinematic() -- 2232
			aimed = false -- 2233
			____exports.coreRetry(core, level.aimMin) -- 2234
			if deps.scene.resetStars ~= nil then -- 2234
				deps.scene.resetStars() -- 2236
			end -- 2236
			deps.plan:setStars(core.stars, core.collectedStars) -- 2238
			deps.rig.reset() -- 2239
			introTourActive = false -- 2241
			core.viewMode = "2D" -- 2242
			appliedMode = "" -- 2243
			applyView() -- 2244
			prepareIdle() -- 2245
			deps.trajectory:clearTrail() -- 2246
			deps.trajectory:clearPrediction() -- 2247
			deps.trajectory:clearGoalRings() -- 2248
			deps.plan:clearTrail() -- 2249
			deps.plan:clearPrediction() -- 2250
			deps.plan:clearGoalRings() -- 2251
			deps:onPhase("Aiming") -- 2252
		end, -- 2231
		stepTime = function(____, dir, span) -- 2254
			if not ____exports.coreTimeWarpAllowed(core) then -- 2254
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2258
				return -- 2259
			end -- 2259
			local span0 = span > 0 and span or 0 -- 2261
			clock = clock + dir * TimeWarpStep -- 2262
			if clock < 0 then -- 2262
				clock = 0 -- 2263
			end -- 2263
			if span0 > 0 and clock > span0 then -- 2263
				clock = span0 -- 2264
			end -- 2264
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2266
		end, -- 2254
		dateNow = function() return core.t0 + clock end, -- 2268
		setBrakeMode = function(____, on) -- 2269
			core.brakeMode = on -- 2270
		end, -- 2269
		brakeMode = function() return core.brakeMode end, -- 2273
		setPlaybackSpeed = function(____, speed) -- 2274
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2274
				return -- 2276
			end -- 2276
			core.playback = speed -- 2277
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2278
		end, -- 2274
		playbackSpeed = function() return core.playback end, -- 2280
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2281
		starsNow = function() -- 2282
			if core.phase == "Flying" or core.phase == "Result" then -- 2282
				local n = 0 -- 2284
				do -- 2284
					local i = 0 -- 2285
					while i < #core.collectedStars do -- 2285
						if core.collectedStars[i + 1] then -- 2285
							n = n + 1 -- 2285
						end -- 2285
						i = i + 1 -- 2285
					end -- 2285
				end -- 2285
				return n -- 2286
			end -- 2286
			return core.previewStarsCount -- 2288
		end, -- 2282
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 2290
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 2291
		hasBraked = function() return core.hasBraked end, -- 2292
		update = function(____, frameDt) return update(frameDt) end -- 2294
	} -- 2294
end -- 1052
return ____exports -- 1052
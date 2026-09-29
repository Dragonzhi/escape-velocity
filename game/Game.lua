-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayPush = ____lualib.__TS__ArrayPush -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
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
local ____ObserveCamera = require("game.ObserveCamera") -- 31
local captureObserve = ____ObserveCamera.captureObserve -- 31
local rotateObserve = ____ObserveCamera.rotateObserve -- 31
local stepObserve = ____ObserveCamera.stepObserve -- 31
local zoomObserve = ____ObserveCamera.zoomObserve -- 31
local ____Projection = require("game.Projection") -- 33
local FLIP_Y = ____Projection.FLIP_Y -- 33
local HANDEDNESS = ____Projection.HANDEDNESS -- 33
local prepareCamera = ____Projection.prepareCamera -- 33
local projectPrepared = ____Projection.projectPrepared -- 33
local ____LevelData = require("game.LevelData") -- 34
local GameSecondsPerRealSecond = ____LevelData.GameSecondsPerRealSecond -- 34
local bodyVelocityAt = ____LevelData.bodyVelocityAt -- 34
local findGoalIndex = ____LevelData.findGoalIndex -- 34
local goalPositionAt = ____LevelData.goalPositionAt -- 34
local goalWaypoints = ____LevelData.goalWaypoints -- 34
local waypointProgress = ____LevelData.waypointProgress -- 34
local ____Transfer = require("game.Transfer") -- 35
local advanceTransferPlayback = ____Transfer.advanceTransferPlayback -- 35
local analyzeTransfer = ____Transfer.analyzeTransfer -- 35
local nextCameraFocus = ____Transfer.nextCameraFocus -- 35
local orbitalShotAt = ____Transfer.orbitalShotAt -- 35
local planTransfer = ____Transfer.planTransfer -- 35
local successMarkerFrame = ____Transfer.successMarkerFrame -- 35
local transferCinematic = ____Transfer.transferCinematic -- 35
local transferPlaybackRate = ____Transfer.transferPlaybackRate -- 35
local transferShotAt = ____Transfer.transferShotAt -- 35
local ____Config = require("game.Config") -- 37
local AimMinSpeed = ____Config.AimMinSpeed -- 38
local CameraFramingBudget = ____Config.CameraFramingBudget -- 38
local CameraTiltMax = ____Config.CameraTiltMax -- 38
local CameraTiltMin = ____Config.CameraTiltMin -- 38
local FlightPlayback = ____Config.FlightPlayback -- 38
local PhysicsStep = ____Config.PhysicsStep -- 39
local PredictSteps = ____Config.PredictSteps -- 39
local SlowMoCloseDist = ____Config.SlowMoCloseDist -- 39
local SlowMoFactor = ____Config.SlowMoFactor -- 39
local SlowMoFloorDist = ____Config.SlowMoFloorDist -- 39
local SlowMoRadiusFactor = ____Config.SlowMoRadiusFactor -- 40
local TimeWarpStep = ____Config.TimeWarpStep -- 40
local FinaleCamDist = ____Config.FinaleCamDist -- 41
local FinaleCamTiltDeg = ____Config.FinaleCamTiltDeg -- 41
local PlaneToWorldX = ____Config.PlaneToWorldX -- 41
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 41
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
function ____exports.resolveResult(outcome, goalIndex, goal) -- 74
	if goal.kind == "escape" then -- 74
		local wps = goalWaypoints(goal) -- 76
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 76
			return "success" -- 77
		end -- 77
	elseif goalIndex >= 0 then -- 77
		return "success" -- 79
	end -- 79
	if outcome == "crashed" then -- 79
		return "crashed" -- 81
	end -- 81
	return "missed" -- 82
end -- 74
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
--- 按关卡上下界调整档位，供状态转换与边界测试共用。
function ____exports.shiftSpeedPow(pow, minPow, maxPow, direction) -- 242
	if direction < 0 then -- 242
		return pow > minPow and pow - 1 or pow -- 243
	end -- 243
	if direction > 0 then -- 243
		return pow < maxPow and pow + 1 or pow -- 244
	end -- 244
	return pow -- 245
end -- 242
local function neutralAim(minSpeed) -- 248
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 249
end -- 248
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 253
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 254
end -- 253
--- 星尘在时刻 t 的位置（没有轨道就用静态坐标）。
local function starPositionsNow(orbits, fallback, t) -- 258
	local out = {} -- 259
	do -- 259
		local i = 0 -- 260
		while i < #fallback do -- 260
			local orbit = i < #orbits and orbits[i + 1] or nil -- 261
			out[#out + 1] = starPositionAt(orbit, fallback[i + 1], t) -- 262
			i = i + 1 -- 260
		end -- 260
	end -- 260
	return out -- 264
end -- 258
function ____exports.createCore(dt, stars, starOrbits) -- 267
	local stList = stars ~= nil and stars or ({}) -- 268
	local colList = {} -- 269
	do -- 269
		local i = 0 -- 270
		while i < #stList do -- 270
			colList[#colList + 1] = false -- 270
			i = i + 1 -- 270
		end -- 270
	end -- 270
	local orbits = starOrbits ~= nil and starOrbits or ({}) -- 271
	return { -- 272
		phase = "Aiming", -- 273
		aim = neutralAim(AimMinSpeed), -- 274
		flight = nil, -- 275
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 276
		burnDuration = 0, -- 277
		t0 = 0, -- 278
		flightTime = 0, -- 279
		missionCompleted = false, -- 280
		flyby = nil, -- 281
		goalIndex = -1, -- 282
		result = nil, -- 283
		viewMode = "2D", -- 285
		playback = FlightPlayback, -- 287
		slowmo = false, -- 288
		slowmoBody = -1, -- 289
		stars = stList, -- 290
		starOrbits = orbits, -- 291
		collectedStars = colList, -- 292
		collectedBonus = {}, -- 293
		bonusRockets = 0, -- 294
		previewStarsCount = 0 -- 295
	} -- 295
end -- 267
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 307
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 308
	return core.viewMode -- 309
end -- 307
--- 教学关显式指定中心宿主；旧关卡仍按最近的有引力天体选择。
function ____exports.selectIdleHost(bodies, start, preferred) -- 313
	if preferred ~= nil and bodies[preferred + 1] ~= nil and bodies[preferred + 1].gm > 0 then -- 313
		return preferred -- 314
	end -- 314
	local index = -1 -- 315
	local nearest = 1000000000 -- 316
	do -- 316
		local i = 0 -- 317
		while i < #bodies do -- 317
			do -- 317
				if bodies[i + 1].gm <= 0 then -- 317
					goto __continue25 -- 318
				end -- 318
				local d = distance( -- 319
					bodyPositionAt(bodies[i + 1], 0), -- 319
					start -- 319
				) -- 319
				if d < nearest then -- 319
					nearest = d -- 320
					index = i -- 320
				end -- 320
			end -- 320
			::__continue25:: -- 320
			i = i + 1 -- 317
		end -- 317
	end -- 317
	return index -- 322
end -- 313
--- 预测线与瞬时点火的初始速度。教学关实际发射另行积分有限燃烧。
function ____exports.burnToMotion(burn, probeVel0) -- 326
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 327
	return {x = v0.x + burn.x, y = v0.y + burn.y} -- 328
end -- 326
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 337
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 337
		return -- 339
	end -- 339
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 340
	local motion = ____exports.burnToMotion(burn, base) -- 341
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 342
	core.burnDuration = level.transfer ~= nil and mag / level.transfer.thrustAcceleration or 0 -- 343
	local thrust = core.burnDuration > 0 and ({acceleration = {x = burn.x / core.burnDuration, y = burn.y / core.burnDuration}, duration = core.burnDuration}) or nil -- 344
	local p0 = from ~= nil and from or level.probeStart -- 345
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = level.transfer ~= nil and base ~= nil and base or motion}, level.bodies, { -- 346
		steps = level.maxSteps, -- 349
		dt = core.dt, -- 349
		sampleEvery = 1, -- 349
		escapeRadius = level.escapeRadius, -- 349
		t0 = core.t0, -- 349
		initialBurn = thrust -- 349
	}) -- 349
	core.flight = flight -- 351
	core.missionCompleted = false -- 352
	local ____core_1 = core -- 353
	local ____temp_0 -- 353
	if level.transfer ~= nil then -- 353
		____temp_0 = analyzeTransfer( -- 353
			flight, -- 353
			level.bodies, -- 353
			level.goal.planetIndex, -- 353
			level.transfer, -- 353
			core.dt, -- 353
			core.t0 -- 353
		) -- 353
	else -- 353
		____temp_0 = nil -- 353
	end -- 353
	____core_1.flyby = ____temp_0 -- 353
	core.goalIndex = findGoalIndex( -- 354
		flight.points, -- 354
		level.bodies, -- 354
		level.goal, -- 354
		core.dt, -- 354
		core.t0, -- 354
		flight.velocities -- 354
	) -- 354
	core.result = core.goalIndex >= 0 and "success" or (flight.outcome == "crashed" and "crashed" or "missed") -- 355
	core.collectedBonus = {} -- 356
	core.bonusRockets = 0 -- 357
	do -- 357
		local i = 0 -- 358
		while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 358
			local ____core_collectedBonus_2 = core.collectedBonus -- 358
			____core_collectedBonus_2[#____core_collectedBonus_2 + 1] = false -- 358
			i = i + 1 -- 358
		end -- 358
	end -- 358
	if core.flyby ~= nil then -- 358
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 359
	end -- 359
	if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 359
		for ____, e in ipairs(core.flyby.encounters) do -- 362
			print((((((((("[escape-velocity] encounter body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " energy=") .. __TS__NumberToFixed(e.energyChange, 2)) .. " work=") .. __TS__NumberToFixed(e.work, 2)) .. " passed=") .. (e.passed and "1" or "0")) -- 362
		end -- 362
	end -- 362
	if core.flyby ~= nil and core.flyby.destination ~= nil then -- 362
		local e = core.flyby.destination -- 364
		print((((((((("[escape-velocity] destination body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " entry=") .. __TS__NumberToFixed(e.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(e.exitIndex, 0)) .. " passed=") .. (e.passed and "1" or "0")) -- 365
	end -- 365
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.x, 5)) .. ",") .. __TS__NumberToFixed(motion.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. (core.result ~= nil and core.result or "pending")) -- 369
	core.flightTime = 0 -- 374
	core.slowmo = false -- 376
	core.slowmoBody = -1 -- 377
	core.phase = "Flying" -- 378
	core.viewMode = "3D" -- 380
end -- 337
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 389
	if core.phase ~= "Aiming" then -- 389
		return false -- 390
	end -- 390
	core.phase = "Armed" -- 391
	return true -- 392
end -- 389
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 396
	if core.phase ~= "Armed" then -- 396
		return false -- 397
	end -- 397
	core.phase = "Aiming" -- 398
	return true -- 399
end -- 396
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 413
	return core.phase == "Aiming" or core.phase == "Armed" -- 414
end -- 413
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 430
	if toT0 then -- 430
		return {t0 = clock, clock = 0} -- 431
	end -- 431
	return {t0 = 0, clock = t0} -- 432
end -- 430
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 444
	local host = -1 -- 454
	do -- 454
		local i = 0 -- 455
		while i < #bodies do -- 455
			do -- 455
				local b = bodies[i + 1] -- 456
				local isHost = false -- 457
				do -- 457
					local j = 0 -- 458
					while j < #bodies do -- 458
						do -- 458
							local h = bodies[j + 1].host -- 459
							if h == nil then -- 459
								goto __continue49 -- 460
							end -- 460
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 460
								isHost = true -- 461
								break -- 461
							end -- 461
						end -- 461
						::__continue49:: -- 461
						j = j + 1 -- 458
					end -- 458
				end -- 458
				if not isHost then -- 458
					goto __continue47 -- 463
				end -- 463
				if host < 0 or b.gm > bodies[host + 1].gm then -- 463
					host = i -- 464
				end -- 464
			end -- 464
			::__continue47:: -- 464
			i = i + 1 -- 455
		end -- 455
	end -- 455
	if host >= 0 then -- 455
		return host -- 466
	end -- 466
	local best = -1 -- 468
	do -- 468
		local i = 0 -- 469
		while i < #bodies do -- 469
			do -- 469
				local b = bodies[i + 1] -- 470
				if b.orbitRadius ~= 0 then -- 470
					goto __continue56 -- 471
				end -- 471
				if best < 0 or b.gm > bodies[best + 1].gm then -- 471
					best = i -- 472
				end -- 472
			end -- 472
			::__continue56:: -- 472
			i = i + 1 -- 469
		end -- 469
	end -- 469
	return best -- 474
end -- 444
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 492
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 493
	local best = -1 -- 494
	local bestD = 1000000000 -- 495
	do -- 495
		local i = 0 -- 496
		while i < #bodies do -- 496
			do -- 496
				if i == anchor then -- 496
					goto __continue61 -- 497
				end -- 497
				local b = bodies[i + 1] -- 498
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 499
				local d = distance( -- 500
					probe, -- 500
					bodyPositionAt(b, t) -- 500
				) -- 500
				if d < threshold and d < bestD then -- 500
					bestD = d -- 502
					best = i -- 503
				end -- 503
			end -- 503
			::__continue61:: -- 503
			i = i + 1 -- 496
		end -- 496
	end -- 496
	return best -- 506
end -- 492
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 510
	if core.flight == nil then -- 510
		return 0 -- 511
	end -- 511
	local idx = math.floor(core.flightTime / core.dt) -- 512
	local last = #core.flight.points - 1 -- 513
	if idx > last then -- 513
		idx = last -- 514
	end -- 514
	if idx < 0 then -- 514
		idx = 0 -- 515
	end -- 515
	return idx -- 516
end -- 510
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
function ____exports.coreUpdate(core, dt, level) -- 533
	if core.phase ~= "Flying" or core.flight == nil then -- 533
		return false -- 534
	end -- 534
	local previousIndex = ____exports.coreProbeIndex(core) -- 535
	if level ~= nil and level.transfer == nil then -- 535
		local idx = ____exports.coreProbeIndex(core) -- 539
		core.slowmoBody = ____exports.slowMotionBody( -- 540
			level.bodies, -- 540
			core.flight.points[idx + 1], -- 540
			core.t0 + core.flightTime, -- 540
			____exports.anchorBodyIndex(level.bodies), -- 540
			level.slowMoFloor -- 540
		) -- 540
		core.slowmo = core.slowmoBody >= 0 -- 541
	end -- 541
	if level ~= nil and level.transfer ~= nil then -- 541
		core.flightTime = advanceTransferPlayback( -- 545
			core.flightTime, -- 545
			dt, -- 545
			core.playback, -- 545
			core.burnDuration, -- 545
			level.transfer, -- 545
			core.flyby, -- 545
			core.dt -- 545
		) -- 545
	else -- 545
		core.flightTime = core.flightTime + dt * core.playback * (core.slowmo and SlowMoFactor or 1) -- 547
	end -- 547
	if not core.missionCompleted and core.goalIndex >= 0 and ____exports.coreProbeIndex(core) >= core.goalIndex then -- 547
		core.missionCompleted = true -- 550
		core.result = "success" -- 551
	end -- 551
	if level ~= nil and level.bonusPoints ~= nil and core.flight ~= nil then -- 551
		local ____end = ____exports.coreProbeIndex(core) -- 554
		local start = math.max(0, previousIndex) -- 555
		do -- 555
			local i = 0 -- 556
			while i < #level.bonusPoints do -- 556
				do -- 556
					if not core.collectedBonus[i + 1] then -- 556
						local point = level.bonusPoints[i + 1] -- 557
						local body = point.bodyIndex ~= nil and level.bodies[point.bodyIndex + 1] or point.orbit -- 558
						if body == nil then -- 558
							goto __continue76 -- 559
						end -- 559
						do -- 559
							local k = start -- 560
							while k <= ____end and k < #core.flight.points do -- 560
								local target = point.position ~= nil and point.position or goalPositionAt(body, core.t0 + k * core.dt, point.offset) -- 561
								if distance(core.flight.points[k + 1], target) <= point.tolerance then -- 561
									core.collectedBonus[i + 1] = true -- 563
									core.bonusRockets = core.bonusRockets + 1 -- 564
									break -- 565
								end -- 565
								k = k + 1 -- 560
							end -- 560
						end -- 560
					end -- 560
				end -- 560
				::__continue76:: -- 560
				i = i + 1 -- 556
			end -- 556
		end -- 556
	end -- 556
	if core.stars ~= nil and #core.stars > 0 then -- 556
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 573
		do -- 573
			local s = 0 -- 574
			while s < #core.stars do -- 574
				if not core.collectedStars[s + 1] then -- 574
					local orbit = s < #core.starOrbits and core.starOrbits[s + 1] or nil -- 576
					local stPos = starPositionAt(orbit, core.stars[s + 1], core.t0 + core.flightTime) -- 577
					local dx = curPos.x - stPos.x -- 578
					local dy = curPos.y - stPos.y -- 579
					if dx * dx + dy * dy <= 30 * 30 then -- 579
						core.collectedStars[s + 1] = true -- 581
					end -- 581
				end -- 581
				s = s + 1 -- 574
			end -- 574
		end -- 574
	end -- 574
	local naturalEnd = #core.flight.points - 1 -- 587
	local viewingSteps = level ~= nil and level.viewingSeconds ~= nil and math.floor(level.viewingSeconds / core.dt) or 0 -- 588
	local endIdx = core.goalIndex >= 0 and math.min(naturalEnd, core.goalIndex + viewingSteps) or naturalEnd -- 589
	if core.goalIndex >= 0 and level ~= nil and level.levelId == 1 and core.flyby ~= nil and core.flyby.viewEndIndex > core.goalIndex then -- 589
		endIdx = math.min(endIdx, core.flyby.viewEndIndex) -- 590
	end -- 590
	local ____temp_5 = core.goalIndex >= 0 and level ~= nil and level.levelId == 2 -- 591
	if ____temp_5 then -- 591
		local ____opt_3 = core.flyby -- 591
		____temp_5 = (____opt_3 and ____opt_3.destination) ~= nil -- 591
	end -- 591
	if ____temp_5 and core.flyby.destination.exitIndex >= core.goalIndex and core.flyby.destination.exitIndex < naturalEnd then -- 591
		endIdx = math.min( -- 592
			endIdx, -- 592
			core.flyby.destination.exitIndex + math.floor(6 / core.dt) -- 592
		) -- 592
	end -- 592
	if ____exports.coreProbeIndex(core) >= endIdx then -- 592
		core.flightTime = endIdx * core.dt -- 596
		core.phase = "Result" -- 597
		return true -- 598
	end -- 598
	return false -- 600
end -- 533
--- 已完成的教学关可提前结束观赏，不能用该操作跳过掠月判定。
function ____exports.coreEndViewing(core) -- 604
	if core.phase ~= "Flying" or not core.missionCompleted then -- 604
		return false -- 605
	end -- 605
	core.flightTime = ____exports.coreProbeIndex(core) * core.dt -- 606
	core.phase = "Result" -- 607
	return true -- 608
end -- 604
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 614
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 618
	local maxSpeed = 0 -- 619
	local closestDist = 1000000000 -- 620
	local eccentricity = nil -- 621
	if core.flight ~= nil then -- 621
		local pts = core.flight.points -- 624
		local vels = core.flight.velocities -- 625
		local ____end = ____exports.coreProbeIndex(core) -- 626
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 627
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 628
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 629
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 630
		do -- 630
			local k = 0 -- 632
			while k <= ____end and k < #pts do -- 632
				local p = pts[k + 1] -- 633
				if vels ~= nil and k < #vels then -- 633
					local v = vels[k + 1] -- 635
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 636
					if spd > maxSpeed then -- 636
						maxSpeed = spd -- 637
					end -- 637
				end -- 637
				if distTargetBody ~= nil then -- 637
					local t = core.t0 + k * core.dt -- 640
					local tp = bodyPositionAt(distTargetBody, t) -- 641
					local d = distance(p, tp) -- 642
					if d < closestDist then -- 642
						closestDist = d -- 643
					end -- 643
				end -- 643
				k = k + 1 -- 632
			end -- 632
		end -- 632
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 632
			local tEnd = core.t0 + ____end * core.dt -- 648
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 649
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 650
			local rx = pts[____end + 1].x - tpEnd.x -- 651
			local ry = pts[____end + 1].y - tpEnd.y -- 652
			local vx = vels[____end + 1].x - tvEnd.x -- 653
			local vy = vels[____end + 1].y - tvEnd.y -- 654
			local r = math.sqrt(rx * rx + ry * ry) -- 655
			local v2 = vx * vx + vy * vy -- 656
			local mu = goalBody.gm -- 657
			if r > 0 and mu > 0 then -- 657
				local energy = v2 / 2 - mu / r -- 659
				local h = rx * vy - ry * vx -- 660
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 661
				if term >= 0 then -- 661
					eccentricity = math.sqrt(term) -- 663
				end -- 663
			end -- 663
		end -- 663
	end -- 663
	local starsCollectedCount = 0 -- 669
	do -- 669
		local i = 0 -- 670
		while i < #core.collectedStars do -- 670
			if core.collectedStars[i + 1] then -- 670
				starsCollectedCount = starsCollectedCount + 1 -- 671
			end -- 671
			i = i + 1 -- 670
		end -- 670
	end -- 670
	return { -- 674
		burnDv = burnDv, -- 675
		flightTime = core.flightTime, -- 676
		closestDist = closestDist < 100000000 and closestDist or 0, -- 677
		maxSpeed = maxSpeed, -- 678
		eccentricity = eccentricity, -- 679
		starsCollected = starsCollectedCount, -- 680
		bonusRockets = core.bonusRockets -- 681
	} -- 681
end -- 614
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 686
	core.phase = "Aiming" -- 687
	core.viewMode = "2D" -- 689
	core.flight = nil -- 690
	core.flightTime = 0 -- 691
	core.missionCompleted = false -- 692
	core.flyby = nil -- 693
	core.goalIndex = -1 -- 694
	core.bonusRockets = 0 -- 695
	do -- 695
		local i = 0 -- 696
		while i < #core.collectedBonus do -- 696
			core.collectedBonus[i + 1] = false -- 696
			i = i + 1 -- 696
		end -- 696
	end -- 696
	core.result = nil -- 697
	core.burnDuration = 0 -- 698
	core.slowmo = false -- 699
	core.slowmoBody = -1 -- 700
	do -- 700
		local i = 0 -- 701
		while i < #core.collectedStars do -- 701
			core.collectedStars[i + 1] = false -- 701
			i = i + 1 -- 701
		end -- 701
	end -- 701
	core.previewStarsCount = 0 -- 702
	core.aim = neutralAim(levelAimMin(aimMin)) -- 703
end -- 686
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 717
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 717
		return false -- 719
	end -- 719
	core.phase = "LevelSelect" -- 720
	core.viewMode = "2D" -- 722
	core.flight = nil -- 723
	core.flightTime = 0 -- 724
	core.goalIndex = -1 -- 725
	core.result = nil -- 726
	core.slowmo = false -- 727
	core.slowmoBody = -1 -- 728
	return true -- 729
end -- 717
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 758
	if core.phase ~= "Result" then -- 758
		return false -- 759
	end -- 759
	core.phase = "Finale" -- 760
	return true -- 761
end -- 758
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 779
	local dist = distance > 1 and distance or 1 -- 780
	local ux = probe.x -- 782
	local uy = probe.y -- 783
	local len = math.sqrt(ux * ux + uy * uy) -- 784
	if len < 0.000001 then -- 784
		ux = 0 -- 785
		uy = 1 -- 785
	else -- 785
		ux = ux / len -- 785
		uy = uy / len -- 785
	end -- 785
	local tilt = tiltDeg * math.pi / 180 -- 786
	local flat = math.cos(tilt) * dist -- 787
	return { -- 788
		target = Vec3(0, 0, 0), -- 790
		eye = Vec3( -- 791
			ux * flat * PlaneToWorldX, -- 791
			math.sin(tilt) * dist, -- 791
			uy * flat * PlaneToWorldZ -- 791
		) -- 791
	} -- 791
end -- 779
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 939
	local introTourActive, introTourT -- 939
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 940
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 946
	local paused = false -- 947
	local speedMinPow = level.speedMinPow ~= nil and level.speedMinPow or 0 -- 948
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 949
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 951
	local function applySpeedRate() -- 952
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 953
	end -- 952
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 966
		if level.transfer ~= nil then -- 966
			paused = false -- 967
			speedPow = 0 -- 967
			applySpeedRate() -- 967
			return -- 967
		end -- 967
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 967
			return -- 968
		end -- 968
		speedPow = level.flightSpeedPow -- 969
		paused = false -- 970
		applySpeedRate() -- 971
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 972
	end -- 966
	applySpeedRate() -- 978
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 981
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
	local function applyView() -- 996
		local mode = core.viewMode -- 997
		if mode == appliedMode then -- 997
			return -- 998
		end -- 998
		appliedMode = mode -- 999
		local is2D = mode == "2D" -- 1000
		deps.plan:setVisible(is2D) -- 1001
		deps.trajectory.root.visible = not is2D -- 1002
		deps:setWorldVisible(not is2D) -- 1003
		deps.aim:setFullScreenAim(is2D) -- 1004
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 1005
	end -- 996
	local ____temp_6 -- 1008
	if level.mission ~= nil then -- 1008
		____temp_6 = level.mission.introTour -- 1008
	else -- 1008
		____temp_6 = nil -- 1008
	end -- 1008
	local tourDef = ____temp_6 -- 1008
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 1009
	local function finishIntroTour() -- 1011
		if not introTourActive then -- 1011
			return -- 1012
		end -- 1012
		introTourActive = false -- 1013
		introTourT = tourDuration -- 1014
		core.viewMode = "2D" -- 1015
		applyView() -- 1016
		deps.aim:setIntroTourBannerVisible(false) -- 1017
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1018
	end -- 1011
	local function makeBasis(frame) -- 1021
		return prepareCamera({ -- 1022
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1024
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1025
			up = {x = 0, y = 1, z = 0}, -- 1026
			fovYDeg = deps.fovYDeg, -- 1027
			aspect = deps.aspect, -- 1028
			viewW = deps.viewW, -- 1029
			viewH = deps.viewH -- 1030
		}, HANDEDNESS, FLIP_Y) -- 1030
	end -- 1021
	local PredMinIntervalSec = 0.08 -- 1042
	local predAimKey = "" -- 1043
	local predPosKey = "" -- 1044
	local predAccum = 1 -- 1045
	local predForce = true -- 1046
	local predPoints = {} -- 1047
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 1049
	introTourActive = false -- 1051
	introTourT = tourDuration -- 1052
	local introLogged = false -- 1053
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1055
	local clock = 0 -- 1061
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1063
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1065
	local obsYawDeg = 0 -- 1069
	local obsPitchDeg = 0 -- 1070
	local obsZoom = 1 -- 1071
	local focusMode = "Auto" -- 1072
	local markerElapsed = -1 -- 1073
	local reportedBonusIds = {} -- 1074
	local bonusEffectElapsed = {} -- 1075
	local cineKey = "" -- 1076
	local cineFrame = nil -- 1077
	local cineFrom = nil -- 1078
	local cineTransition = 0 -- 1079
	local playerPose = nil -- 1080
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1082
	local idleOrbit = nil -- 1084
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1095
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1097
	local lastSlowmoBody = -1 -- 1098
	local flybySounded = {} -- 1099
	local cruiseAzimuth = 0 -- 1100
	local cruiseAzimuthReady = false -- 1101
	local flightLogT = 0 -- 1102
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1104
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1105
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
	local function prepareIdle() -- 1120
		clock = 0 -- 1122
		core.t0 = 0 -- 1123
		idleOrbit = nil -- 1124
		if level.probeVel0 == nil then -- 1124
			return -- 1125
		end -- 1125
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1127
		if hostIndex < 0 then -- 1127
			return -- 1128
		end -- 1128
		local host = level.bodies[hostIndex + 1] -- 1129
		local hp = bodyPositionAt(host, 0) -- 1130
		local hv = bodyVelocityAt(host, 0) -- 1131
		local rx = level.probeStart.x - hp.x -- 1133
		local ry = level.probeStart.y - hp.y -- 1134
		local vx = level.probeVel0.x - hv.x -- 1135
		local vy = level.probeVel0.y - hv.y -- 1136
		local r = math.sqrt(rx * rx + ry * ry) -- 1137
		if r < 1e-12 then -- 1137
			return -- 1138
		end -- 1138
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1140
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1141
		idleOrbit = { -- 1142
			hostIndex = hostIndex, -- 1142
			r = r, -- 1142
			phase0 = math.atan(ry, rx), -- 1142
			omega = dir * omega -- 1142
		} -- 1142
	end -- 1120
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1146
		if idleOrbit == nil then -- 1146
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1148
		end -- 1148
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1153
		local hp = bodyPositionAt(host, tWorld) -- 1154
		local hv = bodyVelocityAt(host, tWorld) -- 1155
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1156
		local ca = math.cos(a) -- 1157
		local sa = math.sin(a) -- 1158
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1159
	end -- 1146
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1176
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1177
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1180
		local wps = goalWaypoints(level.goal) -- 1181
		if #wps == 0 then -- 1181
			return nil -- 1182
		end -- 1182
		local passed = 0 -- 1183
		if core.flight ~= nil then -- 1183
			local upto = math.floor(core.flightTime / core.dt) -- 1185
			passed = waypointProgress( -- 1186
				core.flight.points, -- 1186
				level.bodies, -- 1186
				level.goal, -- 1186
				core.dt, -- 1186
				core.t0, -- 1186
				upto, -- 1186
				core.flight.velocities -- 1186
			).passed -- 1186
		end -- 1186
		if passed >= #wps then -- 1186
			return nil -- 1188
		end -- 1188
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1189
	end -- 1180
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1200
		if level.transfer ~= nil then -- 1200
			return { -- 1202
				pts = { -- 1202
					probe, -- 1202
					bodyPositionAt(level.bodies[1], t), -- 1202
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1202
					goalPositionAt(level.goal.marker ~= nil and level.goal.marker or level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1202
				}, -- 1202
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1203
			} -- 1203
		end -- 1203
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1203
			local hr = anchorDef.radius -- 1208
			do -- 1208
				local i = 0 -- 1209
				while i < #level.bodies do -- 1209
					local b = level.bodies[i + 1] -- 1210
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1210
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1210
							hr = deps.visuals[i + 1].displayRadius -- 1212
						end -- 1212
						break -- 1213
					end -- 1213
					i = i + 1 -- 1209
				end -- 1209
			end -- 1209
			return { -- 1216
				pts = { -- 1216
					probe, -- 1216
					bodyPositionAt(anchorDef, t) -- 1216
				}, -- 1216
				radii = {deps.scene.probeRadius, hr} -- 1216
			} -- 1216
		end -- 1216
		local corePts = {probe} -- 1220
		local coreRadii = {deps.scene.probeRadius} -- 1221
		local next = nextStationBody() -- 1222
		local nextTol = 0 -- 1223
		if next ~= nil then -- 1223
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1225
			local wps = goalWaypoints(level.goal) -- 1226
			local passed = 0 -- 1227
			if core.flight ~= nil then -- 1227
				passed = waypointProgress( -- 1229
					core.flight.points, -- 1229
					level.bodies, -- 1229
					level.goal, -- 1229
					core.dt, -- 1229
					core.t0, -- 1229
					math.floor(core.flightTime / core.dt), -- 1229
					core.flight.velocities -- 1229
				).passed -- 1229
			end -- 1229
			if passed < #wps then -- 1229
				nextTol = wps[passed + 1].tolerance -- 1231
			end -- 1231
			local r = nextTol > next.radius and nextTol or next.radius -- 1232
			coreRadii[#coreRadii + 1] = r -- 1233
		end -- 1233
		if anchorDef == nil then -- 1233
			return {pts = corePts, radii = coreRadii} -- 1236
		end -- 1236
		local anchorR = anchorDef.radius -- 1241
		do -- 1241
			local i = 0 -- 1242
			while i < #level.bodies do -- 1242
				local b = level.bodies[i + 1] -- 1243
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1243
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1243
						anchorR = deps.visuals[i + 1].displayRadius -- 1245
					end -- 1245
					break -- 1246
				end -- 1246
				i = i + 1 -- 1242
			end -- 1242
		end -- 1242
		local withAnchorPts = { -- 1249
			probe, -- 1249
			bodyPositionAt(anchorDef, t) -- 1249
		} -- 1249
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1250
		do -- 1250
			local i = 1 -- 1251
			while i < #corePts do -- 1251
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1252
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1253
				i = i + 1 -- 1251
			end -- 1251
		end -- 1251
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1255
		if want <= CameraFramingBudget then -- 1255
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1256
		end -- 1256
		return {pts = corePts, radii = coreRadii} -- 1257
	end -- 1200
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1261
		local marker = successMarkerFrame(markerElapsed) -- 1262
		if level.goal.region ~= nil then -- 1262
			local out = {} -- 1264
			local region = level.goal.region -- 1265
			local body = level.bodies[region.bodyIndex + 1] -- 1266
			if body ~= nil and (markerElapsed < 0 or marker.visible) then -- 1266
				local center = bodyPositionAt(body, t) -- 1268
				local alpha = markerElapsed >= 0 and marker.alpha or 0.55 -- 1269
				out[#out + 1] = { -- 1270
					center = center, -- 1270
					radius = body.radius + region.minAltitude, -- 1270
					bandOuterRadius = body.radius + region.maxAltitude, -- 1270
					passed = false, -- 1270
					pointAlpha = alpha -- 1270
				} -- 1270
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1271
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1272
			end -- 1272
			if level.bonusPoints ~= nil then -- 1272
				do -- 1272
					local i = 0 -- 1274
					while i < #level.bonusPoints do -- 1274
						do -- 1274
							local collected = core.collectedBonus[i + 1] -- 1275
							if collected and (bonusEffectElapsed[i + 1] == nil or bonusEffectElapsed[i + 1] >= 0.6) then -- 1275
								goto __continue161 -- 1276
							end -- 1276
							local p = level.bonusPoints[i + 1] -- 1277
							local targetBody = p.bodyIndex ~= nil and level.bodies[p.bodyIndex + 1] or p.orbit -- 1278
							if targetBody ~= nil then -- 1278
								local effect = collected and bonusEffectElapsed[i + 1] or -1 -- 1280
								out[#out + 1] = { -- 1281
									center = goalPositionAt(targetBody, t, p.offset), -- 1281
									radius = p.tolerance, -- 1281
									passed = false, -- 1281
									point = true, -- 1281
									showRange = not collected, -- 1281
									pulse = collected and 1 + effect * 2 or 1 + 0.1 * math.sin(t * 4), -- 1281
									pointAlpha = collected and 1 - effect / 0.6 or 1, -- 1281
									burstRadius = collected and p.tolerance * effect / 0.6 or nil -- 1281
								} -- 1281
							end -- 1281
						end -- 1281
						::__continue161:: -- 1281
						i = i + 1 -- 1274
					end -- 1274
				end -- 1274
			end -- 1274
			return out -- 1284
		end -- 1284
		if level.transfer ~= nil and not marker.visible then -- 1284
			return {} -- 1286
		end -- 1286
		local wps = goalWaypoints(level.goal) -- 1287
		if #wps == 0 then -- 1287
			return {} -- 1288
		end -- 1288
		local passed = 0 -- 1289
		if upto ~= nil and core.flight ~= nil then -- 1289
			passed = waypointProgress( -- 1291
				core.flight.points, -- 1291
				level.bodies, -- 1291
				level.goal, -- 1291
				core.dt, -- 1291
				core.t0, -- 1291
				upto, -- 1291
				core.flight.velocities -- 1291
			).passed -- 1291
		end -- 1291
		if transferCinematic(level.transfer) then -- 1291
			passed = 0 -- 1293
		end -- 1293
		if passed >= #wps then -- 1293
			return {} -- 1297
		end -- 1297
		local nextWp = wps[passed + 1] -- 1298
		local body = level.goal.marker ~= nil and level.goal.marker or level.bodies[nextWp.planetIndex + 1] -- 1299
		if body == nil then -- 1299
			return {} -- 1300
		end -- 1300
		local planning = aimed and (core.phase == "Aiming" or core.phase == "Armed") -- 1301
		local ____temp_7 -- 1302
		if level.transfer ~= nil then -- 1302
			____temp_7 = level.transfer.orbital -- 1302
		else -- 1302
			____temp_7 = nil -- 1302
		end -- 1302
		local orbital = ____temp_7 -- 1302
		local rings = {{ -- 1303
			center = goalPositionAt(body, t, nextWp.offset), -- 1303
			radius = nextWp.tolerance, -- 1303
			passed = false, -- 1303
			point = level.transfer ~= nil, -- 1304
			showRange = level.transfer == nil or (orbital == nil or orbital.targetFlyby ~= nil) and planning, -- 1304
			pulse = (1 + 0.1 * math.sin(t * 4)) * marker.scale, -- 1305
			pointAlpha = marker.alpha, -- 1305
			burstRadius = marker.ring -- 1305
		}} -- 1305
		if orbital ~= nil and orbital.region ~= nil and planning then -- 1305
			local center = bodyPositionAt(level.bodies[1], t) -- 1307
			__TS__ArrayPush(rings, {center = center, radius = orbital.region.minRadius, passed = false}, {center = center, radius = orbital.region.maxRadius, passed = false}) -- 1308
		end -- 1308
		return rings -- 1310
	end -- 1261
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1314
		if level.transfer ~= nil and not transferCinematic(level.transfer) then -- 1314
			local basis = makeBasis(f) -- 1316
			local dx = f.eye.x - f.target.x -- 1317
			local dy = f.eye.y - f.target.y -- 1317
			local dz = f.eye.z - f.target.z -- 1317
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1318
			f = { -- 1319
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1319
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1320
			} -- 1320
		end -- 1320
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1320
			return f -- 1322
		end -- 1322
		local dx = f.eye.x - f.target.x -- 1323
		local dy = f.eye.y - f.target.y -- 1324
		local dz = f.eye.z - f.target.z -- 1325
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1326
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1327
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1328
		local lo = CameraTiltMin * math.pi / 180 -- 1329
		local hi = CameraTiltMax * math.pi / 180 -- 1330
		if pitch < lo then -- 1330
			pitch = lo -- 1331
		end -- 1331
		if pitch > hi then -- 1331
			pitch = hi -- 1332
		end -- 1332
		local cp = math.cos(pitch) -- 1333
		return { -- 1334
			target = f.target, -- 1335
			eye = Vec3( -- 1336
				f.target.x + r * cp * math.sin(yaw), -- 1337
				f.target.y + r * math.sin(pitch), -- 1338
				f.target.z + r * cp * math.cos(yaw) -- 1339
			) -- 1339
		} -- 1339
	end -- 1314
	--- 相机放在探测器后方，平滑追随当前速度向量，避免巡航继续沿用点火方向。
	local function cruiseAzFor(velocity, wallDt) -- 1345
		local target = math.atan(-velocity.x, -velocity.y) * 180 / math.pi -- 1346
		if not cruiseAzimuthReady then -- 1346
			cruiseAzimuth = target -- 1348
			cruiseAzimuthReady = true -- 1349
			return cruiseAzimuth -- 1350
		end -- 1350
		local delta = target - cruiseAzimuth -- 1352
		while delta > 180 do -- 1352
			delta = delta - 360 -- 1353
		end -- 1353
		while delta < -180 do -- 1353
			delta = delta + 360 -- 1354
		end -- 1354
		cruiseAzimuth = cruiseAzimuth + delta * (1 - math.exp(-math.max(0, wallDt) * 5)) -- 1355
		return cruiseAzimuth -- 1356
	end -- 1345
	local function playerAnchor(pos, t) -- 1359
		if focusMode == "Probe" then -- 1359
			return planeToWorld(pos, 0) -- 1360
		end -- 1360
		if focusMode == "Overview" then -- 1360
			local points = { -- 1362
				pos, -- 1362
				table.unpack(__TS__ArrayMap( -- 1362
					level.bodies, -- 1362
					function(____, b) return bodyPositionAt(b, t) end -- 1362
				)) -- 1362
			} -- 1362
			local x = 0 -- 1363
			local y = 0 -- 1363
			for ____, p in ipairs(points) do -- 1364
				x = x + p.x -- 1364
				y = y + p.y -- 1364
			end -- 1364
			return planeToWorld({x = x / #points, y = y / #points}, 0) -- 1365
		end -- 1365
		local index = 0 -- 1367
		if focusMode == "Moon" then -- 1367
			index = level.goal.planetIndex -- 1368
		end -- 1368
		local ____temp_8 -- 1369
		if level.transfer ~= nil then -- 1369
			____temp_8 = level.transfer.orbital -- 1369
		else -- 1369
			____temp_8 = nil -- 1369
		end -- 1369
		local cfg = ____temp_8 -- 1369
		if cfg ~= nil then -- 1369
			for ____, e in ipairs(cfg.encounters) do -- 1371
				if e.focus == focusMode then -- 1371
					index = e.planetIndex -- 1371
				end -- 1371
			end -- 1371
			if cfg.targetFlyby ~= nil and cfg.targetFlyby.focus == focusMode then -- 1371
				index = cfg.targetFlyby.planetIndex -- 1372
			end -- 1372
		end -- 1372
		return planeToWorld( -- 1374
			bodyPositionAt(level.bodies[index + 1], t), -- 1374
			0 -- 1374
		) -- 1374
	end -- 1359
	local function playerCamera(pos, t, wallDt) -- 1376
		if focusMode == "Auto" or playerPose == nil then -- 1376
			return nil -- 1377
		end -- 1377
		local f = stepObserve( -- 1378
			playerPose, -- 1378
			playerAnchor(pos, t), -- 1378
			wallDt -- 1378
		) -- 1378
		cineFrame = { -- 1379
			eye = Vec3(f.eye.x, f.eye.y, f.eye.z), -- 1379
			target = Vec3(f.target.x, f.target.y, f.target.z) -- 1379
		} -- 1379
		return cineFrame -- 1380
	end -- 1376
	local function playerMinDistance() -- 1382
		if focusMode == "Probe" then -- 1382
			return level.levelId == 2 and 65 or 100 -- 1383
		end -- 1383
		if focusMode == "Overview" then -- 1383
			return deps.rig.distanceBounds().min -- 1384
		end -- 1384
		local index = focusMode == "Moon" and level.goal.planetIndex or 0 -- 1385
		local ____temp_9 -- 1386
		if level.transfer ~= nil then -- 1386
			____temp_9 = level.transfer.orbital -- 1386
		else -- 1386
			____temp_9 = nil -- 1386
		end -- 1386
		local cfg = ____temp_9 -- 1386
		if cfg ~= nil then -- 1386
			for ____, e in ipairs(cfg.encounters) do -- 1388
				if e.focus == focusMode then -- 1388
					index = e.planetIndex -- 1388
				end -- 1388
			end -- 1388
			if cfg.targetFlyby ~= nil and cfg.targetFlyby.focus == focusMode then -- 1388
				index = cfg.targetFlyby.planetIndex -- 1389
			end -- 1389
		end -- 1389
		return math.max(40, level.bodies[index + 1].radius * 6) -- 1391
	end -- 1382
	local function capturePlayerCamera(refocus) -- 1393
		if refocus == nil then -- 1393
			refocus = false -- 1393
		end -- 1393
		if cineFrame == nil or core.flight == nil then -- 1393
			return -- 1394
		end -- 1394
		local pos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 1395
		local t = core.t0 + core.flightTime -- 1396
		local desired = playerMinDistance() -- 1397
		if focusMode == "Overview" then -- 1397
			desired = deps.rig.wantDistance( -- 1398
				{ -- 1398
					pos, -- 1398
					table.unpack(__TS__ArrayMap( -- 1398
						level.bodies, -- 1398
						function(____, b) return bodyPositionAt(b, t) end -- 1398
					)) -- 1398
				}, -- 1398
				deps.scene.probeRadius, -- 1398
				{ -- 1398
					deps.scene.probeRadius, -- 1398
					table.unpack(__TS__ArrayMap( -- 1398
						level.bodies, -- 1398
						function(____, b) return b.radius end -- 1398
					)) -- 1398
				} -- 1398
			) -- 1398
		end -- 1398
		playerPose = captureObserve( -- 1399
			cineFrame, -- 1399
			playerAnchor(pos, t), -- 1399
			refocus and desired or nil -- 1399
		) -- 1399
	end -- 1393
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1402
		local manual = playerCamera(pos, t, wallDt) -- 1403
		if manual ~= nil then -- 1403
			return manual -- 1404
		end -- 1404
		local cfg = level.transfer.flyby -- 1405
		local autoShot = transferShotAt( -- 1406
			core.flightTime, -- 1406
			core.burnDuration, -- 1406
			core.flyby, -- 1406
			cfg, -- 1406
			core.dt -- 1406
		) -- 1406
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1407
		local key = (focusMode .. ":") .. shot -- 1408
		local earth = bodyPositionAt(level.bodies[1], t) -- 1409
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1410
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1411
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1412
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1413
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1414
		local moonAz = launchAz -- 1415
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1415
			local at = core.flyby.entryIndex -- 1417
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1418
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1420
		end -- 1420
		local pts = {pos} -- 1422
		local radii = {deps.scene.probeRadius} -- 1422
		local az = launchAz -- 1423
		local tilt = 28 -- 1423
		local minDist = 130 -- 1423
		if shot == "Cruise" then -- 1423
			az = cruiseAzFor(velocity, wallDt) -- 1425
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 24 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 24 / vmag or 0)} -- 1426
			radii[#radii + 1] = 0 -- 1427
			minDist = 100 -- 1427
			tilt = 35 -- 1427
		elseif shot == "Moon" then -- 1427
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1429
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1430
			az = moonAz -- 1431
			tilt = 45 -- 1431
			minDist = 160 -- 1431
		elseif shot == "Earth" then -- 1431
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1433
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1434
			az = moonAz + 35 -- 1435
			tilt = 42 -- 1435
			minDist = 180 -- 1435
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1435
				local at = math.min( -- 1437
					#core.flight.points - 1, -- 1437
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1437
				) -- 1437
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1438
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1440
			end -- 1440
		elseif shot == "Overview" then -- 1440
			pts = {pos, earth, moon} -- 1443
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1443
			az = moonAz -- 1444
			tilt = 60 -- 1444
			minDist = 200 -- 1444
		end -- 1444
		if key ~= cineKey then -- 1444
			cineFrom = cineFrame -- 1447
			cineTransition = 0 -- 1448
			if cineKey == "" or shot == "Launch" then -- 1448
				cineFrom = nil -- 1450
			end -- 1450
			cineKey = key -- 1451
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1452
		end -- 1452
		local want = deps.rig.step( -- 1454
			pts, -- 1454
			deps.scene.probeRadius, -- 1454
			radii, -- 1454
			minDist, -- 1454
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1454
		) -- 1454
		local frame = want -- 1455
		if cineFrom ~= nil then -- 1455
			cineTransition = cineTransition + wallDt -- 1457
			local u = math.min(1, cineTransition / 0.6) -- 1458
			local k = u * u * (3 - 2 * u) -- 1459
			frame = { -- 1460
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1460
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1461
			} -- 1461
			if u >= 1 then -- 1461
				cineFrom = nil -- 1462
			end -- 1462
		end -- 1462
		cineFrame = frame -- 1464
		return applyObserve(frame) -- 1465
	end -- 1402
	--- 日心关卡按配置逐站取景，手动选择保持到回到自动。
	local function orbitalCamera(pos, t, wallDt) -- 1469
		local manual = playerCamera(pos, t, wallDt) -- 1470
		if manual ~= nil then -- 1470
			return manual -- 1471
		end -- 1471
		local cfg = level.transfer.orbital -- 1472
		local autoShot = orbitalShotAt( -- 1473
			core.flightTime, -- 1473
			core.burnDuration, -- 1473
			core.flyby, -- 1473
			cfg, -- 1473
			core.dt -- 1473
		) -- 1473
		if level.levelId == 3 and core.missionCompleted then -- 1473
			autoShot = core.flightTime - core.goalIndex * core.dt < 2 and "Cruise" or "Overview" -- 1474
		end -- 1474
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1475
		local key = (focusMode .. ":") .. shot -- 1476
		local velocity = core.flight.velocities[____exports.coreProbeIndex(core) + 1] -- 1477
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1478
		local pts = {pos} -- 1479
		local radii = {deps.scene.probeRadius} -- 1479
		local az = math.atan(core.flight.velocities[1].x, core.flight.velocities[1].y) * 180 / math.pi + 100 -- 1480
		local targetFlybyMission = cfg.targetFlyby ~= nil -- 1481
		local encounterSpecs = {table.unpack(cfg.encounters)} -- 1482
		if cfg.targetFlyby ~= nil then -- 1482
			encounterSpecs[#encounterSpecs + 1] = cfg.targetFlyby -- 1483
		end -- 1483
		local tilt = 28 -- 1484
		local minDist = targetFlybyMission and 40 or 130 -- 1484
		if shot == "Cruise" then -- 1484
			az = cruiseAzFor(velocity, wallDt) -- 1486
			pts[#pts + 1] = {x = pos.x + (speed > 0 and velocity.x * 24 / speed or 0), y = pos.y + (speed > 0 and velocity.y * 24 / speed or 0)} -- 1487
			radii[#radii + 1] = 0 -- 1488
			tilt = 35 -- 1488
			minDist = targetFlybyMission and 65 or 100 -- 1488
		elseif shot == "Overview" then -- 1488
			pts[#pts + 1] = bodyPositionAt(level.bodies[1], t) -- 1490
			radii[#radii + 1] = level.bodies[1].radius -- 1490
			for ____, e in ipairs(encounterSpecs) do -- 1491
				pts[#pts + 1] = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1491
				radii[#radii + 1] = level.bodies[e.planetIndex + 1].radius -- 1491
			end -- 1491
			az = math.atan(pos.x, pos.y) * 180 / math.pi -- 1492
			tilt = 60 -- 1492
			minDist = 300 -- 1492
		elseif shot == "Sun" then -- 1492
			pts = {bodyPositionAt(level.bodies[1], t)} -- 1494
			radii = {level.bodies[1].radius} -- 1494
			tilt = 42 -- 1494
			minDist = 200 -- 1494
		elseif shot ~= "Launch" then -- 1494
			do -- 1494
				local i = 0 -- 1496
				while i < #encounterSpecs do -- 1496
					do -- 1496
						local e = encounterSpecs[i + 1] -- 1497
						if e.focus ~= shot then -- 1497
							goto __continue230 -- 1498
						end -- 1498
						local bp = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1499
						pts = focusMode == "Auto" and ({pos, bp}) or ({bp}) -- 1500
						radii = focusMode == "Auto" and ({deps.scene.probeRadius, level.bodies[e.planetIndex + 1].radius}) or ({level.bodies[e.planetIndex + 1].radius}) -- 1501
						local ____temp_10 -- 1502
						if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 1502
							____temp_10 = i < #cfg.encounters and core.flyby.encounters[i + 1] or core.flyby.destination -- 1502
						else -- 1502
							____temp_10 = nil -- 1502
						end -- 1502
						local stage = ____temp_10 -- 1502
						local at = stage ~= nil and stage.entryIndex >= 0 and stage.entryIndex or 0 -- 1503
						local near = bodyPositionAt(level.bodies[e.planetIndex + 1], core.t0 + at * core.dt) -- 1504
						local probe = core.flight.points[at + 1] -- 1504
						az = math.atan(probe.x - near.x, probe.y - near.y) * 180 / math.pi + 90 -- 1505
						tilt = 45 -- 1506
						minDist = targetFlybyMission and (focusMode == "Auto" and 80 or level.bodies[e.planetIndex + 1].radius * 6) or 180 -- 1506
						break -- 1506
					end -- 1506
					::__continue230:: -- 1506
					i = i + 1 -- 1496
				end -- 1496
			end -- 1496
		end -- 1496
		if key ~= cineKey then -- 1496
			cineFrom = cineFrame -- 1510
			cineTransition = 0 -- 1510
			if cineKey == "" or shot == "Launch" then -- 1510
				cineFrom = nil -- 1511
			end -- 1511
			cineKey = key -- 1512
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1513
		end -- 1513
		local want = deps.rig.step( -- 1515
			pts, -- 1515
			deps.scene.probeRadius, -- 1515
			radii, -- 1515
			minDist, -- 1515
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1515
		) -- 1515
		local frame = want -- 1516
		if cineFrom ~= nil then -- 1516
			cineTransition = cineTransition + wallDt -- 1518
			local u = math.min(1, cineTransition / 0.6) -- 1519
			local k = u * u * (3 - 2 * u) -- 1519
			frame = { -- 1520
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1520
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1521
			} -- 1521
			if u >= 1 then -- 1521
				cineFrom = nil -- 1522
			end -- 1522
		end -- 1522
		cineFrame = frame -- 1524
		return applyObserve(frame) -- 1525
	end -- 1469
	local function resetCinematic() -- 1528
		markerElapsed = -1 -- 1529
		focusMode = "Auto" -- 1530
		cineKey = "" -- 1530
		cineFrame = nil -- 1530
		cineFrom = nil -- 1530
		playerPose = nil -- 1531
		obsYawDeg = 0 -- 1532
		obsPitchDeg = 0 -- 1532
		obsZoom = 1 -- 1532
		cruiseAzimuthReady = false -- 1533
		flybySounded = {} -- 1534
	end -- 1528
	local function updateAiming(dt) -- 1537
		if deps.plan.setBurn ~= nil then -- 1537
			deps.plan:setBurn(core.aim.velocity, false) -- 1538
		end -- 1538
		deps.aim:setEnabled(true) -- 1539
		local dragging = deps.aim:isDragging() -- 1541
		local clockFrozen = dragging or core.phase == "Armed" or transferCinematic(level.transfer) and introTourActive -- 1546
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1546
			local rate = core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1557
			clock = clock + dt * rate -- 1558
			orbitClock = orbitClock + dt * rate -- 1559
		end -- 1559
		local tNow = core.t0 + clock -- 1561
		local idleState = idleProbeAt(tNow) -- 1563
		probePos = idleState.pos -- 1564
		probeVel = idleState.vel -- 1565
		deps.scene.syncBodies(tNow) -- 1567
		if deps.scene.syncStars ~= nil then -- 1567
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1568
		end -- 1568
		deps.scene.syncProbe(probePos) -- 1569
		if idleOrbit ~= nil then -- 1569
			deps.scene.faceVelocity(probeVel) -- 1570
		end -- 1570
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1572
		deps.plan:syncProbe(probePos, probeVel) -- 1573
		if not aimed and #core.stars > 0 then -- 1573
			deps.plan:setStars( -- 1575
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1575
				core.collectedStars -- 1575
			) -- 1575
		end -- 1575
		local fr = framingPoints(probePos, tNow) -- 1579
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1580
		if frameLogged < 6 then -- 1580
			frameLogged = frameLogged + 1 -- 1584
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1585
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1589
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1590
				__TS__ArrayMap( -- 1596
					fr.pts, -- 1596
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1596
				), -- 1596
				" " -- 1596
			)) .. "]") -- 1596
		end -- 1596
		if introTourActive and introTourT < tourDuration then -- 1596
			introTourT = introTourT + dt -- 1600
			local k = introTourT / tourDuration -- 1601
			if k >= 1 then -- 1601
				finishIntroTour() -- 1603
			else -- 1603
				if k >= 0.95 and not introLogged then -- 1603
					introLogged = true -- 1606
					print("[escape-velocity] intro camera finishing") -- 1607
				end -- 1607
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1607
					local elapsed = introTourT -- 1611
					local segIndex = 0 -- 1612
					local segStart = 0 -- 1613
					do -- 1613
						local s = 0 -- 1614
						while s < #tourDef.segments do -- 1614
							local seg = tourDef.segments[s + 1] -- 1615
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1615
								segIndex = s -- 1617
								break -- 1618
							end -- 1618
							elapsed = elapsed - seg.duration -- 1620
							segStart = segStart + seg.duration -- 1621
							s = s + 1 -- 1614
						end -- 1614
					end -- 1614
					local curSeg = tourDef.segments[segIndex + 1] -- 1623
					local segK = math.max( -- 1624
						0, -- 1624
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1624
					) -- 1624
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1626
					deps.aim:setIntroTourBannerVisible(true) -- 1627
					local pwProbe = planeToWorld(probePos, 0) -- 1629
					local function getTargetPosAndDist(targetIdx, userDist) -- 1630
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1630
							local b = level.bodies[targetIdx + 1] -- 1632
							local isMicro = b.orbitRadius < 2 -- 1633
							local p = planeToWorld( -- 1634
								bodyPositionAt(b, tNow), -- 1634
								0 -- 1634
							) -- 1634
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1635
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1636
						end -- 1636
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1638
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1639
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1640
					end -- 1630
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1643
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1644
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1645
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1647
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1648
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1649
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1650
					if segIndex == 0 then -- 1650
						local az = curAz + segK * (18 * math.pi / 180) -- 1654
						local tilt = curTilt -- 1655
						local d = curKey.dist -- 1656
						local eye = Vec3( -- 1657
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1658
							curKey.pos.y + math.sin(tilt) * d, -- 1659
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1660
						) -- 1660
						frame = {target = curKey.pos, eye = eye} -- 1662
					else -- 1662
						local ease = segK * segK * (3 - 2 * segK) -- 1665
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1666
						local az = prevAz + (curAz - prevAz) * ease -- 1671
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1672
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1673
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1674
						local eye = Vec3( -- 1675
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1676
							target.y + math.sin(tilt) * d, -- 1677
							target.z + math.cos(az) * math.cos(tilt) * d -- 1678
						) -- 1678
						frame = {target = target, eye = eye} -- 1680
					end -- 1680
				else -- 1680
					local targetBody = nil -- 1683
					local wps = goalWaypoints(level.goal) -- 1684
					if #wps > 0 then -- 1684
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1686
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1686
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1688
					end -- 1688
					if targetBody == nil and #level.bodies > 0 then -- 1688
						targetBody = level.bodies[#level.bodies] -- 1691
					end -- 1691
					if targetBody ~= nil then -- 1691
						local pwTarget = planeToWorld( -- 1695
							bodyPositionAt(targetBody, tNow), -- 1695
							0 -- 1695
						) -- 1695
						local pwProbe = planeToWorld(probePos, 0) -- 1696
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1697
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1698
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1699
						if k < 0.35 then -- 1699
							local e1 = k / 0.35 -- 1702
							local az = (0.2 + e1 * 0.15) * math.pi -- 1703
							local tilt = 0.35 * math.pi -- 1704
							local eye = Vec3( -- 1705
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1706
								pwTarget.y + math.sin(tilt) * distTarget, -- 1707
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1708
							) -- 1708
							frame = {target = pwTarget, eye = eye} -- 1710
						elseif k < 0.72 then -- 1710
							local e2 = (k - 0.35) / 0.37 -- 1712
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1713
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1714
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1715
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1716
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1717
							local eye = Vec3( -- 1722
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1723
								targetCenter.y + curDist * 0.8, -- 1724
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1725
							) -- 1725
							frame = {target = targetCenter, eye = eye} -- 1727
						else -- 1727
							local e3 = (k - 0.72) / 0.28 -- 1729
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1730
							local az = 0.25 * math.pi -- 1731
							local tilt = 0.36 * math.pi -- 1732
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1733
							local eye = Vec3( -- 1734
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1735
								pwProbe.y + math.sin(tilt) * curDist, -- 1736
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1737
							) -- 1737
							frame = {target = pwProbe, eye = eye} -- 1739
						end -- 1739
					end -- 1739
				end -- 1739
			end -- 1739
		end -- 1739
		frame = applyObserve(frame) -- 1746
		deps.rig.apply(deps.camera, frame) -- 1747
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1748
		local basis = makeBasis(frame) -- 1749
		if core.viewMode == "2D" then -- 1749
			local sp = deps.plan:probeScreen() -- 1755
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1756
		else -- 1756
			local pp = projectPrepared( -- 1758
				planeToWorld(probePos, 0), -- 1758
				basis -- 1758
			) -- 1758
			if pp ~= nil then -- 1758
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1759
			end -- 1759
		end -- 1759
		if not aimed then -- 1759
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1759
				deps.aim:setTransferInfo( -- 1769
					distance( -- 1769
						probePos, -- 1769
						bodyPositionAt(level.bodies[1], tNow) -- 1769
					) - level.bodies[1].radius, -- 1769
					0 -- 1769
				) -- 1769
			end -- 1769
			deps.trajectory:clearPrediction() -- 1773
			deps.plan:clearPrediction() -- 1774
			predForce = true -- 1775
		else -- 1775
			local aimKey = (__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4) -- 1781
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1782
			predAccum = predAccum + dt -- 1783
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1784
			if needIt then -- 1784
				predForce = false -- 1786
				predAccum = 0 -- 1787
				predAimKey = aimKey -- 1788
				predPosKey = posKey -- 1789
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel) -- 1792
				local predictSample = level.transfer ~= nil and 1 or 4 -- 1793
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion}, level.bodies, { -- 1794
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1797
					dt = core.dt, -- 1797
					sampleEvery = predictSample, -- 1797
					escapeRadius = level.escapeRadius, -- 1797
					t0 = tNow -- 1797
				}) -- 1797
				predPoints = sim.points -- 1799
				if level.transfer ~= nil then -- 1799
					local analysis = analyzeTransfer( -- 1801
						sim, -- 1801
						level.bodies, -- 1801
						level.goal.planetIndex, -- 1801
						level.transfer, -- 1801
						core.dt * predictSample, -- 1801
						tNow -- 1801
					) -- 1801
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1802
						sim.points, -- 1802
						level.bodies, -- 1802
						level.goal, -- 1802
						core.dt * predictSample, -- 1802
						tNow, -- 1802
						sim.velocities -- 1802
					) -- 1802
					if analysis ~= nil then -- 1802
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1803
					elseif gi >= 0 then -- 1803
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1804
					end -- 1804
					local radius = distance( -- 1805
						probePos, -- 1805
						bodyPositionAt(level.bodies[1], tNow) -- 1805
					) -- 1805
					local plan = planTransfer( -- 1806
						level.bodies[1].gm, -- 1806
						radius, -- 1806
						probeVel, -- 1806
						core.aim.power, -- 1806
						level.transfer.apoapsisMax, -- 1806
						level.transfer.mode, -- 1806
						level.transfer.periapsisMin -- 1806
					) -- 1806
					if deps.aim.setTransferInfo ~= nil then -- 1806
						deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1807
					end -- 1807
				end -- 1807
				predTimes = {} -- 1809
				do -- 1809
					local pi = 0 -- 1810
					while pi < #predPoints do -- 1810
						predTimes[#predTimes + 1] = tNow + pi * core.dt * predictSample -- 1810
						pi = pi + 1 -- 1810
					end -- 1810
				end -- 1810
			end -- 1810
			deps.trajectory:setPrediction(predPoints, basis) -- 1812
			deps.plan:setPrediction(predPoints) -- 1814
			if #core.stars > 0 then -- 1814
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1817
				local stEval = evaluateCollectedStars( -- 1818
					predPoints, -- 1818
					core.stars, -- 1818
					30, -- 1818
					core.starOrbits, -- 1818
					predTimes -- 1818
				) -- 1818
				core.previewStarsCount = stEval.count -- 1819
				deps.plan:setStars(live, stEval.collected) -- 1820
			end -- 1820
		end -- 1820
		if idleOrbit ~= nil then -- 1820
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1825
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1826
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1827
		end -- 1827
		local rings = goalRingsAt(tNow) -- 1829
		deps.trajectory:setGoalRings(rings, basis) -- 1830
		deps.trajectory:clearTrail() -- 1831
		deps.plan:setGoalRings(rings) -- 1833
		deps.plan:clearTrail() -- 1834
		deps.plan:flush() -- 1835
	end -- 1537
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
	local function updateFinale() -- 1850
		deps.aim:setEnabled(false) -- 1851
		if core.flight == nil then -- 1851
			return -- 1852
		end -- 1852
		local idx = ____exports.coreProbeIndex(core) -- 1853
		local pos = core.flight.points[idx + 1] -- 1854
		local tWorld = core.t0 + core.flightTime -- 1855
		deps.scene.syncBodies(tWorld) -- 1858
		deps.scene.syncProbe(pos) -- 1859
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1860
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1863
		deps.camera:lookAt( -- 1864
			frame.eye, -- 1864
			frame.target, -- 1864
			Vec3(0, 1, 0) -- 1864
		) -- 1864
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1865
		local trail = {} -- 1868
		do -- 1868
			local i = 0 -- 1869
			while i <= idx do -- 1869
				trail[#trail + 1] = core.flight.points[i + 1] -- 1869
				i = i + 1 -- 1869
			end -- 1869
		end -- 1869
		local rings = goalRingsAt(tWorld, idx) -- 1870
		local basis = makeBasis(frame) -- 1871
		if deps.trajectory.setBurn ~= nil then -- 1871
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1873
		end -- 1873
		deps.trajectory:clearOrbitRing() -- 1874
		deps.plan:clearProbeOrbit() -- 1875
		deps.trajectory:setTrail(trail, basis) -- 1876
		deps.trajectory:setGoalRings(rings, basis) -- 1877
		deps.plan:clearPrediction() -- 1878
		deps.plan:setGoalRings(rings) -- 1879
		deps.plan:flush() -- 1880
	end -- 1850
	local function updateFlying(dt) -- 1882
		deps.aim:setObserveEnabled(core.viewMode == "3D") -- 1883
		local wasCompleted = core.missionCompleted -- 1886
		local oldBonusScore = core.bonusRockets -- 1887
		local entered = ____exports.coreUpdate(core, dt, level) -- 1888
		if not wasCompleted and core.missionCompleted then -- 1888
			markerElapsed = 0 -- 1890
			print("[escape-velocity] success marker triggered once") -- 1891
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1892
			if deps.onMissionCompleted ~= nil then -- 1892
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1893
			end -- 1893
		end -- 1893
		if core.bonusRockets > oldBonusScore and deps.onBonusCollected ~= nil and level.bonusPoints ~= nil then -- 1893
			do -- 1893
				local i = 0 -- 1896
				while i < #core.collectedBonus do -- 1896
					if core.collectedBonus[i + 1] and not reportedBonusIds[level.bonusPoints[i + 1].id] then -- 1896
						reportedBonusIds[level.bonusPoints[i + 1].id] = true -- 1897
						bonusEffectElapsed[i + 1] = 0 -- 1898
						deps:onBonusCollected(core.bonusRockets, level.bonusPoints[i + 1].id) -- 1899
					end -- 1899
					i = i + 1 -- 1896
				end -- 1896
			end -- 1896
		end -- 1896
		if core.flight == nil then -- 1896
			return entered -- 1902
		end -- 1902
		local idx = ____exports.coreProbeIndex(core) -- 1904
		local pos = core.flight.points[idx + 1] -- 1905
		local tWorld = core.t0 + core.flightTime -- 1909
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1909
			lastSlowmo = core.slowmo -- 1913
			lastSlowmoBody = core.slowmoBody -- 1914
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1915
			local nearD = near ~= nil and distance( -- 1916
				pos, -- 1916
				bodyPositionAt(near, tWorld) -- 1916
			) or 0 -- 1916
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1917
			if core.slowmo and core.slowmoBody >= 0 and not flybySounded[__TS__NumberToFixed(core.slowmoBody, 0)] then -- 1917
				flybySounded[__TS__NumberToFixed(core.slowmoBody, 0)] = true -- 1922
				if deps.onFlyby ~= nil then -- 1922
					deps:onFlyby(core.slowmoBody) -- 1923
				end -- 1923
			end -- 1923
		end -- 1923
		flightLogT = flightLogT + dt -- 1928
		if flightLogT >= 0.5 then -- 1928
			flightLogT = 0 -- 1930
			local total = (#core.flight.points - 1) * core.dt -- 1931
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1932
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1934
					core.flightTime, -- 1934
					core.burnDuration, -- 1934
					level.transfer, -- 1934
					core.flyby, -- 1934
					core.dt -- 1934
				) or (core.slowmo and SlowMoFactor or 1)), -- 1934
				2 -- 1934
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1934
		end -- 1934
		deps.scene.syncBodies(tWorld) -- 1938
		if deps.scene.syncStars ~= nil then -- 1938
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1939
		end -- 1939
		deps.scene.syncProbe(pos) -- 1940
		if idx > 0 then -- 1940
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1942
		end -- 1942
		do -- 1942
			local s = 0 -- 1946
			while s < #core.stars do -- 1946
				if not core.collectedStars[s + 1] then -- 1946
					local fromLevel = level.starOrbits -- 1948
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1949
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1950
					local dx = pos.x - stPos.x -- 1951
					local dy = pos.y - stPos.y -- 1952
					if dx * dx + dy * dy <= 30 * 30 then -- 1952
						core.collectedStars[s + 1] = true -- 1954
						if deps.scene.setStarCollected ~= nil then -- 1954
							deps.scene.setStarCollected(s) -- 1956
						end -- 1956
						deps.plan:setStars(core.stars, core.collectedStars) -- 1958
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1959
					end -- 1959
				end -- 1959
				s = s + 1 -- 1946
			end -- 1946
		end -- 1946
		local fr -- 1968
		local closeDist = nil -- 1969
		if core.slowmo and core.slowmoBody >= 0 then -- 1969
			local near = level.bodies[core.slowmoBody + 1] -- 1971
			local nearR = near.radius -- 1973
			do -- 1973
				local i = 0 -- 1974
				while i < #level.bodies do -- 1974
					local b = level.bodies[i + 1] -- 1975
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1975
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1975
							nearR = deps.visuals[i + 1].displayRadius -- 1977
						end -- 1977
						break -- 1978
					end -- 1978
					i = i + 1 -- 1974
				end -- 1974
			end -- 1974
			fr = { -- 1981
				pts = { -- 1981
					pos, -- 1981
					bodyPositionAt(near, tWorld) -- 1981
				}, -- 1981
				radii = {deps.scene.probeRadius, nearR} -- 1981
			} -- 1981
			closeDist = SlowMoCloseDist -- 1982
		else -- 1982
			fr = framingPoints(pos, tWorld) -- 1984
		end -- 1984
		local baseFrame = level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalCamera(pos, tWorld, dt) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist)) -- 1986
		local frame = level.transfer ~= nil and not transferCinematic(level.transfer) and applyObserve(baseFrame) or baseFrame -- 1987
		deps.rig.apply(deps.camera, frame) -- 1988
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1989
		local basis = makeBasis(frame) -- 1990
		if deps.trajectory.setBurn ~= nil then -- 1990
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1993
		end -- 1993
		if deps.plan.setBurn ~= nil then -- 1993
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1994
		end -- 1994
		local trail = {} -- 1995
		do -- 1995
			local i = 0 -- 1996
			while i <= idx do -- 1996
				trail[#trail + 1] = core.flight.points[i + 1] -- 1996
				i = i + 1 -- 1996
			end -- 1996
		end -- 1996
		local rings = goalRingsAt(tWorld, idx) -- 1997
		deps.trajectory:clearOrbitRing() -- 1999
		deps.plan:clearProbeOrbit() -- 2000
		deps.trajectory:setTrail(trail, basis) -- 2001
		deps.trajectory:setGoalRings(rings, basis) -- 2002
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 2005
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 2006
		deps.plan:setStars( -- 2007
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 2007
			core.collectedStars -- 2007
		) -- 2007
		deps.plan:setTrail(trail) -- 2008
		deps.plan:clearPrediction() -- 2009
		deps.plan:setGoalRings(rings) -- 2010
		deps.plan:flush() -- 2011
		return entered -- 2013
	end -- 1882
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 2027
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 2028
		core.t0 = next.t0 -- 2029
		clock = next.clock -- 2030
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 2031
	end -- 2027
	local function finishFlight() -- 2034
		if core.result == nil then -- 2034
			return -- 2035
		end -- 2035
		local toFinale = deps.finale == true and core.result == "success" -- 2036
		if toFinale then -- 2036
			____exports.coreEnterFinale(core) -- 2037
		end -- 2037
		deps:onResult( -- 2038
			core.result, -- 2038
			____exports.calcFlightTelemetry(core, level) -- 2038
		) -- 2038
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 2038
			local ____end = #core.flight.points - 1 -- 2040
			deps:onFinale({ -- 2041
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 2041
				time = core.flightTime, -- 2041
				tWorld = core.t0 + core.flightTime -- 2041
			}) -- 2041
		end -- 2041
		deps:onPhase(toFinale and "Finale" or "Result") -- 2043
	end -- 2034
	local function update(dt) -- 2046
		if markerElapsed >= 0 and markerElapsed < 0.6 then -- 2046
			markerElapsed = math.min(0.6, markerElapsed + dt) -- 2047
		end -- 2047
		do -- 2047
			local i = 0 -- 2048
			while i < #bonusEffectElapsed do -- 2048
				if bonusEffectElapsed[i + 1] >= 0 and bonusEffectElapsed[i + 1] < 0.6 then -- 2048
					bonusEffectElapsed[i + 1] = math.min(0.6, bonusEffectElapsed[i + 1] + dt) -- 2048
				end -- 2048
				i = i + 1 -- 2048
			end -- 2048
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
	end -- 2046
	return { -- 2068
		phase = function() return core.phase end, -- 2069
		speedPow = function() return speedPow end, -- 2070
		speedMinPow = function() return speedMinPow end, -- 2071
		speedMaxPow = function() return speedMaxPow end, -- 2072
		isPaused = function() return paused end, -- 2073
		speedRate = function() -- 2074
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 2074
				return core.playback * transferPlaybackRate( -- 2075
					core.flightTime, -- 2075
					core.burnDuration, -- 2075
					level.transfer, -- 2075
					core.flyby, -- 2075
					core.dt -- 2075
				) -- 2075
			end -- 2075
			return core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 2076
		end, -- 2074
		missionSeconds = function() -- 2078
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 2079
			return speedUnit > 0 and w / speedUnit or 0 -- 2080
		end, -- 2078
		speedUp = function() -- 2082
			local next = ____exports.shiftSpeedPow(speedPow, speedMinPow, speedMaxPow, 1) -- 2083
			if next == speedPow then -- 2083
				return -- 2084
			end -- 2084
			speedPow = next -- 2085
			paused = false -- 2086
			applySpeedRate() -- 2087
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2088
		end, -- 2082
		speedDown = function() -- 2090
			local next = ____exports.shiftSpeedPow(speedPow, speedMinPow, speedMaxPow, -1) -- 2091
			if next == speedPow then -- 2091
				return -- 2092
			end -- 2092
			speedPow = next -- 2093
			paused = false -- 2094
			applySpeedRate() -- 2095
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2096
		end, -- 2090
		togglePause = function() -- 2098
			paused = not paused -- 2099
			applySpeedRate() -- 2100
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 2101
		end, -- 2098
		result = function() return core.result end, -- 2103
		onAimDrag = function(____, a) -- 2104
			if introTourActive then -- 2104
				finishIntroTour() -- 2105
			end -- 2105
			core.aim = a -- 2106
			if level.transfer ~= nil then -- 2106
				local radius = distance( -- 2108
					probePos, -- 2108
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 2108
				) -- 2108
				local plan = planTransfer( -- 2109
					level.bodies[1].gm, -- 2109
					radius, -- 2109
					probeVel, -- 2109
					a.power, -- 2109
					level.transfer.apoapsisMax, -- 2109
					level.transfer.mode, -- 2109
					level.transfer.periapsisMin -- 2109
				) -- 2109
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 2110
				if deps.aim.setTransferInfo ~= nil then -- 2110
					deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 2111
				end -- 2111
			end -- 2111
			aimed = true -- 2113
		end, -- 2104
		aimReady = function() -- 2115
			predForce = true -- 2117
			if not ____exports.coreArm(core) then -- 2117
				return -- 2118
			end -- 2118
			if level.transfer ~= nil then -- 2118
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 2119
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 2119
					4 -- 2119
				)) -- 2119
			end -- 2119
			applyView() -- 2120
			deps:onPhase("Armed") -- 2121
		end, -- 2115
		cancelAim = function() -- 2123
			if not ____exports.coreCancelArm(core) then -- 2123
				return -- 2124
			end -- 2124
			aimed = false -- 2125
			predForce = true -- 2126
			deps.trajectory:clearPrediction() -- 2127
			deps.plan:clearPrediction() -- 2128
			applyView() -- 2129
			deps:onPhase("Aiming") -- 2130
			print("[escape-velocity] aim cancelled") -- 2131
		end, -- 2123
		launchArmed = function() -- 2133
			if core.phase ~= "Armed" then -- 2133
				return -- 2135
			end -- 2135
			resetCinematic() -- 2136
			applyFlightSpeed() -- 2137
			handoffDate(true) -- 2138
			reportedBonusIds = {} -- 2139
			bonusEffectElapsed = {} -- 2140
			do -- 2140
				local i = 0 -- 2141
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2141
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2141
					i = i + 1 -- 2141
				end -- 2141
			end -- 2141
			____exports.coreLaunch( -- 2142
				core, -- 2142
				core.aim.velocity, -- 2142
				level, -- 2142
				probePos, -- 2142
				probeVel -- 2142
			) -- 2142
			deps.trajectory:clearPrediction() -- 2143
			deps.plan:clearPrediction() -- 2144
			applyView() -- 2145
			deps:onPhase("Flying") -- 2146
		end, -- 2133
		armed = function() return core.phase == "Armed" end, -- 2148
		viewMode = function() return core.viewMode end, -- 2149
		toggleViewMode = function() -- 2150
			____exports.coreToggleView(core) -- 2152
			applyView() -- 2153
		end, -- 2150
		cameraFocus = function() return focusMode end, -- 2155
		flightStage = function() return level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalShotAt( -- 2156
			core.flightTime, -- 2156
			core.burnDuration, -- 2156
			core.flyby, -- 2156
			level.transfer.orbital, -- 2156
			core.dt -- 2156
		) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 2156
			core.flightTime, -- 2157
			core.burnDuration, -- 2157
			core.flyby, -- 2157
			level.transfer.flyby, -- 2157
			core.dt -- 2157
		) or nil) end, -- 2157
		cycleCameraFocus = function() -- 2158
			if not transferCinematic(level.transfer) or core.phase ~= "Flying" then -- 2158
				return -- 2159
			end -- 2159
			local ____temp_12 -- 2160
			if level.transfer ~= nil and level.transfer.orbital ~= nil then -- 2160
				local ____array_11 = __TS__SparseArrayNew( -- 2160
					"Auto", -- 2160
					"Probe", -- 2160
					table.unpack(__TS__ArrayMap( -- 2160
						level.transfer.orbital.encounters, -- 2160
						function(____, e) return e.focus end -- 2160
					)) -- 2160
				) -- 2160
				__TS__SparseArrayPush( -- 2160
					____array_11, -- 2160
					table.unpack(level.transfer.orbital.targetFlyby ~= nil and ({level.transfer.orbital.targetFlyby.focus}) or ({})) -- 2160
				) -- 2160
				__TS__SparseArrayPush(____array_11, "Sun", "Overview") -- 2160
				____temp_12 = {__TS__SparseArraySpread(____array_11)} -- 2160
			else -- 2160
				____temp_12 = nil -- 2160
			end -- 2160
			local modes = ____temp_12 -- 2160
			focusMode = nextCameraFocus(focusMode, modes) -- 2161
			playerPose = nil -- 2162
			if focusMode ~= "Auto" then -- 2162
				capturePlayerCamera(true) -- 2163
			else -- 2163
				cineKey = "Manual" -- 2164
				cineFrom = cineFrame -- 2164
			end -- 2164
			obsYawDeg = 0 -- 2165
			obsPitchDeg = 0 -- 2165
			obsZoom = 1 -- 2165
			print("[escape-velocity] camera focus -> " .. focusMode) -- 2166
		end, -- 2158
		missionCompleted = function() return core.missionCompleted end, -- 2168
		markerElapsed = function() return markerElapsed end, -- 2169
		endViewing = function() -- 2170
			if not ____exports.coreEndViewing(core) then -- 2170
				return -- 2171
			end -- 2171
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 2172
			finishFlight() -- 2173
		end, -- 2170
		skipIntroTour = function() -- 2175
			finishIntroTour() -- 2176
		end, -- 2175
		isIntroTourActive = function() return introTourActive end, -- 2178
		observeDrag = function(____, dx, dy) -- 2179
			if core.phase == "Flying" and core.viewMode == "3D" and transferCinematic(level.transfer) then -- 2179
				if dx == 0 and dy == 0 then -- 2179
					return -- 2181
				end -- 2181
				if focusMode == "Auto" then -- 2181
					focusMode = "Probe" -- 2182
					capturePlayerCamera() -- 2182
					print("[escape-velocity] camera takeover -> Probe") -- 2182
				end -- 2182
				if playerPose ~= nil then -- 2182
					rotateObserve(playerPose, dx, dy) -- 2183
				end -- 2183
				return -- 2184
			end -- 2184
			if introTourActive then -- 2184
				finishIntroTour() -- 2187
				return -- 2188
			end -- 2188
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2190
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2191
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2192
			if obsPitchDeg > 40 then -- 2192
				obsPitchDeg = 40 -- 2193
			end -- 2193
			if obsPitchDeg < -40 then -- 2193
				obsPitchDeg = -40 -- 2194
			end -- 2194
		end, -- 2179
		observeZoom = function(____, deltaDist) -- 2196
			if core.phase == "Flying" and core.viewMode == "3D" and transferCinematic(level.transfer) then -- 2196
				if focusMode == "Auto" then -- 2196
					focusMode = "Probe" -- 2198
					capturePlayerCamera() -- 2198
				end -- 2198
				if playerPose ~= nil then -- 2198
					zoomObserve( -- 2199
						playerPose, -- 2199
						deltaDist, -- 2199
						playerMinDistance(), -- 2199
						deps.rig.distanceBounds().max -- 2199
					) -- 2199
				end -- 2199
				return -- 2200
			end -- 2200
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2202
			if obsZoom < 0.4 then -- 2202
				obsZoom = 0.4 -- 2203
			end -- 2203
			if obsZoom > 1.8 then -- 2203
				obsZoom = 1.8 -- 2204
			end -- 2204
		end, -- 2196
		launch = function(____, v) -- 2206
			applyFlightSpeed() -- 2207
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2207
				return -- 2208
			end -- 2208
			resetCinematic() -- 2209
			handoffDate(true) -- 2210
			reportedBonusIds = {} -- 2211
			bonusEffectElapsed = {} -- 2212
			do -- 2212
				local i = 0 -- 2213
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2213
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2213
					i = i + 1 -- 2213
				end -- 2213
			end -- 2213
			____exports.coreLaunch( -- 2215
				core, -- 2215
				v, -- 2215
				level, -- 2215
				probePos, -- 2215
				probeVel -- 2215
			) -- 2215
			deps.trajectory:clearPrediction() -- 2216
			deps.plan:clearPrediction() -- 2217
			applyView() -- 2218
			deps:onPhase("Flying") -- 2219
		end, -- 2206
		retry = function() -- 2221
			resetCinematic() -- 2222
			handoffDate(false) -- 2223
			aimed = false -- 2224
			introTourActive = false -- 2225
			____exports.coreRetry(core, level.aimMin) -- 2226
			if deps.scene.resetStars ~= nil then -- 2226
				deps.scene.resetStars() -- 2228
			end -- 2228
			deps.plan:setStars(core.stars, core.collectedStars) -- 2230
			deps.trajectory:clearTrail() -- 2231
			deps.trajectory:clearPrediction() -- 2232
			deps.trajectory:clearGoalRings() -- 2233
			deps.plan:clearTrail() -- 2234
			deps.plan:clearPrediction() -- 2235
			deps.plan:clearGoalRings() -- 2236
			applyView() -- 2237
			deps:onPhase("Aiming") -- 2238
		end, -- 2221
		backToSelect = function() -- 2240
			if not ____exports.coreBackToSelect(core) then -- 2240
				return false -- 2241
			end -- 2241
			deps.aim:setEnabled(false) -- 2243
			deps.trajectory:clearTrail() -- 2244
			deps.trajectory:clearPrediction() -- 2245
			deps.trajectory:clearGoalRings() -- 2246
			deps.plan:clearTrail() -- 2247
			deps.plan:clearPrediction() -- 2248
			deps.plan:clearGoalRings() -- 2249
			applyView() -- 2250
			deps:onPhase("LevelSelect") -- 2251
			return true -- 2252
		end, -- 2240
		startLevel = function() -- 2254
			resetCinematic() -- 2255
			aimed = false -- 2256
			____exports.coreRetry(core, level.aimMin) -- 2257
			if deps.scene.resetStars ~= nil then -- 2257
				deps.scene.resetStars() -- 2259
			end -- 2259
			deps.plan:setStars(core.stars, core.collectedStars) -- 2261
			deps.rig.reset() -- 2262
			introTourActive = false -- 2264
			core.viewMode = "2D" -- 2265
			appliedMode = "" -- 2266
			applyView() -- 2267
			prepareIdle() -- 2268
			deps.trajectory:clearTrail() -- 2269
			deps.trajectory:clearPrediction() -- 2270
			deps.trajectory:clearGoalRings() -- 2271
			deps.plan:clearTrail() -- 2272
			deps.plan:clearPrediction() -- 2273
			deps.plan:clearGoalRings() -- 2274
			deps:onPhase("Aiming") -- 2275
		end, -- 2254
		stepTime = function(____, dir, span) -- 2277
			if not ____exports.coreTimeWarpAllowed(core) then -- 2277
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2281
				return -- 2282
			end -- 2282
			local span0 = span > 0 and span or 0 -- 2284
			clock = clock + dir * TimeWarpStep -- 2285
			if clock < 0 then -- 2285
				clock = 0 -- 2286
			end -- 2286
			if span0 > 0 and clock > span0 then -- 2286
				clock = span0 -- 2287
			end -- 2287
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2289
		end, -- 2277
		dateNow = function() return core.t0 + clock end, -- 2291
		setPlaybackSpeed = function(____, speed) -- 2292
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2292
				return -- 2294
			end -- 2294
			core.playback = speed -- 2295
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2296
		end, -- 2292
		playbackSpeed = function() return core.playback end, -- 2298
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2299
		starsNow = function() -- 2300
			if core.phase == "Flying" or core.phase == "Result" then -- 2300
				local n = 0 -- 2302
				do -- 2302
					local i = 0 -- 2303
					while i < #core.collectedStars do -- 2303
						if core.collectedStars[i + 1] then -- 2303
							n = n + 1 -- 2303
						end -- 2303
						i = i + 1 -- 2303
					end -- 2303
				end -- 2303
				return n -- 2304
			end -- 2304
			return core.previewStarsCount -- 2306
		end, -- 2300
		bonusScore = function() return core.bonusRockets end, -- 2308
		bonusTotal = function() return level.bonusPoints ~= nil and #level.bonusPoints or 0 end, -- 2309
		update = function(____, frameDt) return update(frameDt) end -- 2311
	} -- 2311
end -- 939
return ____exports -- 939
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
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 226
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 227
	local n = math.floor(pow) -- 228
	while n > 0 do -- 228
		rate = rate * 10 -- 230
		n = n - 1 -- 231
	end -- 231
	while n < 0 do -- 231
		rate = rate / 10 -- 234
		n = n + 1 -- 235
	end -- 235
	return rate -- 237
end -- 226
--- 按关卡上下界调整档位，供状态转换与边界测试共用。
function ____exports.shiftSpeedPow(pow, minPow, maxPow, direction) -- 241
	if direction < 0 then -- 241
		return pow > minPow and pow - 1 or pow -- 242
	end -- 242
	if direction > 0 then -- 242
		return pow < maxPow and pow + 1 or pow -- 243
	end -- 243
	return pow -- 244
end -- 241
local function neutralAim(minSpeed) -- 247
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 248
end -- 247
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 252
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 253
end -- 252
--- 星尘在时刻 t 的位置（没有轨道就用静态坐标）。
local function starPositionsNow(orbits, fallback, t) -- 257
	local out = {} -- 258
	do -- 258
		local i = 0 -- 259
		while i < #fallback do -- 259
			local orbit = i < #orbits and orbits[i + 1] or nil -- 260
			out[#out + 1] = starPositionAt(orbit, fallback[i + 1], t) -- 261
			i = i + 1 -- 259
		end -- 259
	end -- 259
	return out -- 263
end -- 257
function ____exports.createCore(dt, stars, starOrbits) -- 266
	local stList = stars ~= nil and stars or ({}) -- 267
	local colList = {} -- 268
	do -- 268
		local i = 0 -- 269
		while i < #stList do -- 269
			colList[#colList + 1] = false -- 269
			i = i + 1 -- 269
		end -- 269
	end -- 269
	local orbits = starOrbits ~= nil and starOrbits or ({}) -- 270
	return { -- 271
		phase = "Aiming", -- 272
		aim = neutralAim(AimMinSpeed), -- 273
		flight = nil, -- 274
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 275
		burnDuration = 0, -- 276
		t0 = 0, -- 277
		flightTime = 0, -- 278
		missionCompleted = false, -- 279
		flyby = nil, -- 280
		goalIndex = -1, -- 281
		result = nil, -- 282
		viewMode = "2D", -- 284
		playback = FlightPlayback, -- 286
		slowmo = false, -- 287
		slowmoBody = -1, -- 288
		stars = stList, -- 289
		starOrbits = orbits, -- 290
		collectedStars = colList, -- 291
		collectedBonus = {}, -- 292
		bonusRockets = 0, -- 293
		previewStarsCount = 0 -- 294
	} -- 294
end -- 266
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 306
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 307
	return core.viewMode -- 308
end -- 306
--- 教学关显式指定中心宿主；旧关卡仍按最近的有引力天体选择。
function ____exports.selectIdleHost(bodies, start, preferred) -- 312
	if preferred ~= nil and bodies[preferred + 1] ~= nil and bodies[preferred + 1].gm > 0 then -- 312
		return preferred -- 313
	end -- 313
	local index = -1 -- 314
	local nearest = 1000000000 -- 315
	do -- 315
		local i = 0 -- 316
		while i < #bodies do -- 316
			do -- 316
				if bodies[i + 1].gm <= 0 then -- 316
					goto __continue25 -- 317
				end -- 317
				local d = distance( -- 318
					bodyPositionAt(bodies[i + 1], 0), -- 318
					start -- 318
				) -- 318
				if d < nearest then -- 318
					nearest = d -- 319
					index = i -- 319
				end -- 319
			end -- 319
			::__continue25:: -- 319
			i = i + 1 -- 316
		end -- 316
	end -- 316
	return index -- 321
end -- 312
--- 预测线与瞬时点火的初始速度。教学关实际发射另行积分有限燃烧。
function ____exports.burnToMotion(burn, probeVel0) -- 325
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 326
	return {x = v0.x + burn.x, y = v0.y + burn.y} -- 327
end -- 325
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 336
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 336
		return -- 338
	end -- 338
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 339
	local motion = ____exports.burnToMotion(burn, base) -- 340
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 341
	core.burnDuration = level.transfer ~= nil and mag / level.transfer.thrustAcceleration or 0 -- 342
	local thrust = core.burnDuration > 0 and ({acceleration = {x = burn.x / core.burnDuration, y = burn.y / core.burnDuration}, duration = core.burnDuration}) or nil -- 343
	local p0 = from ~= nil and from or level.probeStart -- 344
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = level.transfer ~= nil and base ~= nil and base or motion}, level.bodies, { -- 345
		steps = level.maxSteps, -- 348
		dt = core.dt, -- 348
		sampleEvery = 1, -- 348
		escapeRadius = level.escapeRadius, -- 348
		t0 = core.t0, -- 348
		initialBurn = thrust -- 348
	}) -- 348
	core.flight = flight -- 350
	core.missionCompleted = false -- 351
	local ____core_1 = core -- 352
	local ____temp_0 -- 352
	if level.transfer ~= nil then -- 352
		____temp_0 = analyzeTransfer( -- 352
			flight, -- 352
			level.bodies, -- 352
			level.goal.planetIndex, -- 352
			level.transfer, -- 352
			core.dt, -- 352
			core.t0 -- 352
		) -- 352
	else -- 352
		____temp_0 = nil -- 352
	end -- 352
	____core_1.flyby = ____temp_0 -- 352
	core.goalIndex = findGoalIndex( -- 353
		flight.points, -- 353
		level.bodies, -- 353
		level.goal, -- 353
		core.dt, -- 353
		core.t0, -- 353
		flight.velocities -- 353
	) -- 353
	core.result = core.goalIndex >= 0 and "success" or (flight.outcome == "crashed" and "crashed" or "missed") -- 354
	core.collectedBonus = {} -- 355
	core.bonusRockets = 0 -- 356
	do -- 356
		local i = 0 -- 357
		while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 357
			local ____core_collectedBonus_2 = core.collectedBonus -- 357
			____core_collectedBonus_2[#____core_collectedBonus_2 + 1] = false -- 357
			i = i + 1 -- 357
		end -- 357
	end -- 357
	if core.flyby ~= nil then -- 357
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 358
	end -- 358
	if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 358
		for ____, e in ipairs(core.flyby.encounters) do -- 361
			print((((((((("[escape-velocity] encounter body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " energy=") .. __TS__NumberToFixed(e.energyChange, 2)) .. " work=") .. __TS__NumberToFixed(e.work, 2)) .. " passed=") .. (e.passed and "1" or "0")) -- 361
		end -- 361
	end -- 361
	if core.flyby ~= nil and core.flyby.destination ~= nil then -- 361
		local e = core.flyby.destination -- 363
		print((((((((("[escape-velocity] destination body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " entry=") .. __TS__NumberToFixed(e.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(e.exitIndex, 0)) .. " passed=") .. (e.passed and "1" or "0")) -- 364
	end -- 364
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.x, 5)) .. ",") .. __TS__NumberToFixed(motion.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. (core.result ~= nil and core.result or "pending")) -- 368
	core.flightTime = 0 -- 373
	core.slowmo = false -- 375
	core.slowmoBody = -1 -- 376
	core.phase = "Flying" -- 377
	core.viewMode = "3D" -- 379
end -- 336
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 388
	if core.phase ~= "Aiming" then -- 388
		return false -- 389
	end -- 389
	core.phase = "Armed" -- 390
	return true -- 391
end -- 388
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 395
	if core.phase ~= "Armed" then -- 395
		return false -- 396
	end -- 396
	core.phase = "Aiming" -- 397
	return true -- 398
end -- 395
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 412
	return core.phase == "Aiming" or core.phase == "Armed" -- 413
end -- 412
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 429
	if toT0 then -- 429
		return {t0 = clock, clock = 0} -- 430
	end -- 430
	return {t0 = 0, clock = t0} -- 431
end -- 429
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 443
	local host = -1 -- 453
	do -- 453
		local i = 0 -- 454
		while i < #bodies do -- 454
			do -- 454
				local b = bodies[i + 1] -- 455
				local isHost = false -- 456
				do -- 456
					local j = 0 -- 457
					while j < #bodies do -- 457
						do -- 457
							local h = bodies[j + 1].host -- 458
							if h == nil then -- 458
								goto __continue49 -- 459
							end -- 459
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 459
								isHost = true -- 460
								break -- 460
							end -- 460
						end -- 460
						::__continue49:: -- 460
						j = j + 1 -- 457
					end -- 457
				end -- 457
				if not isHost then -- 457
					goto __continue47 -- 462
				end -- 462
				if host < 0 or b.gm > bodies[host + 1].gm then -- 462
					host = i -- 463
				end -- 463
			end -- 463
			::__continue47:: -- 463
			i = i + 1 -- 454
		end -- 454
	end -- 454
	if host >= 0 then -- 454
		return host -- 465
	end -- 465
	local best = -1 -- 467
	do -- 467
		local i = 0 -- 468
		while i < #bodies do -- 468
			do -- 468
				local b = bodies[i + 1] -- 469
				if b.orbitRadius ~= 0 then -- 469
					goto __continue56 -- 470
				end -- 470
				if best < 0 or b.gm > bodies[best + 1].gm then -- 470
					best = i -- 471
				end -- 471
			end -- 471
			::__continue56:: -- 471
			i = i + 1 -- 468
		end -- 468
	end -- 468
	return best -- 473
end -- 443
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 491
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 492
	local best = -1 -- 493
	local bestD = 1000000000 -- 494
	do -- 494
		local i = 0 -- 495
		while i < #bodies do -- 495
			do -- 495
				if i == anchor then -- 495
					goto __continue61 -- 496
				end -- 496
				local b = bodies[i + 1] -- 497
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 498
				local d = distance( -- 499
					probe, -- 499
					bodyPositionAt(b, t) -- 499
				) -- 499
				if d < threshold and d < bestD then -- 499
					bestD = d -- 501
					best = i -- 502
				end -- 502
			end -- 502
			::__continue61:: -- 502
			i = i + 1 -- 495
		end -- 495
	end -- 495
	return best -- 505
end -- 491
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 509
	if core.flight == nil then -- 509
		return 0 -- 510
	end -- 510
	local idx = math.floor(core.flightTime / core.dt) -- 511
	local last = #core.flight.points - 1 -- 512
	if idx > last then -- 512
		idx = last -- 513
	end -- 513
	if idx < 0 then -- 513
		idx = 0 -- 514
	end -- 514
	return idx -- 515
end -- 509
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
function ____exports.coreUpdate(core, dt, level) -- 532
	if core.phase ~= "Flying" or core.flight == nil then -- 532
		return false -- 533
	end -- 533
	local previousIndex = ____exports.coreProbeIndex(core) -- 534
	if level ~= nil and level.transfer == nil then -- 534
		local idx = ____exports.coreProbeIndex(core) -- 538
		core.slowmoBody = ____exports.slowMotionBody( -- 539
			level.bodies, -- 539
			core.flight.points[idx + 1], -- 539
			core.t0 + core.flightTime, -- 539
			____exports.anchorBodyIndex(level.bodies), -- 539
			level.slowMoFloor -- 539
		) -- 539
		core.slowmo = core.slowmoBody >= 0 -- 540
	end -- 540
	if level ~= nil and level.transfer ~= nil then -- 540
		core.flightTime = advanceTransferPlayback( -- 544
			core.flightTime, -- 544
			dt, -- 544
			core.playback, -- 544
			core.burnDuration, -- 544
			level.transfer, -- 544
			core.flyby, -- 544
			core.dt -- 544
		) -- 544
	else -- 544
		core.flightTime = core.flightTime + dt * core.playback * (core.slowmo and SlowMoFactor or 1) -- 546
	end -- 546
	if not core.missionCompleted and core.goalIndex >= 0 and ____exports.coreProbeIndex(core) >= core.goalIndex then -- 546
		core.missionCompleted = true -- 549
		core.result = "success" -- 550
	end -- 550
	if level ~= nil and level.bonusPoints ~= nil and core.flight ~= nil then -- 550
		local ____end = ____exports.coreProbeIndex(core) -- 553
		local start = math.max(0, previousIndex) -- 554
		do -- 554
			local i = 0 -- 555
			while i < #level.bonusPoints do -- 555
				do -- 555
					if not core.collectedBonus[i + 1] then -- 555
						local point = level.bonusPoints[i + 1] -- 556
						local body = point.bodyIndex ~= nil and level.bodies[point.bodyIndex + 1] or point.orbit -- 557
						if body == nil then -- 557
							goto __continue76 -- 558
						end -- 558
						do -- 558
							local k = start -- 559
							while k <= ____end and k < #core.flight.points do -- 559
								local target = point.position ~= nil and point.position or goalPositionAt(body, core.t0 + k * core.dt, point.offset) -- 560
								if distance(core.flight.points[k + 1], target) <= point.tolerance then -- 560
									core.collectedBonus[i + 1] = true -- 562
									core.bonusRockets = core.bonusRockets + 1 -- 563
									break -- 564
								end -- 564
								k = k + 1 -- 559
							end -- 559
						end -- 559
					end -- 559
				end -- 559
				::__continue76:: -- 559
				i = i + 1 -- 555
			end -- 555
		end -- 555
	end -- 555
	if core.stars ~= nil and #core.stars > 0 then -- 555
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 572
		do -- 572
			local s = 0 -- 573
			while s < #core.stars do -- 573
				if not core.collectedStars[s + 1] then -- 573
					local orbit = s < #core.starOrbits and core.starOrbits[s + 1] or nil -- 575
					local stPos = starPositionAt(orbit, core.stars[s + 1], core.t0 + core.flightTime) -- 576
					local dx = curPos.x - stPos.x -- 577
					local dy = curPos.y - stPos.y -- 578
					if dx * dx + dy * dy <= 30 * 30 then -- 578
						core.collectedStars[s + 1] = true -- 580
					end -- 580
				end -- 580
				s = s + 1 -- 573
			end -- 573
		end -- 573
	end -- 573
	local naturalEnd = #core.flight.points - 1 -- 586
	local viewingSteps = level ~= nil and level.viewingSeconds ~= nil and math.floor(level.viewingSeconds / core.dt) or 0 -- 587
	local endIdx = core.goalIndex >= 0 and math.min(naturalEnd, core.goalIndex + viewingSteps) or naturalEnd -- 588
	if core.goalIndex >= 0 and level ~= nil and level.levelId == 1 and core.flyby ~= nil and core.flyby.viewEndIndex > core.goalIndex then -- 588
		endIdx = math.min(endIdx, core.flyby.viewEndIndex) -- 589
	end -- 589
	local ____temp_5 = core.goalIndex >= 0 and level ~= nil and level.levelId == 2 -- 590
	if ____temp_5 then -- 590
		local ____opt_3 = core.flyby -- 590
		____temp_5 = (____opt_3 and ____opt_3.destination) ~= nil -- 590
	end -- 590
	if ____temp_5 and core.flyby.destination.exitIndex >= core.goalIndex and core.flyby.destination.exitIndex < naturalEnd then -- 590
		endIdx = math.min( -- 591
			endIdx, -- 591
			core.flyby.destination.exitIndex + math.floor(6 / core.dt) -- 591
		) -- 591
	end -- 591
	if ____exports.coreProbeIndex(core) >= endIdx then -- 591
		core.flightTime = endIdx * core.dt -- 595
		core.phase = "Result" -- 596
		return true -- 597
	end -- 597
	return false -- 599
end -- 532
--- 已完成的教学关可提前结束观赏，不能用该操作跳过掠月判定。
function ____exports.coreEndViewing(core) -- 603
	if core.phase ~= "Flying" or not core.missionCompleted then -- 603
		return false -- 604
	end -- 604
	core.flightTime = ____exports.coreProbeIndex(core) * core.dt -- 605
	core.phase = "Result" -- 606
	return true -- 607
end -- 603
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 613
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 617
	local maxSpeed = 0 -- 618
	local closestDist = 1000000000 -- 619
	local eccentricity = nil -- 620
	if core.flight ~= nil then -- 620
		local pts = core.flight.points -- 623
		local vels = core.flight.velocities -- 624
		local ____end = ____exports.coreProbeIndex(core) -- 625
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 626
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 627
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 628
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 629
		do -- 629
			local k = 0 -- 631
			while k <= ____end and k < #pts do -- 631
				local p = pts[k + 1] -- 632
				if vels ~= nil and k < #vels then -- 632
					local v = vels[k + 1] -- 634
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 635
					if spd > maxSpeed then -- 635
						maxSpeed = spd -- 636
					end -- 636
				end -- 636
				if distTargetBody ~= nil then -- 636
					local t = core.t0 + k * core.dt -- 639
					local tp = bodyPositionAt(distTargetBody, t) -- 640
					local d = distance(p, tp) -- 641
					if d < closestDist then -- 641
						closestDist = d -- 642
					end -- 642
				end -- 642
				k = k + 1 -- 631
			end -- 631
		end -- 631
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 631
			local tEnd = core.t0 + ____end * core.dt -- 647
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 648
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 649
			local rx = pts[____end + 1].x - tpEnd.x -- 650
			local ry = pts[____end + 1].y - tpEnd.y -- 651
			local vx = vels[____end + 1].x - tvEnd.x -- 652
			local vy = vels[____end + 1].y - tvEnd.y -- 653
			local r = math.sqrt(rx * rx + ry * ry) -- 654
			local v2 = vx * vx + vy * vy -- 655
			local mu = goalBody.gm -- 656
			if r > 0 and mu > 0 then -- 656
				local energy = v2 / 2 - mu / r -- 658
				local h = rx * vy - ry * vx -- 659
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 660
				if term >= 0 then -- 660
					eccentricity = math.sqrt(term) -- 662
				end -- 662
			end -- 662
		end -- 662
	end -- 662
	local starsCollectedCount = 0 -- 668
	do -- 668
		local i = 0 -- 669
		while i < #core.collectedStars do -- 669
			if core.collectedStars[i + 1] then -- 669
				starsCollectedCount = starsCollectedCount + 1 -- 670
			end -- 670
			i = i + 1 -- 669
		end -- 669
	end -- 669
	return { -- 673
		burnDv = burnDv, -- 674
		flightTime = core.flightTime, -- 675
		closestDist = closestDist < 100000000 and closestDist or 0, -- 676
		maxSpeed = maxSpeed, -- 677
		eccentricity = eccentricity, -- 678
		starsCollected = starsCollectedCount, -- 679
		bonusRockets = core.bonusRockets -- 680
	} -- 680
end -- 613
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 685
	core.phase = "Aiming" -- 686
	core.viewMode = "2D" -- 688
	core.flight = nil -- 689
	core.flightTime = 0 -- 690
	core.missionCompleted = false -- 691
	core.flyby = nil -- 692
	core.goalIndex = -1 -- 693
	core.bonusRockets = 0 -- 694
	do -- 694
		local i = 0 -- 695
		while i < #core.collectedBonus do -- 695
			core.collectedBonus[i + 1] = false -- 695
			i = i + 1 -- 695
		end -- 695
	end -- 695
	core.result = nil -- 696
	core.burnDuration = 0 -- 697
	core.slowmo = false -- 698
	core.slowmoBody = -1 -- 699
	do -- 699
		local i = 0 -- 700
		while i < #core.collectedStars do -- 700
			core.collectedStars[i + 1] = false -- 700
			i = i + 1 -- 700
		end -- 700
	end -- 700
	core.previewStarsCount = 0 -- 701
	core.aim = neutralAim(levelAimMin(aimMin)) -- 702
end -- 685
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 716
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 716
		return false -- 718
	end -- 718
	core.phase = "LevelSelect" -- 719
	core.viewMode = "2D" -- 721
	core.flight = nil -- 722
	core.flightTime = 0 -- 723
	core.goalIndex = -1 -- 724
	core.result = nil -- 725
	core.slowmo = false -- 726
	core.slowmoBody = -1 -- 727
	return true -- 728
end -- 716
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 757
	if core.phase ~= "Result" then -- 757
		return false -- 758
	end -- 758
	core.phase = "Finale" -- 759
	return true -- 760
end -- 757
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 778
	local dist = distance > 1 and distance or 1 -- 779
	local ux = probe.x -- 781
	local uy = probe.y -- 782
	local len = math.sqrt(ux * ux + uy * uy) -- 783
	if len < 0.000001 then -- 783
		ux = 0 -- 784
		uy = 1 -- 784
	else -- 784
		ux = ux / len -- 784
		uy = uy / len -- 784
	end -- 784
	local tilt = tiltDeg * math.pi / 180 -- 785
	local flat = math.cos(tilt) * dist -- 786
	return { -- 787
		target = Vec3(0, 0, 0), -- 789
		eye = Vec3( -- 790
			ux * flat * PlaneToWorldX, -- 790
			math.sin(tilt) * dist, -- 790
			uy * flat * PlaneToWorldZ -- 790
		) -- 790
	} -- 790
end -- 778
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 938
	local introTourActive, introTourT -- 938
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 939
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 945
	local paused = false -- 946
	local speedMinPow = level.speedMinPow ~= nil and level.speedMinPow or 0 -- 947
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 948
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 950
	local function applySpeedRate() -- 951
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 952
	end -- 951
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 965
		if level.transfer ~= nil then -- 965
			paused = false -- 966
			speedPow = 0 -- 966
			applySpeedRate() -- 966
			return -- 966
		end -- 966
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 966
			return -- 967
		end -- 967
		speedPow = level.flightSpeedPow -- 968
		paused = false -- 969
		applySpeedRate() -- 970
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 971
	end -- 965
	applySpeedRate() -- 977
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 980
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
	local function applyView() -- 995
		local mode = core.viewMode -- 996
		if mode == appliedMode then -- 996
			return -- 997
		end -- 997
		appliedMode = mode -- 998
		local is2D = mode == "2D" -- 999
		deps.plan:setVisible(is2D) -- 1000
		deps.trajectory.root.visible = not is2D -- 1001
		deps:setWorldVisible(not is2D) -- 1002
		deps.aim:setFullScreenAim(is2D) -- 1003
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 1004
	end -- 995
	local ____temp_6 -- 1007
	if level.mission ~= nil then -- 1007
		____temp_6 = level.mission.introTour -- 1007
	else -- 1007
		____temp_6 = nil -- 1007
	end -- 1007
	local tourDef = ____temp_6 -- 1007
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 1008
	local function finishIntroTour() -- 1010
		if not introTourActive then -- 1010
			return -- 1011
		end -- 1011
		introTourActive = false -- 1012
		introTourT = tourDuration -- 1013
		core.viewMode = "2D" -- 1014
		applyView() -- 1015
		deps.aim:setIntroTourBannerVisible(false) -- 1016
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1017
	end -- 1010
	local function makeBasis(frame) -- 1020
		return prepareCamera({ -- 1021
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1023
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1024
			up = {x = 0, y = 1, z = 0}, -- 1025
			fovYDeg = deps.fovYDeg, -- 1026
			aspect = deps.aspect, -- 1027
			viewW = deps.viewW, -- 1028
			viewH = deps.viewH -- 1029
		}, HANDEDNESS, FLIP_Y) -- 1029
	end -- 1020
	local PredMinIntervalSec = 0.08 -- 1041
	local predAimKey = "" -- 1042
	local predPosKey = "" -- 1043
	local predAccum = 1 -- 1044
	local predForce = true -- 1045
	local predPoints = {} -- 1046
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 1048
	introTourActive = false -- 1050
	introTourT = tourDuration -- 1051
	local introLogged = false -- 1052
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1054
	local clock = 0 -- 1060
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1062
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1064
	local obsYawDeg = 0 -- 1068
	local obsPitchDeg = 0 -- 1069
	local obsZoom = 1 -- 1070
	local focusMode = "Auto" -- 1071
	local markerElapsed = -1 -- 1072
	local reportedBonusIds = {} -- 1073
	local bonusEffectElapsed = {} -- 1074
	local cineKey = "" -- 1075
	local cineFrame = nil -- 1076
	local cineFrom = nil -- 1077
	local cineTransition = 0 -- 1078
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1080
	local idleOrbit = nil -- 1082
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1093
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1095
	local lastSlowmoBody = -1 -- 1096
	local flybySounded = {} -- 1097
	local cruiseAzimuth = 0 -- 1098
	local cruiseAzimuthReady = false -- 1099
	local flightLogT = 0 -- 1100
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1102
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1103
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
	local function prepareIdle() -- 1118
		clock = 0 -- 1120
		core.t0 = 0 -- 1121
		idleOrbit = nil -- 1122
		if level.probeVel0 == nil then -- 1122
			return -- 1123
		end -- 1123
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1125
		if hostIndex < 0 then -- 1125
			return -- 1126
		end -- 1126
		local host = level.bodies[hostIndex + 1] -- 1127
		local hp = bodyPositionAt(host, 0) -- 1128
		local hv = bodyVelocityAt(host, 0) -- 1129
		local rx = level.probeStart.x - hp.x -- 1131
		local ry = level.probeStart.y - hp.y -- 1132
		local vx = level.probeVel0.x - hv.x -- 1133
		local vy = level.probeVel0.y - hv.y -- 1134
		local r = math.sqrt(rx * rx + ry * ry) -- 1135
		if r < 1e-12 then -- 1135
			return -- 1136
		end -- 1136
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1138
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1139
		idleOrbit = { -- 1140
			hostIndex = hostIndex, -- 1140
			r = r, -- 1140
			phase0 = math.atan(ry, rx), -- 1140
			omega = dir * omega -- 1140
		} -- 1140
	end -- 1118
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1144
		if idleOrbit == nil then -- 1144
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1146
		end -- 1146
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1151
		local hp = bodyPositionAt(host, tWorld) -- 1152
		local hv = bodyVelocityAt(host, tWorld) -- 1153
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1154
		local ca = math.cos(a) -- 1155
		local sa = math.sin(a) -- 1156
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1157
	end -- 1144
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1174
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1175
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1178
		local wps = goalWaypoints(level.goal) -- 1179
		if #wps == 0 then -- 1179
			return nil -- 1180
		end -- 1180
		local passed = 0 -- 1181
		if core.flight ~= nil then -- 1181
			local upto = math.floor(core.flightTime / core.dt) -- 1183
			passed = waypointProgress( -- 1184
				core.flight.points, -- 1184
				level.bodies, -- 1184
				level.goal, -- 1184
				core.dt, -- 1184
				core.t0, -- 1184
				upto, -- 1184
				core.flight.velocities -- 1184
			).passed -- 1184
		end -- 1184
		if passed >= #wps then -- 1184
			return nil -- 1186
		end -- 1186
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1187
	end -- 1178
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1198
		if level.transfer ~= nil then -- 1198
			return { -- 1200
				pts = { -- 1200
					probe, -- 1200
					bodyPositionAt(level.bodies[1], t), -- 1200
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1200
					goalPositionAt(level.goal.marker ~= nil and level.goal.marker or level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1200
				}, -- 1200
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1201
			} -- 1201
		end -- 1201
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1201
			local hr = anchorDef.radius -- 1206
			do -- 1206
				local i = 0 -- 1207
				while i < #level.bodies do -- 1207
					local b = level.bodies[i + 1] -- 1208
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1208
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1208
							hr = deps.visuals[i + 1].displayRadius -- 1210
						end -- 1210
						break -- 1211
					end -- 1211
					i = i + 1 -- 1207
				end -- 1207
			end -- 1207
			return { -- 1214
				pts = { -- 1214
					probe, -- 1214
					bodyPositionAt(anchorDef, t) -- 1214
				}, -- 1214
				radii = {deps.scene.probeRadius, hr} -- 1214
			} -- 1214
		end -- 1214
		local corePts = {probe} -- 1218
		local coreRadii = {deps.scene.probeRadius} -- 1219
		local next = nextStationBody() -- 1220
		local nextTol = 0 -- 1221
		if next ~= nil then -- 1221
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1223
			local wps = goalWaypoints(level.goal) -- 1224
			local passed = 0 -- 1225
			if core.flight ~= nil then -- 1225
				passed = waypointProgress( -- 1227
					core.flight.points, -- 1227
					level.bodies, -- 1227
					level.goal, -- 1227
					core.dt, -- 1227
					core.t0, -- 1227
					math.floor(core.flightTime / core.dt), -- 1227
					core.flight.velocities -- 1227
				).passed -- 1227
			end -- 1227
			if passed < #wps then -- 1227
				nextTol = wps[passed + 1].tolerance -- 1229
			end -- 1229
			local r = nextTol > next.radius and nextTol or next.radius -- 1230
			coreRadii[#coreRadii + 1] = r -- 1231
		end -- 1231
		if anchorDef == nil then -- 1231
			return {pts = corePts, radii = coreRadii} -- 1234
		end -- 1234
		local anchorR = anchorDef.radius -- 1239
		do -- 1239
			local i = 0 -- 1240
			while i < #level.bodies do -- 1240
				local b = level.bodies[i + 1] -- 1241
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1241
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1241
						anchorR = deps.visuals[i + 1].displayRadius -- 1243
					end -- 1243
					break -- 1244
				end -- 1244
				i = i + 1 -- 1240
			end -- 1240
		end -- 1240
		local withAnchorPts = { -- 1247
			probe, -- 1247
			bodyPositionAt(anchorDef, t) -- 1247
		} -- 1247
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1248
		do -- 1248
			local i = 1 -- 1249
			while i < #corePts do -- 1249
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1250
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1251
				i = i + 1 -- 1249
			end -- 1249
		end -- 1249
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1253
		if want <= CameraFramingBudget then -- 1253
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1254
		end -- 1254
		return {pts = corePts, radii = coreRadii} -- 1255
	end -- 1198
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1259
		local marker = successMarkerFrame(markerElapsed) -- 1260
		if level.goal.region ~= nil then -- 1260
			local out = {} -- 1262
			local region = level.goal.region -- 1263
			local body = level.bodies[region.bodyIndex + 1] -- 1264
			if body ~= nil and (markerElapsed < 0 or marker.visible) then -- 1264
				local center = bodyPositionAt(body, t) -- 1266
				local alpha = markerElapsed >= 0 and marker.alpha or 0.55 -- 1267
				out[#out + 1] = { -- 1268
					center = center, -- 1268
					radius = body.radius + region.minAltitude, -- 1268
					bandOuterRadius = body.radius + region.maxAltitude, -- 1268
					passed = false, -- 1268
					pointAlpha = alpha -- 1268
				} -- 1268
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1269
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1270
			end -- 1270
			if level.bonusPoints ~= nil then -- 1270
				do -- 1270
					local i = 0 -- 1272
					while i < #level.bonusPoints do -- 1272
						do -- 1272
							local collected = core.collectedBonus[i + 1] -- 1273
							if collected and (bonusEffectElapsed[i + 1] == nil or bonusEffectElapsed[i + 1] >= 0.6) then -- 1273
								goto __continue161 -- 1274
							end -- 1274
							local p = level.bonusPoints[i + 1] -- 1275
							local targetBody = p.bodyIndex ~= nil and level.bodies[p.bodyIndex + 1] or p.orbit -- 1276
							if targetBody ~= nil then -- 1276
								local effect = collected and bonusEffectElapsed[i + 1] or -1 -- 1278
								out[#out + 1] = { -- 1279
									center = goalPositionAt(targetBody, t, p.offset), -- 1279
									radius = p.tolerance, -- 1279
									passed = false, -- 1279
									point = true, -- 1279
									showRange = not collected, -- 1279
									pulse = collected and 1 + effect * 2 or 1 + 0.1 * math.sin(t * 4), -- 1279
									pointAlpha = collected and 1 - effect / 0.6 or 1, -- 1279
									burstRadius = collected and p.tolerance * effect / 0.6 or nil -- 1279
								} -- 1279
							end -- 1279
						end -- 1279
						::__continue161:: -- 1279
						i = i + 1 -- 1272
					end -- 1272
				end -- 1272
			end -- 1272
			return out -- 1282
		end -- 1282
		if level.transfer ~= nil and not marker.visible then -- 1282
			return {} -- 1284
		end -- 1284
		local wps = goalWaypoints(level.goal) -- 1285
		if #wps == 0 then -- 1285
			return {} -- 1286
		end -- 1286
		local passed = 0 -- 1287
		if upto ~= nil and core.flight ~= nil then -- 1287
			passed = waypointProgress( -- 1289
				core.flight.points, -- 1289
				level.bodies, -- 1289
				level.goal, -- 1289
				core.dt, -- 1289
				core.t0, -- 1289
				upto, -- 1289
				core.flight.velocities -- 1289
			).passed -- 1289
		end -- 1289
		if transferCinematic(level.transfer) then -- 1289
			passed = 0 -- 1291
		end -- 1291
		if passed >= #wps then -- 1291
			return {} -- 1295
		end -- 1295
		local nextWp = wps[passed + 1] -- 1296
		local body = level.goal.marker ~= nil and level.goal.marker or level.bodies[nextWp.planetIndex + 1] -- 1297
		if body == nil then -- 1297
			return {} -- 1298
		end -- 1298
		local planning = aimed and (core.phase == "Aiming" or core.phase == "Armed") -- 1299
		local ____temp_7 -- 1300
		if level.transfer ~= nil then -- 1300
			____temp_7 = level.transfer.orbital -- 1300
		else -- 1300
			____temp_7 = nil -- 1300
		end -- 1300
		local orbital = ____temp_7 -- 1300
		local rings = {{ -- 1301
			center = goalPositionAt(body, t, nextWp.offset), -- 1301
			radius = nextWp.tolerance, -- 1301
			passed = false, -- 1301
			point = level.transfer ~= nil, -- 1302
			showRange = level.transfer == nil or (orbital == nil or orbital.targetFlyby ~= nil) and planning, -- 1302
			pulse = (1 + 0.1 * math.sin(t * 4)) * marker.scale, -- 1303
			pointAlpha = marker.alpha, -- 1303
			burstRadius = marker.ring -- 1303
		}} -- 1303
		if orbital ~= nil and orbital.region ~= nil and planning then -- 1303
			local center = bodyPositionAt(level.bodies[1], t) -- 1305
			__TS__ArrayPush(rings, {center = center, radius = orbital.region.minRadius, passed = false}, {center = center, radius = orbital.region.maxRadius, passed = false}) -- 1306
		end -- 1306
		return rings -- 1308
	end -- 1259
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1312
		if level.transfer ~= nil and not transferCinematic(level.transfer) then -- 1312
			local basis = makeBasis(f) -- 1314
			local dx = f.eye.x - f.target.x -- 1315
			local dy = f.eye.y - f.target.y -- 1315
			local dz = f.eye.z - f.target.z -- 1315
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1316
			f = { -- 1317
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1317
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1318
			} -- 1318
		end -- 1318
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1318
			return f -- 1320
		end -- 1320
		local dx = f.eye.x - f.target.x -- 1321
		local dy = f.eye.y - f.target.y -- 1322
		local dz = f.eye.z - f.target.z -- 1323
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1324
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1325
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1326
		local lo = CameraTiltMin * math.pi / 180 -- 1327
		local hi = CameraTiltMax * math.pi / 180 -- 1328
		if pitch < lo then -- 1328
			pitch = lo -- 1329
		end -- 1329
		if pitch > hi then -- 1329
			pitch = hi -- 1330
		end -- 1330
		local cp = math.cos(pitch) -- 1331
		return { -- 1332
			target = f.target, -- 1333
			eye = Vec3( -- 1334
				f.target.x + r * cp * math.sin(yaw), -- 1335
				f.target.y + r * math.sin(pitch), -- 1336
				f.target.z + r * cp * math.cos(yaw) -- 1337
			) -- 1337
		} -- 1337
	end -- 1312
	--- 相机放在探测器后方，平滑追随当前速度向量，避免巡航继续沿用点火方向。
	local function cruiseAzFor(velocity, wallDt) -- 1343
		local target = math.atan(-velocity.x, -velocity.y) * 180 / math.pi -- 1344
		if not cruiseAzimuthReady then -- 1344
			cruiseAzimuth = target -- 1346
			cruiseAzimuthReady = true -- 1347
			return cruiseAzimuth -- 1348
		end -- 1348
		local delta = target - cruiseAzimuth -- 1350
		while delta > 180 do -- 1350
			delta = delta - 360 -- 1351
		end -- 1351
		while delta < -180 do -- 1351
			delta = delta + 360 -- 1352
		end -- 1352
		cruiseAzimuth = cruiseAzimuth + delta * (1 - math.exp(-math.max(0, wallDt) * 5)) -- 1353
		return cruiseAzimuth -- 1354
	end -- 1343
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1358
		local cfg = level.transfer.flyby -- 1359
		local autoShot = transferShotAt( -- 1360
			core.flightTime, -- 1360
			core.burnDuration, -- 1360
			core.flyby, -- 1360
			cfg, -- 1360
			core.dt -- 1360
		) -- 1360
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1361
		local key = (focusMode .. ":") .. shot -- 1362
		local earth = bodyPositionAt(level.bodies[1], t) -- 1363
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1364
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1365
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1366
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1367
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1368
		local moonAz = launchAz -- 1369
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1369
			local at = core.flyby.entryIndex -- 1371
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1372
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1374
		end -- 1374
		local pts = {pos} -- 1376
		local radii = {deps.scene.probeRadius} -- 1376
		local az = launchAz -- 1377
		local tilt = 28 -- 1377
		local minDist = 130 -- 1377
		if shot == "Cruise" then -- 1377
			az = cruiseAzFor(velocity, wallDt) -- 1379
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 24 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 24 / vmag or 0)} -- 1380
			radii[#radii + 1] = 0 -- 1381
			minDist = 100 -- 1381
			tilt = 35 -- 1381
		elseif shot == "Moon" then -- 1381
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1383
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1384
			az = moonAz -- 1385
			tilt = 45 -- 1385
			minDist = 160 -- 1385
		elseif shot == "Earth" then -- 1385
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1387
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1388
			az = moonAz + 35 -- 1389
			tilt = 42 -- 1389
			minDist = 180 -- 1389
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1389
				local at = math.min( -- 1391
					#core.flight.points - 1, -- 1391
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1391
				) -- 1391
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1392
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1394
			end -- 1394
		elseif shot == "Overview" then -- 1394
			pts = {pos, earth, moon} -- 1397
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1397
			az = moonAz -- 1398
			tilt = 60 -- 1398
			minDist = 200 -- 1398
		end -- 1398
		if key ~= cineKey then -- 1398
			cineFrom = cineFrame -- 1401
			cineTransition = 0 -- 1402
			if cineKey == "" or shot == "Launch" then -- 1402
				cineFrom = nil -- 1404
			end -- 1404
			cineKey = key -- 1405
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1406
		end -- 1406
		local want = deps.rig.step( -- 1408
			pts, -- 1408
			deps.scene.probeRadius, -- 1408
			radii, -- 1408
			minDist, -- 1408
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1408
		) -- 1408
		local frame = want -- 1409
		if cineFrom ~= nil then -- 1409
			cineTransition = cineTransition + wallDt -- 1411
			local u = math.min(1, cineTransition / 0.6) -- 1412
			local k = u * u * (3 - 2 * u) -- 1413
			frame = { -- 1414
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1414
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1415
			} -- 1415
			if u >= 1 then -- 1415
				cineFrom = nil -- 1416
			end -- 1416
		end -- 1416
		cineFrame = frame -- 1418
		return applyObserve(frame) -- 1419
	end -- 1358
	--- 日心关卡按配置逐站取景，手动选择保持到回到自动。
	local function orbitalCamera(pos, t, wallDt) -- 1423
		local cfg = level.transfer.orbital -- 1424
		local autoShot = orbitalShotAt( -- 1425
			core.flightTime, -- 1425
			core.burnDuration, -- 1425
			core.flyby, -- 1425
			cfg, -- 1425
			core.dt -- 1425
		) -- 1425
		if level.levelId == 3 and core.missionCompleted then -- 1425
			autoShot = core.flightTime - core.goalIndex * core.dt < 2 and "Cruise" or "Overview" -- 1426
		end -- 1426
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1427
		local key = (focusMode .. ":") .. shot -- 1428
		local velocity = core.flight.velocities[____exports.coreProbeIndex(core) + 1] -- 1429
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1430
		local pts = {pos} -- 1431
		local radii = {deps.scene.probeRadius} -- 1431
		local az = math.atan(core.flight.velocities[1].x, core.flight.velocities[1].y) * 180 / math.pi + 100 -- 1432
		local targetFlybyMission = cfg.targetFlyby ~= nil -- 1433
		local encounterSpecs = {table.unpack(cfg.encounters)} -- 1434
		if cfg.targetFlyby ~= nil then -- 1434
			encounterSpecs[#encounterSpecs + 1] = cfg.targetFlyby -- 1435
		end -- 1435
		local tilt = 28 -- 1436
		local minDist = targetFlybyMission and 40 or 130 -- 1436
		if shot == "Cruise" then -- 1436
			az = cruiseAzFor(velocity, wallDt) -- 1438
			pts[#pts + 1] = {x = pos.x + (speed > 0 and velocity.x * 24 / speed or 0), y = pos.y + (speed > 0 and velocity.y * 24 / speed or 0)} -- 1439
			radii[#radii + 1] = 0 -- 1440
			tilt = 35 -- 1440
			minDist = targetFlybyMission and 65 or 100 -- 1440
		elseif shot == "Overview" then -- 1440
			pts[#pts + 1] = bodyPositionAt(level.bodies[1], t) -- 1442
			radii[#radii + 1] = level.bodies[1].radius -- 1442
			for ____, e in ipairs(encounterSpecs) do -- 1443
				pts[#pts + 1] = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1443
				radii[#radii + 1] = level.bodies[e.planetIndex + 1].radius -- 1443
			end -- 1443
			az = math.atan(pos.x, pos.y) * 180 / math.pi -- 1444
			tilt = 60 -- 1444
			minDist = 300 -- 1444
		elseif shot == "Sun" then -- 1444
			pts = {bodyPositionAt(level.bodies[1], t)} -- 1446
			radii = {level.bodies[1].radius} -- 1446
			tilt = 42 -- 1446
			minDist = 200 -- 1446
		elseif shot ~= "Launch" then -- 1446
			do -- 1446
				local i = 0 -- 1448
				while i < #encounterSpecs do -- 1448
					do -- 1448
						local e = encounterSpecs[i + 1] -- 1449
						if e.focus ~= shot then -- 1449
							goto __continue201 -- 1450
						end -- 1450
						local bp = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1451
						pts = focusMode == "Auto" and ({pos, bp}) or ({bp}) -- 1452
						radii = focusMode == "Auto" and ({deps.scene.probeRadius, level.bodies[e.planetIndex + 1].radius}) or ({level.bodies[e.planetIndex + 1].radius}) -- 1453
						local ____temp_8 -- 1454
						if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 1454
							____temp_8 = i < #cfg.encounters and core.flyby.encounters[i + 1] or core.flyby.destination -- 1454
						else -- 1454
							____temp_8 = nil -- 1454
						end -- 1454
						local stage = ____temp_8 -- 1454
						local at = stage ~= nil and stage.entryIndex >= 0 and stage.entryIndex or 0 -- 1455
						local near = bodyPositionAt(level.bodies[e.planetIndex + 1], core.t0 + at * core.dt) -- 1456
						local probe = core.flight.points[at + 1] -- 1456
						az = math.atan(probe.x - near.x, probe.y - near.y) * 180 / math.pi + 90 -- 1457
						tilt = 45 -- 1458
						minDist = targetFlybyMission and (focusMode == "Auto" and 80 or level.bodies[e.planetIndex + 1].radius * 6) or 180 -- 1458
						break -- 1458
					end -- 1458
					::__continue201:: -- 1458
					i = i + 1 -- 1448
				end -- 1448
			end -- 1448
		end -- 1448
		if key ~= cineKey then -- 1448
			cineFrom = cineFrame -- 1462
			cineTransition = 0 -- 1462
			if cineKey == "" or shot == "Launch" then -- 1462
				cineFrom = nil -- 1463
			end -- 1463
			cineKey = key -- 1464
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1465
		end -- 1465
		local want = deps.rig.step( -- 1467
			pts, -- 1467
			deps.scene.probeRadius, -- 1467
			radii, -- 1467
			minDist, -- 1467
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1467
		) -- 1467
		local frame = want -- 1468
		if cineFrom ~= nil then -- 1468
			cineTransition = cineTransition + wallDt -- 1470
			local u = math.min(1, cineTransition / 0.6) -- 1471
			local k = u * u * (3 - 2 * u) -- 1471
			frame = { -- 1472
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1472
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1473
			} -- 1473
			if u >= 1 then -- 1473
				cineFrom = nil -- 1474
			end -- 1474
		end -- 1474
		cineFrame = frame -- 1476
		return applyObserve(frame) -- 1477
	end -- 1423
	local function resetCinematic() -- 1480
		markerElapsed = -1 -- 1481
		focusMode = "Auto" -- 1482
		cineKey = "" -- 1482
		cineFrame = nil -- 1482
		cineFrom = nil -- 1482
		obsYawDeg = 0 -- 1483
		obsPitchDeg = 0 -- 1483
		obsZoom = 1 -- 1483
		cruiseAzimuthReady = false -- 1484
		flybySounded = {} -- 1485
	end -- 1480
	local function updateAiming(dt) -- 1488
		if deps.plan.setBurn ~= nil then -- 1488
			deps.plan:setBurn(core.aim.velocity, false) -- 1489
		end -- 1489
		deps.aim:setEnabled(true) -- 1490
		local dragging = deps.aim:isDragging() -- 1492
		local clockFrozen = dragging or core.phase == "Armed" or transferCinematic(level.transfer) and introTourActive -- 1497
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1497
			local rate = core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1508
			clock = clock + dt * rate -- 1509
			orbitClock = orbitClock + dt * rate -- 1510
		end -- 1510
		local tNow = core.t0 + clock -- 1512
		local idleState = idleProbeAt(tNow) -- 1514
		probePos = idleState.pos -- 1515
		probeVel = idleState.vel -- 1516
		deps.scene.syncBodies(tNow) -- 1518
		if deps.scene.syncStars ~= nil then -- 1518
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1519
		end -- 1519
		deps.scene.syncProbe(probePos) -- 1520
		if idleOrbit ~= nil then -- 1520
			deps.scene.faceVelocity(probeVel) -- 1521
		end -- 1521
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1523
		deps.plan:syncProbe(probePos, probeVel) -- 1524
		if not aimed and #core.stars > 0 then -- 1524
			deps.plan:setStars( -- 1526
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1526
				core.collectedStars -- 1526
			) -- 1526
		end -- 1526
		local fr = framingPoints(probePos, tNow) -- 1530
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1531
		if frameLogged < 6 then -- 1531
			frameLogged = frameLogged + 1 -- 1535
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1536
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1540
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1541
				__TS__ArrayMap( -- 1547
					fr.pts, -- 1547
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1547
				), -- 1547
				" " -- 1547
			)) .. "]") -- 1547
		end -- 1547
		if introTourActive and introTourT < tourDuration then -- 1547
			introTourT = introTourT + dt -- 1551
			local k = introTourT / tourDuration -- 1552
			if k >= 1 then -- 1552
				finishIntroTour() -- 1554
			else -- 1554
				if k >= 0.95 and not introLogged then -- 1554
					introLogged = true -- 1557
					print("[escape-velocity] intro camera finishing") -- 1558
				end -- 1558
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1558
					local elapsed = introTourT -- 1562
					local segIndex = 0 -- 1563
					local segStart = 0 -- 1564
					do -- 1564
						local s = 0 -- 1565
						while s < #tourDef.segments do -- 1565
							local seg = tourDef.segments[s + 1] -- 1566
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1566
								segIndex = s -- 1568
								break -- 1569
							end -- 1569
							elapsed = elapsed - seg.duration -- 1571
							segStart = segStart + seg.duration -- 1572
							s = s + 1 -- 1565
						end -- 1565
					end -- 1565
					local curSeg = tourDef.segments[segIndex + 1] -- 1574
					local segK = math.max( -- 1575
						0, -- 1575
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1575
					) -- 1575
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1577
					deps.aim:setIntroTourBannerVisible(true) -- 1578
					local pwProbe = planeToWorld(probePos, 0) -- 1580
					local function getTargetPosAndDist(targetIdx, userDist) -- 1581
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1581
							local b = level.bodies[targetIdx + 1] -- 1583
							local isMicro = b.orbitRadius < 2 -- 1584
							local p = planeToWorld( -- 1585
								bodyPositionAt(b, tNow), -- 1585
								0 -- 1585
							) -- 1585
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1586
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1587
						end -- 1587
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1589
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1590
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1591
					end -- 1581
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1594
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1595
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1596
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1598
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1599
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1600
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1601
					if segIndex == 0 then -- 1601
						local az = curAz + segK * (18 * math.pi / 180) -- 1605
						local tilt = curTilt -- 1606
						local d = curKey.dist -- 1607
						local eye = Vec3( -- 1608
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1609
							curKey.pos.y + math.sin(tilt) * d, -- 1610
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1611
						) -- 1611
						frame = {target = curKey.pos, eye = eye} -- 1613
					else -- 1613
						local ease = segK * segK * (3 - 2 * segK) -- 1616
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1617
						local az = prevAz + (curAz - prevAz) * ease -- 1622
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1623
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1624
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1625
						local eye = Vec3( -- 1626
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1627
							target.y + math.sin(tilt) * d, -- 1628
							target.z + math.cos(az) * math.cos(tilt) * d -- 1629
						) -- 1629
						frame = {target = target, eye = eye} -- 1631
					end -- 1631
				else -- 1631
					local targetBody = nil -- 1634
					local wps = goalWaypoints(level.goal) -- 1635
					if #wps > 0 then -- 1635
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1637
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1637
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1639
					end -- 1639
					if targetBody == nil and #level.bodies > 0 then -- 1639
						targetBody = level.bodies[#level.bodies] -- 1642
					end -- 1642
					if targetBody ~= nil then -- 1642
						local pwTarget = planeToWorld( -- 1646
							bodyPositionAt(targetBody, tNow), -- 1646
							0 -- 1646
						) -- 1646
						local pwProbe = planeToWorld(probePos, 0) -- 1647
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1648
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1649
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1650
						if k < 0.35 then -- 1650
							local e1 = k / 0.35 -- 1653
							local az = (0.2 + e1 * 0.15) * math.pi -- 1654
							local tilt = 0.35 * math.pi -- 1655
							local eye = Vec3( -- 1656
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1657
								pwTarget.y + math.sin(tilt) * distTarget, -- 1658
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1659
							) -- 1659
							frame = {target = pwTarget, eye = eye} -- 1661
						elseif k < 0.72 then -- 1661
							local e2 = (k - 0.35) / 0.37 -- 1663
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1664
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1665
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1666
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1667
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1668
							local eye = Vec3( -- 1673
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1674
								targetCenter.y + curDist * 0.8, -- 1675
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1676
							) -- 1676
							frame = {target = targetCenter, eye = eye} -- 1678
						else -- 1678
							local e3 = (k - 0.72) / 0.28 -- 1680
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1681
							local az = 0.25 * math.pi -- 1682
							local tilt = 0.36 * math.pi -- 1683
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1684
							local eye = Vec3( -- 1685
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1686
								pwProbe.y + math.sin(tilt) * curDist, -- 1687
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1688
							) -- 1688
							frame = {target = pwProbe, eye = eye} -- 1690
						end -- 1690
					end -- 1690
				end -- 1690
			end -- 1690
		end -- 1690
		frame = applyObserve(frame) -- 1697
		deps.rig.apply(deps.camera, frame) -- 1698
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1699
		local basis = makeBasis(frame) -- 1700
		if core.viewMode == "2D" then -- 1700
			local sp = deps.plan:probeScreen() -- 1706
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1707
		else -- 1707
			local pp = projectPrepared( -- 1709
				planeToWorld(probePos, 0), -- 1709
				basis -- 1709
			) -- 1709
			if pp ~= nil then -- 1709
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1710
			end -- 1710
		end -- 1710
		if not aimed then -- 1710
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1710
				deps.aim:setTransferInfo( -- 1720
					distance( -- 1720
						probePos, -- 1720
						bodyPositionAt(level.bodies[1], tNow) -- 1720
					) - level.bodies[1].radius, -- 1720
					0 -- 1720
				) -- 1720
			end -- 1720
			deps.trajectory:clearPrediction() -- 1724
			deps.plan:clearPrediction() -- 1725
			predForce = true -- 1726
		else -- 1726
			local aimKey = (__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4) -- 1732
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1733
			predAccum = predAccum + dt -- 1734
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1735
			if needIt then -- 1735
				predForce = false -- 1737
				predAccum = 0 -- 1738
				predAimKey = aimKey -- 1739
				predPosKey = posKey -- 1740
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel) -- 1743
				local predictSample = level.transfer ~= nil and 1 or 4 -- 1744
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion}, level.bodies, { -- 1745
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1748
					dt = core.dt, -- 1748
					sampleEvery = predictSample, -- 1748
					escapeRadius = level.escapeRadius, -- 1748
					t0 = tNow -- 1748
				}) -- 1748
				predPoints = sim.points -- 1750
				if level.transfer ~= nil then -- 1750
					local analysis = analyzeTransfer( -- 1752
						sim, -- 1752
						level.bodies, -- 1752
						level.goal.planetIndex, -- 1752
						level.transfer, -- 1752
						core.dt * predictSample, -- 1752
						tNow -- 1752
					) -- 1752
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1753
						sim.points, -- 1753
						level.bodies, -- 1753
						level.goal, -- 1753
						core.dt * predictSample, -- 1753
						tNow, -- 1753
						sim.velocities -- 1753
					) -- 1753
					if analysis ~= nil then -- 1753
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1754
					elseif gi >= 0 then -- 1754
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1755
					end -- 1755
					local radius = distance( -- 1756
						probePos, -- 1756
						bodyPositionAt(level.bodies[1], tNow) -- 1756
					) -- 1756
					local plan = planTransfer( -- 1757
						level.bodies[1].gm, -- 1757
						radius, -- 1757
						probeVel, -- 1757
						core.aim.power, -- 1757
						level.transfer.apoapsisMax, -- 1757
						level.transfer.mode, -- 1757
						level.transfer.periapsisMin -- 1757
					) -- 1757
					if deps.aim.setTransferInfo ~= nil then -- 1757
						deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1758
					end -- 1758
				end -- 1758
				predTimes = {} -- 1760
				do -- 1760
					local pi = 0 -- 1761
					while pi < #predPoints do -- 1761
						predTimes[#predTimes + 1] = tNow + pi * core.dt * predictSample -- 1761
						pi = pi + 1 -- 1761
					end -- 1761
				end -- 1761
			end -- 1761
			deps.trajectory:setPrediction(predPoints, basis) -- 1763
			deps.plan:setPrediction(predPoints) -- 1765
			if #core.stars > 0 then -- 1765
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1768
				local stEval = evaluateCollectedStars( -- 1769
					predPoints, -- 1769
					core.stars, -- 1769
					30, -- 1769
					core.starOrbits, -- 1769
					predTimes -- 1769
				) -- 1769
				core.previewStarsCount = stEval.count -- 1770
				deps.plan:setStars(live, stEval.collected) -- 1771
			end -- 1771
		end -- 1771
		if idleOrbit ~= nil then -- 1771
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1776
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1777
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1778
		end -- 1778
		local rings = goalRingsAt(tNow) -- 1780
		deps.trajectory:setGoalRings(rings, basis) -- 1781
		deps.trajectory:clearTrail() -- 1782
		deps.plan:setGoalRings(rings) -- 1784
		deps.plan:clearTrail() -- 1785
		deps.plan:flush() -- 1786
	end -- 1488
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
	local function updateFinale() -- 1801
		deps.aim:setEnabled(false) -- 1802
		if core.flight == nil then -- 1802
			return -- 1803
		end -- 1803
		local idx = ____exports.coreProbeIndex(core) -- 1804
		local pos = core.flight.points[idx + 1] -- 1805
		local tWorld = core.t0 + core.flightTime -- 1806
		deps.scene.syncBodies(tWorld) -- 1809
		deps.scene.syncProbe(pos) -- 1810
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1811
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1814
		deps.camera:lookAt( -- 1815
			frame.eye, -- 1815
			frame.target, -- 1815
			Vec3(0, 1, 0) -- 1815
		) -- 1815
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1816
		local trail = {} -- 1819
		do -- 1819
			local i = 0 -- 1820
			while i <= idx do -- 1820
				trail[#trail + 1] = core.flight.points[i + 1] -- 1820
				i = i + 1 -- 1820
			end -- 1820
		end -- 1820
		local rings = goalRingsAt(tWorld, idx) -- 1821
		local basis = makeBasis(frame) -- 1822
		if deps.trajectory.setBurn ~= nil then -- 1822
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1824
		end -- 1824
		deps.trajectory:clearOrbitRing() -- 1825
		deps.plan:clearProbeOrbit() -- 1826
		deps.trajectory:setTrail(trail, basis) -- 1827
		deps.trajectory:setGoalRings(rings, basis) -- 1828
		deps.plan:clearPrediction() -- 1829
		deps.plan:setGoalRings(rings) -- 1830
		deps.plan:flush() -- 1831
	end -- 1801
	local function updateFlying(dt) -- 1833
		deps.aim:setEnabled(false) -- 1834
		local wasCompleted = core.missionCompleted -- 1837
		local oldBonusScore = core.bonusRockets -- 1838
		local entered = ____exports.coreUpdate(core, dt, level) -- 1839
		if not wasCompleted and core.missionCompleted then -- 1839
			markerElapsed = 0 -- 1841
			print("[escape-velocity] success marker triggered once") -- 1842
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1843
			if deps.onMissionCompleted ~= nil then -- 1843
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1844
			end -- 1844
		end -- 1844
		if core.bonusRockets > oldBonusScore and deps.onBonusCollected ~= nil and level.bonusPoints ~= nil then -- 1844
			do -- 1844
				local i = 0 -- 1847
				while i < #core.collectedBonus do -- 1847
					if core.collectedBonus[i + 1] and not reportedBonusIds[level.bonusPoints[i + 1].id] then -- 1847
						reportedBonusIds[level.bonusPoints[i + 1].id] = true -- 1848
						bonusEffectElapsed[i + 1] = 0 -- 1849
						deps:onBonusCollected(core.bonusRockets, level.bonusPoints[i + 1].id) -- 1850
					end -- 1850
					i = i + 1 -- 1847
				end -- 1847
			end -- 1847
		end -- 1847
		if core.flight == nil then -- 1847
			return entered -- 1853
		end -- 1853
		local idx = ____exports.coreProbeIndex(core) -- 1855
		local pos = core.flight.points[idx + 1] -- 1856
		local tWorld = core.t0 + core.flightTime -- 1860
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1860
			lastSlowmo = core.slowmo -- 1864
			lastSlowmoBody = core.slowmoBody -- 1865
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1866
			local nearD = near ~= nil and distance( -- 1867
				pos, -- 1867
				bodyPositionAt(near, tWorld) -- 1867
			) or 0 -- 1867
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1868
			if core.slowmo and core.slowmoBody >= 0 and not flybySounded[__TS__NumberToFixed(core.slowmoBody, 0)] then -- 1868
				flybySounded[__TS__NumberToFixed(core.slowmoBody, 0)] = true -- 1873
				if deps.onFlyby ~= nil then -- 1873
					deps:onFlyby(core.slowmoBody) -- 1874
				end -- 1874
			end -- 1874
		end -- 1874
		flightLogT = flightLogT + dt -- 1879
		if flightLogT >= 0.5 then -- 1879
			flightLogT = 0 -- 1881
			local total = (#core.flight.points - 1) * core.dt -- 1882
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1883
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1885
					core.flightTime, -- 1885
					core.burnDuration, -- 1885
					level.transfer, -- 1885
					core.flyby, -- 1885
					core.dt -- 1885
				) or (core.slowmo and SlowMoFactor or 1)), -- 1885
				2 -- 1885
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1885
		end -- 1885
		deps.scene.syncBodies(tWorld) -- 1889
		if deps.scene.syncStars ~= nil then -- 1889
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1890
		end -- 1890
		deps.scene.syncProbe(pos) -- 1891
		if idx > 0 then -- 1891
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1893
		end -- 1893
		do -- 1893
			local s = 0 -- 1897
			while s < #core.stars do -- 1897
				if not core.collectedStars[s + 1] then -- 1897
					local fromLevel = level.starOrbits -- 1899
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1900
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1901
					local dx = pos.x - stPos.x -- 1902
					local dy = pos.y - stPos.y -- 1903
					if dx * dx + dy * dy <= 30 * 30 then -- 1903
						core.collectedStars[s + 1] = true -- 1905
						if deps.scene.setStarCollected ~= nil then -- 1905
							deps.scene.setStarCollected(s) -- 1907
						end -- 1907
						deps.plan:setStars(core.stars, core.collectedStars) -- 1909
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1910
					end -- 1910
				end -- 1910
				s = s + 1 -- 1897
			end -- 1897
		end -- 1897
		local fr -- 1919
		local closeDist = nil -- 1920
		if core.slowmo and core.slowmoBody >= 0 then -- 1920
			local near = level.bodies[core.slowmoBody + 1] -- 1922
			local nearR = near.radius -- 1924
			do -- 1924
				local i = 0 -- 1925
				while i < #level.bodies do -- 1925
					local b = level.bodies[i + 1] -- 1926
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1926
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1926
							nearR = deps.visuals[i + 1].displayRadius -- 1928
						end -- 1928
						break -- 1929
					end -- 1929
					i = i + 1 -- 1925
				end -- 1925
			end -- 1925
			fr = { -- 1932
				pts = { -- 1932
					pos, -- 1932
					bodyPositionAt(near, tWorld) -- 1932
				}, -- 1932
				radii = {deps.scene.probeRadius, nearR} -- 1932
			} -- 1932
			closeDist = SlowMoCloseDist -- 1933
		else -- 1933
			fr = framingPoints(pos, tWorld) -- 1935
		end -- 1935
		local baseFrame = level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalCamera(pos, tWorld, dt) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist)) -- 1937
		local frame = level.transfer ~= nil and not transferCinematic(level.transfer) and applyObserve(baseFrame) or baseFrame -- 1938
		deps.rig.apply(deps.camera, frame) -- 1939
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1940
		local basis = makeBasis(frame) -- 1941
		if deps.trajectory.setBurn ~= nil then -- 1941
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1944
		end -- 1944
		if deps.plan.setBurn ~= nil then -- 1944
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1945
		end -- 1945
		local trail = {} -- 1946
		do -- 1946
			local i = 0 -- 1947
			while i <= idx do -- 1947
				trail[#trail + 1] = core.flight.points[i + 1] -- 1947
				i = i + 1 -- 1947
			end -- 1947
		end -- 1947
		local rings = goalRingsAt(tWorld, idx) -- 1948
		deps.trajectory:clearOrbitRing() -- 1950
		deps.plan:clearProbeOrbit() -- 1951
		deps.trajectory:setTrail(trail, basis) -- 1952
		deps.trajectory:setGoalRings(rings, basis) -- 1953
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1956
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1957
		deps.plan:setStars( -- 1958
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 1958
			core.collectedStars -- 1958
		) -- 1958
		deps.plan:setTrail(trail) -- 1959
		deps.plan:clearPrediction() -- 1960
		deps.plan:setGoalRings(rings) -- 1961
		deps.plan:flush() -- 1962
		return entered -- 1964
	end -- 1833
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1978
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1979
		core.t0 = next.t0 -- 1980
		clock = next.clock -- 1981
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1982
	end -- 1978
	local function finishFlight() -- 1985
		if core.result == nil then -- 1985
			return -- 1986
		end -- 1986
		local toFinale = deps.finale == true and core.result == "success" -- 1987
		if toFinale then -- 1987
			____exports.coreEnterFinale(core) -- 1988
		end -- 1988
		deps:onResult( -- 1989
			core.result, -- 1989
			____exports.calcFlightTelemetry(core, level) -- 1989
		) -- 1989
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1989
			local ____end = #core.flight.points - 1 -- 1991
			deps:onFinale({ -- 1992
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1992
				time = core.flightTime, -- 1992
				tWorld = core.t0 + core.flightTime -- 1992
			}) -- 1992
		end -- 1992
		deps:onPhase(toFinale and "Finale" or "Result") -- 1994
	end -- 1985
	local function update(dt) -- 1997
		if markerElapsed >= 0 and markerElapsed < 0.6 then -- 1997
			markerElapsed = math.min(0.6, markerElapsed + dt) -- 1998
		end -- 1998
		do -- 1998
			local i = 0 -- 1999
			while i < #bonusEffectElapsed do -- 1999
				if bonusEffectElapsed[i + 1] >= 0 and bonusEffectElapsed[i + 1] < 0.6 then -- 1999
					bonusEffectElapsed[i + 1] = math.min(0.6, bonusEffectElapsed[i + 1] + dt) -- 1999
				end -- 1999
				i = i + 1 -- 1999
			end -- 1999
		end -- 1999
		applyView() -- 2002
		if core.phase == "Aiming" or core.phase == "Armed" then -- 2002
			updateAiming(dt) -- 2004
		elseif core.phase == "Flying" then -- 2004
			local entered = updateFlying(dt) -- 2006
			if entered then -- 2006
				finishFlight() -- 2007
			end -- 2007
		elseif core.phase == "Finale" then -- 2007
			updateFinale() -- 2009
		elseif core.phase == "Result" and core.missionCompleted and level.transfer ~= nil then -- 2009
			local rings = goalRingsAt( -- 2012
				core.t0 + core.flightTime, -- 2012
				____exports.coreProbeIndex(core) -- 2012
			) -- 2012
			deps.plan:setGoalRings(rings) -- 2013
			deps.plan:flush() -- 2013
			if cineFrame ~= nil then -- 2013
				deps.trajectory:setGoalRings( -- 2014
					rings, -- 2014
					makeBasis(cineFrame) -- 2014
				) -- 2014
			end -- 2014
		end -- 2014
	end -- 1997
	return { -- 2019
		phase = function() return core.phase end, -- 2020
		speedPow = function() return speedPow end, -- 2021
		speedMinPow = function() return speedMinPow end, -- 2022
		speedMaxPow = function() return speedMaxPow end, -- 2023
		isPaused = function() return paused end, -- 2024
		speedRate = function() -- 2025
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 2025
				return core.playback * transferPlaybackRate( -- 2026
					core.flightTime, -- 2026
					core.burnDuration, -- 2026
					level.transfer, -- 2026
					core.flyby, -- 2026
					core.dt -- 2026
				) -- 2026
			end -- 2026
			return core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 2027
		end, -- 2025
		missionSeconds = function() -- 2029
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 2030
			return speedUnit > 0 and w / speedUnit or 0 -- 2031
		end, -- 2029
		speedUp = function() -- 2033
			local next = ____exports.shiftSpeedPow(speedPow, speedMinPow, speedMaxPow, 1) -- 2034
			if next == speedPow then -- 2034
				return -- 2035
			end -- 2035
			speedPow = next -- 2036
			paused = false -- 2037
			applySpeedRate() -- 2038
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2039
		end, -- 2033
		speedDown = function() -- 2041
			local next = ____exports.shiftSpeedPow(speedPow, speedMinPow, speedMaxPow, -1) -- 2042
			if next == speedPow then -- 2042
				return -- 2043
			end -- 2043
			speedPow = next -- 2044
			paused = false -- 2045
			applySpeedRate() -- 2046
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2047
		end, -- 2041
		togglePause = function() -- 2049
			paused = not paused -- 2050
			applySpeedRate() -- 2051
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 2052
		end, -- 2049
		result = function() return core.result end, -- 2054
		onAimDrag = function(____, a) -- 2055
			if introTourActive then -- 2055
				finishIntroTour() -- 2056
			end -- 2056
			core.aim = a -- 2057
			if level.transfer ~= nil then -- 2057
				local radius = distance( -- 2059
					probePos, -- 2059
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 2059
				) -- 2059
				local plan = planTransfer( -- 2060
					level.bodies[1].gm, -- 2060
					radius, -- 2060
					probeVel, -- 2060
					a.power, -- 2060
					level.transfer.apoapsisMax, -- 2060
					level.transfer.mode, -- 2060
					level.transfer.periapsisMin -- 2060
				) -- 2060
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 2061
				if deps.aim.setTransferInfo ~= nil then -- 2061
					deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 2062
				end -- 2062
			end -- 2062
			aimed = true -- 2064
		end, -- 2055
		aimReady = function() -- 2066
			predForce = true -- 2068
			if not ____exports.coreArm(core) then -- 2068
				return -- 2069
			end -- 2069
			if level.transfer ~= nil then -- 2069
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 2070
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 2070
					4 -- 2070
				)) -- 2070
			end -- 2070
			applyView() -- 2071
			deps:onPhase("Armed") -- 2072
		end, -- 2066
		cancelAim = function() -- 2074
			if not ____exports.coreCancelArm(core) then -- 2074
				return -- 2075
			end -- 2075
			aimed = false -- 2076
			predForce = true -- 2077
			deps.trajectory:clearPrediction() -- 2078
			deps.plan:clearPrediction() -- 2079
			applyView() -- 2080
			deps:onPhase("Aiming") -- 2081
			print("[escape-velocity] aim cancelled") -- 2082
		end, -- 2074
		launchArmed = function() -- 2084
			if core.phase ~= "Armed" then -- 2084
				return -- 2086
			end -- 2086
			resetCinematic() -- 2087
			applyFlightSpeed() -- 2088
			handoffDate(true) -- 2089
			reportedBonusIds = {} -- 2090
			bonusEffectElapsed = {} -- 2091
			do -- 2091
				local i = 0 -- 2092
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2092
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2092
					i = i + 1 -- 2092
				end -- 2092
			end -- 2092
			____exports.coreLaunch( -- 2093
				core, -- 2093
				core.aim.velocity, -- 2093
				level, -- 2093
				probePos, -- 2093
				probeVel -- 2093
			) -- 2093
			deps.trajectory:clearPrediction() -- 2094
			deps.plan:clearPrediction() -- 2095
			applyView() -- 2096
			deps:onPhase("Flying") -- 2097
		end, -- 2084
		armed = function() return core.phase == "Armed" end, -- 2099
		viewMode = function() return core.viewMode end, -- 2100
		toggleViewMode = function() -- 2101
			____exports.coreToggleView(core) -- 2103
			applyView() -- 2104
		end, -- 2101
		cameraFocus = function() return focusMode end, -- 2106
		flightStage = function() return level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalShotAt( -- 2107
			core.flightTime, -- 2107
			core.burnDuration, -- 2107
			core.flyby, -- 2107
			level.transfer.orbital, -- 2107
			core.dt -- 2107
		) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 2107
			core.flightTime, -- 2108
			core.burnDuration, -- 2108
			core.flyby, -- 2108
			level.transfer.flyby, -- 2108
			core.dt -- 2108
		) or nil) end, -- 2108
		cycleCameraFocus = function() -- 2109
			if not transferCinematic(level.transfer) or core.phase ~= "Flying" then -- 2109
				return -- 2110
			end -- 2110
			local ____temp_10 -- 2111
			if level.transfer ~= nil and level.transfer.orbital ~= nil then -- 2111
				local ____array_9 = __TS__SparseArrayNew( -- 2111
					"Auto", -- 2111
					"Probe", -- 2111
					table.unpack(__TS__ArrayMap( -- 2111
						level.transfer.orbital.encounters, -- 2111
						function(____, e) return e.focus end -- 2111
					)) -- 2111
				) -- 2111
				__TS__SparseArrayPush( -- 2111
					____array_9, -- 2111
					table.unpack(level.transfer.orbital.targetFlyby ~= nil and ({level.transfer.orbital.targetFlyby.focus}) or ({})) -- 2111
				) -- 2111
				__TS__SparseArrayPush(____array_9, "Sun", "Overview") -- 2111
				____temp_10 = {__TS__SparseArraySpread(____array_9)} -- 2111
			else -- 2111
				____temp_10 = nil -- 2111
			end -- 2111
			local modes = ____temp_10 -- 2111
			focusMode = nextCameraFocus(focusMode, modes) -- 2112
			obsYawDeg = 0 -- 2113
			obsPitchDeg = 0 -- 2113
			obsZoom = 1 -- 2113
			print("[escape-velocity] camera focus -> " .. focusMode) -- 2114
		end, -- 2109
		missionCompleted = function() return core.missionCompleted end, -- 2116
		markerElapsed = function() return markerElapsed end, -- 2117
		endViewing = function() -- 2118
			if not ____exports.coreEndViewing(core) then -- 2118
				return -- 2119
			end -- 2119
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 2120
			finishFlight() -- 2121
		end, -- 2118
		skipIntroTour = function() -- 2123
			finishIntroTour() -- 2124
		end, -- 2123
		isIntroTourActive = function() return introTourActive end, -- 2126
		observeDrag = function(____, dx, dy) -- 2127
			if introTourActive then -- 2127
				finishIntroTour() -- 2129
				return -- 2130
			end -- 2130
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2132
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2133
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2134
			if obsPitchDeg > 40 then -- 2134
				obsPitchDeg = 40 -- 2135
			end -- 2135
			if obsPitchDeg < -40 then -- 2135
				obsPitchDeg = -40 -- 2136
			end -- 2136
		end, -- 2127
		observeZoom = function(____, deltaDist) -- 2138
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2139
			if obsZoom < 0.4 then -- 2139
				obsZoom = 0.4 -- 2140
			end -- 2140
			if obsZoom > 1.8 then -- 2140
				obsZoom = 1.8 -- 2141
			end -- 2141
		end, -- 2138
		launch = function(____, v) -- 2143
			applyFlightSpeed() -- 2144
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2144
				return -- 2145
			end -- 2145
			resetCinematic() -- 2146
			handoffDate(true) -- 2147
			reportedBonusIds = {} -- 2148
			bonusEffectElapsed = {} -- 2149
			do -- 2149
				local i = 0 -- 2150
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2150
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2150
					i = i + 1 -- 2150
				end -- 2150
			end -- 2150
			____exports.coreLaunch( -- 2152
				core, -- 2152
				v, -- 2152
				level, -- 2152
				probePos, -- 2152
				probeVel -- 2152
			) -- 2152
			deps.trajectory:clearPrediction() -- 2153
			deps.plan:clearPrediction() -- 2154
			applyView() -- 2155
			deps:onPhase("Flying") -- 2156
		end, -- 2143
		retry = function() -- 2158
			resetCinematic() -- 2159
			handoffDate(false) -- 2160
			aimed = false -- 2161
			introTourActive = false -- 2162
			____exports.coreRetry(core, level.aimMin) -- 2163
			if deps.scene.resetStars ~= nil then -- 2163
				deps.scene.resetStars() -- 2165
			end -- 2165
			deps.plan:setStars(core.stars, core.collectedStars) -- 2167
			deps.trajectory:clearTrail() -- 2168
			deps.trajectory:clearPrediction() -- 2169
			deps.trajectory:clearGoalRings() -- 2170
			deps.plan:clearTrail() -- 2171
			deps.plan:clearPrediction() -- 2172
			deps.plan:clearGoalRings() -- 2173
			applyView() -- 2174
			deps:onPhase("Aiming") -- 2175
		end, -- 2158
		backToSelect = function() -- 2177
			if not ____exports.coreBackToSelect(core) then -- 2177
				return false -- 2178
			end -- 2178
			deps.aim:setEnabled(false) -- 2180
			deps.trajectory:clearTrail() -- 2181
			deps.trajectory:clearPrediction() -- 2182
			deps.trajectory:clearGoalRings() -- 2183
			deps.plan:clearTrail() -- 2184
			deps.plan:clearPrediction() -- 2185
			deps.plan:clearGoalRings() -- 2186
			applyView() -- 2187
			deps:onPhase("LevelSelect") -- 2188
			return true -- 2189
		end, -- 2177
		startLevel = function() -- 2191
			resetCinematic() -- 2192
			aimed = false -- 2193
			____exports.coreRetry(core, level.aimMin) -- 2194
			if deps.scene.resetStars ~= nil then -- 2194
				deps.scene.resetStars() -- 2196
			end -- 2196
			deps.plan:setStars(core.stars, core.collectedStars) -- 2198
			deps.rig.reset() -- 2199
			introTourActive = false -- 2201
			core.viewMode = "2D" -- 2202
			appliedMode = "" -- 2203
			applyView() -- 2204
			prepareIdle() -- 2205
			deps.trajectory:clearTrail() -- 2206
			deps.trajectory:clearPrediction() -- 2207
			deps.trajectory:clearGoalRings() -- 2208
			deps.plan:clearTrail() -- 2209
			deps.plan:clearPrediction() -- 2210
			deps.plan:clearGoalRings() -- 2211
			deps:onPhase("Aiming") -- 2212
		end, -- 2191
		stepTime = function(____, dir, span) -- 2214
			if not ____exports.coreTimeWarpAllowed(core) then -- 2214
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2218
				return -- 2219
			end -- 2219
			local span0 = span > 0 and span or 0 -- 2221
			clock = clock + dir * TimeWarpStep -- 2222
			if clock < 0 then -- 2222
				clock = 0 -- 2223
			end -- 2223
			if span0 > 0 and clock > span0 then -- 2223
				clock = span0 -- 2224
			end -- 2224
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2226
		end, -- 2214
		dateNow = function() return core.t0 + clock end, -- 2228
		setPlaybackSpeed = function(____, speed) -- 2229
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2229
				return -- 2231
			end -- 2231
			core.playback = speed -- 2232
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2233
		end, -- 2229
		playbackSpeed = function() return core.playback end, -- 2235
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2236
		starsNow = function() -- 2237
			if core.phase == "Flying" or core.phase == "Result" then -- 2237
				local n = 0 -- 2239
				do -- 2239
					local i = 0 -- 2240
					while i < #core.collectedStars do -- 2240
						if core.collectedStars[i + 1] then -- 2240
							n = n + 1 -- 2240
						end -- 2240
						i = i + 1 -- 2240
					end -- 2240
				end -- 2240
				return n -- 2241
			end -- 2241
			return core.previewStarsCount -- 2243
		end, -- 2237
		bonusScore = function() return core.bonusRockets end, -- 2245
		bonusTotal = function() return level.bonusPoints ~= nil and #level.bonusPoints or 0 end, -- 2246
		update = function(____, frameDt) return update(frameDt) end -- 2248
	} -- 2248
end -- 938
return ____exports -- 938
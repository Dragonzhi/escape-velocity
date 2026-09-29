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
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 224
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 225
	local n = math.floor(pow) -- 226
	while n > 0 do -- 226
		rate = rate * 10 -- 228
		n = n - 1 -- 229
	end -- 229
	while n < 0 do -- 229
		rate = rate / 10 -- 232
		n = n + 1 -- 233
	end -- 233
	return rate -- 235
end -- 224
local function neutralAim(minSpeed) -- 238
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 239
end -- 238
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 243
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 244
end -- 243
--- 星尘在时刻 t 的位置（没有轨道就用静态坐标）。
local function starPositionsNow(orbits, fallback, t) -- 248
	local out = {} -- 249
	do -- 249
		local i = 0 -- 250
		while i < #fallback do -- 250
			local orbit = i < #orbits and orbits[i + 1] or nil -- 251
			out[#out + 1] = starPositionAt(orbit, fallback[i + 1], t) -- 252
			i = i + 1 -- 250
		end -- 250
	end -- 250
	return out -- 254
end -- 248
function ____exports.createCore(dt, stars, starOrbits) -- 257
	local stList = stars ~= nil and stars or ({}) -- 258
	local colList = {} -- 259
	do -- 259
		local i = 0 -- 260
		while i < #stList do -- 260
			colList[#colList + 1] = false -- 260
			i = i + 1 -- 260
		end -- 260
	end -- 260
	local orbits = starOrbits ~= nil and starOrbits or ({}) -- 261
	return { -- 262
		phase = "Aiming", -- 263
		aim = neutralAim(AimMinSpeed), -- 264
		flight = nil, -- 265
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 266
		burnDuration = 0, -- 267
		t0 = 0, -- 268
		flightTime = 0, -- 269
		missionCompleted = false, -- 270
		flyby = nil, -- 271
		goalIndex = -1, -- 272
		result = nil, -- 273
		viewMode = "2D", -- 275
		playback = FlightPlayback, -- 277
		slowmo = false, -- 278
		slowmoBody = -1, -- 279
		stars = stList, -- 280
		starOrbits = orbits, -- 281
		collectedStars = colList, -- 282
		collectedBonus = {}, -- 283
		bonusRockets = 0, -- 284
		previewStarsCount = 0 -- 285
	} -- 285
end -- 257
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 297
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 298
	return core.viewMode -- 299
end -- 297
--- 教学关显式指定中心宿主；旧关卡仍按最近的有引力天体选择。
function ____exports.selectIdleHost(bodies, start, preferred) -- 303
	if preferred ~= nil and bodies[preferred + 1] ~= nil and bodies[preferred + 1].gm > 0 then -- 303
		return preferred -- 304
	end -- 304
	local index = -1 -- 305
	local nearest = 1000000000 -- 306
	do -- 306
		local i = 0 -- 307
		while i < #bodies do -- 307
			do -- 307
				if bodies[i + 1].gm <= 0 then -- 307
					goto __continue22 -- 308
				end -- 308
				local d = distance( -- 309
					bodyPositionAt(bodies[i + 1], 0), -- 309
					start -- 309
				) -- 309
				if d < nearest then -- 309
					nearest = d -- 310
					index = i -- 310
				end -- 310
			end -- 310
			::__continue22:: -- 310
			i = i + 1 -- 307
		end -- 307
	end -- 307
	return index -- 312
end -- 303
--- 预测线与瞬时点火的初始速度。教学关实际发射另行积分有限燃烧。
function ____exports.burnToMotion(burn, probeVel0) -- 316
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 317
	return {x = v0.x + burn.x, y = v0.y + burn.y} -- 318
end -- 316
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 327
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 327
		return -- 329
	end -- 329
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 330
	local motion = ____exports.burnToMotion(burn, base) -- 331
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 332
	core.burnDuration = level.transfer ~= nil and mag / level.transfer.thrustAcceleration or 0 -- 333
	local thrust = core.burnDuration > 0 and ({acceleration = {x = burn.x / core.burnDuration, y = burn.y / core.burnDuration}, duration = core.burnDuration}) or nil -- 334
	local p0 = from ~= nil and from or level.probeStart -- 335
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = level.transfer ~= nil and base ~= nil and base or motion}, level.bodies, { -- 336
		steps = level.maxSteps, -- 339
		dt = core.dt, -- 339
		sampleEvery = 1, -- 339
		escapeRadius = level.escapeRadius, -- 339
		t0 = core.t0, -- 339
		initialBurn = thrust -- 339
	}) -- 339
	core.flight = flight -- 341
	core.missionCompleted = false -- 342
	local ____core_1 = core -- 343
	local ____temp_0 -- 343
	if level.transfer ~= nil then -- 343
		____temp_0 = analyzeTransfer( -- 343
			flight, -- 343
			level.bodies, -- 343
			level.goal.planetIndex, -- 343
			level.transfer, -- 343
			core.dt, -- 343
			core.t0 -- 343
		) -- 343
	else -- 343
		____temp_0 = nil -- 343
	end -- 343
	____core_1.flyby = ____temp_0 -- 343
	core.goalIndex = findGoalIndex( -- 344
		flight.points, -- 344
		level.bodies, -- 344
		level.goal, -- 344
		core.dt, -- 344
		core.t0, -- 344
		flight.velocities -- 344
	) -- 344
	core.result = core.goalIndex >= 0 and "success" or (flight.outcome == "crashed" and "crashed" or "missed") -- 345
	core.collectedBonus = {} -- 346
	core.bonusRockets = 0 -- 347
	do -- 347
		local i = 0 -- 348
		while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 348
			local ____core_collectedBonus_2 = core.collectedBonus -- 348
			____core_collectedBonus_2[#____core_collectedBonus_2 + 1] = false -- 348
			i = i + 1 -- 348
		end -- 348
	end -- 348
	if core.flyby ~= nil then -- 348
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 349
	end -- 349
	if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 349
		for ____, e in ipairs(core.flyby.encounters) do -- 352
			print((((((((("[escape-velocity] encounter body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " energy=") .. __TS__NumberToFixed(e.energyChange, 2)) .. " work=") .. __TS__NumberToFixed(e.work, 2)) .. " passed=") .. (e.passed and "1" or "0")) -- 352
		end -- 352
	end -- 352
	if core.flyby ~= nil and core.flyby.destination ~= nil then -- 352
		local e = core.flyby.destination -- 354
		print((((((((("[escape-velocity] destination body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " entry=") .. __TS__NumberToFixed(e.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(e.exitIndex, 0)) .. " passed=") .. (e.passed and "1" or "0")) -- 355
	end -- 355
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.x, 5)) .. ",") .. __TS__NumberToFixed(motion.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. (core.result ~= nil and core.result or "pending")) -- 359
	core.flightTime = 0 -- 364
	core.slowmo = false -- 366
	core.slowmoBody = -1 -- 367
	core.phase = "Flying" -- 368
	core.viewMode = "3D" -- 370
end -- 327
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 379
	if core.phase ~= "Aiming" then -- 379
		return false -- 380
	end -- 380
	core.phase = "Armed" -- 381
	return true -- 382
end -- 379
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 386
	if core.phase ~= "Armed" then -- 386
		return false -- 387
	end -- 387
	core.phase = "Aiming" -- 388
	return true -- 389
end -- 386
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 403
	return core.phase == "Aiming" or core.phase == "Armed" -- 404
end -- 403
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 420
	if toT0 then -- 420
		return {t0 = clock, clock = 0} -- 421
	end -- 421
	return {t0 = 0, clock = t0} -- 422
end -- 420
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 434
	local host = -1 -- 444
	do -- 444
		local i = 0 -- 445
		while i < #bodies do -- 445
			do -- 445
				local b = bodies[i + 1] -- 446
				local isHost = false -- 447
				do -- 447
					local j = 0 -- 448
					while j < #bodies do -- 448
						do -- 448
							local h = bodies[j + 1].host -- 449
							if h == nil then -- 449
								goto __continue46 -- 450
							end -- 450
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 450
								isHost = true -- 451
								break -- 451
							end -- 451
						end -- 451
						::__continue46:: -- 451
						j = j + 1 -- 448
					end -- 448
				end -- 448
				if not isHost then -- 448
					goto __continue44 -- 453
				end -- 453
				if host < 0 or b.gm > bodies[host + 1].gm then -- 453
					host = i -- 454
				end -- 454
			end -- 454
			::__continue44:: -- 454
			i = i + 1 -- 445
		end -- 445
	end -- 445
	if host >= 0 then -- 445
		return host -- 456
	end -- 456
	local best = -1 -- 458
	do -- 458
		local i = 0 -- 459
		while i < #bodies do -- 459
			do -- 459
				local b = bodies[i + 1] -- 460
				if b.orbitRadius ~= 0 then -- 460
					goto __continue53 -- 461
				end -- 461
				if best < 0 or b.gm > bodies[best + 1].gm then -- 461
					best = i -- 462
				end -- 462
			end -- 462
			::__continue53:: -- 462
			i = i + 1 -- 459
		end -- 459
	end -- 459
	return best -- 464
end -- 434
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 482
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 483
	local best = -1 -- 484
	local bestD = 1000000000 -- 485
	do -- 485
		local i = 0 -- 486
		while i < #bodies do -- 486
			do -- 486
				if i == anchor then -- 486
					goto __continue58 -- 487
				end -- 487
				local b = bodies[i + 1] -- 488
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 489
				local d = distance( -- 490
					probe, -- 490
					bodyPositionAt(b, t) -- 490
				) -- 490
				if d < threshold and d < bestD then -- 490
					bestD = d -- 492
					best = i -- 493
				end -- 493
			end -- 493
			::__continue58:: -- 493
			i = i + 1 -- 486
		end -- 486
	end -- 486
	return best -- 496
end -- 482
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 500
	if core.flight == nil then -- 500
		return 0 -- 501
	end -- 501
	local idx = math.floor(core.flightTime / core.dt) -- 502
	local last = #core.flight.points - 1 -- 503
	if idx > last then -- 503
		idx = last -- 504
	end -- 504
	if idx < 0 then -- 504
		idx = 0 -- 505
	end -- 505
	return idx -- 506
end -- 500
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
function ____exports.coreUpdate(core, dt, level) -- 523
	if core.phase ~= "Flying" or core.flight == nil then -- 523
		return false -- 524
	end -- 524
	local previousIndex = ____exports.coreProbeIndex(core) -- 525
	if level ~= nil and level.transfer == nil then -- 525
		local idx = ____exports.coreProbeIndex(core) -- 529
		core.slowmoBody = ____exports.slowMotionBody( -- 530
			level.bodies, -- 530
			core.flight.points[idx + 1], -- 530
			core.t0 + core.flightTime, -- 530
			____exports.anchorBodyIndex(level.bodies), -- 530
			level.slowMoFloor -- 530
		) -- 530
		core.slowmo = core.slowmoBody >= 0 -- 531
	end -- 531
	if level ~= nil and level.transfer ~= nil then -- 531
		core.flightTime = advanceTransferPlayback( -- 535
			core.flightTime, -- 535
			dt, -- 535
			core.playback, -- 535
			core.burnDuration, -- 535
			level.transfer, -- 535
			core.flyby, -- 535
			core.dt -- 535
		) -- 535
	else -- 535
		core.flightTime = core.flightTime + dt * core.playback * (core.slowmo and SlowMoFactor or 1) -- 537
	end -- 537
	if not core.missionCompleted and core.goalIndex >= 0 and ____exports.coreProbeIndex(core) >= core.goalIndex then -- 537
		core.missionCompleted = true -- 540
		core.result = "success" -- 541
	end -- 541
	if level ~= nil and level.bonusPoints ~= nil and core.flight ~= nil then -- 541
		local ____end = ____exports.coreProbeIndex(core) -- 544
		local start = math.max(0, previousIndex) -- 545
		do -- 545
			local i = 0 -- 546
			while i < #level.bonusPoints do -- 546
				do -- 546
					if not core.collectedBonus[i + 1] then -- 546
						local point = level.bonusPoints[i + 1] -- 547
						local body = point.bodyIndex ~= nil and level.bodies[point.bodyIndex + 1] or point.orbit -- 548
						if body == nil then -- 548
							goto __continue73 -- 549
						end -- 549
						do -- 549
							local k = start -- 550
							while k <= ____end and k < #core.flight.points do -- 550
								local target = point.position ~= nil and point.position or goalPositionAt(body, core.t0 + k * core.dt, point.offset) -- 551
								if distance(core.flight.points[k + 1], target) <= point.tolerance then -- 551
									core.collectedBonus[i + 1] = true -- 553
									core.bonusRockets = core.bonusRockets + 1 -- 554
									break -- 555
								end -- 555
								k = k + 1 -- 550
							end -- 550
						end -- 550
					end -- 550
				end -- 550
				::__continue73:: -- 550
				i = i + 1 -- 546
			end -- 546
		end -- 546
	end -- 546
	if core.stars ~= nil and #core.stars > 0 then -- 546
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 563
		do -- 563
			local s = 0 -- 564
			while s < #core.stars do -- 564
				if not core.collectedStars[s + 1] then -- 564
					local orbit = s < #core.starOrbits and core.starOrbits[s + 1] or nil -- 566
					local stPos = starPositionAt(orbit, core.stars[s + 1], core.t0 + core.flightTime) -- 567
					local dx = curPos.x - stPos.x -- 568
					local dy = curPos.y - stPos.y -- 569
					if dx * dx + dy * dy <= 30 * 30 then -- 569
						core.collectedStars[s + 1] = true -- 571
					end -- 571
				end -- 571
				s = s + 1 -- 564
			end -- 564
		end -- 564
	end -- 564
	local naturalEnd = #core.flight.points - 1 -- 577
	local viewingSteps = level ~= nil and level.viewingSeconds ~= nil and math.floor(level.viewingSeconds / core.dt) or 0 -- 578
	local endIdx = core.goalIndex >= 0 and math.min(naturalEnd, core.goalIndex + viewingSteps) or naturalEnd -- 579
	if core.goalIndex >= 0 and level ~= nil and level.levelId == 1 and core.flyby ~= nil and core.flyby.viewEndIndex > core.goalIndex then -- 579
		endIdx = math.min(endIdx, core.flyby.viewEndIndex) -- 580
	end -- 580
	local ____temp_5 = core.goalIndex >= 0 and level ~= nil and level.levelId == 2 -- 581
	if ____temp_5 then -- 581
		local ____opt_3 = core.flyby -- 581
		____temp_5 = (____opt_3 and ____opt_3.destination) ~= nil -- 581
	end -- 581
	if ____temp_5 and core.flyby.destination.exitIndex >= core.goalIndex and core.flyby.destination.exitIndex < naturalEnd then -- 581
		endIdx = math.min( -- 582
			endIdx, -- 582
			core.flyby.destination.exitIndex + math.floor(6 / core.dt) -- 582
		) -- 582
	end -- 582
	if ____exports.coreProbeIndex(core) >= endIdx then -- 582
		core.flightTime = endIdx * core.dt -- 586
		core.phase = "Result" -- 587
		return true -- 588
	end -- 588
	return false -- 590
end -- 523
--- 已完成的教学关可提前结束观赏，不能用该操作跳过掠月判定。
function ____exports.coreEndViewing(core) -- 594
	if core.phase ~= "Flying" or not core.missionCompleted then -- 594
		return false -- 595
	end -- 595
	core.flightTime = ____exports.coreProbeIndex(core) * core.dt -- 596
	core.phase = "Result" -- 597
	return true -- 598
end -- 594
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 604
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 608
	local maxSpeed = 0 -- 609
	local closestDist = 1000000000 -- 610
	local eccentricity = nil -- 611
	if core.flight ~= nil then -- 611
		local pts = core.flight.points -- 614
		local vels = core.flight.velocities -- 615
		local ____end = ____exports.coreProbeIndex(core) -- 616
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 617
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 618
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 619
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 620
		do -- 620
			local k = 0 -- 622
			while k <= ____end and k < #pts do -- 622
				local p = pts[k + 1] -- 623
				if vels ~= nil and k < #vels then -- 623
					local v = vels[k + 1] -- 625
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 626
					if spd > maxSpeed then -- 626
						maxSpeed = spd -- 627
					end -- 627
				end -- 627
				if distTargetBody ~= nil then -- 627
					local t = core.t0 + k * core.dt -- 630
					local tp = bodyPositionAt(distTargetBody, t) -- 631
					local d = distance(p, tp) -- 632
					if d < closestDist then -- 632
						closestDist = d -- 633
					end -- 633
				end -- 633
				k = k + 1 -- 622
			end -- 622
		end -- 622
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 622
			local tEnd = core.t0 + ____end * core.dt -- 638
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 639
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 640
			local rx = pts[____end + 1].x - tpEnd.x -- 641
			local ry = pts[____end + 1].y - tpEnd.y -- 642
			local vx = vels[____end + 1].x - tvEnd.x -- 643
			local vy = vels[____end + 1].y - tvEnd.y -- 644
			local r = math.sqrt(rx * rx + ry * ry) -- 645
			local v2 = vx * vx + vy * vy -- 646
			local mu = goalBody.gm -- 647
			if r > 0 and mu > 0 then -- 647
				local energy = v2 / 2 - mu / r -- 649
				local h = rx * vy - ry * vx -- 650
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 651
				if term >= 0 then -- 651
					eccentricity = math.sqrt(term) -- 653
				end -- 653
			end -- 653
		end -- 653
	end -- 653
	local starsCollectedCount = 0 -- 659
	do -- 659
		local i = 0 -- 660
		while i < #core.collectedStars do -- 660
			if core.collectedStars[i + 1] then -- 660
				starsCollectedCount = starsCollectedCount + 1 -- 661
			end -- 661
			i = i + 1 -- 660
		end -- 660
	end -- 660
	return { -- 664
		burnDv = burnDv, -- 665
		flightTime = core.flightTime, -- 666
		closestDist = closestDist < 100000000 and closestDist or 0, -- 667
		maxSpeed = maxSpeed, -- 668
		eccentricity = eccentricity, -- 669
		starsCollected = starsCollectedCount, -- 670
		bonusRockets = core.bonusRockets -- 671
	} -- 671
end -- 604
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 676
	core.phase = "Aiming" -- 677
	core.viewMode = "2D" -- 679
	core.flight = nil -- 680
	core.flightTime = 0 -- 681
	core.missionCompleted = false -- 682
	core.flyby = nil -- 683
	core.goalIndex = -1 -- 684
	core.bonusRockets = 0 -- 685
	do -- 685
		local i = 0 -- 686
		while i < #core.collectedBonus do -- 686
			core.collectedBonus[i + 1] = false -- 686
			i = i + 1 -- 686
		end -- 686
	end -- 686
	core.result = nil -- 687
	core.burnDuration = 0 -- 688
	core.slowmo = false -- 689
	core.slowmoBody = -1 -- 690
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
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 707
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 707
		return false -- 709
	end -- 709
	core.phase = "LevelSelect" -- 710
	core.viewMode = "2D" -- 712
	core.flight = nil -- 713
	core.flightTime = 0 -- 714
	core.goalIndex = -1 -- 715
	core.result = nil -- 716
	core.slowmo = false -- 717
	core.slowmoBody = -1 -- 718
	return true -- 719
end -- 707
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 748
	if core.phase ~= "Result" then -- 748
		return false -- 749
	end -- 749
	core.phase = "Finale" -- 750
	return true -- 751
end -- 748
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 769
	local dist = distance > 1 and distance or 1 -- 770
	local ux = probe.x -- 772
	local uy = probe.y -- 773
	local len = math.sqrt(ux * ux + uy * uy) -- 774
	if len < 0.000001 then -- 774
		ux = 0 -- 775
		uy = 1 -- 775
	else -- 775
		ux = ux / len -- 775
		uy = uy / len -- 775
	end -- 775
	local tilt = tiltDeg * math.pi / 180 -- 776
	local flat = math.cos(tilt) * dist -- 777
	return { -- 778
		target = Vec3(0, 0, 0), -- 780
		eye = Vec3( -- 781
			ux * flat * PlaneToWorldX, -- 781
			math.sin(tilt) * dist, -- 781
			uy * flat * PlaneToWorldZ -- 781
		) -- 781
	} -- 781
end -- 769
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 925
	local introTourActive, introTourT -- 925
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 926
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 932
	local paused = false -- 933
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 934
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 936
	local function applySpeedRate() -- 937
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 938
	end -- 937
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 951
		if level.transfer ~= nil then -- 951
			paused = false -- 952
			speedPow = 0 -- 952
			applySpeedRate() -- 952
			return -- 952
		end -- 952
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 952
			return -- 953
		end -- 953
		speedPow = level.flightSpeedPow -- 954
		paused = false -- 955
		applySpeedRate() -- 956
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 957
	end -- 951
	applySpeedRate() -- 963
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 966
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
	local function applyView() -- 981
		local mode = core.viewMode -- 982
		if mode == appliedMode then -- 982
			return -- 983
		end -- 983
		appliedMode = mode -- 984
		local is2D = mode == "2D" -- 985
		deps.plan:setVisible(is2D) -- 986
		deps.trajectory.root.visible = not is2D -- 987
		deps:setWorldVisible(not is2D) -- 988
		deps.aim:setFullScreenAim(is2D) -- 989
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 990
	end -- 981
	local ____temp_6 -- 993
	if level.mission ~= nil then -- 993
		____temp_6 = level.mission.introTour -- 993
	else -- 993
		____temp_6 = nil -- 993
	end -- 993
	local tourDef = ____temp_6 -- 993
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 994
	local function finishIntroTour() -- 996
		if not introTourActive then -- 996
			return -- 997
		end -- 997
		introTourActive = false -- 998
		introTourT = tourDuration -- 999
		core.viewMode = "2D" -- 1000
		applyView() -- 1001
		deps.aim:setIntroTourBannerVisible(false) -- 1002
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1003
	end -- 996
	local function makeBasis(frame) -- 1006
		return prepareCamera({ -- 1007
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1009
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1010
			up = {x = 0, y = 1, z = 0}, -- 1011
			fovYDeg = deps.fovYDeg, -- 1012
			aspect = deps.aspect, -- 1013
			viewW = deps.viewW, -- 1014
			viewH = deps.viewH -- 1015
		}, HANDEDNESS, FLIP_Y) -- 1015
	end -- 1006
	local PredMinIntervalSec = 0.08 -- 1027
	local predAimKey = "" -- 1028
	local predPosKey = "" -- 1029
	local predAccum = 1 -- 1030
	local predForce = true -- 1031
	local predPoints = {} -- 1032
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 1034
	introTourActive = false -- 1036
	introTourT = tourDuration -- 1037
	local introLogged = false -- 1038
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1040
	local clock = 0 -- 1046
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1048
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1050
	local obsYawDeg = 0 -- 1054
	local obsPitchDeg = 0 -- 1055
	local obsZoom = 1 -- 1056
	local focusMode = "Auto" -- 1057
	local markerElapsed = -1 -- 1058
	local reportedBonusIds = {} -- 1059
	local bonusEffectElapsed = {} -- 1060
	local cineKey = "" -- 1061
	local cineFrame = nil -- 1062
	local cineFrom = nil -- 1063
	local cineTransition = 0 -- 1064
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1066
	local idleOrbit = nil -- 1068
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1079
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1081
	local lastSlowmoBody = -1 -- 1082
	local flightLogT = 0 -- 1083
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1085
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1086
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
	local function prepareIdle() -- 1101
		clock = 0 -- 1103
		core.t0 = 0 -- 1104
		idleOrbit = nil -- 1105
		if level.probeVel0 == nil then -- 1105
			return -- 1106
		end -- 1106
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1108
		if hostIndex < 0 then -- 1108
			return -- 1109
		end -- 1109
		local host = level.bodies[hostIndex + 1] -- 1110
		local hp = bodyPositionAt(host, 0) -- 1111
		local hv = bodyVelocityAt(host, 0) -- 1112
		local rx = level.probeStart.x - hp.x -- 1114
		local ry = level.probeStart.y - hp.y -- 1115
		local vx = level.probeVel0.x - hv.x -- 1116
		local vy = level.probeVel0.y - hv.y -- 1117
		local r = math.sqrt(rx * rx + ry * ry) -- 1118
		if r < 1e-12 then -- 1118
			return -- 1119
		end -- 1119
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1121
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1122
		idleOrbit = { -- 1123
			hostIndex = hostIndex, -- 1123
			r = r, -- 1123
			phase0 = math.atan(ry, rx), -- 1123
			omega = dir * omega -- 1123
		} -- 1123
	end -- 1101
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1127
		if idleOrbit == nil then -- 1127
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1129
		end -- 1129
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1134
		local hp = bodyPositionAt(host, tWorld) -- 1135
		local hv = bodyVelocityAt(host, tWorld) -- 1136
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1137
		local ca = math.cos(a) -- 1138
		local sa = math.sin(a) -- 1139
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1140
	end -- 1127
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1157
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1158
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1161
		local wps = goalWaypoints(level.goal) -- 1162
		if #wps == 0 then -- 1162
			return nil -- 1163
		end -- 1163
		local passed = 0 -- 1164
		if core.flight ~= nil then -- 1164
			local upto = math.floor(core.flightTime / core.dt) -- 1166
			passed = waypointProgress( -- 1167
				core.flight.points, -- 1167
				level.bodies, -- 1167
				level.goal, -- 1167
				core.dt, -- 1167
				core.t0, -- 1167
				upto, -- 1167
				core.flight.velocities -- 1167
			).passed -- 1167
		end -- 1167
		if passed >= #wps then -- 1167
			return nil -- 1169
		end -- 1169
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1170
	end -- 1161
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1181
		if level.transfer ~= nil then -- 1181
			return { -- 1183
				pts = { -- 1183
					probe, -- 1183
					bodyPositionAt(level.bodies[1], t), -- 1183
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1183
					goalPositionAt(level.goal.marker ~= nil and level.goal.marker or level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1183
				}, -- 1183
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1184
			} -- 1184
		end -- 1184
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1184
			local hr = anchorDef.radius -- 1189
			do -- 1189
				local i = 0 -- 1190
				while i < #level.bodies do -- 1190
					local b = level.bodies[i + 1] -- 1191
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1191
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1191
							hr = deps.visuals[i + 1].displayRadius -- 1193
						end -- 1193
						break -- 1194
					end -- 1194
					i = i + 1 -- 1190
				end -- 1190
			end -- 1190
			return { -- 1197
				pts = { -- 1197
					probe, -- 1197
					bodyPositionAt(anchorDef, t) -- 1197
				}, -- 1197
				radii = {deps.scene.probeRadius, hr} -- 1197
			} -- 1197
		end -- 1197
		local corePts = {probe} -- 1201
		local coreRadii = {deps.scene.probeRadius} -- 1202
		local next = nextStationBody() -- 1203
		local nextTol = 0 -- 1204
		if next ~= nil then -- 1204
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1206
			local wps = goalWaypoints(level.goal) -- 1207
			local passed = 0 -- 1208
			if core.flight ~= nil then -- 1208
				passed = waypointProgress( -- 1210
					core.flight.points, -- 1210
					level.bodies, -- 1210
					level.goal, -- 1210
					core.dt, -- 1210
					core.t0, -- 1210
					math.floor(core.flightTime / core.dt), -- 1210
					core.flight.velocities -- 1210
				).passed -- 1210
			end -- 1210
			if passed < #wps then -- 1210
				nextTol = wps[passed + 1].tolerance -- 1212
			end -- 1212
			local r = nextTol > next.radius and nextTol or next.radius -- 1213
			coreRadii[#coreRadii + 1] = r -- 1214
		end -- 1214
		if anchorDef == nil then -- 1214
			return {pts = corePts, radii = coreRadii} -- 1217
		end -- 1217
		local anchorR = anchorDef.radius -- 1222
		do -- 1222
			local i = 0 -- 1223
			while i < #level.bodies do -- 1223
				local b = level.bodies[i + 1] -- 1224
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1224
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1224
						anchorR = deps.visuals[i + 1].displayRadius -- 1226
					end -- 1226
					break -- 1227
				end -- 1227
				i = i + 1 -- 1223
			end -- 1223
		end -- 1223
		local withAnchorPts = { -- 1230
			probe, -- 1230
			bodyPositionAt(anchorDef, t) -- 1230
		} -- 1230
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1231
		do -- 1231
			local i = 1 -- 1232
			while i < #corePts do -- 1232
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1233
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1234
				i = i + 1 -- 1232
			end -- 1232
		end -- 1232
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1236
		if want <= CameraFramingBudget then -- 1236
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1237
		end -- 1237
		return {pts = corePts, radii = coreRadii} -- 1238
	end -- 1181
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1242
		local marker = successMarkerFrame(markerElapsed) -- 1243
		if level.goal.region ~= nil then -- 1243
			local out = {} -- 1245
			local region = level.goal.region -- 1246
			local body = level.bodies[region.bodyIndex + 1] -- 1247
			if body ~= nil and (markerElapsed < 0 or marker.visible) then -- 1247
				local center = bodyPositionAt(body, t) -- 1249
				local alpha = markerElapsed >= 0 and marker.alpha or 0.55 -- 1250
				out[#out + 1] = { -- 1251
					center = center, -- 1251
					radius = body.radius + region.minAltitude, -- 1251
					bandOuterRadius = body.radius + region.maxAltitude, -- 1251
					passed = false, -- 1251
					pointAlpha = alpha -- 1251
				} -- 1251
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1252
				out[#out + 1] = {center = center, radius = body.radius + region.maxAltitude, passed = false, pointAlpha = alpha} -- 1253
			end -- 1253
			if level.bonusPoints ~= nil then -- 1253
				do -- 1253
					local i = 0 -- 1255
					while i < #level.bonusPoints do -- 1255
						do -- 1255
							local collected = core.collectedBonus[i + 1] -- 1256
							if collected and (bonusEffectElapsed[i + 1] == nil or bonusEffectElapsed[i + 1] >= 0.6) then -- 1256
								goto __continue158 -- 1257
							end -- 1257
							local p = level.bonusPoints[i + 1] -- 1258
							local targetBody = p.bodyIndex ~= nil and level.bodies[p.bodyIndex + 1] or p.orbit -- 1259
							if targetBody ~= nil then -- 1259
								local effect = collected and bonusEffectElapsed[i + 1] or -1 -- 1261
								out[#out + 1] = { -- 1262
									center = goalPositionAt(targetBody, t, p.offset), -- 1262
									radius = p.tolerance, -- 1262
									passed = false, -- 1262
									point = true, -- 1262
									showRange = not collected, -- 1262
									pulse = collected and 1 + effect * 2 or 1 + 0.1 * math.sin(t * 4), -- 1262
									pointAlpha = collected and 1 - effect / 0.6 or 1, -- 1262
									burstRadius = collected and p.tolerance * effect / 0.6 or nil -- 1262
								} -- 1262
							end -- 1262
						end -- 1262
						::__continue158:: -- 1262
						i = i + 1 -- 1255
					end -- 1255
				end -- 1255
			end -- 1255
			return out -- 1265
		end -- 1265
		if level.transfer ~= nil and not marker.visible then -- 1265
			return {} -- 1267
		end -- 1267
		local wps = goalWaypoints(level.goal) -- 1268
		if #wps == 0 then -- 1268
			return {} -- 1269
		end -- 1269
		local passed = 0 -- 1270
		if upto ~= nil and core.flight ~= nil then -- 1270
			passed = waypointProgress( -- 1272
				core.flight.points, -- 1272
				level.bodies, -- 1272
				level.goal, -- 1272
				core.dt, -- 1272
				core.t0, -- 1272
				upto, -- 1272
				core.flight.velocities -- 1272
			).passed -- 1272
		end -- 1272
		if transferCinematic(level.transfer) then -- 1272
			passed = 0 -- 1274
		end -- 1274
		if passed >= #wps then -- 1274
			return {} -- 1278
		end -- 1278
		local nextWp = wps[passed + 1] -- 1279
		local body = level.goal.marker ~= nil and level.goal.marker or level.bodies[nextWp.planetIndex + 1] -- 1280
		if body == nil then -- 1280
			return {} -- 1281
		end -- 1281
		local planning = aimed and (core.phase == "Aiming" or core.phase == "Armed") -- 1282
		local ____temp_7 -- 1283
		if level.transfer ~= nil then -- 1283
			____temp_7 = level.transfer.orbital -- 1283
		else -- 1283
			____temp_7 = nil -- 1283
		end -- 1283
		local orbital = ____temp_7 -- 1283
		local rings = {{ -- 1284
			center = goalPositionAt(body, t, nextWp.offset), -- 1284
			radius = nextWp.tolerance, -- 1284
			passed = false, -- 1284
			point = level.transfer ~= nil, -- 1285
			showRange = level.transfer == nil or (orbital == nil or orbital.targetFlyby ~= nil) and planning, -- 1285
			pulse = (1 + 0.1 * math.sin(t * 4)) * marker.scale, -- 1286
			pointAlpha = marker.alpha, -- 1286
			burstRadius = marker.ring -- 1286
		}} -- 1286
		if orbital ~= nil and orbital.region ~= nil and planning then -- 1286
			local center = bodyPositionAt(level.bodies[1], t) -- 1288
			__TS__ArrayPush(rings, {center = center, radius = orbital.region.minRadius, passed = false}, {center = center, radius = orbital.region.maxRadius, passed = false}) -- 1289
		end -- 1289
		return rings -- 1291
	end -- 1242
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1295
		if level.transfer ~= nil and not transferCinematic(level.transfer) then -- 1295
			local basis = makeBasis(f) -- 1297
			local dx = f.eye.x - f.target.x -- 1298
			local dy = f.eye.y - f.target.y -- 1298
			local dz = f.eye.z - f.target.z -- 1298
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1299
			f = { -- 1300
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1300
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1301
			} -- 1301
		end -- 1301
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1301
			return f -- 1303
		end -- 1303
		local dx = f.eye.x - f.target.x -- 1304
		local dy = f.eye.y - f.target.y -- 1305
		local dz = f.eye.z - f.target.z -- 1306
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1307
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1308
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1309
		local lo = CameraTiltMin * math.pi / 180 -- 1310
		local hi = CameraTiltMax * math.pi / 180 -- 1311
		if pitch < lo then -- 1311
			pitch = lo -- 1312
		end -- 1312
		if pitch > hi then -- 1312
			pitch = hi -- 1313
		end -- 1313
		local cp = math.cos(pitch) -- 1314
		return { -- 1315
			target = f.target, -- 1316
			eye = Vec3( -- 1317
				f.target.x + r * cp * math.sin(yaw), -- 1318
				f.target.y + r * math.sin(pitch), -- 1319
				f.target.z + r * cp * math.cos(yaw) -- 1320
			) -- 1320
		} -- 1320
	end -- 1295
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1326
		local cfg = level.transfer.flyby -- 1327
		local autoShot = transferShotAt( -- 1328
			core.flightTime, -- 1328
			core.burnDuration, -- 1328
			core.flyby, -- 1328
			cfg, -- 1328
			core.dt -- 1328
		) -- 1328
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1329
		local key = (focusMode .. ":") .. shot -- 1330
		local earth = bodyPositionAt(level.bodies[1], t) -- 1331
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1332
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1333
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1334
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1335
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1336
		local moonAz = launchAz -- 1337
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1337
			local at = core.flyby.entryIndex -- 1339
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1340
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1342
		end -- 1342
		local pts = {pos} -- 1344
		local radii = {deps.scene.probeRadius} -- 1344
		local az = launchAz -- 1345
		local tilt = 28 -- 1345
		local minDist = 130 -- 1345
		if shot == "Cruise" then -- 1345
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 32 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 32 / vmag or 0)} -- 1347
			radii[#radii + 1] = 0 -- 1348
			minDist = 180 -- 1348
			tilt = 35 -- 1348
		elseif shot == "Moon" then -- 1348
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1350
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1351
			az = moonAz -- 1352
			tilt = 45 -- 1352
			minDist = 160 -- 1352
		elseif shot == "Earth" then -- 1352
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1354
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1355
			az = moonAz + 35 -- 1356
			tilt = 42 -- 1356
			minDist = 180 -- 1356
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1356
				local at = math.min( -- 1358
					#core.flight.points - 1, -- 1358
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1358
				) -- 1358
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1359
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1361
			end -- 1361
		elseif shot == "Overview" then -- 1361
			pts = {pos, earth, moon} -- 1364
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1364
			az = moonAz -- 1365
			tilt = 60 -- 1365
			minDist = 200 -- 1365
		end -- 1365
		if key ~= cineKey then -- 1365
			cineFrom = cineFrame -- 1368
			cineTransition = 0 -- 1369
			if cineKey == "" or shot == "Launch" then -- 1369
				cineFrom = nil -- 1371
			end -- 1371
			cineKey = key -- 1372
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1373
		end -- 1373
		local want = deps.rig.step( -- 1375
			pts, -- 1375
			deps.scene.probeRadius, -- 1375
			radii, -- 1375
			minDist, -- 1375
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1375
		) -- 1375
		local frame = want -- 1376
		if cineFrom ~= nil then -- 1376
			cineTransition = cineTransition + wallDt -- 1378
			local u = math.min(1, cineTransition / 0.6) -- 1379
			local k = u * u * (3 - 2 * u) -- 1380
			frame = { -- 1381
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1381
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1382
			} -- 1382
			if u >= 1 then -- 1382
				cineFrom = nil -- 1383
			end -- 1383
		end -- 1383
		cineFrame = frame -- 1385
		return applyObserve(frame) -- 1386
	end -- 1326
	--- 日心关卡按配置逐站取景，手动选择保持到回到自动。
	local function orbitalCamera(pos, t, wallDt) -- 1390
		local cfg = level.transfer.orbital -- 1391
		local autoShot = orbitalShotAt( -- 1392
			core.flightTime, -- 1392
			core.burnDuration, -- 1392
			core.flyby, -- 1392
			cfg, -- 1392
			core.dt -- 1392
		) -- 1392
		if level.levelId == 3 and core.missionCompleted then -- 1392
			autoShot = core.flightTime - core.goalIndex * core.dt < 2 and "Cruise" or "Overview" -- 1393
		end -- 1393
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1394
		local key = (focusMode .. ":") .. shot -- 1395
		local velocity = core.flight.velocities[____exports.coreProbeIndex(core) + 1] -- 1396
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1397
		local pts = {pos} -- 1398
		local radii = {deps.scene.probeRadius} -- 1398
		local az = math.atan(core.flight.velocities[1].x, core.flight.velocities[1].y) * 180 / math.pi + 100 -- 1399
		local targetFlybyMission = cfg.targetFlyby ~= nil -- 1400
		local encounterSpecs = {table.unpack(cfg.encounters)} -- 1401
		if cfg.targetFlyby ~= nil then -- 1401
			encounterSpecs[#encounterSpecs + 1] = cfg.targetFlyby -- 1402
		end -- 1402
		local tilt = 28 -- 1403
		local minDist = targetFlybyMission and 40 or 130 -- 1403
		if shot == "Cruise" then -- 1403
			pts[#pts + 1] = {x = pos.x + (speed > 0 and velocity.x * 32 / speed or 0), y = pos.y + (speed > 0 and velocity.y * 32 / speed or 0)} -- 1405
			radii[#radii + 1] = 0 -- 1406
			tilt = 35 -- 1406
			minDist = targetFlybyMission and 65 or 180 -- 1406
		elseif shot == "Overview" then -- 1406
			pts[#pts + 1] = bodyPositionAt(level.bodies[1], t) -- 1408
			radii[#radii + 1] = level.bodies[1].radius -- 1408
			for ____, e in ipairs(encounterSpecs) do -- 1409
				pts[#pts + 1] = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1409
				radii[#radii + 1] = level.bodies[e.planetIndex + 1].radius -- 1409
			end -- 1409
			az = math.atan(pos.x, pos.y) * 180 / math.pi -- 1410
			tilt = 60 -- 1410
			minDist = 300 -- 1410
		elseif shot == "Sun" then -- 1410
			pts = {bodyPositionAt(level.bodies[1], t)} -- 1412
			radii = {level.bodies[1].radius} -- 1412
			tilt = 42 -- 1412
			minDist = 200 -- 1412
		elseif shot ~= "Launch" then -- 1412
			do -- 1412
				local i = 0 -- 1414
				while i < #encounterSpecs do -- 1414
					do -- 1414
						local e = encounterSpecs[i + 1] -- 1415
						if e.focus ~= shot then -- 1415
							goto __continue194 -- 1416
						end -- 1416
						local bp = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1417
						pts = focusMode == "Auto" and ({pos, bp}) or ({bp}) -- 1418
						radii = focusMode == "Auto" and ({deps.scene.probeRadius, level.bodies[e.planetIndex + 1].radius}) or ({level.bodies[e.planetIndex + 1].radius}) -- 1419
						local ____temp_8 -- 1420
						if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 1420
							____temp_8 = i < #cfg.encounters and core.flyby.encounters[i + 1] or core.flyby.destination -- 1420
						else -- 1420
							____temp_8 = nil -- 1420
						end -- 1420
						local stage = ____temp_8 -- 1420
						local at = stage ~= nil and stage.entryIndex >= 0 and stage.entryIndex or 0 -- 1421
						local near = bodyPositionAt(level.bodies[e.planetIndex + 1], core.t0 + at * core.dt) -- 1422
						local probe = core.flight.points[at + 1] -- 1422
						az = math.atan(probe.x - near.x, probe.y - near.y) * 180 / math.pi + 90 -- 1423
						tilt = 45 -- 1424
						minDist = targetFlybyMission and (focusMode == "Auto" and 80 or level.bodies[e.planetIndex + 1].radius * 6) or 180 -- 1424
						break -- 1424
					end -- 1424
					::__continue194:: -- 1424
					i = i + 1 -- 1414
				end -- 1414
			end -- 1414
		end -- 1414
		if key ~= cineKey then -- 1414
			cineFrom = cineFrame -- 1428
			cineTransition = 0 -- 1428
			if cineKey == "" or shot == "Launch" then -- 1428
				cineFrom = nil -- 1429
			end -- 1429
			cineKey = key -- 1430
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1431
		end -- 1431
		local want = deps.rig.step( -- 1433
			pts, -- 1433
			deps.scene.probeRadius, -- 1433
			radii, -- 1433
			minDist, -- 1433
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1433
		) -- 1433
		local frame = want -- 1434
		if cineFrom ~= nil then -- 1434
			cineTransition = cineTransition + wallDt -- 1436
			local u = math.min(1, cineTransition / 0.6) -- 1437
			local k = u * u * (3 - 2 * u) -- 1437
			frame = { -- 1438
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1438
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1439
			} -- 1439
			if u >= 1 then -- 1439
				cineFrom = nil -- 1440
			end -- 1440
		end -- 1440
		cineFrame = frame -- 1442
		return applyObserve(frame) -- 1443
	end -- 1390
	local function resetCinematic() -- 1446
		markerElapsed = -1 -- 1447
		focusMode = "Auto" -- 1448
		cineKey = "" -- 1448
		cineFrame = nil -- 1448
		cineFrom = nil -- 1448
		obsYawDeg = 0 -- 1449
		obsPitchDeg = 0 -- 1449
		obsZoom = 1 -- 1449
	end -- 1446
	local function updateAiming(dt) -- 1452
		if deps.plan.setBurn ~= nil then -- 1452
			deps.plan:setBurn(core.aim.velocity, false) -- 1453
		end -- 1453
		deps.aim:setEnabled(true) -- 1454
		local dragging = deps.aim:isDragging() -- 1456
		local clockFrozen = dragging or core.phase == "Armed" or transferCinematic(level.transfer) and introTourActive -- 1461
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1461
			local rate = core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1472
			clock = clock + dt * rate -- 1473
			orbitClock = orbitClock + dt * rate -- 1474
		end -- 1474
		local tNow = core.t0 + clock -- 1476
		local idleState = idleProbeAt(tNow) -- 1478
		probePos = idleState.pos -- 1479
		probeVel = idleState.vel -- 1480
		deps.scene.syncBodies(tNow) -- 1482
		if deps.scene.syncStars ~= nil then -- 1482
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1483
		end -- 1483
		deps.scene.syncProbe(probePos) -- 1484
		if idleOrbit ~= nil then -- 1484
			deps.scene.faceVelocity(probeVel) -- 1485
		end -- 1485
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1487
		deps.plan:syncProbe(probePos, probeVel) -- 1488
		if not aimed and #core.stars > 0 then -- 1488
			deps.plan:setStars( -- 1490
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1490
				core.collectedStars -- 1490
			) -- 1490
		end -- 1490
		local fr = framingPoints(probePos, tNow) -- 1494
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1495
		if frameLogged < 6 then -- 1495
			frameLogged = frameLogged + 1 -- 1499
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1500
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1504
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1505
				__TS__ArrayMap( -- 1511
					fr.pts, -- 1511
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1511
				), -- 1511
				" " -- 1511
			)) .. "]") -- 1511
		end -- 1511
		if introTourActive and introTourT < tourDuration then -- 1511
			introTourT = introTourT + dt -- 1515
			local k = introTourT / tourDuration -- 1516
			if k >= 1 then -- 1516
				finishIntroTour() -- 1518
			else -- 1518
				if k >= 0.95 and not introLogged then -- 1518
					introLogged = true -- 1521
					print("[escape-velocity] intro camera finishing") -- 1522
				end -- 1522
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1522
					local elapsed = introTourT -- 1526
					local segIndex = 0 -- 1527
					local segStart = 0 -- 1528
					do -- 1528
						local s = 0 -- 1529
						while s < #tourDef.segments do -- 1529
							local seg = tourDef.segments[s + 1] -- 1530
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1530
								segIndex = s -- 1532
								break -- 1533
							end -- 1533
							elapsed = elapsed - seg.duration -- 1535
							segStart = segStart + seg.duration -- 1536
							s = s + 1 -- 1529
						end -- 1529
					end -- 1529
					local curSeg = tourDef.segments[segIndex + 1] -- 1538
					local segK = math.max( -- 1539
						0, -- 1539
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1539
					) -- 1539
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1541
					deps.aim:setIntroTourBannerVisible(true) -- 1542
					local pwProbe = planeToWorld(probePos, 0) -- 1544
					local function getTargetPosAndDist(targetIdx, userDist) -- 1545
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1545
							local b = level.bodies[targetIdx + 1] -- 1547
							local isMicro = b.orbitRadius < 2 -- 1548
							local p = planeToWorld( -- 1549
								bodyPositionAt(b, tNow), -- 1549
								0 -- 1549
							) -- 1549
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1550
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1551
						end -- 1551
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1553
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1554
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1555
					end -- 1545
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1558
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1559
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1560
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1562
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1563
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1564
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1565
					if segIndex == 0 then -- 1565
						local az = curAz + segK * (18 * math.pi / 180) -- 1569
						local tilt = curTilt -- 1570
						local d = curKey.dist -- 1571
						local eye = Vec3( -- 1572
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1573
							curKey.pos.y + math.sin(tilt) * d, -- 1574
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1575
						) -- 1575
						frame = {target = curKey.pos, eye = eye} -- 1577
					else -- 1577
						local ease = segK * segK * (3 - 2 * segK) -- 1580
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1581
						local az = prevAz + (curAz - prevAz) * ease -- 1586
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1587
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1588
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1589
						local eye = Vec3( -- 1590
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1591
							target.y + math.sin(tilt) * d, -- 1592
							target.z + math.cos(az) * math.cos(tilt) * d -- 1593
						) -- 1593
						frame = {target = target, eye = eye} -- 1595
					end -- 1595
				else -- 1595
					local targetBody = nil -- 1598
					local wps = goalWaypoints(level.goal) -- 1599
					if #wps > 0 then -- 1599
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1601
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1601
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1603
					end -- 1603
					if targetBody == nil and #level.bodies > 0 then -- 1603
						targetBody = level.bodies[#level.bodies] -- 1606
					end -- 1606
					if targetBody ~= nil then -- 1606
						local pwTarget = planeToWorld( -- 1610
							bodyPositionAt(targetBody, tNow), -- 1610
							0 -- 1610
						) -- 1610
						local pwProbe = planeToWorld(probePos, 0) -- 1611
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1612
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1613
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1614
						if k < 0.35 then -- 1614
							local e1 = k / 0.35 -- 1617
							local az = (0.2 + e1 * 0.15) * math.pi -- 1618
							local tilt = 0.35 * math.pi -- 1619
							local eye = Vec3( -- 1620
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1621
								pwTarget.y + math.sin(tilt) * distTarget, -- 1622
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1623
							) -- 1623
							frame = {target = pwTarget, eye = eye} -- 1625
						elseif k < 0.72 then -- 1625
							local e2 = (k - 0.35) / 0.37 -- 1627
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1628
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1629
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1630
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1631
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1632
							local eye = Vec3( -- 1637
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1638
								targetCenter.y + curDist * 0.8, -- 1639
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1640
							) -- 1640
							frame = {target = targetCenter, eye = eye} -- 1642
						else -- 1642
							local e3 = (k - 0.72) / 0.28 -- 1644
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1645
							local az = 0.25 * math.pi -- 1646
							local tilt = 0.36 * math.pi -- 1647
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1648
							local eye = Vec3( -- 1649
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1650
								pwProbe.y + math.sin(tilt) * curDist, -- 1651
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1652
							) -- 1652
							frame = {target = pwProbe, eye = eye} -- 1654
						end -- 1654
					end -- 1654
				end -- 1654
			end -- 1654
		end -- 1654
		frame = applyObserve(frame) -- 1661
		deps.rig.apply(deps.camera, frame) -- 1662
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1663
		local basis = makeBasis(frame) -- 1664
		if core.viewMode == "2D" then -- 1664
			local sp = deps.plan:probeScreen() -- 1670
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1671
		else -- 1671
			local pp = projectPrepared( -- 1673
				planeToWorld(probePos, 0), -- 1673
				basis -- 1673
			) -- 1673
			if pp ~= nil then -- 1673
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1674
			end -- 1674
		end -- 1674
		if not aimed then -- 1674
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1674
				deps.aim:setTransferInfo( -- 1684
					distance( -- 1684
						probePos, -- 1684
						bodyPositionAt(level.bodies[1], tNow) -- 1684
					) - level.bodies[1].radius, -- 1684
					0 -- 1684
				) -- 1684
			end -- 1684
			deps.trajectory:clearPrediction() -- 1688
			deps.plan:clearPrediction() -- 1689
			predForce = true -- 1690
		else -- 1690
			local aimKey = (__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4) -- 1696
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1697
			predAccum = predAccum + dt -- 1698
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1699
			if needIt then -- 1699
				predForce = false -- 1701
				predAccum = 0 -- 1702
				predAimKey = aimKey -- 1703
				predPosKey = posKey -- 1704
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel) -- 1707
				local predictSample = level.transfer ~= nil and 1 or 4 -- 1708
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion}, level.bodies, { -- 1709
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1712
					dt = core.dt, -- 1712
					sampleEvery = predictSample, -- 1712
					escapeRadius = level.escapeRadius, -- 1712
					t0 = tNow -- 1712
				}) -- 1712
				predPoints = sim.points -- 1714
				if level.transfer ~= nil then -- 1714
					local analysis = analyzeTransfer( -- 1716
						sim, -- 1716
						level.bodies, -- 1716
						level.goal.planetIndex, -- 1716
						level.transfer, -- 1716
						core.dt * predictSample, -- 1716
						tNow -- 1716
					) -- 1716
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1717
						sim.points, -- 1717
						level.bodies, -- 1717
						level.goal, -- 1717
						core.dt * predictSample, -- 1717
						tNow, -- 1717
						sim.velocities -- 1717
					) -- 1717
					if analysis ~= nil then -- 1717
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1718
					elseif gi >= 0 then -- 1718
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1719
					end -- 1719
					local radius = distance( -- 1720
						probePos, -- 1720
						bodyPositionAt(level.bodies[1], tNow) -- 1720
					) -- 1720
					local plan = planTransfer( -- 1721
						level.bodies[1].gm, -- 1721
						radius, -- 1721
						probeVel, -- 1721
						core.aim.power, -- 1721
						level.transfer.apoapsisMax, -- 1721
						level.transfer.mode, -- 1721
						level.transfer.periapsisMin -- 1721
					) -- 1721
					if deps.aim.setTransferInfo ~= nil then -- 1721
						deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1722
					end -- 1722
				end -- 1722
				predTimes = {} -- 1724
				do -- 1724
					local pi = 0 -- 1725
					while pi < #predPoints do -- 1725
						predTimes[#predTimes + 1] = tNow + pi * core.dt * predictSample -- 1725
						pi = pi + 1 -- 1725
					end -- 1725
				end -- 1725
			end -- 1725
			deps.trajectory:setPrediction(predPoints, basis) -- 1727
			deps.plan:setPrediction(predPoints) -- 1729
			if #core.stars > 0 then -- 1729
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1732
				local stEval = evaluateCollectedStars( -- 1733
					predPoints, -- 1733
					core.stars, -- 1733
					30, -- 1733
					core.starOrbits, -- 1733
					predTimes -- 1733
				) -- 1733
				core.previewStarsCount = stEval.count -- 1734
				deps.plan:setStars(live, stEval.collected) -- 1735
			end -- 1735
		end -- 1735
		if idleOrbit ~= nil then -- 1735
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1740
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1741
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1742
		end -- 1742
		local rings = goalRingsAt(tNow) -- 1744
		deps.trajectory:setGoalRings(rings, basis) -- 1745
		deps.trajectory:clearTrail() -- 1746
		deps.plan:setGoalRings(rings) -- 1748
		deps.plan:clearTrail() -- 1749
		deps.plan:flush() -- 1750
	end -- 1452
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
	local function updateFinale() -- 1765
		deps.aim:setEnabled(false) -- 1766
		if core.flight == nil then -- 1766
			return -- 1767
		end -- 1767
		local idx = ____exports.coreProbeIndex(core) -- 1768
		local pos = core.flight.points[idx + 1] -- 1769
		local tWorld = core.t0 + core.flightTime -- 1770
		deps.scene.syncBodies(tWorld) -- 1773
		deps.scene.syncProbe(pos) -- 1774
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1775
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1778
		deps.camera:lookAt( -- 1779
			frame.eye, -- 1779
			frame.target, -- 1779
			Vec3(0, 1, 0) -- 1779
		) -- 1779
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1780
		local trail = {} -- 1783
		do -- 1783
			local i = 0 -- 1784
			while i <= idx do -- 1784
				trail[#trail + 1] = core.flight.points[i + 1] -- 1784
				i = i + 1 -- 1784
			end -- 1784
		end -- 1784
		local rings = goalRingsAt(tWorld, idx) -- 1785
		local basis = makeBasis(frame) -- 1786
		if deps.trajectory.setBurn ~= nil then -- 1786
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1788
		end -- 1788
		deps.trajectory:clearOrbitRing() -- 1789
		deps.plan:clearProbeOrbit() -- 1790
		deps.trajectory:setTrail(trail, basis) -- 1791
		deps.trajectory:setGoalRings(rings, basis) -- 1792
		deps.plan:clearPrediction() -- 1793
		deps.plan:setGoalRings(rings) -- 1794
		deps.plan:flush() -- 1795
	end -- 1765
	local function updateFlying(dt) -- 1797
		deps.aim:setEnabled(false) -- 1798
		local wasCompleted = core.missionCompleted -- 1801
		local oldBonusScore = core.bonusRockets -- 1802
		local entered = ____exports.coreUpdate(core, dt, level) -- 1803
		if not wasCompleted and core.missionCompleted then -- 1803
			markerElapsed = 0 -- 1805
			print("[escape-velocity] success marker triggered once") -- 1806
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1807
			if deps.onMissionCompleted ~= nil then -- 1807
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1808
			end -- 1808
		end -- 1808
		if core.bonusRockets > oldBonusScore and deps.onBonusCollected ~= nil and level.bonusPoints ~= nil then -- 1808
			do -- 1808
				local i = 0 -- 1811
				while i < #core.collectedBonus do -- 1811
					if core.collectedBonus[i + 1] and not reportedBonusIds[level.bonusPoints[i + 1].id] then -- 1811
						reportedBonusIds[level.bonusPoints[i + 1].id] = true -- 1812
						bonusEffectElapsed[i + 1] = 0 -- 1813
						deps:onBonusCollected(core.bonusRockets, level.bonusPoints[i + 1].id) -- 1814
					end -- 1814
					i = i + 1 -- 1811
				end -- 1811
			end -- 1811
		end -- 1811
		if core.flight == nil then -- 1811
			return entered -- 1817
		end -- 1817
		local idx = ____exports.coreProbeIndex(core) -- 1819
		local pos = core.flight.points[idx + 1] -- 1820
		local tWorld = core.t0 + core.flightTime -- 1824
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1824
			lastSlowmo = core.slowmo -- 1828
			lastSlowmoBody = core.slowmoBody -- 1829
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1830
			local nearD = near ~= nil and distance( -- 1831
				pos, -- 1831
				bodyPositionAt(near, tWorld) -- 1831
			) or 0 -- 1831
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1832
		end -- 1832
		flightLogT = flightLogT + dt -- 1839
		if flightLogT >= 0.5 then -- 1839
			flightLogT = 0 -- 1841
			local total = (#core.flight.points - 1) * core.dt -- 1842
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1843
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1845
					core.flightTime, -- 1845
					core.burnDuration, -- 1845
					level.transfer, -- 1845
					core.flyby, -- 1845
					core.dt -- 1845
				) or (core.slowmo and SlowMoFactor or 1)), -- 1845
				2 -- 1845
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1845
		end -- 1845
		deps.scene.syncBodies(tWorld) -- 1849
		if deps.scene.syncStars ~= nil then -- 1849
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1850
		end -- 1850
		deps.scene.syncProbe(pos) -- 1851
		if idx > 0 then -- 1851
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1853
		end -- 1853
		do -- 1853
			local s = 0 -- 1857
			while s < #core.stars do -- 1857
				if not core.collectedStars[s + 1] then -- 1857
					local fromLevel = level.starOrbits -- 1859
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1860
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1861
					local dx = pos.x - stPos.x -- 1862
					local dy = pos.y - stPos.y -- 1863
					if dx * dx + dy * dy <= 30 * 30 then -- 1863
						core.collectedStars[s + 1] = true -- 1865
						if deps.scene.setStarCollected ~= nil then -- 1865
							deps.scene.setStarCollected(s) -- 1867
						end -- 1867
						deps.plan:setStars(core.stars, core.collectedStars) -- 1869
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1870
					end -- 1870
				end -- 1870
				s = s + 1 -- 1857
			end -- 1857
		end -- 1857
		local fr -- 1879
		local closeDist = nil -- 1880
		if core.slowmo and core.slowmoBody >= 0 then -- 1880
			local near = level.bodies[core.slowmoBody + 1] -- 1882
			local nearR = near.radius -- 1884
			do -- 1884
				local i = 0 -- 1885
				while i < #level.bodies do -- 1885
					local b = level.bodies[i + 1] -- 1886
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1886
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1886
							nearR = deps.visuals[i + 1].displayRadius -- 1888
						end -- 1888
						break -- 1889
					end -- 1889
					i = i + 1 -- 1885
				end -- 1885
			end -- 1885
			fr = { -- 1892
				pts = { -- 1892
					pos, -- 1892
					bodyPositionAt(near, tWorld) -- 1892
				}, -- 1892
				radii = {deps.scene.probeRadius, nearR} -- 1892
			} -- 1892
			closeDist = SlowMoCloseDist -- 1893
		else -- 1893
			fr = framingPoints(pos, tWorld) -- 1895
		end -- 1895
		local baseFrame = level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalCamera(pos, tWorld, dt) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist)) -- 1897
		local frame = level.transfer ~= nil and not transferCinematic(level.transfer) and applyObserve(baseFrame) or baseFrame -- 1898
		deps.rig.apply(deps.camera, frame) -- 1899
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1900
		local basis = makeBasis(frame) -- 1901
		if deps.trajectory.setBurn ~= nil then -- 1901
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1904
		end -- 1904
		if deps.plan.setBurn ~= nil then -- 1904
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1905
		end -- 1905
		local trail = {} -- 1906
		do -- 1906
			local i = 0 -- 1907
			while i <= idx do -- 1907
				trail[#trail + 1] = core.flight.points[i + 1] -- 1907
				i = i + 1 -- 1907
			end -- 1907
		end -- 1907
		local rings = goalRingsAt(tWorld, idx) -- 1908
		deps.trajectory:clearOrbitRing() -- 1910
		deps.plan:clearProbeOrbit() -- 1911
		deps.trajectory:setTrail(trail, basis) -- 1912
		deps.trajectory:setGoalRings(rings, basis) -- 1913
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1916
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1917
		deps.plan:setStars( -- 1918
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 1918
			core.collectedStars -- 1918
		) -- 1918
		deps.plan:setTrail(trail) -- 1919
		deps.plan:clearPrediction() -- 1920
		deps.plan:setGoalRings(rings) -- 1921
		deps.plan:flush() -- 1922
		return entered -- 1924
	end -- 1797
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1938
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1939
		core.t0 = next.t0 -- 1940
		clock = next.clock -- 1941
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1942
	end -- 1938
	local function finishFlight() -- 1945
		if core.result == nil then -- 1945
			return -- 1946
		end -- 1946
		local toFinale = deps.finale == true and core.result == "success" -- 1947
		if toFinale then -- 1947
			____exports.coreEnterFinale(core) -- 1948
		end -- 1948
		deps:onResult( -- 1949
			core.result, -- 1949
			____exports.calcFlightTelemetry(core, level) -- 1949
		) -- 1949
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1949
			local ____end = #core.flight.points - 1 -- 1951
			deps:onFinale({ -- 1952
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1952
				time = core.flightTime, -- 1952
				tWorld = core.t0 + core.flightTime -- 1952
			}) -- 1952
		end -- 1952
		deps:onPhase(toFinale and "Finale" or "Result") -- 1954
	end -- 1945
	local function update(dt) -- 1957
		if markerElapsed >= 0 and markerElapsed < 0.6 then -- 1957
			markerElapsed = math.min(0.6, markerElapsed + dt) -- 1958
		end -- 1958
		do -- 1958
			local i = 0 -- 1959
			while i < #bonusEffectElapsed do -- 1959
				if bonusEffectElapsed[i + 1] >= 0 and bonusEffectElapsed[i + 1] < 0.6 then -- 1959
					bonusEffectElapsed[i + 1] = math.min(0.6, bonusEffectElapsed[i + 1] + dt) -- 1959
				end -- 1959
				i = i + 1 -- 1959
			end -- 1959
		end -- 1959
		applyView() -- 1962
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1962
			updateAiming(dt) -- 1964
		elseif core.phase == "Flying" then -- 1964
			local entered = updateFlying(dt) -- 1966
			if entered then -- 1966
				finishFlight() -- 1967
			end -- 1967
		elseif core.phase == "Finale" then -- 1967
			updateFinale() -- 1969
		elseif core.phase == "Result" and core.missionCompleted and level.transfer ~= nil then -- 1969
			local rings = goalRingsAt( -- 1972
				core.t0 + core.flightTime, -- 1972
				____exports.coreProbeIndex(core) -- 1972
			) -- 1972
			deps.plan:setGoalRings(rings) -- 1973
			deps.plan:flush() -- 1973
			if cineFrame ~= nil then -- 1973
				deps.trajectory:setGoalRings( -- 1974
					rings, -- 1974
					makeBasis(cineFrame) -- 1974
				) -- 1974
			end -- 1974
		end -- 1974
	end -- 1957
	return { -- 1979
		phase = function() return core.phase end, -- 1980
		speedPow = function() return speedPow end, -- 1981
		speedMaxPow = function() return speedMaxPow end, -- 1982
		isPaused = function() return paused end, -- 1983
		speedRate = function() -- 1984
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 1984
				return core.playback * transferPlaybackRate( -- 1985
					core.flightTime, -- 1985
					core.burnDuration, -- 1985
					level.transfer, -- 1985
					core.flyby, -- 1985
					core.dt -- 1985
				) -- 1985
			end -- 1985
			return core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1986
		end, -- 1984
		missionSeconds = function() -- 1988
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 1989
			return speedUnit > 0 and w / speedUnit or 0 -- 1990
		end, -- 1988
		speedUp = function() -- 1992
			if speedPow >= speedMaxPow then -- 1992
				return -- 1993
			end -- 1993
			speedPow = speedPow + 1 -- 1994
			paused = false -- 1995
			applySpeedRate() -- 1996
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1997
		end, -- 1992
		speedDown = function() -- 1999
			if speedPow <= 0 then -- 1999
				return -- 2000
			end -- 2000
			speedPow = speedPow - 1 -- 2001
			paused = false -- 2002
			applySpeedRate() -- 2003
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2004
		end, -- 1999
		togglePause = function() -- 2006
			paused = not paused -- 2007
			applySpeedRate() -- 2008
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 2009
		end, -- 2006
		result = function() return core.result end, -- 2011
		onAimDrag = function(____, a) -- 2012
			if introTourActive then -- 2012
				finishIntroTour() -- 2013
			end -- 2013
			core.aim = a -- 2014
			if level.transfer ~= nil then -- 2014
				local radius = distance( -- 2016
					probePos, -- 2016
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 2016
				) -- 2016
				local plan = planTransfer( -- 2017
					level.bodies[1].gm, -- 2017
					radius, -- 2017
					probeVel, -- 2017
					a.power, -- 2017
					level.transfer.apoapsisMax, -- 2017
					level.transfer.mode, -- 2017
					level.transfer.periapsisMin -- 2017
				) -- 2017
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 2018
				if deps.aim.setTransferInfo ~= nil then -- 2018
					deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 2019
				end -- 2019
			end -- 2019
			aimed = true -- 2021
		end, -- 2012
		aimReady = function() -- 2023
			predForce = true -- 2025
			if not ____exports.coreArm(core) then -- 2025
				return -- 2026
			end -- 2026
			if level.transfer ~= nil then -- 2026
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 2027
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 2027
					4 -- 2027
				)) -- 2027
			end -- 2027
			applyView() -- 2028
			deps:onPhase("Armed") -- 2029
		end, -- 2023
		cancelAim = function() -- 2031
			if not ____exports.coreCancelArm(core) then -- 2031
				return -- 2032
			end -- 2032
			aimed = false -- 2033
			predForce = true -- 2034
			deps.trajectory:clearPrediction() -- 2035
			deps.plan:clearPrediction() -- 2036
			applyView() -- 2037
			deps:onPhase("Aiming") -- 2038
			print("[escape-velocity] aim cancelled") -- 2039
		end, -- 2031
		launchArmed = function() -- 2041
			if core.phase ~= "Armed" then -- 2041
				return -- 2043
			end -- 2043
			resetCinematic() -- 2044
			applyFlightSpeed() -- 2045
			handoffDate(true) -- 2046
			reportedBonusIds = {} -- 2047
			bonusEffectElapsed = {} -- 2048
			do -- 2048
				local i = 0 -- 2049
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2049
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2049
					i = i + 1 -- 2049
				end -- 2049
			end -- 2049
			____exports.coreLaunch( -- 2050
				core, -- 2050
				core.aim.velocity, -- 2050
				level, -- 2050
				probePos, -- 2050
				probeVel -- 2050
			) -- 2050
			deps.trajectory:clearPrediction() -- 2051
			deps.plan:clearPrediction() -- 2052
			applyView() -- 2053
			deps:onPhase("Flying") -- 2054
		end, -- 2041
		armed = function() return core.phase == "Armed" end, -- 2056
		viewMode = function() return core.viewMode end, -- 2057
		toggleViewMode = function() -- 2058
			____exports.coreToggleView(core) -- 2060
			applyView() -- 2061
		end, -- 2058
		cameraFocus = function() return focusMode end, -- 2063
		flightStage = function() return level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalShotAt( -- 2064
			core.flightTime, -- 2064
			core.burnDuration, -- 2064
			core.flyby, -- 2064
			level.transfer.orbital, -- 2064
			core.dt -- 2064
		) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 2064
			core.flightTime, -- 2065
			core.burnDuration, -- 2065
			core.flyby, -- 2065
			level.transfer.flyby, -- 2065
			core.dt -- 2065
		) or nil) end, -- 2065
		cycleCameraFocus = function() -- 2066
			if not transferCinematic(level.transfer) or core.phase ~= "Flying" then -- 2066
				return -- 2067
			end -- 2067
			local ____temp_10 -- 2068
			if level.transfer ~= nil and level.transfer.orbital ~= nil then -- 2068
				local ____array_9 = __TS__SparseArrayNew( -- 2068
					"Auto", -- 2068
					"Probe", -- 2068
					table.unpack(__TS__ArrayMap( -- 2068
						level.transfer.orbital.encounters, -- 2068
						function(____, e) return e.focus end -- 2068
					)) -- 2068
				) -- 2068
				__TS__SparseArrayPush( -- 2068
					____array_9, -- 2068
					table.unpack(level.transfer.orbital.targetFlyby ~= nil and ({level.transfer.orbital.targetFlyby.focus}) or ({})) -- 2068
				) -- 2068
				__TS__SparseArrayPush(____array_9, "Sun", "Overview") -- 2068
				____temp_10 = {__TS__SparseArraySpread(____array_9)} -- 2068
			else -- 2068
				____temp_10 = nil -- 2068
			end -- 2068
			local modes = ____temp_10 -- 2068
			focusMode = nextCameraFocus(focusMode, modes) -- 2069
			obsYawDeg = 0 -- 2070
			obsPitchDeg = 0 -- 2070
			obsZoom = 1 -- 2070
			print("[escape-velocity] camera focus -> " .. focusMode) -- 2071
		end, -- 2066
		missionCompleted = function() return core.missionCompleted end, -- 2073
		markerElapsed = function() return markerElapsed end, -- 2074
		endViewing = function() -- 2075
			if not ____exports.coreEndViewing(core) then -- 2075
				return -- 2076
			end -- 2076
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 2077
			finishFlight() -- 2078
		end, -- 2075
		skipIntroTour = function() -- 2080
			finishIntroTour() -- 2081
		end, -- 2080
		isIntroTourActive = function() return introTourActive end, -- 2083
		observeDrag = function(____, dx, dy) -- 2084
			if introTourActive then -- 2084
				finishIntroTour() -- 2086
				return -- 2087
			end -- 2087
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2089
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2090
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2091
			if obsPitchDeg > 40 then -- 2091
				obsPitchDeg = 40 -- 2092
			end -- 2092
			if obsPitchDeg < -40 then -- 2092
				obsPitchDeg = -40 -- 2093
			end -- 2093
		end, -- 2084
		observeZoom = function(____, deltaDist) -- 2095
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2096
			if obsZoom < 0.4 then -- 2096
				obsZoom = 0.4 -- 2097
			end -- 2097
			if obsZoom > 1.8 then -- 2097
				obsZoom = 1.8 -- 2098
			end -- 2098
		end, -- 2095
		launch = function(____, v) -- 2100
			applyFlightSpeed() -- 2101
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2101
				return -- 2102
			end -- 2102
			resetCinematic() -- 2103
			handoffDate(true) -- 2104
			reportedBonusIds = {} -- 2105
			bonusEffectElapsed = {} -- 2106
			do -- 2106
				local i = 0 -- 2107
				while i < (level.bonusPoints ~= nil and #level.bonusPoints or 0) do -- 2107
					bonusEffectElapsed[#bonusEffectElapsed + 1] = -1 -- 2107
					i = i + 1 -- 2107
				end -- 2107
			end -- 2107
			____exports.coreLaunch( -- 2109
				core, -- 2109
				v, -- 2109
				level, -- 2109
				probePos, -- 2109
				probeVel -- 2109
			) -- 2109
			deps.trajectory:clearPrediction() -- 2110
			deps.plan:clearPrediction() -- 2111
			applyView() -- 2112
			deps:onPhase("Flying") -- 2113
		end, -- 2100
		retry = function() -- 2115
			resetCinematic() -- 2116
			handoffDate(false) -- 2117
			aimed = false -- 2118
			introTourActive = false -- 2119
			____exports.coreRetry(core, level.aimMin) -- 2120
			if deps.scene.resetStars ~= nil then -- 2120
				deps.scene.resetStars() -- 2122
			end -- 2122
			deps.plan:setStars(core.stars, core.collectedStars) -- 2124
			deps.trajectory:clearTrail() -- 2125
			deps.trajectory:clearPrediction() -- 2126
			deps.trajectory:clearGoalRings() -- 2127
			deps.plan:clearTrail() -- 2128
			deps.plan:clearPrediction() -- 2129
			deps.plan:clearGoalRings() -- 2130
			applyView() -- 2131
			deps:onPhase("Aiming") -- 2132
		end, -- 2115
		backToSelect = function() -- 2134
			if not ____exports.coreBackToSelect(core) then -- 2134
				return false -- 2135
			end -- 2135
			deps.aim:setEnabled(false) -- 2137
			deps.trajectory:clearTrail() -- 2138
			deps.trajectory:clearPrediction() -- 2139
			deps.trajectory:clearGoalRings() -- 2140
			deps.plan:clearTrail() -- 2141
			deps.plan:clearPrediction() -- 2142
			deps.plan:clearGoalRings() -- 2143
			applyView() -- 2144
			deps:onPhase("LevelSelect") -- 2145
			return true -- 2146
		end, -- 2134
		startLevel = function() -- 2148
			resetCinematic() -- 2149
			aimed = false -- 2150
			____exports.coreRetry(core, level.aimMin) -- 2151
			if deps.scene.resetStars ~= nil then -- 2151
				deps.scene.resetStars() -- 2153
			end -- 2153
			deps.plan:setStars(core.stars, core.collectedStars) -- 2155
			deps.rig.reset() -- 2156
			introTourActive = false -- 2158
			core.viewMode = "2D" -- 2159
			appliedMode = "" -- 2160
			applyView() -- 2161
			prepareIdle() -- 2162
			deps.trajectory:clearTrail() -- 2163
			deps.trajectory:clearPrediction() -- 2164
			deps.trajectory:clearGoalRings() -- 2165
			deps.plan:clearTrail() -- 2166
			deps.plan:clearPrediction() -- 2167
			deps.plan:clearGoalRings() -- 2168
			deps:onPhase("Aiming") -- 2169
		end, -- 2148
		stepTime = function(____, dir, span) -- 2171
			if not ____exports.coreTimeWarpAllowed(core) then -- 2171
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2175
				return -- 2176
			end -- 2176
			local span0 = span > 0 and span or 0 -- 2178
			clock = clock + dir * TimeWarpStep -- 2179
			if clock < 0 then -- 2179
				clock = 0 -- 2180
			end -- 2180
			if span0 > 0 and clock > span0 then -- 2180
				clock = span0 -- 2181
			end -- 2181
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2183
		end, -- 2171
		dateNow = function() return core.t0 + clock end, -- 2185
		setPlaybackSpeed = function(____, speed) -- 2186
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2186
				return -- 2188
			end -- 2188
			core.playback = speed -- 2189
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2190
		end, -- 2186
		playbackSpeed = function() return core.playback end, -- 2192
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2193
		starsNow = function() -- 2194
			if core.phase == "Flying" or core.phase == "Result" then -- 2194
				local n = 0 -- 2196
				do -- 2196
					local i = 0 -- 2197
					while i < #core.collectedStars do -- 2197
						if core.collectedStars[i + 1] then -- 2197
							n = n + 1 -- 2197
						end -- 2197
						i = i + 1 -- 2197
					end -- 2197
				end -- 2197
				return n -- 2198
			end -- 2198
			return core.previewStarsCount -- 2200
		end, -- 2194
		bonusScore = function() return core.bonusRockets end, -- 2202
		bonusTotal = function() return level.bonusPoints ~= nil and #level.bonusPoints or 0 end, -- 2203
		update = function(____, frameDt) return update(frameDt) end -- 2205
	} -- 2205
end -- 925
return ____exports -- 925
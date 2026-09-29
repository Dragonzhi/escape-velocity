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
local analyzeFlyby = ____Transfer.analyzeFlyby -- 34
local nextCameraFocus = ____Transfer.nextCameraFocus -- 34
local planTransfer = ____Transfer.planTransfer -- 34
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
	local ____temp_0 -- 372
	if level.transfer ~= nil then -- 372
		____temp_0 = level.transfer.flyby -- 372
	else -- 372
		____temp_0 = nil -- 372
	end -- 372
	local flybyCfg = ____temp_0 -- 372
	core.flyby = flybyCfg ~= nil and analyzeFlyby( -- 373
		flight, -- 373
		level.bodies[1], -- 373
		level.bodies[level.goal.planetIndex + 1], -- 373
		flybyCfg, -- 373
		core.dt, -- 373
		core.t0 -- 373
	) or nil -- 373
	core.goalIndex = core.flyby ~= nil and core.flyby.completionIndex or findGoalIndex( -- 374
		flight.points, -- 374
		level.bodies, -- 374
		level.goal, -- 374
		core.dt, -- 374
		core.t0, -- 374
		flight.velocities -- 374
	) -- 374
	local ____core_2 = core -- 375
	local ____temp_1 -- 375
	if core.flyby ~= nil and core.goalIndex >= 0 then -- 375
		____temp_1 = nil -- 375
	else -- 375
		____temp_1 = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 375
	end -- 375
	____core_2.result = ____temp_1 -- 375
	if core.flyby ~= nil then -- 375
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 376
	end -- 376
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
								goto __continue40 -- 474
							end -- 474
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 474
								isHost = true -- 475
								break -- 475
							end -- 475
						end -- 475
						::__continue40:: -- 475
						j = j + 1 -- 472
					end -- 472
				end -- 472
				if not isHost then -- 472
					goto __continue38 -- 477
				end -- 477
				if host < 0 or b.gm > bodies[host + 1].gm then -- 477
					host = i -- 478
				end -- 478
			end -- 478
			::__continue38:: -- 478
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
					goto __continue47 -- 485
				end -- 485
				if best < 0 or b.gm > bodies[best + 1].gm then -- 485
					best = i -- 486
				end -- 486
			end -- 486
			::__continue47:: -- 486
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
					goto __continue52 -- 511
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
			::__continue52:: -- 517
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
function ____exports.createGame(level, deps) -- 1050
	local introTourActive, introTourT -- 1050
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 1051
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 1057
	local paused = false -- 1058
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 1059
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 1061
	local function applySpeedRate() -- 1062
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 1063
	end -- 1062
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 1076
		if level.transfer ~= nil then -- 1076
			paused = false -- 1077
			speedPow = 0 -- 1077
			applySpeedRate() -- 1077
			return -- 1077
		end -- 1077
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 1077
			return -- 1078
		end -- 1078
		speedPow = level.flightSpeedPow -- 1079
		paused = false -- 1080
		applySpeedRate() -- 1081
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 1082
	end -- 1076
	applySpeedRate() -- 1088
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 1091
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
	local function applyView() -- 1106
		local mode = core.viewMode -- 1107
		if mode == appliedMode then -- 1107
			return -- 1108
		end -- 1108
		appliedMode = mode -- 1109
		local is2D = mode == "2D" -- 1110
		deps.plan:setVisible(is2D) -- 1111
		deps.trajectory.root.visible = not is2D -- 1112
		deps:setWorldVisible(not is2D) -- 1113
		deps.aim:setFullScreenAim(is2D) -- 1114
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 1115
	end -- 1106
	local ____temp_3 -- 1118
	if level.mission ~= nil then -- 1118
		____temp_3 = level.mission.introTour -- 1118
	else -- 1118
		____temp_3 = nil -- 1118
	end -- 1118
	local tourDef = ____temp_3 -- 1118
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 1119
	local function finishIntroTour() -- 1121
		if not introTourActive then -- 1121
			return -- 1122
		end -- 1122
		introTourActive = false -- 1123
		introTourT = tourDuration -- 1124
		core.viewMode = "2D" -- 1125
		applyView() -- 1126
		deps.aim:setIntroTourBannerVisible(false) -- 1127
		print("[escape-velocity] intro tour completed -> enter 2D") -- 1128
	end -- 1121
	local function makeBasis(frame) -- 1131
		return prepareCamera({ -- 1132
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 1134
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 1135
			up = {x = 0, y = 1, z = 0}, -- 1136
			fovYDeg = deps.fovYDeg, -- 1137
			aspect = deps.aspect, -- 1138
			viewW = deps.viewW, -- 1139
			viewH = deps.viewH -- 1140
		}, HANDEDNESS, FLIP_Y) -- 1140
	end -- 1131
	local PredMinIntervalSec = 0.08 -- 1152
	local predAimKey = "" -- 1153
	local predPosKey = "" -- 1154
	local predAccum = 1 -- 1155
	local predForce = true -- 1156
	local predPoints = {} -- 1157
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 1159
	introTourActive = false -- 1161
	introTourT = tourDuration -- 1162
	local introLogged = false -- 1163
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1165
	local clock = 0 -- 1171
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1173
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1175
	local obsYawDeg = 0 -- 1179
	local obsPitchDeg = 0 -- 1180
	local obsZoom = 1 -- 1181
	local focusMode = "Auto" -- 1182
	local cineKey = "" -- 1183
	local cineFrame = nil -- 1184
	local cineFrom = nil -- 1185
	local cineTransition = 0 -- 1186
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1188
	local idleOrbit = nil -- 1190
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1201
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1203
	local lastSlowmoBody = -1 -- 1204
	local flightLogT = 0 -- 1205
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1207
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1208
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
	local function prepareIdle() -- 1223
		clock = 0 -- 1225
		core.t0 = 0 -- 1226
		idleOrbit = nil -- 1227
		if level.probeVel0 == nil then -- 1227
			return -- 1228
		end -- 1228
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1230
		if hostIndex < 0 then -- 1230
			return -- 1231
		end -- 1231
		local host = level.bodies[hostIndex + 1] -- 1232
		local hp = bodyPositionAt(host, 0) -- 1233
		local hv = bodyVelocityAt(host, 0) -- 1234
		local rx = level.probeStart.x - hp.x -- 1236
		local ry = level.probeStart.y - hp.y -- 1237
		local vx = level.probeVel0.x - hv.x -- 1238
		local vy = level.probeVel0.y - hv.y -- 1239
		local r = math.sqrt(rx * rx + ry * ry) -- 1240
		if r < 1e-12 then -- 1240
			return -- 1241
		end -- 1241
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1243
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1244
		idleOrbit = { -- 1245
			hostIndex = hostIndex, -- 1245
			r = r, -- 1245
			phase0 = math.atan(ry, rx), -- 1245
			omega = dir * omega -- 1245
		} -- 1245
	end -- 1223
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1249
		if idleOrbit == nil then -- 1249
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1251
		end -- 1251
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1256
		local hp = bodyPositionAt(host, tWorld) -- 1257
		local hv = bodyVelocityAt(host, tWorld) -- 1258
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1259
		local ca = math.cos(a) -- 1260
		local sa = math.sin(a) -- 1261
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1262
	end -- 1249
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1279
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1280
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1283
		local wps = goalWaypoints(level.goal) -- 1284
		if #wps == 0 then -- 1284
			return nil -- 1285
		end -- 1285
		local passed = 0 -- 1286
		if core.flight ~= nil then -- 1286
			local upto = math.floor(core.flightTime / core.dt) -- 1288
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
		if passed >= #wps then -- 1289
			return nil -- 1291
		end -- 1291
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1292
	end -- 1283
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1303
		if level.transfer ~= nil then -- 1303
			return { -- 1305
				pts = { -- 1305
					probe, -- 1305
					bodyPositionAt(level.bodies[1], t), -- 1305
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1305
					goalPositionAt(level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1305
				}, -- 1305
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1306
			} -- 1306
		end -- 1306
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1306
			local hr = anchorDef.radius -- 1311
			do -- 1311
				local i = 0 -- 1312
				while i < #level.bodies do -- 1312
					local b = level.bodies[i + 1] -- 1313
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1313
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1313
							hr = deps.visuals[i + 1].displayRadius -- 1315
						end -- 1315
						break -- 1316
					end -- 1316
					i = i + 1 -- 1312
				end -- 1312
			end -- 1312
			return { -- 1319
				pts = { -- 1319
					probe, -- 1319
					bodyPositionAt(anchorDef, t) -- 1319
				}, -- 1319
				radii = {deps.scene.probeRadius, hr} -- 1319
			} -- 1319
		end -- 1319
		local corePts = {probe} -- 1323
		local coreRadii = {deps.scene.probeRadius} -- 1324
		local next = nextStationBody() -- 1325
		local nextTol = 0 -- 1326
		if next ~= nil then -- 1326
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1328
			local wps = goalWaypoints(level.goal) -- 1329
			local passed = 0 -- 1330
			if core.flight ~= nil then -- 1330
				passed = waypointProgress( -- 1332
					core.flight.points, -- 1332
					level.bodies, -- 1332
					level.goal, -- 1332
					core.dt, -- 1332
					core.t0, -- 1332
					math.floor(core.flightTime / core.dt), -- 1332
					core.flight.velocities -- 1332
				).passed -- 1332
			end -- 1332
			if passed < #wps then -- 1332
				nextTol = wps[passed + 1].tolerance -- 1334
			end -- 1334
			local r = nextTol > next.radius and nextTol or next.radius -- 1335
			coreRadii[#coreRadii + 1] = r -- 1336
		end -- 1336
		if anchorDef == nil then -- 1336
			return {pts = corePts, radii = coreRadii} -- 1339
		end -- 1339
		local anchorR = anchorDef.radius -- 1344
		do -- 1344
			local i = 0 -- 1345
			while i < #level.bodies do -- 1345
				local b = level.bodies[i + 1] -- 1346
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1346
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1346
						anchorR = deps.visuals[i + 1].displayRadius -- 1348
					end -- 1348
					break -- 1349
				end -- 1349
				i = i + 1 -- 1345
			end -- 1345
		end -- 1345
		local withAnchorPts = { -- 1352
			probe, -- 1352
			bodyPositionAt(anchorDef, t) -- 1352
		} -- 1352
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1353
		do -- 1353
			local i = 1 -- 1354
			while i < #corePts do -- 1354
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1355
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1356
				i = i + 1 -- 1354
			end -- 1354
		end -- 1354
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1358
		if want <= CameraFramingBudget then -- 1358
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1359
		end -- 1359
		return {pts = corePts, radii = coreRadii} -- 1360
	end -- 1303
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1364
		local wps = goalWaypoints(level.goal) -- 1365
		if #wps == 0 then -- 1365
			return {} -- 1366
		end -- 1366
		local passed = 0 -- 1367
		if upto ~= nil and core.flight ~= nil then -- 1367
			passed = waypointProgress( -- 1369
				core.flight.points, -- 1369
				level.bodies, -- 1369
				level.goal, -- 1369
				core.dt, -- 1369
				core.t0, -- 1369
				upto, -- 1369
				core.flight.velocities -- 1369
			).passed -- 1369
		end -- 1369
		if level.transfer ~= nil and level.transfer.flyby ~= nil then -- 1369
			passed = 0 -- 1371
		end -- 1371
		if passed >= #wps then -- 1371
			return {} -- 1375
		end -- 1375
		local nextWp = wps[passed + 1] -- 1376
		local body = level.bodies[nextWp.planetIndex + 1] -- 1377
		if body == nil then -- 1377
			return {} -- 1378
		end -- 1378
		return {{ -- 1379
			center = goalPositionAt(body, t, nextWp.offset), -- 1379
			radius = nextWp.tolerance, -- 1379
			passed = false, -- 1379
			point = level.transfer ~= nil, -- 1380
			showRange = level.transfer == nil or aimed and (core.phase == "Aiming" or core.phase == "Armed"), -- 1380
			pulse = 1 + 0.1 * math.sin(t * 4) -- 1381
		}} -- 1381
	end -- 1364
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1385
		if level.transfer ~= nil and level.transfer.flyby == nil then -- 1385
			local basis = makeBasis(f) -- 1387
			local dx = f.eye.x - f.target.x -- 1388
			local dy = f.eye.y - f.target.y -- 1388
			local dz = f.eye.z - f.target.z -- 1388
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1389
			f = { -- 1390
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1390
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1391
			} -- 1391
		end -- 1391
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1391
			return f -- 1393
		end -- 1393
		local dx = f.eye.x - f.target.x -- 1394
		local dy = f.eye.y - f.target.y -- 1395
		local dz = f.eye.z - f.target.z -- 1396
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1397
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1398
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1399
		local lo = CameraTiltMin * math.pi / 180 -- 1400
		local hi = CameraTiltMax * math.pi / 180 -- 1401
		if pitch < lo then -- 1401
			pitch = lo -- 1402
		end -- 1402
		if pitch > hi then -- 1402
			pitch = hi -- 1403
		end -- 1403
		local cp = math.cos(pitch) -- 1404
		return { -- 1405
			target = f.target, -- 1406
			eye = Vec3( -- 1407
				f.target.x + r * cp * math.sin(yaw), -- 1408
				f.target.y + r * math.sin(pitch), -- 1409
				f.target.z + r * cp * math.cos(yaw) -- 1410
			) -- 1410
		} -- 1410
	end -- 1385
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1416
		local cfg = level.transfer.flyby -- 1417
		local autoShot = transferShotAt( -- 1418
			core.flightTime, -- 1418
			core.burnDuration, -- 1418
			core.flyby, -- 1418
			cfg, -- 1418
			core.dt -- 1418
		) -- 1418
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1419
		local key = (focusMode .. ":") .. shot -- 1420
		local earth = bodyPositionAt(level.bodies[1], t) -- 1421
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1422
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1423
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1424
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1425
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1426
		local moonAz = launchAz -- 1427
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1427
			local at = core.flyby.entryIndex -- 1429
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1430
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1432
		end -- 1432
		local pts = {pos} -- 1434
		local radii = {deps.scene.probeRadius} -- 1434
		local az = launchAz -- 1435
		local tilt = 28 -- 1435
		local minDist = 130 -- 1435
		if shot == "Cruise" then -- 1435
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 32 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 32 / vmag or 0)} -- 1437
			radii[#radii + 1] = 0 -- 1438
			minDist = 180 -- 1438
			tilt = 35 -- 1438
		elseif shot == "Moon" then -- 1438
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1440
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1441
			az = moonAz -- 1442
			tilt = 45 -- 1442
			minDist = 160 -- 1442
		elseif shot == "Earth" then -- 1442
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1444
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1445
			az = moonAz + 35 -- 1446
			tilt = 42 -- 1446
			minDist = 180 -- 1446
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1446
				local at = math.min( -- 1448
					#core.flight.points - 1, -- 1448
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1448
				) -- 1448
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1449
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1451
			end -- 1451
		elseif shot == "Overview" then -- 1451
			pts = {pos, earth, moon} -- 1454
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1454
			az = moonAz -- 1455
			tilt = 60 -- 1455
			minDist = 200 -- 1455
		end -- 1455
		if key ~= cineKey then -- 1455
			cineFrom = cineFrame -- 1458
			cineTransition = 0 -- 1459
			if cineKey == "" or shot == "Launch" then -- 1459
				cineFrom = nil -- 1461
			end -- 1461
			cineKey = key -- 1462
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1463
		end -- 1463
		local want = deps.rig.step( -- 1465
			pts, -- 1465
			deps.scene.probeRadius, -- 1465
			radii, -- 1465
			minDist, -- 1465
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1465
		) -- 1465
		local frame = want -- 1466
		if cineFrom ~= nil then -- 1466
			cineTransition = cineTransition + wallDt -- 1468
			local u = math.min(1, cineTransition / 0.6) -- 1469
			local k = u * u * (3 - 2 * u) -- 1470
			frame = { -- 1471
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1471
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1472
			} -- 1472
			if u >= 1 then -- 1472
				cineFrom = nil -- 1473
			end -- 1473
		end -- 1473
		cineFrame = frame -- 1475
		return applyObserve(frame) -- 1476
	end -- 1416
	local function resetCinematic() -- 1479
		focusMode = "Auto" -- 1480
		cineKey = "" -- 1480
		cineFrame = nil -- 1480
		cineFrom = nil -- 1480
		obsYawDeg = 0 -- 1481
		obsPitchDeg = 0 -- 1481
		obsZoom = 1 -- 1481
	end -- 1479
	local function updateAiming(dt) -- 1484
		if deps.plan.setBurn ~= nil then -- 1484
			deps.plan:setBurn(core.aim.velocity, false) -- 1485
		end -- 1485
		deps.aim:setEnabled(true) -- 1486
		local dragging = deps.aim:isDragging() -- 1488
		local clockFrozen = dragging or core.phase == "Armed" or level.transfer ~= nil and level.transfer.flyby ~= nil and introTourActive -- 1493
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1493
			local rate = core.playback * (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1) -- 1504
			clock = clock + dt * rate -- 1505
			orbitClock = orbitClock + dt * rate -- 1506
		end -- 1506
		local tNow = core.t0 + clock -- 1508
		local idleState = idleProbeAt(tNow) -- 1510
		probePos = idleState.pos -- 1511
		probeVel = idleState.vel -- 1512
		deps.scene.syncBodies(tNow) -- 1514
		if deps.scene.syncStars ~= nil then -- 1514
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1515
		end -- 1515
		deps.scene.syncProbe(probePos) -- 1516
		if idleOrbit ~= nil then -- 1516
			deps.scene.faceVelocity(probeVel) -- 1517
		end -- 1517
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1519
		deps.plan:syncProbe(probePos, probeVel) -- 1520
		if not aimed and #core.stars > 0 then -- 1520
			deps.plan:setStars( -- 1522
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1522
				core.collectedStars -- 1522
			) -- 1522
		end -- 1522
		local fr = framingPoints(probePos, tNow) -- 1526
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1527
		if frameLogged < 6 then -- 1527
			frameLogged = frameLogged + 1 -- 1531
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1532
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1536
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1537
				__TS__ArrayMap( -- 1543
					fr.pts, -- 1543
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1543
				), -- 1543
				" " -- 1543
			)) .. "]") -- 1543
		end -- 1543
		if introTourActive and introTourT < tourDuration then -- 1543
			introTourT = introTourT + dt -- 1547
			local k = introTourT / tourDuration -- 1548
			if k >= 1 then -- 1548
				finishIntroTour() -- 1550
			else -- 1550
				if k >= 0.95 and not introLogged then -- 1550
					introLogged = true -- 1553
					print("[escape-velocity] intro camera finishing") -- 1554
				end -- 1554
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1554
					local elapsed = introTourT -- 1558
					local segIndex = 0 -- 1559
					local segStart = 0 -- 1560
					do -- 1560
						local s = 0 -- 1561
						while s < #tourDef.segments do -- 1561
							local seg = tourDef.segments[s + 1] -- 1562
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1562
								segIndex = s -- 1564
								break -- 1565
							end -- 1565
							elapsed = elapsed - seg.duration -- 1567
							segStart = segStart + seg.duration -- 1568
							s = s + 1 -- 1561
						end -- 1561
					end -- 1561
					local curSeg = tourDef.segments[segIndex + 1] -- 1570
					local segK = math.max( -- 1571
						0, -- 1571
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1571
					) -- 1571
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1573
					deps.aim:setIntroTourBannerVisible(true) -- 1574
					local pwProbe = planeToWorld(probePos, 0) -- 1576
					local function getTargetPosAndDist(targetIdx, userDist) -- 1577
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1577
							local b = level.bodies[targetIdx + 1] -- 1579
							local isMicro = b.orbitRadius < 2 -- 1580
							local p = planeToWorld( -- 1581
								bodyPositionAt(b, tNow), -- 1581
								0 -- 1581
							) -- 1581
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1582
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1583
						end -- 1583
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1585
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1586
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1587
					end -- 1577
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1590
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1591
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1592
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1594
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1595
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1596
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1597
					if segIndex == 0 then -- 1597
						local az = curAz + segK * (18 * math.pi / 180) -- 1601
						local tilt = curTilt -- 1602
						local d = curKey.dist -- 1603
						local eye = Vec3( -- 1604
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1605
							curKey.pos.y + math.sin(tilt) * d, -- 1606
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1607
						) -- 1607
						frame = {target = curKey.pos, eye = eye} -- 1609
					else -- 1609
						local ease = segK * segK * (3 - 2 * segK) -- 1612
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1613
						local az = prevAz + (curAz - prevAz) * ease -- 1618
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1619
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1620
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1621
						local eye = Vec3( -- 1622
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1623
							target.y + math.sin(tilt) * d, -- 1624
							target.z + math.cos(az) * math.cos(tilt) * d -- 1625
						) -- 1625
						frame = {target = target, eye = eye} -- 1627
					end -- 1627
				else -- 1627
					local targetBody = nil -- 1630
					local wps = goalWaypoints(level.goal) -- 1631
					if #wps > 0 then -- 1631
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1633
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1633
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1635
					end -- 1635
					if targetBody == nil and #level.bodies > 0 then -- 1635
						targetBody = level.bodies[#level.bodies] -- 1638
					end -- 1638
					if targetBody ~= nil then -- 1638
						local pwTarget = planeToWorld( -- 1642
							bodyPositionAt(targetBody, tNow), -- 1642
							0 -- 1642
						) -- 1642
						local pwProbe = planeToWorld(probePos, 0) -- 1643
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1644
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1645
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1646
						if k < 0.35 then -- 1646
							local e1 = k / 0.35 -- 1649
							local az = (0.2 + e1 * 0.15) * math.pi -- 1650
							local tilt = 0.35 * math.pi -- 1651
							local eye = Vec3( -- 1652
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1653
								pwTarget.y + math.sin(tilt) * distTarget, -- 1654
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1655
							) -- 1655
							frame = {target = pwTarget, eye = eye} -- 1657
						elseif k < 0.72 then -- 1657
							local e2 = (k - 0.35) / 0.37 -- 1659
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1660
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1661
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1662
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1663
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1664
							local eye = Vec3( -- 1669
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1670
								targetCenter.y + curDist * 0.8, -- 1671
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1672
							) -- 1672
							frame = {target = targetCenter, eye = eye} -- 1674
						else -- 1674
							local e3 = (k - 0.72) / 0.28 -- 1676
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1677
							local az = 0.25 * math.pi -- 1678
							local tilt = 0.36 * math.pi -- 1679
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1680
							local eye = Vec3( -- 1681
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1682
								pwProbe.y + math.sin(tilt) * curDist, -- 1683
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1684
							) -- 1684
							frame = {target = pwProbe, eye = eye} -- 1686
						end -- 1686
					end -- 1686
				end -- 1686
			end -- 1686
		end -- 1686
		frame = applyObserve(frame) -- 1693
		deps.rig.apply(deps.camera, frame) -- 1694
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1695
		local basis = makeBasis(frame) -- 1696
		if core.viewMode == "2D" then -- 1696
			local sp = deps.plan:probeScreen() -- 1702
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1703
		else -- 1703
			local pp = projectPrepared( -- 1705
				planeToWorld(probePos, 0), -- 1705
				basis -- 1705
			) -- 1705
			if pp ~= nil then -- 1705
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1706
			end -- 1706
		end -- 1706
		if not aimed then -- 1706
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1706
				deps.aim:setTransferInfo( -- 1716
					distance( -- 1716
						probePos, -- 1716
						bodyPositionAt(level.bodies[1], tNow) -- 1716
					) - level.bodies[1].radius, -- 1716
					0 -- 1716
				) -- 1716
			end -- 1716
			deps.trajectory:clearPrediction() -- 1720
			deps.plan:clearPrediction() -- 1721
			predForce = true -- 1722
		else -- 1722
			local aimKey = (((__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4)) .. "|") .. (core.brakeMode and "B" or "C") -- 1728
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1729
			predAccum = predAccum + dt -- 1730
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1731
			if needIt then -- 1731
				predForce = false -- 1733
				predAccum = 0 -- 1734
				predAimKey = aimKey -- 1735
				predPosKey = posKey -- 1736
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, level.transfer == nil and core.brakeMode, level.maxSteps) -- 1739
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 1740
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1743
					dt = core.dt, -- 1743
					sampleEvery = 4, -- 1743
					escapeRadius = level.escapeRadius, -- 1743
					t0 = tNow, -- 1743
					brake = motion.brake -- 1743
				}) -- 1743
				predPoints = sim.points -- 1745
				if level.transfer ~= nil then -- 1745
					local analysis = level.transfer.flyby ~= nil and analyzeFlyby( -- 1747
						sim, -- 1747
						level.bodies[1], -- 1747
						level.bodies[level.goal.planetIndex + 1], -- 1747
						level.transfer.flyby, -- 1747
						core.dt * 4, -- 1747
						tNow -- 1747
					) or nil -- 1747
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1748
						sim.points, -- 1748
						level.bodies, -- 1748
						level.goal, -- 1748
						core.dt * 4, -- 1748
						tNow, -- 1748
						sim.velocities -- 1748
					) -- 1748
					if analysis ~= nil then -- 1748
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1749
					elseif gi >= 0 then -- 1749
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1750
					end -- 1750
					local radius = distance( -- 1751
						probePos, -- 1751
						bodyPositionAt(level.bodies[1], tNow) -- 1751
					) -- 1751
					local plan = planTransfer( -- 1752
						level.bodies[1].gm, -- 1752
						radius, -- 1752
						probeVel, -- 1752
						core.aim.power, -- 1752
						level.transfer.apoapsisMax -- 1752
					) -- 1752
					if deps.aim.setTransferInfo ~= nil then -- 1752
						deps.aim:setTransferInfo(plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1753
					end -- 1753
				end -- 1753
				predTimes = {} -- 1755
				do -- 1755
					local pi = 0 -- 1756
					while pi < #predPoints do -- 1756
						predTimes[#predTimes + 1] = tNow + pi * core.dt * 4 -- 1756
						pi = pi + 1 -- 1756
					end -- 1756
				end -- 1756
			end -- 1756
			deps.trajectory:setPrediction(predPoints, basis) -- 1758
			deps.plan:setPrediction(predPoints) -- 1760
			if #core.stars > 0 then -- 1760
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1763
				local stEval = evaluateCollectedStars( -- 1764
					predPoints, -- 1764
					core.stars, -- 1764
					30, -- 1764
					core.starOrbits, -- 1764
					predTimes -- 1764
				) -- 1764
				core.previewStarsCount = stEval.count -- 1765
				deps.plan:setStars(live, stEval.collected) -- 1766
			end -- 1766
		end -- 1766
		if idleOrbit ~= nil then -- 1766
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1771
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1772
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1773
		end -- 1773
		local rings = goalRingsAt(tNow) -- 1775
		deps.trajectory:setGoalRings(rings, basis) -- 1776
		deps.trajectory:clearTrail() -- 1777
		deps.plan:setGoalRings(rings) -- 1779
		deps.plan:clearTrail() -- 1780
		deps.plan:flush() -- 1781
	end -- 1484
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
	local function updateFinale() -- 1796
		deps.aim:setEnabled(false) -- 1797
		if core.flight == nil then -- 1797
			return -- 1798
		end -- 1798
		local idx = ____exports.coreProbeIndex(core) -- 1799
		local pos = core.flight.points[idx + 1] -- 1800
		local tWorld = core.t0 + core.flightTime -- 1801
		deps.scene.syncBodies(tWorld) -- 1804
		deps.scene.syncProbe(pos) -- 1805
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1806
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1809
		deps.camera:lookAt( -- 1810
			frame.eye, -- 1810
			frame.target, -- 1810
			Vec3(0, 1, 0) -- 1810
		) -- 1810
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1811
		local trail = {} -- 1814
		do -- 1814
			local i = 0 -- 1815
			while i <= idx do -- 1815
				trail[#trail + 1] = core.flight.points[i + 1] -- 1815
				i = i + 1 -- 1815
			end -- 1815
		end -- 1815
		local rings = goalRingsAt(tWorld, idx) -- 1816
		local basis = makeBasis(frame) -- 1817
		if deps.trajectory.setBurn ~= nil then -- 1817
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1819
		end -- 1819
		deps.trajectory:clearOrbitRing() -- 1820
		deps.plan:clearProbeOrbit() -- 1821
		deps.trajectory:setTrail(trail, basis) -- 1822
		deps.trajectory:setGoalRings(rings, basis) -- 1823
		deps.plan:clearPrediction() -- 1824
		deps.plan:setGoalRings(rings) -- 1825
		deps.plan:flush() -- 1826
	end -- 1796
	local function updateFlying(dt) -- 1828
		deps.aim:setEnabled(false) -- 1829
		local wasCompleted = core.missionCompleted -- 1832
		local entered = ____exports.coreUpdate(core, dt, level) -- 1833
		if not wasCompleted and core.missionCompleted then -- 1833
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1835
			if deps.onMissionCompleted ~= nil then -- 1835
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1836
			end -- 1836
		end -- 1836
		if core.flight == nil then -- 1836
			return entered -- 1838
		end -- 1838
		local idx = ____exports.coreProbeIndex(core) -- 1840
		local pos = core.flight.points[idx + 1] -- 1841
		local tWorld = core.t0 + core.flightTime -- 1845
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1845
			lastSlowmo = core.slowmo -- 1849
			lastSlowmoBody = core.slowmoBody -- 1850
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1851
			local nearD = near ~= nil and distance( -- 1852
				pos, -- 1852
				bodyPositionAt(near, tWorld) -- 1852
			) or 0 -- 1852
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1853
		end -- 1853
		flightLogT = flightLogT + dt -- 1860
		if flightLogT >= 0.5 then -- 1860
			flightLogT = 0 -- 1862
			local total = (#core.flight.points - 1) * core.dt -- 1863
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1864
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1866
					core.flightTime, -- 1866
					core.burnDuration, -- 1866
					level.transfer, -- 1866
					core.flyby, -- 1866
					core.dt -- 1866
				) or (core.slowmo and SlowMoFactor or 1)), -- 1866
				2 -- 1866
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1866
		end -- 1866
		deps.scene.syncBodies(tWorld) -- 1870
		if deps.scene.syncStars ~= nil then -- 1870
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1871
		end -- 1871
		deps.scene.syncProbe(pos) -- 1872
		if idx > 0 then -- 1872
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1874
		end -- 1874
		do -- 1874
			local s = 0 -- 1878
			while s < #core.stars do -- 1878
				if not core.collectedStars[s + 1] then -- 1878
					local fromLevel = level.starOrbits -- 1880
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1881
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1882
					local dx = pos.x - stPos.x -- 1883
					local dy = pos.y - stPos.y -- 1884
					if dx * dx + dy * dy <= 30 * 30 then -- 1884
						core.collectedStars[s + 1] = true -- 1886
						if deps.scene.setStarCollected ~= nil then -- 1886
							deps.scene.setStarCollected(s) -- 1888
						end -- 1888
						deps.plan:setStars(core.stars, core.collectedStars) -- 1890
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1891
					end -- 1891
				end -- 1891
				s = s + 1 -- 1878
			end -- 1878
		end -- 1878
		local fr -- 1900
		local closeDist = nil -- 1901
		if core.slowmo and core.slowmoBody >= 0 then -- 1901
			local near = level.bodies[core.slowmoBody + 1] -- 1903
			local nearR = near.radius -- 1905
			do -- 1905
				local i = 0 -- 1906
				while i < #level.bodies do -- 1906
					local b = level.bodies[i + 1] -- 1907
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1907
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1907
							nearR = deps.visuals[i + 1].displayRadius -- 1909
						end -- 1909
						break -- 1910
					end -- 1910
					i = i + 1 -- 1906
				end -- 1906
			end -- 1906
			fr = { -- 1913
				pts = { -- 1913
					pos, -- 1913
					bodyPositionAt(near, tWorld) -- 1913
				}, -- 1913
				radii = {deps.scene.probeRadius, nearR} -- 1913
			} -- 1913
			closeDist = SlowMoCloseDist -- 1914
		else -- 1914
			fr = framingPoints(pos, tWorld) -- 1916
		end -- 1916
		local baseFrame = level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist) -- 1918
		local frame = level.transfer ~= nil and level.transfer.flyby == nil and applyObserve(baseFrame) or baseFrame -- 1919
		deps.rig.apply(deps.camera, frame) -- 1920
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1921
		local basis = makeBasis(frame) -- 1922
		if deps.trajectory.setBurn ~= nil then -- 1922
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1925
		end -- 1925
		if deps.plan.setBurn ~= nil then -- 1925
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1926
		end -- 1926
		local trail = {} -- 1927
		do -- 1927
			local i = 0 -- 1928
			while i <= idx do -- 1928
				trail[#trail + 1] = core.flight.points[i + 1] -- 1928
				i = i + 1 -- 1928
			end -- 1928
		end -- 1928
		local rings = goalRingsAt(tWorld, idx) -- 1929
		deps.trajectory:clearOrbitRing() -- 1931
		deps.plan:clearProbeOrbit() -- 1932
		deps.trajectory:setTrail(trail, basis) -- 1933
		deps.trajectory:setGoalRings(rings, basis) -- 1934
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1937
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1938
		deps.plan:setStars( -- 1939
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 1939
			core.collectedStars -- 1939
		) -- 1939
		deps.plan:setTrail(trail) -- 1940
		deps.plan:clearPrediction() -- 1941
		deps.plan:setGoalRings(rings) -- 1942
		deps.plan:flush() -- 1943
		return entered -- 1945
	end -- 1828
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1959
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1960
		core.t0 = next.t0 -- 1961
		clock = next.clock -- 1962
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1963
	end -- 1959
	local function finishFlight() -- 1966
		if core.result == nil then -- 1966
			return -- 1967
		end -- 1967
		local toFinale = deps.finale == true and core.result == "success" -- 1968
		if toFinale then -- 1968
			____exports.coreEnterFinale(core) -- 1969
		end -- 1969
		deps:onResult( -- 1970
			core.result, -- 1970
			____exports.calcFlightTelemetry(core, level) -- 1970
		) -- 1970
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1970
			local ____end = #core.flight.points - 1 -- 1972
			deps:onFinale({ -- 1973
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1973
				time = core.flightTime, -- 1973
				tWorld = core.t0 + core.flightTime -- 1973
			}) -- 1973
		end -- 1973
		deps:onPhase(toFinale and "Finale" or "Result") -- 1975
	end -- 1966
	local function update(dt) -- 1978
		applyView() -- 1981
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1981
			updateAiming(dt) -- 1983
		elseif core.phase == "Flying" then -- 1983
			local entered = updateFlying(dt) -- 1985
			if entered then -- 1985
				finishFlight() -- 1986
			end -- 1986
		elseif core.phase == "Finale" then -- 1986
			updateFinale() -- 1988
		end -- 1988
	end -- 1978
	return { -- 1993
		phase = function() return core.phase end, -- 1994
		speedPow = function() return speedPow end, -- 1995
		speedMaxPow = function() return speedMaxPow end, -- 1996
		isPaused = function() return paused end, -- 1997
		speedRate = function() -- 1998
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 1998
				return core.playback * transferPlaybackRate( -- 1999
					core.flightTime, -- 1999
					core.burnDuration, -- 1999
					level.transfer, -- 1999
					core.flyby, -- 1999
					core.dt -- 1999
				) -- 1999
			end -- 1999
			return core.playback * (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1) -- 2000
		end, -- 1998
		missionSeconds = function() -- 2002
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 2003
			return speedUnit > 0 and w / speedUnit or 0 -- 2004
		end, -- 2002
		speedUp = function() -- 2006
			if speedPow >= speedMaxPow then -- 2006
				return -- 2007
			end -- 2007
			speedPow = speedPow + 1 -- 2008
			paused = false -- 2009
			applySpeedRate() -- 2010
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2011
		end, -- 2006
		speedDown = function() -- 2013
			if speedPow <= 0 then -- 2013
				return -- 2014
			end -- 2014
			speedPow = speedPow - 1 -- 2015
			paused = false -- 2016
			applySpeedRate() -- 2017
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 2018
		end, -- 2013
		togglePause = function() -- 2020
			paused = not paused -- 2021
			applySpeedRate() -- 2022
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 2023
		end, -- 2020
		result = function() return core.result end, -- 2025
		onAimDrag = function(____, a) -- 2026
			if introTourActive then -- 2026
				finishIntroTour() -- 2027
			end -- 2027
			core.aim = a -- 2028
			if level.transfer ~= nil then -- 2028
				local radius = distance( -- 2030
					probePos, -- 2030
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 2030
				) -- 2030
				local plan = planTransfer( -- 2031
					level.bodies[1].gm, -- 2031
					radius, -- 2031
					probeVel, -- 2031
					a.power, -- 2031
					level.transfer.apoapsisMax -- 2031
				) -- 2031
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 2032
				if deps.aim.setTransferInfo ~= nil then -- 2032
					deps.aim:setTransferInfo(plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 2033
				end -- 2033
			end -- 2033
			aimed = true -- 2035
		end, -- 2026
		aimReady = function() -- 2037
			predForce = true -- 2039
			if not ____exports.coreArm(core) then -- 2039
				return -- 2040
			end -- 2040
			if level.transfer ~= nil then -- 2040
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 2041
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 2041
					4 -- 2041
				)) -- 2041
			end -- 2041
			applyView() -- 2042
			deps:onPhase("Armed") -- 2043
		end, -- 2037
		cancelAim = function() -- 2045
			if not ____exports.coreCancelArm(core) then -- 2045
				return -- 2046
			end -- 2046
			aimed = false -- 2047
			predForce = true -- 2048
			deps.trajectory:clearPrediction() -- 2049
			deps.plan:clearPrediction() -- 2050
			applyView() -- 2051
			deps:onPhase("Aiming") -- 2052
			print("[escape-velocity] aim cancelled") -- 2053
		end, -- 2045
		launchArmed = function() -- 2055
			if core.phase ~= "Armed" then -- 2055
				return -- 2057
			end -- 2057
			resetCinematic() -- 2058
			applyFlightSpeed() -- 2059
			handoffDate(true) -- 2060
			____exports.coreLaunch( -- 2061
				core, -- 2061
				core.aim.velocity, -- 2061
				level, -- 2061
				probePos, -- 2061
				probeVel -- 2061
			) -- 2061
			deps.trajectory:clearPrediction() -- 2062
			deps.plan:clearPrediction() -- 2063
			applyView() -- 2064
			deps:onPhase("Flying") -- 2065
		end, -- 2055
		armed = function() return core.phase == "Armed" end, -- 2067
		viewMode = function() return core.viewMode end, -- 2068
		toggleViewMode = function() -- 2069
			____exports.coreToggleView(core) -- 2071
			applyView() -- 2072
		end, -- 2069
		cameraFocus = function() return focusMode end, -- 2074
		flightStage = function() return level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 2075
			core.flightTime, -- 2076
			core.burnDuration, -- 2076
			core.flyby, -- 2076
			level.transfer.flyby, -- 2076
			core.dt -- 2076
		) or nil end, -- 2076
		cycleCameraFocus = function() -- 2077
			if level.transfer == nil or level.transfer.flyby == nil or core.phase ~= "Flying" then -- 2077
				return -- 2078
			end -- 2078
			focusMode = nextCameraFocus(focusMode) -- 2079
			obsYawDeg = 0 -- 2080
			obsPitchDeg = 0 -- 2080
			obsZoom = 1 -- 2080
			print("[escape-velocity] camera focus -> " .. focusMode) -- 2081
		end, -- 2077
		missionCompleted = function() return core.missionCompleted end, -- 2083
		endViewing = function() -- 2084
			if not ____exports.coreEndViewing(core) then -- 2084
				return -- 2085
			end -- 2085
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 2086
			finishFlight() -- 2087
		end, -- 2084
		skipIntroTour = function() -- 2089
			finishIntroTour() -- 2090
		end, -- 2089
		isIntroTourActive = function() return introTourActive end, -- 2092
		observeDrag = function(____, dx, dy) -- 2093
			if introTourActive then -- 2093
				finishIntroTour() -- 2095
				return -- 2096
			end -- 2096
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2098
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2099
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2100
			if obsPitchDeg > 40 then -- 2100
				obsPitchDeg = 40 -- 2101
			end -- 2101
			if obsPitchDeg < -40 then -- 2101
				obsPitchDeg = -40 -- 2102
			end -- 2102
		end, -- 2093
		observeZoom = function(____, deltaDist) -- 2104
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2105
			if obsZoom < 0.4 then -- 2105
				obsZoom = 0.4 -- 2106
			end -- 2106
			if obsZoom > 1.8 then -- 2106
				obsZoom = 1.8 -- 2107
			end -- 2107
		end, -- 2104
		launch = function(____, v) -- 2109
			applyFlightSpeed() -- 2110
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2110
				return -- 2111
			end -- 2111
			resetCinematic() -- 2112
			handoffDate(true) -- 2113
			____exports.coreLaunch( -- 2115
				core, -- 2115
				v, -- 2115
				level, -- 2115
				probePos, -- 2115
				probeVel -- 2115
			) -- 2115
			deps.trajectory:clearPrediction() -- 2116
			deps.plan:clearPrediction() -- 2117
			applyView() -- 2118
			deps:onPhase("Flying") -- 2119
		end, -- 2109
		retry = function() -- 2121
			resetCinematic() -- 2122
			handoffDate(false) -- 2123
			aimed = false -- 2124
			introTourActive = false -- 2125
			____exports.coreRetry(core, level.aimMin) -- 2126
			if deps.scene.resetStars ~= nil then -- 2126
				deps.scene.resetStars() -- 2128
			end -- 2128
			deps.plan:setStars(core.stars, core.collectedStars) -- 2130
			deps.trajectory:clearTrail() -- 2131
			deps.trajectory:clearPrediction() -- 2132
			deps.trajectory:clearGoalRings() -- 2133
			deps.plan:clearTrail() -- 2134
			deps.plan:clearPrediction() -- 2135
			deps.plan:clearGoalRings() -- 2136
			applyView() -- 2137
			deps:onPhase("Aiming") -- 2138
		end, -- 2121
		backToSelect = function() -- 2140
			if not ____exports.coreBackToSelect(core) then -- 2140
				return false -- 2141
			end -- 2141
			deps.aim:setEnabled(false) -- 2143
			deps.trajectory:clearTrail() -- 2144
			deps.trajectory:clearPrediction() -- 2145
			deps.trajectory:clearGoalRings() -- 2146
			deps.plan:clearTrail() -- 2147
			deps.plan:clearPrediction() -- 2148
			deps.plan:clearGoalRings() -- 2149
			applyView() -- 2150
			deps:onPhase("LevelSelect") -- 2151
			return true -- 2152
		end, -- 2140
		startLevel = function() -- 2154
			resetCinematic() -- 2155
			aimed = false -- 2156
			____exports.coreRetry(core, level.aimMin) -- 2157
			if deps.scene.resetStars ~= nil then -- 2157
				deps.scene.resetStars() -- 2159
			end -- 2159
			deps.plan:setStars(core.stars, core.collectedStars) -- 2161
			deps.rig.reset() -- 2162
			introTourActive = false -- 2164
			core.viewMode = "2D" -- 2165
			appliedMode = "" -- 2166
			applyView() -- 2167
			prepareIdle() -- 2168
			deps.trajectory:clearTrail() -- 2169
			deps.trajectory:clearPrediction() -- 2170
			deps.trajectory:clearGoalRings() -- 2171
			deps.plan:clearTrail() -- 2172
			deps.plan:clearPrediction() -- 2173
			deps.plan:clearGoalRings() -- 2174
			deps:onPhase("Aiming") -- 2175
		end, -- 2154
		stepTime = function(____, dir, span) -- 2177
			if not ____exports.coreTimeWarpAllowed(core) then -- 2177
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2181
				return -- 2182
			end -- 2182
			local span0 = span > 0 and span or 0 -- 2184
			clock = clock + dir * TimeWarpStep -- 2185
			if clock < 0 then -- 2185
				clock = 0 -- 2186
			end -- 2186
			if span0 > 0 and clock > span0 then -- 2186
				clock = span0 -- 2187
			end -- 2187
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2189
		end, -- 2177
		dateNow = function() return core.t0 + clock end, -- 2191
		setBrakeMode = function(____, on) -- 2192
			core.brakeMode = on -- 2193
		end, -- 2192
		brakeMode = function() return core.brakeMode end, -- 2196
		setPlaybackSpeed = function(____, speed) -- 2197
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2197
				return -- 2199
			end -- 2199
			core.playback = speed -- 2200
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2201
		end, -- 2197
		playbackSpeed = function() return core.playback end, -- 2203
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2204
		starsNow = function() -- 2205
			if core.phase == "Flying" or core.phase == "Result" then -- 2205
				local n = 0 -- 2207
				do -- 2207
					local i = 0 -- 2208
					while i < #core.collectedStars do -- 2208
						if core.collectedStars[i + 1] then -- 2208
							n = n + 1 -- 2208
						end -- 2208
						i = i + 1 -- 2208
					end -- 2208
				end -- 2208
				return n -- 2209
			end -- 2209
			return core.previewStarsCount -- 2211
		end, -- 2205
		isBrakeWindowActive = function() return ____exports.isBrakeWindowActive(core, level) end, -- 2213
		applyInFlightBrake = function() return ____exports.applyInFlightBrake(core, level) end, -- 2214
		hasBraked = function() return core.hasBraked end, -- 2215
		update = function(____, frameDt) return update(frameDt) end -- 2217
	} -- 2217
end -- 1050
return ____exports -- 1050
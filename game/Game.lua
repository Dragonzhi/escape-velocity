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
function ____exports.speedRateOf(pow, gameSecPerRealSec) -- 218
	local rate = gameSecPerRealSec > 0 and gameSecPerRealSec or 1 -- 219
	local n = math.floor(pow) -- 220
	while n > 0 do -- 220
		rate = rate * 10 -- 222
		n = n - 1 -- 223
	end -- 223
	while n < 0 do -- 223
		rate = rate / 10 -- 226
		n = n + 1 -- 227
	end -- 227
	return rate -- 229
end -- 218
local function neutralAim(minSpeed) -- 232
	return {velocity = {x = 0, y = -minSpeed}, power = 0, unit = {x = 0, y = -1}} -- 233
end -- 232
--- 这一关的瞄准力度下限（省略 = 全局 AimMinSpeed）。
local function levelAimMin(aimMin) -- 237
	return aimMin ~= nil and aimMin >= 0 and aimMin or AimMinSpeed -- 238
end -- 237
--- 星尘在时刻 t 的位置（没有轨道就用静态坐标）。
local function starPositionsNow(orbits, fallback, t) -- 242
	local out = {} -- 243
	do -- 243
		local i = 0 -- 244
		while i < #fallback do -- 244
			local orbit = i < #orbits and orbits[i + 1] or nil -- 245
			out[#out + 1] = starPositionAt(orbit, fallback[i + 1], t) -- 246
			i = i + 1 -- 244
		end -- 244
	end -- 244
	return out -- 248
end -- 242
function ____exports.createCore(dt, stars, starOrbits) -- 251
	local stList = stars ~= nil and stars or ({}) -- 252
	local colList = {} -- 253
	do -- 253
		local i = 0 -- 254
		while i < #stList do -- 254
			colList[#colList + 1] = false -- 254
			i = i + 1 -- 254
		end -- 254
	end -- 254
	local orbits = starOrbits ~= nil and starOrbits or ({}) -- 255
	return { -- 256
		phase = "Aiming", -- 257
		aim = neutralAim(AimMinSpeed), -- 258
		flight = nil, -- 259
		dt = dt ~= nil and dt > 0 and dt or PhysicsStep, -- 260
		burnDuration = 0, -- 261
		t0 = 0, -- 262
		flightTime = 0, -- 263
		missionCompleted = false, -- 264
		flyby = nil, -- 265
		goalIndex = -1, -- 266
		result = nil, -- 267
		viewMode = "2D", -- 269
		playback = FlightPlayback, -- 271
		slowmo = false, -- 272
		slowmoBody = -1, -- 273
		stars = stList, -- 274
		starOrbits = orbits, -- 275
		collectedStars = colList, -- 276
		previewStarsCount = 0 -- 277
	} -- 277
end -- 251
--- 手动切换 2D/3D（右下角那颗按钮的唯一入口，S3.15）。
-- 
-- ⚠️ 按钮**不许自己翻转一个局部变量** —— 视图的唯一事实来源是 `GameCore.viewMode`，
-- 否则"按钮显示的"与"画出来的"迟早会分家（会话 38 那次"点了重试没反应"就是同一类根因）。
-- 
-- @returns 切换后的新视图（调用方据此同步按钮文字）。
function ____exports.coreToggleView(core) -- 289
	core.viewMode = core.viewMode == "2D" and "3D" or "2D" -- 290
	return core.viewMode -- 291
end -- 289
--- 教学关显式指定中心宿主；旧关卡仍按最近的有引力天体选择。
function ____exports.selectIdleHost(bodies, start, preferred) -- 295
	if preferred ~= nil and bodies[preferred + 1] ~= nil and bodies[preferred + 1].gm > 0 then -- 295
		return preferred -- 296
	end -- 296
	local index = -1 -- 297
	local nearest = 1000000000 -- 298
	do -- 298
		local i = 0 -- 299
		while i < #bodies do -- 299
			do -- 299
				if bodies[i + 1].gm <= 0 then -- 299
					goto __continue22 -- 300
				end -- 300
				local d = distance( -- 301
					bodyPositionAt(bodies[i + 1], 0), -- 301
					start -- 301
				) -- 301
				if d < nearest then -- 301
					nearest = d -- 302
					index = i -- 302
				end -- 302
			end -- 302
			::__continue22:: -- 302
			i = i + 1 -- 299
		end -- 299
	end -- 299
	return index -- 304
end -- 295
--- 预测线与瞬时点火的初始速度。教学关实际发射另行积分有限燃烧。
function ____exports.burnToMotion(burn, probeVel0) -- 308
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 309
	return {x = v0.x + burn.x, y = v0.y + burn.y} -- 310
end -- 308
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 319
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 319
		return -- 321
	end -- 321
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 322
	local motion = ____exports.burnToMotion(burn, base) -- 323
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 324
	core.burnDuration = level.transfer ~= nil and mag / level.transfer.thrustAcceleration or 0 -- 325
	local thrust = core.burnDuration > 0 and ({acceleration = {x = burn.x / core.burnDuration, y = burn.y / core.burnDuration}, duration = core.burnDuration}) or nil -- 326
	local p0 = from ~= nil and from or level.probeStart -- 327
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = level.transfer ~= nil and base ~= nil and base or motion}, level.bodies, { -- 328
		steps = level.maxSteps, -- 331
		dt = core.dt, -- 331
		sampleEvery = 1, -- 331
		escapeRadius = level.escapeRadius, -- 331
		t0 = core.t0, -- 331
		initialBurn = thrust -- 331
	}) -- 331
	core.flight = flight -- 333
	core.missionCompleted = false -- 334
	local ____core_1 = core -- 335
	local ____temp_0 -- 335
	if level.transfer ~= nil then -- 335
		____temp_0 = analyzeTransfer( -- 335
			flight, -- 335
			level.bodies, -- 335
			level.goal.planetIndex, -- 335
			level.transfer, -- 335
			core.dt, -- 335
			core.t0 -- 335
		) -- 335
	else -- 335
		____temp_0 = nil -- 335
	end -- 335
	____core_1.flyby = ____temp_0 -- 335
	core.goalIndex = core.flyby ~= nil and core.flyby.completionIndex or findGoalIndex( -- 336
		flight.points, -- 336
		level.bodies, -- 336
		level.goal, -- 336
		core.dt, -- 336
		core.t0, -- 336
		flight.velocities -- 336
	) -- 336
	local ____core_3 = core -- 337
	local ____temp_2 -- 337
	if core.flyby ~= nil and core.goalIndex >= 0 then -- 337
		____temp_2 = nil -- 337
	else -- 337
		____temp_2 = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 337
	end -- 337
	____core_3.result = ____temp_2 -- 337
	if core.flyby ~= nil then -- 337
		print((((((((((("[escape-velocity] flyby planned entry=" .. __TS__NumberToFixed(core.flyby.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(core.flyby.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(core.flyby.exitIndex, 0)) .. " energyDrop=") .. __TS__NumberToFixed(core.flyby.energyDrop, 2)) .. " complete=") .. __TS__NumberToFixed(core.flyby.completionIndex, 0)) .. " end=") .. __TS__NumberToFixed(core.flyby.viewEndIndex, 0)) -- 338
	end -- 338
	if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 338
		for ____, e in ipairs(core.flyby.encounters) do -- 341
			print((((((((("[escape-velocity] encounter body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " energy=") .. __TS__NumberToFixed(e.energyChange, 2)) .. " work=") .. __TS__NumberToFixed(e.work, 2)) .. " passed=") .. (e.passed and "1" or "0")) -- 341
		end -- 341
	end -- 341
	if core.flyby ~= nil and core.flyby.destination ~= nil then -- 341
		local e = core.flyby.destination -- 343
		print((((((((("[escape-velocity] destination body=" .. __TS__NumberToFixed(e.planetIndex, 0)) .. " entry=") .. __TS__NumberToFixed(e.entryIndex, 0)) .. " peri=") .. __TS__NumberToFixed(e.periapsis, 2)) .. " exit=") .. __TS__NumberToFixed(e.exitIndex, 0)) .. " passed=") .. (e.passed and "1" or "0")) -- 344
	end -- 344
	print((((((((((((((((((("[escape-velocity][dbg] launch p0=(" .. __TS__NumberToFixed(p0.x, 6)) .. ",") .. __TS__NumberToFixed(p0.y, 6)) .. ") v=(") .. __TS__NumberToFixed(motion.x, 5)) .. ",") .. __TS__NumberToFixed(motion.y, 5)) .. ") t0=") .. __TS__NumberToFixed(core.t0, 6)) .. " dt=") .. __TS__NumberToFixed(core.dt, 6)) .. " pts=") .. __TS__NumberToFixed(#flight.points, 0)) .. " gi=") .. __TS__NumberToFixed(core.goalIndex, 0)) .. " outcome=") .. flight.outcome) .. " result=") .. (core.result ~= nil and core.result or "pending")) -- 348
	core.flightTime = 0 -- 353
	core.slowmo = false -- 355
	core.slowmoBody = -1 -- 356
	core.phase = "Flying" -- 357
	core.viewMode = "3D" -- 359
end -- 319
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 368
	if core.phase ~= "Aiming" then -- 368
		return false -- 369
	end -- 369
	core.phase = "Armed" -- 370
	return true -- 371
end -- 368
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 375
	if core.phase ~= "Armed" then -- 375
		return false -- 376
	end -- 376
	core.phase = "Aiming" -- 377
	return true -- 378
end -- 375
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 392
	return core.phase == "Aiming" or core.phase == "Armed" -- 393
end -- 392
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 409
	if toT0 then -- 409
		return {t0 = clock, clock = 0} -- 410
	end -- 410
	return {t0 = 0, clock = t0} -- 411
end -- 409
--- 取景锚点的索引（S3.12 的同款逻辑，提成纯函数）。
-- 
-- L2~L6 是太阳（gm 72000、不绕别的天体转）；L1 场里也有太阳（物理统一），所以六关一致。
-- 返回 -1 = 场里没有「不绕别人转」的天体。
-- 
-- S3.17 的慢动作触发也要用它：**锚点是舞台中心，不是被掠过的对象** ——
-- 太阳半径 28，任何 ≥3 的阈值系数都会让「整个太阳系」落在慢动作阈值里，机制直接失效。
function ____exports.anchorBodyIndex(bodies) -- 423
	local host = -1 -- 433
	do -- 433
		local i = 0 -- 434
		while i < #bodies do -- 434
			do -- 434
				local b = bodies[i + 1] -- 435
				local isHost = false -- 436
				do -- 436
					local j = 0 -- 437
					while j < #bodies do -- 437
						do -- 437
							local h = bodies[j + 1].host -- 438
							if h == nil then -- 438
								goto __continue44 -- 439
							end -- 439
							if h.gm == b.gm and h.radius == b.radius and h.orbitRadius == b.orbitRadius then -- 439
								isHost = true -- 440
								break -- 440
							end -- 440
						end -- 440
						::__continue44:: -- 440
						j = j + 1 -- 437
					end -- 437
				end -- 437
				if not isHost then -- 437
					goto __continue42 -- 442
				end -- 442
				if host < 0 or b.gm > bodies[host + 1].gm then -- 442
					host = i -- 443
				end -- 443
			end -- 443
			::__continue42:: -- 443
			i = i + 1 -- 434
		end -- 434
	end -- 434
	if host >= 0 then -- 434
		return host -- 445
	end -- 445
	local best = -1 -- 447
	do -- 447
		local i = 0 -- 448
		while i < #bodies do -- 448
			do -- 448
				local b = bodies[i + 1] -- 449
				if b.orbitRadius ~= 0 then -- 449
					goto __continue51 -- 450
				end -- 450
				if best < 0 or b.gm > bodies[best + 1].gm then -- 450
					best = i -- 451
				end -- 451
			end -- 451
			::__continue51:: -- 451
			i = i + 1 -- 448
		end -- 448
	end -- 448
	return best -- 453
end -- 423
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
function ____exports.slowMotionBody(bodies, probe, t, anchor, floor) -- 471
	local floorDist = floor ~= nil and floor > 0 and floor or SlowMoFloorDist -- 472
	local best = -1 -- 473
	local bestD = 1000000000 -- 474
	do -- 474
		local i = 0 -- 475
		while i < #bodies do -- 475
			do -- 475
				if i == anchor then -- 475
					goto __continue56 -- 476
				end -- 476
				local b = bodies[i + 1] -- 477
				local threshold = math.max(b.radius * SlowMoRadiusFactor, floorDist) -- 478
				local d = distance( -- 479
					probe, -- 479
					bodyPositionAt(b, t) -- 479
				) -- 479
				if d < threshold and d < bestD then -- 479
					bestD = d -- 481
					best = i -- 482
				end -- 482
			end -- 482
			::__continue56:: -- 482
			i = i + 1 -- 475
		end -- 475
	end -- 475
	return best -- 485
end -- 471
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 489
	if core.flight == nil then -- 489
		return 0 -- 490
	end -- 490
	local idx = math.floor(core.flightTime / core.dt) -- 491
	local last = #core.flight.points - 1 -- 492
	if idx > last then -- 492
		idx = last -- 493
	end -- 493
	if idx < 0 then -- 493
		idx = 0 -- 494
	end -- 494
	return idx -- 495
end -- 489
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
function ____exports.coreUpdate(core, dt, level) -- 512
	if core.phase ~= "Flying" or core.flight == nil then -- 512
		return false -- 513
	end -- 513
	if level ~= nil and level.transfer == nil then -- 513
		local idx = ____exports.coreProbeIndex(core) -- 517
		core.slowmoBody = ____exports.slowMotionBody( -- 518
			level.bodies, -- 518
			core.flight.points[idx + 1], -- 518
			core.t0 + core.flightTime, -- 518
			____exports.anchorBodyIndex(level.bodies), -- 518
			level.slowMoFloor -- 518
		) -- 518
		core.slowmo = core.slowmoBody >= 0 -- 519
	end -- 519
	if level ~= nil and level.transfer ~= nil then -- 519
		core.flightTime = advanceTransferPlayback( -- 523
			core.flightTime, -- 523
			dt, -- 523
			core.playback, -- 523
			core.burnDuration, -- 523
			level.transfer, -- 523
			core.flyby, -- 523
			core.dt -- 523
		) -- 523
	else -- 523
		core.flightTime = core.flightTime + dt * core.playback * (core.slowmo and SlowMoFactor or 1) -- 525
	end -- 525
	if core.flyby ~= nil and not core.missionCompleted and core.flyby.completionIndex >= 0 and ____exports.coreProbeIndex(core) >= core.flyby.completionIndex then -- 525
		core.missionCompleted = true -- 528
		core.result = "success" -- 529
	end -- 529
	if core.stars ~= nil and #core.stars > 0 then -- 529
		local curPos = core.flight.points[____exports.coreProbeIndex(core) + 1] -- 534
		do -- 534
			local s = 0 -- 535
			while s < #core.stars do -- 535
				if not core.collectedStars[s + 1] then -- 535
					local orbit = s < #core.starOrbits and core.starOrbits[s + 1] or nil -- 537
					local stPos = starPositionAt(orbit, core.stars[s + 1], core.t0 + core.flightTime) -- 538
					local dx = curPos.x - stPos.x -- 539
					local dy = curPos.y - stPos.y -- 540
					if dx * dx + dy * dy <= 30 * 30 then -- 540
						core.collectedStars[s + 1] = true -- 542
					end -- 542
				end -- 542
				s = s + 1 -- 535
			end -- 535
		end -- 535
	end -- 535
	local naturalEnd = #core.flight.points - 1 -- 548
	local endIdx = core.flyby ~= nil and core.flyby.viewEndIndex or (core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd) -- 549
	if ____exports.coreProbeIndex(core) >= endIdx then -- 549
		core.flightTime = endIdx * core.dt -- 552
		core.phase = "Result" -- 553
		return true -- 554
	end -- 554
	return false -- 556
end -- 512
--- 已完成的教学关可提前结束观赏，不能用该操作跳过掠月判定。
function ____exports.coreEndViewing(core) -- 560
	if core.phase ~= "Flying" or not core.missionCompleted then -- 560
		return false -- 561
	end -- 561
	core.flightTime = ____exports.coreProbeIndex(core) * core.dt -- 562
	core.phase = "Result" -- 563
	return true -- 564
end -- 560
--- 从飞行回放结果中解算遥测数据（纯计算，可单测）。
function ____exports.calcFlightTelemetry(core, level) -- 570
	local burnDv = math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) -- 574
	local maxSpeed = 0 -- 575
	local closestDist = 1000000000 -- 576
	local eccentricity = nil -- 577
	if core.flight ~= nil then -- 577
		local pts = core.flight.points -- 580
		local vels = core.flight.velocities -- 581
		local ____end = ____exports.coreProbeIndex(core) -- 582
		local goalBody = level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies and level.bodies[level.goal.planetIndex + 1] or nil -- 583
		local c3 = level.mission ~= nil and level.mission.challenges ~= nil and level.mission.challenges[3] or nil -- 584
		local distTargetIdx = c3 ~= nil and c3.targetPlanetIndex ~= nil and c3.targetPlanetIndex or level.goal.planetIndex -- 585
		local distTargetBody = distTargetIdx >= 0 and distTargetIdx < #level.bodies and level.bodies[distTargetIdx + 1] or goalBody -- 586
		do -- 586
			local k = 0 -- 588
			while k <= ____end and k < #pts do -- 588
				local p = pts[k + 1] -- 589
				if vels ~= nil and k < #vels then -- 589
					local v = vels[k + 1] -- 591
					local spd = math.sqrt(v.x * v.x + v.y * v.y) -- 592
					if spd > maxSpeed then -- 592
						maxSpeed = spd -- 593
					end -- 593
				end -- 593
				if distTargetBody ~= nil then -- 593
					local t = core.t0 + k * core.dt -- 596
					local tp = bodyPositionAt(distTargetBody, t) -- 597
					local d = distance(p, tp) -- 598
					if d < closestDist then -- 598
						closestDist = d -- 599
					end -- 599
				end -- 599
				k = k + 1 -- 588
			end -- 588
		end -- 588
		if goalBody ~= nil and goalBody.gm > 0 and vels ~= nil and ____end < #pts and ____end < #vels then -- 588
			local tEnd = core.t0 + ____end * core.dt -- 604
			local tpEnd = bodyPositionAt(goalBody, tEnd) -- 605
			local tvEnd = bodyVelocityAt(goalBody, tEnd) -- 606
			local rx = pts[____end + 1].x - tpEnd.x -- 607
			local ry = pts[____end + 1].y - tpEnd.y -- 608
			local vx = vels[____end + 1].x - tvEnd.x -- 609
			local vy = vels[____end + 1].y - tvEnd.y -- 610
			local r = math.sqrt(rx * rx + ry * ry) -- 611
			local v2 = vx * vx + vy * vy -- 612
			local mu = goalBody.gm -- 613
			if r > 0 and mu > 0 then -- 613
				local energy = v2 / 2 - mu / r -- 615
				local h = rx * vy - ry * vx -- 616
				local term = 1 + 2 * energy * h * h / (mu * mu) -- 617
				if term >= 0 then -- 617
					eccentricity = math.sqrt(term) -- 619
				end -- 619
			end -- 619
		end -- 619
	end -- 619
	local starsCollectedCount = 0 -- 625
	do -- 625
		local i = 0 -- 626
		while i < #core.collectedStars do -- 626
			if core.collectedStars[i + 1] then -- 626
				starsCollectedCount = starsCollectedCount + 1 -- 627
			end -- 627
			i = i + 1 -- 626
		end -- 626
	end -- 626
	return { -- 630
		burnDv = burnDv, -- 631
		flightTime = core.flightTime, -- 632
		closestDist = closestDist < 100000000 and closestDist or 0, -- 633
		maxSpeed = maxSpeed, -- 634
		eccentricity = eccentricity, -- 635
		starsCollected = starsCollectedCount -- 636
	} -- 636
end -- 570
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core, aimMin) -- 641
	core.phase = "Aiming" -- 642
	core.viewMode = "2D" -- 644
	core.flight = nil -- 645
	core.flightTime = 0 -- 646
	core.missionCompleted = false -- 647
	core.flyby = nil -- 648
	core.goalIndex = -1 -- 649
	core.result = nil -- 650
	core.burnDuration = 0 -- 651
	core.slowmo = false -- 652
	core.slowmoBody = -1 -- 653
	do -- 653
		local i = 0 -- 654
		while i < #core.collectedStars do -- 654
			core.collectedStars[i + 1] = false -- 654
			i = i + 1 -- 654
		end -- 654
	end -- 654
	core.previewStarsCount = 0 -- 655
	core.aim = neutralAim(levelAimMin(aimMin)) -- 656
end -- 641
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 670
	if core.phase ~= "Result" and core.phase ~= "Finale" then -- 670
		return false -- 672
	end -- 672
	core.phase = "LevelSelect" -- 673
	core.viewMode = "2D" -- 675
	core.flight = nil -- 676
	core.flightTime = 0 -- 677
	core.goalIndex = -1 -- 678
	core.result = nil -- 679
	core.slowmo = false -- 680
	core.slowmoBody = -1 -- 681
	return true -- 682
end -- 670
--- 进入终章（S3.18）。只在 **Result** 态有效。
-- 
-- 为什么是 Result 的延续而不是另一套结算：L6 成功后玩家已经看过一次「借力成功」了，
-- 终章是**同一局的收尾一屏**（回望地球缩成一点）。所以它保留结算数据
-- （core.result / core.flight），只把相态往前推一格 —— 「返回关卡选择」因此可以复用
-- coreBackToSelect（它现在也认 Finale）。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，什么都不做）。
function ____exports.coreEnterFinale(core) -- 711
	if core.phase ~= "Result" then -- 711
		return false -- 712
	end -- 712
	core.phase = "Finale" -- 713
	return true -- 714
end -- 711
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
function ____exports.finaleCamera(probe, distance, tiltDeg) -- 732
	local dist = distance > 1 and distance or 1 -- 733
	local ux = probe.x -- 735
	local uy = probe.y -- 736
	local len = math.sqrt(ux * ux + uy * uy) -- 737
	if len < 0.000001 then -- 737
		ux = 0 -- 738
		uy = 1 -- 738
	else -- 738
		ux = ux / len -- 738
		uy = uy / len -- 738
	end -- 738
	local tilt = tiltDeg * math.pi / 180 -- 739
	local flat = math.cos(tilt) * dist -- 740
	return { -- 741
		target = Vec3(0, 0, 0), -- 743
		eye = Vec3( -- 744
			ux * flat * PlaneToWorldX, -- 744
			math.sin(tilt) * dist, -- 744
			uy * flat * PlaneToWorldZ -- 744
		) -- 744
	} -- 744
end -- 732
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 885
	local introTourActive, introTourT -- 885
	local core = ____exports.createCore(level.physicsStep, level.stars, level.starOrbits) -- 886
	local speedPow = level.speedDefaultPow ~= nil and level.speedDefaultPow or 0 -- 892
	local paused = false -- 893
	local speedMaxPow = level.speedMaxPow ~= nil and level.speedMaxPow or 7 -- 894
	--- 换算基准（1 真实秒 = 多少游戏秒）：关卡没给就用 LevelData 的默认值。
	local speedUnit = level.speedUnit ~= nil and level.speedUnit > 0 and level.speedUnit or GameSecondsPerRealSecond -- 896
	local function applySpeedRate() -- 897
		core.playback = paused and 0 or ____exports.speedRateOf(speedPow, speedUnit) -- 898
	end -- 897
	--- 发射瞬间把档位提到「飞行观赏档」（B3 + B 修复④，2026-09-28）。
	-- 
	-- L1 = 10,000× ⇒ 0.9 天的快转移 8.6 秒打完；1× 下这一发要飞 ~22 小时，等不起。
	-- 这是**唯一**一处替玩家改档位的地方。
	-- 
	-- ⚠️ 必须**两条发射路径共用**：`launchArmed`（HUD 的「发射」按钮 —— 玩家真正走的那条）
	-- 与 `launch`（开发钩子 / 回归脚本）。B3 当初只写进了 `launch`，于是自动提档
	-- **只有脚本能触发、玩家按按钮永远停在 1×** —— 是 B5 的「合成鼠标证据」把它照出来的
	-- （脚本走 launch、按钮走 launchArmed，两条路都跑一遍才看得见）。
	local function applyFlightSpeed() -- 911
		if level.transfer ~= nil then -- 911
			paused = false -- 912
			speedPow = 0 -- 912
			applySpeedRate() -- 912
			return -- 912
		end -- 912
		if level.flightSpeedPow == nil or level.flightSpeedPow <= speedPow then -- 912
			return -- 913
		end -- 913
		speedPow = level.flightSpeedPow -- 914
		paused = false -- 915
		applySpeedRate() -- 916
		print(("[escape-velocity] speed auto -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (launch)") -- 917
	end -- 911
	applySpeedRate() -- 923
	--- 已经应用到节点上的视图（"" = 还没应用过）。每帧 applyView 都拿它对账。
	local appliedMode = "" -- 926
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
	local function applyView() -- 941
		local mode = core.viewMode -- 942
		if mode == appliedMode then -- 942
			return -- 943
		end -- 943
		appliedMode = mode -- 944
		local is2D = mode == "2D" -- 945
		deps.plan:setVisible(is2D) -- 946
		deps.trajectory.root.visible = not is2D -- 947
		deps:setWorldVisible(not is2D) -- 948
		deps.aim:setFullScreenAim(is2D) -- 949
		print(((("[escape-velocity] view -> " .. mode) .. " (phase=") .. core.phase) .. ")") -- 950
	end -- 941
	local ____temp_4 -- 953
	if level.mission ~= nil then -- 953
		____temp_4 = level.mission.introTour -- 953
	else -- 953
		____temp_4 = nil -- 953
	end -- 953
	local tourDef = ____temp_4 -- 953
	local tourDuration = tourDef ~= nil and tourDef.totalDuration or 3.2 -- 954
	local function finishIntroTour() -- 956
		if not introTourActive then -- 956
			return -- 957
		end -- 957
		introTourActive = false -- 958
		introTourT = tourDuration -- 959
		core.viewMode = "2D" -- 960
		applyView() -- 961
		deps.aim:setIntroTourBannerVisible(false) -- 962
		print("[escape-velocity] intro tour completed -> enter 2D") -- 963
	end -- 956
	local function makeBasis(frame) -- 966
		return prepareCamera({ -- 967
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 969
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 970
			up = {x = 0, y = 1, z = 0}, -- 971
			fovYDeg = deps.fovYDeg, -- 972
			aspect = deps.aspect, -- 973
			viewW = deps.viewW, -- 974
			viewH = deps.viewH -- 975
		}, HANDEDNESS, FLIP_Y) -- 975
	end -- 966
	local PredMinIntervalSec = 0.08 -- 987
	local predAimKey = "" -- 988
	local predPosKey = "" -- 989
	local predAccum = 1 -- 990
	local predForce = true -- 991
	local predPoints = {} -- 992
	--- 与 predPoints 一一对应的世界时刻（星尘公转用）。
	local predTimes = {} -- 994
	introTourActive = false -- 996
	introTourT = tourDuration -- 997
	local introLogged = false -- 998
	--- 相机诊断行的打印计数（只打前几帧，别刷屏）。
	local frameLogged = 0 -- 1000
	local clock = 0 -- 1006
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 1008
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 1010
	local obsYawDeg = 0 -- 1014
	local obsPitchDeg = 0 -- 1015
	local obsZoom = 1 -- 1016
	local focusMode = "Auto" -- 1017
	local markerElapsed = -1 -- 1018
	local cineKey = "" -- 1019
	local cineFrame = nil -- 1020
	local cineFrom = nil -- 1021
	local cineTransition = 0 -- 1022
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 1024
	local idleOrbit = nil -- 1026
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 1037
	--- S3.17：慢动作的上一帧状态（打迁移日志用）与飞行日志累加器（每 0.5 真实秒一行）。
	local lastSlowmo = false -- 1039
	local lastSlowmoBody = -1 -- 1040
	local flightLogT = 0 -- 1041
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 1043
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 1044
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
	local function prepareIdle() -- 1059
		clock = 0 -- 1061
		core.t0 = 0 -- 1062
		idleOrbit = nil -- 1063
		if level.probeVel0 == nil then -- 1063
			return -- 1064
		end -- 1064
		local hostIndex = ____exports.selectIdleHost(level.bodies, level.probeStart, level.transfer ~= nil and 0 or nil) -- 1066
		if hostIndex < 0 then -- 1066
			return -- 1067
		end -- 1067
		local host = level.bodies[hostIndex + 1] -- 1068
		local hp = bodyPositionAt(host, 0) -- 1069
		local hv = bodyVelocityAt(host, 0) -- 1070
		local rx = level.probeStart.x - hp.x -- 1072
		local ry = level.probeStart.y - hp.y -- 1073
		local vx = level.probeVel0.x - hv.x -- 1074
		local vy = level.probeVel0.y - hv.y -- 1075
		local r = math.sqrt(rx * rx + ry * ry) -- 1076
		if r < 1e-12 then -- 1076
			return -- 1077
		end -- 1077
		local omega = math.sqrt(host.gm / (r * r * r)) -- 1079
		local dir = rx * vy - ry * vx >= 0 and 1 or -1 -- 1080
		idleOrbit = { -- 1081
			hostIndex = hostIndex, -- 1081
			r = r, -- 1081
			phase0 = math.atan(ry, rx), -- 1081
			omega = dir * omega -- 1081
		} -- 1081
	end -- 1059
	--- 待机时探测器在 `tWorld` 时刻的状态（解析：宿主位置 + 相对圆轨）。
	local function idleProbeAt(tWorld) -- 1085
		if idleOrbit == nil then -- 1085
			return {pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})} -- 1087
		end -- 1087
		local host = level.bodies[idleOrbit.hostIndex + 1] -- 1092
		local hp = bodyPositionAt(host, tWorld) -- 1093
		local hv = bodyVelocityAt(host, tWorld) -- 1094
		local a = idleOrbit.phase0 + idleOrbit.omega * tWorld -- 1095
		local ca = math.cos(a) -- 1096
		local sa = math.sin(a) -- 1097
		return {pos = {x = hp.x + idleOrbit.r * ca, y = hp.y + idleOrbit.r * sa}, vel = {x = hv.x - idleOrbit.omega * idleOrbit.r * sa, y = hv.y + idleOrbit.omega * idleOrbit.r * ca}} -- 1098
	end -- 1085
	--- **锚点天体**：这一关的"世界中心"（S3.12；**S5 修订口径**）。
	-- 
	-- L2~L6 是太阳（玩家绕的就是它）；L1 是**地球** —— 地月系里玩家绕的是地球。
	-- 
	-- ⚠️ S5 之前的口径是「不绕转（orbitRadius = 0）且 gm 最大」，归正后它**挑错了**：
	--    L1 的太阳 orbitRadius = 0、gm 72000，地球 orbitRadius = 80 ⇒ 锚点变成太阳，
	--    取景包围盒被拉到 80 单位宽，地球被压成远处一个点（用户实测「3D 完全看不到地球」）。
	--    新口径（见 anchorBodyIndex 的文档）：**有别的天体绕着它转的优先**，其次才是不绕转且 gm 最大。
	local anchorIdx = ____exports.anchorBodyIndex(level.bodies) -- 1115
	local anchorDef = anchorIdx >= 0 and level.bodies[anchorIdx + 1] or nil -- 1116
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 1119
		local wps = goalWaypoints(level.goal) -- 1120
		if #wps == 0 then -- 1120
			return nil -- 1121
		end -- 1121
		local passed = 0 -- 1122
		if core.flight ~= nil then -- 1122
			local upto = math.floor(core.flightTime / core.dt) -- 1124
			passed = waypointProgress( -- 1125
				core.flight.points, -- 1125
				level.bodies, -- 1125
				level.goal, -- 1125
				core.dt, -- 1125
				core.t0, -- 1125
				upto, -- 1125
				core.flight.velocities -- 1125
			).passed -- 1125
		end -- 1125
		if passed >= #wps then -- 1125
			return nil -- 1127
		end -- 1127
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 1128
	end -- 1119
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 1139
		if level.transfer ~= nil then -- 1139
			return { -- 1141
				pts = { -- 1141
					probe, -- 1141
					bodyPositionAt(level.bodies[1], t), -- 1141
					bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t), -- 1141
					goalPositionAt(level.goal.marker ~= nil and level.goal.marker or level.bodies[level.goal.planetIndex + 1], t, level.goal.offset) -- 1141
				}, -- 1141
				radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius, level.goal.tolerance} -- 1142
			} -- 1142
		end -- 1142
		if level.aimFraming == "local" and anchorDef ~= nil then -- 1142
			local hr = anchorDef.radius -- 1147
			do -- 1147
				local i = 0 -- 1148
				while i < #level.bodies do -- 1148
					local b = level.bodies[i + 1] -- 1149
					if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1149
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > hr then -- 1149
							hr = deps.visuals[i + 1].displayRadius -- 1151
						end -- 1151
						break -- 1152
					end -- 1152
					i = i + 1 -- 1148
				end -- 1148
			end -- 1148
			return { -- 1155
				pts = { -- 1155
					probe, -- 1155
					bodyPositionAt(anchorDef, t) -- 1155
				}, -- 1155
				radii = {deps.scene.probeRadius, hr} -- 1155
			} -- 1155
		end -- 1155
		local corePts = {probe} -- 1159
		local coreRadii = {deps.scene.probeRadius} -- 1160
		local next = nextStationBody() -- 1161
		local nextTol = 0 -- 1162
		if next ~= nil then -- 1162
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 1164
			local wps = goalWaypoints(level.goal) -- 1165
			local passed = 0 -- 1166
			if core.flight ~= nil then -- 1166
				passed = waypointProgress( -- 1168
					core.flight.points, -- 1168
					level.bodies, -- 1168
					level.goal, -- 1168
					core.dt, -- 1168
					core.t0, -- 1168
					math.floor(core.flightTime / core.dt), -- 1168
					core.flight.velocities -- 1168
				).passed -- 1168
			end -- 1168
			if passed < #wps then -- 1168
				nextTol = wps[passed + 1].tolerance -- 1170
			end -- 1170
			local r = nextTol > next.radius and nextTol or next.radius -- 1171
			coreRadii[#coreRadii + 1] = r -- 1172
		end -- 1172
		if anchorDef == nil then -- 1172
			return {pts = corePts, radii = coreRadii} -- 1175
		end -- 1175
		local anchorR = anchorDef.radius -- 1180
		do -- 1180
			local i = 0 -- 1181
			while i < #level.bodies do -- 1181
				local b = level.bodies[i + 1] -- 1182
				if b.gm == anchorDef.gm and b.radius == anchorDef.radius and b.orbitRadius == anchorDef.orbitRadius then -- 1182
					if i < #deps.visuals and deps.visuals[i + 1].displayRadius > anchorR then -- 1182
						anchorR = deps.visuals[i + 1].displayRadius -- 1184
					end -- 1184
					break -- 1185
				end -- 1185
				i = i + 1 -- 1181
			end -- 1181
		end -- 1181
		local withAnchorPts = { -- 1188
			probe, -- 1188
			bodyPositionAt(anchorDef, t) -- 1188
		} -- 1188
		local withAnchorRadii = {deps.scene.probeRadius, anchorR} -- 1189
		do -- 1189
			local i = 1 -- 1190
			while i < #corePts do -- 1190
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 1191
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 1192
				i = i + 1 -- 1190
			end -- 1190
		end -- 1190
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 1194
		if want <= CameraFramingBudget then -- 1194
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 1195
		end -- 1195
		return {pts = corePts, radii = coreRadii} -- 1196
	end -- 1139
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 1200
		local marker = successMarkerFrame(markerElapsed) -- 1201
		if level.transfer ~= nil and not marker.visible then -- 1201
			return {} -- 1202
		end -- 1202
		local wps = goalWaypoints(level.goal) -- 1203
		if #wps == 0 then -- 1203
			return {} -- 1204
		end -- 1204
		local passed = 0 -- 1205
		if upto ~= nil and core.flight ~= nil then -- 1205
			passed = waypointProgress( -- 1207
				core.flight.points, -- 1207
				level.bodies, -- 1207
				level.goal, -- 1207
				core.dt, -- 1207
				core.t0, -- 1207
				upto, -- 1207
				core.flight.velocities -- 1207
			).passed -- 1207
		end -- 1207
		if transferCinematic(level.transfer) then -- 1207
			passed = 0 -- 1209
		end -- 1209
		if passed >= #wps then -- 1209
			return {} -- 1213
		end -- 1213
		local nextWp = wps[passed + 1] -- 1214
		local body = level.goal.marker ~= nil and level.goal.marker or level.bodies[nextWp.planetIndex + 1] -- 1215
		if body == nil then -- 1215
			return {} -- 1216
		end -- 1216
		local planning = aimed and (core.phase == "Aiming" or core.phase == "Armed") -- 1217
		local ____temp_5 -- 1218
		if level.transfer ~= nil then -- 1218
			____temp_5 = level.transfer.orbital -- 1218
		else -- 1218
			____temp_5 = nil -- 1218
		end -- 1218
		local orbital = ____temp_5 -- 1218
		local rings = {{ -- 1219
			center = goalPositionAt(body, t, nextWp.offset), -- 1219
			radius = nextWp.tolerance, -- 1219
			passed = false, -- 1219
			point = level.transfer ~= nil, -- 1220
			showRange = level.transfer == nil or (orbital == nil or orbital.targetFlyby ~= nil) and planning, -- 1220
			pulse = (1 + 0.1 * math.sin(t * 4)) * marker.scale, -- 1221
			pointAlpha = marker.alpha, -- 1221
			burstRadius = marker.ring -- 1221
		}} -- 1221
		if orbital ~= nil and orbital.region ~= nil and planning then -- 1221
			local center = bodyPositionAt(level.bodies[1], t) -- 1223
			__TS__ArrayPush(rings, {center = center, radius = orbital.region.minRadius, passed = false}, {center = center, radius = orbital.region.maxRadius, passed = false}) -- 1224
		end -- 1224
		return rings -- 1226
	end -- 1200
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 1230
		if level.transfer ~= nil and not transferCinematic(level.transfer) then -- 1230
			local basis = makeBasis(f) -- 1232
			local dx = f.eye.x - f.target.x -- 1233
			local dy = f.eye.y - f.target.y -- 1233
			local dz = f.eye.z - f.target.z -- 1233
			local shift = math.sqrt(dx * dx + dy * dy + dz * dz) * math.tan(deps.fovYDeg * math.pi / 360) * 0.14 -- 1234
			f = { -- 1235
				eye = Vec3(f.eye.x - basis.up.x * shift, f.eye.y - basis.up.y * shift, f.eye.z - basis.up.z * shift), -- 1235
				target = Vec3(f.target.x - basis.up.x * shift, f.target.y - basis.up.y * shift, f.target.z - basis.up.z * shift) -- 1236
			} -- 1236
		end -- 1236
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 1236
			return f -- 1238
		end -- 1238
		local dx = f.eye.x - f.target.x -- 1239
		local dy = f.eye.y - f.target.y -- 1240
		local dz = f.eye.z - f.target.z -- 1241
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 1242
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 1243
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 1244
		local lo = CameraTiltMin * math.pi / 180 -- 1245
		local hi = CameraTiltMax * math.pi / 180 -- 1246
		if pitch < lo then -- 1246
			pitch = lo -- 1247
		end -- 1247
		if pitch > hi then -- 1247
			pitch = hi -- 1248
		end -- 1248
		local cp = math.cos(pitch) -- 1249
		return { -- 1250
			target = f.target, -- 1251
			eye = Vec3( -- 1252
				f.target.x + r * cp * math.sin(yaw), -- 1253
				f.target.y + r * math.sin(pitch), -- 1254
				f.target.z + r * cp * math.cos(yaw) -- 1255
			) -- 1255
		} -- 1255
	end -- 1230
	--- 五个具体机位，沿用 CameraRig 的真实投影拟合；近景只包含当下的主体。
	local function transferCamera(pos, t, wallDt) -- 1261
		local cfg = level.transfer.flyby -- 1262
		local autoShot = transferShotAt( -- 1263
			core.flightTime, -- 1263
			core.burnDuration, -- 1263
			core.flyby, -- 1263
			cfg, -- 1263
			core.dt -- 1263
		) -- 1263
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1264
		local key = (focusMode .. ":") .. shot -- 1265
		local earth = bodyPositionAt(level.bodies[1], t) -- 1266
		local moon = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], t) -- 1267
		local velocity = core.flight ~= nil and core.flight.velocities[____exports.coreProbeIndex(core) + 1] or probeVel -- 1268
		local vmag = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1269
		local firstV = core.flight ~= nil and core.flight.velocities[1] or velocity -- 1270
		local launchAz = math.atan(firstV.x, firstV.y) * 180 / math.pi + 100 -- 1271
		local moonAz = launchAz -- 1272
		if core.flyby ~= nil and core.flyby.entryIndex >= 0 and core.flight ~= nil then -- 1272
			local at = core.flyby.entryIndex -- 1274
			local m = bodyPositionAt(level.bodies[level.goal.planetIndex + 1], core.t0 + at * core.dt) -- 1275
			moonAz = math.atan(core.flight.points[at + 1].x - m.x, core.flight.points[at + 1].y - m.y) * 180 / math.pi + 90 -- 1277
		end -- 1277
		local pts = {pos} -- 1279
		local radii = {deps.scene.probeRadius} -- 1279
		local az = launchAz -- 1280
		local tilt = 28 -- 1280
		local minDist = 130 -- 1280
		if shot == "Cruise" then -- 1280
			pts[#pts + 1] = {x = pos.x + (vmag > 0 and velocity.x * 32 / vmag or 0), y = pos.y + (vmag > 0 and velocity.y * 32 / vmag or 0)} -- 1282
			radii[#radii + 1] = 0 -- 1283
			minDist = 180 -- 1283
			tilt = 35 -- 1283
		elseif shot == "Moon" then -- 1283
			pts = focusMode == "Moon" and ({moon}) or ({pos, moon}) -- 1285
			radii = focusMode == "Moon" and ({level.bodies[level.goal.planetIndex + 1].radius}) or ({deps.scene.probeRadius, level.bodies[level.goal.planetIndex + 1].radius}) -- 1286
			az = moonAz -- 1287
			tilt = 45 -- 1287
			minDist = 160 -- 1287
		elseif shot == "Earth" then -- 1287
			pts = focusMode == "Earth" and ({earth}) or ({pos, earth}) -- 1289
			radii = focusMode == "Earth" and ({level.bodies[1].radius}) or ({deps.scene.probeRadius, level.bodies[1].radius}) -- 1290
			az = moonAz + 35 -- 1291
			tilt = 42 -- 1291
			minDist = 180 -- 1291
			if core.flyby ~= nil and core.flyby.completionIndex >= 0 and core.flight ~= nil then -- 1291
				local at = math.min( -- 1293
					#core.flight.points - 1, -- 1293
					core.flyby.completionIndex + math.floor(cfg.overviewDuration / core.dt) -- 1293
				) -- 1293
				local home = bodyPositionAt(level.bodies[1], core.t0 + at * core.dt) -- 1294
				az = math.atan(core.flight.points[at + 1].x - home.x, core.flight.points[at + 1].y - home.y) * 180 / math.pi -- 1296
			end -- 1296
		elseif shot == "Overview" then -- 1296
			pts = {pos, earth, moon} -- 1299
			radii = {deps.scene.probeRadius, level.bodies[1].radius, level.bodies[level.goal.planetIndex + 1].radius} -- 1299
			az = moonAz -- 1300
			tilt = 60 -- 1300
			minDist = 200 -- 1300
		end -- 1300
		if key ~= cineKey then -- 1300
			cineFrom = cineFrame -- 1303
			cineTransition = 0 -- 1304
			if cineKey == "" or shot == "Launch" then -- 1304
				cineFrom = nil -- 1306
			end -- 1306
			cineKey = key -- 1307
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1308
		end -- 1308
		local want = deps.rig.step( -- 1310
			pts, -- 1310
			deps.scene.probeRadius, -- 1310
			radii, -- 1310
			minDist, -- 1310
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1310
		) -- 1310
		local frame = want -- 1311
		if cineFrom ~= nil then -- 1311
			cineTransition = cineTransition + wallDt -- 1313
			local u = math.min(1, cineTransition / 0.6) -- 1314
			local k = u * u * (3 - 2 * u) -- 1315
			frame = { -- 1316
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1316
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1317
			} -- 1317
			if u >= 1 then -- 1317
				cineFrom = nil -- 1318
			end -- 1318
		end -- 1318
		cineFrame = frame -- 1320
		return applyObserve(frame) -- 1321
	end -- 1261
	--- 日心关卡按配置逐站取景，手动选择保持到回到自动。
	local function orbitalCamera(pos, t, wallDt) -- 1325
		local cfg = level.transfer.orbital -- 1326
		local autoShot = orbitalShotAt( -- 1327
			core.flightTime, -- 1327
			core.burnDuration, -- 1327
			core.flyby, -- 1327
			cfg, -- 1327
			core.dt -- 1327
		) -- 1327
		local shot = focusMode == "Auto" and autoShot or (focusMode == "Probe" and "Cruise" or focusMode) -- 1328
		local key = (focusMode .. ":") .. shot -- 1329
		local velocity = core.flight.velocities[____exports.coreProbeIndex(core) + 1] -- 1330
		local speed = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y) -- 1331
		local pts = {pos} -- 1332
		local radii = {deps.scene.probeRadius} -- 1332
		local az = math.atan(core.flight.velocities[1].x, core.flight.velocities[1].y) * 180 / math.pi + 100 -- 1333
		local targetFlybyMission = cfg.targetFlyby ~= nil -- 1334
		local encounterSpecs = {table.unpack(cfg.encounters)} -- 1335
		if cfg.targetFlyby ~= nil then -- 1335
			encounterSpecs[#encounterSpecs + 1] = cfg.targetFlyby -- 1336
		end -- 1336
		local tilt = 28 -- 1337
		local minDist = targetFlybyMission and 40 or 130 -- 1337
		if shot == "Cruise" then -- 1337
			pts[#pts + 1] = {x = pos.x + (speed > 0 and velocity.x * 32 / speed or 0), y = pos.y + (speed > 0 and velocity.y * 32 / speed or 0)} -- 1339
			radii[#radii + 1] = 0 -- 1340
			tilt = 35 -- 1340
			minDist = targetFlybyMission and 65 or 180 -- 1340
		elseif shot == "Overview" then -- 1340
			pts[#pts + 1] = bodyPositionAt(level.bodies[1], t) -- 1342
			radii[#radii + 1] = level.bodies[1].radius -- 1342
			for ____, e in ipairs(encounterSpecs) do -- 1343
				pts[#pts + 1] = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1343
				radii[#radii + 1] = level.bodies[e.planetIndex + 1].radius -- 1343
			end -- 1343
			az = math.atan(pos.x, pos.y) * 180 / math.pi -- 1344
			tilt = 60 -- 1344
			minDist = 300 -- 1344
		elseif shot == "Sun" then -- 1344
			pts = {bodyPositionAt(level.bodies[1], t)} -- 1346
			radii = {level.bodies[1].radius} -- 1346
			tilt = 42 -- 1346
			minDist = 200 -- 1346
		elseif shot ~= "Launch" then -- 1346
			do -- 1346
				local i = 0 -- 1348
				while i < #encounterSpecs do -- 1348
					do -- 1348
						local e = encounterSpecs[i + 1] -- 1349
						if e.focus ~= shot then -- 1349
							goto __continue172 -- 1350
						end -- 1350
						local bp = bodyPositionAt(level.bodies[e.planetIndex + 1], t) -- 1351
						pts = focusMode == "Auto" and ({pos, bp}) or ({bp}) -- 1352
						radii = focusMode == "Auto" and ({deps.scene.probeRadius, level.bodies[e.planetIndex + 1].radius}) or ({level.bodies[e.planetIndex + 1].radius}) -- 1353
						local ____temp_6 -- 1354
						if core.flyby ~= nil and core.flyby.encounters ~= nil then -- 1354
							____temp_6 = i < #cfg.encounters and core.flyby.encounters[i + 1] or core.flyby.destination -- 1354
						else -- 1354
							____temp_6 = nil -- 1354
						end -- 1354
						local stage = ____temp_6 -- 1354
						local at = stage ~= nil and stage.entryIndex >= 0 and stage.entryIndex or 0 -- 1355
						local near = bodyPositionAt(level.bodies[e.planetIndex + 1], core.t0 + at * core.dt) -- 1356
						local probe = core.flight.points[at + 1] -- 1356
						az = math.atan(probe.x - near.x, probe.y - near.y) * 180 / math.pi + 90 -- 1357
						tilt = 45 -- 1358
						minDist = targetFlybyMission and (focusMode == "Auto" and 80 or level.bodies[e.planetIndex + 1].radius * 6) or 180 -- 1358
						break -- 1358
					end -- 1358
					::__continue172:: -- 1358
					i = i + 1 -- 1348
				end -- 1348
			end -- 1348
		end -- 1348
		if key ~= cineKey then -- 1348
			cineFrom = cineFrame -- 1362
			cineTransition = 0 -- 1362
			if cineKey == "" or shot == "Launch" then -- 1362
				cineFrom = nil -- 1363
			end -- 1363
			cineKey = key -- 1364
			print((("[escape-velocity] camera shot -> " .. key) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1365
		end -- 1365
		local want = deps.rig.step( -- 1367
			pts, -- 1367
			deps.scene.probeRadius, -- 1367
			radii, -- 1367
			minDist, -- 1367
			{azDeg = az, tiltDeg = tilt, lerp = 1} -- 1367
		) -- 1367
		local frame = want -- 1368
		if cineFrom ~= nil then -- 1368
			cineTransition = cineTransition + wallDt -- 1370
			local u = math.min(1, cineTransition / 0.6) -- 1371
			local k = u * u * (3 - 2 * u) -- 1371
			frame = { -- 1372
				eye = Vec3(cineFrom.eye.x + (want.eye.x - cineFrom.eye.x) * k, cineFrom.eye.y + (want.eye.y - cineFrom.eye.y) * k, cineFrom.eye.z + (want.eye.z - cineFrom.eye.z) * k), -- 1372
				target = Vec3(cineFrom.target.x + (want.target.x - cineFrom.target.x) * k, cineFrom.target.y + (want.target.y - cineFrom.target.y) * k, cineFrom.target.z + (want.target.z - cineFrom.target.z) * k) -- 1373
			} -- 1373
			if u >= 1 then -- 1373
				cineFrom = nil -- 1374
			end -- 1374
		end -- 1374
		cineFrame = frame -- 1376
		return applyObserve(frame) -- 1377
	end -- 1325
	local function resetCinematic() -- 1380
		markerElapsed = -1 -- 1381
		focusMode = "Auto" -- 1382
		cineKey = "" -- 1382
		cineFrame = nil -- 1382
		cineFrom = nil -- 1382
		obsYawDeg = 0 -- 1383
		obsPitchDeg = 0 -- 1383
		obsZoom = 1 -- 1383
	end -- 1380
	local function updateAiming(dt) -- 1386
		if deps.plan.setBurn ~= nil then -- 1386
			deps.plan:setBurn(core.aim.velocity, false) -- 1387
		end -- 1387
		deps.aim:setEnabled(true) -- 1388
		local dragging = deps.aim:isDragging() -- 1390
		local clockFrozen = dragging or core.phase == "Armed" or transferCinematic(level.transfer) and introTourActive -- 1395
		if (core.phase == "Aiming" or core.phase == "Armed") and not clockFrozen and idleOrbit ~= nil then -- 1395
			local rate = core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1406
			clock = clock + dt * rate -- 1407
			orbitClock = orbitClock + dt * rate -- 1408
		end -- 1408
		local tNow = core.t0 + clock -- 1410
		local idleState = idleProbeAt(tNow) -- 1412
		probePos = idleState.pos -- 1413
		probeVel = idleState.vel -- 1414
		deps.scene.syncBodies(tNow) -- 1416
		if deps.scene.syncStars ~= nil then -- 1416
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow)) -- 1417
		end -- 1417
		deps.scene.syncProbe(probePos) -- 1418
		if idleOrbit ~= nil then -- 1418
			deps.scene.faceVelocity(probeVel) -- 1419
		end -- 1419
		deps.plan:syncBodies(level.bodies, deps.visuals, tNow) -- 1421
		deps.plan:syncProbe(probePos, probeVel) -- 1422
		if not aimed and #core.stars > 0 then -- 1422
			deps.plan:setStars( -- 1424
				starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tNow), -- 1424
				core.collectedStars -- 1424
			) -- 1424
		end -- 1424
		local fr = framingPoints(probePos, tNow) -- 1428
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 1429
		if frameLogged < 6 then -- 1429
			frameLogged = frameLogged + 1 -- 1433
			local d = math.sqrt((frame.eye.x - frame.target.x) * (frame.eye.x - frame.target.x) + (frame.eye.y - frame.target.y) * (frame.eye.y - frame.target.y) + (frame.eye.z - frame.target.z) * (frame.eye.z - frame.target.z)) -- 1434
			local sunD = math.sqrt(frame.eye.x * frame.eye.x + frame.eye.z * frame.eye.z) -- 1438
			print(((((((((((((((((((((((((("[escape-velocity][cam] aim pts=" .. tostring(#fr.pts)) .. " target=(") .. __TS__NumberToFixed(frame.target.x, 3)) .. ",") .. __TS__NumberToFixed(frame.target.y, 3)) .. ",") .. __TS__NumberToFixed(frame.target.z, 3)) .. ")") .. " eye=(") .. __TS__NumberToFixed(frame.eye.x, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.y, 3)) .. ",") .. __TS__NumberToFixed(frame.eye.z, 3)) .. ")") .. " dist=") .. __TS__NumberToFixed(d, 4)) .. " sunDist=") .. __TS__NumberToFixed(sunD, 3)) .. " probeR=") .. __TS__NumberToFixed(deps.scene.probeRadius, 7)) .. " slowmo=") .. tostring(core.slowmo and 1 or 0)) .. " pts=[") .. table.concat( -- 1439
				__TS__ArrayMap( -- 1445
					fr.pts, -- 1445
					function(____, p) return ((("(" .. __TS__NumberToFixed(p.x, 3)) .. ",") .. __TS__NumberToFixed(p.y, 3)) .. ")" end -- 1445
				), -- 1445
				" " -- 1445
			)) .. "]") -- 1445
		end -- 1445
		if introTourActive and introTourT < tourDuration then -- 1445
			introTourT = introTourT + dt -- 1449
			local k = introTourT / tourDuration -- 1450
			if k >= 1 then -- 1450
				finishIntroTour() -- 1452
			else -- 1452
				if k >= 0.95 and not introLogged then -- 1452
					introLogged = true -- 1455
					print("[escape-velocity] intro camera finishing") -- 1456
				end -- 1456
				if tourDef ~= nil and #tourDef.segments > 0 then -- 1456
					local elapsed = introTourT -- 1460
					local segIndex = 0 -- 1461
					local segStart = 0 -- 1462
					do -- 1462
						local s = 0 -- 1463
						while s < #tourDef.segments do -- 1463
							local seg = tourDef.segments[s + 1] -- 1464
							if elapsed <= seg.duration or s == #tourDef.segments - 1 then -- 1464
								segIndex = s -- 1466
								break -- 1467
							end -- 1467
							elapsed = elapsed - seg.duration -- 1469
							segStart = segStart + seg.duration -- 1470
							s = s + 1 -- 1463
						end -- 1463
					end -- 1463
					local curSeg = tourDef.segments[segIndex + 1] -- 1472
					local segK = math.max( -- 1473
						0, -- 1473
						math.min(1, (introTourT - segStart) / (curSeg.duration > 0 and curSeg.duration or 1)) -- 1473
					) -- 1473
					deps.aim:setIntroTourBanner(curSeg.banner, "轻触屏幕任意位置跳过运镜") -- 1475
					deps.aim:setIntroTourBannerVisible(true) -- 1476
					local pwProbe = planeToWorld(probePos, 0) -- 1478
					local function getTargetPosAndDist(targetIdx, userDist) -- 1479
						if targetIdx ~= nil and targetIdx >= 0 and targetIdx < #level.bodies then -- 1479
							local b = level.bodies[targetIdx + 1] -- 1481
							local isMicro = b.orbitRadius < 2 -- 1482
							local p = planeToWorld( -- 1483
								bodyPositionAt(b, tNow), -- 1483
								0 -- 1483
							) -- 1483
							local defaultD = isMicro and math.max(0.008, b.radius * 2.5) or math.max(8, b.radius * 12) -- 1484
							return {pos = p, dist = userDist ~= nil and userDist or defaultD} -- 1485
						end -- 1485
						local isMicro = #level.bodies > 1 and level.bodies[2].orbitRadius < 2 -- 1487
						local defaultD = isMicro and math.max(0.0035, deps.scene.probeRadius * 6) or math.max(2.5, deps.scene.probeRadius * 6) -- 1488
						return {pos = pwProbe, dist = userDist ~= nil and userDist or defaultD} -- 1489
					end -- 1479
					local curKey = getTargetPosAndDist(curSeg.targetPlanetIndex, curSeg.camDist) -- 1492
					local prevSeg = segIndex > 0 and tourDef.segments[segIndex] or curSeg -- 1493
					local prevKey = segIndex > 0 and getTargetPosAndDist(prevSeg.targetPlanetIndex, prevSeg.camDist) or curKey -- 1494
					local prevAz = (prevSeg.azDeg ~= nil and prevSeg.azDeg or 45) * math.pi / 180 -- 1496
					local curAz = (curSeg.azDeg ~= nil and curSeg.azDeg or 45) * math.pi / 180 -- 1497
					local prevTilt = (prevSeg.tiltDeg ~= nil and prevSeg.tiltDeg or 45) * math.pi / 180 -- 1498
					local curTilt = (curSeg.tiltDeg ~= nil and curSeg.tiltDeg or 45) * math.pi / 180 -- 1499
					if segIndex == 0 then -- 1499
						local az = curAz + segK * (18 * math.pi / 180) -- 1503
						local tilt = curTilt -- 1504
						local d = curKey.dist -- 1505
						local eye = Vec3( -- 1506
							curKey.pos.x + math.sin(az) * math.cos(tilt) * d, -- 1507
							curKey.pos.y + math.sin(tilt) * d, -- 1508
							curKey.pos.z + math.cos(az) * math.cos(tilt) * d -- 1509
						) -- 1509
						frame = {target = curKey.pos, eye = eye} -- 1511
					else -- 1511
						local ease = segK * segK * (3 - 2 * segK) -- 1514
						local target = Vec3(prevKey.pos.x + (curKey.pos.x - prevKey.pos.x) * ease, prevKey.pos.y + (curKey.pos.y - prevKey.pos.y) * ease, prevKey.pos.z + (curKey.pos.z - prevKey.pos.z) * ease) -- 1515
						local az = prevAz + (curAz - prevAz) * ease -- 1520
						local tilt = prevTilt + (curTilt - prevTilt) * ease -- 1521
						local peakBonus = math.sin(ease * math.pi) * math.max(prevKey.dist, curKey.dist) * 0.35 -- 1522
						local d = prevKey.dist + (curKey.dist - prevKey.dist) * ease + peakBonus -- 1523
						local eye = Vec3( -- 1524
							target.x + math.sin(az) * math.cos(tilt) * d, -- 1525
							target.y + math.sin(tilt) * d, -- 1526
							target.z + math.cos(az) * math.cos(tilt) * d -- 1527
						) -- 1527
						frame = {target = target, eye = eye} -- 1529
					end -- 1529
				else -- 1529
					local targetBody = nil -- 1532
					local wps = goalWaypoints(level.goal) -- 1533
					if #wps > 0 then -- 1533
						targetBody = level.bodies[wps[#wps].planetIndex + 1] -- 1535
					elseif level.goal.planetIndex >= 0 and level.goal.planetIndex < #level.bodies then -- 1535
						targetBody = level.bodies[level.goal.planetIndex + 1] -- 1537
					end -- 1537
					if targetBody == nil and #level.bodies > 0 then -- 1537
						targetBody = level.bodies[#level.bodies] -- 1540
					end -- 1540
					if targetBody ~= nil then -- 1540
						local pwTarget = planeToWorld( -- 1544
							bodyPositionAt(targetBody, tNow), -- 1544
							0 -- 1544
						) -- 1544
						local pwProbe = planeToWorld(probePos, 0) -- 1545
						local isMicroSystem = targetBody.orbitRadius < 2 -- 1546
						local distTarget = isMicroSystem and math.max(0.18, targetBody.radius * 180) or math.max(8, targetBody.radius * 350) -- 1547
						local distProbe = isMicroSystem and math.max(0.015, deps.scene.probeRadius * 10) or math.max(1.5, deps.scene.probeRadius * 6) -- 1548
						if k < 0.35 then -- 1548
							local e1 = k / 0.35 -- 1551
							local az = (0.2 + e1 * 0.15) * math.pi -- 1552
							local tilt = 0.35 * math.pi -- 1553
							local eye = Vec3( -- 1554
								pwTarget.x + math.sin(az) * math.cos(tilt) * distTarget, -- 1555
								pwTarget.y + math.sin(tilt) * distTarget, -- 1556
								pwTarget.z + math.cos(az) * math.cos(tilt) * distTarget -- 1557
							) -- 1557
							frame = {target = pwTarget, eye = eye} -- 1559
						elseif k < 0.72 then -- 1559
							local e2 = (k - 0.35) / 0.37 -- 1561
							local ease2 = e2 * e2 * (3 - 2 * e2) -- 1562
							local az = (0.35 + (1 - ease2) * 0.1) * math.pi -- 1563
							local peakDist = isMicroSystem and 1.2 or math.max(distTarget * 2.2, 45) -- 1564
							local curDist = distTarget + (peakDist - distTarget) * math.sin(ease2 * math.pi) + (distProbe - distTarget) * ease2 -- 1565
							local targetCenter = Vec3(pwTarget.x + (pwProbe.x - pwTarget.x) * ease2, pwTarget.y + (pwProbe.y - pwTarget.y) * ease2, pwTarget.z + (pwProbe.z - pwTarget.z) * ease2) -- 1566
							local eye = Vec3( -- 1571
								targetCenter.x + math.sin(az) * 0.5 * curDist, -- 1572
								targetCenter.y + curDist * 0.8, -- 1573
								targetCenter.z + math.cos(az) * 0.5 * curDist -- 1574
							) -- 1574
							frame = {target = targetCenter, eye = eye} -- 1576
						else -- 1576
							local e3 = (k - 0.72) / 0.28 -- 1578
							local ease3 = 1 - (1 - e3) * (1 - e3) -- 1579
							local az = 0.25 * math.pi -- 1580
							local tilt = 0.36 * math.pi -- 1581
							local curDist = distTarget * 0.4 * (1 - ease3) + distProbe * ease3 -- 1582
							local eye = Vec3( -- 1583
								pwProbe.x + math.sin(az) * math.cos(tilt) * curDist, -- 1584
								pwProbe.y + math.sin(tilt) * curDist, -- 1585
								pwProbe.z + math.cos(az) * math.cos(tilt) * curDist -- 1586
							) -- 1586
							frame = {target = pwProbe, eye = eye} -- 1588
						end -- 1588
					end -- 1588
				end -- 1588
			end -- 1588
		end -- 1588
		frame = applyObserve(frame) -- 1595
		deps.rig.apply(deps.camera, frame) -- 1596
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1597
		local basis = makeBasis(frame) -- 1598
		if core.viewMode == "2D" then -- 1598
			local sp = deps.plan:probeScreen() -- 1604
			deps.aim:setProbeOffset({x = sp.x - deps.viewW / 2, y = sp.y - deps.viewH / 2}) -- 1605
		else -- 1605
			local pp = projectPrepared( -- 1607
				planeToWorld(probePos, 0), -- 1607
				basis -- 1607
			) -- 1607
			if pp ~= nil then -- 1607
				deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 1608
			end -- 1608
		end -- 1608
		if not aimed then -- 1608
			if level.transfer ~= nil and deps.aim.setTransferInfo ~= nil then -- 1608
				deps.aim:setTransferInfo( -- 1618
					distance( -- 1618
						probePos, -- 1618
						bodyPositionAt(level.bodies[1], tNow) -- 1618
					) - level.bodies[1].radius, -- 1618
					0 -- 1618
				) -- 1618
			end -- 1618
			deps.trajectory:clearPrediction() -- 1622
			deps.plan:clearPrediction() -- 1623
			predForce = true -- 1624
		else -- 1624
			local aimKey = (__TS__NumberToFixed(core.aim.velocity.x, 4) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 4) -- 1630
			local posKey = (((__TS__NumberToFixed(tNow, 4) .. "|") .. __TS__NumberToFixed(probePos.x, 7)) .. ",") .. __TS__NumberToFixed(probePos.y, 7) -- 1631
			predAccum = predAccum + dt -- 1632
			local needIt = predForce or (aimKey ~= predAimKey or posKey ~= predPosKey) and predAccum >= PredMinIntervalSec -- 1633
			if needIt then -- 1633
				predForce = false -- 1635
				predAccum = 0 -- 1636
				predAimKey = aimKey -- 1637
				predPosKey = posKey -- 1638
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel) -- 1641
				local predictSample = level.transfer ~= nil and 1 or 4 -- 1642
				local sim = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion}, level.bodies, { -- 1643
					steps = level.predictSteps ~= nil and level.predictSteps or PredictSteps, -- 1646
					dt = core.dt, -- 1646
					sampleEvery = predictSample, -- 1646
					escapeRadius = level.escapeRadius, -- 1646
					t0 = tNow -- 1646
				}) -- 1646
				predPoints = sim.points -- 1648
				if level.transfer ~= nil then -- 1648
					local analysis = analyzeTransfer( -- 1650
						sim, -- 1650
						level.bodies, -- 1650
						level.goal.planetIndex, -- 1650
						level.transfer, -- 1650
						core.dt * predictSample, -- 1650
						tNow -- 1650
					) -- 1650
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 1651
						sim.points, -- 1651
						level.bodies, -- 1651
						level.goal, -- 1651
						core.dt * predictSample, -- 1651
						tNow, -- 1651
						sim.velocities -- 1651
					) -- 1651
					if analysis ~= nil then -- 1651
						predPoints = __TS__ArraySlice(sim.points, 0, analysis.viewEndIndex + 1) -- 1652
					elseif gi >= 0 then -- 1652
						predPoints = __TS__ArraySlice(sim.points, 0, gi + 1) -- 1653
					end -- 1653
					local radius = distance( -- 1654
						probePos, -- 1654
						bodyPositionAt(level.bodies[1], tNow) -- 1654
					) -- 1654
					local plan = planTransfer( -- 1655
						level.bodies[1].gm, -- 1655
						radius, -- 1655
						probeVel, -- 1655
						core.aim.power, -- 1655
						level.transfer.apoapsisMax, -- 1655
						level.transfer.mode, -- 1655
						level.transfer.periapsisMin -- 1655
					) -- 1655
					if deps.aim.setTransferInfo ~= nil then -- 1655
						deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration, gi >= 0) -- 1656
					end -- 1656
				end -- 1656
				predTimes = {} -- 1658
				do -- 1658
					local pi = 0 -- 1659
					while pi < #predPoints do -- 1659
						predTimes[#predTimes + 1] = tNow + pi * core.dt * predictSample -- 1659
						pi = pi + 1 -- 1659
					end -- 1659
				end -- 1659
			end -- 1659
			deps.trajectory:setPrediction(predPoints, basis) -- 1661
			deps.plan:setPrediction(predPoints) -- 1663
			if #core.stars > 0 then -- 1663
				local live = starPositionsNow(core.starOrbits, core.stars, tNow) -- 1666
				local stEval = evaluateCollectedStars( -- 1667
					predPoints, -- 1667
					core.stars, -- 1667
					30, -- 1667
					core.starOrbits, -- 1667
					predTimes -- 1667
				) -- 1667
				core.previewStarsCount = stEval.count -- 1668
				deps.plan:setStars(live, stEval.collected) -- 1669
			end -- 1669
		end -- 1669
		if idleOrbit ~= nil then -- 1669
			local hc = bodyPositionAt(level.bodies[idleOrbit.hostIndex + 1], tNow) -- 1674
			deps.trajectory:setOrbitRing(hc, idleOrbit.r, basis) -- 1675
			deps.plan:setProbeOrbit(hc, idleOrbit.r) -- 1676
		end -- 1676
		local rings = goalRingsAt(tNow) -- 1678
		deps.trajectory:setGoalRings(rings, basis) -- 1679
		deps.trajectory:clearTrail() -- 1680
		deps.plan:setGoalRings(rings) -- 1682
		deps.plan:clearTrail() -- 1683
		deps.plan:flush() -- 1684
	end -- 1386
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
	local function updateFinale() -- 1699
		deps.aim:setEnabled(false) -- 1700
		if core.flight == nil then -- 1700
			return -- 1701
		end -- 1701
		local idx = ____exports.coreProbeIndex(core) -- 1702
		local pos = core.flight.points[idx + 1] -- 1703
		local tWorld = core.t0 + core.flightTime -- 1704
		deps.scene.syncBodies(tWorld) -- 1707
		deps.scene.syncProbe(pos) -- 1708
		deps.scene.faceVelocity(core.flight.velocities[idx + 1]) -- 1709
		local frame = ____exports.finaleCamera(pos, FinaleCamDist, FinaleCamTiltDeg) -- 1712
		deps.camera:lookAt( -- 1713
			frame.eye, -- 1713
			frame.target, -- 1713
			Vec3(0, 1, 0) -- 1713
		) -- 1713
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1714
		local trail = {} -- 1717
		do -- 1717
			local i = 0 -- 1718
			while i <= idx do -- 1718
				trail[#trail + 1] = core.flight.points[i + 1] -- 1718
				i = i + 1 -- 1718
			end -- 1718
		end -- 1718
		local rings = goalRingsAt(tWorld, idx) -- 1719
		local basis = makeBasis(frame) -- 1720
		if deps.trajectory.setBurn ~= nil then -- 1720
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1722
		end -- 1722
		deps.trajectory:clearOrbitRing() -- 1723
		deps.plan:clearProbeOrbit() -- 1724
		deps.trajectory:setTrail(trail, basis) -- 1725
		deps.trajectory:setGoalRings(rings, basis) -- 1726
		deps.plan:clearPrediction() -- 1727
		deps.plan:setGoalRings(rings) -- 1728
		deps.plan:flush() -- 1729
	end -- 1699
	local function updateFlying(dt) -- 1731
		deps.aim:setEnabled(false) -- 1732
		local wasCompleted = core.missionCompleted -- 1735
		local entered = ____exports.coreUpdate(core, dt, level) -- 1736
		if not wasCompleted and core.missionCompleted then -- 1736
			markerElapsed = 0 -- 1738
			print("[escape-velocity] success marker triggered once") -- 1739
			print("[escape-velocity] mission completed (continue viewing) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1740
			if deps.onMissionCompleted ~= nil then -- 1740
				deps:onMissionCompleted(____exports.calcFlightTelemetry(core, level)) -- 1741
			end -- 1741
		end -- 1741
		if core.flight == nil then -- 1741
			return entered -- 1743
		end -- 1743
		local idx = ____exports.coreProbeIndex(core) -- 1745
		local pos = core.flight.points[idx + 1] -- 1746
		local tWorld = core.t0 + core.flightTime -- 1750
		if core.slowmo ~= lastSlowmo or core.slowmoBody ~= lastSlowmoBody then -- 1750
			lastSlowmo = core.slowmo -- 1754
			lastSlowmoBody = core.slowmoBody -- 1755
			local near = core.slowmoBody >= 0 and level.bodies[core.slowmoBody + 1] or nil -- 1756
			local nearD = near ~= nil and distance( -- 1757
				pos, -- 1757
				bodyPositionAt(near, tWorld) -- 1757
			) or 0 -- 1757
			print((((((((("[escape-velocity] slow-mo " .. (core.slowmo and "engage" or "release")) .. " body#") .. __TS__NumberToFixed(core.slowmoBody, 0)) .. " r=") .. (near ~= nil and __TS__NumberToFixed(near.radius, 2) or "-")) .. " d=") .. __TS__NumberToFixed(nearD, 1)) .. " t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1758
		end -- 1758
		flightLogT = flightLogT + dt -- 1765
		if flightLogT >= 0.5 then -- 1765
			flightLogT = 0 -- 1767
			local total = (#core.flight.points - 1) * core.dt -- 1768
			print(((((((((((("[escape-velocity] flight t=" .. __TS__NumberToFixed(core.flightTime, 2)) .. "/") .. __TS__NumberToFixed(total, 1)) .. " idx=") .. __TS__NumberToFixed(idx, 0)) .. " speed=") .. __TS__NumberToFixed( -- 1769
				core.playback * (level.transfer ~= nil and transferPlaybackRate( -- 1771
					core.flightTime, -- 1771
					core.burnDuration, -- 1771
					level.transfer, -- 1771
					core.flyby, -- 1771
					core.dt -- 1771
				) or (core.slowmo and SlowMoFactor or 1)), -- 1771
				2 -- 1771
			)) .. " (playback=") .. __TS__NumberToFixed(core.playback, 0)) .. "x slowmo=") .. (core.slowmo and "1" or "0")) .. ")") -- 1771
		end -- 1771
		deps.scene.syncBodies(tWorld) -- 1775
		if deps.scene.syncStars ~= nil then -- 1775
			deps.scene.syncStars(starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld)) -- 1776
		end -- 1776
		deps.scene.syncProbe(pos) -- 1777
		if idx > 0 then -- 1777
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 1779
		end -- 1779
		do -- 1779
			local s = 0 -- 1783
			while s < #core.stars do -- 1783
				if not core.collectedStars[s + 1] then -- 1783
					local fromLevel = level.starOrbits -- 1785
					local orbit = fromLevel ~= nil and s < #fromLevel and fromLevel[s + 1] or (s < #core.starOrbits and core.starOrbits[s + 1] or nil) -- 1786
					local stPos = starPositionAt(orbit, core.stars[s + 1], tWorld) -- 1787
					local dx = pos.x - stPos.x -- 1788
					local dy = pos.y - stPos.y -- 1789
					if dx * dx + dy * dy <= 30 * 30 then -- 1789
						core.collectedStars[s + 1] = true -- 1791
						if deps.scene.setStarCollected ~= nil then -- 1791
							deps.scene.setStarCollected(s) -- 1793
						end -- 1793
						deps.plan:setStars(core.stars, core.collectedStars) -- 1795
						print((("[escape-velocity] star collected: #" .. tostring(s + 1)) .. " at t=") .. __TS__NumberToFixed(core.flightTime, 2)) -- 1796
					end -- 1796
				end -- 1796
				s = s + 1 -- 1783
			end -- 1783
		end -- 1783
		local fr -- 1805
		local closeDist = nil -- 1806
		if core.slowmo and core.slowmoBody >= 0 then -- 1806
			local near = level.bodies[core.slowmoBody + 1] -- 1808
			local nearR = near.radius -- 1810
			do -- 1810
				local i = 0 -- 1811
				while i < #level.bodies do -- 1811
					local b = level.bodies[i + 1] -- 1812
					if b.gm == near.gm and b.radius == near.radius and b.orbitRadius == near.orbitRadius then -- 1812
						if i < #deps.visuals and deps.visuals[i + 1].displayRadius > nearR then -- 1812
							nearR = deps.visuals[i + 1].displayRadius -- 1814
						end -- 1814
						break -- 1815
					end -- 1815
					i = i + 1 -- 1811
				end -- 1811
			end -- 1811
			fr = { -- 1818
				pts = { -- 1818
					pos, -- 1818
					bodyPositionAt(near, tWorld) -- 1818
				}, -- 1818
				radii = {deps.scene.probeRadius, nearR} -- 1818
			} -- 1818
			closeDist = SlowMoCloseDist -- 1819
		else -- 1819
			fr = framingPoints(pos, tWorld) -- 1821
		end -- 1821
		local baseFrame = level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalCamera(pos, tWorld, dt) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferCamera(pos, tWorld, dt) or deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii, closeDist)) -- 1823
		local frame = level.transfer ~= nil and not transferCinematic(level.transfer) and applyObserve(baseFrame) or baseFrame -- 1824
		deps.rig.apply(deps.camera, frame) -- 1825
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 1826
		local basis = makeBasis(frame) -- 1827
		if deps.trajectory.setBurn ~= nil then -- 1827
			deps.trajectory:setBurn(pos, core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration, basis) -- 1830
		end -- 1830
		if deps.plan.setBurn ~= nil then -- 1830
			deps.plan:setBurn(core.aim.velocity, core.phase == "Flying" and core.flightTime < core.burnDuration) -- 1831
		end -- 1831
		local trail = {} -- 1832
		do -- 1832
			local i = 0 -- 1833
			while i <= idx do -- 1833
				trail[#trail + 1] = core.flight.points[i + 1] -- 1833
				i = i + 1 -- 1833
			end -- 1833
		end -- 1833
		local rings = goalRingsAt(tWorld, idx) -- 1834
		deps.trajectory:clearOrbitRing() -- 1836
		deps.plan:clearProbeOrbit() -- 1837
		deps.trajectory:setTrail(trail, basis) -- 1838
		deps.trajectory:setGoalRings(rings, basis) -- 1839
		deps.plan:syncBodies(level.bodies, deps.visuals, tWorld) -- 1842
		deps.plan:syncProbe(pos, core.flight.velocities[idx + 1]) -- 1843
		deps.plan:setStars( -- 1844
			starPositionsNow(level.starOrbits ~= nil and level.starOrbits or ({}), core.stars, tWorld), -- 1844
			core.collectedStars -- 1844
		) -- 1844
		deps.plan:setTrail(trail) -- 1845
		deps.plan:clearPrediction() -- 1846
		deps.plan:setGoalRings(rings) -- 1847
		deps.plan:flush() -- 1848
		return entered -- 1850
	end -- 1731
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 1864
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 1865
		core.t0 = next.t0 -- 1866
		clock = next.clock -- 1867
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 1868
	end -- 1864
	local function finishFlight() -- 1871
		if core.result == nil then -- 1871
			return -- 1872
		end -- 1872
		local toFinale = deps.finale == true and core.result == "success" -- 1873
		if toFinale then -- 1873
			____exports.coreEnterFinale(core) -- 1874
		end -- 1874
		deps:onResult( -- 1875
			core.result, -- 1875
			____exports.calcFlightTelemetry(core, level) -- 1875
		) -- 1875
		if toFinale and core.flight ~= nil and deps.onFinale ~= nil then -- 1875
			local ____end = #core.flight.points - 1 -- 1877
			deps:onFinale({ -- 1878
				distance = distance(core.flight.points[____end + 1], level.probeStart), -- 1878
				time = core.flightTime, -- 1878
				tWorld = core.t0 + core.flightTime -- 1878
			}) -- 1878
		end -- 1878
		deps:onPhase(toFinale and "Finale" or "Result") -- 1880
	end -- 1871
	local function update(dt) -- 1883
		if markerElapsed >= 0 and markerElapsed < 0.6 then -- 1883
			markerElapsed = math.min(0.6, markerElapsed + dt) -- 1884
		end -- 1884
		applyView() -- 1887
		if core.phase == "Aiming" or core.phase == "Armed" then -- 1887
			updateAiming(dt) -- 1889
		elseif core.phase == "Flying" then -- 1889
			local entered = updateFlying(dt) -- 1891
			if entered then -- 1891
				finishFlight() -- 1892
			end -- 1892
		elseif core.phase == "Finale" then -- 1892
			updateFinale() -- 1894
		elseif core.phase == "Result" and core.missionCompleted and level.transfer ~= nil then -- 1894
			local rings = goalRingsAt( -- 1897
				core.t0 + core.flightTime, -- 1897
				____exports.coreProbeIndex(core) -- 1897
			) -- 1897
			deps.plan:setGoalRings(rings) -- 1898
			deps.plan:flush() -- 1898
			if cineFrame ~= nil then -- 1898
				deps.trajectory:setGoalRings( -- 1899
					rings, -- 1899
					makeBasis(cineFrame) -- 1899
				) -- 1899
			end -- 1899
		end -- 1899
	end -- 1883
	return { -- 1904
		phase = function() return core.phase end, -- 1905
		speedPow = function() return speedPow end, -- 1906
		speedMaxPow = function() return speedMaxPow end, -- 1907
		isPaused = function() return paused end, -- 1908
		speedRate = function() -- 1909
			if level.transfer ~= nil and (core.phase == "Flying" or core.phase == "Result") then -- 1909
				return core.playback * transferPlaybackRate( -- 1910
					core.flightTime, -- 1910
					core.burnDuration, -- 1910
					level.transfer, -- 1910
					core.flyby, -- 1910
					core.dt -- 1910
				) -- 1910
			end -- 1910
			return core.playback * (level.transfer ~= nil and level.transfer.orbital ~= nil and level.transfer.orbital.standbyPlayback or (level.transfer ~= nil and level.transfer.flyby ~= nil and level.transfer.flyby.standbyPlayback or 1)) -- 1911
		end, -- 1909
		missionSeconds = function() -- 1913
			local w = (core.phase == "Flying" or core.phase == "Result") and core.t0 + core.flightTime or core.t0 + clock -- 1914
			return speedUnit > 0 and w / speedUnit or 0 -- 1915
		end, -- 1913
		speedUp = function() -- 1917
			if speedPow >= speedMaxPow then -- 1917
				return -- 1918
			end -- 1918
			speedPow = speedPow + 1 -- 1919
			paused = false -- 1920
			applySpeedRate() -- 1921
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1922
		end, -- 1917
		speedDown = function() -- 1924
			if speedPow <= 0 then -- 1924
				return -- 1925
			end -- 1925
			speedPow = speedPow - 1 -- 1926
			paused = false -- 1927
			applySpeedRate() -- 1928
			print(((("[escape-velocity] speed -> 1e" .. __TS__NumberToFixed(speedPow, 0)) .. "x (") .. __TS__NumberToFixed(core.playback, 6)) .. " 游戏秒/真实秒)") -- 1929
		end, -- 1924
		togglePause = function() -- 1931
			paused = not paused -- 1932
			applySpeedRate() -- 1933
			print(((("[escape-velocity] " .. (paused and "paused" or "resumed")) .. " (speedPow=1e") .. __TS__NumberToFixed(speedPow, 0)) .. ")") -- 1934
		end, -- 1931
		result = function() return core.result end, -- 1936
		onAimDrag = function(____, a) -- 1937
			if introTourActive then -- 1937
				finishIntroTour() -- 1938
			end -- 1938
			core.aim = a -- 1939
			if level.transfer ~= nil then -- 1939
				local radius = distance( -- 1941
					probePos, -- 1941
					bodyPositionAt(level.bodies[1], core.t0 + clock) -- 1941
				) -- 1941
				local plan = planTransfer( -- 1942
					level.bodies[1].gm, -- 1942
					radius, -- 1942
					probeVel, -- 1942
					a.power, -- 1942
					level.transfer.apoapsisMax, -- 1942
					level.transfer.mode, -- 1942
					level.transfer.periapsisMin -- 1942
				) -- 1942
				core.aim = {power = a.power, velocity = plan.velocity, unit = a.unit} -- 1943
				if deps.aim.setTransferInfo ~= nil then -- 1943
					deps.aim:setTransferInfo(level.transfer.orbital ~= nil and plan.apoapsis or plan.apoapsis - level.bodies[1].radius, plan.dv / level.transfer.thrustAcceleration) -- 1944
				end -- 1944
			end -- 1944
			aimed = true -- 1946
		end, -- 1937
		aimReady = function() -- 1948
			predForce = true -- 1950
			if not ____exports.coreArm(core) then -- 1950
				return -- 1951
			end -- 1951
			if level.transfer ~= nil then -- 1951
				print("[escape-velocity] transfer armed dv=" .. __TS__NumberToFixed( -- 1952
					math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y), -- 1952
					4 -- 1952
				)) -- 1952
			end -- 1952
			applyView() -- 1953
			deps:onPhase("Armed") -- 1954
		end, -- 1948
		cancelAim = function() -- 1956
			if not ____exports.coreCancelArm(core) then -- 1956
				return -- 1957
			end -- 1957
			aimed = false -- 1958
			predForce = true -- 1959
			deps.trajectory:clearPrediction() -- 1960
			deps.plan:clearPrediction() -- 1961
			applyView() -- 1962
			deps:onPhase("Aiming") -- 1963
			print("[escape-velocity] aim cancelled") -- 1964
		end, -- 1956
		launchArmed = function() -- 1966
			if core.phase ~= "Armed" then -- 1966
				return -- 1968
			end -- 1968
			resetCinematic() -- 1969
			applyFlightSpeed() -- 1970
			handoffDate(true) -- 1971
			____exports.coreLaunch( -- 1972
				core, -- 1972
				core.aim.velocity, -- 1972
				level, -- 1972
				probePos, -- 1972
				probeVel -- 1972
			) -- 1972
			deps.trajectory:clearPrediction() -- 1973
			deps.plan:clearPrediction() -- 1974
			applyView() -- 1975
			deps:onPhase("Flying") -- 1976
		end, -- 1966
		armed = function() return core.phase == "Armed" end, -- 1978
		viewMode = function() return core.viewMode end, -- 1979
		toggleViewMode = function() -- 1980
			____exports.coreToggleView(core) -- 1982
			applyView() -- 1983
		end, -- 1980
		cameraFocus = function() return focusMode end, -- 1985
		flightStage = function() return level.transfer ~= nil and level.transfer.orbital ~= nil and orbitalShotAt( -- 1986
			core.flightTime, -- 1986
			core.burnDuration, -- 1986
			core.flyby, -- 1986
			level.transfer.orbital, -- 1986
			core.dt -- 1986
		) or (level.transfer ~= nil and level.transfer.flyby ~= nil and transferShotAt( -- 1986
			core.flightTime, -- 1987
			core.burnDuration, -- 1987
			core.flyby, -- 1987
			level.transfer.flyby, -- 1987
			core.dt -- 1987
		) or nil) end, -- 1987
		cycleCameraFocus = function() -- 1988
			if not transferCinematic(level.transfer) or core.phase ~= "Flying" then -- 1988
				return -- 1989
			end -- 1989
			local ____temp_8 -- 1990
			if level.transfer ~= nil and level.transfer.orbital ~= nil then -- 1990
				local ____array_7 = __TS__SparseArrayNew( -- 1990
					"Auto", -- 1990
					"Probe", -- 1990
					table.unpack(__TS__ArrayMap( -- 1990
						level.transfer.orbital.encounters, -- 1990
						function(____, e) return e.focus end -- 1990
					)) -- 1990
				) -- 1990
				__TS__SparseArrayPush( -- 1990
					____array_7, -- 1990
					table.unpack(level.transfer.orbital.targetFlyby ~= nil and ({level.transfer.orbital.targetFlyby.focus}) or ({})) -- 1990
				) -- 1990
				__TS__SparseArrayPush(____array_7, "Sun", "Overview") -- 1990
				____temp_8 = {__TS__SparseArraySpread(____array_7)} -- 1990
			else -- 1990
				____temp_8 = nil -- 1990
			end -- 1990
			local modes = ____temp_8 -- 1990
			focusMode = nextCameraFocus(focusMode, modes) -- 1991
			obsYawDeg = 0 -- 1992
			obsPitchDeg = 0 -- 1992
			obsZoom = 1 -- 1992
			print("[escape-velocity] camera focus -> " .. focusMode) -- 1993
		end, -- 1988
		missionCompleted = function() return core.missionCompleted end, -- 1995
		markerElapsed = function() return markerElapsed end, -- 1996
		endViewing = function() -- 1997
			if not ____exports.coreEndViewing(core) then -- 1997
				return -- 1998
			end -- 1998
			print("[escape-velocity] end viewing (manual) t=" .. __TS__NumberToFixed(core.flightTime, 3)) -- 1999
			finishFlight() -- 2000
		end, -- 1997
		skipIntroTour = function() -- 2002
			finishIntroTour() -- 2003
		end, -- 2002
		isIntroTourActive = function() return introTourActive end, -- 2005
		observeDrag = function(____, dx, dy) -- 2006
			if introTourActive then -- 2006
				finishIntroTour() -- 2008
				return -- 2009
			end -- 2009
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 2011
			obsYawDeg = obsYawDeg + dx * 0.35 -- 2012
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 2013
			if obsPitchDeg > 40 then -- 2013
				obsPitchDeg = 40 -- 2014
			end -- 2014
			if obsPitchDeg < -40 then -- 2014
				obsPitchDeg = -40 -- 2015
			end -- 2015
		end, -- 2006
		observeZoom = function(____, deltaDist) -- 2017
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 2018
			if obsZoom < 0.4 then -- 2018
				obsZoom = 0.4 -- 2019
			end -- 2019
			if obsZoom > 1.8 then -- 2019
				obsZoom = 1.8 -- 2020
			end -- 2020
		end, -- 2017
		launch = function(____, v) -- 2022
			applyFlightSpeed() -- 2023
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 2023
				return -- 2024
			end -- 2024
			resetCinematic() -- 2025
			handoffDate(true) -- 2026
			____exports.coreLaunch( -- 2028
				core, -- 2028
				v, -- 2028
				level, -- 2028
				probePos, -- 2028
				probeVel -- 2028
			) -- 2028
			deps.trajectory:clearPrediction() -- 2029
			deps.plan:clearPrediction() -- 2030
			applyView() -- 2031
			deps:onPhase("Flying") -- 2032
		end, -- 2022
		retry = function() -- 2034
			resetCinematic() -- 2035
			handoffDate(false) -- 2036
			aimed = false -- 2037
			introTourActive = false -- 2038
			____exports.coreRetry(core, level.aimMin) -- 2039
			if deps.scene.resetStars ~= nil then -- 2039
				deps.scene.resetStars() -- 2041
			end -- 2041
			deps.plan:setStars(core.stars, core.collectedStars) -- 2043
			deps.trajectory:clearTrail() -- 2044
			deps.trajectory:clearPrediction() -- 2045
			deps.trajectory:clearGoalRings() -- 2046
			deps.plan:clearTrail() -- 2047
			deps.plan:clearPrediction() -- 2048
			deps.plan:clearGoalRings() -- 2049
			applyView() -- 2050
			deps:onPhase("Aiming") -- 2051
		end, -- 2034
		backToSelect = function() -- 2053
			if not ____exports.coreBackToSelect(core) then -- 2053
				return false -- 2054
			end -- 2054
			deps.aim:setEnabled(false) -- 2056
			deps.trajectory:clearTrail() -- 2057
			deps.trajectory:clearPrediction() -- 2058
			deps.trajectory:clearGoalRings() -- 2059
			deps.plan:clearTrail() -- 2060
			deps.plan:clearPrediction() -- 2061
			deps.plan:clearGoalRings() -- 2062
			applyView() -- 2063
			deps:onPhase("LevelSelect") -- 2064
			return true -- 2065
		end, -- 2053
		startLevel = function() -- 2067
			resetCinematic() -- 2068
			aimed = false -- 2069
			____exports.coreRetry(core, level.aimMin) -- 2070
			if deps.scene.resetStars ~= nil then -- 2070
				deps.scene.resetStars() -- 2072
			end -- 2072
			deps.plan:setStars(core.stars, core.collectedStars) -- 2074
			deps.rig.reset() -- 2075
			introTourActive = false -- 2077
			core.viewMode = "2D" -- 2078
			appliedMode = "" -- 2079
			applyView() -- 2080
			prepareIdle() -- 2081
			deps.trajectory:clearTrail() -- 2082
			deps.trajectory:clearPrediction() -- 2083
			deps.trajectory:clearGoalRings() -- 2084
			deps.plan:clearTrail() -- 2085
			deps.plan:clearPrediction() -- 2086
			deps.plan:clearGoalRings() -- 2087
			deps:onPhase("Aiming") -- 2088
		end, -- 2067
		stepTime = function(____, dir, span) -- 2090
			if not ____exports.coreTimeWarpAllowed(core) then -- 2090
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 2094
				return -- 2095
			end -- 2095
			local span0 = span > 0 and span or 0 -- 2097
			clock = clock + dir * TimeWarpStep -- 2098
			if clock < 0 then -- 2098
				clock = 0 -- 2099
			end -- 2099
			if span0 > 0 and clock > span0 then -- 2099
				clock = span0 -- 2100
			end -- 2100
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 2102
		end, -- 2090
		dateNow = function() return core.t0 + clock end, -- 2104
		setPlaybackSpeed = function(____, speed) -- 2105
			if speed ~= 1 and speed ~= 2 and speed ~= 4 then -- 2105
				return -- 2107
			end -- 2107
			core.playback = speed -- 2108
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (phase=") .. core.phase) .. ")") -- 2109
		end, -- 2105
		playbackSpeed = function() return core.playback end, -- 2111
		burnNow = function() return math.sqrt(core.aim.velocity.x * core.aim.velocity.x + core.aim.velocity.y * core.aim.velocity.y) end, -- 2112
		starsNow = function() -- 2113
			if core.phase == "Flying" or core.phase == "Result" then -- 2113
				local n = 0 -- 2115
				do -- 2115
					local i = 0 -- 2116
					while i < #core.collectedStars do -- 2116
						if core.collectedStars[i + 1] then -- 2116
							n = n + 1 -- 2116
						end -- 2116
						i = i + 1 -- 2116
					end -- 2116
				end -- 2116
				return n -- 2117
			end -- 2117
			return core.previewStarsCount -- 2119
		end, -- 2113
		update = function(____, frameDt) return update(frameDt) end -- 2122
	} -- 2122
end -- 885
return ____exports -- 885
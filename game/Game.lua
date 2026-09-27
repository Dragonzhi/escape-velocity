-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
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
local findGoalIndex = ____LevelData.findGoalIndex -- 33
local goalWaypoints = ____LevelData.goalWaypoints -- 33
local waypointProgress = ____LevelData.waypointProgress -- 33
local ____Config = require("game.Config") -- 34
local AimMinSpeed = ____Config.AimMinSpeed -- 35
local BrakeShare = ____Config.BrakeShare -- 35
local CameraFramingBudget = ____Config.CameraFramingBudget -- 35
local CameraTiltMax = ____Config.CameraTiltMax -- 35
local CameraTiltMin = ____Config.CameraTiltMin -- 35
local FlightPlayback = ____Config.FlightPlayback -- 35
local IntroCloseDist = ____Config.IntroCloseDist -- 35
local IntroDurationSec = ____Config.IntroDurationSec -- 36
local PhysicsStep = ____Config.PhysicsStep -- 36
local PredictSteps = ____Config.PredictSteps -- 36
local TimeWarpStep = ____Config.TimeWarpStep -- 36
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
function ____exports.resolveResult(outcome, goalIndex, goal) -- 69
	if goal.kind == "escape" then -- 69
		local wps = goalWaypoints(goal) -- 71
		if outcome == "escaped" and (#wps == 0 or goalIndex >= 0) then -- 71
			return "success" -- 72
		end -- 72
	elseif goalIndex >= 0 then -- 72
		return "success" -- 74
	end -- 74
	if outcome == "crashed" then -- 74
		return "crashed" -- 76
	end -- 76
	return "missed" -- 77
end -- 69
function ____exports.createCore() -- 120
	return { -- 121
		phase = "Aiming", -- 122
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 123
		flight = nil, -- 124
		dt = PhysicsStep, -- 125
		brakeMode = false, -- 126
		t0 = 0, -- 127
		flightTime = 0, -- 128
		goalIndex = -1, -- 129
		result = nil -- 130
	} -- 130
end -- 120
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 149
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 155
	local share = brakeMode and BrakeShare or 1 -- 156
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 157
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 158
	local brake = brakeMode and mag > 0 and ({ -- 159
		dv = mag * (1 - share), -- 160
		startStep = math.floor(maxSteps / 2) -- 160
	}) or nil -- 160
	return {init = init, brake = brake} -- 162
end -- 149
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 171
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 171
		return -- 173
	end -- 173
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 174
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 175
	local p0 = from ~= nil and from or level.probeStart -- 176
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 177
		steps = level.maxSteps, -- 180
		dt = core.dt, -- 180
		sampleEvery = 1, -- 180
		escapeRadius = level.escapeRadius, -- 180
		t0 = core.t0, -- 180
		brake = motion.brake -- 180
	}) -- 180
	core.flight = flight -- 182
	core.goalIndex = findGoalIndex( -- 183
		flight.points, -- 183
		level.bodies, -- 183
		level.goal, -- 183
		core.dt, -- 183
		core.t0, -- 183
		flight.velocities -- 183
	) -- 183
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 184
	core.flightTime = 0 -- 185
	core.phase = "Flying" -- 186
end -- 171
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 195
	if core.phase ~= "Aiming" then -- 195
		return false -- 196
	end -- 196
	core.phase = "Armed" -- 197
	return true -- 198
end -- 195
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 202
	if core.phase ~= "Armed" then -- 202
		return false -- 203
	end -- 203
	core.phase = "Aiming" -- 204
	return true -- 205
end -- 202
--- 时间流（改发射日期）在当前相态下是否允许（S3.11）。
-- 
-- 只在**发射前**允许（Aiming / Armed）：
--  - 飞行用的是 `tWorld = t0 + flightTime`，飞行途中改 t0 等于把参考系整个挪走 ——
--    行星会在飞行路径底下跳位（会话 39 亲眼见过同源现象：物理对、模型错）；
--  - 结算之后改日期没有任何意义。
-- 
-- 提成导出函数是为了**可单测**（`Test/GameTest.ts` 的 time-warp-* 三条），
-- HUD 里的按钮开关（`AimInput.setTimeEnabled`）读的是同一个判据。
function ____exports.coreTimeWarpAllowed(core) -- 219
	return core.phase == "Aiming" or core.phase == "Armed" -- 220
end -- 219
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
function ____exports.coreHandoffDate(t0, clock, toT0) -- 236
	if toT0 then -- 236
		return {t0 = clock, clock = 0} -- 237
	end -- 237
	return {t0 = 0, clock = t0} -- 238
end -- 236
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 242
	if core.flight == nil then -- 242
		return 0 -- 243
	end -- 243
	local idx = math.floor(core.flightTime / core.dt) -- 244
	local last = #core.flight.points - 1 -- 245
	if idx > last then -- 245
		idx = last -- 246
	end -- 246
	if idx < 0 then -- 246
		idx = 0 -- 247
	end -- 247
	return idx -- 248
end -- 242
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 257
	if core.phase ~= "Flying" or core.flight == nil then -- 257
		return false -- 258
	end -- 258
	core.flightTime = core.flightTime + dt * FlightPlayback -- 259
	local naturalEnd = #core.flight.points - 1 -- 260
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 261
	if ____exports.coreProbeIndex(core) >= endIdx then -- 261
		core.flightTime = endIdx * core.dt -- 264
		core.phase = "Result" -- 265
		return true -- 266
	end -- 266
	return false -- 268
end -- 257
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 272
	core.phase = "Aiming" -- 273
	core.flight = nil -- 274
	core.flightTime = 0 -- 275
	core.goalIndex = -1 -- 276
	core.result = nil -- 277
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 278
end -- 272
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 292
	if core.phase ~= "Result" then -- 292
		return false -- 293
	end -- 293
	core.phase = "LevelSelect" -- 294
	core.flight = nil -- 295
	core.flightTime = 0 -- 296
	core.goalIndex = -1 -- 297
	core.result = nil -- 298
	return true -- 299
end -- 292
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 371
	local core = ____exports.createCore() -- 372
	local function makeBasis(frame) -- 375
		return prepareCamera({ -- 376
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 378
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 379
			up = {x = 0, y = 1, z = 0}, -- 380
			fovYDeg = deps.fovYDeg, -- 381
			aspect = deps.aspect, -- 382
			viewW = deps.viewW, -- 383
			viewH = deps.viewH -- 384
		}, HANDEDNESS, FLIP_Y) -- 384
	end -- 375
	local predKey = "" -- 393
	local predPoints = {} -- 394
	local introT = IntroDurationSec -- 396
	local introLogged = false -- 397
	local clock = 0 -- 403
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 405
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 407
	local obsYawDeg = 0 -- 411
	local obsPitchDeg = 0 -- 412
	local obsZoom = 1 -- 413
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 415
	local idlePath = nil -- 416
	--- 玩家**是否已经瞄过**（S3.12）。
	-- 
	-- 用户原话：「预览线有时候调整好了又会变回初始状态，比如第一关，默认就不要显示预览线，
	-- 调整过了再显示」。所以规则是：
	--   - 进关时**一条线都不画**（不管有没有待机轨迹）；
	--   - 玩家在探测器附近拖过一次之后，线就属于"他瞄的这一发"，松手（Armed）也**保持**，
	--     直到发射 / 重试 / 退出关卡才清掉。
	-- 从前那套"没在拖就把待机轨道画成预测线"会让玩家调好的线被覆盖成初始状态。
	local aimed = false -- 427
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 429
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 430
	local function prepareIdle() -- 431
		clock = 0 -- 433
		core.t0 = 0 -- 434
		if level.probeVel0 == nil then -- 434
			idlePath = nil -- 436
			return -- 437
		end -- 437
		local idleSteps = level.maxSteps -- 445
		local v0x = level.probeVel0.x -- 446
		local v0y = level.probeVel0.y -- 447
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 448
		if v0 > 0.000001 then -- 448
			local bestD = 1000000000 -- 450
			for ____, b in ipairs(level.bodies) do -- 451
				do -- 451
					if b.gm <= 0 then -- 451
						goto __continue33 -- 452
					end -- 452
					local dx = b.orbitCenter.x - level.probeStart.x -- 453
					local dy = b.orbitCenter.y - level.probeStart.y -- 454
					local d = math.sqrt(dx * dx + dy * dy) -- 455
					if d < bestD then -- 455
						bestD = d -- 456
					end -- 456
				end -- 456
				::__continue33:: -- 456
			end -- 456
			if bestD > 0.000001 and bestD < 100000000 then -- 456
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 459
				if n > 60 and n < 40000 then -- 459
					idleSteps = n -- 460
				end -- 460
			end -- 460
		end -- 460
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 463
			steps = idleSteps, -- 466
			dt = core.dt, -- 466
			sampleEvery = 1, -- 466
			escapeRadius = level.escapeRadius, -- 466
			t0 = core.t0 -- 466
		}) -- 466
	end -- 431
	local function idleIndex() -- 469
		if idlePath == nil then -- 469
			return 0 -- 470
		end -- 470
		local n = #idlePath.points -- 471
		if n <= 1 then -- 471
			return 0 -- 472
		end -- 472
		local i = math.floor(orbitClock / core.dt) % n -- 473
		if i < 0 then -- 473
			i = 0 -- 474
		end -- 474
		return i -- 475
	end -- 469
	--- **锚点天体**：场里 gm 最大、且不绕别的天体转的那个（S3.12）。
	-- 
	-- L2~L6 是太阳（gm 72000，玩家绕的就是它）；L1 是地球（2600 —— 地月系里玩家绕的是地球，
	-- 而 L1 场里根本没有太阳）。取景与"空间宏大"都靠它：它必须**完整**在画面内。
	local anchorDef = nil -- 484
	for ____, b in ipairs(level.bodies) do -- 485
		do -- 485
			if b.orbitRadius ~= 0 then -- 485
				goto __continue43 -- 486
			end -- 486
			if anchorDef == nil or b.gm > anchorDef.gm then -- 486
				anchorDef = b -- 487
			end -- 487
		end -- 487
		::__continue43:: -- 487
	end -- 487
	--- 目标链上下一个**还没掠过**的站（取景用；没有航点或已走完 ⇒ undefined）。
	local function nextStationBody() -- 491
		local wps = goalWaypoints(level.goal) -- 492
		if #wps == 0 then -- 492
			return nil -- 493
		end -- 493
		local passed = 0 -- 494
		if core.flight ~= nil then -- 494
			local upto = math.floor(core.flightTime / core.dt) -- 496
			passed = waypointProgress( -- 497
				core.flight.points, -- 497
				level.bodies, -- 497
				level.goal, -- 497
				core.dt, -- 497
				core.t0, -- 497
				upto, -- 497
				core.flight.velocities -- 497
			).passed -- 497
		end -- 497
		if passed >= #wps then -- 497
			return nil -- 499
		end -- 499
		return level.bodies[wps[passed + 1].planetIndex + 1] -- 500
	end -- 491
	--- 取景点与逐点半径（S3.12）：**探测器 + 锚点天体 + 下一站**。
	-- 
	-- 从前的取景集合是"探测器 + **全部**行星" ⇒ 相机被迫一路拉远（甚至撑到 CameraMaxDistance），
	-- 画面里什么都小、太阳还会被裁掉一块。用户的原话是：
	-- 「玩家所面对的其实是轨道的一部分，不是能看到整个轨道」—— 远处还没轮到的行星**允许出画**，
	-- 想看全景的玩家自己捏合拉远（observeZoom），开场分镜也还给过一次全景。
	local function framingPoints(probe, t) -- 511
		local corePts = {probe} -- 514
		local coreRadii = {deps.scene.probeRadius} -- 515
		local next = nextStationBody() -- 516
		local nextTol = 0 -- 517
		if next ~= nil then -- 517
			corePts[#corePts + 1] = bodyPositionAt(next, t) -- 519
			local wps = goalWaypoints(level.goal) -- 520
			local passed = 0 -- 521
			if core.flight ~= nil then -- 521
				passed = waypointProgress( -- 523
					core.flight.points, -- 523
					level.bodies, -- 523
					level.goal, -- 523
					core.dt, -- 523
					core.t0, -- 523
					math.floor(core.flightTime / core.dt), -- 523
					core.flight.velocities -- 523
				).passed -- 523
			end -- 523
			if passed < #wps then -- 523
				nextTol = wps[passed + 1].tolerance -- 525
			end -- 525
			local r = nextTol > next.radius and nextTol or next.radius -- 526
			coreRadii[#coreRadii + 1] = r -- 527
		end -- 527
		if anchorDef == nil then -- 527
			return {pts = corePts, radii = coreRadii} -- 530
		end -- 530
		local withAnchorPts = { -- 531
			probe, -- 531
			bodyPositionAt(anchorDef, t) -- 531
		} -- 531
		local withAnchorRadii = {deps.scene.probeRadius, anchorDef.radius} -- 532
		do -- 532
			local i = 1 -- 533
			while i < #corePts do -- 533
				withAnchorPts[#withAnchorPts + 1] = corePts[i + 1] -- 534
				withAnchorRadii[#withAnchorRadii + 1] = coreRadii[i + 1] -- 535
				i = i + 1 -- 533
			end -- 533
		end -- 533
		local want = deps.rig.wantDistance(withAnchorPts, deps.scene.probeRadius, withAnchorRadii) -- 537
		if want <= CameraFramingBudget then -- 537
			return {pts = withAnchorPts, radii = withAnchorRadii} -- 538
		end -- 538
		return {pts = corePts, radii = coreRadii} -- 539
	end -- 511
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 543
		local wps = goalWaypoints(level.goal) -- 544
		if #wps == 0 then -- 544
			return {} -- 545
		end -- 545
		local passed = 0 -- 546
		if upto ~= nil and core.flight ~= nil then -- 546
			passed = waypointProgress( -- 548
				core.flight.points, -- 548
				level.bodies, -- 548
				level.goal, -- 548
				core.dt, -- 548
				core.t0, -- 548
				upto, -- 548
				core.flight.velocities -- 548
			).passed -- 548
		end -- 548
		if passed >= #wps then -- 548
			return {} -- 553
		end -- 553
		local nextWp = wps[passed + 1] -- 554
		local body = level.bodies[nextWp.planetIndex + 1] -- 555
		if body == nil then -- 555
			return {} -- 556
		end -- 556
		return {{ -- 557
			center = bodyPositionAt(body, t), -- 557
			radius = nextWp.tolerance, -- 557
			passed = false -- 557
		}} -- 557
	end -- 543
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 561
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 561
			return f -- 562
		end -- 562
		local dx = f.eye.x - f.target.x -- 563
		local dy = f.eye.y - f.target.y -- 564
		local dz = f.eye.z - f.target.z -- 565
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 566
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 567
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 568
		local lo = CameraTiltMin * math.pi / 180 -- 569
		local hi = CameraTiltMax * math.pi / 180 -- 570
		if pitch < lo then -- 570
			pitch = lo -- 571
		end -- 571
		if pitch > hi then -- 571
			pitch = hi -- 572
		end -- 572
		local cp = math.cos(pitch) -- 573
		return { -- 574
			target = f.target, -- 575
			eye = Vec3( -- 576
				f.target.x + r * cp * math.sin(yaw), -- 577
				f.target.y + r * math.sin(pitch), -- 578
				f.target.z + r * cp * math.cos(yaw) -- 579
			) -- 579
		} -- 579
	end -- 561
	local function updateAiming(dt) -- 584
		deps.aim:setEnabled(true) -- 585
		local dragging = deps.aim:isDragging() -- 587
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 587
			clock = clock + dt -- 590
			orbitClock = orbitClock + dt -- 591
		end -- 591
		local idx = idleIndex() -- 593
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 594
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 595
		local tNow = core.t0 + clock -- 598
		deps.scene.syncBodies(tNow) -- 600
		deps.scene.syncProbe(probePos) -- 601
		if idlePath ~= nil and idx > 0 then -- 601
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 602
		end -- 602
		local fr = framingPoints(probePos, tNow) -- 605
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 606
		if introT < IntroDurationSec then -- 606
			introT = introT + dt -- 610
			local k = introT / IntroDurationSec -- 611
			if k > 1 then -- 611
				k = 1 -- 612
			end -- 612
			if k >= 1 and not introLogged then -- 612
				introLogged = true -- 614
				print("[escape-velocity] intro camera done") -- 615
			end -- 615
			local wps0 = goalWaypoints(level.goal) -- 617
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 618
			local wide = frame -- 619
			local from = wide -- 620
			local to = wide -- 621
			local e = 0 -- 622
			if k < 0.35 then -- 622
				local pw = planeToWorld(probePos, 0) -- 624
				local dx = wide.eye.x - wide.target.x -- 625
				local dy = wide.eye.y - wide.target.y -- 626
				local dz = wide.eye.z - wide.target.z -- 627
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 628
				if len > 0.000001 then -- 628
					local s = IntroCloseDist / len -- 630
					dx = dx * s -- 631
					dy = dy * s -- 631
					dz = dz * s -- 631
				end -- 631
				from = { -- 633
					target = Vec3(pw.x, pw.y, pw.z), -- 633
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 633
				} -- 633
				e = k / 0.35 -- 634
			elseif k < 0.72 and wpBody ~= nil then -- 634
				local c = planeToWorld( -- 637
					bodyPositionAt(wpBody, tNow), -- 637
					0 -- 637
				) -- 637
				local dx = wide.eye.x - wide.target.x -- 638
				local dy = wide.eye.y - wide.target.y -- 639
				local dz = wide.eye.z - wide.target.z -- 640
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 641
				local want = math.max(24, wpBody.radius * 6) -- 642
				if len > 0.000001 then -- 642
					local s = want / len -- 644
					dx = dx * s -- 645
					dy = dy * s -- 645
					dz = dz * s -- 645
				end -- 645
				to = { -- 647
					target = Vec3(c.x, c.y, c.z), -- 647
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 647
				} -- 647
				e = (k - 0.35) / 0.37 -- 648
			elseif wpBody ~= nil then -- 648
				local c = planeToWorld( -- 651
					bodyPositionAt(wpBody, tNow), -- 651
					0 -- 651
				) -- 651
				local dx = wide.eye.x - wide.target.x -- 652
				local dy = wide.eye.y - wide.target.y -- 653
				local dz = wide.eye.z - wide.target.z -- 654
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 655
				local want = math.max(24, wpBody.radius * 6) -- 656
				if len > 0.000001 then -- 656
					local s = want / len -- 658
					dx = dx * s -- 659
					dy = dy * s -- 659
					dz = dz * s -- 659
				end -- 659
				from = { -- 661
					target = Vec3(c.x, c.y, c.z), -- 661
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 661
				} -- 661
				e = (k - 0.72) / 0.28 -- 662
			end -- 662
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 664
			frame = { -- 665
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 666
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 671
			} -- 671
		end -- 671
		frame = applyObserve(frame) -- 679
		deps.rig.apply(deps.camera, frame) -- 680
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 681
		local basis = makeBasis(frame) -- 682
		local pp = projectPrepared( -- 685
			planeToWorld(probePos, 0), -- 685
			basis -- 685
		) -- 685
		if pp ~= nil then -- 685
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 686
		end -- 686
		if not aimed then -- 686
			deps.trajectory:clearPrediction() -- 698
			predKey = "" -- 699
		else -- 699
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 703
			if key ~= predKey then -- 703
				predKey = key -- 707
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 710
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 711
					steps = PredictSteps, -- 714
					dt = core.dt, -- 714
					sampleEvery = 4, -- 714
					escapeRadius = level.escapeRadius, -- 714
					t0 = tNow, -- 714
					brake = motion.brake -- 714
				}).points -- 714
			end -- 714
			deps.trajectory:setPrediction(predPoints, basis) -- 717
		end -- 717
		deps.trajectory:setGoalRings( -- 719
			goalRingsAt(tNow), -- 719
			basis -- 719
		) -- 719
		deps.trajectory:clearTrail() -- 720
	end -- 584
	local function updateFlying(dt) -- 723
		deps.aim:setEnabled(false) -- 724
		local entered = ____exports.coreUpdate(core, dt) -- 725
		if core.flight == nil then -- 725
			return entered -- 726
		end -- 726
		local idx = ____exports.coreProbeIndex(core) -- 728
		local pos = core.flight.points[idx + 1] -- 729
		local tWorld = core.t0 + core.flightTime -- 733
		deps.scene.syncBodies(tWorld) -- 735
		deps.scene.syncProbe(pos) -- 736
		if idx > 0 then -- 736
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 738
		end -- 738
		local fr = framingPoints(pos, tWorld) -- 741
		local frame = deps.rig.step(fr.pts, deps.scene.probeRadius, fr.radii) -- 742
		deps.rig.apply(deps.camera, frame) -- 743
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 744
		local basis = makeBasis(frame) -- 745
		local trail = {} -- 748
		do -- 748
			local i = 0 -- 749
			while i <= idx do -- 749
				trail[#trail + 1] = core.flight.points[i + 1] -- 749
				i = i + 1 -- 749
			end -- 749
		end -- 749
		deps.trajectory:setTrail(trail, basis) -- 750
		deps.trajectory:setGoalRings( -- 751
			goalRingsAt(tWorld, idx), -- 751
			basis -- 751
		) -- 751
		return entered -- 753
	end -- 723
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 767
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 768
		core.t0 = next.t0 -- 769
		clock = next.clock -- 770
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 771
	end -- 767
	local function update(dt) -- 774
		if core.phase == "Aiming" or core.phase == "Armed" then -- 774
			updateAiming(dt) -- 776
		elseif core.phase == "Flying" then -- 776
			local entered = updateFlying(dt) -- 778
			if entered and core.result ~= nil then -- 778
				deps:onResult(core.result) -- 780
				deps:onPhase("Result") -- 781
			end -- 781
		end -- 781
	end -- 774
	return { -- 787
		phase = function() return core.phase end, -- 788
		result = function() return core.result end, -- 789
		onAimDrag = function(____, a) -- 790
			core.aim = a -- 791
			aimed = true -- 792
			introT = IntroDurationSec -- 793
		end, -- 790
		aimReady = function() -- 795
			if not ____exports.coreArm(core) then -- 795
				return -- 796
			end -- 796
			deps:onPhase("Armed") -- 797
		end, -- 795
		launchArmed = function() -- 799
			if core.phase ~= "Armed" then -- 799
				return -- 801
			end -- 801
			handoffDate(true) -- 802
			____exports.coreLaunch( -- 803
				core, -- 803
				core.aim.velocity, -- 803
				level, -- 803
				probePos, -- 803
				probeVel -- 803
			) -- 803
			deps.trajectory:clearPrediction() -- 804
			deps:onPhase("Flying") -- 805
		end, -- 799
		armed = function() return core.phase == "Armed" end, -- 807
		observeDrag = function(____, dx, dy) -- 808
			introT = IntroDurationSec -- 809
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 810
			obsYawDeg = obsYawDeg + dx * 0.35 -- 811
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 812
			if obsPitchDeg > 40 then -- 812
				obsPitchDeg = 40 -- 813
			end -- 813
			if obsPitchDeg < -40 then -- 813
				obsPitchDeg = -40 -- 814
			end -- 814
		end, -- 808
		observeZoom = function(____, deltaDist) -- 816
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 817
			if obsZoom < 0.4 then -- 817
				obsZoom = 0.4 -- 818
			end -- 818
			if obsZoom > 1.8 then -- 818
				obsZoom = 1.8 -- 819
			end -- 819
		end, -- 816
		launch = function(____, v) -- 821
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 821
				return -- 822
			end -- 822
			handoffDate(true) -- 823
			____exports.coreLaunch( -- 825
				core, -- 825
				v, -- 825
				level, -- 825
				probePos, -- 825
				probeVel -- 825
			) -- 825
			deps.trajectory:clearPrediction() -- 826
			deps:onPhase("Flying") -- 827
		end, -- 821
		retry = function() -- 829
			if core.phase ~= "Result" then -- 829
				return -- 830
			end -- 830
			handoffDate(false) -- 831
			aimed = false -- 832
			____exports.coreRetry(core) -- 833
			deps.trajectory:clearTrail() -- 834
			deps.trajectory:clearPrediction() -- 835
			deps.trajectory:clearGoalRings() -- 836
			deps:onPhase("Aiming") -- 837
		end, -- 829
		backToSelect = function() -- 839
			if not ____exports.coreBackToSelect(core) then -- 839
				return false -- 840
			end -- 840
			deps.aim:setEnabled(false) -- 842
			deps.trajectory:clearTrail() -- 843
			deps.trajectory:clearPrediction() -- 844
			deps.trajectory:clearGoalRings() -- 845
			deps:onPhase("LevelSelect") -- 846
			return true -- 847
		end, -- 839
		startLevel = function() -- 849
			aimed = false -- 852
			____exports.coreRetry(core) -- 853
			introT = 0 -- 854
			introLogged = false -- 855
			prepareIdle() -- 856
			deps.trajectory:clearTrail() -- 857
			deps.trajectory:clearPrediction() -- 858
			deps.trajectory:clearGoalRings() -- 859
			deps:onPhase("Aiming") -- 860
		end, -- 849
		stepTime = function(____, dir, span) -- 862
			if not ____exports.coreTimeWarpAllowed(core) then -- 862
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 866
				return -- 867
			end -- 867
			local span0 = span > 0 and span or 0 -- 869
			clock = clock + dir * TimeWarpStep -- 870
			if clock < 0 then -- 870
				clock = 0 -- 871
			end -- 871
			if span0 > 0 and clock > span0 then -- 871
				clock = span0 -- 872
			end -- 872
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 874
		end, -- 862
		dateNow = function() return core.t0 + clock end, -- 876
		setBrakeMode = function(____, on) -- 877
			core.brakeMode = on -- 878
		end, -- 877
		brakeMode = function() return core.brakeMode end, -- 881
		update = function(____, frameDt) return update(frameDt) end -- 883
	} -- 883
end -- 371
return ____exports -- 371
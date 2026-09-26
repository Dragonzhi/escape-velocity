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
local CameraTiltMax = ____Config.CameraTiltMax -- 35
local CameraTiltMin = ____Config.CameraTiltMin -- 35
local FlightPlayback = ____Config.FlightPlayback -- 35
local IntroCloseDist = ____Config.IntroCloseDist -- 35
local IntroDurationSec = ____Config.IntroDurationSec -- 35
local PhysicsStep = ____Config.PhysicsStep -- 35
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
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 479
		local wps = goalWaypoints(level.goal) -- 480
		if #wps == 0 then -- 480
			return {} -- 481
		end -- 481
		local passed = 0 -- 482
		if upto ~= nil and core.flight ~= nil then -- 482
			passed = waypointProgress( -- 484
				core.flight.points, -- 484
				level.bodies, -- 484
				level.goal, -- 484
				core.dt, -- 484
				core.t0, -- 484
				upto, -- 484
				core.flight.velocities -- 484
			).passed -- 484
		end -- 484
		if passed >= #wps then -- 484
			return {} -- 489
		end -- 489
		local nextWp = wps[passed + 1] -- 490
		local body = level.bodies[nextWp.planetIndex + 1] -- 491
		if body == nil then -- 491
			return {} -- 492
		end -- 492
		return {{ -- 493
			center = bodyPositionAt(body, t), -- 493
			radius = nextWp.tolerance, -- 493
			passed = false -- 493
		}} -- 493
	end -- 479
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 497
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 497
			return f -- 498
		end -- 498
		local dx = f.eye.x - f.target.x -- 499
		local dy = f.eye.y - f.target.y -- 500
		local dz = f.eye.z - f.target.z -- 501
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 502
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 503
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 504
		local lo = CameraTiltMin * math.pi / 180 -- 505
		local hi = CameraTiltMax * math.pi / 180 -- 506
		if pitch < lo then -- 506
			pitch = lo -- 507
		end -- 507
		if pitch > hi then -- 507
			pitch = hi -- 508
		end -- 508
		local cp = math.cos(pitch) -- 509
		return { -- 510
			target = f.target, -- 511
			eye = Vec3( -- 512
				f.target.x + r * cp * math.sin(yaw), -- 513
				f.target.y + r * math.sin(pitch), -- 514
				f.target.z + r * cp * math.cos(yaw) -- 515
			) -- 515
		} -- 515
	end -- 497
	local function updateAiming(dt) -- 520
		deps.aim:setEnabled(true) -- 521
		local dragging = deps.aim:isDragging() -- 523
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 523
			clock = clock + dt -- 526
			orbitClock = orbitClock + dt -- 527
		end -- 527
		local idx = idleIndex() -- 529
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 530
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 531
		local tNow = core.t0 + clock -- 534
		deps.scene.syncBodies(tNow) -- 536
		deps.scene.syncProbe(probePos) -- 537
		if idlePath ~= nil and idx > 0 then -- 537
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 538
		end -- 538
		local planetPts = {} -- 540
		for ____, p in ipairs(deps.scene.planets) do -- 541
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 541
		end -- 541
		local frame = deps.rig.step( -- 543
			{ -- 543
				probePos, -- 543
				table.unpack(planetPts) -- 543
			}, -- 543
			deps.scene.probeRadius -- 543
		) -- 543
		if introT < IntroDurationSec then -- 543
			introT = introT + dt -- 547
			local k = introT / IntroDurationSec -- 548
			if k > 1 then -- 548
				k = 1 -- 549
			end -- 549
			if k >= 1 and not introLogged then -- 549
				introLogged = true -- 551
				print("[escape-velocity] intro camera done") -- 552
			end -- 552
			local wps0 = goalWaypoints(level.goal) -- 554
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 555
			local wide = frame -- 556
			local from = wide -- 557
			local to = wide -- 558
			local e = 0 -- 559
			if k < 0.35 then -- 559
				local pw = planeToWorld(probePos, 0) -- 561
				local dx = wide.eye.x - wide.target.x -- 562
				local dy = wide.eye.y - wide.target.y -- 563
				local dz = wide.eye.z - wide.target.z -- 564
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 565
				if len > 0.000001 then -- 565
					local s = IntroCloseDist / len -- 567
					dx = dx * s -- 568
					dy = dy * s -- 568
					dz = dz * s -- 568
				end -- 568
				from = { -- 570
					target = Vec3(pw.x, pw.y, pw.z), -- 570
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 570
				} -- 570
				e = k / 0.35 -- 571
			elseif k < 0.72 and wpBody ~= nil then -- 571
				local c = planeToWorld( -- 574
					bodyPositionAt(wpBody, tNow), -- 574
					0 -- 574
				) -- 574
				local dx = wide.eye.x - wide.target.x -- 575
				local dy = wide.eye.y - wide.target.y -- 576
				local dz = wide.eye.z - wide.target.z -- 577
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 578
				local want = math.max(24, wpBody.radius * 6) -- 579
				if len > 0.000001 then -- 579
					local s = want / len -- 581
					dx = dx * s -- 582
					dy = dy * s -- 582
					dz = dz * s -- 582
				end -- 582
				to = { -- 584
					target = Vec3(c.x, c.y, c.z), -- 584
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 584
				} -- 584
				e = (k - 0.35) / 0.37 -- 585
			elseif wpBody ~= nil then -- 585
				local c = planeToWorld( -- 588
					bodyPositionAt(wpBody, tNow), -- 588
					0 -- 588
				) -- 588
				local dx = wide.eye.x - wide.target.x -- 589
				local dy = wide.eye.y - wide.target.y -- 590
				local dz = wide.eye.z - wide.target.z -- 591
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 592
				local want = math.max(24, wpBody.radius * 6) -- 593
				if len > 0.000001 then -- 593
					local s = want / len -- 595
					dx = dx * s -- 596
					dy = dy * s -- 596
					dz = dz * s -- 596
				end -- 596
				from = { -- 598
					target = Vec3(c.x, c.y, c.z), -- 598
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 598
				} -- 598
				e = (k - 0.72) / 0.28 -- 599
			end -- 599
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 601
			frame = { -- 602
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 603
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 608
			} -- 608
		end -- 608
		frame = applyObserve(frame) -- 616
		deps.rig.apply(deps.camera, frame) -- 617
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 618
		local basis = makeBasis(frame) -- 619
		local pp = projectPrepared( -- 622
			planeToWorld(probePos, 0), -- 622
			basis -- 622
		) -- 622
		if pp ~= nil then -- 622
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 623
		end -- 623
		if not aimed then -- 623
			deps.trajectory:clearPrediction() -- 635
			predKey = "" -- 636
		else -- 636
			local key = (((((((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(tNow, 2)) .. "|") .. __TS__NumberToFixed(probePos.x, 2)) .. ",") .. __TS__NumberToFixed(probePos.y, 2)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 640
			if key ~= predKey then -- 640
				predKey = key -- 644
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 647
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 648
					steps = PredictSteps, -- 651
					dt = core.dt, -- 651
					sampleEvery = 4, -- 651
					escapeRadius = level.escapeRadius, -- 651
					t0 = tNow, -- 651
					brake = motion.brake -- 651
				}).points -- 651
			end -- 651
			deps.trajectory:setPrediction(predPoints, basis) -- 654
		end -- 654
		deps.trajectory:setGoalRings( -- 656
			goalRingsAt(tNow), -- 656
			basis -- 656
		) -- 656
		deps.trajectory:clearTrail() -- 657
	end -- 520
	local function updateFlying(dt) -- 660
		deps.aim:setEnabled(false) -- 661
		local entered = ____exports.coreUpdate(core, dt) -- 662
		if core.flight == nil then -- 662
			return entered -- 663
		end -- 663
		local idx = ____exports.coreProbeIndex(core) -- 665
		local pos = core.flight.points[idx + 1] -- 666
		local tWorld = core.t0 + core.flightTime -- 670
		deps.scene.syncBodies(tWorld) -- 672
		deps.scene.syncProbe(pos) -- 673
		if idx > 0 then -- 673
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 675
		end -- 675
		local planetPts = {} -- 678
		for ____, p in ipairs(deps.scene.planets) do -- 679
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tWorld) -- 679
		end -- 679
		local frame = deps.rig.step( -- 681
			{ -- 681
				pos, -- 681
				table.unpack(planetPts) -- 681
			}, -- 681
			deps.scene.probeRadius -- 681
		) -- 681
		deps.rig.apply(deps.camera, frame) -- 682
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 683
		local basis = makeBasis(frame) -- 684
		local trail = {} -- 687
		do -- 687
			local i = 0 -- 688
			while i <= idx do -- 688
				trail[#trail + 1] = core.flight.points[i + 1] -- 688
				i = i + 1 -- 688
			end -- 688
		end -- 688
		deps.trajectory:setTrail(trail, basis) -- 689
		deps.trajectory:setGoalRings( -- 690
			goalRingsAt(tWorld, idx), -- 690
			basis -- 690
		) -- 690
		return entered -- 692
	end -- 660
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 706
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 707
		core.t0 = next.t0 -- 708
		clock = next.clock -- 709
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 710
	end -- 706
	local function update(dt) -- 713
		if core.phase == "Aiming" or core.phase == "Armed" then -- 713
			updateAiming(dt) -- 715
		elseif core.phase == "Flying" then -- 715
			local entered = updateFlying(dt) -- 717
			if entered and core.result ~= nil then -- 717
				deps:onResult(core.result) -- 719
				deps:onPhase("Result") -- 720
			end -- 720
		end -- 720
	end -- 713
	return { -- 726
		phase = function() return core.phase end, -- 727
		result = function() return core.result end, -- 728
		onAimDrag = function(____, a) -- 729
			core.aim = a -- 730
			aimed = true -- 731
			introT = IntroDurationSec -- 732
		end, -- 729
		aimReady = function() -- 734
			if not ____exports.coreArm(core) then -- 734
				return -- 735
			end -- 735
			deps:onPhase("Armed") -- 736
		end, -- 734
		launchArmed = function() -- 738
			if core.phase ~= "Armed" then -- 738
				return -- 740
			end -- 740
			handoffDate(true) -- 741
			____exports.coreLaunch( -- 742
				core, -- 742
				core.aim.velocity, -- 742
				level, -- 742
				probePos, -- 742
				probeVel -- 742
			) -- 742
			deps.trajectory:clearPrediction() -- 743
			deps:onPhase("Flying") -- 744
		end, -- 738
		armed = function() return core.phase == "Armed" end, -- 746
		observeDrag = function(____, dx, dy) -- 747
			introT = IntroDurationSec -- 748
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 749
			obsYawDeg = obsYawDeg + dx * 0.35 -- 750
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 751
			if obsPitchDeg > 40 then -- 751
				obsPitchDeg = 40 -- 752
			end -- 752
			if obsPitchDeg < -40 then -- 752
				obsPitchDeg = -40 -- 753
			end -- 753
		end, -- 747
		observeZoom = function(____, deltaDist) -- 755
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 756
			if obsZoom < 0.4 then -- 756
				obsZoom = 0.4 -- 757
			end -- 757
			if obsZoom > 1.8 then -- 757
				obsZoom = 1.8 -- 758
			end -- 758
		end, -- 755
		launch = function(____, v) -- 760
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 760
				return -- 761
			end -- 761
			handoffDate(true) -- 762
			____exports.coreLaunch( -- 764
				core, -- 764
				v, -- 764
				level, -- 764
				probePos, -- 764
				probeVel -- 764
			) -- 764
			deps.trajectory:clearPrediction() -- 765
			deps:onPhase("Flying") -- 766
		end, -- 760
		retry = function() -- 768
			if core.phase ~= "Result" then -- 768
				return -- 769
			end -- 769
			handoffDate(false) -- 770
			aimed = false -- 771
			____exports.coreRetry(core) -- 772
			deps.trajectory:clearTrail() -- 773
			deps.trajectory:clearPrediction() -- 774
			deps.trajectory:clearGoalRings() -- 775
			deps:onPhase("Aiming") -- 776
		end, -- 768
		backToSelect = function() -- 778
			if not ____exports.coreBackToSelect(core) then -- 778
				return false -- 779
			end -- 779
			deps.aim:setEnabled(false) -- 781
			deps.trajectory:clearTrail() -- 782
			deps.trajectory:clearPrediction() -- 783
			deps.trajectory:clearGoalRings() -- 784
			deps:onPhase("LevelSelect") -- 785
			return true -- 786
		end, -- 778
		startLevel = function() -- 788
			aimed = false -- 791
			____exports.coreRetry(core) -- 792
			introT = 0 -- 793
			introLogged = false -- 794
			prepareIdle() -- 795
			deps.trajectory:clearTrail() -- 796
			deps.trajectory:clearPrediction() -- 797
			deps.trajectory:clearGoalRings() -- 798
			deps:onPhase("Aiming") -- 799
		end, -- 788
		stepTime = function(____, dir, span) -- 801
			if not ____exports.coreTimeWarpAllowed(core) then -- 801
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 805
				return -- 806
			end -- 806
			local span0 = span > 0 and span or 0 -- 808
			clock = clock + dir * TimeWarpStep -- 809
			if clock < 0 then -- 809
				clock = 0 -- 810
			end -- 810
			if span0 > 0 and clock > span0 then -- 810
				clock = span0 -- 811
			end -- 811
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 813
		end, -- 801
		dateNow = function() return core.t0 + clock end, -- 815
		setBrakeMode = function(____, on) -- 816
			core.brakeMode = on -- 817
		end, -- 816
		brakeMode = function() return core.brakeMode end, -- 820
		update = function(____, frameDt) return update(frameDt) end -- 822
	} -- 822
end -- 371
return ____exports -- 371
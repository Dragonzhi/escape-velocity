-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
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
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 418
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 419
	local function prepareIdle() -- 420
		clock = 0 -- 422
		core.t0 = 0 -- 423
		if level.probeVel0 == nil then -- 423
			idlePath = nil -- 425
			return -- 426
		end -- 426
		local idleSteps = level.maxSteps -- 434
		local v0x = level.probeVel0.x -- 435
		local v0y = level.probeVel0.y -- 436
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 437
		if v0 > 0.000001 then -- 437
			local bestD = 1000000000 -- 439
			for ____, b in ipairs(level.bodies) do -- 440
				do -- 440
					if b.gm <= 0 then -- 440
						goto __continue33 -- 441
					end -- 441
					local dx = b.orbitCenter.x - level.probeStart.x -- 442
					local dy = b.orbitCenter.y - level.probeStart.y -- 443
					local d = math.sqrt(dx * dx + dy * dy) -- 444
					if d < bestD then -- 444
						bestD = d -- 445
					end -- 445
				end -- 445
				::__continue33:: -- 445
			end -- 445
			if bestD > 0.000001 and bestD < 100000000 then -- 445
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 448
				if n > 60 and n < 40000 then -- 448
					idleSteps = n -- 449
				end -- 449
			end -- 449
		end -- 449
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 452
			steps = idleSteps, -- 455
			dt = core.dt, -- 455
			sampleEvery = 1, -- 455
			escapeRadius = level.escapeRadius, -- 455
			t0 = core.t0 -- 455
		}) -- 455
	end -- 420
	local function idleIndex() -- 458
		if idlePath == nil then -- 458
			return 0 -- 459
		end -- 459
		local n = #idlePath.points -- 460
		if n <= 1 then -- 460
			return 0 -- 461
		end -- 461
		local i = math.floor(orbitClock / core.dt) % n -- 462
		if i < 0 then -- 462
			i = 0 -- 463
		end -- 463
		return i -- 464
	end -- 458
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 468
		local wps = goalWaypoints(level.goal) -- 469
		if #wps == 0 then -- 469
			return {} -- 470
		end -- 470
		local passed = 0 -- 471
		if upto ~= nil and core.flight ~= nil then -- 471
			passed = waypointProgress( -- 473
				core.flight.points, -- 473
				level.bodies, -- 473
				level.goal, -- 473
				core.dt, -- 473
				core.t0, -- 473
				upto, -- 473
				core.flight.velocities -- 473
			).passed -- 473
		end -- 473
		if passed >= #wps then -- 473
			return {} -- 478
		end -- 478
		local nextWp = wps[passed + 1] -- 479
		local body = level.bodies[nextWp.planetIndex + 1] -- 480
		if body == nil then -- 480
			return {} -- 481
		end -- 481
		return {{ -- 482
			center = bodyPositionAt(body, t), -- 482
			radius = nextWp.tolerance, -- 482
			passed = false -- 482
		}} -- 482
	end -- 468
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 486
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 486
			return f -- 487
		end -- 487
		local dx = f.eye.x - f.target.x -- 488
		local dy = f.eye.y - f.target.y -- 489
		local dz = f.eye.z - f.target.z -- 490
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 491
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 492
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 493
		local lo = CameraTiltMin * math.pi / 180 -- 494
		local hi = CameraTiltMax * math.pi / 180 -- 495
		if pitch < lo then -- 495
			pitch = lo -- 496
		end -- 496
		if pitch > hi then -- 496
			pitch = hi -- 497
		end -- 497
		local cp = math.cos(pitch) -- 498
		return { -- 499
			target = f.target, -- 500
			eye = Vec3( -- 501
				f.target.x + r * cp * math.sin(yaw), -- 502
				f.target.y + r * math.sin(pitch), -- 503
				f.target.z + r * cp * math.cos(yaw) -- 504
			) -- 504
		} -- 504
	end -- 486
	local function updateAiming(dt) -- 509
		deps.aim:setEnabled(true) -- 510
		local dragging = deps.aim:isDragging() -- 512
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 512
			clock = clock + dt -- 515
			orbitClock = orbitClock + dt -- 516
		end -- 516
		local idx = idleIndex() -- 518
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 519
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 520
		local tNow = core.t0 + clock -- 523
		deps.scene.syncBodies(tNow) -- 525
		deps.scene.syncProbe(probePos) -- 526
		if idlePath ~= nil and idx > 0 then -- 526
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 527
		end -- 527
		local planetPts = {} -- 529
		for ____, p in ipairs(deps.scene.planets) do -- 530
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 530
		end -- 530
		local frame = deps.rig.step( -- 532
			{ -- 532
				probePos, -- 532
				table.unpack(planetPts) -- 532
			}, -- 532
			deps.scene.probeRadius -- 532
		) -- 532
		if introT < IntroDurationSec then -- 532
			introT = introT + dt -- 536
			local k = introT / IntroDurationSec -- 537
			if k > 1 then -- 537
				k = 1 -- 538
			end -- 538
			if k >= 1 and not introLogged then -- 538
				introLogged = true -- 540
				print("[escape-velocity] intro camera done") -- 541
			end -- 541
			local wps0 = goalWaypoints(level.goal) -- 543
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 544
			local wide = frame -- 545
			local from = wide -- 546
			local to = wide -- 547
			local e = 0 -- 548
			if k < 0.35 then -- 548
				local pw = planeToWorld(probePos, 0) -- 550
				local dx = wide.eye.x - wide.target.x -- 551
				local dy = wide.eye.y - wide.target.y -- 552
				local dz = wide.eye.z - wide.target.z -- 553
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 554
				if len > 0.000001 then -- 554
					local s = IntroCloseDist / len -- 556
					dx = dx * s -- 557
					dy = dy * s -- 557
					dz = dz * s -- 557
				end -- 557
				from = { -- 559
					target = Vec3(pw.x, pw.y, pw.z), -- 559
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 559
				} -- 559
				e = k / 0.35 -- 560
			elseif k < 0.72 and wpBody ~= nil then -- 560
				local c = planeToWorld( -- 563
					bodyPositionAt(wpBody, tNow), -- 563
					0 -- 563
				) -- 563
				local dx = wide.eye.x - wide.target.x -- 564
				local dy = wide.eye.y - wide.target.y -- 565
				local dz = wide.eye.z - wide.target.z -- 566
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 567
				local want = math.max(24, wpBody.radius * 6) -- 568
				if len > 0.000001 then -- 568
					local s = want / len -- 570
					dx = dx * s -- 571
					dy = dy * s -- 571
					dz = dz * s -- 571
				end -- 571
				to = { -- 573
					target = Vec3(c.x, c.y, c.z), -- 573
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 573
				} -- 573
				e = (k - 0.35) / 0.37 -- 574
			elseif wpBody ~= nil then -- 574
				local c = planeToWorld( -- 577
					bodyPositionAt(wpBody, tNow), -- 577
					0 -- 577
				) -- 577
				local dx = wide.eye.x - wide.target.x -- 578
				local dy = wide.eye.y - wide.target.y -- 579
				local dz = wide.eye.z - wide.target.z -- 580
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 581
				local want = math.max(24, wpBody.radius * 6) -- 582
				if len > 0.000001 then -- 582
					local s = want / len -- 584
					dx = dx * s -- 585
					dy = dy * s -- 585
					dz = dz * s -- 585
				end -- 585
				from = { -- 587
					target = Vec3(c.x, c.y, c.z), -- 587
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 587
				} -- 587
				e = (k - 0.72) / 0.28 -- 588
			end -- 588
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 590
			frame = { -- 591
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 592
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 597
			} -- 597
		end -- 597
		frame = applyObserve(frame) -- 605
		deps.rig.apply(deps.camera, frame) -- 606
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 607
		local basis = makeBasis(frame) -- 608
		local pp = projectPrepared( -- 611
			planeToWorld(probePos, 0), -- 611
			basis -- 611
		) -- 611
		if pp ~= nil then -- 611
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 612
		end -- 612
		if not dragging and idlePath ~= nil then -- 612
			deps.trajectory:setPrediction( -- 622
				__TS__ArraySlice(idlePath.points, idx), -- 622
				basis -- 622
			) -- 622
		else -- 622
			local key = (((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 624
			if key ~= predKey then -- 624
				predKey = key -- 627
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 630
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 631
					steps = PredictSteps, -- 634
					dt = core.dt, -- 634
					sampleEvery = 4, -- 634
					escapeRadius = level.escapeRadius, -- 634
					t0 = tNow, -- 634
					brake = motion.brake -- 634
				}).points -- 634
			end -- 634
			deps.trajectory:setPrediction(predPoints, basis) -- 637
		end -- 637
		deps.trajectory:setGoalRings( -- 639
			goalRingsAt(tNow), -- 639
			basis -- 639
		) -- 639
		deps.trajectory:clearTrail() -- 640
	end -- 509
	local function updateFlying(dt) -- 643
		deps.aim:setEnabled(false) -- 644
		local entered = ____exports.coreUpdate(core, dt) -- 645
		if core.flight == nil then -- 645
			return entered -- 646
		end -- 646
		local idx = ____exports.coreProbeIndex(core) -- 648
		local pos = core.flight.points[idx + 1] -- 649
		local tWorld = core.t0 + core.flightTime -- 653
		deps.scene.syncBodies(tWorld) -- 655
		deps.scene.syncProbe(pos) -- 656
		if idx > 0 then -- 656
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 658
		end -- 658
		local planetPts = {} -- 661
		for ____, p in ipairs(deps.scene.planets) do -- 662
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tWorld) -- 662
		end -- 662
		local frame = deps.rig.step( -- 664
			{ -- 664
				pos, -- 664
				table.unpack(planetPts) -- 664
			}, -- 664
			deps.scene.probeRadius -- 664
		) -- 664
		deps.rig.apply(deps.camera, frame) -- 665
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 666
		local basis = makeBasis(frame) -- 667
		local trail = {} -- 670
		do -- 670
			local i = 0 -- 671
			while i <= idx do -- 671
				trail[#trail + 1] = core.flight.points[i + 1] -- 671
				i = i + 1 -- 671
			end -- 671
		end -- 671
		deps.trajectory:setTrail(trail, basis) -- 672
		deps.trajectory:setGoalRings( -- 673
			goalRingsAt(tWorld, idx), -- 673
			basis -- 673
		) -- 673
		return entered -- 675
	end -- 643
	--- **发射日期交棒**（S3.12 修 bug：发射瞬间行星跳回原位）。
	-- 
	-- 事实来源只有一个：tWorld = core.t0 + core.flightTime（AGENTS 硬约束 7）。
	-- 发射前玩家用「加速 / 回退」拨出来的是 clock（瞄准期的世界时钟），
	-- 而 coreLaunch 是**纯函数**、只认 core.t0 —— 过去没有人把两者接起来，
	-- 于是 L4/L6 一按「发射」，行星就从"第 180 秒"跳回"第 0 秒"（用户会话 44 的原话）。
	-- 
	-- toT0 = true：发射时 clock → t0（dateNow() 与瞄准期的 tNow 都不变，画面不跳）；
	-- toT0 = false：重试时 t0 → clock（**保留玩家挑好的日期**，L4 才能就着这个日期继续调）。
	local function handoffDate(toT0) -- 689
		local next = ____exports.coreHandoffDate(core.t0, clock, toT0) -- 690
		core.t0 = next.t0 -- 691
		clock = next.clock -- 692
		print((((("[escape-velocity] date handoff " .. (toT0 and "clock->t0" or "t0->clock")) .. " t0=") .. __TS__NumberToFixed(core.t0, 1)) .. " clock=") .. __TS__NumberToFixed(clock, 1)) -- 693
	end -- 689
	local function update(dt) -- 696
		if core.phase == "Aiming" or core.phase == "Armed" then -- 696
			updateAiming(dt) -- 698
		elseif core.phase == "Flying" then -- 698
			local entered = updateFlying(dt) -- 700
			if entered and core.result ~= nil then -- 700
				deps:onResult(core.result) -- 702
				deps:onPhase("Result") -- 703
			end -- 703
		end -- 703
	end -- 696
	return { -- 709
		phase = function() return core.phase end, -- 710
		result = function() return core.result end, -- 711
		onAimDrag = function(____, a) -- 712
			core.aim = a -- 713
			introT = IntroDurationSec -- 714
		end, -- 712
		aimReady = function() -- 716
			if not ____exports.coreArm(core) then -- 716
				return -- 717
			end -- 717
			deps:onPhase("Armed") -- 718
		end, -- 716
		launchArmed = function() -- 720
			if core.phase ~= "Armed" then -- 720
				return -- 722
			end -- 722
			handoffDate(true) -- 723
			____exports.coreLaunch( -- 724
				core, -- 724
				core.aim.velocity, -- 724
				level, -- 724
				probePos, -- 724
				probeVel -- 724
			) -- 724
			deps.trajectory:clearPrediction() -- 725
			deps:onPhase("Flying") -- 726
		end, -- 720
		armed = function() return core.phase == "Armed" end, -- 728
		observeDrag = function(____, dx, dy) -- 729
			introT = IntroDurationSec -- 730
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 731
			obsYawDeg = obsYawDeg + dx * 0.35 -- 732
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 733
			if obsPitchDeg > 40 then -- 733
				obsPitchDeg = 40 -- 734
			end -- 734
			if obsPitchDeg < -40 then -- 734
				obsPitchDeg = -40 -- 735
			end -- 735
		end, -- 729
		observeZoom = function(____, deltaDist) -- 737
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 738
			if obsZoom < 0.4 then -- 738
				obsZoom = 0.4 -- 739
			end -- 739
			if obsZoom > 1.8 then -- 739
				obsZoom = 1.8 -- 740
			end -- 740
		end, -- 737
		launch = function(____, v) -- 742
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 742
				return -- 743
			end -- 743
			handoffDate(true) -- 744
			____exports.coreLaunch( -- 746
				core, -- 746
				v, -- 746
				level, -- 746
				probePos, -- 746
				probeVel -- 746
			) -- 746
			deps.trajectory:clearPrediction() -- 747
			deps:onPhase("Flying") -- 748
		end, -- 742
		retry = function() -- 750
			if core.phase ~= "Result" then -- 750
				return -- 751
			end -- 751
			handoffDate(false) -- 752
			____exports.coreRetry(core) -- 753
			deps.trajectory:clearTrail() -- 754
			deps.trajectory:clearPrediction() -- 755
			deps.trajectory:clearGoalRings() -- 756
			deps:onPhase("Aiming") -- 757
		end, -- 750
		backToSelect = function() -- 759
			if not ____exports.coreBackToSelect(core) then -- 759
				return false -- 760
			end -- 760
			deps.aim:setEnabled(false) -- 762
			deps.trajectory:clearTrail() -- 763
			deps.trajectory:clearPrediction() -- 764
			deps.trajectory:clearGoalRings() -- 765
			deps:onPhase("LevelSelect") -- 766
			return true -- 767
		end, -- 759
		startLevel = function() -- 769
			____exports.coreRetry(core) -- 772
			introT = 0 -- 773
			introLogged = false -- 774
			prepareIdle() -- 775
			deps.trajectory:clearTrail() -- 776
			deps.trajectory:clearPrediction() -- 777
			deps.trajectory:clearGoalRings() -- 778
			deps:onPhase("Aiming") -- 779
		end, -- 769
		stepTime = function(____, dir, span) -- 781
			if not ____exports.coreTimeWarpAllowed(core) then -- 781
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 785
				return -- 786
			end -- 786
			local span0 = span > 0 and span or 0 -- 788
			clock = clock + dir * TimeWarpStep -- 789
			if clock < 0 then -- 789
				clock = 0 -- 790
			end -- 790
			if span0 > 0 and clock > span0 then -- 790
				clock = span0 -- 791
			end -- 791
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 793
		end, -- 781
		dateNow = function() return core.t0 + clock end, -- 795
		setBrakeMode = function(____, on) -- 796
			core.brakeMode = on -- 797
		end, -- 796
		brakeMode = function() return core.brakeMode end, -- 800
		update = function(____, frameDt) return update(frameDt) end -- 802
	} -- 802
end -- 371
return ____exports -- 371
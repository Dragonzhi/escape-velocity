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
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 224
	if core.flight == nil then -- 224
		return 0 -- 225
	end -- 225
	local idx = math.floor(core.flightTime / core.dt) -- 226
	local last = #core.flight.points - 1 -- 227
	if idx > last then -- 227
		idx = last -- 228
	end -- 228
	if idx < 0 then -- 228
		idx = 0 -- 229
	end -- 229
	return idx -- 230
end -- 224
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 239
	if core.phase ~= "Flying" or core.flight == nil then -- 239
		return false -- 240
	end -- 240
	core.flightTime = core.flightTime + dt * FlightPlayback -- 241
	local naturalEnd = #core.flight.points - 1 -- 242
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 243
	if ____exports.coreProbeIndex(core) >= endIdx then -- 243
		core.flightTime = endIdx * core.dt -- 246
		core.phase = "Result" -- 247
		return true -- 248
	end -- 248
	return false -- 250
end -- 239
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 254
	core.phase = "Aiming" -- 255
	core.flight = nil -- 256
	core.flightTime = 0 -- 257
	core.goalIndex = -1 -- 258
	core.result = nil -- 259
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 260
end -- 254
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 274
	if core.phase ~= "Result" then -- 274
		return false -- 275
	end -- 275
	core.phase = "LevelSelect" -- 276
	core.flight = nil -- 277
	core.flightTime = 0 -- 278
	core.goalIndex = -1 -- 279
	core.result = nil -- 280
	return true -- 281
end -- 274
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 353
	local core = ____exports.createCore() -- 354
	local function makeBasis(frame) -- 357
		return prepareCamera({ -- 358
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 360
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 361
			up = {x = 0, y = 1, z = 0}, -- 362
			fovYDeg = deps.fovYDeg, -- 363
			aspect = deps.aspect, -- 364
			viewW = deps.viewW, -- 365
			viewH = deps.viewH -- 366
		}, HANDEDNESS, FLIP_Y) -- 366
	end -- 357
	local predKey = "" -- 375
	local predPoints = {} -- 376
	local introT = IntroDurationSec -- 378
	local introLogged = false -- 379
	local clock = 0 -- 385
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 387
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 389
	local obsYawDeg = 0 -- 393
	local obsPitchDeg = 0 -- 394
	local obsZoom = 1 -- 395
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 397
	local idlePath = nil -- 398
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 400
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 401
	local function prepareIdle() -- 402
		clock = 0 -- 403
		if level.probeVel0 == nil then -- 403
			idlePath = nil -- 405
			return -- 406
		end -- 406
		local idleSteps = level.maxSteps -- 414
		local v0x = level.probeVel0.x -- 415
		local v0y = level.probeVel0.y -- 416
		local v0 = math.sqrt(v0x * v0x + v0y * v0y) -- 417
		if v0 > 0.000001 then -- 417
			local bestD = 1000000000 -- 419
			for ____, b in ipairs(level.bodies) do -- 420
				do -- 420
					if b.gm <= 0 then -- 420
						goto __continue31 -- 421
					end -- 421
					local dx = b.orbitCenter.x - level.probeStart.x -- 422
					local dy = b.orbitCenter.y - level.probeStart.y -- 423
					local d = math.sqrt(dx * dx + dy * dy) -- 424
					if d < bestD then -- 424
						bestD = d -- 425
					end -- 425
				end -- 425
				::__continue31:: -- 425
			end -- 425
			if bestD > 0.000001 and bestD < 100000000 then -- 425
				local n = math.floor(2 * math.pi * bestD / v0 / core.dt + 0.5) -- 428
				if n > 60 and n < 40000 then -- 428
					idleSteps = n -- 429
				end -- 429
			end -- 429
		end -- 429
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 432
			steps = idleSteps, -- 435
			dt = core.dt, -- 435
			sampleEvery = 1, -- 435
			escapeRadius = level.escapeRadius, -- 435
			t0 = core.t0 -- 435
		}) -- 435
	end -- 402
	local function idleIndex() -- 438
		if idlePath == nil then -- 438
			return 0 -- 439
		end -- 439
		local n = #idlePath.points -- 440
		if n <= 1 then -- 440
			return 0 -- 441
		end -- 441
		local i = math.floor(orbitClock / core.dt) % n -- 442
		if i < 0 then -- 442
			i = 0 -- 443
		end -- 443
		return i -- 444
	end -- 438
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 448
		local wps = goalWaypoints(level.goal) -- 449
		if #wps == 0 then -- 449
			return {} -- 450
		end -- 450
		local passed = 0 -- 451
		if upto ~= nil and core.flight ~= nil then -- 451
			passed = waypointProgress( -- 453
				core.flight.points, -- 453
				level.bodies, -- 453
				level.goal, -- 453
				core.dt, -- 453
				core.t0, -- 453
				upto, -- 453
				core.flight.velocities -- 453
			).passed -- 453
		end -- 453
		if passed >= #wps then -- 453
			return {} -- 458
		end -- 458
		local nextWp = wps[passed + 1] -- 459
		local body = level.bodies[nextWp.planetIndex + 1] -- 460
		if body == nil then -- 460
			return {} -- 461
		end -- 461
		return {{ -- 462
			center = bodyPositionAt(body, t), -- 462
			radius = nextWp.tolerance, -- 462
			passed = false -- 462
		}} -- 462
	end -- 448
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 466
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 466
			return f -- 467
		end -- 467
		local dx = f.eye.x - f.target.x -- 468
		local dy = f.eye.y - f.target.y -- 469
		local dz = f.eye.z - f.target.z -- 470
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 471
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 472
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 473
		local lo = CameraTiltMin * math.pi / 180 -- 474
		local hi = CameraTiltMax * math.pi / 180 -- 475
		if pitch < lo then -- 475
			pitch = lo -- 476
		end -- 476
		if pitch > hi then -- 476
			pitch = hi -- 477
		end -- 477
		local cp = math.cos(pitch) -- 478
		return { -- 479
			target = f.target, -- 480
			eye = Vec3( -- 481
				f.target.x + r * cp * math.sin(yaw), -- 482
				f.target.y + r * math.sin(pitch), -- 483
				f.target.z + r * cp * math.cos(yaw) -- 484
			) -- 484
		} -- 484
	end -- 466
	local function updateAiming(dt) -- 489
		deps.aim:setEnabled(true) -- 490
		local dragging = deps.aim:isDragging() -- 492
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 492
			clock = clock + dt -- 495
			orbitClock = orbitClock + dt -- 496
		end -- 496
		local idx = idleIndex() -- 498
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 499
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 500
		local tNow = core.t0 + clock -- 503
		deps.scene.syncBodies(tNow) -- 505
		deps.scene.syncProbe(probePos) -- 506
		if idlePath ~= nil and idx > 0 then -- 506
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 507
		end -- 507
		local planetPts = {} -- 509
		for ____, p in ipairs(deps.scene.planets) do -- 510
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 510
		end -- 510
		local frame = deps.rig.step( -- 512
			{ -- 512
				probePos, -- 512
				table.unpack(planetPts) -- 512
			}, -- 512
			deps.scene.probeRadius -- 512
		) -- 512
		if introT < IntroDurationSec then -- 512
			introT = introT + dt -- 516
			local k = introT / IntroDurationSec -- 517
			if k > 1 then -- 517
				k = 1 -- 518
			end -- 518
			if k >= 1 and not introLogged then -- 518
				introLogged = true -- 520
				print("[escape-velocity] intro camera done") -- 521
			end -- 521
			local wps0 = goalWaypoints(level.goal) -- 523
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 524
			local wide = frame -- 525
			local from = wide -- 526
			local to = wide -- 527
			local e = 0 -- 528
			if k < 0.35 then -- 528
				local pw = planeToWorld(probePos, 0) -- 530
				local dx = wide.eye.x - wide.target.x -- 531
				local dy = wide.eye.y - wide.target.y -- 532
				local dz = wide.eye.z - wide.target.z -- 533
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 534
				if len > 0.000001 then -- 534
					local s = IntroCloseDist / len -- 536
					dx = dx * s -- 537
					dy = dy * s -- 537
					dz = dz * s -- 537
				end -- 537
				from = { -- 539
					target = Vec3(pw.x, pw.y, pw.z), -- 539
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 539
				} -- 539
				e = k / 0.35 -- 540
			elseif k < 0.72 and wpBody ~= nil then -- 540
				local c = planeToWorld( -- 543
					bodyPositionAt(wpBody, tNow), -- 543
					0 -- 543
				) -- 543
				local dx = wide.eye.x - wide.target.x -- 544
				local dy = wide.eye.y - wide.target.y -- 545
				local dz = wide.eye.z - wide.target.z -- 546
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 547
				local want = math.max(24, wpBody.radius * 6) -- 548
				if len > 0.000001 then -- 548
					local s = want / len -- 550
					dx = dx * s -- 551
					dy = dy * s -- 551
					dz = dz * s -- 551
				end -- 551
				to = { -- 553
					target = Vec3(c.x, c.y, c.z), -- 553
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 553
				} -- 553
				e = (k - 0.35) / 0.37 -- 554
			elseif wpBody ~= nil then -- 554
				local c = planeToWorld( -- 557
					bodyPositionAt(wpBody, tNow), -- 557
					0 -- 557
				) -- 557
				local dx = wide.eye.x - wide.target.x -- 558
				local dy = wide.eye.y - wide.target.y -- 559
				local dz = wide.eye.z - wide.target.z -- 560
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 561
				local want = math.max(24, wpBody.radius * 6) -- 562
				if len > 0.000001 then -- 562
					local s = want / len -- 564
					dx = dx * s -- 565
					dy = dy * s -- 565
					dz = dz * s -- 565
				end -- 565
				from = { -- 567
					target = Vec3(c.x, c.y, c.z), -- 567
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 567
				} -- 567
				e = (k - 0.72) / 0.28 -- 568
			end -- 568
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 570
			frame = { -- 571
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 572
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 577
			} -- 577
		end -- 577
		frame = applyObserve(frame) -- 585
		deps.rig.apply(deps.camera, frame) -- 586
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 587
		local basis = makeBasis(frame) -- 588
		local pp = projectPrepared( -- 591
			planeToWorld(probePos, 0), -- 591
			basis -- 591
		) -- 591
		if pp ~= nil then -- 591
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 592
		end -- 592
		if not dragging and idlePath ~= nil then -- 592
			deps.trajectory:setPrediction( -- 602
				__TS__ArraySlice(idlePath.points, idx), -- 602
				basis -- 602
			) -- 602
		else -- 602
			local key = (((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 604
			if key ~= predKey then -- 604
				predKey = key -- 607
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 610
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 611
					steps = PredictSteps, -- 614
					dt = core.dt, -- 614
					sampleEvery = 4, -- 614
					escapeRadius = level.escapeRadius, -- 614
					t0 = tNow, -- 614
					brake = motion.brake -- 614
				}).points -- 614
			end -- 614
			deps.trajectory:setPrediction(predPoints, basis) -- 617
		end -- 617
		deps.trajectory:setGoalRings( -- 619
			goalRingsAt(tNow), -- 619
			basis -- 619
		) -- 619
		deps.trajectory:clearTrail() -- 620
	end -- 489
	local function updateFlying(dt) -- 623
		deps.aim:setEnabled(false) -- 624
		local entered = ____exports.coreUpdate(core, dt) -- 625
		if core.flight == nil then -- 625
			return entered -- 626
		end -- 626
		local idx = ____exports.coreProbeIndex(core) -- 628
		local pos = core.flight.points[idx + 1] -- 629
		local tWorld = core.t0 + core.flightTime -- 633
		deps.scene.syncBodies(tWorld) -- 635
		deps.scene.syncProbe(pos) -- 636
		if idx > 0 then -- 636
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 638
		end -- 638
		local planetPts = {} -- 641
		for ____, p in ipairs(deps.scene.planets) do -- 642
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tWorld) -- 642
		end -- 642
		local frame = deps.rig.step( -- 644
			{ -- 644
				pos, -- 644
				table.unpack(planetPts) -- 644
			}, -- 644
			deps.scene.probeRadius -- 644
		) -- 644
		deps.rig.apply(deps.camera, frame) -- 645
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 646
		local basis = makeBasis(frame) -- 647
		local trail = {} -- 650
		do -- 650
			local i = 0 -- 651
			while i <= idx do -- 651
				trail[#trail + 1] = core.flight.points[i + 1] -- 651
				i = i + 1 -- 651
			end -- 651
		end -- 651
		deps.trajectory:setTrail(trail, basis) -- 652
		deps.trajectory:setGoalRings( -- 653
			goalRingsAt(tWorld, idx), -- 653
			basis -- 653
		) -- 653
		return entered -- 655
	end -- 623
	local function update(dt) -- 658
		if core.phase == "Aiming" or core.phase == "Armed" then -- 658
			updateAiming(dt) -- 660
		elseif core.phase == "Flying" then -- 660
			local entered = updateFlying(dt) -- 662
			if entered and core.result ~= nil then -- 662
				deps:onResult(core.result) -- 664
				deps:onPhase("Result") -- 665
			end -- 665
		end -- 665
	end -- 658
	return { -- 671
		phase = function() return core.phase end, -- 672
		result = function() return core.result end, -- 673
		onAimDrag = function(____, a) -- 674
			core.aim = a -- 675
			introT = IntroDurationSec -- 676
		end, -- 674
		aimReady = function() -- 678
			if not ____exports.coreArm(core) then -- 678
				return -- 679
			end -- 679
			deps:onPhase("Armed") -- 680
		end, -- 678
		launchArmed = function() -- 682
			if core.phase ~= "Armed" then -- 682
				return -- 684
			end -- 684
			____exports.coreLaunch( -- 685
				core, -- 685
				core.aim.velocity, -- 685
				level, -- 685
				probePos, -- 685
				probeVel -- 685
			) -- 685
			deps.trajectory:clearPrediction() -- 686
			deps:onPhase("Flying") -- 687
		end, -- 682
		armed = function() return core.phase == "Armed" end, -- 689
		observeDrag = function(____, dx, dy) -- 690
			introT = IntroDurationSec -- 691
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 692
			obsYawDeg = obsYawDeg + dx * 0.35 -- 693
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 694
			if obsPitchDeg > 40 then -- 694
				obsPitchDeg = 40 -- 695
			end -- 695
			if obsPitchDeg < -40 then -- 695
				obsPitchDeg = -40 -- 696
			end -- 696
		end, -- 690
		observeZoom = function(____, deltaDist) -- 698
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 699
			if obsZoom < 0.4 then -- 699
				obsZoom = 0.4 -- 700
			end -- 700
			if obsZoom > 1.8 then -- 700
				obsZoom = 1.8 -- 701
			end -- 701
		end, -- 698
		launch = function(____, v) -- 703
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 703
				return -- 704
			end -- 704
			____exports.coreLaunch( -- 706
				core, -- 706
				v, -- 706
				level, -- 706
				probePos, -- 706
				probeVel -- 706
			) -- 706
			deps.trajectory:clearPrediction() -- 707
			deps:onPhase("Flying") -- 708
		end, -- 703
		retry = function() -- 710
			if core.phase ~= "Result" then -- 710
				return -- 711
			end -- 711
			____exports.coreRetry(core) -- 712
			deps.trajectory:clearTrail() -- 713
			deps.trajectory:clearPrediction() -- 714
			deps.trajectory:clearGoalRings() -- 715
			deps:onPhase("Aiming") -- 716
		end, -- 710
		backToSelect = function() -- 718
			if not ____exports.coreBackToSelect(core) then -- 718
				return false -- 719
			end -- 719
			deps.aim:setEnabled(false) -- 721
			deps.trajectory:clearTrail() -- 722
			deps.trajectory:clearPrediction() -- 723
			deps.trajectory:clearGoalRings() -- 724
			deps:onPhase("LevelSelect") -- 725
			return true -- 726
		end, -- 718
		startLevel = function() -- 728
			____exports.coreRetry(core) -- 731
			introT = 0 -- 732
			introLogged = false -- 733
			prepareIdle() -- 734
			deps.trajectory:clearTrail() -- 735
			deps.trajectory:clearPrediction() -- 736
			deps.trajectory:clearGoalRings() -- 737
			deps:onPhase("Aiming") -- 738
		end, -- 728
		stepTime = function(____, dir, span) -- 740
			if not ____exports.coreTimeWarpAllowed(core) then -- 740
				print(("[escape-velocity] stepTime ignored (phase=" .. core.phase) .. ")") -- 744
				return -- 745
			end -- 745
			local span0 = span > 0 and span or 0 -- 747
			clock = clock + dir * TimeWarpStep -- 748
			if clock < 0 then -- 748
				clock = 0 -- 749
			end -- 749
			if span0 > 0 and clock > span0 then -- 749
				clock = span0 -- 750
			end -- 750
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 752
		end, -- 740
		dateNow = function() return core.t0 + clock end, -- 754
		setBrakeMode = function(____, on) -- 755
			core.brakeMode = on -- 756
		end, -- 755
		brakeMode = function() return core.brakeMode end, -- 759
		update = function(____, frameDt) return update(frameDt) end -- 761
	} -- 761
end -- 353
return ____exports -- 353
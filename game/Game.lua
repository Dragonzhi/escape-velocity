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
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 65
	if goalIndex >= 0 then -- 65
		return "success" -- 66
	end -- 66
	if goal.kind == "escape" and outcome == "escaped" then -- 66
		return "success" -- 67
	end -- 67
	if outcome == "crashed" then -- 67
		return "crashed" -- 68
	end -- 68
	return "missed" -- 69
end -- 65
function ____exports.createCore() -- 112
	return { -- 113
		phase = "Aiming", -- 114
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 115
		flight = nil, -- 116
		dt = PhysicsStep, -- 117
		brakeMode = false, -- 118
		t0 = 0, -- 119
		flightTime = 0, -- 120
		goalIndex = -1, -- 121
		result = nil -- 122
	} -- 122
end -- 112
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 141
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 147
	local share = brakeMode and BrakeShare or 1 -- 148
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 149
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 150
	local brake = brakeMode and mag > 0 and ({ -- 151
		dv = mag * (1 - share), -- 152
		startStep = math.floor(maxSteps / 2) -- 152
	}) or nil -- 152
	return {init = init, brake = brake} -- 154
end -- 141
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 163
	if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 163
		return -- 165
	end -- 165
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 166
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 167
	local p0 = from ~= nil and from or level.probeStart -- 168
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 169
		steps = level.maxSteps, -- 172
		dt = core.dt, -- 172
		sampleEvery = 1, -- 172
		escapeRadius = level.escapeRadius, -- 172
		t0 = core.t0, -- 172
		brake = motion.brake -- 172
	}) -- 172
	core.flight = flight -- 174
	core.goalIndex = findGoalIndex( -- 175
		flight.points, -- 175
		level.bodies, -- 175
		level.goal, -- 175
		core.dt, -- 175
		core.t0, -- 175
		flight.velocities -- 175
	) -- 175
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 176
	core.flightTime = 0 -- 177
	core.phase = "Flying" -- 178
end -- 163
--- 进入 Armed（瞄准完成、等待发射）。只在 Aiming 态有效。
-- 
-- 停在这里而不是直接发射，是用户 2026-09-26 定的交互：**松手不发射** ——
-- 玩家可以先松手、转视角看看行星在哪，确认之后再按「发射」。
function ____exports.coreArm(core) -- 187
	if core.phase ~= "Aiming" then -- 187
		return false -- 188
	end -- 188
	core.phase = "Armed" -- 189
	return true -- 190
end -- 187
--- 取消瞄准（从 Armed 回到 Aiming）。
function ____exports.coreCancelArm(core) -- 194
	if core.phase ~= "Armed" then -- 194
		return false -- 195
	end -- 195
	core.phase = "Aiming" -- 196
	return true -- 197
end -- 194
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 201
	if core.flight == nil then -- 201
		return 0 -- 202
	end -- 202
	local idx = math.floor(core.flightTime / core.dt) -- 203
	local last = #core.flight.points - 1 -- 204
	if idx > last then -- 204
		idx = last -- 205
	end -- 205
	if idx < 0 then -- 205
		idx = 0 -- 206
	end -- 206
	return idx -- 207
end -- 201
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 216
	if core.phase ~= "Flying" or core.flight == nil then -- 216
		return false -- 217
	end -- 217
	core.flightTime = core.flightTime + dt * FlightPlayback -- 218
	local naturalEnd = #core.flight.points - 1 -- 219
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 220
	if ____exports.coreProbeIndex(core) >= endIdx then -- 220
		core.flightTime = endIdx * core.dt -- 223
		core.phase = "Result" -- 224
		return true -- 225
	end -- 225
	return false -- 227
end -- 216
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 231
	core.phase = "Aiming" -- 232
	core.flight = nil -- 233
	core.flightTime = 0 -- 234
	core.goalIndex = -1 -- 235
	core.result = nil -- 236
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 237
end -- 231
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 251
	if core.phase ~= "Result" then -- 251
		return false -- 252
	end -- 252
	core.phase = "LevelSelect" -- 253
	core.flight = nil -- 254
	core.flightTime = 0 -- 255
	core.goalIndex = -1 -- 256
	core.result = nil -- 257
	return true -- 258
end -- 251
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 330
	local core = ____exports.createCore() -- 331
	local function makeBasis(frame) -- 334
		return prepareCamera({ -- 335
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 337
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 338
			up = {x = 0, y = 1, z = 0}, -- 339
			fovYDeg = deps.fovYDeg, -- 340
			aspect = deps.aspect, -- 341
			viewW = deps.viewW, -- 342
			viewH = deps.viewH -- 343
		}, HANDEDNESS, FLIP_Y) -- 343
	end -- 334
	local predKey = "" -- 352
	local predPoints = {} -- 353
	local introT = IntroDurationSec -- 355
	local introLogged = false -- 356
	local clock = 0 -- 362
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 364
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 366
	local obsYawDeg = 0 -- 370
	local obsPitchDeg = 0 -- 371
	local obsZoom = 1 -- 372
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 374
	local idlePath = nil -- 375
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 377
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 378
	local function prepareIdle() -- 379
		clock = 0 -- 380
		if level.probeVel0 == nil then -- 380
			idlePath = nil -- 382
			return -- 383
		end -- 383
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 385
			steps = level.maxSteps, -- 388
			dt = core.dt, -- 388
			sampleEvery = 1, -- 388
			escapeRadius = level.escapeRadius, -- 388
			t0 = core.t0 -- 388
		}) -- 388
	end -- 379
	local function idleIndex() -- 391
		if idlePath == nil then -- 391
			return 0 -- 392
		end -- 392
		local n = #idlePath.points -- 393
		if n <= 1 then -- 393
			return 0 -- 394
		end -- 394
		local i = math.floor(orbitClock / core.dt) % n -- 395
		if i < 0 then -- 395
			i = 0 -- 396
		end -- 396
		return i -- 397
	end -- 391
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 401
		local wps = goalWaypoints(level.goal) -- 402
		if #wps == 0 then -- 402
			return {} -- 403
		end -- 403
		local passed = 0 -- 404
		if upto ~= nil and core.flight ~= nil then -- 404
			passed = waypointProgress( -- 406
				core.flight.points, -- 406
				level.bodies, -- 406
				level.goal, -- 406
				core.dt, -- 406
				core.t0, -- 406
				upto, -- 406
				core.flight.velocities -- 406
			).passed -- 406
		end -- 406
		if passed >= #wps then -- 406
			return {} -- 411
		end -- 411
		local nextWp = wps[passed + 1] -- 412
		local body = level.bodies[nextWp.planetIndex + 1] -- 413
		if body == nil then -- 413
			return {} -- 414
		end -- 414
		return {{ -- 415
			center = bodyPositionAt(body, t), -- 415
			radius = nextWp.tolerance, -- 415
			passed = false -- 415
		}} -- 415
	end -- 401
	--- 把自动取景按观察参数改写成"玩家的机位"（绕 target 转 + 缩放）。
	local function applyObserve(f) -- 419
		if obsYawDeg == 0 and obsPitchDeg == 0 and obsZoom == 1 then -- 419
			return f -- 420
		end -- 420
		local dx = f.eye.x - f.target.x -- 421
		local dy = f.eye.y - f.target.y -- 422
		local dz = f.eye.z - f.target.z -- 423
		local r = math.sqrt(dx * dx + dy * dy + dz * dz) * obsZoom -- 424
		local yaw = math.atan(dx, dz) + obsYawDeg * math.pi / 180 -- 425
		local pitch = math.asin(dy / (r > 0.000001 and r / obsZoom or 1)) + obsPitchDeg * math.pi / 180 -- 426
		local lo = CameraTiltMin * math.pi / 180 -- 427
		local hi = CameraTiltMax * math.pi / 180 -- 428
		if pitch < lo then -- 428
			pitch = lo -- 429
		end -- 429
		if pitch > hi then -- 429
			pitch = hi -- 430
		end -- 430
		local cp = math.cos(pitch) -- 431
		return { -- 432
			target = f.target, -- 433
			eye = Vec3( -- 434
				f.target.x + r * cp * math.sin(yaw), -- 435
				f.target.y + r * math.sin(pitch), -- 436
				f.target.z + r * cp * math.cos(yaw) -- 437
			) -- 437
		} -- 437
	end -- 419
	local function updateAiming(dt) -- 442
		deps.aim:setEnabled(true) -- 443
		local dragging = deps.aim:isDragging() -- 445
		if core.phase == "Aiming" and not dragging and idlePath ~= nil then -- 445
			clock = clock + dt -- 448
			orbitClock = orbitClock + dt -- 449
		end -- 449
		local idx = idleIndex() -- 451
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 452
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 453
		local tNow = core.t0 + clock -- 456
		deps.scene.syncBodies(tNow) -- 458
		deps.scene.syncProbe(probePos) -- 459
		if idlePath ~= nil and idx > 0 then -- 459
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 460
		end -- 460
		local planetPts = {} -- 462
		for ____, p in ipairs(deps.scene.planets) do -- 463
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 463
		end -- 463
		local frame = deps.rig.step( -- 465
			{ -- 465
				probePos, -- 465
				table.unpack(planetPts) -- 465
			}, -- 465
			deps.scene.probeRadius -- 465
		) -- 465
		if introT < IntroDurationSec then -- 465
			introT = introT + dt -- 469
			local k = introT / IntroDurationSec -- 470
			if k > 1 then -- 470
				k = 1 -- 471
			end -- 471
			if k >= 1 and not introLogged then -- 471
				introLogged = true -- 473
				print("[escape-velocity] intro camera done") -- 474
			end -- 474
			local wps0 = goalWaypoints(level.goal) -- 476
			local wpBody = #wps0 > 0 and level.bodies[wps0[1].planetIndex + 1] or nil -- 477
			local wide = frame -- 478
			local from = wide -- 479
			local to = wide -- 480
			local e = 0 -- 481
			if k < 0.35 then -- 481
				local pw = planeToWorld(probePos, 0) -- 483
				local dx = wide.eye.x - wide.target.x -- 484
				local dy = wide.eye.y - wide.target.y -- 485
				local dz = wide.eye.z - wide.target.z -- 486
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 487
				if len > 0.000001 then -- 487
					local s = IntroCloseDist / len -- 489
					dx = dx * s -- 490
					dy = dy * s -- 490
					dz = dz * s -- 490
				end -- 490
				from = { -- 492
					target = Vec3(pw.x, pw.y, pw.z), -- 492
					eye = Vec3(pw.x + dx, pw.y + dy, pw.z + dz) -- 492
				} -- 492
				e = k / 0.35 -- 493
			elseif k < 0.72 and wpBody ~= nil then -- 493
				local c = planeToWorld( -- 496
					bodyPositionAt(wpBody, tNow), -- 496
					0 -- 496
				) -- 496
				local dx = wide.eye.x - wide.target.x -- 497
				local dy = wide.eye.y - wide.target.y -- 498
				local dz = wide.eye.z - wide.target.z -- 499
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 500
				local want = math.max(24, wpBody.radius * 6) -- 501
				if len > 0.000001 then -- 501
					local s = want / len -- 503
					dx = dx * s -- 504
					dy = dy * s -- 504
					dz = dz * s -- 504
				end -- 504
				to = { -- 506
					target = Vec3(c.x, c.y, c.z), -- 506
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 506
				} -- 506
				e = (k - 0.35) / 0.37 -- 507
			elseif wpBody ~= nil then -- 507
				local c = planeToWorld( -- 510
					bodyPositionAt(wpBody, tNow), -- 510
					0 -- 510
				) -- 510
				local dx = wide.eye.x - wide.target.x -- 511
				local dy = wide.eye.y - wide.target.y -- 512
				local dz = wide.eye.z - wide.target.z -- 513
				local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 514
				local want = math.max(24, wpBody.radius * 6) -- 515
				if len > 0.000001 then -- 515
					local s = want / len -- 517
					dx = dx * s -- 518
					dy = dy * s -- 518
					dz = dz * s -- 518
				end -- 518
				from = { -- 520
					target = Vec3(c.x, c.y, c.z), -- 520
					eye = Vec3(c.x + dx, c.y + dy, c.z + dz) -- 520
				} -- 520
				e = (k - 0.72) / 0.28 -- 521
			end -- 521
			local ease = 1 - (1 - e) * (1 - e) * (1 - e) -- 523
			frame = { -- 524
				target = Vec3(from.target.x + (to.target.x - from.target.x) * ease, from.target.y + (to.target.y - from.target.y) * ease, from.target.z + (to.target.z - from.target.z) * ease), -- 525
				eye = Vec3(from.eye.x + (to.eye.x - from.eye.x) * ease, from.eye.y + (to.eye.y - from.eye.y) * ease, from.eye.z + (to.eye.z - from.eye.z) * ease) -- 530
			} -- 530
		end -- 530
		frame = applyObserve(frame) -- 538
		deps.rig.apply(deps.camera, frame) -- 539
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 540
		local basis = makeBasis(frame) -- 541
		local pp = projectPrepared( -- 544
			planeToWorld(probePos, 0), -- 544
			basis -- 544
		) -- 544
		if pp ~= nil then -- 544
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 545
		end -- 545
		if not dragging and idlePath ~= nil then -- 545
			deps.trajectory:setPrediction( -- 555
				__TS__ArraySlice(idlePath.points, idx), -- 555
				basis -- 555
			) -- 555
		else -- 555
			local key = (((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 557
			if key ~= predKey then -- 557
				predKey = key -- 560
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 563
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 564
					steps = PredictSteps, -- 567
					dt = core.dt, -- 567
					sampleEvery = 4, -- 567
					escapeRadius = level.escapeRadius, -- 567
					t0 = tNow, -- 567
					brake = motion.brake -- 567
				}).points -- 567
			end -- 567
			deps.trajectory:setPrediction(predPoints, basis) -- 570
		end -- 570
		deps.trajectory:setGoalRings( -- 572
			goalRingsAt(tNow), -- 572
			basis -- 572
		) -- 572
		deps.trajectory:clearTrail() -- 573
	end -- 442
	local function updateFlying(dt) -- 576
		deps.aim:setEnabled(false) -- 577
		local entered = ____exports.coreUpdate(core, dt) -- 578
		if core.flight == nil then -- 578
			return entered -- 579
		end -- 579
		local idx = ____exports.coreProbeIndex(core) -- 581
		local pos = core.flight.points[idx + 1] -- 582
		local tWorld = core.t0 + core.flightTime -- 586
		deps.scene.syncBodies(tWorld) -- 588
		deps.scene.syncProbe(pos) -- 589
		if idx > 0 then -- 589
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 591
		end -- 591
		local planetPts = {} -- 594
		for ____, p in ipairs(deps.scene.planets) do -- 595
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tWorld) -- 595
		end -- 595
		local frame = deps.rig.step( -- 597
			{ -- 597
				pos, -- 597
				table.unpack(planetPts) -- 597
			}, -- 597
			deps.scene.probeRadius -- 597
		) -- 597
		deps.rig.apply(deps.camera, frame) -- 598
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 599
		local basis = makeBasis(frame) -- 600
		local trail = {} -- 603
		do -- 603
			local i = 0 -- 604
			while i <= idx do -- 604
				trail[#trail + 1] = core.flight.points[i + 1] -- 604
				i = i + 1 -- 604
			end -- 604
		end -- 604
		deps.trajectory:setTrail(trail, basis) -- 605
		deps.trajectory:setGoalRings( -- 606
			goalRingsAt(tWorld, idx), -- 606
			basis -- 606
		) -- 606
		return entered -- 608
	end -- 576
	local function update(dt) -- 611
		if core.phase == "Aiming" or core.phase == "Armed" then -- 611
			updateAiming(dt) -- 613
		elseif core.phase == "Flying" then -- 613
			local entered = updateFlying(dt) -- 615
			if entered and core.result ~= nil then -- 615
				deps:onResult(core.result) -- 617
				deps:onPhase("Result") -- 618
			end -- 618
		end -- 618
	end -- 611
	return { -- 624
		phase = function() return core.phase end, -- 625
		result = function() return core.result end, -- 626
		onAimDrag = function(____, a) -- 627
			core.aim = a -- 628
			introT = IntroDurationSec -- 629
		end, -- 627
		aimReady = function() -- 631
			if not ____exports.coreArm(core) then -- 631
				return -- 632
			end -- 632
			deps:onPhase("Armed") -- 633
		end, -- 631
		launchArmed = function() -- 635
			if core.phase ~= "Armed" then -- 635
				return -- 637
			end -- 637
			____exports.coreLaunch( -- 638
				core, -- 638
				core.aim.velocity, -- 638
				level, -- 638
				probePos, -- 638
				probeVel -- 638
			) -- 638
			deps.trajectory:clearPrediction() -- 639
			deps:onPhase("Flying") -- 640
		end, -- 635
		armed = function() return core.phase == "Armed" end, -- 642
		observeDrag = function(____, dx, dy) -- 643
			introT = IntroDurationSec -- 644
			print((((("[escape-velocity] observe drag dx=" .. __TS__NumberToFixed(dx, 0)) .. " dy=") .. __TS__NumberToFixed(dy, 0)) .. " yaw=") .. __TS__NumberToFixed(obsYawDeg, 0)) -- 645
			obsYawDeg = obsYawDeg + dx * 0.35 -- 646
			obsPitchDeg = obsPitchDeg + dy * 0.25 -- 647
			if obsPitchDeg > 40 then -- 647
				obsPitchDeg = 40 -- 648
			end -- 648
			if obsPitchDeg < -40 then -- 648
				obsPitchDeg = -40 -- 649
			end -- 649
		end, -- 643
		observeZoom = function(____, deltaDist) -- 651
			obsZoom = obsZoom * (1 + deltaDist * 0.002) -- 652
			if obsZoom < 0.4 then -- 652
				obsZoom = 0.4 -- 653
			end -- 653
			if obsZoom > 1.8 then -- 653
				obsZoom = 1.8 -- 654
			end -- 654
		end, -- 651
		launch = function(____, v) -- 656
			if core.phase ~= "Aiming" and core.phase ~= "Armed" then -- 656
				return -- 657
			end -- 657
			____exports.coreLaunch( -- 659
				core, -- 659
				v, -- 659
				level, -- 659
				probePos, -- 659
				probeVel -- 659
			) -- 659
			deps.trajectory:clearPrediction() -- 660
			deps:onPhase("Flying") -- 661
		end, -- 656
		retry = function() -- 663
			if core.phase ~= "Result" then -- 663
				return -- 664
			end -- 664
			____exports.coreRetry(core) -- 665
			deps.trajectory:clearTrail() -- 666
			deps.trajectory:clearPrediction() -- 667
			deps.trajectory:clearGoalRings() -- 668
			deps:onPhase("Aiming") -- 669
		end, -- 663
		backToSelect = function() -- 671
			if not ____exports.coreBackToSelect(core) then -- 671
				return false -- 672
			end -- 672
			deps.aim:setEnabled(false) -- 674
			deps.trajectory:clearTrail() -- 675
			deps.trajectory:clearPrediction() -- 676
			deps.trajectory:clearGoalRings() -- 677
			deps:onPhase("LevelSelect") -- 678
			return true -- 679
		end, -- 671
		startLevel = function() -- 681
			____exports.coreRetry(core) -- 684
			introT = 0 -- 685
			introLogged = false -- 686
			prepareIdle() -- 687
			deps.trajectory:clearTrail() -- 688
			deps.trajectory:clearPrediction() -- 689
			deps.trajectory:clearGoalRings() -- 690
			deps:onPhase("Aiming") -- 691
		end, -- 681
		stepTime = function(____, dir, span) -- 693
			local span0 = span > 0 and span or 0 -- 694
			clock = clock + dir * TimeWarpStep -- 695
			if clock < 0 then -- 695
				clock = 0 -- 696
			end -- 696
			if span0 > 0 and clock > span0 then -- 696
				clock = span0 -- 697
			end -- 697
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 699
		end, -- 693
		dateNow = function() return core.t0 + clock end, -- 701
		setBrakeMode = function(____, on) -- 702
			core.brakeMode = on -- 703
		end, -- 702
		brakeMode = function() return core.brakeMode end, -- 706
		update = function(____, frameDt) return update(frameDt) end -- 708
	} -- 708
end -- 330
return ____exports -- 330
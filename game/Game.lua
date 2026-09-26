-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
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
local FlightPlayback = ____Config.FlightPlayback -- 35
local IntroCloseDist = ____Config.IntroCloseDist -- 35
local IntroDurationSec = ____Config.IntroDurationSec -- 35
local PhysicsStep = ____Config.PhysicsStep -- 35
local PredictSteps = ____Config.PredictSteps -- 35
local TimeWarpStep = ____Config.TimeWarpStep -- 35
--- 结算三态判定（手册 §5.8）。
-- 
-- 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
-- （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
-- 
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 57
	if goalIndex >= 0 then -- 57
		return "success" -- 58
	end -- 58
	if goal.kind == "escape" and outcome == "escaped" then -- 58
		return "success" -- 59
	end -- 59
	if outcome == "crashed" then -- 59
		return "crashed" -- 60
	end -- 60
	return "missed" -- 61
end -- 57
function ____exports.createCore() -- 104
	return { -- 105
		phase = "Aiming", -- 106
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 107
		flight = nil, -- 108
		dt = PhysicsStep, -- 109
		brakeMode = false, -- 110
		t0 = 0, -- 111
		flightTime = 0, -- 112
		goalIndex = -1, -- 113
		result = nil -- 114
	} -- 114
end -- 104
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 133
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 139
	local share = brakeMode and BrakeShare or 1 -- 140
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 141
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 142
	local brake = brakeMode and mag > 0 and ({ -- 143
		dv = mag * (1 - share), -- 144
		startStep = math.floor(maxSteps / 2) -- 144
	}) or nil -- 144
	return {init = init, brake = brake} -- 146
end -- 133
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 155
	if core.phase ~= "Aiming" then -- 155
		return -- 156
	end -- 156
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 157
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 158
	local p0 = from ~= nil and from or level.probeStart -- 159
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 160
		steps = level.maxSteps, -- 163
		dt = core.dt, -- 163
		sampleEvery = 1, -- 163
		escapeRadius = level.escapeRadius, -- 163
		t0 = core.t0, -- 163
		brake = motion.brake -- 163
	}) -- 163
	core.flight = flight -- 165
	core.goalIndex = findGoalIndex( -- 166
		flight.points, -- 166
		level.bodies, -- 166
		level.goal, -- 166
		core.dt, -- 166
		core.t0, -- 166
		flight.velocities -- 166
	) -- 166
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 167
	core.flightTime = 0 -- 168
	core.phase = "Flying" -- 169
end -- 155
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 173
	if core.flight == nil then -- 173
		return 0 -- 174
	end -- 174
	local idx = math.floor(core.flightTime / core.dt) -- 175
	local last = #core.flight.points - 1 -- 176
	if idx > last then -- 176
		idx = last -- 177
	end -- 177
	if idx < 0 then -- 177
		idx = 0 -- 178
	end -- 178
	return idx -- 179
end -- 173
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 188
	if core.phase ~= "Flying" or core.flight == nil then -- 188
		return false -- 189
	end -- 189
	core.flightTime = core.flightTime + dt * FlightPlayback -- 190
	local naturalEnd = #core.flight.points - 1 -- 191
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 192
	if ____exports.coreProbeIndex(core) >= endIdx then -- 192
		core.flightTime = endIdx * core.dt -- 195
		core.phase = "Result" -- 196
		return true -- 197
	end -- 197
	return false -- 199
end -- 188
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 203
	core.phase = "Aiming" -- 204
	core.flight = nil -- 205
	core.flightTime = 0 -- 206
	core.goalIndex = -1 -- 207
	core.result = nil -- 208
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 209
end -- 203
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 223
	if core.phase ~= "Result" then -- 223
		return false -- 224
	end -- 224
	core.phase = "LevelSelect" -- 225
	core.flight = nil -- 226
	core.flightTime = 0 -- 227
	core.goalIndex = -1 -- 228
	core.result = nil -- 229
	return true -- 230
end -- 223
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 290
	local core = ____exports.createCore() -- 291
	local function makeBasis(frame) -- 294
		return prepareCamera({ -- 295
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 297
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 298
			up = {x = 0, y = 1, z = 0}, -- 299
			fovYDeg = deps.fovYDeg, -- 300
			aspect = deps.aspect, -- 301
			viewW = deps.viewW, -- 302
			viewH = deps.viewH -- 303
		}, HANDEDNESS, FLIP_Y) -- 303
	end -- 294
	local predKey = "" -- 312
	local predPoints = {} -- 313
	local introT = IntroDurationSec -- 315
	local introLogged = false -- 316
	local clock = 0 -- 322
	--- 探测器自己那口钟：待机时慢慢走，时间流快进时**不动**（它在轨道上等着窗口）。
	local orbitClock = 0 -- 324
	--- 时间流方向：-1 回退 / 0 停 / +1 加速（按住即走）。
	local warpDir = 0 -- 326
	--- 时间流量程（秒）：世界时钟夹在 [0, span]；0 = 不限制。
	local warpSpan = 0 -- 328
	local idlePath = nil -- 329
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 331
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 332
	local function prepareIdle() -- 333
		clock = 0 -- 334
		if level.probeVel0 == nil then -- 334
			idlePath = nil -- 336
			return -- 337
		end -- 337
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 339
			steps = level.maxSteps, -- 342
			dt = core.dt, -- 342
			sampleEvery = 1, -- 342
			escapeRadius = level.escapeRadius, -- 342
			t0 = core.t0 -- 342
		}) -- 342
	end -- 333
	local function idleIndex() -- 345
		if idlePath == nil then -- 345
			return 0 -- 346
		end -- 346
		local n = #idlePath.points -- 347
		if n <= 1 then -- 347
			return 0 -- 348
		end -- 348
		local i = math.floor(orbitClock / core.dt) % n -- 349
		if i < 0 then -- 349
			i = 0 -- 350
		end -- 350
		return i -- 351
	end -- 345
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 355
		local wps = goalWaypoints(level.goal) -- 356
		if #wps == 0 then -- 356
			return {} -- 357
		end -- 357
		local passed = 0 -- 358
		if upto ~= nil and core.flight ~= nil then -- 358
			passed = waypointProgress( -- 360
				core.flight.points, -- 360
				level.bodies, -- 360
				level.goal, -- 360
				core.dt, -- 360
				core.t0, -- 360
				upto, -- 360
				core.flight.velocities -- 360
			).passed -- 360
		end -- 360
		if passed >= #wps then -- 360
			return {} -- 365
		end -- 365
		local nextWp = wps[passed + 1] -- 366
		local body = level.bodies[nextWp.planetIndex + 1] -- 367
		if body == nil then -- 367
			return {} -- 368
		end -- 368
		return {{ -- 369
			center = bodyPositionAt(body, t), -- 369
			radius = nextWp.tolerance, -- 369
			passed = false -- 369
		}} -- 369
	end -- 355
	local function updateAiming(dt) -- 372
		deps.aim:setEnabled(true) -- 373
		local dragging = deps.aim:isDragging() -- 375
		if not dragging and idlePath ~= nil then -- 375
		end -- 375
		local idx = idleIndex() -- 381
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 382
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 383
		local tNow = core.t0 + clock -- 386
		deps.scene.syncBodies(tNow) -- 388
		deps.scene.syncProbe(probePos) -- 389
		if idlePath ~= nil and idx > 0 then -- 389
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 390
		end -- 390
		local planetPts = {} -- 392
		for ____, p in ipairs(deps.scene.planets) do -- 393
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 393
		end -- 393
		local frame = deps.rig.step( -- 395
			{ -- 395
				probePos, -- 395
				table.unpack(planetPts) -- 395
			}, -- 395
			deps.scene.probeRadius -- 395
		) -- 395
		if introT < IntroDurationSec then -- 395
			introT = introT + dt -- 398
			local k = introT / IntroDurationSec -- 399
			if k > 1 then -- 399
				k = 1 -- 400
			end -- 400
			if k >= 1 and not introLogged then -- 400
				introLogged = true -- 403
				local t = frame.target -- 404
				print((("[escape-velocity] intro camera: close=" .. __TS__NumberToFixed(IntroCloseDist, 0)) .. " -> wide=") .. __TS__NumberToFixed( -- 405
					math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)), -- 405
					0 -- 405
				)) -- 405
			end -- 405
			local ease = 1 - (1 - k) * (1 - k) * (1 - k) -- 407
			local pw = planeToWorld(probePos, 0) -- 408
			local dx = frame.eye.x - frame.target.x -- 409
			local dy = frame.eye.y - frame.target.y -- 410
			local dz = frame.eye.z - frame.target.z -- 411
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 412
			if len > 0.000001 then -- 412
				local s = IntroCloseDist / len -- 414
				dx = dx * s -- 415
				dy = dy * s -- 415
				dz = dz * s -- 415
			end -- 415
			local ctx = pw.x -- 417
			local cty = pw.y -- 417
			local ctz = pw.z -- 417
			local cex = pw.x + dx -- 418
			local cey = pw.y + dy -- 418
			local cez = pw.z + dz -- 418
			frame = { -- 419
				target = Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease), -- 420
				eye = Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease) -- 421
			} -- 421
		end -- 421
		deps.rig.apply(deps.camera, frame) -- 424
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 425
		local basis = makeBasis(frame) -- 426
		local pp = projectPrepared( -- 429
			planeToWorld(probePos, 0), -- 429
			basis -- 429
		) -- 429
		if pp ~= nil then -- 429
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 430
		end -- 430
		if not dragging and idlePath ~= nil then -- 430
			deps.trajectory:setPrediction( -- 440
				__TS__ArraySlice(idlePath.points, idx), -- 440
				basis -- 440
			) -- 440
		else -- 440
			local key = (((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 442
			if key ~= predKey then -- 442
				predKey = key -- 445
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 448
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 449
					steps = PredictSteps, -- 452
					dt = core.dt, -- 452
					sampleEvery = 4, -- 452
					escapeRadius = level.escapeRadius, -- 452
					t0 = tNow, -- 452
					brake = motion.brake -- 452
				}).points -- 452
			end -- 452
			deps.trajectory:setPrediction(predPoints, basis) -- 455
		end -- 455
		deps.trajectory:setGoalRings( -- 457
			goalRingsAt(tNow), -- 457
			basis -- 457
		) -- 457
		deps.trajectory:clearTrail() -- 458
	end -- 372
	local function updateFlying(dt) -- 461
		deps.aim:setEnabled(false) -- 462
		local entered = ____exports.coreUpdate(core, dt) -- 463
		if core.flight == nil then -- 463
			return entered -- 464
		end -- 464
		local idx = ____exports.coreProbeIndex(core) -- 466
		local pos = core.flight.points[idx + 1] -- 467
		local tWorld = core.t0 + core.flightTime -- 471
		deps.scene.syncBodies(tWorld) -- 473
		deps.scene.syncProbe(pos) -- 474
		if idx > 0 then -- 474
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 476
		end -- 476
		local planetPts = {} -- 479
		for ____, p in ipairs(deps.scene.planets) do -- 480
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tWorld) -- 480
		end -- 480
		local frame = deps.rig.step( -- 482
			{ -- 482
				pos, -- 482
				table.unpack(planetPts) -- 482
			}, -- 482
			deps.scene.probeRadius -- 482
		) -- 482
		deps.rig.apply(deps.camera, frame) -- 483
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 484
		local basis = makeBasis(frame) -- 485
		local trail = {} -- 488
		do -- 488
			local i = 0 -- 489
			while i <= idx do -- 489
				trail[#trail + 1] = core.flight.points[i + 1] -- 489
				i = i + 1 -- 489
			end -- 489
		end -- 489
		deps.trajectory:setTrail(trail, basis) -- 490
		deps.trajectory:setGoalRings( -- 491
			goalRingsAt(tWorld, idx), -- 491
			basis -- 491
		) -- 491
		return entered -- 493
	end -- 461
	local function update(dt) -- 496
		if core.phase == "Aiming" then -- 496
			updateAiming(dt) -- 498
		elseif core.phase == "Flying" then -- 498
			local entered = updateFlying(dt) -- 500
			if entered and core.result ~= nil then -- 500
				deps:onResult(core.result) -- 502
				deps:onPhase("Result") -- 503
			end -- 503
		end -- 503
	end -- 496
	return { -- 509
		phase = function() return core.phase end, -- 510
		result = function() return core.result end, -- 511
		onAimDrag = function(____, a) -- 512
			core.aim = a -- 513
			introT = IntroDurationSec -- 514
		end, -- 512
		launch = function(____, v) -- 516
			if core.phase ~= "Aiming" then -- 516
				return -- 517
			end -- 517
			____exports.coreLaunch( -- 519
				core, -- 519
				v, -- 519
				level, -- 519
				probePos, -- 519
				probeVel -- 519
			) -- 519
			deps.trajectory:clearPrediction() -- 520
			deps:onPhase("Flying") -- 521
		end, -- 516
		retry = function() -- 523
			if core.phase ~= "Result" then -- 523
				return -- 524
			end -- 524
			____exports.coreRetry(core) -- 525
			deps.trajectory:clearTrail() -- 526
			deps.trajectory:clearPrediction() -- 527
			deps.trajectory:clearGoalRings() -- 528
			deps:onPhase("Aiming") -- 529
		end, -- 523
		backToSelect = function() -- 531
			if not ____exports.coreBackToSelect(core) then -- 531
				return false -- 532
			end -- 532
			deps.aim:setEnabled(false) -- 534
			deps.trajectory:clearTrail() -- 535
			deps.trajectory:clearPrediction() -- 536
			deps.trajectory:clearGoalRings() -- 537
			deps:onPhase("LevelSelect") -- 538
			return true -- 539
		end, -- 531
		startLevel = function() -- 541
			____exports.coreRetry(core) -- 544
			introT = 0 -- 545
			introLogged = false -- 546
			prepareIdle() -- 547
			deps.trajectory:clearTrail() -- 548
			deps.trajectory:clearPrediction() -- 549
			deps.trajectory:clearGoalRings() -- 550
			deps:onPhase("Aiming") -- 551
		end, -- 541
		stepTime = function(____, dir, span) -- 553
			local span0 = span > 0 and span or 0 -- 554
			clock = clock + dir * TimeWarpStep -- 555
			if clock < 0 then -- 555
				clock = 0 -- 556
			end -- 556
			if span0 > 0 and clock > span0 then -- 556
				clock = span0 -- 557
			end -- 557
			print((("[escape-velocity] stepTime dir=" .. __TS__NumberToFixed(dir, 0)) .. " clock=") .. __TS__NumberToFixed(clock, 0)) -- 559
		end, -- 553
		dateNow = function() return core.t0 + clock end, -- 561
		setBrakeMode = function(____, on) -- 562
			core.brakeMode = on -- 563
		end, -- 562
		brakeMode = function() return core.brakeMode end, -- 566
		update = function(____, frameDt) return update(frameDt) end -- 568
	} -- 568
end -- 290
return ____exports -- 290
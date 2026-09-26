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
local AimMinSpeed = ____Config.AimMinSpeed -- 34
local BrakeShare = ____Config.BrakeShare -- 34
local FlightPlayback = ____Config.FlightPlayback -- 34
local IntroCloseDist = ____Config.IntroCloseDist -- 34
local IntroDurationSec = ____Config.IntroDurationSec -- 34
local PhysicsStep = ____Config.PhysicsStep -- 34
local PredictSteps = ____Config.PredictSteps -- 34
--- 结算三态判定（手册 §5.8）。
-- 
-- 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
-- （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
-- 
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 55
	if goalIndex >= 0 then -- 55
		return "success" -- 56
	end -- 56
	if goal.kind == "escape" and outcome == "escaped" then -- 56
		return "success" -- 57
	end -- 57
	if outcome == "crashed" then -- 57
		return "crashed" -- 58
	end -- 58
	return "missed" -- 59
end -- 55
function ____exports.createCore() -- 102
	return { -- 103
		phase = "Aiming", -- 104
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 105
		flight = nil, -- 106
		dt = PhysicsStep, -- 107
		brakeMode = false, -- 108
		t0 = 0, -- 109
		flightTime = 0, -- 110
		goalIndex = -1, -- 111
		result = nil -- 112
	} -- 112
end -- 102
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.burnToMotion(burn, probeVel0, brakeMode, maxSteps) -- 131
	local v0 = probeVel0 ~= nil and probeVel0 or ({x = 0, y = 0}) -- 137
	local share = brakeMode and BrakeShare or 1 -- 138
	local init = {x = v0.x + burn.x * share, y = v0.y + burn.y * share} -- 139
	local mag = math.sqrt(burn.x * burn.x + burn.y * burn.y) -- 140
	local brake = brakeMode and mag > 0 and ({ -- 141
		dv = mag * (1 - share), -- 142
		startStep = math.floor(maxSteps / 2) -- 142
	}) or nil -- 142
	return {init = init, brake = brake} -- 144
end -- 131
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。只在 Aiming 态有效。
-- 
-- `from`/`vel0` 是"点火那一刻探测器在哪、以什么速度前进"（S3.9.4：它会绕地球转，
-- 所以不能写死 `level.probeStart`）；省略则退回出发姿态（无待机时钟的关卡/测试）。
function ____exports.coreLaunch(core, burn, level, from, vel0) -- 153
	if core.phase ~= "Aiming" then -- 153
		return -- 154
	end -- 154
	local base = vel0 ~= nil and vel0 or level.probeVel0 -- 155
	local motion = ____exports.burnToMotion(burn, base, core.brakeMode, level.maxSteps) -- 156
	local p0 = from ~= nil and from or level.probeStart -- 157
	local flight = simulate({pos = {x = p0.x, y = p0.y}, vel = motion.init}, level.bodies, { -- 158
		steps = level.maxSteps, -- 161
		dt = core.dt, -- 161
		sampleEvery = 1, -- 161
		escapeRadius = level.escapeRadius, -- 161
		t0 = core.t0, -- 161
		brake = motion.brake -- 161
	}) -- 161
	core.flight = flight -- 163
	core.goalIndex = findGoalIndex( -- 164
		flight.points, -- 164
		level.bodies, -- 164
		level.goal, -- 164
		core.dt, -- 164
		core.t0, -- 164
		flight.velocities -- 164
	) -- 164
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 165
	core.flightTime = 0 -- 166
	core.phase = "Flying" -- 167
end -- 153
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 171
	if core.flight == nil then -- 171
		return 0 -- 172
	end -- 172
	local idx = math.floor(core.flightTime / core.dt) -- 173
	local last = #core.flight.points - 1 -- 174
	if idx > last then -- 174
		idx = last -- 175
	end -- 175
	if idx < 0 then -- 175
		idx = 0 -- 176
	end -- 176
	return idx -- 177
end -- 171
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 186
	if core.phase ~= "Flying" or core.flight == nil then -- 186
		return false -- 187
	end -- 187
	core.flightTime = core.flightTime + dt * FlightPlayback -- 188
	local naturalEnd = #core.flight.points - 1 -- 189
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 190
	if ____exports.coreProbeIndex(core) >= endIdx then -- 190
		core.flightTime = endIdx * core.dt -- 193
		core.phase = "Result" -- 194
		return true -- 195
	end -- 195
	return false -- 197
end -- 186
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 201
	core.phase = "Aiming" -- 202
	core.flight = nil -- 203
	core.flightTime = 0 -- 204
	core.goalIndex = -1 -- 205
	core.result = nil -- 206
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 207
end -- 201
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 221
	if core.phase ~= "Result" then -- 221
		return false -- 222
	end -- 222
	core.phase = "LevelSelect" -- 223
	core.flight = nil -- 224
	core.flightTime = 0 -- 225
	core.goalIndex = -1 -- 226
	core.result = nil -- 227
	return true -- 228
end -- 221
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 285
	local core = ____exports.createCore() -- 286
	local function makeBasis(frame) -- 289
		return prepareCamera({ -- 290
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 292
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 293
			up = {x = 0, y = 1, z = 0}, -- 294
			fovYDeg = deps.fovYDeg, -- 295
			aspect = deps.aspect, -- 296
			viewW = deps.viewW, -- 297
			viewH = deps.viewH -- 298
		}, HANDEDNESS, FLIP_Y) -- 298
	end -- 289
	local predKey = "" -- 307
	local predPoints = {} -- 308
	local introT = IntroDurationSec -- 310
	local introLogged = false -- 311
	local clock = 0 -- 317
	local idlePath = nil -- 318
	--- 探测器**此刻**在哪 / 以什么速度前进（待机会绕着地球走，所以不能写死 probeStart）。
	local probePos = {x = level.probeStart.x, y = level.probeStart.y} -- 320
	local probeVel = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 321
	local function prepareIdle() -- 322
		clock = 0 -- 323
		if level.probeVel0 == nil then -- 323
			idlePath = nil -- 325
			return -- 326
		end -- 326
		idlePath = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = level.probeVel0.x, y = level.probeVel0.y}}, level.bodies, { -- 328
			steps = level.maxSteps, -- 331
			dt = core.dt, -- 331
			sampleEvery = 1, -- 331
			escapeRadius = level.escapeRadius, -- 331
			t0 = core.t0 -- 331
		}) -- 331
	end -- 322
	local function idleIndex() -- 334
		if idlePath == nil then -- 334
			return 0 -- 335
		end -- 335
		local n = #idlePath.points -- 336
		if n <= 1 then -- 336
			return 0 -- 337
		end -- 337
		local i = math.floor(clock / core.dt) % n -- 338
		if i < 0 then -- 338
			i = 0 -- 339
		end -- 339
		return i -- 340
	end -- 334
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 344
		local wps = goalWaypoints(level.goal) -- 345
		if #wps == 0 then -- 345
			return {} -- 346
		end -- 346
		local passed = 0 -- 347
		if upto ~= nil and core.flight ~= nil then -- 347
			passed = waypointProgress( -- 349
				core.flight.points, -- 349
				level.bodies, -- 349
				level.goal, -- 349
				core.dt, -- 349
				core.t0, -- 349
				upto, -- 349
				core.flight.velocities -- 349
			).passed -- 349
		end -- 349
		if passed >= #wps then -- 349
			return {} -- 354
		end -- 354
		local nextWp = wps[passed + 1] -- 355
		local body = level.bodies[nextWp.planetIndex + 1] -- 356
		if body == nil then -- 356
			return {} -- 357
		end -- 357
		return {{ -- 358
			center = bodyPositionAt(body, t), -- 358
			radius = nextWp.tolerance, -- 358
			passed = false -- 358
		}} -- 358
	end -- 344
	local function updateAiming(dt) -- 361
		deps.aim:setEnabled(true) -- 362
		local dragging = deps.aim:isDragging() -- 364
		if not dragging and idlePath ~= nil then -- 364
			clock = clock + dt -- 365
		end -- 365
		local idx = idleIndex() -- 366
		probePos = idlePath ~= nil and idlePath.points[idx + 1] or level.probeStart -- 367
		probeVel = idlePath ~= nil and idlePath.velocities[idx + 1] or (level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0})) -- 368
		local tNow = core.t0 + clock -- 371
		deps.scene.syncBodies(tNow) -- 373
		deps.scene.syncProbe(probePos) -- 374
		if idlePath ~= nil and idx > 0 then -- 374
			deps.scene.faceVelocity(sub(probePos, idlePath.points[idx])) -- 375
		end -- 375
		local planetPts = {} -- 377
		for ____, p in ipairs(deps.scene.planets) do -- 378
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, tNow) -- 378
		end -- 378
		local frame = deps.rig.step( -- 380
			{ -- 380
				probePos, -- 380
				table.unpack(planetPts) -- 380
			}, -- 380
			deps.scene.probeRadius -- 380
		) -- 380
		if introT < IntroDurationSec then -- 380
			introT = introT + dt -- 383
			local k = introT / IntroDurationSec -- 384
			if k > 1 then -- 384
				k = 1 -- 385
			end -- 385
			if k >= 1 and not introLogged then -- 385
				introLogged = true -- 388
				local t = frame.target -- 389
				print((("[escape-velocity] intro camera: close=" .. __TS__NumberToFixed(IntroCloseDist, 0)) .. " -> wide=") .. __TS__NumberToFixed( -- 390
					math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)), -- 390
					0 -- 390
				)) -- 390
			end -- 390
			local ease = 1 - (1 - k) * (1 - k) * (1 - k) -- 392
			local pw = planeToWorld(probePos, 0) -- 393
			local dx = frame.eye.x - frame.target.x -- 394
			local dy = frame.eye.y - frame.target.y -- 395
			local dz = frame.eye.z - frame.target.z -- 396
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 397
			if len > 0.000001 then -- 397
				local s = IntroCloseDist / len -- 399
				dx = dx * s -- 400
				dy = dy * s -- 400
				dz = dz * s -- 400
			end -- 400
			local ctx = pw.x -- 402
			local cty = pw.y -- 402
			local ctz = pw.z -- 402
			local cex = pw.x + dx -- 403
			local cey = pw.y + dy -- 403
			local cez = pw.z + dz -- 403
			frame = { -- 404
				target = Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease), -- 405
				eye = Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease) -- 406
			} -- 406
		end -- 406
		deps.rig.apply(deps.camera, frame) -- 409
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 410
		local basis = makeBasis(frame) -- 411
		local pp = projectPrepared( -- 414
			planeToWorld(probePos, 0), -- 414
			basis -- 414
		) -- 414
		if pp ~= nil then -- 414
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 415
		end -- 415
		if not dragging and idlePath ~= nil then -- 415
			deps.trajectory:setPrediction( -- 425
				__TS__ArraySlice(idlePath.points, idx), -- 425
				basis -- 425
			) -- 425
		else -- 425
			local key = (((((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C")) .. "|") .. __TS__NumberToFixed(idx, 0) -- 427
			if key ~= predKey then -- 427
				predKey = key -- 430
				local motion = ____exports.burnToMotion(core.aim.velocity, probeVel, core.brakeMode, level.maxSteps) -- 433
				predPoints = simulate({pos = {x = probePos.x, y = probePos.y}, vel = motion.init}, level.bodies, { -- 434
					steps = PredictSteps, -- 437
					dt = core.dt, -- 437
					sampleEvery = 4, -- 437
					escapeRadius = level.escapeRadius, -- 437
					t0 = tNow, -- 437
					brake = motion.brake -- 437
				}).points -- 437
			end -- 437
			deps.trajectory:setPrediction(predPoints, basis) -- 440
		end -- 440
		deps.trajectory:setGoalRings( -- 442
			goalRingsAt(tNow), -- 442
			basis -- 442
		) -- 442
		deps.trajectory:clearTrail() -- 443
	end -- 361
	local function updateFlying(dt) -- 446
		deps.aim:setEnabled(false) -- 447
		local entered = ____exports.coreUpdate(core, dt) -- 448
		if core.flight == nil then -- 448
			return entered -- 449
		end -- 449
		local idx = ____exports.coreProbeIndex(core) -- 451
		local pos = core.flight.points[idx + 1] -- 452
		local t = core.flightTime -- 453
		deps.scene.syncBodies(t) -- 455
		deps.scene.syncProbe(pos) -- 456
		if idx > 0 then -- 456
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 458
		end -- 458
		local planetPts = {} -- 461
		for ____, p in ipairs(deps.scene.planets) do -- 462
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 462
		end -- 462
		local frame = deps.rig.step( -- 464
			{ -- 464
				pos, -- 464
				table.unpack(planetPts) -- 464
			}, -- 464
			deps.scene.probeRadius -- 464
		) -- 464
		deps.rig.apply(deps.camera, frame) -- 465
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 466
		local basis = makeBasis(frame) -- 467
		local trail = {} -- 470
		do -- 470
			local i = 0 -- 471
			while i <= idx do -- 471
				trail[#trail + 1] = core.flight.points[i + 1] -- 471
				i = i + 1 -- 471
			end -- 471
		end -- 471
		deps.trajectory:setTrail(trail, basis) -- 472
		deps.trajectory:setGoalRings( -- 473
			goalRingsAt(t, idx), -- 473
			basis -- 473
		) -- 473
		return entered -- 475
	end -- 446
	local function update(dt) -- 478
		if core.phase == "Aiming" then -- 478
			updateAiming(dt) -- 480
		elseif core.phase == "Flying" then -- 480
			local entered = updateFlying(dt) -- 482
			if entered and core.result ~= nil then -- 482
				deps:onResult(core.result) -- 484
				deps:onPhase("Result") -- 485
			end -- 485
		end -- 485
	end -- 478
	return { -- 491
		phase = function() return core.phase end, -- 492
		result = function() return core.result end, -- 493
		onAimDrag = function(____, a) -- 494
			core.aim = a -- 495
			introT = IntroDurationSec -- 496
		end, -- 494
		launch = function(____, v) -- 498
			if core.phase ~= "Aiming" then -- 498
				return -- 499
			end -- 499
			____exports.coreLaunch( -- 501
				core, -- 501
				v, -- 501
				level, -- 501
				probePos, -- 501
				probeVel -- 501
			) -- 501
			deps.trajectory:clearPrediction() -- 502
			deps:onPhase("Flying") -- 503
		end, -- 498
		retry = function() -- 505
			if core.phase ~= "Result" then -- 505
				return -- 506
			end -- 506
			____exports.coreRetry(core) -- 507
			deps.trajectory:clearTrail() -- 508
			deps.trajectory:clearPrediction() -- 509
			deps.trajectory:clearGoalRings() -- 510
			deps:onPhase("Aiming") -- 511
		end, -- 505
		backToSelect = function() -- 513
			if not ____exports.coreBackToSelect(core) then -- 513
				return false -- 514
			end -- 514
			deps.aim:setEnabled(false) -- 516
			deps.trajectory:clearTrail() -- 517
			deps.trajectory:clearPrediction() -- 518
			deps.trajectory:clearGoalRings() -- 519
			deps:onPhase("LevelSelect") -- 520
			return true -- 521
		end, -- 513
		startLevel = function() -- 523
			____exports.coreRetry(core) -- 526
			introT = 0 -- 527
			introLogged = false -- 528
			prepareIdle() -- 529
			deps.trajectory:clearTrail() -- 530
			deps.trajectory:clearPrediction() -- 531
			deps.trajectory:clearGoalRings() -- 532
			deps:onPhase("Aiming") -- 533
		end, -- 523
		setLaunchDate = function(____, t0) -- 535
			core.t0 = t0 -- 536
			prepareIdle() -- 538
		end, -- 535
		setBrakeMode = function(____, on) -- 540
			core.brakeMode = on -- 541
		end, -- 540
		brakeMode = function() return core.brakeMode end, -- 544
		update = function(____, frameDt) return update(frameDt) end -- 546
	} -- 546
end -- 285
return ____exports -- 285
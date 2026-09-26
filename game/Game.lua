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
function ____exports.coreLaunch(core, burn, level) -- 147
	if core.phase ~= "Aiming" then -- 147
		return -- 148
	end -- 148
	local motion = ____exports.burnToMotion(burn, level.probeVel0, core.brakeMode, level.maxSteps) -- 149
	local flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = motion.init}, level.bodies, { -- 150
		steps = level.maxSteps, -- 153
		dt = core.dt, -- 153
		sampleEvery = 1, -- 153
		escapeRadius = level.escapeRadius, -- 153
		t0 = core.t0, -- 153
		brake = motion.brake -- 153
	}) -- 153
	core.flight = flight -- 155
	core.goalIndex = findGoalIndex( -- 156
		flight.points, -- 156
		level.bodies, -- 156
		level.goal, -- 156
		core.dt, -- 156
		core.t0 -- 156
	) -- 156
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 157
	core.flightTime = 0 -- 158
	core.phase = "Flying" -- 159
end -- 147
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 163
	if core.flight == nil then -- 163
		return 0 -- 164
	end -- 164
	local idx = math.floor(core.flightTime / core.dt) -- 165
	local last = #core.flight.points - 1 -- 166
	if idx > last then -- 166
		idx = last -- 167
	end -- 167
	if idx < 0 then -- 167
		idx = 0 -- 168
	end -- 168
	return idx -- 169
end -- 163
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 178
	if core.phase ~= "Flying" or core.flight == nil then -- 178
		return false -- 179
	end -- 179
	core.flightTime = core.flightTime + dt * FlightPlayback -- 180
	local naturalEnd = #core.flight.points - 1 -- 181
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 182
	if ____exports.coreProbeIndex(core) >= endIdx then -- 182
		core.flightTime = endIdx * core.dt -- 185
		core.phase = "Result" -- 186
		return true -- 187
	end -- 187
	return false -- 189
end -- 178
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 193
	core.phase = "Aiming" -- 194
	core.flight = nil -- 195
	core.flightTime = 0 -- 196
	core.goalIndex = -1 -- 197
	core.result = nil -- 198
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 199
end -- 193
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 213
	if core.phase ~= "Result" then -- 213
		return false -- 214
	end -- 214
	core.phase = "LevelSelect" -- 215
	core.flight = nil -- 216
	core.flightTime = 0 -- 217
	core.goalIndex = -1 -- 218
	core.result = nil -- 219
	return true -- 220
end -- 213
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 272
	local core = ____exports.createCore() -- 273
	local function makeBasis(frame) -- 276
		return prepareCamera({ -- 277
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 279
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 280
			up = {x = 0, y = 1, z = 0}, -- 281
			fovYDeg = deps.fovYDeg, -- 282
			aspect = deps.aspect, -- 283
			viewW = deps.viewW, -- 284
			viewH = deps.viewH -- 285
		}, HANDEDNESS, FLIP_Y) -- 285
	end -- 276
	local predKey = "" -- 294
	local predPoints = {} -- 295
	local introT = IntroDurationSec -- 297
	local introLogged = false -- 298
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 301
		local wps = goalWaypoints(level.goal) -- 302
		if #wps == 0 then -- 302
			return {} -- 303
		end -- 303
		local passed = 0 -- 304
		if upto ~= nil and core.flight ~= nil then -- 304
			passed = waypointProgress( -- 306
				core.flight.points, -- 306
				level.bodies, -- 306
				level.goal, -- 306
				core.dt, -- 306
				core.t0, -- 306
				upto -- 306
			).passed -- 306
		end -- 306
		if passed >= #wps then -- 306
			return {} -- 311
		end -- 311
		local nextWp = wps[passed + 1] -- 312
		local body = level.bodies[nextWp.planetIndex + 1] -- 313
		if body == nil then -- 313
			return {} -- 314
		end -- 314
		return {{ -- 315
			center = bodyPositionAt(body, t), -- 315
			radius = nextWp.tolerance, -- 315
			passed = false -- 315
		}} -- 315
	end -- 301
	local function updateAiming(dt) -- 318
		deps.aim:setEnabled(true) -- 319
		deps.scene.syncBodies(core.t0) -- 321
		deps.scene.syncProbe(level.probeStart) -- 322
		local planetPts = {} -- 324
		for ____, p in ipairs(deps.scene.planets) do -- 325
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, core.t0) -- 325
		end -- 325
		local frame = deps.rig.step( -- 327
			{ -- 327
				level.probeStart, -- 327
				table.unpack(planetPts) -- 327
			}, -- 327
			deps.scene.probeRadius -- 327
		) -- 327
		if introT < IntroDurationSec then -- 327
			introT = introT + dt -- 330
			local k = introT / IntroDurationSec -- 331
			if k > 1 then -- 331
				k = 1 -- 332
			end -- 332
			if k >= 1 and not introLogged then -- 332
				introLogged = true -- 335
				local t = frame.target -- 336
				print((("[escape-velocity] intro camera: close=" .. __TS__NumberToFixed(IntroCloseDist, 0)) .. " -> wide=") .. __TS__NumberToFixed( -- 337
					math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)), -- 337
					0 -- 337
				)) -- 337
			end -- 337
			local ease = 1 - (1 - k) * (1 - k) * (1 - k) -- 339
			local pw = planeToWorld(level.probeStart, 0) -- 340
			local dx = frame.eye.x - frame.target.x -- 341
			local dy = frame.eye.y - frame.target.y -- 342
			local dz = frame.eye.z - frame.target.z -- 343
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 344
			if len > 0.000001 then -- 344
				local s = IntroCloseDist / len -- 346
				dx = dx * s -- 347
				dy = dy * s -- 347
				dz = dz * s -- 347
			end -- 347
			local ctx = pw.x -- 349
			local cty = pw.y -- 349
			local ctz = pw.z -- 349
			local cex = pw.x + dx -- 350
			local cey = pw.y + dy -- 350
			local cez = pw.z + dz -- 350
			frame = { -- 351
				target = Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease), -- 352
				eye = Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease) -- 353
			} -- 353
		end -- 353
		deps.rig.apply(deps.camera, frame) -- 356
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 357
		local basis = makeBasis(frame) -- 358
		local pp = projectPrepared( -- 361
			planeToWorld(level.probeStart, 0), -- 361
			basis -- 361
		) -- 361
		if pp ~= nil then -- 361
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 362
		end -- 362
		local key = (((((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3)) .. "|") .. (core.brakeMode and "B" or "C") -- 370
		if key ~= predKey then -- 370
			predKey = key -- 372
			local motion = ____exports.burnToMotion(core.aim.velocity, level.probeVel0, core.brakeMode, level.maxSteps) -- 374
			predPoints = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = motion.init}, level.bodies, { -- 375
				steps = PredictSteps, -- 378
				dt = core.dt, -- 378
				sampleEvery = 4, -- 378
				escapeRadius = level.escapeRadius, -- 378
				t0 = core.t0, -- 378
				brake = motion.brake -- 378
			}).points -- 378
		end -- 378
		deps.trajectory:setPrediction(predPoints, basis) -- 381
		deps.trajectory:setGoalRings( -- 382
			goalRingsAt(core.t0), -- 382
			basis -- 382
		) -- 382
		deps.trajectory:clearTrail() -- 383
	end -- 318
	local function updateFlying(dt) -- 386
		deps.aim:setEnabled(false) -- 387
		local entered = ____exports.coreUpdate(core, dt) -- 388
		if core.flight == nil then -- 388
			return entered -- 389
		end -- 389
		local idx = ____exports.coreProbeIndex(core) -- 391
		local pos = core.flight.points[idx + 1] -- 392
		local t = core.flightTime -- 393
		deps.scene.syncBodies(t) -- 395
		deps.scene.syncProbe(pos) -- 396
		if idx > 0 then -- 396
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 398
		end -- 398
		local planetPts = {} -- 401
		for ____, p in ipairs(deps.scene.planets) do -- 402
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 402
		end -- 402
		local frame = deps.rig.step( -- 404
			{ -- 404
				pos, -- 404
				table.unpack(planetPts) -- 404
			}, -- 404
			deps.scene.probeRadius -- 404
		) -- 404
		deps.rig.apply(deps.camera, frame) -- 405
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 406
		local basis = makeBasis(frame) -- 407
		local trail = {} -- 410
		do -- 410
			local i = 0 -- 411
			while i <= idx do -- 411
				trail[#trail + 1] = core.flight.points[i + 1] -- 411
				i = i + 1 -- 411
			end -- 411
		end -- 411
		deps.trajectory:setTrail(trail, basis) -- 412
		deps.trajectory:setGoalRings( -- 413
			goalRingsAt(t, idx), -- 413
			basis -- 413
		) -- 413
		return entered -- 415
	end -- 386
	local function update(dt) -- 418
		if core.phase == "Aiming" then -- 418
			updateAiming(dt) -- 420
		elseif core.phase == "Flying" then -- 420
			local entered = updateFlying(dt) -- 422
			if entered and core.result ~= nil then -- 422
				deps:onResult(core.result) -- 424
				deps:onPhase("Result") -- 425
			end -- 425
		end -- 425
	end -- 418
	return { -- 431
		phase = function() return core.phase end, -- 432
		result = function() return core.result end, -- 433
		onAimDrag = function(____, a) -- 434
			core.aim = a -- 435
			introT = IntroDurationSec -- 436
		end, -- 434
		launch = function(____, v) -- 438
			if core.phase ~= "Aiming" then -- 438
				return -- 439
			end -- 439
			____exports.coreLaunch(core, v, level) -- 440
			deps.trajectory:clearPrediction() -- 441
			deps:onPhase("Flying") -- 442
		end, -- 438
		retry = function() -- 444
			if core.phase ~= "Result" then -- 444
				return -- 445
			end -- 445
			____exports.coreRetry(core) -- 446
			deps.trajectory:clearTrail() -- 447
			deps.trajectory:clearPrediction() -- 448
			deps.trajectory:clearGoalRings() -- 449
			deps:onPhase("Aiming") -- 450
		end, -- 444
		backToSelect = function() -- 452
			if not ____exports.coreBackToSelect(core) then -- 452
				return false -- 453
			end -- 453
			deps.aim:setEnabled(false) -- 455
			deps.trajectory:clearTrail() -- 456
			deps.trajectory:clearPrediction() -- 457
			deps.trajectory:clearGoalRings() -- 458
			deps:onPhase("LevelSelect") -- 459
			return true -- 460
		end, -- 452
		startLevel = function() -- 462
			____exports.coreRetry(core) -- 465
			introT = 0 -- 466
			introLogged = false -- 467
			deps.trajectory:clearTrail() -- 468
			deps.trajectory:clearPrediction() -- 469
			deps.trajectory:clearGoalRings() -- 470
			deps:onPhase("Aiming") -- 471
		end, -- 462
		setBrakeMode = function(____, on) -- 473
			core.brakeMode = on -- 474
		end, -- 473
		brakeMode = function() return core.brakeMode end, -- 477
		update = function(____, frameDt) return update(frameDt) end -- 479
	} -- 479
end -- 272
return ____exports -- 272
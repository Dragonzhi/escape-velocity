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
function ____exports.createCore() -- 97
	return { -- 98
		phase = "Aiming", -- 99
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 100
		flight = nil, -- 101
		dt = PhysicsStep, -- 102
		t0 = 0, -- 103
		flightTime = 0, -- 104
		goalIndex = -1, -- 105
		result = nil -- 106
	} -- 106
end -- 97
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.coreLaunch(core, velocity, level) -- 117
	if core.phase ~= "Aiming" then -- 117
		return -- 118
	end -- 118
	local flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = velocity.x, y = velocity.y}}, level.bodies, { -- 119
		steps = level.maxSteps, -- 122
		dt = core.dt, -- 122
		sampleEvery = 1, -- 122
		escapeRadius = level.escapeRadius, -- 122
		t0 = core.t0 -- 122
	}) -- 122
	core.flight = flight -- 124
	core.goalIndex = findGoalIndex( -- 125
		flight.points, -- 125
		level.bodies, -- 125
		level.goal, -- 125
		core.dt, -- 125
		core.t0 -- 125
	) -- 125
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 126
	core.flightTime = 0 -- 127
	core.phase = "Flying" -- 128
end -- 117
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 132
	if core.flight == nil then -- 132
		return 0 -- 133
	end -- 133
	local idx = math.floor(core.flightTime / core.dt) -- 134
	local last = #core.flight.points - 1 -- 135
	if idx > last then -- 135
		idx = last -- 136
	end -- 136
	if idx < 0 then -- 136
		idx = 0 -- 137
	end -- 137
	return idx -- 138
end -- 132
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 147
	if core.phase ~= "Flying" or core.flight == nil then -- 147
		return false -- 148
	end -- 148
	core.flightTime = core.flightTime + dt * FlightPlayback -- 149
	local naturalEnd = #core.flight.points - 1 -- 150
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 151
	if ____exports.coreProbeIndex(core) >= endIdx then -- 151
		core.flightTime = endIdx * core.dt -- 154
		core.phase = "Result" -- 155
		return true -- 156
	end -- 156
	return false -- 158
end -- 147
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 162
	core.phase = "Aiming" -- 163
	core.flight = nil -- 164
	core.flightTime = 0 -- 165
	core.goalIndex = -1 -- 166
	core.result = nil -- 167
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 168
end -- 162
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 182
	if core.phase ~= "Result" then -- 182
		return false -- 183
	end -- 183
	core.phase = "LevelSelect" -- 184
	core.flight = nil -- 185
	core.flightTime = 0 -- 186
	core.goalIndex = -1 -- 187
	core.result = nil -- 188
	return true -- 189
end -- 182
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 237
	local core = ____exports.createCore() -- 238
	--- 玩家的点火（Δv）落在"出发时已有的速度"上 = 真正的初始速度（S3.9.3）。
	-- L1 的 probeVel0 = 绕地球的圆轨道速度；其余关卡省略 = 静止出发（与旧行为逐位一致）。
	local function launchVelocity(burn) -- 244
		local v0 = level.probeVel0 ~= nil and level.probeVel0 or ({x = 0, y = 0}) -- 245
		return {x = burn.x + v0.x, y = burn.y + v0.y} -- 246
	end -- 244
	local function makeBasis(frame) -- 249
		return prepareCamera({ -- 250
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 252
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 253
			up = {x = 0, y = 1, z = 0}, -- 254
			fovYDeg = deps.fovYDeg, -- 255
			aspect = deps.aspect, -- 256
			viewW = deps.viewW, -- 257
			viewH = deps.viewH -- 258
		}, HANDEDNESS, FLIP_Y) -- 258
	end -- 249
	local predKey = "" -- 267
	local predPoints = {} -- 268
	local introT = IntroDurationSec -- 270
	local introLogged = false -- 271
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 274
		local wps = goalWaypoints(level.goal) -- 275
		if #wps == 0 then -- 275
			return {} -- 276
		end -- 276
		local passed = 0 -- 277
		if upto ~= nil and core.flight ~= nil then -- 277
			passed = waypointProgress( -- 279
				core.flight.points, -- 279
				level.bodies, -- 279
				level.goal, -- 279
				core.dt, -- 279
				core.t0, -- 279
				upto -- 279
			).passed -- 279
		end -- 279
		if passed >= #wps then -- 279
			return {} -- 284
		end -- 284
		local nextWp = wps[passed + 1] -- 285
		local body = level.bodies[nextWp.planetIndex + 1] -- 286
		if body == nil then -- 286
			return {} -- 287
		end -- 287
		return {{ -- 288
			center = bodyPositionAt(body, t), -- 288
			radius = nextWp.tolerance, -- 288
			passed = false -- 288
		}} -- 288
	end -- 274
	local function updateAiming(dt) -- 291
		deps.aim:setEnabled(true) -- 292
		deps.scene.syncBodies(core.t0) -- 294
		deps.scene.syncProbe(level.probeStart) -- 295
		local planetPts = {} -- 297
		for ____, p in ipairs(deps.scene.planets) do -- 298
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, core.t0) -- 298
		end -- 298
		local frame = deps.rig.step( -- 300
			{ -- 300
				level.probeStart, -- 300
				table.unpack(planetPts) -- 300
			}, -- 300
			deps.scene.probeRadius -- 300
		) -- 300
		if introT < IntroDurationSec then -- 300
			introT = introT + dt -- 303
			local k = introT / IntroDurationSec -- 304
			if k > 1 then -- 304
				k = 1 -- 305
			end -- 305
			if k >= 1 and not introLogged then -- 305
				introLogged = true -- 308
				local t = frame.target -- 309
				print((("[escape-velocity] intro camera: close=" .. __TS__NumberToFixed(IntroCloseDist, 0)) .. " -> wide=") .. __TS__NumberToFixed( -- 310
					math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)), -- 310
					0 -- 310
				)) -- 310
			end -- 310
			local ease = 1 - (1 - k) * (1 - k) * (1 - k) -- 312
			local pw = planeToWorld(level.probeStart, 0) -- 313
			local dx = frame.eye.x - frame.target.x -- 314
			local dy = frame.eye.y - frame.target.y -- 315
			local dz = frame.eye.z - frame.target.z -- 316
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 317
			if len > 0.000001 then -- 317
				local s = IntroCloseDist / len -- 319
				dx = dx * s -- 320
				dy = dy * s -- 320
				dz = dz * s -- 320
			end -- 320
			local ctx = pw.x -- 322
			local cty = pw.y -- 322
			local ctz = pw.z -- 322
			local cex = pw.x + dx -- 323
			local cey = pw.y + dy -- 323
			local cez = pw.z + dz -- 323
			frame = { -- 324
				target = Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease), -- 325
				eye = Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease) -- 326
			} -- 326
		end -- 326
		deps.rig.apply(deps.camera, frame) -- 329
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 330
		local basis = makeBasis(frame) -- 331
		local pp = projectPrepared( -- 334
			planeToWorld(level.probeStart, 0), -- 334
			basis -- 334
		) -- 334
		if pp ~= nil then -- 334
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 335
		end -- 335
		local key = (((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3) -- 343
		if key ~= predKey then -- 343
			predKey = key -- 345
			predPoints = simulate( -- 346
				{ -- 347
					pos = {x = level.probeStart.x, y = level.probeStart.y}, -- 347
					vel = launchVelocity(core.aim.velocity) -- 347
				}, -- 347
				level.bodies, -- 348
				{ -- 349
					steps = PredictSteps, -- 349
					dt = core.dt, -- 349
					sampleEvery = 4, -- 349
					escapeRadius = level.escapeRadius, -- 349
					t0 = core.t0 -- 349
				} -- 349
			).points -- 349
		end -- 349
		deps.trajectory:setPrediction(predPoints, basis) -- 352
		deps.trajectory:setGoalRings( -- 353
			goalRingsAt(core.t0), -- 353
			basis -- 353
		) -- 353
		deps.trajectory:clearTrail() -- 354
	end -- 291
	local function updateFlying(dt) -- 357
		deps.aim:setEnabled(false) -- 358
		local entered = ____exports.coreUpdate(core, dt) -- 359
		if core.flight == nil then -- 359
			return entered -- 360
		end -- 360
		local idx = ____exports.coreProbeIndex(core) -- 362
		local pos = core.flight.points[idx + 1] -- 363
		local t = core.flightTime -- 364
		deps.scene.syncBodies(t) -- 366
		deps.scene.syncProbe(pos) -- 367
		if idx > 0 then -- 367
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 369
		end -- 369
		local planetPts = {} -- 372
		for ____, p in ipairs(deps.scene.planets) do -- 373
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 373
		end -- 373
		local frame = deps.rig.step( -- 375
			{ -- 375
				pos, -- 375
				table.unpack(planetPts) -- 375
			}, -- 375
			deps.scene.probeRadius -- 375
		) -- 375
		deps.rig.apply(deps.camera, frame) -- 376
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 377
		local basis = makeBasis(frame) -- 378
		local trail = {} -- 381
		do -- 381
			local i = 0 -- 382
			while i <= idx do -- 382
				trail[#trail + 1] = core.flight.points[i + 1] -- 382
				i = i + 1 -- 382
			end -- 382
		end -- 382
		deps.trajectory:setTrail(trail, basis) -- 383
		deps.trajectory:setGoalRings( -- 384
			goalRingsAt(t, idx), -- 384
			basis -- 384
		) -- 384
		return entered -- 386
	end -- 357
	local function update(dt) -- 389
		if core.phase == "Aiming" then -- 389
			updateAiming(dt) -- 391
		elseif core.phase == "Flying" then -- 391
			local entered = updateFlying(dt) -- 393
			if entered and core.result ~= nil then -- 393
				deps:onResult(core.result) -- 395
				deps:onPhase("Result") -- 396
			end -- 396
		end -- 396
	end -- 389
	return { -- 402
		phase = function() return core.phase end, -- 403
		result = function() return core.result end, -- 404
		onAimDrag = function(____, a) -- 405
			core.aim = a -- 406
			introT = IntroDurationSec -- 407
		end, -- 405
		launch = function(____, v) -- 409
			if core.phase ~= "Aiming" then -- 409
				return -- 410
			end -- 410
			____exports.coreLaunch( -- 411
				core, -- 411
				launchVelocity(v), -- 411
				level -- 411
			) -- 411
			deps.trajectory:clearPrediction() -- 412
			deps:onPhase("Flying") -- 413
		end, -- 409
		retry = function() -- 415
			if core.phase ~= "Result" then -- 415
				return -- 416
			end -- 416
			____exports.coreRetry(core) -- 417
			deps.trajectory:clearTrail() -- 418
			deps.trajectory:clearPrediction() -- 419
			deps.trajectory:clearGoalRings() -- 420
			deps:onPhase("Aiming") -- 421
		end, -- 415
		backToSelect = function() -- 423
			if not ____exports.coreBackToSelect(core) then -- 423
				return false -- 424
			end -- 424
			deps.aim:setEnabled(false) -- 426
			deps.trajectory:clearTrail() -- 427
			deps.trajectory:clearPrediction() -- 428
			deps.trajectory:clearGoalRings() -- 429
			deps:onPhase("LevelSelect") -- 430
			return true -- 431
		end, -- 423
		startLevel = function() -- 433
			____exports.coreRetry(core) -- 436
			introT = 0 -- 437
			introLogged = false -- 438
			deps.trajectory:clearTrail() -- 439
			deps.trajectory:clearPrediction() -- 440
			deps.trajectory:clearGoalRings() -- 441
			deps:onPhase("Aiming") -- 442
		end, -- 433
		update = function(____, frameDt) return update(frameDt) end -- 445
	} -- 445
end -- 237
return ____exports -- 237
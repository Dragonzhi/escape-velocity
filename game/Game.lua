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
function ____exports.createCore() -- 95
	return { -- 96
		phase = "Aiming", -- 97
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 98
		flight = nil, -- 99
		dt = PhysicsStep, -- 100
		t0 = 0, -- 101
		flightTime = 0, -- 102
		goalIndex = -1, -- 103
		result = nil -- 104
	} -- 104
end -- 95
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.coreLaunch(core, velocity, level) -- 115
	if core.phase ~= "Aiming" then -- 115
		return -- 116
	end -- 116
	local flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = velocity.x, y = velocity.y}}, level.bodies, { -- 117
		steps = level.maxSteps, -- 120
		dt = core.dt, -- 120
		sampleEvery = 1, -- 120
		escapeRadius = level.escapeRadius, -- 120
		t0 = core.t0 -- 120
	}) -- 120
	core.flight = flight -- 122
	core.goalIndex = findGoalIndex( -- 123
		flight.points, -- 123
		level.bodies, -- 123
		level.goal, -- 123
		core.dt, -- 123
		core.t0 -- 123
	) -- 123
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 124
	core.flightTime = 0 -- 125
	core.phase = "Flying" -- 126
end -- 115
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 130
	if core.flight == nil then -- 130
		return 0 -- 131
	end -- 131
	local idx = math.floor(core.flightTime / core.dt) -- 132
	local last = #core.flight.points - 1 -- 133
	if idx > last then -- 133
		idx = last -- 134
	end -- 134
	if idx < 0 then -- 134
		idx = 0 -- 135
	end -- 135
	return idx -- 136
end -- 130
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 145
	if core.phase ~= "Flying" or core.flight == nil then -- 145
		return false -- 146
	end -- 146
	core.flightTime = core.flightTime + dt * FlightPlayback -- 147
	local naturalEnd = #core.flight.points - 1 -- 148
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 149
	if ____exports.coreProbeIndex(core) >= endIdx then -- 149
		core.flightTime = endIdx * core.dt -- 152
		core.phase = "Result" -- 153
		return true -- 154
	end -- 154
	return false -- 156
end -- 145
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 160
	core.phase = "Aiming" -- 161
	core.flight = nil -- 162
	core.flightTime = 0 -- 163
	core.goalIndex = -1 -- 164
	core.result = nil -- 165
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 166
end -- 160
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 180
	if core.phase ~= "Result" then -- 180
		return false -- 181
	end -- 181
	core.phase = "LevelSelect" -- 182
	core.flight = nil -- 183
	core.flightTime = 0 -- 184
	core.goalIndex = -1 -- 185
	core.result = nil -- 186
	return true -- 187
end -- 180
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 235
	local core = ____exports.createCore() -- 236
	local function makeBasis(frame) -- 238
		return prepareCamera({ -- 239
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 241
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 242
			up = {x = 0, y = 1, z = 0}, -- 243
			fovYDeg = deps.fovYDeg, -- 244
			aspect = deps.aspect, -- 245
			viewW = deps.viewW, -- 246
			viewH = deps.viewH -- 247
		}, HANDEDNESS, FLIP_Y) -- 247
	end -- 238
	local predKey = "" -- 256
	local predPoints = {} -- 257
	local introT = IntroDurationSec -- 259
	local introLogged = false -- 260
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 263
		local wps = goalWaypoints(level.goal) -- 264
		if #wps == 0 then -- 264
			return {} -- 265
		end -- 265
		local passed = 0 -- 266
		if upto ~= nil and core.flight ~= nil then -- 266
			passed = waypointProgress( -- 268
				core.flight.points, -- 268
				level.bodies, -- 268
				level.goal, -- 268
				core.dt, -- 268
				core.t0, -- 268
				upto -- 268
			).passed -- 268
		end -- 268
		if passed >= #wps then -- 268
			return {} -- 273
		end -- 273
		local nextWp = wps[passed + 1] -- 274
		local body = level.bodies[nextWp.planetIndex + 1] -- 275
		if body == nil then -- 275
			return {} -- 276
		end -- 276
		return {{ -- 277
			center = bodyPositionAt(body, t), -- 277
			radius = nextWp.tolerance, -- 277
			passed = false -- 277
		}} -- 277
	end -- 263
	local function updateAiming(dt) -- 280
		deps.aim:setEnabled(true) -- 281
		deps.scene.syncBodies(core.t0) -- 283
		deps.scene.syncProbe(level.probeStart) -- 284
		local planetPts = {} -- 286
		for ____, p in ipairs(deps.scene.planets) do -- 287
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, core.t0) -- 287
		end -- 287
		local frame = deps.rig.step( -- 289
			{ -- 289
				level.probeStart, -- 289
				table.unpack(planetPts) -- 289
			}, -- 289
			deps.scene.probeRadius -- 289
		) -- 289
		if introT < IntroDurationSec then -- 289
			introT = introT + dt -- 292
			local k = introT / IntroDurationSec -- 293
			if k > 1 then -- 293
				k = 1 -- 294
			end -- 294
			if k >= 1 and not introLogged then -- 294
				introLogged = true -- 297
				local t = frame.target -- 298
				print((("[escape-velocity] intro camera: close=" .. __TS__NumberToFixed(IntroCloseDist, 0)) .. " -> wide=") .. __TS__NumberToFixed( -- 299
					math.sqrt((frame.eye.x - t.x) * (frame.eye.x - t.x) + (frame.eye.y - t.y) * (frame.eye.y - t.y) + (frame.eye.z - t.z) * (frame.eye.z - t.z)), -- 299
					0 -- 299
				)) -- 299
			end -- 299
			local ease = 1 - (1 - k) * (1 - k) * (1 - k) -- 301
			local pw = planeToWorld(level.probeStart, 0) -- 302
			local dx = frame.eye.x - frame.target.x -- 303
			local dy = frame.eye.y - frame.target.y -- 304
			local dz = frame.eye.z - frame.target.z -- 305
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 306
			if len > 0.000001 then -- 306
				local s = IntroCloseDist / len -- 308
				dx = dx * s -- 309
				dy = dy * s -- 309
				dz = dz * s -- 309
			end -- 309
			local ctx = pw.x -- 311
			local cty = pw.y -- 311
			local ctz = pw.z -- 311
			local cex = pw.x + dx -- 312
			local cey = pw.y + dy -- 312
			local cez = pw.z + dz -- 312
			frame = { -- 313
				target = Vec3(ctx + (frame.target.x - ctx) * ease, cty + (frame.target.y - cty) * ease, ctz + (frame.target.z - ctz) * ease), -- 314
				eye = Vec3(cex + (frame.eye.x - cex) * ease, cey + (frame.eye.y - cey) * ease, cez + (frame.eye.z - cez) * ease) -- 315
			} -- 315
		end -- 315
		deps.rig.apply(deps.camera, frame) -- 318
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 319
		local basis = makeBasis(frame) -- 320
		local pp = projectPrepared( -- 323
			planeToWorld(level.probeStart, 0), -- 323
			basis -- 323
		) -- 323
		if pp ~= nil then -- 323
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 324
		end -- 324
		local key = (((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3) -- 332
		if key ~= predKey then -- 332
			predKey = key -- 334
			predPoints = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = core.aim.velocity.x, y = core.aim.velocity.y}}, level.bodies, { -- 335
				steps = PredictSteps, -- 338
				dt = core.dt, -- 338
				sampleEvery = 4, -- 338
				escapeRadius = level.escapeRadius, -- 338
				t0 = core.t0 -- 338
			}).points -- 338
		end -- 338
		deps.trajectory:setPrediction(predPoints, basis) -- 341
		deps.trajectory:setGoalRings( -- 342
			goalRingsAt(core.t0), -- 342
			basis -- 342
		) -- 342
		deps.trajectory:clearTrail() -- 343
	end -- 280
	local function updateFlying(dt) -- 346
		deps.aim:setEnabled(false) -- 347
		local entered = ____exports.coreUpdate(core, dt) -- 348
		if core.flight == nil then -- 348
			return entered -- 349
		end -- 349
		local idx = ____exports.coreProbeIndex(core) -- 351
		local pos = core.flight.points[idx + 1] -- 352
		local t = core.flightTime -- 353
		deps.scene.syncBodies(t) -- 355
		deps.scene.syncProbe(pos) -- 356
		if idx > 0 then -- 356
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 358
		end -- 358
		local planetPts = {} -- 361
		for ____, p in ipairs(deps.scene.planets) do -- 362
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 362
		end -- 362
		local frame = deps.rig.step( -- 364
			{ -- 364
				pos, -- 364
				table.unpack(planetPts) -- 364
			}, -- 364
			deps.scene.probeRadius -- 364
		) -- 364
		deps.rig.apply(deps.camera, frame) -- 365
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 366
		local basis = makeBasis(frame) -- 367
		local trail = {} -- 370
		do -- 370
			local i = 0 -- 371
			while i <= idx do -- 371
				trail[#trail + 1] = core.flight.points[i + 1] -- 371
				i = i + 1 -- 371
			end -- 371
		end -- 371
		deps.trajectory:setTrail(trail, basis) -- 372
		deps.trajectory:setGoalRings( -- 373
			goalRingsAt(t, idx), -- 373
			basis -- 373
		) -- 373
		return entered -- 375
	end -- 346
	local function update(dt) -- 378
		if core.phase == "Aiming" then -- 378
			updateAiming(dt) -- 380
		elseif core.phase == "Flying" then -- 380
			local entered = updateFlying(dt) -- 382
			if entered and core.result ~= nil then -- 382
				deps:onResult(core.result) -- 384
				deps:onPhase("Result") -- 385
			end -- 385
		end -- 385
	end -- 378
	return { -- 391
		phase = function() return core.phase end, -- 392
		result = function() return core.result end, -- 393
		onAimDrag = function(____, a) -- 394
			core.aim = a -- 395
			introT = IntroDurationSec -- 396
		end, -- 394
		launch = function(____, v) -- 398
			if core.phase ~= "Aiming" then -- 398
				return -- 399
			end -- 399
			____exports.coreLaunch(core, v, level) -- 400
			deps.trajectory:clearPrediction() -- 401
			deps:onPhase("Flying") -- 402
		end, -- 398
		retry = function() -- 404
			if core.phase ~= "Result" then -- 404
				return -- 405
			end -- 405
			____exports.coreRetry(core) -- 406
			deps.trajectory:clearTrail() -- 407
			deps.trajectory:clearPrediction() -- 408
			deps.trajectory:clearGoalRings() -- 409
			deps:onPhase("Aiming") -- 410
		end, -- 404
		backToSelect = function() -- 412
			if not ____exports.coreBackToSelect(core) then -- 412
				return false -- 413
			end -- 413
			deps.aim:setEnabled(false) -- 415
			deps.trajectory:clearTrail() -- 416
			deps.trajectory:clearPrediction() -- 417
			deps.trajectory:clearGoalRings() -- 418
			deps:onPhase("LevelSelect") -- 419
			return true -- 420
		end, -- 412
		startLevel = function() -- 422
			____exports.coreRetry(core) -- 425
			introT = 0 -- 426
			introLogged = false -- 427
			deps.trajectory:clearTrail() -- 428
			deps.trajectory:clearPrediction() -- 429
			deps.trajectory:clearGoalRings() -- 430
			deps:onPhase("Aiming") -- 431
		end, -- 422
		update = function(____, frameDt) return update(frameDt) end -- 434
	} -- 434
end -- 235
return ____exports -- 235
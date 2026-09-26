-- [ts]: Game.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
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
	--- 当前 t0 下的航点环（S3.7）：已掠过的航点画暗。
	local function goalRingsAt(t, upto) -- 260
		local wps = goalWaypoints(level.goal) -- 261
		if #wps == 0 then -- 261
			return {} -- 262
		end -- 262
		local passed = 0 -- 263
		if upto ~= nil and core.flight ~= nil then -- 263
			passed = waypointProgress( -- 265
				core.flight.points, -- 265
				level.bodies, -- 265
				level.goal, -- 265
				core.dt, -- 265
				core.t0, -- 265
				upto -- 265
			).passed -- 265
		end -- 265
		local rings = {} -- 267
		do -- 267
			local i = 0 -- 268
			while i < #wps do -- 268
				do -- 268
					local body = level.bodies[wps[i + 1].planetIndex + 1] -- 269
					if body == nil then -- 269
						goto __continue25 -- 270
					end -- 270
					rings[#rings + 1] = { -- 271
						center = bodyPositionAt(body, t), -- 271
						radius = wps[i + 1].tolerance, -- 271
						passed = i < passed -- 271
					} -- 271
				end -- 271
				::__continue25:: -- 271
				i = i + 1 -- 268
			end -- 268
		end -- 268
		return rings -- 273
	end -- 260
	local function updateAiming() -- 276
		deps.aim:setEnabled(true) -- 277
		deps.scene.syncBodies(core.t0) -- 279
		deps.scene.syncProbe(level.probeStart) -- 280
		local planetPts = {} -- 282
		for ____, p in ipairs(deps.scene.planets) do -- 283
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, core.t0) -- 283
		end -- 283
		local frame = deps.rig.step( -- 285
			{ -- 285
				level.probeStart, -- 285
				table.unpack(planetPts) -- 285
			}, -- 285
			deps.scene.probeRadius -- 285
		) -- 285
		deps.rig.apply(deps.camera, frame) -- 286
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 287
		local basis = makeBasis(frame) -- 288
		local pp = projectPrepared( -- 291
			planeToWorld(level.probeStart, 0), -- 291
			basis -- 291
		) -- 291
		if pp ~= nil then -- 291
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 292
		end -- 292
		local key = (((__TS__NumberToFixed(core.aim.velocity.x, 3) .. "|") .. __TS__NumberToFixed(core.aim.velocity.y, 3)) .. "|") .. __TS__NumberToFixed(core.t0, 3) -- 300
		if key ~= predKey then -- 300
			predKey = key -- 302
			predPoints = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = core.aim.velocity.x, y = core.aim.velocity.y}}, level.bodies, { -- 303
				steps = PredictSteps, -- 306
				dt = core.dt, -- 306
				sampleEvery = 4, -- 306
				escapeRadius = level.escapeRadius, -- 306
				t0 = core.t0 -- 306
			}).points -- 306
		end -- 306
		deps.trajectory:setPrediction(predPoints, basis) -- 309
		deps.trajectory:setGoalRings( -- 310
			goalRingsAt(core.t0), -- 310
			basis -- 310
		) -- 310
		deps.trajectory:clearTrail() -- 311
	end -- 276
	local function updateFlying(dt) -- 314
		deps.aim:setEnabled(false) -- 315
		local entered = ____exports.coreUpdate(core, dt) -- 316
		if core.flight == nil then -- 316
			return entered -- 317
		end -- 317
		local idx = ____exports.coreProbeIndex(core) -- 319
		local pos = core.flight.points[idx + 1] -- 320
		local t = core.flightTime -- 321
		deps.scene.syncBodies(t) -- 323
		deps.scene.syncProbe(pos) -- 324
		if idx > 0 then -- 324
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 326
		end -- 326
		local planetPts = {} -- 329
		for ____, p in ipairs(deps.scene.planets) do -- 330
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 330
		end -- 330
		local frame = deps.rig.step( -- 332
			{ -- 332
				pos, -- 332
				table.unpack(planetPts) -- 332
			}, -- 332
			deps.scene.probeRadius -- 332
		) -- 332
		deps.rig.apply(deps.camera, frame) -- 333
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 334
		local basis = makeBasis(frame) -- 335
		local trail = {} -- 338
		do -- 338
			local i = 0 -- 339
			while i <= idx do -- 339
				trail[#trail + 1] = core.flight.points[i + 1] -- 339
				i = i + 1 -- 339
			end -- 339
		end -- 339
		deps.trajectory:setTrail(trail, basis) -- 340
		deps.trajectory:setGoalRings( -- 341
			goalRingsAt(t, idx), -- 341
			basis -- 341
		) -- 341
		return entered -- 343
	end -- 314
	local function update(dt) -- 346
		if core.phase == "Aiming" then -- 346
			updateAiming() -- 348
		elseif core.phase == "Flying" then -- 348
			local entered = updateFlying(dt) -- 350
			if entered and core.result ~= nil then -- 350
				deps:onResult(core.result) -- 352
				deps:onPhase("Result") -- 353
			end -- 353
		end -- 353
	end -- 346
	return { -- 359
		phase = function() return core.phase end, -- 360
		result = function() return core.result end, -- 361
		onAimDrag = function(____, a) -- 362
			core.aim = a -- 363
		end, -- 362
		launch = function(____, v) -- 365
			if core.phase ~= "Aiming" then -- 365
				return -- 366
			end -- 366
			____exports.coreLaunch(core, v, level) -- 367
			deps.trajectory:clearPrediction() -- 368
			deps:onPhase("Flying") -- 369
		end, -- 365
		retry = function() -- 371
			if core.phase ~= "Result" then -- 371
				return -- 372
			end -- 372
			____exports.coreRetry(core) -- 373
			deps.trajectory:clearTrail() -- 374
			deps.trajectory:clearPrediction() -- 375
			deps.trajectory:clearGoalRings() -- 376
			deps:onPhase("Aiming") -- 377
		end, -- 371
		backToSelect = function() -- 379
			if not ____exports.coreBackToSelect(core) then -- 379
				return false -- 380
			end -- 380
			deps.aim:setEnabled(false) -- 382
			deps.trajectory:clearTrail() -- 383
			deps.trajectory:clearPrediction() -- 384
			deps.trajectory:clearGoalRings() -- 385
			deps:onPhase("LevelSelect") -- 386
			return true -- 387
		end, -- 379
		startLevel = function() -- 389
			____exports.coreRetry(core) -- 392
			deps.trajectory:clearTrail() -- 393
			deps.trajectory:clearPrediction() -- 394
			deps.trajectory:clearGoalRings() -- 395
			deps:onPhase("Aiming") -- 396
		end, -- 389
		update = function(____, frameDt) return update(frameDt) end -- 399
	} -- 399
end -- 235
return ____exports -- 235
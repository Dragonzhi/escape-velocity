-- [ts]: Game.ts
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
function ____exports.createCore() -- 90
	return { -- 91
		phase = "Aiming", -- 92
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 93
		flight = nil, -- 94
		dt = PhysicsStep, -- 95
		flightTime = 0, -- 96
		goalIndex = -1, -- 97
		result = nil -- 98
	} -- 98
end -- 90
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.coreLaunch(core, velocity, level) -- 109
	if core.phase ~= "Aiming" then -- 109
		return -- 110
	end -- 110
	local flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = velocity.x, y = velocity.y}}, level.bodies, {steps = level.maxSteps, dt = core.dt, sampleEvery = 1, escapeRadius = level.escapeRadius}) -- 111
	core.flight = flight -- 116
	core.goalIndex = findGoalIndex(flight.points, level.bodies, level.goal, core.dt) -- 117
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 118
	core.flightTime = 0 -- 119
	core.phase = "Flying" -- 120
end -- 109
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 124
	if core.flight == nil then -- 124
		return 0 -- 125
	end -- 125
	local idx = math.floor(core.flightTime / core.dt) -- 126
	local last = #core.flight.points - 1 -- 127
	if idx > last then -- 127
		idx = last -- 128
	end -- 128
	if idx < 0 then -- 128
		idx = 0 -- 129
	end -- 129
	return idx -- 130
end -- 124
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 139
	if core.phase ~= "Flying" or core.flight == nil then -- 139
		return false -- 140
	end -- 140
	core.flightTime = core.flightTime + dt * FlightPlayback -- 141
	local naturalEnd = #core.flight.points - 1 -- 142
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 143
	if ____exports.coreProbeIndex(core) >= endIdx then -- 143
		core.flightTime = endIdx * core.dt -- 146
		core.phase = "Result" -- 147
		return true -- 148
	end -- 148
	return false -- 150
end -- 139
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 154
	core.phase = "Aiming" -- 155
	core.flight = nil -- 156
	core.flightTime = 0 -- 157
	core.goalIndex = -1 -- 158
	core.result = nil -- 159
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 160
end -- 154
--- 返回关卡选择（S2.3，决策 D5）。
-- 
-- **只在 Result 态可用**：飞行途中或矄准途中“返回”会让玩家丢掉一次未结算的发射，
-- 与“松手后不可修正”（愿景 §3）冲突 —— 不可撤销就该走完结算再看结果。
-- 
-- 顺带清掉飞行与结算数据：离开这一关后它们不再有意义，留着会让“再次进入本关”
-- 时短暂读到上一局的终态。
-- 
-- @returns 是否真的切过去了（非 Result 态返回 false，不做任何事）。
function ____exports.coreBackToSelect(core) -- 174
	if core.phase ~= "Result" then -- 174
		return false -- 175
	end -- 175
	core.phase = "LevelSelect" -- 176
	core.flight = nil -- 177
	core.flightTime = 0 -- 178
	core.goalIndex = -1 -- 179
	core.result = nil -- 180
	return true -- 181
end -- 174
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 229
	local core = ____exports.createCore() -- 230
	local function makeBasis(frame) -- 232
		return prepareCamera({ -- 233
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 235
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 236
			up = {x = 0, y = 1, z = 0}, -- 237
			fovYDeg = deps.fovYDeg, -- 238
			aspect = deps.aspect, -- 239
			viewW = deps.viewW, -- 240
			viewH = deps.viewH -- 241
		}, HANDEDNESS, FLIP_Y) -- 241
	end -- 232
	local function updateAiming() -- 248
		deps.aim:setEnabled(true) -- 249
		deps.scene.syncBodies(0) -- 250
		deps.scene.syncProbe(level.probeStart) -- 251
		local planetPts = {} -- 253
		for ____, p in ipairs(deps.scene.planets) do -- 254
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, 0) -- 254
		end -- 254
		local frame = deps.rig.step( -- 256
			{ -- 256
				level.probeStart, -- 256
				table.unpack(planetPts) -- 256
			}, -- 256
			deps.scene.probeRadius -- 256
		) -- 256
		deps.rig.apply(deps.camera, frame) -- 257
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 258
		local basis = makeBasis(frame) -- 259
		local pp = projectPrepared( -- 262
			planeToWorld(level.probeStart, 0), -- 262
			basis -- 262
		) -- 262
		if pp ~= nil then -- 262
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 263
		end -- 263
		local pred = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = core.aim.velocity.x, y = core.aim.velocity.y}}, level.bodies, {steps = PredictSteps, dt = core.dt, sampleEvery = 4, escapeRadius = level.escapeRadius}) -- 270
		deps.trajectory:setPrediction(pred.points, basis) -- 275
		deps.trajectory:clearTrail() -- 276
	end -- 248
	local function updateFlying(dt) -- 279
		deps.aim:setEnabled(false) -- 280
		local entered = ____exports.coreUpdate(core, dt) -- 281
		if core.flight == nil then -- 281
			return entered -- 282
		end -- 282
		local idx = ____exports.coreProbeIndex(core) -- 284
		local pos = core.flight.points[idx + 1] -- 285
		local t = core.flightTime -- 286
		deps.scene.syncBodies(t) -- 288
		deps.scene.syncProbe(pos) -- 289
		if idx > 0 then -- 289
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 291
		end -- 291
		local planetPts = {} -- 294
		for ____, p in ipairs(deps.scene.planets) do -- 295
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 295
		end -- 295
		local frame = deps.rig.step( -- 297
			{ -- 297
				pos, -- 297
				table.unpack(planetPts) -- 297
			}, -- 297
			deps.scene.probeRadius -- 297
		) -- 297
		deps.rig.apply(deps.camera, frame) -- 298
		deps.scene.syncBackdrop(frame.eye, frame.target) -- 299
		local basis = makeBasis(frame) -- 300
		local trail = {} -- 303
		do -- 303
			local i = 0 -- 304
			while i <= idx do -- 304
				trail[#trail + 1] = core.flight.points[i + 1] -- 304
				i = i + 1 -- 304
			end -- 304
		end -- 304
		deps.trajectory:setTrail(trail, basis) -- 305
		return entered -- 307
	end -- 279
	local function update(dt) -- 310
		if core.phase == "Aiming" then -- 310
			updateAiming() -- 312
		elseif core.phase == "Flying" then -- 312
			local entered = updateFlying(dt) -- 314
			if entered and core.result ~= nil then -- 314
				deps:onResult(core.result) -- 316
				deps:onPhase("Result") -- 317
			end -- 317
		end -- 317
	end -- 310
	return { -- 323
		phase = function() return core.phase end, -- 324
		result = function() return core.result end, -- 325
		onAimDrag = function(____, a) -- 326
			core.aim = a -- 327
		end, -- 326
		launch = function(____, v) -- 329
			if core.phase ~= "Aiming" then -- 329
				return -- 330
			end -- 330
			____exports.coreLaunch(core, v, level) -- 331
			deps.trajectory:clearPrediction() -- 332
			deps:onPhase("Flying") -- 333
		end, -- 329
		retry = function() -- 335
			if core.phase ~= "Result" then -- 335
				return -- 336
			end -- 336
			____exports.coreRetry(core) -- 337
			deps.trajectory:clearTrail() -- 338
			deps.trajectory:clearPrediction() -- 339
			deps:onPhase("Aiming") -- 340
		end, -- 335
		backToSelect = function() -- 342
			if not ____exports.coreBackToSelect(core) then -- 342
				return false -- 343
			end -- 343
			deps.aim:setEnabled(false) -- 345
			deps.trajectory:clearTrail() -- 346
			deps.trajectory:clearPrediction() -- 347
			deps:onPhase("LevelSelect") -- 348
			return true -- 349
		end, -- 342
		startLevel = function() -- 351
			____exports.coreRetry(core) -- 354
			deps.trajectory:clearTrail() -- 355
			deps.trajectory:clearPrediction() -- 356
			deps:onPhase("Aiming") -- 357
		end, -- 351
		update = function(____, frameDt) return update(frameDt) end -- 360
	} -- 360
end -- 229
return ____exports -- 229
-- [ts]: Game.ts
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 26
local bodyPositionAt = ____Gravity.bodyPositionAt -- 26
local simulate = ____Gravity.simulate -- 26
local sub = ____Gravity.sub -- 26
local ____Scene = require("game.Scene") -- 27
local planeToWorld = ____Scene.planeToWorld -- 27
local ____Projection = require("game.Projection") -- 30
local FLIP_Y = ____Projection.FLIP_Y -- 30
local HANDEDNESS = ____Projection.HANDEDNESS -- 30
local prepareCamera = ____Projection.prepareCamera -- 30
local projectPrepared = ____Projection.projectPrepared -- 30
local ____LevelData = require("game.LevelData") -- 31
local findGoalIndex = ____LevelData.findGoalIndex -- 31
local ____Config = require("game.Config") -- 32
local AimMinSpeed = ____Config.AimMinSpeed -- 32
local FlightPlayback = ____Config.FlightPlayback -- 32
local PhysicsStep = ____Config.PhysicsStep -- 32
local PredictSteps = ____Config.PredictSteps -- 32
--- 结算三态判定（手册 §5.8）。
-- 
-- 优先级：到达目标 > 逃逸目标达成 > 撞毁 > 错过。
-- （到达目标优先于撞毁：轨迹在到达点截断，撞毁点根本不会发生。）
-- 
-- 全部输入在**发射瞬间**即可确定 —— 结算与飞行一样是确定性的。
function ____exports.resolveResult(outcome, goalIndex, goal) -- 48
	if goalIndex >= 0 then -- 48
		return "success" -- 49
	end -- 49
	if goal.kind == "escape" and outcome == "escaped" then -- 49
		return "success" -- 50
	end -- 50
	if outcome == "crashed" then -- 50
		return "crashed" -- 51
	end -- 51
	return "missed" -- 52
end -- 48
function ____exports.createCore() -- 83
	return { -- 84
		phase = "Aiming", -- 85
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 86
		flight = nil, -- 87
		dt = PhysicsStep, -- 88
		flightTime = 0, -- 89
		goalIndex = -1, -- 90
		result = nil -- 91
	} -- 91
end -- 83
--- 发射：预推演整段飞行、判定目标与结算，并进入 Flying。
-- 只在 Aiming 态有效。
-- 
-- 结算在**这一刻**就完全确定（确定性设计的直接推论）：
-- 轨迹、目标到达点、撞毁/逃逸/超时，全部已知。
function ____exports.coreLaunch(core, velocity, level) -- 102
	if core.phase ~= "Aiming" then -- 102
		return -- 103
	end -- 103
	local flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = velocity.x, y = velocity.y}}, level.bodies, {steps = level.maxSteps, dt = core.dt, sampleEvery = 1, escapeRadius = level.escapeRadius}) -- 104
	core.flight = flight -- 109
	core.goalIndex = findGoalIndex(flight.points, level.bodies, level.goal, core.dt) -- 110
	core.result = ____exports.resolveResult(flight.outcome, core.goalIndex, level.goal) -- 111
	core.flightTime = 0 -- 112
	core.phase = "Flying" -- 113
end -- 102
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 117
	if core.flight == nil then -- 117
		return 0 -- 118
	end -- 118
	local idx = math.floor(core.flightTime / core.dt) -- 119
	local last = #core.flight.points - 1 -- 120
	if idx > last then -- 120
		idx = last -- 121
	end -- 121
	if idx < 0 then -- 121
		idx = 0 -- 122
	end -- 122
	return idx -- 123
end -- 117
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
-- 
-- 飞行终点 = min(自然终点, 目标到达点)：到达目标即刻成功收束。
-- 收束时把回放时间吸附到终点索引，冻结帧恰好停在到达/终点的位置。
function ____exports.coreUpdate(core, dt) -- 132
	if core.phase ~= "Flying" or core.flight == nil then -- 132
		return false -- 133
	end -- 133
	core.flightTime = core.flightTime + dt * FlightPlayback -- 134
	local naturalEnd = #core.flight.points - 1 -- 135
	local endIdx = core.goalIndex >= 0 and core.goalIndex < naturalEnd and core.goalIndex or naturalEnd -- 136
	if ____exports.coreProbeIndex(core) >= endIdx then -- 136
		core.flightTime = endIdx * core.dt -- 139
		core.phase = "Result" -- 140
		return true -- 141
	end -- 141
	return false -- 143
end -- 132
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 147
	core.phase = "Aiming" -- 148
	core.flight = nil -- 149
	core.flightTime = 0 -- 150
	core.goalIndex = -1 -- 151
	core.result = nil -- 152
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 153
end -- 147
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 188
	local core = ____exports.createCore() -- 189
	local function makeBasis(frame) -- 191
		return prepareCamera({ -- 192
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 194
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 195
			up = {x = 0, y = 1, z = 0}, -- 196
			fovYDeg = deps.fovYDeg, -- 197
			aspect = deps.aspect, -- 198
			viewW = deps.viewW, -- 199
			viewH = deps.viewH -- 200
		}, HANDEDNESS, FLIP_Y) -- 200
	end -- 191
	local function updateAiming() -- 207
		deps.aim:setEnabled(true) -- 208
		deps.scene.syncBodies(0) -- 209
		deps.scene.syncProbe(level.probeStart) -- 210
		local planetPts = {} -- 212
		for ____, p in ipairs(deps.scene.planets) do -- 213
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, 0) -- 213
		end -- 213
		local frame = deps.rig.step({ -- 215
			level.probeStart, -- 215
			table.unpack(planetPts) -- 215
		}) -- 215
		deps.rig.apply(deps.camera, frame) -- 216
		local basis = makeBasis(frame) -- 217
		local pp = projectPrepared( -- 220
			planeToWorld(level.probeStart, 0), -- 220
			basis -- 220
		) -- 220
		if pp ~= nil then -- 220
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 221
		end -- 221
		local pred = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = core.aim.velocity.x, y = core.aim.velocity.y}}, level.bodies, {steps = PredictSteps, dt = core.dt, sampleEvery = 4, escapeRadius = level.escapeRadius}) -- 228
		deps.trajectory:setPrediction(pred.points, basis) -- 233
		deps.trajectory:clearTrail() -- 234
	end -- 207
	local function updateFlying(dt) -- 237
		deps.aim:setEnabled(false) -- 238
		local entered = ____exports.coreUpdate(core, dt) -- 239
		if core.flight == nil then -- 239
			return entered -- 240
		end -- 240
		local idx = ____exports.coreProbeIndex(core) -- 242
		local pos = core.flight.points[idx + 1] -- 243
		local t = core.flightTime -- 244
		deps.scene.syncBodies(t) -- 246
		deps.scene.syncProbe(pos) -- 247
		if idx > 0 then -- 247
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 249
		end -- 249
		local planetPts = {} -- 252
		for ____, p in ipairs(deps.scene.planets) do -- 253
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 253
		end -- 253
		local frame = deps.rig.step({ -- 255
			pos, -- 255
			table.unpack(planetPts) -- 255
		}) -- 255
		deps.rig.apply(deps.camera, frame) -- 256
		local basis = makeBasis(frame) -- 257
		local trail = {} -- 260
		do -- 260
			local i = 0 -- 261
			while i <= idx do -- 261
				trail[#trail + 1] = core.flight.points[i + 1] -- 261
				i = i + 1 -- 261
			end -- 261
		end -- 261
		deps.trajectory:setTrail(trail, basis) -- 262
		return entered -- 264
	end -- 237
	local function update(dt) -- 267
		if core.phase == "Aiming" then -- 267
			updateAiming() -- 269
		elseif core.phase == "Flying" then -- 269
			local entered = updateFlying(dt) -- 271
			if entered and core.result ~= nil then -- 271
				deps:onResult(core.result) -- 273
				deps:onPhase("Result") -- 274
			end -- 274
		end -- 274
	end -- 267
	return { -- 280
		phase = function() return core.phase end, -- 281
		result = function() return core.result end, -- 282
		onAimDrag = function(____, a) -- 283
			core.aim = a -- 284
		end, -- 283
		launch = function(____, v) -- 286
			if core.phase ~= "Aiming" then -- 286
				return -- 287
			end -- 287
			____exports.coreLaunch(core, v, level) -- 288
			deps.trajectory:clearPrediction() -- 289
			deps:onPhase("Flying") -- 290
		end, -- 286
		retry = function() -- 292
			if core.phase ~= "Result" then -- 292
				return -- 293
			end -- 293
			____exports.coreRetry(core) -- 294
			deps.trajectory:clearTrail() -- 295
			deps.trajectory:clearPrediction() -- 296
			deps:onPhase("Aiming") -- 297
		end, -- 292
		update = function(____, frameDt) return update(frameDt) end -- 300
	} -- 300
end -- 188
return ____exports -- 188
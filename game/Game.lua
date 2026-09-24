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
local ____Config = require("game.Config") -- 31
local AimMinSpeed = ____Config.AimMinSpeed -- 31
local FlightPlayback = ____Config.FlightPlayback -- 31
local PhysicsStep = ____Config.PhysicsStep -- 31
local PredictSteps = ____Config.PredictSteps -- 31
--- 物理结局 → 结算三态。
-- 
-- S1 测试关：飞出边界 = 逃逸成功。
-- S2 接入关卡数据后，按“目标行星到达容差”细化（§5.8）。
function ____exports.resolveOutcome(outcome) -- 45
	if outcome == "crashed" then -- 45
		return "crashed" -- 46
	end -- 46
	if outcome == "escaped" then -- 46
		return "success" -- 47
	end -- 47
	return "missed" -- 48
end -- 45
function ____exports.createCore() -- 76
	return { -- 77
		phase = "Aiming", -- 78
		aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}}, -- 79
		flight = nil, -- 80
		dt = PhysicsStep, -- 81
		flightTime = 0, -- 82
		result = nil -- 83
	} -- 83
end -- 76
--- 发射：预推演整段飞行并进入 Flying。只在 Aiming 态有效。
function ____exports.coreLaunch(core, velocity, level) -- 88
	if core.phase ~= "Aiming" then -- 88
		return -- 89
	end -- 89
	core.flight = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = velocity.x, y = velocity.y}}, level.bodies, {steps = level.maxSteps, dt = core.dt, sampleEvery = 1, escapeRadius = level.escapeRadius}) -- 90
	core.flightTime = 0 -- 95
	core.phase = "Flying" -- 96
end -- 88
--- 当前帧探测器在 flight.points 中的索引（夹紧到有效范围）。
function ____exports.coreProbeIndex(core) -- 100
	if core.flight == nil then -- 100
		return 0 -- 101
	end -- 101
	local idx = math.floor(core.flightTime / core.dt) -- 102
	local last = #core.flight.points - 1 -- 103
	if idx > last then -- 103
		idx = last -- 104
	end -- 104
	if idx < 0 then -- 104
		idx = 0 -- 105
	end -- 105
	return idx -- 106
end -- 100
--- 推进核心状态。返回 true 表示这一帧进入了 Result。
function ____exports.coreUpdate(core, dt) -- 112
	if core.phase ~= "Flying" or core.flight == nil then -- 112
		return false -- 113
	end -- 113
	core.flightTime = core.flightTime + dt * FlightPlayback -- 114
	if ____exports.coreProbeIndex(core) >= #core.flight.points - 1 then -- 114
		core.phase = "Result" -- 116
		core.result = ____exports.resolveOutcome(core.flight.outcome) -- 117
		return true -- 118
	end -- 118
	return false -- 120
end -- 112
--- 重试本关：回到 Aiming，清空飞行与结算。
function ____exports.coreRetry(core) -- 124
	core.phase = "Aiming" -- 125
	core.flight = nil -- 126
	core.flightTime = 0 -- 127
	core.result = nil -- 128
	core.aim = {velocity = {x = 0, y = -AimMinSpeed}, power = 0, unit = {x = 0, y = -1}} -- 129
end -- 124
--- 组装游戏（状态机 + 引擎驱动）。
function ____exports.createGame(level, deps) -- 164
	local core = ____exports.createCore() -- 165
	local aimDirty = true -- 166
	local function makeBasis(frame) -- 168
		return prepareCamera({ -- 169
			eye = {x = frame.eye.x, y = frame.eye.y, z = frame.eye.z}, -- 171
			target = {x = frame.target.x, y = frame.target.y, z = frame.target.z}, -- 172
			up = {x = 0, y = 1, z = 0}, -- 173
			fovYDeg = deps.fovYDeg, -- 174
			aspect = deps.aspect, -- 175
			viewW = deps.viewW, -- 176
			viewH = deps.viewH -- 177
		}, HANDEDNESS, FLIP_Y) -- 177
	end -- 168
	local function updateAiming() -- 184
		deps.aim:setEnabled(true) -- 185
		deps.scene.syncBodies(0) -- 186
		deps.scene.syncProbe(level.probeStart) -- 187
		local planetPts = {} -- 189
		for ____, p in ipairs(deps.scene.planets) do -- 190
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, 0) -- 190
		end -- 190
		local frame = deps.rig.step({ -- 192
			level.probeStart, -- 192
			table.unpack(planetPts) -- 192
		}) -- 192
		deps.rig.apply(deps.camera, frame) -- 193
		local basis = makeBasis(frame) -- 194
		local pp = projectPrepared( -- 197
			planeToWorld(level.probeStart, 0), -- 197
			basis -- 197
		) -- 197
		if pp ~= nil then -- 197
			deps.aim:setProbeOffset({x = pp.x, y = pp.y}) -- 198
		end -- 198
		if aimDirty then -- 198
			local pred = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = {x = core.aim.velocity.x, y = core.aim.velocity.y}}, level.bodies, {steps = PredictSteps, dt = core.dt, sampleEvery = 4, escapeRadius = level.escapeRadius}) -- 201
			deps.trajectory:setPrediction(pred.points, basis) -- 206
			deps.trajectory:clearTrail() -- 207
			aimDirty = false -- 208
		end -- 208
	end -- 184
	local function updateFlying(dt) -- 212
		deps.aim:setEnabled(false) -- 213
		local entered = ____exports.coreUpdate(core, dt) -- 214
		if core.flight == nil then -- 214
			return entered -- 215
		end -- 215
		local idx = ____exports.coreProbeIndex(core) -- 217
		local pos = core.flight.points[idx + 1] -- 218
		local t = core.flightTime -- 219
		deps.scene.syncBodies(t) -- 221
		deps.scene.syncProbe(pos) -- 222
		if idx > 0 then -- 222
			deps.scene.faceVelocity(sub(pos, core.flight.points[idx])) -- 224
		end -- 224
		local planetPts = {} -- 227
		for ____, p in ipairs(deps.scene.planets) do -- 228
			planetPts[#planetPts + 1] = bodyPositionAt(p.def, t) -- 228
		end -- 228
		local frame = deps.rig.step({ -- 230
			pos, -- 230
			table.unpack(planetPts) -- 230
		}) -- 230
		deps.rig.apply(deps.camera, frame) -- 231
		local basis = makeBasis(frame) -- 232
		local trail = {} -- 235
		do -- 235
			local i = 0 -- 236
			while i <= idx do -- 236
				trail[#trail + 1] = core.flight.points[i + 1] -- 236
				i = i + 1 -- 236
			end -- 236
		end -- 236
		deps.trajectory:setTrail(trail, basis) -- 237
		return entered -- 239
	end -- 212
	local function update(dt) -- 242
		if core.phase == "Aiming" then -- 242
			updateAiming() -- 244
		elseif core.phase == "Flying" then -- 244
			local entered = updateFlying(dt) -- 246
			if entered and core.result ~= nil then -- 246
				deps:onResult(core.result) -- 248
				deps:onPhase("Result") -- 249
			end -- 249
		end -- 249
	end -- 242
	return { -- 255
		phase = function() return core.phase end, -- 256
		result = function() return core.result end, -- 257
		onAimDrag = function(____, a) -- 258
			core.aim = a -- 259
			aimDirty = true -- 260
		end, -- 258
		launch = function(____, v) -- 262
			if core.phase ~= "Aiming" then -- 262
				return -- 263
			end -- 263
			____exports.coreLaunch(core, v, level) -- 264
			deps.trajectory:clearPrediction() -- 265
			deps:onPhase("Flying") -- 266
		end, -- 262
		retry = function() -- 268
			if core.phase ~= "Result" then -- 268
				return -- 269
			end -- 269
			____exports.coreRetry(core) -- 270
			deps.trajectory:clearTrail() -- 271
			deps.trajectory:clearPrediction() -- 272
			aimDirty = true -- 273
			deps:onPhase("Aiming") -- 274
		end, -- 268
		update = function(____, frameDt) return update(frameDt) end -- 277
	} -- 277
end -- 164
return ____exports -- 164
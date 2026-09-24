-- [ts]: CameraRig.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 13
local Vec3 = ____Dora.Vec3 -- 13
local ____Config = require("game.Config") -- 14
local CameraLerp = ____Config.CameraLerp -- 14
local CameraMaxDistance = ____Config.CameraMaxDistance -- 14
local CameraMinDistance = ____Config.CameraMinDistance -- 14
local CameraTiltDefault = ____Config.CameraTiltDefault -- 14
local ____Scene = require("game.Scene") -- 16
local planeToWorld = ____Scene.planeToWorld -- 16
function ____exports.defaultRigOptions() -- 31
	return { -- 32
		tiltDeg = CameraTiltDefault, -- 33
		minDistance = CameraMinDistance, -- 34
		maxDistance = CameraMaxDistance, -- 35
		lerp = CameraLerp, -- 36
		fitFactor = 1.6 -- 37
	} -- 37
end -- 31
--- 计算所有关键点的包围盒中心与半对角。
-- 
-- 关键点通常包含：探测器、所有行星、目标点。
-- 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
function ____exports.computeFit(points) -- 94
	if #points == 0 then -- 94
		return {centerX = 0, centerY = 0, extent = 0} -- 95
	end -- 95
	local minX = points[1].x -- 97
	local maxX = points[1].x -- 98
	local minY = points[1].y -- 99
	local maxY = points[1].y -- 100
	do -- 100
		local i = 1 -- 101
		while i < #points do -- 101
			local p = points[i + 1] -- 102
			if p.x < minX then -- 102
				minX = p.x -- 103
			end -- 103
			if p.x > maxX then -- 103
				maxX = p.x -- 104
			end -- 104
			if p.y < minY then -- 104
				minY = p.y -- 105
			end -- 105
			if p.y > maxY then -- 105
				maxY = p.y -- 106
			end -- 106
			i = i + 1 -- 101
		end -- 101
	end -- 101
	local hw = (maxX - minX) / 2 -- 109
	local hh = (maxY - minY) / 2 -- 110
	return { -- 111
		centerX = (minX + maxX) / 2, -- 112
		centerY = (minY + maxY) / 2, -- 113
		extent = math.sqrt(hw * hw + hh * hh) -- 114
	} -- 114
end -- 94
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；顺序无关。
function ____exports.computeRigStep(state, points, opts) -- 123
	local fit = ____exports.computeFit(points) -- 128
	local wantDistance = opts.minDistance + fit.extent * opts.fitFactor -- 130
	if wantDistance < opts.minDistance then -- 130
		wantDistance = opts.minDistance -- 131
	end -- 131
	if wantDistance > opts.maxDistance then -- 131
		wantDistance = opts.maxDistance -- 132
	end -- 132
	if not state.initialized then -- 132
		state.focusX = fit.centerX -- 136
		state.focusY = fit.centerY -- 137
		state.distance = wantDistance -- 138
		state.initialized = true -- 139
	else -- 139
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 141
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 142
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 143
		state.distance = state.distance + (wantDistance - state.distance) * k -- 144
	end -- 144
	local targetWorld = planeToWorld({x = state.focusX, y = state.focusY}, 0) -- 147
	local tilt = opts.tiltDeg * math.pi / 180 -- 150
	local eye = Vec3( -- 151
		targetWorld.x, -- 152
		targetWorld.y + math.sin(tilt) * state.distance, -- 153
		targetWorld.z + math.cos(tilt) * state.distance -- 154
	) -- 154
	return {target = targetWorld, eye = eye} -- 157
end -- 123
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 161
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 162
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 163
	return { -- 165
		step = function(points) -- 166
			return ____exports.computeRigStep(state, points, options) -- 167
		end, -- 166
		apply = function(camera, frame) -- 169
			camera:lookAt( -- 170
				frame.eye, -- 170
				frame.target, -- 170
				Vec3(0, 1, 0) -- 170
			) -- 170
		end -- 169
	} -- 169
end -- 161
return ____exports -- 161
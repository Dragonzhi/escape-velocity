-- [ts]: CameraRig.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 22
local Vec3 = ____Dora.Vec3 -- 22
local ____Projection = require("game.Projection") -- 23
local HANDEDNESS = ____Projection.HANDEDNESS -- 23
local FLIP_Y = ____Projection.FLIP_Y -- 23
local prepareCamera = ____Projection.prepareCamera -- 23
local projectPrepared = ____Projection.projectPrepared -- 23
local ____Config = require("game.Config") -- 24
local CameraLerp = ____Config.CameraLerp -- 24
local CameraMaxDistance = ____Config.CameraMaxDistance -- 24
local CameraMinDistance = ____Config.CameraMinDistance -- 24
local CameraTiltDefault = ____Config.CameraTiltDefault -- 24
local ____Scene = require("game.Scene") -- 26
local planeToWorld = ____Scene.planeToWorld -- 26
--- 默认参数。
-- 
-- @param fovYDeg 垂直视野角，来自 `View.fieldOfView`；省略按 45（引擎默认）算。
-- @param aspect 宽高比，来自 `View.aspectRatio`；省略按 1（正方形）算。
function ____exports.defaultRigOptions(fovYDeg, aspect) -- 51
	return { -- 52
		tiltDeg = CameraTiltDefault, -- 53
		minDistance = CameraMinDistance, -- 54
		maxDistance = CameraMaxDistance, -- 55
		lerp = CameraLerp, -- 56
		fovYDeg = fovYDeg ~= nil and fovYDeg or 45, -- 57
		aspect = aspect ~= nil and aspect > 0 and aspect or 1, -- 58
		margin = 0.05 -- 59
	} -- 59
end -- 51
--- 计算所有关键点的包围盒中心与半对角。
-- 
-- 关键点通常包含：探测器、所有行星、目标点。
-- 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
function ____exports.computeFit(points) -- 117
	if #points == 0 then -- 117
		return {centerX = 0, centerY = 0, extent = 0} -- 118
	end -- 118
	local minX = points[1].x -- 120
	local maxX = points[1].x -- 121
	local minY = points[1].y -- 122
	local maxY = points[1].y -- 123
	do -- 123
		local i = 1 -- 124
		while i < #points do -- 124
			local p = points[i + 1] -- 125
			if p.x < minX then -- 125
				minX = p.x -- 126
			end -- 126
			if p.x > maxX then -- 126
				maxX = p.x -- 127
			end -- 127
			if p.y < minY then -- 127
				minY = p.y -- 128
			end -- 128
			if p.y > maxY then -- 128
				maxY = p.y -- 129
			end -- 129
			i = i + 1 -- 124
		end -- 124
	end -- 124
	local hw = (maxX - minX) / 2 -- 132
	local hh = (maxY - minY) / 2 -- 133
	return { -- 134
		centerX = (minX + maxX) / 2, -- 135
		centerY = (minY + maxY) / 2, -- 136
		extent = math.sqrt(hw * hw + hh * hh) -- 137
	} -- 137
end -- 117
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 142
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 143
	local tilt = opts.tiltDeg * math.pi / 180 -- 144
	return { -- 145
		target = targetWorld, -- 146
		eye = Vec3( -- 147
			targetWorld.x, -- 148
			targetWorld.y + math.sin(tilt) * distance, -- 149
			targetWorld.z + math.cos(tilt) * distance -- 150
		) -- 150
	} -- 150
end -- 142
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts) -- 165
	local frame = frameAt(centerX, centerY, distance, opts) -- 173
	local view = { -- 174
		eye = frame.eye, -- 175
		target = frame.target, -- 176
		up = {x = 0, y = 1, z = 0}, -- 177
		fovYDeg = opts.fovYDeg, -- 178
		aspect = opts.aspect, -- 179
		viewW = 2, -- 180
		viewH = 2 -- 181
	} -- 181
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 183
	local limit = 1 - opts.margin -- 184
	do -- 184
		local i = 0 -- 186
		while i < #points do -- 186
			local p = projectPrepared( -- 187
				planeToWorld(points[i + 1], 0), -- 187
				basis -- 187
			) -- 187
			if p == nil then -- 187
				return false -- 188
			end -- 188
			local r = i == 0 and probeRadius or 0 -- 189
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 190
			local rx = ry / opts.aspect -- 191
			if math.abs(p.x) + rx > limit then -- 191
				return false -- 192
			end -- 192
			if math.abs(p.y) + ry > limit then -- 192
				return false -- 193
			end -- 193
			i = i + 1 -- 186
		end -- 186
	end -- 186
	return true -- 195
end -- 165
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts) -- 204
	local lo = opts.minDistance -- 211
	local hi = opts.maxDistance -- 212
	if frameFits( -- 212
		points, -- 213
		centerX, -- 213
		centerY, -- 213
		lo, -- 213
		probeRadius, -- 213
		opts -- 213
	) then -- 213
		return lo -- 213
	end -- 213
	if not frameFits( -- 213
		points, -- 214
		centerX, -- 214
		centerY, -- 214
		hi, -- 214
		probeRadius, -- 214
		opts -- 214
	) then -- 214
		return hi -- 214
	end -- 214
	local a = lo -- 216
	local b = hi -- 217
	do -- 217
		local i = 0 -- 218
		while i < 24 do -- 218
			local mid = (a + b) / 2 -- 219
			if frameFits( -- 219
				points, -- 220
				centerX, -- 220
				centerY, -- 220
				mid, -- 220
				probeRadius, -- 220
				opts -- 220
			) then -- 220
				b = mid -- 220
			else -- 220
				a = mid -- 220
			end -- 220
			i = i + 1 -- 218
		end -- 218
	end -- 218
	return b -- 222
end -- 204
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius) -- 230
	local fit = ____exports.computeFit(points) -- 236
	local radius = probeRadius ~= nil and probeRadius or 0 -- 237
	local wantDistance = fitDistance( -- 239
		points, -- 239
		fit.centerX, -- 239
		fit.centerY, -- 239
		radius, -- 239
		opts -- 239
	) -- 239
	if not state.initialized then -- 239
		state.focusX = fit.centerX -- 243
		state.focusY = fit.centerY -- 244
		state.distance = wantDistance -- 245
		state.initialized = true -- 246
	else -- 246
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 248
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 249
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 250
		state.distance = state.distance + (wantDistance - state.distance) * k -- 251
	end -- 251
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 255
end -- 230
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 259
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 260
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 261
	return { -- 263
		step = function(points, probeRadius) -- 264
			return ____exports.computeRigStep(state, points, options, probeRadius) -- 265
		end, -- 264
		apply = function(camera, frame) -- 267
			camera:lookAt( -- 268
				frame.eye, -- 268
				frame.target, -- 268
				Vec3(0, 1, 0) -- 268
			) -- 268
		end -- 267
	} -- 267
end -- 259
return ____exports -- 259
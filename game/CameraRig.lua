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
function ____exports.computeFit(points) -- 134
	if #points == 0 then -- 134
		return {centerX = 0, centerY = 0, extent = 0} -- 135
	end -- 135
	local minX = points[1].x -- 137
	local maxX = points[1].x -- 138
	local minY = points[1].y -- 139
	local maxY = points[1].y -- 140
	do -- 140
		local i = 1 -- 141
		while i < #points do -- 141
			local p = points[i + 1] -- 142
			if p.x < minX then -- 142
				minX = p.x -- 143
			end -- 143
			if p.x > maxX then -- 143
				maxX = p.x -- 144
			end -- 144
			if p.y < minY then -- 144
				minY = p.y -- 145
			end -- 145
			if p.y > maxY then -- 145
				maxY = p.y -- 146
			end -- 146
			i = i + 1 -- 141
		end -- 141
	end -- 141
	local hw = (maxX - minX) / 2 -- 149
	local hh = (maxY - minY) / 2 -- 150
	return { -- 151
		centerX = (minX + maxX) / 2, -- 152
		centerY = (minY + maxY) / 2, -- 153
		extent = math.sqrt(hw * hw + hh * hh) -- 154
	} -- 154
end -- 134
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 159
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 160
	local tilt = opts.tiltDeg * math.pi / 180 -- 161
	return { -- 162
		target = targetWorld, -- 163
		eye = Vec3( -- 164
			targetWorld.x, -- 165
			targetWorld.y + math.sin(tilt) * distance, -- 166
			targetWorld.z + math.cos(tilt) * distance -- 167
		) -- 167
	} -- 167
end -- 159
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 182
	local frame = frameAt(centerX, centerY, distance, opts) -- 192
	local view = { -- 193
		eye = frame.eye, -- 194
		target = frame.target, -- 195
		up = {x = 0, y = 1, z = 0}, -- 196
		fovYDeg = opts.fovYDeg, -- 197
		aspect = opts.aspect, -- 198
		viewW = 2, -- 199
		viewH = 2 -- 200
	} -- 200
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 202
	local limit = 1 - opts.margin -- 203
	do -- 203
		local i = 0 -- 205
		while i < #points do -- 205
			local p = projectPrepared( -- 206
				planeToWorld(points[i + 1], 0), -- 206
				basis -- 206
			) -- 206
			if p == nil then -- 206
				return false -- 207
			end -- 207
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 208
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 209
			local rx = ry / opts.aspect -- 210
			if math.abs(p.x) + rx > limit then -- 210
				return false -- 211
			end -- 211
			if math.abs(p.y) + ry > limit then -- 211
				return false -- 212
			end -- 212
			i = i + 1 -- 205
		end -- 205
	end -- 205
	return true -- 214
end -- 182
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 223
	local lo = opts.minDistance -- 231
	local hi = opts.maxDistance -- 232
	if frameFits( -- 232
		points, -- 233
		centerX, -- 233
		centerY, -- 233
		lo, -- 233
		probeRadius, -- 233
		opts, -- 233
		radii -- 233
	) then -- 233
		return lo -- 233
	end -- 233
	if not frameFits( -- 233
		points, -- 234
		centerX, -- 234
		centerY, -- 234
		hi, -- 234
		probeRadius, -- 234
		opts, -- 234
		radii -- 234
	) then -- 234
		return hi -- 234
	end -- 234
	local a = lo -- 236
	local b = hi -- 237
	do -- 237
		local i = 0 -- 238
		while i < 24 do -- 238
			local mid = (a + b) / 2 -- 239
			if frameFits( -- 239
				points, -- 240
				centerX, -- 240
				centerY, -- 240
				mid, -- 240
				probeRadius, -- 240
				opts, -- 240
				radii -- 240
			) then -- 240
				b = mid -- 240
			else -- 240
				a = mid -- 240
			end -- 240
			i = i + 1 -- 238
		end -- 238
	end -- 238
	return b -- 242
end -- 223
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 250
	local fit = ____exports.computeFit(points) -- 258
	local radius = probeRadius ~= nil and probeRadius or 0 -- 259
	local wantDistance = fitDistance( -- 261
		points, -- 261
		fit.centerX, -- 261
		fit.centerY, -- 261
		radius, -- 261
		opts, -- 261
		radii -- 261
	) -- 261
	if not state.initialized then -- 261
		state.focusX = fit.centerX -- 265
		state.focusY = fit.centerY -- 266
		state.distance = wantDistance -- 267
		state.initialized = true -- 268
	else -- 268
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 270
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 271
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 272
		state.distance = state.distance + (wantDistance - state.distance) * k -- 273
	end -- 273
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 277
end -- 250
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 281
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 282
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 283
	return { -- 285
		step = function(points, probeRadius, radii, minDistance) -- 286
			local opts = options -- 289
			if minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 289
				opts = { -- 291
					tiltDeg = options.tiltDeg, -- 292
					minDistance = minDistance, -- 293
					maxDistance = options.maxDistance, -- 294
					lerp = options.lerp, -- 295
					fovYDeg = options.fovYDeg, -- 296
					aspect = options.aspect, -- 297
					margin = options.margin -- 298
				} -- 298
			end -- 298
			return ____exports.computeRigStep( -- 301
				state, -- 301
				points, -- 301
				opts, -- 301
				probeRadius, -- 301
				radii -- 301
			) -- 301
		end, -- 286
		wantDistance = function(points, probeRadius, radii) -- 304
			local fit = ____exports.computeFit(points) -- 305
			return fitDistance( -- 306
				points, -- 306
				fit.centerX, -- 306
				fit.centerY, -- 306
				probeRadius ~= nil and probeRadius or 0, -- 306
				options, -- 306
				radii -- 306
			) -- 306
		end, -- 304
		apply = function(camera, frame) -- 308
			camera:lookAt( -- 309
				frame.eye, -- 309
				frame.target, -- 309
				Vec3(0, 1, 0) -- 309
			) -- 309
		end, -- 308
		reset = function() -- 311
			state.focusX = 0 -- 312
			state.focusY = 0 -- 313
			state.distance = options.minDistance -- 314
			state.initialized = false -- 315
		end -- 311
	} -- 311
end -- 281
return ____exports -- 281
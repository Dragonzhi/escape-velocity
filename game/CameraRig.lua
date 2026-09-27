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
function ____exports.defaultRigOptions(fovYDeg, aspect, minDistance, maxDistance) -- 51
	return { -- 52
		tiltDeg = CameraTiltDefault, -- 53
		minDistance = minDistance ~= nil and minDistance > 0 and minDistance or CameraMinDistance, -- 56
		maxDistance = maxDistance ~= nil and maxDistance > 0 and maxDistance or CameraMaxDistance, -- 57
		lerp = CameraLerp, -- 58
		fovYDeg = fovYDeg ~= nil and fovYDeg or 45, -- 59
		aspect = aspect ~= nil and aspect > 0 and aspect or 1, -- 60
		margin = 0.05 -- 61
	} -- 61
end -- 51
--- 计算所有关键点的包围盒中心与半对角。
-- 
-- 关键点通常包含：探测器、所有行星、目标点。
-- 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
function ____exports.computeFit(points) -- 136
	if #points == 0 then -- 136
		return {centerX = 0, centerY = 0, extent = 0} -- 137
	end -- 137
	local minX = points[1].x -- 139
	local maxX = points[1].x -- 140
	local minY = points[1].y -- 141
	local maxY = points[1].y -- 142
	do -- 142
		local i = 1 -- 143
		while i < #points do -- 143
			local p = points[i + 1] -- 144
			if p.x < minX then -- 144
				minX = p.x -- 145
			end -- 145
			if p.x > maxX then -- 145
				maxX = p.x -- 146
			end -- 146
			if p.y < minY then -- 146
				minY = p.y -- 147
			end -- 147
			if p.y > maxY then -- 147
				maxY = p.y -- 148
			end -- 148
			i = i + 1 -- 143
		end -- 143
	end -- 143
	local hw = (maxX - minX) / 2 -- 151
	local hh = (maxY - minY) / 2 -- 152
	return { -- 153
		centerX = (minX + maxX) / 2, -- 154
		centerY = (minY + maxY) / 2, -- 155
		extent = math.sqrt(hw * hw + hh * hh) -- 156
	} -- 156
end -- 136
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 161
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 162
	local tilt = opts.tiltDeg * math.pi / 180 -- 163
	return { -- 164
		target = targetWorld, -- 165
		eye = Vec3( -- 166
			targetWorld.x, -- 167
			targetWorld.y + math.sin(tilt) * distance, -- 168
			targetWorld.z + math.cos(tilt) * distance -- 169
		) -- 169
	} -- 169
end -- 161
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 184
	local frame = frameAt(centerX, centerY, distance, opts) -- 194
	local view = { -- 195
		eye = frame.eye, -- 196
		target = frame.target, -- 197
		up = {x = 0, y = 1, z = 0}, -- 198
		fovYDeg = opts.fovYDeg, -- 199
		aspect = opts.aspect, -- 200
		viewW = 2, -- 201
		viewH = 2 -- 202
	} -- 202
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 204
	local limit = 1 - opts.margin -- 205
	do -- 205
		local i = 0 -- 207
		while i < #points do -- 207
			local p = projectPrepared( -- 208
				planeToWorld(points[i + 1], 0), -- 208
				basis -- 208
			) -- 208
			if p == nil then -- 208
				return false -- 209
			end -- 209
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 210
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 211
			local rx = ry / opts.aspect -- 212
			if math.abs(p.x) + rx > limit then -- 212
				return false -- 213
			end -- 213
			if math.abs(p.y) + ry > limit then -- 213
				return false -- 214
			end -- 214
			i = i + 1 -- 207
		end -- 207
	end -- 207
	return true -- 216
end -- 184
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 225
	local lo = opts.minDistance -- 233
	local hi = opts.maxDistance -- 234
	if frameFits( -- 234
		points, -- 235
		centerX, -- 235
		centerY, -- 235
		lo, -- 235
		probeRadius, -- 235
		opts, -- 235
		radii -- 235
	) then -- 235
		return lo -- 235
	end -- 235
	if not frameFits( -- 235
		points, -- 236
		centerX, -- 236
		centerY, -- 236
		hi, -- 236
		probeRadius, -- 236
		opts, -- 236
		radii -- 236
	) then -- 236
		return hi -- 236
	end -- 236
	local a = lo -- 238
	local b = hi -- 239
	do -- 239
		local i = 0 -- 240
		while i < 24 do -- 240
			local mid = (a + b) / 2 -- 241
			if frameFits( -- 241
				points, -- 242
				centerX, -- 242
				centerY, -- 242
				mid, -- 242
				probeRadius, -- 242
				opts, -- 242
				radii -- 242
			) then -- 242
				b = mid -- 242
			else -- 242
				a = mid -- 242
			end -- 242
			i = i + 1 -- 240
		end -- 240
	end -- 240
	return b -- 244
end -- 225
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 252
	local fit = ____exports.computeFit(points) -- 260
	local radius = probeRadius ~= nil and probeRadius or 0 -- 261
	local wantDistance = fitDistance( -- 263
		points, -- 263
		fit.centerX, -- 263
		fit.centerY, -- 263
		radius, -- 263
		opts, -- 263
		radii -- 263
	) -- 263
	if not state.initialized then -- 263
		state.focusX = fit.centerX -- 267
		state.focusY = fit.centerY -- 268
		state.distance = wantDistance -- 269
		state.initialized = true -- 270
	else -- 270
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 272
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 273
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 274
		state.distance = state.distance + (wantDistance - state.distance) * k -- 275
	end -- 275
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 279
end -- 252
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 283
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 284
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 285
	return { -- 287
		step = function(points, probeRadius, radii, minDistance) -- 288
			local opts = options -- 291
			if minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 291
				opts = { -- 293
					tiltDeg = options.tiltDeg, -- 294
					minDistance = minDistance, -- 295
					maxDistance = options.maxDistance, -- 296
					lerp = options.lerp, -- 297
					fovYDeg = options.fovYDeg, -- 298
					aspect = options.aspect, -- 299
					margin = options.margin -- 300
				} -- 300
			end -- 300
			return ____exports.computeRigStep( -- 303
				state, -- 303
				points, -- 303
				opts, -- 303
				probeRadius, -- 303
				radii -- 303
			) -- 303
		end, -- 288
		wantDistance = function(points, probeRadius, radii) -- 306
			local fit = ____exports.computeFit(points) -- 307
			return fitDistance( -- 308
				points, -- 308
				fit.centerX, -- 308
				fit.centerY, -- 308
				probeRadius ~= nil and probeRadius or 0, -- 308
				options, -- 308
				radii -- 308
			) -- 308
		end, -- 306
		apply = function(camera, frame) -- 310
			camera:lookAt( -- 311
				frame.eye, -- 311
				frame.target, -- 311
				Vec3(0, 1, 0) -- 311
			) -- 311
		end, -- 310
		reset = function() -- 313
			state.focusX = 0 -- 314
			state.focusY = 0 -- 315
			state.distance = options.minDistance -- 316
			state.initialized = false -- 317
		end -- 313
	} -- 313
end -- 283
return ____exports -- 283
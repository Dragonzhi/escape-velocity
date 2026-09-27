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
function ____exports.computeFit(points) -- 125
	if #points == 0 then -- 125
		return {centerX = 0, centerY = 0, extent = 0} -- 126
	end -- 126
	local minX = points[1].x -- 128
	local maxX = points[1].x -- 129
	local minY = points[1].y -- 130
	local maxY = points[1].y -- 131
	do -- 131
		local i = 1 -- 132
		while i < #points do -- 132
			local p = points[i + 1] -- 133
			if p.x < minX then -- 133
				minX = p.x -- 134
			end -- 134
			if p.x > maxX then -- 134
				maxX = p.x -- 135
			end -- 135
			if p.y < minY then -- 135
				minY = p.y -- 136
			end -- 136
			if p.y > maxY then -- 136
				maxY = p.y -- 137
			end -- 137
			i = i + 1 -- 132
		end -- 132
	end -- 132
	local hw = (maxX - minX) / 2 -- 140
	local hh = (maxY - minY) / 2 -- 141
	return { -- 142
		centerX = (minX + maxX) / 2, -- 143
		centerY = (minY + maxY) / 2, -- 144
		extent = math.sqrt(hw * hw + hh * hh) -- 145
	} -- 145
end -- 125
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 150
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 151
	local tilt = opts.tiltDeg * math.pi / 180 -- 152
	return { -- 153
		target = targetWorld, -- 154
		eye = Vec3( -- 155
			targetWorld.x, -- 156
			targetWorld.y + math.sin(tilt) * distance, -- 157
			targetWorld.z + math.cos(tilt) * distance -- 158
		) -- 158
	} -- 158
end -- 150
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 173
	local frame = frameAt(centerX, centerY, distance, opts) -- 183
	local view = { -- 184
		eye = frame.eye, -- 185
		target = frame.target, -- 186
		up = {x = 0, y = 1, z = 0}, -- 187
		fovYDeg = opts.fovYDeg, -- 188
		aspect = opts.aspect, -- 189
		viewW = 2, -- 190
		viewH = 2 -- 191
	} -- 191
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 193
	local limit = 1 - opts.margin -- 194
	do -- 194
		local i = 0 -- 196
		while i < #points do -- 196
			local p = projectPrepared( -- 197
				planeToWorld(points[i + 1], 0), -- 197
				basis -- 197
			) -- 197
			if p == nil then -- 197
				return false -- 198
			end -- 198
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 199
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 200
			local rx = ry / opts.aspect -- 201
			if math.abs(p.x) + rx > limit then -- 201
				return false -- 202
			end -- 202
			if math.abs(p.y) + ry > limit then -- 202
				return false -- 203
			end -- 203
			i = i + 1 -- 196
		end -- 196
	end -- 196
	return true -- 205
end -- 173
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 214
	local lo = opts.minDistance -- 222
	local hi = opts.maxDistance -- 223
	if frameFits( -- 223
		points, -- 224
		centerX, -- 224
		centerY, -- 224
		lo, -- 224
		probeRadius, -- 224
		opts, -- 224
		radii -- 224
	) then -- 224
		return lo -- 224
	end -- 224
	if not frameFits( -- 224
		points, -- 225
		centerX, -- 225
		centerY, -- 225
		hi, -- 225
		probeRadius, -- 225
		opts, -- 225
		radii -- 225
	) then -- 225
		return hi -- 225
	end -- 225
	local a = lo -- 227
	local b = hi -- 228
	do -- 228
		local i = 0 -- 229
		while i < 24 do -- 229
			local mid = (a + b) / 2 -- 230
			if frameFits( -- 230
				points, -- 231
				centerX, -- 231
				centerY, -- 231
				mid, -- 231
				probeRadius, -- 231
				opts, -- 231
				radii -- 231
			) then -- 231
				b = mid -- 231
			else -- 231
				a = mid -- 231
			end -- 231
			i = i + 1 -- 229
		end -- 229
	end -- 229
	return b -- 233
end -- 214
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 241
	local fit = ____exports.computeFit(points) -- 249
	local radius = probeRadius ~= nil and probeRadius or 0 -- 250
	local wantDistance = fitDistance( -- 252
		points, -- 252
		fit.centerX, -- 252
		fit.centerY, -- 252
		radius, -- 252
		opts, -- 252
		radii -- 252
	) -- 252
	if not state.initialized then -- 252
		state.focusX = fit.centerX -- 256
		state.focusY = fit.centerY -- 257
		state.distance = wantDistance -- 258
		state.initialized = true -- 259
	else -- 259
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 261
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 262
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 263
		state.distance = state.distance + (wantDistance - state.distance) * k -- 264
	end -- 264
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 268
end -- 241
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 272
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 273
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 274
	return { -- 276
		step = function(points, probeRadius, radii, minDistance) -- 277
			local opts = options -- 280
			if minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 280
				opts = { -- 282
					tiltDeg = options.tiltDeg, -- 283
					minDistance = minDistance, -- 284
					maxDistance = options.maxDistance, -- 285
					lerp = options.lerp, -- 286
					fovYDeg = options.fovYDeg, -- 287
					aspect = options.aspect, -- 288
					margin = options.margin -- 289
				} -- 289
			end -- 289
			return ____exports.computeRigStep( -- 292
				state, -- 292
				points, -- 292
				opts, -- 292
				probeRadius, -- 292
				radii -- 292
			) -- 292
		end, -- 277
		wantDistance = function(points, probeRadius, radii) -- 295
			local fit = ____exports.computeFit(points) -- 296
			return fitDistance( -- 297
				points, -- 297
				fit.centerX, -- 297
				fit.centerY, -- 297
				probeRadius ~= nil and probeRadius or 0, -- 297
				options, -- 297
				radii -- 297
			) -- 297
		end, -- 295
		apply = function(camera, frame) -- 299
			camera:lookAt( -- 300
				frame.eye, -- 300
				frame.target, -- 300
				Vec3(0, 1, 0) -- 300
			) -- 300
		end -- 299
	} -- 299
end -- 272
return ____exports -- 272
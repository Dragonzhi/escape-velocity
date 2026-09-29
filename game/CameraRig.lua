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
local CameraTiltMax = ____Config.CameraTiltMax -- 24
local CameraTiltMin = ____Config.CameraTiltMin -- 24
local ____Scene = require("game.Scene") -- 26
local planeToWorld = ____Scene.planeToWorld -- 26
--- 默认参数。
-- 
-- @param fovYDeg 垂直视野角，来自 `View.fieldOfView`；省略按 45（引擎默认）算。
-- @param aspect 宽高比，来自 `View.aspectRatio`；省略按 1（正方形）算。
function ____exports.defaultRigOptions(fovYDeg, aspect, minDistance, maxDistance, tiltDeg) -- 64
	return { -- 65
		tiltDeg = tiltDeg ~= nil and tiltDeg >= CameraTiltMin and tiltDeg <= CameraTiltMax and tiltDeg or CameraTiltDefault, -- 69
		minDistance = minDistance ~= nil and minDistance > 0 and minDistance or CameraMinDistance, -- 72
		maxDistance = maxDistance ~= nil and maxDistance > 0 and maxDistance or CameraMaxDistance, -- 73
		lerp = CameraLerp, -- 74
		fovYDeg = fovYDeg ~= nil and fovYDeg or 45, -- 75
		aspect = aspect ~= nil and aspect > 0 and aspect or 1, -- 76
		margin = 0.05 -- 77
	} -- 77
end -- 64
--- 计算所有关键点的包围盒中心与半对角。
-- 
-- 关键点通常包含：探测器、所有行星、目标点。
-- 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
function ____exports.computeFit(points) -- 153
	if #points == 0 then -- 153
		return {centerX = 0, centerY = 0, extent = 0} -- 154
	end -- 154
	local minX = points[1].x -- 156
	local maxX = points[1].x -- 157
	local minY = points[1].y -- 158
	local maxY = points[1].y -- 159
	do -- 159
		local i = 1 -- 160
		while i < #points do -- 160
			local p = points[i + 1] -- 161
			if p.x < minX then -- 161
				minX = p.x -- 162
			end -- 162
			if p.x > maxX then -- 162
				maxX = p.x -- 163
			end -- 163
			if p.y < minY then -- 163
				minY = p.y -- 164
			end -- 164
			if p.y > maxY then -- 164
				maxY = p.y -- 165
			end -- 165
			i = i + 1 -- 160
		end -- 160
	end -- 160
	local hw = (maxX - minX) / 2 -- 168
	local hh = (maxY - minY) / 2 -- 169
	return { -- 170
		centerX = (minX + maxX) / 2, -- 171
		centerY = (minY + maxY) / 2, -- 172
		extent = math.sqrt(hw * hw + hh * hh) -- 173
	} -- 173
end -- 153
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 178
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 179
	local tilt = opts.tiltDeg * math.pi / 180 -- 180
	local az = (opts.azDeg ~= nil and opts.azDeg or 0) * math.pi / 180 -- 181
	local shift = distance * math.tan(opts.fovYDeg * math.pi / 360) * (opts.screenBiasY ~= nil and opts.screenBiasY or 0) -- 182
	local sx = -math.sin(az) * math.sin(tilt) * shift -- 183
	local sy = math.cos(tilt) * shift -- 184
	local sz = -math.cos(az) * math.sin(tilt) * shift -- 185
	return { -- 186
		target = Vec3(targetWorld.x - sx, targetWorld.y - sy, targetWorld.z - sz), -- 187
		eye = Vec3( -- 188
			targetWorld.x + math.sin(az) * math.cos(tilt) * distance - sx, -- 189
			targetWorld.y + math.sin(tilt) * distance - sy, -- 190
			targetWorld.z + math.cos(az) * math.cos(tilt) * distance - sz -- 191
		) -- 191
	} -- 191
end -- 178
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 206
	local frame = frameAt(centerX, centerY, distance, opts) -- 216
	local view = { -- 217
		eye = frame.eye, -- 218
		target = frame.target, -- 219
		up = {x = 0, y = 1, z = 0}, -- 220
		fovYDeg = opts.fovYDeg, -- 221
		aspect = opts.aspect, -- 222
		viewW = 2, -- 223
		viewH = 2 -- 224
	} -- 224
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 226
	local limit = 1 - opts.margin -- 227
	local minY = opts.screenMinY ~= nil and opts.screenMinY or -limit -- 228
	local maxY = opts.screenMaxY ~= nil and opts.screenMaxY or limit -- 229
	do -- 229
		local i = 0 -- 231
		while i < #points do -- 231
			local p = projectPrepared( -- 232
				planeToWorld(points[i + 1], 0), -- 232
				basis -- 232
			) -- 232
			if p == nil then -- 232
				return false -- 233
			end -- 233
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 234
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 235
			local rx = ry / opts.aspect -- 236
			if math.abs(p.x) + rx > limit then -- 236
				return false -- 237
			end -- 237
			if p.y - ry < minY or p.y + ry > maxY then -- 237
				return false -- 238
			end -- 238
			i = i + 1 -- 231
		end -- 231
	end -- 231
	return true -- 240
end -- 206
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 249
	local lo = opts.minDistance -- 257
	local hi = opts.maxDistance -- 258
	if frameFits( -- 258
		points, -- 259
		centerX, -- 259
		centerY, -- 259
		lo, -- 259
		probeRadius, -- 259
		opts, -- 259
		radii -- 259
	) then -- 259
		return lo -- 259
	end -- 259
	if not frameFits( -- 259
		points, -- 260
		centerX, -- 260
		centerY, -- 260
		hi, -- 260
		probeRadius, -- 260
		opts, -- 260
		radii -- 260
	) then -- 260
		return hi -- 260
	end -- 260
	local a = lo -- 262
	local b = hi -- 263
	do -- 263
		local i = 0 -- 264
		while i < 24 do -- 264
			local mid = (a + b) / 2 -- 265
			if frameFits( -- 265
				points, -- 266
				centerX, -- 266
				centerY, -- 266
				mid, -- 266
				probeRadius, -- 266
				opts, -- 266
				radii -- 266
			) then -- 266
				b = mid -- 266
			else -- 266
				a = mid -- 266
			end -- 266
			i = i + 1 -- 264
		end -- 264
	end -- 264
	return b -- 268
end -- 249
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 276
	local fit = ____exports.computeFit(points) -- 284
	local radius = probeRadius ~= nil and probeRadius or 0 -- 285
	local wantDistance = fitDistance( -- 287
		points, -- 287
		fit.centerX, -- 287
		fit.centerY, -- 287
		radius, -- 287
		opts, -- 287
		radii -- 287
	) -- 287
	if not state.initialized then -- 287
		state.focusX = fit.centerX -- 291
		state.focusY = fit.centerY -- 292
		state.distance = wantDistance -- 293
		state.initialized = true -- 294
	else -- 294
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 296
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 297
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 298
		state.distance = state.distance + (wantDistance - state.distance) * k -- 299
	end -- 299
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 303
end -- 276
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 307
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 308
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 309
	return { -- 311
		step = function(points, probeRadius, radii, minDistance, shot) -- 312
			local opts = options -- 315
			if shot ~= nil or minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 315
				opts = { -- 317
					azDeg = shot ~= nil and shot.azDeg or options.azDeg, -- 318
					screenMinY = options.screenMinY, -- 319
					screenMaxY = options.screenMaxY, -- 319
					screenBiasY = options.screenBiasY, -- 319
					tiltDeg = shot ~= nil and math.max( -- 320
						CameraTiltMin, -- 320
						math.min(CameraTiltMax, shot.tiltDeg) -- 320
					) or options.tiltDeg, -- 320
					minDistance = minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance and minDistance or options.minDistance, -- 321
					maxDistance = options.maxDistance, -- 322
					lerp = shot ~= nil and shot.lerp or options.lerp, -- 323
					fovYDeg = options.fovYDeg, -- 324
					aspect = options.aspect, -- 325
					margin = options.margin -- 326
				} -- 326
			end -- 326
			return ____exports.computeRigStep( -- 329
				state, -- 329
				points, -- 329
				opts, -- 329
				probeRadius, -- 329
				radii -- 329
			) -- 329
		end, -- 312
		distanceBounds = function() return {min = options.minDistance, max = options.maxDistance} end, -- 332
		wantDistance = function(points, probeRadius, radii) -- 333
			local fit = ____exports.computeFit(points) -- 334
			return fitDistance( -- 335
				points, -- 335
				fit.centerX, -- 335
				fit.centerY, -- 335
				probeRadius ~= nil and probeRadius or 0, -- 335
				options, -- 335
				radii -- 335
			) -- 335
		end, -- 333
		apply = function(camera, frame) -- 337
			camera:lookAt( -- 338
				frame.eye, -- 338
				frame.target, -- 338
				Vec3(0, 1, 0) -- 338
			) -- 338
		end, -- 337
		reset = function() -- 340
			state.focusX = 0 -- 341
			state.focusY = 0 -- 342
			state.distance = options.minDistance -- 343
			state.initialized = false -- 344
		end -- 340
	} -- 340
end -- 307
return ____exports -- 307
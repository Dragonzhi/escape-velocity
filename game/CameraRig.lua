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
function ____exports.computeFit(points) -- 152
	if #points == 0 then -- 152
		return {centerX = 0, centerY = 0, extent = 0} -- 153
	end -- 153
	local minX = points[1].x -- 155
	local maxX = points[1].x -- 156
	local minY = points[1].y -- 157
	local maxY = points[1].y -- 158
	do -- 158
		local i = 1 -- 159
		while i < #points do -- 159
			local p = points[i + 1] -- 160
			if p.x < minX then -- 160
				minX = p.x -- 161
			end -- 161
			if p.x > maxX then -- 161
				maxX = p.x -- 162
			end -- 162
			if p.y < minY then -- 162
				minY = p.y -- 163
			end -- 163
			if p.y > maxY then -- 163
				maxY = p.y -- 164
			end -- 164
			i = i + 1 -- 159
		end -- 159
	end -- 159
	local hw = (maxX - minX) / 2 -- 167
	local hh = (maxY - minY) / 2 -- 168
	return { -- 169
		centerX = (minX + maxX) / 2, -- 170
		centerY = (minY + maxY) / 2, -- 171
		extent = math.sqrt(hw * hw + hh * hh) -- 172
	} -- 172
end -- 152
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 177
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 178
	local tilt = opts.tiltDeg * math.pi / 180 -- 179
	local az = (opts.azDeg ~= nil and opts.azDeg or 0) * math.pi / 180 -- 180
	local shift = distance * math.tan(opts.fovYDeg * math.pi / 360) * (opts.screenBiasY ~= nil and opts.screenBiasY or 0) -- 181
	local sx = -math.sin(az) * math.sin(tilt) * shift -- 182
	local sy = math.cos(tilt) * shift -- 183
	local sz = -math.cos(az) * math.sin(tilt) * shift -- 184
	return { -- 185
		target = Vec3(targetWorld.x - sx, targetWorld.y - sy, targetWorld.z - sz), -- 186
		eye = Vec3( -- 187
			targetWorld.x + math.sin(az) * math.cos(tilt) * distance - sx, -- 188
			targetWorld.y + math.sin(tilt) * distance - sy, -- 189
			targetWorld.z + math.cos(az) * math.cos(tilt) * distance - sz -- 190
		) -- 190
	} -- 190
end -- 177
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 205
	local frame = frameAt(centerX, centerY, distance, opts) -- 215
	local view = { -- 216
		eye = frame.eye, -- 217
		target = frame.target, -- 218
		up = {x = 0, y = 1, z = 0}, -- 219
		fovYDeg = opts.fovYDeg, -- 220
		aspect = opts.aspect, -- 221
		viewW = 2, -- 222
		viewH = 2 -- 223
	} -- 223
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 225
	local limit = 1 - opts.margin -- 226
	local minY = opts.screenMinY ~= nil and opts.screenMinY or -limit -- 227
	local maxY = opts.screenMaxY ~= nil and opts.screenMaxY or limit -- 228
	do -- 228
		local i = 0 -- 230
		while i < #points do -- 230
			local p = projectPrepared( -- 231
				planeToWorld(points[i + 1], 0), -- 231
				basis -- 231
			) -- 231
			if p == nil then -- 231
				return false -- 232
			end -- 232
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 233
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 234
			local rx = ry / opts.aspect -- 235
			if math.abs(p.x) + rx > limit then -- 235
				return false -- 236
			end -- 236
			if p.y - ry < minY or p.y + ry > maxY then -- 236
				return false -- 237
			end -- 237
			i = i + 1 -- 230
		end -- 230
	end -- 230
	return true -- 239
end -- 205
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 248
	local lo = opts.minDistance -- 256
	local hi = opts.maxDistance -- 257
	if frameFits( -- 257
		points, -- 258
		centerX, -- 258
		centerY, -- 258
		lo, -- 258
		probeRadius, -- 258
		opts, -- 258
		radii -- 258
	) then -- 258
		return lo -- 258
	end -- 258
	if not frameFits( -- 258
		points, -- 259
		centerX, -- 259
		centerY, -- 259
		hi, -- 259
		probeRadius, -- 259
		opts, -- 259
		radii -- 259
	) then -- 259
		return hi -- 259
	end -- 259
	local a = lo -- 261
	local b = hi -- 262
	do -- 262
		local i = 0 -- 263
		while i < 24 do -- 263
			local mid = (a + b) / 2 -- 264
			if frameFits( -- 264
				points, -- 265
				centerX, -- 265
				centerY, -- 265
				mid, -- 265
				probeRadius, -- 265
				opts, -- 265
				radii -- 265
			) then -- 265
				b = mid -- 265
			else -- 265
				a = mid -- 265
			end -- 265
			i = i + 1 -- 263
		end -- 263
	end -- 263
	return b -- 267
end -- 248
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 275
	local fit = ____exports.computeFit(points) -- 283
	local radius = probeRadius ~= nil and probeRadius or 0 -- 284
	local wantDistance = fitDistance( -- 286
		points, -- 286
		fit.centerX, -- 286
		fit.centerY, -- 286
		radius, -- 286
		opts, -- 286
		radii -- 286
	) -- 286
	if not state.initialized then -- 286
		state.focusX = fit.centerX -- 290
		state.focusY = fit.centerY -- 291
		state.distance = wantDistance -- 292
		state.initialized = true -- 293
	else -- 293
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 295
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 296
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 297
		state.distance = state.distance + (wantDistance - state.distance) * k -- 298
	end -- 298
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 302
end -- 275
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 306
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 307
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 308
	return { -- 310
		step = function(points, probeRadius, radii, minDistance, shot) -- 311
			local opts = options -- 314
			if shot ~= nil or minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 314
				opts = { -- 316
					azDeg = shot ~= nil and shot.azDeg or options.azDeg, -- 317
					screenMinY = options.screenMinY, -- 318
					screenMaxY = options.screenMaxY, -- 318
					screenBiasY = options.screenBiasY, -- 318
					tiltDeg = shot ~= nil and math.max( -- 319
						CameraTiltMin, -- 319
						math.min(CameraTiltMax, shot.tiltDeg) -- 319
					) or options.tiltDeg, -- 319
					minDistance = minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance and minDistance or options.minDistance, -- 320
					maxDistance = options.maxDistance, -- 321
					lerp = shot ~= nil and shot.lerp or options.lerp, -- 322
					fovYDeg = options.fovYDeg, -- 323
					aspect = options.aspect, -- 324
					margin = options.margin -- 325
				} -- 325
			end -- 325
			return ____exports.computeRigStep( -- 328
				state, -- 328
				points, -- 328
				opts, -- 328
				probeRadius, -- 328
				radii -- 328
			) -- 328
		end, -- 311
		wantDistance = function(points, probeRadius, radii) -- 331
			local fit = ____exports.computeFit(points) -- 332
			return fitDistance( -- 333
				points, -- 333
				fit.centerX, -- 333
				fit.centerY, -- 333
				probeRadius ~= nil and probeRadius or 0, -- 333
				options, -- 333
				radii -- 333
			) -- 333
		end, -- 331
		apply = function(camera, frame) -- 335
			camera:lookAt( -- 336
				frame.eye, -- 336
				frame.target, -- 336
				Vec3(0, 1, 0) -- 336
			) -- 336
		end, -- 335
		reset = function() -- 338
			state.focusX = 0 -- 339
			state.focusY = 0 -- 340
			state.distance = options.minDistance -- 341
			state.initialized = false -- 342
		end -- 338
	} -- 338
end -- 306
return ____exports -- 306
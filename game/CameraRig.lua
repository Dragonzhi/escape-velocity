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
function ____exports.defaultRigOptions(fovYDeg, aspect, minDistance, maxDistance, tiltDeg) -- 51
	return { -- 52
		tiltDeg = tiltDeg ~= nil and tiltDeg >= CameraTiltMin and tiltDeg <= CameraTiltMax and tiltDeg or CameraTiltDefault, -- 56
		minDistance = minDistance ~= nil and minDistance > 0 and minDistance or CameraMinDistance, -- 59
		maxDistance = maxDistance ~= nil and maxDistance > 0 and maxDistance or CameraMaxDistance, -- 60
		lerp = CameraLerp, -- 61
		fovYDeg = fovYDeg ~= nil and fovYDeg or 45, -- 62
		aspect = aspect ~= nil and aspect > 0 and aspect or 1, -- 63
		margin = 0.05 -- 64
	} -- 64
end -- 51
--- 计算所有关键点的包围盒中心与半对角。
-- 
-- 关键点通常包含：探测器、所有行星、目标点。
-- 半对角随“探测器飞离场景中心”单调增长 → 相机单调拉远。
function ____exports.computeFit(points) -- 139
	if #points == 0 then -- 139
		return {centerX = 0, centerY = 0, extent = 0} -- 140
	end -- 140
	local minX = points[1].x -- 142
	local maxX = points[1].x -- 143
	local minY = points[1].y -- 144
	local maxY = points[1].y -- 145
	do -- 145
		local i = 1 -- 146
		while i < #points do -- 146
			local p = points[i + 1] -- 147
			if p.x < minX then -- 147
				minX = p.x -- 148
			end -- 148
			if p.x > maxX then -- 148
				maxX = p.x -- 149
			end -- 149
			if p.y < minY then -- 149
				minY = p.y -- 150
			end -- 150
			if p.y > maxY then -- 150
				maxY = p.y -- 151
			end -- 151
			i = i + 1 -- 146
		end -- 146
	end -- 146
	local hw = (maxX - minX) / 2 -- 154
	local hh = (maxY - minY) / 2 -- 155
	return { -- 156
		centerX = (minX + maxX) / 2, -- 157
		centerY = (minY + maxY) / 2, -- 158
		extent = math.sqrt(hw * hw + hh * hh) -- 159
	} -- 159
end -- 139
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 164
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 165
	local tilt = opts.tiltDeg * math.pi / 180 -- 166
	return { -- 167
		target = targetWorld, -- 168
		eye = Vec3( -- 169
			targetWorld.x, -- 170
			targetWorld.y + math.sin(tilt) * distance, -- 171
			targetWorld.z + math.cos(tilt) * distance -- 172
		) -- 172
	} -- 172
end -- 164
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 187
	local frame = frameAt(centerX, centerY, distance, opts) -- 197
	local view = { -- 198
		eye = frame.eye, -- 199
		target = frame.target, -- 200
		up = {x = 0, y = 1, z = 0}, -- 201
		fovYDeg = opts.fovYDeg, -- 202
		aspect = opts.aspect, -- 203
		viewW = 2, -- 204
		viewH = 2 -- 205
	} -- 205
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 207
	local limit = 1 - opts.margin -- 208
	do -- 208
		local i = 0 -- 210
		while i < #points do -- 210
			local p = projectPrepared( -- 211
				planeToWorld(points[i + 1], 0), -- 211
				basis -- 211
			) -- 211
			if p == nil then -- 211
				return false -- 212
			end -- 212
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 213
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 214
			local rx = ry / opts.aspect -- 215
			if math.abs(p.x) + rx > limit then -- 215
				return false -- 216
			end -- 216
			if math.abs(p.y) + ry > limit then -- 216
				return false -- 217
			end -- 217
			i = i + 1 -- 210
		end -- 210
	end -- 210
	return true -- 219
end -- 187
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 228
	local lo = opts.minDistance -- 236
	local hi = opts.maxDistance -- 237
	if frameFits( -- 237
		points, -- 238
		centerX, -- 238
		centerY, -- 238
		lo, -- 238
		probeRadius, -- 238
		opts, -- 238
		radii -- 238
	) then -- 238
		return lo -- 238
	end -- 238
	if not frameFits( -- 238
		points, -- 239
		centerX, -- 239
		centerY, -- 239
		hi, -- 239
		probeRadius, -- 239
		opts, -- 239
		radii -- 239
	) then -- 239
		return hi -- 239
	end -- 239
	local a = lo -- 241
	local b = hi -- 242
	do -- 242
		local i = 0 -- 243
		while i < 24 do -- 243
			local mid = (a + b) / 2 -- 244
			if frameFits( -- 244
				points, -- 245
				centerX, -- 245
				centerY, -- 245
				mid, -- 245
				probeRadius, -- 245
				opts, -- 245
				radii -- 245
			) then -- 245
				b = mid -- 245
			else -- 245
				a = mid -- 245
			end -- 245
			i = i + 1 -- 243
		end -- 243
	end -- 243
	return b -- 247
end -- 228
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 255
	local fit = ____exports.computeFit(points) -- 263
	local radius = probeRadius ~= nil and probeRadius or 0 -- 264
	local wantDistance = fitDistance( -- 266
		points, -- 266
		fit.centerX, -- 266
		fit.centerY, -- 266
		radius, -- 266
		opts, -- 266
		radii -- 266
	) -- 266
	if not state.initialized then -- 266
		state.focusX = fit.centerX -- 270
		state.focusY = fit.centerY -- 271
		state.distance = wantDistance -- 272
		state.initialized = true -- 273
	else -- 273
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 275
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 276
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 277
		state.distance = state.distance + (wantDistance - state.distance) * k -- 278
	end -- 278
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 282
end -- 255
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 286
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 287
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 288
	return { -- 290
		step = function(points, probeRadius, radii, minDistance) -- 291
			local opts = options -- 294
			if minDistance ~= nil and minDistance > 0 and minDistance < options.minDistance then -- 294
				opts = { -- 296
					tiltDeg = options.tiltDeg, -- 297
					minDistance = minDistance, -- 298
					maxDistance = options.maxDistance, -- 299
					lerp = options.lerp, -- 300
					fovYDeg = options.fovYDeg, -- 301
					aspect = options.aspect, -- 302
					margin = options.margin -- 303
				} -- 303
			end -- 303
			return ____exports.computeRigStep( -- 306
				state, -- 306
				points, -- 306
				opts, -- 306
				probeRadius, -- 306
				radii -- 306
			) -- 306
		end, -- 291
		wantDistance = function(points, probeRadius, radii) -- 309
			local fit = ____exports.computeFit(points) -- 310
			return fitDistance( -- 311
				points, -- 311
				fit.centerX, -- 311
				fit.centerY, -- 311
				probeRadius ~= nil and probeRadius or 0, -- 311
				options, -- 311
				radii -- 311
			) -- 311
		end, -- 309
		apply = function(camera, frame) -- 313
			camera:lookAt( -- 314
				frame.eye, -- 314
				frame.target, -- 314
				Vec3(0, 1, 0) -- 314
			) -- 314
		end, -- 313
		reset = function() -- 316
			state.focusX = 0 -- 317
			state.focusY = 0 -- 318
			state.distance = options.minDistance -- 319
			state.initialized = false -- 320
		end -- 316
	} -- 316
end -- 286
return ____exports -- 286
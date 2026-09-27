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
function ____exports.computeFit(points) -- 121
	if #points == 0 then -- 121
		return {centerX = 0, centerY = 0, extent = 0} -- 122
	end -- 122
	local minX = points[1].x -- 124
	local maxX = points[1].x -- 125
	local minY = points[1].y -- 126
	local maxY = points[1].y -- 127
	do -- 127
		local i = 1 -- 128
		while i < #points do -- 128
			local p = points[i + 1] -- 129
			if p.x < minX then -- 129
				minX = p.x -- 130
			end -- 130
			if p.x > maxX then -- 130
				maxX = p.x -- 131
			end -- 131
			if p.y < minY then -- 131
				minY = p.y -- 132
			end -- 132
			if p.y > maxY then -- 132
				maxY = p.y -- 133
			end -- 133
			i = i + 1 -- 128
		end -- 128
	end -- 128
	local hw = (maxX - minX) / 2 -- 136
	local hh = (maxY - minY) / 2 -- 137
	return { -- 138
		centerX = (minX + maxX) / 2, -- 139
		centerY = (minY + maxY) / 2, -- 140
		extent = math.sqrt(hw * hw + hh * hh) -- 141
	} -- 141
end -- 121
--- 由注视点（平面坐标）与距离构造一帧相机参数（纯计算，不碰引擎相机对象）。
local function frameAt(centerX, centerY, distance, opts) -- 146
	local targetWorld = planeToWorld({x = centerX, y = centerY}, 0) -- 147
	local tilt = opts.tiltDeg * math.pi / 180 -- 148
	return { -- 149
		target = targetWorld, -- 150
		eye = Vec3( -- 151
			targetWorld.x, -- 152
			targetWorld.y + math.sin(tilt) * distance, -- 153
			targetWorld.z + math.cos(tilt) * distance -- 154
		) -- 154
	} -- 154
end -- 146
--- 这一组关键点在给定距离下，是否**全部**落在“画面内缩 margin”的安全区内。
-- 
-- 投影走 game/Projection.ts（与渲染、预测线同一套已标定公式）。
-- 把 viewW/viewH 取 2 ⇒ `projectPrepared` 的返回值就是 NDC（±1 = 画面边缘），
-- 于是安全区就是 ±(1 - margin)。
-- 
-- @param probeRadius points[0]（探测器）的模型外接半径（世界单位）；它是**有体积**的，
-- 只约束中心点会让碟形天线被边缘切掉。屏幕上多占的 NDC ≈ (r / 深度) × focal。
local function frameFits(points, centerX, centerY, distance, probeRadius, opts, radii) -- 169
	local frame = frameAt(centerX, centerY, distance, opts) -- 179
	local view = { -- 180
		eye = frame.eye, -- 181
		target = frame.target, -- 182
		up = {x = 0, y = 1, z = 0}, -- 183
		fovYDeg = opts.fovYDeg, -- 184
		aspect = opts.aspect, -- 185
		viewW = 2, -- 186
		viewH = 2 -- 187
	} -- 187
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 189
	local limit = 1 - opts.margin -- 190
	do -- 190
		local i = 0 -- 192
		while i < #points do -- 192
			local p = projectPrepared( -- 193
				planeToWorld(points[i + 1], 0), -- 193
				basis -- 193
			) -- 193
			if p == nil then -- 193
				return false -- 194
			end -- 194
			local r = radii ~= nil and radii[i + 1] ~= nil and radii[i + 1] or (i == 0 and probeRadius or 0) -- 195
			local ry = r > 0 and r / p.vz * basis.focal or 0 -- 196
			local rx = ry / opts.aspect -- 197
			if math.abs(p.x) + rx > limit then -- 197
				return false -- 198
			end -- 198
			if math.abs(p.y) + ry > limit then -- 198
				return false -- 199
			end -- 199
			i = i + 1 -- 192
		end -- 192
	end -- 192
	return true -- 201
end -- 169
--- 把所有关键点塞进画面所需的最小相机距离。
-- 
-- 距离越大画面越广 ⇒ 约束单调，可以二分；每一步只在“确实装得下”时收紧上界，
-- 所以返回值**一定**满足约束（两个端点都装不下时退化为 maxDistance）。
local function fitDistance(points, centerX, centerY, probeRadius, opts, radii) -- 210
	local lo = opts.minDistance -- 218
	local hi = opts.maxDistance -- 219
	if frameFits( -- 219
		points, -- 220
		centerX, -- 220
		centerY, -- 220
		lo, -- 220
		probeRadius, -- 220
		opts, -- 220
		radii -- 220
	) then -- 220
		return lo -- 220
	end -- 220
	if not frameFits( -- 220
		points, -- 221
		centerX, -- 221
		centerY, -- 221
		hi, -- 221
		probeRadius, -- 221
		opts, -- 221
		radii -- 221
	) then -- 221
		return hi -- 221
	end -- 221
	local a = lo -- 223
	local b = hi -- 224
	do -- 224
		local i = 0 -- 225
		while i < 24 do -- 225
			local mid = (a + b) / 2 -- 226
			if frameFits( -- 226
				points, -- 227
				centerX, -- 227
				centerY, -- 227
				mid, -- 227
				probeRadius, -- 227
				opts, -- 227
				radii -- 227
			) then -- 227
				b = mid -- 227
			else -- 227
				a = mid -- 227
			end -- 227
			i = i + 1 -- 225
		end -- 225
	end -- 225
	return b -- 229
end -- 210
--- 纯计算：根据关键点集合，算出这一帧的相机参数。
-- 
-- `points` 中应包含探测器、行星与目标；**约定 points[0] = 探测器**（`probeRadius` 只作用于它）。
function ____exports.computeRigStep(state, points, opts, probeRadius, radii) -- 237
	local fit = ____exports.computeFit(points) -- 245
	local radius = probeRadius ~= nil and probeRadius or 0 -- 246
	local wantDistance = fitDistance( -- 248
		points, -- 248
		fit.centerX, -- 248
		fit.centerY, -- 248
		radius, -- 248
		opts, -- 248
		radii -- 248
	) -- 248
	if not state.initialized then -- 248
		state.focusX = fit.centerX -- 252
		state.focusY = fit.centerY -- 253
		state.distance = wantDistance -- 254
		state.initialized = true -- 255
	else -- 255
		local k = opts.lerp < 0 and 0 or (opts.lerp > 1 and 1 or opts.lerp) -- 257
		state.focusX = state.focusX + (fit.centerX - state.focusX) * k -- 258
		state.focusY = state.focusY + (fit.centerY - state.focusY) * k -- 259
		state.distance = state.distance + (wantDistance - state.distance) * k -- 260
	end -- 260
	return frameAt(state.focusX, state.focusY, state.distance, opts) -- 264
end -- 237
--- 创建一个机架（持有平滑状态）。
function ____exports.createCameraRig(opts) -- 268
	local options = opts ~= nil and opts or ____exports.defaultRigOptions() -- 269
	local state = {focusX = 0, focusY = 0, distance = options.minDistance, initialized = false} -- 270
	return { -- 272
		step = function(points, probeRadius, radii) -- 273
			return ____exports.computeRigStep( -- 274
				state, -- 274
				points, -- 274
				options, -- 274
				probeRadius, -- 274
				radii -- 274
			) -- 274
		end, -- 273
		wantDistance = function(points, probeRadius, radii) -- 277
			local fit = ____exports.computeFit(points) -- 278
			return fitDistance( -- 279
				points, -- 279
				fit.centerX, -- 279
				fit.centerY, -- 279
				probeRadius ~= nil and probeRadius or 0, -- 279
				options, -- 279
				radii -- 279
			) -- 279
		end, -- 277
		apply = function(camera, frame) -- 281
			camera:lookAt( -- 282
				frame.eye, -- 282
				frame.target, -- 282
				Vec3(0, 1, 0) -- 282
			) -- 282
		end -- 281
	} -- 281
end -- 268
return ____exports -- 268
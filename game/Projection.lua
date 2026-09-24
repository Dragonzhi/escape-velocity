-- [ts]: Projection.ts
local ____exports = {} -- 1
local sub, cross, length, normalize -- 1
function sub(a, b) -- 174
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} -- 175
end -- 175
function cross(a, b) -- 178
	return {x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x} -- 179
end -- 179
function length(a) -- 190
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) -- 191
end -- 191
function normalize(a) -- 194
	local l = length(a) -- 195
	if l < 1e-9 then -- 195
		return {x = 0, y = 0, z = 0} -- 196
	end -- 196
	return {x = a.x / l, y = a.y / l, z = a.z / l} -- 197
end -- 197
--- 已实测确认的默认约定，业务代码直接用这两个常量。
____exports.HANDEDNESS = 1 -- 26
____exports.FLIP_Y = false -- 27
--- 用预计算的基把屏幕偏移量（与 project() 同空间）反投影成世界射线方向。
function ____exports.unprojectDirectionPrepared(screen, b) -- 30
	local ndcX = screen.x * 2 / b.viewW -- 31
	local ndcY = (b.flipY and -screen.y or screen.y) * 2 / b.viewH -- 32
	local vx = ndcX * b.aspect / b.focal -- 34
	local vy = ndcY / b.focal -- 35
	return normalize({x = b.forward.x + vx * b.right.x + vy * b.up.x, y = b.forward.y + vx * b.right.y + vy * b.up.y, z = b.forward.z + vx * b.right.z + vy * b.up.z}) -- 37
end -- 30
--- 把屏幕偏移量（与 project() 同空间）反投影到世界 y = planeY 平面上。
-- 
-- 用于“玩家拖到哪里” → “平面上的哪个点”。
-- 射线与平面平行、或交点在相机后方时返回 undefined。
function ____exports.screenToPlaneY(screen, b, planeY) -- 50
	local dir = ____exports.unprojectDirectionPrepared(screen, b) -- 55
	if math.abs(dir.y) < 1e-9 then -- 55
		return nil -- 56
	end -- 56
	local t = (planeY - b.eye.y) / dir.y -- 59
	if t <= 0.000001 then -- 59
		return nil -- 60
	end -- 60
	return {x = b.eye.x + t * dir.x, y = planeY, z = b.eye.z + t * dir.z} -- 62
end -- 50
--- 把 project() 的输出转成 Dora 2D 覆盖层坐标（中心原点、+Y 向上）。
-- 
-- project() 输出 +Y 向下（图像坐标），而 Director.ui 等 2D 节点是
-- 中心原点 +Y 向上，所以这里只需翻转 y。
function ____exports.toOverlay(p) -- 75
	return {x = p.x, y = -p.y} -- 76
end -- 75
--- 预计算相机基（每帧调一次）。
function ____exports.prepareCamera(cam, handedness, flipY) -- 100
	local f = normalize(sub(cam.target, cam.eye)) -- 105
	local up = normalize(cam.up) -- 106
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 107
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 108
	return { -- 110
		eye = {x = cam.eye.x, y = cam.eye.y, z = cam.eye.z}, -- 111
		forward = f, -- 112
		right = r, -- 113
		up = u, -- 114
		focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2), -- 115
		aspect = cam.aspect, -- 116
		viewW = cam.viewW, -- 117
		viewH = cam.viewH, -- 118
		flipY = flipY -- 119
	} -- 119
end -- 100
--- 用预计算的基投影一个点。语义与 `project()` 一致。
function ____exports.projectPrepared(p, b) -- 124
	local dx = p.x - b.eye.x -- 125
	local dy = p.y - b.eye.y -- 126
	local dz = p.z - b.eye.z -- 127
	local vz = dx * b.forward.x + dy * b.forward.y + dz * b.forward.z -- 129
	if vz <= 0.000001 then -- 129
		return nil -- 130
	end -- 130
	local vx = dx * b.right.x + dy * b.right.y + dz * b.right.z -- 132
	local vy = dx * b.up.x + dy * b.up.y + dz * b.up.z -- 133
	local ndcX = vx / vz * b.focal / b.aspect -- 135
	local ndcY = vy / vz * b.focal -- 136
	return {x = ndcX * b.viewW / 2, y = (b.flipY and -ndcY or ndcY) * b.viewH / 2, vz = vz} -- 138
end -- 124
local function dot(a, b) -- 186
	return a.x * b.x + a.y * b.y + a.z * b.z -- 187
end -- 186
--- 两向量叉积的模长（并行度度量，用于一致性校验）。
function ____exports.crossLength(a, b) -- 201
	return length(cross(a, b)) -- 202
end -- 201
function ____exports.dotProduct(a, b) -- 205
	return dot(a, b) -- 206
end -- 205
function ____exports.vecLength(a) -- 209
	return length(a) -- 210
end -- 209
--- 把世界坐标点投影到屏幕视图坐标。
-- 
-- 默认调用参数用 `HANDEDNESS` / `FLIP_Y`（已实测标定）。
-- 输出语义见文件头：viewPoint = view 中心 + 本返回值，+Y 向下。
-- 
-- @returns 投影结果；点在相机后方（或太近）时返回 undefined。
function ____exports.project(p, cam, handedness, flipY) -- 221
	local f = normalize(sub(cam.target, cam.eye)) -- 227
	local up = normalize(cam.up) -- 228
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 230
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 231
	local d = sub(p, cam.eye) -- 233
	local vz = dot(d, f) -- 234
	if vz <= 0.000001 then -- 234
		return nil -- 235
	end -- 235
	local vx = dot(d, r) -- 237
	local vy = dot(d, u) -- 238
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 241
	local ndcX = vx / vz * focal / cam.aspect -- 242
	local ndcY = vy / vz * focal -- 243
	return {x = ndcX * cam.viewW / 2, y = (flipY and -ndcY or ndcY) * cam.viewH / 2, vz = vz} -- 245
end -- 221
--- 把一个屏幕视图坐标点（中心原点，+Y 向上）反投影成世界坐标射线。
-- 用于自测：应该与 View3D.getRayOrigin/getRayDirection 一致。
function ____exports.unprojectDirection(screen, cam, handedness, flipY) -- 256
	local f = normalize(sub(cam.target, cam.eye)) -- 262
	local up = normalize(cam.up) -- 263
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 264
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 265
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 267
	local ndcX = screen.x * 2 / cam.viewW -- 268
	local ndcY = (flipY and -screen.y or screen.y) * 2 / cam.viewH -- 269
	local vx = ndcX * cam.aspect / focal * 1 -- 271
	local vy = ndcY / focal * 1 -- 272
	return normalize({x = f.x + vx * r.x + vy * u.x, y = f.y + vx * r.y + vy * u.y, z = f.z + vx * r.z + vy * u.z}) -- 275
end -- 256
return ____exports -- 256
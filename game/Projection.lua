-- [ts]: Projection.ts
local ____exports = {} -- 1
local sub, cross, length, normalize -- 1
function sub(a, b) -- 134
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} -- 135
end -- 135
function cross(a, b) -- 138
	return {x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x} -- 139
end -- 139
function length(a) -- 150
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) -- 151
end -- 151
function normalize(a) -- 154
	local l = length(a) -- 155
	if l < 1e-9 then -- 155
		return {x = 0, y = 0, z = 0} -- 156
	end -- 156
	return {x = a.x / l, y = a.y / l, z = a.z / l} -- 157
end -- 157
--- 已实测确认的默认约定，业务代码直接用这两个常量。
____exports.HANDEDNESS = 1 -- 26
____exports.FLIP_Y = false -- 27
--- 把 project() 的输出转成 Dora 2D 覆盖层坐标（中心原点、+Y 向上）。
-- 
-- project() 输出 +Y 向下（图像坐标），而 Director.ui 等 2D 节点是
-- 中心原点 +Y 向上，所以这里只需翻转 y。
function ____exports.toOverlay(p) -- 35
	return {x = p.x, y = -p.y} -- 36
end -- 35
--- 预计算相机基（每帧调一次）。
function ____exports.prepareCamera(cam, handedness, flipY) -- 60
	local f = normalize(sub(cam.target, cam.eye)) -- 65
	local up = normalize(cam.up) -- 66
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 67
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 68
	return { -- 70
		eye = {x = cam.eye.x, y = cam.eye.y, z = cam.eye.z}, -- 71
		forward = f, -- 72
		right = r, -- 73
		up = u, -- 74
		focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2), -- 75
		aspect = cam.aspect, -- 76
		viewW = cam.viewW, -- 77
		viewH = cam.viewH, -- 78
		flipY = flipY -- 79
	} -- 79
end -- 60
--- 用预计算的基投影一个点。语义与 `project()` 一致。
function ____exports.projectPrepared(p, b) -- 84
	local dx = p.x - b.eye.x -- 85
	local dy = p.y - b.eye.y -- 86
	local dz = p.z - b.eye.z -- 87
	local vz = dx * b.forward.x + dy * b.forward.y + dz * b.forward.z -- 89
	if vz <= 0.000001 then -- 89
		return nil -- 90
	end -- 90
	local vx = dx * b.right.x + dy * b.right.y + dz * b.right.z -- 92
	local vy = dx * b.up.x + dy * b.up.y + dz * b.up.z -- 93
	local ndcX = vx / vz * b.focal / b.aspect -- 95
	local ndcY = vy / vz * b.focal -- 96
	return {x = ndcX * b.viewW / 2, y = (b.flipY and -ndcY or ndcY) * b.viewH / 2, vz = vz} -- 98
end -- 84
local function dot(a, b) -- 146
	return a.x * b.x + a.y * b.y + a.z * b.z -- 147
end -- 146
--- 两向量叉积的模长（并行度度量，用于一致性校验）。
function ____exports.crossLength(a, b) -- 161
	return length(cross(a, b)) -- 162
end -- 161
function ____exports.dotProduct(a, b) -- 165
	return dot(a, b) -- 166
end -- 165
function ____exports.vecLength(a) -- 169
	return length(a) -- 170
end -- 169
--- 把世界坐标点投影到屏幕视图坐标。
-- 
-- 默认调用参数用 `HANDEDNESS` / `FLIP_Y`（已实测标定）。
-- 输出语义见文件头：viewPoint = view 中心 + 本返回值，+Y 向下。
-- 
-- @returns 投影结果；点在相机后方（或太近）时返回 undefined。
function ____exports.project(p, cam, handedness, flipY) -- 181
	local f = normalize(sub(cam.target, cam.eye)) -- 187
	local up = normalize(cam.up) -- 188
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 190
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 191
	local d = sub(p, cam.eye) -- 193
	local vz = dot(d, f) -- 194
	if vz <= 0.000001 then -- 194
		return nil -- 195
	end -- 195
	local vx = dot(d, r) -- 197
	local vy = dot(d, u) -- 198
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 201
	local ndcX = vx / vz * focal / cam.aspect -- 202
	local ndcY = vy / vz * focal -- 203
	return {x = ndcX * cam.viewW / 2, y = (flipY and -ndcY or ndcY) * cam.viewH / 2, vz = vz} -- 205
end -- 181
--- 把一个屏幕视图坐标点（中心原点，+Y 向上）反投影成世界坐标射线。
-- 用于自测：应该与 View3D.getRayOrigin/getRayDirection 一致。
function ____exports.unprojectDirection(screen, cam, handedness, flipY) -- 216
	local f = normalize(sub(cam.target, cam.eye)) -- 222
	local up = normalize(cam.up) -- 223
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 224
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 225
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 227
	local ndcX = screen.x * 2 / cam.viewW -- 228
	local ndcY = (flipY and -screen.y or screen.y) * 2 / cam.viewH -- 229
	local vx = ndcX * cam.aspect / focal * 1 -- 231
	local vy = ndcY / focal * 1 -- 232
	return normalize({x = f.x + vx * r.x + vy * u.x, y = f.y + vx * r.y + vy * u.y, z = f.z + vx * r.z + vy * u.z}) -- 235
end -- 216
return ____exports -- 216
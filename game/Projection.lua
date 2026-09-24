-- [ts]: Projection.ts
local ____exports = {} -- 1
local sub, cross, length, normalize -- 1
function sub(a, b) -- 181
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} -- 182
end -- 182
function cross(a, b) -- 185
	return {x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x} -- 186
end -- 186
function length(a) -- 197
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) -- 198
end -- 198
function normalize(a) -- 201
	local l = length(a) -- 202
	if l < 1e-9 then -- 202
		return {x = 0, y = 0, z = 0} -- 203
	end -- 203
	return {x = a.x / l, y = a.y / l, z = a.z / l} -- 204
end -- 204
--- 已实测确认的默认约定，业务代码直接用这两个常量。
____exports.HANDEDNESS = 1 -- 30
____exports.FLIP_Y = false -- 31
--- 用预计算的基把屏幕偏移量（与 project() 同空间）反投影成世界射线方向。
function ____exports.unprojectDirectionPrepared(screen, b) -- 34
	local ndcX = screen.x * 2 / b.viewW -- 35
	local ndcY = (b.flipY and -screen.y or screen.y) * 2 / b.viewH -- 36
	local vx = ndcX * b.aspect / b.focal -- 38
	local vy = ndcY / b.focal -- 39
	return normalize({x = b.forward.x + vx * b.right.x + vy * b.up.x, y = b.forward.y + vx * b.right.y + vy * b.up.y, z = b.forward.z + vx * b.right.z + vy * b.up.z}) -- 41
end -- 34
--- 把屏幕偏移量（与 project() 同空间）反投影到世界 y = planeY 平面上。
-- 
-- 用于“玩家拖到哪里” → “平面上的哪个点”。
-- 射线与平面平行、或交点在相机后方时返回 undefined。
function ____exports.screenToPlaneY(screen, b, planeY) -- 54
	local dir = ____exports.unprojectDirectionPrepared(screen, b) -- 59
	if math.abs(dir.y) < 1e-9 then -- 59
		return nil -- 60
	end -- 60
	local t = (planeY - b.eye.y) / dir.y -- 63
	if t <= 0.000001 then -- 63
		return nil -- 64
	end -- 64
	return {x = b.eye.x + t * dir.x, y = planeY, z = b.eye.z + t * dir.z} -- 66
end -- 54
--- 把 project() 的输出转成 Dora 2D 覆盖层坐标（中心原点、+Y 向上）。
-- 
-- ⚠️ 修正（S2 阶段实测）：project() 的输出**已经是**中心原点 +Y 向上 ——
-- 与 Dora UI 空间一致，**无需翻转**（恒等变换）。
-- 旧版在这里多翻了一次，导致所有 2D 覆盖层（预测线）垂直镜像于真实渲染。
-- 修正依据：颜色标记球对照（绿=探测器、红=火星、白=注视点标记），
-- 渲染位置与旧 project() 输出恰好关于屏幕中心镜像。
function ____exports.toOverlay(p) -- 82
	return {x = p.x, y = p.y} -- 83
end -- 82
--- 预计算相机基（每帧调一次）。
function ____exports.prepareCamera(cam, handedness, flipY) -- 107
	local f = normalize(sub(cam.target, cam.eye)) -- 112
	local up = normalize(cam.up) -- 113
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 114
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 115
	return { -- 117
		eye = {x = cam.eye.x, y = cam.eye.y, z = cam.eye.z}, -- 118
		forward = f, -- 119
		right = r, -- 120
		up = u, -- 121
		focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2), -- 122
		aspect = cam.aspect, -- 123
		viewW = cam.viewW, -- 124
		viewH = cam.viewH, -- 125
		flipY = flipY -- 126
	} -- 126
end -- 107
--- 用预计算的基投影一个点。语义与 `project()` 一致。
function ____exports.projectPrepared(p, b) -- 131
	local dx = p.x - b.eye.x -- 132
	local dy = p.y - b.eye.y -- 133
	local dz = p.z - b.eye.z -- 134
	local vz = dx * b.forward.x + dy * b.forward.y + dz * b.forward.z -- 136
	if vz <= 0.000001 then -- 136
		return nil -- 137
	end -- 137
	local vx = dx * b.right.x + dy * b.right.y + dz * b.right.z -- 139
	local vy = dx * b.up.x + dy * b.up.y + dz * b.up.z -- 140
	local ndcX = vx / vz * b.focal / b.aspect -- 142
	local ndcY = vy / vz * b.focal -- 143
	return {x = ndcX * b.viewW / 2, y = (b.flipY and -ndcY or ndcY) * b.viewH / 2, vz = vz} -- 145
end -- 131
local function dot(a, b) -- 193
	return a.x * b.x + a.y * b.y + a.z * b.z -- 194
end -- 193
--- 两向量叉积的模长（并行度度量，用于一致性校验）。
function ____exports.crossLength(a, b) -- 208
	return length(cross(a, b)) -- 209
end -- 208
function ____exports.dotProduct(a, b) -- 212
	return dot(a, b) -- 213
end -- 212
function ____exports.vecLength(a) -- 216
	return length(a) -- 217
end -- 216
--- 把世界坐标点投影到屏幕视图坐标。
-- 
-- 默认调用参数用 `HANDEDNESS` / `FLIP_Y`（已实测标定）。
-- 输出语义见文件头：viewPoint = view 中心 + 本返回值，+Y 向下。
-- 
-- @returns 投影结果；点在相机后方（或太近）时返回 undefined。
function ____exports.project(p, cam, handedness, flipY) -- 228
	local f = normalize(sub(cam.target, cam.eye)) -- 234
	local up = normalize(cam.up) -- 235
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 237
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 238
	local d = sub(p, cam.eye) -- 240
	local vz = dot(d, f) -- 241
	if vz <= 0.000001 then -- 241
		return nil -- 242
	end -- 242
	local vx = dot(d, r) -- 244
	local vy = dot(d, u) -- 245
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 248
	local ndcX = vx / vz * focal / cam.aspect -- 249
	local ndcY = vy / vz * focal -- 250
	return {x = ndcX * cam.viewW / 2, y = (flipY and -ndcY or ndcY) * cam.viewH / 2, vz = vz} -- 252
end -- 228
--- 把一个屏幕视图坐标点（中心原点，+Y 向上）反投影成世界坐标射线。
-- 用于自测：应该与 View3D.getRayOrigin/getRayDirection 一致。
function ____exports.unprojectDirection(screen, cam, handedness, flipY) -- 263
	local f = normalize(sub(cam.target, cam.eye)) -- 269
	local up = normalize(cam.up) -- 270
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 271
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 272
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 274
	local ndcX = screen.x * 2 / cam.viewW -- 275
	local ndcY = (flipY and -screen.y or screen.y) * 2 / cam.viewH -- 276
	local vx = ndcX * cam.aspect / focal * 1 -- 278
	local vy = ndcY / focal * 1 -- 279
	return normalize({x = f.x + vx * r.x + vy * u.x, y = f.y + vx * r.y + vy * u.y, z = f.z + vx * r.z + vy * u.z}) -- 282
end -- 263
return ____exports -- 263
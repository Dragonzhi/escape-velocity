-- [ts]: Projection.ts
local ____exports = {} -- 1
--- 已实测确认的默认约定，业务代码直接用这两个常量。
____exports.HANDEDNESS = 1 -- 26
____exports.FLIP_Y = false -- 27
--- 把 project() 的输出转成 Dora 2D 覆盖层坐标（中心原点、+Y 向上）。
function ____exports.toOverlay(p) -- 30
	return {x = p.x, y = -p.y} -- 31
end -- 30
local function sub(a, b) -- 63
	return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} -- 64
end -- 63
local function cross(a, b) -- 67
	return {x = a.y * b.z - a.z * b.y, y = a.z * b.x - a.x * b.z, z = a.x * b.y - a.y * b.x} -- 68
end -- 67
local function dot(a, b) -- 75
	return a.x * b.x + a.y * b.y + a.z * b.z -- 76
end -- 75
local function length(a) -- 79
	return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) -- 80
end -- 79
local function normalize(a) -- 83
	local l = length(a) -- 84
	if l < 1e-9 then -- 84
		return {x = 0, y = 0, z = 0} -- 85
	end -- 85
	return {x = a.x / l, y = a.y / l, z = a.z / l} -- 86
end -- 83
--- 两向量叉积的模长（并行度度量，用于一致性校验）。
function ____exports.crossLength(a, b) -- 90
	return length(cross(a, b)) -- 91
end -- 90
function ____exports.dotProduct(a, b) -- 94
	return dot(a, b) -- 95
end -- 94
function ____exports.vecLength(a) -- 98
	return length(a) -- 99
end -- 98
--- 把世界坐标点投影到屏幕视图坐标。
-- 
-- 默认调用参数用 `HANDEDNESS` / `FLIP_Y`（已实测标定）。
-- 输出语义见文件头：viewPoint = view 中心 + 本返回值，+Y 向下。
-- 
-- @returns 投影结果；点在相机后方（或太近）时返回 undefined。
function ____exports.project(p, cam, handedness, flipY) -- 110
	local f = normalize(sub(cam.target, cam.eye)) -- 116
	local up = normalize(cam.up) -- 117
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 119
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 120
	local d = sub(p, cam.eye) -- 122
	local vz = dot(d, f) -- 123
	if vz <= 0.000001 then -- 123
		return nil -- 124
	end -- 124
	local vx = dot(d, r) -- 126
	local vy = dot(d, u) -- 127
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 130
	local ndcX = vx / vz * focal / cam.aspect -- 131
	local ndcY = vy / vz * focal -- 132
	return {x = ndcX * cam.viewW / 2, y = (flipY and -ndcY or ndcY) * cam.viewH / 2, vz = vz} -- 134
end -- 110
--- 把一个屏幕视图坐标点（中心原点，+Y 向上）反投影成世界坐标射线。
-- 用于自测：应该与 View3D.getRayOrigin/getRayDirection 一致。
function ____exports.unprojectDirection(screen, cam, handedness, flipY) -- 145
	local f = normalize(sub(cam.target, cam.eye)) -- 151
	local up = normalize(cam.up) -- 152
	local r = handedness == 0 and normalize(cross(up, f)) or normalize(cross(f, up)) -- 153
	local u = handedness == 0 and cross(f, r) or cross(r, f) -- 154
	local focal = 1 / math.tan(cam.fovYDeg * math.pi / 180 / 2) -- 156
	local ndcX = screen.x * 2 / cam.viewW -- 157
	local ndcY = (flipY and -screen.y or screen.y) * 2 / cam.viewH -- 158
	local vx = ndcX * cam.aspect / focal * 1 -- 160
	local vy = ndcY / focal * 1 -- 161
	return normalize({x = f.x + vx * r.x + vy * u.x, y = f.y + vx * r.y + vy * u.y, z = f.z + vx * r.z + vy * u.z}) -- 164
end -- 145
return ____exports -- 145
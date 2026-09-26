-- [ts]: CameraRigTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____CameraRig = require("game.CameraRig") -- 7
local createCameraRig = ____CameraRig.createCameraRig -- 7
local computeFit = ____CameraRig.computeFit -- 7
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 7
local ____Config = require("game.Config") -- 8
local PlaneToWorldX = ____Config.PlaneToWorldX -- 8
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 8
local ____Projection = require("game.Projection") -- 10
local FLIP_Y = ____Projection.FLIP_Y -- 10
local HANDEDNESS = ____Projection.HANDEDNESS -- 10
local prepareCamera = ____Projection.prepareCamera -- 10
local projectPrepared = ____Projection.projectPrepared -- 10
local failures = {} -- 17
local checks = 0 -- 18
local function check(name, ok, detail) -- 20
	checks = checks + 1 -- 21
	if not ok then -- 21
		failures[#failures + 1] = {name = name, detail = detail} -- 22
	end -- 22
end -- 20
--- 1) computeFit：包围盒中心与半对角。
local function testFit() -- 26
	local pts = {{x = -10, y = -10}, {x = 10, y = 10}} -- 27
	local f = computeFit(pts) -- 31
	check( -- 32
		"fit-center", -- 32
		math.abs(f.centerX) < 1e-12 and math.abs(f.centerY) < 1e-12, -- 32
		((("center=(" .. tostring(f.centerX)) .. ", ") .. tostring(f.centerY)) .. ")" -- 32
	) -- 32
	check( -- 34
		"fit-extent", -- 34
		math.abs(f.extent - math.sqrt(200)) < 1e-9, -- 34
		"extent=" .. tostring(f.extent) -- 34
	) -- 34
	local empty = computeFit({}) -- 37
	check( -- 38
		"fit-empty", -- 38
		empty.extent == 0 and empty.centerX == 0, -- 38
		"extent=" .. tostring(empty.extent) -- 38
	) -- 38
	local one = computeFit({{x = 3, y = -4}}) -- 41
	check( -- 42
		"fit-single", -- 42
		one.extent == 0 and one.centerX == 3 and one.centerY == -4, -- 42
		"extent=" .. tostring(one.extent) -- 42
	) -- 42
end -- 26
--- 2) 距离单调性：探测器越远，相机距离越大（S1.2 的核心验收点）。
local function testDistanceMonotonic() -- 46
	local opts = defaultRigOptions() -- 47
	local planets = {{x = 0, y = 0}, {x = 0, y = -14}} -- 48
	local rig = createCameraRig(opts) -- 50
	local dists = {} -- 53
	for ____, probeY in ipairs({ -- 54
		14, -- 54
		20, -- 54
		30, -- 54
		50, -- 54
		80, -- 54
		120 -- 54
	}) do -- 54
		local frame = rig.step({{x = 0, y = probeY}, planets[1], planets[2]}) -- 55
		local dx = frame.eye.x - frame.target.x -- 56
		local dy = frame.eye.y - frame.target.y -- 57
		local dz = frame.eye.z - frame.target.z -- 58
		dists[#dists + 1] = math.sqrt(dx * dx + dy * dy + dz * dz) -- 59
	end -- 59
	local monotonic = true -- 65
	do -- 65
		local i = 1 -- 66
		while i < #dists do -- 66
			if dists[i + 1] < dists[i] - 0.001 then -- 66
				monotonic = false -- 68
				break -- 69
			end -- 69
			i = i + 1 -- 66
		end -- 66
	end -- 66
	check( -- 72
		"rig-distance-monotonic", -- 72
		monotonic, -- 72
		"distances=" .. table.concat( -- 72
			__TS__ArrayMap( -- 72
				dists, -- 72
				function(____, d) return __TS__NumberToFixed(d, 1) end -- 72
			), -- 72
			", " -- 72
		) -- 72
	) -- 72
	local grew = dists[#dists] > dists[1] + 1 -- 75
	check( -- 76
		"rig-distance-grows", -- 76
		grew, -- 76
		(("first=" .. __TS__NumberToFixed(dists[1], 1)) .. " last=") .. __TS__NumberToFixed(dists[#dists], 1) -- 76
	) -- 76
end -- 46
--- 6) 取景：关键点（**含探测器的模型半径**）必须全部落在画面内。
-- 
-- 这是 S3.1 的回归点：旧算法「距离 = min + 半对角 × 1.6」是与相机无关的启发式，
-- 竖屏（aspect 0.5638）下 L3 的探测器中心被投到 ndcX = 1.11 —— 整个跑到画面外，
-- 表现为「进关卡看不到自己的飞行器，预测线从画面外射进来」（截图发现）。
local function overflowOf(frame, opts, pts, radius) -- 86
	local view = { -- 87
		eye = frame.eye, -- 88
		target = frame.target, -- 89
		up = {x = 0, y = 1, z = 0}, -- 90
		fovYDeg = opts.fovYDeg, -- 91
		aspect = opts.aspect, -- 92
		viewW = 2, -- 93
		viewH = 2 -- 94
	} -- 94
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 96
	local worst = 0 -- 97
	do -- 97
		local i = 0 -- 98
		while i < #pts do -- 98
			local p = projectPrepared({x = pts[i + 1].x * PlaneToWorldX, y = 0, z = pts[i + 1].y * PlaneToWorldZ}, basis) -- 99
			if p == nil then -- 99
				return 99 -- 103
			end -- 103
			local r = i == 0 and radius or 0 -- 104
			local ry = r / p.vz * basis.focal -- 105
			local rx = ry / opts.aspect -- 106
			local ox = math.abs(p.x) + rx -- 107
			local oy = math.abs(p.y) + ry -- 108
			if ox > worst then -- 108
				worst = ox -- 109
			end -- 109
			if oy > worst then -- 109
				worst = oy -- 110
			end -- 110
			i = i + 1 -- 98
		end -- 98
	end -- 98
	return worst -- 112
end -- 86
local function testFraming() -- 115
	local pts = {{x = 0, y = 18}, {x = 0, y = -2}, {x = -26, y = -26}} -- 117
	local probeRadius = 2.13 -- 119
	local portrait = defaultRigOptions(45, 601 / 1066) -- 121
	local rigP = createCameraRig(portrait) -- 122
	local frameP = rigP.step(pts, probeRadius) -- 123
	local overP = overflowOf(frameP, portrait, pts, probeRadius) -- 124
	local limit = 1 - portrait.margin -- 125
	check( -- 126
		"rig-frame-portrait-fits", -- 126
		overP <= limit + 0.000001, -- 126
		(("max|ndc|=" .. __TS__NumberToFixed(overP, 4)) .. " limit=") .. __TS__NumberToFixed(limit, 2) -- 126
	) -- 126
	check( -- 129
		"rig-frame-probe-inside", -- 129
		overP < 0.99, -- 129
		("max|ndc|=" .. __TS__NumberToFixed(overP, 4)) .. "（旧算法 1.11 = 出画）" -- 129
	) -- 129
	local dx = frameP.eye.x - frameP.target.x -- 132
	local dy = frameP.eye.y - frameP.target.y -- 133
	local dz = frameP.eye.z - frameP.target.z -- 134
	local distP = math.sqrt(dx * dx + dy * dy + dz * dz) -- 135
	check( -- 136
		"rig-frame-portrait-distance", -- 137
		distP >= portrait.minDistance * 0.999 and distP <= portrait.maxDistance * 1.001, -- 138
		((((("dist=" .. __TS__NumberToFixed(distP, 2)) .. " range=[") .. tostring(portrait.minDistance)) .. ", ") .. tostring(portrait.maxDistance)) .. "]" -- 138
	) -- 138
	local landscape = defaultRigOptions(45, 2024 / 1231) -- 143
	local rigL = createCameraRig(landscape) -- 144
	local frameL = rigL.step(pts, probeRadius) -- 145
	local overL = overflowOf(frameL, landscape, pts, probeRadius) -- 146
	check( -- 147
		"rig-frame-landscape-fits", -- 147
		overL <= 1 - landscape.margin + 0.000001, -- 147
		"max|ndc|=" .. __TS__NumberToFixed(overL, 4) -- 147
	) -- 147
	local frameFar = createCameraRig(portrait).step(pts, 8) -- 150
	local fx = frameFar.eye.x - frameFar.target.x -- 151
	local fy = frameFar.eye.y - frameFar.target.y -- 152
	local fz = frameFar.eye.z - frameFar.target.z -- 153
	local distFar = math.sqrt(fx * fx + fy * fy + fz * fz) -- 154
	check( -- 155
		"rig-frame-radius-matters", -- 155
		distFar > distP + 0.5, -- 155
		(("r=2.13 → " .. __TS__NumberToFixed(distP, 2)) .. ", r=8.0 → ") .. __TS__NumberToFixed(distFar, 2) -- 155
	) -- 155
end -- 115
--- 3) 距离夹紧：不超出 [min, max]。
local function testClamp() -- 159
	local opts = defaultRigOptions() -- 160
	local rig = createCameraRig(opts) -- 161
	local far = rig.step({{x = 0, y = 5000}, {x = 0, y = 0}}) -- 164
	local dx = far.eye.x - far.target.x -- 165
	local dy = far.eye.y - far.target.y -- 166
	local dz = far.eye.z - far.target.z -- 167
	local dFar = math.sqrt(dx * dx + dy * dy + dz * dz) -- 168
	check( -- 170
		"rig-clamp-max", -- 170
		dFar <= opts.maxDistance * 1.001, -- 170
		(("distance=" .. tostring(dFar)) .. " max=") .. tostring(opts.maxDistance) -- 170
	) -- 170
	local near = rig.step({{x = 0, y = 0}, {x = 0, y = 0}}) -- 173
	local ex = near.eye.x - near.target.x -- 174
	local ey = near.eye.y - near.target.y -- 175
	local ez = near.eye.z - near.target.z -- 176
	local dNear = math.sqrt(ex * ex + ey * ey + ez * ez) -- 177
	check( -- 178
		"rig-clamp-min", -- 178
		dNear >= opts.minDistance * 0.999, -- 178
		(("distance=" .. tostring(dNear)) .. " min=") .. tostring(opts.minDistance) -- 178
	) -- 178
end -- 159
--- 4) 倾角固定：相机到注视点的方向应始终符合 tilt。
local function testTilt() -- 182
	local opts = defaultRigOptions() -- 183
	local rig = createCameraRig(opts) -- 184
	local frame = rig.step({{x = 5, y = 5}, {x = -5, y = -5}}) -- 185
	local dz = frame.eye.z - frame.target.z -- 187
	local dy = frame.eye.y - frame.target.y -- 188
	local angle = math.atan(dy, dz) * 180 / math.pi -- 189
	check( -- 190
		"rig-tilt", -- 190
		math.abs(angle - opts.tiltDeg) < 0.5, -- 190
		(("angle=" .. __TS__NumberToFixed(angle, 2)) .. " expected=") .. tostring(opts.tiltDeg) -- 190
	) -- 190
	check( -- 191
		"rig-tilt-in-range", -- 191
		opts.tiltDeg >= 20 and opts.tiltDeg <= 60, -- 191
		("tilt=" .. tostring(opts.tiltDeg)) .. "（安全区 20–60）" -- 191
	) -- 191
end -- 182
--- 5) 平滑：lerp 较小时，单帧不会直接跳到目标值。
local function testSmoothing() -- 195
	local opts = defaultRigOptions() -- 196
	opts.lerp = 0.1 -- 197
	local rig = createCameraRig(opts) -- 198
	local a = rig.step({{x = 0, y = 0}}) -- 200
	local b = rig.step({{x = 100, y = 0}}) -- 201
	local moved = math.abs(b.target.x - a.target.x) -- 203
	check( -- 205
		"rig-smoothing-partial", -- 205
		moved > 0.5 and moved < 99, -- 205
		("moved=" .. __TS__NumberToFixed(moved, 2)) .. "（应在 0 与 100 之间）" -- 205
	) -- 205
end -- 195
function ____exports.runTests() -- 208
	testFit() -- 209
	testDistanceMonotonic() -- 210
	testClamp() -- 211
	testTilt() -- 212
	testSmoothing() -- 213
	testFraming() -- 214
	local lines = {} -- 216
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 217
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 218
	local limit = #failures < 12 and #failures or 12 -- 219
	do -- 219
		local i = 0 -- 220
		while i < limit do -- 220
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 221
			i = i + 1 -- 220
		end -- 220
	end -- 220
	return table.concat(lines, "\n") -- 223
end -- 208
return ____exports -- 208
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
	local monotonic = true -- 62
	do -- 62
		local i = 1 -- 63
		while i < #dists do -- 63
			if dists[i + 1] < dists[i] - 1e-9 then -- 63
				monotonic = false -- 65
				break -- 66
			end -- 66
			i = i + 1 -- 63
		end -- 63
	end -- 63
	check( -- 69
		"rig-distance-monotonic", -- 69
		monotonic, -- 69
		"distances=" .. table.concat( -- 69
			__TS__ArrayMap( -- 69
				dists, -- 69
				function(____, d) return __TS__NumberToFixed(d, 1) end -- 69
			), -- 69
			", " -- 69
		) -- 69
	) -- 69
	local grew = dists[#dists] > dists[1] + 1 -- 72
	check( -- 73
		"rig-distance-grows", -- 73
		grew, -- 73
		(("first=" .. __TS__NumberToFixed(dists[1], 1)) .. " last=") .. __TS__NumberToFixed(dists[#dists], 1) -- 73
	) -- 73
end -- 46
--- 6) 取景：关键点（**含探测器的模型半径**）必须全部落在画面内。
-- 
-- 这是 S3.1 的回归点：旧算法「距离 = min + 半对角 × 1.6」是与相机无关的启发式，
-- 竖屏（aspect 0.5638）下 L3 的探测器中心被投到 ndcX = 1.11 —— 整个跑到画面外，
-- 表现为「进关卡看不到自己的飞行器，预测线从画面外射进来」（截图发现）。
local function overflowOf(frame, opts, pts, radius) -- 83
	local view = { -- 84
		eye = frame.eye, -- 85
		target = frame.target, -- 86
		up = {x = 0, y = 1, z = 0}, -- 87
		fovYDeg = opts.fovYDeg, -- 88
		aspect = opts.aspect, -- 89
		viewW = 2, -- 90
		viewH = 2 -- 91
	} -- 91
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 93
	local worst = 0 -- 94
	do -- 94
		local i = 0 -- 95
		while i < #pts do -- 95
			local p = projectPrepared({x = pts[i + 1].x * PlaneToWorldX, y = 0, z = pts[i + 1].y * PlaneToWorldZ}, basis) -- 96
			if p == nil then -- 96
				return 99 -- 100
			end -- 100
			local r = i == 0 and radius or 0 -- 101
			local ry = r / p.vz * basis.focal -- 102
			local rx = ry / opts.aspect -- 103
			local ox = math.abs(p.x) + rx -- 104
			local oy = math.abs(p.y) + ry -- 105
			if ox > worst then -- 105
				worst = ox -- 106
			end -- 106
			if oy > worst then -- 106
				worst = oy -- 107
			end -- 107
			i = i + 1 -- 95
		end -- 95
	end -- 95
	return worst -- 109
end -- 83
local function testFraming() -- 112
	local pts = {{x = 0, y = 18}, {x = 0, y = -2}, {x = -26, y = -26}} -- 114
	local probeRadius = 2.13 -- 116
	local portrait = defaultRigOptions(45, 601 / 1066) -- 118
	local rigP = createCameraRig(portrait) -- 119
	local frameP = rigP.step(pts, probeRadius) -- 120
	local overP = overflowOf(frameP, portrait, pts, probeRadius) -- 121
	local limit = 1 - portrait.margin -- 122
	check( -- 123
		"rig-frame-portrait-fits", -- 123
		overP <= limit + 0.000001, -- 123
		(("max|ndc|=" .. __TS__NumberToFixed(overP, 4)) .. " limit=") .. __TS__NumberToFixed(limit, 2) -- 123
	) -- 123
	check( -- 126
		"rig-frame-probe-inside", -- 126
		overP < 0.99, -- 126
		("max|ndc|=" .. __TS__NumberToFixed(overP, 4)) .. "（旧算法 1.11 = 出画）" -- 126
	) -- 126
	local dx = frameP.eye.x - frameP.target.x -- 129
	local dy = frameP.eye.y - frameP.target.y -- 130
	local dz = frameP.eye.z - frameP.target.z -- 131
	local distP = math.sqrt(dx * dx + dy * dy + dz * dz) -- 132
	check( -- 133
		"rig-frame-portrait-distance", -- 134
		distP >= portrait.minDistance * 0.999 and distP <= portrait.maxDistance * 1.001, -- 135
		((((("dist=" .. __TS__NumberToFixed(distP, 2)) .. " range=[") .. tostring(portrait.minDistance)) .. ", ") .. tostring(portrait.maxDistance)) .. "]" -- 135
	) -- 135
	local landscape = defaultRigOptions(45, 2024 / 1231) -- 140
	local rigL = createCameraRig(landscape) -- 141
	local frameL = rigL.step(pts, probeRadius) -- 142
	local overL = overflowOf(frameL, landscape, pts, probeRadius) -- 143
	check( -- 144
		"rig-frame-landscape-fits", -- 144
		overL <= 1 - landscape.margin + 0.000001, -- 144
		"max|ndc|=" .. __TS__NumberToFixed(overL, 4) -- 144
	) -- 144
	local frameFar = createCameraRig(portrait).step(pts, 8) -- 147
	local fx = frameFar.eye.x - frameFar.target.x -- 148
	local fy = frameFar.eye.y - frameFar.target.y -- 149
	local fz = frameFar.eye.z - frameFar.target.z -- 150
	local distFar = math.sqrt(fx * fx + fy * fy + fz * fz) -- 151
	check( -- 152
		"rig-frame-radius-matters", -- 152
		distFar > distP + 0.5, -- 152
		(("r=2.13 → " .. __TS__NumberToFixed(distP, 2)) .. ", r=8.0 → ") .. __TS__NumberToFixed(distFar, 2) -- 152
	) -- 152
end -- 112
--- 3) 距离夹紧：不超出 [min, max]。
local function testClamp() -- 156
	local opts = defaultRigOptions() -- 157
	local rig = createCameraRig(opts) -- 158
	local far = rig.step({{x = 0, y = 5000}, {x = 0, y = 0}}) -- 161
	local dx = far.eye.x - far.target.x -- 162
	local dy = far.eye.y - far.target.y -- 163
	local dz = far.eye.z - far.target.z -- 164
	local dFar = math.sqrt(dx * dx + dy * dy + dz * dz) -- 165
	check( -- 167
		"rig-clamp-max", -- 167
		dFar <= opts.maxDistance * 1.001, -- 167
		(("distance=" .. tostring(dFar)) .. " max=") .. tostring(opts.maxDistance) -- 167
	) -- 167
	local near = rig.step({{x = 0, y = 0}, {x = 0, y = 0}}) -- 170
	local ex = near.eye.x - near.target.x -- 171
	local ey = near.eye.y - near.target.y -- 172
	local ez = near.eye.z - near.target.z -- 173
	local dNear = math.sqrt(ex * ex + ey * ey + ez * ez) -- 174
	check( -- 175
		"rig-clamp-min", -- 175
		dNear >= opts.minDistance * 0.999, -- 175
		(("distance=" .. tostring(dNear)) .. " min=") .. tostring(opts.minDistance) -- 175
	) -- 175
end -- 156
--- 4) 倾角固定：相机到注视点的方向应始终符合 tilt。
local function testTilt() -- 179
	local opts = defaultRigOptions() -- 180
	local rig = createCameraRig(opts) -- 181
	local frame = rig.step({{x = 5, y = 5}, {x = -5, y = -5}}) -- 182
	local dz = frame.eye.z - frame.target.z -- 184
	local dy = frame.eye.y - frame.target.y -- 185
	local angle = math.atan(dy, dz) * 180 / math.pi -- 186
	check( -- 187
		"rig-tilt", -- 187
		math.abs(angle - opts.tiltDeg) < 0.5, -- 187
		(("angle=" .. __TS__NumberToFixed(angle, 2)) .. " expected=") .. tostring(opts.tiltDeg) -- 187
	) -- 187
	check( -- 188
		"rig-tilt-in-range", -- 188
		opts.tiltDeg >= 20 and opts.tiltDeg <= 60, -- 188
		("tilt=" .. tostring(opts.tiltDeg)) .. "（安全区 20–60）" -- 188
	) -- 188
end -- 179
--- 5) 平滑：lerp 较小时，单帧不会直接跳到目标值。
local function testSmoothing() -- 192
	local opts = defaultRigOptions() -- 193
	opts.lerp = 0.1 -- 194
	local rig = createCameraRig(opts) -- 195
	local a = rig.step({{x = 0, y = 0}}) -- 197
	local b = rig.step({{x = 100, y = 0}}) -- 198
	local moved = math.abs(b.target.x - a.target.x) -- 200
	check( -- 202
		"rig-smoothing-partial", -- 202
		moved > 0.5 and moved < 99, -- 202
		("moved=" .. __TS__NumberToFixed(moved, 2)) .. "（应在 0 与 100 之间）" -- 202
	) -- 202
end -- 192
function ____exports.runTests() -- 205
	testFit() -- 206
	testDistanceMonotonic() -- 207
	testClamp() -- 208
	testTilt() -- 209
	testSmoothing() -- 210
	testFraming() -- 211
	local lines = {} -- 213
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 214
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 215
	local limit = #failures < 12 and #failures or 12 -- 216
	do -- 216
		local i = 0 -- 217
		while i < limit do -- 217
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 218
			i = i + 1 -- 217
		end -- 217
	end -- 217
	return table.concat(lines, "\n") -- 220
end -- 205
return ____exports -- 205
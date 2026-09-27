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
local SlowMoCloseDist = ____Config.SlowMoCloseDist -- 8
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
--- 7) 慢动作特写的距离下限（S3.17）：step 的第 4 个参数只换夹紧左端，不另写一套取景。
-- 
-- 判据：① 同一组关键点 + 逐点半径，传了更小的下限就**真的更近**（贴近被掠过的天体）；
-- ② 下限只是地板，求解器仍保证全部关键点（含半径）在画面内；③ 日常取景（不传）不受影响。
local function testSlowMoCloseup() -- 215
	local opts = defaultRigOptions(45, 601 / 1066) -- 216
	local pts = {{x = 0, y = 13}, {x = 0, y = 0}} -- 218
	local radii = {2.13, 4.63} -- 219
	local wide = createCameraRig(opts).step(pts, 2.13, radii) -- 222
	local close = createCameraRig(opts).step(pts, 2.13, radii, SlowMoCloseDist) -- 223
	local function dist(f) -- 224
		local dx = f.eye.x - f.target.x -- 225
		local dy = f.eye.y - f.target.y -- 226
		local dz = f.eye.z - f.target.z -- 227
		return math.sqrt(dx * dx + dy * dy + dz * dz) -- 228
	end -- 224
	check( -- 230
		"rig-slowmo-closer", -- 230
		dist(close) < dist(wide) - 20, -- 230
		((("close=" .. __TS__NumberToFixed( -- 231
			dist(close), -- 231
			1 -- 231
		)) .. " wide=") .. __TS__NumberToFixed( -- 231
			dist(wide), -- 231
			1 -- 231
		)) .. "（贴近被掠过的天体）" -- 231
	) -- 231
	check( -- 232
		"rig-slowmo-floor", -- 232
		dist(close) >= SlowMoCloseDist * 0.999, -- 232
		(("dist=" .. __TS__NumberToFixed( -- 233
			dist(close), -- 233
			2 -- 233
		)) .. " floor=") .. tostring(SlowMoCloseDist) -- 233
	) -- 233
	local view = { -- 236
		eye = close.eye, -- 237
		target = close.target, -- 238
		up = {x = 0, y = 1, z = 0}, -- 239
		fovYDeg = opts.fovYDeg, -- 240
		aspect = opts.aspect, -- 241
		viewW = 2, -- 242
		viewH = 2 -- 243
	} -- 243
	local basis = prepareCamera(view, HANDEDNESS, FLIP_Y) -- 245
	local worst = 0 -- 246
	do -- 246
		local i = 0 -- 247
		while i < #pts do -- 247
			local p = projectPrepared({x = pts[i + 1].x * PlaneToWorldX, y = 0, z = pts[i + 1].y * PlaneToWorldZ}, basis) -- 248
			if p == nil then -- 248
				worst = 99 -- 249
				break -- 249
			end -- 249
			local ry = radii[i + 1] / p.vz * basis.focal -- 250
			local rx = ry / opts.aspect -- 251
			if math.abs(p.x) + rx > worst then -- 251
				worst = math.abs(p.x) + rx -- 252
			end -- 252
			if math.abs(p.y) + ry > worst then -- 252
				worst = math.abs(p.y) + ry -- 253
			end -- 253
			i = i + 1 -- 247
		end -- 247
	end -- 247
	check( -- 255
		"rig-slowmo-fits", -- 255
		worst <= 1 - opts.margin + 0.000001, -- 255
		(("max|ndc|=" .. __TS__NumberToFixed(worst, 4)) .. " limit=") .. __TS__NumberToFixed(1 - opts.margin, 2) -- 256
	) -- 256
	local again = createCameraRig(opts).step(pts, 2.13, radii) -- 259
	check( -- 260
		"rig-slowmo-opt-in", -- 260
		math.abs(dist(again) - opts.minDistance) < 1, -- 260
		(("dist=" .. __TS__NumberToFixed( -- 261
			dist(again), -- 261
			1 -- 261
		)) .. " 期望夹在 ") .. tostring(opts.minDistance) -- 261
	) -- 261
end -- 215
function ____exports.runTests() -- 264
	testFit() -- 265
	testDistanceMonotonic() -- 266
	testClamp() -- 267
	testTilt() -- 268
	testSmoothing() -- 269
	testFraming() -- 270
	testSlowMoCloseup() -- 271
	local lines = {} -- 273
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 274
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 275
	local limit = #failures < 12 and #failures or 12 -- 276
	do -- 276
		local i = 0 -- 277
		while i < limit do -- 277
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 278
			i = i + 1 -- 277
		end -- 277
	end -- 277
	return table.concat(lines, "\n") -- 280
end -- 264
return ____exports -- 264
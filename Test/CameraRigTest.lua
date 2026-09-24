-- [ts]: CameraRigTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local ____exports = {} -- 1
local ____CameraRig = require("game.CameraRig") -- 7
local createCameraRig = ____CameraRig.createCameraRig -- 7
local computeFit = ____CameraRig.computeFit -- 7
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 7
local failures = {} -- 15
local checks = 0 -- 16
local function check(name, ok, detail) -- 18
	checks = checks + 1 -- 19
	if not ok then -- 19
		failures[#failures + 1] = {name = name, detail = detail} -- 20
	end -- 20
end -- 18
--- 1) computeFit：包围盒中心与半对角。
local function testFit() -- 24
	local pts = {{x = -10, y = -10}, {x = 10, y = 10}} -- 25
	local f = computeFit(pts) -- 29
	check( -- 30
		"fit-center", -- 30
		math.abs(f.centerX) < 1e-12 and math.abs(f.centerY) < 1e-12, -- 30
		((("center=(" .. tostring(f.centerX)) .. ", ") .. tostring(f.centerY)) .. ")" -- 30
	) -- 30
	check( -- 32
		"fit-extent", -- 32
		math.abs(f.extent - math.sqrt(200)) < 1e-9, -- 32
		"extent=" .. tostring(f.extent) -- 32
	) -- 32
	local empty = computeFit({}) -- 35
	check( -- 36
		"fit-empty", -- 36
		empty.extent == 0 and empty.centerX == 0, -- 36
		"extent=" .. tostring(empty.extent) -- 36
	) -- 36
	local one = computeFit({{x = 3, y = -4}}) -- 39
	check( -- 40
		"fit-single", -- 40
		one.extent == 0 and one.centerX == 3 and one.centerY == -4, -- 40
		"extent=" .. tostring(one.extent) -- 40
	) -- 40
end -- 24
--- 2) 距离单调性：探测器越远，相机距离越大（S1.2 的核心验收点）。
local function testDistanceMonotonic() -- 44
	local opts = defaultRigOptions() -- 45
	local planets = {{x = 0, y = 0}, {x = 0, y = -14}} -- 46
	local rig = createCameraRig(opts) -- 48
	local dists = {} -- 51
	for ____, probeY in ipairs({ -- 52
		14, -- 52
		20, -- 52
		30, -- 52
		50, -- 52
		80, -- 52
		120 -- 52
	}) do -- 52
		local frame = rig.step({{x = 0, y = probeY}, planets[1], planets[2]}) -- 53
		local dx = frame.eye.x - frame.target.x -- 54
		local dy = frame.eye.y - frame.target.y -- 55
		local dz = frame.eye.z - frame.target.z -- 56
		dists[#dists + 1] = math.sqrt(dx * dx + dy * dy + dz * dz) -- 57
	end -- 57
	local monotonic = true -- 60
	do -- 60
		local i = 1 -- 61
		while i < #dists do -- 61
			if dists[i + 1] < dists[i] - 1e-9 then -- 61
				monotonic = false -- 63
				break -- 64
			end -- 64
			i = i + 1 -- 61
		end -- 61
	end -- 61
	check( -- 67
		"rig-distance-monotonic", -- 67
		monotonic, -- 67
		"distances=" .. table.concat( -- 67
			__TS__ArrayMap( -- 67
				dists, -- 67
				function(____, d) return __TS__NumberToFixed(d, 1) end -- 67
			), -- 67
			", " -- 67
		) -- 67
	) -- 67
	local grew = dists[#dists] > dists[1] + 1 -- 70
	check( -- 71
		"rig-distance-grows", -- 71
		grew, -- 71
		(("first=" .. __TS__NumberToFixed(dists[1], 1)) .. " last=") .. __TS__NumberToFixed(dists[#dists], 1) -- 71
	) -- 71
end -- 44
--- 3) 距离夹紧：不超出 [min, max]。
local function testClamp() -- 75
	local opts = defaultRigOptions() -- 76
	local rig = createCameraRig(opts) -- 77
	local far = rig.step({{x = 0, y = 5000}, {x = 0, y = 0}}) -- 80
	local dx = far.eye.x - far.target.x -- 81
	local dy = far.eye.y - far.target.y -- 82
	local dz = far.eye.z - far.target.z -- 83
	local dFar = math.sqrt(dx * dx + dy * dy + dz * dz) -- 84
	check( -- 86
		"rig-clamp-max", -- 86
		dFar <= opts.maxDistance * 1.001, -- 86
		(("distance=" .. tostring(dFar)) .. " max=") .. tostring(opts.maxDistance) -- 86
	) -- 86
	local near = rig.step({{x = 0, y = 0}, {x = 0, y = 0}}) -- 89
	local ex = near.eye.x - near.target.x -- 90
	local ey = near.eye.y - near.target.y -- 91
	local ez = near.eye.z - near.target.z -- 92
	local dNear = math.sqrt(ex * ex + ey * ey + ez * ez) -- 93
	check( -- 94
		"rig-clamp-min", -- 94
		dNear >= opts.minDistance * 0.999, -- 94
		(("distance=" .. tostring(dNear)) .. " min=") .. tostring(opts.minDistance) -- 94
	) -- 94
end -- 75
--- 4) 倾角固定：相机到注视点的方向应始终符合 tilt。
local function testTilt() -- 98
	local opts = defaultRigOptions() -- 99
	local rig = createCameraRig(opts) -- 100
	local frame = rig.step({{x = 5, y = 5}, {x = -5, y = -5}}) -- 101
	local dz = frame.eye.z - frame.target.z -- 103
	local dy = frame.eye.y - frame.target.y -- 104
	local angle = math.atan(dy, dz) * 180 / math.pi -- 105
	check( -- 106
		"rig-tilt", -- 106
		math.abs(angle - opts.tiltDeg) < 0.5, -- 106
		(("angle=" .. __TS__NumberToFixed(angle, 2)) .. " expected=") .. tostring(opts.tiltDeg) -- 106
	) -- 106
	check( -- 107
		"rig-tilt-in-range", -- 107
		opts.tiltDeg >= 20 and opts.tiltDeg <= 60, -- 107
		("tilt=" .. tostring(opts.tiltDeg)) .. "（安全区 20–60）" -- 107
	) -- 107
end -- 98
--- 5) 平滑：lerp 较小时，单帧不会直接跳到目标值。
local function testSmoothing() -- 111
	local opts = defaultRigOptions() -- 112
	opts.lerp = 0.1 -- 113
	local rig = createCameraRig(opts) -- 114
	local a = rig.step({{x = 0, y = 0}}) -- 116
	local b = rig.step({{x = 100, y = 0}}) -- 117
	local moved = math.abs(b.target.x - a.target.x) -- 119
	check( -- 121
		"rig-smoothing-partial", -- 121
		moved > 0.5 and moved < 99, -- 121
		("moved=" .. __TS__NumberToFixed(moved, 2)) .. "（应在 0 与 100 之间）" -- 121
	) -- 121
end -- 111
function ____exports.runTests() -- 124
	testFit() -- 125
	testDistanceMonotonic() -- 126
	testClamp() -- 127
	testTilt() -- 128
	testSmoothing() -- 129
	local lines = {} -- 131
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 132
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 133
	local limit = #failures < 12 and #failures or 12 -- 134
	do -- 134
		local i = 0 -- 135
		while i < limit do -- 135
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 136
			i = i + 1 -- 135
		end -- 135
	end -- 135
	return table.concat(lines, "\n") -- 138
end -- 124
return ____exports -- 124
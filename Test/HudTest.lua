-- [ts]: HudTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Config = require("game.Config") -- 7
local AimMaxSpeed = ____Config.AimMaxSpeed -- 7
local AimMinSpeed = ____Config.AimMinSpeed -- 7
local ____Hud = require("game.Hud") -- 8
local computeAim = ____Hud.computeAim -- 8
local screenToPlane = ____Hud.screenToPlane -- 8
local defaultMaxDragPx = ____Hud.defaultMaxDragPx -- 8
local localToOffset = ____Hud.localToOffset -- 8
local offsetToLocal = ____Hud.offsetToLocal -- 8
local ____Projection = require("game.Projection") -- 9
local HANDEDNESS = ____Projection.HANDEDNESS -- 9
local FLIP_Y = ____Projection.FLIP_Y -- 9
local prepareCamera = ____Projection.prepareCamera -- 9
local project = ____Projection.project -- 9
local failures = {} -- 16
local checks = 0 -- 17
local function check(name, ok, detail) -- 19
	checks = checks + 1 -- 20
	if not ok then -- 20
		failures[#failures + 1] = {name = name, detail = detail} -- 21
	end -- 21
end -- 19
local PROBE = {x = -60, y = 120} -- 25
--- 1) 无拖动：不发射，速度取最小值。
local function testNoDrag() -- 28
	local a = computeAim(PROBE, PROBE, 300) -- 29
	check( -- 30
		"no-drag-power", -- 30
		a.power == 0, -- 30
		"power=" .. tostring(a.power) -- 30
	) -- 30
	local speed = math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y) -- 31
	check( -- 32
		"no-drag-speed-min", -- 32
		math.abs(speed - AimMinSpeed) < 1e-9, -- 32
		(("speed=" .. tostring(speed)) .. " expected=") .. tostring(AimMinSpeed) -- 32
	) -- 32
	check( -- 34
		"no-drag-forward", -- 34
		a.velocity.y < 0 and math.abs(a.velocity.x) < 1e-9, -- 34
		((("v=(" .. tostring(a.velocity.x)) .. ", ") .. tostring(a.velocity.y)) .. ")" -- 34
	) -- 34
end -- 28
--- 2) 方向：由“探测器 → 触摸点”决定。
-- 投影偏移空间 +Y 向下，平面 +y 在屏幕上表现为向上，所以：
--  触摸在探测器**上方**（offset.y 更小）→ 平面 +y（靠近相机的一侧）
--  触摸在探测器**下方**（offset.y 更大）→ 平面 -y（远离相机）
local function testDirection() -- 42
	local down = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + 200}, 300) -- 44
	check( -- 45
		"dir-down", -- 45
		down.velocity.y < -1, -- 45
		("vy=" .. __TS__NumberToFixed(down.velocity.y, 2)) .. "（应为负）" -- 45
	) -- 45
	local up = computeAim(PROBE, {x = PROBE.x, y = PROBE.y - 200}, 300) -- 48
	check( -- 49
		"dir-up", -- 49
		up.velocity.y > 1, -- 49
		("vy=" .. __TS__NumberToFixed(up.velocity.y, 2)) .. "（应为正）" -- 49
	) -- 49
	local right = computeAim(PROBE, {x = PROBE.x + 200, y = PROBE.y}, 300) -- 52
	check( -- 53
		"dir-right", -- 53
		right.velocity.x > 1 and math.abs(right.velocity.y) < 1e-9, -- 53
		((("v=(" .. __TS__NumberToFixed(right.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(right.velocity.y, 2)) .. ")" -- 53
	) -- 53
	local u = math.sqrt(down.unit.x * down.unit.x + down.unit.y * down.unit.y) -- 56
	check( -- 57
		"unit-length", -- 57
		math.abs(u - 1) < 1e-9, -- 57
		"|unit|=" .. tostring(u) -- 57
	) -- 57
end -- 42
--- 3) 力度：随拖动距离线性增长并夹紧到 1。
local function testPower() -- 61
	local maxDrag = defaultMaxDragPx() -- 62
	local half = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag / 2}, maxDrag) -- 65
	check( -- 66
		"power-half", -- 66
		math.abs(half.power - 0.5) < 0.000001, -- 66
		"power=" .. tostring(half.power) -- 66
	) -- 66
	local full = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag}, maxDrag) -- 69
	check( -- 70
		"power-full", -- 70
		math.abs(full.power - 1) < 0.000001, -- 70
		"power=" .. tostring(full.power) -- 70
	) -- 70
	local over = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag * 3}, maxDrag) -- 73
	check( -- 74
		"power-clamped", -- 74
		over.power == 1, -- 74
		"power=" .. tostring(over.power) -- 74
	) -- 74
	local overSpeed = math.sqrt(over.velocity.x * over.velocity.x + over.velocity.y * over.velocity.y) -- 75
	check( -- 76
		"speed-clamped", -- 76
		math.abs(overSpeed - AimMaxSpeed) < 0.000001, -- 76
		(("speed=" .. tostring(overSpeed)) .. " expected=") .. tostring(AimMaxSpeed) -- 76
	) -- 76
	local monotonic = true -- 79
	local prev = -1 -- 80
	for ____, f in ipairs({ -- 81
		0, -- 81
		0.25, -- 81
		0.5, -- 81
		0.75, -- 81
		1 -- 81
	}) do -- 81
		local r = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag * f}, maxDrag) -- 82
		local s = math.sqrt(r.velocity.x * r.velocity.x + r.velocity.y * r.velocity.y) -- 83
		if s < prev - 1e-9 then -- 83
			monotonic = false -- 84
			break -- 84
		end -- 84
		prev = s -- 85
	end -- 85
	check("speed-monotonic", monotonic, "速度未随力度单调增长") -- 87
end -- 61
--- 4) screenToPlane 与 project() 互逆（验证反投影公式正确）。
local function testRoundTrip() -- 91
	local cam = { -- 92
		eye = {x = 0, y = 21.2, z = 21.2}, -- 93
		target = {x = 0, y = 0, z = 0}, -- 94
		up = {x = 0, y = 1, z = 0}, -- 95
		fovYDeg = 45, -- 96
		aspect = 0.5625, -- 97
		viewW = 1080, -- 98
		viewH = 1920 -- 99
	} -- 99
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 101
	local pts = {{x = 0, y = 0}, {x = 5, y = -8}, {x = -6, y = 4}} -- 104
	local maxErr = 0 -- 110
	for ____, p in ipairs(pts) do -- 111
		local world = {x = p.x, y = 0, z = p.y} -- 112
		local proj = project(world, cam, HANDEDNESS, FLIP_Y) -- 113
		if proj == nil then -- 113
			maxErr = 1000000000 -- 114
			break -- 114
		end -- 114
		local back = screenToPlane({x = proj.x, y = proj.y}, basis) -- 116
		if back == nil then -- 116
			maxErr = 1000000000 -- 117
			break -- 117
		end -- 117
		local dx = back.x - p.x -- 118
		local dy = back.y - p.y -- 119
		local e = math.sqrt(dx * dx + dy * dy) -- 120
		if e > maxErr then -- 120
			maxErr = e -- 121
		end -- 121
	end -- 121
	check( -- 123
		"screen-plane-roundtrip", -- 123
		maxErr < 0.000001, -- 123
		("maxErr=" .. __TS__NumberToFixed(maxErr, 12)) .. "（应接近 0）" -- 123
	) -- 123
end -- 91
--- 5) 坐标换算：局部坐标 ↔ 投影偏移空间应互逆，且语义正确。
local function testSpaceConversion() -- 127
	local space = {viewW = 1080, viewH = 1920} -- 128
	local center = localToOffset({x = 540, y = 960}, space) -- 131
	check( -- 132
		"space-center", -- 132
		math.abs(center.x) < 1e-9 and math.abs(center.y) < 1e-9, -- 132
		((("offset=(" .. tostring(center.x)) .. ", ") .. tostring(center.y)) .. ")" -- 132
	) -- 132
	local bl = localToOffset({x = 0, y = 0}, space) -- 135
	check( -- 136
		"space-bottom-left", -- 136
		math.abs(bl.x + 540) < 1e-9 and math.abs(bl.y - 960) < 1e-9, -- 136
		((("offset=(" .. tostring(bl.x)) .. ", ") .. tostring(bl.y)) .. ")" -- 136
	) -- 136
	local tl = localToOffset({x = 0, y = 1920}, space) -- 139
	check( -- 140
		"space-top-left", -- 140
		math.abs(tl.x + 540) < 1e-9 and math.abs(tl.y + 960) < 1e-9, -- 140
		((("offset=(" .. tostring(tl.x)) .. ", ") .. tostring(tl.y)) .. ")" -- 140
	) -- 140
	local allExact = true -- 143
	for ____, p in ipairs({{x = 100, y = 200}, {x = 0, y = 0}, {x = -300, y = 150}}) do -- 144
		local back = offsetToLocal( -- 145
			localToOffset(p, space), -- 145
			space -- 145
		) -- 145
		if math.abs(back.x - p.x) > 1e-9 or math.abs(back.y - p.y) > 1e-9 then -- 145
			allExact = false -- 146
			break -- 146
		end -- 146
	end -- 146
	check("space-roundtrip", allExact, "localToOffset / offsetToLocal 不互逆") -- 148
end -- 127
function ____exports.runTests() -- 151
	testNoDrag() -- 152
	testDirection() -- 153
	testPower() -- 154
	testRoundTrip() -- 155
	testSpaceConversion() -- 156
	local lines = {} -- 158
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 159
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 160
	local limit = #failures < 12 and #failures or 12 -- 161
	do -- 161
		local i = 0 -- 162
		while i < limit do -- 162
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 163
			i = i + 1 -- 162
		end -- 162
	end -- 162
	return table.concat(lines, "\n") -- 165
end -- 151
return ____exports -- 151
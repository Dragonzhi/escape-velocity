-- [ts]: PlanViewTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____LevelData = require("game.LevelData") -- 12
local getLevel = ____LevelData.getLevel -- 12
local scaledPlanets = ____LevelData.scaledPlanets -- 12
local ____PlanView = require("game.PlanView") -- 13
local computePlanMapping = ____PlanView.computePlanMapping -- 13
local planeToScreen = ____PlanView.planeToScreen -- 13
local planFitRadius = ____PlanView.planFitRadius -- 13
local screenToPlane = ____PlanView.screenToPlane -- 13
local failures = {} -- 20
local checks = 0 -- 21
local function check(name, ok, detail) -- 23
	checks = checks + 1 -- 24
	if not ok then -- 24
		failures[#failures + 1] = {name = name, detail = detail} -- 25
	end -- 25
end -- 23
--- 造一颗绕原点公转的行星。
local function orbiter(radius, orbitRadius) -- 29
	return { -- 30
		gm = 0, -- 31
		radius = radius, -- 31
		orbitCenter = {x = 0, y = 0}, -- 32
		orbitRadius = orbitRadius, -- 32
		orbitPeriod = orbitRadius > 0 and 1 or 0, -- 33
		phase0 = 0, -- 33
		orbitDirection = 1 -- 33
	} -- 33
end -- 29
--- 造一颗绕**别的天体**转的卫星（月球：圆心跟着地球走）。
local function satellite(radius, host, orbitRadius) -- 38
	return { -- 39
		gm = 0, -- 40
		radius = radius, -- 40
		orbitCenter = {x = 0, y = 0}, -- 41
		orbitRadius = orbitRadius, -- 41
		orbitPeriod = 10, -- 42
		phase0 = 0, -- 42
		orbitDirection = 1, -- 42
		host = host -- 42
	} -- 42
end -- 38
--- 1) 映射：等比、留白、退化半径兜底。
local function testMapping() -- 47
	local W = 601 -- 48
	local H = 1066 -- 49
	local R = 265 -- 50
	local m = computePlanMapping(W, H, R, 0.12) -- 51
	local expect = W * 0.76 / (2 * R) -- 54
	check( -- 55
		"map-width-limited", -- 55
		math.abs(m.scale - expect) < 1e-9, -- 55
		(("scale=" .. __TS__NumberToFixed(m.scale, 4)) .. " expect=") .. __TS__NumberToFixed(expect, 4) -- 55
	) -- 55
	check( -- 56
		"map-fits-height", -- 56
		R * m.scale <= H * 0.4 + 0.000001, -- 56
		(("R*scale=" .. __TS__NumberToFixed(R * m.scale, 1)) .. " halfH=") .. __TS__NumberToFixed(H * 0.4, 1) -- 56
	) -- 56
	local right = planeToScreen({x = R, y = 0}, m) -- 59
	local left = planeToScreen({x = -R, y = 0}, m) -- 60
	check( -- 61
		"map-margin-respected", -- 61
		right.x <= W * 0.88 + 0.000001 and left.x >= W * 0.12 - 0.000001, -- 62
		((((((("x=[" .. __TS__NumberToFixed(left.x, 1)) .. ",") .. __TS__NumberToFixed(right.x, 1)) .. "] limit=[") .. __TS__NumberToFixed(W * 0.12, 1)) .. ",") .. __TS__NumberToFixed(W * 0.88, 1)) .. "]" -- 62
	) -- 62
	local mLand = computePlanMapping(2024, 1230, 100, 0.12) -- 66
	check( -- 67
		"map-height-limited", -- 67
		math.abs(mLand.scale - 1230 * 0.76 / 200) < 1e-9, -- 67
		"scale=" .. __TS__NumberToFixed(mLand.scale, 4) -- 67
	) -- 67
	local cx = m.originX -- 70
	local cy = m.originY -- 71
	local px = planeToScreen({x = 40, y = 0}, m) -- 72
	local py = planeToScreen({x = 0, y = 40}, m) -- 73
	local dxx = px.x - cx -- 74
	local dxy = px.y - cy -- 75
	local dyx = py.x - cx -- 76
	local dyy = py.y - cy -- 77
	local rx = math.sqrt(dxx * dxx + dxy * dxy) -- 78
	local ry = math.sqrt(dyx * dyx + dyy * dyy) -- 79
	check( -- 80
		"map-no-distortion", -- 80
		math.abs(rx - ry) < 1e-9, -- 80
		(("rx=" .. __TS__NumberToFixed(rx, 4)) .. " ry=") .. __TS__NumberToFixed(ry, 4) -- 80
	) -- 80
	local m0 = computePlanMapping(W, H, 0, 0.12) -- 83
	check( -- 84
		"map-degenerate-radius", -- 84
		m0.scale > 0 and m0.scale < 1000000000, -- 84
		"scale=" .. tostring(m0.scale) -- 84
	) -- 84
	local mBig = computePlanMapping(W, H, 100, 0.9) -- 86
	check( -- 87
		"map-margin-clamped", -- 87
		mBig.scale > 0 and mBig.scale < 1000000000, -- 87
		"scale=" .. tostring(mBig.scale) -- 87
	) -- 87
end -- 47
--- 2) 平面 → 屏幕：中心对原点、**y 反向**、可逆。
local function testPlaneToScreen() -- 91
	local W = 601 -- 92
	local H = 1066 -- 93
	local m = computePlanMapping(W, H, 100, 0.12) -- 94
	local o = planeToScreen({x = 0, y = 0}, m) -- 96
	check( -- 97
		"screen-origin-at-center", -- 97
		o.x == W / 2 and o.y == H / 2, -- 97
		((((((("(" .. tostring(o.x)) .. ",") .. tostring(o.y)) .. ") expect=(") .. tostring(W / 2)) .. ",") .. tostring(H / 2)) .. ")" -- 97
	) -- 97
	local up = planeToScreen({x = 0, y = 50}, m) -- 100
	local down = planeToScreen({x = 0, y = -50}, m) -- 101
	check( -- 102
		"screen-y-flipped", -- 102
		up.y < o.y and down.y > o.y, -- 102
		(((("plane+50 -> y=" .. __TS__NumberToFixed(up.y, 1)) .. " plane-50 -> y=") .. __TS__NumberToFixed(down.y, 1)) .. " center=") .. tostring(o.y) -- 102
	) -- 102
	local p = {x = 37.5, y = -18.25} -- 105
	local back = screenToPlane( -- 106
		planeToScreen(p, m), -- 106
		m -- 106
	) -- 106
	check( -- 107
		"screen-roundtrip", -- 107
		math.abs(back.x - p.x) < 1e-9 and math.abs(back.y - p.y) < 1e-9, -- 107
		((((((("(" .. tostring(back.x)) .. ",") .. tostring(back.y)) .. ") vs (") .. tostring(p.x)) .. ",") .. tostring(p.y)) .. ")" -- 107
	) -- 107
end -- 91
--- 3) 视野半径：最外圈轨道 + 目标容差（含卫星的宿主链）。
local function testFitRadius() -- 111
	local sun = orbiter(28, 0) -- 113
	local earth = orbiter(1.76, 80) -- 114
	local moon = satellite(1, earth, 15) -- 115
	local fit1 = planFitRadius({sun, earth, moon}, {x = 0, y = 90}, 2, 5) -- 116
	local expect1 = 80 + 15 + 5 -- 117
	check( -- 118
		"fit-l1-moon-host-chain", -- 118
		math.abs(fit1 - expect1) < 1e-9, -- 118
		(("fit=" .. __TS__NumberToFixed(fit1, 2)) .. " expect=") .. tostring(expect1) -- 118
	) -- 118
	local jup = orbiter(4.63, 105) -- 121
	local sat = orbiter(4.3, 135) -- 122
	local ura = orbiter(3.04, 165) -- 123
	local nep = orbiter(3, 195) -- 124
	local fit6 = planFitRadius( -- 125
		{ -- 125
			sun, -- 125
			orbiter(1.76, 80), -- 125
			jup, -- 125
			sat, -- 125
			ura, -- 125
			nep -- 125
		}, -- 125
		{x = 0, y = 80}, -- 125
		5, -- 125
		70 -- 125
	) -- 125
	check( -- 126
		"fit-l6-outer-orbit-plus-tolerance", -- 126
		math.abs(fit6 - 265) < 1e-9, -- 126
		("fit=" .. __TS__NumberToFixed(fit6, 2)) .. " expect=265" -- 126
	) -- 126
	local fitProbe = planFitRadius( -- 129
		{orbiter(1, 10)}, -- 129
		{x = 0, y = 300}, -- 129
		0, -- 129
		0 -- 129
	) -- 129
	check( -- 130
		"fit-includes-probe", -- 130
		fitProbe >= 300, -- 130
		"fit=" .. __TS__NumberToFixed(fitProbe, 2) -- 130
	) -- 130
	local fitEmpty = planFitRadius({}, {x = 0, y = 0}, -1, 0) -- 133
	check( -- 134
		"fit-nonzero", -- 134
		fitEmpty > 0 and fitEmpty < 1000000000, -- 134
		"fit=" .. tostring(fitEmpty) -- 134
	) -- 134
	local l1 = getLevel(0) -- 137
	if l1 == nil then -- 137
		check("fit-real-l1", false, "getLevel(0) 返回 undefined") -- 139
	else -- 139
		local real1 = planFitRadius( -- 141
			scaledPlanets(l1), -- 141
			l1.probeStart, -- 141
			l1.goal.planetIndex, -- 141
			l1.goal.tolerance -- 141
		) -- 141
		check( -- 142
			"fit-real-l1", -- 142
			real1 >= 100 and real1 < 200, -- 142
			("L1 fit=" .. __TS__NumberToFixed(real1, 2)) .. "（应 ≥ 月球最远 95 + 容差 5）" -- 142
		) -- 142
	end -- 142
	local l6 = getLevel(5) -- 144
	if l6 == nil then -- 144
		check("fit-real-l6", false, "getLevel(5) 返回 undefined") -- 146
	else -- 146
		local real6 = planFitRadius( -- 149
			scaledPlanets(l6), -- 149
			l6.probeStart, -- 149
			l6.goal.planetIndex, -- 149
			70 -- 149
		) -- 149
		check( -- 150
			"fit-real-l6", -- 150
			real6 >= 265 and real6 < 300, -- 150
			"L6 fit=" .. __TS__NumberToFixed(real6, 2) -- 150
		) -- 150
	end -- 150
end -- 111
function ____exports.runTests() -- 154
	testMapping() -- 155
	testPlaneToScreen() -- 156
	testFitRadius() -- 157
	local lines = {} -- 159
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 160
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 161
	local limit = #failures < 12 and #failures or 12 -- 162
	do -- 162
		local i = 0 -- 163
		while i < limit do -- 163
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 164
			i = i + 1 -- 163
		end -- 163
	end -- 163
	return table.concat(lines, "\n") -- 166
end -- 154
return ____exports -- 154
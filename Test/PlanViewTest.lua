-- [ts]: PlanViewTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____LevelData = require("game.LevelData") -- 12
local getLevel = ____LevelData.getLevel -- 12
local installArcadeLevels = ____LevelData.installArcadeLevels -- 12
local scaledPlanets = ____LevelData.scaledPlanets -- 12
local ____Dora = require("Dora") -- 13
local Content = ____Dora.Content -- 13
local json = ____Dora.json -- 13
local ____PlanView = require("game.PlanView") -- 14
local arrivalRingRadius = ____PlanView.arrivalRingRadius -- 14
local computePlanMapping = ____PlanView.computePlanMapping -- 14
local planeToScreen = ____PlanView.planeToScreen -- 14
local planFitRadius = ____PlanView.planFitRadius -- 14
local screenToPlane = ____PlanView.screenToPlane -- 14
local failures = {} -- 21
local checks = 0 -- 22
local function check(name, ok, detail) -- 24
	checks = checks + 1 -- 25
	if not ok then -- 25
		failures[#failures + 1] = {name = name, detail = detail} -- 26
	end -- 26
end -- 24
--- 造一颗绕原点公转的行星。
local function orbiter(radius, orbitRadius) -- 30
	return { -- 31
		gm = 0, -- 32
		radius = radius, -- 32
		orbitCenter = {x = 0, y = 0}, -- 33
		orbitRadius = orbitRadius, -- 33
		orbitPeriod = orbitRadius > 0 and 1 or 0, -- 34
		phase0 = 0, -- 34
		orbitDirection = 1 -- 34
	} -- 34
end -- 30
--- 造一颗绕**别的天体**转的卫星（月球：圆心跟着地球走）。
local function satellite(radius, host, orbitRadius) -- 39
	return { -- 40
		gm = 0, -- 41
		radius = radius, -- 41
		orbitCenter = {x = 0, y = 0}, -- 42
		orbitRadius = orbitRadius, -- 42
		orbitPeriod = 10, -- 43
		phase0 = 0, -- 43
		orbitDirection = 1, -- 43
		host = host -- 43
	} -- 43
end -- 39
--- 1) 映射：等比、留白、退化半径兜底。
local function testMapping() -- 48
	local W = 601 -- 49
	local H = 1066 -- 50
	local R = 265 -- 51
	local m = computePlanMapping(W, H, R, 0.12) -- 52
	local expect = W * 0.76 / (2 * R) -- 55
	check( -- 56
		"map-width-limited", -- 56
		math.abs(m.scale - expect) < 1e-9, -- 56
		(("scale=" .. __TS__NumberToFixed(m.scale, 4)) .. " expect=") .. __TS__NumberToFixed(expect, 4) -- 56
	) -- 56
	check( -- 57
		"map-fits-height", -- 57
		R * m.scale <= H * 0.4 + 0.000001, -- 57
		(("R*scale=" .. __TS__NumberToFixed(R * m.scale, 1)) .. " halfH=") .. __TS__NumberToFixed(H * 0.4, 1) -- 57
	) -- 57
	local right = planeToScreen({x = R, y = 0}, m) -- 60
	local left = planeToScreen({x = -R, y = 0}, m) -- 61
	check( -- 62
		"map-margin-respected", -- 62
		right.x <= W * 0.88 + 0.000001 and left.x >= W * 0.12 - 0.000001, -- 63
		((((((("x=[" .. __TS__NumberToFixed(left.x, 1)) .. ",") .. __TS__NumberToFixed(right.x, 1)) .. "] limit=[") .. __TS__NumberToFixed(W * 0.12, 1)) .. ",") .. __TS__NumberToFixed(W * 0.88, 1)) .. "]" -- 63
	) -- 63
	local mLand = computePlanMapping(2024, 1230, 100, 0.12) -- 67
	check( -- 68
		"map-height-limited", -- 68
		math.abs(mLand.scale - 1230 * 0.76 / 200) < 1e-9, -- 68
		"scale=" .. __TS__NumberToFixed(mLand.scale, 4) -- 68
	) -- 68
	local cx = m.originX -- 71
	local cy = m.originY -- 72
	local px = planeToScreen({x = 40, y = 0}, m) -- 73
	local py = planeToScreen({x = 0, y = 40}, m) -- 74
	local dxx = px.x - cx -- 75
	local dxy = px.y - cy -- 76
	local dyx = py.x - cx -- 77
	local dyy = py.y - cy -- 78
	local rx = math.sqrt(dxx * dxx + dxy * dxy) -- 79
	local ry = math.sqrt(dyx * dyx + dyy * dyy) -- 80
	check( -- 81
		"map-no-distortion", -- 81
		math.abs(rx - ry) < 1e-9, -- 81
		(("rx=" .. __TS__NumberToFixed(rx, 4)) .. " ry=") .. __TS__NumberToFixed(ry, 4) -- 81
	) -- 81
	local m0 = computePlanMapping(W, H, 0, 0.12) -- 84
	check( -- 85
		"map-degenerate-radius", -- 85
		m0.scale > 0 and m0.scale < 1000000000, -- 85
		"scale=" .. tostring(m0.scale) -- 85
	) -- 85
	local mBig = computePlanMapping(W, H, 100, 0.9) -- 87
	check( -- 88
		"map-margin-clamped", -- 88
		mBig.scale > 0 and mBig.scale < 1000000000, -- 88
		"scale=" .. tostring(mBig.scale) -- 88
	) -- 88
end -- 48
--- 2) 平面 → 屏幕：中心对原点、**y 反向**、可逆。
local function testPlaneToScreen() -- 92
	local W = 601 -- 93
	local H = 1066 -- 94
	local m = computePlanMapping(W, H, 100, 0.12) -- 95
	local o = planeToScreen({x = 0, y = 0}, m) -- 97
	check( -- 98
		"screen-origin-at-center", -- 98
		o.x == W / 2 and o.y == H / 2, -- 98
		((((((("(" .. tostring(o.x)) .. ",") .. tostring(o.y)) .. ") expect=(") .. tostring(W / 2)) .. ",") .. tostring(H / 2)) .. ")" -- 98
	) -- 98
	local up = planeToScreen({x = 0, y = 50}, m) -- 101
	local down = planeToScreen({x = 0, y = -50}, m) -- 102
	check( -- 103
		"screen-y-flipped", -- 103
		up.y < o.y and down.y > o.y, -- 103
		(((("plane+50 -> y=" .. __TS__NumberToFixed(up.y, 1)) .. " plane-50 -> y=") .. __TS__NumberToFixed(down.y, 1)) .. " center=") .. tostring(o.y) -- 103
	) -- 103
	local p = {x = 37.5, y = -18.25} -- 106
	local back = screenToPlane( -- 107
		planeToScreen(p, m), -- 107
		m -- 107
	) -- 107
	check( -- 108
		"screen-roundtrip", -- 108
		math.abs(back.x - p.x) < 1e-9 and math.abs(back.y - p.y) < 1e-9, -- 108
		((((((("(" .. tostring(back.x)) .. ",") .. tostring(back.y)) .. ") vs (") .. tostring(p.x)) .. ",") .. tostring(p.y)) .. ")" -- 108
	) -- 108
end -- 92
--- 3) 视野半径：最外圈轨道 + 目标容差（含卫星的宿主链）。
local function testFitRadius() -- 112
	local sun = orbiter(28, 0) -- 114
	local earth = orbiter(1.76, 80) -- 115
	local moon = satellite(1, earth, 15) -- 116
	local fit1 = planFitRadius({sun, earth, moon}, {x = 0, y = 90}, 2, 5) -- 117
	local expect1 = 80 + 15 + 5 -- 118
	check( -- 119
		"fit-l1-moon-host-chain", -- 119
		math.abs(fit1 - expect1) < 1e-9, -- 119
		(("fit=" .. __TS__NumberToFixed(fit1, 2)) .. " expect=") .. tostring(expect1) -- 119
	) -- 119
	local jup = orbiter(4.63, 105) -- 122
	local sat = orbiter(4.3, 135) -- 123
	local ura = orbiter(3.04, 165) -- 124
	local nep = orbiter(3, 195) -- 125
	local fit6 = planFitRadius( -- 126
		{ -- 126
			sun, -- 126
			orbiter(1.76, 80), -- 126
			jup, -- 126
			sat, -- 126
			ura, -- 126
			nep -- 126
		}, -- 126
		{x = 0, y = 80}, -- 126
		5, -- 126
		70 -- 126
	) -- 126
	check( -- 127
		"fit-l6-outer-orbit-plus-tolerance", -- 127
		math.abs(fit6 - 265) < 1e-9, -- 127
		("fit=" .. __TS__NumberToFixed(fit6, 2)) .. " expect=265" -- 127
	) -- 127
	local fitProbe = planFitRadius( -- 130
		{orbiter(1, 10)}, -- 130
		{x = 0, y = 300}, -- 130
		0, -- 130
		0 -- 130
	) -- 130
	check( -- 131
		"fit-includes-probe", -- 131
		fitProbe >= 300, -- 131
		"fit=" .. __TS__NumberToFixed(fitProbe, 2) -- 131
	) -- 131
	local fitEmpty = planFitRadius({}, {x = 0, y = 0}, -1, 0) -- 134
	check( -- 135
		"fit-nonzero", -- 135
		fitEmpty > 0 and fitEmpty < 1000000000, -- 135
		"fit=" .. tostring(fitEmpty) -- 135
	) -- 135
	local l1 = getLevel(0) -- 138
	if l1 == nil then -- 138
		check("fit-real-l1", false, "getLevel(0) 返回 undefined") -- 140
	else -- 140
		local real1 = planFitRadius( -- 142
			scaledPlanets(l1), -- 142
			l1.probeStart, -- 142
			l1.goal.planetIndex, -- 142
			l1.goal.tolerance, -- 142
			l1.planCenter -- 142
		) -- 142
		local probeR = math.sqrt(l1.probeStart.x * l1.probeStart.x + l1.probeStart.y * l1.probeStart.y) -- 143
		check( -- 144
			"fit-real-l1-covers-probe", -- 144
			real1 + 0.000001 >= probeR, -- 144
			(("L1 fit=" .. __TS__NumberToFixed(real1, 1)) .. " 待命轨道=") .. __TS__NumberToFixed(probeR, 1) -- 144
		) -- 144
	end -- 144
	local l3 = getLevel(2) -- 147
	if l3 == nil then -- 147
		check("fit-real-l3", false, "getLevel(2) 返回 undefined") -- 149
	else -- 149
		local real3 = planFitRadius( -- 151
			scaledPlanets(l3), -- 151
			l3.probeStart, -- 151
			l3.goal.planetIndex, -- 151
			l3.goal.tolerance -- 151
		) -- 151
		check( -- 152
			"fit-real-l3", -- 152
			real3 > 0, -- 152
			"L3 fit=" .. __TS__NumberToFixed(real3, 2) -- 152
		) -- 152
	end -- 152
end -- 112
--- S5 §3.8 规则 3：2D 到达圈画的必须是**真实容差**，不是视觉半径。
local function testArrivalRingIsRealTolerance() -- 157
	local l1 = getLevel(0) -- 158
	if l1 == nil then -- 158
		check("ring-l1", false, "getLevel(0) undefined") -- 159
		return -- 159
	end -- 159
	check( -- 160
		"ring-l1-equals-tolerance", -- 160
		math.abs(arrivalRingRadius(l1.goal) - l1.goal.tolerance) < 1e-12, -- 160
		(("ring=" .. tostring(arrivalRingRadius(l1.goal))) .. " tol=") .. tostring(l1.goal.tolerance) -- 160
	) -- 160
	local ringBefore = arrivalRingRadius(l1.goal) -- 165
	local vi = l1.goal.planetIndex -- 166
	local savedRadius = l1.visuals[vi + 1].displayRadius -- 167
	l1.visuals[vi + 1].displayRadius = savedRadius * 3 + 1 -- 168
	local ringAfter = arrivalRingRadius(l1.goal) -- 169
	l1.visuals[vi + 1].displayRadius = savedRadius -- 170
	check( -- 171
		"ring-l1-ignores-visual-radius", -- 171
		ringBefore == ringAfter, -- 171
		((((((("ring=" .. tostring(ringBefore)) .. " -> ") .. tostring(ringAfter)) .. "（视觉半径从 ") .. tostring(savedRadius)) .. " 改成 ") .. tostring(savedRadius * 3 + 1)) .. " 后到达圈必须不变）" -- 171
	) -- 171
	local l6 = getLevel(5) -- 174
	if l6 ~= nil then -- 174
		check( -- 176
			"ring-l6-chain-max", -- 176
			math.abs(arrivalRingRadius(l6.goal) - 120) < 1e-9, -- 176
			("ring=" .. tostring(arrivalRingRadius(l6.goal))) .. "（链上最大容差）" -- 176
		) -- 176
	end -- 176
end -- 157
function ____exports.runTests() -- 181
	local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 182
	local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 183
	installArcadeLevels( -- 184
		levelsText, -- 184
		bodiesText, -- 184
		function(text) -- 184
			local decoded = {json.decode(text)} -- 185
			if decoded[2] ~= nil then -- 185
				return nil -- 186
			end -- 186
			return decoded[1] -- 187
		end -- 184
	) -- 184
	testArrivalRingIsRealTolerance() -- 189
	testMapping() -- 190
	testPlaneToScreen() -- 191
	testFitRadius() -- 192
	local lines = {} -- 194
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 195
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 196
	local limit = #failures < 12 and #failures or 12 -- 197
	do -- 197
		local i = 0 -- 198
		while i < limit do -- 198
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 199
			i = i + 1 -- 198
		end -- 198
	end -- 198
	return table.concat(lines, "\n") -- 201
end -- 181
return ____exports -- 181
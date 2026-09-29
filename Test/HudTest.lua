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
local resultPanelLayout = ____Hud.resultPanelLayout -- 8
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
-- 投影偏移空间 +Y 向上（修正后），且修正后的渲染方向是：
-- 平面 -y（朝目标）在屏幕**上方**。所以：
--  触摸在探测器**上方**（offset.y 更大 → dy > 0）→ 平面 -y（朝目标）
--  触摸在探测器**下方**（dy < 0）→ 平面 +y（背离目标）
local function testDirection() -- 43
	local up = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + 200}, 300) -- 45
	check( -- 46
		"dir-up-toward-goal", -- 46
		up.velocity.y < -1, -- 46
		("vy=" .. __TS__NumberToFixed(up.velocity.y, 2)) .. "（应为负 = 朝目标）" -- 46
	) -- 46
	local down = computeAim(PROBE, {x = PROBE.x, y = PROBE.y - 200}, 300) -- 49
	check( -- 50
		"dir-down", -- 50
		down.velocity.y > 1, -- 50
		("vy=" .. __TS__NumberToFixed(down.velocity.y, 2)) .. "（应为正）" -- 50
	) -- 50
	local right = computeAim(PROBE, {x = PROBE.x + 200, y = PROBE.y}, 300) -- 53
	check( -- 54
		"dir-right", -- 54
		right.velocity.x > 1 and math.abs(right.velocity.y) < 1e-9, -- 54
		((("v=(" .. __TS__NumberToFixed(right.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(right.velocity.y, 2)) .. ")" -- 54
	) -- 54
	local u = math.sqrt(up.unit.x * up.unit.x + up.unit.y * up.unit.y) -- 57
	check( -- 58
		"unit-length", -- 58
		math.abs(u - 1) < 1e-9, -- 58
		"|unit|=" .. tostring(u) -- 58
	) -- 58
end -- 43
--- 3) 力度：随拖动距离线性增长并夹紧到 1。
local function testPower() -- 62
	local maxDrag = defaultMaxDragPx() -- 63
	local half = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag / 2}, maxDrag) -- 66
	check( -- 67
		"power-half", -- 67
		math.abs(half.power - 0.5) < 0.000001, -- 67
		"power=" .. tostring(half.power) -- 67
	) -- 67
	local full = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag}, maxDrag) -- 70
	check( -- 71
		"power-full", -- 71
		math.abs(full.power - 1) < 0.000001, -- 71
		"power=" .. tostring(full.power) -- 71
	) -- 71
	local over = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag * 3}, maxDrag) -- 74
	check( -- 75
		"power-clamped", -- 75
		over.power == 1, -- 75
		"power=" .. tostring(over.power) -- 75
	) -- 75
	local overSpeed = math.sqrt(over.velocity.x * over.velocity.x + over.velocity.y * over.velocity.y) -- 76
	check( -- 77
		"speed-clamped", -- 77
		math.abs(overSpeed - AimMaxSpeed) < 0.000001, -- 77
		(("speed=" .. tostring(overSpeed)) .. " expected=") .. tostring(AimMaxSpeed) -- 77
	) -- 77
	local monotonic = true -- 80
	local prev = -1 -- 81
	for ____, f in ipairs({ -- 82
		0, -- 82
		0.25, -- 82
		0.5, -- 82
		0.75, -- 82
		1 -- 82
	}) do -- 82
		local r = computeAim(PROBE, {x = PROBE.x, y = PROBE.y + maxDrag * f}, maxDrag) -- 83
		local s = math.sqrt(r.velocity.x * r.velocity.x + r.velocity.y * r.velocity.y) -- 84
		if s < prev - 1e-9 then -- 84
			monotonic = false -- 85
			break -- 85
		end -- 85
		prev = s -- 86
	end -- 86
	check("speed-monotonic", monotonic, "速度未随力度单调增长") -- 88
end -- 62
--- 4) screenToPlane 与 project() 互逆（验证反投影公式正确）。
local function testRoundTrip() -- 92
	local cam = { -- 93
		eye = {x = 0, y = 21.2, z = 21.2}, -- 94
		target = {x = 0, y = 0, z = 0}, -- 95
		up = {x = 0, y = 1, z = 0}, -- 96
		fovYDeg = 45, -- 97
		aspect = 0.5625, -- 98
		viewW = 1080, -- 99
		viewH = 1920 -- 100
	} -- 100
	local basis = prepareCamera(cam, HANDEDNESS, FLIP_Y) -- 102
	local pts = {{x = 0, y = 0}, {x = 5, y = -8}, {x = -6, y = 4}} -- 105
	local maxErr = 0 -- 111
	for ____, p in ipairs(pts) do -- 112
		local world = {x = p.x, y = 0, z = p.y} -- 113
		local proj = project(world, cam, HANDEDNESS, FLIP_Y) -- 114
		if proj == nil then -- 114
			maxErr = 1000000000 -- 115
			break -- 115
		end -- 115
		local back = screenToPlane({x = proj.x, y = proj.y}, basis) -- 117
		if back == nil then -- 117
			maxErr = 1000000000 -- 118
			break -- 118
		end -- 118
		local dx = back.x - p.x -- 119
		local dy = back.y - p.y -- 120
		local e = math.sqrt(dx * dx + dy * dy) -- 121
		if e > maxErr then -- 121
			maxErr = e -- 122
		end -- 122
	end -- 122
	check( -- 124
		"screen-plane-roundtrip", -- 124
		maxErr < 0.000001, -- 124
		("maxErr=" .. __TS__NumberToFixed(maxErr, 12)) .. "（应接近 0）" -- 124
	) -- 124
end -- 92
--- 5) 坐标换算：局部坐标 ↔ 投影偏移空间应互逆，且语义正确。
local function testSpaceConversion() -- 128
	local space = {viewW = 1080, viewH = 1920} -- 129
	local center = localToOffset({x = 540, y = 960}, space) -- 132
	check( -- 133
		"space-center", -- 133
		math.abs(center.x) < 1e-9 and math.abs(center.y) < 1e-9, -- 133
		((("offset=(" .. tostring(center.x)) .. ", ") .. tostring(center.y)) .. ")" -- 133
	) -- 133
	local bl = localToOffset({x = 0, y = 0}, space) -- 136
	check( -- 137
		"space-bottom-left", -- 137
		math.abs(bl.x + 540) < 1e-9 and math.abs(bl.y + 960) < 1e-9, -- 137
		((("offset=(" .. tostring(bl.x)) .. ", ") .. tostring(bl.y)) .. ")" -- 137
	) -- 137
	local tl = localToOffset({x = 0, y = 1920}, space) -- 140
	check( -- 141
		"space-top-left", -- 141
		math.abs(tl.x + 540) < 1e-9 and math.abs(tl.y - 960) < 1e-9, -- 141
		((("offset=(" .. tostring(tl.x)) .. ", ") .. tostring(tl.y)) .. ")" -- 141
	) -- 141
	local allExact = true -- 144
	for ____, p in ipairs({{x = 100, y = 200}, {x = 0, y = 0}, {x = -300, y = 150}}) do -- 145
		local back = offsetToLocal( -- 146
			localToOffset(p, space), -- 146
			space -- 146
		) -- 146
		if math.abs(back.x - p.x) > 1e-9 or math.abs(back.y - p.y) > 1e-9 then -- 146
			allExact = false -- 147
			break -- 147
		end -- 147
	end -- 147
	check("space-roundtrip", allExact, "localToOffset / offsetToLocal 不互逆") -- 149
end -- 128
--- 6) 结算卡与操作按钮始终落在竖屏视口内。
local function testResultPanelLayout() -- 153
	for ____, size in ipairs({ -- 154
		{w = 280, h = 400}, -- 154
		{w = 320, h = 568}, -- 154
		{w = 360, h = 640}, -- 154
		{w = 390, h = 844}, -- 154
		{w = 430, h = 932} -- 154
	}) do -- 154
		local layout = resultPanelLayout(size.w, size.h) -- 155
		check( -- 156
			"result-card-inside-" .. tostring(size.w), -- 156
			layout.cardX >= 0 and layout.cardX + layout.cardW <= size.w, -- 156
			(((("x=" .. tostring(layout.cardX)) .. " w=") .. tostring(layout.cardW)) .. " view=") .. tostring(size.w) -- 156
		) -- 156
		check( -- 157
			"result-card-height-" .. tostring(size.h), -- 157
			layout.cardY >= 0 and layout.cardY + layout.cardH <= size.h, -- 157
			(((("y=" .. tostring(layout.cardY)) .. " h=") .. tostring(layout.cardH)) .. " view=") .. tostring(size.h) -- 157
		) -- 157
		local buttonX = layout.cardX + (layout.cardW - layout.buttonW) / 2 -- 158
		check( -- 159
			"result-buttons-inside-" .. tostring(size.w), -- 159
			buttonX >= 0 and buttonX + layout.buttonW <= size.w, -- 159
			(((("x=" .. tostring(buttonX)) .. " w=") .. tostring(layout.buttonW)) .. " view=") .. tostring(size.w) -- 159
		) -- 159
		check( -- 160
			"result-button-target-" .. tostring(size.h), -- 160
			layout.buttonH >= 48, -- 160
			"buttonH=" .. tostring(layout.buttonH) -- 160
		) -- 160
	end -- 160
end -- 153
function ____exports.runTests() -- 164
	testNoDrag() -- 165
	testDirection() -- 166
	testPower() -- 167
	testRoundTrip() -- 168
	testSpaceConversion() -- 169
	testResultPanelLayout() -- 170
	local lines = {} -- 172
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 173
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 174
	local limit = #failures < 12 and #failures or 12 -- 175
	do -- 175
		local i = 0 -- 176
		while i < limit do -- 176
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 177
			i = i + 1 -- 176
		end -- 176
	end -- 176
	return table.concat(lines, "\n") -- 179
end -- 164
return ____exports -- 164
-- [ts]: OrbitFlowTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local __TS__ArraySort = ____lualib.__TS__ArraySort -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 13
local bodyPositionAt = ____Gravity.bodyPositionAt -- 13
local ____OrbitFlow = require("game.OrbitFlow") -- 14
local FlowDotsPerOrbit = ____OrbitFlow.FlowDotsPerOrbit -- 15
local flowDotAngle = ____OrbitFlow.flowDotAngle -- 15
local flowDotPosition = ____OrbitFlow.flowDotPosition -- 15
local orbitAngularRate = ____OrbitFlow.orbitAngularRate -- 15
local orbitCenterAt = ____OrbitFlow.orbitCenterAt -- 15
local ____LevelData = require("game.LevelData") -- 17
local getLevel = ____LevelData.getLevel -- 17
local levelCount = ____LevelData.levelCount -- 17
local scaledPlanets = ____LevelData.scaledPlanets -- 17
local ____Scale = require("game.Scale") -- 18
local SunGm = ____Scale.SunGm -- 18
local failures = {} -- 25
local checks = 0 -- 26
local function check(name, ok, detail) -- 28
	checks = checks + 1 -- 29
	if not ok then -- 29
		failures[#failures + 1] = {name = name, detail = detail} -- 30
	end -- 30
end -- 28
--- 度 → 弧度。
local function deg(d) -- 34
	return d * math.pi / 180 -- 35
end -- 34
--- 造一颗绕原点公转的天体（dir = +1 顺行 / -1 逆行）。
local function orbiter(orbitRadius, period, dir, phaseDeg) -- 39
	return { -- 40
		gm = 0, -- 41
		radius = 1, -- 41
		orbitCenter = {x = 0, y = 0}, -- 42
		orbitRadius = orbitRadius, -- 43
		orbitPeriod = period, -- 43
		phase0 = deg(phaseDeg), -- 44
		orbitDirection = dir -- 44
	} -- 44
end -- 39
--- 造一颗绕**会动的宿主**的卫星（圆心 = 宿主此刻的位置）。
local function satellite(host, orbitRadius, period) -- 49
	return { -- 50
		gm = 0, -- 51
		radius = 1, -- 51
		orbitCenter = {x = 0, y = 0}, -- 52
		orbitRadius = orbitRadius, -- 53
		orbitPeriod = period, -- 53
		phase0 = 0, -- 54
		orbitDirection = 1, -- 54
		host = host -- 54
	} -- 54
end -- 49
--- 1) 第 0 个光点 == 行星位置（与物理几何不可能分家）。
local function testDotZeroOnPlanet() -- 59
	local b = orbiter(80, 700, 1, 37) -- 60
	local host = orbiter(80, 700, 1, 10) -- 61
	local moon = satellite(host, 15, 120) -- 62
	for ____, t in ipairs({0, 1, 7.5, 123.25}) do -- 63
		local dot = flowDotPosition(b, t, 0, FlowDotsPerOrbit) -- 64
		local planet = bodyPositionAt(b, t) -- 65
		check( -- 66
			"dot0-equals-planet", -- 66
			math.abs(dot.x - planet.x) < 1e-9 and math.abs(dot.y - planet.y) < 1e-9, -- 67
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(dot.x, 4)) .. ",") .. __TS__NumberToFixed(dot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(planet.x, 4)) .. ",") .. __TS__NumberToFixed(planet.y, 4)) .. ")" -- 68
		) -- 68
		local mdot = flowDotPosition(moon, t, 0, FlowDotsPerOrbit) -- 70
		local mplanet = bodyPositionAt(moon, t) -- 71
		check( -- 72
			"dot0-equals-planet-host-chain", -- 72
			math.abs(mdot.x - mplanet.x) < 1e-9 and math.abs(mdot.y - mplanet.y) < 1e-9, -- 73
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(mdot.x, 4)) .. ",") .. __TS__NumberToFixed(mdot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(mplanet.x, 4)) .. ",") .. __TS__NumberToFixed(mplanet.y, 4)) .. ")" -- 74
		) -- 74
	end -- 74
end -- 59
--- 2) 光点均匀分布、且全部落在轨道上（半径 = orbitRadius，圆心 = 宿主/轨道圆心）。
local function testDotsOnOrbit() -- 79
	local b = orbiter(105, 1076, 1, 0) -- 80
	local host = orbiter(80, 700, 1, 200) -- 81
	local moon = satellite(host, 15, 120) -- 82
	local t = 42 -- 83
	local c = orbitCenterAt(b, t) -- 84
	local okSpacing = true -- 85
	local okRadius = true -- 86
	local okWrap = true -- 87
	do -- 87
		local k = 0 -- 88
		while k < FlowDotsPerOrbit do -- 88
			local a0 = flowDotAngle(b, t, k, FlowDotsPerOrbit) -- 89
			if k + 1 < FlowDotsPerOrbit then -- 89
				local a1 = flowDotAngle(b, t, k + 1, FlowDotsPerOrbit) -- 91
				if math.abs(a1 - a0 - 2 * math.pi / FlowDotsPerOrbit) > 1e-9 then -- 91
					okSpacing = false -- 92
				end -- 92
			else -- 92
				local wrapped = flowDotAngle(b, t, FlowDotsPerOrbit, FlowDotsPerOrbit) -- 95
				if math.abs(wrapped - flowDotAngle(b, t, 0, FlowDotsPerOrbit)) > 1e-9 then -- 95
					okWrap = false -- 96
				end -- 96
			end -- 96
			local p = flowDotPosition(b, t, k, FlowDotsPerOrbit) -- 98
			local d = math.sqrt((p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y)) -- 99
			if math.abs(d - 105) > 1e-9 then -- 99
				okRadius = false -- 100
			end -- 100
			k = k + 1 -- 88
		end -- 88
	end -- 88
	check( -- 102
		"dot-spacing-uniform", -- 102
		okSpacing, -- 102
		("step=" .. __TS__NumberToFixed(2 * math.pi / FlowDotsPerOrbit, 4)) .. " rad" -- 102
	) -- 102
	check("dot-chain-closes", okWrap, "dot N wraps back to dot 0") -- 103
	check("dots-on-orbit", okRadius, "every dot at distance orbitRadius from center") -- 104
	local mc = orbitCenterAt(moon, t) -- 106
	local hp = bodyPositionAt(host, t) -- 107
	check( -- 108
		"center-follows-host", -- 108
		math.abs(mc.x - hp.x) < 1e-9 and math.abs(mc.y - hp.y) < 1e-9, -- 109
		((((((("center=(" .. __TS__NumberToFixed(mc.x, 3)) .. ",") .. __TS__NumberToFixed(mc.y, 3)) .. ") host=(") .. __TS__NumberToFixed(hp.x, 3)) .. ",") .. __TS__NumberToFixed(hp.y, 3)) .. ")" -- 110
	) -- 110
end -- 79
--- 3) 方向 = orbitDirection（顺行逆时针、逆行顺时针；不写死）。
local function testDirectionFromField() -- 114
	local pro = orbiter(55, 400, 1, 0) -- 115
	local retro = orbiter(55, 400, -1, 0) -- 116
	local dt = 5 -- 117
	local dPro = flowDotAngle(pro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(pro, 0, 0, FlowDotsPerOrbit) -- 118
	local dRetro = flowDotAngle(retro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(retro, 0, 0, FlowDotsPerOrbit) -- 119
	check( -- 120
		"direction-prograde", -- 120
		dPro > 0, -- 120
		((("delta=" .. __TS__NumberToFixed(dPro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 120
	) -- 120
	check( -- 121
		"direction-retrograde", -- 121
		dRetro < 0, -- 121
		((("delta=" .. __TS__NumberToFixed(dRetro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 121
	) -- 121
	local allPro = true -- 123
	local allRetro = true -- 124
	do -- 124
		local k = 0 -- 125
		while k < FlowDotsPerOrbit do -- 125
			if flowDotAngle(pro, dt, k, FlowDotsPerOrbit) - flowDotAngle(pro, 0, k, FlowDotsPerOrbit) <= 0 then -- 125
				allPro = false -- 126
			end -- 126
			if flowDotAngle(retro, dt, k, FlowDotsPerOrbit) - flowDotAngle(retro, 0, k, FlowDotsPerOrbit) >= 0 then -- 126
				allRetro = false -- 127
			end -- 127
			k = k + 1 -- 125
		end -- 125
	end -- 125
	check("direction-whole-chain", allPro and allRetro, "every dot of the chain flows the same way") -- 129
end -- 114
--- 4) 快慢 ∝ 角速度：delta = omega*dt（精确等式），且周期 4 倍的天体慢 4 倍。
local function testSpeedProportionalToOmega() -- 133
	local fast = orbiter(55, 400, 1, 0) -- 134
	local slow = orbiter(195, 1600, 1, 0) -- 135
	local dt = 3.7 -- 136
	local dFast = flowDotAngle(fast, dt, 0, FlowDotsPerOrbit) - flowDotAngle(fast, 0, 0, FlowDotsPerOrbit) -- 137
	local dSlow = flowDotAngle(slow, dt, 0, FlowDotsPerOrbit) - flowDotAngle(slow, 0, 0, FlowDotsPerOrbit) -- 138
	check( -- 139
		"speed-equals-omega-times-dt", -- 139
		math.abs(dFast - orbitAngularRate(fast) * dt) < 1e-9 and math.abs(dSlow - orbitAngularRate(slow) * dt) < 1e-9, -- 140
		((("fast=" .. __TS__NumberToFixed(dFast, 5)) .. " slow=") .. __TS__NumberToFixed(dSlow, 5)) .. " rad" -- 141
	) -- 141
	check( -- 142
		"speed-quarter-period-quarter-angle", -- 142
		math.abs(dFast / dSlow - 4) < 1e-9, -- 143
		("ratio=" .. __TS__NumberToFixed(dFast / dSlow, 4)) .. " expect=4（T 4 倍 => 角速度 1/4）" -- 144
	) -- 144
	local vFast = math.abs(orbitAngularRate(fast)) * 55 -- 146
	local vSlow = math.abs(orbitAngularRate(slow)) * 195 -- 147
	check( -- 148
		"linear-speed-inner-faster", -- 148
		vFast > vSlow, -- 148
		(("v(55)=" .. __TS__NumberToFixed(vFast, 4)) .. " v(195)=") .. __TS__NumberToFixed(vSlow, 4) -- 148
	) -- 148
end -- 133
--- 5) 静止天体（太阳 / orbitPeriod = 0）：没有可流动的轨道，角速度 0、光点不动。
local function testStaticBody() -- 152
	local sun = orbiter(28, 0, 1, 0) -- 153
	check( -- 154
		"static-zero-rate", -- 154
		orbitAngularRate(sun) == 0, -- 154
		"orbitPeriod=0 => omega=0" -- 154
	) -- 154
	local a0 = flowDotAngle(sun, 0, 3, FlowDotsPerOrbit) -- 155
	local a1 = flowDotAngle(sun, 999, 3, FlowDotsPerOrbit) -- 156
	check( -- 157
		"static-dots-frozen", -- 157
		a0 == a1, -- 157
		"angle stays " .. __TS__NumberToFixed(a0, 4) -- 157
	) -- 157
end -- 152
--- 6) 位置是 t 的**纯函数**（同一个 t 两次调用逐位一致）；拨日期光点必须动。
local function testPureFunctionOfTime() -- 161
	local b = orbiter(135, 1569, 1, 88) -- 162
	local p1 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 163
	local p2 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 164
	check( -- 165
		"pure-function-of-t", -- 165
		p1.x == p2.x and p1.y == p2.y, -- 165
		((("(" .. __TS__NumberToFixed(p1.x, 6)) .. ",") .. __TS__NumberToFixed(p1.y, 6)) .. ")" -- 165
	) -- 165
	local moved = flowDotPosition(b, 12.5 + 30, 2, FlowDotsPerOrbit) -- 166
	local dist = math.sqrt((moved.x - p1.x) * (moved.x - p1.x) + (moved.y - p1.y) * (moved.y - p1.y)) -- 167
	check( -- 168
		"dots-move-with-date", -- 168
		dist > 1, -- 168
		("30s 后同一点移动了 " .. __TS__NumberToFixed(dist, 2)) .. " 单位" -- 168
	) -- 168
end -- 161
--- 7) 真实关卡数据（唯一事实来源）：六关都有可流动的轨道，|omega| 随半径严格递减（开普勒）。
local function testRealLevels() -- 172
	local allHaveOrbits = true -- 173
	local keplerOk = true -- 174
	local orderOk = true -- 175
	local detail = {} -- 176
	local count = levelCount() -- 177
	do -- 177
		local li = 0 -- 178
		while li < count do -- 178
			do -- 178
				local lv = getLevel(li) -- 179
				if lv == nil then -- 179
					allHaveOrbits = false -- 181
					goto __continue28 -- 182
				end -- 182
				local bodies = scaledPlanets(lv) -- 184
				local movers = {} -- 185
				for ____, b in ipairs(bodies) do -- 186
					if b.orbitRadius > 0 and b.orbitPeriod > 0 then -- 186
						movers[#movers + 1] = b -- 187
					end -- 187
				end -- 187
				for ____, b in ipairs(movers) do -- 190
					local mu = b.host ~= nil and b.host.gm or SunGm -- 191
					local om = math.abs(orbitAngularRate(b)) -- 192
					local kk = om * om * b.orbitRadius * b.orbitRadius * b.orbitRadius -- 193
					if math.abs(kk - mu) > math.abs(mu) * 1e-9 then -- 193
						keplerOk = false -- 194
					end -- 194
				end -- 194
				local sorted = __TS__ArraySort( -- 197
					__TS__ArraySlice(movers), -- 197
					function(____, a, b2) return a.orbitRadius - b2.orbitRadius end -- 197
				) -- 197
				do -- 197
					local i = 1 -- 198
					while i < #sorted do -- 198
						if not (math.abs(orbitAngularRate(sorted[i + 1])) < math.abs(orbitAngularRate(sorted[i]))) then -- 198
							orderOk = false -- 199
						end -- 199
						i = i + 1 -- 198
					end -- 198
				end -- 198
				detail[#detail + 1] = (("L" .. tostring(lv.id)) .. ":") .. tostring(#movers) -- 201
			end -- 201
			::__continue28:: -- 201
			li = li + 1 -- 178
		end -- 178
	end -- 178
	check( -- 203
		"levels-flow-orbits-inspected", -- 203
		true, -- 203
		"movers per level = " .. table.concat(detail, " ") -- 203
	) -- 203
	check("kepler-third-law", keplerOk, "omega^2 * r^3 = mu_host for every orbit（真开普勒，S5 归正）") -- 204
	check("inner-orbit-faster", orderOk, "|omega| strictly decreases with orbit radius") -- 205
end -- 172
function ____exports.runTests() -- 208
	testDotZeroOnPlanet() -- 209
	testDotsOnOrbit() -- 210
	testDirectionFromField() -- 211
	testSpeedProportionalToOmega() -- 212
	testStaticBody() -- 213
	testPureFunctionOfTime() -- 214
	testRealLevels() -- 215
	local lines = {} -- 217
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 218
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 219
	local limit = #failures < 12 and #failures or 12 -- 220
	do -- 220
		local i = 0 -- 221
		while i < limit do -- 221
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 222
			i = i + 1 -- 221
		end -- 221
	end -- 221
	return table.concat(lines, "\n") -- 224
end -- 208
return ____exports -- 208
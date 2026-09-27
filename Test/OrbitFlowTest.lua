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
local scaledPlanets = ____LevelData.scaledPlanets -- 17
local failures = {} -- 24
local checks = 0 -- 25
local function check(name, ok, detail) -- 27
	checks = checks + 1 -- 28
	if not ok then -- 28
		failures[#failures + 1] = {name = name, detail = detail} -- 29
	end -- 29
end -- 27
--- 度 → 弧度。
local function deg(d) -- 33
	return d * math.pi / 180 -- 34
end -- 33
--- 造一颗绕原点公转的天体（dir = +1 顺行 / -1 逆行）。
local function orbiter(orbitRadius, period, dir, phaseDeg) -- 38
	return { -- 39
		gm = 0, -- 40
		radius = 1, -- 40
		orbitCenter = {x = 0, y = 0}, -- 41
		orbitRadius = orbitRadius, -- 42
		orbitPeriod = period, -- 42
		phase0 = deg(phaseDeg), -- 43
		orbitDirection = dir -- 43
	} -- 43
end -- 38
--- 造一颗绕**会动的宿主**的卫星（圆心 = 宿主此刻的位置）。
local function satellite(host, orbitRadius, period) -- 48
	return { -- 49
		gm = 0, -- 50
		radius = 1, -- 50
		orbitCenter = {x = 0, y = 0}, -- 51
		orbitRadius = orbitRadius, -- 52
		orbitPeriod = period, -- 52
		phase0 = 0, -- 53
		orbitDirection = 1, -- 53
		host = host -- 53
	} -- 53
end -- 48
--- 1) 第 0 个光点 == 行星位置（与物理几何不可能分家）。
local function testDotZeroOnPlanet() -- 58
	local b = orbiter(80, 700, 1, 37) -- 59
	local host = orbiter(80, 700, 1, 10) -- 60
	local moon = satellite(host, 15, 120) -- 61
	for ____, t in ipairs({0, 1, 7.5, 123.25}) do -- 62
		local dot = flowDotPosition(b, t, 0, FlowDotsPerOrbit) -- 63
		local planet = bodyPositionAt(b, t) -- 64
		check( -- 65
			"dot0-equals-planet", -- 65
			math.abs(dot.x - planet.x) < 1e-9 and math.abs(dot.y - planet.y) < 1e-9, -- 66
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(dot.x, 4)) .. ",") .. __TS__NumberToFixed(dot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(planet.x, 4)) .. ",") .. __TS__NumberToFixed(planet.y, 4)) .. ")" -- 67
		) -- 67
		local mdot = flowDotPosition(moon, t, 0, FlowDotsPerOrbit) -- 69
		local mplanet = bodyPositionAt(moon, t) -- 70
		check( -- 71
			"dot0-equals-planet-host-chain", -- 71
			math.abs(mdot.x - mplanet.x) < 1e-9 and math.abs(mdot.y - mplanet.y) < 1e-9, -- 72
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(mdot.x, 4)) .. ",") .. __TS__NumberToFixed(mdot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(mplanet.x, 4)) .. ",") .. __TS__NumberToFixed(mplanet.y, 4)) .. ")" -- 73
		) -- 73
	end -- 73
end -- 58
--- 2) 光点均匀分布、且全部落在轨道上（半径 = orbitRadius，圆心 = 宿主/轨道圆心）。
local function testDotsOnOrbit() -- 78
	local b = orbiter(105, 1076, 1, 0) -- 79
	local host = orbiter(80, 700, 1, 200) -- 80
	local moon = satellite(host, 15, 120) -- 81
	local t = 42 -- 82
	local c = orbitCenterAt(b, t) -- 83
	local okSpacing = true -- 84
	local okRadius = true -- 85
	local okWrap = true -- 86
	do -- 86
		local k = 0 -- 87
		while k < FlowDotsPerOrbit do -- 87
			local a0 = flowDotAngle(b, t, k, FlowDotsPerOrbit) -- 88
			if k + 1 < FlowDotsPerOrbit then -- 88
				local a1 = flowDotAngle(b, t, k + 1, FlowDotsPerOrbit) -- 90
				if math.abs(a1 - a0 - 2 * math.pi / FlowDotsPerOrbit) > 1e-9 then -- 90
					okSpacing = false -- 91
				end -- 91
			else -- 91
				local wrapped = flowDotAngle(b, t, FlowDotsPerOrbit, FlowDotsPerOrbit) -- 94
				if math.abs(wrapped - flowDotAngle(b, t, 0, FlowDotsPerOrbit)) > 1e-9 then -- 94
					okWrap = false -- 95
				end -- 95
			end -- 95
			local p = flowDotPosition(b, t, k, FlowDotsPerOrbit) -- 97
			local d = math.sqrt((p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y)) -- 98
			if math.abs(d - 105) > 1e-9 then -- 98
				okRadius = false -- 99
			end -- 99
			k = k + 1 -- 87
		end -- 87
	end -- 87
	check( -- 101
		"dot-spacing-uniform", -- 101
		okSpacing, -- 101
		("step=" .. __TS__NumberToFixed(2 * math.pi / FlowDotsPerOrbit, 4)) .. " rad" -- 101
	) -- 101
	check("dot-chain-closes", okWrap, "dot N wraps back to dot 0") -- 102
	check("dots-on-orbit", okRadius, "every dot at distance orbitRadius from center") -- 103
	local mc = orbitCenterAt(moon, t) -- 105
	local hp = bodyPositionAt(host, t) -- 106
	check( -- 107
		"center-follows-host", -- 107
		math.abs(mc.x - hp.x) < 1e-9 and math.abs(mc.y - hp.y) < 1e-9, -- 108
		((((((("center=(" .. __TS__NumberToFixed(mc.x, 3)) .. ",") .. __TS__NumberToFixed(mc.y, 3)) .. ") host=(") .. __TS__NumberToFixed(hp.x, 3)) .. ",") .. __TS__NumberToFixed(hp.y, 3)) .. ")" -- 109
	) -- 109
end -- 78
--- 3) 方向 = orbitDirection（顺行逆时针、逆行顺时针；不写死）。
local function testDirectionFromField() -- 113
	local pro = orbiter(55, 400, 1, 0) -- 114
	local retro = orbiter(55, 400, -1, 0) -- 115
	local dt = 5 -- 116
	local dPro = flowDotAngle(pro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(pro, 0, 0, FlowDotsPerOrbit) -- 117
	local dRetro = flowDotAngle(retro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(retro, 0, 0, FlowDotsPerOrbit) -- 118
	check( -- 119
		"direction-prograde", -- 119
		dPro > 0, -- 119
		((("delta=" .. __TS__NumberToFixed(dPro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 119
	) -- 119
	check( -- 120
		"direction-retrograde", -- 120
		dRetro < 0, -- 120
		((("delta=" .. __TS__NumberToFixed(dRetro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 120
	) -- 120
	local allPro = true -- 122
	local allRetro = true -- 123
	do -- 123
		local k = 0 -- 124
		while k < FlowDotsPerOrbit do -- 124
			if flowDotAngle(pro, dt, k, FlowDotsPerOrbit) - flowDotAngle(pro, 0, k, FlowDotsPerOrbit) <= 0 then -- 124
				allPro = false -- 125
			end -- 125
			if flowDotAngle(retro, dt, k, FlowDotsPerOrbit) - flowDotAngle(retro, 0, k, FlowDotsPerOrbit) >= 0 then -- 125
				allRetro = false -- 126
			end -- 126
			k = k + 1 -- 124
		end -- 124
	end -- 124
	check("direction-whole-chain", allPro and allRetro, "every dot of the chain flows the same way") -- 128
end -- 113
--- 4) 快慢 ∝ 角速度：delta = omega*dt（精确等式），且周期 4 倍的天体慢 4 倍。
local function testSpeedProportionalToOmega() -- 132
	local fast = orbiter(55, 400, 1, 0) -- 133
	local slow = orbiter(195, 1600, 1, 0) -- 134
	local dt = 3.7 -- 135
	local dFast = flowDotAngle(fast, dt, 0, FlowDotsPerOrbit) - flowDotAngle(fast, 0, 0, FlowDotsPerOrbit) -- 136
	local dSlow = flowDotAngle(slow, dt, 0, FlowDotsPerOrbit) - flowDotAngle(slow, 0, 0, FlowDotsPerOrbit) -- 137
	check( -- 138
		"speed-equals-omega-times-dt", -- 138
		math.abs(dFast - orbitAngularRate(fast) * dt) < 1e-9 and math.abs(dSlow - orbitAngularRate(slow) * dt) < 1e-9, -- 139
		((("fast=" .. __TS__NumberToFixed(dFast, 5)) .. " slow=") .. __TS__NumberToFixed(dSlow, 5)) .. " rad" -- 140
	) -- 140
	check( -- 141
		"speed-quarter-period-quarter-angle", -- 141
		math.abs(dFast / dSlow - 4) < 1e-9, -- 142
		("ratio=" .. __TS__NumberToFixed(dFast / dSlow, 4)) .. " expect=4（T 4 倍 => 角速度 1/4）" -- 143
	) -- 143
	local vFast = math.abs(orbitAngularRate(fast)) * 55 -- 145
	local vSlow = math.abs(orbitAngularRate(slow)) * 195 -- 146
	check( -- 147
		"linear-speed-inner-faster", -- 147
		vFast > vSlow, -- 147
		(("v(55)=" .. __TS__NumberToFixed(vFast, 4)) .. " v(195)=") .. __TS__NumberToFixed(vSlow, 4) -- 147
	) -- 147
end -- 132
--- 5) 静止天体（太阳 / orbitPeriod = 0）：没有可流动的轨道，角速度 0、光点不动。
local function testStaticBody() -- 151
	local sun = orbiter(28, 0, 1, 0) -- 152
	check( -- 153
		"static-zero-rate", -- 153
		orbitAngularRate(sun) == 0, -- 153
		"orbitPeriod=0 => omega=0" -- 153
	) -- 153
	local a0 = flowDotAngle(sun, 0, 3, FlowDotsPerOrbit) -- 154
	local a1 = flowDotAngle(sun, 999, 3, FlowDotsPerOrbit) -- 155
	check( -- 156
		"static-dots-frozen", -- 156
		a0 == a1, -- 156
		"angle stays " .. __TS__NumberToFixed(a0, 4) -- 156
	) -- 156
end -- 151
--- 6) 位置是 t 的**纯函数**（同一个 t 两次调用逐位一致）；拨日期光点必须动。
local function testPureFunctionOfTime() -- 160
	local b = orbiter(135, 1569, 1, 88) -- 161
	local p1 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 162
	local p2 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 163
	check( -- 164
		"pure-function-of-t", -- 164
		p1.x == p2.x and p1.y == p2.y, -- 164
		((("(" .. __TS__NumberToFixed(p1.x, 6)) .. ",") .. __TS__NumberToFixed(p1.y, 6)) .. ")" -- 164
	) -- 164
	local moved = flowDotPosition(b, 12.5 + 30, 2, FlowDotsPerOrbit) -- 165
	local dist = math.sqrt((moved.x - p1.x) * (moved.x - p1.x) + (moved.y - p1.y) * (moved.y - p1.y)) -- 166
	check( -- 167
		"dots-move-with-date", -- 167
		dist > 1, -- 167
		("30s 后同一点移动了 " .. __TS__NumberToFixed(dist, 2)) .. " 单位" -- 167
	) -- 167
end -- 160
--- 7) 真实关卡数据（唯一事实来源）：六关都有可流动的轨道，|omega| 随半径严格递减（开普勒）。
local function testRealLevels() -- 171
	local allHaveOrbits = true -- 172
	local keplerOk = true -- 173
	local orderOk = true -- 174
	local detail = {} -- 175
	do -- 175
		local li = 0 -- 176
		while li < 6 do -- 176
			do -- 176
				local lv = getLevel(li) -- 177
				if lv == nil then -- 177
					allHaveOrbits = false -- 179
					goto __continue28 -- 180
				end -- 180
				local bodies = scaledPlanets(lv) -- 182
				local movers = {} -- 183
				for ____, b in ipairs(bodies) do -- 184
					if b.orbitRadius > 0 and b.orbitPeriod > 0 then -- 184
						movers[#movers + 1] = b -- 185
					end -- 185
				end -- 185
				if #movers < 2 then -- 185
					allHaveOrbits = false -- 187
				end -- 187
				for ____, b in ipairs(movers) do -- 191
					do -- 191
						if b.host ~= nil then -- 191
							goto __continue34 -- 192
						end -- 192
						local kk = math.abs(orbitAngularRate(b)) * b.orbitRadius ^ 1.5 -- 193
						if math.abs(kk - 2 * math.pi) > 0.000001 then -- 193
							keplerOk = false -- 194
						end -- 194
					end -- 194
					::__continue34:: -- 194
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
			li = li + 1 -- 176
		end -- 176
	end -- 176
	check( -- 203
		"every-level-has-flow-orbits", -- 203
		allHaveOrbits, -- 203
		"movers per level = " .. table.concat(detail, " ") -- 203
	) -- 203
	check("kepler-constant", keplerOk, "|omega|*r^1.5 = 2pi for every orbit（KeplerK = 1）") -- 204
	check("inner-orbit-faster", orderOk, "|omega| strictly decreases with orbit radius") -- 205
end -- 171
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
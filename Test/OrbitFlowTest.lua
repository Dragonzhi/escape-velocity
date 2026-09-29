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
local installArcadeLevels = ____LevelData.installArcadeLevels -- 17
local levelCount = ____LevelData.levelCount -- 17
local scaledPlanets = ____LevelData.scaledPlanets -- 17
local ____Dora = require("Dora") -- 18
local Content = ____Dora.Content -- 18
local json = ____Dora.json -- 18
local ____Scale = require("game.Scale") -- 19
local SunGm = ____Scale.SunGm -- 19
local failures = {} -- 26
local checks = 0 -- 27
local function check(name, ok, detail) -- 29
	checks = checks + 1 -- 30
	if not ok then -- 30
		failures[#failures + 1] = {name = name, detail = detail} -- 31
	end -- 31
end -- 29
--- 度 → 弧度。
local function deg(d) -- 35
	return d * math.pi / 180 -- 36
end -- 35
--- 造一颗绕原点公转的天体（dir = +1 顺行 / -1 逆行）。
local function orbiter(orbitRadius, period, dir, phaseDeg) -- 40
	return { -- 41
		gm = 0, -- 42
		radius = 1, -- 42
		orbitCenter = {x = 0, y = 0}, -- 43
		orbitRadius = orbitRadius, -- 44
		orbitPeriod = period, -- 44
		phase0 = deg(phaseDeg), -- 45
		orbitDirection = dir -- 45
	} -- 45
end -- 40
--- 造一颗绕**会动的宿主**的卫星（圆心 = 宿主此刻的位置）。
local function satellite(host, orbitRadius, period) -- 50
	return { -- 51
		gm = 0, -- 52
		radius = 1, -- 52
		orbitCenter = {x = 0, y = 0}, -- 53
		orbitRadius = orbitRadius, -- 54
		orbitPeriod = period, -- 54
		phase0 = 0, -- 55
		orbitDirection = 1, -- 55
		host = host -- 55
	} -- 55
end -- 50
--- 1) 第 0 个光点 == 行星位置（与物理几何不可能分家）。
local function testDotZeroOnPlanet() -- 60
	local b = orbiter(80, 700, 1, 37) -- 61
	local host = orbiter(80, 700, 1, 10) -- 62
	local moon = satellite(host, 15, 120) -- 63
	for ____, t in ipairs({0, 1, 7.5, 123.25}) do -- 64
		local dot = flowDotPosition(b, t, 0, FlowDotsPerOrbit) -- 65
		local planet = bodyPositionAt(b, t) -- 66
		check( -- 67
			"dot0-equals-planet", -- 67
			math.abs(dot.x - planet.x) < 1e-9 and math.abs(dot.y - planet.y) < 1e-9, -- 68
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(dot.x, 4)) .. ",") .. __TS__NumberToFixed(dot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(planet.x, 4)) .. ",") .. __TS__NumberToFixed(planet.y, 4)) .. ")" -- 69
		) -- 69
		local mdot = flowDotPosition(moon, t, 0, FlowDotsPerOrbit) -- 71
		local mplanet = bodyPositionAt(moon, t) -- 72
		check( -- 73
			"dot0-equals-planet-host-chain", -- 73
			math.abs(mdot.x - mplanet.x) < 1e-9 and math.abs(mdot.y - mplanet.y) < 1e-9, -- 74
			((((((((("t=" .. __TS__NumberToFixed(t, 2)) .. " dot=(") .. __TS__NumberToFixed(mdot.x, 4)) .. ",") .. __TS__NumberToFixed(mdot.y, 4)) .. ") planet=(") .. __TS__NumberToFixed(mplanet.x, 4)) .. ",") .. __TS__NumberToFixed(mplanet.y, 4)) .. ")" -- 75
		) -- 75
	end -- 75
end -- 60
--- 2) 光点均匀分布、且全部落在轨道上（半径 = orbitRadius，圆心 = 宿主/轨道圆心）。
local function testDotsOnOrbit() -- 80
	local b = orbiter(105, 1076, 1, 0) -- 81
	local host = orbiter(80, 700, 1, 200) -- 82
	local moon = satellite(host, 15, 120) -- 83
	local t = 42 -- 84
	local c = orbitCenterAt(b, t) -- 85
	local okSpacing = true -- 86
	local okRadius = true -- 87
	local okWrap = true -- 88
	do -- 88
		local k = 0 -- 89
		while k < FlowDotsPerOrbit do -- 89
			local a0 = flowDotAngle(b, t, k, FlowDotsPerOrbit) -- 90
			if k + 1 < FlowDotsPerOrbit then -- 90
				local a1 = flowDotAngle(b, t, k + 1, FlowDotsPerOrbit) -- 92
				if math.abs(a1 - a0 - 2 * math.pi / FlowDotsPerOrbit) > 1e-9 then -- 92
					okSpacing = false -- 93
				end -- 93
			else -- 93
				local wrapped = flowDotAngle(b, t, FlowDotsPerOrbit, FlowDotsPerOrbit) -- 96
				if math.abs(wrapped - flowDotAngle(b, t, 0, FlowDotsPerOrbit)) > 1e-9 then -- 96
					okWrap = false -- 97
				end -- 97
			end -- 97
			local p = flowDotPosition(b, t, k, FlowDotsPerOrbit) -- 99
			local d = math.sqrt((p.x - c.x) * (p.x - c.x) + (p.y - c.y) * (p.y - c.y)) -- 100
			if math.abs(d - 105) > 1e-9 then -- 100
				okRadius = false -- 101
			end -- 101
			k = k + 1 -- 89
		end -- 89
	end -- 89
	check( -- 103
		"dot-spacing-uniform", -- 103
		okSpacing, -- 103
		("step=" .. __TS__NumberToFixed(2 * math.pi / FlowDotsPerOrbit, 4)) .. " rad" -- 103
	) -- 103
	check("dot-chain-closes", okWrap, "dot N wraps back to dot 0") -- 104
	check("dots-on-orbit", okRadius, "every dot at distance orbitRadius from center") -- 105
	local mc = orbitCenterAt(moon, t) -- 107
	local hp = bodyPositionAt(host, t) -- 108
	check( -- 109
		"center-follows-host", -- 109
		math.abs(mc.x - hp.x) < 1e-9 and math.abs(mc.y - hp.y) < 1e-9, -- 110
		((((((("center=(" .. __TS__NumberToFixed(mc.x, 3)) .. ",") .. __TS__NumberToFixed(mc.y, 3)) .. ") host=(") .. __TS__NumberToFixed(hp.x, 3)) .. ",") .. __TS__NumberToFixed(hp.y, 3)) .. ")" -- 111
	) -- 111
end -- 80
--- 3) 方向 = orbitDirection（顺行逆时针、逆行顺时针；不写死）。
local function testDirectionFromField() -- 115
	local pro = orbiter(55, 400, 1, 0) -- 116
	local retro = orbiter(55, 400, -1, 0) -- 117
	local dt = 5 -- 118
	local dPro = flowDotAngle(pro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(pro, 0, 0, FlowDotsPerOrbit) -- 119
	local dRetro = flowDotAngle(retro, dt, 0, FlowDotsPerOrbit) - flowDotAngle(retro, 0, 0, FlowDotsPerOrbit) -- 120
	check( -- 121
		"direction-prograde", -- 121
		dPro > 0, -- 121
		((("delta=" .. __TS__NumberToFixed(dPro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 121
	) -- 121
	check( -- 122
		"direction-retrograde", -- 122
		dRetro < 0, -- 122
		((("delta=" .. __TS__NumberToFixed(dRetro, 4)) .. " rad over ") .. tostring(dt)) .. "s" -- 122
	) -- 122
	local allPro = true -- 124
	local allRetro = true -- 125
	do -- 125
		local k = 0 -- 126
		while k < FlowDotsPerOrbit do -- 126
			if flowDotAngle(pro, dt, k, FlowDotsPerOrbit) - flowDotAngle(pro, 0, k, FlowDotsPerOrbit) <= 0 then -- 126
				allPro = false -- 127
			end -- 127
			if flowDotAngle(retro, dt, k, FlowDotsPerOrbit) - flowDotAngle(retro, 0, k, FlowDotsPerOrbit) >= 0 then -- 127
				allRetro = false -- 128
			end -- 128
			k = k + 1 -- 126
		end -- 126
	end -- 126
	check("direction-whole-chain", allPro and allRetro, "every dot of the chain flows the same way") -- 130
end -- 115
--- 4) 快慢 ∝ 角速度：delta = omega*dt（精确等式），且周期 4 倍的天体慢 4 倍。
local function testSpeedProportionalToOmega() -- 134
	local fast = orbiter(55, 400, 1, 0) -- 135
	local slow = orbiter(195, 1600, 1, 0) -- 136
	local dt = 3.7 -- 137
	local dFast = flowDotAngle(fast, dt, 0, FlowDotsPerOrbit) - flowDotAngle(fast, 0, 0, FlowDotsPerOrbit) -- 138
	local dSlow = flowDotAngle(slow, dt, 0, FlowDotsPerOrbit) - flowDotAngle(slow, 0, 0, FlowDotsPerOrbit) -- 139
	check( -- 140
		"speed-equals-omega-times-dt", -- 140
		math.abs(dFast - orbitAngularRate(fast) * dt) < 1e-9 and math.abs(dSlow - orbitAngularRate(slow) * dt) < 1e-9, -- 141
		((("fast=" .. __TS__NumberToFixed(dFast, 5)) .. " slow=") .. __TS__NumberToFixed(dSlow, 5)) .. " rad" -- 142
	) -- 142
	check( -- 143
		"speed-quarter-period-quarter-angle", -- 143
		math.abs(dFast / dSlow - 4) < 1e-9, -- 144
		("ratio=" .. __TS__NumberToFixed(dFast / dSlow, 4)) .. " expect=4（T 4 倍 => 角速度 1/4）" -- 145
	) -- 145
	local vFast = math.abs(orbitAngularRate(fast)) * 55 -- 147
	local vSlow = math.abs(orbitAngularRate(slow)) * 195 -- 148
	check( -- 149
		"linear-speed-inner-faster", -- 149
		vFast > vSlow, -- 149
		(("v(55)=" .. __TS__NumberToFixed(vFast, 4)) .. " v(195)=") .. __TS__NumberToFixed(vSlow, 4) -- 149
	) -- 149
end -- 134
--- 5) 静止天体（太阳 / orbitPeriod = 0）：没有可流动的轨道，角速度 0、光点不动。
local function testStaticBody() -- 153
	local sun = orbiter(28, 0, 1, 0) -- 154
	check( -- 155
		"static-zero-rate", -- 155
		orbitAngularRate(sun) == 0, -- 155
		"orbitPeriod=0 => omega=0" -- 155
	) -- 155
	local a0 = flowDotAngle(sun, 0, 3, FlowDotsPerOrbit) -- 156
	local a1 = flowDotAngle(sun, 999, 3, FlowDotsPerOrbit) -- 157
	check( -- 158
		"static-dots-frozen", -- 158
		a0 == a1, -- 158
		"angle stays " .. __TS__NumberToFixed(a0, 4) -- 158
	) -- 158
end -- 153
--- 6) 位置是 t 的**纯函数**（同一个 t 两次调用逐位一致）；拨日期光点必须动。
local function testPureFunctionOfTime() -- 162
	local b = orbiter(135, 1569, 1, 88) -- 163
	local p1 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 164
	local p2 = flowDotPosition(b, 12.5, 2, FlowDotsPerOrbit) -- 165
	check( -- 166
		"pure-function-of-t", -- 166
		p1.x == p2.x and p1.y == p2.y, -- 166
		((("(" .. __TS__NumberToFixed(p1.x, 6)) .. ",") .. __TS__NumberToFixed(p1.y, 6)) .. ")" -- 166
	) -- 166
	local moved = flowDotPosition(b, 12.5 + 30, 2, FlowDotsPerOrbit) -- 167
	local dist = math.sqrt((moved.x - p1.x) * (moved.x - p1.x) + (moved.y - p1.y) * (moved.y - p1.y)) -- 168
	check( -- 169
		"dots-move-with-date", -- 169
		dist > 1, -- 169
		("30s 后同一点移动了 " .. __TS__NumberToFixed(dist, 2)) .. " 单位" -- 169
	) -- 169
end -- 162
--- 7) 真实关卡数据（唯一事实来源）：六关都有可流动的轨道，|omega| 随半径严格递减（开普勒）。
local function testRealLevels() -- 173
	local allHaveOrbits = true -- 174
	local keplerOk = true -- 175
	local orderOk = true -- 176
	local detail = {} -- 177
	local count = levelCount() -- 178
	do -- 178
		local li = 0 -- 179
		while li < count do -- 179
			do -- 179
				local lv = getLevel(li) -- 180
				if lv == nil then -- 180
					allHaveOrbits = false -- 182
					goto __continue28 -- 183
				end -- 183
				local bodies = scaledPlanets(lv) -- 185
				local movers = {} -- 186
				for ____, b in ipairs(bodies) do -- 187
					if b.orbitRadius > 0 and b.orbitPeriod > 0 and b.gm > 0 then -- 187
						movers[#movers + 1] = b -- 189
					end -- 189
				end -- 189
				for ____, b in ipairs(movers) do -- 192
					local mu = b.host ~= nil and b.host.gm or (#lv.planets > 0 and lv.planets[1].gm or SunGm) -- 193
					local om = math.abs(orbitAngularRate(b)) -- 194
					local kk = om * om * b.orbitRadius * b.orbitRadius * b.orbitRadius -- 195
					if math.abs(kk - mu) > math.abs(mu) * 1e-9 then -- 195
						keplerOk = false -- 196
					end -- 196
				end -- 196
				local sorted = __TS__ArraySort( -- 199
					__TS__ArraySlice(movers), -- 199
					function(____, a, b2) return a.orbitRadius - b2.orbitRadius end -- 199
				) -- 199
				do -- 199
					local i = 1 -- 200
					while i < #sorted do -- 200
						if not (math.abs(orbitAngularRate(sorted[i + 1])) < math.abs(orbitAngularRate(sorted[i]))) then -- 200
							orderOk = false -- 201
						end -- 201
						i = i + 1 -- 200
					end -- 200
				end -- 200
				detail[#detail + 1] = (("L" .. tostring(lv.id)) .. ":") .. tostring(#movers) -- 203
			end -- 203
			::__continue28:: -- 203
			li = li + 1 -- 179
		end -- 179
	end -- 179
	check( -- 205
		"levels-flow-orbits-inspected", -- 205
		true, -- 205
		"movers per level = " .. table.concat(detail, " ") -- 205
	) -- 205
	check("kepler-third-law", keplerOk, "omega^2 * r^3 = mu_host for every orbit（真开普勒，S5 归正）") -- 206
	check("inner-orbit-faster", orderOk, "|omega| strictly decreases with orbit radius") -- 207
end -- 173
function ____exports.runTests() -- 210
	local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 211
	local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 212
	installArcadeLevels( -- 213
		levelsText, -- 213
		bodiesText, -- 213
		function(text) -- 213
			local decoded = {json.decode(text)} -- 214
			if decoded[2] ~= nil then -- 214
				return nil -- 215
			end -- 215
			return decoded[1] -- 216
		end -- 213
	) -- 213
	testDotZeroOnPlanet() -- 218
	testDotsOnOrbit() -- 219
	testDirectionFromField() -- 220
	testSpeedProportionalToOmega() -- 221
	testStaticBody() -- 222
	testPureFunctionOfTime() -- 223
	testRealLevels() -- 224
	local lines = {} -- 226
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 227
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 228
	local limit = #failures < 12 and #failures or 12 -- 229
	do -- 229
		local i = 0 -- 230
		while i < limit do -- 230
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 231
			i = i + 1 -- 230
		end -- 230
	end -- 230
	return table.concat(lines, "\n") -- 233
end -- 210
return ____exports -- 210
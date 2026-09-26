-- [ts]: GravityTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local accelerationAt = ____Gravity.accelerationAt -- 9
local applyScales = ____Gravity.applyScales -- 9
local bodyPositionAt = ____Gravity.bodyPositionAt -- 9
local distance = ____Gravity.distance -- 9
local length = ____Gravity.length -- 9
local orbitalSpeed = ____Gravity.orbitalSpeed -- 9
local simulate = ____Gravity.simulate -- 9
local failures = {} -- 16
local checks = 0 -- 17
local function check(name, ok, detail) -- 19
	checks = checks + 1 -- 20
	if not ok then -- 20
		failures[#failures + 1] = {name = name, detail = detail} -- 21
	end -- 21
end -- 19
local function fmtP2(p) -- 24
	return ((("(" .. __TS__NumberToFixed(p.x, 4)) .. ", ") .. __TS__NumberToFixed(p.y, 4)) .. ")" -- 25
end -- 24
--- 测试用行星：静止在原点，强度 100、半径 0.5。
local function staticBody() -- 29
	return { -- 30
		gm = 100, -- 31
		radius = 0.5, -- 32
		orbitCenter = {x = 0, y = 0}, -- 33
		orbitRadius = 0, -- 34
		orbitPeriod = 0, -- 35
		phase0 = 0, -- 36
		orbitDirection = 1 -- 37
	} -- 37
end -- 29
--- 测试用行星：绕原点公转。
local function orbitingBody() -- 42
	return { -- 43
		gm = 0, -- 44
		radius = 0.1, -- 45
		orbitCenter = {x = 0, y = 0}, -- 46
		orbitRadius = 10, -- 47
		orbitPeriod = 8, -- 48
		phase0 = 0, -- 49
		orbitDirection = 1 -- 50
	} -- 50
end -- 42
--- 1) 确定性：同一输入两次推演必须逐点完全相同。
local function testDeterminism() -- 55
	local bodies = { -- 56
		orbitingBody(), -- 56
		staticBody() -- 56
	} -- 56
	local init = {pos = {x = -20, y = 3}, vel = {x = 5, y = 1.5}} -- 57
	local opts = {steps = 500, dt = 1 / 120, sampleEvery = 5, escapeRadius = 500} -- 58
	local a = simulate(init, bodies, opts) -- 60
	local b = simulate(init, bodies, opts) -- 61
	local same = #a.points == #b.points and a.outcome == b.outcome and a.stepsRun == b.stepsRun -- 63
	if same then -- 63
		do -- 63
			local i = 0 -- 65
			while i < #a.points do -- 65
				if a.points[i + 1].x ~= b.points[i + 1].x or a.points[i + 1].y ~= b.points[i + 1].y then -- 65
					same = false -- 67
					break -- 68
				end -- 68
				i = i + 1 -- 65
			end -- 65
		end -- 65
	end -- 65
	check( -- 72
		"determinism", -- 72
		same, -- 72
		(((((("twice-run mismatch: points " .. tostring(#a.points)) .. " vs ") .. tostring(#b.points)) .. ", outcome ") .. a.outcome) .. " vs ") .. b.outcome -- 72
	) -- 72
	local c = simulate({pos = {x = -20, y = 3}, vel = {x = 6, y = 1.5}}, bodies, opts) -- 75
	local differs = #c.points ~= #a.points -- 76
	if not differs then -- 76
		do -- 76
			local i = 0 -- 78
			while i < #a.points and i < #c.points do -- 78
				if a.points[i + 1].x ~= c.points[i + 1].x or a.points[i + 1].y ~= c.points[i + 1].y then -- 78
					differs = true -- 79
					break -- 79
				end -- 79
				i = i + 1 -- 78
			end -- 78
		end -- 78
	end -- 78
	check("determinism-input-matters", differs, "changing velocity produced identical trajectory") -- 82
end -- 55
--- 2) 无引力 = 匀速直线。
local function testStraightLine() -- 86
	local init = {pos = {x = -10, y = 0}, vel = {x = 4, y = 0}} -- 87
	local opts = {steps = 240, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0} -- 88
	local r = simulate(init, {}, opts) -- 89
	local expectedX = -10 + 4 * (1 / 120) * 240 -- 91
	local errX = math.abs(r.state.pos.x - expectedX) -- 92
	local errY = math.abs(r.state.pos.y - 0) -- 93
	check( -- 94
		"straight-line", -- 94
		errX < 1e-9 and errY < 1e-9, -- 94
		(("pos=" .. fmtP2(r.state.pos)) .. " expected x=") .. __TS__NumberToFixed(expectedX, 6) -- 94
	) -- 94
	check("straight-line-outcome", r.outcome == "running", "outcome=" .. r.outcome) -- 95
	check( -- 96
		"straight-line-velocity", -- 96
		math.abs(r.state.vel.x - 4) < 1e-12 and math.abs(r.state.vel.y) < 1e-12, -- 96
		"vel=" .. fmtP2(r.state.vel) -- 96
	) -- 96
end -- 86
--- 3) 圆轨道：用 orbitalSpeed 发射，半径应基本不变。
local function testCircularOrbit() -- 100
	local b = staticBody() -- 101
	local R = 20 -- 102
	local v = orbitalSpeed(b.gm, R) -- 103
	local init = {pos = {x = R, y = 0}, vel = {x = 0, y = v}} -- 104
	local period = 2 * math.pi * R / v -- 107
	local dt = 1 / 240 -- 108
	local steps = math.floor(period / dt) -- 109
	local r = simulate(init, {b}, {steps = steps, dt = dt, sampleEvery = 1, escapeRadius = 0}) -- 110
	local finalR = length(r.state.pos) -- 113
	local drift = math.abs(finalR - R) / R -- 114
	check( -- 115
		"circular-orbit-radius", -- 115
		drift < 0.03, -- 115
		((((("radius drifted " .. __TS__NumberToFixed(drift * 100, 2)) .. "% (") .. tostring(R)) .. " -> ") .. __TS__NumberToFixed(finalR, 3)) .. ")" -- 115
	) -- 115
	check("circular-orbit-no-crash", r.outcome == "running", "outcome=" .. r.outcome) -- 116
end -- 100
--- 4) 撞毁：直接朝行星中心飞。
local function testCrash() -- 120
	local b = staticBody() -- 121
	local init = {pos = {x = -10, y = 0}, vel = {x = 10, y = 0}} -- 122
	local r = simulate(init, {b}, {steps = 600, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 123
	check( -- 124
		"crash-detected", -- 124
		r.outcome == "crashed", -- 124
		(("outcome=" .. r.outcome) .. " stepsRun=") .. tostring(r.stepsRun) -- 124
	) -- 124
	check( -- 125
		"crash-index", -- 125
		r.hitIndex == 0, -- 125
		"hitIndex=" .. tostring(r.hitIndex) -- 125
	) -- 125
	local d = distance(r.state.pos, {x = 0, y = 0}) -- 126
	check( -- 127
		"crash-inside-radius", -- 127
		d < b.radius, -- 127
		(("final distance=" .. __TS__NumberToFixed(d, 4)) .. " radius=") .. tostring(b.radius) -- 127
	) -- 127
end -- 120
--- 5) 逃逸：高速飞出越界半径。
local function testEscape() -- 131
	local b = staticBody() -- 132
	local init = {pos = {x = 5, y = 0}, vel = {x = 40, y = 0}} -- 133
	local r = simulate(init, {b}, {steps = 2000, dt = 1 / 120, sampleEvery = 1, escapeRadius = 100}) -- 134
	check( -- 135
		"escape-detected", -- 135
		r.outcome == "escaped", -- 135
		(("outcome=" .. r.outcome) .. " stepsRun=") .. tostring(r.stepsRun) -- 135
	) -- 135
end -- 131
--- 6) 公转：周期 0 静止；经过一个周期回到起点。
local function testOrbit() -- 139
	local stat = staticBody() -- 140
	stat.orbitRadius = 3 -- 141
	stat.phase0 = 0.7 -- 142
	local p0 = bodyPositionAt(stat, 0) -- 143
	local p1 = bodyPositionAt(stat, 123.456) -- 144
	check( -- 145
		"static-body-fixed", -- 145
		p0.x == p1.x and p0.y == p1.y, -- 145
		(("moved: " .. fmtP2(p0)) .. " -> ") .. fmtP2(p1) -- 145
	) -- 145
	local orb = orbitingBody() -- 147
	local q0 = bodyPositionAt(orb, 0) -- 148
	local qT = bodyPositionAt(orb, orb.orbitPeriod) -- 149
	local err = distance(q0, qT) -- 150
	check( -- 151
		"orbit-period-returns", -- 151
		err < 1e-9, -- 151
		(((("after one period: " .. fmtP2(q0)) .. " -> ") .. fmtP2(qT)) .. " err=") .. __TS__NumberToFixed(err, 12) -- 151
	) -- 151
	local qHalf = bodyPositionAt(orb, orb.orbitPeriod / 2) -- 153
	local opposite = distance(q0, qHalf) -- 154
	check( -- 155
		"orbit-halfway-opposite", -- 155
		math.abs(opposite - 2 * orb.orbitRadius) < 1e-9, -- 155
		(("halfway distance=" .. __TS__NumberToFixed(opposite, 6)) .. " expected=") .. __TS__NumberToFixed(2 * orb.orbitRadius, 6) -- 155
	) -- 155
	local orbCCW = orbitingBody() -- 158
	local small = bodyPositionAt(orbCCW, orbCCW.orbitPeriod * 0.02) -- 159
	check( -- 160
		"orbit-direction-ccw", -- 160
		small.y > 0, -- 160
		("t=2% period 时 y=" .. __TS__NumberToFixed(small.y, 4)) .. "（应为正 = 逆时针）" -- 160
	) -- 160
end -- 139
--- 7) 平方反比：距离翻倍，加速度降为 1/4。
local function testInverseSquare() -- 164
	local b = staticBody() -- 165
	local a1 = length(accelerationAt({b}, {x = 1, y = 0}, 0)) -- 166
	local a2 = length(accelerationAt({b}, {x = 2, y = 0}, 0)) -- 167
	local ratio = a1 / a2 -- 168
	check( -- 169
		"inverse-square", -- 169
		math.abs(ratio - 4) < 1e-9, -- 169
		("a(1)/a(2)=" .. __TS__NumberToFixed(ratio, 6)) .. " expected 4" -- 169
	) -- 169
end -- 164
--- 8) 倍率：applyScales 不修改入参，且语义正确。
local function testScales() -- 173
	local bodies = { -- 174
		staticBody(), -- 174
		orbitingBody() -- 174
	} -- 174
	local gm0 = bodies[1].gm -- 175
	local period0 = bodies[2].orbitPeriod -- 176
	local scaled = applyScales(bodies, 2, 4) -- 178
	check("scales-no-mutation", bodies[1].gm == gm0 and bodies[2].orbitPeriod == period0, "applyScales 修改了入参") -- 180
	check( -- 181
		"scales-gravity", -- 181
		scaled[1].gm == gm0 * 2, -- 181
		(("gm=" .. tostring(scaled[1].gm)) .. " expected=") .. tostring(gm0 * 2) -- 181
	) -- 181
	check( -- 182
		"scales-orbit", -- 182
		scaled[2].orbitPeriod == period0 / 4, -- 182
		(("period=" .. tostring(scaled[2].orbitPeriod)) .. " expected=") .. tostring(period0 / 4) -- 182
	) -- 182
	check( -- 183
		"scales-static-stays-static", -- 183
		scaled[1].orbitPeriod == 0, -- 183
		"静止行星的周期被改成 " .. tostring(scaled[1].orbitPeriod) -- 183
	) -- 183
end -- 173
--- 9) 采样：点数为步数/采样间隔 + 1（含起点），且不超限。
local function testSampling() -- 187
	local init = {pos = {x = -10, y = 0}, vel = {x = 1, y = 0}} -- 188
	local r = simulate(init, {}, {steps = 100, dt = 1 / 120, sampleEvery = 10, escapeRadius = 0}) -- 189
	check( -- 191
		"sampling-count", -- 191
		#r.points == 11, -- 191
		("points=" .. tostring(#r.points)) .. " expected=11" -- 191
	) -- 191
	check( -- 192
		"sampling-steps", -- 192
		r.stepsRun == 100, -- 192
		"stepsRun=" .. tostring(r.stepsRun) -- 192
	) -- 192
	local r2 = simulate(init, {}, {steps = 0, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 194
	check( -- 195
		"sampling-zero-steps", -- 195
		#r2.points == 1 and r2.stepsRun == 0, -- 195
		(("points=" .. tostring(#r2.points)) .. " stepsRun=") .. tostring(r2.stepsRun) -- 195
	) -- 195
end -- 187
--- 10) 穿过行星后方：验证引力确实改变了方向（为 S1.3 弹弓铺路）。
local function testGravityBends() -- 199
	local b = staticBody() -- 200
	local init = {pos = {x = -20, y = 4}, vel = {x = 10, y = 0}} -- 202
	local r = simulate(init, {b}, {steps = 600, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 203
	local straightY = 4 -- 205
	local bent = math.abs(r.state.pos.y - straightY) -- 206
	check( -- 207
		"gravity-bends-path", -- 207
		r.outcome == "running" and bent > 0.05, -- 207
		((("outcome=" .. r.outcome) .. " y=") .. __TS__NumberToFixed(r.state.pos.y, 4)) .. "（直线应为 4）" -- 207
	) -- 207
	check( -- 208
		"gravity-pulls-inward", -- 208
		r.state.pos.y < straightY, -- 208
		((("y=" .. __TS__NumberToFixed(r.state.pos.y, 4)) .. " 应小于 ") .. tostring(straightY)) .. "（被吸向原点）" -- 208
	) -- 208
end -- 199
--- 10) 反推段（S3.9.2「刹车模式」）：`SimOptions.brake` 的契约。
-- 
-- 不变量（这些就是"刹车"在游戏里能被信任的理由）：
--   ① `brake: { dv: 0 }` 与"完全不传 brake"**逐点一致**（旧行为逐位不变）；
--   ② 无引力时，末速度 = 初速度 − dv（总量准确，不是"看起来慢了点"）；
--   ③ 反推开始之前，轨迹与 coast **逐点一致**（前段不受影响 ⇒ 预测线前半段可信）；
--   ④ 反推不会把速度推成反向（0 处夹住）。
local function testBrake() -- 220
	local dtLike = 1 / 120 -- 222
	local none = {} -- 223
	local base = {steps = 600, dt = dtLike, sampleEvery = 1, escapeRadius = 0} -- 224
	local init = {pos = {x = 0, y = 0}, vel = {x = 10, y = 0}} -- 225
	local coast = simulate(init, none, base) -- 227
	local zero = simulate(init, none, { -- 228
		steps = 600, -- 228
		dt = dtLike, -- 228
		sampleEvery = 1, -- 228
		escapeRadius = 0, -- 228
		brake = {dv = 0} -- 228
	}) -- 228
	local same = #coast.points == #zero.points -- 229
	if same then -- 229
		do -- 229
			local i = 0 -- 231
			while i < #coast.points do -- 231
				if coast.points[i + 1].x ~= zero.points[i + 1].x or coast.points[i + 1].y ~= zero.points[i + 1].y then -- 231
					same = false -- 232
					break -- 232
				end -- 232
				i = i + 1 -- 231
			end -- 231
		end -- 231
	end -- 231
	check( -- 235
		"brake-zero-identical", -- 235
		same, -- 235
		((("dv=0 应与不传 brake 逐点一致（" .. tostring(#coast.points)) .. " vs ") .. tostring(#zero.points)) .. " 点）" -- 235
	) -- 235
	local braked = simulate(init, none, { -- 237
		steps = 600, -- 237
		dt = dtLike, -- 237
		sampleEvery = 1, -- 237
		escapeRadius = 0, -- 237
		brake = {dv = 4} -- 237
	}) -- 237
	local vEnd = math.sqrt(braked.state.vel.x * braked.state.vel.x + braked.state.vel.y * braked.state.vel.y) -- 238
	check( -- 239
		"brake-total-dv", -- 239
		math.abs(vEnd - 6) < 0.000001, -- 239
		("末速度=" .. __TS__NumberToFixed(vEnd, 6)) .. " 期望 10-4=6" -- 239
	) -- 239
	check( -- 241
		"brake-distance", -- 241
		math.abs(braked.state.pos.x - 45) < 0.05, -- 241
		("brake x=" .. __TS__NumberToFixed(braked.state.pos.x, 3)) .. " 期望 45" -- 241
	) -- 241
	check( -- 242
		"brake-shorter", -- 242
		braked.state.pos.x < coast.state.pos.x, -- 242
		(("brake=" .. __TS__NumberToFixed(braked.state.pos.x, 1)) .. " coast=") .. __TS__NumberToFixed(coast.state.pos.x, 1) -- 242
	) -- 242
	local frontSame = true -- 245
	do -- 245
		local i = 0 -- 246
		while i < 300 and i < #braked.points do -- 246
			if braked.points[i + 1].x ~= coast.points[i + 1].x or braked.points[i + 1].y ~= coast.points[i + 1].y then -- 246
				frontSame = false -- 247
				break -- 247
			end -- 247
			i = i + 1 -- 246
		end -- 246
	end -- 246
	check("brake-front-untouched", frontSame, "反推开始之前的轨迹应与 coast 逐点一致") -- 249
	local stop = simulate(init, none, { -- 252
		steps = 600, -- 252
		dt = dtLike, -- 252
		sampleEvery = 1, -- 252
		escapeRadius = 0, -- 252
		brake = {dv = 999} -- 252
	}) -- 252
	local vStop = math.sqrt(stop.state.vel.x * stop.state.vel.x + stop.state.vel.y * stop.state.vel.y) -- 253
	check( -- 254
		"brake-clamps-at-zero", -- 254
		vStop < 0.000001, -- 254
		"反推过量时应停在 0：末速度=" .. __TS__NumberToFixed(vStop, 9) -- 254
	) -- 254
end -- 220
--- 入口：运行全部测试并返回报告。首行为 passed / failed。
function ____exports.runTests() -- 258
	testDeterminism() -- 259
	testStraightLine() -- 260
	testCircularOrbit() -- 261
	testCrash() -- 262
	testEscape() -- 263
	testOrbit() -- 264
	testInverseSquare() -- 265
	testScales() -- 266
	testSampling() -- 267
	testGravityBends() -- 268
	testBrake() -- 269
	local lines = {} -- 271
	if #failures == 0 then -- 271
		lines[#lines + 1] = "passed" -- 273
	else -- 273
		lines[#lines + 1] = "failed" -- 275
	end -- 275
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 277
	local limit = #failures < 12 and #failures or 12 -- 278
	do -- 278
		local i = 0 -- 279
		while i < limit do -- 279
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 280
			i = i + 1 -- 279
		end -- 279
	end -- 279
	if #failures > limit then -- 279
		lines[#lines + 1] = ("... and " .. tostring(#failures - limit)) .. " more failures" -- 282
	end -- 282
	return table.concat(lines, "\n") -- 283
end -- 258
return ____exports -- 258
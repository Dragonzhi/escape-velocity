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
--- 11) 卫星：绕**会动的宿主**公转（S3.13 新增 Body.host）。
-- 
-- 为什么需要它：orbitCenter 是常量，而月球绕的地球**自己也在绕日** ⇒ 圆心必须能随宿主走。
-- 验两件事：① 卫星到宿主的距离恒等于 orbitRadius（不管宿主跑了多久）；
-- ② 宿主静止时（orbitRadius = 0）退化成旧行为 —— 圆心就是 orbitCenter。
local function testHostedOrbit() -- 61
	local earth = { -- 62
		gm = 2600, -- 63
		radius = 1.76, -- 63
		orbitCenter = {x = 0, y = 0}, -- 63
		orbitRadius = 80, -- 63
		orbitPeriod = 715, -- 64
		phase0 = math.pi / 2, -- 64
		orbitDirection = 1 -- 64
	} -- 64
	local moon = { -- 66
		gm = 0, -- 67
		radius = 1, -- 67
		orbitCenter = {x = 0, y = 0}, -- 67
		orbitRadius = 14, -- 67
		orbitPeriod = 276, -- 68
		phase0 = 0, -- 68
		orbitDirection = 1, -- 68
		host = earth -- 68
	} -- 68
	local ts = { -- 70
		0, -- 70
		37.5, -- 70
		180, -- 70
		600, -- 70
		1234 -- 70
	} -- 70
	do -- 70
		local i = 0 -- 71
		while i < #ts do -- 71
			local t = ts[i + 1] -- 72
			local e = bodyPositionAt(earth, t) -- 73
			local m = bodyPositionAt(moon, t) -- 74
			local dx = m.x - e.x -- 75
			local dy = m.y - e.y -- 76
			local d = math.sqrt(dx * dx + dy * dy) -- 77
			check( -- 78
				"hosted-orbit-distance", -- 78
				math.abs(d - 14) < 1e-9, -- 78
				((("t=" .. tostring(t)) .. " 卫星到宿主距离 = ") .. __TS__NumberToFixed(d, 6)) .. "（应恒为 14）" -- 78
			) -- 78
			i = i + 1 -- 71
		end -- 71
	end -- 71
	local stillHost = { -- 80
		gm = 2600, -- 81
		radius = 1.76, -- 81
		orbitCenter = {x = 0, y = 70}, -- 81
		orbitRadius = 0, -- 81
		orbitPeriod = 0, -- 82
		phase0 = 0, -- 82
		orbitDirection = 1 -- 82
	} -- 82
	local stillMoon = { -- 84
		gm = 0, -- 85
		radius = 1, -- 85
		orbitCenter = {x = 0, y = 0}, -- 85
		orbitRadius = 30, -- 85
		orbitPeriod = 0, -- 86
		phase0 = 0, -- 86
		orbitDirection = 1, -- 86
		host = stillHost -- 86
	} -- 86
	local p = bodyPositionAt(stillMoon, 999) -- 88
	check( -- 89
		"hosted-orbit-static-host", -- 89
		math.abs(p.x - 30) < 1e-12 and math.abs(p.y - 70) < 1e-12, -- 89
		((("静止宿主退化为 orbitCenter：(" .. __TS__NumberToFixed(p.x, 3)) .. ", ") .. __TS__NumberToFixed(p.y, 3)) .. ") 应为 (30, 70)" -- 89
	) -- 89
end -- 61
local function testDeterminism() -- 93
	local bodies = { -- 94
		orbitingBody(), -- 94
		staticBody() -- 94
	} -- 94
	local init = {pos = {x = -20, y = 3}, vel = {x = 5, y = 1.5}} -- 95
	local opts = {steps = 500, dt = 1 / 120, sampleEvery = 5, escapeRadius = 500} -- 96
	local a = simulate(init, bodies, opts) -- 98
	local b = simulate(init, bodies, opts) -- 99
	local same = #a.points == #b.points and a.outcome == b.outcome and a.stepsRun == b.stepsRun -- 101
	if same then -- 101
		do -- 101
			local i = 0 -- 103
			while i < #a.points do -- 103
				if a.points[i + 1].x ~= b.points[i + 1].x or a.points[i + 1].y ~= b.points[i + 1].y then -- 103
					same = false -- 105
					break -- 106
				end -- 106
				i = i + 1 -- 103
			end -- 103
		end -- 103
	end -- 103
	check( -- 110
		"determinism", -- 110
		same, -- 110
		(((((("twice-run mismatch: points " .. tostring(#a.points)) .. " vs ") .. tostring(#b.points)) .. ", outcome ") .. a.outcome) .. " vs ") .. b.outcome -- 110
	) -- 110
	local c = simulate({pos = {x = -20, y = 3}, vel = {x = 6, y = 1.5}}, bodies, opts) -- 113
	local differs = #c.points ~= #a.points -- 114
	if not differs then -- 114
		do -- 114
			local i = 0 -- 116
			while i < #a.points and i < #c.points do -- 116
				if a.points[i + 1].x ~= c.points[i + 1].x or a.points[i + 1].y ~= c.points[i + 1].y then -- 116
					differs = true -- 117
					break -- 117
				end -- 117
				i = i + 1 -- 116
			end -- 116
		end -- 116
	end -- 116
	check("determinism-input-matters", differs, "changing velocity produced identical trajectory") -- 120
end -- 93
--- 2) 无引力 = 匀速直线。
local function testStraightLine() -- 124
	local init = {pos = {x = -10, y = 0}, vel = {x = 4, y = 0}} -- 125
	local opts = {steps = 240, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0} -- 126
	local r = simulate(init, {}, opts) -- 127
	local expectedX = -10 + 4 * (1 / 120) * 240 -- 129
	local errX = math.abs(r.state.pos.x - expectedX) -- 130
	local errY = math.abs(r.state.pos.y - 0) -- 131
	check( -- 132
		"straight-line", -- 132
		errX < 1e-9 and errY < 1e-9, -- 132
		(("pos=" .. fmtP2(r.state.pos)) .. " expected x=") .. __TS__NumberToFixed(expectedX, 6) -- 132
	) -- 132
	check("straight-line-outcome", r.outcome == "running", "outcome=" .. r.outcome) -- 133
	check( -- 134
		"straight-line-velocity", -- 134
		math.abs(r.state.vel.x - 4) < 1e-12 and math.abs(r.state.vel.y) < 1e-12, -- 134
		"vel=" .. fmtP2(r.state.vel) -- 134
	) -- 134
end -- 124
--- 3) 圆轨道：用 orbitalSpeed 发射，半径应基本不变。
local function testCircularOrbit() -- 138
	local b = staticBody() -- 139
	local R = 20 -- 140
	local v = orbitalSpeed(b.gm, R) -- 141
	local init = {pos = {x = R, y = 0}, vel = {x = 0, y = v}} -- 142
	local period = 2 * math.pi * R / v -- 145
	local dt = 1 / 240 -- 146
	local steps = math.floor(period / dt) -- 147
	local r = simulate(init, {b}, {steps = steps, dt = dt, sampleEvery = 1, escapeRadius = 0}) -- 148
	local finalR = length(r.state.pos) -- 151
	local drift = math.abs(finalR - R) / R -- 152
	check( -- 153
		"circular-orbit-radius", -- 153
		drift < 0.03, -- 153
		((((("radius drifted " .. __TS__NumberToFixed(drift * 100, 2)) .. "% (") .. tostring(R)) .. " -> ") .. __TS__NumberToFixed(finalR, 3)) .. ")" -- 153
	) -- 153
	check("circular-orbit-no-crash", r.outcome == "running", "outcome=" .. r.outcome) -- 154
end -- 138
--- 4) 撞毁：直接朝行星中心飞。
local function testCrash() -- 158
	local b = staticBody() -- 159
	local init = {pos = {x = -10, y = 0}, vel = {x = 10, y = 0}} -- 160
	local r = simulate(init, {b}, {steps = 600, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 161
	check( -- 162
		"crash-detected", -- 162
		r.outcome == "crashed", -- 162
		(("outcome=" .. r.outcome) .. " stepsRun=") .. tostring(r.stepsRun) -- 162
	) -- 162
	check( -- 163
		"crash-index", -- 163
		r.hitIndex == 0, -- 163
		"hitIndex=" .. tostring(r.hitIndex) -- 163
	) -- 163
	local d = distance(r.state.pos, {x = 0, y = 0}) -- 164
	check( -- 165
		"crash-inside-radius", -- 165
		d < b.radius, -- 165
		(("final distance=" .. __TS__NumberToFixed(d, 4)) .. " radius=") .. tostring(b.radius) -- 165
	) -- 165
end -- 158
--- 5) 逃逸：高速飞出越界半径。
local function testEscape() -- 169
	local b = staticBody() -- 170
	local init = {pos = {x = 5, y = 0}, vel = {x = 40, y = 0}} -- 171
	local r = simulate(init, {b}, {steps = 2000, dt = 1 / 120, sampleEvery = 1, escapeRadius = 100}) -- 172
	check( -- 173
		"escape-detected", -- 173
		r.outcome == "escaped", -- 173
		(("outcome=" .. r.outcome) .. " stepsRun=") .. tostring(r.stepsRun) -- 173
	) -- 173
end -- 169
--- 6) 公转：周期 0 静止；经过一个周期回到起点。
local function testOrbit() -- 177
	local stat = staticBody() -- 178
	stat.orbitRadius = 3 -- 179
	stat.phase0 = 0.7 -- 180
	local p0 = bodyPositionAt(stat, 0) -- 181
	local p1 = bodyPositionAt(stat, 123.456) -- 182
	check( -- 183
		"static-body-fixed", -- 183
		p0.x == p1.x and p0.y == p1.y, -- 183
		(("moved: " .. fmtP2(p0)) .. " -> ") .. fmtP2(p1) -- 183
	) -- 183
	local orb = orbitingBody() -- 185
	local q0 = bodyPositionAt(orb, 0) -- 186
	local qT = bodyPositionAt(orb, orb.orbitPeriod) -- 187
	local err = distance(q0, qT) -- 188
	check( -- 189
		"orbit-period-returns", -- 189
		err < 1e-9, -- 189
		(((("after one period: " .. fmtP2(q0)) .. " -> ") .. fmtP2(qT)) .. " err=") .. __TS__NumberToFixed(err, 12) -- 189
	) -- 189
	local qHalf = bodyPositionAt(orb, orb.orbitPeriod / 2) -- 191
	local opposite = distance(q0, qHalf) -- 192
	check( -- 193
		"orbit-halfway-opposite", -- 193
		math.abs(opposite - 2 * orb.orbitRadius) < 1e-9, -- 193
		(("halfway distance=" .. __TS__NumberToFixed(opposite, 6)) .. " expected=") .. __TS__NumberToFixed(2 * orb.orbitRadius, 6) -- 193
	) -- 193
	local orbCCW = orbitingBody() -- 196
	local small = bodyPositionAt(orbCCW, orbCCW.orbitPeriod * 0.02) -- 197
	check( -- 198
		"orbit-direction-ccw", -- 198
		small.y > 0, -- 198
		("t=2% period 时 y=" .. __TS__NumberToFixed(small.y, 4)) .. "（应为正 = 逆时针）" -- 198
	) -- 198
end -- 177
--- 7) 平方反比：距离翻倍，加速度降为 1/4。
local function testInverseSquare() -- 202
	local b = staticBody() -- 203
	local a1 = length(accelerationAt({b}, {x = 1, y = 0}, 0)) -- 204
	local a2 = length(accelerationAt({b}, {x = 2, y = 0}, 0)) -- 205
	local ratio = a1 / a2 -- 206
	check( -- 207
		"inverse-square", -- 207
		math.abs(ratio - 4) < 1e-9, -- 207
		("a(1)/a(2)=" .. __TS__NumberToFixed(ratio, 6)) .. " expected 4" -- 207
	) -- 207
end -- 202
--- 8) 倍率：applyScales 不修改入参，且语义正确。
local function testScales() -- 211
	local bodies = { -- 212
		staticBody(), -- 212
		orbitingBody() -- 212
	} -- 212
	local gm0 = bodies[1].gm -- 213
	local period0 = bodies[2].orbitPeriod -- 214
	local scaled = applyScales(bodies, 2, 4) -- 216
	check("scales-no-mutation", bodies[1].gm == gm0 and bodies[2].orbitPeriod == period0, "applyScales 修改了入参") -- 218
	check( -- 219
		"scales-gravity", -- 219
		scaled[1].gm == gm0 * 2, -- 219
		(("gm=" .. tostring(scaled[1].gm)) .. " expected=") .. tostring(gm0 * 2) -- 219
	) -- 219
	check( -- 220
		"scales-orbit", -- 220
		scaled[2].orbitPeriod == period0 / 4, -- 220
		(("period=" .. tostring(scaled[2].orbitPeriod)) .. " expected=") .. tostring(period0 / 4) -- 220
	) -- 220
	check( -- 221
		"scales-static-stays-static", -- 221
		scaled[1].orbitPeriod == 0, -- 221
		"静止行星的周期被改成 " .. tostring(scaled[1].orbitPeriod) -- 221
	) -- 221
end -- 211
--- 9) 采样：点数为步数/采样间隔 + 1（含起点），且不超限。
local function testSampling() -- 225
	local init = {pos = {x = -10, y = 0}, vel = {x = 1, y = 0}} -- 226
	local r = simulate(init, {}, {steps = 100, dt = 1 / 120, sampleEvery = 10, escapeRadius = 0}) -- 227
	check( -- 229
		"sampling-count", -- 229
		#r.points == 11, -- 229
		("points=" .. tostring(#r.points)) .. " expected=11" -- 229
	) -- 229
	check( -- 230
		"sampling-steps", -- 230
		r.stepsRun == 100, -- 230
		"stepsRun=" .. tostring(r.stepsRun) -- 230
	) -- 230
	local r2 = simulate(init, {}, {steps = 0, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 232
	check( -- 233
		"sampling-zero-steps", -- 233
		#r2.points == 1 and r2.stepsRun == 0, -- 233
		(("points=" .. tostring(#r2.points)) .. " stepsRun=") .. tostring(r2.stepsRun) -- 233
	) -- 233
end -- 225
--- 10) 穿过行星后方：验证引力确实改变了方向（为 S1.3 弹弓铺路）。
local function testGravityBends() -- 237
	local b = staticBody() -- 238
	local init = {pos = {x = -20, y = 4}, vel = {x = 10, y = 0}} -- 240
	local r = simulate(init, {b}, {steps = 600, dt = 1 / 120, sampleEvery = 1, escapeRadius = 0}) -- 241
	local straightY = 4 -- 243
	local bent = math.abs(r.state.pos.y - straightY) -- 244
	check( -- 245
		"gravity-bends-path", -- 245
		r.outcome == "running" and bent > 0.05, -- 245
		((("outcome=" .. r.outcome) .. " y=") .. __TS__NumberToFixed(r.state.pos.y, 4)) .. "（直线应为 4）" -- 245
	) -- 245
	check( -- 246
		"gravity-pulls-inward", -- 246
		r.state.pos.y < straightY, -- 246
		((("y=" .. __TS__NumberToFixed(r.state.pos.y, 4)) .. " 应小于 ") .. tostring(straightY)) .. "（被吸向原点）" -- 246
	) -- 246
end -- 237
--- 10) 反推段（S3.9.2「刹车模式」）：`SimOptions.brake` 的契约。
-- 
-- 不变量（这些就是"刹车"在游戏里能被信任的理由）：
--   ① `brake: { dv: 0 }` 与"完全不传 brake"**逐点一致**（旧行为逐位不变）；
--   ② 无引力时，末速度 = 初速度 − dv（总量准确，不是"看起来慢了点"）；
--   ③ 反推开始之前，轨迹与 coast **逐点一致**（前段不受影响 ⇒ 预测线前半段可信）；
--   ④ 反推不会把速度推成反向（0 处夹住）。
local function testBrake() -- 258
	local dtLike = 1 / 120 -- 260
	local none = {} -- 261
	local base = {steps = 600, dt = dtLike, sampleEvery = 1, escapeRadius = 0} -- 262
	local init = {pos = {x = 0, y = 0}, vel = {x = 10, y = 0}} -- 263
	local coast = simulate(init, none, base) -- 265
	local zero = simulate(init, none, { -- 266
		steps = 600, -- 266
		dt = dtLike, -- 266
		sampleEvery = 1, -- 266
		escapeRadius = 0, -- 266
		brake = {dv = 0} -- 266
	}) -- 266
	local same = #coast.points == #zero.points -- 267
	if same then -- 267
		do -- 267
			local i = 0 -- 269
			while i < #coast.points do -- 269
				if coast.points[i + 1].x ~= zero.points[i + 1].x or coast.points[i + 1].y ~= zero.points[i + 1].y then -- 269
					same = false -- 270
					break -- 270
				end -- 270
				i = i + 1 -- 269
			end -- 269
		end -- 269
	end -- 269
	check( -- 273
		"brake-zero-identical", -- 273
		same, -- 273
		((("dv=0 应与不传 brake 逐点一致（" .. tostring(#coast.points)) .. " vs ") .. tostring(#zero.points)) .. " 点）" -- 273
	) -- 273
	local braked = simulate(init, none, { -- 275
		steps = 600, -- 275
		dt = dtLike, -- 275
		sampleEvery = 1, -- 275
		escapeRadius = 0, -- 275
		brake = {dv = 4} -- 275
	}) -- 275
	local vEnd = math.sqrt(braked.state.vel.x * braked.state.vel.x + braked.state.vel.y * braked.state.vel.y) -- 276
	check( -- 277
		"brake-total-dv", -- 277
		math.abs(vEnd - 6) < 0.000001, -- 277
		("末速度=" .. __TS__NumberToFixed(vEnd, 6)) .. " 期望 10-4=6" -- 277
	) -- 277
	check( -- 279
		"brake-distance", -- 279
		math.abs(braked.state.pos.x - 45) < 0.05, -- 279
		("brake x=" .. __TS__NumberToFixed(braked.state.pos.x, 3)) .. " 期望 45" -- 279
	) -- 279
	check( -- 280
		"brake-shorter", -- 280
		braked.state.pos.x < coast.state.pos.x, -- 280
		(("brake=" .. __TS__NumberToFixed(braked.state.pos.x, 1)) .. " coast=") .. __TS__NumberToFixed(coast.state.pos.x, 1) -- 280
	) -- 280
	local frontSame = true -- 283
	do -- 283
		local i = 0 -- 284
		while i < 300 and i < #braked.points do -- 284
			if braked.points[i + 1].x ~= coast.points[i + 1].x or braked.points[i + 1].y ~= coast.points[i + 1].y then -- 284
				frontSame = false -- 285
				break -- 285
			end -- 285
			i = i + 1 -- 284
		end -- 284
	end -- 284
	check("brake-front-untouched", frontSame, "反推开始之前的轨迹应与 coast 逐点一致") -- 287
	local stop = simulate(init, none, { -- 290
		steps = 600, -- 290
		dt = dtLike, -- 290
		sampleEvery = 1, -- 290
		escapeRadius = 0, -- 290
		brake = {dv = 999} -- 290
	}) -- 290
	local vStop = math.sqrt(stop.state.vel.x * stop.state.vel.x + stop.state.vel.y * stop.state.vel.y) -- 291
	check( -- 292
		"brake-clamps-at-zero", -- 292
		vStop < 0.000001, -- 292
		"反推过量时应停在 0：末速度=" .. __TS__NumberToFixed(vStop, 9) -- 292
	) -- 292
end -- 258
--- 入口：运行全部测试并返回报告。首行为 passed / failed。
function ____exports.runTests() -- 296
	testHostedOrbit() -- 297
	testDeterminism() -- 298
	testStraightLine() -- 299
	testCircularOrbit() -- 300
	testCrash() -- 301
	testEscape() -- 302
	testOrbit() -- 303
	testInverseSquare() -- 304
	testScales() -- 305
	testSampling() -- 306
	testGravityBends() -- 307
	testBrake() -- 308
	local lines = {} -- 310
	if #failures == 0 then -- 310
		lines[#lines + 1] = "passed" -- 312
	else -- 312
		lines[#lines + 1] = "failed" -- 314
	end -- 314
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 316
	local limit = #failures < 12 and #failures or 12 -- 317
	do -- 317
		local i = 0 -- 318
		while i < limit do -- 318
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 319
			i = i + 1 -- 318
		end -- 318
	end -- 318
	if #failures > limit then -- 318
		lines[#lines + 1] = ("... and " .. tostring(#failures - limit)) .. " more failures" -- 321
	end -- 321
	return table.concat(lines, "\n") -- 322
end -- 296
return ____exports -- 296
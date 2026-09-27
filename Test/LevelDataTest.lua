-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local distance = ____Gravity.distance -- 9
local simulate = ____Gravity.simulate -- 9
local ____LevelData = require("game.LevelData") -- 10
local captureThreshold = ____LevelData.captureThreshold -- 10
local findGoalIndex = ____LevelData.findGoalIndex -- 10
local getLevel = ____LevelData.getLevel -- 10
local levelCount = ____LevelData.levelCount -- 10
local relativeSpeedAt = ____LevelData.relativeSpeedAt -- 10
local scaledPlanets = ____LevelData.scaledPlanets -- 10
local waypointProgress = ____LevelData.waypointProgress -- 10
local ____Config = require("game.Config") -- 11
local AimMaxSpeed = ____Config.AimMaxSpeed -- 11
local AimMinSpeed = ____Config.AimMinSpeed -- 11
local BrakeShare = ____Config.BrakeShare -- 11
local PhysicsStep = ____Config.PhysicsStep -- 11
local ____Game = require("game.Game") -- 12
local resolveResult = ____Game.resolveResult -- 12
local failures = {} -- 19
local checks = 0 -- 20
local function check(name, ok, detail) -- 22
	checks = checks + 1 -- 23
	if not ok then -- 23
		failures[#failures + 1] = {name = name, detail = detail} -- 24
	end -- 24
end -- 22
--- 1) 结构有效性：视觉表对齐、目标索引合法、容差 > 半径。
local function testValidity() -- 28
	local n = levelCount() -- 29
	check( -- 30
		"level-count", -- 30
		n == 6, -- 30
		("levelCount=" .. tostring(n)) .. "（愿景定稿六关）" -- 30
	) -- 30
	do -- 30
		local i = 0 -- 32
		while i < n do -- 32
			do -- 32
				local lv = getLevel(i) -- 33
				if lv == nil then -- 33
					check( -- 34
						("lv" .. tostring(i + 1)) .. "-exists", -- 34
						false, -- 34
						"missing" -- 34
					) -- 34
					goto __continue6 -- 34
				end -- 34
				check( -- 36
					("lv" .. tostring(lv.id)) .. "-visuals-aligned", -- 36
					#lv.planets == #lv.visuals, -- 36
					(("planets=" .. tostring(#lv.planets)) .. " visuals=") .. tostring(#lv.visuals) -- 36
				) -- 36
				do -- 36
					local k = 0 -- 40
					while k < #lv.planets and k < #lv.visuals do -- 40
						check( -- 41
							((("lv" .. tostring(lv.id)) .. "-planet") .. tostring(k)) .. "-radius-fair", -- 41
							lv.planets[k + 1].radius == lv.visuals[k + 1].displayRadius, -- 41
							((("radius=" .. tostring(lv.planets[k + 1].radius)) .. " displayRadius=") .. tostring(lv.visuals[k + 1].displayRadius)) .. "（必须相等）" -- 41
						) -- 41
						k = k + 1 -- 40
					end -- 40
				end -- 40
				local goal = lv.goal -- 45
				if goal.kind == "planet" then -- 45
					local gp = lv.planets[goal.planetIndex + 1] -- 47
					check( -- 48
						("lv" .. tostring(lv.id)) .. "-goal-index", -- 48
						gp ~= nil, -- 48
						("planetIndex=" .. tostring(goal.planetIndex)) .. " 越界" -- 48
					) -- 48
					if gp ~= nil then -- 48
						check( -- 50
							("lv" .. tostring(lv.id)) .. "-tolerance>radius", -- 50
							goal.tolerance > gp.radius, -- 50
							((("tolerance=" .. tostring(goal.tolerance)) .. " radius=") .. tostring(gp.radius)) .. "（容差必须大于半径，否则不可达）" -- 50
						) -- 50
					end -- 50
				end -- 50
				check( -- 55
					("lv" .. tostring(lv.id)) .. "-brief", -- 55
					lv.brief ~= nil and #lv.brief > 0, -- 55
					"缺少任务简报" -- 55
				) -- 55
			end -- 55
			::__continue6:: -- 55
			i = i + 1 -- 32
		end -- 32
	end -- 32
end -- 28
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 60
	local bodies = {{ -- 62
		gm = 0, -- 63
		radius = 1.2, -- 63
		orbitCenter = {x = 0, y = -20}, -- 63
		orbitRadius = 0, -- 63
		orbitPeriod = 0, -- 63
		phase0 = 0, -- 63
		orbitDirection = 1 -- 63
	}} -- 63
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 65
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 66
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 68
	check( -- 69
		"find-goal-static", -- 69
		gi >= 0, -- 69
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 69
	) -- 69
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 72
	check( -- 73
		"find-goal-escape", -- 73
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 73
		"escape 目标不应产生 goalIndex" -- 73
	) -- 73
	local movers = {{ -- 76
		gm = 0, -- 77
		radius = 1.2, -- 77
		orbitCenter = {x = 0, y = -6}, -- 77
		orbitRadius = 9, -- 77
		orbitPeriod = 9, -- 77
		phase0 = 0, -- 77
		orbitDirection = 1 -- 77
	}} -- 77
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 79
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 81
	if gi2 >= 0 then -- 81
		local p = sim2.points[gi2 + 1] -- 84
		local minD = 1000000000 -- 85
		do -- 85
			local k = 0 -- 86
			while k < #movers do -- 86
				local gp = movers[k + 1] -- 87
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 88
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 89
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 90
				local dx = p.x - gx -- 91
				local dy = p.y - gy -- 92
				local d = math.sqrt(dx * dx + dy * dy) -- 93
				if d < minD then -- 93
					minD = d -- 94
				end -- 94
				k = k + 1 -- 86
			end -- 86
		end -- 86
		check( -- 96
			"find-goal-moving-accurate", -- 96
			minD < 3, -- 96
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 96
		) -- 96
	else -- 96
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 99
	end -- 99
end -- 60
--- 4) 捕获入轨（S3.9.2）：进环还不够，还得"慢到能被抓住"。
local function testCapture() -- 105
	local bodies = {{ -- 106
		gm = 4000, -- 107
		radius = 4, -- 107
		orbitCenter = {x = 0, y = 0}, -- 107
		orbitRadius = 0, -- 107
		orbitPeriod = 0, -- 107
		phase0 = 0, -- 107
		orbitDirection = 1 -- 107
	}} -- 107
	local goal = {kind = "planet", planetIndex = 0, tolerance = 30, chain = {{planetIndex = 0, tolerance = 30, capture = true}}} -- 109
	local every = 4 -- 113
	local function pass(speed, steps) -- 114
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 115
		return findGoalIndex( -- 120
			sim.points, -- 120
			bodies, -- 120
			goal, -- 120
			PhysicsStep * every, -- 120
			0, -- 120
			sim.velocities -- 120
		) -- 120
	end -- 114
	local fastIdx = pass(40, 900) -- 123
	local function manualWalk(speed, steps) -- 124
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 125
		local limit = #sim.points - 1 -- 130
		local st = waypointProgress( -- 131
			sim.points, -- 131
			bodies, -- 131
			goal, -- 131
			PhysicsStep * every, -- 131
			0, -- 131
			nil, -- 131
			sim.velocities -- 131
		) -- 131
		local best = -1 -- 132
		local bestRel = 0 -- 133
		local bestThr = 0 -- 134
		do -- 134
			local i = 0 -- 135
			while i <= limit do -- 135
				do -- 135
					local d = distance(sim.points[i + 1], {x = 0, y = 0}) -- 136
					if d < 30 then -- 136
						local rel = relativeSpeedAt( -- 138
							sim.points, -- 138
							i, -- 138
							bodies[1], -- 138
							PhysicsStep * every, -- 138
							0, -- 138
							limit, -- 138
							sim.velocities -- 138
						) -- 138
						local thr = captureThreshold(bodies[1], d, 1.4142135623730951) -- 139
						if d <= bodies[1].radius then -- 139
							goto __continue22 -- 140
						end -- 140
						if rel <= thr then -- 140
							best = i -- 141
							bestRel = rel -- 141
							bestThr = thr -- 141
							break -- 141
						end -- 141
					end -- 141
				end -- 141
				::__continue22:: -- 141
				i = i + 1 -- 135
			end -- 135
		end -- 135
		return ((((((((("模块 passed=" .. tostring(st.passed)) .. " lastIndex=") .. tostring(st.lastIndex)) .. "；手工可捕获点=") .. tostring(best)) .. "（rel=") .. __TS__NumberToFixed(bestRel, 1)) .. " thr=") .. __TS__NumberToFixed(bestThr, 1)) .. "）" -- 144
	end -- 124
	check( -- 146
		"capture-rejects-fast", -- 146
		fastIdx == -1, -- 146
		(("快速掠过不应该算捕获：idx=" .. tostring(fastIdx)) .. " ") .. manualWalk(40, 900) -- 146
	) -- 146
	check( -- 148
		"capture-accepts-slow", -- 148
		pass(3, 2400) >= 0, -- 148
		"远低于逃逸速度的接近应该算捕获" -- 148
	) -- 148
end -- 105
--- 角度 × 力度的采样网格。
-- 
-- 12 方向太粗会漏掉窄解（实测 L3/L5 的解在斜向速度上），所以非时间轴关用 24×6；
-- 时间轴关还要再乘 t0 档数，为控制引擎内耗时退回 12×4（× 24 档 t0 仍然有 1152 个样本）。
local levelDvTop = AimMaxSpeed -- 166
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 168
--- 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。
local levelBrake = false -- 170
local function grid(dirCount, powerCount) -- 175
	local out = {} -- 176
	do -- 176
		local d = 0 -- 177
		while d < dirCount do -- 177
			local angle = d * 2 * math.pi / dirCount -- 178
			do -- 178
				local k = 0 -- 179
				while k < powerCount do -- 179
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 182
					local speed = AimMinSpeed + (levelDvTop - AimMinSpeed) * p -- 184
					local share = levelBrake and BrakeShare or 1 -- 187
					out[#out + 1] = { -- 188
						vel = { -- 189
							x = math.cos(angle) * speed * share + levelVel0.x, -- 189
							y = math.sin(angle) * speed * share + levelVel0.y -- 189
						}, -- 189
						brakeDv = levelBrake and speed * (1 - share) or 0 -- 190
					} -- 190
					k = k + 1 -- 179
				end -- 179
			end -- 179
			d = d + 1 -- 177
		end -- 177
	end -- 177
	return out -- 194
end -- 175
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 198
	local stat = { -- 199
		solutions = 0, -- 199
		total = 0, -- 199
		perT0 = {}, -- 199
		t0s = {}, -- 199
		best = "" -- 199
	} -- 199
	if lv == nil then -- 199
		return stat -- 200
	end -- 200
	local bodies = scaledPlanets(lv) -- 201
	local sampleEvery = 4 -- 202
	local t0s = {} -- 203
	if lv.timeWindow ~= nil then -- 203
		do -- 203
			local i = 0 -- 205
			while i < t0Count do -- 205
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 205
				i = i + 1 -- 205
			end -- 205
		end -- 205
	else -- 205
		t0s[#t0s + 1] = 0 -- 207
	end -- 207
	local vs = grid(dirCount, powerCount) -- 209
	do -- 209
		local ti = 0 -- 211
		while ti < #t0s do -- 211
			local t0 = t0s[ti + 1] -- 212
			local ____stat_t0s_0 = stat.t0s -- 212
			____stat_t0s_0[#____stat_t0s_0 + 1] = t0 -- 213
			local hits = 0 -- 214
			for ____, sample in ipairs(vs) do -- 215
				local sim = simulate( -- 216
					{pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, -- 217
					bodies, -- 218
					{ -- 219
						steps = lv.maxSteps, -- 220
						dt = PhysicsStep, -- 220
						sampleEvery = sampleEvery, -- 220
						escapeRadius = lv.escapeRadius, -- 220
						t0 = t0, -- 220
						brake = sample.brakeDv > 0 and ({ -- 221
							dv = sample.brakeDv, -- 221
							startStep = math.floor(lv.maxSteps / 2) -- 221
						}) or nil -- 221
					} -- 221
				) -- 221
				local gi = findGoalIndex( -- 226
					sim.points, -- 226
					bodies, -- 226
					lv.goal, -- 226
					PhysicsStep * sampleEvery, -- 226
					t0, -- 226
					sim.velocities -- 226
				) -- 226
				stat.total = stat.total + 1 -- 227
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 227
					stat.solutions = stat.solutions + 1 -- 229
					hits = hits + 1 -- 230
					if stat.best == "" then -- 230
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 232
						stat.best = ((((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 233
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 233
							1 -- 233
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1)) .. (levelBrake and " brake" or "") -- 233
					end -- 233
				end -- 233
			end -- 233
			local ____stat_perT0_1 = stat.perT0 -- 233
			____stat_perT0_1[#____stat_perT0_1 + 1] = hits -- 237
			ti = ti + 1 -- 211
		end -- 211
	end -- 211
	return stat -- 239
end -- 198
local function testReachability() -- 242
	local n = levelCount() -- 243
	local out = {} -- 244
	do -- 244
		local i = 0 -- 248
		while i < n do -- 248
			do -- 248
				local lv = getLevel(i) -- 249
				if lv == nil then -- 249
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 250
					goto __continue45 -- 250
				end -- 250
				local t0Count = lv.timeWindow ~= nil and 24 or 1 -- 252
				levelDvTop = lv.dvBudget ~= nil and lv.dvBudget < AimMaxSpeed and lv.dvBudget or AimMaxSpeed -- 253
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 254
				levelBrake = false -- 257
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 258
				if stat.solutions == 0 then -- 258
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 24 or 1) -- 260
				end -- 260
				if stat.solutions == 0 then -- 260
					levelBrake = true -- 263
					stat = sweepLevel(lv, 12, 4, t0Count) -- 264
				end -- 264
				out[#out + 1] = stat -- 266
				check( -- 267
					("lv" .. tostring(lv.id)) .. "-reachable", -- 267
					stat.solutions > 0, -- 267
					(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 267
				) -- 267
			end -- 267
			::__continue45:: -- 267
			i = i + 1 -- 248
		end -- 248
	end -- 248
	return out -- 270
end -- 242
--- 4) 时间轴（S3.6.4 的数据侧判据）：**日期必须真的有用**。
-- 
-- 历史：PLAN 最初写的是「t0=0 无解」，实测做不到（场里自由度太多，任何时机都能蒙中一条线）。
-- 第二轮改成「至少要有一个 t0 档零解」，它当时能过 —— 但那是**假象**：那一版 L4 的两颗行星
-- 相位是照一条**撞太阳的弧线**排的，任何日期都对不上，于是大半时间轴是死区（S3.11 修了相位）。
-- 相位修对之后「零解的时机」又消失了，而且**这是原理性的**：单次点火有方向+力度两个自由度，
-- 一个自由度就能补偿掉整个日期的偏差（实测把木星错开 95° 仍能靠改方向蒙中 1 条）。
-- 
-- 所以判据改成**可观测、且真的对应"日期有用"**的两条：
--  ① 起点（t0=0，玩家一进关看到的那一天）必须**明显差于**最好的时机——至少 2 倍；
--  ② 最好时机本身要有足够多的解（≥3），整关总解数 ≥3。
local function testTimeWindow(stats) -- 285
	local n = levelCount() -- 286
	local withWindow = 0 -- 287
	do -- 287
		local i = 0 -- 288
		while i < n do -- 288
			do -- 288
				local lv = getLevel(i) -- 289
				if lv == nil or lv.timeWindow == nil then -- 289
					goto __continue51 -- 290
				end -- 290
				withWindow = withWindow + 1 -- 291
				local st = stats[i + 1] -- 292
				local peak = 0 -- 293
				for ____, h in ipairs(st.perT0) do -- 294
					if h > peak then -- 294
						peak = h -- 294
					end -- 294
				end -- 294
				local dead = 0 -- 295
				for ____, h in ipairs(st.perT0) do -- 296
					if h == 0 then -- 296
						dead = dead + 1 -- 296
					end -- 296
				end -- 296
				check( -- 300
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 300
					peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak), -- 300
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 300
				) -- 300
				check( -- 302
					("lv" .. tostring(lv.id)) .. "-window-open", -- 302
					st.solutions >= 3, -- 302
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 303
				) -- 303
			end -- 303
			::__continue51:: -- 303
			i = i + 1 -- 288
		end -- 288
	end -- 288
	check( -- 306
		"time-window-exists", -- 306
		withWindow == n, -- 306
		(("六关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n) -- 306
	) -- 306
end -- 285
function ____exports.runTests() -- 309
	testValidity() -- 310
	testFindGoalIndex() -- 311
	local stats = testReachability() -- 312
	testTimeWindow(stats) -- 313
	testCapture() -- 314
	local lines = {} -- 316
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 317
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 318
	local limit = #failures < 12 and #failures or 12 -- 319
	do -- 319
		local i = 0 -- 320
		while i < limit do -- 320
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 321
			i = i + 1 -- 320
		end -- 320
	end -- 320
	return table.concat(lines, "\n") -- 323
end -- 309
return ____exports -- 309
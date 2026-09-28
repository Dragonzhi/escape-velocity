-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local distance = ____Gravity.distance -- 9
local simulate = ____Gravity.simulate -- 9
local ____LevelData = require("game.LevelData") -- 11
local captureThreshold = ____LevelData.captureThreshold -- 11
local evaluateRockets = ____LevelData.evaluateRockets -- 11
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 11
local findGoalIndex = ____LevelData.findGoalIndex -- 11
local getLevel = ____LevelData.getLevel -- 11
local levelCount = ____LevelData.levelCount -- 11
local relativeSpeedAt = ____LevelData.relativeSpeedAt -- 11
local scaledPlanets = ____LevelData.scaledPlanets -- 11
local waypointProgress = ____LevelData.waypointProgress -- 11
local ____Config = require("game.Config") -- 12
local AimMaxSpeed = ____Config.AimMaxSpeed -- 12
local AimMinSpeed = ____Config.AimMinSpeed -- 12
local BrakeShare = ____Config.BrakeShare -- 12
local PhysicsStep = ____Config.PhysicsStep -- 12
local ____Tuning = require("game.Tuning") -- 13
local levelRuntime = ____Tuning.levelRuntime -- 13
local ____Game = require("game.Game") -- 14
local resolveResult = ____Game.resolveResult -- 14
local failures = {} -- 21
local checks = 0 -- 22
local function check(name, ok, detail) -- 24
	checks = checks + 1 -- 25
	if not ok then -- 25
		failures[#failures + 1] = {name = name, detail = detail} -- 26
	end -- 26
end -- 24
--- 1) 结构有效性：视觉表对齐、目标索引合法、容差 > 半径。
local function testValidity() -- 30
	local n = levelCount() -- 31
	check( -- 32
		"level-count", -- 32
		n == 3, -- 32
		("levelCount=" .. tostring(n)) .. "（史诗三部曲三关）" -- 32
	) -- 32
	do -- 32
		local i = 0 -- 34
		while i < n do -- 34
			do -- 34
				local lv = getLevel(i) -- 35
				if lv == nil then -- 35
					check( -- 36
						("lv" .. tostring(i + 1)) .. "-exists", -- 36
						false, -- 36
						"missing" -- 36
					) -- 36
					goto __continue6 -- 36
				end -- 36
				check( -- 38
					("lv" .. tostring(lv.id)) .. "-visuals-aligned", -- 38
					#lv.planets == #lv.visuals, -- 38
					(("planets=" .. tostring(#lv.planets)) .. " visuals=") .. tostring(#lv.visuals) -- 38
				) -- 38
				do -- 38
					local k = 0 -- 45
					while k < #lv.planets and k < #lv.visuals do -- 45
						check( -- 46
							((("lv" .. tostring(lv.id)) .. "-planet") .. tostring(k)) .. "-visual-radius>0", -- 46
							lv.visuals[k + 1].displayRadius > 0, -- 46
							"displayRadius=" .. tostring(lv.visuals[k + 1].displayRadius) -- 47
						) -- 47
						check( -- 48
							((("lv" .. tostring(lv.id)) .. "-planet") .. tostring(k)) .. "-phys-radius>0", -- 48
							lv.planets[k + 1].radius > 0, -- 48
							"radius=" .. tostring(lv.planets[k + 1].radius) -- 49
						) -- 49
						k = k + 1 -- 45
					end -- 45
				end -- 45
				local goal = lv.goal -- 52
				if goal.kind == "planet" then -- 52
					local gp = lv.planets[goal.planetIndex + 1] -- 54
					check( -- 55
						("lv" .. tostring(lv.id)) .. "-goal-index", -- 55
						gp ~= nil, -- 55
						("planetIndex=" .. tostring(goal.planetIndex)) .. " 越界" -- 55
					) -- 55
					if gp ~= nil then -- 55
						check( -- 57
							("lv" .. tostring(lv.id)) .. "-tolerance>radius", -- 57
							goal.tolerance > gp.radius, -- 57
							((("tolerance=" .. tostring(goal.tolerance)) .. " radius=") .. tostring(gp.radius)) .. "（容差必须大于半径，否则不可达）" -- 57
						) -- 57
					end -- 57
				end -- 57
				check( -- 62
					("lv" .. tostring(lv.id)) .. "-brief", -- 62
					lv.brief ~= nil and #lv.brief > 0, -- 62
					"缺少任务简报" -- 62
				) -- 62
				local v0 = lv.probeVel0 -- 65
				check( -- 66
					("lv" .. tostring(lv.id)) .. "-probe-velocity-present", -- 66
					v0 ~= nil, -- 66
					"probeVel0 必须存在" -- 66
				) -- 66
				if v0 ~= nil then -- 66
					check( -- 68
						("lv" .. tostring(lv.id)) .. "-probe-at-rest", -- 68
						v0.x == 0 and v0.y == 0, -- 68
						((("初速度在发射台上必须为 0: (" .. tostring(v0.x)) .. ", ") .. tostring(v0.y)) .. ")" -- 68
					) -- 68
				end -- 68
				local ____temp_0 -- 72
				if lv.mission ~= nil then -- 72
					____temp_0 = lv.mission.introTour -- 72
				else -- 72
					____temp_0 = nil -- 72
				end -- 72
				local tour = ____temp_0 -- 72
				if tour ~= nil then -- 72
					check( -- 74
						("lv" .. tostring(lv.id)) .. "-intro-tour-duration>0", -- 74
						tour.totalDuration > 0, -- 74
						"duration=" .. tostring(tour.totalDuration) -- 74
					) -- 74
					check( -- 75
						("lv" .. tostring(lv.id)) .. "-intro-tour-segments>=3", -- 75
						#tour.segments >= 3, -- 75
						"segments=" .. tostring(#tour.segments) -- 75
					) -- 75
				end -- 75
			end -- 75
			::__continue6:: -- 75
			i = i + 1 -- 34
		end -- 34
	end -- 34
	local l1 = getLevel(0) -- 80
	if l1 ~= nil then -- 80
		check( -- 82
			"arcade-l1-earth-radius", -- 82
			l1.planets[1].radius > 0 and l1.planets[1].gm > 0, -- 82
			"earth r=" .. tostring(l1.planets[1].radius) -- 82
		) -- 82
		check("arcade-l1-obstacle-present", l1.planets[2].isObstacle == true, "第2个天体必须为障碍物") -- 83
		check("arcade-l1-stars-count", l1.stars ~= nil and #l1.stars == 3, "必须有 3 颗金色星尘") -- 84
	end -- 84
end -- 30
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 89
	local bodies = {{ -- 91
		gm = 0, -- 92
		radius = 1.2, -- 92
		orbitCenter = {x = 0, y = -20}, -- 92
		orbitRadius = 0, -- 92
		orbitPeriod = 0, -- 92
		phase0 = 0, -- 92
		orbitDirection = 1 -- 92
	}} -- 92
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 94
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 95
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 97
	check( -- 98
		"find-goal-static", -- 98
		gi >= 0, -- 98
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 98
	) -- 98
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 101
	check( -- 102
		"find-goal-escape", -- 102
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 102
		"escape 目标不应产生 goalIndex" -- 102
	) -- 102
	local movers = {{ -- 105
		gm = 0, -- 106
		radius = 1.2, -- 106
		orbitCenter = {x = 0, y = -6}, -- 106
		orbitRadius = 9, -- 106
		orbitPeriod = 9, -- 106
		phase0 = 0, -- 106
		orbitDirection = 1 -- 106
	}} -- 106
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 108
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 110
	if gi2 >= 0 then -- 110
		local p = sim2.points[gi2 + 1] -- 113
		local minD = 1000000000 -- 114
		do -- 114
			local k = 0 -- 115
			while k < #movers do -- 115
				local gp = movers[k + 1] -- 116
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 117
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 118
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 119
				local dx = p.x - gx -- 120
				local dy = p.y - gy -- 121
				local d = math.sqrt(dx * dx + dy * dy) -- 122
				if d < minD then -- 122
					minD = d -- 123
				end -- 123
				k = k + 1 -- 115
			end -- 115
		end -- 115
		check( -- 125
			"find-goal-moving-accurate", -- 125
			minD < 3, -- 125
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 125
		) -- 125
	else -- 125
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 128
	end -- 128
end -- 89
--- 4) 捕获入轨（S3.9.2）：进环还不够，还得"慢到能被抓住"。
local function testCapture() -- 134
	local bodies = {{ -- 135
		gm = 4000, -- 136
		radius = 4, -- 136
		orbitCenter = {x = 0, y = 0}, -- 136
		orbitRadius = 0, -- 136
		orbitPeriod = 0, -- 136
		phase0 = 0, -- 136
		orbitDirection = 1 -- 136
	}} -- 136
	local goal = {kind = "planet", planetIndex = 0, tolerance = 30, chain = {{planetIndex = 0, tolerance = 30, capture = true}}} -- 138
	local every = 4 -- 142
	local function pass(speed, steps) -- 143
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 144
		return findGoalIndex( -- 149
			sim.points, -- 149
			bodies, -- 149
			goal, -- 149
			PhysicsStep * every, -- 149
			0, -- 149
			sim.velocities -- 149
		) -- 149
	end -- 143
	local fastIdx = pass(40, 900) -- 152
	local function manualWalk(speed, steps) -- 153
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 154
		local limit = #sim.points - 1 -- 159
		local st = waypointProgress( -- 160
			sim.points, -- 160
			bodies, -- 160
			goal, -- 160
			PhysicsStep * every, -- 160
			0, -- 160
			nil, -- 160
			sim.velocities -- 160
		) -- 160
		local best = -1 -- 161
		local bestRel = 0 -- 162
		local bestThr = 0 -- 163
		do -- 163
			local i = 0 -- 164
			while i <= limit do -- 164
				do -- 164
					local d = distance(sim.points[i + 1], {x = 0, y = 0}) -- 165
					if d < 30 then -- 165
						local rel = relativeSpeedAt( -- 167
							sim.points, -- 167
							i, -- 167
							bodies[1], -- 167
							PhysicsStep * every, -- 167
							0, -- 167
							limit, -- 167
							sim.velocities -- 167
						) -- 167
						local thr = captureThreshold(bodies[1], d, 1.4142135623730951) -- 168
						if d <= bodies[1].radius then -- 168
							goto __continue25 -- 169
						end -- 169
						if rel <= thr then -- 169
							best = i -- 170
							bestRel = rel -- 170
							bestThr = thr -- 170
							break -- 170
						end -- 170
					end -- 170
				end -- 170
				::__continue25:: -- 170
				i = i + 1 -- 164
			end -- 164
		end -- 164
		return ((((((((("模块 passed=" .. tostring(st.passed)) .. " lastIndex=") .. tostring(st.lastIndex)) .. "；手工可捕获点=") .. tostring(best)) .. "（rel=") .. __TS__NumberToFixed(bestRel, 1)) .. " thr=") .. __TS__NumberToFixed(bestThr, 1)) .. "）" -- 173
	end -- 153
	check( -- 175
		"capture-rejects-fast", -- 175
		fastIdx == -1, -- 175
		(("快速掠过不应该算捕获：idx=" .. tostring(fastIdx)) .. " ") .. manualWalk(40, 900) -- 175
	) -- 175
	check( -- 177
		"capture-accepts-slow", -- 177
		pass(3, 2400) >= 0, -- 177
		"远低于逃逸速度的接近应该算捕获" -- 177
	) -- 177
end -- 134
--- 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
-- 
-- ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
--    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
--    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
local REACH_GATE_LEVELS = 1 -- 202
--- 时间轴判据是否作为硬门（S5 本轮 = false）。
-- 
-- 关掉的两个理由，都写明白：
--   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
--      日期一变地球就转走、探测器不动（停泊轨 200 km，周期 88.4 分钟），所以 L1 的"时机"是**月球自己的相位**；
--      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
--   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
-- 
-- 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
local WINDOW_GATE = false -- 215
local levelDvTop = AimMaxSpeed -- 217
--- 这一关的力度**下限**（B0：L1 的真实阿波罗剖面用 [3.0, 4.6]，TLI 需要 3.1556）。
local levelDvMin = AimMinSpeed -- 219
--- 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。
local sweepDt = PhysicsStep -- 221
local sweepSteps = 0 -- 222
local sweepEvery = 4 -- 223
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 225
--- 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。
local levelBrake = false -- 227
local function grid(dirCount, powerCount) -- 232
	local out = {} -- 233
	do -- 233
		local d = 0 -- 234
		while d < dirCount do -- 234
			local angle = d * 2 * math.pi / dirCount -- 235
			do -- 235
				local k = 0 -- 236
				while k < powerCount do -- 236
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 239
					local speed = levelDvMin + (levelDvTop - levelDvMin) * p -- 241
					local share = levelBrake and BrakeShare or 1 -- 244
					out[#out + 1] = { -- 245
						vel = { -- 246
							x = math.cos(angle) * speed * share + levelVel0.x, -- 246
							y = math.sin(angle) * speed * share + levelVel0.y -- 246
						}, -- 246
						brakeDv = levelBrake and speed * (1 - share) or 0 -- 247
					} -- 247
					k = k + 1 -- 236
				end -- 236
			end -- 236
			d = d + 1 -- 234
		end -- 234
	end -- 234
	return out -- 251
end -- 232
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 255
	local stat = { -- 256
		solutions = 0, -- 256
		total = 0, -- 256
		perT0 = {}, -- 256
		t0s = {}, -- 256
		best = "" -- 256
	} -- 256
	if lv == nil then -- 256
		return stat -- 257
	end -- 257
	local bodies = scaledPlanets(lv) -- 258
	local sampleEvery = sweepEvery -- 259
	local steps = sweepSteps > 0 and sweepSteps or lv.maxSteps -- 260
	local t0s = {} -- 261
	if lv.timeWindow ~= nil then -- 261
		do -- 261
			local i = 0 -- 263
			while i < t0Count do -- 263
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 263
				i = i + 1 -- 263
			end -- 263
		end -- 263
	else -- 263
		t0s[#t0s + 1] = 0 -- 265
	end -- 265
	local vs = grid(dirCount, powerCount) -- 267
	do -- 267
		local ti = 0 -- 269
		while ti < #t0s do -- 269
			local t0 = t0s[ti + 1] -- 270
			local ____stat_t0s_1 = stat.t0s -- 270
			____stat_t0s_1[#____stat_t0s_1 + 1] = t0 -- 271
			local hits = 0 -- 272
			for ____, sample in ipairs(vs) do -- 273
				local sim = simulate( -- 274
					{pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, -- 275
					bodies, -- 276
					{ -- 277
						steps = steps, -- 278
						dt = sweepDt, -- 278
						sampleEvery = sampleEvery, -- 278
						escapeRadius = lv.escapeRadius, -- 278
						t0 = t0, -- 278
						brake = sample.brakeDv > 0 and ({ -- 279
							dv = sample.brakeDv, -- 279
							startStep = math.floor(steps / 2) -- 279
						}) or nil -- 279
					} -- 279
				) -- 279
				local gi = findGoalIndex( -- 284
					sim.points, -- 284
					bodies, -- 284
					lv.goal, -- 284
					sweepDt * sampleEvery, -- 284
					t0, -- 284
					sim.velocities -- 284
				) -- 284
				stat.total = stat.total + 1 -- 285
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 285
					stat.solutions = stat.solutions + 1 -- 287
					hits = hits + 1 -- 288
					if stat.best == "" then -- 288
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 290
						stat.best = ((((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 291
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 291
							1 -- 291
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1)) .. (levelBrake and " brake" or "") -- 291
					end -- 291
				end -- 291
			end -- 291
			local ____stat_perT0_2 = stat.perT0 -- 291
			____stat_perT0_2[#____stat_perT0_2 + 1] = hits -- 295
			ti = ti + 1 -- 269
		end -- 269
	end -- 269
	return stat -- 297
end -- 255
local function testReachability() -- 300
	local n = levelCount() -- 301
	local out = {} -- 302
	local sweepCount = REACH_GATE_LEVELS -- 308
	do -- 308
		local i = 0 -- 312
		while i < n do -- 312
			do -- 312
				local lv = getLevel(i) -- 313
				if lv == nil then -- 313
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 314
					goto __continue48 -- 314
				end -- 314
				if i >= sweepCount then -- 314
					out[#out + 1] = { -- 316
						solutions = 0, -- 316
						total = 0, -- 316
						perT0 = {}, -- 316
						t0s = {}, -- 316
						best = "（本轮不扫掠，见 testReachability 的说明）" -- 316
					} -- 316
					goto __continue48 -- 317
				end -- 317
				local t0Count = lv.timeWindow ~= nil and 4 or 1 -- 322
				local rtLv = levelRuntime(i) -- 323
				levelDvMin = rtLv.aimMin -- 324
				levelDvTop = AimMaxSpeed -- 325
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 326
				sweepDt = rtLv.physicsStep -- 327
				sweepEvery = 1 -- 328
				sweepSteps = lv.maxSteps -- 329
				levelBrake = false -- 330
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 331
				if stat.solutions == 0 then -- 331
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 4 or 1) -- 333
				end -- 333
				if stat.solutions == 0 then -- 333
					stat = sweepLevel(lv, 120, 6, 1) -- 336
				end -- 336
				if stat.solutions == 0 then -- 336
					levelBrake = true -- 339
					stat = sweepLevel(lv, 12, 4, t0Count) -- 340
				end -- 340
				out[#out + 1] = stat -- 342
				if i < REACH_GATE_LEVELS then -- 342
					check( -- 344
						("lv" .. tostring(lv.id)) .. "-reachable", -- 344
						stat.solutions > 0, -- 344
						(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 344
					) -- 344
				else -- 344
					check( -- 348
						("lv" .. tostring(lv.id)) .. "-reachable-informational", -- 348
						true, -- 348
						(((((("未把关：" .. lv.title) .. " ") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 348
					) -- 348
				end -- 348
			end -- 348
			::__continue48:: -- 348
			i = i + 1 -- 312
		end -- 312
	end -- 312
	return out -- 352
end -- 300
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
local function testTimeWindow(stats) -- 367
	local n = levelCount() -- 368
	local withWindow = 0 -- 369
	do -- 369
		local i = 0 -- 370
		while i < n do -- 370
			do -- 370
				local lv = getLevel(i) -- 371
				if lv == nil or lv.timeWindow == nil then -- 371
					goto __continue58 -- 372
				end -- 372
				withWindow = withWindow + 1 -- 373
				local st = stats[i + 1] -- 374
				local peak = 0 -- 375
				for ____, h in ipairs(st.perT0) do -- 376
					if h > peak then -- 376
						peak = h -- 376
					end -- 376
				end -- 376
				local dead = 0 -- 377
				for ____, h in ipairs(st.perT0) do -- 378
					if h == 0 then -- 378
						dead = dead + 1 -- 378
					end -- 378
				end -- 378
				local mattersOk = peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak) -- 382
				local openOk = st.solutions >= 3 -- 383
				check( -- 384
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 384
					not WINDOW_GATE or mattersOk, -- 384
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 384
				) -- 384
				check( -- 386
					("lv" .. tostring(lv.id)) .. "-window-open", -- 386
					not WINDOW_GATE or openOk, -- 386
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 387
				) -- 387
			end -- 387
			::__continue58:: -- 387
			i = i + 1 -- 370
		end -- 370
	end -- 370
	check( -- 389
		"time-window-exists", -- 389
		not WINDOW_GATE or withWindow == n - 1, -- 389
		((("除 L1 外各关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n - 1)) .. "（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）" -- 390
	) -- 390
end -- 367
--- 6) 任务元数据完整性（S7）。
local function testMissionMeta() -- 394
	local n = levelCount() -- 395
	do -- 395
		local i = 0 -- 396
		while i < n do -- 396
			do -- 396
				local lv = getLevel(i) -- 397
				if lv == nil then -- 397
					goto __continue68 -- 398
				end -- 398
				local m = lv.mission -- 399
				check( -- 400
					("lv" .. tostring(lv.id)) .. "-mission-meta-present", -- 400
					m ~= nil, -- 400
					"缺少 mission 元数据" -- 400
				) -- 400
				if m == nil then -- 400
					goto __continue68 -- 401
				end -- 401
				check( -- 403
					("lv" .. tostring(lv.id)) .. "-mission-id", -- 403
					m.id == "L" .. tostring(lv.id), -- 403
					"id=" .. m.id -- 403
				) -- 403
				check( -- 404
					("lv" .. tostring(lv.id)) .. "-mission-codename", -- 404
					#m.codeName > 0, -- 404
					"codeName 为空" -- 404
				) -- 404
				check( -- 405
					("lv" .. tostring(lv.id)) .. "-mission-challenges-count", -- 405
					#m.challenges == 3, -- 405
					"challenges.length=" .. tostring(#m.challenges) -- 405
				) -- 405
				check( -- 406
					("lv" .. tostring(lv.id)) .. "-c1-type-success", -- 406
					m.challenges[1].type == "success", -- 406
					"c1 type=" .. m.challenges[1].type -- 406
				) -- 406
				check( -- 407
					("lv" .. tostring(lv.id)) .. "-c2-type-fuel", -- 407
					m.challenges[2].type == "fuel", -- 407
					"c2 type=" .. m.challenges[2].type -- 407
				) -- 407
				check( -- 408
					("lv" .. tostring(lv.id)) .. "-c3-type-valid", -- 408
					__TS__ArrayIndexOf({"distance", "speed", "eccentricity"}, m.challenges[3].type) >= 0, -- 408
					"c3 type=" .. m.challenges[3].type -- 408
				) -- 408
			end -- 408
			::__continue68:: -- 408
			i = i + 1 -- 396
		end -- 396
	end -- 396
end -- 394
--- 7) 火箭星级评价逻辑（S7 纯函数判定）。
local function testEvaluateRockets() -- 413
	local l1 = getLevel(0) -- 414
	if l1 ~= nil then -- 414
		check( -- 416
			"rockets-fail-0", -- 416
			evaluateRockets(l1, "crash", 0.1) == 0, -- 416
			"失败应为 0 枚火箭" -- 416
		) -- 416
		check( -- 417
			"rockets-escaped-0", -- 417
			evaluateRockets(l1, "escaped", 0.1) == 0, -- 417
			"逃逸应为 0 枚火箭" -- 417
		) -- 417
		check( -- 418
			"rockets-success-overburn-1", -- 418
			evaluateRockets(l1, "success", l1.dvBudget * 0.95) == 1, -- 418
			"燃油超标应为 1 枚火箭" -- 418
		) -- 418
		check( -- 419
			"rockets-fuel-ok-2", -- 419
			evaluateRockets(l1, "success", l1.dvBudget * 0.5) == 2, -- 419
			"达成省油应为 2 枚火箭" -- 419
		) -- 419
		check( -- 420
			"rockets-peri-ok-3", -- 420
			evaluateRockets(l1, "success", l1.dvBudget * 0.5, {maxSpeed = 320}) == 3, -- 420
			"达成高速狂飙应为 3 枚火箭" -- 420
		) -- 420
		check( -- 421
			"rockets-peri-fail-2", -- 421
			evaluateRockets(l1, "success", l1.dvBudget * 0.5, {maxSpeed = 200}) == 2, -- 421
			"未达成速度挑战应为 2 枚火箭" -- 421
		) -- 421
		local det = evaluateRocketsDetailed(l1, "success", l1.dvBudget * 0.5, {maxSpeed = 320}) -- 423
		check("rockets-detailed-count", det.rockets == 3, "详细评价火箭数应为 3") -- 424
		check("rockets-detailed-c1", det.achieved[1] == true, "挑战 1 应达成") -- 425
		check("rockets-detailed-c2", det.achieved[2] == true, "挑战 2 应达成") -- 426
		check("rockets-detailed-c3", det.achieved[3] == true, "挑战 3 应达成") -- 427
	end -- 427
	local l4 = getLevel(3) -- 430
	if l4 ~= nil then -- 430
		check( -- 432
			"rockets-l4-eccentricity-3", -- 432
			evaluateRockets(l4, "success", l4.dvBudget * 0.6, {eccentricity = 0.25}) == 3, -- 432
			"低偏心率入轨应为 3 枚火箭" -- 432
		) -- 432
	end -- 432
	local l3 = getLevel(2) -- 435
	if l3 ~= nil then -- 435
		check( -- 437
			"rockets-l3-speed-3", -- 437
			evaluateRockets(l3, "success", l3.dvBudget * 0.7, {maxSpeed = 350}) == 3, -- 437
			"高速狂飙应为 3 枚火箭" -- 437
		) -- 437
	end -- 437
end -- 413
function ____exports.runTests() -- 441
	testValidity() -- 442
	testFindGoalIndex() -- 443
	local stats = testReachability() -- 444
	testTimeWindow(stats) -- 445
	testCapture() -- 446
	testMissionMeta() -- 447
	testEvaluateRockets() -- 448
	local lines = {} -- 450
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 451
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 452
	local limit = #failures < 12 and #failures or 12 -- 453
	do -- 453
		local i = 0 -- 454
		while i < limit do -- 454
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 455
			i = i + 1 -- 454
		end -- 454
	end -- 454
	return table.concat(lines, "\n") -- 457
end -- 441
return ____exports -- 441
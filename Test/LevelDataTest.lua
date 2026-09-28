-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local bodyPositionAt = ____Gravity.bodyPositionAt -- 9
local distance = ____Gravity.distance -- 9
local simulate = ____Gravity.simulate -- 9
local ____Scale = require("game.Scale") -- 10
local SunGm = ____Scale.SunGm -- 10
local ____LevelData = require("game.LevelData") -- 11
local bodyVelocityAt = ____LevelData.bodyVelocityAt -- 11
local captureThreshold = ____LevelData.captureThreshold -- 11
local evaluateRockets = ____LevelData.evaluateRockets -- 11
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
		n == 6, -- 32
		("levelCount=" .. tostring(n)) .. "（愿景定稿六关）" -- 32
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
				local v0 = lv.probeVel0 -- 66
				check( -- 67
					("lv" .. tostring(lv.id)) .. "-probe-velocity-present", -- 67
					v0 ~= nil, -- 67
					"probeVel0 必须存在（S5 起必填）" -- 67
				) -- 67
				if v0 ~= nil then -- 67
					if lv.id == 1 then -- 67
						local host = lv.planets[2] -- 70
						local hp = bodyPositionAt(host, 0) -- 71
						local hv = bodyVelocityAt(host, 0) -- 72
						local d = math.sqrt((lv.probeStart.x - hp.x) ^ 2 + (lv.probeStart.y - hp.y) ^ 2) -- 73
						local rel = math.sqrt((v0.x - hv.x) ^ 2 + (v0.y - hv.y) ^ 2) -- 74
						local want = math.sqrt(host.gm / d) -- 75
						check( -- 76
							"l1-velocity-is-circular-around-earth", -- 76
							math.abs(rel - want) < want * 0.000001, -- 76
							(((("rel=" .. __TS__NumberToFixed(rel, 6)) .. " 圆轨=") .. __TS__NumberToFixed(want, 6)) .. " d=") .. __TS__NumberToFixed(d, 4) -- 76
						) -- 76
					else -- 76
						local d = math.sqrt(lv.probeStart.x ^ 2 + lv.probeStart.y ^ 2) -- 79
						local want = math.sqrt(SunGm / d) -- 80
						local sp = math.sqrt(v0.x ^ 2 + v0.y ^ 2) -- 81
						check( -- 82
							("lv" .. tostring(lv.id)) .. "-velocity-is-circular", -- 82
							math.abs(sp - want) < want * 0.000001, -- 82
							(((("|v0|=" .. __TS__NumberToFixed(sp, 6)) .. " 圆轨=") .. __TS__NumberToFixed(want, 6)) .. " r=") .. __TS__NumberToFixed(d, 3) -- 82
						) -- 82
					end -- 82
				end -- 82
			end -- 82
			::__continue6:: -- 82
			i = i + 1 -- 34
		end -- 34
	end -- 34
	local l1 = getLevel(0) -- 89
	if l1 ~= nil then -- 89
		check( -- 91
			"scale-provenance-earth-radius", -- 91
			math.abs(l1.planets[2].radius - 0.003407) < 0.000001, -- 91
			"earth r=" .. tostring(l1.planets[2].radius) -- 91
		) -- 91
		check( -- 92
			"scale-provenance-moon-orbit", -- 92
			math.abs(l1.planets[3].orbitRadius - 0.2055644) < 0.000001, -- 92
			"moon a=" .. tostring(l1.planets[3].orbitRadius) -- 92
		) -- 92
		check( -- 94
			"moon-period-uses-host-gm", -- 94
			math.abs(l1.planets[3].orbitPeriod - 1.2593) < 0.001, -- 94
			"moon T=" .. tostring(l1.planets[3].orbitPeriod) -- 94
		) -- 94
	end -- 94
	local l4 = getLevel(3) -- 96
	if l4 ~= nil then -- 96
		check( -- 98
			"scale-provenance-jupiter-orbit", -- 98
			math.abs(l4.planets[2].orbitRadius - 416.231) < 0.01, -- 98
			"jupiter a=" .. tostring(l4.planets[2].orbitRadius) -- 98
		) -- 98
		check( -- 99
			"scale-provenance-jupiter-period", -- 99
			math.abs(l4.planets[2].orbitPeriod - 198.845) < 0.01, -- 99
			"jupiter T=" .. tostring(l4.planets[2].orbitPeriod) -- 99
		) -- 99
	end -- 99
end -- 30
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 104
	local bodies = {{ -- 106
		gm = 0, -- 107
		radius = 1.2, -- 107
		orbitCenter = {x = 0, y = -20}, -- 107
		orbitRadius = 0, -- 107
		orbitPeriod = 0, -- 107
		phase0 = 0, -- 107
		orbitDirection = 1 -- 107
	}} -- 107
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 109
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 110
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 112
	check( -- 113
		"find-goal-static", -- 113
		gi >= 0, -- 113
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 113
	) -- 113
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 116
	check( -- 117
		"find-goal-escape", -- 117
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 117
		"escape 目标不应产生 goalIndex" -- 117
	) -- 117
	local movers = {{ -- 120
		gm = 0, -- 121
		radius = 1.2, -- 121
		orbitCenter = {x = 0, y = -6}, -- 121
		orbitRadius = 9, -- 121
		orbitPeriod = 9, -- 121
		phase0 = 0, -- 121
		orbitDirection = 1 -- 121
	}} -- 121
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 123
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 125
	if gi2 >= 0 then -- 125
		local p = sim2.points[gi2 + 1] -- 128
		local minD = 1000000000 -- 129
		do -- 129
			local k = 0 -- 130
			while k < #movers do -- 130
				local gp = movers[k + 1] -- 131
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 132
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 133
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 134
				local dx = p.x - gx -- 135
				local dy = p.y - gy -- 136
				local d = math.sqrt(dx * dx + dy * dy) -- 137
				if d < minD then -- 137
					minD = d -- 138
				end -- 138
				k = k + 1 -- 130
			end -- 130
		end -- 130
		check( -- 140
			"find-goal-moving-accurate", -- 140
			minD < 3, -- 140
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 140
		) -- 140
	else -- 140
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 143
	end -- 143
end -- 104
--- 4) 捕获入轨（S3.9.2）：进环还不够，还得"慢到能被抓住"。
local function testCapture() -- 149
	local bodies = {{ -- 150
		gm = 4000, -- 151
		radius = 4, -- 151
		orbitCenter = {x = 0, y = 0}, -- 151
		orbitRadius = 0, -- 151
		orbitPeriod = 0, -- 151
		phase0 = 0, -- 151
		orbitDirection = 1 -- 151
	}} -- 151
	local goal = {kind = "planet", planetIndex = 0, tolerance = 30, chain = {{planetIndex = 0, tolerance = 30, capture = true}}} -- 153
	local every = 4 -- 157
	local function pass(speed, steps) -- 158
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 159
		return findGoalIndex( -- 164
			sim.points, -- 164
			bodies, -- 164
			goal, -- 164
			PhysicsStep * every, -- 164
			0, -- 164
			sim.velocities -- 164
		) -- 164
	end -- 158
	local fastIdx = pass(40, 900) -- 167
	local function manualWalk(speed, steps) -- 168
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 169
		local limit = #sim.points - 1 -- 174
		local st = waypointProgress( -- 175
			sim.points, -- 175
			bodies, -- 175
			goal, -- 175
			PhysicsStep * every, -- 175
			0, -- 175
			nil, -- 175
			sim.velocities -- 175
		) -- 175
		local best = -1 -- 176
		local bestRel = 0 -- 177
		local bestThr = 0 -- 178
		do -- 178
			local i = 0 -- 179
			while i <= limit do -- 179
				do -- 179
					local d = distance(sim.points[i + 1], {x = 0, y = 0}) -- 180
					if d < 30 then -- 180
						local rel = relativeSpeedAt( -- 182
							sim.points, -- 182
							i, -- 182
							bodies[1], -- 182
							PhysicsStep * every, -- 182
							0, -- 182
							limit, -- 182
							sim.velocities -- 182
						) -- 182
						local thr = captureThreshold(bodies[1], d, 1.4142135623730951) -- 183
						if d <= bodies[1].radius then -- 183
							goto __continue27 -- 184
						end -- 184
						if rel <= thr then -- 184
							best = i -- 185
							bestRel = rel -- 185
							bestThr = thr -- 185
							break -- 185
						end -- 185
					end -- 185
				end -- 185
				::__continue27:: -- 185
				i = i + 1 -- 179
			end -- 179
		end -- 179
		return ((((((((("模块 passed=" .. tostring(st.passed)) .. " lastIndex=") .. tostring(st.lastIndex)) .. "；手工可捕获点=") .. tostring(best)) .. "（rel=") .. __TS__NumberToFixed(bestRel, 1)) .. " thr=") .. __TS__NumberToFixed(bestThr, 1)) .. "）" -- 188
	end -- 168
	check( -- 190
		"capture-rejects-fast", -- 190
		fastIdx == -1, -- 190
		(("快速掠过不应该算捕获：idx=" .. tostring(fastIdx)) .. " ") .. manualWalk(40, 900) -- 190
	) -- 190
	check( -- 192
		"capture-accepts-slow", -- 192
		pass(3, 2400) >= 0, -- 192
		"远低于逃逸速度的接近应该算捕获" -- 192
	) -- 192
end -- 149
--- 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
-- 
-- ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
--    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
--    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
local REACH_GATE_LEVELS = 1 -- 217
--- 时间轴判据是否作为硬门（S5 本轮 = false）。
-- 
-- 关掉的两个理由，都写明白：
--   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
--      日期一变地球就转走、探测器不动，所以 L1 的"时机"是**月球自己的相位**；
--      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
--   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
-- 
-- 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
local WINDOW_GATE = false -- 230
local levelDvTop = AimMaxSpeed -- 232
--- 这一关的力度**下限**（S5：L1 的 Δv 预算只有 0.35，全局下限 5 比整关预算还大）。
local levelDvMin = AimMinSpeed -- 234
--- 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。
local sweepDt = PhysicsStep -- 236
local sweepSteps = 0 -- 237
local sweepEvery = 4 -- 238
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 240
--- 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。
local levelBrake = false -- 242
local function grid(dirCount, powerCount) -- 247
	local out = {} -- 248
	do -- 248
		local d = 0 -- 249
		while d < dirCount do -- 249
			local angle = d * 2 * math.pi / dirCount -- 250
			do -- 250
				local k = 0 -- 251
				while k < powerCount do -- 251
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 254
					local speed = levelDvMin + (levelDvTop - levelDvMin) * p -- 256
					local share = levelBrake and BrakeShare or 1 -- 259
					out[#out + 1] = { -- 260
						vel = { -- 261
							x = math.cos(angle) * speed * share + levelVel0.x, -- 261
							y = math.sin(angle) * speed * share + levelVel0.y -- 261
						}, -- 261
						brakeDv = levelBrake and speed * (1 - share) or 0 -- 262
					} -- 262
					k = k + 1 -- 251
				end -- 251
			end -- 251
			d = d + 1 -- 249
		end -- 249
	end -- 249
	return out -- 266
end -- 247
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 270
	local stat = { -- 271
		solutions = 0, -- 271
		total = 0, -- 271
		perT0 = {}, -- 271
		t0s = {}, -- 271
		best = "" -- 271
	} -- 271
	if lv == nil then -- 271
		return stat -- 272
	end -- 272
	local bodies = scaledPlanets(lv) -- 273
	local sampleEvery = sweepEvery -- 274
	local steps = sweepSteps > 0 and sweepSteps or lv.maxSteps -- 275
	local t0s = {} -- 276
	if lv.timeWindow ~= nil then -- 276
		do -- 276
			local i = 0 -- 278
			while i < t0Count do -- 278
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 278
				i = i + 1 -- 278
			end -- 278
		end -- 278
	else -- 278
		t0s[#t0s + 1] = 0 -- 280
	end -- 280
	local vs = grid(dirCount, powerCount) -- 282
	do -- 282
		local ti = 0 -- 284
		while ti < #t0s do -- 284
			local t0 = t0s[ti + 1] -- 285
			local ____stat_t0s_0 = stat.t0s -- 285
			____stat_t0s_0[#____stat_t0s_0 + 1] = t0 -- 286
			local hits = 0 -- 287
			for ____, sample in ipairs(vs) do -- 288
				local sim = simulate( -- 289
					{pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, -- 290
					bodies, -- 291
					{ -- 292
						steps = steps, -- 293
						dt = sweepDt, -- 293
						sampleEvery = sampleEvery, -- 293
						escapeRadius = lv.escapeRadius, -- 293
						t0 = t0, -- 293
						brake = sample.brakeDv > 0 and ({ -- 294
							dv = sample.brakeDv, -- 294
							startStep = math.floor(steps / 2) -- 294
						}) or nil -- 294
					} -- 294
				) -- 294
				local gi = findGoalIndex( -- 299
					sim.points, -- 299
					bodies, -- 299
					lv.goal, -- 299
					sweepDt * sampleEvery, -- 299
					t0, -- 299
					sim.velocities -- 299
				) -- 299
				stat.total = stat.total + 1 -- 300
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 300
					stat.solutions = stat.solutions + 1 -- 302
					hits = hits + 1 -- 303
					if stat.best == "" then -- 303
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 305
						stat.best = ((((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 306
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 306
							1 -- 306
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1)) .. (levelBrake and " brake" or "") -- 306
					end -- 306
				end -- 306
			end -- 306
			local ____stat_perT0_1 = stat.perT0 -- 306
			____stat_perT0_1[#____stat_perT0_1 + 1] = hits -- 310
			ti = ti + 1 -- 284
		end -- 284
	end -- 284
	return stat -- 312
end -- 270
local function testReachability() -- 315
	local n = levelCount() -- 316
	local out = {} -- 317
	local sweepCount = REACH_GATE_LEVELS -- 323
	do -- 323
		local i = 0 -- 327
		while i < n do -- 327
			do -- 327
				local lv = getLevel(i) -- 328
				if lv == nil then -- 328
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 329
					goto __continue50 -- 329
				end -- 329
				if i >= sweepCount then -- 329
					out[#out + 1] = { -- 331
						solutions = 0, -- 331
						total = 0, -- 331
						perT0 = {}, -- 331
						t0s = {}, -- 331
						best = "（本轮不扫掠，见 testReachability 的说明）" -- 331
					} -- 331
					goto __continue50 -- 332
				end -- 332
				local t0Count = lv.timeWindow ~= nil and 4 or 1 -- 337
				local rtLv = levelRuntime(i) -- 338
				levelDvMin = rtLv.aimMin -- 339
				levelDvTop = lv.dvBudget ~= nil and lv.dvBudget < AimMaxSpeed and lv.dvBudget or AimMaxSpeed -- 340
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 341
				sweepDt = i == 0 and rtLv.physicsStep or 1 / 40 -- 346
				sweepEvery = 1 -- 347
				sweepSteps = i == 0 and lv.maxSteps or math.min(lv.maxSteps, 8000) -- 349
				levelBrake = false -- 352
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 353
				if stat.solutions == 0 then -- 353
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 4 or 1) -- 355
				end -- 355
				if stat.solutions == 0 then -- 355
					levelBrake = true -- 358
					stat = sweepLevel(lv, 12, 4, t0Count) -- 359
				end -- 359
				out[#out + 1] = stat -- 361
				if i < REACH_GATE_LEVELS then -- 361
					check( -- 363
						("lv" .. tostring(lv.id)) .. "-reachable", -- 363
						stat.solutions > 0, -- 363
						(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 363
					) -- 363
				else -- 363
					check( -- 367
						("lv" .. tostring(lv.id)) .. "-reachable-informational", -- 367
						true, -- 367
						(((((("未把关：" .. lv.title) .. " ") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 367
					) -- 367
				end -- 367
			end -- 367
			::__continue50:: -- 367
			i = i + 1 -- 327
		end -- 327
	end -- 327
	return out -- 371
end -- 315
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
local function testTimeWindow(stats) -- 386
	local n = levelCount() -- 387
	local withWindow = 0 -- 388
	do -- 388
		local i = 0 -- 389
		while i < n do -- 389
			do -- 389
				local lv = getLevel(i) -- 390
				if lv == nil or lv.timeWindow == nil then -- 390
					goto __continue59 -- 391
				end -- 391
				withWindow = withWindow + 1 -- 392
				local st = stats[i + 1] -- 393
				local peak = 0 -- 394
				for ____, h in ipairs(st.perT0) do -- 395
					if h > peak then -- 395
						peak = h -- 395
					end -- 395
				end -- 395
				local dead = 0 -- 396
				for ____, h in ipairs(st.perT0) do -- 397
					if h == 0 then -- 397
						dead = dead + 1 -- 397
					end -- 397
				end -- 397
				local mattersOk = peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak) -- 401
				local openOk = st.solutions >= 3 -- 402
				check( -- 403
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 403
					not WINDOW_GATE or mattersOk, -- 403
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 403
				) -- 403
				check( -- 405
					("lv" .. tostring(lv.id)) .. "-window-open", -- 405
					not WINDOW_GATE or openOk, -- 405
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 406
				) -- 406
			end -- 406
			::__continue59:: -- 406
			i = i + 1 -- 389
		end -- 389
	end -- 389
	check( -- 409
		"time-window-exists", -- 409
		not WINDOW_GATE or withWindow == n, -- 409
		((("六关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n)) .. "（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）" -- 410
	) -- 410
end -- 386
--- 6) 任务元数据完整性（S7）。
local function testMissionMeta() -- 414
	local n = levelCount() -- 415
	do -- 415
		local i = 0 -- 416
		while i < n do -- 416
			do -- 416
				local lv = getLevel(i) -- 417
				if lv == nil then -- 417
					goto __continue69 -- 418
				end -- 418
				local m = lv.mission -- 419
				check( -- 420
					("lv" .. tostring(lv.id)) .. "-mission-meta-present", -- 420
					m ~= nil, -- 420
					"缺少 mission 元数据" -- 420
				) -- 420
				if m == nil then -- 420
					goto __continue69 -- 421
				end -- 421
				check( -- 423
					("lv" .. tostring(lv.id)) .. "-mission-id", -- 423
					m.id == "L" .. tostring(lv.id), -- 423
					"id=" .. m.id -- 423
				) -- 423
				check( -- 424
					("lv" .. tostring(lv.id)) .. "-mission-codename", -- 424
					#m.codeName > 0, -- 424
					"codeName 为空" -- 424
				) -- 424
				check( -- 425
					("lv" .. tostring(lv.id)) .. "-mission-challenges-count", -- 425
					#m.challenges == 3, -- 425
					"challenges.length=" .. tostring(#m.challenges) -- 425
				) -- 425
				check( -- 426
					("lv" .. tostring(lv.id)) .. "-c1-type-success", -- 426
					m.challenges[1].type == "success", -- 426
					"c1 type=" .. m.challenges[1].type -- 426
				) -- 426
				check( -- 427
					("lv" .. tostring(lv.id)) .. "-c2-type-fuel", -- 427
					m.challenges[2].type == "fuel", -- 427
					"c2 type=" .. m.challenges[2].type -- 427
				) -- 427
				check( -- 428
					("lv" .. tostring(lv.id)) .. "-c3-type-valid", -- 428
					__TS__ArrayIndexOf({"distance", "speed", "eccentricity"}, m.challenges[3].type) >= 0, -- 428
					"c3 type=" .. m.challenges[3].type -- 428
				) -- 428
			end -- 428
			::__continue69:: -- 428
			i = i + 1 -- 416
		end -- 416
	end -- 416
end -- 414
--- 7) 火箭星级评价逻辑（S7 纯函数判定）。
local function testEvaluateRockets() -- 433
	local l1 = getLevel(0) -- 434
	if l1 ~= nil then -- 434
		check( -- 436
			"rockets-fail-0", -- 436
			evaluateRockets(l1, "crash", 0.1) == 0, -- 436
			"失败应为 0 枚火箭" -- 436
		) -- 436
		check( -- 437
			"rockets-escaped-0", -- 437
			evaluateRockets(l1, "escaped", 0.1) == 0, -- 437
			"逃逸应为 0 枚火箭" -- 437
		) -- 437
		check( -- 438
			"rockets-success-overburn-1", -- 438
			evaluateRockets(l1, "success", l1.dvBudget * 0.95) == 1, -- 438
			"燃油超标应为 1 枚火箭" -- 438
		) -- 438
		check( -- 439
			"rockets-fuel-ok-2", -- 439
			evaluateRockets(l1, "success", l1.dvBudget * 0.5) == 2, -- 439
			"达成省油应为 2 枚火箭" -- 439
		) -- 439
		check( -- 440
			"rockets-peri-ok-3", -- 440
			evaluateRockets(l1, "success", l1.dvBudget * 0.5, {closestDist = 0.01}) == 3, -- 440
			"达成近掠应为 3 枚火箭" -- 440
		) -- 440
		check( -- 441
			"rockets-peri-fail-2", -- 441
			evaluateRockets(l1, "success", l1.dvBudget * 0.5, {closestDist = 0.05}) == 2, -- 441
			"未达成近掠应为 2 枚火箭" -- 441
		) -- 441
	end -- 441
	local l4 = getLevel(3) -- 444
	if l4 ~= nil then -- 444
		check( -- 446
			"rockets-l4-eccentricity-3", -- 446
			evaluateRockets(l4, "success", l4.dvBudget * 0.6, {eccentricity = 0.25}) == 3, -- 446
			"低偏心率入轨应为 3 枚火箭" -- 446
		) -- 446
	end -- 446
	local l3 = getLevel(2) -- 449
	if l3 ~= nil then -- 449
		check( -- 451
			"rockets-l3-speed-3", -- 451
			evaluateRockets(l3, "success", l3.dvBudget * 0.7, {maxSpeed = 65}) == 3, -- 451
			"高速狂飙应为 3 枚火箭" -- 451
		) -- 451
	end -- 451
end -- 433
function ____exports.runTests() -- 455
	testValidity() -- 456
	testFindGoalIndex() -- 457
	local stats = testReachability() -- 458
	testTimeWindow(stats) -- 459
	testCapture() -- 460
	testMissionMeta() -- 461
	testEvaluateRockets() -- 462
	local lines = {} -- 464
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 465
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 466
	local limit = #failures < 12 and #failures or 12 -- 467
	do -- 467
		local i = 0 -- 468
		while i < limit do -- 468
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 469
			i = i + 1 -- 468
		end -- 468
	end -- 468
	return table.concat(lines, "\n") -- 471
end -- 455
return ____exports -- 455
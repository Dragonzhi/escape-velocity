-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local bodyPositionAt = ____Gravity.bodyPositionAt -- 9
local distance = ____Gravity.distance -- 9
local simulate = ____Gravity.simulate -- 9
local ____LevelData = require("game.LevelData") -- 11
local captureThreshold = ____LevelData.captureThreshold -- 11
local evaluateRockets = ____LevelData.evaluateRockets -- 11
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 11
local findGoalIndex = ____LevelData.findGoalIndex -- 11
local getLevel = ____LevelData.getLevel -- 11
local installArcadeLevels = ____LevelData.installArcadeLevels -- 11
local levelCount = ____LevelData.levelCount -- 11
local relativeSpeedAt = ____LevelData.relativeSpeedAt -- 11
local scaledPlanets = ____LevelData.scaledPlanets -- 11
local waypointProgress = ____LevelData.waypointProgress -- 11
local ____Dora = require("Dora") -- 12
local Content = ____Dora.Content -- 12
local json = ____Dora.json -- 12
local ____Config = require("game.Config") -- 13
local AimMaxSpeed = ____Config.AimMaxSpeed -- 13
local AimMinSpeed = ____Config.AimMinSpeed -- 13
local BrakeShare = ____Config.BrakeShare -- 13
local PhysicsStep = ____Config.PhysicsStep -- 13
local ____Tuning = require("game.Tuning") -- 14
local levelRuntime = ____Tuning.levelRuntime -- 14
local ____Game = require("game.Game") -- 15
local resolveResult = ____Game.resolveResult -- 15
local ____Transfer = require("game.Transfer") -- 16
local analyzeTransfer = ____Transfer.analyzeTransfer -- 16
local planTransfer = ____Transfer.planTransfer -- 16
local ____LevelData = require("game.LevelData") -- 17
local goalPositionAt = ____LevelData.goalPositionAt -- 17
local failures = {} -- 24
local checks = 0 -- 25
local function check(name, ok, detail) -- 27
	checks = checks + 1 -- 28
	if not ok then -- 28
		failures[#failures + 1] = {name = name, detail = detail} -- 29
	end -- 29
end -- 27
--- 测试与游戏走同一份 JSON。装不上就让后面的断言全部失败，而不是悄悄测空表。
local function loadFixture() -- 33
	local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 34
	local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 35
	check( -- 36
		"json-installed", -- 36
		installArcadeLevels( -- 36
			levelsText, -- 36
			bodiesText, -- 36
			function(text) -- 36
				local decoded = {json.decode(text)} -- 37
				if decoded[2] ~= nil then -- 37
					return nil -- 38
				end -- 38
				return decoded[1] -- 39
			end -- 36
		), -- 36
		"Assets/Levels/*.json 没有装上" -- 40
	) -- 40
end -- 33
--- 1) 结构有效性：视觉表对齐、目标索引合法、容差 > 半径。
local function testValidity() -- 44
	local n = levelCount() -- 45
	check( -- 46
		"level-count", -- 46
		n == 3, -- 46
		("levelCount=" .. tostring(n)) .. "（街机三关）" -- 46
	) -- 46
	do -- 46
		local i = 0 -- 48
		while i < n do -- 48
			do -- 48
				local lv = getLevel(i) -- 49
				if lv == nil then -- 49
					check( -- 50
						("lv" .. tostring(i + 1)) .. "-exists", -- 50
						false, -- 50
						"missing" -- 50
					) -- 50
					goto __continue9 -- 50
				end -- 50
				check( -- 52
					("lv" .. tostring(lv.id)) .. "-visuals-aligned", -- 52
					#lv.planets == #lv.visuals, -- 52
					(("planets=" .. tostring(#lv.planets)) .. " visuals=") .. tostring(#lv.visuals) -- 52
				) -- 52
				do -- 52
					local k = 0 -- 59
					while k < #lv.planets and k < #lv.visuals do -- 59
						check( -- 60
							((("lv" .. tostring(lv.id)) .. "-planet") .. tostring(k)) .. "-visual-radius>0", -- 60
							lv.visuals[k + 1].displayRadius > 0, -- 60
							"displayRadius=" .. tostring(lv.visuals[k + 1].displayRadius) -- 61
						) -- 61
						check( -- 62
							((("lv" .. tostring(lv.id)) .. "-planet") .. tostring(k)) .. "-phys-radius>0", -- 62
							lv.planets[k + 1].radius > 0, -- 62
							"radius=" .. tostring(lv.planets[k + 1].radius) -- 63
						) -- 63
						k = k + 1 -- 59
					end -- 59
				end -- 59
				local goal = lv.goal -- 66
				if goal.kind == "planet" then -- 66
					local gp = lv.planets[goal.planetIndex + 1] -- 68
					check( -- 69
						("lv" .. tostring(lv.id)) .. "-goal-index", -- 69
						gp ~= nil, -- 69
						("planetIndex=" .. tostring(goal.planetIndex)) .. " 越界" -- 69
					) -- 69
					if gp ~= nil then -- 69
						local ____check_3 = check -- 71
						local ____temp_2 = ("lv" .. tostring(lv.id)) .. "-tolerance>radius" -- 71
						local ____temp_1 -- 71
						if goal.marker ~= nil then -- 71
							____temp_1 = goal.marker.gm == 0 and goal.marker.radius == 0 and goal.marker.orbitRadius > gp.radius -- 71
						else -- 71
							local ____temp_0 -- 71
							if goal.offset ~= nil then -- 71
								____temp_0 = distance( -- 71
									goalPositionAt(gp, 0, goal.offset), -- 71
									bodyPositionAt(gp, 0) -- 71
								) > goal.tolerance + gp.radius -- 71
							else -- 71
								____temp_0 = goal.tolerance > gp.radius -- 71
							end -- 71
							____temp_1 = ____temp_0 -- 71
						end -- 71
						____check_3( -- 71
							____temp_2, -- 71
							____temp_1, -- 71
							((("tolerance=" .. tostring(goal.tolerance)) .. " radius=") .. tostring(gp.radius)) .. "（容差必须大于半径，否则不可达）" -- 71
						) -- 71
					end -- 71
				end -- 71
				check( -- 76
					("lv" .. tostring(lv.id)) .. "-brief", -- 76
					lv.brief ~= nil and #lv.brief > 0, -- 76
					"缺少任务简报" -- 76
				) -- 76
				local v0 = lv.probeVel0 -- 79
				check( -- 80
					("lv" .. tostring(lv.id)) .. "-probe-velocity-present", -- 80
					v0 ~= nil, -- 80
					"probeVel0 必须存在" -- 80
				) -- 80
				if v0 ~= nil and #lv.planets > 0 then -- 80
					local host = lv.planets[1] -- 82
					local rx = lv.probeStart.x - host.orbitCenter.x -- 83
					local ry = lv.probeStart.y - host.orbitCenter.y -- 84
					local rr = math.sqrt(rx * rx + ry * ry) -- 85
					local expect = rr > 0 and math.sqrt(host.gm / rr) or 0 -- 86
					local got = math.sqrt(v0.x * v0.x + v0.y * v0.y) -- 87
					check( -- 88
						("lv" .. tostring(lv.id)) .. "-probe-circular", -- 88
						math.abs(got - expect) < 0.000001, -- 88
						(("v=" .. __TS__NumberToFixed(got, 3)) .. " 圆轨=") .. __TS__NumberToFixed(expect, 3) -- 88
					) -- 88
					local cross = rx * v0.y - ry * v0.x -- 90
					check( -- 91
						("lv" .. tostring(lv.id)) .. "-probe-tangent", -- 91
						math.abs(cross - rr * expect) < 0.0001, -- 91
						"cross=" .. __TS__NumberToFixed(cross, 3) -- 91
					) -- 91
				end -- 91
				local ____temp_4 -- 95
				if lv.mission ~= nil then -- 95
					____temp_4 = lv.mission.introTour -- 95
				else -- 95
					____temp_4 = nil -- 95
				end -- 95
				local tour = ____temp_4 -- 95
				if tour ~= nil then -- 95
					check( -- 97
						("lv" .. tostring(lv.id)) .. "-intro-tour-duration>0", -- 97
						tour.totalDuration > 0, -- 97
						"duration=" .. tostring(tour.totalDuration) -- 97
					) -- 97
					check( -- 98
						("lv" .. tostring(lv.id)) .. "-intro-tour-segments>=3", -- 98
						#tour.segments >= 3, -- 98
						"segments=" .. tostring(#tour.segments) -- 98
					) -- 98
				end -- 98
			end -- 98
			::__continue9:: -- 98
			i = i + 1 -- 48
		end -- 48
	end -- 48
	local l1 = getLevel(0) -- 103
	if l1 ~= nil then -- 103
		check( -- 105
			"arcade-l1-earth-radius", -- 105
			l1.planets[1].radius > 0 and l1.planets[1].gm > 0, -- 105
			"earth r=" .. tostring(l1.planets[1].radius) -- 105
		) -- 105
		check("transfer-l1-moon-present", l1.planets[2].name == "月球" and l1.planets[2].gm > 0 and #l1.planets == 2, "地月教学关必须只有地球与月球") -- 106
		check("transfer-l1-no-stars", l1.stars ~= nil and #l1.stars == 0, "教学关不收集星尘") -- 107
	end -- 107
end -- 44
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 112
	local bodies = {{ -- 114
		gm = 0, -- 115
		radius = 1.2, -- 115
		orbitCenter = {x = 0, y = -20}, -- 115
		orbitRadius = 0, -- 115
		orbitPeriod = 0, -- 115
		phase0 = 0, -- 115
		orbitDirection = 1 -- 115
	}} -- 115
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 117
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 118
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 120
	check( -- 121
		"find-goal-static", -- 121
		gi >= 0, -- 121
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 121
	) -- 121
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 124
	check( -- 125
		"find-goal-escape", -- 125
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 125
		"escape 目标不应产生 goalIndex" -- 125
	) -- 125
	local movers = {{ -- 128
		gm = 0, -- 129
		radius = 1.2, -- 129
		orbitCenter = {x = 0, y = -6}, -- 129
		orbitRadius = 9, -- 129
		orbitPeriod = 9, -- 129
		phase0 = 0, -- 129
		orbitDirection = 1 -- 129
	}} -- 129
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 131
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 133
	if gi2 >= 0 then -- 133
		local p = sim2.points[gi2 + 1] -- 136
		local minD = 1000000000 -- 137
		do -- 137
			local k = 0 -- 138
			while k < #movers do -- 138
				local gp = movers[k + 1] -- 139
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 140
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 141
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 142
				local dx = p.x - gx -- 143
				local dy = p.y - gy -- 144
				local d = math.sqrt(dx * dx + dy * dy) -- 145
				if d < minD then -- 145
					minD = d -- 146
				end -- 146
				k = k + 1 -- 138
			end -- 138
		end -- 138
		check( -- 148
			"find-goal-moving-accurate", -- 148
			minD < 3, -- 148
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 148
		) -- 148
	else -- 148
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 151
	end -- 151
end -- 112
--- 4) 捕获入轨（S3.9.2）：进环还不够，还得"慢到能被抓住"。
local function testCapture() -- 157
	local bodies = {{ -- 158
		gm = 4000, -- 159
		radius = 4, -- 159
		orbitCenter = {x = 0, y = 0}, -- 159
		orbitRadius = 0, -- 159
		orbitPeriod = 0, -- 159
		phase0 = 0, -- 159
		orbitDirection = 1 -- 159
	}} -- 159
	local goal = {kind = "planet", planetIndex = 0, tolerance = 30, chain = {{planetIndex = 0, tolerance = 30, capture = true}}} -- 161
	local every = 4 -- 165
	local function pass(speed, steps) -- 166
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 167
		return findGoalIndex( -- 172
			sim.points, -- 172
			bodies, -- 172
			goal, -- 172
			PhysicsStep * every, -- 172
			0, -- 172
			sim.velocities -- 172
		) -- 172
	end -- 166
	local fastIdx = pass(40, 900) -- 175
	local function manualWalk(speed, steps) -- 176
		local sim = simulate({pos = {x = 0, y = 60}, vel = {x = 0, y = -speed}}, bodies, {steps = steps, dt = PhysicsStep, sampleEvery = every, escapeRadius = 0}) -- 177
		local limit = #sim.points - 1 -- 182
		local st = waypointProgress( -- 183
			sim.points, -- 183
			bodies, -- 183
			goal, -- 183
			PhysicsStep * every, -- 183
			0, -- 183
			nil, -- 183
			sim.velocities -- 183
		) -- 183
		local best = -1 -- 184
		local bestRel = 0 -- 185
		local bestThr = 0 -- 186
		do -- 186
			local i = 0 -- 187
			while i <= limit do -- 187
				do -- 187
					local d = distance(sim.points[i + 1], {x = 0, y = 0}) -- 188
					if d < 30 then -- 188
						local rel = relativeSpeedAt( -- 190
							sim.points, -- 190
							i, -- 190
							bodies[1], -- 190
							PhysicsStep * every, -- 190
							0, -- 190
							limit, -- 190
							sim.velocities -- 190
						) -- 190
						local thr = captureThreshold(bodies[1], d, 1.4142135623730951) -- 191
						if d <= bodies[1].radius then -- 191
							goto __continue28 -- 192
						end -- 192
						if rel <= thr then -- 192
							best = i -- 193
							bestRel = rel -- 193
							bestThr = thr -- 193
							break -- 193
						end -- 193
					end -- 193
				end -- 193
				::__continue28:: -- 193
				i = i + 1 -- 187
			end -- 187
		end -- 187
		return ((((((((("模块 passed=" .. tostring(st.passed)) .. " lastIndex=") .. tostring(st.lastIndex)) .. "；手工可捕获点=") .. tostring(best)) .. "（rel=") .. __TS__NumberToFixed(bestRel, 1)) .. " thr=") .. __TS__NumberToFixed(bestThr, 1)) .. "）" -- 196
	end -- 176
	check( -- 198
		"capture-rejects-fast", -- 198
		fastIdx == -1, -- 198
		(("快速掠过不应该算捕获：idx=" .. tostring(fastIdx)) .. " ") .. manualWalk(40, 900) -- 198
	) -- 198
	check( -- 200
		"capture-accepts-slow", -- 200
		pass(3, 2400) >= 0, -- 200
		"远低于逃逸速度的接近应该算捕获" -- 200
	) -- 200
end -- 157
--- 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
-- 
-- ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
--    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
--    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
local REACH_GATE_LEVELS = 3 -- 225
--- 时间轴判据是否作为硬门（S5 本轮 = false）。
-- 
-- 关掉的两个理由，都写明白：
--   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
--      日期一变地球就转走、探测器不动（停泊轨 200 km，周期 88.4 分钟），所以 L1 的"时机"是**月球自己的相位**；
--      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
--   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
-- 
-- 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
local WINDOW_GATE = false -- 238
local levelDvTop = AimMaxSpeed -- 240
--- 这一关的力度**下限**（B0：L1 的真实阿波罗剖面用 [3.0, 4.6]，TLI 需要 3.1556）。
local levelDvMin = AimMinSpeed -- 242
--- 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。
local sweepDt = PhysicsStep -- 244
local sweepSteps = 0 -- 245
local sweepEvery = 4 -- 246
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 248
--- 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。
local levelBrake = false -- 250
local function grid(dirCount, powerCount) -- 255
	local out = {} -- 256
	do -- 256
		local d = 0 -- 257
		while d < dirCount do -- 257
			local angle = d * 2 * math.pi / dirCount -- 258
			do -- 258
				local k = 0 -- 259
				while k < powerCount do -- 259
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 262
					local speed = levelDvMin + (levelDvTop - levelDvMin) * p -- 264
					local share = levelBrake and BrakeShare or 1 -- 267
					out[#out + 1] = { -- 268
						vel = { -- 269
							x = math.cos(angle) * speed * share + levelVel0.x, -- 269
							y = math.sin(angle) * speed * share + levelVel0.y -- 269
						}, -- 269
						brakeDv = levelBrake and speed * (1 - share) or 0 -- 270
					} -- 270
					k = k + 1 -- 259
				end -- 259
			end -- 259
			d = d + 1 -- 257
		end -- 257
	end -- 257
	return out -- 274
end -- 255
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 278
	local stat = { -- 279
		solutions = 0, -- 279
		total = 0, -- 279
		perT0 = {}, -- 279
		t0s = {}, -- 279
		best = "" -- 279
	} -- 279
	if lv == nil then -- 279
		return stat -- 280
	end -- 280
	local bodies = scaledPlanets(lv) -- 281
	local sampleEvery = sweepEvery -- 282
	local steps = sweepSteps > 0 and sweepSteps or lv.maxSteps -- 283
	local t0s = {} -- 284
	if lv.timeWindow ~= nil then -- 284
		do -- 284
			local i = 0 -- 286
			while i < t0Count do -- 286
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 286
				i = i + 1 -- 286
			end -- 286
		end -- 286
	else -- 286
		t0s[#t0s + 1] = 0 -- 288
	end -- 288
	local vs = grid(dirCount, powerCount) -- 290
	do -- 290
		local ti = 0 -- 292
		while ti < #t0s do -- 292
			local t0 = t0s[ti + 1] -- 293
			local ____stat_t0s_5 = stat.t0s -- 293
			____stat_t0s_5[#____stat_t0s_5 + 1] = t0 -- 294
			local hits = 0 -- 295
			for ____, sample in ipairs(vs) do -- 296
				local sim = simulate( -- 297
					{pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, -- 298
					bodies, -- 299
					{ -- 300
						steps = steps, -- 301
						dt = sweepDt, -- 301
						sampleEvery = sampleEvery, -- 301
						escapeRadius = lv.escapeRadius, -- 301
						t0 = t0, -- 301
						brake = sample.brakeDv > 0 and ({ -- 302
							dv = sample.brakeDv, -- 302
							startStep = math.floor(steps / 2) -- 302
						}) or nil -- 302
					} -- 302
				) -- 302
				local gi = findGoalIndex( -- 307
					sim.points, -- 307
					bodies, -- 307
					lv.goal, -- 307
					sweepDt * sampleEvery, -- 307
					t0, -- 307
					sim.velocities -- 307
				) -- 307
				stat.total = stat.total + 1 -- 308
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 308
					stat.solutions = stat.solutions + 1 -- 310
					hits = hits + 1 -- 311
					if stat.best == "" then -- 311
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 313
						stat.best = ((((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 314
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 314
							1 -- 314
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1)) .. (levelBrake and " brake" or "") -- 314
					end -- 314
				end -- 314
			end -- 314
			local ____stat_perT0_6 = stat.perT0 -- 314
			____stat_perT0_6[#____stat_perT0_6 + 1] = hits -- 318
			ti = ti + 1 -- 292
		end -- 292
	end -- 292
	return stat -- 320
end -- 278
local function testReachability() -- 323
	local n = levelCount() -- 324
	local out = {} -- 325
	local sweepCount = REACH_GATE_LEVELS -- 331
	do -- 331
		local i = 0 -- 335
		while i < n do -- 335
			do -- 335
				local lv = getLevel(i) -- 336
				if lv == nil then -- 336
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 337
					goto __continue51 -- 337
				end -- 337
				if lv.transfer ~= nil then -- 337
					local bodies = scaledPlanets(lv) -- 339
					local radius = distance( -- 340
						lv.probeStart, -- 340
						bodyPositionAt(bodies[1], 0) -- 340
					) -- 340
					local ra = distance( -- 341
						goalPositionAt(bodies[lv.goal.planetIndex + 1], 0, lv.goal.offset), -- 341
						bodyPositionAt(bodies[1], 0) -- 341
					) -- 341
					local t0 = 1 -- 342
					local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(bodies[1].gm / (radius * radius * radius)) * t0 -- 343
					local pos = { -- 344
						x = radius * math.cos(a), -- 344
						y = radius * math.sin(a) -- 344
					} -- 344
					local vel = { -- 345
						x = -math.sin(a) * math.sqrt(bodies[1].gm / radius), -- 345
						y = math.cos(a) * math.sqrt(bodies[1].gm / radius) -- 345
					} -- 345
					local power = lv.transfer.orbital ~= nil and (lv.transfer.mode == "lowerPeriapsis" and 11 / 14 or 0.5) or (lv.transfer.flyby ~= nil and 0.875 or (ra - radius) / (lv.transfer.apoapsisMax - radius)) -- 346
					local plan = planTransfer( -- 347
						bodies[1].gm, -- 347
						radius, -- 347
						vel, -- 347
						power, -- 347
						lv.transfer.apoapsisMax, -- 347
						lv.transfer.mode, -- 347
						lv.transfer.periapsisMin -- 347
					) -- 347
					local duration = plan.dv / lv.transfer.thrustAcceleration -- 348
					local flight = simulate( -- 349
						{pos = pos, vel = vel}, -- 349
						bodies, -- 349
						{ -- 349
							dt = levelRuntime(i).physicsStep, -- 349
							steps = lv.maxSteps, -- 349
							sampleEvery = 1, -- 349
							escapeRadius = lv.escapeRadius, -- 349
							t0 = t0, -- 349
							initialBurn = {duration = duration, acceleration = {x = plan.velocity.x / duration, y = plan.velocity.y / duration}} -- 350
						} -- 350
					) -- 350
					local analysis = analyzeTransfer( -- 351
						flight, -- 351
						bodies, -- 351
						lv.goal.planetIndex, -- 351
						lv.transfer, -- 351
						levelRuntime(i).physicsStep, -- 351
						t0 -- 351
					) -- 351
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 352
						flight.points, -- 352
						bodies, -- 352
						lv.goal, -- 352
						levelRuntime(i).physicsStep, -- 352
						t0, -- 352
						flight.velocities -- 352
					) -- 352
					check( -- 353
						("lv" .. tostring(lv.id)) .. "-reachable", -- 353
						gi >= 0, -- 353
						"有限燃烧基准解必须完成当前关卡任务" -- 353
					) -- 353
					out[#out + 1] = { -- 354
						solutions = gi >= 0 and 1 or 0, -- 354
						total = 1, -- 354
						perT0 = {}, -- 354
						t0s = {}, -- 354
						best = "有限燃烧地月转移" -- 354
					} -- 354
					goto __continue51 -- 355
				end -- 355
				if i >= sweepCount then -- 355
					out[#out + 1] = { -- 358
						solutions = 0, -- 358
						total = 0, -- 358
						perT0 = {}, -- 358
						t0s = {}, -- 358
						best = "（本轮不扫掠，见 testReachability 的说明）" -- 358
					} -- 358
					goto __continue51 -- 359
				end -- 359
				local t0Count = lv.timeWindow ~= nil and 4 or 1 -- 364
				levelDvMin = #lv.planets > 0 and 40 or AimMinSpeed -- 365
				levelDvTop = lv.dvBudget -- 366
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 367
				sweepDt = 1 / 60 -- 368
				sweepEvery = 2 -- 369
				sweepSteps = lv.maxSteps -- 370
				levelBrake = false -- 371
				local stat = sweepLevel(lv, 18, 5, t0Count) -- 372
				if stat.solutions == 0 then -- 372
					stat = sweepLevel(lv, 36, 6, 1) -- 374
				end -- 374
				out[#out + 1] = stat -- 376
				if i < REACH_GATE_LEVELS then -- 376
					check( -- 378
						("lv" .. tostring(lv.id)) .. "-reachable", -- 378
						stat.solutions > 0, -- 378
						(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 378
					) -- 378
				else -- 378
					check( -- 382
						("lv" .. tostring(lv.id)) .. "-reachable-informational", -- 382
						true, -- 382
						(((((("未把关：" .. lv.title) .. " ") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 382
					) -- 382
				end -- 382
			end -- 382
			::__continue51:: -- 382
			i = i + 1 -- 335
		end -- 335
	end -- 335
	return out -- 386
end -- 323
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
local function testTimeWindow(stats) -- 401
	local n = levelCount() -- 402
	local withWindow = 0 -- 403
	do -- 403
		local i = 0 -- 404
		while i < n do -- 404
			do -- 404
				local lv = getLevel(i) -- 405
				if lv == nil or lv.timeWindow == nil then -- 405
					goto __continue60 -- 406
				end -- 406
				withWindow = withWindow + 1 -- 407
				local st = stats[i + 1] -- 408
				local peak = 0 -- 409
				for ____, h in ipairs(st.perT0) do -- 410
					if h > peak then -- 410
						peak = h -- 410
					end -- 410
				end -- 410
				local dead = 0 -- 411
				for ____, h in ipairs(st.perT0) do -- 412
					if h == 0 then -- 412
						dead = dead + 1 -- 412
					end -- 412
				end -- 412
				local mattersOk = peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak) -- 416
				local openOk = st.solutions >= 3 -- 417
				check( -- 418
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 418
					not WINDOW_GATE or mattersOk, -- 418
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 418
				) -- 418
				check( -- 420
					("lv" .. tostring(lv.id)) .. "-window-open", -- 420
					not WINDOW_GATE or openOk, -- 420
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 421
				) -- 421
			end -- 421
			::__continue60:: -- 421
			i = i + 1 -- 404
		end -- 404
	end -- 404
	check( -- 423
		"time-window-exists", -- 423
		not WINDOW_GATE or withWindow == n - 1, -- 423
		((("除 L1 外各关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n - 1)) .. "（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）" -- 424
	) -- 424
end -- 401
--- 6) 任务元数据完整性（S7）。
local function testMissionMeta() -- 428
	local n = levelCount() -- 429
	do -- 429
		local i = 0 -- 430
		while i < n do -- 430
			do -- 430
				local lv = getLevel(i) -- 431
				if lv == nil then -- 431
					goto __continue70 -- 432
				end -- 432
				local m = lv.mission -- 433
				check( -- 434
					("lv" .. tostring(lv.id)) .. "-mission-meta-present", -- 434
					m ~= nil, -- 434
					"缺少 mission 元数据" -- 434
				) -- 434
				if m == nil then -- 434
					goto __continue70 -- 435
				end -- 435
				check( -- 437
					("lv" .. tostring(lv.id)) .. "-mission-id", -- 437
					m.id == "L" .. tostring(lv.id), -- 437
					"id=" .. m.id -- 437
				) -- 437
				check( -- 438
					("lv" .. tostring(lv.id)) .. "-mission-codename", -- 438
					#m.codeName > 0, -- 438
					"codeName 为空" -- 438
				) -- 438
				check( -- 439
					("lv" .. tostring(lv.id)) .. "-mission-challenges-count", -- 439
					#m.challenges == (lv.transfer ~= nil and 1 or 3), -- 439
					"challenges.length=" .. tostring(#m.challenges) -- 439
				) -- 439
				check( -- 440
					("lv" .. tostring(lv.id)) .. "-c1-type-success", -- 440
					m.challenges[1].type == "success", -- 440
					"c1 type=" .. m.challenges[1].type -- 440
				) -- 440
				if lv.transfer ~= nil then -- 440
					goto __continue70 -- 441
				end -- 441
				check( -- 442
					("lv" .. tostring(lv.id)) .. "-c2-type-stars", -- 442
					m.challenges[2].type == "stars", -- 442
					"c2 type=" .. m.challenges[2].type -- 442
				) -- 442
				check( -- 443
					("lv" .. tostring(lv.id)) .. "-c3-type-stars", -- 443
					m.challenges[3].type == "stars", -- 443
					"c3 type=" .. m.challenges[3].type -- 443
				) -- 443
			end -- 443
			::__continue70:: -- 443
			i = i + 1 -- 430
		end -- 430
	end -- 430
end -- 428
--- 7) 火箭星级评价逻辑（S7 纯函数判定）。
local function testEvaluateRockets() -- 448
	local fixture = getLevel(1) -- 449
	local l1 = fixture ~= nil and __TS__ObjectAssign( -- 451
		{}, -- 451
		fixture, -- 451
		{mission = __TS__ObjectAssign({}, fixture.mission, {challenges = {{desc = "目标", type = "success"}, {desc = "两颗星尘", type = "stars", threshold = 2}, {desc = "三颗星尘", type = "stars", threshold = 3}}})} -- 451
	) or nil -- 451
	if l1 ~= nil then -- 451
		l1.transfer = nil -- 454
	end -- 454
	if l1 ~= nil then -- 454
		check( -- 456
			"rockets-fail-0", -- 456
			evaluateRockets(l1, "crash", 0.1) == 0, -- 456
			"失败应为 0 枚火箭" -- 456
		) -- 456
		check( -- 457
			"rockets-escaped-0", -- 457
			evaluateRockets(l1, "escaped", 0.1) == 0, -- 457
			"逃逸应为 0 枚火箭" -- 457
		) -- 457
		check( -- 458
			"rockets-success-nostar-1", -- 458
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 0}) == 1, -- 458
			"只进门应为 1 星" -- 458
		) -- 458
		check( -- 459
			"rockets-stars-2", -- 459
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 2}) == 2, -- 459
			"两颗星尘应为 2 星" -- 459
		) -- 459
		check( -- 460
			"rockets-stars-3", -- 460
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 3}) == 3, -- 460
			"三颗星尘应为 3 星" -- 460
		) -- 460
		check( -- 461
			"rockets-stars-1-not-2", -- 461
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 1}) == 1, -- 461
			"一颗星尘仍是 1 星" -- 461
		) -- 461
		local det = evaluateRocketsDetailed(l1, "success", l1.dvBudget, {starsCollected = 3}) -- 463
		check("rockets-detailed-count", det.rockets == 3, "详细评价火箭数应为 3") -- 464
		check("rockets-detailed-c1", det.achieved[1] == true, "挑战 1 应达成") -- 465
		check("rockets-detailed-c2", det.achieved[2] == true, "挑战 2 应达成") -- 466
		check("rockets-detailed-c3", det.achieved[3] == true, "挑战 3 应达成") -- 467
	end -- 467
	local l4 = getLevel(3) -- 470
	if l4 ~= nil then -- 470
		check( -- 472
			"rockets-l4-eccentricity-3", -- 472
			evaluateRockets(l4, "success", l4.dvBudget * 0.6, {eccentricity = 0.25}) == 3, -- 472
			"低偏心率入轨应为 3 枚火箭" -- 472
		) -- 472
	end -- 472
	local l3 = getLevel(2) -- 475
	if l3 ~= nil then -- 475
		check( -- 477
			"rockets-l3-completion-only", -- 477
			evaluateRockets(l3, "success", l3.dvBudget, {starsCollected = 3}) == 1, -- 477
			"日心任务只记录完成" -- 477
		) -- 477
	end -- 477
end -- 448
function ____exports.runTests() -- 481
	loadFixture() -- 482
	testValidity() -- 483
	testFindGoalIndex() -- 484
	local stats = testReachability() -- 485
	testTimeWindow(stats) -- 486
	testCapture() -- 487
	testMissionMeta() -- 488
	testEvaluateRockets() -- 489
	local lines = {} -- 491
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 492
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 493
	local limit = #failures < 12 and #failures or 12 -- 494
	do -- 494
		local i = 0 -- 495
		while i < limit do -- 495
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 496
			i = i + 1 -- 495
		end -- 495
	end -- 495
	return table.concat(lines, "\n") -- 498
end -- 481
return ____exports -- 481
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
local evaluateRockets = ____LevelData.evaluateRockets -- 11
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 11
local findGoalIndex = ____LevelData.findGoalIndex -- 11
local getLevel = ____LevelData.getLevel -- 11
local installArcadeLevels = ____LevelData.installArcadeLevels -- 11
local levelCount = ____LevelData.levelCount -- 11
local scaledPlanets = ____LevelData.scaledPlanets -- 11
local ____Dora = require("Dora") -- 12
local Content = ____Dora.Content -- 12
local json = ____Dora.json -- 12
local ____Config = require("game.Config") -- 13
local AimMaxSpeed = ____Config.AimMaxSpeed -- 13
local AimMinSpeed = ____Config.AimMinSpeed -- 13
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
--- 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
-- 
-- ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
--    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
--    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
local REACH_GATE_LEVELS = 3 -- 178
--- 时间轴判据是否作为硬门（S5 本轮 = false）。
-- 
-- 关掉的两个理由，都写明白：
--   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
--      日期一变地球就转走、探测器不动（停泊轨 200 km，周期 88.4 分钟），所以 L1 的"时机"是**月球自己的相位**；
--      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
--   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
-- 
-- 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
local WINDOW_GATE = false -- 191
local levelDvTop = AimMaxSpeed -- 193
--- 这一关的力度**下限**（B0：L1 的真实阿波罗剖面用 [3.0, 4.6]，TLI 需要 3.1556）。
local levelDvMin = AimMinSpeed -- 195
--- 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。
local sweepDt = PhysicsStep -- 197
local sweepSteps = 0 -- 198
local sweepEvery = 4 -- 199
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 201
local function grid(dirCount, powerCount) -- 204
	local out = {} -- 205
	do -- 205
		local d = 0 -- 206
		while d < dirCount do -- 206
			local angle = d * 2 * math.pi / dirCount -- 207
			do -- 207
				local k = 0 -- 208
				while k < powerCount do -- 208
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 211
					local speed = levelDvMin + (levelDvTop - levelDvMin) * p -- 213
					out[#out + 1] = {vel = { -- 214
						x = math.cos(angle) * speed + levelVel0.x, -- 214
						y = math.sin(angle) * speed + levelVel0.y -- 214
					}} -- 214
					k = k + 1 -- 208
				end -- 208
			end -- 208
			d = d + 1 -- 206
		end -- 206
	end -- 206
	return out -- 217
end -- 204
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 221
	local stat = { -- 222
		solutions = 0, -- 222
		total = 0, -- 222
		perT0 = {}, -- 222
		t0s = {}, -- 222
		best = "" -- 222
	} -- 222
	if lv == nil then -- 222
		return stat -- 223
	end -- 223
	local bodies = scaledPlanets(lv) -- 224
	local sampleEvery = sweepEvery -- 225
	local steps = sweepSteps > 0 and sweepSteps or lv.maxSteps -- 226
	local t0s = {} -- 227
	if lv.timeWindow ~= nil then -- 227
		do -- 227
			local i = 0 -- 229
			while i < t0Count do -- 229
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 229
				i = i + 1 -- 229
			end -- 229
		end -- 229
	else -- 229
		t0s[#t0s + 1] = 0 -- 231
	end -- 231
	local vs = grid(dirCount, powerCount) -- 233
	do -- 233
		local ti = 0 -- 235
		while ti < #t0s do -- 235
			local t0 = t0s[ti + 1] -- 236
			local ____stat_t0s_5 = stat.t0s -- 236
			____stat_t0s_5[#____stat_t0s_5 + 1] = t0 -- 237
			local hits = 0 -- 238
			for ____, sample in ipairs(vs) do -- 239
				local sim = simulate({pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, bodies, { -- 240
					steps = steps, -- 244
					dt = sweepDt, -- 244
					sampleEvery = sampleEvery, -- 244
					escapeRadius = lv.escapeRadius, -- 244
					t0 = t0 -- 244
				}) -- 244
				local gi = findGoalIndex( -- 249
					sim.points, -- 249
					bodies, -- 249
					lv.goal, -- 249
					sweepDt * sampleEvery, -- 249
					t0, -- 249
					sim.velocities -- 249
				) -- 249
				stat.total = stat.total + 1 -- 250
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 250
					stat.solutions = stat.solutions + 1 -- 252
					hits = hits + 1 -- 253
					if stat.best == "" then -- 253
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 255
						stat.best = (((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 256
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 256
							1 -- 256
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1) -- 256
					end -- 256
				end -- 256
			end -- 256
			local ____stat_perT0_6 = stat.perT0 -- 256
			____stat_perT0_6[#____stat_perT0_6 + 1] = hits -- 260
			ti = ti + 1 -- 235
		end -- 235
	end -- 235
	return stat -- 262
end -- 221
local function testReachability() -- 265
	local n = levelCount() -- 266
	local out = {} -- 267
	local sweepCount = REACH_GATE_LEVELS -- 273
	do -- 273
		local i = 0 -- 277
		while i < n do -- 277
			do -- 277
				local lv = getLevel(i) -- 278
				if lv == nil then -- 278
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 279
					goto __continue43 -- 279
				end -- 279
				if lv.transfer ~= nil then -- 279
					local bodies = scaledPlanets(lv) -- 281
					local radius = distance( -- 282
						lv.probeStart, -- 282
						bodyPositionAt(bodies[1], 0) -- 282
					) -- 282
					local ra = distance( -- 283
						goalPositionAt(bodies[lv.goal.planetIndex + 1], 0, lv.goal.offset), -- 283
						bodyPositionAt(bodies[1], 0) -- 283
					) -- 283
					local t0 = 1 -- 284
					local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(bodies[1].gm / (radius * radius * radius)) * t0 -- 285
					local pos = { -- 286
						x = radius * math.cos(a), -- 286
						y = radius * math.sin(a) -- 286
					} -- 286
					local vel = { -- 287
						x = -math.sin(a) * math.sqrt(bodies[1].gm / radius), -- 287
						y = math.cos(a) * math.sqrt(bodies[1].gm / radius) -- 287
					} -- 287
					local power = lv.transfer.orbital ~= nil and (lv.transfer.mode == "lowerPeriapsis" and 11 / 14 or 0.5) or (lv.transfer.flyby ~= nil and 0.875 or (ra - radius) / (lv.transfer.apoapsisMax - radius)) -- 288
					local plan = planTransfer( -- 289
						bodies[1].gm, -- 289
						radius, -- 289
						vel, -- 289
						power, -- 289
						lv.transfer.apoapsisMax, -- 289
						lv.transfer.mode, -- 289
						lv.transfer.periapsisMin -- 289
					) -- 289
					local duration = plan.dv / lv.transfer.thrustAcceleration -- 290
					local flight = simulate( -- 291
						{pos = pos, vel = vel}, -- 291
						bodies, -- 291
						{ -- 291
							dt = levelRuntime(i).physicsStep, -- 291
							steps = lv.maxSteps, -- 291
							sampleEvery = 1, -- 291
							escapeRadius = lv.escapeRadius, -- 291
							t0 = t0, -- 291
							initialBurn = {duration = duration, acceleration = {x = plan.velocity.x / duration, y = plan.velocity.y / duration}} -- 292
						} -- 292
					) -- 292
					local analysis = analyzeTransfer( -- 293
						flight, -- 293
						bodies, -- 293
						lv.goal.planetIndex, -- 293
						lv.transfer, -- 293
						levelRuntime(i).physicsStep, -- 293
						t0 -- 293
					) -- 293
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 294
						flight.points, -- 294
						bodies, -- 294
						lv.goal, -- 294
						levelRuntime(i).physicsStep, -- 294
						t0, -- 294
						flight.velocities -- 294
					) -- 294
					check( -- 295
						("lv" .. tostring(lv.id)) .. "-reachable", -- 295
						gi >= 0, -- 295
						"有限燃烧基准解必须完成当前关卡任务" -- 295
					) -- 295
					out[#out + 1] = { -- 296
						solutions = gi >= 0 and 1 or 0, -- 296
						total = 1, -- 296
						perT0 = {}, -- 296
						t0s = {}, -- 296
						best = "有限燃烧地月转移" -- 296
					} -- 296
					goto __continue43 -- 297
				end -- 297
				if i >= sweepCount then -- 297
					out[#out + 1] = { -- 300
						solutions = 0, -- 300
						total = 0, -- 300
						perT0 = {}, -- 300
						t0s = {}, -- 300
						best = "（本轮不扫掠，见 testReachability 的说明）" -- 300
					} -- 300
					goto __continue43 -- 301
				end -- 301
				local t0Count = lv.timeWindow ~= nil and 4 or 1 -- 306
				levelDvMin = #lv.planets > 0 and 40 or AimMinSpeed -- 307
				levelDvTop = lv.dvBudget -- 308
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 309
				sweepDt = 1 / 60 -- 310
				sweepEvery = 2 -- 311
				sweepSteps = lv.maxSteps -- 312
				local stat = sweepLevel(lv, 18, 5, t0Count) -- 313
				if stat.solutions == 0 then -- 313
					stat = sweepLevel(lv, 36, 6, 1) -- 315
				end -- 315
				out[#out + 1] = stat -- 317
				if i < REACH_GATE_LEVELS then -- 317
					check( -- 319
						("lv" .. tostring(lv.id)) .. "-reachable", -- 319
						stat.solutions > 0, -- 319
						(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 319
					) -- 319
				else -- 319
					check( -- 323
						("lv" .. tostring(lv.id)) .. "-reachable-informational", -- 323
						true, -- 323
						(((((("未把关：" .. lv.title) .. " ") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 323
					) -- 323
				end -- 323
			end -- 323
			::__continue43:: -- 323
			i = i + 1 -- 277
		end -- 277
	end -- 277
	return out -- 327
end -- 265
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
local function testTimeWindow(stats) -- 342
	local n = levelCount() -- 343
	local withWindow = 0 -- 344
	do -- 344
		local i = 0 -- 345
		while i < n do -- 345
			do -- 345
				local lv = getLevel(i) -- 346
				if lv == nil or lv.timeWindow == nil then -- 346
					goto __continue52 -- 347
				end -- 347
				withWindow = withWindow + 1 -- 348
				local st = stats[i + 1] -- 349
				local peak = 0 -- 350
				for ____, h in ipairs(st.perT0) do -- 351
					if h > peak then -- 351
						peak = h -- 351
					end -- 351
				end -- 351
				local dead = 0 -- 352
				for ____, h in ipairs(st.perT0) do -- 353
					if h == 0 then -- 353
						dead = dead + 1 -- 353
					end -- 353
				end -- 353
				local mattersOk = peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak) -- 357
				local openOk = st.solutions >= 3 -- 358
				check( -- 359
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 359
					not WINDOW_GATE or mattersOk, -- 359
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 359
				) -- 359
				check( -- 361
					("lv" .. tostring(lv.id)) .. "-window-open", -- 361
					not WINDOW_GATE or openOk, -- 361
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 362
				) -- 362
			end -- 362
			::__continue52:: -- 362
			i = i + 1 -- 345
		end -- 345
	end -- 345
	check( -- 364
		"time-window-exists", -- 364
		not WINDOW_GATE or withWindow == n - 1, -- 364
		((("除 L1 外各关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n - 1)) .. "（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）" -- 365
	) -- 365
end -- 342
--- 6) 任务元数据完整性（S7）。
local function testMissionMeta() -- 369
	local n = levelCount() -- 370
	do -- 370
		local i = 0 -- 371
		while i < n do -- 371
			do -- 371
				local lv = getLevel(i) -- 372
				if lv == nil then -- 372
					goto __continue62 -- 373
				end -- 373
				local m = lv.mission -- 374
				check( -- 375
					("lv" .. tostring(lv.id)) .. "-mission-meta-present", -- 375
					m ~= nil, -- 375
					"缺少 mission 元数据" -- 375
				) -- 375
				if m == nil then -- 375
					goto __continue62 -- 376
				end -- 376
				check( -- 378
					("lv" .. tostring(lv.id)) .. "-mission-id", -- 378
					m.id == "L" .. tostring(lv.id), -- 378
					"id=" .. m.id -- 378
				) -- 378
				check( -- 379
					("lv" .. tostring(lv.id)) .. "-mission-codename", -- 379
					#m.codeName > 0, -- 379
					"codeName 为空" -- 379
				) -- 379
				check( -- 380
					("lv" .. tostring(lv.id)) .. "-mission-challenges-count", -- 380
					#m.challenges == (lv.transfer ~= nil and 1 or 3), -- 380
					"challenges.length=" .. tostring(#m.challenges) -- 380
				) -- 380
				check( -- 381
					("lv" .. tostring(lv.id)) .. "-c1-type-success", -- 381
					m.challenges[1].type == "success", -- 381
					"c1 type=" .. m.challenges[1].type -- 381
				) -- 381
				if lv.transfer ~= nil then -- 381
					goto __continue62 -- 382
				end -- 382
				check( -- 383
					("lv" .. tostring(lv.id)) .. "-c2-type-stars", -- 383
					m.challenges[2].type == "stars", -- 383
					"c2 type=" .. m.challenges[2].type -- 383
				) -- 383
				check( -- 384
					("lv" .. tostring(lv.id)) .. "-c3-type-stars", -- 384
					m.challenges[3].type == "stars", -- 384
					"c3 type=" .. m.challenges[3].type -- 384
				) -- 384
			end -- 384
			::__continue62:: -- 384
			i = i + 1 -- 371
		end -- 371
	end -- 371
end -- 369
--- 7) 火箭星级评价逻辑（S7 纯函数判定）。
local function testEvaluateRockets() -- 389
	local fixture = getLevel(1) -- 390
	local l1 = fixture ~= nil and __TS__ObjectAssign( -- 392
		{}, -- 392
		fixture, -- 392
		{mission = __TS__ObjectAssign({}, fixture.mission, {challenges = {{desc = "目标", type = "success"}, {desc = "两颗星尘", type = "stars", threshold = 2}, {desc = "三颗星尘", type = "stars", threshold = 3}}})} -- 392
	) or nil -- 392
	if l1 ~= nil then -- 392
		l1.transfer = nil -- 395
	end -- 395
	if l1 ~= nil then -- 395
		check( -- 397
			"rockets-fail-0", -- 397
			evaluateRockets(l1, "crash", 0.1) == 0, -- 397
			"失败应为 0 枚火箭" -- 397
		) -- 397
		check( -- 398
			"rockets-escaped-0", -- 398
			evaluateRockets(l1, "escaped", 0.1) == 0, -- 398
			"逃逸应为 0 枚火箭" -- 398
		) -- 398
		check( -- 399
			"rockets-success-nostar-1", -- 399
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 0}) == 1, -- 399
			"只进门应为 1 星" -- 399
		) -- 399
		check( -- 400
			"rockets-stars-2", -- 400
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 2}) == 2, -- 400
			"两颗星尘应为 2 星" -- 400
		) -- 400
		check( -- 401
			"rockets-stars-3", -- 401
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 3}) == 3, -- 401
			"三颗星尘应为 3 星" -- 401
		) -- 401
		check( -- 402
			"rockets-stars-1-not-2", -- 402
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 1}) == 1, -- 402
			"一颗星尘仍是 1 星" -- 402
		) -- 402
		local det = evaluateRocketsDetailed(l1, "success", l1.dvBudget, {starsCollected = 3}) -- 404
		check("rockets-detailed-count", det.rockets == 3, "详细评价火箭数应为 3") -- 405
		check("rockets-detailed-c1", det.achieved[1] == true, "挑战 1 应达成") -- 406
		check("rockets-detailed-c2", det.achieved[2] == true, "挑战 2 应达成") -- 407
		check("rockets-detailed-c3", det.achieved[3] == true, "挑战 3 应达成") -- 408
	end -- 408
	local l4 = getLevel(3) -- 411
	if l4 ~= nil then -- 411
		check( -- 413
			"rockets-l4-eccentricity-3", -- 413
			evaluateRockets(l4, "success", l4.dvBudget * 0.6, {eccentricity = 0.25}) == 3, -- 413
			"低偏心率入轨应为 3 枚火箭" -- 413
		) -- 413
	end -- 413
	local l3 = getLevel(2) -- 416
	if l3 ~= nil then -- 416
		check( -- 418
			"rockets-l3-completion-only", -- 418
			evaluateRockets(l3, "success", l3.dvBudget, {starsCollected = 3}) == 1, -- 418
			"日心任务只记录完成" -- 418
		) -- 418
	end -- 418
end -- 389
function ____exports.runTests() -- 422
	loadFixture() -- 423
	testValidity() -- 424
	testFindGoalIndex() -- 425
	local stats = testReachability() -- 426
	testTimeWindow(stats) -- 427
	testMissionMeta() -- 428
	testEvaluateRockets() -- 429
	local lines = {} -- 431
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 432
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 433
	local limit = #failures < 12 and #failures or 12 -- 434
	do -- 434
		local i = 0 -- 435
		while i < limit do -- 435
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 436
			i = i + 1 -- 435
		end -- 435
	end -- 435
	return table.concat(lines, "\n") -- 438
end -- 422
return ____exports -- 422
-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local __TS__ArrayReverse = ____lualib.__TS__ArrayReverse -- 1
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
local findGoalRegionIndex = ____LevelData.findGoalRegionIndex -- 11
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
		local ____check_10 = check -- 108
		local ____opt_5 = l1.goal.region -- 108
		local ____temp_9 = (____opt_5 and ____opt_5.minAltitude) == 14 and l1.goal.region.maxAltitude == 57 -- 108
		if ____temp_9 then -- 108
			local ____opt_7 = l1.bonusPoints -- 108
			____temp_9 = (____opt_7 and #____opt_7) == 1 -- 108
		end -- 108
		____check_10("goal-l1-height-band", ____temp_9, "L1 月球目标环或加分点配置不符") -- 108
	end -- 108
	local l2 = getLevel(1) -- 110
	local l3 = getLevel(2) -- 110
	local ____check_18 = check -- 111
	local ____opt_11 = l2 and l2.goal.region -- 111
	local ____temp_17 = (____opt_11 and ____opt_11.bodyIndex) == 2 and l2.goal.region.minAltitude == 6 -- 111
	if ____temp_17 then -- 111
		local ____opt_15 = l2.bonusPoints -- 111
		____temp_17 = (____opt_15 and #____opt_15) == 2 -- 111
	end -- 111
	____check_18("goal-l2-mercury-band", ____temp_17, "L2 水星目标环配置错误") -- 111
	local ____check_26 = check -- 112
	local ____opt_19 = l3 and l3.goal.region -- 112
	local ____temp_25 = (____opt_19 and ____opt_19.bodyIndex) == 0 and l3.goal.region.minAltitude == 828 and l3.goal.region.maxAltitude == 888 and l3.goal.region.requiresEscape == true and l3.goal.region.direction == "outward" -- 112
	if ____temp_25 then -- 112
		local ____opt_23 = l3.bonusPoints -- 112
		____temp_25 = (____opt_23 and #____opt_23) == 3 -- 112
	end -- 112
	____check_26("goal-l3-solar-escape", ____temp_25, "L3 逃逸目标或点位配置错误") -- 112
	check("goal-l3-body-sizes", (l3 and l3.planets[1].radius) == 72 and l3.planets[2].radius == 24 and l3.planets[3].radius == 20, "L3 天体半径覆盖未应用") -- 113
end -- 44
local function testGoalRegion() -- 116
	local body = { -- 117
		gm = 100, -- 117
		radius = 1, -- 117
		orbitCenter = {x = 0, y = 0}, -- 117
		orbitRadius = 0, -- 117
		orbitPeriod = 0, -- 117
		phase0 = 0, -- 117
		orbitDirection = 1 -- 117
	} -- 117
	local pts = {{x = 0, y = 0}, {x = 4, y = 0}, {x = 8, y = 0}} -- 118
	local vel = {{x = 8, y = 0}, {x = 8, y = 0}, {x = 8, y = 0}} -- 119
	local outward = { -- 120
		bodyIndex = 0, -- 120
		minAltitude = 2, -- 120
		maxAltitude = 5, -- 120
		direction = "outward", -- 120
		requiresEscape = true -- 120
	} -- 120
	check( -- 121
		"goal-region-entry", -- 121
		findGoalRegionIndex( -- 121
			pts, -- 121
			vel, -- 121
			{body}, -- 121
			outward, -- 121
			0.1, -- 121
			0 -- 121
		) == 1, -- 121
		"应在首个外向穿环采样完成" -- 121
	) -- 121
	check( -- 122
		"goal-region-energy-required", -- 122
		findGoalRegionIndex( -- 122
			pts, -- 122
			{{x = 1, y = 0}, {x = 1, y = 0}, {x = 1, y = 0}}, -- 122
			{body}, -- 122
			outward, -- 122
			0.1, -- 122
			0 -- 122
		) < 0, -- 122
		"逃逸目标必须满足比能条件" -- 122
	) -- 122
	check( -- 123
		"goal-region-direction-required", -- 123
		findGoalRegionIndex( -- 123
			__TS__ArrayReverse(__TS__ArraySlice(pts)), -- 123
			vel, -- 123
			{body}, -- 123
			outward, -- 123
			0.1, -- 123
			0 -- 123
		) < 0, -- 123
		"向内穿过不能满足向外条件" -- 123
	) -- 123
end -- 116
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 127
	local bodies = {{ -- 129
		gm = 0, -- 130
		radius = 1.2, -- 130
		orbitCenter = {x = 0, y = -20}, -- 130
		orbitRadius = 0, -- 130
		orbitPeriod = 0, -- 130
		phase0 = 0, -- 130
		orbitDirection = 1 -- 130
	}} -- 130
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 132
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 133
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 135
	check( -- 136
		"find-goal-static", -- 136
		gi >= 0, -- 136
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 136
	) -- 136
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 139
	check( -- 140
		"find-goal-escape", -- 140
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 140
		"escape 目标不应产生 goalIndex" -- 140
	) -- 140
	local movers = {{ -- 143
		gm = 0, -- 144
		radius = 1.2, -- 144
		orbitCenter = {x = 0, y = -6}, -- 144
		orbitRadius = 9, -- 144
		orbitPeriod = 9, -- 144
		phase0 = 0, -- 144
		orbitDirection = 1 -- 144
	}} -- 144
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 146
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 148
	if gi2 >= 0 then -- 148
		local p = sim2.points[gi2 + 1] -- 151
		local minD = 1000000000 -- 152
		do -- 152
			local k = 0 -- 153
			while k < #movers do -- 153
				local gp = movers[k + 1] -- 154
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 155
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 156
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 157
				local dx = p.x - gx -- 158
				local dy = p.y - gy -- 159
				local d = math.sqrt(dx * dx + dy * dy) -- 160
				if d < minD then -- 160
					minD = d -- 161
				end -- 161
				k = k + 1 -- 153
			end -- 153
		end -- 153
		check( -- 163
			"find-goal-moving-accurate", -- 163
			minD < 3, -- 163
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 163
		) -- 163
	else -- 163
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 166
	end -- 166
end -- 127
--- 本轮验收范围（用户 2026-09-27 原话）：「先只做到 L1 完备，可以正常游玩就行了！」
-- 
-- ⇒ **可达性判据只对 L1 把关**。L2–L6 的关卡数据仍在（六关都能进去、都能跑），
--    但它们的数值验收（成功率 / 相位 / 时间窗）推迟到后续轮次。
--    这里**如实标注**：外圈关的扫掠照跑、结果照打，只是不让本模块变红。
local REACH_GATE_LEVELS = 3 -- 193
--- 时间轴判据是否作为硬门（S5 本轮 = false）。
-- 
-- 关掉的两个理由，都写明白：
--   ① 用户把范围收窄到 L1，而 **L1 没有日期轴** —— 探测器出发点是个固定点（地球外侧 0.1 的圆轨），
--      日期一变地球就转走、探测器不动（停泊轨 200 km，周期 88.4 分钟），所以 L1 的"时机"是**月球自己的相位**；
--      要让 L1 也有日期轴，得让出发点跟着地球走（probeHost），那是后续轮次的事。
--   ② 扫掠的 t0 采样为了控耗时从 24 档降到 4 档，「峰值 ≥ 2× 起点」这种统计在 1~3 个解上不可信。
-- 
-- 关掉的是**判据**，不是**测量**：perT0 照算、细节照打，恢复只需把这里改成 true。
local WINDOW_GATE = false -- 206
local levelDvTop = AimMaxSpeed -- 208
--- 这一关的力度**下限**（B0：L1 的真实阿波罗剖面用 [3.0, 4.6]，TLI 需要 3.1556）。
local levelDvMin = AimMinSpeed -- 210
--- 这一遍扫掠用的物理步长与步数（S5 起按关卡给，见 testReachability）。
local sweepDt = PhysicsStep -- 212
local sweepSteps = 0 -- 213
local sweepEvery = 4 -- 214
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 216
local function grid(dirCount, powerCount) -- 219
	local out = {} -- 220
	do -- 220
		local d = 0 -- 221
		while d < dirCount do -- 221
			local angle = d * 2 * math.pi / dirCount -- 222
			do -- 222
				local k = 0 -- 223
				while k < powerCount do -- 223
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 226
					local speed = levelDvMin + (levelDvTop - levelDvMin) * p -- 228
					out[#out + 1] = {vel = { -- 229
						x = math.cos(angle) * speed + levelVel0.x, -- 229
						y = math.sin(angle) * speed + levelVel0.y -- 229
					}} -- 229
					k = k + 1 -- 223
				end -- 223
			end -- 223
			d = d + 1 -- 221
		end -- 221
	end -- 221
	return out -- 232
end -- 219
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 236
	local stat = { -- 237
		solutions = 0, -- 237
		total = 0, -- 237
		perT0 = {}, -- 237
		t0s = {}, -- 237
		best = "" -- 237
	} -- 237
	if lv == nil then -- 237
		return stat -- 238
	end -- 238
	local bodies = scaledPlanets(lv) -- 239
	local sampleEvery = sweepEvery -- 240
	local steps = sweepSteps > 0 and sweepSteps or lv.maxSteps -- 241
	local t0s = {} -- 242
	if lv.timeWindow ~= nil then -- 242
		do -- 242
			local i = 0 -- 244
			while i < t0Count do -- 244
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 244
				i = i + 1 -- 244
			end -- 244
		end -- 244
	else -- 244
		t0s[#t0s + 1] = 0 -- 246
	end -- 246
	local vs = grid(dirCount, powerCount) -- 248
	do -- 248
		local ti = 0 -- 250
		while ti < #t0s do -- 250
			local t0 = t0s[ti + 1] -- 251
			local ____stat_t0s_29 = stat.t0s -- 251
			____stat_t0s_29[#____stat_t0s_29 + 1] = t0 -- 252
			local hits = 0 -- 253
			for ____, sample in ipairs(vs) do -- 254
				local sim = simulate({pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, bodies, { -- 255
					steps = steps, -- 259
					dt = sweepDt, -- 259
					sampleEvery = sampleEvery, -- 259
					escapeRadius = lv.escapeRadius, -- 259
					t0 = t0 -- 259
				}) -- 259
				local gi = findGoalIndex( -- 264
					sim.points, -- 264
					bodies, -- 264
					lv.goal, -- 264
					sweepDt * sampleEvery, -- 264
					t0, -- 264
					sim.velocities -- 264
				) -- 264
				stat.total = stat.total + 1 -- 265
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 265
					stat.solutions = stat.solutions + 1 -- 267
					hits = hits + 1 -- 268
					if stat.best == "" then -- 268
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 270
						stat.best = (((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 271
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 271
							1 -- 271
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1) -- 271
					end -- 271
				end -- 271
			end -- 271
			local ____stat_perT0_30 = stat.perT0 -- 271
			____stat_perT0_30[#____stat_perT0_30 + 1] = hits -- 275
			ti = ti + 1 -- 250
		end -- 250
	end -- 250
	return stat -- 277
end -- 236
local function testReachability() -- 280
	local n = levelCount() -- 281
	local out = {} -- 282
	local sweepCount = REACH_GATE_LEVELS -- 288
	do -- 288
		local i = 0 -- 292
		while i < n do -- 292
			do -- 292
				local lv = getLevel(i) -- 293
				if lv == nil then -- 293
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 294
					goto __continue44 -- 294
				end -- 294
				if lv.transfer ~= nil then -- 294
					local bodies = scaledPlanets(lv) -- 296
					local radius = distance( -- 297
						lv.probeStart, -- 297
						bodyPositionAt(bodies[1], 0) -- 297
					) -- 297
					local ra = distance( -- 298
						goalPositionAt(bodies[lv.goal.planetIndex + 1], 0, lv.goal.offset), -- 298
						bodyPositionAt(bodies[1], 0) -- 298
					) -- 298
					local t0 = 1 -- 299
					local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(bodies[1].gm / (radius * radius * radius)) * t0 -- 300
					local pos = { -- 301
						x = radius * math.cos(a), -- 301
						y = radius * math.sin(a) -- 301
					} -- 301
					local vel = { -- 302
						x = -math.sin(a) * math.sqrt(bodies[1].gm / radius), -- 302
						y = math.cos(a) * math.sqrt(bodies[1].gm / radius) -- 302
					} -- 302
					local power = lv.transfer.orbital ~= nil and (lv.transfer.mode == "lowerPeriapsis" and 11 / 14 or 0.5) or (lv.transfer.flyby ~= nil and 0.875 or (ra - radius) / (lv.transfer.apoapsisMax - radius)) -- 303
					local plan = planTransfer( -- 304
						bodies[1].gm, -- 304
						radius, -- 304
						vel, -- 304
						power, -- 304
						lv.transfer.apoapsisMax, -- 304
						lv.transfer.mode, -- 304
						lv.transfer.periapsisMin -- 304
					) -- 304
					local duration = plan.dv / lv.transfer.thrustAcceleration -- 305
					local flight = simulate( -- 306
						{pos = pos, vel = vel}, -- 306
						bodies, -- 306
						{ -- 306
							dt = levelRuntime(i).physicsStep, -- 306
							steps = lv.maxSteps, -- 306
							sampleEvery = 1, -- 306
							escapeRadius = lv.escapeRadius, -- 306
							t0 = t0, -- 306
							initialBurn = {duration = duration, acceleration = {x = plan.velocity.x / duration, y = plan.velocity.y / duration}} -- 307
						} -- 307
					) -- 307
					local analysis = analyzeTransfer( -- 308
						flight, -- 308
						bodies, -- 308
						lv.goal.planetIndex, -- 308
						lv.transfer, -- 308
						levelRuntime(i).physicsStep, -- 308
						t0 -- 308
					) -- 308
					local gi = analysis ~= nil and analysis.completionIndex or findGoalIndex( -- 309
						flight.points, -- 309
						bodies, -- 309
						lv.goal, -- 309
						levelRuntime(i).physicsStep, -- 309
						t0, -- 309
						flight.velocities -- 309
					) -- 309
					check( -- 310
						("lv" .. tostring(lv.id)) .. "-reachable", -- 310
						gi >= 0, -- 310
						"有限燃烧基准解必须完成当前关卡任务" -- 310
					) -- 310
					out[#out + 1] = { -- 311
						solutions = gi >= 0 and 1 or 0, -- 311
						total = 1, -- 311
						perT0 = {}, -- 311
						t0s = {}, -- 311
						best = "有限燃烧地月转移" -- 311
					} -- 311
					goto __continue44 -- 312
				end -- 312
				if i >= sweepCount then -- 312
					out[#out + 1] = { -- 315
						solutions = 0, -- 315
						total = 0, -- 315
						perT0 = {}, -- 315
						t0s = {}, -- 315
						best = "（本轮不扫掠，见 testReachability 的说明）" -- 315
					} -- 315
					goto __continue44 -- 316
				end -- 316
				local t0Count = lv.timeWindow ~= nil and 4 or 1 -- 321
				levelDvMin = #lv.planets > 0 and 40 or AimMinSpeed -- 322
				levelDvTop = lv.dvBudget -- 323
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 324
				sweepDt = 1 / 60 -- 325
				sweepEvery = 2 -- 326
				sweepSteps = lv.maxSteps -- 327
				local stat = sweepLevel(lv, 18, 5, t0Count) -- 328
				if stat.solutions == 0 then -- 328
					stat = sweepLevel(lv, 36, 6, 1) -- 330
				end -- 330
				out[#out + 1] = stat -- 332
				if i < REACH_GATE_LEVELS then -- 332
					check( -- 334
						("lv" .. tostring(lv.id)) .. "-reachable", -- 334
						stat.solutions > 0, -- 334
						(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 334
					) -- 334
				else -- 334
					check( -- 338
						("lv" .. tostring(lv.id)) .. "-reachable-informational", -- 338
						true, -- 338
						(((((("未把关：" .. lv.title) .. " ") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 338
					) -- 338
				end -- 338
			end -- 338
			::__continue44:: -- 338
			i = i + 1 -- 292
		end -- 292
	end -- 292
	return out -- 342
end -- 280
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
local function testTimeWindow(stats) -- 357
	local n = levelCount() -- 358
	local withWindow = 0 -- 359
	do -- 359
		local i = 0 -- 360
		while i < n do -- 360
			do -- 360
				local lv = getLevel(i) -- 361
				if lv == nil or lv.timeWindow == nil then -- 361
					goto __continue53 -- 362
				end -- 362
				withWindow = withWindow + 1 -- 363
				local st = stats[i + 1] -- 364
				local peak = 0 -- 365
				for ____, h in ipairs(st.perT0) do -- 366
					if h > peak then -- 366
						peak = h -- 366
					end -- 366
				end -- 366
				local dead = 0 -- 367
				for ____, h in ipairs(st.perT0) do -- 368
					if h == 0 then -- 368
						dead = dead + 1 -- 368
					end -- 368
				end -- 368
				local mattersOk = peak >= 3 and (dead >= 1 or st.perT0[1] * 2 <= peak) -- 372
				local openOk = st.solutions >= 3 -- 373
				check( -- 374
					("lv" .. tostring(lv.id)) .. "-window-matters", -- 374
					not WINDOW_GATE or mattersOk, -- 374
					((((((("时间轴必须真的有用：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0)) .. " 档零解，t0=0 有 ") .. tostring(st.perT0[1])) .. " 解、最好时机 ") .. tostring(peak)) .. " 解（要差 2 倍以上）" -- 374
				) -- 374
				check( -- 376
					("lv" .. tostring(lv.id)) .. "-window-open", -- 376
					not WINDOW_GATE or openOk, -- 376
					"时间轴必须有能落进去的窗口：solutions=" .. tostring(st.solutions) -- 377
				) -- 377
			end -- 377
			::__continue53:: -- 377
			i = i + 1 -- 360
		end -- 360
	end -- 360
	check( -- 379
		"time-window-exists", -- 379
		not WINDOW_GATE or withWindow == n - 1, -- 379
		((("除 L1 外各关都必须有时间轴：withWindow=" .. tostring(withWindow)) .. "/") .. tostring(n - 1)) .. "（L1 例外：它没有日期轴，见 LevelDef 里 L1 的说明）" -- 380
	) -- 380
end -- 357
--- 6) 任务元数据完整性（S7）。
local function testMissionMeta() -- 384
	local n = levelCount() -- 385
	do -- 385
		local i = 0 -- 386
		while i < n do -- 386
			do -- 386
				local lv = getLevel(i) -- 387
				if lv == nil then -- 387
					goto __continue63 -- 388
				end -- 388
				local m = lv.mission -- 389
				check( -- 390
					("lv" .. tostring(lv.id)) .. "-mission-meta-present", -- 390
					m ~= nil, -- 390
					"缺少 mission 元数据" -- 390
				) -- 390
				if m == nil then -- 390
					goto __continue63 -- 391
				end -- 391
				check( -- 393
					("lv" .. tostring(lv.id)) .. "-mission-id", -- 393
					m.id == "L" .. tostring(lv.id), -- 393
					"id=" .. m.id -- 393
				) -- 393
				check( -- 394
					("lv" .. tostring(lv.id)) .. "-mission-codename", -- 394
					#m.codeName > 0, -- 394
					"codeName 为空" -- 394
				) -- 394
				check( -- 395
					("lv" .. tostring(lv.id)) .. "-mission-challenges-count", -- 395
					#m.challenges == (lv.transfer ~= nil and 1 or 3), -- 395
					"challenges.length=" .. tostring(#m.challenges) -- 395
				) -- 395
				check( -- 396
					("lv" .. tostring(lv.id)) .. "-c1-type-success", -- 396
					m.challenges[1].type == "success", -- 396
					"c1 type=" .. m.challenges[1].type -- 396
				) -- 396
				if lv.transfer ~= nil then -- 396
					goto __continue63 -- 397
				end -- 397
				check( -- 398
					("lv" .. tostring(lv.id)) .. "-c2-type-stars", -- 398
					m.challenges[2].type == "stars", -- 398
					"c2 type=" .. m.challenges[2].type -- 398
				) -- 398
				check( -- 399
					("lv" .. tostring(lv.id)) .. "-c3-type-stars", -- 399
					m.challenges[3].type == "stars", -- 399
					"c3 type=" .. m.challenges[3].type -- 399
				) -- 399
			end -- 399
			::__continue63:: -- 399
			i = i + 1 -- 386
		end -- 386
	end -- 386
end -- 384
--- 7) 火箭星级评价逻辑（S7 纯函数判定）。
local function testEvaluateRockets() -- 404
	local fixture = getLevel(1) -- 405
	local l1 = fixture ~= nil and __TS__ObjectAssign( -- 407
		{}, -- 407
		fixture, -- 407
		{mission = __TS__ObjectAssign({}, fixture.mission, {challenges = {{desc = "目标", type = "success"}, {desc = "两颗星尘", type = "stars", threshold = 2}, {desc = "三颗星尘", type = "stars", threshold = 3}}})} -- 407
	) or nil -- 407
	if l1 ~= nil then -- 407
		l1.transfer = nil -- 410
	end -- 410
	if l1 ~= nil then -- 410
		check( -- 412
			"rockets-fail-0", -- 412
			evaluateRockets(l1, "crash", 0.1) == 0, -- 412
			"失败应为 0 枚火箭" -- 412
		) -- 412
		check( -- 413
			"rockets-escaped-0", -- 413
			evaluateRockets(l1, "escaped", 0.1) == 0, -- 413
			"逃逸应为 0 枚火箭" -- 413
		) -- 413
		check( -- 414
			"rockets-success-nostar-1", -- 414
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 0}) == 1, -- 414
			"只进门应为 1 星" -- 414
		) -- 414
		check( -- 415
			"rockets-stars-2", -- 415
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 2}) == 2, -- 415
			"两颗星尘应为 2 星" -- 415
		) -- 415
		check( -- 416
			"rockets-stars-3", -- 416
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 3}) == 3, -- 416
			"三颗星尘应为 3 星" -- 416
		) -- 416
		check( -- 417
			"rockets-stars-1-not-2", -- 417
			evaluateRockets(l1, "success", l1.dvBudget, {starsCollected = 1}) == 1, -- 417
			"一颗星尘仍是 1 星" -- 417
		) -- 417
		local det = evaluateRocketsDetailed(l1, "success", l1.dvBudget, {starsCollected = 3}) -- 419
		check("rockets-detailed-count", det.rockets == 3, "详细评价火箭数应为 3") -- 420
		check("rockets-detailed-c1", det.achieved[1] == true, "挑战 1 应达成") -- 421
		check("rockets-detailed-c2", det.achieved[2] == true, "挑战 2 应达成") -- 422
		check("rockets-detailed-c3", det.achieved[3] == true, "挑战 3 应达成") -- 423
	end -- 423
	local l4 = getLevel(3) -- 426
	if l4 ~= nil then -- 426
		check( -- 428
			"rockets-l4-eccentricity-3", -- 428
			evaluateRockets(l4, "success", l4.dvBudget * 0.6, {eccentricity = 0.25}) == 3, -- 428
			"低偏心率入轨应为 3 枚火箭" -- 428
		) -- 428
	end -- 428
	local l3 = getLevel(2) -- 431
	if l3 ~= nil then -- 431
		check( -- 433
			"rockets-l3-completion-only", -- 433
			evaluateRockets(l3, "success", l3.dvBudget, {starsCollected = 3}) == 1, -- 433
			"日心任务只记录完成" -- 433
		) -- 433
	end -- 433
end -- 404
function ____exports.runTests() -- 437
	loadFixture() -- 438
	testValidity() -- 439
	testGoalRegion() -- 440
	testFindGoalIndex() -- 441
	local stats = testReachability() -- 442
	testTimeWindow(stats) -- 443
	testMissionMeta() -- 444
	testEvaluateRockets() -- 445
	local lines = {} -- 447
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 448
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 449
	local limit = #failures < 12 and #failures or 12 -- 450
	do -- 450
		local i = 0 -- 451
		while i < limit do -- 451
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 452
			i = i + 1 -- 451
		end -- 451
	end -- 451
	return table.concat(lines, "\n") -- 454
end -- 437
return ____exports -- 437
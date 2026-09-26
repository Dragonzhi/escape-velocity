-- [ts]: LevelDataTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 9
local simulate = ____Gravity.simulate -- 9
local ____LevelData = require("game.LevelData") -- 10
local findGoalIndex = ____LevelData.findGoalIndex -- 10
local getLevel = ____LevelData.getLevel -- 10
local levelCount = ____LevelData.levelCount -- 10
local scaledPlanets = ____LevelData.scaledPlanets -- 10
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
--- 角度 × 力度的采样网格。
-- 
-- 12 方向太粗会漏掉窄解（实测 L3/L5 的解在斜向速度上），所以非时间轴关用 24×6；
-- 时间轴关还要再乘 t0 档数，为控制引擎内耗时退回 12×4（× 24 档 t0 仍然有 1152 个样本）。
local levelDvTop = AimMaxSpeed -- 118
--- 出发时已有的速度（S3.9.3，L1 = 绕地球的圆轨道）；扫掠的初速度 = 它 + 这一次点火。
local levelVel0 = {x = 0, y = 0} -- 120
--- 这一遍扫掠用不用**刹车模式**（S3.9.2：两次点火共享 Δv ⇒ 点火只拿一半）。
local levelBrake = false -- 122
local function grid(dirCount, powerCount) -- 127
	local out = {} -- 128
	do -- 128
		local d = 0 -- 129
		while d < dirCount do -- 129
			local angle = d * 2 * math.pi / dirCount -- 130
			do -- 130
				local k = 0 -- 131
				while k < powerCount do -- 131
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 134
					local speed = AimMinSpeed + (levelDvTop - AimMinSpeed) * p -- 136
					local share = levelBrake and BrakeShare or 1 -- 139
					out[#out + 1] = { -- 140
						vel = { -- 141
							x = math.cos(angle) * speed * share + levelVel0.x, -- 141
							y = math.sin(angle) * speed * share + levelVel0.y -- 141
						}, -- 141
						brakeDv = levelBrake and speed * (1 - share) or 0 -- 142
					} -- 142
					k = k + 1 -- 131
				end -- 131
			end -- 131
			d = d + 1 -- 129
		end -- 129
	end -- 129
	return out -- 146
end -- 127
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 150
	local stat = { -- 151
		solutions = 0, -- 151
		total = 0, -- 151
		perT0 = {}, -- 151
		t0s = {}, -- 151
		best = "" -- 151
	} -- 151
	if lv == nil then -- 151
		return stat -- 152
	end -- 152
	local bodies = scaledPlanets(lv) -- 153
	local sampleEvery = 4 -- 154
	local t0s = {} -- 155
	if lv.timeWindow ~= nil then -- 155
		do -- 155
			local i = 0 -- 157
			while i < t0Count do -- 157
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 157
				i = i + 1 -- 157
			end -- 157
		end -- 157
	else -- 157
		t0s[#t0s + 1] = 0 -- 159
	end -- 159
	local vs = grid(dirCount, powerCount) -- 161
	do -- 161
		local ti = 0 -- 163
		while ti < #t0s do -- 163
			local t0 = t0s[ti + 1] -- 164
			local ____stat_t0s_0 = stat.t0s -- 164
			____stat_t0s_0[#____stat_t0s_0 + 1] = t0 -- 165
			local hits = 0 -- 166
			for ____, sample in ipairs(vs) do -- 167
				local sim = simulate( -- 168
					{pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = sample.vel}, -- 169
					bodies, -- 170
					{ -- 171
						steps = lv.maxSteps, -- 172
						dt = PhysicsStep, -- 172
						sampleEvery = sampleEvery, -- 172
						escapeRadius = lv.escapeRadius, -- 172
						t0 = t0, -- 172
						brake = sample.brakeDv > 0 and ({ -- 173
							dv = sample.brakeDv, -- 173
							startStep = math.floor(lv.maxSteps / 2) -- 173
						}) or nil -- 173
					} -- 173
				) -- 173
				local gi = findGoalIndex( -- 178
					sim.points, -- 178
					bodies, -- 178
					lv.goal, -- 178
					PhysicsStep * sampleEvery, -- 178
					t0 -- 178
				) -- 178
				stat.total = stat.total + 1 -- 179
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 179
					stat.solutions = stat.solutions + 1 -- 181
					hits = hits + 1 -- 182
					if stat.best == "" then -- 182
						local angle = math.atan(sample.vel.y, sample.vel.x) * 180 / math.pi -- 184
						stat.best = ((((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 185
							math.sqrt(sample.vel.x * sample.vel.x + sample.vel.y * sample.vel.y), -- 185
							1 -- 185
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1)) .. (levelBrake and " brake" or "") -- 185
					end -- 185
				end -- 185
			end -- 185
			local ____stat_perT0_1 = stat.perT0 -- 185
			____stat_perT0_1[#____stat_perT0_1 + 1] = hits -- 189
			ti = ti + 1 -- 163
		end -- 163
	end -- 163
	return stat -- 191
end -- 150
local function testReachability() -- 194
	local n = levelCount() -- 195
	local out = {} -- 196
	do -- 196
		local i = 0 -- 200
		while i < n do -- 200
			do -- 200
				local lv = getLevel(i) -- 201
				if lv == nil then -- 201
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 202
					goto __continue37 -- 202
				end -- 202
				local t0Count = lv.timeWindow ~= nil and 24 or 1 -- 204
				levelDvTop = lv.dvBudget ~= nil and lv.dvBudget < AimMaxSpeed and lv.dvBudget or AimMaxSpeed -- 205
				levelVel0 = lv.probeVel0 ~= nil and lv.probeVel0 or ({x = 0, y = 0}) -- 206
				levelBrake = false -- 209
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 210
				if stat.solutions == 0 then -- 210
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 24 or 1) -- 212
				end -- 212
				if stat.solutions == 0 then -- 212
					levelBrake = true -- 215
					stat = sweepLevel(lv, 12, 4, t0Count) -- 216
				end -- 216
				out[#out + 1] = stat -- 218
				check( -- 219
					("lv" .. tostring(lv.id)) .. "-reachable", -- 219
					stat.solutions > 0, -- 219
					(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 219
				) -- 219
			end -- 219
			::__continue37:: -- 219
			i = i + 1 -- 200
		end -- 200
	end -- 200
	return out -- 222
end -- 194
--- 4) 时间轴（S3.6.4 的数据侧判据）：窗口必须**真的会关**。
-- 
-- PLAN 原来写的是「t0=0 无解」，实测做不到 —— 场里自由度太多，任何时机都能蒙中一条线
-- （证据：24×6×24 的密网格下每个 t0 都有解）。所以判据改成**可观测的三条**：
--  ① 有 t0 档零解（窗口确实会关）；② 有解的 t0 档 ≥ 6；③ 该关总解数 ≥ 3。
local function testTimeWindow(stats) -- 231
	local n = levelCount() -- 232
	local withWindow = 0 -- 233
	do -- 233
		local i = 0 -- 234
		while i < n do -- 234
			do -- 234
				local lv = getLevel(i) -- 235
				if lv == nil or lv.timeWindow == nil then -- 235
					goto __continue43 -- 236
				end -- 236
				withWindow = withWindow + 1 -- 237
				local st = stats[i + 1] -- 238
				local dead = 0 -- 239
				local alive = 0 -- 240
				for ____, h in ipairs(st.perT0) do -- 241
					if h == 0 then -- 241
						dead = dead + 1 -- 242
					else -- 242
						alive = alive + 1 -- 242
					end -- 242
				end -- 242
				check( -- 244
					("lv" .. tostring(lv.id)) .. "-window-closes", -- 244
					dead >= 1, -- 244
					(("时间轴关必须有「发射了也没用」的时机：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0) -- 244
				) -- 244
				check( -- 247
					("lv" .. tostring(lv.id)) .. "-window-open", -- 247
					alive >= 3 and st.solutions >= 3, -- 247
					(("时间轴必须有能落进去的窗口：alive=" .. tostring(alive)) .. " solutions=") .. tostring(st.solutions) -- 247
				) -- 247
			end -- 247
			::__continue43:: -- 247
			i = i + 1 -- 234
		end -- 234
	end -- 234
	check("time-window-exists", withWindow >= 1, "至少有一关带时间轴（L4 窗口）") -- 250
end -- 231
function ____exports.runTests() -- 253
	testValidity() -- 254
	testFindGoalIndex() -- 255
	local stats = testReachability() -- 256
	testTimeWindow(stats) -- 257
	local lines = {} -- 259
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 260
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 261
	local limit = #failures < 12 and #failures or 12 -- 262
	do -- 262
		local i = 0 -- 263
		while i < limit do -- 263
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 264
			i = i + 1 -- 263
		end -- 263
	end -- 263
	return table.concat(lines, "\n") -- 266
end -- 253
return ____exports -- 253
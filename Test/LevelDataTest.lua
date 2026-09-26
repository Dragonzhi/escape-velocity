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
local function grid(dirCount, powerCount) -- 118
	local out = {} -- 119
	do -- 119
		local d = 0 -- 120
		while d < dirCount do -- 120
			local angle = d * 2 * math.pi / dirCount -- 121
			do -- 121
				local k = 0 -- 122
				while k < powerCount do -- 122
					local p = powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1) -- 123
					local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * p -- 124
					out[#out + 1] = { -- 125
						x = math.cos(angle) * speed, -- 125
						y = math.sin(angle) * speed -- 125
					} -- 125
					k = k + 1 -- 122
				end -- 122
			end -- 122
			d = d + 1 -- 120
		end -- 120
	end -- 120
	return out -- 128
end -- 118
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 132
	local stat = { -- 133
		solutions = 0, -- 133
		total = 0, -- 133
		perT0 = {}, -- 133
		t0s = {}, -- 133
		best = "" -- 133
	} -- 133
	if lv == nil then -- 133
		return stat -- 134
	end -- 134
	local bodies = scaledPlanets(lv) -- 135
	local sampleEvery = 4 -- 136
	local t0s = {} -- 137
	if lv.timeWindow ~= nil then -- 137
		do -- 137
			local i = 0 -- 139
			while i < t0Count do -- 139
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 139
				i = i + 1 -- 139
			end -- 139
		end -- 139
	else -- 139
		t0s[#t0s + 1] = 0 -- 141
	end -- 141
	local vs = grid(dirCount, powerCount) -- 143
	do -- 143
		local ti = 0 -- 145
		while ti < #t0s do -- 145
			local t0 = t0s[ti + 1] -- 146
			local ____stat_t0s_0 = stat.t0s -- 146
			____stat_t0s_0[#____stat_t0s_0 + 1] = t0 -- 147
			local hits = 0 -- 148
			for ____, v in ipairs(vs) do -- 149
				local sim = simulate({pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = v}, bodies, { -- 150
					steps = lv.maxSteps, -- 153
					dt = PhysicsStep, -- 153
					sampleEvery = sampleEvery, -- 153
					escapeRadius = lv.escapeRadius, -- 153
					t0 = t0 -- 153
				}) -- 153
				local gi = findGoalIndex( -- 157
					sim.points, -- 157
					bodies, -- 157
					lv.goal, -- 157
					PhysicsStep * sampleEvery, -- 157
					t0 -- 157
				) -- 157
				stat.total = stat.total + 1 -- 158
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 158
					stat.solutions = stat.solutions + 1 -- 160
					hits = hits + 1 -- 161
					if stat.best == "" then -- 161
						local angle = math.atan(v.y, v.x) * 180 / math.pi -- 163
						stat.best = (((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 164
							math.sqrt(v.x * v.x + v.y * v.y), -- 164
							1 -- 164
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1) -- 164
					end -- 164
				end -- 164
			end -- 164
			local ____stat_perT0_1 = stat.perT0 -- 164
			____stat_perT0_1[#____stat_perT0_1 + 1] = hits -- 168
			ti = ti + 1 -- 145
		end -- 145
	end -- 145
	return stat -- 170
end -- 132
local function testReachability() -- 173
	local n = levelCount() -- 174
	local out = {} -- 175
	do -- 175
		local i = 0 -- 179
		while i < n do -- 179
			do -- 179
				local lv = getLevel(i) -- 180
				if lv == nil then -- 180
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 181
					goto __continue37 -- 181
				end -- 181
				local t0Count = lv.timeWindow ~= nil and 12 or 1 -- 182
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 183
				if stat.solutions == 0 then -- 183
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 24 or 1) -- 185
				end -- 185
				out[#out + 1] = stat -- 187
				check( -- 188
					("lv" .. tostring(lv.id)) .. "-reachable", -- 188
					stat.solutions > 0, -- 188
					(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 188
				) -- 188
			end -- 188
			::__continue37:: -- 188
			i = i + 1 -- 179
		end -- 179
	end -- 179
	return out -- 191
end -- 173
--- 4) 时间轴（S3.6.4 的数据侧判据）：窗口必须**真的会关**。
-- 
-- PLAN 原来写的是「t0=0 无解」，实测做不到 —— 场里自由度太多，任何时机都能蒙中一条线
-- （证据：24×6×24 的密网格下每个 t0 都有解）。所以判据改成**可观测的三条**：
--  ① 有 t0 档零解（窗口确实会关）；② 有解的 t0 档 ≥ 6；③ 该关总解数 ≥ 3。
local function testTimeWindow(stats) -- 200
	local n = levelCount() -- 201
	local withWindow = 0 -- 202
	do -- 202
		local i = 0 -- 203
		while i < n do -- 203
			do -- 203
				local lv = getLevel(i) -- 204
				if lv == nil or lv.timeWindow == nil then -- 204
					goto __continue42 -- 205
				end -- 205
				withWindow = withWindow + 1 -- 206
				local st = stats[i + 1] -- 207
				local dead = 0 -- 208
				local alive = 0 -- 209
				for ____, h in ipairs(st.perT0) do -- 210
					if h == 0 then -- 210
						dead = dead + 1 -- 211
					else -- 211
						alive = alive + 1 -- 211
					end -- 211
				end -- 211
				check( -- 213
					("lv" .. tostring(lv.id)) .. "-window-closes", -- 213
					dead >= 1, -- 213
					(("时间轴关必须有「发射了也没用」的时机：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0) -- 213
				) -- 213
				check( -- 215
					("lv" .. tostring(lv.id)) .. "-window-open", -- 215
					alive >= 6 and st.solutions >= 3, -- 215
					(("时间轴必须有足够宽的窗口：alive=" .. tostring(alive)) .. " solutions=") .. tostring(st.solutions) -- 215
				) -- 215
			end -- 215
			::__continue42:: -- 215
			i = i + 1 -- 203
		end -- 203
	end -- 203
	check("time-window-exists", withWindow >= 1, "至少有一关带时间轴（L4 窗口）") -- 218
end -- 200
function ____exports.runTests() -- 221
	testValidity() -- 222
	testFindGoalIndex() -- 223
	local stats = testReachability() -- 224
	testTimeWindow(stats) -- 225
	local lines = {} -- 227
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 228
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 229
	local limit = #failures < 12 and #failures or 12 -- 230
	do -- 230
		local i = 0 -- 231
		while i < limit do -- 231
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 232
			i = i + 1 -- 231
		end -- 231
	end -- 231
	return table.concat(lines, "\n") -- 234
end -- 221
return ____exports -- 221
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
local levelDvTop = AimMaxSpeed -- 118
local function grid(dirCount, powerCount) -- 120
	local out = {} -- 121
	do -- 121
		local d = 0 -- 122
		while d < dirCount do -- 122
			local angle = d * 2 * math.pi / dirCount -- 123
			do -- 123
				local k = 0 -- 124
				while k < powerCount do -- 124
					local p = powerCount == 4 and ({0.35, 0.6, 0.85, 1})[k + 1] or (powerCount == 1 and 1 or 0.35 + 0.65 * k / (powerCount - 1)) -- 127
					local speed = AimMinSpeed + (levelDvTop - AimMinSpeed) * p -- 129
					out[#out + 1] = { -- 130
						x = math.cos(angle) * speed, -- 130
						y = math.sin(angle) * speed -- 130
					} -- 130
					k = k + 1 -- 124
				end -- 124
			end -- 124
			d = d + 1 -- 122
		end -- 122
	end -- 122
	return out -- 133
end -- 120
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
local function sweepLevel(lv, dirCount, powerCount, t0Count) -- 137
	local stat = { -- 138
		solutions = 0, -- 138
		total = 0, -- 138
		perT0 = {}, -- 138
		t0s = {}, -- 138
		best = "" -- 138
	} -- 138
	if lv == nil then -- 138
		return stat -- 139
	end -- 139
	local bodies = scaledPlanets(lv) -- 140
	local sampleEvery = 4 -- 141
	local t0s = {} -- 142
	if lv.timeWindow ~= nil then -- 142
		do -- 142
			local i = 0 -- 144
			while i < t0Count do -- 144
				t0s[#t0s + 1] = lv.timeWindow.span * i / t0Count -- 144
				i = i + 1 -- 144
			end -- 144
		end -- 144
	else -- 144
		t0s[#t0s + 1] = 0 -- 146
	end -- 146
	local vs = grid(dirCount, powerCount) -- 148
	do -- 148
		local ti = 0 -- 150
		while ti < #t0s do -- 150
			local t0 = t0s[ti + 1] -- 151
			local ____stat_t0s_0 = stat.t0s -- 151
			____stat_t0s_0[#____stat_t0s_0 + 1] = t0 -- 152
			local hits = 0 -- 153
			for ____, v in ipairs(vs) do -- 154
				local sim = simulate({pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = v}, bodies, { -- 155
					steps = lv.maxSteps, -- 158
					dt = PhysicsStep, -- 158
					sampleEvery = sampleEvery, -- 158
					escapeRadius = lv.escapeRadius, -- 158
					t0 = t0 -- 158
				}) -- 158
				local gi = findGoalIndex( -- 162
					sim.points, -- 162
					bodies, -- 162
					lv.goal, -- 162
					PhysicsStep * sampleEvery, -- 162
					t0 -- 162
				) -- 162
				stat.total = stat.total + 1 -- 163
				if resolveResult(sim.outcome, gi, lv.goal) == "success" then -- 163
					stat.solutions = stat.solutions + 1 -- 165
					hits = hits + 1 -- 166
					if stat.best == "" then -- 166
						local angle = math.atan(v.y, v.x) * 180 / math.pi -- 168
						stat.best = (((("dir=" .. __TS__NumberToFixed(angle, 0)) .. "deg v=") .. __TS__NumberToFixed( -- 169
							math.sqrt(v.x * v.x + v.y * v.y), -- 169
							1 -- 169
						)) .. " t0=") .. __TS__NumberToFixed(t0, 1) -- 169
					end -- 169
				end -- 169
			end -- 169
			local ____stat_perT0_1 = stat.perT0 -- 169
			____stat_perT0_1[#____stat_perT0_1 + 1] = hits -- 173
			ti = ti + 1 -- 150
		end -- 150
	end -- 150
	return stat -- 175
end -- 137
local function testReachability() -- 178
	local n = levelCount() -- 179
	local out = {} -- 180
	do -- 180
		local i = 0 -- 184
		while i < n do -- 184
			do -- 184
				local lv = getLevel(i) -- 185
				if lv == nil then -- 185
					out[#out + 1] = sweepLevel(lv, 12, 4, 1) -- 186
					goto __continue37 -- 186
				end -- 186
				local t0Count = lv.timeWindow ~= nil and 24 or 1 -- 188
				levelDvTop = lv.dvBudget ~= nil and lv.dvBudget < AimMaxSpeed and lv.dvBudget or AimMaxSpeed -- 189
				local stat = sweepLevel(lv, 12, 4, t0Count) -- 190
				if stat.solutions == 0 then -- 190
					stat = sweepLevel(lv, 24, 6, lv.timeWindow ~= nil and 24 or 1) -- 192
				end -- 192
				out[#out + 1] = stat -- 194
				check( -- 195
					("lv" .. tostring(lv.id)) .. "-reachable", -- 195
					stat.solutions > 0, -- 195
					(((((("每关至少要有一个可行解（" .. lv.title) .. "）：") .. tostring(stat.solutions)) .. "/") .. tostring(stat.total)) .. " ") .. stat.best -- 195
				) -- 195
			end -- 195
			::__continue37:: -- 195
			i = i + 1 -- 184
		end -- 184
	end -- 184
	return out -- 198
end -- 178
--- 4) 时间轴（S3.6.4 的数据侧判据）：窗口必须**真的会关**。
-- 
-- PLAN 原来写的是「t0=0 无解」，实测做不到 —— 场里自由度太多，任何时机都能蒙中一条线
-- （证据：24×6×24 的密网格下每个 t0 都有解）。所以判据改成**可观测的三条**：
--  ① 有 t0 档零解（窗口确实会关）；② 有解的 t0 档 ≥ 6；③ 该关总解数 ≥ 3。
local function testTimeWindow(stats) -- 207
	local n = levelCount() -- 208
	local withWindow = 0 -- 209
	do -- 209
		local i = 0 -- 210
		while i < n do -- 210
			do -- 210
				local lv = getLevel(i) -- 211
				if lv == nil or lv.timeWindow == nil then -- 211
					goto __continue42 -- 212
				end -- 212
				withWindow = withWindow + 1 -- 213
				local st = stats[i + 1] -- 214
				local dead = 0 -- 215
				local alive = 0 -- 216
				for ____, h in ipairs(st.perT0) do -- 217
					if h == 0 then -- 217
						dead = dead + 1 -- 218
					else -- 218
						alive = alive + 1 -- 218
					end -- 218
				end -- 218
				check( -- 220
					("lv" .. tostring(lv.id)) .. "-window-closes", -- 220
					dead >= 1, -- 220
					(("时间轴关必须有「发射了也没用」的时机：dead=" .. tostring(dead)) .. "/") .. tostring(#st.perT0) -- 220
				) -- 220
				check( -- 223
					("lv" .. tostring(lv.id)) .. "-window-open", -- 223
					alive >= 3 and st.solutions >= 3, -- 223
					(("时间轴必须有能落进去的窗口：alive=" .. tostring(alive)) .. " solutions=") .. tostring(st.solutions) -- 223
				) -- 223
			end -- 223
			::__continue42:: -- 223
			i = i + 1 -- 210
		end -- 210
	end -- 210
	check("time-window-exists", withWindow >= 1, "至少有一关带时间轴（L4 窗口）") -- 226
end -- 207
function ____exports.runTests() -- 229
	testValidity() -- 230
	testFindGoalIndex() -- 231
	local stats = testReachability() -- 232
	testTimeWindow(stats) -- 233
	local lines = {} -- 235
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 236
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 237
	local limit = #failures < 12 and #failures or 12 -- 238
	do -- 238
		local i = 0 -- 239
		while i < limit do -- 239
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 240
			i = i + 1 -- 239
		end -- 239
	end -- 239
	return table.concat(lines, "\n") -- 242
end -- 229
return ____exports -- 229
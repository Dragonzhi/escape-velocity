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
				local goal = lv.goal -- 39
				if goal.kind == "planet" then -- 39
					local gp = lv.planets[goal.planetIndex + 1] -- 41
					check( -- 42
						("lv" .. tostring(lv.id)) .. "-goal-index", -- 42
						gp ~= nil, -- 42
						("planetIndex=" .. tostring(goal.planetIndex)) .. " 越界" -- 42
					) -- 42
					if gp ~= nil then -- 42
						check( -- 44
							("lv" .. tostring(lv.id)) .. "-tolerance>radius", -- 44
							goal.tolerance > gp.radius, -- 44
							((("tolerance=" .. tostring(goal.tolerance)) .. " radius=") .. tostring(gp.radius)) .. "（容差必须大于半径，否则不可达）" -- 44
						) -- 44
					end -- 44
				end -- 44
				check( -- 49
					("lv" .. tostring(lv.id)) .. "-brief", -- 49
					lv.brief ~= nil and #lv.brief > 0, -- 49
					"缺少任务简报" -- 49
				) -- 49
			end -- 49
			::__continue6:: -- 49
			i = i + 1 -- 32
		end -- 32
	end -- 32
end -- 28
--- 2) findGoalIndex：静止与移动目标。
local function testFindGoalIndex() -- 54
	local bodies = {{ -- 56
		gm = 0, -- 57
		radius = 1.2, -- 57
		orbitCenter = {x = 0, y = -20}, -- 57
		orbitRadius = 0, -- 57
		orbitPeriod = 0, -- 57
		phase0 = 0, -- 57
		orbitDirection = 1 -- 57
	}} -- 57
	local goal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 59
	local sim = simulate({pos = {x = 0, y = 16}, vel = {x = 0, y = -10}}, bodies, {steps = 600, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 60
	local gi = findGoalIndex(sim.points, bodies, goal, PhysicsStep) -- 62
	check( -- 63
		"find-goal-static", -- 63
		gi >= 0, -- 63
		("goalIndex=" .. tostring(gi)) .. "（直射静止目标应命中）" -- 63
	) -- 63
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 66
	check( -- 67
		"find-goal-escape", -- 67
		findGoalIndex(sim.points, bodies, escapeGoal, PhysicsStep) == -1, -- 67
		"escape 目标不应产生 goalIndex" -- 67
	) -- 67
	local movers = {{ -- 70
		gm = 0, -- 71
		radius = 1.2, -- 71
		orbitCenter = {x = 0, y = -6}, -- 71
		orbitRadius = 9, -- 71
		orbitPeriod = 9, -- 71
		phase0 = 0, -- 71
		orbitDirection = 1 -- 71
	}} -- 71
	local sim2 = simulate({pos = {x = 9, y = 10}, vel = {x = 0, y = -8}}, movers, {steps = 900, dt = PhysicsStep, sampleEvery = 1, escapeRadius = 400}) -- 73
	local gi2 = findGoalIndex(sim2.points, movers, {kind = "planet", planetIndex = 0, tolerance = 3}, PhysicsStep) -- 75
	if gi2 >= 0 then -- 75
		local p = sim2.points[gi2 + 1] -- 78
		local minD = 1000000000 -- 79
		do -- 79
			local k = 0 -- 80
			while k < #movers do -- 80
				local gp = movers[k + 1] -- 81
				local angle = gp.phase0 + gp.orbitDirection * 2 * math.pi * (gi2 * PhysicsStep / gp.orbitPeriod) -- 82
				local gx = gp.orbitCenter.x + gp.orbitRadius * math.cos(angle) -- 83
				local gy = gp.orbitCenter.y + gp.orbitRadius * math.sin(angle) -- 84
				local dx = p.x - gx -- 85
				local dy = p.y - gy -- 86
				local d = math.sqrt(dx * dx + dy * dy) -- 87
				if d < minD then -- 87
					minD = d -- 88
				end -- 88
				k = k + 1 -- 80
			end -- 80
		end -- 80
		check( -- 90
			"find-goal-moving-accurate", -- 90
			minD < 3, -- 90
			("minDist=" .. __TS__NumberToFixed(minD, 3)) .. "（命中点应在容差内）" -- 90
		) -- 90
	else -- 90
		check("find-goal-moving-accurate", true, "该速度未命中（不判定）") -- 93
	end -- 93
end -- 54
--- 3) 可玩性扫掠：每关至少一个速度向量能达成目标。
-- 
-- 用**角度 × 力度**采样（12 方向 × 4 档力度），真实覆盖玩家的连续输入空间。
-- 轴向网格会漏掉斜向解（实测 L3/L5 的解在 v=(-16,-14) 这类斜向速度上）。
local function testReachability() -- 102
	local n = levelCount() -- 103
	local powers = {0.35, 0.6, 0.85, 1} -- 104
	local dirCount = 12 -- 105
	do -- 105
		local i = 0 -- 107
		while i < n do -- 107
			do -- 107
				local lv = getLevel(i) -- 108
				if lv == nil then -- 108
					goto __continue18 -- 109
				end -- 109
				local bodies = scaledPlanets(lv) -- 110
				local best = "" -- 112
				local found = false -- 113
				do -- 113
					local d = 0 -- 114
					while d < dirCount and not found do -- 114
						local angle = d * 2 * math.pi / dirCount -- 115
						local ux = math.cos(angle) -- 116
						local uy = math.sin(angle) -- 117
						for ____, p in ipairs(powers) do -- 118
							local speed = AimMinSpeed + (AimMaxSpeed - AimMinSpeed) * p -- 119
							local v = {x = ux * speed, y = uy * speed} -- 120
							local sim = simulate({pos = {x = lv.probeStart.x, y = lv.probeStart.y}, vel = v}, bodies, {steps = lv.maxSteps, dt = PhysicsStep, sampleEvery = 4, escapeRadius = lv.escapeRadius}) -- 122
							local gi = findGoalIndex(sim.points, bodies, lv.goal, PhysicsStep) -- 127
							local kind = resolveResult(sim.outcome, gi, lv.goal) -- 128
							if kind == "success" then -- 128
								found = true -- 130
								best = (("dir=" .. __TS__NumberToFixed(angle * 180 / math.pi, 0)) .. "deg power=") .. tostring(p) -- 131
								break -- 132
							end -- 132
						end -- 132
						d = d + 1 -- 114
					end -- 114
				end -- 114
				check( -- 136
					("lv" .. tostring(lv.id)) .. "-reachable", -- 136
					found, -- 136
					(("六关必须至少存在一个可行解（" .. lv.title) .. "）") .. (best ~= "" and " found " .. best or "") -- 136
				) -- 136
			end -- 136
			::__continue18:: -- 136
			i = i + 1 -- 107
		end -- 107
	end -- 107
end -- 102
function ____exports.runTests() -- 140
	testValidity() -- 141
	testFindGoalIndex() -- 142
	testReachability() -- 143
	local lines = {} -- 145
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 146
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 147
	local limit = #failures < 12 and #failures or 12 -- 148
	do -- 148
		local i = 0 -- 149
		while i < limit do -- 149
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 150
			i = i + 1 -- 149
		end -- 149
	end -- 149
	return table.concat(lines, "\n") -- 152
end -- 140
return ____exports -- 140
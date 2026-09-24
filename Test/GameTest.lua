-- [ts]: GameTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Config = require("game.Config") -- 8
local FlightPlayback = ____Config.FlightPlayback -- 8
local PhysicsStep = ____Config.PhysicsStep -- 8
local ____Game = require("game.Game") -- 10
local coreLaunch = ____Game.coreLaunch -- 10
local coreProbeIndex = ____Game.coreProbeIndex -- 10
local coreRetry = ____Game.coreRetry -- 10
local coreUpdate = ____Game.coreUpdate -- 10
local createCore = ____Game.createCore -- 10
local resolveResult = ____Game.resolveResult -- 10
local failures = {} -- 17
local checks = 0 -- 18
local function check(name, ok, detail) -- 20
	checks = checks + 1 -- 21
	if not ok then -- 21
		failures[#failures + 1] = {name = name, detail = detail} -- 22
	end -- 22
end -- 20
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发，目标 = 逃逸。
local function testLevel() -- 26
	local bodies = {{ -- 27
		gm = 900, -- 28
		radius = 2.2, -- 28
		orbitCenter = {x = 0, y = 0}, -- 29
		orbitRadius = 0, -- 29
		orbitPeriod = 0, -- 30
		phase0 = 0, -- 30
		orbitDirection = 1 -- 30
	}} -- 30
	return { -- 32
		bodies = bodies, -- 33
		probeStart = {x = 0, y = 16}, -- 34
		goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 35
		escapeRadius = 400, -- 36
		maxSteps = 1500 -- 37
	} -- 37
end -- 26
--- 1) 结算判定（手册 §5.8）。
local function testResolveResult() -- 42
	local escapeGoal = {kind = "escape", planetIndex = -1, tolerance = 0} -- 43
	local planetGoal = {kind = "planet", planetIndex = 0, tolerance = 3} -- 44
	check( -- 47
		"resolve-goal-first", -- 47
		resolveResult("crashed", 5, planetGoal) == "success", -- 47
		"到达目标应优先于撞毁（轨迹在到达点截断）" -- 47
	) -- 47
	check( -- 48
		"resolve-goal-running", -- 48
		resolveResult("running", 3, planetGoal) == "success", -- 48
		"到达目标即成功" -- 48
	) -- 48
	check( -- 51
		"resolve-escape-success", -- 51
		resolveResult("escaped", -1, escapeGoal) == "success", -- 51
		"逃逸目标达成 = 成功" -- 51
	) -- 51
	check( -- 52
		"resolve-escape-timeout", -- 52
		resolveResult("running", -1, escapeGoal) == "missed", -- 52
		"超时 = 错过" -- 52
	) -- 52
	check( -- 55
		"resolve-planet-escaped", -- 55
		resolveResult("escaped", -1, planetGoal) == "missed", -- 55
		"飞出边界但未到达目标 = 错过" -- 55
	) -- 55
	check( -- 56
		"resolve-planet-crashed", -- 56
		resolveResult("crashed", -1, planetGoal) == "crashed", -- 56
		"撞毁 = 撞毁" -- 56
	) -- 56
end -- 42
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 60
	local level = testLevel() -- 61
	local core = createCore() -- 62
	coreLaunch(core, {x = 6, y = -12}, level) -- 64
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 65
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 66
	check( -- 67
		"launch-time-zero", -- 67
		core.flightTime == 0, -- 67
		"flightTime=" .. tostring(core.flightTime) -- 67
	) -- 67
	local before = core.flight ~= nil and #core.flight.points or 0 -- 70
	coreLaunch(core, {x = 0, y = -20}, level) -- 71
	local after = core.flight ~= nil and #core.flight.points or 0 -- 72
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 73
end -- 60
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 77
	local level = testLevel() -- 78
	local core = createCore() -- 79
	coreLaunch(core, {x = 6, y = -12}, level) -- 80
	local flight = core.flight -- 81
	if flight == nil then -- 81
		check("playback-flight", false, "no flight") -- 82
		return -- 82
	end -- 82
	local total = #flight.points - 1 -- 84
	check( -- 85
		"playback-start-index", -- 85
		coreProbeIndex(core) == 0, -- 85
		"idx=" .. tostring(coreProbeIndex(core)) -- 85
	) -- 85
	local entered = false -- 88
	local frames = 0 -- 89
	while not entered and frames < 100000 do -- 89
		entered = coreUpdate(core, 1 / 60) -- 91
		frames = frames + 1 -- 92
		if core.phase == "Result" then -- 92
			break -- 93
		end -- 93
	end -- 93
	check( -- 96
		"playback-enters-result", -- 96
		entered and core.phase == "Result", -- 96
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 96
	) -- 96
	check( -- 97
		"playback-final-index", -- 97
		coreProbeIndex(core) == total, -- 97
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 97
	) -- 97
	check( -- 98
		"playback-result-kind", -- 98
		core.result == resolveResult(flight.outcome, core.goalIndex, level.goal), -- 98
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 98
	) -- 98
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 101
	local actualRealSeconds = frames / 60 -- 102
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 103
	check( -- 104
		"playback-duration", -- 104
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 104
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 104
	) -- 104
end -- 77
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 109
	local level = testLevel() -- 110
	local core = createCore() -- 111
	coreRetry(core) -- 114
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 115
	coreLaunch(core, {x = 6, y = -12}, level) -- 117
	local entered = false -- 118
	local guard = 0 -- 119
	while not entered and guard < 100000 do -- 119
		entered = coreUpdate(core, 1 / 60) -- 121
		guard = guard + 1 -- 122
	end -- 122
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 124
	coreRetry(core) -- 126
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 127
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 128
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 129
	check("retry-goal-cleared", core.goalIndex == -1, "目标索引未清空") -- 130
	check( -- 131
		"retry-time-reset", -- 131
		core.flightTime == 0, -- 131
		"flightTime=" .. tostring(core.flightTime) -- 131
	) -- 131
	coreLaunch(core, {x = 0, y = -20}, level) -- 134
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 135
end -- 109
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 139
	local level = testLevel() -- 140
	local core = createCore() -- 141
	coreLaunch(core, {x = 6, y = -12}, level) -- 142
	local flight = core.flight -- 143
	if flight == nil then -- 143
		check("clamp-flight", false, "no flight") -- 144
		return -- 144
	end -- 144
	core.flightTime = -100 -- 146
	check( -- 147
		"clamp-negative", -- 147
		coreProbeIndex(core) == 0, -- 147
		"idx=" .. tostring(coreProbeIndex(core)) -- 147
	) -- 147
	core.flightTime = 1000000000 -- 149
	check( -- 150
		"clamp-huge", -- 150
		coreProbeIndex(core) == #flight.points - 1, -- 150
		"idx=" .. tostring(coreProbeIndex(core)) -- 150
	) -- 150
end -- 139
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 154
	local level = testLevel() -- 155
	local results = {} -- 156
	do -- 156
		local run = 0 -- 157
		while run < 2 do -- 157
			local core = createCore() -- 158
			coreLaunch(core, {x = 6, y = -12}, level) -- 159
			local guard = 0 -- 160
			while core.phase ~= "Result" and guard < 100000 do -- 160
				coreUpdate(core, 1 / 60) -- 162
				guard = guard + 1 -- 163
			end -- 163
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 165
			run = run + 1 -- 157
		end -- 157
	end -- 157
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 167
end -- 154
--- 7) 目标截断：到达目标后飞行提前结束，结算为成功。
local function testGoalTruncation() -- 171
	local bodies = {{ -- 173
		gm = 0, -- 174
		radius = 1.2, -- 174
		orbitCenter = {x = 0, y = -20}, -- 174
		orbitRadius = 0, -- 174
		orbitPeriod = 0, -- 174
		phase0 = 0, -- 174
		orbitDirection = 1 -- 174
	}} -- 174
	local level = { -- 176
		bodies = bodies, -- 177
		probeStart = {x = 0, y = 16}, -- 178
		goal = {kind = "planet", planetIndex = 0, tolerance = 3}, -- 179
		escapeRadius = 400, -- 180
		maxSteps = 1500 -- 181
	} -- 181
	local core = createCore() -- 184
	coreLaunch(core, {x = 0, y = -10}, level) -- 185
	check( -- 187
		"goal-found", -- 187
		core.goalIndex >= 0, -- 187
		"goalIndex=" .. tostring(core.goalIndex) -- 187
	) -- 187
	check( -- 188
		"goal-result-at-launch", -- 188
		core.result == "success", -- 188
		("result=" .. tostring(core.result)) .. "（结算应在发射瞬间确定）" -- 188
	) -- 188
	local flight = core.flight -- 190
	if flight == nil or core.goalIndex < 0 then -- 190
		check("goal-flight", false, "no flight") -- 191
		return -- 191
	end -- 191
	local guard = 0 -- 194
	while core.phase ~= "Result" and guard < 100000 do -- 194
		coreUpdate(core, 1 / 60) -- 196
		guard = guard + 1 -- 197
	end -- 197
	check( -- 199
		"goal-ends-early", -- 199
		core.phase == "Result" and coreProbeIndex(core) == core.goalIndex, -- 199
		(((("idx=" .. tostring(coreProbeIndex(core))) .. " goal=") .. tostring(core.goalIndex)) .. " natural=") .. tostring(#flight.points - 1) -- 199
	) -- 199
	check( -- 201
		"goal-still-success", -- 201
		core.result == "success", -- 201
		"result=" .. tostring(core.result) -- 201
	) -- 201
end -- 171
function ____exports.runTests() -- 204
	testResolveResult() -- 205
	testLaunch() -- 206
	testPlayback() -- 207
	testRetry() -- 208
	testIndexClamp() -- 209
	testDeterministicCycle() -- 210
	testGoalTruncation() -- 211
	local lines = {} -- 213
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 214
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 215
	local limit = #failures < 12 and #failures or 12 -- 216
	do -- 216
		local i = 0 -- 217
		while i < limit do -- 217
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 218
			i = i + 1 -- 217
		end -- 217
	end -- 217
	return table.concat(lines, "\n") -- 220
end -- 204
return ____exports -- 204
-- [ts]: GameTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Config = require("game.Config") -- 8
local FlightPlayback = ____Config.FlightPlayback -- 8
local PhysicsStep = ____Config.PhysicsStep -- 8
local ____Game = require("game.Game") -- 9
local coreLaunch = ____Game.coreLaunch -- 9
local coreProbeIndex = ____Game.coreProbeIndex -- 9
local coreRetry = ____Game.coreRetry -- 9
local coreUpdate = ____Game.coreUpdate -- 9
local createCore = ____Game.createCore -- 9
local resolveOutcome = ____Game.resolveOutcome -- 9
local failures = {} -- 16
local checks = 0 -- 17
local function check(name, ok, detail) -- 19
	checks = checks + 1 -- 20
	if not ok then -- 20
		failures[#failures + 1] = {name = name, detail = detail} -- 21
	end -- 21
end -- 19
--- 测试关：一颗静止行星在原点，探测器从 (0,16) 出发。
local function testLevel() -- 25
	local bodies = {{ -- 26
		gm = 900, -- 27
		radius = 2.2, -- 27
		orbitCenter = {x = 0, y = 0}, -- 28
		orbitRadius = 0, -- 28
		orbitPeriod = 0, -- 29
		phase0 = 0, -- 29
		orbitDirection = 1 -- 29
	}} -- 29
	return {bodies = bodies, probeStart = {x = 0, y = 16}, escapeRadius = 400, maxSteps = 1500} -- 31
end -- 25
--- 1) 结局映射（手册 §5.8 的 S1 简化版）。
local function testResolveOutcome() -- 35
	check( -- 36
		"resolve-crashed", -- 36
		resolveOutcome("crashed") == "crashed", -- 36
		"撞毁应映射为 crashed" -- 36
	) -- 36
	check( -- 37
		"resolve-escaped", -- 37
		resolveOutcome("escaped") == "success", -- 37
		"逃逸应映射为 success（S1 测试关）" -- 37
	) -- 37
	check( -- 38
		"resolve-running", -- 38
		resolveOutcome("running") == "missed", -- 38
		"超时应映射为 missed" -- 38
	) -- 38
end -- 35
--- 2) 发射：预推演、阶段切换、重复发射被拒绝。
local function testLaunch() -- 42
	local level = testLevel() -- 43
	local core = createCore() -- 44
	coreLaunch(core, {x = 6, y = -12}, level) -- 46
	check("launch-phase", core.phase == "Flying", "phase=" .. core.phase) -- 47
	check("launch-flight", core.flight ~= nil and #core.flight.points > 1, "飞行轨迹未预推演") -- 48
	check( -- 49
		"launch-time-zero", -- 49
		core.flightTime == 0, -- 49
		"flightTime=" .. tostring(core.flightTime) -- 49
	) -- 49
	local before = core.flight ~= nil and #core.flight.points or 0 -- 52
	coreLaunch(core, {x = 0, y = -20}, level) -- 53
	local after = core.flight ~= nil and #core.flight.points or 0 -- 54
	check("launch-guard", before == after, "Flying 态发射未被拒绝") -- 55
end -- 42
--- 3) 回放：时间推进 → 索引推进；到达终点恰好进入 Result。
local function testPlayback() -- 59
	local level = testLevel() -- 60
	local core = createCore() -- 61
	coreLaunch(core, {x = 6, y = -12}, level) -- 62
	local flight = core.flight -- 63
	if flight == nil then -- 63
		check("playback-flight", false, "no flight") -- 64
		return -- 64
	end -- 64
	local total = #flight.points - 1 -- 66
	check( -- 67
		"playback-start-index", -- 67
		coreProbeIndex(core) == 0, -- 67
		"idx=" .. tostring(coreProbeIndex(core)) -- 67
	) -- 67
	local entered = false -- 70
	local frames = 0 -- 71
	while not entered and frames < 100000 do -- 71
		entered = coreUpdate(core, 1 / 60) -- 73
		frames = frames + 1 -- 74
		if core.phase == "Result" then -- 74
			break -- 75
		end -- 75
	end -- 75
	check( -- 78
		"playback-enters-result", -- 78
		entered and core.phase == "Result", -- 78
		(("phase=" .. core.phase) .. " frames=") .. tostring(frames) -- 78
	) -- 78
	check( -- 79
		"playback-final-index", -- 79
		coreProbeIndex(core) == total, -- 79
		(("idx=" .. tostring(coreProbeIndex(core))) .. " total=") .. tostring(total) -- 79
	) -- 79
	check( -- 80
		"playback-result-kind", -- 80
		core.result == resolveOutcome(flight.outcome), -- 80
		(("result=" .. tostring(core.result)) .. " outcome=") .. flight.outcome -- 80
	) -- 80
	local expectedRealSeconds = total * PhysicsStep / FlightPlayback -- 83
	local actualRealSeconds = frames / 60 -- 84
	local tolerance = expectedRealSeconds * 0.05 + 0.05 -- 85
	check( -- 86
		"playback-duration", -- 86
		math.abs(actualRealSeconds - expectedRealSeconds) < tolerance, -- 86
		((("expected≈" .. __TS__NumberToFixed(expectedRealSeconds, 2)) .. "s actual=") .. __TS__NumberToFixed(actualRealSeconds, 2)) .. "s" -- 86
	) -- 86
end -- 59
--- 4) 重试：清空飞行与结算，回到 Aiming；非 Result 态重试被拒绝。
local function testRetry() -- 91
	local level = testLevel() -- 92
	local core = createCore() -- 93
	coreRetry(core) -- 96
	check("retry-guard-aiming", core.phase == "Aiming", "phase=" .. core.phase) -- 97
	coreLaunch(core, {x = 6, y = -12}, level) -- 99
	local entered = false -- 100
	local guard = 0 -- 101
	while not entered and guard < 100000 do -- 101
		entered = coreUpdate(core, 1 / 60) -- 103
		guard = guard + 1 -- 104
	end -- 104
	check("retry-reached-result", core.phase == "Result", "phase=" .. core.phase) -- 106
	coreRetry(core) -- 108
	check("retry-phase", core.phase == "Aiming", "phase=" .. core.phase) -- 109
	check("retry-flight-cleared", core.flight == nil, "飞行轨迹未清空") -- 110
	check("retry-result-cleared", core.result == nil, "结算未清空") -- 111
	check( -- 112
		"retry-time-reset", -- 112
		core.flightTime == 0, -- 112
		"flightTime=" .. tostring(core.flightTime) -- 112
	) -- 112
	coreLaunch(core, {x = 0, y = -20}, level) -- 115
	check("retry-relaunch", core.phase == "Flying" and core.flight ~= nil, "phase=" .. core.phase) -- 116
end -- 91
--- 5) 索引夹紧：极端时间不越界。
local function testIndexClamp() -- 120
	local level = testLevel() -- 121
	local core = createCore() -- 122
	coreLaunch(core, {x = 6, y = -12}, level) -- 123
	local flight = core.flight -- 124
	if flight == nil then -- 124
		check("clamp-flight", false, "no flight") -- 125
		return -- 125
	end -- 125
	core.flightTime = -100 -- 127
	check( -- 128
		"clamp-negative", -- 128
		coreProbeIndex(core) == 0, -- 128
		"idx=" .. tostring(coreProbeIndex(core)) -- 128
	) -- 128
	core.flightTime = 1000000000 -- 130
	check( -- 131
		"clamp-huge", -- 131
		coreProbeIndex(core) == #flight.points - 1, -- 131
		"idx=" .. tostring(coreProbeIndex(core)) -- 131
	) -- 131
end -- 120
--- 6) 确定性贯穿状态机：同一发射向量两次完整流程，结局一致。
local function testDeterministicCycle() -- 135
	local level = testLevel() -- 136
	local results = {} -- 137
	do -- 137
		local run = 0 -- 138
		while run < 2 do -- 138
			local core = createCore() -- 139
			coreLaunch(core, {x = 6, y = -12}, level) -- 140
			local guard = 0 -- 141
			while core.phase ~= "Result" and guard < 100000 do -- 141
				coreUpdate(core, 1 / 60) -- 143
				guard = guard + 1 -- 144
			end -- 144
			results[#results + 1] = (((tostring(core.result) .. ":") .. (core.flight ~= nil and core.flight.outcome or "none")) .. ":") .. tostring(core.flight ~= nil and #core.flight.points or 0) -- 146
			run = run + 1 -- 138
		end -- 138
	end -- 138
	check("cycle-deterministic", results[1] == results[2], (results[1] .. " vs ") .. results[2]) -- 148
end -- 135
function ____exports.runTests() -- 151
	testResolveOutcome() -- 152
	testLaunch() -- 153
	testPlayback() -- 154
	testRetry() -- 155
	testIndexClamp() -- 156
	testDeterministicCycle() -- 157
	local lines = {} -- 159
	lines[#lines + 1] = #failures == 0 and "passed" or "failed" -- 160
	lines[#lines + 1] = (("checks=" .. tostring(checks)) .. " failures=") .. tostring(#failures) -- 161
	local limit = #failures < 12 and #failures or 12 -- 162
	do -- 162
		local i = 0 -- 163
		while i < limit do -- 163
			lines[#lines + 1] = (("FAIL " .. failures[i + 1].name) .. ": ") .. failures[i + 1].detail -- 164
			i = i + 1 -- 163
		end -- 163
	end -- 163
	return table.concat(lines, "\n") -- 166
end -- 151
return ____exports -- 151
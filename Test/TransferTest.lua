-- [ts]: TransferTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 2
local Content = ____Dora.Content -- 2
local json = ____Dora.json -- 2
local ____Gravity = require("game.Gravity") -- 3
local bodyPositionAt = ____Gravity.bodyPositionAt -- 3
local distance = ____Gravity.distance -- 3
local simulate = ____Gravity.simulate -- 3
local ____LevelData = require("game.LevelData") -- 4
local getLevel = ____LevelData.getLevel -- 4
local goalPositionAt = ____LevelData.goalPositionAt -- 4
local installArcadeLevels = ____LevelData.installArcadeLevels -- 4
local findGoalIndex = ____LevelData.findGoalIndex -- 4
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 4
local ____Transfer = require("game.Transfer") -- 5
local advanceTransferPlayback = ____Transfer.advanceTransferPlayback -- 5
local analyzeFlyby = ____Transfer.analyzeFlyby -- 5
local nextCameraFocus = ____Transfer.nextCameraFocus -- 5
local planTransfer = ____Transfer.planTransfer -- 5
local transferPlaybackRate = ____Transfer.transferPlaybackRate -- 5
local transferShotAt = ____Transfer.transferShotAt -- 5
local ____Game = require("game.Game") -- 6
local createCore = ____Game.createCore -- 6
local coreEndViewing = ____Game.coreEndViewing -- 6
local coreLaunch = ____Game.coreLaunch -- 6
local coreUpdate = ____Game.coreUpdate -- 6
local coreRetry = ____Game.coreRetry -- 6
local selectIdleHost = ____Game.selectIdleHost -- 6
local isBrakeWindowActive = ____Game.isBrakeWindowActive -- 6
local applyInFlightBrake = ____Game.applyInFlightBrake -- 6
function ____exports.runTests() -- 8
	local checks = 0 -- 9
	local failures = {} -- 10
	local function check(name, ok) -- 11
		checks = checks + 1 -- 11
		if not ok then -- 11
			failures[#failures + 1] = name -- 11
		end -- 11
	end -- 11
	installArcadeLevels( -- 12
		Content:load("Assets/Levels/levels.json"), -- 12
		Content:load("Assets/Levels/bodies.json"), -- 12
		function(text) return (json.decode(text)) end -- 12
	) -- 12
	local lv = getLevel(0) -- 13
	if lv == nil or lv.transfer == nil or lv.transfer.flyby == nil then -- 13
		return "failed\nmissing transfer fixture" -- 14
	end -- 14
	local tr = lv.transfer -- 15
	local cfg = lv.transfer.flyby -- 16
	local dt = 0.016 -- 17
	local radius = distance( -- 18
		lv.probeStart, -- 18
		bodyPositionAt(lv.planets[1], 0) -- 18
	) -- 18
	local date = 1 -- 19
	local power = 0.875 -- 19
	local function startAt(t) -- 20
		local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(lv.planets[1].gm / (radius * radius * radius)) * t -- 21
		local speed = math.sqrt(lv.planets[1].gm / radius) -- 22
		return { -- 23
			pos = { -- 23
				x = radius * math.cos(a), -- 23
				y = radius * math.sin(a) -- 23
			}, -- 23
			vel = { -- 23
				x = -math.sin(a) * speed, -- 23
				y = math.cos(a) * speed -- 23
			} -- 23
		} -- 23
	end -- 20
	local start = startAt(date) -- 25
	local plan = planTransfer( -- 26
		lv.planets[1].gm, -- 26
		radius, -- 26
		start.vel, -- 26
		power, -- 26
		tr.apoapsisMax -- 26
	) -- 26
	local level = { -- 27
		bodies = lv.planets, -- 27
		probeStart = lv.probeStart, -- 27
		probeVel0 = lv.probeVel0, -- 27
		goal = lv.goal, -- 27
		escapeRadius = lv.escapeRadius, -- 27
		maxSteps = lv.maxSteps, -- 27
		transfer = tr -- 27
	} -- 27
	local core = createCore(dt) -- 28
	core.t0 = date -- 29
	core.aim.velocity = plan.velocity -- 30
	coreLaunch( -- 31
		core, -- 31
		plan.velocity, -- 31
		level, -- 31
		start.pos, -- 31
		start.vel -- 31
	) -- 31
	core.playback = 1 -- 32
	check("earth-moon-only", #lv.planets == 2 and lv.planets[2].name == "月球") -- 33
	check( -- 34
		"low-orbit-height", -- 34
		math.abs(radius - lv.planets[1].radius - 90) < 1e-9 -- 34
	) -- 34
	check( -- 35
		"nearest-earth-at-low-orbit", -- 35
		selectIdleHost(lv.planets, lv.probeStart) == 0 -- 35
	) -- 35
	check( -- 36
		"explicit-earth-host", -- 36
		selectIdleHost(lv.planets, lv.probeStart, 0) == 0 -- 36
	) -- 36
	check("no-stars", lv.stars ~= nil and #lv.stars == 0) -- 37
	check("completion-only", lv.mission ~= nil and #lv.mission.challenges == 1) -- 38
	check( -- 39
		"prograde-only", -- 39
		math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-9 -- 39
	) -- 39
	check( -- 40
		"zero-burn", -- 40
		planTransfer( -- 40
			lv.planets[1].gm, -- 40
			radius, -- 40
			lv.probeVel0, -- 40
			0, -- 40
			tr.apoapsisMax -- 40
		).dv == 0 -- 40
	) -- 40
	check( -- 41
		"power-clamped", -- 41
		planTransfer( -- 41
			lv.planets[1].gm, -- 41
			radius, -- 41
			lv.probeVel0, -- 41
			2, -- 41
			tr.apoapsisMax -- 41
		).apoapsis == tr.apoapsisMax -- 41
	) -- 41
	check("burn-about-0.3s", core.burnDuration > 0.25 and core.burnDuration < 0.35) -- 42
	check("planned-safe-flyby", core.flyby ~= nil and core.goalIndex >= 0 and core.flyby.energyDrop >= cfg.minEnergyDrop) -- 43
	check("completion-not-visible-at-launch", not core.missionCompleted and core.result == nil) -- 44
	check( -- 45
		"cannot-end-before-completion", -- 45
		not coreEndViewing(core) -- 45
	) -- 45
	check( -- 46
		"no-brake-window", -- 46
		not isBrakeWindowActive(core, level) -- 46
	) -- 46
	check( -- 47
		"cannot-brake", -- 47
		not applyInFlightBrake(core, level) -- 47
	) -- 47
	local actual = core.flight -- 48
	if actual == nil then -- 48
		return "failed\nmissing flight" -- 49
	end -- 49
	check( -- 50
		"no-instant-impulse", -- 50
		distance(actual.velocities[1], start.vel) < 1e-10 -- 50
	) -- 50
	local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 51
		dt = dt, -- 51
		steps = lv.maxSteps, -- 51
		sampleEvery = 1, -- 51
		escapeRadius = lv.escapeRadius, -- 51
		t0 = date -- 51
	}) -- 51
	local reference = analyzeFlyby( -- 52
		ref, -- 52
		lv.planets[1], -- 52
		lv.planets[2], -- 52
		cfg, -- 52
		dt, -- 52
		date -- 52
	) -- 52
	check("reference-safe-flyby", reference.completionIndex >= 0) -- 53
	local peri = core.flyby ~= nil and core.flyby.periapsisIndex or 0 -- 54
	local drift = distance(actual.points[peri + 1], ref.points[peri + 1]) -- 55
	check("small-nonzero-drift", drift > 0.01 and drift < 20) -- 56
	check( -- 57
		"periapsis-drift-tolerated", -- 57
		core.flyby ~= nil and math.abs(core.flyby.periapsis - reference.periapsis) < 5 -- 57
	) -- 57
	local accelerated = analyzeFlyby( -- 58
		actual, -- 58
		lv.planets[1], -- 58
		lv.planets[2], -- 58
		__TS__ObjectAssign({}, cfg, {minEnergyDrop = 1000}), -- 58
		dt, -- 58
		date -- 58
	) -- 58
	check("energy-drop-is-required", accelerated.completionIndex < 0) -- 59
	check( -- 60
		"close-pass-is-required", -- 60
		analyzeFlyby( -- 60
			actual, -- 60
			lv.planets[1], -- 60
			lv.planets[2], -- 60
			__TS__ObjectAssign({}, cfg, {maxPeriapsis = 45}), -- 60
			dt, -- 60
			date -- 60
		).completionIndex < 0 -- 60
	) -- 60
	check( -- 61
		"safety-margin-is-required", -- 61
		analyzeFlyby( -- 61
			actual, -- 61
			lv.planets[1], -- 61
			lv.planets[2], -- 61
			__TS__ObjectAssign({}, cfg, {minPeriapsis = 60}), -- 61
			dt, -- 61
			date -- 61
		).completionIndex < 0 -- 61
	) -- 61
	local timeout = analyzeFlyby( -- 62
		actual, -- 62
		lv.planets[1], -- 62
		lv.planets[2], -- 62
		__TS__ObjectAssign({}, cfg, {returnRadius = 1}), -- 62
		dt, -- 62
		date -- 62
	) -- 62
	check( -- 63
		"view-timeout-without-earth-return", -- 63
		timeout.completionIndex >= 0 and timeout.viewEndIndex == timeout.completionIndex + math.floor(cfg.maxViewingTime / dt) -- 63
	) -- 63
	local light = createCore(dt) -- 64
	light.t0 = date -- 65
	coreLaunch( -- 66
		light, -- 66
		plan.velocity, -- 66
		level, -- 66
		start.pos, -- 66
		start.vel -- 66
	) -- 66
	local lightIndex = findGoalIndex( -- 67
		actual.points, -- 67
		lv.planets, -- 67
		lv.goal, -- 67
		dt, -- 67
		date -- 67
	) -- 67
	light.flightTime = lightIndex * dt -- 68
	light.playback = 0 -- 69
	coreUpdate(light, 0, level) -- 70
	check("light-does-not-complete", lightIndex > 0 and lightIndex < core.goalIndex and light.phase == "Flying" and not light.missionCompleted) -- 71
	light.flightTime = core.goalIndex * dt -- 72
	coreUpdate(light, 0, level) -- 73
	check("flyby-completes-without-ending", light.missionCompleted and light.phase == "Flying" and light.result == "success") -- 74
	check( -- 75
		"manual-end-after-completion", -- 75
		coreEndViewing(light) and light.phase == "Result" and light.result == "success" -- 75
	) -- 75
	do -- 75
		local t = 0 -- 76
		while t < 80 do -- 76
			local moon = bodyPositionAt(lv.planets[2], t) -- 77
			local goal = goalPositionAt(lv.planets[2], t, lv.goal.offset) -- 78
			check( -- 79
				"safe-goal-" .. __TS__NumberToFixed(t, 0), -- 79
				distance(moon, goal) > lv.planets[2].radius + lv.goal.tolerance -- 79
			) -- 79
			t = t + 20 -- 76
		end -- 76
	end -- 76
	local opts = { -- 81
		dt = dt, -- 81
		steps = 100, -- 81
		sampleEvery = 1, -- 81
		escapeRadius = 0, -- 81
		initialBurn = {acceleration = {x = 10, y = 0}, duration = 0.301} -- 81
	} -- 81
	local fractional = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 82
	check( -- 83
		"fractional-last-burn-step", -- 83
		math.abs(fractional.state.vel.x - 3.01) < 1e-10 -- 83
	) -- 83
	local twice = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 84
	check("burn-deterministic", fractional.state.pos.x == twice.state.pos.x and fractional.state.vel.x == twice.state.vel.x) -- 85
	local pausedAt = core.flightTime -- 86
	core.playback = 0 -- 87
	do -- 87
		local i = 0 -- 88
		while i < 50 do -- 88
			coreUpdate(core, 1 / 60, level) -- 88
			i = i + 1 -- 88
		end -- 88
	end -- 88
	check("pause-freezes-burn", core.flightTime == pausedAt) -- 89
	core.playback = 1 -- 90
	local wall = 0 -- 91
	while core.phase == "Flying" and wall < 40 do -- 91
		coreUpdate(core, 1 / 60, level) -- 92
		wall = wall + 1 / 60 -- 92
	end -- 92
	check("12-to-18s-playback", wall >= 12 and wall <= 18) -- 93
	check("return-clamped", core.phase == "Result" and core.missionCompleted and core.flyby ~= nil and core.flightTime == core.flyby.viewEndIndex * dt and core.flightTime > core.goalIndex * dt) -- 94
	check( -- 95
		"return-near-earth", -- 95
		distance( -- 95
			actual.points[math.floor(core.flightTime / dt) + 1], -- 95
			bodyPositionAt(lv.planets[1], date + core.flightTime) -- 95
		) <= cfg.returnRadius -- 95
	) -- 95
	local fast = createCore(dt) -- 96
	fast.t0 = date -- 97
	coreLaunch( -- 98
		fast, -- 98
		plan.velocity, -- 98
		level, -- 98
		start.pos, -- 98
		start.vel -- 98
	) -- 98
	fast.playback = 4 -- 99
	do -- 99
		local i = 0 -- 100
		while i < 1000 and fast.phase == "Flying" do -- 100
			coreUpdate(fast, 1 / 120, level) -- 100
			i = i + 1 -- 100
		end -- 100
	end -- 100
	check( -- 101
		"speed-does-not-change-result", -- 101
		fast.result == core.result and fast.flightTime == core.flightTime and fast.flight ~= nil and distance(fast.flight.points[fast.goalIndex + 1], actual.points[core.goalIndex + 1]) == 0 -- 101
	) -- 101
	local low = createCore(dt) -- 102
	low.t0 = date -- 103
	coreLaunch( -- 104
		low, -- 104
		planTransfer( -- 104
			lv.planets[1].gm, -- 104
			radius, -- 104
			start.vel, -- 104
			0.05, -- 104
			tr.apoapsisMax -- 104
		).velocity, -- 104
		level, -- 104
		start.pos, -- 104
		start.vel -- 104
	) -- 104
	check("low-power-misses", low.goalIndex < 0) -- 105
	local wrong = createCore(dt) -- 106
	wrong.t0 = 1.8 -- 107
	local wrongStart = startAt(wrong.t0) -- 108
	coreLaunch( -- 109
		wrong, -- 109
		planTransfer( -- 109
			lv.planets[1].gm, -- 109
			radius, -- 109
			wrongStart.vel, -- 109
			power, -- 109
			tr.apoapsisMax -- 109
		).velocity, -- 109
		level, -- 109
		wrongStart.pos, -- 109
		wrongStart.vel -- 109
	) -- 109
	check("wrong-phase-misses", wrong.goalIndex < 0) -- 110
	local collision = simulate( -- 111
		{ -- 111
			pos = bodyPositionAt(lv.planets[2], 0), -- 111
			vel = {x = 0, y = 0} -- 111
		}, -- 111
		lv.planets, -- 111
		{dt = dt, steps = 10, sampleEvery = 1, escapeRadius = 0} -- 111
	) -- 111
	check("moon-is-solid", collision.outcome == "crashed") -- 112
	check( -- 113
		"moon-is-not-target", -- 113
		findGoalIndex( -- 113
			collision.points, -- 113
			lv.planets, -- 113
			lv.goal, -- 113
			dt, -- 113
			0 -- 113
		) < 0 -- 113
	) -- 113
	check( -- 114
		"collision-cannot-complete", -- 114
		analyzeFlyby( -- 114
			collision, -- 114
			lv.planets[1], -- 114
			lv.planets[2], -- 114
			cfg, -- 114
			dt, -- 114
			0 -- 114
		).completionIndex < 0 -- 114
	) -- 114
	local collideCore = createCore(dt) -- 115
	coreLaunch( -- 116
		collideCore, -- 116
		{x = 0, y = 0}, -- 116
		level, -- 116
		bodyPositionAt(lv.planets[2], 0), -- 116
		{x = 0, y = 0} -- 116
	) -- 116
	coreUpdate(collideCore, 1, level) -- 117
	check("collision-fails-before-completion", collideCore.phase == "Result" and collideCore.result == "crashed" and not collideCore.missionCompleted) -- 118
	local afterCrash = createCore(dt) -- 119
	coreLaunch( -- 120
		afterCrash, -- 120
		{x = 0, y = 0}, -- 120
		level, -- 120
		bodyPositionAt(lv.planets[2], 0), -- 120
		{x = 0, y = 0} -- 120
	) -- 120
	afterCrash.missionCompleted = true -- 122
	afterCrash.result = "success" -- 122
	coreUpdate(afterCrash, 1, level) -- 123
	check("completion-survives-later-collision", afterCrash.phase == "Result" and afterCrash.result == "success") -- 124
	check( -- 125
		"launch-shot", -- 125
		transferShotAt( -- 125
			0, -- 125
			core.burnDuration, -- 125
			core.flyby, -- 125
			cfg, -- 125
			dt -- 125
		) == "Launch" -- 125
	) -- 125
	check( -- 126
		"cruise-shot", -- 126
		transferShotAt( -- 126
			4, -- 126
			core.burnDuration, -- 126
			core.flyby, -- 126
			cfg, -- 126
			dt -- 126
		) == "Cruise" -- 126
	) -- 126
	check( -- 127
		"moon-shot", -- 127
		transferShotAt( -- 127
			peri * dt, -- 127
			core.burnDuration, -- 127
			core.flyby, -- 127
			cfg, -- 127
			dt -- 127
		) == "Moon" -- 127
	) -- 127
	check( -- 128
		"overview-shot", -- 128
		transferShotAt( -- 128
			core.goalIndex * dt + 1, -- 128
			core.burnDuration, -- 128
			core.flyby, -- 128
			cfg, -- 128
			dt -- 128
		) == "Overview" -- 128
	) -- 128
	check( -- 129
		"return-shot", -- 129
		transferShotAt( -- 129
			core.goalIndex * dt + cfg.overviewDuration + 0.1, -- 129
			core.burnDuration, -- 129
			core.flyby, -- 129
			cfg, -- 129
			dt -- 129
		) == "Earth" -- 129
	) -- 129
	check( -- 130
		"camera-cycle", -- 130
		nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus("Auto"))))) == "Auto" -- 130
	) -- 130
	check( -- 131
		"burn-at-1x", -- 131
		transferPlaybackRate( -- 131
			0.1, -- 131
			core.burnDuration, -- 131
			tr, -- 131
			core.flyby, -- 131
			dt -- 131
		) == 1 -- 131
	) -- 131
	check( -- 132
		"coast-at-3x", -- 132
		transferPlaybackRate( -- 132
			4, -- 132
			core.burnDuration, -- 132
			tr, -- 132
			core.flyby, -- 132
			dt -- 132
		) == 3 -- 132
	) -- 132
	check( -- 133
		"periapsis-at-1x", -- 133
		transferPlaybackRate( -- 133
			peri * dt, -- 133
			core.burnDuration, -- 133
			tr, -- 133
			core.flyby, -- 133
			dt -- 133
		) == 1 -- 133
	) -- 133
	local at30 = 0 -- 134
	local at120 = 0 -- 134
	do -- 134
		local i = 0 -- 135
		while i < 360 do -- 135
			at30 = advanceTransferPlayback( -- 135
				at30, -- 135
				1 / 30, -- 135
				1, -- 135
				core.burnDuration, -- 135
				tr, -- 135
				core.flyby, -- 135
				dt -- 135
			) -- 135
			i = i + 1 -- 135
		end -- 135
	end -- 135
	do -- 135
		local i = 0 -- 136
		while i < 1440 do -- 136
			at120 = advanceTransferPlayback( -- 136
				at120, -- 136
				1 / 120, -- 136
				1, -- 136
				core.burnDuration, -- 136
				tr, -- 136
				core.flyby, -- 136
				dt -- 136
			) -- 136
			i = i + 1 -- 136
		end -- 136
	end -- 136
	check( -- 137
		"frame-rate-independent-playback", -- 137
		math.abs(at30 - at120) < 1e-9 -- 137
	) -- 137
	local score = evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}) -- 138
	check("no-phantom-stars", score.rockets == 1 and not score.achieved[2] and not score.achieved[3]) -- 139
	coreRetry(core, 0) -- 140
	check("retry-aiming", core.phase == "Aiming" and core.flight == nil and not core.missionCompleted and core.flyby == nil) -- 141
	check( -- 142
		"l2-configured", -- 142
		getLevel(1) ~= nil and getLevel(1).transfer.orbital ~= nil and #getLevel(1).stars == 0 -- 142
	) -- 142
	check( -- 143
		"l3-configured", -- 143
		getLevel(2) ~= nil and getLevel(2).transfer.orbital ~= nil and #getLevel(2).stars == 0 -- 143
	) -- 143
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 144
end -- 8
return ____exports -- 8
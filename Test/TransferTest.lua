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
local goalPulseAlpha = ____Transfer.goalPulseAlpha -- 5
local successMarkerFrame = ____Transfer.successMarkerFrame -- 5
local transferPlaybackRate = ____Transfer.transferPlaybackRate -- 5
local transferShotAt = ____Transfer.transferShotAt -- 5
local ____Game = require("game.Game") -- 6
local createCore = ____Game.createCore -- 6
local coreEndViewing = ____Game.coreEndViewing -- 6
local coreLaunch = ____Game.coreLaunch -- 6
local coreUpdate = ____Game.coreUpdate -- 6
local coreRetry = ____Game.coreRetry -- 6
local selectIdleHost = ____Game.selectIdleHost -- 6
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
	check( -- 18
		"goal-pulse-min", -- 18
		math.abs(goalPulseAlpha(0) - 0.3) < 1e-9 -- 18
	) -- 18
	check( -- 19
		"goal-pulse-max", -- 19
		math.abs(goalPulseAlpha(0.8) - 0.75) < 1e-9 -- 19
	) -- 19
	check( -- 20
		"goal-pulse-period", -- 20
		math.abs(goalPulseAlpha(1.6) - goalPulseAlpha(0)) < 1e-9 -- 20
	) -- 20
	check( -- 21
		"goal-pulse-smooth", -- 21
		goalPulseAlpha(0.4) > goalPulseAlpha(0) and goalPulseAlpha(0.4) < goalPulseAlpha(0.8) -- 21
	) -- 21
	check( -- 22
		"marker-idle-visible", -- 22
		successMarkerFrame(-1).visible and successMarkerFrame(-1).alpha == 1 -- 22
	) -- 22
	check( -- 23
		"marker-bright-pulse", -- 23
		successMarkerFrame(0.1).scale > 1.5 and successMarkerFrame(0.1).ring == 0 -- 23
	) -- 23
	check( -- 24
		"marker-expands-and-fades", -- 24
		successMarkerFrame(0.3).ring > 8 and successMarkerFrame(0.3).alpha < 1 -- 24
	) -- 24
	check( -- 25
		"marker-hidden-at-0.6", -- 25
		not successMarkerFrame(0.6).visible and successMarkerFrame(0.6).alpha == 0 -- 25
	) -- 25
	check( -- 26
		"marker-stays-hidden", -- 26
		not successMarkerFrame(10).visible -- 26
	) -- 26
	local radius = distance( -- 27
		lv.probeStart, -- 27
		bodyPositionAt(lv.planets[1], 0) -- 27
	) -- 27
	local date = 1 -- 28
	local power = 0.875 -- 28
	local function startAt(t) -- 29
		local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(lv.planets[1].gm / (radius * radius * radius)) * t -- 30
		local speed = math.sqrt(lv.planets[1].gm / radius) -- 31
		return { -- 32
			pos = { -- 32
				x = radius * math.cos(a), -- 32
				y = radius * math.sin(a) -- 32
			}, -- 32
			vel = { -- 32
				x = -math.sin(a) * speed, -- 32
				y = math.cos(a) * speed -- 32
			} -- 32
		} -- 32
	end -- 29
	local start = startAt(date) -- 34
	local plan = planTransfer( -- 35
		lv.planets[1].gm, -- 35
		radius, -- 35
		start.vel, -- 35
		power, -- 35
		tr.apoapsisMax -- 35
	) -- 35
	local level = { -- 36
		levelId = 1, -- 36
		viewingSeconds = 24, -- 36
		bonusPoints = lv.bonusPoints, -- 36
		bodies = lv.planets, -- 36
		probeStart = lv.probeStart, -- 36
		probeVel0 = lv.probeVel0, -- 36
		goal = lv.goal, -- 36
		escapeRadius = lv.escapeRadius, -- 36
		maxSteps = lv.maxSteps, -- 36
		transfer = tr -- 36
	} -- 36
	local core = createCore(dt) -- 37
	core.t0 = date -- 38
	core.aim.velocity = plan.velocity -- 39
	coreLaunch( -- 40
		core, -- 40
		plan.velocity, -- 40
		level, -- 40
		start.pos, -- 40
		start.vel -- 40
	) -- 40
	core.playback = 1 -- 41
	check("earth-moon-only", #lv.planets == 2 and lv.planets[2].name == "月球") -- 42
	check( -- 43
		"low-orbit-height", -- 43
		math.abs(radius - lv.planets[1].radius - 90) < 1e-9 -- 43
	) -- 43
	check( -- 44
		"nearest-earth-at-low-orbit", -- 44
		selectIdleHost(lv.planets, lv.probeStart) == 0 -- 44
	) -- 44
	check( -- 45
		"explicit-earth-host", -- 45
		selectIdleHost(lv.planets, lv.probeStart, 0) == 0 -- 45
	) -- 45
	check("no-stars", lv.stars ~= nil and #lv.stars == 0) -- 46
	check("completion-only", lv.mission ~= nil and #lv.mission.challenges == 1) -- 47
	check( -- 48
		"prograde-only", -- 48
		math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-9 -- 48
	) -- 48
	check( -- 49
		"zero-burn", -- 49
		planTransfer( -- 49
			lv.planets[1].gm, -- 49
			radius, -- 49
			lv.probeVel0, -- 49
			0, -- 49
			tr.apoapsisMax -- 49
		).dv == 0 -- 49
	) -- 49
	check( -- 50
		"power-clamped", -- 50
		planTransfer( -- 50
			lv.planets[1].gm, -- 50
			radius, -- 50
			lv.probeVel0, -- 50
			2, -- 50
			tr.apoapsisMax -- 50
		).apoapsis == tr.apoapsisMax -- 50
	) -- 50
	check("burn-about-0.3s", core.burnDuration > 0.25 and core.burnDuration < 0.35) -- 51
	check("planned-safe-flyby", core.flyby ~= nil and core.goalIndex >= 0 and core.flyby.energyDrop >= cfg.minEnergyDrop) -- 52
	check("completion-not-visible-at-launch", not core.missionCompleted) -- 53
	check( -- 54
		"cannot-end-before-completion", -- 54
		not coreEndViewing(core) -- 54
	) -- 54
	local actual = core.flight -- 55
	if actual == nil then -- 55
		return "failed\nmissing flight" -- 56
	end -- 56
	check( -- 57
		"no-instant-impulse", -- 57
		distance(actual.velocities[1], start.vel) < 1e-10 -- 57
	) -- 57
	local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 58
		dt = dt, -- 58
		steps = lv.maxSteps, -- 58
		sampleEvery = 1, -- 58
		escapeRadius = lv.escapeRadius, -- 58
		t0 = date -- 58
	}) -- 58
	local reference = analyzeFlyby( -- 59
		ref, -- 59
		lv.planets[1], -- 59
		lv.planets[2], -- 59
		cfg, -- 59
		dt, -- 59
		date -- 59
	) -- 59
	check("reference-safe-flyby", reference.completionIndex >= 0) -- 60
	local peri = core.flyby ~= nil and core.flyby.periapsisIndex or 0 -- 61
	local drift = distance(actual.points[peri + 1], ref.points[peri + 1]) -- 62
	check("small-nonzero-drift", drift > 0.01 and drift < 20) -- 63
	check( -- 64
		"periapsis-drift-tolerated", -- 64
		core.flyby ~= nil and math.abs(core.flyby.periapsis - reference.periapsis) < 5 -- 64
	) -- 64
	local accelerated = analyzeFlyby( -- 65
		actual, -- 65
		lv.planets[1], -- 65
		lv.planets[2], -- 65
		__TS__ObjectAssign({}, cfg, {minEnergyDrop = 1000}), -- 65
		dt, -- 65
		date -- 65
	) -- 65
	check("energy-drop-is-required", accelerated.completionIndex < 0) -- 66
	check( -- 67
		"close-pass-is-required", -- 67
		analyzeFlyby( -- 67
			actual, -- 67
			lv.planets[1], -- 67
			lv.planets[2], -- 67
			__TS__ObjectAssign({}, cfg, {maxPeriapsis = 45}), -- 67
			dt, -- 67
			date -- 67
		).completionIndex < 0 -- 67
	) -- 67
	check( -- 68
		"safety-margin-is-required", -- 68
		analyzeFlyby( -- 68
			actual, -- 68
			lv.planets[1], -- 68
			lv.planets[2], -- 68
			__TS__ObjectAssign({}, cfg, {minPeriapsis = 60}), -- 68
			dt, -- 68
			date -- 68
		).completionIndex < 0 -- 68
	) -- 68
	local timeout = analyzeFlyby( -- 69
		actual, -- 69
		lv.planets[1], -- 69
		lv.planets[2], -- 69
		__TS__ObjectAssign({}, cfg, {returnRadius = 1}), -- 69
		dt, -- 69
		date -- 69
	) -- 69
	check( -- 70
		"view-timeout-without-earth-return", -- 70
		timeout.completionIndex >= 0 and timeout.viewEndIndex == timeout.completionIndex + math.floor(cfg.maxViewingTime / dt) -- 70
	) -- 70
	local light = createCore(dt) -- 71
	light.t0 = date -- 72
	coreLaunch( -- 73
		light, -- 73
		plan.velocity, -- 73
		level, -- 73
		start.pos, -- 73
		start.vel -- 73
	) -- 73
	local lightIndex = core.goalIndex - 1 -- 74
	light.flightTime = lightIndex * dt -- 75
	light.playback = 0 -- 76
	coreUpdate(light, 0, level) -- 77
	check("light-does-not-complete", lightIndex >= 0 and lightIndex < core.goalIndex and light.phase == "Flying" and not light.missionCompleted) -- 78
	light.flightTime = core.goalIndex * dt -- 79
	coreUpdate(light, 0, level) -- 80
	check("flyby-completes-without-ending", light.missionCompleted and light.phase == "Flying" and light.result == "success") -- 81
	check( -- 82
		"manual-end-after-completion", -- 82
		coreEndViewing(light) and light.phase == "Result" and light.result == "success" -- 82
	) -- 82
	do -- 82
		local t = 0 -- 83
		while t < 80 do -- 83
			local moon = bodyPositionAt(lv.planets[2], t) -- 84
			local goal = goalPositionAt(lv.planets[2], t, lv.goal.offset) -- 85
			check( -- 86
				"safe-goal-" .. __TS__NumberToFixed(t, 0), -- 86
				distance(moon, goal) > lv.planets[2].radius + lv.goal.tolerance -- 86
			) -- 86
			t = t + 20 -- 83
		end -- 83
	end -- 83
	local opts = { -- 88
		dt = dt, -- 88
		steps = 100, -- 88
		sampleEvery = 1, -- 88
		escapeRadius = 0, -- 88
		initialBurn = {acceleration = {x = 10, y = 0}, duration = 0.301} -- 88
	} -- 88
	local fractional = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 89
	check( -- 90
		"fractional-last-burn-step", -- 90
		math.abs(fractional.state.vel.x - 3.01) < 1e-10 -- 90
	) -- 90
	local twice = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 91
	check("burn-deterministic", fractional.state.pos.x == twice.state.pos.x and fractional.state.vel.x == twice.state.vel.x) -- 92
	local pausedAt = core.flightTime -- 93
	core.playback = 0 -- 94
	do -- 94
		local i = 0 -- 95
		while i < 50 do -- 95
			coreUpdate(core, 1 / 60, level) -- 95
			i = i + 1 -- 95
		end -- 95
	end -- 95
	check("pause-freezes-burn", core.flightTime == pausedAt) -- 96
	core.playback = 1 -- 97
	local wall = 0 -- 98
	while core.phase == "Flying" and wall < 40 do -- 98
		coreUpdate(core, 1 / 60, level) -- 99
		wall = wall + 1 / 60 -- 99
	end -- 99
	check("12-to-18s-playback", wall >= 12 and wall <= 18) -- 100
	check("return-clamped", core.phase == "Result" and core.missionCompleted and core.flyby ~= nil and core.flightTime == core.flyby.viewEndIndex * dt and core.flightTime > core.goalIndex * dt) -- 101
	check( -- 102
		"return-near-earth", -- 102
		distance( -- 102
			actual.points[math.floor(core.flightTime / dt) + 1], -- 102
			bodyPositionAt(lv.planets[1], date + core.flightTime) -- 102
		) <= cfg.returnRadius -- 102
	) -- 102
	local fast = createCore(dt) -- 103
	fast.t0 = date -- 104
	coreLaunch( -- 105
		fast, -- 105
		plan.velocity, -- 105
		level, -- 105
		start.pos, -- 105
		start.vel -- 105
	) -- 105
	fast.playback = 4 -- 106
	do -- 106
		local i = 0 -- 107
		while i < 1000 and fast.phase == "Flying" do -- 107
			coreUpdate(fast, 1 / 120, level) -- 107
			i = i + 1 -- 107
		end -- 107
	end -- 107
	check( -- 108
		"speed-does-not-change-result", -- 108
		fast.result == core.result and fast.flightTime == core.flightTime and fast.flight ~= nil and distance(fast.flight.points[fast.goalIndex + 1], actual.points[core.goalIndex + 1]) == 0 -- 108
	) -- 108
	local low = createCore(dt) -- 109
	low.t0 = date -- 110
	coreLaunch( -- 111
		low, -- 111
		planTransfer( -- 111
			lv.planets[1].gm, -- 111
			radius, -- 111
			start.vel, -- 111
			0.05, -- 111
			tr.apoapsisMax -- 111
		).velocity, -- 111
		level, -- 111
		start.pos, -- 111
		start.vel -- 111
	) -- 111
	check("low-power-misses", low.goalIndex < 0) -- 112
	local wrong = createCore(dt) -- 113
	wrong.t0 = 1.8 -- 114
	local wrongStart = startAt(wrong.t0) -- 115
	coreLaunch( -- 116
		wrong, -- 116
		planTransfer( -- 116
			lv.planets[1].gm, -- 116
			radius, -- 116
			wrongStart.vel, -- 116
			power, -- 116
			tr.apoapsisMax -- 116
		).velocity, -- 116
		level, -- 116
		wrongStart.pos, -- 116
		wrongStart.vel -- 116
	) -- 116
	check("wrong-phase-flyby-misses", wrong.flyby ~= nil and wrong.flyby.completionIndex < 0) -- 117
	local collision = simulate( -- 118
		{ -- 118
			pos = bodyPositionAt(lv.planets[2], 0), -- 118
			vel = {x = 0, y = 0} -- 118
		}, -- 118
		lv.planets, -- 118
		{dt = dt, steps = 10, sampleEvery = 1, escapeRadius = 0} -- 118
	) -- 118
	check("moon-is-solid", collision.outcome == "crashed") -- 119
	check( -- 120
		"moon-is-not-target", -- 120
		findGoalIndex( -- 120
			collision.points, -- 120
			lv.planets, -- 120
			lv.goal, -- 120
			dt, -- 120
			0 -- 120
		) < 0 -- 120
	) -- 120
	check( -- 121
		"collision-cannot-complete", -- 121
		analyzeFlyby( -- 121
			collision, -- 121
			lv.planets[1], -- 121
			lv.planets[2], -- 121
			cfg, -- 121
			dt, -- 121
			0 -- 121
		).completionIndex < 0 -- 121
	) -- 121
	local collideCore = createCore(dt) -- 122
	coreLaunch( -- 123
		collideCore, -- 123
		{x = 0, y = 0}, -- 123
		level, -- 123
		bodyPositionAt(lv.planets[2], 0), -- 123
		{x = 0, y = 0} -- 123
	) -- 123
	coreUpdate(collideCore, 1, level) -- 124
	check("collision-fails-before-completion", collideCore.phase == "Result" and collideCore.result == "crashed" and not collideCore.missionCompleted) -- 125
	local afterCrash = createCore(dt) -- 126
	coreLaunch( -- 127
		afterCrash, -- 127
		{x = 0, y = 0}, -- 127
		level, -- 127
		bodyPositionAt(lv.planets[2], 0), -- 127
		{x = 0, y = 0} -- 127
	) -- 127
	afterCrash.missionCompleted = true -- 129
	afterCrash.result = "success" -- 129
	coreUpdate(afterCrash, 1, level) -- 130
	check("completion-survives-later-collision", afterCrash.phase == "Result" and afterCrash.result == "success") -- 131
	check( -- 132
		"launch-shot", -- 132
		transferShotAt( -- 132
			0, -- 132
			core.burnDuration, -- 132
			core.flyby, -- 132
			cfg, -- 132
			dt -- 132
		) == "Launch" -- 132
	) -- 132
	check( -- 133
		"cruise-shot", -- 133
		transferShotAt( -- 133
			4, -- 133
			core.burnDuration, -- 133
			core.flyby, -- 133
			cfg, -- 133
			dt -- 133
		) == "Cruise" -- 133
	) -- 133
	check( -- 134
		"moon-shot", -- 134
		transferShotAt( -- 134
			peri * dt, -- 134
			core.burnDuration, -- 134
			core.flyby, -- 134
			cfg, -- 134
			dt -- 134
		) == "Moon" -- 134
	) -- 134
	check( -- 135
		"overview-shot", -- 135
		transferShotAt( -- 135
			core.flyby.completionIndex * dt + 1, -- 135
			core.burnDuration, -- 135
			core.flyby, -- 135
			cfg, -- 135
			dt -- 135
		) == "Overview" -- 135
	) -- 135
	check( -- 136
		"return-shot", -- 136
		transferShotAt( -- 136
			core.flyby.completionIndex * dt + cfg.overviewDuration + 0.1, -- 136
			core.burnDuration, -- 136
			core.flyby, -- 136
			cfg, -- 136
			dt -- 136
		) == "Earth" -- 136
	) -- 136
	check( -- 137
		"camera-cycle", -- 137
		nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus("Auto"))))) == "Auto" -- 137
	) -- 137
	check( -- 138
		"burn-at-1x", -- 138
		transferPlaybackRate( -- 138
			0.1, -- 138
			core.burnDuration, -- 138
			tr, -- 138
			core.flyby, -- 138
			dt -- 138
		) == 1 -- 138
	) -- 138
	check( -- 139
		"coast-at-3x", -- 139
		transferPlaybackRate( -- 139
			4, -- 139
			core.burnDuration, -- 139
			tr, -- 139
			core.flyby, -- 139
			dt -- 139
		) == 3 -- 139
	) -- 139
	check( -- 140
		"periapsis-at-1x", -- 140
		transferPlaybackRate( -- 140
			peri * dt, -- 140
			core.burnDuration, -- 140
			tr, -- 140
			core.flyby, -- 140
			dt -- 140
		) == 1 -- 140
	) -- 140
	local at30 = 0 -- 141
	local at120 = 0 -- 141
	do -- 141
		local i = 0 -- 142
		while i < 360 do -- 142
			at30 = advanceTransferPlayback( -- 142
				at30, -- 142
				1 / 30, -- 142
				1, -- 142
				core.burnDuration, -- 142
				tr, -- 142
				core.flyby, -- 142
				dt -- 142
			) -- 142
			i = i + 1 -- 142
		end -- 142
	end -- 142
	do -- 142
		local i = 0 -- 143
		while i < 1440 do -- 143
			at120 = advanceTransferPlayback( -- 143
				at120, -- 143
				1 / 120, -- 143
				1, -- 143
				core.burnDuration, -- 143
				tr, -- 143
				core.flyby, -- 143
				dt -- 143
			) -- 143
			i = i + 1 -- 143
		end -- 143
	end -- 143
	check( -- 144
		"frame-rate-independent-playback", -- 144
		math.abs(at30 - at120) < 1e-9 -- 144
	) -- 144
	local score = evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}) -- 145
	check("no-phantom-stars", score.rockets == 1 and not score.achieved[2] and not score.achieved[3]) -- 146
	coreRetry(core, 0) -- 147
	check("retry-aiming", core.phase == "Aiming" and core.flight == nil and not core.missionCompleted and core.flyby == nil) -- 148
	check( -- 149
		"l2-configured", -- 149
		getLevel(1) ~= nil and getLevel(1).transfer.orbital ~= nil and #getLevel(1).stars == 0 -- 149
	) -- 149
	check( -- 150
		"l3-configured", -- 150
		getLevel(2) ~= nil and getLevel(2).transfer.orbital ~= nil and #getLevel(2).stars == 0 -- 150
	) -- 150
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 151
end -- 8
return ____exports -- 8
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
		"marker-idle-visible", -- 18
		successMarkerFrame(-1).visible and successMarkerFrame(-1).alpha == 1 -- 18
	) -- 18
	check( -- 19
		"marker-bright-pulse", -- 19
		successMarkerFrame(0.1).scale > 1.5 and successMarkerFrame(0.1).ring == 0 -- 19
	) -- 19
	check( -- 20
		"marker-expands-and-fades", -- 20
		successMarkerFrame(0.3).ring > 8 and successMarkerFrame(0.3).alpha < 1 -- 20
	) -- 20
	check( -- 21
		"marker-hidden-at-0.6", -- 21
		not successMarkerFrame(0.6).visible and successMarkerFrame(0.6).alpha == 0 -- 21
	) -- 21
	check( -- 22
		"marker-stays-hidden", -- 22
		not successMarkerFrame(10).visible -- 22
	) -- 22
	local radius = distance( -- 23
		lv.probeStart, -- 23
		bodyPositionAt(lv.planets[1], 0) -- 23
	) -- 23
	local date = 1 -- 24
	local power = 0.875 -- 24
	local function startAt(t) -- 25
		local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(lv.planets[1].gm / (radius * radius * radius)) * t -- 26
		local speed = math.sqrt(lv.planets[1].gm / radius) -- 27
		return { -- 28
			pos = { -- 28
				x = radius * math.cos(a), -- 28
				y = radius * math.sin(a) -- 28
			}, -- 28
			vel = { -- 28
				x = -math.sin(a) * speed, -- 28
				y = math.cos(a) * speed -- 28
			} -- 28
		} -- 28
	end -- 25
	local start = startAt(date) -- 30
	local plan = planTransfer( -- 31
		lv.planets[1].gm, -- 31
		radius, -- 31
		start.vel, -- 31
		power, -- 31
		tr.apoapsisMax -- 31
	) -- 31
	local level = { -- 32
		bodies = lv.planets, -- 32
		probeStart = lv.probeStart, -- 32
		probeVel0 = lv.probeVel0, -- 32
		goal = lv.goal, -- 32
		escapeRadius = lv.escapeRadius, -- 32
		maxSteps = lv.maxSteps, -- 32
		transfer = tr -- 32
	} -- 32
	local core = createCore(dt) -- 33
	core.t0 = date -- 34
	core.aim.velocity = plan.velocity -- 35
	coreLaunch( -- 36
		core, -- 36
		plan.velocity, -- 36
		level, -- 36
		start.pos, -- 36
		start.vel -- 36
	) -- 36
	core.playback = 1 -- 37
	check("earth-moon-only", #lv.planets == 2 and lv.planets[2].name == "月球") -- 38
	check( -- 39
		"low-orbit-height", -- 39
		math.abs(radius - lv.planets[1].radius - 90) < 1e-9 -- 39
	) -- 39
	check( -- 40
		"nearest-earth-at-low-orbit", -- 40
		selectIdleHost(lv.planets, lv.probeStart) == 0 -- 40
	) -- 40
	check( -- 41
		"explicit-earth-host", -- 41
		selectIdleHost(lv.planets, lv.probeStart, 0) == 0 -- 41
	) -- 41
	check("no-stars", lv.stars ~= nil and #lv.stars == 0) -- 42
	check("completion-only", lv.mission ~= nil and #lv.mission.challenges == 1) -- 43
	check( -- 44
		"prograde-only", -- 44
		math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-9 -- 44
	) -- 44
	check( -- 45
		"zero-burn", -- 45
		planTransfer( -- 45
			lv.planets[1].gm, -- 45
			radius, -- 45
			lv.probeVel0, -- 45
			0, -- 45
			tr.apoapsisMax -- 45
		).dv == 0 -- 45
	) -- 45
	check( -- 46
		"power-clamped", -- 46
		planTransfer( -- 46
			lv.planets[1].gm, -- 46
			radius, -- 46
			lv.probeVel0, -- 46
			2, -- 46
			tr.apoapsisMax -- 46
		).apoapsis == tr.apoapsisMax -- 46
	) -- 46
	check("burn-about-0.3s", core.burnDuration > 0.25 and core.burnDuration < 0.35) -- 47
	check("planned-safe-flyby", core.flyby ~= nil and core.goalIndex >= 0 and core.flyby.energyDrop >= cfg.minEnergyDrop) -- 48
	check("completion-not-visible-at-launch", not core.missionCompleted and core.result == nil) -- 49
	check( -- 50
		"cannot-end-before-completion", -- 50
		not coreEndViewing(core) -- 50
	) -- 50
	local actual = core.flight -- 51
	if actual == nil then -- 51
		return "failed\nmissing flight" -- 52
	end -- 52
	check( -- 53
		"no-instant-impulse", -- 53
		distance(actual.velocities[1], start.vel) < 1e-10 -- 53
	) -- 53
	local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 54
		dt = dt, -- 54
		steps = lv.maxSteps, -- 54
		sampleEvery = 1, -- 54
		escapeRadius = lv.escapeRadius, -- 54
		t0 = date -- 54
	}) -- 54
	local reference = analyzeFlyby( -- 55
		ref, -- 55
		lv.planets[1], -- 55
		lv.planets[2], -- 55
		cfg, -- 55
		dt, -- 55
		date -- 55
	) -- 55
	check("reference-safe-flyby", reference.completionIndex >= 0) -- 56
	local peri = core.flyby ~= nil and core.flyby.periapsisIndex or 0 -- 57
	local drift = distance(actual.points[peri + 1], ref.points[peri + 1]) -- 58
	check("small-nonzero-drift", drift > 0.01 and drift < 20) -- 59
	check( -- 60
		"periapsis-drift-tolerated", -- 60
		core.flyby ~= nil and math.abs(core.flyby.periapsis - reference.periapsis) < 5 -- 60
	) -- 60
	local accelerated = analyzeFlyby( -- 61
		actual, -- 61
		lv.planets[1], -- 61
		lv.planets[2], -- 61
		__TS__ObjectAssign({}, cfg, {minEnergyDrop = 1000}), -- 61
		dt, -- 61
		date -- 61
	) -- 61
	check("energy-drop-is-required", accelerated.completionIndex < 0) -- 62
	check( -- 63
		"close-pass-is-required", -- 63
		analyzeFlyby( -- 63
			actual, -- 63
			lv.planets[1], -- 63
			lv.planets[2], -- 63
			__TS__ObjectAssign({}, cfg, {maxPeriapsis = 45}), -- 63
			dt, -- 63
			date -- 63
		).completionIndex < 0 -- 63
	) -- 63
	check( -- 64
		"safety-margin-is-required", -- 64
		analyzeFlyby( -- 64
			actual, -- 64
			lv.planets[1], -- 64
			lv.planets[2], -- 64
			__TS__ObjectAssign({}, cfg, {minPeriapsis = 60}), -- 64
			dt, -- 64
			date -- 64
		).completionIndex < 0 -- 64
	) -- 64
	local timeout = analyzeFlyby( -- 65
		actual, -- 65
		lv.planets[1], -- 65
		lv.planets[2], -- 65
		__TS__ObjectAssign({}, cfg, {returnRadius = 1}), -- 65
		dt, -- 65
		date -- 65
	) -- 65
	check( -- 66
		"view-timeout-without-earth-return", -- 66
		timeout.completionIndex >= 0 and timeout.viewEndIndex == timeout.completionIndex + math.floor(cfg.maxViewingTime / dt) -- 66
	) -- 66
	local light = createCore(dt) -- 67
	light.t0 = date -- 68
	coreLaunch( -- 69
		light, -- 69
		plan.velocity, -- 69
		level, -- 69
		start.pos, -- 69
		start.vel -- 69
	) -- 69
	local lightIndex = findGoalIndex( -- 70
		actual.points, -- 70
		lv.planets, -- 70
		lv.goal, -- 70
		dt, -- 70
		date -- 70
	) -- 70
	light.flightTime = lightIndex * dt -- 71
	light.playback = 0 -- 72
	coreUpdate(light, 0, level) -- 73
	check("light-does-not-complete", lightIndex > 0 and lightIndex < core.goalIndex and light.phase == "Flying" and not light.missionCompleted) -- 74
	light.flightTime = core.goalIndex * dt -- 75
	coreUpdate(light, 0, level) -- 76
	check("flyby-completes-without-ending", light.missionCompleted and light.phase == "Flying" and light.result == "success") -- 77
	check( -- 78
		"manual-end-after-completion", -- 78
		coreEndViewing(light) and light.phase == "Result" and light.result == "success" -- 78
	) -- 78
	do -- 78
		local t = 0 -- 79
		while t < 80 do -- 79
			local moon = bodyPositionAt(lv.planets[2], t) -- 80
			local goal = goalPositionAt(lv.planets[2], t, lv.goal.offset) -- 81
			check( -- 82
				"safe-goal-" .. __TS__NumberToFixed(t, 0), -- 82
				distance(moon, goal) > lv.planets[2].radius + lv.goal.tolerance -- 82
			) -- 82
			t = t + 20 -- 79
		end -- 79
	end -- 79
	local opts = { -- 84
		dt = dt, -- 84
		steps = 100, -- 84
		sampleEvery = 1, -- 84
		escapeRadius = 0, -- 84
		initialBurn = {acceleration = {x = 10, y = 0}, duration = 0.301} -- 84
	} -- 84
	local fractional = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 85
	check( -- 86
		"fractional-last-burn-step", -- 86
		math.abs(fractional.state.vel.x - 3.01) < 1e-10 -- 86
	) -- 86
	local twice = simulate({pos = {x = 0, y = 0}, vel = {x = 0, y = 0}}, {}, opts) -- 87
	check("burn-deterministic", fractional.state.pos.x == twice.state.pos.x and fractional.state.vel.x == twice.state.vel.x) -- 88
	local pausedAt = core.flightTime -- 89
	core.playback = 0 -- 90
	do -- 90
		local i = 0 -- 91
		while i < 50 do -- 91
			coreUpdate(core, 1 / 60, level) -- 91
			i = i + 1 -- 91
		end -- 91
	end -- 91
	check("pause-freezes-burn", core.flightTime == pausedAt) -- 92
	core.playback = 1 -- 93
	local wall = 0 -- 94
	while core.phase == "Flying" and wall < 40 do -- 94
		coreUpdate(core, 1 / 60, level) -- 95
		wall = wall + 1 / 60 -- 95
	end -- 95
	check("12-to-18s-playback", wall >= 12 and wall <= 18) -- 96
	check("return-clamped", core.phase == "Result" and core.missionCompleted and core.flyby ~= nil and core.flightTime == core.flyby.viewEndIndex * dt and core.flightTime > core.goalIndex * dt) -- 97
	check( -- 98
		"return-near-earth", -- 98
		distance( -- 98
			actual.points[math.floor(core.flightTime / dt) + 1], -- 98
			bodyPositionAt(lv.planets[1], date + core.flightTime) -- 98
		) <= cfg.returnRadius -- 98
	) -- 98
	local fast = createCore(dt) -- 99
	fast.t0 = date -- 100
	coreLaunch( -- 101
		fast, -- 101
		plan.velocity, -- 101
		level, -- 101
		start.pos, -- 101
		start.vel -- 101
	) -- 101
	fast.playback = 4 -- 102
	do -- 102
		local i = 0 -- 103
		while i < 1000 and fast.phase == "Flying" do -- 103
			coreUpdate(fast, 1 / 120, level) -- 103
			i = i + 1 -- 103
		end -- 103
	end -- 103
	check( -- 104
		"speed-does-not-change-result", -- 104
		fast.result == core.result and fast.flightTime == core.flightTime and fast.flight ~= nil and distance(fast.flight.points[fast.goalIndex + 1], actual.points[core.goalIndex + 1]) == 0 -- 104
	) -- 104
	local low = createCore(dt) -- 105
	low.t0 = date -- 106
	coreLaunch( -- 107
		low, -- 107
		planTransfer( -- 107
			lv.planets[1].gm, -- 107
			radius, -- 107
			start.vel, -- 107
			0.05, -- 107
			tr.apoapsisMax -- 107
		).velocity, -- 107
		level, -- 107
		start.pos, -- 107
		start.vel -- 107
	) -- 107
	check("low-power-misses", low.goalIndex < 0) -- 108
	local wrong = createCore(dt) -- 109
	wrong.t0 = 1.8 -- 110
	local wrongStart = startAt(wrong.t0) -- 111
	coreLaunch( -- 112
		wrong, -- 112
		planTransfer( -- 112
			lv.planets[1].gm, -- 112
			radius, -- 112
			wrongStart.vel, -- 112
			power, -- 112
			tr.apoapsisMax -- 112
		).velocity, -- 112
		level, -- 112
		wrongStart.pos, -- 112
		wrongStart.vel -- 112
	) -- 112
	check("wrong-phase-misses", wrong.goalIndex < 0) -- 113
	local collision = simulate( -- 114
		{ -- 114
			pos = bodyPositionAt(lv.planets[2], 0), -- 114
			vel = {x = 0, y = 0} -- 114
		}, -- 114
		lv.planets, -- 114
		{dt = dt, steps = 10, sampleEvery = 1, escapeRadius = 0} -- 114
	) -- 114
	check("moon-is-solid", collision.outcome == "crashed") -- 115
	check( -- 116
		"moon-is-not-target", -- 116
		findGoalIndex( -- 116
			collision.points, -- 116
			lv.planets, -- 116
			lv.goal, -- 116
			dt, -- 116
			0 -- 116
		) < 0 -- 116
	) -- 116
	check( -- 117
		"collision-cannot-complete", -- 117
		analyzeFlyby( -- 117
			collision, -- 117
			lv.planets[1], -- 117
			lv.planets[2], -- 117
			cfg, -- 117
			dt, -- 117
			0 -- 117
		).completionIndex < 0 -- 117
	) -- 117
	local collideCore = createCore(dt) -- 118
	coreLaunch( -- 119
		collideCore, -- 119
		{x = 0, y = 0}, -- 119
		level, -- 119
		bodyPositionAt(lv.planets[2], 0), -- 119
		{x = 0, y = 0} -- 119
	) -- 119
	coreUpdate(collideCore, 1, level) -- 120
	check("collision-fails-before-completion", collideCore.phase == "Result" and collideCore.result == "crashed" and not collideCore.missionCompleted) -- 121
	local afterCrash = createCore(dt) -- 122
	coreLaunch( -- 123
		afterCrash, -- 123
		{x = 0, y = 0}, -- 123
		level, -- 123
		bodyPositionAt(lv.planets[2], 0), -- 123
		{x = 0, y = 0} -- 123
	) -- 123
	afterCrash.missionCompleted = true -- 125
	afterCrash.result = "success" -- 125
	coreUpdate(afterCrash, 1, level) -- 126
	check("completion-survives-later-collision", afterCrash.phase == "Result" and afterCrash.result == "success") -- 127
	check( -- 128
		"launch-shot", -- 128
		transferShotAt( -- 128
			0, -- 128
			core.burnDuration, -- 128
			core.flyby, -- 128
			cfg, -- 128
			dt -- 128
		) == "Launch" -- 128
	) -- 128
	check( -- 129
		"cruise-shot", -- 129
		transferShotAt( -- 129
			4, -- 129
			core.burnDuration, -- 129
			core.flyby, -- 129
			cfg, -- 129
			dt -- 129
		) == "Cruise" -- 129
	) -- 129
	check( -- 130
		"moon-shot", -- 130
		transferShotAt( -- 130
			peri * dt, -- 130
			core.burnDuration, -- 130
			core.flyby, -- 130
			cfg, -- 130
			dt -- 130
		) == "Moon" -- 130
	) -- 130
	check( -- 131
		"overview-shot", -- 131
		transferShotAt( -- 131
			core.goalIndex * dt + 1, -- 131
			core.burnDuration, -- 131
			core.flyby, -- 131
			cfg, -- 131
			dt -- 131
		) == "Overview" -- 131
	) -- 131
	check( -- 132
		"return-shot", -- 132
		transferShotAt( -- 132
			core.goalIndex * dt + cfg.overviewDuration + 0.1, -- 132
			core.burnDuration, -- 132
			core.flyby, -- 132
			cfg, -- 132
			dt -- 132
		) == "Earth" -- 132
	) -- 132
	check( -- 133
		"camera-cycle", -- 133
		nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus(nextCameraFocus("Auto"))))) == "Auto" -- 133
	) -- 133
	check( -- 134
		"burn-at-1x", -- 134
		transferPlaybackRate( -- 134
			0.1, -- 134
			core.burnDuration, -- 134
			tr, -- 134
			core.flyby, -- 134
			dt -- 134
		) == 1 -- 134
	) -- 134
	check( -- 135
		"coast-at-3x", -- 135
		transferPlaybackRate( -- 135
			4, -- 135
			core.burnDuration, -- 135
			tr, -- 135
			core.flyby, -- 135
			dt -- 135
		) == 3 -- 135
	) -- 135
	check( -- 136
		"periapsis-at-1x", -- 136
		transferPlaybackRate( -- 136
			peri * dt, -- 136
			core.burnDuration, -- 136
			tr, -- 136
			core.flyby, -- 136
			dt -- 136
		) == 1 -- 136
	) -- 136
	local at30 = 0 -- 137
	local at120 = 0 -- 137
	do -- 137
		local i = 0 -- 138
		while i < 360 do -- 138
			at30 = advanceTransferPlayback( -- 138
				at30, -- 138
				1 / 30, -- 138
				1, -- 138
				core.burnDuration, -- 138
				tr, -- 138
				core.flyby, -- 138
				dt -- 138
			) -- 138
			i = i + 1 -- 138
		end -- 138
	end -- 138
	do -- 138
		local i = 0 -- 139
		while i < 1440 do -- 139
			at120 = advanceTransferPlayback( -- 139
				at120, -- 139
				1 / 120, -- 139
				1, -- 139
				core.burnDuration, -- 139
				tr, -- 139
				core.flyby, -- 139
				dt -- 139
			) -- 139
			i = i + 1 -- 139
		end -- 139
	end -- 139
	check( -- 140
		"frame-rate-independent-playback", -- 140
		math.abs(at30 - at120) < 1e-9 -- 140
	) -- 140
	local score = evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}) -- 141
	check("no-phantom-stars", score.rockets == 1 and not score.achieved[2] and not score.achieved[3]) -- 142
	coreRetry(core, 0) -- 143
	check("retry-aiming", core.phase == "Aiming" and core.flight == nil and not core.missionCompleted and core.flyby == nil) -- 144
	check( -- 145
		"l2-configured", -- 145
		getLevel(1) ~= nil and getLevel(1).transfer.orbital ~= nil and #getLevel(1).stars == 0 -- 145
	) -- 145
	check( -- 146
		"l3-configured", -- 146
		getLevel(2) ~= nil and getLevel(2).transfer.orbital ~= nil and #getLevel(2).stars == 0 -- 146
	) -- 146
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 147
end -- 8
return ____exports -- 8
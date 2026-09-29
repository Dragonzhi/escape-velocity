-- [ts]: OrbitalTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ArrayMap = ____lualib.__TS__ArrayMap -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
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
local analyzeOrbitalMission = ____Transfer.analyzeOrbitalMission -- 5
local advanceTransferPlayback = ____Transfer.advanceTransferPlayback -- 5
local orbitalShotAt = ____Transfer.orbitalShotAt -- 5
local planTransfer = ____Transfer.planTransfer -- 5
local ____LevelLoader = require("game.LevelLoader") -- 6
local convertLevelJson = ____LevelLoader.convertLevelJson -- 6
local ____Game = require("game.Game") -- 7
local createCore = ____Game.createCore -- 7
local coreLaunch = ____Game.coreLaunch -- 7
local coreUpdate = ____Game.coreUpdate -- 7
local coreEndViewing = ____Game.coreEndViewing -- 7
local coreRetry = ____Game.coreRetry -- 7
local ____Scene = require("game.Scene") -- 8
local isSunVisual = ____Scene.isSunVisual -- 8
function ____exports.runTests() -- 10
	local checks = 0 -- 11
	local failures = {} -- 12
	local function check(name, ok) -- 13
		checks = checks + 1 -- 13
		if not ok then -- 13
			failures[#failures + 1] = name -- 13
		end -- 13
	end -- 13
	installArcadeLevels( -- 14
		Content:load("Assets/Levels/levels.json"), -- 14
		Content:load("Assets/Levels/bodies.json"), -- 14
		function(s) return (json.decode(s)) end -- 14
	) -- 14
	local dt = 0.016 -- 15
	local ____table = (json.decode(Content:load("Assets/Levels/bodies.json"))) -- 16
	local configs = (json.decode(Content:load("Assets/Levels/levels.json"))) -- 17
	local baseSunRadius = ____table.bodies.sun.radius -- 18
	local baseVenusRadius = ____table.bodies.venus.radius -- 18
	local l2 = convertLevelJson(configs.levels[2], ____table) -- 19
	check("l2-body-overrides", l2.planets[1].radius == 72 and l2.planets[2].radius == 12 and l2.planets[3].radius == 6 and l2.planets[3].gm == 800) -- 20
	check( -- 21
		"l2-model-collision-size", -- 21
		__TS__ArrayEvery( -- 21
			l2.visuals, -- 21
			function(____, v, i) return v.displayRadius == l2.planets[i + 1].radius end -- 21
		) -- 21
	) -- 21
	check( -- 22
		"shared-prototypes-unchanged", -- 22
		____table.bodies.sun.radius == baseSunRadius and ____table.bodies.venus.radius == baseVenusRadius and getLevel(2).planets[1].radius == 72 -- 22
	) -- 22
	check( -- 23
		"exclusive-terminal-config", -- 23
		convertLevelJson( -- 23
			__TS__ObjectAssign( -- 23
				{}, -- 23
				configs.levels[2], -- 23
				{transfer = __TS__ObjectAssign( -- 23
					{}, -- 23
					configs.levels[2].transfer, -- 23
					{orbital = __TS__ObjectAssign({}, configs.levels[2].transfer.orbital, {region = {minRadius = 150, maxRadius = 170, direction = "inward"}})} -- 23
				)} -- 23
			), -- 23
			____table -- 23
		) == nil -- 23
	) -- 23
	local missingTerminal = __TS__ObjectAssign({}, configs.levels[3].transfer.orbital) -- 24
	missingTerminal.region = nil -- 24
	check( -- 25
		"missing-terminal-config", -- 25
		convertLevelJson( -- 25
			__TS__ObjectAssign( -- 25
				{}, -- 25
				configs.levels[3], -- 25
				{transfer = __TS__ObjectAssign({}, configs.levels[3].transfer, {orbital = missingTerminal})} -- 25
			), -- 25
			____table -- 25
		) == nil -- 25
	) -- 25
	check( -- 26
		"invalid-destination-index", -- 26
		convertLevelJson( -- 26
			__TS__ObjectAssign( -- 26
				{}, -- 26
				configs.levels[2], -- 26
				{transfer = __TS__ObjectAssign( -- 26
					{}, -- 26
					configs.levels[2].transfer, -- 26
					{orbital = __TS__ObjectAssign( -- 26
						{}, -- 26
						configs.levels[2].transfer.orbital, -- 26
						{targetFlyby = __TS__ObjectAssign({}, configs.levels[2].transfer.orbital.targetFlyby, {planetIndex = 9})} -- 26
					)} -- 26
				)} -- 26
			), -- 26
			____table -- 26
		) == nil -- 26
	) -- 26
	check( -- 28
		"explicit-sun-model", -- 28
		isSunVisual({ -- 28
			r = 1, -- 28
			g = 1, -- 28
			b = 1, -- 28
			displayRadius = 50, -- 28
			ring = false, -- 28
			model = "Sun" -- 28
		}) -- 28
	) -- 28
	check( -- 29
		"massive-earth-not-sun", -- 29
		not isSunVisual({ -- 29
			r = 1, -- 29
			g = 1, -- 29
			b = 1, -- 29
			displayRadius = 42, -- 29
			ring = false, -- 29
			model = "Planet_Earth" -- 29
		}) -- 29
	) -- 29
	check( -- 30
		"undefined-not-sun", -- 30
		not isSunVisual(nil) -- 30
	) -- 30
	do -- 30
		local n = 1 -- 31
		while n <= 2 do -- 31
			local lv = getLevel(n) -- 32
			if lv.transfer == nil or lv.transfer.orbital == nil then -- 32
				return "failed\nmissing orbital fixture" -- 33
			end -- 33
			local tr = lv.transfer -- 34
			local cfg = lv.transfer.orbital -- 34
			local mu = lv.planets[1].gm -- 34
			local r = distance( -- 35
				lv.probeStart, -- 35
				bodyPositionAt(lv.planets[1], 0) -- 35
			) -- 35
			local power = n == 1 and 11 / 14 or 0.5 -- 36
			local function stateAt(date) -- 37
				local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(mu / (r * r * r)) * date -- 38
				local speed = math.sqrt(mu / r) -- 38
				return { -- 39
					pos = { -- 39
						x = r * math.cos(a), -- 39
						y = r * math.sin(a) -- 39
					}, -- 39
					vel = { -- 39
						x = -math.sin(a) * speed, -- 39
						y = math.cos(a) * speed -- 39
					} -- 39
				} -- 39
			end -- 37
			local level = { -- 41
				levelId = n + 1, -- 41
				viewingSeconds = n == 1 and 12 or 6, -- 41
				bonusPoints = lv.bonusPoints, -- 41
				bodies = lv.planets, -- 41
				probeStart = lv.probeStart, -- 41
				probeVel0 = lv.probeVel0, -- 41
				goal = lv.goal, -- 41
				escapeRadius = lv.escapeRadius, -- 41
				maxSteps = lv.maxSteps, -- 41
				transfer = tr -- 41
			} -- 41
			local function launchAt(date, p) -- 42
				local core = createCore(dt) -- 43
				local start = stateAt(date) -- 43
				local plan = planTransfer( -- 44
					mu, -- 44
					r, -- 44
					start.vel, -- 44
					p, -- 44
					tr.apoapsisMax, -- 44
					tr.mode, -- 44
					tr.periapsisMin -- 44
				) -- 44
				core.t0 = date -- 45
				coreLaunch( -- 45
					core, -- 45
					plan.velocity, -- 45
					level, -- 45
					start.pos, -- 45
					start.vel -- 45
				) -- 45
				core.playback = 1 -- 45
				return core -- 46
			end -- 42
			local core = launchAt(1, power) -- 48
			local flight = core.flight -- 48
			local analysis = core.flyby -- 48
			local prefix = ("L" .. __TS__NumberToFixed(n + 1, 0)) .. "-" -- 49
			check(prefix .. "sun-center", mu == 800000 and lv.planets[1].radius == 72 and lv.planets[1].orbitRadius == 0) -- 50
			check( -- 51
				prefix .. "only-real-bodies", -- 51
				#lv.planets == 3 and #lv.stars == 0 and __TS__ArrayEvery( -- 51
					lv.planets, -- 51
					function(____, b) return b.gm > 0 and not b.isObstacle end -- 51
				) -- 51
			) -- 51
			if n == 1 then -- 51
				local body = lv.planets[3] -- 53
				local point = goalPositionAt(body, 1, lv.goal.offset) -- 53
				check( -- 54
					prefix .. "mercury-guidance", -- 54
					lv.goal.marker == nil and lv.goal.planetIndex == 2 and lv.goal.tolerance == 6 and math.abs(distance( -- 54
						point, -- 54
						bodyPositionAt(body, 1) -- 54
					) - 14) < 1e-8 -- 54
				) -- 54
				check( -- 55
					prefix .. "marker-safe-gap", -- 55
					distance( -- 55
						point, -- 55
						bodyPositionAt(body, 1) -- 55
					) - lv.goal.tolerance > body.radius -- 55
				) -- 55
			else -- 55
				check( -- 57
					prefix .. "marker-independent", -- 57
					lv.goal.marker ~= nil and lv.goal.marker.gm == 0 and __TS__ArrayIndexOf(lv.planets, lv.goal.marker) < 0 -- 57
				) -- 57
				check( -- 58
					prefix .. "marker-guidance-only", -- 58
					findGoalIndex( -- 58
						{bodyPositionAt(lv.goal.marker, 0)}, -- 58
						lv.planets, -- 58
						lv.goal, -- 58
						dt -- 58
					) < 0 -- 58
				) -- 58
			end -- 58
			check(prefix .. "sun-emissive", lv.visuals[1].emissive ~= nil and lv.visuals[1].emissive.r == 1) -- 60
			check( -- 61
				prefix .. "baseline-success", -- 61
				core.goalIndex > 0 and __TS__ArrayEvery( -- 61
					analysis.encounters, -- 61
					function(____, e) return e.passed end -- 61
				) -- 61
			) -- 61
			check(prefix .. "short-burn", core.burnDuration > 0.29 and core.burnDuration < 0.31) -- 62
			check( -- 63
				prefix .. "not-precompleted", -- 63
				not core.missionCompleted and not coreEndViewing(core) -- 63
			) -- 63
			local start = stateAt(1) -- 64
			local plan = planTransfer( -- 64
				mu, -- 64
				r, -- 64
				start.vel, -- 64
				power, -- 64
				tr.apoapsisMax, -- 64
				tr.mode, -- 64
				tr.periapsisMin -- 64
			) -- 64
			check( -- 65
				prefix .. "drag-radius", -- 65
				math.abs(plan.apoapsis - (n == 1 and 180 or 420)) < 1e-8 -- 65
			) -- 65
			check( -- 66
				prefix .. "system-tangent", -- 66
				math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-8 and (plan.velocity.x * start.vel.x + plan.velocity.y * start.vel.y) * (n == 1 and -1 or 1) > 0 -- 66
			) -- 66
			check( -- 67
				prefix .. "finite-burn", -- 67
				distance(flight.velocities[1], start.vel) < 1e-10 -- 67
			) -- 67
			local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 68
				dt = dt, -- 68
				steps = 3600, -- 68
				sampleEvery = 1, -- 68
				escapeRadius = lv.escapeRadius, -- 68
				t0 = 1 -- 68
			}) -- 68
			check( -- 69
				prefix .. "instant-plan-success", -- 69
				analyzeOrbitalMission( -- 69
					ref, -- 69
					lv.planets, -- 69
					cfg, -- 69
					dt, -- 69
					1 -- 69
				).completionIndex > 0 -- 69
			) -- 69
			for ____, e in ipairs(analysis.encounters) do -- 70
				check( -- 70
					(prefix .. "small-drift-") .. __TS__NumberToFixed(e.planetIndex, 0), -- 70
					distance(flight.points[e.periapsisIndex + 1], ref.points[e.periapsisIndex + 1]) < 5 -- 70
				) -- 70
			end -- 70
			check( -- 71
				prefix .. "work-required", -- 71
				analyzeOrbitalMission( -- 71
					flight, -- 71
					lv.planets, -- 71
					__TS__ObjectAssign( -- 71
						{}, -- 71
						cfg, -- 71
						{encounters = __TS__ArrayMap( -- 71
							cfg.encounters, -- 71
							function(____, e) return __TS__ObjectAssign({}, e, {minWork = 1000000000}) end -- 71
						)} -- 71
					), -- 71
					dt, -- 71
					1 -- 71
				).completionIndex < 0 -- 71
			) -- 71
			check( -- 72
				prefix .. "missing-assist-fails", -- 72
				analyzeOrbitalMission( -- 72
					flight, -- 72
					__TS__ArrayMap( -- 72
						lv.planets, -- 72
						function(____, b, i) return i == 1 and __TS__ObjectAssign({}, b, {gm = 0}) or b end -- 72
					), -- 72
					cfg, -- 72
					dt, -- 72
					1 -- 72
				).completionIndex < 0 -- 72
			) -- 72
			check( -- 73
				prefix .. "energy-required", -- 73
				analyzeOrbitalMission( -- 73
					flight, -- 73
					lv.planets, -- 73
					__TS__ObjectAssign( -- 73
						{}, -- 73
						cfg, -- 73
						{encounters = __TS__ArrayMap( -- 73
							cfg.encounters, -- 73
							function(____, e) return __TS__ObjectAssign({}, e, {minEnergyChange = 1000000000}) end -- 73
						)} -- 73
					), -- 73
					dt, -- 73
					1 -- 73
				).completionIndex < 0 -- 73
			) -- 73
			check( -- 74
				prefix .. "safe-distance-required", -- 74
				analyzeOrbitalMission( -- 74
					flight, -- 74
					lv.planets, -- 74
					__TS__ObjectAssign( -- 74
						{}, -- 74
						cfg, -- 74
						{encounters = __TS__ArrayMap( -- 74
							cfg.encounters, -- 74
							function(____, e) return __TS__ObjectAssign({}, e, {minPeriapsis = 105}) end -- 74
						)} -- 74
					), -- 74
					dt, -- 74
					1 -- 74
				).completionIndex < 0 -- 74
			) -- 74
			if cfg.targetFlyby ~= nil then -- 74
				local dest = analysis.destination -- 76
				check(prefix .. "complete-mercury-flyby", dest.passed and dest.entryIndex > analysis.encounters[1].exitIndex and dest.periapsisIndex > dest.entryIndex and dest.exitIndex > dest.periapsisIndex and core.goalIndex >= dest.entryIndex and core.goalIndex < dest.exitIndex and dest.periapsis >= 12 and dest.periapsis <= 28) -- 77
				check( -- 78
					prefix .. "mercury-small-planning-drift", -- 78
					distance(flight.points[dest.periapsisIndex + 1], ref.points[dest.periapsisIndex + 1]) < 5 -- 78
				) -- 78
				local truncated = __TS__ObjectAssign( -- 79
					{}, -- 79
					flight, -- 79
					{ -- 79
						points = __TS__ArraySlice(flight.points, 0, dest.exitIndex), -- 79
						velocities = __TS__ArraySlice(flight.velocities, 0, dest.exitIndex) -- 79
					} -- 79
				) -- 79
				check( -- 80
					prefix .. "entry-peri-without-exit-fails", -- 80
					analyzeOrbitalMission( -- 80
						truncated, -- 80
						lv.planets, -- 80
						cfg, -- 80
						dt, -- 80
						1 -- 80
					).completionIndex < 0 -- 80
				) -- 80
				check( -- 81
					prefix .. "unsafe-mercury-fails", -- 81
					analyzeOrbitalMission( -- 81
						flight, -- 81
						lv.planets, -- 81
						__TS__ObjectAssign( -- 81
							{}, -- 81
							cfg, -- 81
							{targetFlyby = __TS__ObjectAssign({}, cfg.targetFlyby, {minPeriapsis = 25})} -- 81
						), -- 81
						dt, -- 81
						1 -- 81
					).completionIndex < 0 -- 81
				) -- 81
				check( -- 82
					prefix .. "missed-mercury-fails", -- 82
					analyzeOrbitalMission( -- 82
						flight, -- 82
						lv.planets, -- 82
						__TS__ObjectAssign( -- 82
							{}, -- 82
							cfg, -- 82
							{targetFlyby = __TS__ObjectAssign({}, cfg.targetFlyby, {maxPeriapsis = 12})} -- 82
						), -- 82
						dt, -- 82
						1 -- 82
					).completionIndex < 0 -- 82
				) -- 82
				local missed = launchAt(1, 0.9) -- 83
				local oldBand = __TS__ObjectAssign({}, cfg) -- 84
				oldBand.targetFlyby = nil -- 84
				oldBand.region = {minRadius = 150, maxRadius = 170, direction = "inward"} -- 84
				check( -- 85
					prefix .. "old-band-alone-insufficient", -- 85
					missed.goalIndex < 0 and analyzeOrbitalMission( -- 85
						missed.flight, -- 85
						lv.planets, -- 85
						oldBand, -- 85
						dt, -- 85
						1 -- 85
					).completionIndex >= 0 -- 85
				) -- 85
				check( -- 86
					prefix .. "mercury-camera", -- 86
					orbitalShotAt( -- 86
						dest.periapsisIndex * dt, -- 86
						core.burnDuration, -- 86
						analysis, -- 86
						cfg, -- 86
						dt -- 86
					) == "Mercury" -- 86
				) -- 86
				check( -- 87
					prefix .. "between-planets-cruise", -- 87
					orbitalShotAt( -- 87
						(analysis.encounters[1].exitIndex + 1) * dt, -- 87
						core.burnDuration, -- 87
						analysis, -- 87
						cfg, -- 87
						dt -- 87
					) == "Cruise" -- 87
				) -- 87
			else -- 87
				local reverse = analyzeOrbitalMission( -- 89
					flight, -- 89
					lv.planets, -- 89
					__TS__ObjectAssign( -- 89
						{}, -- 89
						cfg, -- 89
						{region = __TS__ObjectAssign({}, cfg.region, {direction = "inward"})} -- 89
					), -- 89
					dt, -- 89
					1 -- 89
				) -- 89
				check(prefix .. "target-direction-required", reverse.completionIndex < 0) -- 90
				check( -- 91
					prefix .. "order-required", -- 91
					analyzeOrbitalMission( -- 91
						flight, -- 91
						lv.planets, -- 91
						__TS__ObjectAssign({}, cfg, {encounters = {cfg.encounters[2], cfg.encounters[1]}}), -- 91
						dt, -- 91
						1 -- 91
					).completionIndex < 0 -- 91
				) -- 91
			end -- 91
			local lowPower = launchAt(1, 0.04) -- 93
			local ____temp_1 = prefix .. (n == 1 and "low-power-fails" or "low-power-escape-allowed") -- 94
			local ____temp_0 -- 94
			if n == 1 then -- 94
				____temp_0 = lowPower.goalIndex < 0 -- 94
			else -- 94
				____temp_0 = lowPower.goalIndex >= 0 -- 94
			end -- 94
			check(____temp_1, ____temp_0) -- 94
			check( -- 95
				prefix .. "wrong-date-fails", -- 95
				launchAt(10, power).goalIndex < 0 -- 95
			) -- 95
			core.playback = 0 -- 96
			core.flightTime = (core.goalIndex - 1) * dt -- 96
			coreUpdate(core, 0, level) -- 96
			check(prefix .. "before-region-incomplete", not core.missionCompleted) -- 97
			core.flightTime = core.goalIndex * dt -- 98
			coreUpdate(core, 0, level) -- 98
			check(prefix .. "actual-region-completes", core.missionCompleted and core.phase == "Flying" and core.result == "success") -- 99
			check( -- 100
				prefix .. "manual-end", -- 100
				coreEndViewing(core) and core.phase == "Result" -- 100
			) -- 100
			local normal = launchAt(1, power) -- 101
			local fast = launchAt(1, power) -- 101
			fast.playback = 4 -- 102
			do -- 102
				local i = 0 -- 103
				while i < 2500 and normal.phase == "Flying" do -- 103
					coreUpdate(normal, 1 / 60, level) -- 103
					i = i + 1 -- 103
				end -- 103
			end -- 103
			do -- 103
				local i = 0 -- 104
				while i < 2500 and fast.phase == "Flying" do -- 104
					coreUpdate(fast, 1 / 120, level) -- 104
					i = i + 1 -- 104
				end -- 104
			end -- 104
			check(prefix .. "natural-end-success", normal.phase == "Result" and normal.missionCompleted and normal.result == "success") -- 105
			check( -- 106
				prefix .. "speed-deterministic", -- 106
				fast.result == normal.result and fast.flightTime == normal.flightTime and distance(fast.flight.state.pos, normal.flight.state.pos) == 0 -- 106
			) -- 106
			check( -- 107
				prefix .. "viewing-bounded", -- 107
				normal.flightTime > core.goalIndex * dt and normal.flightTime <= (core.goalIndex + math.floor(level.viewingSeconds / dt)) * dt -- 107
			) -- 107
			local at30 = 0 -- 108
			local at120 = 0 -- 108
			do -- 108
				local i = 0 -- 109
				while i < 450 do -- 109
					at30 = advanceTransferPlayback( -- 109
						at30, -- 109
						1 / 30, -- 109
						1, -- 109
						normal.burnDuration, -- 109
						tr, -- 109
						analysis, -- 109
						dt -- 109
					) -- 109
					i = i + 1 -- 109
				end -- 109
			end -- 109
			do -- 109
				local i = 0 -- 110
				while i < 1800 do -- 110
					at120 = advanceTransferPlayback( -- 110
						at120, -- 110
						1 / 120, -- 110
						1, -- 110
						normal.burnDuration, -- 110
						tr, -- 110
						analysis, -- 110
						dt -- 110
					) -- 110
					i = i + 1 -- 110
				end -- 110
			end -- 110
			check( -- 111
				prefix .. "fps-independent", -- 111
				math.abs(at30 - at120) < 1e-8 -- 111
			) -- 111
			do -- 111
				local i = 0 -- 112
				while i < #analysis.encounters do -- 112
					check( -- 112
						(prefix .. "encounter-shot-") .. __TS__NumberToFixed(i, 0), -- 112
						orbitalShotAt( -- 112
							analysis.encounters[i + 1].periapsisIndex * dt, -- 112
							normal.burnDuration, -- 112
							analysis, -- 112
							cfg, -- 112
							dt -- 112
						) == cfg.encounters[i + 1].focus -- 112
					) -- 112
					i = i + 1 -- 112
				end -- 112
			end -- 112
			check( -- 113
				prefix .. "one-completion-record", -- 113
				evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}).rockets == 1 -- 113
			) -- 113
			do -- 113
				local i = 0 -- 114
				while i < #lv.planets do -- 114
					local crash = createCore(dt) -- 115
					coreLaunch( -- 115
						crash, -- 115
						{x = 0, y = 0}, -- 115
						level, -- 115
						bodyPositionAt(lv.planets[i + 1], 0), -- 115
						{x = 0, y = 0} -- 115
					) -- 115
					coreUpdate(crash, 1, level) -- 115
					check( -- 116
						(prefix .. "early-collision-fails-") .. __TS__NumberToFixed(i, 0), -- 116
						crash.result == "crashed" and not crash.missionCompleted -- 116
					) -- 116
					i = i + 1 -- 114
				end -- 114
			end -- 114
			coreRetry(core, 0) -- 118
			check(prefix .. "retry-reset", not core.missionCompleted and core.flyby == nil and core.phase == "Aiming") -- 118
			n = n + 1 -- 31
		end -- 31
	end -- 31
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 120
end -- 10
return ____exports -- 10
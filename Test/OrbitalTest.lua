-- [ts]: OrbitalTest.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__ArrayEvery = ____lualib.__TS__ArrayEvery -- 1
local __TS__ArrayIndexOf = ____lualib.__TS__ArrayIndexOf -- 1
local __TS__ObjectAssign = ____lualib.__TS__ObjectAssign -- 1
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
local installArcadeLevels = ____LevelData.installArcadeLevels -- 4
local findGoalIndex = ____LevelData.findGoalIndex -- 4
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 4
local ____Transfer = require("game.Transfer") -- 5
local analyzeOrbitalMission = ____Transfer.analyzeOrbitalMission -- 5
local advanceTransferPlayback = ____Transfer.advanceTransferPlayback -- 5
local orbitalShotAt = ____Transfer.orbitalShotAt -- 5
local planTransfer = ____Transfer.planTransfer -- 5
local ____Game = require("game.Game") -- 6
local createCore = ____Game.createCore -- 6
local coreLaunch = ____Game.coreLaunch -- 6
local coreUpdate = ____Game.coreUpdate -- 6
local coreEndViewing = ____Game.coreEndViewing -- 6
local coreRetry = ____Game.coreRetry -- 6
local ____Scene = require("game.Scene") -- 7
local isSunVisual = ____Scene.isSunVisual -- 7
function ____exports.runTests() -- 9
	local checks = 0 -- 10
	local failures = {} -- 11
	local function check(name, ok) -- 12
		checks = checks + 1 -- 12
		if not ok then -- 12
			failures[#failures + 1] = name -- 12
		end -- 12
	end -- 12
	installArcadeLevels( -- 13
		Content:load("Assets/Levels/levels.json"), -- 13
		Content:load("Assets/Levels/bodies.json"), -- 13
		function(s) return (json.decode(s)) end -- 13
	) -- 13
	local dt = 0.016 -- 14
	check( -- 15
		"explicit-sun-model", -- 15
		isSunVisual({ -- 15
			r = 1, -- 15
			g = 1, -- 15
			b = 1, -- 15
			displayRadius = 50, -- 15
			ring = false, -- 15
			model = "Sun" -- 15
		}) -- 15
	) -- 15
	check( -- 16
		"massive-earth-not-sun", -- 16
		not isSunVisual({ -- 16
			r = 1, -- 16
			g = 1, -- 16
			b = 1, -- 16
			displayRadius = 42, -- 16
			ring = false, -- 16
			model = "Planet_Earth" -- 16
		}) -- 16
	) -- 16
	check( -- 17
		"undefined-not-sun", -- 17
		not isSunVisual(nil) -- 17
	) -- 17
	do -- 17
		local n = 1 -- 18
		while n <= 2 do -- 18
			local lv = getLevel(n) -- 19
			if lv.transfer == nil or lv.transfer.orbital == nil then -- 19
				return "failed\nmissing orbital fixture" -- 20
			end -- 20
			local tr = lv.transfer -- 21
			local cfg = lv.transfer.orbital -- 21
			local mu = lv.planets[1].gm -- 21
			local r = distance( -- 22
				lv.probeStart, -- 22
				bodyPositionAt(lv.planets[1], 0) -- 22
			) -- 22
			local power = n == 1 and 11 / 14 or 0.5 -- 23
			local function stateAt(date) -- 24
				local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(mu / (r * r * r)) * date -- 25
				local speed = math.sqrt(mu / r) -- 25
				return { -- 26
					pos = { -- 26
						x = r * math.cos(a), -- 26
						y = r * math.sin(a) -- 26
					}, -- 26
					vel = { -- 26
						x = -math.sin(a) * speed, -- 26
						y = math.cos(a) * speed -- 26
					} -- 26
				} -- 26
			end -- 24
			local level = { -- 28
				bodies = lv.planets, -- 28
				probeStart = lv.probeStart, -- 28
				probeVel0 = lv.probeVel0, -- 28
				goal = lv.goal, -- 28
				escapeRadius = lv.escapeRadius, -- 28
				maxSteps = lv.maxSteps, -- 28
				transfer = tr -- 28
			} -- 28
			local function launchAt(date, p) -- 29
				local core = createCore(dt) -- 30
				local start = stateAt(date) -- 30
				local plan = planTransfer( -- 31
					mu, -- 31
					r, -- 31
					start.vel, -- 31
					p, -- 31
					tr.apoapsisMax, -- 31
					tr.mode, -- 31
					tr.periapsisMin -- 31
				) -- 31
				core.t0 = date -- 32
				coreLaunch( -- 32
					core, -- 32
					plan.velocity, -- 32
					level, -- 32
					start.pos, -- 32
					start.vel -- 32
				) -- 32
				core.playback = 1 -- 32
				return core -- 33
			end -- 29
			local core = launchAt(1, power) -- 35
			local flight = core.flight -- 35
			local analysis = core.flyby -- 35
			local prefix = ("L" .. __TS__NumberToFixed(n + 1, 0)) .. "-" -- 36
			check(prefix .. "sun-center", mu == 800000 and lv.planets[1].radius == 50 and lv.planets[1].orbitRadius == 0) -- 37
			check( -- 38
				prefix .. "only-real-bodies", -- 38
				#lv.planets == n + 1 and #lv.stars == 0 and __TS__ArrayEvery( -- 38
					lv.planets, -- 38
					function(____, b) return b.gm > 0 and not b.isObstacle end -- 38
				) -- 38
			) -- 38
			check( -- 39
				prefix .. "marker-independent", -- 39
				lv.goal.marker ~= nil and lv.goal.marker.gm == 0 and lv.goal.marker.radius == 0 and __TS__ArrayIndexOf(lv.planets, lv.goal.marker) < 0 -- 39
			) -- 39
			check( -- 40
				prefix .. "marker-guidance-only", -- 40
				findGoalIndex( -- 40
					{bodyPositionAt(lv.goal.marker, 0)}, -- 40
					lv.planets, -- 40
					lv.goal, -- 40
					dt -- 40
				) < 0 -- 40
			) -- 40
			check(prefix .. "sun-emissive", lv.visuals[1].emissive ~= nil and lv.visuals[1].emissive.r == 1) -- 41
			check( -- 42
				prefix .. "baseline-success", -- 42
				core.goalIndex > 0 and __TS__ArrayEvery( -- 42
					analysis.encounters, -- 42
					function(____, e) return e.passed end -- 42
				) -- 42
			) -- 42
			check(prefix .. "short-burn", core.burnDuration > 0.29 and core.burnDuration < 0.31) -- 43
			check( -- 44
				prefix .. "not-precompleted", -- 44
				not core.missionCompleted and core.result == nil and not coreEndViewing(core) -- 44
			) -- 44
			local start = stateAt(1) -- 45
			local plan = planTransfer( -- 45
				mu, -- 45
				r, -- 45
				start.vel, -- 45
				power, -- 45
				tr.apoapsisMax, -- 45
				tr.mode, -- 45
				tr.periapsisMin -- 45
			) -- 45
			check( -- 46
				prefix .. "drag-radius", -- 46
				math.abs(plan.apoapsis - (n == 1 and 180 or 420)) < 1e-8 -- 46
			) -- 46
			check( -- 47
				prefix .. "system-tangent", -- 47
				math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-8 and (plan.velocity.x * start.vel.x + plan.velocity.y * start.vel.y) * (n == 1 and -1 or 1) > 0 -- 47
			) -- 47
			check( -- 48
				prefix .. "finite-burn", -- 48
				distance(flight.velocities[1], start.vel) < 1e-10 -- 48
			) -- 48
			local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 49
				dt = dt, -- 49
				steps = 3600, -- 49
				sampleEvery = 1, -- 49
				escapeRadius = lv.escapeRadius, -- 49
				t0 = 1 -- 49
			}) -- 49
			check( -- 50
				prefix .. "instant-plan-success", -- 50
				analyzeOrbitalMission( -- 50
					ref, -- 50
					lv.planets, -- 50
					cfg, -- 50
					dt, -- 50
					1 -- 50
				).completionIndex > 0 -- 50
			) -- 50
			for ____, e in ipairs(analysis.encounters) do -- 51
				check( -- 51
					(prefix .. "small-drift-") .. __TS__NumberToFixed(e.planetIndex, 0), -- 51
					distance(flight.points[e.periapsisIndex + 1], ref.points[e.periapsisIndex + 1]) < 5 -- 51
				) -- 51
			end -- 51
			check( -- 52
				prefix .. "work-required", -- 52
				analyzeOrbitalMission( -- 52
					flight, -- 52
					lv.planets, -- 52
					__TS__ObjectAssign( -- 52
						{}, -- 52
						cfg, -- 52
						{encounters = __TS__ArrayMap( -- 52
							cfg.encounters, -- 52
							function(____, e) return __TS__ObjectAssign({}, e, {minWork = 1000000000}) end -- 52
						)} -- 52
					), -- 52
					dt, -- 52
					1 -- 52
				).completionIndex < 0 -- 52
			) -- 52
			check( -- 53
				prefix .. "missing-assist-fails", -- 53
				analyzeOrbitalMission( -- 53
					flight, -- 53
					__TS__ArrayMap( -- 53
						lv.planets, -- 53
						function(____, b, i) return i == 1 and __TS__ObjectAssign({}, b, {gm = 0}) or b end -- 53
					), -- 53
					cfg, -- 53
					dt, -- 53
					1 -- 53
				).completionIndex < 0 -- 53
			) -- 53
			check( -- 54
				prefix .. "energy-required", -- 54
				analyzeOrbitalMission( -- 54
					flight, -- 54
					lv.planets, -- 54
					__TS__ObjectAssign( -- 54
						{}, -- 54
						cfg, -- 54
						{encounters = __TS__ArrayMap( -- 54
							cfg.encounters, -- 54
							function(____, e) return __TS__ObjectAssign({}, e, {minEnergyChange = 1000000000}) end -- 54
						)} -- 54
					), -- 54
					dt, -- 54
					1 -- 54
				).completionIndex < 0 -- 54
			) -- 54
			check( -- 55
				prefix .. "safe-distance-required", -- 55
				analyzeOrbitalMission( -- 55
					flight, -- 55
					lv.planets, -- 55
					__TS__ObjectAssign( -- 55
						{}, -- 55
						cfg, -- 55
						{encounters = __TS__ArrayMap( -- 55
							cfg.encounters, -- 55
							function(____, e) return __TS__ObjectAssign({}, e, {minPeriapsis = 105}) end -- 55
						)} -- 55
					), -- 55
					dt, -- 55
					1 -- 55
				).completionIndex < 0 -- 55
			) -- 55
			local reverse = analyzeOrbitalMission( -- 56
				flight, -- 56
				lv.planets, -- 56
				__TS__ObjectAssign( -- 56
					{}, -- 56
					cfg, -- 56
					{region = __TS__ObjectAssign({}, cfg.region, {direction = n == 1 and "outward" or "inward"})} -- 56
				), -- 56
				dt, -- 56
				1 -- 56
			) -- 56
			check( -- 58
				prefix .. "target-direction-required", -- 58
				reverse.completionIndex < 0 or reverse.completionIndex < analysis.completionIndex and analyzeOrbitalMission( -- 58
					__TS__ObjectAssign( -- 58
						{}, -- 58
						flight, -- 58
						{ -- 58
							points = __TS__ArraySlice(flight.points, 0, reverse.completionIndex + 1), -- 58
							velocities = __TS__ArraySlice(flight.velocities, 0, reverse.completionIndex + 1) -- 58
						} -- 58
					), -- 58
					lv.planets, -- 58
					cfg, -- 58
					dt, -- 58
					1 -- 58
				).completionIndex < 0 -- 58
			) -- 58
			if n == 2 then -- 58
				check( -- 59
					prefix .. "order-required", -- 59
					analyzeOrbitalMission( -- 59
						flight, -- 59
						lv.planets, -- 59
						__TS__ObjectAssign({}, cfg, {encounters = {cfg.encounters[2], cfg.encounters[1]}}), -- 59
						dt, -- 59
						1 -- 59
					).completionIndex < 0 -- 59
				) -- 59
			end -- 59
			check( -- 60
				prefix .. "low-power-fails", -- 60
				launchAt(1, 0.04).goalIndex < 0 -- 60
			) -- 60
			check( -- 61
				prefix .. "wrong-date-fails", -- 61
				launchAt(0, power).goalIndex < 0 -- 61
			) -- 61
			core.playback = 0 -- 62
			core.flightTime = (core.goalIndex - 1) * dt -- 62
			coreUpdate(core, 0, level) -- 62
			check(prefix .. "before-region-incomplete", not core.missionCompleted) -- 63
			core.flightTime = core.goalIndex * dt -- 64
			coreUpdate(core, 0, level) -- 64
			check(prefix .. "actual-region-completes", core.missionCompleted and core.phase == "Flying" and core.result == "success") -- 65
			check( -- 66
				prefix .. "manual-end", -- 66
				coreEndViewing(core) and core.phase == "Result" -- 66
			) -- 66
			local normal = launchAt(1, power) -- 67
			local fast = launchAt(1, power) -- 67
			fast.playback = 4 -- 68
			do -- 68
				local i = 0 -- 69
				while i < 2500 and normal.phase == "Flying" do -- 69
					coreUpdate(normal, 1 / 60, level) -- 69
					i = i + 1 -- 69
				end -- 69
			end -- 69
			do -- 69
				local i = 0 -- 70
				while i < 2500 and fast.phase == "Flying" do -- 70
					coreUpdate(fast, 1 / 120, level) -- 70
					i = i + 1 -- 70
				end -- 70
			end -- 70
			check(prefix .. "natural-end-success", normal.phase == "Result" and normal.missionCompleted and normal.result == "success") -- 71
			check( -- 72
				prefix .. "speed-deterministic", -- 72
				fast.result == normal.result and fast.flightTime == normal.flightTime and distance(fast.flight.state.pos, normal.flight.state.pos) == 0 -- 72
			) -- 72
			check( -- 73
				prefix .. "view-six-seconds-or-natural-end", -- 73
				analysis.viewEndIndex == math.min(#flight.points - 1, core.goalIndex + 375) -- 73
			) -- 73
			local at30 = 0 -- 74
			local at120 = 0 -- 74
			do -- 74
				local i = 0 -- 75
				while i < 450 do -- 75
					at30 = advanceTransferPlayback( -- 75
						at30, -- 75
						1 / 30, -- 75
						1, -- 75
						normal.burnDuration, -- 75
						tr, -- 75
						analysis, -- 75
						dt -- 75
					) -- 75
					i = i + 1 -- 75
				end -- 75
			end -- 75
			do -- 75
				local i = 0 -- 76
				while i < 1800 do -- 76
					at120 = advanceTransferPlayback( -- 76
						at120, -- 76
						1 / 120, -- 76
						1, -- 76
						normal.burnDuration, -- 76
						tr, -- 76
						analysis, -- 76
						dt -- 76
					) -- 76
					i = i + 1 -- 76
				end -- 76
			end -- 76
			check( -- 77
				prefix .. "fps-independent", -- 77
				math.abs(at30 - at120) < 1e-8 -- 77
			) -- 77
			do -- 77
				local i = 0 -- 78
				while i < #analysis.encounters do -- 78
					check( -- 78
						(prefix .. "encounter-shot-") .. __TS__NumberToFixed(i, 0), -- 78
						orbitalShotAt( -- 78
							analysis.encounters[i + 1].periapsisIndex * dt, -- 78
							normal.burnDuration, -- 78
							analysis, -- 78
							cfg, -- 78
							dt -- 78
						) == cfg.encounters[i + 1].focus -- 78
					) -- 78
					i = i + 1 -- 78
				end -- 78
			end -- 78
			check( -- 79
				prefix .. "one-completion-record", -- 79
				evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}).rockets == 1 -- 79
			) -- 79
			local crash = createCore(dt) -- 80
			coreLaunch( -- 80
				crash, -- 80
				{x = 0, y = 0}, -- 80
				level, -- 80
				{x = 0, y = 0}, -- 80
				{x = 0, y = 0} -- 80
			) -- 80
			coreUpdate(crash, 1, level) -- 80
			check(prefix .. "early-collision-fails", crash.result == "crashed" and not crash.missionCompleted) -- 81
			coreRetry(core, 0) -- 82
			check(prefix .. "retry-reset", not core.missionCompleted and core.flyby == nil and core.phase == "Aiming") -- 82
			n = n + 1 -- 18
		end -- 18
	end -- 18
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 84
end -- 9
return ____exports -- 9
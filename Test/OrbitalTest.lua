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
		function(s) return (json.decode(s)) end -- 12
	) -- 12
	local dt = 0.016 -- 13
	do -- 13
		local n = 1 -- 14
		while n <= 2 do -- 14
			local lv = getLevel(n) -- 15
			if lv.transfer == nil or lv.transfer.orbital == nil then -- 15
				return "failed\nmissing orbital fixture" -- 16
			end -- 16
			local tr = lv.transfer -- 17
			local cfg = lv.transfer.orbital -- 17
			local mu = lv.planets[1].gm -- 17
			local r = distance( -- 18
				lv.probeStart, -- 18
				bodyPositionAt(lv.planets[1], 0) -- 18
			) -- 18
			local power = n == 1 and 11 / 14 or 0.5 -- 19
			local function stateAt(date) -- 20
				local a = math.atan(lv.probeStart.y, lv.probeStart.x) + math.sqrt(mu / (r * r * r)) * date -- 21
				local speed = math.sqrt(mu / r) -- 21
				return { -- 22
					pos = { -- 22
						x = r * math.cos(a), -- 22
						y = r * math.sin(a) -- 22
					}, -- 22
					vel = { -- 22
						x = -math.sin(a) * speed, -- 22
						y = math.cos(a) * speed -- 22
					} -- 22
				} -- 22
			end -- 20
			local level = { -- 24
				bodies = lv.planets, -- 24
				probeStart = lv.probeStart, -- 24
				probeVel0 = lv.probeVel0, -- 24
				goal = lv.goal, -- 24
				escapeRadius = lv.escapeRadius, -- 24
				maxSteps = lv.maxSteps, -- 24
				transfer = tr -- 24
			} -- 24
			local function launchAt(date, p) -- 25
				local core = createCore(dt) -- 26
				local start = stateAt(date) -- 26
				local plan = planTransfer( -- 27
					mu, -- 27
					r, -- 27
					start.vel, -- 27
					p, -- 27
					tr.apoapsisMax, -- 27
					tr.mode, -- 27
					tr.periapsisMin -- 27
				) -- 27
				core.t0 = date -- 28
				coreLaunch( -- 28
					core, -- 28
					plan.velocity, -- 28
					level, -- 28
					start.pos, -- 28
					start.vel -- 28
				) -- 28
				core.playback = 1 -- 28
				return core -- 29
			end -- 25
			local core = launchAt(1, power) -- 31
			local flight = core.flight -- 31
			local analysis = core.flyby -- 31
			local prefix = ("L" .. __TS__NumberToFixed(n + 1, 0)) .. "-" -- 32
			check(prefix .. "sun-center", mu == 800000 and lv.planets[1].radius == 50 and lv.planets[1].orbitRadius == 0) -- 33
			check( -- 34
				prefix .. "only-real-bodies", -- 34
				#lv.planets == n + 1 and #lv.stars == 0 and __TS__ArrayEvery( -- 34
					lv.planets, -- 34
					function(____, b) return b.gm > 0 and not b.isObstacle end -- 34
				) -- 34
			) -- 34
			check( -- 35
				prefix .. "marker-independent", -- 35
				lv.goal.marker ~= nil and lv.goal.marker.gm == 0 and lv.goal.marker.radius == 0 and __TS__ArrayIndexOf(lv.planets, lv.goal.marker) < 0 -- 35
			) -- 35
			check( -- 36
				prefix .. "marker-guidance-only", -- 36
				findGoalIndex( -- 36
					{bodyPositionAt(lv.goal.marker, 0)}, -- 36
					lv.planets, -- 36
					lv.goal, -- 36
					dt -- 36
				) < 0 -- 36
			) -- 36
			check(prefix .. "sun-emissive", lv.visuals[1].emissive ~= nil and lv.visuals[1].emissive.r == 1) -- 37
			check( -- 38
				prefix .. "baseline-success", -- 38
				core.goalIndex > 0 and __TS__ArrayEvery( -- 38
					analysis.encounters, -- 38
					function(____, e) return e.passed end -- 38
				) -- 38
			) -- 38
			check(prefix .. "short-burn", core.burnDuration > 0.29 and core.burnDuration < 0.31) -- 39
			check( -- 40
				prefix .. "not-precompleted", -- 40
				not core.missionCompleted and core.result == nil and not coreEndViewing(core) -- 40
			) -- 40
			local start = stateAt(1) -- 41
			local plan = planTransfer( -- 41
				mu, -- 41
				r, -- 41
				start.vel, -- 41
				power, -- 41
				tr.apoapsisMax, -- 41
				tr.mode, -- 41
				tr.periapsisMin -- 41
			) -- 41
			check( -- 42
				prefix .. "drag-radius", -- 42
				math.abs(plan.apoapsis - (n == 1 and 180 or 420)) < 1e-8 -- 42
			) -- 42
			check( -- 43
				prefix .. "system-tangent", -- 43
				math.abs(plan.velocity.x * start.vel.y - plan.velocity.y * start.vel.x) < 1e-8 and (plan.velocity.x * start.vel.x + plan.velocity.y * start.vel.y) * (n == 1 and -1 or 1) > 0 -- 43
			) -- 43
			check( -- 44
				prefix .. "finite-burn", -- 44
				distance(flight.velocities[1], start.vel) < 1e-10 -- 44
			) -- 44
			local ref = simulate({pos = start.pos, vel = {x = start.vel.x + plan.velocity.x, y = start.vel.y + plan.velocity.y}}, lv.planets, { -- 45
				dt = dt, -- 45
				steps = 3600, -- 45
				sampleEvery = 1, -- 45
				escapeRadius = lv.escapeRadius, -- 45
				t0 = 1 -- 45
			}) -- 45
			check( -- 46
				prefix .. "instant-plan-success", -- 46
				analyzeOrbitalMission( -- 46
					ref, -- 46
					lv.planets, -- 46
					cfg, -- 46
					dt, -- 46
					1 -- 46
				).completionIndex > 0 -- 46
			) -- 46
			for ____, e in ipairs(analysis.encounters) do -- 47
				check( -- 47
					(prefix .. "small-drift-") .. __TS__NumberToFixed(e.planetIndex, 0), -- 47
					distance(flight.points[e.periapsisIndex + 1], ref.points[e.periapsisIndex + 1]) < 5 -- 47
				) -- 47
			end -- 47
			check( -- 48
				prefix .. "work-required", -- 48
				analyzeOrbitalMission( -- 48
					flight, -- 48
					lv.planets, -- 48
					__TS__ObjectAssign( -- 48
						{}, -- 48
						cfg, -- 48
						{encounters = __TS__ArrayMap( -- 48
							cfg.encounters, -- 48
							function(____, e) return __TS__ObjectAssign({}, e, {minWork = 1000000000}) end -- 48
						)} -- 48
					), -- 48
					dt, -- 48
					1 -- 48
				).completionIndex < 0 -- 48
			) -- 48
			check( -- 49
				prefix .. "energy-required", -- 49
				analyzeOrbitalMission( -- 49
					flight, -- 49
					lv.planets, -- 49
					__TS__ObjectAssign( -- 49
						{}, -- 49
						cfg, -- 49
						{encounters = __TS__ArrayMap( -- 49
							cfg.encounters, -- 49
							function(____, e) return __TS__ObjectAssign({}, e, {minEnergyChange = 1000000000}) end -- 49
						)} -- 49
					), -- 49
					dt, -- 49
					1 -- 49
				).completionIndex < 0 -- 49
			) -- 49
			check( -- 50
				prefix .. "safe-distance-required", -- 50
				analyzeOrbitalMission( -- 50
					flight, -- 50
					lv.planets, -- 50
					__TS__ObjectAssign( -- 50
						{}, -- 50
						cfg, -- 50
						{encounters = __TS__ArrayMap( -- 50
							cfg.encounters, -- 50
							function(____, e) return __TS__ObjectAssign({}, e, {minPeriapsis = 105}) end -- 50
						)} -- 50
					), -- 50
					dt, -- 50
					1 -- 50
				).completionIndex < 0 -- 50
			) -- 50
			local reverse = analyzeOrbitalMission( -- 51
				flight, -- 51
				lv.planets, -- 51
				__TS__ObjectAssign( -- 51
					{}, -- 51
					cfg, -- 51
					{region = __TS__ObjectAssign({}, cfg.region, {direction = n == 1 and "outward" or "inward"})} -- 51
				), -- 51
				dt, -- 51
				1 -- 51
			) -- 51
			check( -- 53
				prefix .. "target-direction-required", -- 53
				reverse.completionIndex < 0 or reverse.completionIndex < analysis.completionIndex and analyzeOrbitalMission( -- 53
					__TS__ObjectAssign( -- 53
						{}, -- 53
						flight, -- 53
						{ -- 53
							points = __TS__ArraySlice(flight.points, 0, reverse.completionIndex + 1), -- 53
							velocities = __TS__ArraySlice(flight.velocities, 0, reverse.completionIndex + 1) -- 53
						} -- 53
					), -- 53
					lv.planets, -- 53
					cfg, -- 53
					dt, -- 53
					1 -- 53
				).completionIndex < 0 -- 53
			) -- 53
			if n == 2 then -- 53
				check( -- 54
					prefix .. "order-required", -- 54
					analyzeOrbitalMission( -- 54
						flight, -- 54
						lv.planets, -- 54
						__TS__ObjectAssign({}, cfg, {encounters = {cfg.encounters[2], cfg.encounters[1]}}), -- 54
						dt, -- 54
						1 -- 54
					).completionIndex < 0 -- 54
				) -- 54
			end -- 54
			check( -- 55
				prefix .. "low-power-fails", -- 55
				launchAt(1, 0.04).goalIndex < 0 -- 55
			) -- 55
			check( -- 56
				prefix .. "wrong-date-fails", -- 56
				launchAt(0, power).goalIndex < 0 -- 56
			) -- 56
			core.playback = 0 -- 57
			core.flightTime = (core.goalIndex - 1) * dt -- 57
			coreUpdate(core, 0, level) -- 57
			check(prefix .. "before-region-incomplete", not core.missionCompleted) -- 58
			core.flightTime = core.goalIndex * dt -- 59
			coreUpdate(core, 0, level) -- 59
			check(prefix .. "actual-region-completes", core.missionCompleted and core.phase == "Flying" and core.result == "success") -- 60
			check( -- 61
				prefix .. "manual-end", -- 61
				coreEndViewing(core) and core.phase == "Result" -- 61
			) -- 61
			local normal = launchAt(1, power) -- 62
			local fast = launchAt(1, power) -- 62
			fast.playback = 4 -- 63
			do -- 63
				local i = 0 -- 64
				while i < 2500 and normal.phase == "Flying" do -- 64
					coreUpdate(normal, 1 / 60, level) -- 64
					i = i + 1 -- 64
				end -- 64
			end -- 64
			do -- 64
				local i = 0 -- 65
				while i < 2500 and fast.phase == "Flying" do -- 65
					coreUpdate(fast, 1 / 120, level) -- 65
					i = i + 1 -- 65
				end -- 65
			end -- 65
			check(prefix .. "natural-end-success", normal.phase == "Result" and normal.missionCompleted and normal.result == "success") -- 66
			check( -- 67
				prefix .. "speed-deterministic", -- 67
				fast.result == normal.result and fast.flightTime == normal.flightTime and distance(fast.flight.state.pos, normal.flight.state.pos) == 0 -- 67
			) -- 67
			check( -- 68
				prefix .. "view-six-seconds-or-natural-end", -- 68
				analysis.viewEndIndex == math.min(#flight.points - 1, core.goalIndex + 375) -- 68
			) -- 68
			local at30 = 0 -- 69
			local at120 = 0 -- 69
			do -- 69
				local i = 0 -- 70
				while i < 450 do -- 70
					at30 = advanceTransferPlayback( -- 70
						at30, -- 70
						1 / 30, -- 70
						1, -- 70
						normal.burnDuration, -- 70
						tr, -- 70
						analysis, -- 70
						dt -- 70
					) -- 70
					i = i + 1 -- 70
				end -- 70
			end -- 70
			do -- 70
				local i = 0 -- 71
				while i < 1800 do -- 71
					at120 = advanceTransferPlayback( -- 71
						at120, -- 71
						1 / 120, -- 71
						1, -- 71
						normal.burnDuration, -- 71
						tr, -- 71
						analysis, -- 71
						dt -- 71
					) -- 71
					i = i + 1 -- 71
				end -- 71
			end -- 71
			check( -- 72
				prefix .. "fps-independent", -- 72
				math.abs(at30 - at120) < 1e-8 -- 72
			) -- 72
			do -- 72
				local i = 0 -- 73
				while i < #analysis.encounters do -- 73
					check( -- 73
						(prefix .. "encounter-shot-") .. __TS__NumberToFixed(i, 0), -- 73
						orbitalShotAt( -- 73
							analysis.encounters[i + 1].periapsisIndex * dt, -- 73
							normal.burnDuration, -- 73
							analysis, -- 73
							cfg, -- 73
							dt -- 73
						) == cfg.encounters[i + 1].focus -- 73
					) -- 73
					i = i + 1 -- 73
				end -- 73
			end -- 73
			check( -- 74
				prefix .. "one-completion-record", -- 74
				evaluateRocketsDetailed(lv, "success", plan.dv, {starsCollected = 3}).rockets == 1 -- 74
			) -- 74
			local crash = createCore(dt) -- 75
			coreLaunch( -- 75
				crash, -- 75
				{x = 0, y = 0}, -- 75
				level, -- 75
				{x = 0, y = 0}, -- 75
				{x = 0, y = 0} -- 75
			) -- 75
			coreUpdate(crash, 1, level) -- 75
			check(prefix .. "early-collision-fails", crash.result == "crashed" and not crash.missionCompleted) -- 76
			coreRetry(core, 0) -- 77
			check(prefix .. "retry-reset", not core.missionCompleted and core.flyby == nil and core.phase == "Aiming") -- 77
			n = n + 1 -- 14
		end -- 14
	end -- 14
	return (((((#failures == 0 and "passed" or "failed") .. "\nchecks=") .. __TS__NumberToFixed(checks, 0)) .. " failures=") .. __TS__NumberToFixed(#failures, 0)) .. (#failures > 0 and "\n" .. table.concat(failures, "\n") or "") -- 79
end -- 8
return ____exports -- 8
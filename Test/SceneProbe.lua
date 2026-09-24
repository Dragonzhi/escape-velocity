-- [ts]: SceneProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local App = ____Dora.App -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Content = ____Dora.Content -- 10
local Director = ____Dora.Director -- 10
local Path = ____Dora.Path -- 10
local Vec3 = ____Dora.Vec3 -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____CameraRig = require("game.CameraRig") -- 11
local createCameraRig = ____CameraRig.createCameraRig -- 11
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 11
local ____Gravity = require("game.Gravity") -- 12
local bodyPositionAt = ____Gravity.bodyPositionAt -- 12
local simulate = ____Gravity.simulate -- 12
local ____Scene = require("game.Scene") -- 13
local buildScene = ____Scene.buildScene -- 13
local ____Vision = require("Test.Vision") -- 14
local captureReport = ____Vision.captureReport -- 14
local root = Content.searchPaths[1] -- 16
local outDir = Path(root, ".agent", "test-results") -- 17
if not Content:exist(outDir) then -- 17
	Content:mkdir(outDir) -- 18
end -- 18
local marker = Path(outDir, "s12-scene.txt") -- 19
local lines = {} -- 21
local function flush(final) -- 22
	Content:save( -- 23
		marker, -- 23
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 23
	) -- 23
end -- 22
lines[#lines + 1] = "phase=started" -- 25
flush(false) -- 26
local bodies = {{ -- 29
	gm = 900, -- 31
	radius = 2.2, -- 31
	orbitCenter = {x = 0, y = 0}, -- 32
	orbitRadius = 0, -- 32
	orbitPeriod = 0, -- 33
	phase0 = 0, -- 33
	orbitDirection = 1 -- 33
}, { -- 33
	gm = 300, -- 36
	radius = 1.4, -- 36
	orbitCenter = {x = 0, y = -14}, -- 37
	orbitRadius = 8, -- 37
	orbitPeriod = 10, -- 38
	phase0 = 0, -- 38
	orbitDirection = 1 -- 38
}} -- 38
local visuals = {{ -- 43
	r = 0.55, -- 44
	g = 0.62, -- 44
	b = 0.78, -- 44
	displayRadius = 2.2, -- 44
	ring = false -- 44
}, { -- 44
	r = 0.85, -- 45
	g = 0.72, -- 45
	b = 0.5, -- 45
	displayRadius = 1.4, -- 45
	ring = true -- 45
}} -- 45
local probeStart = {x = 0, y = 14} -- 48
local view = Director.entry -- 51
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 52
local sceneOptions = { -- 54
	root = view, -- 55
	bodies = bodies, -- 56
	visuals = visuals, -- 57
	probeStart = probeStart, -- 58
	probeScale = 1.6, -- 59
	spherePath = "Assets/Model/Sphere.gltf", -- 60
	ringPath = "Assets/Model/Ring.gltf", -- 61
	probePath = "Assets/Model/Probe.gltf" -- 62
} -- 62
local scene = buildScene(sceneOptions) -- 65
if scene == nil then -- 65
	lines[#lines + 1] = "RESULT=FAIL reason=scene-build-failed" -- 67
	flush(true) -- 68
else -- 68
	lines[#lines + 1] = "scene built OK" -- 70
	flush(false) -- 71
	local camera = Camera3D() -- 73
	Director:pushCamera(camera) -- 74
	lines[#lines + 1] = "camera OK" -- 75
	flush(false) -- 76
	local rig = createCameraRig(defaultRigOptions()) -- 78
	lines[#lines + 1] = "rig OK" -- 79
	flush(false) -- 80
	local initial = {pos = probeStart, vel = {x = 6, y = -12}} -- 83
	local sim = simulate(initial, bodies, {steps = 1500, dt = 1 / 120, sampleEvery = 5, escapeRadius = 400}) -- 84
	lines[#lines + 1] = (((("sim: outcome=" .. sim.outcome) .. " points=") .. tostring(#sim.points)) .. " stepsRun=") .. tostring(sim.stepsRun) -- 87
	local goal = {x = 0, y = -30} -- 90
	local planet0Pos = bodyPositionAt(bodies[1], 0) -- 91
	local planet1Pos = bodyPositionAt(bodies[2], 0) -- 92
	lines[#lines + 1] = ((("goal = (" .. __TS__NumberToFixed(goal.x, 2)) .. ", ") .. __TS__NumberToFixed(goal.y, 2)) .. ")" -- 93
	flush(false) -- 94
	lines[#lines + 1] = "entering threadLoop" -- 95
	flush(false) -- 96
	local opts = defaultRigOptions() -- 99
	local frame = 0 -- 100
	local requested = false -- 101
	local analyzed = false -- 102
	local lateShot = "" -- 103
	local firstEye = Vec3(0, 0, 0) -- 104
	local lastEye = Vec3(0, 0, 0) -- 105
	local firstTarget = Vec3(0, 0, 0) -- 106
	local lastTarget = Vec3(0, 0, 0) -- 107
	local initialShot = "" -- 108
	local minRigDistance = 1000000000 -- 109
	local maxRigDistance = 0 -- 110
	threadLoop(function() -- 112
		frame = frame + 1 -- 114
		if frame == 1 then -- 114
			lines[#lines + 1] = "frame 1 entered" -- 116
			flush(false) -- 117
		end -- 117
		local idx = frame * 4 -- 119
		local pos = idx < #sim.points and sim.points[idx + 1] or sim.points[#sim.points] -- 120
		do -- 120
			local function ____catch(e) -- 120
				if frame < 3 then -- 120
					lines[#lines + 1] = ("EXCEPTION at frame " .. tostring(frame)) .. ": sync/rig failed" -- 145
					flush(false) -- 146
				end -- 146
			end -- 146
			local ____try, ____hasReturned = pcall(function() -- 146
				scene.syncProbe(pos) -- 123
				scene.syncBodies(0) -- 124
				local rigFrame = rig.step({pos, goal, planet0Pos, planet1Pos}) -- 126
				rig.apply(camera, rigFrame) -- 127
				if frame == 1 then -- 127
					firstEye = rigFrame.eye -- 130
					firstTarget = rigFrame.target -- 131
				end -- 131
				lastEye = rigFrame.eye -- 133
				lastTarget = rigFrame.target -- 134
				local rdx = rigFrame.eye.x - rigFrame.target.x -- 137
				local rdy = rigFrame.eye.y - rigFrame.target.y -- 138
				local rdz = rigFrame.eye.z - rigFrame.target.z -- 139
				local rigDist = math.sqrt(rdx * rdx + rdy * rdy + rdz * rdz) -- 140
				if rigDist < minRigDistance then -- 140
					minRigDistance = rigDist -- 141
				end -- 141
				if rigDist > maxRigDistance then -- 141
					maxRigDistance = rigDist -- 142
				end -- 142
			end) -- 142
			if not ____try then -- 142
				____catch(____hasReturned) -- 142
			end -- 142
		end -- 142
		if not requested and frame > 3 then -- 142
			requested = true -- 152
			initialShot = App:saveScreenshot(Path(outDir, "s12-initial")) -- 153
			lines[#lines + 1] = "initial shot requested at frame=" .. tostring(frame) -- 154
			flush(false) -- 155
		end -- 155
		if frame == 76 then -- 155
			lateShot = App:saveScreenshot(Path(outDir, "s12-late")) -- 160
			lines[#lines + 1] = "late shot requested at frame=" .. tostring(frame) -- 161
			flush(false) -- 162
		end -- 162
		if requested and not analyzed and frame > 84 then -- 162
			analyzed = true -- 167
			local stats = view.stats -- 168
			lines[#lines + 1] = (((("stats: draws=" .. tostring(stats.drawCalls)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " triangles=") .. tostring(stats.triangles) -- 169
			lines[#lines + 1] = (("rig distance range over flight: min=" .. __TS__NumberToFixed(minRigDistance, 2)) .. " max=") .. __TS__NumberToFixed(maxRigDistance, 2) -- 170
			lines[#lines + 1] = "camera pulled back=" .. tostring(maxRigDistance > minRigDistance + 1) -- 171
			lines[#lines + 1] = "" -- 172
			lines[#lines + 1] = "--- initial frame analysis (aiming view) ---"
			lines[#lines + 1] = captureReport(initialShot, {"initial frame (aiming view)"}) -- 174
			lines[#lines + 1] = "" -- 175
			lines[#lines + 1] = "--- late frame analysis (after flight) ---"
			lines[#lines + 1] = captureReport( -- 177
				lateShot, -- 177
				{("late frame (frame " .. tostring(frame)) .. ", probe at far end)"} -- 177
			) -- 177
			flush(true) -- 178
			return true -- 179
		end -- 179
		return false -- 183
	end) -- 112
end -- 112
return ____exports -- 112
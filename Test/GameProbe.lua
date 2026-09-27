-- [ts]: GameProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 12
local App = ____Dora.App -- 12
local Camera3D = ____Dora.Camera3D -- 12
local Content = ____Dora.Content -- 12
local Director = ____Dora.Director -- 12
local Path = ____Dora.Path -- 12
local View = ____Dora.View -- 12
local threadLoop = ____Dora.threadLoop -- 12
local ____Config = require("game.Config") -- 13
local GravityScale = ____Config.GravityScale -- 13
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 13
local ____Gravity = require("game.Gravity") -- 14
local applyScales = ____Gravity.applyScales -- 14
local ____Scene = require("game.Scene") -- 15
local buildScene = ____Scene.buildScene -- 15
local ____CameraRig = require("game.CameraRig") -- 16
local createCameraRig = ____CameraRig.createCameraRig -- 16
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 16
local ____Trajectory = require("game.Trajectory") -- 17
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 17
local trajectoryOptions = ____Trajectory.defaultOptions -- 17
local ____PlanView = require("game.PlanView") -- 18
local createPlanView = ____PlanView.createPlanView -- 18
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 18
local ____Hud = require("game.Hud") -- 19
local createAimInput = ____Hud.createAimInput -- 19
local ____Game = require("game.Game") -- 20
local createGame = ____Game.createGame -- 20
local ____Vision = require("Test.Vision") -- 21
local captureReport = ____Vision.captureReport -- 21
local root = Content.searchPaths[1] -- 23
local outDir = Path(root, ".agent", "test-results") -- 24
if not Content:exist(outDir) then -- 24
	Content:mkdir(outDir) -- 25
end -- 25
local marker = Path(outDir, "s15-game.txt") -- 26
local lines = {} -- 28
local function flush(final) -- 29
	Content:save( -- 30
		marker, -- 30
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 30
	) -- 30
end -- 29
lines[#lines + 1] = "phase=started" -- 32
flush(false) -- 33
local rawBodies = {{ -- 36
	gm = 900, -- 37
	radius = 2.2, -- 37
	orbitCenter = {x = 0, y = 0}, -- 37
	orbitRadius = 0, -- 37
	orbitPeriod = 0, -- 37
	phase0 = 0, -- 37
	orbitDirection = 1 -- 37
}, { -- 37
	gm = 300, -- 38
	radius = 1.4, -- 38
	orbitCenter = {x = 0, y = -14}, -- 38
	orbitRadius = 8, -- 38
	orbitPeriod = 10, -- 38
	phase0 = 0, -- 38
	orbitDirection = 1 -- 38
}} -- 38
local bodies = applyScales(rawBodies, GravityScale, OrbitSpeedScale) -- 40
local visuals = {{ -- 41
	r = 0.55, -- 42
	g = 0.62, -- 42
	b = 0.78, -- 42
	displayRadius = 2.2, -- 42
	ring = false -- 42
}, { -- 42
	r = 0.85, -- 43
	g = 0.72, -- 43
	b = 0.5, -- 43
	displayRadius = 1.4, -- 43
	ring = true -- 43
}} -- 43
local level = { -- 45
	bodies = bodies, -- 45
	probeStart = {x = 0, y = 16}, -- 45
	goal = {kind = "escape", planetIndex = -1, tolerance = 0}, -- 45
	escapeRadius = 400, -- 45
	maxSteps = 1500 -- 45
} -- 45
local view = Director.entry -- 47
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 48
local scene = buildScene({ -- 50
	root = view, -- 51
	bodies = bodies, -- 52
	visuals = visuals, -- 53
	probeStart = level.probeStart, -- 54
	probeScale = 1.6, -- 55
	spherePath = "Assets/Model/Sphere.gltf", -- 56
	ringPath = "Assets/Model/Ring.gltf", -- 57
	probePath = "Assets/Model/Probe.gltf" -- 58
}) -- 58
if scene == nil then -- 58
	lines[#lines + 1] = "RESULT=FAIL reason=scene-build-failed" -- 62
	flush(true) -- 63
else -- 63
	local frame -- 63
	local camera = Camera3D() -- 65
	Director:pushCamera(camera) -- 66
	local rig = createCameraRig(defaultRigOptions()) -- 67
	local trajectory = createTrajectoryView( -- 68
		Director.ui, -- 68
		trajectoryOptions() -- 68
	) -- 68
	local plan = createPlanView( -- 70
		Director.ui, -- 70
		View.size.width, -- 70
		View.size.height, -- 70
		defaultPlanOptions() -- 70
	) -- 70
	local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 71
	local phaseHistory = {} -- 73
	local resultKind = "" -- 74
	local probeOffsetLog = "" -- 75
	local game = createGame( -- 77
		level, -- 77
		{ -- 77
			scene = scene, -- 78
			camera = camera, -- 79
			rig = rig, -- 80
			trajectory = trajectory, -- 81
			plan = plan, -- 82
			visuals = {}, -- 83
			setWorldVisible = function() -- 84
			end, -- 84
			aim = aim, -- 85
			viewW = View.size.width, -- 86
			viewH = View.size.height, -- 87
			fovYDeg = View.fieldOfView, -- 88
			aspect = View.aspectRatio, -- 89
			onPhase = function(____, p) -- 90
				phaseHistory[#phaseHistory + 1] = (p .. "@f") .. tostring(frame) -- 91
			end, -- 90
			onResult = function(____, r) -- 93
				resultKind = r -- 94
			end -- 93
		} -- 93
	) -- 93
	aim:onDrag(function(a) return game:onAimDrag(a) end) -- 98
	frame = 0 -- 100
	local launched = false -- 101
	local retried = false -- 102
	local aimShot = "" -- 103
	local resultShot = "" -- 104
	local aimAnalyzed = false -- 105
	local resultAnalyzed = false -- 106
	local launchFrame = 0 -- 107
	local resultFrame = 0 -- 108
	local retryFrame = 0 -- 109
	local minRigDist = 1000000000 -- 110
	local maxRigDist = 0 -- 111
	threadLoop(function() -- 113
		frame = frame + 1 -- 114
		game:update(App.deltaTime) -- 115
		if frame == 8 then -- 115
			aim:handleOffset({x = 60, y = -80}) -- 122
			local a = aim:current() -- 123
			lines[#lines + 1] = ((((((("drag applied at frame " .. tostring(frame)) .. ": power=") .. __TS__NumberToFixed(a.power, 3)) .. " vel=(") .. __TS__NumberToFixed(a.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(a.velocity.y, 2)) .. ")" -- 124
			flush(false) -- 125
		end -- 125
		if frame == 10 then -- 125
			lines[#lines + 1] = ("probe offset logged at frame " .. tostring(frame)) .. " (see drag line above)" -- 128
			flush(false) -- 129
		end -- 129
		if frame == 12 then -- 129
			aimShot = App:saveScreenshot(Path(outDir, "s15-aiming")) -- 134
			lines[#lines + 1] = "aiming shot requested at frame " .. tostring(frame) -- 135
			flush(false) -- 136
		end -- 136
		if frame == 20 and not launched then -- 136
			launched = true -- 139
			launchFrame = frame -- 140
			game:launch(aim:current().velocity) -- 141
			lines[#lines + 1] = (("launched at frame " .. tostring(frame)) .. ": phase=") .. game:phase() -- 142
			flush(false) -- 143
		end -- 143
		if launched and game:phase() == "Flying" and frame % 60 == 0 then -- 143
			lines[#lines + 1] = "flying: frame=" .. tostring(frame) -- 148
			flush(false) -- 149
		end -- 149
		if launched and not retried and game:phase() == "Result" then -- 149
			retried = true -- 154
			resultFrame = frame -- 155
			resultShot = App:saveScreenshot(Path(outDir, "s15-result")) -- 156
			lines[#lines + 1] = ((((("result at frame " .. tostring(frame)) .. ": kind=") .. resultKind) .. " (flight took ") .. __TS__NumberToFixed((resultFrame - launchFrame) / 60, 1)) .. "s real)" -- 157
			lines[#lines + 1] = "phase history: " .. table.concat(phaseHistory, " -> ") -- 158
			flush(false) -- 159
		end -- 159
		if retried and retryFrame == 0 and frame > resultFrame + 10 then -- 159
			game:retry() -- 164
			retryFrame = frame -- 165
			lines[#lines + 1] = (("retried at frame " .. tostring(frame)) .. ": phase=") .. game:phase() -- 166
			flush(false) -- 167
		end -- 167
		if retryFrame > 0 and not resultAnalyzed and frame > retryFrame + 8 then -- 167
			resultAnalyzed = true -- 172
			lines[#lines + 1] = "" -- 173
			lines[#lines + 1] = "--- aiming frame (prediction line) ---"
			lines[#lines + 1] = captureReport(aimShot, {"aiming: prediction line visible"}) -- 175
			lines[#lines + 1] = "" -- 176
			lines[#lines + 1] = "--- result frame (trail + frozen) ---"
			lines[#lines + 1] = captureReport(resultShot, {"result: " .. resultKind}) -- 178
			lines[#lines + 1] = "" -- 179
			lines[#lines + 1] = ("final phase=" .. game:phase()) .. " (expect Aiming)" -- 180
			lines[#lines + 1] = "RESULT=" .. (game:phase() == "Aiming" and resultKind ~= "" and "PASS" or "FAIL") -- 181
			flush(true) -- 182
			return true -- 183
		end -- 183
		return false -- 186
	end) -- 113
end -- 113
return ____exports -- 113
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
local ____Hud = require("game.Hud") -- 18
local createAimInput = ____Hud.createAimInput -- 18
local ____Game = require("game.Game") -- 19
local createGame = ____Game.createGame -- 19
local ____Vision = require("Test.Vision") -- 20
local captureReport = ____Vision.captureReport -- 20
local root = Content.searchPaths[1] -- 22
local outDir = Path(root, ".agent", "test-results") -- 23
if not Content:exist(outDir) then -- 23
	Content:mkdir(outDir) -- 24
end -- 24
local marker = Path(outDir, "s15-game.txt") -- 25
local lines = {} -- 27
local function flush(final) -- 28
	Content:save( -- 29
		marker, -- 29
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 29
	) -- 29
end -- 28
lines[#lines + 1] = "phase=started" -- 31
flush(false) -- 32
local rawBodies = {{ -- 35
	gm = 900, -- 36
	radius = 2.2, -- 36
	orbitCenter = {x = 0, y = 0}, -- 36
	orbitRadius = 0, -- 36
	orbitPeriod = 0, -- 36
	phase0 = 0, -- 36
	orbitDirection = 1 -- 36
}, { -- 36
	gm = 300, -- 37
	radius = 1.4, -- 37
	orbitCenter = {x = 0, y = -14}, -- 37
	orbitRadius = 8, -- 37
	orbitPeriod = 10, -- 37
	phase0 = 0, -- 37
	orbitDirection = 1 -- 37
}} -- 37
local bodies = applyScales(rawBodies, GravityScale, OrbitSpeedScale) -- 39
local visuals = {{ -- 40
	r = 0.55, -- 41
	g = 0.62, -- 41
	b = 0.78, -- 41
	displayRadius = 2.2, -- 41
	ring = false -- 41
}, { -- 41
	r = 0.85, -- 42
	g = 0.72, -- 42
	b = 0.5, -- 42
	displayRadius = 1.4, -- 42
	ring = true -- 42
}} -- 42
local level = {bodies = bodies, probeStart = {x = 0, y = 16}, escapeRadius = 400, maxSteps = 1500} -- 44
local view = Director.entry -- 46
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 47
local scene = buildScene({ -- 49
	root = view, -- 50
	bodies = bodies, -- 51
	visuals = visuals, -- 52
	probeStart = level.probeStart, -- 53
	probeScale = 1.6, -- 54
	spherePath = "Assets/Model/Sphere.gltf", -- 55
	ringPath = "Assets/Model/Ring.gltf", -- 56
	probePath = "Assets/Model/Probe.gltf" -- 57
}) -- 57
if scene == nil then -- 57
	lines[#lines + 1] = "RESULT=FAIL reason=scene-build-failed" -- 61
	flush(true) -- 62
else -- 62
	local frame -- 62
	local camera = Camera3D() -- 64
	Director:pushCamera(camera) -- 65
	local rig = createCameraRig(defaultRigOptions()) -- 66
	local trajectory = createTrajectoryView( -- 67
		Director.ui, -- 67
		trajectoryOptions() -- 67
	) -- 67
	local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 68
	local phaseHistory = {} -- 70
	local resultKind = "" -- 71
	local probeOffsetLog = "" -- 72
	local game = createGame( -- 74
		level, -- 74
		{ -- 74
			scene = scene, -- 75
			camera = camera, -- 76
			rig = rig, -- 77
			trajectory = trajectory, -- 78
			aim = aim, -- 79
			viewW = View.size.width, -- 80
			viewH = View.size.height, -- 81
			fovYDeg = View.fieldOfView, -- 82
			aspect = View.aspectRatio, -- 83
			onPhase = function(____, p) -- 84
				phaseHistory[#phaseHistory + 1] = (p .. "@f") .. tostring(frame) -- 85
			end, -- 84
			onResult = function(____, r) -- 87
				resultKind = r -- 88
			end -- 87
		} -- 87
	) -- 87
	aim:onDrag(function(a) return game:onAimDrag(a) end) -- 92
	frame = 0 -- 94
	local launched = false -- 95
	local retried = false -- 96
	local aimShot = "" -- 97
	local resultShot = "" -- 98
	local aimAnalyzed = false -- 99
	local resultAnalyzed = false -- 100
	local launchFrame = 0 -- 101
	local resultFrame = 0 -- 102
	local retryFrame = 0 -- 103
	local minRigDist = 1000000000 -- 104
	local maxRigDist = 0 -- 105
	threadLoop(function() -- 107
		frame = frame + 1 -- 108
		game:update(App.deltaTime) -- 109
		if frame == 8 then -- 109
			aim:handleOffset({x = 60, y = -80}) -- 116
			local a = aim:current() -- 117
			lines[#lines + 1] = ((((((("drag applied at frame " .. tostring(frame)) .. ": power=") .. __TS__NumberToFixed(a.power, 3)) .. " vel=(") .. __TS__NumberToFixed(a.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(a.velocity.y, 2)) .. ")" -- 118
			flush(false) -- 119
		end -- 119
		if frame == 10 then -- 119
			lines[#lines + 1] = ("probe offset logged at frame " .. tostring(frame)) .. " (see drag line above)" -- 122
			flush(false) -- 123
		end -- 123
		if frame == 12 then -- 123
			aimShot = App:saveScreenshot(Path(outDir, "s15-aiming")) -- 128
			lines[#lines + 1] = "aiming shot requested at frame " .. tostring(frame) -- 129
			flush(false) -- 130
		end -- 130
		if frame == 20 and not launched then -- 130
			launched = true -- 133
			launchFrame = frame -- 134
			game:launch(aim:current().velocity) -- 135
			lines[#lines + 1] = (("launched at frame " .. tostring(frame)) .. ": phase=") .. game:phase() -- 136
			flush(false) -- 137
		end -- 137
		if launched and game:phase() == "Flying" and frame % 60 == 0 then -- 137
			lines[#lines + 1] = "flying: frame=" .. tostring(frame) -- 142
			flush(false) -- 143
		end -- 143
		if launched and not retried and game:phase() == "Result" then -- 143
			retried = true -- 148
			resultFrame = frame -- 149
			resultShot = App:saveScreenshot(Path(outDir, "s15-result")) -- 150
			lines[#lines + 1] = ((((("result at frame " .. tostring(frame)) .. ": kind=") .. resultKind) .. " (flight took ") .. __TS__NumberToFixed((resultFrame - launchFrame) / 60, 1)) .. "s real)" -- 151
			lines[#lines + 1] = "phase history: " .. table.concat(phaseHistory, " -> ") -- 152
			flush(false) -- 153
		end -- 153
		if retried and retryFrame == 0 and frame > resultFrame + 10 then -- 153
			game:retry() -- 158
			retryFrame = frame -- 159
			lines[#lines + 1] = (("retried at frame " .. tostring(frame)) .. ": phase=") .. game:phase() -- 160
			flush(false) -- 161
		end -- 161
		if retryFrame > 0 and not resultAnalyzed and frame > retryFrame + 8 then -- 161
			resultAnalyzed = true -- 166
			lines[#lines + 1] = "" -- 167
			lines[#lines + 1] = "--- aiming frame (prediction line) ---"
			lines[#lines + 1] = captureReport(aimShot, {"aiming: prediction line visible"}) -- 169
			lines[#lines + 1] = "" -- 170
			lines[#lines + 1] = "--- result frame (trail + frozen) ---"
			lines[#lines + 1] = captureReport(resultShot, {"result: " .. resultKind}) -- 172
			lines[#lines + 1] = "" -- 173
			lines[#lines + 1] = ("final phase=" .. game:phase()) .. " (expect Aiming)" -- 174
			lines[#lines + 1] = "RESULT=" .. (game:phase() == "Aiming" and resultKind ~= "" and "PASS" or "FAIL") -- 175
			flush(true) -- 176
			return true -- 177
		end -- 177
		return false -- 180
	end) -- 107
end -- 107
return ____exports -- 107
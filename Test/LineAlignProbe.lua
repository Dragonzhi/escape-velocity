-- [ts]: LineAlignProbe.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 15
local App = ____Dora.App -- 15
local Camera3D = ____Dora.Camera3D -- 15
local Content = ____Dora.Content -- 15
local Director = ____Dora.Director -- 15
local Path = ____Dora.Path -- 15
local View = ____Dora.View -- 15
local threadLoop = ____Dora.threadLoop -- 15
local ____LevelData = require("game.LevelData") -- 16
local getLevel = ____LevelData.getLevel -- 16
local scaledPlanets = ____LevelData.scaledPlanets -- 16
local ____Scene = require("game.Scene") -- 17
local buildScene = ____Scene.buildScene -- 17
local ____CameraRig = require("game.CameraRig") -- 18
local createCameraRig = ____CameraRig.createCameraRig -- 18
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 18
local ____Trajectory = require("game.Trajectory") -- 19
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 19
local trajectoryOptions = ____Trajectory.defaultOptions -- 19
local ____Hud = require("game.Hud") -- 20
local createAimInput = ____Hud.createAimInput -- 20
local ____Game = require("game.Game") -- 21
local createGame = ____Game.createGame -- 21
local ____Vision = require("Test.Vision") -- 22
local captureReport = ____Vision.captureReport -- 22
local root = Content.searchPaths[1] -- 24
local outDir = Path(root, ".agent", "test-results") -- 25
if not Content:exist(outDir) then -- 25
	Content:mkdir(outDir) -- 26
end -- 26
local marker = Path(outDir, "s21-line-align.txt") -- 27
local lines = {} -- 29
local function flush(final) -- 30
	Content:save( -- 31
		marker, -- 31
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 31
	) -- 31
end -- 30
lines[#lines + 1] = "phase=started" -- 33
flush(false) -- 34
local levelDef = getLevel(0) -- 36
if levelDef == nil then -- 36
	lines[#lines + 1] = "RESULT=FAIL reason=no-level" -- 38
	flush(true) -- 39
else -- 39
	local bodies = scaledPlanets(levelDef) -- 41
	local level = { -- 42
		bodies = bodies, -- 43
		probeStart = levelDef.probeStart, -- 44
		goal = levelDef.goal, -- 45
		escapeRadius = levelDef.escapeRadius, -- 46
		maxSteps = levelDef.maxSteps -- 47
	} -- 47
	local view = Director.entry -- 50
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 51
	local scene = buildScene({ -- 52
		root = view, -- 53
		bodies = bodies, -- 54
		visuals = levelDef.visuals, -- 55
		probeStart = level.probeStart, -- 56
		probeScale = 1.6, -- 57
		spherePath = "Assets/Model/Sphere.gltf", -- 58
		ringPath = "Assets/Model/Ring.gltf", -- 59
		probePath = "Assets/Model/Probe.gltf" -- 60
	}) -- 60
	if scene == nil then -- 60
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 64
		flush(true) -- 65
	else -- 65
		local camera = Camera3D() -- 67
		Director:pushCamera(camera) -- 68
		local rig = createCameraRig(defaultRigOptions()) -- 69
		local trajectory = createTrajectoryView( -- 70
			Director.ui, -- 70
			trajectoryOptions() -- 70
		) -- 70
		local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 71
		local lastPhase = "Aiming" -- 73
		local game = createGame( -- 74
			level, -- 74
			{ -- 74
				scene = scene, -- 75
				camera = camera, -- 75
				rig = rig, -- 75
				trajectory = trajectory, -- 75
				aim = aim, -- 75
				viewW = View.size.width, -- 76
				viewH = View.size.height, -- 76
				fovYDeg = View.fieldOfView, -- 77
				aspect = View.aspectRatio, -- 77
				onPhase = function(____, p) -- 78
					lastPhase = p -- 78
				end, -- 78
				onResult = function() -- 79
				end -- 79
			} -- 79
		) -- 79
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 81
		local frame = 0 -- 83
		local launched = false -- 84
		local resultFrame = 0 -- 85
		local retried = false -- 86
		local retryFrame = 0 -- 87
		local shot1 = "" -- 88
		local shot2 = "" -- 89
		local shot3 = "" -- 90
		local done = false -- 91
		threadLoop(function() -- 93
			frame = frame + 1 -- 94
			game:update(App.deltaTime) -- 95
			if frame == 15 then -- 95
				shot1 = App:saveScreenshot(Path(outDir, "s21-steady")) -- 99
				lines[#lines + 1] = "steady shot @f" .. tostring(frame) -- 100
				flush(false) -- 101
			end -- 101
			if frame == 20 then -- 101
				aim:handleOffset({x = 60, y = -80}) -- 105
			end -- 105
			if frame == 24 and not launched then -- 105
				launched = true -- 107
				game:launch(aim:current().velocity) -- 108
				lines[#lines + 1] = "launched @f" .. tostring(frame) -- 109
				flush(false) -- 110
			end -- 110
			if launched and lastPhase == "Result" and resultFrame == 0 then -- 110
				resultFrame = frame -- 115
				lines[#lines + 1] = "result @f" .. tostring(frame) -- 116
				flush(false) -- 117
			end -- 117
			if resultFrame > 0 and not retried and frame > resultFrame + 5 then -- 117
				retried = true -- 120
				retryFrame = frame -- 121
				game:retry() -- 122
				lines[#lines + 1] = "retried @f" .. tostring(frame) -- 123
				flush(false) -- 124
			end -- 124
			if retried and frame == retryFrame + 8 then -- 124
				shot2 = App:saveScreenshot(Path(outDir, "s21-retry-mid")) -- 129
				lines[#lines + 1] = ("retry-mid shot @f" .. tostring(frame)) .. "（相机仍在 lerp）" -- 130
				flush(false) -- 131
			end -- 131
			if retried and frame == retryFrame + 40 then -- 131
				shot3 = App:saveScreenshot(Path(outDir, "s21-retry-settled")) -- 134
				lines[#lines + 1] = "retry-settled shot @f" .. tostring(frame) -- 135
				flush(false) -- 136
			end -- 136
			if retried and frame == retryFrame + 48 and not done then -- 136
				done = true -- 140
				lines[#lines + 1] = "" -- 141
				lines[#lines + 1] = "--- steady aiming ---"
				lines[#lines + 1] = captureReport(shot1, {"steady aiming: line should start at probe"}) -- 143
				lines[#lines + 1] = "" -- 144
				lines[#lines + 1] = "--- retry mid-transition (camera still lerping) ---"
				lines[#lines + 1] = captureReport(shot2, {"mid-transition: line must track probe (fix: redraw every frame)"}) -- 146
				lines[#lines + 1] = "" -- 147
				lines[#lines + 1] = "--- retry settled ---"
				lines[#lines + 1] = captureReport(shot3, {"settled aiming: line should start at probe again"}) -- 149
				lines[#lines + 1] = "" -- 150
				lines[#lines + 1] = "final phase=" .. game:phase() -- 151
				lines[#lines + 1] = "RESULT=PASS" -- 152
				flush(true) -- 153
				return true -- 154
			end -- 154
			return false -- 157
		end) -- 93
	end -- 93
end -- 93
return ____exports -- 93
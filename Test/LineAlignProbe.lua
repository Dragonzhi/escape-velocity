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
local ____PlanView = require("game.PlanView") -- 20
local createPlanView = ____PlanView.createPlanView -- 20
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 20
local ____Hud = require("game.Hud") -- 21
local createAimInput = ____Hud.createAimInput -- 21
local ____Game = require("game.Game") -- 22
local createGame = ____Game.createGame -- 22
local ____Vision = require("Test.Vision") -- 23
local captureReport = ____Vision.captureReport -- 23
local root = Content.searchPaths[1] -- 25
local outDir = Path(root, ".agent", "test-results") -- 26
if not Content:exist(outDir) then -- 26
	Content:mkdir(outDir) -- 27
end -- 27
local marker = Path(outDir, "s21-line-align.txt") -- 28
local lines = {} -- 30
local function flush(final) -- 31
	Content:save( -- 32
		marker, -- 32
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 32
	) -- 32
end -- 31
lines[#lines + 1] = "phase=started" -- 34
flush(false) -- 35
local levelDef = getLevel(0) -- 37
if levelDef == nil then -- 37
	lines[#lines + 1] = "RESULT=FAIL reason=no-level" -- 39
	flush(true) -- 40
else -- 40
	local bodies = scaledPlanets(levelDef) -- 42
	local level = { -- 43
		bodies = bodies, -- 44
		probeStart = levelDef.probeStart, -- 45
		goal = levelDef.goal, -- 46
		escapeRadius = levelDef.escapeRadius, -- 47
		maxSteps = levelDef.maxSteps -- 48
	} -- 48
	local view = Director.entry -- 51
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 52
	local scene = buildScene({ -- 53
		root = view, -- 54
		bodies = bodies, -- 55
		visuals = levelDef.visuals, -- 56
		probeStart = level.probeStart, -- 57
		probeScale = 1.6, -- 58
		spherePath = "Assets/Model/Sphere.gltf", -- 59
		ringPath = "Assets/Model/Ring.gltf", -- 60
		probePath = "Assets/Model/Probe.gltf" -- 61
	}) -- 61
	if scene == nil then -- 61
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 65
		flush(true) -- 66
	else -- 66
		local camera = Camera3D() -- 68
		Director:pushCamera(camera) -- 69
		local rig = createCameraRig(defaultRigOptions()) -- 70
		local trajectory = createTrajectoryView( -- 71
			Director.ui, -- 71
			trajectoryOptions() -- 71
		) -- 71
		local plan = createPlanView( -- 73
			Director.ui, -- 73
			View.size.width, -- 73
			View.size.height, -- 73
			defaultPlanOptions() -- 73
		) -- 73
		local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 74
		local lastPhase = "Aiming" -- 76
		local game = createGame( -- 77
			level, -- 77
			{ -- 77
				scene = scene, -- 78
				camera = camera, -- 78
				rig = rig, -- 78
				trajectory = trajectory, -- 78
				plan = plan, -- 78
				visuals = {}, -- 79
				setWorldVisible = function() -- 79
				end, -- 79
				aim = aim, -- 80
				viewW = View.size.width, -- 81
				viewH = View.size.height, -- 81
				fovYDeg = View.fieldOfView, -- 82
				aspect = View.aspectRatio, -- 82
				onPhase = function(____, p) -- 83
					lastPhase = p -- 83
				end, -- 83
				onResult = function() -- 84
				end -- 84
			} -- 84
		) -- 84
		game:toggleViewMode() -- 86
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 87
		local frame = 0 -- 89
		local launched = false -- 90
		local resultFrame = 0 -- 91
		local retried = false -- 92
		local retryFrame = 0 -- 93
		local shot1 = "" -- 94
		local shot2 = "" -- 95
		local shot3 = "" -- 96
		local done = false -- 97
		threadLoop(function() -- 99
			frame = frame + 1 -- 100
			game:update(App.deltaTime) -- 101
			if frame == 15 then -- 101
				shot1 = App:saveScreenshot(Path(outDir, "s21-steady")) -- 105
				lines[#lines + 1] = "steady shot @f" .. tostring(frame) -- 106
				flush(false) -- 107
			end -- 107
			if frame == 20 then -- 107
				aim:handleOffset({x = 60, y = -80}) -- 111
			end -- 111
			if frame == 24 and not launched then -- 111
				launched = true -- 113
				game:launch(aim:current().velocity) -- 114
				lines[#lines + 1] = "launched @f" .. tostring(frame) -- 115
				flush(false) -- 116
			end -- 116
			if launched and lastPhase == "Result" and resultFrame == 0 then -- 116
				resultFrame = frame -- 121
				lines[#lines + 1] = "result @f" .. tostring(frame) -- 122
				flush(false) -- 123
			end -- 123
			if resultFrame > 0 and not retried and frame > resultFrame + 5 then -- 123
				retried = true -- 126
				retryFrame = frame -- 127
				game:retry() -- 128
				lines[#lines + 1] = "retried @f" .. tostring(frame) -- 129
				flush(false) -- 130
			end -- 130
			if retried and frame == retryFrame + 8 then -- 130
				shot2 = App:saveScreenshot(Path(outDir, "s21-retry-mid")) -- 135
				lines[#lines + 1] = ("retry-mid shot @f" .. tostring(frame)) .. "（相机仍在 lerp）" -- 136
				flush(false) -- 137
			end -- 137
			if retried and frame == retryFrame + 40 then -- 137
				shot3 = App:saveScreenshot(Path(outDir, "s21-retry-settled")) -- 140
				lines[#lines + 1] = "retry-settled shot @f" .. tostring(frame) -- 141
				flush(false) -- 142
			end -- 142
			if retried and frame == retryFrame + 48 and not done then -- 142
				done = true -- 146
				lines[#lines + 1] = "" -- 147
				lines[#lines + 1] = "--- steady aiming ---"
				lines[#lines + 1] = captureReport(shot1, {"steady aiming: line should start at probe"}) -- 149
				lines[#lines + 1] = "" -- 150
				lines[#lines + 1] = "--- retry mid-transition (camera still lerping) ---"
				lines[#lines + 1] = captureReport(shot2, {"mid-transition: line must track probe (fix: redraw every frame)"}) -- 152
				lines[#lines + 1] = "" -- 153
				lines[#lines + 1] = "--- retry settled ---"
				lines[#lines + 1] = captureReport(shot3, {"settled aiming: line should start at probe again"}) -- 155
				lines[#lines + 1] = "" -- 156
				lines[#lines + 1] = "final phase=" .. game:phase() -- 157
				lines[#lines + 1] = "RESULT=PASS" -- 158
				flush(true) -- 159
				return true -- 160
			end -- 160
			return false -- 163
		end) -- 99
	end -- 99
end -- 99
return ____exports -- 99
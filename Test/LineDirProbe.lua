-- [ts]: LineDirProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 9
local App = ____Dora.App -- 9
local Camera3D = ____Dora.Camera3D -- 9
local Content = ____Dora.Content -- 9
local Director = ____Dora.Director -- 9
local Path = ____Dora.Path -- 9
local View = ____Dora.View -- 9
local threadLoop = ____Dora.threadLoop -- 9
local ____LevelData = require("game.LevelData") -- 10
local getLevel = ____LevelData.getLevel -- 10
local scaledPlanets = ____LevelData.scaledPlanets -- 10
local ____Gravity = require("game.Gravity") -- 11
local simulate = ____Gravity.simulate -- 11
local ____Scene = require("game.Scene") -- 12
local buildScene = ____Scene.buildScene -- 12
local ____CameraRig = require("game.CameraRig") -- 13
local createCameraRig = ____CameraRig.createCameraRig -- 13
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 13
local ____Trajectory = require("game.Trajectory") -- 14
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 14
local trajectoryOptions = ____Trajectory.defaultOptions -- 14
local ____PlanView = require("game.PlanView") -- 15
local createPlanView = ____PlanView.createPlanView -- 15
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 15
local ____Hud = require("game.Hud") -- 16
local createAimInput = ____Hud.createAimInput -- 16
local ____Game = require("game.Game") -- 17
local createGame = ____Game.createGame -- 17
local ____Config = require("game.Config") -- 18
local PredictSteps = ____Config.PredictSteps -- 18
local ____Vision = require("Test.Vision") -- 19
local captureReport = ____Vision.captureReport -- 19
local root = Content.searchPaths[1] -- 21
local outDir = Path(root, ".agent", "test-results") -- 22
if not Content:exist(outDir) then -- 22
	Content:mkdir(outDir) -- 23
end -- 23
local marker = Path(outDir, "s21-line-dir.txt") -- 24
local lines = {} -- 26
local function flush(final) -- 27
	Content:save( -- 28
		marker, -- 28
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 28
	) -- 28
end -- 27
lines[#lines + 1] = "phase=started" -- 30
flush(false) -- 31
local levelDef = getLevel(0) -- 33
if levelDef == nil then -- 33
	lines[#lines + 1] = "RESULT=FAIL reason=no-level" -- 35
	flush(true) -- 36
else -- 36
	local bodies = scaledPlanets(levelDef) -- 38
	local level = { -- 39
		bodies = bodies, -- 40
		probeStart = levelDef.probeStart, -- 41
		goal = levelDef.goal, -- 42
		escapeRadius = levelDef.escapeRadius, -- 43
		maxSteps = levelDef.maxSteps -- 44
	} -- 44
	--- 打印一条模拟轨迹的首末平面坐标（与渲染无关，纯物理）。
	local function logSim(tag, vel) -- 48
		local sim = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = vel}, level.bodies, {steps = PredictSteps, dt = 1 / 120, sampleEvery = 4, escapeRadius = level.escapeRadius}) -- 49
		local first = sim.points[1] -- 54
		local last = sim.points[#sim.points] -- 55
		lines[#lines + 1] = (((((((((((((tag .. ": vel=(") .. __TS__NumberToFixed(vel.x, 2)) .. ", ") .. __TS__NumberToFixed(vel.y, 2)) .. ") start=(") .. __TS__NumberToFixed(first.x, 2)) .. ", ") .. __TS__NumberToFixed(first.y, 2)) .. ") end=(") .. __TS__NumberToFixed(last.x, 2)) .. ", ") .. __TS__NumberToFixed(last.y, 2)) .. ") pts=") .. tostring(#sim.points) -- 56
	end -- 48
	local view = Director.entry -- 59
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 60
	local scene = buildScene({ -- 61
		root = view, -- 62
		bodies = bodies, -- 63
		visuals = levelDef.visuals, -- 64
		probeStart = level.probeStart, -- 65
		probeScale = 1.6, -- 66
		spherePath = "Assets/Model/Sphere.gltf", -- 67
		ringPath = "Assets/Model/Ring.gltf", -- 68
		probePath = "Assets/Model/Probe.gltf" -- 69
	}) -- 69
	if scene == nil then -- 69
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 73
		flush(true) -- 74
	else -- 74
		local camera = Camera3D() -- 76
		Director:pushCamera(camera) -- 77
		local rig = createCameraRig(defaultRigOptions()) -- 78
		local trajectory = createTrajectoryView( -- 79
			Director.ui, -- 79
			trajectoryOptions() -- 79
		) -- 79
		local plan = createPlanView( -- 81
			Director.ui, -- 81
			View.size.width, -- 81
			View.size.height, -- 81
			defaultPlanOptions() -- 81
		) -- 81
		local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 82
		local lastPhase = "Aiming" -- 84
		local game = createGame( -- 85
			level, -- 85
			{ -- 85
				scene = scene, -- 86
				camera = camera, -- 86
				rig = rig, -- 86
				trajectory = trajectory, -- 86
				plan = plan, -- 86
				visuals = {}, -- 87
				setWorldVisible = function() -- 87
				end, -- 87
				aim = aim, -- 88
				viewW = View.size.width, -- 89
				viewH = View.size.height, -- 89
				fovYDeg = View.fieldOfView, -- 90
				aspect = View.aspectRatio, -- 90
				onPhase = function(____, p) -- 91
					lastPhase = p -- 91
				end, -- 91
				onResult = function() -- 92
				end -- 92
			} -- 92
		) -- 92
		game:toggleViewMode() -- 94
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 95
		local frame = 0 -- 97
		local shotDefault = "" -- 98
		local shotDown = "" -- 99
		threadLoop(function() -- 101
			frame = frame + 1 -- 102
			game:update(App.deltaTime) -- 103
			if frame == 15 then -- 103
				logSim("default-aim", {x = 0, y = -2}) -- 107
				shotDefault = App:saveScreenshot(Path(outDir, "s21-dir-default")) -- 108
				lines[#lines + 1] = "default shot @f" .. tostring(frame) -- 109
				flush(false) -- 110
			end -- 110
			if frame == 20 then -- 110
				aim:handleOffset({x = 0, y = 300}) -- 115
				local a = aim:current() -- 116
				logSim("drag-down", a.velocity) -- 117
			end -- 117
			if frame == 26 then -- 117
				shotDown = App:saveScreenshot(Path(outDir, "s21-dir-down")) -- 120
				lines[#lines + 1] = "drag-down shot @f" .. tostring(frame) -- 121
				flush(false) -- 122
			end -- 122
			if frame == 34 then -- 122
				lines[#lines + 1] = "" -- 126
				lines[#lines + 1] = "--- default aim (vel (0,-2), toward Mars at bottom) ---"
				lines[#lines + 1] = captureReport(shotDefault, {"line should go DOWN from probe toward Mars"}) -- 128
				lines[#lines + 1] = "" -- 129
				lines[#lines + 1] = "--- drag down (big forward velocity) ---"
				lines[#lines + 1] = captureReport(shotDown, {"line should go DOWN fast"}) -- 131
				lines[#lines + 1] = "" -- 132
				lines[#lines + 1] = "RESULT=DONE" -- 133
				flush(true) -- 134
				return true -- 135
			end -- 135
			return false -- 138
		end) -- 101
	end -- 101
end -- 101
return ____exports -- 101
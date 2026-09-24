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
local ____Hud = require("game.Hud") -- 15
local createAimInput = ____Hud.createAimInput -- 15
local ____Game = require("game.Game") -- 16
local createGame = ____Game.createGame -- 16
local ____Config = require("game.Config") -- 17
local PredictSteps = ____Config.PredictSteps -- 17
local ____Vision = require("Test.Vision") -- 18
local captureReport = ____Vision.captureReport -- 18
local root = Content.searchPaths[1] -- 20
local outDir = Path(root, ".agent", "test-results") -- 21
if not Content:exist(outDir) then -- 21
	Content:mkdir(outDir) -- 22
end -- 22
local marker = Path(outDir, "s21-line-dir.txt") -- 23
local lines = {} -- 25
local function flush(final) -- 26
	Content:save( -- 27
		marker, -- 27
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 27
	) -- 27
end -- 26
lines[#lines + 1] = "phase=started" -- 29
flush(false) -- 30
local levelDef = getLevel(0) -- 32
if levelDef == nil then -- 32
	lines[#lines + 1] = "RESULT=FAIL reason=no-level" -- 34
	flush(true) -- 35
else -- 35
	local bodies = scaledPlanets(levelDef) -- 37
	local level = { -- 38
		bodies = bodies, -- 39
		probeStart = levelDef.probeStart, -- 40
		goal = levelDef.goal, -- 41
		escapeRadius = levelDef.escapeRadius, -- 42
		maxSteps = levelDef.maxSteps -- 43
	} -- 43
	--- 打印一条模拟轨迹的首末平面坐标（与渲染无关，纯物理）。
	local function logSim(tag, vel) -- 47
		local sim = simulate({pos = {x = level.probeStart.x, y = level.probeStart.y}, vel = vel}, level.bodies, {steps = PredictSteps, dt = 1 / 120, sampleEvery = 4, escapeRadius = level.escapeRadius}) -- 48
		local first = sim.points[1] -- 53
		local last = sim.points[#sim.points] -- 54
		lines[#lines + 1] = (((((((((((((tag .. ": vel=(") .. __TS__NumberToFixed(vel.x, 2)) .. ", ") .. __TS__NumberToFixed(vel.y, 2)) .. ") start=(") .. __TS__NumberToFixed(first.x, 2)) .. ", ") .. __TS__NumberToFixed(first.y, 2)) .. ") end=(") .. __TS__NumberToFixed(last.x, 2)) .. ", ") .. __TS__NumberToFixed(last.y, 2)) .. ") pts=") .. tostring(#sim.points) -- 55
	end -- 47
	local view = Director.entry -- 58
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 59
	local scene = buildScene({ -- 60
		root = view, -- 61
		bodies = bodies, -- 62
		visuals = levelDef.visuals, -- 63
		probeStart = level.probeStart, -- 64
		probeScale = 1.6, -- 65
		spherePath = "Assets/Model/Sphere.gltf", -- 66
		ringPath = "Assets/Model/Ring.gltf", -- 67
		probePath = "Assets/Model/Probe.gltf" -- 68
	}) -- 68
	if scene == nil then -- 68
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 72
		flush(true) -- 73
	else -- 73
		local camera = Camera3D() -- 75
		Director:pushCamera(camera) -- 76
		local rig = createCameraRig(defaultRigOptions()) -- 77
		local trajectory = createTrajectoryView( -- 78
			Director.ui, -- 78
			trajectoryOptions() -- 78
		) -- 78
		local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 79
		local lastPhase = "Aiming" -- 81
		local game = createGame( -- 82
			level, -- 82
			{ -- 82
				scene = scene, -- 83
				camera = camera, -- 83
				rig = rig, -- 83
				trajectory = trajectory, -- 83
				aim = aim, -- 83
				viewW = View.size.width, -- 84
				viewH = View.size.height, -- 84
				fovYDeg = View.fieldOfView, -- 85
				aspect = View.aspectRatio, -- 85
				onPhase = function(____, p) -- 86
					lastPhase = p -- 86
				end, -- 86
				onResult = function() -- 87
				end -- 87
			} -- 87
		) -- 87
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 89
		local frame = 0 -- 91
		local shotDefault = "" -- 92
		local shotDown = "" -- 93
		threadLoop(function() -- 95
			frame = frame + 1 -- 96
			game:update(App.deltaTime) -- 97
			if frame == 15 then -- 97
				logSim("default-aim", {x = 0, y = -2}) -- 101
				shotDefault = App:saveScreenshot(Path(outDir, "s21-dir-default")) -- 102
				lines[#lines + 1] = "default shot @f" .. tostring(frame) -- 103
				flush(false) -- 104
			end -- 104
			if frame == 20 then -- 104
				aim:handleOffset({x = 0, y = 300}) -- 109
				local a = aim:current() -- 110
				logSim("drag-down", a.velocity) -- 111
			end -- 111
			if frame == 26 then -- 111
				shotDown = App:saveScreenshot(Path(outDir, "s21-dir-down")) -- 114
				lines[#lines + 1] = "drag-down shot @f" .. tostring(frame) -- 115
				flush(false) -- 116
			end -- 116
			if frame == 34 then -- 116
				lines[#lines + 1] = "" -- 120
				lines[#lines + 1] = "--- default aim (vel (0,-2), toward Mars at bottom) ---"
				lines[#lines + 1] = captureReport(shotDefault, {"line should go DOWN from probe toward Mars"}) -- 122
				lines[#lines + 1] = "" -- 123
				lines[#lines + 1] = "--- drag down (big forward velocity) ---"
				lines[#lines + 1] = captureReport(shotDown, {"line should go DOWN fast"}) -- 125
				lines[#lines + 1] = "" -- 126
				lines[#lines + 1] = "RESULT=DONE" -- 127
				flush(true) -- 128
				return true -- 129
			end -- 129
			return false -- 132
		end) -- 95
	end -- 95
end -- 95
return ____exports -- 95
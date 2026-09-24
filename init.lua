-- [ts]: init.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local App = ____Dora.App -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Director = ____Dora.Director -- 10
local Label = ____Dora.Label -- 10
local Node = ____Dora.Node -- 10
local Size = ____Dora.Size -- 10
local Vec2 = ____Dora.Vec2 -- 10
local View = ____Dora.View -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____LevelData = require("game.LevelData") -- 11
local getLevel = ____LevelData.getLevel -- 11
local scaledPlanets = ____LevelData.scaledPlanets -- 11
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
local levelDef = getLevel(0) -- 19
if levelDef == nil then -- 19
	print("[escape-velocity] FATAL: no level data") -- 22
else -- 22
	local bodies = scaledPlanets(levelDef) -- 24
	local visuals = levelDef.visuals -- 25
	local level = { -- 27
		bodies = bodies, -- 28
		probeStart = levelDef.probeStart, -- 29
		goal = levelDef.goal, -- 30
		escapeRadius = levelDef.escapeRadius, -- 31
		maxSteps = levelDef.maxSteps -- 32
	} -- 32
	local view = Director.entry -- 36
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 37
	local scene = buildScene({ -- 39
		root = view, -- 40
		bodies = bodies, -- 41
		visuals = visuals, -- 42
		probeStart = level.probeStart, -- 43
		probeScale = 1.6, -- 44
		spherePath = "Assets/Model/Sphere.gltf", -- 45
		ringPath = "Assets/Model/Ring.gltf", -- 46
		probePath = "Assets/Model/Probe.gltf" -- 47
	}) -- 47
	if scene == nil then -- 47
		print("[escape-velocity] FATAL: scene build failed (model load error?)") -- 51
	else -- 51
		local camera = Camera3D() -- 53
		Director:pushCamera(camera) -- 54
		local rig = createCameraRig(defaultRigOptions()) -- 56
		local trajectory = createTrajectoryView( -- 57
			Director.ui, -- 57
			trajectoryOptions() -- 57
		) -- 57
		local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 58
		local resultLabel = Label("sarasa-mono-sc-regular", 52) -- 61
		local function showResult() -- 62
		end -- 62
		local function showPhase() -- 63
		end -- 63
		if resultLabel ~= nil then -- 63
			resultLabel.anchor = Vec2(0.5, 0.5) -- 66
			resultLabel.position = Vec2(0, View.size.height / 2 - 320) -- 67
			resultLabel.visible = false -- 68
			Director.ui:addChild(resultLabel) -- 69
			showResult = function(r) -- 71
				if r == "success" then -- 71
					resultLabel.text = "逃逸成功" -- 72
				elseif r == "crashed" then -- 72
					resultLabel.text = "撞毁" -- 73
				else -- 73
					resultLabel.text = "错过" -- 74
				end -- 74
				resultLabel.visible = true -- 75
			end -- 71
			showPhase = function(hasResult) -- 77
				if not hasResult then -- 77
					resultLabel.visible = false -- 78
				end -- 78
			end -- 77
		end -- 77
		local retryNode = Node() -- 83
		retryNode.size = Size(View.size.width, View.size.height) -- 84
		retryNode.anchor = Vec2(0.5, 0.5) -- 85
		retryNode.position = Vec2(0, 0) -- 86
		retryNode.touchEnabled = false -- 87
		Director.ui:addChild(retryNode) -- 88
		local game = createGame( -- 90
			level, -- 90
			{ -- 90
				scene = scene, -- 91
				camera = camera, -- 92
				rig = rig, -- 93
				trajectory = trajectory, -- 94
				aim = aim, -- 95
				viewW = View.size.width, -- 96
				viewH = View.size.height, -- 97
				fovYDeg = View.fieldOfView, -- 98
				aspect = View.aspectRatio, -- 99
				onPhase = function(____, p) -- 100
					retryNode.touchEnabled = p == "Result" -- 101
					showPhase(p == "Result") -- 102
					print("[escape-velocity] phase -> " .. p) -- 103
				end, -- 100
				onResult = function(____, r) -- 105
					showResult(r) -- 106
					print("[escape-velocity] result = " .. r) -- 107
				end -- 105
			} -- 105
		) -- 105
		aim:onDrag(function(a) return game:onAimDrag(a) end) -- 111
		aim:onRelease(function(a) return game:launch(a.velocity) end) -- 112
		retryNode:onTapEnded(function() -- 114
			if game:phase() == "Result" then -- 114
				game:retry() -- 116
			end -- 116
		end) -- 114
		threadLoop(function() -- 122
			game:update(App.deltaTime) -- 123
			return false -- 124
		end) -- 122
		print((("[escape-velocity] game started: L" .. tostring(levelDef.id)) .. " ") .. levelDef.title) -- 127
	end -- 127
end -- 127
return ____exports -- 127
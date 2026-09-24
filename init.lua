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
local ____Config = require("game.Config") -- 11
local GravityScale = ____Config.GravityScale -- 11
local OrbitSpeedScale = ____Config.OrbitSpeedScale -- 11
local ____Gravity = require("game.Gravity") -- 12
local applyScales = ____Gravity.applyScales -- 12
local ____Scene = require("game.Scene") -- 13
local buildScene = ____Scene.buildScene -- 13
local ____CameraRig = require("game.CameraRig") -- 14
local createCameraRig = ____CameraRig.createCameraRig -- 14
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 14
local ____Trajectory = require("game.Trajectory") -- 15
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 15
local trajectoryOptions = ____Trajectory.defaultOptions -- 15
local ____Hud = require("game.Hud") -- 16
local createAimInput = ____Hud.createAimInput -- 16
local ____Game = require("game.Game") -- 17
local createGame = ____Game.createGame -- 17
local rawBodies = {{ -- 20
	gm = 900, -- 22
	radius = 2.2, -- 22
	orbitCenter = {x = 0, y = 0}, -- 23
	orbitRadius = 0, -- 23
	orbitPeriod = 0, -- 24
	phase0 = 0, -- 24
	orbitDirection = 1 -- 24
}, { -- 24
	gm = 300, -- 27
	radius = 1.4, -- 27
	orbitCenter = {x = 0, y = -14}, -- 28
	orbitRadius = 8, -- 28
	orbitPeriod = 10, -- 29
	phase0 = 0, -- 29
	orbitDirection = 1 -- 29
}} -- 29
local bodies = applyScales(rawBodies, GravityScale, OrbitSpeedScale) -- 32
local visuals = {{ -- 34
	r = 0.55, -- 35
	g = 0.62, -- 35
	b = 0.78, -- 35
	displayRadius = 2.2, -- 35
	ring = false -- 35
}, { -- 35
	r = 0.85, -- 36
	g = 0.72, -- 36
	b = 0.5, -- 36
	displayRadius = 1.4, -- 36
	ring = true -- 36
}} -- 36
local level = {bodies = bodies, probeStart = {x = 0, y = 16}, escapeRadius = 400, maxSteps = 1500} -- 39
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
	print("[escape-velocity] FATAL: scene build failed (model load error?)") -- 62
else -- 62
	local camera = Camera3D() -- 64
	Director:pushCamera(camera) -- 65
	local rig = createCameraRig(defaultRigOptions()) -- 67
	local trajectory = createTrajectoryView( -- 68
		Director.ui, -- 68
		trajectoryOptions() -- 68
	) -- 68
	local aim = createAimInput(Director.ui, View.size.width, View.size.height) -- 69
	local resultLabel = Label("sarasa-mono-sc-regular", 52) -- 72
	local function showResult() -- 73
	end -- 73
	local function showPhase() -- 74
	end -- 74
	if resultLabel ~= nil then -- 74
		resultLabel.anchor = Vec2(0.5, 0.5) -- 77
		resultLabel.position = Vec2(0, View.size.height / 2 - 320) -- 78
		resultLabel.visible = false -- 79
		Director.ui:addChild(resultLabel) -- 80
		showResult = function(r) -- 82
			if r == "success" then -- 82
				resultLabel.text = "逃逸成功" -- 83
			elseif r == "crashed" then -- 83
				resultLabel.text = "撞毁" -- 84
			else -- 84
				resultLabel.text = "错过" -- 85
			end -- 85
			resultLabel.visible = true -- 86
		end -- 82
		showPhase = function(hasResult) -- 88
			if not hasResult then -- 88
				resultLabel.visible = false -- 89
			end -- 89
		end -- 88
	end -- 88
	local retryNode = Node() -- 94
	retryNode.size = Size(View.size.width, View.size.height) -- 95
	retryNode.anchor = Vec2(0.5, 0.5) -- 96
	retryNode.position = Vec2(0, 0) -- 97
	retryNode.touchEnabled = false -- 98
	Director.ui:addChild(retryNode) -- 99
	local game = createGame( -- 101
		level, -- 101
		{ -- 101
			scene = scene, -- 102
			camera = camera, -- 103
			rig = rig, -- 104
			trajectory = trajectory, -- 105
			aim = aim, -- 106
			viewW = View.size.width, -- 107
			viewH = View.size.height, -- 108
			fovYDeg = View.fieldOfView, -- 109
			aspect = View.aspectRatio, -- 110
			onPhase = function(____, p) -- 111
				retryNode.touchEnabled = p == "Result" -- 112
				showPhase(p == "Result") -- 113
				print("[escape-velocity] phase -> " .. p) -- 114
			end, -- 111
			onResult = function(____, r) -- 116
				showResult(r) -- 117
				print("[escape-velocity] result = " .. r) -- 118
			end -- 116
		} -- 116
	) -- 116
	aim:onDrag(function(a) return game:onAimDrag(a) end) -- 122
	aim:onRelease(function(a) return game:launch(a.velocity) end) -- 123
	retryNode:onTapEnded(function() -- 125
		if game:phase() == "Result" then -- 125
			game:retry() -- 127
		end -- 127
	end) -- 125
	threadLoop(function() -- 133
		game:update(App.deltaTime) -- 134
		return false -- 135
	end) -- 133
	print("[escape-velocity] game started (S1.5)") -- 138
end -- 138
return ____exports -- 138
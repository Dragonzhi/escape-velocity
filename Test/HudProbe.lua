-- [ts]: HudProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 15
local App = ____Dora.App -- 15
local Camera3D = ____Dora.Camera3D -- 15
local Content = ____Dora.Content -- 15
local Director = ____Dora.Director -- 15
local Path = ____Dora.Path -- 15
local Vec3 = ____Dora.Vec3 -- 15
local View = ____Dora.View -- 15
local threadLoop = ____Dora.threadLoop -- 15
local ____Projection = require("game.Projection") -- 16
local HANDEDNESS = ____Projection.HANDEDNESS -- 16
local FLIP_Y = ____Projection.FLIP_Y -- 16
local prepareCamera = ____Projection.prepareCamera -- 16
local project = ____Projection.project -- 16
local ____Gravity = require("game.Gravity") -- 17
local simulate = ____Gravity.simulate -- 17
local ____CameraRig = require("game.CameraRig") -- 18
local createCameraRig = ____CameraRig.createCameraRig -- 18
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 18
local ____Trajectory = require("game.Trajectory") -- 19
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 19
local defaultOptions = ____Trajectory.defaultOptions -- 19
local ____Hud = require("game.Hud") -- 20
local createAimInput = ____Hud.createAimInput -- 20
local defaultMaxDragPx = ____Hud.defaultMaxDragPx -- 20
local ____Vision = require("Test.Vision") -- 21
local captureReport = ____Vision.captureReport -- 21
local root = Content.searchPaths[1] -- 23
local outDir = Path(root, ".agent", "test-results") -- 24
if not Content:exist(outDir) then -- 24
	Content:mkdir(outDir) -- 25
end -- 25
local marker = Path(outDir, "s14-hud.txt") -- 26
local lines = {} -- 28
local function flush(final) -- 29
	Content:save( -- 30
		marker, -- 30
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 30
	) -- 30
end -- 29
lines[#lines + 1] = "phase=started" -- 32
flush(false) -- 33
local bodies = {{ -- 35
	gm = 900, -- 36
	radius = 2.2, -- 36
	orbitCenter = {x = 0, y = 0}, -- 37
	orbitRadius = 0, -- 37
	orbitPeriod = 0, -- 38
	phase0 = 0, -- 38
	orbitDirection = 1 -- 38
}} -- 38
local probeStart = {x = 0, y = 16} -- 41
local view = Director.entry -- 42
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 43
local camera = Camera3D() -- 45
Director:pushCamera(camera) -- 46
local rig = createCameraRig(defaultRigOptions()) -- 47
local traj = createTrajectoryView( -- 48
	Director.ui, -- 48
	defaultOptions() -- 48
) -- 48
local rigFrame = rig.step({probeStart, {x = 0, y = 0}}) -- 51
camera:lookAt( -- 52
	rigFrame.eye, -- 52
	rigFrame.target, -- 52
	Vec3(0, 1, 0) -- 52
) -- 52
local W = View.size.width -- 54
local H = View.size.height -- 55
local camView = { -- 57
	eye = {x = rigFrame.eye.x, y = rigFrame.eye.y, z = rigFrame.eye.z}, -- 58
	target = {x = rigFrame.target.x, y = rigFrame.target.y, z = rigFrame.target.z}, -- 59
	up = {x = 0, y = 1, z = 0}, -- 60
	fovYDeg = View.fieldOfView, -- 61
	aspect = View.aspectRatio, -- 62
	viewW = W, -- 63
	viewH = H -- 64
} -- 64
local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 66
local probeProj = project({x = probeStart.x, y = 0, z = probeStart.y}, camView, HANDEDNESS, FLIP_Y) -- 69
local aim = createAimInput(Director.ui, W, H) -- 71
lines[#lines + 1] = (("view=" .. tostring(W)) .. "x") .. tostring(H) -- 72
lines[#lines + 1] = "probe screen = " .. (probeProj ~= nil and ((("(" .. __TS__NumberToFixed(probeProj.x, 1)) .. ", ") .. __TS__NumberToFixed(probeProj.y, 1)) .. ")" or "BEHIND CAMERA") -- 73
lines[#lines + 1] = "maxDragPx=" .. tostring(defaultMaxDragPx()) -- 74
if probeProj == nil then -- 74
	lines[#lines + 1] = "RESULT=FAIL reason=probe-behind-camera" -- 77
	flush(true) -- 78
else -- 78
	local probeOffset = {x = probeProj.x, y = probeProj.y} -- 81
	aim:setProbeOffset(probeOffset) -- 82
	aim:setEnabled(true) -- 83
	local lastAim = aim:current() -- 86
	local dragCount = 0 -- 87
	aim:onDrag(function(a) -- 88
		lastAim = a -- 89
		dragCount = dragCount + 1 -- 90
	end) -- 88
	local released = nil -- 92
	aim:onAimReady(function(a) -- 94
		released = a -- 95
	end) -- 94
	local dragTo = {x = probeOffset.x + 40, y = probeOffset.y + 260} -- 99
	aim:handleOffset(dragTo) -- 100
	lines[#lines + 1] = ((("after drag to offset(" .. __TS__NumberToFixed(dragTo.x, 0)) .. ", ") .. __TS__NumberToFixed(dragTo.y, 0)) .. "):" -- 102
	lines[#lines + 1] = "  dragCount=" .. tostring(dragCount) -- 103
	lines[#lines + 1] = "  power=" .. __TS__NumberToFixed(lastAim.power, 3) -- 104
	lines[#lines + 1] = ((("  unit=(" .. __TS__NumberToFixed(lastAim.unit.x, 3)) .. ", ") .. __TS__NumberToFixed(lastAim.unit.y, 3)) .. ")" -- 105
	lines[#lines + 1] = ((("  velocity=(" .. __TS__NumberToFixed(lastAim.velocity.x, 2)) .. ", ") .. __TS__NumberToFixed(lastAim.velocity.y, 2)) .. ")" -- 106
	lines[#lines + 1] = "  released=" .. tostring(released ~= nil) -- 109
	local predicted = simulate({pos = probeStart, vel = lastAim.velocity}, bodies, {steps = 900, dt = 1 / 120, sampleEvery = 4, escapeRadius = 400}) -- 112
	traj:setPrediction(predicted.points, basis) -- 117
	traj:setTrail({probeStart}, basis) -- 118
	lines[#lines + 1] = (("  predicted: outcome=" .. predicted.outcome) .. " points=") .. tostring(#predicted.points) -- 119
	flush(false) -- 120
	local frame = 0 -- 123
	local requested = false -- 124
	local analyzed = false -- 125
	local shot = "" -- 126
	threadLoop(function() -- 128
		frame = frame + 1 -- 129
		if not requested and frame > 3 then -- 129
			requested = true -- 132
			shot = App:saveScreenshot(Path(outDir, "s14-hud")) -- 133
			lines[#lines + 1] = "shot requested at frame=" .. tostring(frame) -- 134
			flush(false) -- 135
		end -- 135
		if requested and not analyzed and frame > 16 then -- 135
			analyzed = true -- 139
			lines[#lines + 1] = "" -- 140
			lines[#lines + 1] = "--- aim + prediction frame ---"
			lines[#lines + 1] = captureReport(shot, {"aim-driven prediction line"}) -- 142
			flush(true) -- 143
			return true -- 144
		end -- 144
		return false -- 147
	end) -- 128
end -- 128
return ____exports -- 128
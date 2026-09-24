-- [ts]: TrajectoryProbe.ts
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
local View = ____Dora.View -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____Projection = require("game.Projection") -- 11
local HANDEDNESS = ____Projection.HANDEDNESS -- 11
local FLIP_Y = ____Projection.FLIP_Y -- 11
local prepareCamera = ____Projection.prepareCamera -- 11
local ____Gravity = require("game.Gravity") -- 12
local simulate = ____Gravity.simulate -- 12
local ____CameraRig = require("game.CameraRig") -- 13
local createCameraRig = ____CameraRig.createCameraRig -- 13
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 13
local ____Trajectory = require("game.Trajectory") -- 14
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 14
local defaultOptions = ____Trajectory.defaultOptions -- 14
local ____Vision = require("Test.Vision") -- 15
local captureReport = ____Vision.captureReport -- 15
local root = Content.searchPaths[1] -- 17
local outDir = Path(root, ".agent", "test-results") -- 18
if not Content:exist(outDir) then -- 18
	Content:mkdir(outDir) -- 19
end -- 19
local marker = Path(outDir, "s13-trajectory.txt") -- 20
local lines = {} -- 22
local function flush(final) -- 23
	Content:save( -- 24
		marker, -- 24
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 24
	) -- 24
end -- 23
lines[#lines + 1] = "phase=started" -- 26
flush(false) -- 27
local bodies = {{ -- 30
	gm = 900, -- 31
	radius = 2.2, -- 31
	orbitCenter = {x = 0, y = 0}, -- 32
	orbitRadius = 0, -- 32
	orbitPeriod = 0, -- 33
	phase0 = 0, -- 33
	orbitDirection = 1 -- 33
}} -- 33
local probeStart = {x = 0, y = 16} -- 36
local view = Director.entry -- 37
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 38
local camera = Camera3D() -- 41
Director:pushCamera(camera) -- 42
local rig = createCameraRig(defaultRigOptions()) -- 44
local traj = createTrajectoryView( -- 46
	Director.ui, -- 46
	defaultOptions() -- 46
) -- 46
lines[#lines + 1] = "trajectory view created (on Director.ui)" -- 47
local initial = {pos = probeStart, vel = {x = 6, y = -12}} -- 52
local simFull = simulate(initial, bodies, {steps = 1500, dt = 1 / 120, sampleEvery = 5, escapeRadius = 400}) -- 53
lines[#lines + 1] = (((("full sim: outcome=" .. simFull.outcome) .. " points=") .. tostring(#simFull.points)) .. " stepsRun=") .. tostring(simFull.stepsRun) -- 54
flush(false) -- 55
local W = View.size.width -- 57
local H = View.size.height -- 58
local aspect = View.aspectRatio -- 59
lines[#lines + 1] = (((("view=" .. tostring(W)) .. "x") .. tostring(H)) .. " aspect=") .. __TS__NumberToFixed(aspect, 4) -- 60
flush(false) -- 61
local frame = 0 -- 63
local requested = false -- 64
local analyzed = false -- 65
local trajectoryShot = "" -- 66
threadLoop(function() -- 68
	frame = frame + 1 -- 69
	local idx = frame * 3 -- 72
	local capped = idx < #simFull.points and idx or #simFull.points - 1 -- 73
	local probePos = simFull.points[capped + 1] -- 74
	local rigFrame = rig.step({probePos, {x = 0, y = 0}}) -- 77
	camera:lookAt( -- 78
		rigFrame.eye, -- 78
		rigFrame.target, -- 78
		Vec3(0, 1, 0) -- 78
	) -- 78
	local camView = { -- 81
		eye = {x = rigFrame.eye.x, y = rigFrame.eye.y, z = rigFrame.eye.z}, -- 82
		target = {x = rigFrame.target.x, y = rigFrame.target.y, z = rigFrame.target.z}, -- 83
		up = {x = 0, y = 1, z = 0}, -- 84
		fovYDeg = View.fieldOfView, -- 85
		aspect = aspect, -- 86
		viewW = W, -- 87
		viewH = H -- 88
	} -- 88
	local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 90
	traj:setPrediction(simFull.points, basis) -- 93
	local trail = {} -- 96
	do -- 96
		local i = 0 -- 97
		while i <= capped and i < #simFull.points do -- 97
			trail[#trail + 1] = simFull.points[i + 1] -- 97
			i = i + 1 -- 97
		end -- 97
	end -- 97
	traj:setTrail(trail, basis) -- 98
	if not requested and frame > 3 then -- 98
		requested = true -- 101
		trajectoryShot = App:saveScreenshot(Path(outDir, "s13-trajectory")) -- 102
		lines[#lines + 1] = "shot requested at frame=" .. tostring(frame) -- 103
		flush(false) -- 104
	end -- 104
	if requested and not analyzed and frame > 20 then -- 104
		analyzed = true -- 108
		lines[#lines + 1] = ((((("analyzing at frame=" .. tostring(frame)) .. ", probe=(") .. __TS__NumberToFixed(probePos.x, 1)) .. ", ") .. __TS__NumberToFixed(probePos.y, 1)) .. ")" -- 109
		lines[#lines + 1] = (("trail points=" .. tostring(#trail)) .. " predict points=") .. tostring(#simFull.points) -- 110
		lines[#lines + 1] = "" -- 111
		lines[#lines + 1] = "--- trajectory frame (prediction + trail) ---"
		lines[#lines + 1] = captureReport(trajectoryShot, {"prediction line = full path", "trail = prefix already flown"}) -- 113
		flush(true) -- 114
		return true -- 115
	end -- 115
	return false -- 118
end) -- 68
return ____exports -- 68
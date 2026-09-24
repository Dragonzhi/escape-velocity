-- [ts]: ProjCheckProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 11
local App = ____Dora.App -- 11
local Camera3D = ____Dora.Camera3D -- 11
local Content = ____Dora.Content -- 11
local Director = ____Dora.Director -- 11
local Path = ____Dora.Path -- 11
local Vec2 = ____Dora.Vec2 -- 11
local View = ____Dora.View -- 11
local threadLoop = ____Dora.threadLoop -- 11
local ____LevelData = require("game.LevelData") -- 12
local getLevel = ____LevelData.getLevel -- 12
local scaledPlanets = ____LevelData.scaledPlanets -- 12
local ____Scene = require("game.Scene") -- 13
local buildScene = ____Scene.buildScene -- 13
local ____CameraRig = require("game.CameraRig") -- 14
local createCameraRig = ____CameraRig.createCameraRig -- 14
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 14
local ____Projection = require("game.Projection") -- 15
local FLIP_Y = ____Projection.FLIP_Y -- 15
local HANDEDNESS = ____Projection.HANDEDNESS -- 15
local prepareCamera = ____Projection.prepareCamera -- 15
local projectPrepared = ____Projection.projectPrepared -- 15
local ____Vision = require("Test.Vision") -- 16
local captureReport = ____Vision.captureReport -- 16
local root = Content.searchPaths[1] -- 18
local outDir = Path(root, ".agent", "test-results") -- 19
if not Content:exist(outDir) then -- 19
	Content:mkdir(outDir) -- 20
end -- 20
local marker = Path(outDir, "s21-proj-check.txt") -- 21
local lines = {} -- 23
local function flush(final) -- 24
	Content:save( -- 25
		marker, -- 25
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 25
	) -- 25
end -- 24
lines[#lines + 1] = "phase=started" -- 27
flush(false) -- 28
local levelDef = getLevel(0) -- 30
if levelDef == nil then -- 30
	lines[#lines + 1] = "RESULT=FAIL" -- 32
	flush(true) -- 33
else -- 33
	local bodies = scaledPlanets(levelDef) -- 35
	local probeStart = levelDef.probeStart -- 36
	local mars = levelDef.planets[1].orbitCenter -- 37
	local view = Director.entry -- 39
	view:setEnvironmentIntensity(0.35, 0.35, 1) -- 40
	local scene = buildScene({ -- 41
		root = view, -- 42
		bodies = bodies, -- 43
		visuals = levelDef.visuals, -- 44
		probeStart = probeStart, -- 45
		probeScale = 1.6, -- 46
		spherePath = "Assets/Model/Sphere.gltf", -- 47
		ringPath = "Assets/Model/Ring.gltf", -- 48
		probePath = "Assets/Model/Probe.gltf" -- 49
	}) -- 49
	if scene == nil then -- 49
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 53
		flush(true) -- 54
	else -- 54
		local camera = Camera3D() -- 56
		Director:pushCamera(camera) -- 57
		local rig = createCameraRig(defaultRigOptions()) -- 58
		scene.syncProbe(probeStart) -- 60
		scene.syncBodies(0) -- 61
		local frame = 0 -- 63
		local shot = "" -- 64
		local printed = false -- 65
		threadLoop(function() -- 67
			frame = frame + 1 -- 68
			local pts = {probeStart, mars} -- 71
			local rigFrame = rig.step(pts) -- 72
			rig.apply(camera, rigFrame) -- 73
			if frame == 12 and not printed then -- 73
				printed = true -- 76
				local camView = { -- 77
					eye = {x = rigFrame.eye.x, y = rigFrame.eye.y, z = rigFrame.eye.z}, -- 78
					target = {x = rigFrame.target.x, y = rigFrame.target.y, z = rigFrame.target.z}, -- 79
					up = {x = 0, y = 1, z = 0}, -- 80
					fovYDeg = View.fieldOfView, -- 81
					aspect = View.aspectRatio, -- 82
					viewW = View.size.width, -- 83
					viewH = View.size.height -- 84
				} -- 84
				local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 86
				lines[#lines + 1] = ((((((((((("camera: eye=(" .. __TS__NumberToFixed(rigFrame.eye.x, 2)) .. ", ") .. __TS__NumberToFixed(rigFrame.eye.y, 2)) .. ", ") .. __TS__NumberToFixed(rigFrame.eye.z, 2)) .. ") target=(") .. __TS__NumberToFixed(rigFrame.target.x, 2)) .. ", ") .. __TS__NumberToFixed(rigFrame.target.y, 2)) .. ", ") .. __TS__NumberToFixed(rigFrame.target.z, 2)) .. ")" -- 88
				lines[#lines + 1] = (((((((((((("basis: fwd=(" .. __TS__NumberToFixed(basis.forward.x, 4)) .. ", ") .. __TS__NumberToFixed(basis.forward.y, 4)) .. ", ") .. __TS__NumberToFixed(basis.forward.z, 4)) .. ") up=(") .. __TS__NumberToFixed(basis.up.x, 4)) .. ", ") .. __TS__NumberToFixed(basis.up.y, 4)) .. ", ") .. __TS__NumberToFixed(basis.up.z, 4)) .. ") focal=") .. __TS__NumberToFixed(basis.focal, 4) -- 89
				local probeWorld = {x = 0, y = 0, z = 16} -- 92
				local marsWorld = {x = 0, y = 0, z = -30} -- 93
				local pp = projectPrepared(probeWorld, basis) -- 94
				local pm = projectPrepared(marsWorld, basis) -- 95
				if pp ~= nil then -- 95
					lines[#lines + 1] = ((("my projection: probe(0,0,16) -> pixel (" .. __TS__NumberToFixed(View.size.width / 2 + pp.x, 1)) .. ", ") .. __TS__NumberToFixed(View.size.height / 2 + pp.y, 1)) .. ")" -- 96
				end -- 96
				if pm ~= nil then -- 96
					lines[#lines + 1] = ((("my projection: mars (0,0,-30) -> pixel (" .. __TS__NumberToFixed(View.size.width / 2 + pm.x, 1)) .. ", ") .. __TS__NumberToFixed(View.size.height / 2 + pm.y, 1)) .. ")" -- 97
				end -- 97
				if pp ~= nil then -- 97
					local vpX = View.size.width / 2 + pp.x -- 101
					local vpY = View.size.height / 2 + pp.y -- 102
					local hit = view:pick(Vec2(vpX, vpY)) -- 103
					lines[#lines + 1] = (((("engine pick at my-probe-pixel (" .. __TS__NumberToFixed(vpX, 0)) .. ", ") .. __TS__NumberToFixed(vpY, 0)) .. "): ") .. (hit ~= nil and "HIT a model" or "no model") -- 104
				end -- 104
				local centerRay = view:getRayDirection(Vec2(View.size.width / 2, View.size.height / 2)) -- 108
				lines[#lines + 1] = ((((("engine ray @center: (" .. __TS__NumberToFixed(centerRay.x, 4)) .. ", ") .. __TS__NumberToFixed(centerRay.y, 4)) .. ", ") .. __TS__NumberToFixed(centerRay.z, 4)) .. ")" -- 109
				lines[#lines + 1] = ((((("my forward:        (" .. __TS__NumberToFixed(basis.forward.x, 4)) .. ", ") .. __TS__NumberToFixed(basis.forward.y, 4)) .. ", ") .. __TS__NumberToFixed(basis.forward.z, 4)) .. ")" -- 110
				local topRay = view:getRayDirection(Vec2(View.size.width / 2, 100)) -- 112
				lines[#lines + 1] = ((((("engine ray @(1012,100): (" .. __TS__NumberToFixed(topRay.x, 4)) .. ", ") .. __TS__NumberToFixed(topRay.y, 4)) .. ", ") .. __TS__NumberToFixed(topRay.z, 4)) .. ")" -- 113
				local myTop = {x = basis.forward.x + 0 * basis.right.x + -515 / (View.size.height / 2) / basis.focal * basis.up.x, y = basis.forward.y + 0 * basis.right.y + -515 / (View.size.height / 2) / basis.focal * basis.up.y, z = basis.forward.z + 0 * basis.right.z + -515 / (View.size.height / 2) / basis.focal * basis.up.z} -- 115
				local myTopLen = math.sqrt(myTop.x * myTop.x + myTop.y * myTop.y + myTop.z * myTop.z) -- 120
				lines[#lines + 1] = ((((("my ray @(1012,100):     (" .. __TS__NumberToFixed(myTop.x / myTopLen, 4)) .. ", ") .. __TS__NumberToFixed(myTop.y / myTopLen, 4)) .. ", ") .. __TS__NumberToFixed(myTop.z / myTopLen, 4)) .. ")" -- 121
				shot = App:saveScreenshot(Path(outDir, "s21-proj")) -- 123
				lines[#lines + 1] = "shot @f" .. tostring(frame) -- 124
				flush(false) -- 125
			end -- 125
			if frame == 22 then -- 125
				lines[#lines + 1] = "" -- 129
				lines[#lines + 1] = "--- rendered positions (ground truth) ---"
				lines[#lines + 1] = captureReport(shot, {"probe tetra + mars sphere; compare with my projection above"}) -- 131
				lines[#lines + 1] = "" -- 132
				lines[#lines + 1] = "RESULT=DONE" -- 133
				flush(true) -- 134
				return true -- 135
			end -- 135
			return false -- 138
		end) -- 67
	end -- 67
end -- 67
return ____exports -- 67
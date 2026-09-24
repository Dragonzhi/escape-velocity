-- [ts]: VerdictProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local App = ____Dora.App -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Color = ____Dora.Color -- 10
local Content = ____Dora.Content -- 10
local Director = ____Dora.Director -- 10
local Path = ____Dora.Path -- 10
local Vec3 = ____Dora.Vec3 -- 10
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
local ____Projection = require("game.Projection") -- 14
local FLIP_Y = ____Projection.FLIP_Y -- 14
local HANDEDNESS = ____Projection.HANDEDNESS -- 14
local prepareCamera = ____Projection.prepareCamera -- 14
local projectPrepared = ____Projection.projectPrepared -- 14
local ____Dora = require("Dora") -- 15
local Model3D = ____Dora.Model3D -- 15
local ____Vision = require("Test.Vision") -- 16
local parseTga = ____Vision.parseTga -- 16
local rgbAt = ____Vision.rgbAt -- 16
local root = Content.searchPaths[1] -- 19
local outDir = Path(root, ".agent", "test-results") -- 20
if not Content:exist(outDir) then -- 20
	Content:mkdir(outDir) -- 21
end -- 21
local marker = Path(outDir, "s21-verdict.txt") -- 22
local lines = {} -- 24
local function flush(final) -- 25
	Content:save( -- 26
		marker, -- 26
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 26
	) -- 26
end -- 25
lines[#lines + 1] = "phase=started" -- 28
flush(false) -- 29
local levelDef = getLevel(0) -- 31
if levelDef == nil then -- 31
	lines[#lines + 1] = "RESULT=FAIL" -- 33
	flush(true) -- 34
else -- 34
	local bodies = scaledPlanets(levelDef) -- 36
	local probeStart = levelDef.probeStart -- 37
	local marsDef = levelDef.planets[1] -- 38
	local view = Director.entry -- 40
	view:setEnvironmentIntensity(0.5, 0.5, 1) -- 41
	local scene = buildScene({ -- 42
		root = view, -- 43
		bodies = bodies, -- 44
		visuals = levelDef.visuals, -- 45
		probeStart = probeStart, -- 46
		probeScale = 1.6, -- 47
		spherePath = "Assets/Model/Sphere.gltf", -- 48
		ringPath = "Assets/Model/Ring.gltf", -- 49
		probePath = "Assets/Model/Probe.gltf" -- 50
	}) -- 50
	if scene == nil then -- 50
		lines[#lines + 1] = "RESULT=FAIL reason=scene" -- 54
		flush(true) -- 55
	else -- 55
		local pm = scene.probe:getMaterial(0) -- 58
		if pm ~= nil then -- 58
			pm.baseColor = Color(0, 255, 0, 255) -- 59
		end -- 59
		local mm = scene.planets[1].body:getMaterial(0) -- 60
		if mm ~= nil then -- 60
			mm.baseColor = Color(255, 0, 0, 255) -- 61
		end -- 61
		local camera = Camera3D() -- 63
		Director:pushCamera(camera) -- 64
		local rig = createCameraRig(defaultRigOptions()) -- 65
		scene.syncProbe(probeStart) -- 67
		scene.syncBodies(0) -- 68
		local pts = {probeStart, {x = marsDef.orbitCenter.x, y = marsDef.orbitCenter.y}} -- 71
		local rigFrame = rig.step(pts) -- 72
		rig.apply(camera, rigFrame) -- 73
		local targetW = rigFrame.target -- 74
		local markerSphere = Model3D("Assets/Model/Sphere.gltf") -- 76
		if markerSphere ~= nil then -- 76
			markerSphere.position = Vec3(targetW.x, targetW.y, targetW.z) -- 78
			markerSphere.scale = Vec3(0.8, 0.8, 0.8) -- 79
			local mm2 = markerSphere:getMaterial(0) -- 80
			if mm2 ~= nil then -- 80
				mm2.baseColor = Color(255, 255, 255, 255) -- 81
			end -- 81
			view:addChild(markerSphere) -- 82
		end -- 82
		local frame = 0 -- 85
		local shot = "" -- 86
		threadLoop(function() -- 88
			frame = frame + 1 -- 89
			if frame == 12 then -- 89
				local camView = { -- 92
					eye = {x = rigFrame.eye.x, y = rigFrame.eye.y, z = rigFrame.eye.z}, -- 93
					target = {x = rigFrame.target.x, y = rigFrame.target.y, z = rigFrame.target.z}, -- 94
					up = {x = 0, y = 1, z = 0}, -- 95
					fovYDeg = View.fieldOfView, -- 96
					aspect = View.aspectRatio, -- 97
					viewW = View.size.width, -- 98
					viewH = View.size.height -- 99
				} -- 99
				local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 101
				local pp = projectPrepared({x = 0, y = 0, z = 16}, basis) -- 103
				local pmars = projectPrepared({x = 0, y = 0, z = -30}, basis) -- 104
				local pt = projectPrepared({x = targetW.x, y = targetW.y, z = targetW.z}, basis) -- 105
				if pp ~= nil then -- 105
					lines[#lines + 1] = ((("my projection: probe(green) -> pixel (" .. __TS__NumberToFixed(View.size.width / 2 + pp.x, 0)) .. ", ") .. __TS__NumberToFixed(View.size.height / 2 + pp.y, 0)) .. ")" -- 106
				end -- 106
				if pmars ~= nil then -- 106
					lines[#lines + 1] = ((("my projection: mars(red)   -> pixel (" .. __TS__NumberToFixed(View.size.width / 2 + pmars.x, 0)) .. ", ") .. __TS__NumberToFixed(View.size.height / 2 + pmars.y, 0)) .. ")" -- 107
				end -- 107
				if pt ~= nil then -- 107
					lines[#lines + 1] = ((("my projection: target(marker) -> pixel (" .. __TS__NumberToFixed(View.size.width / 2 + pt.x, 0)) .. ", ") .. __TS__NumberToFixed(View.size.height / 2 + pt.y, 0)) .. ")  <- 应为主点" -- 108
				end -- 108
				shot = App:saveScreenshot(Path(outDir, "s21-verdict")) -- 110
				lines[#lines + 1] = "shot @f" .. tostring(frame) -- 111
				flush(false) -- 112
			end -- 112
			if frame == 24 then -- 112
				local data = Content:load(shot) -- 117
				local img = parseTga(data) -- 118
				if img ~= nil then -- 118
					local green = "" -- 120
					local red = "" -- 121
					local white = "" -- 122
					local gN = 0 -- 123
					local rN = 0 -- 124
					local wN = 0 -- 125
					local gx = 0 -- 126
					local gy = 0 -- 127
					local rx = 0 -- 128
					local ry = 0 -- 129
					local wx = 0 -- 130
					local wy = 0 -- 131
					do -- 131
						local y = 0 -- 132
						while y < img.height do -- 132
							do -- 132
								local x = 0 -- 133
								while x < img.width do -- 133
									local rgb = rgbAt(img, x, y) -- 134
									local r = rgb[1] -- 135
									local g = rgb[2] -- 136
									local b = rgb[3] -- 137
									if g > 150 and r < 100 and b < 100 then -- 137
										gx = gx + x -- 138
										gy = gy + y -- 138
										gN = gN + 1 -- 138
									elseif r > 150 and g < 100 and b < 100 then -- 138
										rx = rx + x -- 139
										ry = ry + y -- 139
										rN = rN + 1 -- 139
									elseif r > 200 and g > 200 and b > 200 then -- 139
										wx = wx + x -- 140
										wy = wy + y -- 140
										wN = wN + 1 -- 140
									end -- 140
									x = x + 4 -- 133
								end -- 133
							end -- 133
							y = y + 4 -- 132
						end -- 132
					end -- 132
					if gN > 0 then -- 132
						green = (((("probe(GREEN) rendered at (" .. __TS__NumberToFixed(gx / gN, 0)) .. ", ") .. __TS__NumberToFixed(gy / gN, 0)) .. ") samples=") .. tostring(gN) -- 143
					end -- 143
					if rN > 0 then -- 143
						red = (((("mars(RED) rendered at (" .. __TS__NumberToFixed(rx / rN, 0)) .. ", ") .. __TS__NumberToFixed(ry / rN, 0)) .. ") samples=") .. tostring(rN) -- 144
					end -- 144
					if wN > 0 then -- 144
						white = ((((("target-marker(WHITE) rendered at (" .. __TS__NumberToFixed(wx / wN, 0)) .. ", ") .. __TS__NumberToFixed(wy / wN, 0)) .. ") samples=") .. tostring(wN)) .. "  <- 主点真值" -- 145
					end -- 145
					lines[#lines + 1] = green == "" and "probe(GREEN): NOT FOUND" or green -- 146
					lines[#lines + 1] = red == "" and "mars(RED): NOT FOUND" or red -- 147
					lines[#lines + 1] = white == "" and "target-marker(WHITE): NOT FOUND" or white -- 148
				end -- 148
				lines[#lines + 1] = "" -- 150
				lines[#lines + 1] = "RESULT=DONE" -- 151
				flush(true) -- 152
				return true -- 153
			end -- 153
			return false -- 156
		end) -- 88
	end -- 88
end -- 88
return ____exports -- 88
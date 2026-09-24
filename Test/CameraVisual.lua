-- [ts]: CameraVisual.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local App = ____Dora.App -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Color3 = ____Dora.Color3 -- 10
local Content = ____Dora.Content -- 10
local Director = ____Dora.Director -- 10
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 10
local Model3D = ____Dora.Model3D -- 10
local Path = ____Dora.Path -- 10
local Vec3 = ____Dora.Vec3 -- 10
local View = ____Dora.View -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____Vision = require("Test.Vision") -- 11
local captureReport = ____Vision.captureReport -- 11
local root = Content.searchPaths[1] -- 13
local outDir = Path(root, ".agent", "test-results") -- 14
if not Content:exist(outDir) then -- 14
	Content:mkdir(outDir) -- 15
end -- 15
local marker = Path(outDir, "s04-camera-visual.txt") -- 16
Content:save(marker, "phase=started") -- 17
local view = Director.entry -- 19
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 20
local DIST = 30 -- 23
local TILT = 45 * math.pi / 180 -- 24
local eye = Vec3( -- 25
	0, -- 25
	math.sin(TILT) * DIST, -- 25
	math.cos(TILT) * DIST -- 25
) -- 25
local camera = Camera3D() -- 26
camera:lookAt( -- 27
	eye, -- 27
	Vec3(0, 0, 0) -- 27
) -- 27
Director:pushCamera(camera) -- 28
local light = DirectionalLight3D() -- 30
light.color = Color3(16774106) -- 31
light.intensity = 3.2 -- 32
light.angleX = -48 -- 33
light.angleY = 28 -- 34
view:addChild(light) -- 35
local startProbe = Model3D("Assets/Model/Probe.gltf") -- 38
if startProbe ~= nil then -- 38
	startProbe.position = Vec3(0, 0, 9) -- 40
	startProbe.scale = Vec3(1.6, 1.6, 1.6) -- 41
	view:addChild(startProbe) -- 42
end -- 42
local midPlanet = Model3D("Assets/Model/Sphere.gltf") -- 44
if midPlanet ~= nil then -- 44
	midPlanet.position = Vec3(0, 0, 0) -- 46
	midPlanet.scale = Vec3(3, 3, 3) -- 47
	view:addChild(midPlanet) -- 48
end -- 48
local goalPlanet = Model3D("Assets/Model/Sphere.gltf") -- 50
if goalPlanet ~= nil then -- 50
	goalPlanet.position = Vec3(0, 0, -13) -- 52
	goalPlanet.scale = Vec3(2.2, 2.2, 2.2) -- 53
	view:addChild(goalPlanet) -- 54
end -- 54
local elapsed = 0 -- 57
local requested = false -- 58
local analyzed = false -- 59
local shotPath = "" -- 60
threadLoop(function() -- 62
	elapsed = elapsed + App.deltaTime -- 63
	if not requested and elapsed > 1.5 then -- 63
		requested = true -- 65
		shotPath = App:saveScreenshot(Path(outDir, "s04-shot")) -- 66
	end -- 66
	if requested and not analyzed and elapsed > 2.5 then -- 66
		analyzed = true -- 69
		local stats = view.stats -- 70
		local sceneLines = { -- 71
			(((((("camera: dist=" .. tostring(DIST)) .. " tilt=45deg fovY=") .. tostring(View.fieldOfView)) .. " view=") .. tostring(View.size.width)) .. "x") .. tostring(View.size.height), -- 71
			"scene: startProbe at z=+9, midPlanet z=0, goalPlanet z=-13 (vertical track along world Z)", -- 73
			(((("stats: draws=" .. tostring(stats.drawCalls)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " triangles=") .. tostring(stats.triangles) -- 73
		} -- 73
		local report = captureReport(shotPath, sceneLines) -- 76
		Content:save(marker, report .. "\n\nphase=done") -- 77
	end -- 77
	return false -- 79
end) -- 62
return ____exports -- 62
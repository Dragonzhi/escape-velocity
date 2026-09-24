-- [ts]: VisionProbe.ts
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
local threadLoop = ____Dora.threadLoop -- 10
local ____Vision = require("Test.Vision") -- 11
local captureReport = ____Vision.captureReport -- 11
local root = Content.searchPaths[1] -- 13
local outDir = Path(root, ".agent", "test-results") -- 14
if not Content:exist(outDir) then -- 14
	Content:mkdir(outDir) -- 15
end -- 15
local marker = Path(outDir, "vision-capture.txt") -- 17
local reportPath = Path(outDir, "vision-report.txt") -- 18
Content:save(marker, "phase=started") -- 19
local view = Director.entry -- 22
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 23
local camera = Camera3D() -- 25
camera:lookAt( -- 26
	Vec3(0, 4.5, 11), -- 26
	Vec3(0, 0, 0) -- 26
) -- 26
Director:pushCamera(camera) -- 27
local light = DirectionalLight3D() -- 29
light.color = Color3(16774106) -- 30
light.intensity = 3.2 -- 31
light.angleX = -48 -- 32
light.angleY = 28 -- 33
view:addChild(light) -- 34
local planet = Model3D("Assets/Model/Sphere.gltf") -- 36
if planet ~= nil then -- 36
	planet.position = Vec3(-6.5, 0, 0) -- 38
	planet.scale = Vec3(1.6, 1.6, 1.6) -- 39
	view:addChild(planet) -- 40
end -- 40
local ringedPlanet = Model3D("Assets/Model/Sphere.gltf") -- 42
if ringedPlanet ~= nil then -- 42
	ringedPlanet.position = Vec3(0, 0, 0) -- 44
	ringedPlanet.scale = Vec3(1.6, 1.6, 1.6) -- 45
	view:addChild(ringedPlanet) -- 46
end -- 46
local probe = Model3D("Assets/Model/Probe.gltf") -- 48
if probe ~= nil then -- 48
	probe.position = Vec3(6.5, 0, 0) -- 50
	probe.scale = Vec3(3.2, 3.2, 3.2) -- 51
	view:addChild(probe) -- 52
end -- 52
local elapsed = 0 -- 57
local requested = false -- 58
local analyzed = false -- 59
local shotPath = "" -- 60
threadLoop(function() -- 62
	elapsed = elapsed + App.deltaTime -- 63
	if not requested and elapsed > 1.5 then -- 63
		requested = true -- 67
		shotPath = App:saveScreenshot(Path(outDir, "shot")) -- 68
		Content:save(marker, "phase=requested") -- 69
	end -- 69
	if requested and not analyzed and elapsed > 2.5 then -- 69
		analyzed = true -- 74
		local stats = view.stats -- 75
		local sceneLines = { -- 76
			(((("models: planet=" .. tostring(planet ~= nil)) .. " ringed=") .. tostring(ringedPlanet ~= nil)) .. " probe=") .. tostring(probe ~= nil), -- 76
			"expected: 3 horizontally separated objects at x=-6.5 / 0 / +6.5", -- 78
			(((("stats: draws=" .. tostring(stats.drawCalls)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " triangles=") .. tostring(stats.triangles), -- 78
			"shotPath=" .. shotPath, -- 80
			"shotBytes=" .. tostring(Content:exist(shotPath) and ({Content:getAttr(shotPath)}) or -1) -- 81
		} -- 81
		local report = captureReport(shotPath, sceneLines) -- 83
		Content:save(reportPath, report) -- 84
		Content:save(marker, "phase=done") -- 85
	end -- 85
	return false -- 87
end) -- 62
return ____exports -- 62
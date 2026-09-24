-- [ts]: Smoke.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 8
local App = ____Dora.App -- 8
local Camera3D = ____Dora.Camera3D -- 8
local Color3 = ____Dora.Color3 -- 8
local Content = ____Dora.Content -- 8
local Director = ____Dora.Director -- 8
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 8
local Model3D = ____Dora.Model3D -- 8
local Path = ____Dora.Path -- 8
local Vec3 = ____Dora.Vec3 -- 8
local threadLoop = ____Dora.threadLoop -- 8
local resultDir = Path(Content.searchPaths[1], ".agent", "test-results") -- 10
if not Content:exist(resultDir) then -- 10
	Content:mkdir(resultDir) -- 11
end -- 11
local view = Director.entry -- 13
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 14
local camera = Camera3D() -- 16
camera:lookAt( -- 17
	Vec3(0, 3, 7), -- 17
	Vec3(0, 0, 0) -- 17
) -- 17
Director:pushCamera(camera) -- 18
local light = DirectionalLight3D() -- 20
light.color = Color3(16777215) -- 21
light.intensity = 3 -- 22
light.angleX = -50 -- 23
light.angleY = 25 -- 24
view:addChild(light) -- 25
local missing = {} -- 27
local sphere = Model3D("Assets/Model/Sphere.gltf") -- 29
if sphere ~= nil then -- 29
	sphere.position = Vec3(-2.2, 0, 0) -- 31
	sphere.scale = Vec3(1, 1, 1) -- 32
	view:addChild(sphere) -- 33
else -- 33
	missing[#missing + 1] = "Sphere.gltf" -- 35
end -- 35
local ring = Model3D("Assets/Model/Ring.gltf") -- 38
if ring ~= nil then -- 38
	ring.position = Vec3(0, 0, 0) -- 40
	view:addChild(ring) -- 41
else -- 41
	missing[#missing + 1] = "Ring.gltf" -- 43
end -- 43
local probe = Model3D("Assets/Model/Probe.gltf") -- 46
if probe ~= nil then -- 46
	probe.position = Vec3(2.2, 0, 0) -- 48
	view:addChild(probe) -- 49
else -- 49
	missing[#missing + 1] = "Probe.gltf" -- 51
end -- 51
local elapsed = 0 -- 54
local checked = false -- 55
threadLoop(function() -- 56
	if probe ~= nil then -- 56
		probe.angleY = probe.angleY + App.deltaTime * 60 -- 57
	end -- 57
	if sphere ~= nil then -- 57
		sphere.angleY = sphere.angleY + App.deltaTime * 30 -- 58
	end -- 58
	elapsed = elapsed + App.deltaTime -- 59
	if not checked and elapsed > 1.5 then -- 59
		checked = true -- 61
		local stats = view.stats -- 62
		local ok = #missing == 0 and stats.drawCalls > 0 and stats.visibleVisuals > 0 -- 63
		Content:save( -- 64
			Path(resultDir, "s0-assets.txt"), -- 65
			(((((((("status=" .. (ok and "PASS" or "FAIL")) .. " draws=") .. tostring(stats.drawCalls)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " triangles=") .. tostring(stats.triangles)) .. " missing=") .. table.concat(missing, ",") -- 65
		) -- 65
	end -- 65
	return false -- 69
end) -- 56
return ____exports -- 56
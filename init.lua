-- [ts]: init.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 11
local App = ____Dora.App -- 11
local Camera3D = ____Dora.Camera3D -- 11
local Color3 = ____Dora.Color3 -- 11
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 11
local Director = ____Dora.Director -- 11
local Model3D = ____Dora.Model3D -- 11
local Vec3 = ____Dora.Vec3 -- 11
local View = ____Dora.View -- 11
local threadLoop = ____Dora.threadLoop -- 11
local view = Director.entry -- 13
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 16
local camera = Camera3D() -- 19
camera:lookAt( -- 20
	Vec3(0, 4.5, 11), -- 20
	Vec3(0, 0, 0) -- 20
) -- 20
Director:pushCamera(camera) -- 21
local light = DirectionalLight3D() -- 24
light.color = Color3(16774106) -- 25
light.intensity = 3.2 -- 26
light.angleX = -48 -- 27
light.angleY = 28 -- 28
view:addChild(light) -- 29
local planet = Model3D("Assets/Model/Sphere.gltf") -- 32
if planet ~= nil then -- 32
	planet.position = Vec3(-3.2, 0, 0) -- 34
	planet.scale = Vec3(2.2, 2.2, 2.2) -- 35
	view:addChild(planet) -- 36
end -- 36
local ring = Model3D("Assets/Model/Ring.gltf") -- 40
if ring ~= nil then -- 40
	ring.position = Vec3(0, 0, 0) -- 42
	ring.scale = Vec3(1.6, 1, 1.6) -- 43
	view:addChild(ring) -- 44
end -- 44
local ringedPlanet = Model3D("Assets/Model/Sphere.gltf") -- 47
if ringedPlanet ~= nil then -- 47
	ringedPlanet.position = Vec3(0, 0, 0) -- 49
	ringedPlanet.scale = Vec3(1.4, 1.4, 1.4) -- 50
	view:addChild(ringedPlanet) -- 51
end -- 51
local probe = Model3D("Assets/Model/Probe.gltf") -- 55
if probe ~= nil then -- 55
	probe.position = Vec3(3.4, 0, 0) -- 57
	probe.scale = Vec3(1.1, 1.1, 1.1) -- 58
	view:addChild(probe) -- 59
end -- 59
local elapsed = 0 -- 63
local reported = false -- 64
threadLoop(function() -- 65
	local dt = App.deltaTime -- 66
	if planet ~= nil then -- 66
		planet.angleY = planet.angleY + dt * 18 -- 67
	end -- 67
	if ringedPlanet ~= nil then -- 67
		ringedPlanet.angleY = ringedPlanet.angleY + dt * 26 -- 68
	end -- 68
	if probe ~= nil then -- 68
		probe.angleY = probe.angleY + dt * 60 -- 69
	end -- 69
	elapsed = elapsed + dt -- 71
	if not reported and elapsed > 2 then -- 71
		reported = true -- 73
		local stats = view.stats -- 74
		print((((((((("[escape-velocity] draws=" .. tostring(stats.drawCalls)) .. " visible=") .. tostring(stats.visibleVisuals)) .. " triangles=") .. tostring(stats.triangles)) .. " view=") .. tostring(View.size.width)) .. "x") .. tostring(View.size.height)) -- 75
	end -- 75
	return false -- 77
end) -- 65
return ____exports -- 65
-- [ts]: GltfModelProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 11
local App = ____Dora.App -- 11
local Camera3D = ____Dora.Camera3D -- 11
local Color = ____Dora.Color -- 11
local Color3 = ____Dora.Color3 -- 11
local Content = ____Dora.Content -- 11
local Director = ____Dora.Director -- 11
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 11
local Model3D = ____Dora.Model3D -- 11
local Path = ____Dora.Path -- 11
local Vec3 = ____Dora.Vec3 -- 11
local threadLoop = ____Dora.threadLoop -- 11
local resultDir = Path(Content.searchPaths[1], ".agent", "test-results") -- 13
if not Content:exist(resultDir) then -- 13
	Content:mkdir(resultDir) -- 14
end -- 14
local marker = Path(resultDir, "s3-gltf.txt") -- 15
local view = Director.entry -- 17
view:setEnvironmentIntensity(0.35, 0.35, 1) -- 18
local camera = Camera3D() -- 20
camera:lookAt( -- 21
	Vec3(0, 9, 19), -- 21
	Vec3(0, 0, 0) -- 21
) -- 21
Director:pushCamera(camera) -- 22
local light = DirectionalLight3D() -- 24
light.color = Color3(16774106) -- 25
light.intensity = 3.2 -- 26
light.angleX = -50 -- 27
light.angleY = 25 -- 28
view:addChild(light) -- 29
--- 文件名（不含扩展名）、染色、是否自发光。
local specs = { -- 32
	{name = "Planet_Earth", hex = 4882367, glow = false}, -- 33
	{name = "Planet_Mars", hex = 12670266, glow = false}, -- 34
	{name = "Planet_Venus", hex = 14262363, glow = false}, -- 35
	{name = "Planet_Neptune", hex = 4878297, glow = false}, -- 36
	{name = "Planet_Jupiter", hex = 14201994, glow = false}, -- 37
	{name = "Planet_Saturn", hex = 14270586, glow = false}, -- 38
	{name = "Sun", hex = 16765514, glow = true}, -- 39
	{name = "BlackHole", hex = 1315868, glow = false}, -- 40
	{name = "Asteroid_01", hex = 7039851, glow = false}, -- 41
	{name = "Probe_Voyager", hex = 14474460, glow = false}, -- 42
	{name = "Probe_Voyager_v1", hex = 14474460, glow = false} -- 43
} -- 43
local missing = {} -- 46
local detail = {} -- 47
local built = 0 -- 48
do -- 48
	local i = 0 -- 50
	while i < #specs do -- 50
		do -- 50
			local spec = specs[i + 1] -- 51
			local col = i % 4 -- 52
			local row = math.floor(i / 4) -- 53
			local model = Model3D(("Assets/Model/" .. spec.name) .. ".glb") -- 54
			if model == nil then -- 54
				missing[#missing + 1] = spec.name -- 56
				goto __continue4 -- 57
			end -- 57
			model.position = Vec3((col - 1.5) * 3.6, 0, (row - 1) * 3.6) -- 59
			local mats = 0 -- 62
			do -- 62
				local k = 0 -- 63
				while k < 12 do -- 63
					local mat = model:getMaterial(k) -- 64
					if mat == nil then -- 64
						break -- 65
					end -- 65
					mats = mats + 1 -- 66
					local r = math.floor(spec.hex / 65536) % 256 -- 67
					local g = math.floor(spec.hex / 256) % 256 -- 68
					local b = spec.hex % 256 -- 69
					mat.baseColor = Color(r, g, b, 255) -- 70
					if spec.glow then -- 70
						mat.emissive = Color3(16764006) -- 71
					end -- 71
					k = k + 1 -- 63
				end -- 63
			end -- 63
			detail[#detail + 1] = (spec.name .. ":mats=") .. __TS__NumberToFixed(mats, 0) -- 73
			view:addChild(model) -- 74
			built = built + 1 -- 75
		end -- 75
		::__continue4:: -- 75
		i = i + 1 -- 50
	end -- 50
end -- 50
local elapsed = 0 -- 78
local dumped = false -- 79
threadLoop(function() -- 80
	elapsed = elapsed + App.deltaTime -- 81
	if not dumped and elapsed > 1.5 then -- 81
		dumped = true -- 83
		local stats = view.stats -- 84
		local ok = #missing == 0 and stats.visibleVisuals >= built and built == #specs -- 85
		Content:save( -- 86
			marker, -- 87
			(((((((((((((("status=" .. (ok and "PASS" or "FAIL")) .. "\nbuilt=") .. __TS__NumberToFixed(built, 0)) .. "/") .. __TS__NumberToFixed(#specs, 0)) .. "\ndraws=") .. __TS__NumberToFixed(stats.drawCalls, 0)) .. "\nvisible=") .. __TS__NumberToFixed(stats.visibleVisuals, 0)) .. "\ntriangles=") .. __TS__NumberToFixed(stats.triangles, 0)) .. "\nmissing=") .. table.concat(missing, ",")) .. "\n") .. table.concat(detail, "\n") -- 88
		) -- 88
		App:saveScreenshot(Path(resultDir, "s3-gltf")) -- 96
	end -- 96
	return false -- 98
end) -- 80
return ____exports -- 80
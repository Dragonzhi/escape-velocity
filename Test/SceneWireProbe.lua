-- [ts]: SceneWireProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__StringReplace = ____lualib.__TS__StringReplace -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 10
local Camera3D = ____Dora.Camera3D -- 10
local Content = ____Dora.Content -- 10
local Director = ____Dora.Director -- 10
local Model3D = ____Dora.Model3D -- 10
local Node3D = ____Dora.Node3D -- 10
local Path = ____Dora.Path -- 10
local View = ____Dora.View -- 10
local threadLoop = ____Dora.threadLoop -- 10
local ____LevelData = require("game.LevelData") -- 11
local getLevel = ____LevelData.getLevel -- 11
local levelCount = ____LevelData.levelCount -- 11
local scaledPlanets = ____LevelData.scaledPlanets -- 11
local ____Scene = require("game.Scene") -- 12
local buildScene = ____Scene.buildScene -- 12
local ____CameraRig = require("game.CameraRig") -- 13
local createCameraRig = ____CameraRig.createCameraRig -- 13
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 13
local ____Gravity = require("game.Gravity") -- 14
local bodyPositionAt = ____Gravity.bodyPositionAt -- 14
local searchPaths = Content.searchPaths -- 16
local projRoot = searchPaths[1] -- 17
do -- 17
	local i = 0 -- 18
	while i < 8 do -- 18
		if i >= #searchPaths then -- 18
			break -- 19
		end -- 19
		local p = searchPaths[i + 1] -- 20
		if Content:exist(Path(p, "init.lua")) or Content:exist(Path(p, "init.ts")) then -- 20
			projRoot = p -- 21
			break -- 21
		end -- 21
		i = i + 1 -- 18
	end -- 18
end -- 18
local outDir = Path(projRoot, ".agent", "test-results") -- 23
if not Content:exist(outDir) then -- 23
	Content:mkdir(outDir) -- 24
end -- 24
local marker = Path(outDir, "s31-wire.txt") -- 25
local TRIS = { -- 29
	{name = "Planet_Earth", tris = 80}, -- 30
	{name = "Planet_Mars", tris = 80}, -- 30
	{name = "Planet_Venus", tris = 80}, -- 31
	{name = "Planet_Neptune", tris = 80}, -- 31
	{name = "Planet_Jupiter", tris = 320}, -- 32
	{name = "Planet_Saturn", tris = 464}, -- 32
	{name = "Probe_Voyager_v1", tris = 600}, -- 33
	{name = "Sphere.gltf", tris = 120}, -- 34
	{name = "Ring.gltf", tris = 16}, -- 34
	{name = "StarQuad.gltf", tris = 2} -- 35
} -- 35
local function triOf(name) -- 38
	do -- 38
		local i = 0 -- 39
		while i < #TRIS do -- 39
			if TRIS[i + 1].name == name then -- 39
				return TRIS[i + 1].tris -- 39
			end -- 39
			i = i + 1 -- 39
		end -- 39
	end -- 39
	return -1 -- 40
end -- 38
View.frustumCulling = false -- 48
local lines = {} -- 50
lines[#lines + 1] = "frustumCulling=false（否则画面外的行星不计入 stats）" -- 51
lines[#lines + 1] = (((("root=" .. projRoot) .. " view=") .. __TS__NumberToFixed(View.size.width, 0)) .. "x") .. __TS__NumberToFixed(View.size.height, 0) -- 52
lines[#lines + 1] = "file  planets(models)  expectedTris  measuredTris  draws  visibleVisuals  match" -- 53
Content:save( -- 54
	marker, -- 54
	table.concat(lines, "\n") -- 54
) -- 54
local total = levelCount() -- 56
local worlds = {} -- 57
local cams = {} -- 58
local rigs = {} -- 59
local expected = {} -- 60
local labels = {} -- 61
do -- 61
	local i = 0 -- 63
	while i < total do -- 63
		do -- 63
			local def = getLevel(i) -- 64
			if def == nil then -- 64
				goto __continue12 -- 65
			end -- 65
			local bodies = scaledPlanets(def) -- 66
			local world = Node3D() -- 67
			Director.entry:addChild(world) -- 68
			world.visible = false -- 69
			local scene = buildScene({ -- 70
				root = world, -- 71
				bodies = bodies, -- 72
				visuals = def.visuals, -- 73
				probeStart = def.probeStart, -- 74
				probeScale = 1.2, -- 75
				spherePath = "Assets/Model/Sphere.gltf", -- 76
				ringPath = "Assets/Model/Ring.gltf", -- 77
				probePath = "Assets/Model/Probe_Voyager_v1.glb" -- 78
			}) -- 78
			if scene == nil then -- 78
				lines[#lines + 1] = ("L" .. __TS__NumberToFixed(i + 1, 0)) .. " SCENE_FAILED" -- 81
				Content:save( -- 82
					marker, -- 82
					table.concat(lines, "\n") -- 82
				) -- 82
				goto __continue12 -- 83
			end -- 83
			worlds[#worlds + 1] = world -- 85
			local exp = triOf("Probe_Voyager_v1") + triOf("StarQuad.gltf") -- 88
			local names = {} -- 89
			do -- 89
				local k = 0 -- 90
				while k < #def.visuals do -- 90
					local m = def.visuals[k + 1].model -- 91
					if m ~= nil and m ~= "" then -- 91
						exp = exp + triOf(m) -- 92
						names[#names + 1] = m -- 92
					else -- 92
						exp = exp + triOf("Sphere.gltf") -- 93
						if def.visuals[k + 1].ring then -- 93
							exp = exp + triOf("Ring.gltf") -- 93
						end -- 93
						names[#names + 1] = "sphere" .. (def.visuals[k + 1].ring and "+ring" or "") -- 93
					end -- 93
					k = k + 1 -- 90
				end -- 90
			end -- 90
			expected[#expected + 1] = exp -- 95
			labels[#labels + 1] = ((("L" .. __TS__NumberToFixed(i + 1, 0)) .. " [") .. table.concat(names, "+")) .. "]" -- 96
			local rig = createCameraRig(defaultRigOptions()) -- 99
			local camera = Camera3D() -- 100
			cams[#cams + 1] = camera -- 101
			local poses = {} -- 102
			local t = 0 -- 103
			do -- 103
				local b = 0 -- 104
				while b < #bodies do -- 104
					poses[#poses + 1] = bodyPositionAt(bodies[b + 1], t) -- 104
					b = b + 1 -- 104
				end -- 104
			end -- 104
			rigs[#rigs + 1] = {index = i, poses = poses} -- 105
			scene.syncBodies(0) -- 106
			scene.syncProbe(def.probeStart) -- 107
			local frame = rig.step( -- 108
				{ -- 108
					def.probeStart, -- 108
					table.unpack(poses) -- 108
				}, -- 108
				2.13 -- 108
			) -- 108
			rig.apply(camera, frame) -- 109
			scene.syncBackdrop(frame.eye, frame.target) -- 110
		end -- 110
		::__continue12:: -- 110
		i = i + 1 -- 63
	end -- 63
end -- 63
lines[#lines + 1] = (("worlds=" .. __TS__NumberToFixed(#worlds, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 113
Content:save( -- 114
	marker, -- 114
	table.concat(lines, "\n") -- 114
) -- 114
--- 逐个资产单独放一个场景：用来确认“每关固定多出来的三角面”是不是常数开销。
local assetFiles = { -- 117
	"Planet_Mars.glb", -- 118
	"Planet_Venus.glb", -- 118
	"Planet_Jupiter.glb", -- 118
	"Planet_Saturn.glb", -- 118
	"Planet_Neptune.glb", -- 118
	"Probe_Voyager_v1.glb", -- 119
	"Probe.gltf", -- 119
	"Sphere.gltf", -- 119
	"Ring.gltf", -- 119
	"StarQuad.gltf" -- 119
} -- 119
local assetNodes = {} -- 121
do -- 121
	local i = 0 -- 122
	while i < #assetFiles do -- 122
		do -- 122
			local m = Model3D((string.find(assetFiles[i + 1], ".glb", nil, true) or 0) - 1 > 0 and "Assets/Model/" .. assetFiles[i + 1] or "Assets/Model/" .. assetFiles[i + 1]) -- 123
			if m == nil then -- 123
				lines[#lines + 1] = "ASSET_FAIL " .. assetFiles[i + 1] -- 124
				goto __continue23 -- 124
			end -- 124
			m.visible = false -- 125
			Director.entry:addChild(m) -- 126
			assetNodes[#assetNodes + 1] = m -- 127
		end -- 127
		::__continue23:: -- 127
		i = i + 1 -- 122
	end -- 122
end -- 122
lines[#lines + 1] = (("assetNodes=" .. __TS__NumberToFixed(#assetNodes, 0)) .. "/") .. __TS__NumberToFixed(#assetFiles, 0) -- 129
Content:save( -- 130
	marker, -- 130
	table.concat(lines, "\n") -- 130
) -- 130
local cursor = 0 -- 132
local settle = 0 -- 133
local settle2 = 0 -- 134
local phase = 0 -- 135
threadLoop(function() -- 137
	if phase == 2 then -- 137
		if settle2 == 0 then -- 137
			do -- 137
				local i = 0 -- 140
				while i < #worlds do -- 140
					worlds[i + 1].visible = false -- 140
					i = i + 1 -- 140
				end -- 140
			end -- 140
			do -- 140
				local i = 0 -- 141
				while i < #assetNodes do -- 141
					assetNodes[i + 1].visible = i == cursor -- 141
					i = i + 1 -- 141
				end -- 141
			end -- 141
			settle2 = 1 -- 142
			return false -- 143
		end -- 143
		settle2 = settle2 + 1 -- 145
		if settle2 < 15 then -- 145
			return false -- 146
		end -- 146
		settle2 = 0 -- 147
		local st2 = Director.entry.stats -- 148
		local bare = __TS__StringReplace(assetFiles[cursor + 1], ".glb", "") -- 149
		lines[#lines + 1] = (((((((("ASSET " .. assetFiles[cursor + 1]) .. "  measuredTris=") .. __TS__NumberToFixed(st2.triangles, 0)) .. "  expected=") .. __TS__NumberToFixed( -- 150
			triOf(bare), -- 151
			0 -- 151
		)) .. "  draws=") .. __TS__NumberToFixed(st2.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(st2.visibleVisuals, 0) -- 151
		Content:save( -- 153
			marker, -- 153
			table.concat(lines, "\n") -- 153
		) -- 153
		cursor = cursor + 1 -- 154
		if cursor >= #assetNodes then -- 154
			lines[#lines + 1] = "RESULT=PASS" -- 156
			Content:save( -- 157
				marker, -- 157
				table.concat(lines, "\n") -- 157
			) -- 157
			return true -- 158
		end -- 158
		return false -- 160
	end -- 160
	if phase == 0 then -- 160
		do -- 160
			local i = 0 -- 163
			while i < #worlds do -- 163
				worlds[i + 1].visible = i == cursor -- 163
				i = i + 1 -- 163
			end -- 163
		end -- 163
		if cursor < #cams then -- 163
			Director:pushCamera(cams[cursor + 1]) -- 165
		end -- 165
		phase = 1 -- 166
		settle = 0 -- 167
		return false -- 168
	end -- 168
	settle = settle + 1 -- 170
	if settle < 30 then -- 170
		return false -- 172
	end -- 172
	local stats = Director.entry.stats -- 173
	local exp = expected[cursor + 1] -- 174
	local got = stats.triangles -- 175
	lines[#lines + 1] = (((((((((labels[cursor + 1] .. "  expected=") .. __TS__NumberToFixed(exp, 0)) .. "  measured=") .. __TS__NumberToFixed(got, 0)) .. "  draws=") .. __TS__NumberToFixed(stats.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(stats.visibleVisuals, 0)) .. "  match=") .. tostring(exp == got) -- 176
	Content:save( -- 179
		marker, -- 179
		table.concat(lines, "\n") -- 179
	) -- 179
	cursor = cursor + 1 -- 180
	if cursor >= #worlds then -- 180
		phase = 2 -- 182
		cursor = 0 -- 183
		return false -- 184
	end -- 184
	phase = 0 -- 186
	return false -- 187
end) -- 137
return ____exports -- 137
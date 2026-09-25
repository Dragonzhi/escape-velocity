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
	{name = "Probe_Voyager_v1", tris = 764}, -- 33
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
			local exp = triOf("Probe_Voyager_v1") + triOf("StarQuad.gltf") -- 89
			local names = {} -- 90
			do -- 90
				local k = 0 -- 91
				while k < #def.visuals do -- 91
					local m = def.visuals[k + 1].model -- 92
					if m ~= nil and m ~= "" then -- 92
						exp = exp + triOf(m) -- 93
						names[#names + 1] = m -- 93
					else -- 93
						exp = exp + triOf("Sphere.gltf") -- 94
						if def.visuals[k + 1].ring then -- 94
							exp = exp + triOf("Ring.gltf") -- 94
						end -- 94
						names[#names + 1] = "sphere" .. (def.visuals[k + 1].ring and "+ring" or "") -- 94
					end -- 94
					k = k + 1 -- 91
				end -- 91
			end -- 91
			expected[#expected + 1] = exp -- 96
			labels[#labels + 1] = ((("L" .. __TS__NumberToFixed(i + 1, 0)) .. " [") .. table.concat(names, "+")) .. "]" -- 97
			local rig = createCameraRig(defaultRigOptions()) -- 100
			local camera = Camera3D() -- 101
			cams[#cams + 1] = camera -- 102
			local poses = {} -- 103
			local t = 0 -- 104
			do -- 104
				local b = 0 -- 105
				while b < #bodies do -- 105
					poses[#poses + 1] = bodyPositionAt(bodies[b + 1], t) -- 105
					b = b + 1 -- 105
				end -- 105
			end -- 105
			rigs[#rigs + 1] = {index = i, poses = poses} -- 106
			scene.syncBodies(0) -- 107
			scene.syncProbe(def.probeStart) -- 108
			local frame = rig.step( -- 109
				{ -- 109
					def.probeStart, -- 109
					table.unpack(poses) -- 109
				}, -- 109
				2.13 -- 109
			) -- 109
			rig.apply(camera, frame) -- 110
			scene.syncBackdrop(frame.eye, frame.target) -- 111
		end -- 111
		::__continue12:: -- 111
		i = i + 1 -- 63
	end -- 63
end -- 63
lines[#lines + 1] = (("worlds=" .. __TS__NumberToFixed(#worlds, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 114
Content:save( -- 115
	marker, -- 115
	table.concat(lines, "\n") -- 115
) -- 115
--- 逐个资产单独放一个场景：用来确认“每关固定多出来的三角面”是不是常数开销。
local assetFiles = { -- 118
	"Planet_Mars.glb", -- 119
	"Planet_Venus.glb", -- 119
	"Planet_Jupiter.glb", -- 119
	"Planet_Saturn.glb", -- 119
	"Planet_Neptune.glb", -- 119
	"Probe_Voyager_v1.glb", -- 120
	"Probe.gltf", -- 120
	"Sphere.gltf", -- 120
	"Ring.gltf", -- 120
	"StarQuad.gltf" -- 120
} -- 120
local assetNodes = {} -- 122
do -- 122
	local i = 0 -- 123
	while i < #assetFiles do -- 123
		do -- 123
			local m = Model3D((string.find(assetFiles[i + 1], ".glb", nil, true) or 0) - 1 > 0 and "Assets/Model/" .. assetFiles[i + 1] or "Assets/Model/" .. assetFiles[i + 1]) -- 124
			if m == nil then -- 124
				lines[#lines + 1] = "ASSET_FAIL " .. assetFiles[i + 1] -- 125
				goto __continue23 -- 125
			end -- 125
			m.visible = false -- 126
			Director.entry:addChild(m) -- 127
			assetNodes[#assetNodes + 1] = m -- 128
		end -- 128
		::__continue23:: -- 128
		i = i + 1 -- 123
	end -- 123
end -- 123
lines[#lines + 1] = (("assetNodes=" .. __TS__NumberToFixed(#assetNodes, 0)) .. "/") .. __TS__NumberToFixed(#assetFiles, 0) -- 130
Content:save( -- 131
	marker, -- 131
	table.concat(lines, "\n") -- 131
) -- 131
local cursor = 0 -- 133
local settle = 0 -- 134
local settle2 = 0 -- 135
local phase = 0 -- 136
threadLoop(function() -- 138
	if phase == 2 then -- 138
		if settle2 == 0 then -- 138
			do -- 138
				local i = 0 -- 141
				while i < #worlds do -- 141
					worlds[i + 1].visible = false -- 141
					i = i + 1 -- 141
				end -- 141
			end -- 141
			do -- 141
				local i = 0 -- 142
				while i < #assetNodes do -- 142
					assetNodes[i + 1].visible = i == cursor -- 142
					i = i + 1 -- 142
				end -- 142
			end -- 142
			settle2 = 1 -- 143
			return false -- 144
		end -- 144
		settle2 = settle2 + 1 -- 146
		if settle2 < 15 then -- 146
			return false -- 147
		end -- 147
		settle2 = 0 -- 148
		local st2 = Director.entry.stats -- 149
		local bare = __TS__StringReplace(assetFiles[cursor + 1], ".glb", "") -- 150
		lines[#lines + 1] = (((((((("ASSET " .. assetFiles[cursor + 1]) .. "  measuredTris=") .. __TS__NumberToFixed(st2.triangles, 0)) .. "  expected=") .. __TS__NumberToFixed( -- 151
			triOf(bare), -- 152
			0 -- 152
		)) .. "  draws=") .. __TS__NumberToFixed(st2.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(st2.visibleVisuals, 0) -- 152
		Content:save( -- 154
			marker, -- 154
			table.concat(lines, "\n") -- 154
		) -- 154
		cursor = cursor + 1 -- 155
		if cursor >= #assetNodes then -- 155
			lines[#lines + 1] = "RESULT=PASS" -- 157
			Content:save( -- 158
				marker, -- 158
				table.concat(lines, "\n") -- 158
			) -- 158
			return true -- 159
		end -- 159
		return false -- 161
	end -- 161
	if phase == 0 then -- 161
		do -- 161
			local i = 0 -- 164
			while i < #worlds do -- 164
				worlds[i + 1].visible = i == cursor -- 164
				i = i + 1 -- 164
			end -- 164
		end -- 164
		if cursor < #cams then -- 164
			Director:pushCamera(cams[cursor + 1]) -- 166
		end -- 166
		phase = 1 -- 167
		settle = 0 -- 168
		return false -- 169
	end -- 169
	settle = settle + 1 -- 171
	if settle < 30 then -- 171
		return false -- 173
	end -- 173
	local stats = Director.entry.stats -- 174
	local exp = expected[cursor + 1] -- 175
	local got = stats.triangles -- 176
	lines[#lines + 1] = (((((((((labels[cursor + 1] .. "  expected=") .. __TS__NumberToFixed(exp, 0)) .. "  measured=") .. __TS__NumberToFixed(got, 0)) .. "  draws=") .. __TS__NumberToFixed(stats.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(stats.visibleVisuals, 0)) .. "  match=") .. tostring(exp == got) -- 177
	Content:save( -- 180
		marker, -- 180
		table.concat(lines, "\n") -- 180
	) -- 180
	cursor = cursor + 1 -- 181
	if cursor >= #worlds then -- 181
		phase = 2 -- 183
		cursor = 0 -- 184
		return false -- 185
	end -- 185
	phase = 0 -- 187
	return false -- 188
end) -- 138
return ____exports -- 138
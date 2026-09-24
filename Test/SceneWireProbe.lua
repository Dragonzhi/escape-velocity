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
	{name = "StarShell.gltf", tris = 1800}, -- 35
	{name = "StarShellBright.gltf", tris = 140} -- 35
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
			local exp = triOf("Probe_Voyager_v1") + triOf("StarShell.gltf") + triOf("StarShellBright.gltf") -- 88
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
			local frame = rig.step({ -- 108
				def.probeStart, -- 108
				table.unpack(poses) -- 108
			}) -- 108
			rig.apply(camera, frame) -- 109
		end -- 109
		::__continue12:: -- 109
		i = i + 1 -- 63
	end -- 63
end -- 63
lines[#lines + 1] = (("worlds=" .. __TS__NumberToFixed(#worlds, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 112
Content:save( -- 113
	marker, -- 113
	table.concat(lines, "\n") -- 113
) -- 113
--- 逐个资产单独放一个场景：用来确认“每关固定多出来的三角面”是不是常数开销。
local assetFiles = { -- 116
	"Planet_Mars.glb", -- 117
	"Planet_Venus.glb", -- 117
	"Planet_Jupiter.glb", -- 117
	"Planet_Saturn.glb", -- 117
	"Planet_Neptune.glb", -- 117
	"Probe_Voyager_v1.glb", -- 118
	"Probe.gltf", -- 118
	"Sphere.gltf", -- 118
	"Ring.gltf", -- 118
	"StarShell.gltf", -- 118
	"StarShellBright.gltf" -- 118
} -- 118
local assetNodes = {} -- 120
do -- 120
	local i = 0 -- 121
	while i < #assetFiles do -- 121
		do -- 121
			local m = Model3D((string.find(assetFiles[i + 1], ".glb", nil, true) or 0) - 1 > 0 and "Assets/Model/" .. assetFiles[i + 1] or "Assets/Model/" .. assetFiles[i + 1]) -- 122
			if m == nil then -- 122
				lines[#lines + 1] = "ASSET_FAIL " .. assetFiles[i + 1] -- 123
				goto __continue23 -- 123
			end -- 123
			m.visible = false -- 124
			Director.entry:addChild(m) -- 125
			assetNodes[#assetNodes + 1] = m -- 126
		end -- 126
		::__continue23:: -- 126
		i = i + 1 -- 121
	end -- 121
end -- 121
lines[#lines + 1] = (("assetNodes=" .. __TS__NumberToFixed(#assetNodes, 0)) .. "/") .. __TS__NumberToFixed(#assetFiles, 0) -- 128
Content:save( -- 129
	marker, -- 129
	table.concat(lines, "\n") -- 129
) -- 129
local cursor = 0 -- 131
local settle = 0 -- 132
local settle2 = 0 -- 133
local phase = 0 -- 134
threadLoop(function() -- 136
	if phase == 2 then -- 136
		if settle2 == 0 then -- 136
			do -- 136
				local i = 0 -- 139
				while i < #worlds do -- 139
					worlds[i + 1].visible = false -- 139
					i = i + 1 -- 139
				end -- 139
			end -- 139
			do -- 139
				local i = 0 -- 140
				while i < #assetNodes do -- 140
					assetNodes[i + 1].visible = i == cursor -- 140
					i = i + 1 -- 140
				end -- 140
			end -- 140
			settle2 = 1 -- 141
			return false -- 142
		end -- 142
		settle2 = settle2 + 1 -- 144
		if settle2 < 15 then -- 144
			return false -- 145
		end -- 145
		settle2 = 0 -- 146
		local st2 = Director.entry.stats -- 147
		local bare = __TS__StringReplace(assetFiles[cursor + 1], ".glb", "") -- 148
		lines[#lines + 1] = (((((((("ASSET " .. assetFiles[cursor + 1]) .. "  measuredTris=") .. __TS__NumberToFixed(st2.triangles, 0)) .. "  expected=") .. __TS__NumberToFixed( -- 149
			triOf(bare), -- 150
			0 -- 150
		)) .. "  draws=") .. __TS__NumberToFixed(st2.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(st2.visibleVisuals, 0) -- 150
		Content:save( -- 152
			marker, -- 152
			table.concat(lines, "\n") -- 152
		) -- 152
		cursor = cursor + 1 -- 153
		if cursor >= #assetNodes then -- 153
			lines[#lines + 1] = "RESULT=PASS" -- 155
			Content:save( -- 156
				marker, -- 156
				table.concat(lines, "\n") -- 156
			) -- 156
			return true -- 157
		end -- 157
		return false -- 159
	end -- 159
	if phase == 0 then -- 159
		do -- 159
			local i = 0 -- 162
			while i < #worlds do -- 162
				worlds[i + 1].visible = i == cursor -- 162
				i = i + 1 -- 162
			end -- 162
		end -- 162
		if cursor < #cams then -- 162
			Director:pushCamera(cams[cursor + 1]) -- 164
		end -- 164
		phase = 1 -- 165
		settle = 0 -- 166
		return false -- 167
	end -- 167
	settle = settle + 1 -- 169
	if settle < 30 then -- 169
		return false -- 171
	end -- 171
	local stats = Director.entry.stats -- 172
	local exp = expected[cursor + 1] -- 173
	local got = stats.triangles -- 174
	lines[#lines + 1] = (((((((((labels[cursor + 1] .. "  expected=") .. __TS__NumberToFixed(exp, 0)) .. "  measured=") .. __TS__NumberToFixed(got, 0)) .. "  draws=") .. __TS__NumberToFixed(stats.drawCalls, 0)) .. "  visible=") .. __TS__NumberToFixed(stats.visibleVisuals, 0)) .. "  match=") .. tostring(exp == got) -- 175
	Content:save( -- 178
		marker, -- 178
		table.concat(lines, "\n") -- 178
	) -- 178
	cursor = cursor + 1 -- 179
	if cursor >= #worlds then -- 179
		phase = 2 -- 181
		cursor = 0 -- 182
		return false -- 183
	end -- 183
	phase = 0 -- 185
	return false -- 186
end) -- 136
return ____exports -- 136
-- [ts]: ClipPlaneProbe.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 16
local App = ____Dora.App -- 16
local Camera3D = ____Dora.Camera3D -- 16
local Content = ____Dora.Content -- 16
local Director = ____Dora.Director -- 16
local Node3D = ____Dora.Node3D -- 16
local Path = ____Dora.Path -- 16
local Vec3 = ____Dora.Vec3 -- 16
local View = ____Dora.View -- 16
local threadLoop = ____Dora.threadLoop -- 16
local ____LevelData = require("game.LevelData") -- 17
local getLevel = ____LevelData.getLevel -- 17
local scaledPlanets = ____LevelData.scaledPlanets -- 17
local ____Scene = require("game.Scene") -- 18
local buildScene = ____Scene.buildScene -- 18
local planeToWorld = ____Scene.planeToWorld -- 18
local ____Vision = require("Test.Vision") -- 19
local parseTga = ____Vision.parseTga -- 19
local rgbAt = ____Vision.rgbAt -- 19
local ____Tuning = require("game.Tuning") -- 20
local levelRuntime = ____Tuning.levelRuntime -- 20
local function dumpTree(rawNode, depth, out) -- 32
	local node = rawNode -- 34
	local kids = node.children -- 35
	if kids == nil then -- 35
		return -- 36
	end -- 36
	local pad = "" -- 37
	do -- 37
		local i = 0 -- 38
		while i < depth do -- 38
			pad = pad .. "  " -- 38
			i = i + 1 -- 38
		end -- 38
	end -- 38
	local n = kids.count -- 39
	do -- 39
		local i = 0 -- 40
		while i < n do -- 40
			local c = kids:get(i + 1) -- 41
			local gc = c.children ~= nil and c.children.count or 0 -- 42
			out[#out + 1] = (((((((((((((pad .. "-") .. __TS__NumberToFixed(i, 0)) .. " pos=(") .. __TS__NumberToFixed(c.position.x, 4)) .. ",") .. __TS__NumberToFixed(c.position.y, 4)) .. ",") .. __TS__NumberToFixed(c.position.z, 4)) .. ") scale=") .. __TS__NumberToFixed(c.scale.x, 6)) .. " visible=") .. tostring(c.visible and 1 or 0)) .. " kids=") .. __TS__NumberToFixed(gc, 0) -- 43
			if depth < 2 then -- 43
				dumpTree(c, depth + 1, out) -- 45
			end -- 45
			i = i + 1 -- 40
		end -- 40
	end -- 40
end -- 32
--- 每张图的背景均值（按变体顺序），最后用来出判定。
local bgMeans = {} -- 58
--- 报告一张截图的**上带**颜色。
-- 
-- 取样区 = 横向 2%~98%、纵向 4.5%~14%（y ≈ 62~193）：
-- 这一段在 L1 贴地球机位里一定**在地球盘面之上**（地球盘面的上缘在 y ≈ 240），
-- 所以它读到的就是"背景"本身 —— 那块灰正是出现在这里（旧取样区落在盘面上，读成了地球的颜色）。
local function analyze(shotPath, v) -- 67
	local out = {} -- 68
	out[#out + 1] = ((((((("--- " .. v.label) .. " (near=") .. tostring(v.near)) .. " far=") .. tostring(v.far)) .. " hide=") .. v.hide) .. ") ---"
	if not Content:exist(shotPath) then -- 69
		out[#out + 1] = "  VISION FAILED: not found " .. shotPath -- 71
		return out -- 72
	end -- 72
	local img = parseTga(Content:load(shotPath)) -- 74
	if img == nil then -- 74
		out[#out + 1] = "  VISION FAILED: unsupported TGA" -- 76
		return out -- 77
	end -- 77
	local r = 0 -- 79
	local g = 0 -- 79
	local b = 0 -- 79
	local n = 0 -- 79
	local x0 = math.floor(img.width * 0.02) -- 80
	local x1 = math.floor(img.width * 0.98) -- 81
	local y0 = math.floor(img.height * 0.045) -- 82
	local y1 = math.floor(img.height * 0.14) -- 83
	do -- 83
		local y = y0 -- 84
		while y < y1 do -- 84
			do -- 84
				local x = x0 -- 85
				while x < x1 do -- 85
					local c = rgbAt(img, x, y) -- 86
					r = r + c[1] -- 87
					g = g + c[2] -- 87
					b = b + c[3] -- 87
					n = n + 1 -- 87
					x = x + 7 -- 85
				end -- 85
			end -- 85
			y = y + 7 -- 84
		end -- 84
	end -- 84
	local cx = rgbAt( -- 90
		img, -- 90
		math.floor(img.width / 2), -- 90
		math.floor(img.height / 2) -- 90
	) -- 90
	local mean = (r + g + b) / 3 / n -- 91
	bgMeans[#bgMeans + 1] = mean -- 92
	out[#out + 1] = (((((((((((((((("  size=" .. __TS__NumberToFixed(img.width, 0)) .. "x") .. __TS__NumberToFixed(img.height, 0)) .. " bgMean=(") .. __TS__NumberToFixed(r / n, 1)) .. ",") .. __TS__NumberToFixed(g / n, 1)) .. ",") .. __TS__NumberToFixed(b / n, 1)) .. ")") .. " center=(") .. __TS__NumberToFixed(cx[1], 0)) .. ",") .. __TS__NumberToFixed(cx[2], 0)) .. ",") .. __TS__NumberToFixed(cx[3], 0)) .. ")" -- 93
	return out -- 96
end -- 67
--- 项目根：单文件入口下 `Content.searchPaths[0]` 是 `<proj>/Test`（AGENTS 的"搜索根陷阱"）——
-- 上跳一级才是项目根，否则标记文件会写进 `Test/.agent/...`（曾经踩过）。
local function findRoot() -- 103
	local sp0 = Content.searchPaths[1] -- 104
	if sp0 ~= nil then -- 104
		local up = Path(sp0, "..") -- 106
		if Content:exist(Path(up, "game", "Scene.lua")) then -- 106
			return up -- 107
		end -- 107
		if Content:exist(Path(sp0, "game", "Scene.lua")) then -- 107
			return sp0 -- 108
		end -- 108
	end -- 108
	return Path(Content.writablePath, "escape-velocity") -- 110
end -- 103
local root = findRoot() -- 113
local outDir = Path(root, ".agent", "test-results") -- 114
if not Content:exist(outDir) then -- 114
	Content:mkdir(outDir) -- 115
end -- 115
local marker = Path(outDir, "clip-probe.txt") -- 116
local lines = {} -- 118
local function flush(final) -- 119
	Content:save( -- 120
		marker, -- 120
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 120
	) -- 120
end -- 119
lines[#lines + 1] = "phase=started" -- 122
flush(false) -- 123
lines[#lines + 1] = (((((((((("engine defaults: near=" .. tostring(View.nearPlaneDistance)) .. " far=") .. tostring(View.farPlaneDistance)) .. " fov=") .. tostring(View.fieldOfView)) .. " aspect=") .. __TS__NumberToFixed(View.aspectRatio, 4)) .. " standardDistance=") .. tostring(View.standardDistance)) .. " frustumCulling=") .. tostring(View.frustumCulling and 1 or 0) -- 126
lines[#lines + 1] = (("sky sphere exists: " .. tostring(Content:exist("Assets/Model/StarSphere.gltf") and 1 or 0)) .. " ; sky quad exists: ") .. tostring(Content:exist("Assets/Model/StarQuad.gltf") and 1 or 0) -- 129
flush(false) -- 131
local def = getLevel(0) -- 133
if def == nil then -- 133
	lines[#lines + 1] = "RESULT=FAIL reason=no-level-1" -- 135
	flush(true) -- 136
else -- 136
	local bodies = scaledPlanets(def) -- 138
	local world = Node3D() -- 139
	Director.entry:addChild(world) -- 140
	local rtg = def.probeVariant == "rtg" -- 141
	local scene = buildScene({ -- 142
		root = world, -- 143
		bodies = bodies, -- 144
		visuals = def.visuals, -- 145
		probeStart = def.probeStart, -- 146
		probeScale = levelRuntime(0).probeVisualRadius, -- 147
		spherePath = "Assets/Model/Sphere.gltf", -- 148
		ringPath = "Assets/Model/Ring.gltf", -- 149
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 150
		probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 151
		probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 152
		probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 153
		probeBodyRadius = rtg and 0.871 or 1.084, -- 154
		probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 155
		orbitFlowDots = levelRuntime(0).orbitFlowDots, -- 158
		orbitRings = levelRuntime(0).orbitRings -- 159
	}) -- 159
	flush(false) -- 161
	if scene == nil then -- 161
		lines[#lines + 1] = "RESULT=FAIL reason=scene-build-failed" -- 164
		flush(true) -- 165
	else -- 165
		lines[#lines + 1] = "scene built; probeRadius=" .. tostring(scene.probeRadius) -- 167
		do -- 167
			local i = 0 -- 168
			while i < #def.visuals do -- 168
				local ____temp_1 = ("  body " .. __TS__NumberToFixed(i, 0)) .. " model=" -- 169
				local ____temp_0 -- 169
				if def.visuals[i + 1].model ~= nil then -- 169
					____temp_0 = def.visuals[i + 1].model -- 169
				else -- 169
					____temp_0 = "?" -- 169
				end -- 169
				lines[#lines + 1] = ((((____temp_1 .. tostring(____temp_0)) .. " displayRadius=") .. tostring(def.visuals[i + 1].displayRadius)) .. " orbitRadius=") .. __TS__NumberToFixed(bodies[i + 1].orbitRadius, 6) -- 169
				i = i + 1 -- 168
			end -- 168
		end -- 168
		flush(false) -- 173
		local camera = Camera3D() -- 175
		Director:pushCamera(camera) -- 176
		local target = planeToWorld({x = 0, y = 80}, 0) -- 179
		local dist = 0.01264 -- 180
		local tilt = 22 * math.pi / 180 -- 181
		local eye = Vec3( -- 182
			target.x, -- 182
			target.y + math.sin(tilt) * dist, -- 182
			target.z + math.cos(tilt) * dist -- 182
		) -- 182
		camera:lookAt( -- 183
			eye, -- 183
			target, -- 183
			Vec3(0, 1, 0) -- 183
		) -- 183
		scene.syncBodies(0) -- 184
		scene.syncProbe({x = 0, y = 80.003514}) -- 187
		scene.syncBackdrop(eye, target) -- 188
		local nearOpt = levelRuntime(0).cameraNear -- 191
		local shippedNear = nearOpt ~= nil and nearOpt > 0 and nearOpt or 0.1 -- 192
		local variants = {{label = "base(发布配置)", near = shippedNear, far = 10000, hide = "none"}, {label = "only-sky", near = shippedNear, far = 10000, hide = "all"}, {label = "world-off", near = shippedNear, far = 10000, hide = "world"}, {label = "engine-near0.1", near = 0.1, far = 10000, hide = "none"}} -- 193
		--- 把节点恢复成全部可见，再按变体藏指定的那一个。
		local function applyHide(what) -- 200
			world.visible = true -- 201
			do -- 201
				local i = 0 -- 202
				while i < #scene.planets do -- 202
					scene.planets[i + 1].body.visible = true -- 202
					i = i + 1 -- 202
				end -- 202
			end -- 202
			scene.probe.visible = true -- 203
			if what == "world" then -- 203
				world.visible = false -- 204
				return -- 204
			end -- 204
			if what == "probe" then -- 204
				scene.probe.visible = false -- 205
				return -- 205
			end -- 205
			if what == "all" then -- 205
				do -- 205
					local i = 0 -- 207
					while i < #scene.planets do -- 207
						scene.planets[i + 1].body.visible = false -- 207
						i = i + 1 -- 207
					end -- 207
				end -- 207
				scene.probe.visible = false -- 208
				return -- 209
			end -- 209
			if what == "sun" then -- 209
				scene.planets[1].body.visible = false -- 211
			elseif what == "earth" then -- 211
				scene.planets[2].body.visible = false -- 212
			elseif what == "moon" then -- 212
				scene.planets[3].body.visible = false -- 213
			end -- 213
		end -- 200
		do -- 200
			local i = 0 -- 216
			while i < #scene.planets do -- 216
				local n = scene.planets[i + 1].body -- 217
				lines[#lines + 1] = (((((((((("  node[" .. __TS__NumberToFixed(i, 0)) .. "] pos=(") .. __TS__NumberToFixed(n.position.x, 4)) .. ",") .. __TS__NumberToFixed(n.position.y, 4)) .. ",") .. __TS__NumberToFixed(n.position.z, 4)) .. ") scale=") .. __TS__NumberToFixed(n.scale.x, 6)) .. " visible=") .. tostring(n.visible and 1 or 0) -- 218
				i = i + 1 -- 216
			end -- 216
		end -- 216
		lines[#lines + 1] = (((((("  probe pos=(" .. __TS__NumberToFixed(scene.probe.position.x, 4)) .. ",") .. __TS__NumberToFixed(scene.probe.position.y, 4)) .. ",") .. __TS__NumberToFixed(scene.probe.position.z, 4)) .. ") scale=") .. __TS__NumberToFixed(scene.probe.scale.x, 8) -- 221
		lines[#lines + 1] = "--- scene tree under world ---"
		local tree = {} -- 226
		dumpTree(world, 0, tree) -- 227
		for ____, t in ipairs(tree) do -- 228
			lines[#lines + 1] = t -- 228
		end -- 228
		flush(false) -- 229
		local shots = {} -- 230
		local FramesPerVariant = 24 -- 231
		local frame = 0 -- 232
		lines[#lines + 1] = (("variants=" .. __TS__NumberToFixed(#variants, 0)) .. " framesPerVariant=") .. __TS__NumberToFixed(FramesPerVariant, 0) -- 234
		flush(false) -- 235
		threadLoop(function() -- 237
			local vi = math.floor(frame / FramesPerVariant) -- 238
			if vi >= #variants then -- 238
				local report = {} -- 240
				do -- 240
					local i = 0 -- 241
					while i < #shots do -- 241
						local part = analyze(shots[i + 1], variants[i + 1]) -- 242
						for ____, l in ipairs(part) do -- 243
							report[#report + 1] = l -- 243
						end -- 243
						i = i + 1 -- 241
					end -- 241
				end -- 241
				lines[#lines + 1] = "" -- 245
				for ____, l in ipairs(report) do -- 246
					lines[#lines + 1] = l -- 246
				end -- 246
				local baseBg = #bgMeans > 0 and bgMeans[1] or -1 -- 250
				local nearBg = #bgMeans > 3 and bgMeans[4] or -1 -- 251
				local clearBg = #bgMeans > 2 and bgMeans[3] or -1 -- 252
				local ok = baseBg >= 0 and baseBg < 45 and nearBg < 45 and clearBg > 20 and clearBg < 32 -- 256
				lines[#lines + 1] = "" -- 257
				lines[#lines + 1] = ((((((("VERDICT baseBg=" .. __TS__NumberToFixed(baseBg, 1)) .. " (要 < 45 = 无灰带)") .. " engineNear0.1Bg=") .. __TS__NumberToFixed(nearBg, 1)) .. " (要 < 45 = 暗背景)") .. " clearColorBg=") .. __TS__NumberToFixed(clearBg, 1)) .. " (要 ≈ 26 = 引擎清屏色)" -- 258
				lines[#lines + 1] = "RESULT=" .. (ok and "PASS" or "FAIL") -- 261
				flush(true) -- 262
				return true -- 263
			end -- 263
			local ____local = frame % FramesPerVariant -- 265
			local v = variants[vi + 1] -- 266
			if ____local == 0 then -- 266
				View.nearPlaneDistance = v.near -- 268
				View.farPlaneDistance = v.far -- 269
				applyHide(v.hide) -- 270
				scene.syncBackdrop(eye, target) -- 271
				lines[#lines + 1] = (("variant " .. v.label) .. " applied at frame ") .. __TS__NumberToFixed(frame, 0) -- 272
				flush(false) -- 273
			elseif ____local == 4 then -- 273
				shots[#shots + 1] = App:saveScreenshot(Path( -- 275
					outDir, -- 275
					"clip-" .. __TS__NumberToFixed(vi, 0) -- 275
				)) -- 275
			end -- 275
			frame = frame + 1 -- 277
			return false -- 278
		end) -- 237
	end -- 237
end -- 237
return ____exports -- 237
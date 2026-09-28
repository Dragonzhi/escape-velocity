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
--- 递归打印节点树（位置/缩放/可见性）—— 认"那块灰"用。
-- 
-- ⚠️ 参数用 `any`：`children` 在 d.ts 里挂在 `Node` 上，而 `Node3D` 的声明里没有它
-- （`Node` 的 position 又是 Vec2，强转会把 z 弄丢），索性按 Lua 侧的真实形状走。
local function dumpTree(node, depth, out) -- 28
	local kids = node.children -- 29
	if kids == nil then -- 29
		return -- 30
	end -- 30
	local pad = "" -- 31
	do -- 31
		local i = 0 -- 32
		while i < depth do -- 32
			pad = pad .. "  " -- 32
			i = i + 1 -- 32
		end -- 32
	end -- 32
	local n = kids.count -- 33
	do -- 33
		local i = 0 -- 34
		while i < n do -- 34
			local c = kids[i] -- 35
			local ____temp_0 -- 36
			if c.children ~= nil then -- 36
				____temp_0 = c.children.count -- 36
			else -- 36
				____temp_0 = 0 -- 36
			end -- 36
			local gc = ____temp_0 -- 36
			out[#out + 1] = (((((((((((((pad .. "-") .. __TS__NumberToFixed(i, 0)) .. " pos=(") .. tostring(c.position.x.toFixed(4))) .. ",") .. tostring(c.position.y.toFixed(4))) .. ",") .. tostring(c.position.z.toFixed(4))) .. ") scale=") .. tostring(c.scale.x.toFixed(6))) .. " visible=") .. tostring(c.visible and 1 or 0)) .. " kids=") .. tostring(gc.toFixed(0)) -- 37
			if depth < 2 then -- 37
				dumpTree(c, depth + 1, out) -- 39
			end -- 39
			i = i + 1 -- 34
		end -- 34
	end -- 34
end -- 28
--- 每张图的背景均值（按变体顺序），最后用来出判定。
local bgMeans = {} -- 52
--- 报告一张截图的**上带**颜色。
-- 
-- 取样区 = 横向 2%~98%、纵向 4.5%~14%（y ≈ 62~193）：
-- 这一段在 L1 贴地球机位里一定**在地球盘面之上**（地球盘面的上缘在 y ≈ 240），
-- 所以它读到的就是"背景"本身 —— 那块灰正是出现在这里（旧取样区落在盘面上，读成了地球的颜色）。
local function analyze(shotPath, v) -- 61
	local out = {} -- 62
	out[#out + 1] = ((((((("--- " .. v.label) .. " (near=") .. tostring(v.near)) .. " far=") .. tostring(v.far)) .. " hide=") .. v.hide) .. ") ---"
	if not Content:exist(shotPath) then -- 63
		out[#out + 1] = "  VISION FAILED: not found " .. shotPath -- 65
		return out -- 66
	end -- 66
	local img = parseTga(Content:load(shotPath)) -- 68
	if img == nil then -- 68
		out[#out + 1] = "  VISION FAILED: unsupported TGA" -- 70
		return out -- 71
	end -- 71
	local r = 0 -- 73
	local g = 0 -- 73
	local b = 0 -- 73
	local n = 0 -- 73
	local x0 = math.floor(img.width * 0.02) -- 74
	local x1 = math.floor(img.width * 0.98) -- 75
	local y0 = math.floor(img.height * 0.045) -- 76
	local y1 = math.floor(img.height * 0.14) -- 77
	do -- 77
		local y = y0 -- 78
		while y < y1 do -- 78
			do -- 78
				local x = x0 -- 79
				while x < x1 do -- 79
					local c = rgbAt(img, x, y) -- 80
					r = r + c[1] -- 81
					g = g + c[2] -- 81
					b = b + c[3] -- 81
					n = n + 1 -- 81
					x = x + 7 -- 79
				end -- 79
			end -- 79
			y = y + 7 -- 78
		end -- 78
	end -- 78
	local cx = rgbAt( -- 84
		img, -- 84
		math.floor(img.width / 2), -- 84
		math.floor(img.height / 2) -- 84
	) -- 84
	local mean = (r + g + b) / 3 / n -- 85
	bgMeans[#bgMeans + 1] = mean -- 86
	out[#out + 1] = (((((((((((((((("  size=" .. __TS__NumberToFixed(img.width, 0)) .. "x") .. __TS__NumberToFixed(img.height, 0)) .. " bgMean=(") .. __TS__NumberToFixed(r / n, 1)) .. ",") .. __TS__NumberToFixed(g / n, 1)) .. ",") .. __TS__NumberToFixed(b / n, 1)) .. ")") .. " center=(") .. __TS__NumberToFixed(cx[1], 0)) .. ",") .. __TS__NumberToFixed(cx[2], 0)) .. ",") .. __TS__NumberToFixed(cx[3], 0)) .. ")" -- 87
	return out -- 90
end -- 61
--- 项目根：单文件入口下 `Content.searchPaths[0]` 是 `<proj>/Test`（AGENTS 的"搜索根陷阱"）——
-- 上跳一级才是项目根，否则标记文件会写进 `Test/.agent/...`（曾经踩过）。
local function findRoot() -- 97
	local sp0 = Content.searchPaths[1] -- 98
	if sp0 ~= nil then -- 98
		local up = Path(sp0, "..") -- 100
		if Content:exist(Path(up, "game", "Scene.lua")) then -- 100
			return up -- 101
		end -- 101
		if Content:exist(Path(sp0, "game", "Scene.lua")) then -- 101
			return sp0 -- 102
		end -- 102
	end -- 102
	return Path(Content.writablePath, "escape-velocity") -- 104
end -- 97
local root = findRoot() -- 107
local outDir = Path(root, ".agent", "test-results") -- 108
if not Content:exist(outDir) then -- 108
	Content:mkdir(outDir) -- 109
end -- 109
local marker = Path(outDir, "clip-probe.txt") -- 110
local lines = {} -- 112
local function flush(final) -- 113
	Content:save( -- 114
		marker, -- 114
		table.concat(lines, "\n") .. (final and "\nphase=done" or "") -- 114
	) -- 114
end -- 113
lines[#lines + 1] = "phase=started" -- 116
flush(false) -- 117
lines[#lines + 1] = (((((((((("engine defaults: near=" .. tostring(View.nearPlaneDistance)) .. " far=") .. tostring(View.farPlaneDistance)) .. " fov=") .. tostring(View.fieldOfView)) .. " aspect=") .. __TS__NumberToFixed(View.aspectRatio, 4)) .. " standardDistance=") .. tostring(View.standardDistance)) .. " frustumCulling=") .. tostring(View.frustumCulling and 1 or 0) -- 120
lines[#lines + 1] = (("sky sphere exists: " .. tostring(Content:exist("Assets/Model/StarSphere.gltf") and 1 or 0)) .. " ; sky quad exists: ") .. tostring(Content:exist("Assets/Model/StarQuad.gltf") and 1 or 0) -- 123
flush(false) -- 125
local def = getLevel(0) -- 127
if def == nil then -- 127
	lines[#lines + 1] = "RESULT=FAIL reason=no-level-1" -- 129
	flush(true) -- 130
else -- 130
	local bodies = scaledPlanets(def) -- 132
	local world = Node3D() -- 133
	Director.entry:addChild(world) -- 134
	local rtg = def.probeVariant == "rtg" -- 135
	local scene = buildScene({ -- 136
		root = world, -- 137
		bodies = bodies, -- 138
		visuals = def.visuals, -- 139
		probeStart = def.probeStart, -- 140
		probeScale = levelRuntime(0).probeVisualRadius, -- 141
		spherePath = "Assets/Model/Sphere.gltf", -- 142
		ringPath = "Assets/Model/Ring.gltf", -- 143
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 144
		probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 145
		probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 146
		probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 147
		probeBodyRadius = rtg and 0.871 or 1.084, -- 148
		probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 149
		orbitFlowDots = levelRuntime(0).orbitFlowDots, -- 152
		orbitRings = levelRuntime(0).orbitRings -- 153
	}) -- 153
	flush(false) -- 155
	if scene == nil then -- 155
		lines[#lines + 1] = "RESULT=FAIL reason=scene-build-failed" -- 158
		flush(true) -- 159
	else -- 159
		lines[#lines + 1] = "scene built; probeRadius=" .. tostring(scene.probeRadius) -- 161
		do -- 161
			local i = 0 -- 162
			while i < #def.visuals do -- 162
				local ____temp_2 = ("  body " .. __TS__NumberToFixed(i, 0)) .. " model=" -- 163
				local ____temp_1 -- 163
				if def.visuals[i + 1].model ~= nil then -- 163
					____temp_1 = def.visuals[i + 1].model -- 163
				else -- 163
					____temp_1 = "?" -- 163
				end -- 163
				lines[#lines + 1] = ((((____temp_2 .. tostring(____temp_1)) .. " displayRadius=") .. tostring(def.visuals[i + 1].displayRadius)) .. " orbitRadius=") .. __TS__NumberToFixed(bodies[i + 1].orbitRadius, 6) -- 163
				i = i + 1 -- 162
			end -- 162
		end -- 162
		flush(false) -- 167
		local camera = Camera3D() -- 169
		Director:pushCamera(camera) -- 170
		local target = planeToWorld({x = 0, y = 80}, 0) -- 173
		local dist = 0.01264 -- 174
		local tilt = 22 * math.pi / 180 -- 175
		local eye = Vec3( -- 176
			target.x, -- 176
			target.y + math.sin(tilt) * dist, -- 176
			target.z + math.cos(tilt) * dist -- 176
		) -- 176
		camera:lookAt( -- 177
			eye, -- 177
			target, -- 177
			Vec3(0, 1, 0) -- 177
		) -- 177
		scene.syncBodies(0) -- 178
		scene.syncProbe({x = 0, y = 80.003514}) -- 181
		scene.syncBackdrop(eye, target) -- 182
		local nearOpt = levelRuntime(0).cameraNear -- 185
		local shippedNear = nearOpt ~= nil and nearOpt > 0 and nearOpt or 0.1 -- 186
		local variants = {{label = "base(发布配置)", near = shippedNear, far = 10000, hide = "none"}, {label = "only-sky", near = shippedNear, far = 10000, hide = "all"}, {label = "world-off", near = shippedNear, far = 10000, hide = "world"}, {label = "engine-near0.1", near = 0.1, far = 10000, hide = "none"}} -- 187
		--- 把节点恢复成全部可见，再按变体藏指定的那一个。
		local function applyHide(what) -- 194
			world.visible = true -- 195
			do -- 195
				local i = 0 -- 196
				while i < #scene.planets do -- 196
					scene.planets[i + 1].body.visible = true -- 196
					i = i + 1 -- 196
				end -- 196
			end -- 196
			scene.probe.visible = true -- 197
			if what == "world" then -- 197
				world.visible = false -- 198
				return -- 198
			end -- 198
			if what == "probe" then -- 198
				scene.probe.visible = false -- 199
				return -- 199
			end -- 199
			if what == "all" then -- 199
				do -- 199
					local i = 0 -- 201
					while i < #scene.planets do -- 201
						scene.planets[i + 1].body.visible = false -- 201
						i = i + 1 -- 201
					end -- 201
				end -- 201
				scene.probe.visible = false -- 202
				return -- 203
			end -- 203
			if what == "sun" then -- 203
				scene.planets[1].body.visible = false -- 205
			elseif what == "earth" then -- 205
				scene.planets[2].body.visible = false -- 206
			elseif what == "moon" then -- 206
				scene.planets[3].body.visible = false -- 207
			end -- 207
		end -- 194
		do -- 194
			local i = 0 -- 210
			while i < #scene.planets do -- 210
				local n = scene.planets[i + 1].body -- 211
				lines[#lines + 1] = (((((((((("  node[" .. __TS__NumberToFixed(i, 0)) .. "] pos=(") .. __TS__NumberToFixed(n.position.x, 4)) .. ",") .. __TS__NumberToFixed(n.position.y, 4)) .. ",") .. __TS__NumberToFixed(n.position.z, 4)) .. ") scale=") .. __TS__NumberToFixed(n.scale.x, 6)) .. " visible=") .. tostring(n.visible and 1 or 0) -- 212
				i = i + 1 -- 210
			end -- 210
		end -- 210
		lines[#lines + 1] = (((((("  probe pos=(" .. __TS__NumberToFixed(scene.probe.position.x, 4)) .. ",") .. __TS__NumberToFixed(scene.probe.position.y, 4)) .. ",") .. __TS__NumberToFixed(scene.probe.position.z, 4)) .. ") scale=") .. __TS__NumberToFixed(scene.probe.scale.x, 8) -- 215
		lines[#lines + 1] = "--- scene tree under world ---"
		local tree = {} -- 220
		dumpTree(world, 0, tree) -- 221
		for ____, t in ipairs(tree) do -- 222
			lines[#lines + 1] = t -- 222
		end -- 222
		flush(false) -- 223
		local shots = {} -- 224
		local FramesPerVariant = 24 -- 225
		local frame = 0 -- 226
		lines[#lines + 1] = (("variants=" .. __TS__NumberToFixed(#variants, 0)) .. " framesPerVariant=") .. __TS__NumberToFixed(FramesPerVariant, 0) -- 228
		flush(false) -- 229
		threadLoop(function() -- 231
			local vi = math.floor(frame / FramesPerVariant) -- 232
			if vi >= #variants then -- 232
				local report = {} -- 234
				do -- 234
					local i = 0 -- 235
					while i < #shots do -- 235
						local part = analyze(shots[i + 1], variants[i + 1]) -- 236
						for ____, l in ipairs(part) do -- 237
							report[#report + 1] = l -- 237
						end -- 237
						i = i + 1 -- 235
					end -- 235
				end -- 235
				lines[#lines + 1] = "" -- 239
				for ____, l in ipairs(report) do -- 240
					lines[#lines + 1] = l -- 240
				end -- 240
				local baseBg = #bgMeans > 0 and bgMeans[1] or -1 -- 244
				local nearBg = #bgMeans > 3 and bgMeans[4] or -1 -- 245
				local clearBg = #bgMeans > 2 and bgMeans[3] or -1 -- 246
				local ok = baseBg >= 0 and baseBg < 45 and nearBg < 45 and clearBg > 20 and clearBg < 32 -- 250
				lines[#lines + 1] = "" -- 251
				lines[#lines + 1] = ((((((("VERDICT baseBg=" .. __TS__NumberToFixed(baseBg, 1)) .. " (要 < 45 = 无灰带)") .. " engineNear0.1Bg=") .. __TS__NumberToFixed(nearBg, 1)) .. " (要 < 45 = 暗背景)") .. " clearColorBg=") .. __TS__NumberToFixed(clearBg, 1)) .. " (要 ≈ 26 = 引擎清屏色)" -- 252
				lines[#lines + 1] = "RESULT=" .. (ok and "PASS" or "FAIL") -- 255
				flush(true) -- 256
				return true -- 257
			end -- 257
			local ____local = frame % FramesPerVariant -- 259
			local v = variants[vi + 1] -- 260
			if ____local == 0 then -- 260
				View.nearPlaneDistance = v.near -- 262
				View.farPlaneDistance = v.far -- 263
				applyHide(v.hide) -- 264
				scene.syncBackdrop(eye, target) -- 265
				lines[#lines + 1] = (("variant " .. v.label) .. " applied at frame ") .. __TS__NumberToFixed(frame, 0) -- 266
				flush(false) -- 267
			elseif ____local == 4 then -- 267
				shots[#shots + 1] = App:saveScreenshot(Path( -- 269
					outDir, -- 269
					"clip-" .. __TS__NumberToFixed(vi, 0) -- 269
				)) -- 269
			end -- 269
			frame = frame + 1 -- 271
			return false -- 272
		end) -- 231
	end -- 231
end -- 231
return ____exports -- 231
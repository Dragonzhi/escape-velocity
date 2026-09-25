-- [ts]: init.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 21
local App = ____Dora.App -- 21
local Camera3D = ____Dora.Camera3D -- 21
local Content = ____Dora.Content -- 21
local Director = ____Dora.Director -- 21
local Node = ____Dora.Node -- 21
local Node3D = ____Dora.Node3D -- 21
local Path = ____Dora.Path -- 21
local Size = ____Dora.Size -- 21
local Vec2 = ____Dora.Vec2 -- 21
local View = ____Dora.View -- 21
local threadLoop = ____Dora.threadLoop -- 21
local ____LevelData = require("game.LevelData") -- 22
local getLevel = ____LevelData.getLevel -- 22
local levelCount = ____LevelData.levelCount -- 22
local scaledPlanets = ____LevelData.scaledPlanets -- 22
local ____Scene = require("game.Scene") -- 23
local buildScene = ____Scene.buildScene -- 23
local ____CameraRig = require("game.CameraRig") -- 24
local createCameraRig = ____CameraRig.createCameraRig -- 24
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 24
local ____Trajectory = require("game.Trajectory") -- 25
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 25
local trajectoryOptions = ____Trajectory.defaultOptions -- 25
local ____Hud = require("game.Hud") -- 26
local createAimInput = ____Hud.createAimInput -- 26
local createLevelSelect = ____Hud.createLevelSelect -- 26
local createResultPanel = ____Hud.createResultPanel -- 26
local ____Game = require("game.Game") -- 27
local createGame = ____Game.createGame -- 27
local ____Progress = require("game.Progress") -- 28
local advanceUnlocked = ____Progress.advanceUnlocked -- 28
local loadProgress = ____Progress.loadProgress -- 28
local progressFilePath = ____Progress.progressFilePath -- 28
local saveProgress = ____Progress.saveProgress -- 28
local levelTotal = levelCount() -- 50
if levelTotal <= 0 then -- 50
	print("[escape-velocity] FATAL: no level data") -- 53
else -- 53
	local viewW = View.size.width -- 55
	local viewH = View.size.height -- 56
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 59
	local levelLayers = {} -- 65
	do -- 65
		local i = 0 -- 66
		while i < levelTotal do -- 66
			local layer = Node() -- 67
			layer.size = Size(viewW, viewH) -- 68
			layer.anchor = Vec2(0.5, 0.5) -- 69
			layer.position = Vec2(0, 0) -- 70
			Director.ui:addChild(layer) -- 71
			levelLayers[#levelLayers + 1] = layer -- 72
			i = i + 1 -- 66
		end -- 66
	end -- 66
	local uiLayer = Node() -- 76
	uiLayer.size = Size(viewW, viewH) -- 77
	uiLayer.anchor = Vec2(0.5, 0.5) -- 78
	uiLayer.position = Vec2(0, 0) -- 79
	Director.ui:addChild(uiLayer) -- 80
	local levelNames = {} -- 83
	do -- 83
		local i = 0 -- 84
		while i < levelTotal do -- 84
			local def = getLevel(i) -- 85
			local title = def ~= nil and def.title or "" -- 86
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 87
			i = i + 1 -- 84
		end -- 84
	end -- 84
	local levelEntries = {} -- 89
	do -- 89
		local i = 0 -- 90
		while i < levelTotal do -- 90
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 90
			i = i + 1 -- 90
		end -- 90
	end -- 90
	local progress = loadProgress(levelTotal) -- 93
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 94
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 95
	local slots = {} -- 97
	do -- 97
		local i = 0 -- 98
		while i < levelTotal do -- 98
			slots[#slots + 1] = {built = false, runtime = nil} -- 98
			i = i + 1 -- 98
		end -- 98
	end -- 98
	local activeIndex = -1 -- 100
	local select = nil -- 101
	local resultPanel = nil -- 102
	local function activeRuntime() -- 104
		if activeIndex < 0 then -- 104
			return nil -- 105
		end -- 105
		return slots[activeIndex + 1].runtime -- 106
	end -- 104
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 114
		do -- 114
			local i = 0 -- 115
			while i < levelTotal do -- 115
				do -- 115
					local slot = slots[i + 1] -- 116
					levelLayers[i + 1].visible = i == index -- 119
					if slot.runtime == nil then -- 119
						goto __continue16 -- 120
					end -- 120
					local active = i == index -- 121
					slot.runtime.world.visible = active -- 122
					slot.runtime.aim:setEnabled(active) -- 123
				end -- 123
				::__continue16:: -- 123
				i = i + 1 -- 115
			end -- 115
		end -- 115
	end -- 114
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 132
		local slot = slots[index + 1] -- 133
		if slot.built and slot.runtime ~= nil then -- 133
			return slot.runtime -- 134
		end -- 134
		local def = getLevel(index) -- 136
		if def == nil then -- 136
			return nil -- 137
		end -- 137
		local bodies = scaledPlanets(def) -- 139
		local level = { -- 140
			bodies = bodies, -- 141
			probeStart = def.probeStart, -- 142
			goal = def.goal, -- 143
			escapeRadius = def.escapeRadius, -- 144
			maxSteps = def.maxSteps -- 145
		} -- 145
		local world = Node3D() -- 148
		Director.entry:addChild(world) -- 149
		world.visible = false -- 150
		local scene = buildScene({ -- 152
			root = world, -- 153
			bodies = bodies, -- 154
			visuals = def.visuals, -- 155
			probeStart = level.probeStart, -- 156
			probeScale = 1.2, -- 161
			spherePath = "Assets/Model/Sphere.gltf", -- 162
			ringPath = "Assets/Model/Ring.gltf", -- 163
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 164
			home = {x = level.probeStart.x, y = level.probeStart.y + 4.2}, -- 166
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 169
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 170
		}) -- 170
		if scene == nil then -- 170
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 173
			return nil -- 174
		end -- 174
		local camera = Camera3D() -- 177
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 180
		local trajectory = createTrajectoryView( -- 181
			levelLayers[index + 1], -- 181
			trajectoryOptions() -- 181
		) -- 181
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 182
		local game = createGame( -- 184
			level, -- 184
			{ -- 184
				scene = scene, -- 185
				camera = camera, -- 186
				rig = rig, -- 187
				trajectory = trajectory, -- 188
				aim = aim, -- 189
				viewW = viewW, -- 190
				viewH = viewH, -- 191
				fovYDeg = View.fieldOfView, -- 192
				aspect = View.aspectRatio, -- 193
				onPhase = function(____, p) -- 194
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 195
				end, -- 194
				onResult = function(____, r) -- 197
					if r == "success" then -- 197
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 200
						if next ~= progress.unlocked then -- 200
							progress = {unlocked = next} -- 202
							saveProgress(progress) -- 203
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 204
						end -- 204
					end -- 204
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 207
					if resultPanel ~= nil then -- 207
						resultPanel:show(r, levelNames[index + 1]) -- 208
					end -- 208
				end -- 197
			} -- 197
		) -- 197
		aim:onDrag(function(a) -- 215
			game:onAimDrag(a) -- 215
		end) -- 215
		aim:onRelease(function(a) -- 216
			game:launch(a.velocity) -- 216
		end) -- 216
		local runtime = { -- 218
			index = index, -- 219
			name = levelNames[index + 1], -- 220
			world = world, -- 221
			camera = camera, -- 222
			game = game, -- 223
			aim = aim, -- 224
			trajectory = trajectory -- 225
		} -- 225
		slot.built = true -- 227
		slot.runtime = runtime -- 228
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 229
		return runtime -- 230
	end -- 132
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 234
		local runtime = ensureLevel(index) -- 235
		if runtime == nil then -- 235
			return -- 236
		end -- 236
		if select ~= nil then -- 236
			select:hide() -- 240
		end -- 240
		activeIndex = index -- 241
		showOnlyLevel(index) -- 242
		Director:pushCamera(runtime.camera) -- 243
		runtime.game:startLevel() -- 244
		print("[escape-velocity] enter " .. runtime.name) -- 245
	end -- 234
	local function onRetryTap() -- 248
		if resultPanel ~= nil then -- 248
			resultPanel:hide() -- 249
		end -- 249
		local runtime = activeRuntime() -- 250
		if runtime ~= nil then -- 250
			runtime.game:retry() -- 251
		end -- 251
	end -- 248
	local function onBackToSelectTap() -- 254
		local runtime = activeRuntime() -- 255
		if runtime == nil then -- 255
			return -- 256
		end -- 256
		if not runtime.game:backToSelect() then -- 256
			return -- 258
		end -- 258
		runtime.world.visible = false -- 259
		runtime.aim:setEnabled(false) -- 260
		if resultPanel ~= nil then -- 260
			resultPanel:hide() -- 261
		end -- 261
		progress = loadProgress(levelTotal) -- 263
		if select ~= nil then -- 263
			select:show(progress.unlocked) -- 264
		end -- 264
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 265
	end -- 254
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 278
		resultPanel = createResultPanel( -- 279
			uiLayer, -- 279
			viewW, -- 279
			viewH, -- 279
			{ -- 279
				onRetry = function() return onRetryTap() end, -- 280
				onBackToSelect = function() return onBackToSelectTap() end -- 281
			} -- 281
		) -- 281
		local created = createLevelSelect( -- 283
			uiLayer, -- 283
			viewW, -- 283
			viewH, -- 283
			{ -- 283
				levels = levelEntries, -- 284
				onPick = function(____, index) -- 285
					if select ~= nil then -- 285
						select:hide() -- 286
					end -- 286
					enterLevel(index) -- 287
				end -- 285
			} -- 285
		) -- 285
		select = created -- 290
		return created -- 291
	end -- 278
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 304
		local w = View.size.width -- 305
		local h = View.size.height -- 306
		if w == viewW and h == viewH then -- 306
			return -- 307
		end -- 307
		if select ~= nil then -- 307
			select:hide() -- 310
		end -- 310
		if resultPanel ~= nil then -- 310
			resultPanel:hide() -- 311
		end -- 311
		do -- 311
			local i = 0 -- 312
			while i < levelTotal do -- 312
				local slot = slots[i + 1] -- 313
				if slot.runtime ~= nil then -- 313
					slot.runtime.world.visible = false -- 315
					slot.runtime.aim:setEnabled(false) -- 316
					slot.runtime.trajectory:clearPrediction() -- 319
					slot.runtime.trajectory:clearTrail() -- 320
				end -- 320
				slot.built = false -- 322
				slot.runtime = nil -- 323
				i = i + 1 -- 312
			end -- 312
		end -- 312
		viewW = w -- 327
		viewH = h -- 328
		uiLayer.size = Size(viewW, viewH) -- 329
		do -- 329
			local i = 0 -- 330
			while i < levelTotal do -- 330
				levelLayers[i + 1].size = Size(viewW, viewH) -- 330
				i = i + 1 -- 330
			end -- 330
		end -- 330
		local panel = buildPanels() -- 333
		if activeIndex >= 0 then -- 333
			local keep = activeIndex -- 335
			activeIndex = -1 -- 336
			enterLevel(keep) -- 337
		else -- 337
			panel:show(progress.unlocked) -- 339
		end -- 339
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 341
	end -- 304
	Director.entry:onAppChange(function(name) -- 345
		if name == "Size" then -- 345
			relayoutForViewport() -- 346
		end -- 346
	end) -- 345
	buildPanels():show(progress.unlocked) -- 350
	local enterReq = Path( -- 355
		Path(".", ".agent", "test-results"), -- 355
		"enter-request.txt" -- 355
	) -- 355
	local autoLaunchAt = -1 -- 357
	local autoFrame = 0 -- 358
	local autoVX = 0 -- 359
	local autoVY = 0 -- 360
	if Content:exist(enterReq) then -- 360
		local spec = Content:load(enterReq) -- 362
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 363
		local n = tonumber(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 364
		if n ~= nil and n >= 1 and n <= levelTotal then -- 364
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 366
			enterLevel(n - 1) -- 367
			if at >= 0 then -- 367
				local rest = __TS__StringSubstring(spec, at + 1) -- 369
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 370
				local c2 = (string.find( -- 371
					rest, -- 371
					":", -- 371
					math.max(c1 + 1 + 1, 1), -- 371
					true -- 371
				) or 0) - 1 -- 371
				if c1 > 0 and c2 > c1 then -- 371
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 373
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 374
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 375
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 375
						autoLaunchAt = frames -- 377
						autoVX = vx -- 378
						autoVY = vy -- 379
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 380
					end -- 380
				end -- 380
			end -- 380
		end -- 380
	end -- 380
	threadLoop(function() -- 389
		local runtime = activeRuntime() -- 390
		if runtime ~= nil then -- 390
			runtime.game:update(App.deltaTime) -- 392
			if autoLaunchAt >= 0 then -- 392
				autoFrame = autoFrame + 1 -- 395
				if autoFrame >= autoLaunchAt then -- 395
					autoLaunchAt = -1 -- 397
					print("[escape-velocity] auto launch") -- 398
					runtime.game:launch({x = autoVX, y = autoVY}) -- 399
				end -- 399
			end -- 399
		end -- 399
		return false -- 404
	end) -- 389
	print(((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", level select shown") -- 408
end -- 408
return ____exports -- 408
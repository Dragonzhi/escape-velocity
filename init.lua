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
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 168
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 169
		}) -- 169
		if scene == nil then -- 169
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 172
			return nil -- 173
		end -- 173
		local camera = Camera3D() -- 176
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 179
		local trajectory = createTrajectoryView( -- 180
			levelLayers[index + 1], -- 180
			trajectoryOptions() -- 180
		) -- 180
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 181
		local game = createGame( -- 183
			level, -- 183
			{ -- 183
				scene = scene, -- 184
				camera = camera, -- 185
				rig = rig, -- 186
				trajectory = trajectory, -- 187
				aim = aim, -- 188
				viewW = viewW, -- 189
				viewH = viewH, -- 190
				fovYDeg = View.fieldOfView, -- 191
				aspect = View.aspectRatio, -- 192
				onPhase = function(____, p) -- 193
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 194
				end, -- 193
				onResult = function(____, r) -- 196
					if r == "success" then -- 196
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 199
						if next ~= progress.unlocked then -- 199
							progress = {unlocked = next} -- 201
							saveProgress(progress) -- 202
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 203
						end -- 203
					end -- 203
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 206
					if resultPanel ~= nil then -- 206
						resultPanel:show(r, levelNames[index + 1]) -- 207
					end -- 207
				end -- 196
			} -- 196
		) -- 196
		aim:onDrag(function(a) -- 214
			game:onAimDrag(a) -- 214
		end) -- 214
		aim:onRelease(function(a) -- 215
			game:launch(a.velocity) -- 215
		end) -- 215
		local runtime = { -- 217
			index = index, -- 218
			name = levelNames[index + 1], -- 219
			world = world, -- 220
			camera = camera, -- 221
			game = game, -- 222
			aim = aim, -- 223
			trajectory = trajectory -- 224
		} -- 224
		slot.built = true -- 226
		slot.runtime = runtime -- 227
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 228
		return runtime -- 229
	end -- 132
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 233
		local runtime = ensureLevel(index) -- 234
		if runtime == nil then -- 234
			return -- 235
		end -- 235
		local wasActive = activeIndex == index -- 238
		if select ~= nil then -- 238
			select:hide() -- 239
		end -- 239
		activeIndex = index -- 240
		showOnlyLevel(index) -- 241
		if not wasActive then -- 241
			Director:pushCamera(runtime.camera) -- 242
		end -- 242
		runtime.game:startLevel() -- 243
		print("[escape-velocity] enter " .. runtime.name) -- 244
	end -- 233
	local function onRetryTap() -- 247
		if resultPanel ~= nil then -- 247
			resultPanel:hide() -- 248
		end -- 248
		local runtime = activeRuntime() -- 249
		if runtime ~= nil then -- 249
			runtime.game:retry() -- 250
		end -- 250
	end -- 247
	local function onBackToSelectTap() -- 253
		local runtime = activeRuntime() -- 254
		if runtime == nil then -- 254
			return -- 255
		end -- 255
		if not runtime.game:backToSelect() then -- 255
			return -- 257
		end -- 257
		runtime.world.visible = false -- 258
		runtime.aim:setEnabled(false) -- 259
		if resultPanel ~= nil then -- 259
			resultPanel:hide() -- 260
		end -- 260
		progress = loadProgress(levelTotal) -- 262
		if select ~= nil then -- 262
			select:show(progress.unlocked) -- 263
		end -- 263
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 264
	end -- 253
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 277
		resultPanel = createResultPanel( -- 278
			uiLayer, -- 278
			viewW, -- 278
			viewH, -- 278
			{ -- 278
				onRetry = function() return onRetryTap() end, -- 279
				onBackToSelect = function() return onBackToSelectTap() end -- 280
			} -- 280
		) -- 280
		local created = createLevelSelect( -- 282
			uiLayer, -- 282
			viewW, -- 282
			viewH, -- 282
			{ -- 282
				levels = levelEntries, -- 283
				onPick = function(____, index) -- 284
					if select ~= nil then -- 284
						select:hide() -- 285
					end -- 285
					enterLevel(index) -- 286
				end -- 284
			} -- 284
		) -- 284
		select = created -- 289
		return created -- 290
	end -- 277
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 303
		local w = View.size.width -- 304
		local h = View.size.height -- 305
		if w == viewW and h == viewH then -- 305
			return -- 306
		end -- 306
		if select ~= nil then -- 306
			select:hide() -- 309
		end -- 309
		if resultPanel ~= nil then -- 309
			resultPanel:hide() -- 310
		end -- 310
		do -- 310
			local i = 0 -- 311
			while i < levelTotal do -- 311
				local slot = slots[i + 1] -- 312
				if slot.runtime ~= nil then -- 312
					slot.runtime.world.visible = false -- 314
					slot.runtime.aim:setEnabled(false) -- 315
					slot.runtime.trajectory:clearPrediction() -- 318
					slot.runtime.trajectory:clearTrail() -- 319
				end -- 319
				slot.built = false -- 321
				slot.runtime = nil -- 322
				i = i + 1 -- 311
			end -- 311
		end -- 311
		viewW = w -- 326
		viewH = h -- 327
		uiLayer.size = Size(viewW, viewH) -- 328
		do -- 328
			local i = 0 -- 329
			while i < levelTotal do -- 329
				levelLayers[i + 1].size = Size(viewW, viewH) -- 329
				i = i + 1 -- 329
			end -- 329
		end -- 329
		local panel = buildPanels() -- 332
		if activeIndex >= 0 then -- 332
			local keep = activeIndex -- 334
			activeIndex = -1 -- 335
			enterLevel(keep) -- 336
		else -- 336
			panel:show(progress.unlocked) -- 338
		end -- 338
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 340
	end -- 303
	Director.entry:onAppChange(function(name) -- 344
		if name == "Size" then -- 344
			relayoutForViewport() -- 345
		end -- 345
	end) -- 344
	buildPanels():show(progress.unlocked) -- 349
	local enterReq = Path( -- 354
		Path(".", ".agent", "test-results"), -- 354
		"enter-request.txt" -- 354
	) -- 354
	local autoLaunchAt = -1 -- 356
	local autoFrame = 0 -- 357
	local autoVX = 0 -- 358
	local autoVY = 0 -- 359
	local autoBackAt = -1 -- 361
	local autoReenterAt = -1 -- 362
	if Content:exist(enterReq) then -- 362
		local spec = Content:load(enterReq) -- 364
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 365
		local n = tonumber(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 366
		if n ~= nil and n >= 1 and n <= levelTotal then -- 366
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 368
			enterLevel(n - 1) -- 369
			if at >= 0 then -- 369
				local rest = __TS__StringSubstring(spec, at + 1) -- 371
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 372
				local c2 = (string.find( -- 373
					rest, -- 373
					":", -- 373
					math.max(c1 + 1 + 1, 1), -- 373
					true -- 373
				) or 0) - 1 -- 373
				if c1 > 0 and c2 > c1 then -- 373
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 375
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 376
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 377
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 377
						autoLaunchAt = frames -- 379
						autoVX = vx -- 380
						autoVY = vy -- 381
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 382
					end -- 382
				end -- 382
			end -- 382
		end -- 382
	end -- 382
	threadLoop(function() -- 391
		local runtime = activeRuntime() -- 392
		if runtime ~= nil then -- 392
			runtime.game:update(App.deltaTime) -- 394
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 394
				autoFrame = autoFrame + 1 -- 397
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 397
					autoLaunchAt = -1 -- 399
					print("[escape-velocity] auto launch") -- 400
					runtime.game:launch({x = autoVX, y = autoVY}) -- 401
					autoBackAt = autoFrame + 320 -- 402
					autoReenterAt = autoFrame + 380 -- 403
				end -- 403
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 403
					autoBackAt = -1 -- 407
					if runtime.game:backToSelect() then -- 407
						print("[escape-velocity] auto back to select") -- 408
					end -- 408
				end -- 408
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 408
					autoReenterAt = -1 -- 411
					print("[escape-velocity] auto re-enter") -- 412
					enterLevel(0) -- 413
				end -- 413
			end -- 413
		end -- 413
		return false -- 418
	end) -- 391
	print(((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", level select shown") -- 422
end -- 422
return ____exports -- 422
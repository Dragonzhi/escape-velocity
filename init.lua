-- [ts]: init.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__StringSubstring = ____lualib.__TS__StringSubstring -- 1
local __TS__StringTrim = ____lualib.__TS__StringTrim -- 1
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
local ____Opening = require("game.Opening") -- 29
local createOpening = ____Opening.createOpening -- 29
local loadIntroSeen = ____Opening.loadIntroSeen -- 29
local saveIntroSeen = ____Opening.saveIntroSeen -- 29
local levelTotal = levelCount() -- 51
if levelTotal <= 0 then -- 51
	print("[escape-velocity] FATAL: no level data") -- 54
else -- 54
	local opening, startOpening, introHold -- 54
	local viewW = View.size.width -- 56
	local viewH = View.size.height -- 57
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 60
	local levelLayers = {} -- 66
	do -- 66
		local i = 0 -- 67
		while i < levelTotal do -- 67
			local layer = Node() -- 68
			layer.size = Size(viewW, viewH) -- 69
			layer.anchor = Vec2(0.5, 0.5) -- 70
			layer.position = Vec2(0, 0) -- 71
			Director.ui:addChild(layer) -- 72
			levelLayers[#levelLayers + 1] = layer -- 73
			i = i + 1 -- 67
		end -- 67
	end -- 67
	local openingLayer = Node() -- 78
	openingLayer.size = Size(viewW, viewH) -- 79
	openingLayer.anchor = Vec2(0.5, 0.5) -- 80
	openingLayer.position = Vec2(0, 0) -- 81
	Director.ui:addChild(openingLayer) -- 82
	local openingRoot = Node3D() -- 85
	openingRoot.visible = false -- 86
	Director.entry:addChild(openingRoot) -- 87
	local openingCamera = Camera3D() -- 88
	local uiLayer = Node() -- 91
	uiLayer.size = Size(viewW, viewH) -- 92
	uiLayer.anchor = Vec2(0.5, 0.5) -- 93
	uiLayer.position = Vec2(0, 0) -- 94
	Director.ui:addChild(uiLayer) -- 95
	local levelNames = {} -- 98
	do -- 98
		local i = 0 -- 99
		while i < levelTotal do -- 99
			local def = getLevel(i) -- 100
			local title = def ~= nil and def.title or "" -- 101
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 102
			i = i + 1 -- 99
		end -- 99
	end -- 99
	local levelEntries = {} -- 104
	do -- 104
		local i = 0 -- 105
		while i < levelTotal do -- 105
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 105
			i = i + 1 -- 105
		end -- 105
	end -- 105
	local progress = loadProgress(levelTotal) -- 108
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 109
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 110
	local slots = {} -- 112
	do -- 112
		local i = 0 -- 113
		while i < levelTotal do -- 113
			slots[#slots + 1] = {built = false, runtime = nil} -- 113
			i = i + 1 -- 113
		end -- 113
	end -- 113
	local activeIndex = -1 -- 115
	local select = nil -- 116
	local resultPanel = nil -- 117
	local function activeRuntime() -- 119
		if activeIndex < 0 then -- 119
			return nil -- 120
		end -- 120
		return slots[activeIndex + 1].runtime -- 121
	end -- 119
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 129
		do -- 129
			local i = 0 -- 130
			while i < levelTotal do -- 130
				do -- 130
					local slot = slots[i + 1] -- 131
					levelLayers[i + 1].visible = i == index -- 134
					if slot.runtime == nil then -- 134
						goto __continue16 -- 135
					end -- 135
					local active = i == index -- 136
					slot.runtime.world.visible = active -- 137
					slot.runtime.aim:setEnabled(active) -- 138
				end -- 138
				::__continue16:: -- 138
				i = i + 1 -- 130
			end -- 130
		end -- 130
	end -- 129
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 147
		local slot = slots[index + 1] -- 148
		if slot.built and slot.runtime ~= nil then -- 148
			return slot.runtime -- 149
		end -- 149
		local def = getLevel(index) -- 151
		if def == nil then -- 151
			return nil -- 152
		end -- 152
		local bodies = scaledPlanets(def) -- 154
		local level = { -- 155
			bodies = bodies, -- 156
			probeStart = def.probeStart, -- 157
			goal = def.goal, -- 158
			escapeRadius = def.escapeRadius, -- 159
			maxSteps = def.maxSteps -- 160
		} -- 160
		local world = Node3D() -- 163
		Director.entry:addChild(world) -- 164
		world.visible = false -- 165
		local scene = buildScene({ -- 167
			root = world, -- 168
			bodies = bodies, -- 169
			visuals = def.visuals, -- 170
			probeStart = level.probeStart, -- 171
			probeScale = 1.2, -- 176
			spherePath = "Assets/Model/Sphere.gltf", -- 177
			ringPath = "Assets/Model/Ring.gltf", -- 178
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 179
			home = {x = level.probeStart.x, y = level.probeStart.y + 4.2}, -- 182
			homeRadius = def.homeRadius, -- 183
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 185
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 186
		}) -- 186
		if scene == nil then -- 186
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 189
			return nil -- 190
		end -- 190
		local camera = Camera3D() -- 193
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 196
		local trajectory = createTrajectoryView( -- 197
			levelLayers[index + 1], -- 197
			trajectoryOptions() -- 197
		) -- 197
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 198
		local game = createGame( -- 200
			level, -- 200
			{ -- 200
				scene = scene, -- 201
				camera = camera, -- 202
				rig = rig, -- 203
				trajectory = trajectory, -- 204
				aim = aim, -- 205
				viewW = viewW, -- 206
				viewH = viewH, -- 207
				fovYDeg = View.fieldOfView, -- 208
				aspect = View.aspectRatio, -- 209
				onPhase = function(____, p) -- 210
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 211
				end, -- 210
				onResult = function(____, r) -- 213
					if r == "success" then -- 213
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 216
						if next ~= progress.unlocked then -- 216
							progress = {unlocked = next} -- 218
							saveProgress(progress) -- 219
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 220
						end -- 220
					end -- 220
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 223
					if resultPanel ~= nil then -- 223
						resultPanel:show(r, levelNames[index + 1]) -- 224
					end -- 224
				end -- 213
			} -- 213
		) -- 213
		aim:onDrag(function(a) -- 231
			game:onAimDrag(a) -- 231
		end) -- 231
		aim:onRelease(function(a) -- 232
			game:launch(a.velocity) -- 232
		end) -- 232
		local runtime = { -- 234
			index = index, -- 235
			name = levelNames[index + 1], -- 236
			world = world, -- 237
			camera = camera, -- 238
			game = game, -- 239
			aim = aim, -- 240
			trajectory = trajectory -- 241
		} -- 241
		slot.built = true -- 243
		slot.runtime = runtime -- 244
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 245
		return runtime -- 246
	end -- 147
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 250
		local runtime = ensureLevel(index) -- 251
		if runtime == nil then -- 251
			return -- 252
		end -- 252
		local wasActive = activeIndex == index -- 255
		if opening ~= nil then -- 255
			opening.hide() -- 257
		end -- 257
		if select ~= nil then -- 257
			select:hide() -- 258
		end -- 258
		activeIndex = index -- 259
		showOnlyLevel(index) -- 260
		if not wasActive then -- 260
			Director:pushCamera(runtime.camera) -- 261
		end -- 261
		runtime.game:startLevel() -- 262
		print("[escape-velocity] enter " .. runtime.name) -- 263
	end -- 250
	local function onRetryTap() -- 266
		if resultPanel ~= nil then -- 266
			resultPanel:hide() -- 267
		end -- 267
		local runtime = activeRuntime() -- 268
		if runtime ~= nil then -- 268
			runtime.game:retry() -- 269
		end -- 269
	end -- 266
	local function onBackToSelectTap() -- 272
		local runtime = activeRuntime() -- 273
		if runtime == nil then -- 273
			return -- 274
		end -- 274
		if not runtime.game:backToSelect() then -- 274
			return -- 276
		end -- 276
		runtime.world.visible = false -- 277
		runtime.aim:setEnabled(false) -- 278
		if resultPanel ~= nil then -- 278
			resultPanel:hide() -- 279
		end -- 279
		progress = loadProgress(levelTotal) -- 281
		if select ~= nil then -- 281
			select:show(progress.unlocked) -- 282
		end -- 282
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 283
	end -- 272
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 296
		resultPanel = createResultPanel( -- 297
			uiLayer, -- 297
			viewW, -- 297
			viewH, -- 297
			{ -- 297
				onRetry = function() return onRetryTap() end, -- 298
				onBackToSelect = function() return onBackToSelectTap() end -- 299
			} -- 299
		) -- 299
		local created = createLevelSelect( -- 301
			uiLayer, -- 301
			viewW, -- 301
			viewH, -- 301
			{ -- 301
				levels = levelEntries, -- 302
				onPick = function(____, index) -- 303
					if select ~= nil then -- 303
						select:hide() -- 304
					end -- 304
					enterLevel(index) -- 305
				end, -- 303
				onReplayIntro = function() -- 308
					if select ~= nil then -- 308
						select:hide() -- 309
					end -- 309
					startOpening() -- 310
					print("[escape-velocity] opening replay (user)") -- 311
				end -- 308
			} -- 308
		) -- 308
		select = created -- 314
		return created -- 315
	end -- 296
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 328
		local w = View.size.width -- 329
		local h = View.size.height -- 330
		if w == viewW and h == viewH then -- 330
			return -- 331
		end -- 331
		if opening ~= nil then -- 331
			opening.hide() -- 337
			opening = nil -- 338
		end -- 338
		if select ~= nil then -- 338
			select:hide() -- 340
		end -- 340
		if resultPanel ~= nil then -- 340
			resultPanel:hide() -- 341
		end -- 341
		do -- 341
			local i = 0 -- 342
			while i < levelTotal do -- 342
				local slot = slots[i + 1] -- 343
				if slot.runtime ~= nil then -- 343
					slot.runtime.world.visible = false -- 345
					slot.runtime.aim:setEnabled(false) -- 346
					slot.runtime.trajectory:clearPrediction() -- 349
					slot.runtime.trajectory:clearTrail() -- 350
					slot.runtime.trajectory:clearGoalRings() -- 352
				end -- 352
				slot.built = false -- 354
				slot.runtime = nil -- 355
				i = i + 1 -- 342
			end -- 342
		end -- 342
		viewW = w -- 359
		viewH = h -- 360
		uiLayer.size = Size(viewW, viewH) -- 361
		openingLayer.size = Size(viewW, viewH) -- 362
		do -- 362
			local i = 0 -- 363
			while i < levelTotal do -- 363
				levelLayers[i + 1].size = Size(viewW, viewH) -- 363
				i = i + 1 -- 363
			end -- 363
		end -- 363
		local panel = buildPanels() -- 366
		if activeIndex >= 0 then -- 366
			local keep = activeIndex -- 368
			activeIndex = -1 -- 369
			enterLevel(keep) -- 370
		else -- 370
			panel:show(progress.unlocked) -- 372
		end -- 372
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 374
	end -- 328
	Director.entry:onAppChange(function(name) -- 378
		if name == "Size" then -- 378
			relayoutForViewport() -- 379
		end -- 379
	end) -- 378
	local introSeen = loadIntroSeen() -- 387
	local forceIntro = false -- 388
	opening = nil -- 389
	startOpening = function() -- 391
		if opening == nil then -- 391
			opening = createOpening({ -- 393
				root = openingRoot, -- 394
				camera = openingCamera, -- 395
				layer = openingLayer, -- 396
				viewW = viewW, -- 397
				viewH = viewH, -- 398
				fovYDeg = View.fieldOfView, -- 399
				aspect = View.aspectRatio, -- 400
				spherePath = "Assets/Model/Sphere.gltf", -- 401
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 402
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 403
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 404
				onFinish = function() -- 405
					introHold = -1 -- 406
					if not introSeen then -- 406
						saveIntroSeen() -- 408
						introSeen = true -- 409
						print("[escape-velocity] intro seen -> saved") -- 410
					end -- 410
					if select ~= nil then -- 410
						select:show(progress.unlocked) -- 413
					end -- 413
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 414
						opening.frameIndex(), -- 414
						0 -- 414
					) or "?")) -- 414
				end -- 405
			}) -- 405
		end -- 405
		if opening == nil then -- 405
			return -- 418
		end -- 418
		Director:pushCamera(openingCamera) -- 419
		opening.start() -- 420
		print("[escape-velocity] opening start (first launch)") -- 421
	end -- 391
	local startupPanel = buildPanels() -- 424
	local enterReq = Path( -- 436
		Path(".", ".agent", "test-results"), -- 436
		"enter-request.txt" -- 436
	) -- 436
	local autoLaunchAt = -1 -- 437
	local autoFrame = 0 -- 438
	local autoVX = 0 -- 439
	local autoVY = 0 -- 440
	local autoBackAt = -1 -- 442
	local autoReenterAt = -1 -- 443
	local autoEntered = false -- 444
	introHold = -1 -- 446
	if Content:exist(enterReq) then -- 446
		local spec = Content:load(enterReq) -- 448
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 449
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 450
		if head == "intro" then -- 450
			forceIntro = true -- 452
			if at >= 0 then -- 452
				local rest = __TS__StringSubstring(spec, at + 1) -- 454
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 455
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 455
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 457
					if v ~= nil and v >= 0 then -- 457
						introHold = v -- 459
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 460
					end -- 460
				end -- 460
			end -- 460
		end -- 460
		local n = tonumber(head) -- 465
		if n ~= nil and n >= 1 and n <= levelTotal then -- 465
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 467
			enterLevel(n - 1) -- 468
			autoEntered = true -- 469
			if at >= 0 then -- 469
				local rest = __TS__StringSubstring(spec, at + 1) -- 471
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 472
				local c2 = (string.find( -- 473
					rest, -- 473
					":", -- 473
					math.max(c1 + 1 + 1, 1), -- 473
					true -- 473
				) or 0) - 1 -- 473
				if c1 > 0 and c2 > c1 then -- 473
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 475
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 476
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 477
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 477
						autoLaunchAt = frames -- 479
						autoVX = vx -- 480
						autoVY = vy -- 481
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 482
					end -- 482
				end -- 482
			end -- 482
		end -- 482
	end -- 482
	if autoEntered then -- 482
		print("[escape-velocity] opening skipped (auto enter)") -- 492
	elseif forceIntro or not introSeen then -- 492
		startOpening() -- 494
	else -- 494
		startupPanel:show(progress.unlocked) -- 496
		print("[escape-velocity] opening skipped (already seen)") -- 497
	end -- 497
	threadLoop(function() -- 502
		if opening ~= nil and opening.running() then -- 502
			if introHold < 0 or opening.frameIndex() < introHold then -- 502
				opening.step() -- 506
			end -- 506
			if App.deltaTime > 0.05 then -- 506
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 510
					opening.frameIndex(), -- 510
					0 -- 510
				)) -- 510
			end -- 510
		end -- 510
		local runtime = activeRuntime() -- 514
		if runtime ~= nil then -- 514
			runtime.game:update(App.deltaTime) -- 516
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 516
				autoFrame = autoFrame + 1 -- 519
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 519
					autoLaunchAt = -1 -- 521
					print("[escape-velocity] auto launch") -- 522
					runtime.game:launch({x = autoVX, y = autoVY}) -- 523
					autoBackAt = autoFrame + 320 -- 524
					autoReenterAt = autoFrame + 380 -- 525
				end -- 525
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 525
					autoBackAt = -1 -- 529
					if runtime.game:backToSelect() then -- 529
						print("[escape-velocity] auto back to select") -- 530
					end -- 530
				end -- 530
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 530
					autoReenterAt = -1 -- 533
					print("[escape-velocity] auto re-enter") -- 534
					enterLevel(0) -- 535
				end -- 535
			end -- 535
		end -- 535
		return false -- 540
	end) -- 502
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 544
end -- 544
return ____exports -- 544
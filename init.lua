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
local ____PlanView = require("game.PlanView") -- 26
local arrivalRingRadius = ____PlanView.arrivalRingRadius -- 26
local createPlanView = ____PlanView.createPlanView -- 26
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 26
local planFitRadius = ____PlanView.planFitRadius -- 26
local ____Hud = require("game.Hud") -- 27
local FinaleMainText = ____Hud.FinaleMainText -- 27
local createAimInput = ____Hud.createAimInput -- 27
local createFinalePanel = ____Hud.createFinalePanel -- 27
local createLevelSelect = ____Hud.createLevelSelect -- 27
local createResultPanel = ____Hud.createResultPanel -- 27
local finaleSubtitle = ____Hud.finaleSubtitle -- 27
local ____Game = require("game.Game") -- 28
local createGame = ____Game.createGame -- 28
local ____Progress = require("game.Progress") -- 29
local advanceUnlocked = ____Progress.advanceUnlocked -- 29
local loadProgress = ____Progress.loadProgress -- 29
local progressFilePath = ____Progress.progressFilePath -- 29
local saveProgress = ____Progress.saveProgress -- 29
local ____Ui = require("game.Ui") -- 31
local advanceUiClock = ____Ui.advanceUiClock -- 31
local ____Tuning = require("game.Tuning") -- 33
local levelRuntime = ____Tuning.levelRuntime -- 33
local ____Opening = require("game.Opening") -- 34
local createOpening = ____Opening.createOpening -- 34
local loadIntroSeen = ____Opening.loadIntroSeen -- 34
local saveIntroSeen = ____Opening.saveIntroSeen -- 34
local levelTotal = levelCount() -- 64
if levelTotal <= 0 then -- 64
	print("[escape-velocity] FATAL: no level data") -- 67
else -- 67
	local opening, startOpening, introHold -- 67
	local viewW = View.size.width -- 69
	local viewH = View.size.height -- 70
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 73
	local levelLayers = {} -- 79
	do -- 79
		local i = 0 -- 80
		while i < levelTotal do -- 80
			local layer = Node() -- 81
			layer.size = Size(viewW, viewH) -- 82
			layer.anchor = Vec2(0.5, 0.5) -- 83
			layer.position = Vec2(0, 0) -- 84
			Director.ui:addChild(layer) -- 85
			levelLayers[#levelLayers + 1] = layer -- 86
			i = i + 1 -- 80
		end -- 80
	end -- 80
	local openingLayer = Node() -- 91
	openingLayer.size = Size(viewW, viewH) -- 92
	openingLayer.anchor = Vec2(0.5, 0.5) -- 93
	openingLayer.position = Vec2(0, 0) -- 94
	Director.ui:addChild(openingLayer) -- 95
	local openingRoot = Node3D() -- 98
	openingRoot.visible = false -- 99
	Director.entry:addChild(openingRoot) -- 100
	local openingCamera = Camera3D() -- 101
	local uiLayer = Node() -- 104
	uiLayer.size = Size(viewW, viewH) -- 105
	uiLayer.anchor = Vec2(0.5, 0.5) -- 106
	uiLayer.position = Vec2(0, 0) -- 107
	Director.ui:addChild(uiLayer) -- 108
	local levelNames = {} -- 111
	do -- 111
		local i = 0 -- 112
		while i < levelTotal do -- 112
			local def = getLevel(i) -- 113
			local title = def ~= nil and def.title or "" -- 114
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 115
			i = i + 1 -- 112
		end -- 112
	end -- 112
	local levelEntries = {} -- 117
	do -- 117
		local i = 0 -- 118
		while i < levelTotal do -- 118
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 118
			i = i + 1 -- 118
		end -- 118
	end -- 118
	local progress = loadProgress(levelTotal) -- 121
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 122
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 123
	local slots = {} -- 125
	do -- 125
		local i = 0 -- 126
		while i < levelTotal do -- 126
			slots[#slots + 1] = {built = false, runtime = nil} -- 126
			i = i + 1 -- 126
		end -- 126
	end -- 126
	local activeIndex = -1 -- 128
	local select = nil -- 129
	local resultPanel = nil -- 130
	local finalePanel = nil -- 132
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 134
	local resultIndex = -1 -- 139
	local function activeRuntime() -- 141
		if activeIndex < 0 then -- 141
			return nil -- 142
		end -- 142
		return slots[activeIndex + 1].runtime -- 143
	end -- 141
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 151
		do -- 151
			local i = 0 -- 152
			while i < levelTotal do -- 152
				do -- 152
					local slot = slots[i + 1] -- 153
					levelLayers[i + 1].visible = i == index -- 156
					if slot.runtime == nil then -- 156
						goto __continue16 -- 157
					end -- 157
					local active = i == index -- 158
					slot.runtime.world.visible = active -- 159
					slot.runtime.aim:setEnabled(active) -- 160
					if active then -- 160
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 162
					end -- 162
				end -- 162
				::__continue16:: -- 162
				i = i + 1 -- 152
			end -- 152
		end -- 152
	end -- 151
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 171
		local game -- 171
		local slot = slots[index + 1] -- 172
		if slot.built and slot.runtime ~= nil then -- 172
			return slot.runtime -- 173
		end -- 173
		local def = getLevel(index) -- 175
		if def == nil then -- 175
			return nil -- 176
		end -- 176
		local bodies = scaledPlanets(def) -- 178
		local level = { -- 179
			bodies = bodies, -- 180
			probeStart = def.probeStart, -- 181
			probeVel0 = def.probeVel0, -- 183
			goal = def.goal, -- 184
			escapeRadius = def.escapeRadius, -- 185
			physicsStep = levelRuntime(index).physicsStep, -- 186
			playback = levelRuntime(index).playback, -- 187
			aimClockRate = levelRuntime(index).aimClockRate, -- 188
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 189
			aimMin = levelRuntime(index).aimMin, -- 190
			maxSteps = def.maxSteps -- 191
		} -- 191
		local world = Node3D() -- 194
		Director.entry:addChild(world) -- 195
		world.visible = false -- 196
		local rtg = def.probeVariant == "rtg" -- 198
		local scene = buildScene({ -- 199
			root = world, -- 200
			bodies = bodies, -- 201
			visuals = def.visuals, -- 202
			probeStart = level.probeStart, -- 203
			probeScale = levelRuntime(index).probeVisualRadius, -- 209
			spherePath = "Assets/Model/Sphere.gltf", -- 210
			ringPath = "Assets/Model/Ring.gltf", -- 211
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 212
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 219
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 220
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 221
			probeBodyRadius = rtg and 0.871 or 1.084, -- 222
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 224
		}) -- 224
		if scene == nil then -- 224
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 227
			return nil -- 228
		end -- 228
		local rt = levelRuntime(index) -- 231
		local camera = Camera3D() -- 232
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 235
		local trajectory = createTrajectoryView( -- 236
			levelLayers[index + 1], -- 236
			trajectoryOptions() -- 236
		) -- 236
		local plan = createPlanView( -- 239
			levelLayers[index + 1], -- 239
			viewW, -- 239
			viewH, -- 239
			defaultPlanOptions(), -- 239
			def.planCenter -- 239
		) -- 239
		local planTolerance = arrivalRingRadius(def.goal) -- 240
		plan:fitTo(planFitRadius( -- 241
			bodies, -- 241
			level.probeStart, -- 241
			def.goal.planetIndex, -- 241
			planTolerance, -- 241
			def.planCenter -- 241
		)) -- 241
		local aim = createAimInput( -- 243
			levelLayers[index + 1], -- 243
			viewW, -- 243
			viewH, -- 243
			def.dvBudget, -- 243
			rt.aimMin, -- 243
			rt.playbackSpeeds -- 243
		) -- 243
		aim:setBurnInfo(0, def.dvBudget) -- 245
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 247
		aim:setDate(0, dateSpan) -- 248
		aim:onWarp(function(dir) -- 249
			game:stepTime(dir, dateSpan) -- 250
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 251
		end) -- 249
		game = createGame( -- 254
			level, -- 254
			{ -- 254
				scene = scene, -- 255
				camera = camera, -- 256
				rig = rig, -- 257
				trajectory = trajectory, -- 258
				plan = plan, -- 259
				visuals = def.visuals, -- 261
				setWorldVisible = function(____, on) -- 263
					world.visible = on -- 264
				end, -- 263
				aim = aim, -- 266
				viewW = viewW, -- 267
				viewH = viewH, -- 268
				fovYDeg = View.fieldOfView, -- 269
				aspect = View.aspectRatio, -- 270
				onPhase = function(____, p) -- 271
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 272
					if index == activeIndex then -- 272
						if p == "Finale" then -- 272
							if resultPanel ~= nil then -- 272
								resultPanel:hide() -- 280
							end -- 280
							if finalePanel ~= nil then -- 280
								finalePanel:show(finaleText.main, finaleText.sub) -- 281
							end -- 281
						else -- 281
							if p ~= "Result" and resultPanel ~= nil then -- 281
								resultPanel:hide() -- 283
							end -- 283
							if finalePanel ~= nil then -- 283
								finalePanel:hide() -- 284
							end -- 284
						end -- 284
					end -- 284
				end, -- 271
				onResult = function(____, r) -- 288
					if r == "success" then -- 288
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 291
						if next ~= progress.unlocked then -- 291
							progress = {unlocked = next} -- 293
							saveProgress(progress) -- 294
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 295
						end -- 295
					end -- 295
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 298
					resultIndex = index -- 299
					if resultPanel ~= nil then -- 299
						resultPanel:show(r, levelNames[index + 1]) -- 300
					end -- 300
				end, -- 288
				onFinale = function(____, info) -- 303
					finaleText = { -- 304
						main = FinaleMainText, -- 304
						sub = finaleSubtitle(info.distance, info.time) -- 304
					} -- 304
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 305
				end, -- 303
				finale = index == levelTotal - 1 -- 310
			} -- 310
		) -- 310
		aim:onDrag(function(a) -- 316
			game:onAimDrag(a) -- 317
			aim:setBurnInfo( -- 319
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 319
				def.dvBudget -- 319
			) -- 319
		end) -- 316
		aim:onAimReady(function(a) -- 322
			game:onAimDrag(a) -- 323
			game:aimReady() -- 324
			print("[escape-velocity] aim ready -> Armed") -- 325
		end) -- 322
		aim:onLaunch(function() -- 327
			print("[escape-velocity] launch button tap") -- 328
			game:launchArmed() -- 329
		end) -- 327
		aim:onObserve(function(dx, dy) -- 332
			game:observeDrag(dx, dy) -- 333
		end) -- 332
		aim:onZoom(function(deltaDist) -- 335
			game:observeZoom(deltaDist) -- 336
		end) -- 335
		aim:onViewToggle(function() -- 339
			game:toggleViewMode() -- 340
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 341
		end) -- 339
		aim:onBrake(function(on) -- 344
			game:setBrakeMode(on) -- 345
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 346
		end) -- 344
		aim:setBrake(game:brakeMode()) -- 348
		aim:onPlayback(function(speed) -- 351
			game:setPlaybackSpeed(speed) -- 352
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 353
		end) -- 351
		aim:setPlayback(game:playbackSpeed()) -- 355
		local runtime = { -- 357
			index = index, -- 358
			name = levelNames[index + 1], -- 359
			world = world, -- 360
			camera = camera, -- 361
			game = game, -- 362
			aim = aim, -- 363
			trajectory = trajectory, -- 364
			plan = plan, -- 365
			levelHasTimeWindow = def.timeWindow ~= nil, -- 366
			dvBudget = def.dvBudget, -- 367
			dateSpan = dateSpan -- 368
		} -- 368
		slot.built = true -- 370
		slot.runtime = runtime -- 371
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 372
		return runtime -- 373
	end -- 171
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 377
		local runtime = ensureLevel(index) -- 378
		if runtime == nil then -- 378
			return -- 379
		end -- 379
		local wasActive = activeIndex == index -- 382
		if opening ~= nil then -- 382
			opening.hide() -- 384
		end -- 384
		if select ~= nil then -- 384
			select:hide() -- 385
		end -- 385
		activeIndex = index -- 386
		showOnlyLevel(index) -- 387
		if not wasActive then -- 387
			Director:pushCamera(runtime.camera) -- 388
		end -- 388
		runtime.game:startLevel() -- 389
		print("[escape-velocity] enter " .. runtime.name) -- 390
	end -- 377
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 394
		if resultIndex >= 0 and resultIndex < levelTotal then -- 394
			local rt = slots[resultIndex + 1].runtime -- 396
			if rt ~= nil then -- 396
				return rt -- 397
			end -- 397
		end -- 397
		return activeRuntime() -- 399
	end -- 394
	local function onRetryTap() -- 402
		local rt = resultRuntime() -- 404
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 405
		if resultPanel ~= nil then -- 405
			resultPanel:hide() -- 406
		end -- 406
		if rt ~= nil then -- 406
			rt.game:retry() -- 407
		end -- 407
	end -- 402
	local function onBackToSelectTap() -- 410
		local rt = resultRuntime() -- 411
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 412
		if rt == nil then -- 412
			return -- 413
		end -- 413
		local runtime = rt -- 414
		if not runtime.game:backToSelect() then -- 414
			return -- 416
		end -- 416
		runtime.world.visible = false -- 417
		runtime.aim:setEnabled(false) -- 418
		if resultPanel ~= nil then -- 418
			resultPanel:hide() -- 419
		end -- 419
		if finalePanel ~= nil then -- 419
			finalePanel:hide() -- 421
		end -- 421
		progress = loadProgress(levelTotal) -- 423
		if select ~= nil then -- 423
			select:show(progress.unlocked) -- 424
		end -- 424
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 425
	end -- 410
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 438
		finalePanel = createFinalePanel( -- 441
			uiLayer, -- 441
			viewW, -- 441
			viewH, -- 441
			{onBackToSelect = function() return onBackToSelectTap() end} -- 441
		) -- 441
		resultPanel = createResultPanel( -- 444
			uiLayer, -- 444
			viewW, -- 444
			viewH, -- 444
			{ -- 444
				onRetry = function() return onRetryTap() end, -- 445
				onBackToSelect = function() return onBackToSelectTap() end -- 446
			} -- 446
		) -- 446
		local created = createLevelSelect( -- 448
			uiLayer, -- 448
			viewW, -- 448
			viewH, -- 448
			{ -- 448
				levels = levelEntries, -- 449
				onPick = function(____, index) -- 450
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 451
					if select ~= nil then -- 451
						select:hide() -- 452
					end -- 452
					enterLevel(index) -- 453
				end, -- 450
				onReplayIntro = function() -- 456
					if select ~= nil then -- 456
						select:hide() -- 457
					end -- 457
					startOpening() -- 458
					print("[escape-velocity] opening replay (user)") -- 459
				end -- 456
			} -- 456
		) -- 456
		select = created -- 462
		return created -- 463
	end -- 438
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 476
		local w = View.size.width -- 477
		local h = View.size.height -- 478
		if w == viewW and h == viewH then -- 478
			return -- 479
		end -- 479
		if opening ~= nil then -- 479
			opening.hide() -- 485
			opening = nil -- 486
		end -- 486
		if select ~= nil then -- 486
			select:hide() -- 488
		end -- 488
		if resultPanel ~= nil then -- 488
			resultPanel:hide() -- 489
		end -- 489
		if finalePanel ~= nil then -- 489
			finalePanel:hide() -- 490
		end -- 490
		do -- 490
			local i = 0 -- 491
			while i < levelTotal do -- 491
				local slot = slots[i + 1] -- 492
				if slot.runtime ~= nil then -- 492
					slot.runtime.world.visible = false -- 494
					slot.runtime.aim:setEnabled(false) -- 495
					slot.runtime.trajectory:clearPrediction() -- 498
					slot.runtime.trajectory:clearTrail() -- 499
					slot.runtime.trajectory:clearGoalRings() -- 501
					slot.runtime.plan:setVisible(false) -- 504
					slot.runtime.plan:clear() -- 505
				end -- 505
				slot.built = false -- 507
				slot.runtime = nil -- 508
				i = i + 1 -- 491
			end -- 491
		end -- 491
		viewW = w -- 512
		viewH = h -- 513
		uiLayer.size = Size(viewW, viewH) -- 514
		openingLayer.size = Size(viewW, viewH) -- 515
		do -- 515
			local i = 0 -- 516
			while i < levelTotal do -- 516
				levelLayers[i + 1].size = Size(viewW, viewH) -- 516
				i = i + 1 -- 516
			end -- 516
		end -- 516
		local panel = buildPanels() -- 519
		if activeIndex >= 0 then -- 519
			local keep = activeIndex -- 521
			activeIndex = -1 -- 522
			enterLevel(keep) -- 523
		else -- 523
			panel:show(progress.unlocked) -- 525
		end -- 525
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 527
	end -- 476
	Director.entry:onAppChange(function(name) -- 531
		if name == "Size" then -- 531
			relayoutForViewport() -- 532
		end -- 532
	end) -- 531
	local introSeen = loadIntroSeen() -- 540
	local forceIntro = false -- 541
	opening = nil -- 542
	startOpening = function() -- 544
		if opening == nil then -- 544
			opening = createOpening({ -- 546
				root = openingRoot, -- 547
				camera = openingCamera, -- 548
				layer = openingLayer, -- 549
				viewW = viewW, -- 550
				viewH = viewH, -- 551
				fovYDeg = View.fieldOfView, -- 552
				aspect = View.aspectRatio, -- 553
				spherePath = "Assets/Model/Sphere.gltf", -- 554
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 555
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 556
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 557
				onFinish = function() -- 558
					introHold = -1 -- 559
					if not introSeen then -- 559
						saveIntroSeen() -- 561
						introSeen = true -- 562
						print("[escape-velocity] intro seen -> saved") -- 563
					end -- 563
					if select ~= nil then -- 563
						select:show(progress.unlocked) -- 566
					end -- 566
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 567
						opening.frameIndex(), -- 567
						0 -- 567
					) or "?")) -- 567
				end -- 558
			}) -- 558
		end -- 558
		if opening == nil then -- 558
			return -- 571
		end -- 571
		Director:pushCamera(openingCamera) -- 572
		opening.start() -- 573
		print("[escape-velocity] opening start (first launch)") -- 574
	end -- 544
	local startupPanel = buildPanels() -- 577
	local enterReq = Path( -- 589
		Path(".", ".agent", "test-results"), -- 589
		"enter-request.txt" -- 589
	) -- 589
	local autoLaunchAt = -1 -- 590
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 592
	local autoFrame = 0 -- 593
	local autoVX = 0 -- 594
	local autoVY = 0 -- 595
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 603
	local autoBackAt = -1 -- 605
	local autoReenterAt = -1 -- 606
	local autoEntered = false -- 607
	introHold = -1 -- 609
	if Content:exist(enterReq) then -- 609
		local spec = Content:load(enterReq) -- 611
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 612
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 613
		if head == "intro" then -- 613
			forceIntro = true -- 615
			if at >= 0 then -- 615
				local rest = __TS__StringSubstring(spec, at + 1) -- 617
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 618
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 618
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 620
					if v ~= nil and v >= 0 then -- 620
						introHold = v -- 622
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 623
					end -- 623
				end -- 623
			end -- 623
		end -- 623
		local n = tonumber(head) -- 628
		if n ~= nil and n >= 1 and n <= levelTotal then -- 628
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 630
			enterLevel(n - 1) -- 631
			autoEntered = true -- 632
			if at >= 0 then -- 632
				local rest = __TS__StringSubstring(spec, at + 1) -- 634
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 634
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 639
					if f ~= nil and f >= 0 then -- 639
						autoArmAt = f -- 641
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 642
					end -- 642
				else -- 642
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 645
					local c2 = (string.find( -- 646
						rest, -- 646
						":", -- 646
						math.max(c1 + 1 + 1, 1), -- 646
						true -- 646
					) or 0) - 1 -- 646
					if c1 > 0 and c2 > c1 then -- 646
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 648
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 649
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 652
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 653
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 654
						local vy = tonumber(vyText) -- 655
						local ____temp_0 -- 656
						if c3 > 0 then -- 656
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 656
						else -- 656
							____temp_0 = nil -- 656
						end -- 656
						local steps = ____temp_0 -- 656
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 656
							autoLaunchAt = frames -- 658
							autoVX = vx -- 659
							autoVY = vy -- 660
							if steps ~= nil and steps > 0 then -- 660
								autoWarpSteps = math.floor(steps) -- 662
							end -- 662
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 664
						end -- 664
					end -- 664
				end -- 664
			end -- 664
		end -- 664
	end -- 664
	if autoEntered then -- 664
		print("[escape-velocity] opening skipped (auto enter)") -- 677
	elseif forceIntro or not introSeen then -- 677
		startOpening() -- 679
	else -- 679
		startupPanel:show(progress.unlocked) -- 681
		print("[escape-velocity] opening skipped (already seen)") -- 682
	end -- 682
	threadLoop(function() -- 687
		advanceUiClock(App.deltaTime) -- 691
		if opening ~= nil and opening.running() then -- 691
			if introHold < 0 or opening.frameIndex() < introHold then -- 691
				opening.step() -- 695
			end -- 695
			if App.deltaTime > 0.05 then -- 695
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 699
					opening.frameIndex(), -- 699
					0 -- 699
				)) -- 699
			end -- 699
		end -- 699
		local runtime = activeRuntime() -- 703
		if runtime ~= nil then -- 703
			runtime.game:update(App.deltaTime) -- 705
			runtime.aim:setBurnInfo( -- 707
				runtime.game:burnNow(), -- 707
				runtime.dvBudget -- 707
			) -- 707
			if runtime.levelHasTimeWindow then -- 707
				runtime.aim:setDate( -- 710
					runtime.game:dateNow(), -- 710
					runtime.dateSpan -- 710
				) -- 710
			end -- 710
			local phaseNow = runtime.game:phase() -- 714
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 715
			runtime.aim:update(App.deltaTime) -- 716
			runtime.aim:setArmed(runtime.game:armed()) -- 718
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 720
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 722
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 723
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 723
				autoFrame = autoFrame + 1 -- 726
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 726
					autoArmAt = -1 -- 729
					print("[escape-velocity] auto arm (enter-request)") -- 730
					runtime.game:aimReady() -- 731
				end -- 731
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 731
					autoLaunchAt = -1 -- 734
					print("[escape-velocity] auto launch") -- 735
					if autoWarpSteps > 0 then -- 735
						do -- 735
							local s = 0 -- 739
							while s < autoWarpSteps do -- 739
								runtime.game:stepTime(1, runtime.dateSpan) -- 739
								s = s + 1 -- 739
							end -- 739
						end -- 739
						autoWarpSteps = 0 -- 740
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 741
							runtime.game:dateNow(), -- 741
							0 -- 741
						)) .. ")") -- 741
					end -- 741
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 743
					runtime.game:launch({x = autoVX, y = autoVY}) -- 744
					autoBackAt = autoFrame + 320 -- 745
					autoReenterAt = autoFrame + 380 -- 746
				end -- 746
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 746
					autoBackAt = -1 -- 750
					if runtime.game:backToSelect() then -- 750
						print("[escape-velocity] auto back to select") -- 751
					end -- 751
				end -- 751
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 751
					autoReenterAt = -1 -- 754
					print("[escape-velocity] auto re-enter") -- 755
					enterLevel(0) -- 756
				end -- 756
			end -- 756
		end -- 756
		return false -- 761
	end) -- 687
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 765
end -- 765
return ____exports -- 765
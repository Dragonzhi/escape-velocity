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
local getTotalRockets = ____Progress.getTotalRockets -- 29
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
local ____SolarHub = require("game.SolarHub") -- 35
local createSolarHub = ____SolarHub.createSolarHub -- 35
local levelTotal = levelCount() -- 65
if levelTotal <= 0 then -- 65
	print("[escape-velocity] FATAL: no level data") -- 68
else -- 68
	local opening, startOpening, introHold -- 68
	local viewW = View.size.width -- 70
	local viewH = View.size.height -- 71
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 74
	local levelLayers = {} -- 80
	do -- 80
		local i = 0 -- 81
		while i < levelTotal do -- 81
			local layer = Node() -- 82
			layer.size = Size(viewW, viewH) -- 83
			layer.anchor = Vec2(0.5, 0.5) -- 84
			layer.position = Vec2(0, 0) -- 85
			Director.ui:addChild(layer) -- 86
			levelLayers[#levelLayers + 1] = layer -- 87
			i = i + 1 -- 81
		end -- 81
	end -- 81
	local openingLayer = Node() -- 92
	openingLayer.size = Size(viewW, viewH) -- 93
	openingLayer.anchor = Vec2(0.5, 0.5) -- 94
	openingLayer.position = Vec2(0, 0) -- 95
	Director.ui:addChild(openingLayer) -- 96
	local openingRoot = Node3D() -- 99
	openingRoot.visible = false -- 100
	Director.entry:addChild(openingRoot) -- 101
	local openingCamera = Camera3D() -- 102
	local hubRoot = Node3D() -- 105
	hubRoot.visible = false -- 106
	Director.entry:addChild(hubRoot) -- 107
	local hubCamera = Camera3D() -- 108
	local hubLayer = Node() -- 110
	hubLayer.size = Size(viewW, viewH) -- 111
	hubLayer.anchor = Vec2(0.5, 0.5) -- 112
	hubLayer.position = Vec2(0, 0) -- 113
	Director.ui:addChild(hubLayer) -- 114
	local uiLayer = Node() -- 117
	uiLayer.size = Size(viewW, viewH) -- 118
	uiLayer.anchor = Vec2(0.5, 0.5) -- 119
	uiLayer.position = Vec2(0, 0) -- 120
	Director.ui:addChild(uiLayer) -- 121
	local levelNames = {} -- 124
	do -- 124
		local i = 0 -- 125
		while i < levelTotal do -- 125
			local def = getLevel(i) -- 126
			local title = def ~= nil and def.title or "" -- 127
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 128
			i = i + 1 -- 125
		end -- 125
	end -- 125
	local levelEntries = {} -- 130
	do -- 130
		local i = 0 -- 131
		while i < levelTotal do -- 131
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 131
			i = i + 1 -- 131
		end -- 131
	end -- 131
	local progress = loadProgress(levelTotal) -- 134
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 135
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 136
	local slots = {} -- 138
	do -- 138
		local i = 0 -- 139
		while i < levelTotal do -- 139
			slots[#slots + 1] = {built = false, runtime = nil} -- 139
			i = i + 1 -- 139
		end -- 139
	end -- 139
	local activeIndex = -1 -- 141
	local select = nil -- 142
	local solarHub = nil -- 143
	local resultPanel = nil -- 144
	local finalePanel = nil -- 146
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 148
	local resultIndex = -1 -- 153
	local function activeRuntime() -- 155
		if activeIndex < 0 then -- 155
			return nil -- 156
		end -- 156
		return slots[activeIndex + 1].runtime -- 157
	end -- 155
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 165
		do -- 165
			local i = 0 -- 166
			while i < levelTotal do -- 166
				do -- 166
					local slot = slots[i + 1] -- 167
					levelLayers[i + 1].visible = i == index -- 170
					if slot.runtime == nil then -- 170
						goto __continue16 -- 171
					end -- 171
					local active = i == index -- 172
					slot.runtime.world.visible = active -- 173
					slot.runtime.aim:setEnabled(active) -- 174
					if active then -- 174
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 176
					end -- 176
				end -- 176
				::__continue16:: -- 176
				i = i + 1 -- 166
			end -- 166
		end -- 166
	end -- 165
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 185
		local game -- 185
		local slot = slots[index + 1] -- 186
		if slot.built and slot.runtime ~= nil then -- 186
			return slot.runtime -- 187
		end -- 187
		local def = getLevel(index) -- 189
		if def == nil then -- 189
			return nil -- 190
		end -- 190
		local bodies = scaledPlanets(def) -- 192
		local level = { -- 193
			bodies = bodies, -- 194
			probeStart = def.probeStart, -- 195
			probeVel0 = def.probeVel0, -- 197
			goal = def.goal, -- 198
			escapeRadius = def.escapeRadius, -- 199
			physicsStep = levelRuntime(index).physicsStep, -- 200
			playback = levelRuntime(index).playback, -- 201
			aimClockRate = levelRuntime(index).aimClockRate, -- 202
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 203
			aimMin = levelRuntime(index).aimMin, -- 204
			maxSteps = def.maxSteps -- 205
		} -- 205
		local world = Node3D() -- 208
		Director.entry:addChild(world) -- 209
		world.visible = false -- 210
		local rtg = def.probeVariant == "rtg" -- 212
		local scene = buildScene({ -- 213
			root = world, -- 214
			bodies = bodies, -- 215
			visuals = def.visuals, -- 216
			probeStart = level.probeStart, -- 217
			probeScale = levelRuntime(index).probeVisualRadius, -- 223
			spherePath = "Assets/Model/Sphere.gltf", -- 224
			ringPath = "Assets/Model/Ring.gltf", -- 225
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 226
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 233
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 234
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 235
			probeBodyRadius = rtg and 0.871 or 1.084, -- 236
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 238
		}) -- 238
		if scene == nil then -- 238
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 241
			return nil -- 242
		end -- 242
		local rt = levelRuntime(index) -- 245
		local camera = Camera3D() -- 246
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 249
		local trajectory = createTrajectoryView( -- 250
			levelLayers[index + 1], -- 250
			trajectoryOptions() -- 250
		) -- 250
		local plan = createPlanView( -- 253
			levelLayers[index + 1], -- 253
			viewW, -- 253
			viewH, -- 253
			defaultPlanOptions(), -- 253
			def.planCenter -- 253
		) -- 253
		local planTolerance = arrivalRingRadius(def.goal) -- 254
		plan:fitTo(planFitRadius( -- 255
			bodies, -- 255
			level.probeStart, -- 255
			def.goal.planetIndex, -- 255
			planTolerance, -- 255
			def.planCenter -- 255
		)) -- 255
		local aim = createAimInput( -- 257
			levelLayers[index + 1], -- 257
			viewW, -- 257
			viewH, -- 257
			def.dvBudget, -- 257
			rt.aimMin, -- 257
			rt.playbackSpeeds -- 257
		) -- 257
		aim:setBurnInfo(0, def.dvBudget) -- 259
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 261
		aim:setDate(0, dateSpan) -- 262
		aim:onWarp(function(dir) -- 263
			game:stepTime(dir, dateSpan) -- 264
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 265
		end) -- 263
		game = createGame( -- 268
			level, -- 268
			{ -- 268
				scene = scene, -- 269
				camera = camera, -- 270
				rig = rig, -- 271
				trajectory = trajectory, -- 272
				plan = plan, -- 273
				visuals = def.visuals, -- 275
				setWorldVisible = function(____, on) -- 277
					world.visible = on -- 278
				end, -- 277
				aim = aim, -- 280
				viewW = viewW, -- 281
				viewH = viewH, -- 282
				fovYDeg = View.fieldOfView, -- 283
				aspect = View.aspectRatio, -- 284
				onPhase = function(____, p) -- 285
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 286
					if index == activeIndex then -- 286
						if p == "Finale" then -- 286
							if resultPanel ~= nil then -- 286
								resultPanel:hide() -- 294
							end -- 294
							if finalePanel ~= nil then -- 294
								finalePanel:show(finaleText.main, finaleText.sub) -- 295
							end -- 295
						else -- 295
							if p ~= "Result" and resultPanel ~= nil then -- 295
								resultPanel:hide() -- 297
							end -- 297
							if finalePanel ~= nil then -- 297
								finalePanel:hide() -- 298
							end -- 298
						end -- 298
					end -- 298
				end, -- 285
				onResult = function(____, r) -- 302
					if r == "success" then -- 302
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 305
						if next ~= progress.unlocked then -- 305
							progress = {unlocked = next} -- 307
							saveProgress(progress) -- 308
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 309
						end -- 309
					end -- 309
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 312
					resultIndex = index -- 313
					if resultPanel ~= nil then -- 313
						resultPanel:show(r, levelNames[index + 1]) -- 314
					end -- 314
				end, -- 302
				onFinale = function(____, info) -- 317
					finaleText = { -- 318
						main = FinaleMainText, -- 318
						sub = finaleSubtitle(info.distance, info.time) -- 318
					} -- 318
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 319
				end, -- 317
				finale = index == levelTotal - 1 -- 324
			} -- 324
		) -- 324
		aim:onDrag(function(a) -- 330
			game:onAimDrag(a) -- 331
			aim:setBurnInfo( -- 333
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 333
				def.dvBudget -- 333
			) -- 333
		end) -- 330
		aim:onAimReady(function(a) -- 336
			game:onAimDrag(a) -- 337
			game:aimReady() -- 338
			print("[escape-velocity] aim ready -> Armed") -- 339
		end) -- 336
		aim:onLaunch(function() -- 341
			print("[escape-velocity] launch button tap") -- 342
			game:launchArmed() -- 343
		end) -- 341
		aim:onObserve(function(dx, dy) -- 346
			game:observeDrag(dx, dy) -- 347
		end) -- 346
		aim:onZoom(function(deltaDist) -- 349
			game:observeZoom(deltaDist) -- 350
		end) -- 349
		aim:onViewToggle(function() -- 353
			game:toggleViewMode() -- 354
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 355
		end) -- 353
		aim:onBrake(function(on) -- 358
			game:setBrakeMode(on) -- 359
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 360
		end) -- 358
		aim:setBrake(game:brakeMode()) -- 362
		aim:onPlayback(function(speed) -- 365
			game:setPlaybackSpeed(speed) -- 366
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 367
		end) -- 365
		aim:setPlayback(game:playbackSpeed()) -- 369
		local runtime = { -- 371
			index = index, -- 372
			name = levelNames[index + 1], -- 373
			world = world, -- 374
			camera = camera, -- 375
			game = game, -- 376
			aim = aim, -- 377
			trajectory = trajectory, -- 378
			plan = plan, -- 379
			levelHasTimeWindow = def.timeWindow ~= nil, -- 380
			dvBudget = def.dvBudget, -- 381
			dateSpan = dateSpan -- 382
		} -- 382
		slot.built = true -- 384
		slot.runtime = runtime -- 385
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 386
		return runtime -- 387
	end -- 185
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 391
		local runtime = ensureLevel(index) -- 392
		if runtime == nil then -- 392
			return -- 393
		end -- 393
		local wasActive = activeIndex == index -- 396
		if opening ~= nil then -- 396
			opening.hide() -- 398
		end -- 398
		if select ~= nil then -- 398
			select:hide() -- 399
		end -- 399
		if solarHub ~= nil then -- 399
			solarHub.hide() -- 400
		end -- 400
		activeIndex = index -- 401
		showOnlyLevel(index) -- 402
		if not wasActive then -- 402
			Director:pushCamera(runtime.camera) -- 403
		end -- 403
		runtime.game:startLevel() -- 404
		print("[escape-velocity] enter " .. runtime.name) -- 405
	end -- 391
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 409
		if resultIndex >= 0 and resultIndex < levelTotal then -- 409
			local rt = slots[resultIndex + 1].runtime -- 411
			if rt ~= nil then -- 411
				return rt -- 412
			end -- 412
		end -- 412
		return activeRuntime() -- 414
	end -- 409
	local function onRetryTap() -- 417
		local rt = resultRuntime() -- 419
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 420
		if resultPanel ~= nil then -- 420
			resultPanel:hide() -- 421
		end -- 421
		if rt ~= nil then -- 421
			rt.game:retry() -- 422
		end -- 422
	end -- 417
	local function ensureSolarHub() -- 425
		if solarHub ~= nil then -- 425
			return solarHub -- 426
		end -- 426
		solarHub = createSolarHub({ -- 427
			root = hubRoot, -- 428
			camera = hubCamera, -- 429
			layer = hubLayer, -- 430
			viewW = viewW, -- 431
			viewH = viewH, -- 432
			fovYDeg = View.fieldOfView, -- 433
			aspect = View.aspectRatio, -- 434
			spherePath = "Assets/Model/Sphere.gltf", -- 435
			onLaunch = function(____, levelIndex) -- 436
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 437
				if solarHub ~= nil then -- 437
					solarHub.hide() -- 438
				end -- 438
				enterLevel(levelIndex) -- 439
			end, -- 436
			onReplayIntro = function() -- 441
				if solarHub ~= nil then -- 441
					solarHub.hide() -- 442
				end -- 442
				startOpening() -- 443
				print("[escape-velocity] opening replay from solarHub") -- 444
			end -- 441
		}) -- 441
		return solarHub -- 447
	end -- 425
	local function onBackToSelectTap() -- 450
		local rt = resultRuntime() -- 451
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 452
		if rt == nil then -- 452
			return -- 453
		end -- 453
		local runtime = rt -- 454
		if not runtime.game:backToSelect() then -- 454
			return -- 456
		end -- 456
		runtime.world.visible = false -- 457
		runtime.aim:setEnabled(false) -- 458
		if resultPanel ~= nil then -- 458
			resultPanel:hide() -- 459
		end -- 459
		if finalePanel ~= nil then -- 459
			finalePanel:hide() -- 461
		end -- 461
		if select ~= nil then -- 461
			select:hide() -- 462
		end -- 462
		progress = loadProgress(levelTotal) -- 464
		local hub = ensureSolarHub() -- 465
		Director:pushCamera(hubCamera) -- 466
		hub.show(progress) -- 467
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 468
			getTotalRockets(progress, levelTotal), -- 468
			0 -- 468
		)) -- 468
	end -- 450
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 481
		finalePanel = createFinalePanel( -- 484
			uiLayer, -- 484
			viewW, -- 484
			viewH, -- 484
			{onBackToSelect = function() return onBackToSelectTap() end} -- 484
		) -- 484
		resultPanel = createResultPanel( -- 487
			uiLayer, -- 487
			viewW, -- 487
			viewH, -- 487
			{ -- 487
				onRetry = function() return onRetryTap() end, -- 488
				onBackToSelect = function() return onBackToSelectTap() end -- 489
			} -- 489
		) -- 489
		local created = createLevelSelect( -- 491
			uiLayer, -- 491
			viewW, -- 491
			viewH, -- 491
			{ -- 491
				levels = levelEntries, -- 492
				onPick = function(____, index) -- 493
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 494
					if select ~= nil then -- 494
						select:hide() -- 495
					end -- 495
					enterLevel(index) -- 496
				end, -- 493
				onReplayIntro = function() -- 499
					if select ~= nil then -- 499
						select:hide() -- 500
					end -- 500
					startOpening() -- 501
					print("[escape-velocity] opening replay (user)") -- 502
				end -- 499
			} -- 499
		) -- 499
		select = created -- 505
		return created -- 506
	end -- 481
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 519
		local w = View.size.width -- 520
		local h = View.size.height -- 521
		if w == viewW and h == viewH then -- 521
			return -- 522
		end -- 522
		if opening ~= nil then -- 522
			opening.hide() -- 528
			opening = nil -- 529
		end -- 529
		if select ~= nil then -- 529
			select:hide() -- 531
		end -- 531
		if resultPanel ~= nil then -- 531
			resultPanel:hide() -- 532
		end -- 532
		if finalePanel ~= nil then -- 532
			finalePanel:hide() -- 533
		end -- 533
		do -- 533
			local i = 0 -- 534
			while i < levelTotal do -- 534
				local slot = slots[i + 1] -- 535
				if slot.runtime ~= nil then -- 535
					slot.runtime.world.visible = false -- 537
					slot.runtime.aim:setEnabled(false) -- 538
					slot.runtime.trajectory:clearPrediction() -- 541
					slot.runtime.trajectory:clearTrail() -- 542
					slot.runtime.trajectory:clearGoalRings() -- 544
					slot.runtime.plan:setVisible(false) -- 547
					slot.runtime.plan:clear() -- 548
				end -- 548
				slot.built = false -- 550
				slot.runtime = nil -- 551
				i = i + 1 -- 534
			end -- 534
		end -- 534
		viewW = w -- 555
		viewH = h -- 556
		uiLayer.size = Size(viewW, viewH) -- 557
		openingLayer.size = Size(viewW, viewH) -- 558
		hubLayer.size = Size(viewW, viewH) -- 559
		do -- 559
			local i = 0 -- 560
			while i < levelTotal do -- 560
				levelLayers[i + 1].size = Size(viewW, viewH) -- 560
				i = i + 1 -- 560
			end -- 560
		end -- 560
		if solarHub ~= nil then -- 560
			solarHub.relayout(viewW, viewH) -- 562
		end -- 562
		buildPanels() -- 566
		if activeIndex >= 0 then -- 566
			local keep = activeIndex -- 568
			activeIndex = -1 -- 569
			enterLevel(keep) -- 570
		else -- 570
			local hub = ensureSolarHub() -- 572
			Director:pushCamera(hubCamera) -- 573
			hub.show(progress) -- 574
		end -- 574
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 576
	end -- 519
	Director.entry:onAppChange(function(name) -- 580
		if name == "Size" then -- 580
			relayoutForViewport() -- 581
		end -- 581
	end) -- 580
	local introSeen = loadIntroSeen() -- 589
	local forceIntro = false -- 590
	opening = nil -- 591
	startOpening = function() -- 593
		if opening == nil then -- 593
			opening = createOpening({ -- 595
				root = openingRoot, -- 596
				camera = openingCamera, -- 597
				layer = openingLayer, -- 598
				viewW = viewW, -- 599
				viewH = viewH, -- 600
				fovYDeg = View.fieldOfView, -- 601
				aspect = View.aspectRatio, -- 602
				spherePath = "Assets/Model/Sphere.gltf", -- 603
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 604
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 605
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 606
				onFinish = function() -- 607
					introHold = -1 -- 608
					if not introSeen then -- 608
						saveIntroSeen() -- 610
						introSeen = true -- 611
						print("[escape-velocity] intro seen -> saved") -- 612
					end -- 612
					if opening ~= nil then -- 612
						opening.hide() -- 615
					end -- 615
					if select ~= nil then -- 615
						select:hide() -- 616
					end -- 616
					local hub = ensureSolarHub() -- 617
					Director:pushCamera(hubCamera) -- 618
					hub.show(progress) -- 619
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 620
						opening.frameIndex(), -- 620
						0 -- 620
					) or "?")) -- 620
				end -- 607
			}) -- 607
		end -- 607
		if opening == nil then -- 607
			return -- 624
		end -- 624
		Director:pushCamera(openingCamera) -- 625
		opening.start() -- 626
		print("[escape-velocity] opening start (first launch)") -- 627
	end -- 593
	local startupPanel = buildPanels() -- 630
	local enterReq = Path( -- 642
		Path(".", ".agent", "test-results"), -- 642
		"enter-request.txt" -- 642
	) -- 642
	local autoLaunchAt = -1 -- 643
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 645
	local autoFrame = 0 -- 646
	local autoVX = 0 -- 647
	local autoVY = 0 -- 648
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 656
	local autoBackAt = -1 -- 658
	local autoReenterAt = -1 -- 659
	local autoEntered = false -- 660
	introHold = -1 -- 662
	if Content:exist(enterReq) then -- 662
		local spec = Content:load(enterReq) -- 664
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 665
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 666
		if head == "intro" then -- 666
			forceIntro = true -- 668
			if at >= 0 then -- 668
				local rest = __TS__StringSubstring(spec, at + 1) -- 670
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 671
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 671
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 673
					if v ~= nil and v >= 0 then -- 673
						introHold = v -- 675
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 676
					end -- 676
				end -- 676
			end -- 676
		end -- 676
		local n = tonumber(head) -- 681
		if n ~= nil and n >= 1 and n <= levelTotal then -- 681
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 683
			enterLevel(n - 1) -- 684
			autoEntered = true -- 685
			if at >= 0 then -- 685
				local rest = __TS__StringSubstring(spec, at + 1) -- 687
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 687
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 692
					if f ~= nil and f >= 0 then -- 692
						autoArmAt = f -- 694
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 695
					end -- 695
				else -- 695
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 698
					local c2 = (string.find( -- 699
						rest, -- 699
						":", -- 699
						math.max(c1 + 1 + 1, 1), -- 699
						true -- 699
					) or 0) - 1 -- 699
					if c1 > 0 and c2 > c1 then -- 699
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 701
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 702
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 705
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 706
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 707
						local vy = tonumber(vyText) -- 708
						local ____temp_0 -- 709
						if c3 > 0 then -- 709
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 709
						else -- 709
							____temp_0 = nil -- 709
						end -- 709
						local steps = ____temp_0 -- 709
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 709
							autoLaunchAt = frames -- 711
							autoVX = vx -- 712
							autoVY = vy -- 713
							if steps ~= nil and steps > 0 then -- 713
								autoWarpSteps = math.floor(steps) -- 715
							end -- 715
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 717
						end -- 717
					end -- 717
				end -- 717
			end -- 717
		end -- 717
	end -- 717
	if autoEntered then -- 717
		print("[escape-velocity] opening skipped (auto enter)") -- 730
	elseif forceIntro or not introSeen then -- 730
		startOpening() -- 732
	else -- 732
		local hub = ensureSolarHub() -- 734
		Director:pushCamera(hubCamera) -- 735
		hub.show(progress) -- 736
		print("[escape-velocity] entered solarHub (already seen)") -- 737
	end -- 737
	threadLoop(function() -- 742
		advanceUiClock(App.deltaTime) -- 746
		if solarHub ~= nil and solarHub.visible() then -- 746
			solarHub.step(App.deltaTime) -- 750
		end -- 750
		if opening ~= nil and opening.running() then -- 750
			if introHold < 0 or opening.frameIndex() < introHold then -- 750
				opening.step() -- 756
			end -- 756
			if App.deltaTime > 0.05 then -- 756
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 760
					opening.frameIndex(), -- 760
					0 -- 760
				)) -- 760
			end -- 760
		end -- 760
		local runtime = activeRuntime() -- 764
		if runtime ~= nil then -- 764
			runtime.game:update(App.deltaTime) -- 766
			runtime.aim:setBurnInfo( -- 768
				runtime.game:burnNow(), -- 768
				runtime.dvBudget -- 768
			) -- 768
			if runtime.levelHasTimeWindow then -- 768
				runtime.aim:setDate( -- 771
					runtime.game:dateNow(), -- 771
					runtime.dateSpan -- 771
				) -- 771
			end -- 771
			local phaseNow = runtime.game:phase() -- 775
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 776
			runtime.aim:update(App.deltaTime) -- 777
			runtime.aim:setArmed(runtime.game:armed()) -- 779
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 781
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 783
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 784
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 784
				autoFrame = autoFrame + 1 -- 787
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 787
					autoArmAt = -1 -- 790
					print("[escape-velocity] auto arm (enter-request)") -- 791
					runtime.game:aimReady() -- 792
				end -- 792
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 792
					autoLaunchAt = -1 -- 795
					print("[escape-velocity] auto launch") -- 796
					if autoWarpSteps > 0 then -- 796
						do -- 796
							local s = 0 -- 800
							while s < autoWarpSteps do -- 800
								runtime.game:stepTime(1, runtime.dateSpan) -- 800
								s = s + 1 -- 800
							end -- 800
						end -- 800
						autoWarpSteps = 0 -- 801
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 802
							runtime.game:dateNow(), -- 802
							0 -- 802
						)) .. ")") -- 802
					end -- 802
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 804
					runtime.game:launch({x = autoVX, y = autoVY}) -- 805
					autoBackAt = autoFrame + 320 -- 806
					autoReenterAt = autoFrame + 380 -- 807
				end -- 807
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 807
					autoBackAt = -1 -- 811
					if runtime.game:backToSelect() then -- 811
						print("[escape-velocity] auto back to select") -- 812
					end -- 812
				end -- 812
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 812
					autoReenterAt = -1 -- 815
					print("[escape-velocity] auto re-enter") -- 816
					enterLevel(0) -- 817
				end -- 817
			end -- 817
		end -- 817
		return false -- 822
	end) -- 742
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 826
end -- 826
return ____exports -- 826
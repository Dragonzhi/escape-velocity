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
local levelTotal = levelCount() -- 62
if levelTotal <= 0 then -- 62
	print("[escape-velocity] FATAL: no level data") -- 65
else -- 65
	local opening, startOpening, introHold -- 65
	local viewW = View.size.width -- 67
	local viewH = View.size.height -- 68
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 71
	local levelLayers = {} -- 77
	do -- 77
		local i = 0 -- 78
		while i < levelTotal do -- 78
			local layer = Node() -- 79
			layer.size = Size(viewW, viewH) -- 80
			layer.anchor = Vec2(0.5, 0.5) -- 81
			layer.position = Vec2(0, 0) -- 82
			Director.ui:addChild(layer) -- 83
			levelLayers[#levelLayers + 1] = layer -- 84
			i = i + 1 -- 78
		end -- 78
	end -- 78
	local openingLayer = Node() -- 89
	openingLayer.size = Size(viewW, viewH) -- 90
	openingLayer.anchor = Vec2(0.5, 0.5) -- 91
	openingLayer.position = Vec2(0, 0) -- 92
	Director.ui:addChild(openingLayer) -- 93
	local openingRoot = Node3D() -- 96
	openingRoot.visible = false -- 97
	Director.entry:addChild(openingRoot) -- 98
	local openingCamera = Camera3D() -- 99
	local uiLayer = Node() -- 102
	uiLayer.size = Size(viewW, viewH) -- 103
	uiLayer.anchor = Vec2(0.5, 0.5) -- 104
	uiLayer.position = Vec2(0, 0) -- 105
	Director.ui:addChild(uiLayer) -- 106
	local levelNames = {} -- 109
	do -- 109
		local i = 0 -- 110
		while i < levelTotal do -- 110
			local def = getLevel(i) -- 111
			local title = def ~= nil and def.title or "" -- 112
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 113
			i = i + 1 -- 110
		end -- 110
	end -- 110
	local levelEntries = {} -- 115
	do -- 115
		local i = 0 -- 116
		while i < levelTotal do -- 116
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 116
			i = i + 1 -- 116
		end -- 116
	end -- 116
	local progress = loadProgress(levelTotal) -- 119
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 120
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 121
	local slots = {} -- 123
	do -- 123
		local i = 0 -- 124
		while i < levelTotal do -- 124
			slots[#slots + 1] = {built = false, runtime = nil} -- 124
			i = i + 1 -- 124
		end -- 124
	end -- 124
	local activeIndex = -1 -- 126
	local select = nil -- 127
	local resultPanel = nil -- 128
	local finalePanel = nil -- 130
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 132
	local resultIndex = -1 -- 137
	local function activeRuntime() -- 139
		if activeIndex < 0 then -- 139
			return nil -- 140
		end -- 140
		return slots[activeIndex + 1].runtime -- 141
	end -- 139
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 149
		do -- 149
			local i = 0 -- 150
			while i < levelTotal do -- 150
				do -- 150
					local slot = slots[i + 1] -- 151
					levelLayers[i + 1].visible = i == index -- 154
					if slot.runtime == nil then -- 154
						goto __continue16 -- 155
					end -- 155
					local active = i == index -- 156
					slot.runtime.world.visible = active -- 157
					slot.runtime.aim:setEnabled(active) -- 158
					if active then -- 158
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 160
					end -- 160
				end -- 160
				::__continue16:: -- 160
				i = i + 1 -- 150
			end -- 150
		end -- 150
	end -- 149
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 169
		local game -- 169
		local slot = slots[index + 1] -- 170
		if slot.built and slot.runtime ~= nil then -- 170
			return slot.runtime -- 171
		end -- 171
		local def = getLevel(index) -- 173
		if def == nil then -- 173
			return nil -- 174
		end -- 174
		local bodies = scaledPlanets(def) -- 176
		local level = { -- 177
			bodies = bodies, -- 178
			probeStart = def.probeStart, -- 179
			probeVel0 = def.probeVel0, -- 181
			goal = def.goal, -- 182
			escapeRadius = def.escapeRadius, -- 183
			physicsStep = levelRuntime(index).physicsStep, -- 184
			playback = levelRuntime(index).playback, -- 185
			maxSteps = def.maxSteps -- 186
		} -- 186
		local world = Node3D() -- 189
		Director.entry:addChild(world) -- 190
		world.visible = false -- 191
		local rtg = def.probeVariant == "rtg" -- 193
		local scene = buildScene({ -- 194
			root = world, -- 195
			bodies = bodies, -- 196
			visuals = def.visuals, -- 197
			probeStart = level.probeStart, -- 198
			probeScale = 2.2, -- 202
			spherePath = "Assets/Model/Sphere.gltf", -- 203
			ringPath = "Assets/Model/Ring.gltf", -- 204
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 205
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 212
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 213
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 214
			probeBodyRadius = rtg and 0.871 or 1.084, -- 215
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 217
		}) -- 217
		if scene == nil then -- 217
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 220
			return nil -- 221
		end -- 221
		local rt = levelRuntime(index) -- 224
		local camera = Camera3D() -- 225
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 228
		local trajectory = createTrajectoryView( -- 229
			levelLayers[index + 1], -- 229
			trajectoryOptions() -- 229
		) -- 229
		local plan = createPlanView( -- 232
			levelLayers[index + 1], -- 232
			viewW, -- 232
			viewH, -- 232
			defaultPlanOptions(), -- 232
			def.planCenter -- 232
		) -- 232
		local planTolerance = arrivalRingRadius(def.goal) -- 233
		plan:fitTo(planFitRadius( -- 234
			bodies, -- 234
			level.probeStart, -- 234
			def.goal.planetIndex, -- 234
			planTolerance, -- 234
			def.planCenter -- 234
		)) -- 234
		local aim = createAimInput( -- 236
			levelLayers[index + 1], -- 236
			viewW, -- 236
			viewH, -- 236
			def.dvBudget, -- 236
			rt.aimMin, -- 236
			rt.playbackSpeeds -- 236
		) -- 236
		aim:setBurnInfo(0, def.dvBudget) -- 238
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 240
		aim:setDate(0, dateSpan) -- 241
		aim:onWarp(function(dir) -- 242
			game:stepTime(dir, dateSpan) -- 243
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 244
		end) -- 242
		game = createGame( -- 247
			level, -- 247
			{ -- 247
				scene = scene, -- 248
				camera = camera, -- 249
				rig = rig, -- 250
				trajectory = trajectory, -- 251
				plan = plan, -- 252
				visuals = def.visuals, -- 254
				setWorldVisible = function(____, on) -- 256
					world.visible = on -- 257
				end, -- 256
				aim = aim, -- 259
				viewW = viewW, -- 260
				viewH = viewH, -- 261
				fovYDeg = View.fieldOfView, -- 262
				aspect = View.aspectRatio, -- 263
				onPhase = function(____, p) -- 264
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 265
					if index == activeIndex then -- 265
						if p == "Finale" then -- 265
							if resultPanel ~= nil then -- 265
								resultPanel:hide() -- 273
							end -- 273
							if finalePanel ~= nil then -- 273
								finalePanel:show(finaleText.main, finaleText.sub) -- 274
							end -- 274
						else -- 274
							if p ~= "Result" and resultPanel ~= nil then -- 274
								resultPanel:hide() -- 276
							end -- 276
							if finalePanel ~= nil then -- 276
								finalePanel:hide() -- 277
							end -- 277
						end -- 277
					end -- 277
				end, -- 264
				onResult = function(____, r) -- 281
					if r == "success" then -- 281
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 284
						if next ~= progress.unlocked then -- 284
							progress = {unlocked = next} -- 286
							saveProgress(progress) -- 287
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 288
						end -- 288
					end -- 288
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 291
					resultIndex = index -- 292
					if resultPanel ~= nil then -- 292
						resultPanel:show(r, levelNames[index + 1]) -- 293
					end -- 293
				end, -- 281
				onFinale = function(____, info) -- 296
					finaleText = { -- 297
						main = FinaleMainText, -- 297
						sub = finaleSubtitle(info.distance, info.time) -- 297
					} -- 297
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 298
				end, -- 296
				finale = index == levelTotal - 1 -- 303
			} -- 303
		) -- 303
		aim:onDrag(function(a) -- 309
			game:onAimDrag(a) -- 310
			aim:setBurnInfo( -- 312
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 312
				def.dvBudget -- 312
			) -- 312
		end) -- 309
		aim:onAimReady(function(a) -- 315
			game:onAimDrag(a) -- 316
			game:aimReady() -- 317
			print("[escape-velocity] aim ready -> Armed") -- 318
		end) -- 315
		aim:onLaunch(function() -- 320
			print("[escape-velocity] launch button tap") -- 321
			game:launchArmed() -- 322
		end) -- 320
		aim:onObserve(function(dx, dy) -- 325
			game:observeDrag(dx, dy) -- 326
		end) -- 325
		aim:onZoom(function(deltaDist) -- 328
			game:observeZoom(deltaDist) -- 329
		end) -- 328
		aim:onViewToggle(function() -- 332
			game:toggleViewMode() -- 333
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 334
		end) -- 332
		aim:onBrake(function(on) -- 337
			game:setBrakeMode(on) -- 338
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 339
		end) -- 337
		aim:setBrake(game:brakeMode()) -- 341
		aim:onPlayback(function(speed) -- 344
			game:setPlaybackSpeed(speed) -- 345
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 346
		end) -- 344
		aim:setPlayback(game:playbackSpeed()) -- 348
		local runtime = { -- 350
			index = index, -- 351
			name = levelNames[index + 1], -- 352
			world = world, -- 353
			camera = camera, -- 354
			game = game, -- 355
			aim = aim, -- 356
			trajectory = trajectory, -- 357
			plan = plan, -- 358
			levelHasTimeWindow = def.timeWindow ~= nil, -- 359
			dateSpan = dateSpan -- 360
		} -- 360
		slot.built = true -- 362
		slot.runtime = runtime -- 363
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 364
		return runtime -- 365
	end -- 169
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 369
		local runtime = ensureLevel(index) -- 370
		if runtime == nil then -- 370
			return -- 371
		end -- 371
		local wasActive = activeIndex == index -- 374
		if opening ~= nil then -- 374
			opening.hide() -- 376
		end -- 376
		if select ~= nil then -- 376
			select:hide() -- 377
		end -- 377
		activeIndex = index -- 378
		showOnlyLevel(index) -- 379
		if not wasActive then -- 379
			Director:pushCamera(runtime.camera) -- 380
		end -- 380
		runtime.game:startLevel() -- 381
		print("[escape-velocity] enter " .. runtime.name) -- 382
	end -- 369
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 386
		if resultIndex >= 0 and resultIndex < levelTotal then -- 386
			local rt = slots[resultIndex + 1].runtime -- 388
			if rt ~= nil then -- 388
				return rt -- 389
			end -- 389
		end -- 389
		return activeRuntime() -- 391
	end -- 386
	local function onRetryTap() -- 394
		local rt = resultRuntime() -- 396
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 397
		if resultPanel ~= nil then -- 397
			resultPanel:hide() -- 398
		end -- 398
		if rt ~= nil then -- 398
			rt.game:retry() -- 399
		end -- 399
	end -- 394
	local function onBackToSelectTap() -- 402
		local rt = resultRuntime() -- 403
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 404
		if rt == nil then -- 404
			return -- 405
		end -- 405
		local runtime = rt -- 406
		if not runtime.game:backToSelect() then -- 406
			return -- 408
		end -- 408
		runtime.world.visible = false -- 409
		runtime.aim:setEnabled(false) -- 410
		if resultPanel ~= nil then -- 410
			resultPanel:hide() -- 411
		end -- 411
		if finalePanel ~= nil then -- 411
			finalePanel:hide() -- 413
		end -- 413
		progress = loadProgress(levelTotal) -- 415
		if select ~= nil then -- 415
			select:show(progress.unlocked) -- 416
		end -- 416
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 417
	end -- 402
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 430
		finalePanel = createFinalePanel( -- 433
			uiLayer, -- 433
			viewW, -- 433
			viewH, -- 433
			{onBackToSelect = function() return onBackToSelectTap() end} -- 433
		) -- 433
		resultPanel = createResultPanel( -- 436
			uiLayer, -- 436
			viewW, -- 436
			viewH, -- 436
			{ -- 436
				onRetry = function() return onRetryTap() end, -- 437
				onBackToSelect = function() return onBackToSelectTap() end -- 438
			} -- 438
		) -- 438
		local created = createLevelSelect( -- 440
			uiLayer, -- 440
			viewW, -- 440
			viewH, -- 440
			{ -- 440
				levels = levelEntries, -- 441
				onPick = function(____, index) -- 442
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 443
					if select ~= nil then -- 443
						select:hide() -- 444
					end -- 444
					enterLevel(index) -- 445
				end, -- 442
				onReplayIntro = function() -- 448
					if select ~= nil then -- 448
						select:hide() -- 449
					end -- 449
					startOpening() -- 450
					print("[escape-velocity] opening replay (user)") -- 451
				end -- 448
			} -- 448
		) -- 448
		select = created -- 454
		return created -- 455
	end -- 430
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 468
		local w = View.size.width -- 469
		local h = View.size.height -- 470
		if w == viewW and h == viewH then -- 470
			return -- 471
		end -- 471
		if opening ~= nil then -- 471
			opening.hide() -- 477
			opening = nil -- 478
		end -- 478
		if select ~= nil then -- 478
			select:hide() -- 480
		end -- 480
		if resultPanel ~= nil then -- 480
			resultPanel:hide() -- 481
		end -- 481
		if finalePanel ~= nil then -- 481
			finalePanel:hide() -- 482
		end -- 482
		do -- 482
			local i = 0 -- 483
			while i < levelTotal do -- 483
				local slot = slots[i + 1] -- 484
				if slot.runtime ~= nil then -- 484
					slot.runtime.world.visible = false -- 486
					slot.runtime.aim:setEnabled(false) -- 487
					slot.runtime.trajectory:clearPrediction() -- 490
					slot.runtime.trajectory:clearTrail() -- 491
					slot.runtime.trajectory:clearGoalRings() -- 493
					slot.runtime.plan:setVisible(false) -- 496
					slot.runtime.plan:clear() -- 497
				end -- 497
				slot.built = false -- 499
				slot.runtime = nil -- 500
				i = i + 1 -- 483
			end -- 483
		end -- 483
		viewW = w -- 504
		viewH = h -- 505
		uiLayer.size = Size(viewW, viewH) -- 506
		openingLayer.size = Size(viewW, viewH) -- 507
		do -- 507
			local i = 0 -- 508
			while i < levelTotal do -- 508
				levelLayers[i + 1].size = Size(viewW, viewH) -- 508
				i = i + 1 -- 508
			end -- 508
		end -- 508
		local panel = buildPanels() -- 511
		if activeIndex >= 0 then -- 511
			local keep = activeIndex -- 513
			activeIndex = -1 -- 514
			enterLevel(keep) -- 515
		else -- 515
			panel:show(progress.unlocked) -- 517
		end -- 517
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 519
	end -- 468
	Director.entry:onAppChange(function(name) -- 523
		if name == "Size" then -- 523
			relayoutForViewport() -- 524
		end -- 524
	end) -- 523
	local introSeen = loadIntroSeen() -- 532
	local forceIntro = false -- 533
	opening = nil -- 534
	startOpening = function() -- 536
		if opening == nil then -- 536
			opening = createOpening({ -- 538
				root = openingRoot, -- 539
				camera = openingCamera, -- 540
				layer = openingLayer, -- 541
				viewW = viewW, -- 542
				viewH = viewH, -- 543
				fovYDeg = View.fieldOfView, -- 544
				aspect = View.aspectRatio, -- 545
				spherePath = "Assets/Model/Sphere.gltf", -- 546
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 547
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 548
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 549
				onFinish = function() -- 550
					introHold = -1 -- 551
					if not introSeen then -- 551
						saveIntroSeen() -- 553
						introSeen = true -- 554
						print("[escape-velocity] intro seen -> saved") -- 555
					end -- 555
					if select ~= nil then -- 555
						select:show(progress.unlocked) -- 558
					end -- 558
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 559
						opening.frameIndex(), -- 559
						0 -- 559
					) or "?")) -- 559
				end -- 550
			}) -- 550
		end -- 550
		if opening == nil then -- 550
			return -- 563
		end -- 563
		Director:pushCamera(openingCamera) -- 564
		opening.start() -- 565
		print("[escape-velocity] opening start (first launch)") -- 566
	end -- 536
	local startupPanel = buildPanels() -- 569
	local enterReq = Path( -- 581
		Path(".", ".agent", "test-results"), -- 581
		"enter-request.txt" -- 581
	) -- 581
	local autoLaunchAt = -1 -- 582
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 584
	local autoFrame = 0 -- 585
	local autoVX = 0 -- 586
	local autoVY = 0 -- 587
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 595
	local autoBackAt = -1 -- 597
	local autoReenterAt = -1 -- 598
	local autoEntered = false -- 599
	introHold = -1 -- 601
	if Content:exist(enterReq) then -- 601
		local spec = Content:load(enterReq) -- 603
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 604
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 605
		if head == "intro" then -- 605
			forceIntro = true -- 607
			if at >= 0 then -- 607
				local rest = __TS__StringSubstring(spec, at + 1) -- 609
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 610
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 610
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 612
					if v ~= nil and v >= 0 then -- 612
						introHold = v -- 614
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 615
					end -- 615
				end -- 615
			end -- 615
		end -- 615
		local n = tonumber(head) -- 620
		if n ~= nil and n >= 1 and n <= levelTotal then -- 620
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 622
			enterLevel(n - 1) -- 623
			autoEntered = true -- 624
			if at >= 0 then -- 624
				local rest = __TS__StringSubstring(spec, at + 1) -- 626
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 626
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 631
					if f ~= nil and f >= 0 then -- 631
						autoArmAt = f -- 633
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 634
					end -- 634
				else -- 634
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 637
					local c2 = (string.find( -- 638
						rest, -- 638
						":", -- 638
						math.max(c1 + 1 + 1, 1), -- 638
						true -- 638
					) or 0) - 1 -- 638
					if c1 > 0 and c2 > c1 then -- 638
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 640
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 641
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 644
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 645
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 646
						local vy = tonumber(vyText) -- 647
						local ____temp_0 -- 648
						if c3 > 0 then -- 648
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 648
						else -- 648
							____temp_0 = nil -- 648
						end -- 648
						local steps = ____temp_0 -- 648
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 648
							autoLaunchAt = frames -- 650
							autoVX = vx -- 651
							autoVY = vy -- 652
							if steps ~= nil and steps > 0 then -- 652
								autoWarpSteps = math.floor(steps) -- 654
							end -- 654
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 656
						end -- 656
					end -- 656
				end -- 656
			end -- 656
		end -- 656
	end -- 656
	if autoEntered then -- 656
		print("[escape-velocity] opening skipped (auto enter)") -- 669
	elseif forceIntro or not introSeen then -- 669
		startOpening() -- 671
	else -- 671
		startupPanel:show(progress.unlocked) -- 673
		print("[escape-velocity] opening skipped (already seen)") -- 674
	end -- 674
	threadLoop(function() -- 679
		advanceUiClock(App.deltaTime) -- 683
		if opening ~= nil and opening.running() then -- 683
			if introHold < 0 or opening.frameIndex() < introHold then -- 683
				opening.step() -- 687
			end -- 687
			if App.deltaTime > 0.05 then -- 687
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 691
					opening.frameIndex(), -- 691
					0 -- 691
				)) -- 691
			end -- 691
		end -- 691
		local runtime = activeRuntime() -- 695
		if runtime ~= nil then -- 695
			runtime.game:update(App.deltaTime) -- 697
			if runtime.levelHasTimeWindow then -- 697
				runtime.aim:setDate( -- 700
					runtime.game:dateNow(), -- 700
					runtime.dateSpan -- 700
				) -- 700
			end -- 700
			local phaseNow = runtime.game:phase() -- 704
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 705
			runtime.aim:update(App.deltaTime) -- 706
			runtime.aim:setArmed(runtime.game:armed()) -- 708
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 710
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 712
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 713
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 713
				autoFrame = autoFrame + 1 -- 716
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 716
					autoArmAt = -1 -- 719
					print("[escape-velocity] auto arm (enter-request)") -- 720
					runtime.game:aimReady() -- 721
				end -- 721
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 721
					autoLaunchAt = -1 -- 724
					print("[escape-velocity] auto launch") -- 725
					if autoWarpSteps > 0 then -- 725
						do -- 725
							local s = 0 -- 729
							while s < autoWarpSteps do -- 729
								runtime.game:stepTime(1, runtime.dateSpan) -- 729
								s = s + 1 -- 729
							end -- 729
						end -- 729
						autoWarpSteps = 0 -- 730
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 731
							runtime.game:dateNow(), -- 731
							0 -- 731
						)) .. ")") -- 731
					end -- 731
					runtime.game:launch({x = autoVX, y = autoVY}) -- 733
					autoBackAt = autoFrame + 320 -- 734
					autoReenterAt = autoFrame + 380 -- 735
				end -- 735
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 735
					autoBackAt = -1 -- 739
					if runtime.game:backToSelect() then -- 739
						print("[escape-velocity] auto back to select") -- 740
					end -- 740
				end -- 740
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 740
					autoReenterAt = -1 -- 743
					print("[escape-velocity] auto re-enter") -- 744
					enterLevel(0) -- 745
				end -- 745
			end -- 745
		end -- 745
		return false -- 750
	end) -- 679
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 754
end -- 754
return ____exports -- 754
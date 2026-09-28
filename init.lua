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
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 22
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
local getMissionRockets = ____Progress.getMissionRockets -- 29
local getTotalRockets = ____Progress.getTotalRockets -- 29
local loadProgress = ____Progress.loadProgress -- 29
local progressFilePath = ____Progress.progressFilePath -- 29
local recordMissionResult = ____Progress.recordMissionResult -- 29
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
local debugTriggerResultFn = nil -- 59
local debugTriggerBrakeWindowFn = nil -- 60
local debugTriggerBrakePressFn = nil -- 61
local debugTriggerEnterLevelFn = nil -- 62
local debugTriggerZoomInFn = nil -- 63
local debugTriggerResetViewFn = nil -- 64
local debugForceBrakeWindow = false -- 65
local debugForceBraked = false -- 66
local activeResultPanel = nil -- 67
local levelTotal = levelCount() -- 75
if levelTotal <= 0 then -- 75
	print("[escape-velocity] FATAL: no level data") -- 78
else -- 78
	local opening, startOpening, introHold -- 78
	local viewW = View.size.width -- 80
	local viewH = View.size.height -- 81
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 84
	local levelLayers = {} -- 90
	do -- 90
		local i = 0 -- 91
		while i < levelTotal do -- 91
			local layer = Node() -- 92
			layer.size = Size(viewW, viewH) -- 93
			layer.anchor = Vec2(0.5, 0.5) -- 94
			layer.position = Vec2(0, 0) -- 95
			Director.ui:addChild(layer) -- 96
			levelLayers[#levelLayers + 1] = layer -- 97
			i = i + 1 -- 91
		end -- 91
	end -- 91
	local openingLayer = Node() -- 102
	openingLayer.size = Size(viewW, viewH) -- 103
	openingLayer.anchor = Vec2(0.5, 0.5) -- 104
	openingLayer.position = Vec2(0, 0) -- 105
	Director.ui:addChild(openingLayer) -- 106
	local openingRoot = Node3D() -- 109
	openingRoot.visible = false -- 110
	Director.entry:addChild(openingRoot) -- 111
	local openingCamera = Camera3D() -- 112
	local hubRoot = Node3D() -- 115
	hubRoot.visible = false -- 116
	Director.entry:addChild(hubRoot) -- 117
	local hubCamera = Camera3D() -- 118
	local hubLayer = Node() -- 120
	hubLayer.size = Size(viewW, viewH) -- 121
	hubLayer.anchor = Vec2(0.5, 0.5) -- 122
	hubLayer.position = Vec2(0, 0) -- 123
	Director.ui:addChild(hubLayer) -- 124
	local uiLayer = Node() -- 127
	uiLayer.size = Size(viewW, viewH) -- 128
	uiLayer.anchor = Vec2(0.5, 0.5) -- 129
	uiLayer.position = Vec2(0, 0) -- 130
	Director.ui:addChild(uiLayer) -- 131
	local levelNames = {} -- 134
	do -- 134
		local i = 0 -- 135
		while i < levelTotal do -- 135
			local def = getLevel(i) -- 136
			local title = def ~= nil and def.title or "" -- 137
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 138
			i = i + 1 -- 135
		end -- 135
	end -- 135
	local levelEntries = {} -- 140
	do -- 140
		local i = 0 -- 141
		while i < levelTotal do -- 141
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 141
			i = i + 1 -- 141
		end -- 141
	end -- 141
	local progress = loadProgress(levelTotal) -- 144
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 145
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 146
	local slots = {} -- 148
	do -- 148
		local i = 0 -- 149
		while i < levelTotal do -- 149
			slots[#slots + 1] = {built = false, runtime = nil} -- 149
			i = i + 1 -- 149
		end -- 149
	end -- 149
	local activeIndex = -1 -- 151
	local select = nil -- 152
	local solarHub = nil -- 153
	local resultPanel = nil -- 154
	local finalePanel = nil -- 156
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 158
	local resultIndex = -1 -- 163
	local function activeRuntime() -- 165
		if activeIndex < 0 then -- 165
			return nil -- 166
		end -- 166
		return slots[activeIndex + 1].runtime -- 167
	end -- 165
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 175
		do -- 175
			local i = 0 -- 176
			while i < levelTotal do -- 176
				do -- 176
					local slot = slots[i + 1] -- 177
					levelLayers[i + 1].visible = i == index -- 180
					if slot.runtime == nil then -- 180
						goto __continue16 -- 181
					end -- 181
					local active = i == index -- 182
					slot.runtime.world.visible = active -- 183
					slot.runtime.aim:setEnabled(active) -- 184
					if active then -- 184
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 186
					end -- 186
				end -- 186
				::__continue16:: -- 186
				i = i + 1 -- 176
			end -- 176
		end -- 176
	end -- 175
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 195
		local game -- 195
		local slot = slots[index + 1] -- 196
		if slot.built and slot.runtime ~= nil then -- 196
			return slot.runtime -- 197
		end -- 197
		local def = getLevel(index) -- 199
		if def == nil then -- 199
			return nil -- 200
		end -- 200
		local bodies = scaledPlanets(def) -- 202
		local level = { -- 203
			bodies = bodies, -- 204
			probeStart = def.probeStart, -- 205
			probeVel0 = def.probeVel0, -- 207
			goal = def.goal, -- 208
			escapeRadius = def.escapeRadius, -- 209
			physicsStep = levelRuntime(index).physicsStep, -- 210
			playback = levelRuntime(index).playback, -- 211
			aimClockRate = levelRuntime(index).aimClockRate, -- 212
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 213
			aimMin = levelRuntime(index).aimMin, -- 214
			maxSteps = def.maxSteps, -- 215
			predictSteps = levelRuntime(index).predictSteps -- 216
		} -- 216
		local world = Node3D() -- 219
		Director.entry:addChild(world) -- 220
		world.visible = false -- 221
		local rtg = def.probeVariant == "rtg" -- 223
		local scene = buildScene({ -- 224
			root = world, -- 225
			bodies = bodies, -- 226
			visuals = def.visuals, -- 227
			probeStart = level.probeStart, -- 228
			probeScale = levelRuntime(index).probeVisualRadius, -- 234
			spherePath = "Assets/Model/Sphere.gltf", -- 235
			ringPath = "Assets/Model/Ring.gltf", -- 236
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 237
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 244
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 245
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 246
			probeBodyRadius = rtg and 0.871 or 1.084, -- 247
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 249
		}) -- 249
		if scene == nil then -- 249
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 252
			return nil -- 253
		end -- 253
		local rt = levelRuntime(index) -- 256
		local camera = Camera3D() -- 257
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 260
		local trajectory = createTrajectoryView( -- 261
			levelLayers[index + 1], -- 261
			trajectoryOptions() -- 261
		) -- 261
		local plan = createPlanView( -- 264
			levelLayers[index + 1], -- 264
			viewW, -- 264
			viewH, -- 264
			defaultPlanOptions(), -- 264
			def.planCenter -- 264
		) -- 264
		local planTolerance = arrivalRingRadius(def.goal) -- 265
		plan:fitTo(planFitRadius( -- 266
			bodies, -- 266
			level.probeStart, -- 266
			def.goal.planetIndex, -- 266
			planTolerance, -- 266
			def.planCenter -- 266
		)) -- 266
		local aim = createAimInput( -- 268
			levelLayers[index + 1], -- 268
			viewW, -- 268
			viewH, -- 268
			def.dvBudget, -- 268
			rt.aimMin, -- 268
			rt.playbackSpeeds -- 268
		) -- 268
		aim:setBurnInfo(0, def.dvBudget) -- 270
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 272
		aim:setDate(0, dateSpan) -- 273
		aim:onWarp(function(dir) -- 274
			game:stepTime(dir, dateSpan) -- 275
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 276
		end) -- 274
		aim:onZoomIn(function() -- 280
			plan:zoomIn() -- 281
		end) -- 280
		aim:onZoomOut(function() -- 283
			plan:zoomOut() -- 284
		end) -- 283
		aim:onFitView(function() -- 286
			plan:resetView() -- 287
		end) -- 286
		local challengesList = {} -- 291
		if def.mission ~= nil then -- 291
			do -- 291
				local k = 0 -- 293
				while k < #def.mission.challenges do -- 293
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 294
					k = k + 1 -- 293
				end -- 293
			end -- 293
		end -- 293
		local initialRockets = getMissionRockets(progress, index) -- 297
		local drawerTitle = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 298
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 299
		game = createGame( -- 301
			level, -- 301
			{ -- 301
				scene = scene, -- 302
				camera = camera, -- 303
				rig = rig, -- 304
				trajectory = trajectory, -- 305
				plan = plan, -- 306
				visuals = def.visuals, -- 308
				setWorldVisible = function(____, on) -- 310
					world.visible = on -- 311
				end, -- 310
				aim = aim, -- 313
				viewW = viewW, -- 314
				viewH = viewH, -- 315
				fovYDeg = View.fieldOfView, -- 316
				aspect = View.aspectRatio, -- 317
				onPhase = function(____, p) -- 318
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 319
					if index == activeIndex then -- 319
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 326
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 327
						aim:setMissionDrawerVisible(inAim) -- 328
						if p == "Finale" then -- 328
							if resultPanel ~= nil then -- 328
								resultPanel:hide() -- 330
							end -- 330
							if finalePanel ~= nil then -- 330
								finalePanel:show(finaleText.main, finaleText.sub) -- 331
							end -- 331
						else -- 331
							if p ~= "Result" and resultPanel ~= nil then -- 331
								resultPanel:hide() -- 333
							end -- 333
							if finalePanel ~= nil then -- 333
								finalePanel:hide() -- 334
							end -- 334
						end -- 334
					end -- 334
				end, -- 318
				onResult = function(____, r, telemetry) -- 338
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 339
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity}) -- 345
					progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 352
					saveProgress(progress) -- 353
					local currentTotal = getTotalRockets(progress, levelTotal) -- 354
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 356
					resultIndex = index -- 360
					local challengesList = {} -- 362
					if def.mission ~= nil then -- 362
						do -- 362
							local k = 0 -- 364
							while k < #def.mission.challenges do -- 364
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 365
								k = k + 1 -- 364
							end -- 364
						end -- 364
					end -- 364
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 369
					local detailParams = { -- 373
						result = r, -- 374
						levelName = titleWithSub, -- 375
						levelIndex = index, -- 376
						rocketsGot = evalInfo.rockets, -- 377
						challenges = challengesList, -- 378
						achieved = evalInfo.achieved, -- 379
						burnDv = telem.burnDv, -- 380
						dvBudget = def.dvBudget, -- 381
						flightTime = telem.flightTime, -- 382
						totalRockets = currentTotal, -- 383
						totalPossibleRockets = levelTotal * 3 -- 384
					} -- 384
					if resultPanel ~= nil then -- 384
						resultPanel:show(r, titleWithSub, detailParams) -- 388
					end -- 388
				end, -- 338
				onFinale = function(____, info) -- 392
					finaleText = { -- 393
						main = FinaleMainText, -- 393
						sub = finaleSubtitle(info.distance, info.time) -- 393
					} -- 393
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 394
				end, -- 392
				finale = index == levelTotal - 1 -- 399
			} -- 399
		) -- 399
		aim:onDrag(function(a) -- 405
			game:onAimDrag(a) -- 406
			aim:setBurnInfo( -- 408
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 408
				def.dvBudget -- 408
			) -- 408
		end) -- 405
		aim:onAimReady(function(a) -- 411
			game:onAimDrag(a) -- 412
			game:aimReady() -- 413
			print("[escape-velocity] aim ready -> Armed") -- 414
		end) -- 411
		aim:onLaunch(function() -- 416
			print("[escape-velocity] launch button tap") -- 417
			game:launchArmed() -- 418
		end) -- 416
		aim:onObserve(function(dx, dy) -- 421
			game:observeDrag(dx, dy) -- 422
		end) -- 421
		aim:onZoom(function(deltaDist) -- 424
			game:observeZoom(deltaDist) -- 425
		end) -- 424
		aim:onViewToggle(function() -- 428
			game:toggleViewMode() -- 429
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 430
		end) -- 428
		aim:onBrake(function(on) -- 433
			game:setBrakeMode(on) -- 434
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 435
		end) -- 433
		aim:setBrake(game:brakeMode()) -- 437
		aim:onPlayback(function(speed) -- 440
			game:setPlaybackSpeed(speed) -- 441
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 442
		end) -- 440
		aim:setPlayback(game:playbackSpeed()) -- 444
		aim:onLiveBrake(function() -- 446
			print(("[escape-velocity] tap: live brake (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 447
			game:applyInFlightBrake() -- 448
		end) -- 446
		local runtime = { -- 451
			index = index, -- 452
			name = levelNames[index + 1], -- 453
			world = world, -- 454
			camera = camera, -- 455
			game = game, -- 456
			aim = aim, -- 457
			trajectory = trajectory, -- 458
			plan = plan, -- 459
			levelHasTimeWindow = def.timeWindow ~= nil, -- 460
			dvBudget = def.dvBudget, -- 461
			dateSpan = dateSpan -- 462
		} -- 462
		slot.built = true -- 464
		slot.runtime = runtime -- 465
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 466
		return runtime -- 467
	end -- 195
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 471
		local runtime = ensureLevel(index) -- 472
		if runtime == nil then -- 472
			return -- 473
		end -- 473
		local wasActive = activeIndex == index -- 476
		if opening ~= nil then -- 476
			opening.hide() -- 478
		end -- 478
		if select ~= nil then -- 478
			select:hide() -- 479
		end -- 479
		if solarHub ~= nil then -- 479
			solarHub.hide() -- 480
		end -- 480
		activeIndex = index -- 481
		showOnlyLevel(index) -- 482
		if not wasActive then -- 482
			Director:pushCamera(runtime.camera) -- 483
		end -- 483
		runtime.game:startLevel() -- 484
		print("[escape-velocity] enter " .. runtime.name) -- 485
	end -- 471
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 489
		if resultIndex >= 0 and resultIndex < levelTotal then -- 489
			local rt = slots[resultIndex + 1].runtime -- 491
			if rt ~= nil then -- 491
				return rt -- 492
			end -- 492
		end -- 492
		return activeRuntime() -- 494
	end -- 489
	local function onRetryTap() -- 497
		local rt = resultRuntime() -- 499
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 500
		if resultPanel ~= nil then -- 500
			resultPanel:hide() -- 501
		end -- 501
		if rt ~= nil then -- 501
			rt.game:retry() -- 502
		end -- 502
	end -- 497
	local function ensureSolarHub() -- 505
		if solarHub ~= nil then -- 505
			return solarHub -- 506
		end -- 506
		solarHub = createSolarHub({ -- 507
			root = hubRoot, -- 508
			camera = hubCamera, -- 509
			layer = hubLayer, -- 510
			viewW = viewW, -- 511
			viewH = viewH, -- 512
			fovYDeg = View.fieldOfView, -- 513
			aspect = View.aspectRatio, -- 514
			spherePath = "Assets/Model/Sphere.gltf", -- 515
			onLaunch = function(____, levelIndex) -- 516
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 517
				if solarHub ~= nil then -- 517
					solarHub.hide() -- 518
				end -- 518
				enterLevel(levelIndex) -- 519
			end, -- 516
			onReplayIntro = function() -- 521
				if solarHub ~= nil then -- 521
					solarHub.hide() -- 522
				end -- 522
				startOpening() -- 523
				print("[escape-velocity] opening replay from solarHub") -- 524
			end -- 521
		}) -- 521
		return solarHub -- 527
	end -- 505
	local function onBackToSelectTap() -- 530
		local rt = resultRuntime() -- 531
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 532
		if rt == nil then -- 532
			return -- 533
		end -- 533
		local runtime = rt -- 534
		if not runtime.game:backToSelect() then -- 534
			return -- 536
		end -- 536
		runtime.world.visible = false -- 537
		runtime.aim:setEnabled(false) -- 538
		if resultPanel ~= nil then -- 538
			resultPanel:hide() -- 539
		end -- 539
		if finalePanel ~= nil then -- 539
			finalePanel:hide() -- 541
		end -- 541
		if select ~= nil then -- 541
			select:hide() -- 542
		end -- 542
		progress = loadProgress(levelTotal) -- 544
		local hub = ensureSolarHub() -- 545
		Director:pushCamera(hubCamera) -- 546
		hub.show(progress) -- 547
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 548
			getTotalRockets(progress, levelTotal), -- 548
			0 -- 548
		)) -- 548
	end -- 530
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 561
		finalePanel = createFinalePanel( -- 564
			uiLayer, -- 564
			viewW, -- 564
			viewH, -- 564
			{onBackToSelect = function() return onBackToSelectTap() end} -- 564
		) -- 564
		resultPanel = createResultPanel( -- 567
			uiLayer, -- 567
			viewW, -- 567
			viewH, -- 567
			{ -- 567
				onRetry = function() return onRetryTap() end, -- 568
				onBackToSelect = function() return onBackToSelectTap() end -- 569
			} -- 569
		) -- 569
		activeResultPanel = resultPanel -- 571
		local created = createLevelSelect( -- 572
			uiLayer, -- 572
			viewW, -- 572
			viewH, -- 572
			{ -- 572
				levels = levelEntries, -- 573
				onPick = function(____, index) -- 574
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 575
					if select ~= nil then -- 575
						select:hide() -- 576
					end -- 576
					enterLevel(index) -- 577
				end, -- 574
				onReplayIntro = function() -- 580
					if select ~= nil then -- 580
						select:hide() -- 581
					end -- 581
					startOpening() -- 582
					print("[escape-velocity] opening replay (user)") -- 583
				end -- 580
			} -- 580
		) -- 580
		select = created -- 586
		return created -- 587
	end -- 561
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 600
		local w = View.size.width -- 601
		local h = View.size.height -- 602
		if w == viewW and h == viewH then -- 602
			return -- 603
		end -- 603
		if opening ~= nil then -- 603
			opening.hide() -- 609
			opening = nil -- 610
		end -- 610
		if select ~= nil then -- 610
			select:hide() -- 612
		end -- 612
		if resultPanel ~= nil then -- 612
			resultPanel:hide() -- 613
		end -- 613
		if finalePanel ~= nil then -- 613
			finalePanel:hide() -- 614
		end -- 614
		do -- 614
			local i = 0 -- 615
			while i < levelTotal do -- 615
				local slot = slots[i + 1] -- 616
				if slot.runtime ~= nil then -- 616
					slot.runtime.world.visible = false -- 618
					slot.runtime.aim:setEnabled(false) -- 619
					slot.runtime.trajectory:clearPrediction() -- 622
					slot.runtime.trajectory:clearTrail() -- 623
					slot.runtime.trajectory:clearGoalRings() -- 625
					slot.runtime.plan:setVisible(false) -- 628
					slot.runtime.plan:clear() -- 629
				end -- 629
				slot.built = false -- 631
				slot.runtime = nil -- 632
				i = i + 1 -- 615
			end -- 615
		end -- 615
		viewW = w -- 636
		viewH = h -- 637
		uiLayer.size = Size(viewW, viewH) -- 638
		openingLayer.size = Size(viewW, viewH) -- 639
		hubLayer.size = Size(viewW, viewH) -- 640
		do -- 640
			local i = 0 -- 641
			while i < levelTotal do -- 641
				levelLayers[i + 1].size = Size(viewW, viewH) -- 641
				i = i + 1 -- 641
			end -- 641
		end -- 641
		if solarHub ~= nil then -- 641
			solarHub.relayout(viewW, viewH) -- 643
		end -- 643
		buildPanels() -- 647
		if activeIndex >= 0 then -- 647
			local keep = activeIndex -- 649
			activeIndex = -1 -- 650
			enterLevel(keep) -- 651
		else -- 651
			local hub = ensureSolarHub() -- 653
			Director:pushCamera(hubCamera) -- 654
			hub.show(progress) -- 655
		end -- 655
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 657
	end -- 600
	Director.entry:onAppChange(function(name) -- 661
		if name == "Size" then -- 661
			relayoutForViewport() -- 662
		end -- 662
	end) -- 661
	local introSeen = loadIntroSeen() -- 670
	local forceIntro = false -- 671
	opening = nil -- 672
	startOpening = function() -- 674
		if opening == nil then -- 674
			opening = createOpening({ -- 676
				root = openingRoot, -- 677
				camera = openingCamera, -- 678
				layer = openingLayer, -- 679
				viewW = viewW, -- 680
				viewH = viewH, -- 681
				fovYDeg = View.fieldOfView, -- 682
				aspect = View.aspectRatio, -- 683
				spherePath = "Assets/Model/Sphere.gltf", -- 684
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 685
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 686
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 687
				onFinish = function() -- 688
					introHold = -1 -- 689
					if not introSeen then -- 689
						saveIntroSeen() -- 691
						introSeen = true -- 692
						print("[escape-velocity] intro seen -> saved") -- 693
					end -- 693
					if opening ~= nil then -- 693
						opening.hide() -- 696
					end -- 696
					if select ~= nil then -- 696
						select:hide() -- 697
					end -- 697
					local hub = ensureSolarHub() -- 698
					Director:pushCamera(hubCamera) -- 699
					hub.show(progress) -- 700
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 701
						opening.frameIndex(), -- 701
						0 -- 701
					) or "?")) -- 701
				end -- 688
			}) -- 688
		end -- 688
		if opening == nil then -- 688
			return -- 705
		end -- 705
		Director:pushCamera(openingCamera) -- 706
		opening.start() -- 707
		print("[escape-velocity] opening start (first launch)") -- 708
	end -- 674
	local startupPanel = buildPanels() -- 711
	local enterReq = Path( -- 723
		Path(".", ".agent", "test-results"), -- 723
		"enter-request.txt" -- 723
	) -- 723
	local autoLaunchAt = -1 -- 724
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 726
	local autoFrame = 0 -- 727
	local autoVX = 0 -- 728
	local autoVY = 0 -- 729
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 737
	local autoBackAt = -1 -- 739
	local autoReenterAt = -1 -- 740
	local autoEntered = false -- 741
	introHold = -1 -- 743
	if Content:exist(enterReq) then -- 743
		local spec = Content:load(enterReq) -- 745
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 746
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 747
		if head == "intro" then -- 747
			forceIntro = true -- 749
			if at >= 0 then -- 749
				local rest = __TS__StringSubstring(spec, at + 1) -- 751
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 752
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 752
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 754
					if v ~= nil and v >= 0 then -- 754
						introHold = v -- 756
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 757
					end -- 757
				end -- 757
			end -- 757
		end -- 757
		local n = tonumber(head) -- 762
		if n ~= nil and n >= 1 and n <= levelTotal then -- 762
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 764
			enterLevel(n - 1) -- 765
			autoEntered = true -- 766
			if at >= 0 then -- 766
				local rest = __TS__StringSubstring(spec, at + 1) -- 768
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 768
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 773
					if f ~= nil and f >= 0 then -- 773
						autoArmAt = f -- 775
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 776
					end -- 776
				else -- 776
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 779
					local c2 = (string.find( -- 780
						rest, -- 780
						":", -- 780
						math.max(c1 + 1 + 1, 1), -- 780
						true -- 780
					) or 0) - 1 -- 780
					if c1 > 0 and c2 > c1 then -- 780
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 782
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 783
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 786
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 787
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 788
						local vy = tonumber(vyText) -- 789
						local ____temp_0 -- 790
						if c3 > 0 then -- 790
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 790
						else -- 790
							____temp_0 = nil -- 790
						end -- 790
						local steps = ____temp_0 -- 790
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 790
							autoLaunchAt = frames -- 792
							autoVX = vx -- 793
							autoVY = vy -- 794
							if steps ~= nil and steps > 0 then -- 794
								autoWarpSteps = math.floor(steps) -- 796
							end -- 796
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 798
						end -- 798
					end -- 798
				end -- 798
			end -- 798
		end -- 798
	end -- 798
	if autoEntered then -- 798
		print("[escape-velocity] opening skipped (auto enter)") -- 811
	elseif forceIntro or not introSeen then -- 811
		startOpening() -- 813
	else -- 813
		local hub = ensureSolarHub() -- 815
		Director:pushCamera(hubCamera) -- 816
		hub.show(progress) -- 817
		print("[escape-velocity] entered solarHub (already seen)") -- 818
	end -- 818
	threadLoop(function() -- 823
		advanceUiClock(App.deltaTime) -- 827
		if solarHub ~= nil and solarHub.visible() then -- 827
			solarHub.step(App.deltaTime) -- 831
		end -- 831
		if opening ~= nil and opening.running() then -- 831
			if introHold < 0 or opening.frameIndex() < introHold then -- 831
				opening.step() -- 837
			end -- 837
			if App.deltaTime > 0.05 then -- 837
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 841
					opening.frameIndex(), -- 841
					0 -- 841
				)) -- 841
			end -- 841
		end -- 841
		local runtime = activeRuntime() -- 845
		if runtime ~= nil then -- 845
			runtime.game:update(App.deltaTime) -- 847
			runtime.aim:setBurnInfo( -- 849
				runtime.game:burnNow(), -- 849
				runtime.dvBudget -- 849
			) -- 849
			if runtime.levelHasTimeWindow then -- 849
				runtime.aim:setDate( -- 852
					runtime.game:dateNow(), -- 852
					runtime.dateSpan -- 852
				) -- 852
			end -- 852
			local phaseNow = runtime.game:phase() -- 856
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 857
			runtime.aim:update(App.deltaTime) -- 858
			runtime.aim:setArmed(runtime.game:armed()) -- 860
			local is2D = runtime.game:viewMode() == "2D" -- 862
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 863
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 864
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 865
			runtime.aim:setMissionDrawerVisible(inAim) -- 866
			local curBurn = runtime.game:burnNow() -- 868
			local fuelLimit = runtime.dvBudget * 0.75 -- 869
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 870
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 872
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 873
			local brakeActive = phaseNow == "Flying" and runtime.game:isBrakeWindowActive() or debugForceBrakeWindow -- 875
			local isBraked = runtime.game:hasBraked() or debugForceBraked -- 876
			runtime.aim:setLiveBrakeVisible(brakeActive) -- 877
			runtime.aim:setLiveBraked(isBraked) -- 878
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 878
				autoFrame = autoFrame + 1 -- 881
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 881
					autoArmAt = -1 -- 884
					print("[escape-velocity] auto arm (enter-request)") -- 885
					runtime.game:aimReady() -- 886
				end -- 886
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 886
					autoLaunchAt = -1 -- 889
					print("[escape-velocity] auto launch") -- 890
					if autoWarpSteps > 0 then -- 890
						do -- 890
							local s = 0 -- 894
							while s < autoWarpSteps do -- 894
								runtime.game:stepTime(1, runtime.dateSpan) -- 894
								s = s + 1 -- 894
							end -- 894
						end -- 894
						autoWarpSteps = 0 -- 895
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 896
							runtime.game:dateNow(), -- 896
							0 -- 896
						)) .. ")") -- 896
					end -- 896
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 898
					runtime.game:launch({x = autoVX, y = autoVY}) -- 899
					autoBackAt = autoFrame + 320 -- 900
					autoReenterAt = autoFrame + 380 -- 901
				end -- 901
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 901
					autoBackAt = -1 -- 905
					if runtime.game:backToSelect() then -- 905
						print("[escape-velocity] auto back to select") -- 906
					end -- 906
				end -- 906
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 906
					autoReenterAt = -1 -- 909
					print("[escape-velocity] auto re-enter") -- 910
					enterLevel(0) -- 911
				end -- 911
			end -- 911
		end -- 911
		return false -- 916
	end) -- 823
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 920
	debugTriggerResultFn = function(levelIndex, outcome) -- 922
		if outcome == nil then -- 922
			outcome = "success" -- 922
		end -- 922
		if solarHub ~= nil then -- 922
			solarHub.hide() -- 923
		end -- 923
		if opening ~= nil then -- 923
			opening.hide() -- 924
		end -- 924
		local def = getLevel(levelIndex) -- 925
		if def == nil or resultPanel == nil then -- 925
			return -- 926
		end -- 926
		local burn = def.dvBudget * 0.65 -- 927
		local challengesList = {} -- 928
		if def.mission ~= nil then -- 928
			do -- 928
				local k = 0 -- 930
				while k < #def.mission.challenges do -- 930
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 931
					k = k + 1 -- 930
				end -- 930
			end -- 930
		end -- 930
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 934
		resultPanel:show(outcome, titleWithSub, { -- 938
			result = outcome, -- 939
			levelName = titleWithSub, -- 940
			levelIndex = levelIndex, -- 941
			rocketsGot = outcome == "success" and 3 or 0, -- 942
			challenges = challengesList, -- 943
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 944
			burnDv = burn, -- 945
			dvBudget = def.dvBudget, -- 946
			flightTime = 12.8, -- 947
			totalRockets = outcome == "success" and 16 or 13, -- 948
			totalPossibleRockets = 18 -- 949
		}) -- 949
	end -- 922
	debugTriggerBrakeWindowFn = function(levelIndex) -- 953
		if solarHub ~= nil then -- 953
			solarHub.hide() -- 954
		end -- 954
		if opening ~= nil then -- 954
			opening.hide() -- 955
		end -- 955
		enterLevel(levelIndex) -- 956
		local rt = activeRuntime() -- 957
		if rt ~= nil then -- 957
			rt.game:launch({x = 2, y = -20}) -- 959
			debugForceBrakeWindow = true -- 960
			debugForceBraked = false -- 961
			rt.aim:setLiveBrakeVisible(true) -- 962
			rt.aim:setLiveBraked(false) -- 963
			if rt.game:viewMode() ~= "3D" then -- 963
				rt.game:toggleViewMode() -- 964
			end -- 964
		end -- 964
	end -- 953
	debugTriggerBrakePressFn = function() -- 968
		debugForceBrakeWindow = true -- 969
		debugForceBraked = true -- 970
		local rt = activeRuntime() -- 971
		if rt ~= nil then -- 971
			rt.aim:setLiveBrakeVisible(true) -- 973
			rt.aim:setLiveBraked(true) -- 974
		end -- 974
	end -- 968
	debugTriggerEnterLevelFn = function(levelIndex) -- 978
		if solarHub ~= nil then -- 978
			solarHub.hide() -- 979
		end -- 979
		if opening ~= nil then -- 979
			opening.hide() -- 980
		end -- 980
		enterLevel(levelIndex) -- 981
	end -- 978
	debugTriggerZoomInFn = function() -- 984
		local rt = activeRuntime() -- 985
		if rt ~= nil then -- 985
			rt.plan:zoomIn() -- 987
		end -- 987
	end -- 984
	debugTriggerResetViewFn = function() -- 991
		local rt = activeRuntime() -- 992
		if rt ~= nil then -- 992
			rt.plan:resetView() -- 994
		end -- 994
	end -- 991
end -- 991
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1000
	return activeResultPanel -- 1001
end -- 1000
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1005
	if outcome == nil then -- 1005
		outcome = "success" -- 1005
	end -- 1005
	if debugTriggerResultFn ~= nil then -- 1005
		debugTriggerResultFn(levelIndex, outcome) -- 1007
	end -- 1007
end -- 1005
--- 触发进入制动窗口演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakeWindow(levelIndex) -- 1012
	if levelIndex == nil then -- 1012
		levelIndex = 3 -- 1012
	end -- 1012
	if debugTriggerBrakeWindowFn ~= nil then -- 1012
		debugTriggerBrakeWindowFn(levelIndex) -- 1014
	end -- 1014
end -- 1012
--- 触发按下逆喷制动按钮演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakePress() -- 1019
	if debugTriggerBrakePressFn ~= nil then -- 1019
		debugTriggerBrakePressFn() -- 1021
	end -- 1021
end -- 1019
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1026
	if debugTriggerEnterLevelFn ~= nil then -- 1026
		debugTriggerEnterLevelFn(levelIndex) -- 1028
	end -- 1028
end -- 1026
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1033
	if debugTriggerZoomInFn ~= nil then -- 1033
		debugTriggerZoomInFn() -- 1035
	end -- 1035
end -- 1033
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1040
	if debugTriggerResetViewFn ~= nil then -- 1040
		debugTriggerResetViewFn() -- 1042
	end -- 1042
end -- 1040
return ____exports -- 1040
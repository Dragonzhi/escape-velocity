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
local GameSecondsPerRealSecond = ____LevelData.GameSecondsPerRealSecond -- 22
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
			speedUnit = GameSecondsPerRealSecond, -- 212
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 213
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 214
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 215
			aimFraming = levelRuntime(index).aimFraming, -- 216
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 217
			aimMin = levelRuntime(index).aimMin, -- 218
			maxSteps = def.maxSteps, -- 219
			predictSteps = levelRuntime(index).predictSteps -- 220
		} -- 220
		local world = Node3D() -- 223
		Director.entry:addChild(world) -- 224
		world.visible = false -- 225
		local rtg = def.probeVariant == "rtg" -- 227
		local scene = buildScene({ -- 228
			root = world, -- 229
			bodies = bodies, -- 230
			visuals = def.visuals, -- 231
			probeStart = level.probeStart, -- 232
			probeScale = levelRuntime(index).probeVisualRadius, -- 238
			spherePath = "Assets/Model/Sphere.gltf", -- 239
			ringPath = "Assets/Model/Ring.gltf", -- 240
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 241
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 248
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 249
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 250
			probeBodyRadius = rtg and 0.871 or 1.084, -- 251
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 253
			orbitFlowDots = levelRuntime(index).orbitFlowDots -- 254
		}) -- 254
		if scene == nil then -- 254
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 257
			return nil -- 258
		end -- 258
		local rt = levelRuntime(index) -- 261
		local camera = Camera3D() -- 262
		local rig = createCameraRig(defaultRigOptions( -- 266
			View.fieldOfView, -- 266
			View.aspectRatio, -- 266
			rt.cameraMin, -- 266
			rt.cameraMax, -- 266
			rt.tiltDeg -- 266
		)) -- 266
		local trajectory = createTrajectoryView( -- 267
			levelLayers[index + 1], -- 267
			trajectoryOptions() -- 267
		) -- 267
		local planOpts = defaultPlanOptions() -- 271
		if levelRuntime(index).orbitFlowDots == false then -- 271
			planOpts.flowDotRadius = 0 -- 272
		end -- 272
		local plan = createPlanView( -- 273
			levelLayers[index + 1], -- 273
			viewW, -- 273
			viewH, -- 273
			planOpts, -- 273
			def.planCenter -- 273
		) -- 273
		local planTolerance = arrivalRingRadius(def.goal) -- 274
		plan:fitTo(planFitRadius( -- 275
			bodies, -- 275
			level.probeStart, -- 275
			def.goal.planetIndex, -- 275
			planTolerance, -- 275
			def.planCenter -- 275
		)) -- 275
		local aim = createAimInput( -- 277
			levelLayers[index + 1], -- 277
			viewW, -- 277
			viewH, -- 277
			def.dvBudget, -- 277
			rt.aimMin, -- 277
			rt.playbackSpeeds -- 277
		) -- 277
		aim:setBurnInfo(0, def.dvBudget) -- 279
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 281
		aim:setDate(0, dateSpan) -- 282
		aim:onWarp(function(dir) -- 283
			game:stepTime(dir, dateSpan) -- 284
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 285
		end) -- 283
		aim:onZoomIn(function() -- 289
			plan:zoomIn() -- 290
		end) -- 289
		aim:onZoomOut(function() -- 292
			plan:zoomOut() -- 293
		end) -- 292
		aim:onFitView(function() -- 295
			plan:resetView() -- 296
		end) -- 295
		local challengesList = {} -- 300
		if def.mission ~= nil then -- 300
			do -- 300
				local k = 0 -- 302
				while k < #def.mission.challenges do -- 302
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 303
					k = k + 1 -- 302
				end -- 302
			end -- 302
		end -- 302
		local initialRockets = getMissionRockets(progress, index) -- 306
		local drawerTitle = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 307
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 308
		game = createGame( -- 310
			level, -- 310
			{ -- 310
				scene = scene, -- 311
				camera = camera, -- 312
				rig = rig, -- 313
				trajectory = trajectory, -- 314
				plan = plan, -- 315
				visuals = def.visuals, -- 317
				setWorldVisible = function(____, on) -- 319
					world.visible = on -- 320
				end, -- 319
				aim = aim, -- 322
				viewW = viewW, -- 323
				viewH = viewH, -- 324
				fovYDeg = View.fieldOfView, -- 325
				aspect = View.aspectRatio, -- 326
				onPhase = function(____, p) -- 327
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 328
					if index == activeIndex then -- 328
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 335
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 336
						aim:setMissionDrawerVisible(inAim) -- 337
						if p == "Finale" then -- 337
							if resultPanel ~= nil then -- 337
								resultPanel:hide() -- 339
							end -- 339
							if finalePanel ~= nil then -- 339
								finalePanel:show(finaleText.main, finaleText.sub) -- 340
							end -- 340
						else -- 340
							if p ~= "Result" and resultPanel ~= nil then -- 340
								resultPanel:hide() -- 342
							end -- 342
							if finalePanel ~= nil then -- 342
								finalePanel:hide() -- 343
							end -- 343
						end -- 343
					end -- 343
				end, -- 327
				onResult = function(____, r, telemetry) -- 347
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 348
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity}) -- 354
					progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 361
					saveProgress(progress) -- 362
					local currentTotal = getTotalRockets(progress, levelTotal) -- 363
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 365
					resultIndex = index -- 369
					local challengesList = {} -- 371
					if def.mission ~= nil then -- 371
						do -- 371
							local k = 0 -- 373
							while k < #def.mission.challenges do -- 373
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 374
								k = k + 1 -- 373
							end -- 373
						end -- 373
					end -- 373
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 378
					local detailParams = { -- 382
						result = r, -- 383
						levelName = titleWithSub, -- 384
						levelIndex = index, -- 385
						rocketsGot = evalInfo.rockets, -- 386
						challenges = challengesList, -- 387
						achieved = evalInfo.achieved, -- 388
						burnDv = telem.burnDv, -- 389
						dvBudget = def.dvBudget, -- 390
						flightTime = telem.flightTime, -- 391
						totalRockets = currentTotal, -- 392
						totalPossibleRockets = levelTotal * 3 -- 393
					} -- 393
					if resultPanel ~= nil then -- 393
						resultPanel:show(r, titleWithSub, detailParams) -- 397
					end -- 397
				end, -- 347
				onFinale = function(____, info) -- 401
					finaleText = { -- 402
						main = FinaleMainText, -- 402
						sub = finaleSubtitle(info.distance, info.time) -- 402
					} -- 402
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 403
				end, -- 401
				finale = index == levelTotal - 1 -- 408
			} -- 408
		) -- 408
		aim:onDrag(function(a) -- 414
			game:onAimDrag(a) -- 415
			aim:setBurnInfo( -- 417
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 417
				def.dvBudget -- 417
			) -- 417
		end) -- 414
		aim:onAimReady(function(a) -- 420
			game:onAimDrag(a) -- 421
			game:aimReady() -- 422
			print("[escape-velocity] aim ready -> Armed") -- 423
		end) -- 420
		aim:onLaunch(function() -- 425
			print("[escape-velocity] launch button tap") -- 426
			game:launchArmed() -- 427
		end) -- 425
		aim:onObserve(function(dx, dy) -- 430
			game:observeDrag(dx, dy) -- 431
		end) -- 430
		aim:onZoom(function(deltaDist) -- 433
			game:observeZoom(deltaDist) -- 434
		end) -- 433
		aim:onViewToggle(function() -- 437
			game:toggleViewMode() -- 438
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 439
		end) -- 437
		aim:onBrake(function(on) -- 442
			game:setBrakeMode(on) -- 443
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 444
		end) -- 442
		aim:setBrake(game:brakeMode()) -- 446
		aim:onSpeedUp(function() -- 450
			game:speedUp() -- 451
		end) -- 450
		aim:onSpeedDown(function() -- 453
			game:speedDown() -- 454
		end) -- 453
		aim:onTogglePause(function() -- 456
			game:togglePause() -- 457
		end) -- 456
		aim:onPlayback(function(speed) -- 459
			game:setPlaybackSpeed(speed) -- 460
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 461
		end) -- 459
		aim:setPlayback(game:playbackSpeed()) -- 463
		aim:onLiveBrake(function() -- 465
			print(("[escape-velocity] tap: live brake (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 466
			game:applyInFlightBrake() -- 467
		end) -- 465
		local runtime = { -- 470
			index = index, -- 471
			name = levelNames[index + 1], -- 472
			world = world, -- 473
			camera = camera, -- 474
			game = game, -- 475
			aim = aim, -- 476
			trajectory = trajectory, -- 477
			plan = plan, -- 478
			levelHasTimeWindow = def.timeWindow ~= nil, -- 479
			dvBudget = def.dvBudget, -- 480
			dateSpan = dateSpan -- 481
		} -- 481
		slot.built = true -- 483
		slot.runtime = runtime -- 484
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 485
		return runtime -- 486
	end -- 195
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 490
		local runtime = ensureLevel(index) -- 491
		if runtime == nil then -- 491
			return -- 492
		end -- 492
		local wasActive = activeIndex == index -- 495
		if opening ~= nil then -- 495
			opening.hide() -- 497
		end -- 497
		if select ~= nil then -- 497
			select:hide() -- 498
		end -- 498
		if solarHub ~= nil then -- 498
			solarHub.hide() -- 499
		end -- 499
		activeIndex = index -- 500
		showOnlyLevel(index) -- 501
		if not wasActive then -- 501
			Director:pushCamera(runtime.camera) -- 502
		end -- 502
		runtime.game:startLevel() -- 503
		print("[escape-velocity] enter " .. runtime.name) -- 504
	end -- 490
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 508
		if resultIndex >= 0 and resultIndex < levelTotal then -- 508
			local rt = slots[resultIndex + 1].runtime -- 510
			if rt ~= nil then -- 510
				return rt -- 511
			end -- 511
		end -- 511
		return activeRuntime() -- 513
	end -- 508
	local function onRetryTap() -- 516
		local rt = resultRuntime() -- 518
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 519
		if resultPanel ~= nil then -- 519
			resultPanel:hide() -- 520
		end -- 520
		if rt ~= nil then -- 520
			rt.game:retry() -- 521
		end -- 521
	end -- 516
	local function ensureSolarHub() -- 524
		if solarHub ~= nil then -- 524
			return solarHub -- 525
		end -- 525
		solarHub = createSolarHub({ -- 526
			root = hubRoot, -- 527
			camera = hubCamera, -- 528
			layer = hubLayer, -- 529
			viewW = viewW, -- 530
			viewH = viewH, -- 531
			fovYDeg = View.fieldOfView, -- 532
			aspect = View.aspectRatio, -- 533
			spherePath = "Assets/Model/Sphere.gltf", -- 534
			onLaunch = function(____, levelIndex) -- 535
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 536
				if solarHub ~= nil then -- 536
					solarHub.hide() -- 537
				end -- 537
				enterLevel(levelIndex) -- 538
			end, -- 535
			onReplayIntro = function() -- 540
				if solarHub ~= nil then -- 540
					solarHub.hide() -- 541
				end -- 541
				startOpening() -- 542
				print("[escape-velocity] opening replay from solarHub") -- 543
			end -- 540
		}) -- 540
		return solarHub -- 546
	end -- 524
	local function onBackToSelectTap() -- 549
		local rt = resultRuntime() -- 550
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 551
		if rt == nil then -- 551
			return -- 552
		end -- 552
		local runtime = rt -- 553
		if not runtime.game:backToSelect() then -- 553
			return -- 555
		end -- 555
		runtime.world.visible = false -- 556
		runtime.aim:setEnabled(false) -- 557
		if resultPanel ~= nil then -- 557
			resultPanel:hide() -- 558
		end -- 558
		if finalePanel ~= nil then -- 558
			finalePanel:hide() -- 560
		end -- 560
		if select ~= nil then -- 560
			select:hide() -- 561
		end -- 561
		progress = loadProgress(levelTotal) -- 563
		local hub = ensureSolarHub() -- 564
		Director:pushCamera(hubCamera) -- 565
		hub.show(progress) -- 566
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 567
			getTotalRockets(progress, levelTotal), -- 567
			0 -- 567
		)) -- 567
	end -- 549
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 580
		finalePanel = createFinalePanel( -- 583
			uiLayer, -- 583
			viewW, -- 583
			viewH, -- 583
			{onBackToSelect = function() return onBackToSelectTap() end} -- 583
		) -- 583
		resultPanel = createResultPanel( -- 586
			uiLayer, -- 586
			viewW, -- 586
			viewH, -- 586
			{ -- 586
				onRetry = function() return onRetryTap() end, -- 587
				onBackToSelect = function() return onBackToSelectTap() end -- 588
			} -- 588
		) -- 588
		activeResultPanel = resultPanel -- 590
		local created = createLevelSelect( -- 591
			uiLayer, -- 591
			viewW, -- 591
			viewH, -- 591
			{ -- 591
				levels = levelEntries, -- 592
				onPick = function(____, index) -- 593
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 594
					if select ~= nil then -- 594
						select:hide() -- 595
					end -- 595
					enterLevel(index) -- 596
				end, -- 593
				onReplayIntro = function() -- 599
					if select ~= nil then -- 599
						select:hide() -- 600
					end -- 600
					startOpening() -- 601
					print("[escape-velocity] opening replay (user)") -- 602
				end -- 599
			} -- 599
		) -- 599
		select = created -- 605
		return created -- 606
	end -- 580
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 619
		local w = View.size.width -- 620
		local h = View.size.height -- 621
		if w == viewW and h == viewH then -- 621
			return -- 622
		end -- 622
		if opening ~= nil then -- 622
			opening.hide() -- 628
			opening = nil -- 629
		end -- 629
		if select ~= nil then -- 629
			select:hide() -- 631
		end -- 631
		if resultPanel ~= nil then -- 631
			resultPanel:hide() -- 632
		end -- 632
		if finalePanel ~= nil then -- 632
			finalePanel:hide() -- 633
		end -- 633
		do -- 633
			local i = 0 -- 634
			while i < levelTotal do -- 634
				local slot = slots[i + 1] -- 635
				if slot.runtime ~= nil then -- 635
					slot.runtime.world.visible = false -- 637
					slot.runtime.aim:setEnabled(false) -- 638
					slot.runtime.trajectory:clearPrediction() -- 641
					slot.runtime.trajectory:clearTrail() -- 642
					slot.runtime.trajectory:clearGoalRings() -- 644
					slot.runtime.plan:setVisible(false) -- 647
					slot.runtime.plan:clear() -- 648
				end -- 648
				slot.built = false -- 650
				slot.runtime = nil -- 651
				i = i + 1 -- 634
			end -- 634
		end -- 634
		viewW = w -- 655
		viewH = h -- 656
		uiLayer.size = Size(viewW, viewH) -- 657
		openingLayer.size = Size(viewW, viewH) -- 658
		hubLayer.size = Size(viewW, viewH) -- 659
		do -- 659
			local i = 0 -- 660
			while i < levelTotal do -- 660
				levelLayers[i + 1].size = Size(viewW, viewH) -- 660
				i = i + 1 -- 660
			end -- 660
		end -- 660
		if solarHub ~= nil then -- 660
			solarHub.relayout(viewW, viewH) -- 662
		end -- 662
		buildPanels() -- 666
		if activeIndex >= 0 then -- 666
			local keep = activeIndex -- 668
			activeIndex = -1 -- 669
			enterLevel(keep) -- 670
		else -- 670
			local hub = ensureSolarHub() -- 672
			Director:pushCamera(hubCamera) -- 673
			hub.show(progress) -- 674
		end -- 674
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 676
	end -- 619
	Director.entry:onAppChange(function(name) -- 680
		if name == "Size" then -- 680
			relayoutForViewport() -- 681
		end -- 681
	end) -- 680
	local introSeen = loadIntroSeen() -- 689
	local forceIntro = false -- 690
	opening = nil -- 691
	startOpening = function() -- 693
		if opening == nil then -- 693
			opening = createOpening({ -- 695
				root = openingRoot, -- 696
				camera = openingCamera, -- 697
				layer = openingLayer, -- 698
				viewW = viewW, -- 699
				viewH = viewH, -- 700
				fovYDeg = View.fieldOfView, -- 701
				aspect = View.aspectRatio, -- 702
				spherePath = "Assets/Model/Sphere.gltf", -- 703
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 704
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 705
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 706
				onFinish = function() -- 707
					introHold = -1 -- 708
					if not introSeen then -- 708
						saveIntroSeen() -- 710
						introSeen = true -- 711
						print("[escape-velocity] intro seen -> saved") -- 712
					end -- 712
					if opening ~= nil then -- 712
						opening.hide() -- 715
					end -- 715
					if select ~= nil then -- 715
						select:hide() -- 716
					end -- 716
					local hub = ensureSolarHub() -- 717
					Director:pushCamera(hubCamera) -- 718
					hub.show(progress) -- 719
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 720
						opening.frameIndex(), -- 720
						0 -- 720
					) or "?")) -- 720
				end -- 707
			}) -- 707
		end -- 707
		if opening == nil then -- 707
			return -- 724
		end -- 724
		Director:pushCamera(openingCamera) -- 725
		opening.start() -- 726
		print("[escape-velocity] opening start (first launch)") -- 727
	end -- 693
	local startupPanel = buildPanels() -- 730
	local enterReq = Path( -- 742
		Path(".", ".agent", "test-results"), -- 742
		"enter-request.txt" -- 742
	) -- 742
	local autoLaunchAt = -1 -- 743
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 745
	local autoFrame = 0 -- 746
	local autoVX = 0 -- 747
	local autoVY = 0 -- 748
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 756
	local autoBackAt = -1 -- 758
	local autoReenterAt = -1 -- 759
	local autoEntered = false -- 760
	introHold = -1 -- 762
	if Content:exist(enterReq) then -- 762
		local spec = Content:load(enterReq) -- 764
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 765
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 766
		if head == "intro" then -- 766
			forceIntro = true -- 768
			if at >= 0 then -- 768
				local rest = __TS__StringSubstring(spec, at + 1) -- 770
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 771
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 771
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 773
					if v ~= nil and v >= 0 then -- 773
						introHold = v -- 775
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 776
					end -- 776
				end -- 776
			end -- 776
		end -- 776
		local n = tonumber(head) -- 781
		if n ~= nil and n >= 1 and n <= levelTotal then -- 781
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 783
			enterLevel(n - 1) -- 784
			autoEntered = true -- 785
			if at >= 0 then -- 785
				local rest = __TS__StringSubstring(spec, at + 1) -- 787
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 787
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 792
					if f ~= nil and f >= 0 then -- 792
						autoArmAt = f -- 794
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 795
					end -- 795
				else -- 795
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 798
					local c2 = (string.find( -- 799
						rest, -- 799
						":", -- 799
						math.max(c1 + 1 + 1, 1), -- 799
						true -- 799
					) or 0) - 1 -- 799
					if c1 > 0 and c2 > c1 then -- 799
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 801
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 802
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 805
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 806
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 807
						local vy = tonumber(vyText) -- 808
						local ____temp_0 -- 809
						if c3 > 0 then -- 809
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 809
						else -- 809
							____temp_0 = nil -- 809
						end -- 809
						local steps = ____temp_0 -- 809
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 809
							autoLaunchAt = frames -- 811
							autoVX = vx -- 812
							autoVY = vy -- 813
							if steps ~= nil and steps > 0 then -- 813
								autoWarpSteps = math.floor(steps) -- 815
							end -- 815
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 817
						end -- 817
					end -- 817
				end -- 817
			end -- 817
		end -- 817
	end -- 817
	if autoEntered then -- 817
		print("[escape-velocity] opening skipped (auto enter)") -- 830
	elseif forceIntro or not introSeen then -- 830
		startOpening() -- 832
	else -- 832
		local hub = ensureSolarHub() -- 834
		Director:pushCamera(hubCamera) -- 835
		hub.show(progress) -- 836
		print("[escape-velocity] entered solarHub (already seen)") -- 837
	end -- 837
	threadLoop(function() -- 842
		advanceUiClock(App.deltaTime) -- 846
		if solarHub ~= nil and solarHub.visible() then -- 846
			solarHub.step(App.deltaTime) -- 850
		end -- 850
		if opening ~= nil and opening.running() then -- 850
			if introHold < 0 or opening.frameIndex() < introHold then -- 850
				opening.step() -- 856
			end -- 856
			if App.deltaTime > 0.05 then -- 856
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 860
					opening.frameIndex(), -- 860
					0 -- 860
				)) -- 860
			end -- 860
		end -- 860
		local runtime = activeRuntime() -- 864
		if runtime ~= nil then -- 864
			runtime.game:update(App.deltaTime) -- 866
			runtime.aim:setBurnInfo( -- 868
				runtime.game:burnNow(), -- 868
				runtime.dvBudget -- 868
			) -- 868
			if runtime.levelHasTimeWindow then -- 868
				runtime.aim:setDate( -- 871
					runtime.game:dateNow(), -- 871
					runtime.dateSpan -- 871
				) -- 871
			end -- 871
			local phaseNow = runtime.game:phase() -- 875
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 876
			runtime.aim:update(App.deltaTime) -- 877
			runtime.aim:setArmed(runtime.game:armed()) -- 879
			local is2D = runtime.game:viewMode() == "2D" -- 881
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 882
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 883
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 884
			runtime.aim:setMissionDrawerVisible(inAim) -- 885
			local curBurn = runtime.game:burnNow() -- 887
			local fuelLimit = runtime.dvBudget * 0.75 -- 888
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 889
			runtime.aim:setTimeControl( -- 892
				runtime.game:speedPow(), -- 893
				runtime.game:speedMaxPow(), -- 894
				runtime.game:isPaused(), -- 895
				runtime.game:missionSeconds() -- 896
			) -- 896
			local brakeActive = phaseNow == "Flying" and runtime.game:isBrakeWindowActive() or debugForceBrakeWindow -- 899
			local isBraked = runtime.game:hasBraked() or debugForceBraked -- 900
			runtime.aim:setLiveBrakeVisible(brakeActive) -- 901
			runtime.aim:setLiveBraked(isBraked) -- 902
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 902
				autoFrame = autoFrame + 1 -- 905
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 905
					autoArmAt = -1 -- 908
					print("[escape-velocity] auto arm (enter-request)") -- 909
					runtime.game:aimReady() -- 910
				end -- 910
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 910
					autoLaunchAt = -1 -- 913
					print("[escape-velocity] auto launch") -- 914
					if autoWarpSteps > 0 then -- 914
						do -- 914
							local s = 0 -- 918
							while s < autoWarpSteps do -- 918
								runtime.game:stepTime(1, runtime.dateSpan) -- 918
								s = s + 1 -- 918
							end -- 918
						end -- 918
						autoWarpSteps = 0 -- 919
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 920
							runtime.game:dateNow(), -- 920
							0 -- 920
						)) .. ")") -- 920
					end -- 920
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 922
					runtime.game:launch({x = autoVX, y = autoVY}) -- 923
					autoBackAt = autoFrame + 320 -- 924
					autoReenterAt = autoFrame + 380 -- 925
				end -- 925
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 925
					autoBackAt = -1 -- 929
					if runtime.game:backToSelect() then -- 929
						print("[escape-velocity] auto back to select") -- 930
					end -- 930
				end -- 930
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 930
					autoReenterAt = -1 -- 933
					print("[escape-velocity] auto re-enter") -- 934
					enterLevel(0) -- 935
				end -- 935
			end -- 935
		end -- 935
		return false -- 940
	end) -- 842
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 944
	debugTriggerResultFn = function(levelIndex, outcome) -- 946
		if outcome == nil then -- 946
			outcome = "success" -- 946
		end -- 946
		if solarHub ~= nil then -- 946
			solarHub.hide() -- 947
		end -- 947
		if opening ~= nil then -- 947
			opening.hide() -- 948
		end -- 948
		local def = getLevel(levelIndex) -- 949
		if def == nil or resultPanel == nil then -- 949
			return -- 950
		end -- 950
		local burn = def.dvBudget * 0.65 -- 951
		local challengesList = {} -- 952
		if def.mission ~= nil then -- 952
			do -- 952
				local k = 0 -- 954
				while k < #def.mission.challenges do -- 954
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 955
					k = k + 1 -- 954
				end -- 954
			end -- 954
		end -- 954
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 958
		resultPanel:show(outcome, titleWithSub, { -- 962
			result = outcome, -- 963
			levelName = titleWithSub, -- 964
			levelIndex = levelIndex, -- 965
			rocketsGot = outcome == "success" and 3 or 0, -- 966
			challenges = challengesList, -- 967
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 968
			burnDv = burn, -- 969
			dvBudget = def.dvBudget, -- 970
			flightTime = 12.8, -- 971
			totalRockets = outcome == "success" and 16 or 13, -- 972
			totalPossibleRockets = 18 -- 973
		}) -- 973
	end -- 946
	debugTriggerBrakeWindowFn = function(levelIndex) -- 977
		if solarHub ~= nil then -- 977
			solarHub.hide() -- 978
		end -- 978
		if opening ~= nil then -- 978
			opening.hide() -- 979
		end -- 979
		enterLevel(levelIndex) -- 980
		local rt = activeRuntime() -- 981
		if rt ~= nil then -- 981
			rt.game:launch({x = 2, y = -20}) -- 983
			debugForceBrakeWindow = true -- 984
			debugForceBraked = false -- 985
			rt.aim:setLiveBrakeVisible(true) -- 986
			rt.aim:setLiveBraked(false) -- 987
			if rt.game:viewMode() ~= "3D" then -- 987
				rt.game:toggleViewMode() -- 988
			end -- 988
		end -- 988
	end -- 977
	debugTriggerBrakePressFn = function() -- 992
		debugForceBrakeWindow = true -- 993
		debugForceBraked = true -- 994
		local rt = activeRuntime() -- 995
		if rt ~= nil then -- 995
			rt.aim:setLiveBrakeVisible(true) -- 997
			rt.aim:setLiveBraked(true) -- 998
		end -- 998
	end -- 992
	debugTriggerEnterLevelFn = function(levelIndex) -- 1002
		if solarHub ~= nil then -- 1002
			solarHub.hide() -- 1003
		end -- 1003
		if opening ~= nil then -- 1003
			opening.hide() -- 1004
		end -- 1004
		enterLevel(levelIndex) -- 1005
	end -- 1002
	debugTriggerZoomInFn = function() -- 1008
		local rt = activeRuntime() -- 1009
		if rt ~= nil then -- 1009
			rt.plan:zoomIn() -- 1011
		end -- 1011
	end -- 1008
	debugTriggerResetViewFn = function() -- 1015
		local rt = activeRuntime() -- 1016
		if rt ~= nil then -- 1016
			rt.plan:resetView() -- 1018
		end -- 1018
	end -- 1015
end -- 1015
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1024
	return activeResultPanel -- 1025
end -- 1024
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1029
	if outcome == nil then -- 1029
		outcome = "success" -- 1029
	end -- 1029
	if debugTriggerResultFn ~= nil then -- 1029
		debugTriggerResultFn(levelIndex, outcome) -- 1031
	end -- 1031
end -- 1029
--- 触发进入制动窗口演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakeWindow(levelIndex) -- 1036
	if levelIndex == nil then -- 1036
		levelIndex = 3 -- 1036
	end -- 1036
	if debugTriggerBrakeWindowFn ~= nil then -- 1036
		debugTriggerBrakeWindowFn(levelIndex) -- 1038
	end -- 1038
end -- 1036
--- 触发按下逆喷制动按钮演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakePress() -- 1043
	if debugTriggerBrakePressFn ~= nil then -- 1043
		debugTriggerBrakePressFn() -- 1045
	end -- 1045
end -- 1043
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1050
	if debugTriggerEnterLevelFn ~= nil then -- 1050
		debugTriggerEnterLevelFn(levelIndex) -- 1052
	end -- 1052
end -- 1050
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1057
	if debugTriggerZoomInFn ~= nil then -- 1057
		debugTriggerZoomInFn() -- 1059
	end -- 1059
end -- 1057
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1064
	if debugTriggerResetViewFn ~= nil then -- 1064
		debugTriggerResetViewFn() -- 1066
	end -- 1066
end -- 1064
return ____exports -- 1064
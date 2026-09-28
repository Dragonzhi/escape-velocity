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
local debugForceBrakeWindow = false -- 62
local debugForceBraked = false -- 63
local activeResultPanel = nil -- 64
local levelTotal = levelCount() -- 72
if levelTotal <= 0 then -- 72
	print("[escape-velocity] FATAL: no level data") -- 75
else -- 75
	local opening, startOpening, introHold -- 75
	local viewW = View.size.width -- 77
	local viewH = View.size.height -- 78
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 81
	local levelLayers = {} -- 87
	do -- 87
		local i = 0 -- 88
		while i < levelTotal do -- 88
			local layer = Node() -- 89
			layer.size = Size(viewW, viewH) -- 90
			layer.anchor = Vec2(0.5, 0.5) -- 91
			layer.position = Vec2(0, 0) -- 92
			Director.ui:addChild(layer) -- 93
			levelLayers[#levelLayers + 1] = layer -- 94
			i = i + 1 -- 88
		end -- 88
	end -- 88
	local openingLayer = Node() -- 99
	openingLayer.size = Size(viewW, viewH) -- 100
	openingLayer.anchor = Vec2(0.5, 0.5) -- 101
	openingLayer.position = Vec2(0, 0) -- 102
	Director.ui:addChild(openingLayer) -- 103
	local openingRoot = Node3D() -- 106
	openingRoot.visible = false -- 107
	Director.entry:addChild(openingRoot) -- 108
	local openingCamera = Camera3D() -- 109
	local hubRoot = Node3D() -- 112
	hubRoot.visible = false -- 113
	Director.entry:addChild(hubRoot) -- 114
	local hubCamera = Camera3D() -- 115
	local hubLayer = Node() -- 117
	hubLayer.size = Size(viewW, viewH) -- 118
	hubLayer.anchor = Vec2(0.5, 0.5) -- 119
	hubLayer.position = Vec2(0, 0) -- 120
	Director.ui:addChild(hubLayer) -- 121
	local uiLayer = Node() -- 124
	uiLayer.size = Size(viewW, viewH) -- 125
	uiLayer.anchor = Vec2(0.5, 0.5) -- 126
	uiLayer.position = Vec2(0, 0) -- 127
	Director.ui:addChild(uiLayer) -- 128
	local levelNames = {} -- 131
	do -- 131
		local i = 0 -- 132
		while i < levelTotal do -- 132
			local def = getLevel(i) -- 133
			local title = def ~= nil and def.title or "" -- 134
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 135
			i = i + 1 -- 132
		end -- 132
	end -- 132
	local levelEntries = {} -- 137
	do -- 137
		local i = 0 -- 138
		while i < levelTotal do -- 138
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 138
			i = i + 1 -- 138
		end -- 138
	end -- 138
	local progress = loadProgress(levelTotal) -- 141
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 142
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 143
	local slots = {} -- 145
	do -- 145
		local i = 0 -- 146
		while i < levelTotal do -- 146
			slots[#slots + 1] = {built = false, runtime = nil} -- 146
			i = i + 1 -- 146
		end -- 146
	end -- 146
	local activeIndex = -1 -- 148
	local select = nil -- 149
	local solarHub = nil -- 150
	local resultPanel = nil -- 151
	local finalePanel = nil -- 153
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 155
	local resultIndex = -1 -- 160
	local function activeRuntime() -- 162
		if activeIndex < 0 then -- 162
			return nil -- 163
		end -- 163
		return slots[activeIndex + 1].runtime -- 164
	end -- 162
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 172
		do -- 172
			local i = 0 -- 173
			while i < levelTotal do -- 173
				do -- 173
					local slot = slots[i + 1] -- 174
					levelLayers[i + 1].visible = i == index -- 177
					if slot.runtime == nil then -- 177
						goto __continue16 -- 178
					end -- 178
					local active = i == index -- 179
					slot.runtime.world.visible = active -- 180
					slot.runtime.aim:setEnabled(active) -- 181
					if active then -- 181
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 183
					end -- 183
				end -- 183
				::__continue16:: -- 183
				i = i + 1 -- 173
			end -- 173
		end -- 173
	end -- 172
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 192
		local game -- 192
		local slot = slots[index + 1] -- 193
		if slot.built and slot.runtime ~= nil then -- 193
			return slot.runtime -- 194
		end -- 194
		local def = getLevel(index) -- 196
		if def == nil then -- 196
			return nil -- 197
		end -- 197
		local bodies = scaledPlanets(def) -- 199
		local level = { -- 200
			bodies = bodies, -- 201
			probeStart = def.probeStart, -- 202
			probeVel0 = def.probeVel0, -- 204
			goal = def.goal, -- 205
			escapeRadius = def.escapeRadius, -- 206
			physicsStep = levelRuntime(index).physicsStep, -- 207
			playback = levelRuntime(index).playback, -- 208
			aimClockRate = levelRuntime(index).aimClockRate, -- 209
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 210
			aimMin = levelRuntime(index).aimMin, -- 211
			maxSteps = def.maxSteps -- 212
		} -- 212
		local world = Node3D() -- 215
		Director.entry:addChild(world) -- 216
		world.visible = false -- 217
		local rtg = def.probeVariant == "rtg" -- 219
		local scene = buildScene({ -- 220
			root = world, -- 221
			bodies = bodies, -- 222
			visuals = def.visuals, -- 223
			probeStart = level.probeStart, -- 224
			probeScale = levelRuntime(index).probeVisualRadius, -- 230
			spherePath = "Assets/Model/Sphere.gltf", -- 231
			ringPath = "Assets/Model/Ring.gltf", -- 232
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 233
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 240
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 241
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 242
			probeBodyRadius = rtg and 0.871 or 1.084, -- 243
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 245
		}) -- 245
		if scene == nil then -- 245
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 248
			return nil -- 249
		end -- 249
		local rt = levelRuntime(index) -- 252
		local camera = Camera3D() -- 253
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 256
		local trajectory = createTrajectoryView( -- 257
			levelLayers[index + 1], -- 257
			trajectoryOptions() -- 257
		) -- 257
		local plan = createPlanView( -- 260
			levelLayers[index + 1], -- 260
			viewW, -- 260
			viewH, -- 260
			defaultPlanOptions(), -- 260
			def.planCenter -- 260
		) -- 260
		local planTolerance = arrivalRingRadius(def.goal) -- 261
		plan:fitTo(planFitRadius( -- 262
			bodies, -- 262
			level.probeStart, -- 262
			def.goal.planetIndex, -- 262
			planTolerance, -- 262
			def.planCenter -- 262
		)) -- 262
		local aim = createAimInput( -- 264
			levelLayers[index + 1], -- 264
			viewW, -- 264
			viewH, -- 264
			def.dvBudget, -- 264
			rt.aimMin, -- 264
			rt.playbackSpeeds -- 264
		) -- 264
		aim:setBurnInfo(0, def.dvBudget) -- 266
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 268
		aim:setDate(0, dateSpan) -- 269
		aim:onWarp(function(dir) -- 270
			game:stepTime(dir, dateSpan) -- 271
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 272
		end) -- 270
		game = createGame( -- 275
			level, -- 275
			{ -- 275
				scene = scene, -- 276
				camera = camera, -- 277
				rig = rig, -- 278
				trajectory = trajectory, -- 279
				plan = plan, -- 280
				visuals = def.visuals, -- 282
				setWorldVisible = function(____, on) -- 284
					world.visible = on -- 285
				end, -- 284
				aim = aim, -- 287
				viewW = viewW, -- 288
				viewH = viewH, -- 289
				fovYDeg = View.fieldOfView, -- 290
				aspect = View.aspectRatio, -- 291
				onPhase = function(____, p) -- 292
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 293
					if index == activeIndex then -- 293
						if p == "Finale" then -- 293
							if resultPanel ~= nil then -- 293
								resultPanel:hide() -- 301
							end -- 301
							if finalePanel ~= nil then -- 301
								finalePanel:show(finaleText.main, finaleText.sub) -- 302
							end -- 302
						else -- 302
							if p ~= "Result" and resultPanel ~= nil then -- 302
								resultPanel:hide() -- 304
							end -- 304
							if finalePanel ~= nil then -- 304
								finalePanel:hide() -- 305
							end -- 305
						end -- 305
					end -- 305
				end, -- 292
				onResult = function(____, r, telemetry) -- 309
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 310
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity}) -- 316
					progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 323
					saveProgress(progress) -- 324
					local currentTotal = getTotalRockets(progress, levelTotal) -- 325
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 327
					resultIndex = index -- 331
					local challengesList = {} -- 333
					if def.mission ~= nil then -- 333
						do -- 333
							local k = 0 -- 335
							while k < #def.mission.challenges do -- 335
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 336
								k = k + 1 -- 335
							end -- 335
						end -- 335
					end -- 335
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 340
					local detailParams = { -- 344
						result = r, -- 345
						levelName = titleWithSub, -- 346
						levelIndex = index, -- 347
						rocketsGot = evalInfo.rockets, -- 348
						challenges = challengesList, -- 349
						achieved = evalInfo.achieved, -- 350
						burnDv = telem.burnDv, -- 351
						dvBudget = def.dvBudget, -- 352
						flightTime = telem.flightTime, -- 353
						totalRockets = currentTotal, -- 354
						totalPossibleRockets = levelTotal * 3 -- 355
					} -- 355
					if resultPanel ~= nil then -- 355
						resultPanel:show(r, titleWithSub, detailParams) -- 359
					end -- 359
				end, -- 309
				onFinale = function(____, info) -- 363
					finaleText = { -- 364
						main = FinaleMainText, -- 364
						sub = finaleSubtitle(info.distance, info.time) -- 364
					} -- 364
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 365
				end, -- 363
				finale = index == levelTotal - 1 -- 370
			} -- 370
		) -- 370
		aim:onDrag(function(a) -- 376
			game:onAimDrag(a) -- 377
			aim:setBurnInfo( -- 379
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 379
				def.dvBudget -- 379
			) -- 379
		end) -- 376
		aim:onAimReady(function(a) -- 382
			game:onAimDrag(a) -- 383
			game:aimReady() -- 384
			print("[escape-velocity] aim ready -> Armed") -- 385
		end) -- 382
		aim:onLaunch(function() -- 387
			print("[escape-velocity] launch button tap") -- 388
			game:launchArmed() -- 389
		end) -- 387
		aim:onObserve(function(dx, dy) -- 392
			game:observeDrag(dx, dy) -- 393
		end) -- 392
		aim:onZoom(function(deltaDist) -- 395
			game:observeZoom(deltaDist) -- 396
		end) -- 395
		aim:onViewToggle(function() -- 399
			game:toggleViewMode() -- 400
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 401
		end) -- 399
		aim:onBrake(function(on) -- 404
			game:setBrakeMode(on) -- 405
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 406
		end) -- 404
		aim:setBrake(game:brakeMode()) -- 408
		aim:onPlayback(function(speed) -- 411
			game:setPlaybackSpeed(speed) -- 412
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 413
		end) -- 411
		aim:setPlayback(game:playbackSpeed()) -- 415
		aim:onLiveBrake(function() -- 417
			print(("[escape-velocity] tap: live brake (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 418
			game:applyInFlightBrake() -- 419
		end) -- 417
		local runtime = { -- 422
			index = index, -- 423
			name = levelNames[index + 1], -- 424
			world = world, -- 425
			camera = camera, -- 426
			game = game, -- 427
			aim = aim, -- 428
			trajectory = trajectory, -- 429
			plan = plan, -- 430
			levelHasTimeWindow = def.timeWindow ~= nil, -- 431
			dvBudget = def.dvBudget, -- 432
			dateSpan = dateSpan -- 433
		} -- 433
		slot.built = true -- 435
		slot.runtime = runtime -- 436
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 437
		return runtime -- 438
	end -- 192
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 442
		local runtime = ensureLevel(index) -- 443
		if runtime == nil then -- 443
			return -- 444
		end -- 444
		local wasActive = activeIndex == index -- 447
		if opening ~= nil then -- 447
			opening.hide() -- 449
		end -- 449
		if select ~= nil then -- 449
			select:hide() -- 450
		end -- 450
		if solarHub ~= nil then -- 450
			solarHub.hide() -- 451
		end -- 451
		activeIndex = index -- 452
		showOnlyLevel(index) -- 453
		if not wasActive then -- 453
			Director:pushCamera(runtime.camera) -- 454
		end -- 454
		runtime.game:startLevel() -- 455
		print("[escape-velocity] enter " .. runtime.name) -- 456
	end -- 442
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 460
		if resultIndex >= 0 and resultIndex < levelTotal then -- 460
			local rt = slots[resultIndex + 1].runtime -- 462
			if rt ~= nil then -- 462
				return rt -- 463
			end -- 463
		end -- 463
		return activeRuntime() -- 465
	end -- 460
	local function onRetryTap() -- 468
		local rt = resultRuntime() -- 470
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 471
		if resultPanel ~= nil then -- 471
			resultPanel:hide() -- 472
		end -- 472
		if rt ~= nil then -- 472
			rt.game:retry() -- 473
		end -- 473
	end -- 468
	local function ensureSolarHub() -- 476
		if solarHub ~= nil then -- 476
			return solarHub -- 477
		end -- 477
		solarHub = createSolarHub({ -- 478
			root = hubRoot, -- 479
			camera = hubCamera, -- 480
			layer = hubLayer, -- 481
			viewW = viewW, -- 482
			viewH = viewH, -- 483
			fovYDeg = View.fieldOfView, -- 484
			aspect = View.aspectRatio, -- 485
			spherePath = "Assets/Model/Sphere.gltf", -- 486
			onLaunch = function(____, levelIndex) -- 487
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 488
				if solarHub ~= nil then -- 488
					solarHub.hide() -- 489
				end -- 489
				enterLevel(levelIndex) -- 490
			end, -- 487
			onReplayIntro = function() -- 492
				if solarHub ~= nil then -- 492
					solarHub.hide() -- 493
				end -- 493
				startOpening() -- 494
				print("[escape-velocity] opening replay from solarHub") -- 495
			end -- 492
		}) -- 492
		return solarHub -- 498
	end -- 476
	local function onBackToSelectTap() -- 501
		local rt = resultRuntime() -- 502
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 503
		if rt == nil then -- 503
			return -- 504
		end -- 504
		local runtime = rt -- 505
		if not runtime.game:backToSelect() then -- 505
			return -- 507
		end -- 507
		runtime.world.visible = false -- 508
		runtime.aim:setEnabled(false) -- 509
		if resultPanel ~= nil then -- 509
			resultPanel:hide() -- 510
		end -- 510
		if finalePanel ~= nil then -- 510
			finalePanel:hide() -- 512
		end -- 512
		if select ~= nil then -- 512
			select:hide() -- 513
		end -- 513
		progress = loadProgress(levelTotal) -- 515
		local hub = ensureSolarHub() -- 516
		Director:pushCamera(hubCamera) -- 517
		hub.show(progress) -- 518
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 519
			getTotalRockets(progress, levelTotal), -- 519
			0 -- 519
		)) -- 519
	end -- 501
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 532
		finalePanel = createFinalePanel( -- 535
			uiLayer, -- 535
			viewW, -- 535
			viewH, -- 535
			{onBackToSelect = function() return onBackToSelectTap() end} -- 535
		) -- 535
		resultPanel = createResultPanel( -- 538
			uiLayer, -- 538
			viewW, -- 538
			viewH, -- 538
			{ -- 538
				onRetry = function() return onRetryTap() end, -- 539
				onBackToSelect = function() return onBackToSelectTap() end -- 540
			} -- 540
		) -- 540
		activeResultPanel = resultPanel -- 542
		local created = createLevelSelect( -- 543
			uiLayer, -- 543
			viewW, -- 543
			viewH, -- 543
			{ -- 543
				levels = levelEntries, -- 544
				onPick = function(____, index) -- 545
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 546
					if select ~= nil then -- 546
						select:hide() -- 547
					end -- 547
					enterLevel(index) -- 548
				end, -- 545
				onReplayIntro = function() -- 551
					if select ~= nil then -- 551
						select:hide() -- 552
					end -- 552
					startOpening() -- 553
					print("[escape-velocity] opening replay (user)") -- 554
				end -- 551
			} -- 551
		) -- 551
		select = created -- 557
		return created -- 558
	end -- 532
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 571
		local w = View.size.width -- 572
		local h = View.size.height -- 573
		if w == viewW and h == viewH then -- 573
			return -- 574
		end -- 574
		if opening ~= nil then -- 574
			opening.hide() -- 580
			opening = nil -- 581
		end -- 581
		if select ~= nil then -- 581
			select:hide() -- 583
		end -- 583
		if resultPanel ~= nil then -- 583
			resultPanel:hide() -- 584
		end -- 584
		if finalePanel ~= nil then -- 584
			finalePanel:hide() -- 585
		end -- 585
		do -- 585
			local i = 0 -- 586
			while i < levelTotal do -- 586
				local slot = slots[i + 1] -- 587
				if slot.runtime ~= nil then -- 587
					slot.runtime.world.visible = false -- 589
					slot.runtime.aim:setEnabled(false) -- 590
					slot.runtime.trajectory:clearPrediction() -- 593
					slot.runtime.trajectory:clearTrail() -- 594
					slot.runtime.trajectory:clearGoalRings() -- 596
					slot.runtime.plan:setVisible(false) -- 599
					slot.runtime.plan:clear() -- 600
				end -- 600
				slot.built = false -- 602
				slot.runtime = nil -- 603
				i = i + 1 -- 586
			end -- 586
		end -- 586
		viewW = w -- 607
		viewH = h -- 608
		uiLayer.size = Size(viewW, viewH) -- 609
		openingLayer.size = Size(viewW, viewH) -- 610
		hubLayer.size = Size(viewW, viewH) -- 611
		do -- 611
			local i = 0 -- 612
			while i < levelTotal do -- 612
				levelLayers[i + 1].size = Size(viewW, viewH) -- 612
				i = i + 1 -- 612
			end -- 612
		end -- 612
		if solarHub ~= nil then -- 612
			solarHub.relayout(viewW, viewH) -- 614
		end -- 614
		buildPanels() -- 618
		if activeIndex >= 0 then -- 618
			local keep = activeIndex -- 620
			activeIndex = -1 -- 621
			enterLevel(keep) -- 622
		else -- 622
			local hub = ensureSolarHub() -- 624
			Director:pushCamera(hubCamera) -- 625
			hub.show(progress) -- 626
		end -- 626
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 628
	end -- 571
	Director.entry:onAppChange(function(name) -- 632
		if name == "Size" then -- 632
			relayoutForViewport() -- 633
		end -- 633
	end) -- 632
	local introSeen = loadIntroSeen() -- 641
	local forceIntro = false -- 642
	opening = nil -- 643
	startOpening = function() -- 645
		if opening == nil then -- 645
			opening = createOpening({ -- 647
				root = openingRoot, -- 648
				camera = openingCamera, -- 649
				layer = openingLayer, -- 650
				viewW = viewW, -- 651
				viewH = viewH, -- 652
				fovYDeg = View.fieldOfView, -- 653
				aspect = View.aspectRatio, -- 654
				spherePath = "Assets/Model/Sphere.gltf", -- 655
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 656
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 657
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 658
				onFinish = function() -- 659
					introHold = -1 -- 660
					if not introSeen then -- 660
						saveIntroSeen() -- 662
						introSeen = true -- 663
						print("[escape-velocity] intro seen -> saved") -- 664
					end -- 664
					if opening ~= nil then -- 664
						opening.hide() -- 667
					end -- 667
					if select ~= nil then -- 667
						select:hide() -- 668
					end -- 668
					local hub = ensureSolarHub() -- 669
					Director:pushCamera(hubCamera) -- 670
					hub.show(progress) -- 671
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 672
						opening.frameIndex(), -- 672
						0 -- 672
					) or "?")) -- 672
				end -- 659
			}) -- 659
		end -- 659
		if opening == nil then -- 659
			return -- 676
		end -- 676
		Director:pushCamera(openingCamera) -- 677
		opening.start() -- 678
		print("[escape-velocity] opening start (first launch)") -- 679
	end -- 645
	local startupPanel = buildPanels() -- 682
	local enterReq = Path( -- 694
		Path(".", ".agent", "test-results"), -- 694
		"enter-request.txt" -- 694
	) -- 694
	local autoLaunchAt = -1 -- 695
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 697
	local autoFrame = 0 -- 698
	local autoVX = 0 -- 699
	local autoVY = 0 -- 700
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 708
	local autoBackAt = -1 -- 710
	local autoReenterAt = -1 -- 711
	local autoEntered = false -- 712
	introHold = -1 -- 714
	if Content:exist(enterReq) then -- 714
		local spec = Content:load(enterReq) -- 716
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 717
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 718
		if head == "intro" then -- 718
			forceIntro = true -- 720
			if at >= 0 then -- 720
				local rest = __TS__StringSubstring(spec, at + 1) -- 722
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 723
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 723
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 725
					if v ~= nil and v >= 0 then -- 725
						introHold = v -- 727
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 728
					end -- 728
				end -- 728
			end -- 728
		end -- 728
		local n = tonumber(head) -- 733
		if n ~= nil and n >= 1 and n <= levelTotal then -- 733
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 735
			enterLevel(n - 1) -- 736
			autoEntered = true -- 737
			if at >= 0 then -- 737
				local rest = __TS__StringSubstring(spec, at + 1) -- 739
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 739
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 744
					if f ~= nil and f >= 0 then -- 744
						autoArmAt = f -- 746
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 747
					end -- 747
				else -- 747
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 750
					local c2 = (string.find( -- 751
						rest, -- 751
						":", -- 751
						math.max(c1 + 1 + 1, 1), -- 751
						true -- 751
					) or 0) - 1 -- 751
					if c1 > 0 and c2 > c1 then -- 751
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 753
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 754
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 757
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 758
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 759
						local vy = tonumber(vyText) -- 760
						local ____temp_0 -- 761
						if c3 > 0 then -- 761
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 761
						else -- 761
							____temp_0 = nil -- 761
						end -- 761
						local steps = ____temp_0 -- 761
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 761
							autoLaunchAt = frames -- 763
							autoVX = vx -- 764
							autoVY = vy -- 765
							if steps ~= nil and steps > 0 then -- 765
								autoWarpSteps = math.floor(steps) -- 767
							end -- 767
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 769
						end -- 769
					end -- 769
				end -- 769
			end -- 769
		end -- 769
	end -- 769
	if autoEntered then -- 769
		print("[escape-velocity] opening skipped (auto enter)") -- 782
	elseif forceIntro or not introSeen then -- 782
		startOpening() -- 784
	else -- 784
		local hub = ensureSolarHub() -- 786
		Director:pushCamera(hubCamera) -- 787
		hub.show(progress) -- 788
		print("[escape-velocity] entered solarHub (already seen)") -- 789
	end -- 789
	threadLoop(function() -- 794
		advanceUiClock(App.deltaTime) -- 798
		if solarHub ~= nil and solarHub.visible() then -- 798
			solarHub.step(App.deltaTime) -- 802
		end -- 802
		if opening ~= nil and opening.running() then -- 802
			if introHold < 0 or opening.frameIndex() < introHold then -- 802
				opening.step() -- 808
			end -- 808
			if App.deltaTime > 0.05 then -- 808
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 812
					opening.frameIndex(), -- 812
					0 -- 812
				)) -- 812
			end -- 812
		end -- 812
		local runtime = activeRuntime() -- 816
		if runtime ~= nil then -- 816
			runtime.game:update(App.deltaTime) -- 818
			runtime.aim:setBurnInfo( -- 820
				runtime.game:burnNow(), -- 820
				runtime.dvBudget -- 820
			) -- 820
			if runtime.levelHasTimeWindow then -- 820
				runtime.aim:setDate( -- 823
					runtime.game:dateNow(), -- 823
					runtime.dateSpan -- 823
				) -- 823
			end -- 823
			local phaseNow = runtime.game:phase() -- 827
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 828
			runtime.aim:update(App.deltaTime) -- 829
			runtime.aim:setArmed(runtime.game:armed()) -- 831
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 833
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 835
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 836
			local brakeActive = phaseNow == "Flying" and runtime.game:isBrakeWindowActive() or debugForceBrakeWindow -- 838
			local isBraked = runtime.game:hasBraked() or debugForceBraked -- 839
			runtime.aim:setLiveBrakeVisible(brakeActive) -- 840
			runtime.aim:setLiveBraked(isBraked) -- 841
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 841
				autoFrame = autoFrame + 1 -- 844
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 844
					autoArmAt = -1 -- 847
					print("[escape-velocity] auto arm (enter-request)") -- 848
					runtime.game:aimReady() -- 849
				end -- 849
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 849
					autoLaunchAt = -1 -- 852
					print("[escape-velocity] auto launch") -- 853
					if autoWarpSteps > 0 then -- 853
						do -- 853
							local s = 0 -- 857
							while s < autoWarpSteps do -- 857
								runtime.game:stepTime(1, runtime.dateSpan) -- 857
								s = s + 1 -- 857
							end -- 857
						end -- 857
						autoWarpSteps = 0 -- 858
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 859
							runtime.game:dateNow(), -- 859
							0 -- 859
						)) .. ")") -- 859
					end -- 859
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 861
					runtime.game:launch({x = autoVX, y = autoVY}) -- 862
					autoBackAt = autoFrame + 320 -- 863
					autoReenterAt = autoFrame + 380 -- 864
				end -- 864
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 864
					autoBackAt = -1 -- 868
					if runtime.game:backToSelect() then -- 868
						print("[escape-velocity] auto back to select") -- 869
					end -- 869
				end -- 869
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 869
					autoReenterAt = -1 -- 872
					print("[escape-velocity] auto re-enter") -- 873
					enterLevel(0) -- 874
				end -- 874
			end -- 874
		end -- 874
		return false -- 879
	end) -- 794
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 883
	debugTriggerResultFn = function(levelIndex, outcome) -- 885
		if outcome == nil then -- 885
			outcome = "success" -- 885
		end -- 885
		if solarHub ~= nil then -- 885
			solarHub.hide() -- 886
		end -- 886
		if opening ~= nil then -- 886
			opening.hide() -- 887
		end -- 887
		local def = getLevel(levelIndex) -- 888
		if def == nil or resultPanel == nil then -- 888
			return -- 889
		end -- 889
		local burn = def.dvBudget * 0.65 -- 890
		local challengesList = {} -- 891
		if def.mission ~= nil then -- 891
			do -- 891
				local k = 0 -- 893
				while k < #def.mission.challenges do -- 893
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 894
					k = k + 1 -- 893
				end -- 893
			end -- 893
		end -- 893
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 897
		resultPanel:show(outcome, titleWithSub, { -- 901
			result = outcome, -- 902
			levelName = titleWithSub, -- 903
			levelIndex = levelIndex, -- 904
			rocketsGot = outcome == "success" and 3 or 0, -- 905
			challenges = challengesList, -- 906
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 907
			burnDv = burn, -- 908
			dvBudget = def.dvBudget, -- 909
			flightTime = 12.8, -- 910
			totalRockets = outcome == "success" and 16 or 13, -- 911
			totalPossibleRockets = 18 -- 912
		}) -- 912
	end -- 885
	debugTriggerBrakeWindowFn = function(levelIndex) -- 916
		if solarHub ~= nil then -- 916
			solarHub.hide() -- 917
		end -- 917
		if opening ~= nil then -- 917
			opening.hide() -- 918
		end -- 918
		enterLevel(levelIndex) -- 919
		local rt = activeRuntime() -- 920
		if rt ~= nil then -- 920
			rt.game:launch({x = 2, y = -20}) -- 922
			debugForceBrakeWindow = true -- 923
			debugForceBraked = false -- 924
			rt.aim:setLiveBrakeVisible(true) -- 925
			rt.aim:setLiveBraked(false) -- 926
			if rt.game:viewMode() ~= "3D" then -- 926
				rt.game:toggleViewMode() -- 927
			end -- 927
		end -- 927
	end -- 916
	debugTriggerBrakePressFn = function() -- 931
		debugForceBrakeWindow = true -- 932
		debugForceBraked = true -- 933
		local rt = activeRuntime() -- 934
		if rt ~= nil then -- 934
			rt.aim:setLiveBrakeVisible(true) -- 936
			rt.aim:setLiveBraked(true) -- 937
		end -- 937
	end -- 931
end -- 931
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 943
	return activeResultPanel -- 944
end -- 943
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 948
	if outcome == nil then -- 948
		outcome = "success" -- 948
	end -- 948
	if debugTriggerResultFn ~= nil then -- 948
		debugTriggerResultFn(levelIndex, outcome) -- 950
	end -- 950
end -- 948
--- 触发进入制动窗口演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakeWindow(levelIndex) -- 955
	if levelIndex == nil then -- 955
		levelIndex = 3 -- 955
	end -- 955
	if debugTriggerBrakeWindowFn ~= nil then -- 955
		debugTriggerBrakeWindowFn(levelIndex) -- 957
	end -- 957
end -- 955
--- 触发按下逆喷制动按钮演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakePress() -- 962
	if debugTriggerBrakePressFn ~= nil then -- 962
		debugTriggerBrakePressFn() -- 964
	end -- 964
end -- 962
return ____exports -- 962
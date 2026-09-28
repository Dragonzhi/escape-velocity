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
local activeResultPanel = nil -- 60
local levelTotal = levelCount() -- 68
if levelTotal <= 0 then -- 68
	print("[escape-velocity] FATAL: no level data") -- 71
else -- 71
	local opening, startOpening, introHold -- 71
	local viewW = View.size.width -- 73
	local viewH = View.size.height -- 74
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 77
	local levelLayers = {} -- 83
	do -- 83
		local i = 0 -- 84
		while i < levelTotal do -- 84
			local layer = Node() -- 85
			layer.size = Size(viewW, viewH) -- 86
			layer.anchor = Vec2(0.5, 0.5) -- 87
			layer.position = Vec2(0, 0) -- 88
			Director.ui:addChild(layer) -- 89
			levelLayers[#levelLayers + 1] = layer -- 90
			i = i + 1 -- 84
		end -- 84
	end -- 84
	local openingLayer = Node() -- 95
	openingLayer.size = Size(viewW, viewH) -- 96
	openingLayer.anchor = Vec2(0.5, 0.5) -- 97
	openingLayer.position = Vec2(0, 0) -- 98
	Director.ui:addChild(openingLayer) -- 99
	local openingRoot = Node3D() -- 102
	openingRoot.visible = false -- 103
	Director.entry:addChild(openingRoot) -- 104
	local openingCamera = Camera3D() -- 105
	local hubRoot = Node3D() -- 108
	hubRoot.visible = false -- 109
	Director.entry:addChild(hubRoot) -- 110
	local hubCamera = Camera3D() -- 111
	local hubLayer = Node() -- 113
	hubLayer.size = Size(viewW, viewH) -- 114
	hubLayer.anchor = Vec2(0.5, 0.5) -- 115
	hubLayer.position = Vec2(0, 0) -- 116
	Director.ui:addChild(hubLayer) -- 117
	local uiLayer = Node() -- 120
	uiLayer.size = Size(viewW, viewH) -- 121
	uiLayer.anchor = Vec2(0.5, 0.5) -- 122
	uiLayer.position = Vec2(0, 0) -- 123
	Director.ui:addChild(uiLayer) -- 124
	local levelNames = {} -- 127
	do -- 127
		local i = 0 -- 128
		while i < levelTotal do -- 128
			local def = getLevel(i) -- 129
			local title = def ~= nil and def.title or "" -- 130
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 131
			i = i + 1 -- 128
		end -- 128
	end -- 128
	local levelEntries = {} -- 133
	do -- 133
		local i = 0 -- 134
		while i < levelTotal do -- 134
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 134
			i = i + 1 -- 134
		end -- 134
	end -- 134
	local progress = loadProgress(levelTotal) -- 137
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 138
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 139
	local slots = {} -- 141
	do -- 141
		local i = 0 -- 142
		while i < levelTotal do -- 142
			slots[#slots + 1] = {built = false, runtime = nil} -- 142
			i = i + 1 -- 142
		end -- 142
	end -- 142
	local activeIndex = -1 -- 144
	local select = nil -- 145
	local solarHub = nil -- 146
	local resultPanel = nil -- 147
	local finalePanel = nil -- 149
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 151
	local resultIndex = -1 -- 156
	local function activeRuntime() -- 158
		if activeIndex < 0 then -- 158
			return nil -- 159
		end -- 159
		return slots[activeIndex + 1].runtime -- 160
	end -- 158
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 168
		do -- 168
			local i = 0 -- 169
			while i < levelTotal do -- 169
				do -- 169
					local slot = slots[i + 1] -- 170
					levelLayers[i + 1].visible = i == index -- 173
					if slot.runtime == nil then -- 173
						goto __continue16 -- 174
					end -- 174
					local active = i == index -- 175
					slot.runtime.world.visible = active -- 176
					slot.runtime.aim:setEnabled(active) -- 177
					if active then -- 177
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 179
					end -- 179
				end -- 179
				::__continue16:: -- 179
				i = i + 1 -- 169
			end -- 169
		end -- 169
	end -- 168
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 188
		local game -- 188
		local slot = slots[index + 1] -- 189
		if slot.built and slot.runtime ~= nil then -- 189
			return slot.runtime -- 190
		end -- 190
		local def = getLevel(index) -- 192
		if def == nil then -- 192
			return nil -- 193
		end -- 193
		local bodies = scaledPlanets(def) -- 195
		local level = { -- 196
			bodies = bodies, -- 197
			probeStart = def.probeStart, -- 198
			probeVel0 = def.probeVel0, -- 200
			goal = def.goal, -- 201
			escapeRadius = def.escapeRadius, -- 202
			physicsStep = levelRuntime(index).physicsStep, -- 203
			playback = levelRuntime(index).playback, -- 204
			aimClockRate = levelRuntime(index).aimClockRate, -- 205
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 206
			aimMin = levelRuntime(index).aimMin, -- 207
			maxSteps = def.maxSteps -- 208
		} -- 208
		local world = Node3D() -- 211
		Director.entry:addChild(world) -- 212
		world.visible = false -- 213
		local rtg = def.probeVariant == "rtg" -- 215
		local scene = buildScene({ -- 216
			root = world, -- 217
			bodies = bodies, -- 218
			visuals = def.visuals, -- 219
			probeStart = level.probeStart, -- 220
			probeScale = levelRuntime(index).probeVisualRadius, -- 226
			spherePath = "Assets/Model/Sphere.gltf", -- 227
			ringPath = "Assets/Model/Ring.gltf", -- 228
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 229
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 236
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 237
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 238
			probeBodyRadius = rtg and 0.871 or 1.084, -- 239
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 241
		}) -- 241
		if scene == nil then -- 241
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 244
			return nil -- 245
		end -- 245
		local rt = levelRuntime(index) -- 248
		local camera = Camera3D() -- 249
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 252
		local trajectory = createTrajectoryView( -- 253
			levelLayers[index + 1], -- 253
			trajectoryOptions() -- 253
		) -- 253
		local plan = createPlanView( -- 256
			levelLayers[index + 1], -- 256
			viewW, -- 256
			viewH, -- 256
			defaultPlanOptions(), -- 256
			def.planCenter -- 256
		) -- 256
		local planTolerance = arrivalRingRadius(def.goal) -- 257
		plan:fitTo(planFitRadius( -- 258
			bodies, -- 258
			level.probeStart, -- 258
			def.goal.planetIndex, -- 258
			planTolerance, -- 258
			def.planCenter -- 258
		)) -- 258
		local aim = createAimInput( -- 260
			levelLayers[index + 1], -- 260
			viewW, -- 260
			viewH, -- 260
			def.dvBudget, -- 260
			rt.aimMin, -- 260
			rt.playbackSpeeds -- 260
		) -- 260
		aim:setBurnInfo(0, def.dvBudget) -- 262
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 264
		aim:setDate(0, dateSpan) -- 265
		aim:onWarp(function(dir) -- 266
			game:stepTime(dir, dateSpan) -- 267
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 268
		end) -- 266
		game = createGame( -- 271
			level, -- 271
			{ -- 271
				scene = scene, -- 272
				camera = camera, -- 273
				rig = rig, -- 274
				trajectory = trajectory, -- 275
				plan = plan, -- 276
				visuals = def.visuals, -- 278
				setWorldVisible = function(____, on) -- 280
					world.visible = on -- 281
				end, -- 280
				aim = aim, -- 283
				viewW = viewW, -- 284
				viewH = viewH, -- 285
				fovYDeg = View.fieldOfView, -- 286
				aspect = View.aspectRatio, -- 287
				onPhase = function(____, p) -- 288
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 289
					if index == activeIndex then -- 289
						if p == "Finale" then -- 289
							if resultPanel ~= nil then -- 289
								resultPanel:hide() -- 297
							end -- 297
							if finalePanel ~= nil then -- 297
								finalePanel:show(finaleText.main, finaleText.sub) -- 298
							end -- 298
						else -- 298
							if p ~= "Result" and resultPanel ~= nil then -- 298
								resultPanel:hide() -- 300
							end -- 300
							if finalePanel ~= nil then -- 300
								finalePanel:hide() -- 301
							end -- 301
						end -- 301
					end -- 301
				end, -- 288
				onResult = function(____, r, telemetry) -- 305
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 306
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity}) -- 312
					progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 319
					saveProgress(progress) -- 320
					local currentTotal = getTotalRockets(progress, levelTotal) -- 321
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 323
					resultIndex = index -- 327
					local challengesList = {} -- 329
					if def.mission ~= nil then -- 329
						do -- 329
							local k = 0 -- 331
							while k < #def.mission.challenges do -- 331
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 332
								k = k + 1 -- 331
							end -- 331
						end -- 331
					end -- 331
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 336
					local detailParams = { -- 340
						result = r, -- 341
						levelName = titleWithSub, -- 342
						levelIndex = index, -- 343
						rocketsGot = evalInfo.rockets, -- 344
						challenges = challengesList, -- 345
						achieved = evalInfo.achieved, -- 346
						burnDv = telem.burnDv, -- 347
						dvBudget = def.dvBudget, -- 348
						flightTime = telem.flightTime, -- 349
						totalRockets = currentTotal, -- 350
						totalPossibleRockets = levelTotal * 3 -- 351
					} -- 351
					if resultPanel ~= nil then -- 351
						resultPanel:show(r, titleWithSub, detailParams) -- 355
					end -- 355
				end, -- 305
				onFinale = function(____, info) -- 359
					finaleText = { -- 360
						main = FinaleMainText, -- 360
						sub = finaleSubtitle(info.distance, info.time) -- 360
					} -- 360
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 361
				end, -- 359
				finale = index == levelTotal - 1 -- 366
			} -- 366
		) -- 366
		aim:onDrag(function(a) -- 372
			game:onAimDrag(a) -- 373
			aim:setBurnInfo( -- 375
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 375
				def.dvBudget -- 375
			) -- 375
		end) -- 372
		aim:onAimReady(function(a) -- 378
			game:onAimDrag(a) -- 379
			game:aimReady() -- 380
			print("[escape-velocity] aim ready -> Armed") -- 381
		end) -- 378
		aim:onLaunch(function() -- 383
			print("[escape-velocity] launch button tap") -- 384
			game:launchArmed() -- 385
		end) -- 383
		aim:onObserve(function(dx, dy) -- 388
			game:observeDrag(dx, dy) -- 389
		end) -- 388
		aim:onZoom(function(deltaDist) -- 391
			game:observeZoom(deltaDist) -- 392
		end) -- 391
		aim:onViewToggle(function() -- 395
			game:toggleViewMode() -- 396
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 397
		end) -- 395
		aim:onBrake(function(on) -- 400
			game:setBrakeMode(on) -- 401
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 402
		end) -- 400
		aim:setBrake(game:brakeMode()) -- 404
		aim:onPlayback(function(speed) -- 407
			game:setPlaybackSpeed(speed) -- 408
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 409
		end) -- 407
		aim:setPlayback(game:playbackSpeed()) -- 411
		local runtime = { -- 413
			index = index, -- 414
			name = levelNames[index + 1], -- 415
			world = world, -- 416
			camera = camera, -- 417
			game = game, -- 418
			aim = aim, -- 419
			trajectory = trajectory, -- 420
			plan = plan, -- 421
			levelHasTimeWindow = def.timeWindow ~= nil, -- 422
			dvBudget = def.dvBudget, -- 423
			dateSpan = dateSpan -- 424
		} -- 424
		slot.built = true -- 426
		slot.runtime = runtime -- 427
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 428
		return runtime -- 429
	end -- 188
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 433
		local runtime = ensureLevel(index) -- 434
		if runtime == nil then -- 434
			return -- 435
		end -- 435
		local wasActive = activeIndex == index -- 438
		if opening ~= nil then -- 438
			opening.hide() -- 440
		end -- 440
		if select ~= nil then -- 440
			select:hide() -- 441
		end -- 441
		if solarHub ~= nil then -- 441
			solarHub.hide() -- 442
		end -- 442
		activeIndex = index -- 443
		showOnlyLevel(index) -- 444
		if not wasActive then -- 444
			Director:pushCamera(runtime.camera) -- 445
		end -- 445
		runtime.game:startLevel() -- 446
		print("[escape-velocity] enter " .. runtime.name) -- 447
	end -- 433
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 451
		if resultIndex >= 0 and resultIndex < levelTotal then -- 451
			local rt = slots[resultIndex + 1].runtime -- 453
			if rt ~= nil then -- 453
				return rt -- 454
			end -- 454
		end -- 454
		return activeRuntime() -- 456
	end -- 451
	local function onRetryTap() -- 459
		local rt = resultRuntime() -- 461
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 462
		if resultPanel ~= nil then -- 462
			resultPanel:hide() -- 463
		end -- 463
		if rt ~= nil then -- 463
			rt.game:retry() -- 464
		end -- 464
	end -- 459
	local function ensureSolarHub() -- 467
		if solarHub ~= nil then -- 467
			return solarHub -- 468
		end -- 468
		solarHub = createSolarHub({ -- 469
			root = hubRoot, -- 470
			camera = hubCamera, -- 471
			layer = hubLayer, -- 472
			viewW = viewW, -- 473
			viewH = viewH, -- 474
			fovYDeg = View.fieldOfView, -- 475
			aspect = View.aspectRatio, -- 476
			spherePath = "Assets/Model/Sphere.gltf", -- 477
			onLaunch = function(____, levelIndex) -- 478
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 479
				if solarHub ~= nil then -- 479
					solarHub.hide() -- 480
				end -- 480
				enterLevel(levelIndex) -- 481
			end, -- 478
			onReplayIntro = function() -- 483
				if solarHub ~= nil then -- 483
					solarHub.hide() -- 484
				end -- 484
				startOpening() -- 485
				print("[escape-velocity] opening replay from solarHub") -- 486
			end -- 483
		}) -- 483
		return solarHub -- 489
	end -- 467
	local function onBackToSelectTap() -- 492
		local rt = resultRuntime() -- 493
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 494
		if rt == nil then -- 494
			return -- 495
		end -- 495
		local runtime = rt -- 496
		if not runtime.game:backToSelect() then -- 496
			return -- 498
		end -- 498
		runtime.world.visible = false -- 499
		runtime.aim:setEnabled(false) -- 500
		if resultPanel ~= nil then -- 500
			resultPanel:hide() -- 501
		end -- 501
		if finalePanel ~= nil then -- 501
			finalePanel:hide() -- 503
		end -- 503
		if select ~= nil then -- 503
			select:hide() -- 504
		end -- 504
		progress = loadProgress(levelTotal) -- 506
		local hub = ensureSolarHub() -- 507
		Director:pushCamera(hubCamera) -- 508
		hub.show(progress) -- 509
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 510
			getTotalRockets(progress, levelTotal), -- 510
			0 -- 510
		)) -- 510
	end -- 492
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 523
		finalePanel = createFinalePanel( -- 526
			uiLayer, -- 526
			viewW, -- 526
			viewH, -- 526
			{onBackToSelect = function() return onBackToSelectTap() end} -- 526
		) -- 526
		resultPanel = createResultPanel( -- 529
			uiLayer, -- 529
			viewW, -- 529
			viewH, -- 529
			{ -- 529
				onRetry = function() return onRetryTap() end, -- 530
				onBackToSelect = function() return onBackToSelectTap() end -- 531
			} -- 531
		) -- 531
		activeResultPanel = resultPanel -- 533
		local created = createLevelSelect( -- 534
			uiLayer, -- 534
			viewW, -- 534
			viewH, -- 534
			{ -- 534
				levels = levelEntries, -- 535
				onPick = function(____, index) -- 536
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 537
					if select ~= nil then -- 537
						select:hide() -- 538
					end -- 538
					enterLevel(index) -- 539
				end, -- 536
				onReplayIntro = function() -- 542
					if select ~= nil then -- 542
						select:hide() -- 543
					end -- 543
					startOpening() -- 544
					print("[escape-velocity] opening replay (user)") -- 545
				end -- 542
			} -- 542
		) -- 542
		select = created -- 548
		return created -- 549
	end -- 523
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 562
		local w = View.size.width -- 563
		local h = View.size.height -- 564
		if w == viewW and h == viewH then -- 564
			return -- 565
		end -- 565
		if opening ~= nil then -- 565
			opening.hide() -- 571
			opening = nil -- 572
		end -- 572
		if select ~= nil then -- 572
			select:hide() -- 574
		end -- 574
		if resultPanel ~= nil then -- 574
			resultPanel:hide() -- 575
		end -- 575
		if finalePanel ~= nil then -- 575
			finalePanel:hide() -- 576
		end -- 576
		do -- 576
			local i = 0 -- 577
			while i < levelTotal do -- 577
				local slot = slots[i + 1] -- 578
				if slot.runtime ~= nil then -- 578
					slot.runtime.world.visible = false -- 580
					slot.runtime.aim:setEnabled(false) -- 581
					slot.runtime.trajectory:clearPrediction() -- 584
					slot.runtime.trajectory:clearTrail() -- 585
					slot.runtime.trajectory:clearGoalRings() -- 587
					slot.runtime.plan:setVisible(false) -- 590
					slot.runtime.plan:clear() -- 591
				end -- 591
				slot.built = false -- 593
				slot.runtime = nil -- 594
				i = i + 1 -- 577
			end -- 577
		end -- 577
		viewW = w -- 598
		viewH = h -- 599
		uiLayer.size = Size(viewW, viewH) -- 600
		openingLayer.size = Size(viewW, viewH) -- 601
		hubLayer.size = Size(viewW, viewH) -- 602
		do -- 602
			local i = 0 -- 603
			while i < levelTotal do -- 603
				levelLayers[i + 1].size = Size(viewW, viewH) -- 603
				i = i + 1 -- 603
			end -- 603
		end -- 603
		if solarHub ~= nil then -- 603
			solarHub.relayout(viewW, viewH) -- 605
		end -- 605
		buildPanels() -- 609
		if activeIndex >= 0 then -- 609
			local keep = activeIndex -- 611
			activeIndex = -1 -- 612
			enterLevel(keep) -- 613
		else -- 613
			local hub = ensureSolarHub() -- 615
			Director:pushCamera(hubCamera) -- 616
			hub.show(progress) -- 617
		end -- 617
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 619
	end -- 562
	Director.entry:onAppChange(function(name) -- 623
		if name == "Size" then -- 623
			relayoutForViewport() -- 624
		end -- 624
	end) -- 623
	local introSeen = loadIntroSeen() -- 632
	local forceIntro = false -- 633
	opening = nil -- 634
	startOpening = function() -- 636
		if opening == nil then -- 636
			opening = createOpening({ -- 638
				root = openingRoot, -- 639
				camera = openingCamera, -- 640
				layer = openingLayer, -- 641
				viewW = viewW, -- 642
				viewH = viewH, -- 643
				fovYDeg = View.fieldOfView, -- 644
				aspect = View.aspectRatio, -- 645
				spherePath = "Assets/Model/Sphere.gltf", -- 646
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 647
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 648
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 649
				onFinish = function() -- 650
					introHold = -1 -- 651
					if not introSeen then -- 651
						saveIntroSeen() -- 653
						introSeen = true -- 654
						print("[escape-velocity] intro seen -> saved") -- 655
					end -- 655
					if opening ~= nil then -- 655
						opening.hide() -- 658
					end -- 658
					if select ~= nil then -- 658
						select:hide() -- 659
					end -- 659
					local hub = ensureSolarHub() -- 660
					Director:pushCamera(hubCamera) -- 661
					hub.show(progress) -- 662
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 663
						opening.frameIndex(), -- 663
						0 -- 663
					) or "?")) -- 663
				end -- 650
			}) -- 650
		end -- 650
		if opening == nil then -- 650
			return -- 667
		end -- 667
		Director:pushCamera(openingCamera) -- 668
		opening.start() -- 669
		print("[escape-velocity] opening start (first launch)") -- 670
	end -- 636
	local startupPanel = buildPanels() -- 673
	local enterReq = Path( -- 685
		Path(".", ".agent", "test-results"), -- 685
		"enter-request.txt" -- 685
	) -- 685
	local autoLaunchAt = -1 -- 686
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 688
	local autoFrame = 0 -- 689
	local autoVX = 0 -- 690
	local autoVY = 0 -- 691
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 699
	local autoBackAt = -1 -- 701
	local autoReenterAt = -1 -- 702
	local autoEntered = false -- 703
	introHold = -1 -- 705
	if Content:exist(enterReq) then -- 705
		local spec = Content:load(enterReq) -- 707
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 708
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 709
		if head == "intro" then -- 709
			forceIntro = true -- 711
			if at >= 0 then -- 711
				local rest = __TS__StringSubstring(spec, at + 1) -- 713
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 714
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 714
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 716
					if v ~= nil and v >= 0 then -- 716
						introHold = v -- 718
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 719
					end -- 719
				end -- 719
			end -- 719
		end -- 719
		local n = tonumber(head) -- 724
		if n ~= nil and n >= 1 and n <= levelTotal then -- 724
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 726
			enterLevel(n - 1) -- 727
			autoEntered = true -- 728
			if at >= 0 then -- 728
				local rest = __TS__StringSubstring(spec, at + 1) -- 730
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 730
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 735
					if f ~= nil and f >= 0 then -- 735
						autoArmAt = f -- 737
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 738
					end -- 738
				else -- 738
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 741
					local c2 = (string.find( -- 742
						rest, -- 742
						":", -- 742
						math.max(c1 + 1 + 1, 1), -- 742
						true -- 742
					) or 0) - 1 -- 742
					if c1 > 0 and c2 > c1 then -- 742
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 744
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 745
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 748
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 749
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 750
						local vy = tonumber(vyText) -- 751
						local ____temp_0 -- 752
						if c3 > 0 then -- 752
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 752
						else -- 752
							____temp_0 = nil -- 752
						end -- 752
						local steps = ____temp_0 -- 752
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 752
							autoLaunchAt = frames -- 754
							autoVX = vx -- 755
							autoVY = vy -- 756
							if steps ~= nil and steps > 0 then -- 756
								autoWarpSteps = math.floor(steps) -- 758
							end -- 758
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 760
						end -- 760
					end -- 760
				end -- 760
			end -- 760
		end -- 760
	end -- 760
	if autoEntered then -- 760
		print("[escape-velocity] opening skipped (auto enter)") -- 773
	elseif forceIntro or not introSeen then -- 773
		startOpening() -- 775
	else -- 775
		local hub = ensureSolarHub() -- 777
		Director:pushCamera(hubCamera) -- 778
		hub.show(progress) -- 779
		print("[escape-velocity] entered solarHub (already seen)") -- 780
	end -- 780
	threadLoop(function() -- 785
		advanceUiClock(App.deltaTime) -- 789
		if solarHub ~= nil and solarHub.visible() then -- 789
			solarHub.step(App.deltaTime) -- 793
		end -- 793
		if opening ~= nil and opening.running() then -- 793
			if introHold < 0 or opening.frameIndex() < introHold then -- 793
				opening.step() -- 799
			end -- 799
			if App.deltaTime > 0.05 then -- 799
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 803
					opening.frameIndex(), -- 803
					0 -- 803
				)) -- 803
			end -- 803
		end -- 803
		local runtime = activeRuntime() -- 807
		if runtime ~= nil then -- 807
			runtime.game:update(App.deltaTime) -- 809
			runtime.aim:setBurnInfo( -- 811
				runtime.game:burnNow(), -- 811
				runtime.dvBudget -- 811
			) -- 811
			if runtime.levelHasTimeWindow then -- 811
				runtime.aim:setDate( -- 814
					runtime.game:dateNow(), -- 814
					runtime.dateSpan -- 814
				) -- 814
			end -- 814
			local phaseNow = runtime.game:phase() -- 818
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 819
			runtime.aim:update(App.deltaTime) -- 820
			runtime.aim:setArmed(runtime.game:armed()) -- 822
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 824
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 826
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 827
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 827
				autoFrame = autoFrame + 1 -- 830
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 830
					autoArmAt = -1 -- 833
					print("[escape-velocity] auto arm (enter-request)") -- 834
					runtime.game:aimReady() -- 835
				end -- 835
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 835
					autoLaunchAt = -1 -- 838
					print("[escape-velocity] auto launch") -- 839
					if autoWarpSteps > 0 then -- 839
						do -- 839
							local s = 0 -- 843
							while s < autoWarpSteps do -- 843
								runtime.game:stepTime(1, runtime.dateSpan) -- 843
								s = s + 1 -- 843
							end -- 843
						end -- 843
						autoWarpSteps = 0 -- 844
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 845
							runtime.game:dateNow(), -- 845
							0 -- 845
						)) .. ")") -- 845
					end -- 845
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 847
					runtime.game:launch({x = autoVX, y = autoVY}) -- 848
					autoBackAt = autoFrame + 320 -- 849
					autoReenterAt = autoFrame + 380 -- 850
				end -- 850
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 850
					autoBackAt = -1 -- 854
					if runtime.game:backToSelect() then -- 854
						print("[escape-velocity] auto back to select") -- 855
					end -- 855
				end -- 855
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 855
					autoReenterAt = -1 -- 858
					print("[escape-velocity] auto re-enter") -- 859
					enterLevel(0) -- 860
				end -- 860
			end -- 860
		end -- 860
		return false -- 865
	end) -- 785
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 869
	debugTriggerResultFn = function(levelIndex, outcome) -- 871
		if outcome == nil then -- 871
			outcome = "success" -- 871
		end -- 871
		if solarHub ~= nil then -- 871
			solarHub.hide() -- 872
		end -- 872
		if opening ~= nil then -- 872
			opening.hide() -- 873
		end -- 873
		local def = getLevel(levelIndex) -- 874
		if def == nil or resultPanel == nil then -- 874
			return -- 875
		end -- 875
		local burn = def.dvBudget * 0.65 -- 876
		local challengesList = {} -- 877
		if def.mission ~= nil then -- 877
			do -- 877
				local k = 0 -- 879
				while k < #def.mission.challenges do -- 879
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 880
					k = k + 1 -- 879
				end -- 879
			end -- 879
		end -- 879
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 883
		resultPanel:show(outcome, titleWithSub, { -- 887
			result = outcome, -- 888
			levelName = titleWithSub, -- 889
			levelIndex = levelIndex, -- 890
			rocketsGot = outcome == "success" and 3 or 0, -- 891
			challenges = challengesList, -- 892
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 893
			burnDv = burn, -- 894
			dvBudget = def.dvBudget, -- 895
			flightTime = 12.8, -- 896
			totalRockets = outcome == "success" and 16 or 13, -- 897
			totalPossibleRockets = 18 -- 898
		}) -- 898
	end -- 871
end -- 871
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 904
	return activeResultPanel -- 905
end -- 904
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 909
	if outcome == nil then -- 909
		outcome = "success" -- 909
	end -- 909
	if debugTriggerResultFn ~= nil then -- 909
		debugTriggerResultFn(levelIndex, outcome) -- 911
	end -- 911
end -- 909
return ____exports -- 909
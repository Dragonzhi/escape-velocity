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
			aimClockRate = levelRuntime(index).aimClockRate, -- 186
			maxSteps = def.maxSteps -- 187
		} -- 187
		local world = Node3D() -- 190
		Director.entry:addChild(world) -- 191
		world.visible = false -- 192
		local rtg = def.probeVariant == "rtg" -- 194
		local scene = buildScene({ -- 195
			root = world, -- 196
			bodies = bodies, -- 197
			visuals = def.visuals, -- 198
			probeStart = level.probeStart, -- 199
			probeScale = 2.2, -- 203
			spherePath = "Assets/Model/Sphere.gltf", -- 204
			ringPath = "Assets/Model/Ring.gltf", -- 205
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 206
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 213
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 214
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 215
			probeBodyRadius = rtg and 0.871 or 1.084, -- 216
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 218
		}) -- 218
		if scene == nil then -- 218
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 221
			return nil -- 222
		end -- 222
		local rt = levelRuntime(index) -- 225
		local camera = Camera3D() -- 226
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio, rt.cameraMin, rt.cameraMax)) -- 229
		local trajectory = createTrajectoryView( -- 230
			levelLayers[index + 1], -- 230
			trajectoryOptions() -- 230
		) -- 230
		local plan = createPlanView( -- 233
			levelLayers[index + 1], -- 233
			viewW, -- 233
			viewH, -- 233
			defaultPlanOptions(), -- 233
			def.planCenter -- 233
		) -- 233
		local planTolerance = arrivalRingRadius(def.goal) -- 234
		plan:fitTo(planFitRadius( -- 235
			bodies, -- 235
			level.probeStart, -- 235
			def.goal.planetIndex, -- 235
			planTolerance, -- 235
			def.planCenter -- 235
		)) -- 235
		local aim = createAimInput( -- 237
			levelLayers[index + 1], -- 237
			viewW, -- 237
			viewH, -- 237
			def.dvBudget, -- 237
			rt.aimMin, -- 237
			rt.playbackSpeeds -- 237
		) -- 237
		aim:setBurnInfo(0, def.dvBudget) -- 239
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 241
		aim:setDate(0, dateSpan) -- 242
		aim:onWarp(function(dir) -- 243
			game:stepTime(dir, dateSpan) -- 244
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 245
		end) -- 243
		game = createGame( -- 248
			level, -- 248
			{ -- 248
				scene = scene, -- 249
				camera = camera, -- 250
				rig = rig, -- 251
				trajectory = trajectory, -- 252
				plan = plan, -- 253
				visuals = def.visuals, -- 255
				setWorldVisible = function(____, on) -- 257
					world.visible = on -- 258
				end, -- 257
				aim = aim, -- 260
				viewW = viewW, -- 261
				viewH = viewH, -- 262
				fovYDeg = View.fieldOfView, -- 263
				aspect = View.aspectRatio, -- 264
				onPhase = function(____, p) -- 265
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 266
					if index == activeIndex then -- 266
						if p == "Finale" then -- 266
							if resultPanel ~= nil then -- 266
								resultPanel:hide() -- 274
							end -- 274
							if finalePanel ~= nil then -- 274
								finalePanel:show(finaleText.main, finaleText.sub) -- 275
							end -- 275
						else -- 275
							if p ~= "Result" and resultPanel ~= nil then -- 275
								resultPanel:hide() -- 277
							end -- 277
							if finalePanel ~= nil then -- 277
								finalePanel:hide() -- 278
							end -- 278
						end -- 278
					end -- 278
				end, -- 265
				onResult = function(____, r) -- 282
					if r == "success" then -- 282
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 285
						if next ~= progress.unlocked then -- 285
							progress = {unlocked = next} -- 287
							saveProgress(progress) -- 288
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 289
						end -- 289
					end -- 289
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 292
					resultIndex = index -- 293
					if resultPanel ~= nil then -- 293
						resultPanel:show(r, levelNames[index + 1]) -- 294
					end -- 294
				end, -- 282
				onFinale = function(____, info) -- 297
					finaleText = { -- 298
						main = FinaleMainText, -- 298
						sub = finaleSubtitle(info.distance, info.time) -- 298
					} -- 298
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 299
				end, -- 297
				finale = index == levelTotal - 1 -- 304
			} -- 304
		) -- 304
		aim:onDrag(function(a) -- 310
			game:onAimDrag(a) -- 311
			aim:setBurnInfo( -- 313
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 313
				def.dvBudget -- 313
			) -- 313
		end) -- 310
		aim:onAimReady(function(a) -- 316
			game:onAimDrag(a) -- 317
			game:aimReady() -- 318
			print("[escape-velocity] aim ready -> Armed") -- 319
		end) -- 316
		aim:onLaunch(function() -- 321
			print("[escape-velocity] launch button tap") -- 322
			game:launchArmed() -- 323
		end) -- 321
		aim:onObserve(function(dx, dy) -- 326
			game:observeDrag(dx, dy) -- 327
		end) -- 326
		aim:onZoom(function(deltaDist) -- 329
			game:observeZoom(deltaDist) -- 330
		end) -- 329
		aim:onViewToggle(function() -- 333
			game:toggleViewMode() -- 334
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 335
		end) -- 333
		aim:onBrake(function(on) -- 338
			game:setBrakeMode(on) -- 339
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 340
		end) -- 338
		aim:setBrake(game:brakeMode()) -- 342
		aim:onPlayback(function(speed) -- 345
			game:setPlaybackSpeed(speed) -- 346
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 347
		end) -- 345
		aim:setPlayback(game:playbackSpeed()) -- 349
		local runtime = { -- 351
			index = index, -- 352
			name = levelNames[index + 1], -- 353
			world = world, -- 354
			camera = camera, -- 355
			game = game, -- 356
			aim = aim, -- 357
			trajectory = trajectory, -- 358
			plan = plan, -- 359
			levelHasTimeWindow = def.timeWindow ~= nil, -- 360
			dateSpan = dateSpan -- 361
		} -- 361
		slot.built = true -- 363
		slot.runtime = runtime -- 364
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 365
		return runtime -- 366
	end -- 169
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 370
		local runtime = ensureLevel(index) -- 371
		if runtime == nil then -- 371
			return -- 372
		end -- 372
		local wasActive = activeIndex == index -- 375
		if opening ~= nil then -- 375
			opening.hide() -- 377
		end -- 377
		if select ~= nil then -- 377
			select:hide() -- 378
		end -- 378
		activeIndex = index -- 379
		showOnlyLevel(index) -- 380
		if not wasActive then -- 380
			Director:pushCamera(runtime.camera) -- 381
		end -- 381
		runtime.game:startLevel() -- 382
		print("[escape-velocity] enter " .. runtime.name) -- 383
	end -- 370
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 387
		if resultIndex >= 0 and resultIndex < levelTotal then -- 387
			local rt = slots[resultIndex + 1].runtime -- 389
			if rt ~= nil then -- 389
				return rt -- 390
			end -- 390
		end -- 390
		return activeRuntime() -- 392
	end -- 387
	local function onRetryTap() -- 395
		local rt = resultRuntime() -- 397
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 398
		if resultPanel ~= nil then -- 398
			resultPanel:hide() -- 399
		end -- 399
		if rt ~= nil then -- 399
			rt.game:retry() -- 400
		end -- 400
	end -- 395
	local function onBackToSelectTap() -- 403
		local rt = resultRuntime() -- 404
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 405
		if rt == nil then -- 405
			return -- 406
		end -- 406
		local runtime = rt -- 407
		if not runtime.game:backToSelect() then -- 407
			return -- 409
		end -- 409
		runtime.world.visible = false -- 410
		runtime.aim:setEnabled(false) -- 411
		if resultPanel ~= nil then -- 411
			resultPanel:hide() -- 412
		end -- 412
		if finalePanel ~= nil then -- 412
			finalePanel:hide() -- 414
		end -- 414
		progress = loadProgress(levelTotal) -- 416
		if select ~= nil then -- 416
			select:show(progress.unlocked) -- 417
		end -- 417
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 418
	end -- 403
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 431
		finalePanel = createFinalePanel( -- 434
			uiLayer, -- 434
			viewW, -- 434
			viewH, -- 434
			{onBackToSelect = function() return onBackToSelectTap() end} -- 434
		) -- 434
		resultPanel = createResultPanel( -- 437
			uiLayer, -- 437
			viewW, -- 437
			viewH, -- 437
			{ -- 437
				onRetry = function() return onRetryTap() end, -- 438
				onBackToSelect = function() return onBackToSelectTap() end -- 439
			} -- 439
		) -- 439
		local created = createLevelSelect( -- 441
			uiLayer, -- 441
			viewW, -- 441
			viewH, -- 441
			{ -- 441
				levels = levelEntries, -- 442
				onPick = function(____, index) -- 443
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 444
					if select ~= nil then -- 444
						select:hide() -- 445
					end -- 445
					enterLevel(index) -- 446
				end, -- 443
				onReplayIntro = function() -- 449
					if select ~= nil then -- 449
						select:hide() -- 450
					end -- 450
					startOpening() -- 451
					print("[escape-velocity] opening replay (user)") -- 452
				end -- 449
			} -- 449
		) -- 449
		select = created -- 455
		return created -- 456
	end -- 431
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 469
		local w = View.size.width -- 470
		local h = View.size.height -- 471
		if w == viewW and h == viewH then -- 471
			return -- 472
		end -- 472
		if opening ~= nil then -- 472
			opening.hide() -- 478
			opening = nil -- 479
		end -- 479
		if select ~= nil then -- 479
			select:hide() -- 481
		end -- 481
		if resultPanel ~= nil then -- 481
			resultPanel:hide() -- 482
		end -- 482
		if finalePanel ~= nil then -- 482
			finalePanel:hide() -- 483
		end -- 483
		do -- 483
			local i = 0 -- 484
			while i < levelTotal do -- 484
				local slot = slots[i + 1] -- 485
				if slot.runtime ~= nil then -- 485
					slot.runtime.world.visible = false -- 487
					slot.runtime.aim:setEnabled(false) -- 488
					slot.runtime.trajectory:clearPrediction() -- 491
					slot.runtime.trajectory:clearTrail() -- 492
					slot.runtime.trajectory:clearGoalRings() -- 494
					slot.runtime.plan:setVisible(false) -- 497
					slot.runtime.plan:clear() -- 498
				end -- 498
				slot.built = false -- 500
				slot.runtime = nil -- 501
				i = i + 1 -- 484
			end -- 484
		end -- 484
		viewW = w -- 505
		viewH = h -- 506
		uiLayer.size = Size(viewW, viewH) -- 507
		openingLayer.size = Size(viewW, viewH) -- 508
		do -- 508
			local i = 0 -- 509
			while i < levelTotal do -- 509
				levelLayers[i + 1].size = Size(viewW, viewH) -- 509
				i = i + 1 -- 509
			end -- 509
		end -- 509
		local panel = buildPanels() -- 512
		if activeIndex >= 0 then -- 512
			local keep = activeIndex -- 514
			activeIndex = -1 -- 515
			enterLevel(keep) -- 516
		else -- 516
			panel:show(progress.unlocked) -- 518
		end -- 518
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 520
	end -- 469
	Director.entry:onAppChange(function(name) -- 524
		if name == "Size" then -- 524
			relayoutForViewport() -- 525
		end -- 525
	end) -- 524
	local introSeen = loadIntroSeen() -- 533
	local forceIntro = false -- 534
	opening = nil -- 535
	startOpening = function() -- 537
		if opening == nil then -- 537
			opening = createOpening({ -- 539
				root = openingRoot, -- 540
				camera = openingCamera, -- 541
				layer = openingLayer, -- 542
				viewW = viewW, -- 543
				viewH = viewH, -- 544
				fovYDeg = View.fieldOfView, -- 545
				aspect = View.aspectRatio, -- 546
				spherePath = "Assets/Model/Sphere.gltf", -- 547
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 548
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 549
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 550
				onFinish = function() -- 551
					introHold = -1 -- 552
					if not introSeen then -- 552
						saveIntroSeen() -- 554
						introSeen = true -- 555
						print("[escape-velocity] intro seen -> saved") -- 556
					end -- 556
					if select ~= nil then -- 556
						select:show(progress.unlocked) -- 559
					end -- 559
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 560
						opening.frameIndex(), -- 560
						0 -- 560
					) or "?")) -- 560
				end -- 551
			}) -- 551
		end -- 551
		if opening == nil then -- 551
			return -- 564
		end -- 564
		Director:pushCamera(openingCamera) -- 565
		opening.start() -- 566
		print("[escape-velocity] opening start (first launch)") -- 567
	end -- 537
	local startupPanel = buildPanels() -- 570
	local enterReq = Path( -- 582
		Path(".", ".agent", "test-results"), -- 582
		"enter-request.txt" -- 582
	) -- 582
	local autoLaunchAt = -1 -- 583
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 585
	local autoFrame = 0 -- 586
	local autoVX = 0 -- 587
	local autoVY = 0 -- 588
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 596
	local autoBackAt = -1 -- 598
	local autoReenterAt = -1 -- 599
	local autoEntered = false -- 600
	introHold = -1 -- 602
	if Content:exist(enterReq) then -- 602
		local spec = Content:load(enterReq) -- 604
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 605
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 606
		if head == "intro" then -- 606
			forceIntro = true -- 608
			if at >= 0 then -- 608
				local rest = __TS__StringSubstring(spec, at + 1) -- 610
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 611
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 611
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 613
					if v ~= nil and v >= 0 then -- 613
						introHold = v -- 615
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 616
					end -- 616
				end -- 616
			end -- 616
		end -- 616
		local n = tonumber(head) -- 621
		if n ~= nil and n >= 1 and n <= levelTotal then -- 621
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 623
			enterLevel(n - 1) -- 624
			autoEntered = true -- 625
			if at >= 0 then -- 625
				local rest = __TS__StringSubstring(spec, at + 1) -- 627
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 627
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 632
					if f ~= nil and f >= 0 then -- 632
						autoArmAt = f -- 634
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 635
					end -- 635
				else -- 635
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 638
					local c2 = (string.find( -- 639
						rest, -- 639
						":", -- 639
						math.max(c1 + 1 + 1, 1), -- 639
						true -- 639
					) or 0) - 1 -- 639
					if c1 > 0 and c2 > c1 then -- 639
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 641
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 642
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 645
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 646
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 647
						local vy = tonumber(vyText) -- 648
						local ____temp_0 -- 649
						if c3 > 0 then -- 649
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 649
						else -- 649
							____temp_0 = nil -- 649
						end -- 649
						local steps = ____temp_0 -- 649
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 649
							autoLaunchAt = frames -- 651
							autoVX = vx -- 652
							autoVY = vy -- 653
							if steps ~= nil and steps > 0 then -- 653
								autoWarpSteps = math.floor(steps) -- 655
							end -- 655
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 657
						end -- 657
					end -- 657
				end -- 657
			end -- 657
		end -- 657
	end -- 657
	if autoEntered then -- 657
		print("[escape-velocity] opening skipped (auto enter)") -- 670
	elseif forceIntro or not introSeen then -- 670
		startOpening() -- 672
	else -- 672
		startupPanel:show(progress.unlocked) -- 674
		print("[escape-velocity] opening skipped (already seen)") -- 675
	end -- 675
	threadLoop(function() -- 680
		advanceUiClock(App.deltaTime) -- 684
		if opening ~= nil and opening.running() then -- 684
			if introHold < 0 or opening.frameIndex() < introHold then -- 684
				opening.step() -- 688
			end -- 688
			if App.deltaTime > 0.05 then -- 688
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 692
					opening.frameIndex(), -- 692
					0 -- 692
				)) -- 692
			end -- 692
		end -- 692
		local runtime = activeRuntime() -- 696
		if runtime ~= nil then -- 696
			runtime.game:update(App.deltaTime) -- 698
			if runtime.levelHasTimeWindow then -- 698
				runtime.aim:setDate( -- 701
					runtime.game:dateNow(), -- 701
					runtime.dateSpan -- 701
				) -- 701
			end -- 701
			local phaseNow = runtime.game:phase() -- 705
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 706
			runtime.aim:update(App.deltaTime) -- 707
			runtime.aim:setArmed(runtime.game:armed()) -- 709
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 711
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 713
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 714
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 714
				autoFrame = autoFrame + 1 -- 717
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 717
					autoArmAt = -1 -- 720
					print("[escape-velocity] auto arm (enter-request)") -- 721
					runtime.game:aimReady() -- 722
				end -- 722
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 722
					autoLaunchAt = -1 -- 725
					print("[escape-velocity] auto launch") -- 726
					if autoWarpSteps > 0 then -- 726
						do -- 726
							local s = 0 -- 730
							while s < autoWarpSteps do -- 730
								runtime.game:stepTime(1, runtime.dateSpan) -- 730
								s = s + 1 -- 730
							end -- 730
						end -- 730
						autoWarpSteps = 0 -- 731
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 732
							runtime.game:dateNow(), -- 732
							0 -- 732
						)) .. ")") -- 732
					end -- 732
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 734
					runtime.game:launch({x = autoVX, y = autoVY}) -- 735
					autoBackAt = autoFrame + 320 -- 736
					autoReenterAt = autoFrame + 380 -- 737
				end -- 737
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 737
					autoBackAt = -1 -- 741
					if runtime.game:backToSelect() then -- 741
						print("[escape-velocity] auto back to select") -- 742
					end -- 742
				end -- 742
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 742
					autoReenterAt = -1 -- 745
					print("[escape-velocity] auto re-enter") -- 746
					enterLevel(0) -- 747
				end -- 747
			end -- 747
		end -- 747
		return false -- 752
	end) -- 680
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 756
end -- 756
return ____exports -- 756
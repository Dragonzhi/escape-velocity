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
local goalWaypoints = ____LevelData.goalWaypoints -- 22
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
local ____Opening = require("game.Opening") -- 30
local createOpening = ____Opening.createOpening -- 30
local loadIntroSeen = ____Opening.loadIntroSeen -- 30
local saveIntroSeen = ____Opening.saveIntroSeen -- 30
local levelTotal = levelCount() -- 58
if levelTotal <= 0 then -- 58
	print("[escape-velocity] FATAL: no level data") -- 61
else -- 61
	local opening, startOpening, introHold -- 61
	local viewW = View.size.width -- 63
	local viewH = View.size.height -- 64
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 67
	local levelLayers = {} -- 73
	do -- 73
		local i = 0 -- 74
		while i < levelTotal do -- 74
			local layer = Node() -- 75
			layer.size = Size(viewW, viewH) -- 76
			layer.anchor = Vec2(0.5, 0.5) -- 77
			layer.position = Vec2(0, 0) -- 78
			Director.ui:addChild(layer) -- 79
			levelLayers[#levelLayers + 1] = layer -- 80
			i = i + 1 -- 74
		end -- 74
	end -- 74
	local openingLayer = Node() -- 85
	openingLayer.size = Size(viewW, viewH) -- 86
	openingLayer.anchor = Vec2(0.5, 0.5) -- 87
	openingLayer.position = Vec2(0, 0) -- 88
	Director.ui:addChild(openingLayer) -- 89
	local openingRoot = Node3D() -- 92
	openingRoot.visible = false -- 93
	Director.entry:addChild(openingRoot) -- 94
	local openingCamera = Camera3D() -- 95
	local uiLayer = Node() -- 98
	uiLayer.size = Size(viewW, viewH) -- 99
	uiLayer.anchor = Vec2(0.5, 0.5) -- 100
	uiLayer.position = Vec2(0, 0) -- 101
	Director.ui:addChild(uiLayer) -- 102
	local levelNames = {} -- 105
	do -- 105
		local i = 0 -- 106
		while i < levelTotal do -- 106
			local def = getLevel(i) -- 107
			local title = def ~= nil and def.title or "" -- 108
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 109
			i = i + 1 -- 106
		end -- 106
	end -- 106
	local levelEntries = {} -- 111
	do -- 111
		local i = 0 -- 112
		while i < levelTotal do -- 112
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 112
			i = i + 1 -- 112
		end -- 112
	end -- 112
	local progress = loadProgress(levelTotal) -- 115
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 116
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 117
	local slots = {} -- 119
	do -- 119
		local i = 0 -- 120
		while i < levelTotal do -- 120
			slots[#slots + 1] = {built = false, runtime = nil} -- 120
			i = i + 1 -- 120
		end -- 120
	end -- 120
	local activeIndex = -1 -- 122
	local select = nil -- 123
	local resultPanel = nil -- 124
	local finalePanel = nil -- 126
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 128
	local resultIndex = -1 -- 133
	local function activeRuntime() -- 135
		if activeIndex < 0 then -- 135
			return nil -- 136
		end -- 136
		return slots[activeIndex + 1].runtime -- 137
	end -- 135
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 145
		do -- 145
			local i = 0 -- 146
			while i < levelTotal do -- 146
				do -- 146
					local slot = slots[i + 1] -- 147
					levelLayers[i + 1].visible = i == index -- 150
					if slot.runtime == nil then -- 150
						goto __continue16 -- 151
					end -- 151
					local active = i == index -- 152
					slot.runtime.world.visible = active -- 153
					slot.runtime.aim:setEnabled(active) -- 154
					if active then -- 154
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 156
					end -- 156
				end -- 156
				::__continue16:: -- 156
				i = i + 1 -- 146
			end -- 146
		end -- 146
	end -- 145
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 165
		local game -- 165
		local slot = slots[index + 1] -- 166
		if slot.built and slot.runtime ~= nil then -- 166
			return slot.runtime -- 167
		end -- 167
		local def = getLevel(index) -- 169
		if def == nil then -- 169
			return nil -- 170
		end -- 170
		local bodies = scaledPlanets(def) -- 172
		local level = { -- 173
			bodies = bodies, -- 174
			probeStart = def.probeStart, -- 175
			probeVel0 = def.probeVel0, -- 177
			goal = def.goal, -- 178
			escapeRadius = def.escapeRadius, -- 179
			maxSteps = def.maxSteps -- 180
		} -- 180
		local world = Node3D() -- 183
		Director.entry:addChild(world) -- 184
		world.visible = false -- 185
		local rtg = def.probeVariant == "rtg" -- 187
		local scene = buildScene({ -- 188
			root = world, -- 189
			bodies = bodies, -- 190
			visuals = def.visuals, -- 191
			probeStart = level.probeStart, -- 192
			probeScale = 2.2, -- 196
			spherePath = "Assets/Model/Sphere.gltf", -- 197
			ringPath = "Assets/Model/Ring.gltf", -- 198
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 199
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 206
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 207
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 208
			probeBodyRadius = rtg and 0.871 or 1.084, -- 209
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 211
		}) -- 211
		if scene == nil then -- 211
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 214
			return nil -- 215
		end -- 215
		local camera = Camera3D() -- 218
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 221
		local trajectory = createTrajectoryView( -- 222
			levelLayers[index + 1], -- 222
			trajectoryOptions() -- 222
		) -- 222
		local plan = createPlanView( -- 225
			levelLayers[index + 1], -- 225
			viewW, -- 225
			viewH, -- 225
			defaultPlanOptions() -- 225
		) -- 225
		local planTolerance = def.goal.tolerance -- 226
		local planChain = goalWaypoints(def.goal) -- 227
		do -- 227
			local w = 0 -- 228
			while w < #planChain do -- 228
				if planChain[w + 1].tolerance > planTolerance then -- 228
					planTolerance = planChain[w + 1].tolerance -- 229
				end -- 229
				w = w + 1 -- 228
			end -- 228
		end -- 228
		plan:fitTo(planFitRadius(bodies, level.probeStart, def.goal.planetIndex, planTolerance)) -- 231
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 233
		aim:setBurnInfo(0, def.dvBudget) -- 235
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 237
		aim:setDate(0, dateSpan) -- 238
		aim:onWarp(function(dir) -- 239
			game:stepTime(dir, dateSpan) -- 240
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 241
		end) -- 239
		game = createGame( -- 244
			level, -- 244
			{ -- 244
				scene = scene, -- 245
				camera = camera, -- 246
				rig = rig, -- 247
				trajectory = trajectory, -- 248
				plan = plan, -- 249
				visuals = def.visuals, -- 251
				setWorldVisible = function(____, on) -- 253
					world.visible = on -- 254
				end, -- 253
				aim = aim, -- 256
				viewW = viewW, -- 257
				viewH = viewH, -- 258
				fovYDeg = View.fieldOfView, -- 259
				aspect = View.aspectRatio, -- 260
				onPhase = function(____, p) -- 261
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 262
					if index == activeIndex then -- 262
						if p == "Finale" then -- 262
							if resultPanel ~= nil then -- 262
								resultPanel:hide() -- 270
							end -- 270
							if finalePanel ~= nil then -- 270
								finalePanel:show(finaleText.main, finaleText.sub) -- 271
							end -- 271
						else -- 271
							if p ~= "Result" and resultPanel ~= nil then -- 271
								resultPanel:hide() -- 273
							end -- 273
							if finalePanel ~= nil then -- 273
								finalePanel:hide() -- 274
							end -- 274
						end -- 274
					end -- 274
				end, -- 261
				onResult = function(____, r) -- 278
					if r == "success" then -- 278
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 281
						if next ~= progress.unlocked then -- 281
							progress = {unlocked = next} -- 283
							saveProgress(progress) -- 284
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 285
						end -- 285
					end -- 285
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 288
					resultIndex = index -- 289
					if resultPanel ~= nil then -- 289
						resultPanel:show(r, levelNames[index + 1]) -- 290
					end -- 290
				end, -- 278
				onFinale = function(____, info) -- 293
					finaleText = { -- 294
						main = FinaleMainText, -- 294
						sub = finaleSubtitle(info.distance, info.time) -- 294
					} -- 294
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 295
				end, -- 293
				finale = index == levelTotal - 1 -- 300
			} -- 300
		) -- 300
		aim:onDrag(function(a) -- 306
			game:onAimDrag(a) -- 307
			aim:setBurnInfo( -- 309
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 309
				def.dvBudget -- 309
			) -- 309
		end) -- 306
		aim:onAimReady(function(a) -- 312
			game:onAimDrag(a) -- 313
			game:aimReady() -- 314
			print("[escape-velocity] aim ready -> Armed") -- 315
		end) -- 312
		aim:onLaunch(function() -- 317
			print("[escape-velocity] launch button tap") -- 318
			game:launchArmed() -- 319
		end) -- 317
		aim:onObserve(function(dx, dy) -- 322
			game:observeDrag(dx, dy) -- 323
		end) -- 322
		aim:onZoom(function(deltaDist) -- 325
			game:observeZoom(deltaDist) -- 326
		end) -- 325
		aim:onViewToggle(function() -- 329
			game:toggleViewMode() -- 330
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 331
		end) -- 329
		aim:onBrake(function(on) -- 334
			game:setBrakeMode(on) -- 335
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 336
		end) -- 334
		aim:setBrake(game:brakeMode()) -- 338
		aim:onPlayback(function(speed) -- 341
			game:setPlaybackSpeed(speed) -- 342
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 343
		end) -- 341
		aim:setPlayback(game:playbackSpeed()) -- 345
		local runtime = { -- 347
			index = index, -- 348
			name = levelNames[index + 1], -- 349
			world = world, -- 350
			camera = camera, -- 351
			game = game, -- 352
			aim = aim, -- 353
			trajectory = trajectory, -- 354
			plan = plan, -- 355
			levelHasTimeWindow = def.timeWindow ~= nil, -- 356
			dateSpan = dateSpan -- 357
		} -- 357
		slot.built = true -- 359
		slot.runtime = runtime -- 360
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 361
		return runtime -- 362
	end -- 165
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 366
		local runtime = ensureLevel(index) -- 367
		if runtime == nil then -- 367
			return -- 368
		end -- 368
		local wasActive = activeIndex == index -- 371
		if opening ~= nil then -- 371
			opening.hide() -- 373
		end -- 373
		if select ~= nil then -- 373
			select:hide() -- 374
		end -- 374
		activeIndex = index -- 375
		showOnlyLevel(index) -- 376
		if not wasActive then -- 376
			Director:pushCamera(runtime.camera) -- 377
		end -- 377
		runtime.game:startLevel() -- 378
		print("[escape-velocity] enter " .. runtime.name) -- 379
	end -- 366
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 383
		if resultIndex >= 0 and resultIndex < levelTotal then -- 383
			local rt = slots[resultIndex + 1].runtime -- 385
			if rt ~= nil then -- 385
				return rt -- 386
			end -- 386
		end -- 386
		return activeRuntime() -- 388
	end -- 383
	local function onRetryTap() -- 391
		local rt = resultRuntime() -- 393
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 394
		if resultPanel ~= nil then -- 394
			resultPanel:hide() -- 395
		end -- 395
		if rt ~= nil then -- 395
			rt.game:retry() -- 396
		end -- 396
	end -- 391
	local function onBackToSelectTap() -- 399
		local rt = resultRuntime() -- 400
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 401
		if rt == nil then -- 401
			return -- 402
		end -- 402
		local runtime = rt -- 403
		if not runtime.game:backToSelect() then -- 403
			return -- 405
		end -- 405
		runtime.world.visible = false -- 406
		runtime.aim:setEnabled(false) -- 407
		if resultPanel ~= nil then -- 407
			resultPanel:hide() -- 408
		end -- 408
		if finalePanel ~= nil then -- 408
			finalePanel:hide() -- 410
		end -- 410
		progress = loadProgress(levelTotal) -- 412
		if select ~= nil then -- 412
			select:show(progress.unlocked) -- 413
		end -- 413
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 414
	end -- 399
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 427
		finalePanel = createFinalePanel( -- 430
			uiLayer, -- 430
			viewW, -- 430
			viewH, -- 430
			{onBackToSelect = function() return onBackToSelectTap() end} -- 430
		) -- 430
		resultPanel = createResultPanel( -- 433
			uiLayer, -- 433
			viewW, -- 433
			viewH, -- 433
			{ -- 433
				onRetry = function() return onRetryTap() end, -- 434
				onBackToSelect = function() return onBackToSelectTap() end -- 435
			} -- 435
		) -- 435
		local created = createLevelSelect( -- 437
			uiLayer, -- 437
			viewW, -- 437
			viewH, -- 437
			{ -- 437
				levels = levelEntries, -- 438
				onPick = function(____, index) -- 439
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 440
					if select ~= nil then -- 440
						select:hide() -- 441
					end -- 441
					enterLevel(index) -- 442
				end, -- 439
				onReplayIntro = function() -- 445
					if select ~= nil then -- 445
						select:hide() -- 446
					end -- 446
					startOpening() -- 447
					print("[escape-velocity] opening replay (user)") -- 448
				end -- 445
			} -- 445
		) -- 445
		select = created -- 451
		return created -- 452
	end -- 427
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 465
		local w = View.size.width -- 466
		local h = View.size.height -- 467
		if w == viewW and h == viewH then -- 467
			return -- 468
		end -- 468
		if opening ~= nil then -- 468
			opening.hide() -- 474
			opening = nil -- 475
		end -- 475
		if select ~= nil then -- 475
			select:hide() -- 477
		end -- 477
		if resultPanel ~= nil then -- 477
			resultPanel:hide() -- 478
		end -- 478
		if finalePanel ~= nil then -- 478
			finalePanel:hide() -- 479
		end -- 479
		do -- 479
			local i = 0 -- 480
			while i < levelTotal do -- 480
				local slot = slots[i + 1] -- 481
				if slot.runtime ~= nil then -- 481
					slot.runtime.world.visible = false -- 483
					slot.runtime.aim:setEnabled(false) -- 484
					slot.runtime.trajectory:clearPrediction() -- 487
					slot.runtime.trajectory:clearTrail() -- 488
					slot.runtime.trajectory:clearGoalRings() -- 490
					slot.runtime.plan:setVisible(false) -- 493
					slot.runtime.plan:clear() -- 494
				end -- 494
				slot.built = false -- 496
				slot.runtime = nil -- 497
				i = i + 1 -- 480
			end -- 480
		end -- 480
		viewW = w -- 501
		viewH = h -- 502
		uiLayer.size = Size(viewW, viewH) -- 503
		openingLayer.size = Size(viewW, viewH) -- 504
		do -- 504
			local i = 0 -- 505
			while i < levelTotal do -- 505
				levelLayers[i + 1].size = Size(viewW, viewH) -- 505
				i = i + 1 -- 505
			end -- 505
		end -- 505
		local panel = buildPanels() -- 508
		if activeIndex >= 0 then -- 508
			local keep = activeIndex -- 510
			activeIndex = -1 -- 511
			enterLevel(keep) -- 512
		else -- 512
			panel:show(progress.unlocked) -- 514
		end -- 514
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 516
	end -- 465
	Director.entry:onAppChange(function(name) -- 520
		if name == "Size" then -- 520
			relayoutForViewport() -- 521
		end -- 521
	end) -- 520
	local introSeen = loadIntroSeen() -- 529
	local forceIntro = false -- 530
	opening = nil -- 531
	startOpening = function() -- 533
		if opening == nil then -- 533
			opening = createOpening({ -- 535
				root = openingRoot, -- 536
				camera = openingCamera, -- 537
				layer = openingLayer, -- 538
				viewW = viewW, -- 539
				viewH = viewH, -- 540
				fovYDeg = View.fieldOfView, -- 541
				aspect = View.aspectRatio, -- 542
				spherePath = "Assets/Model/Sphere.gltf", -- 543
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 544
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 545
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 546
				onFinish = function() -- 547
					introHold = -1 -- 548
					if not introSeen then -- 548
						saveIntroSeen() -- 550
						introSeen = true -- 551
						print("[escape-velocity] intro seen -> saved") -- 552
					end -- 552
					if select ~= nil then -- 552
						select:show(progress.unlocked) -- 555
					end -- 555
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 556
						opening.frameIndex(), -- 556
						0 -- 556
					) or "?")) -- 556
				end -- 547
			}) -- 547
		end -- 547
		if opening == nil then -- 547
			return -- 560
		end -- 560
		Director:pushCamera(openingCamera) -- 561
		opening.start() -- 562
		print("[escape-velocity] opening start (first launch)") -- 563
	end -- 533
	local startupPanel = buildPanels() -- 566
	local enterReq = Path( -- 578
		Path(".", ".agent", "test-results"), -- 578
		"enter-request.txt" -- 578
	) -- 578
	local autoLaunchAt = -1 -- 579
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 581
	local autoFrame = 0 -- 582
	local autoVX = 0 -- 583
	local autoVY = 0 -- 584
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 592
	local autoBackAt = -1 -- 594
	local autoReenterAt = -1 -- 595
	local autoEntered = false -- 596
	introHold = -1 -- 598
	if Content:exist(enterReq) then -- 598
		local spec = Content:load(enterReq) -- 600
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 601
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 602
		if head == "intro" then -- 602
			forceIntro = true -- 604
			if at >= 0 then -- 604
				local rest = __TS__StringSubstring(spec, at + 1) -- 606
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 607
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 607
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 609
					if v ~= nil and v >= 0 then -- 609
						introHold = v -- 611
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 612
					end -- 612
				end -- 612
			end -- 612
		end -- 612
		local n = tonumber(head) -- 617
		if n ~= nil and n >= 1 and n <= levelTotal then -- 617
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 619
			enterLevel(n - 1) -- 620
			autoEntered = true -- 621
			if at >= 0 then -- 621
				local rest = __TS__StringSubstring(spec, at + 1) -- 623
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 623
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 628
					if f ~= nil and f >= 0 then -- 628
						autoArmAt = f -- 630
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 631
					end -- 631
				else -- 631
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 634
					local c2 = (string.find( -- 635
						rest, -- 635
						":", -- 635
						math.max(c1 + 1 + 1, 1), -- 635
						true -- 635
					) or 0) - 1 -- 635
					if c1 > 0 and c2 > c1 then -- 635
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 637
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 638
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 641
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 642
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 643
						local vy = tonumber(vyText) -- 644
						local ____temp_0 -- 645
						if c3 > 0 then -- 645
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 645
						else -- 645
							____temp_0 = nil -- 645
						end -- 645
						local steps = ____temp_0 -- 645
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 645
							autoLaunchAt = frames -- 647
							autoVX = vx -- 648
							autoVY = vy -- 649
							if steps ~= nil and steps > 0 then -- 649
								autoWarpSteps = math.floor(steps) -- 651
							end -- 651
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 653
						end -- 653
					end -- 653
				end -- 653
			end -- 653
		end -- 653
	end -- 653
	if autoEntered then -- 653
		print("[escape-velocity] opening skipped (auto enter)") -- 666
	elseif forceIntro or not introSeen then -- 666
		startOpening() -- 668
	else -- 668
		startupPanel:show(progress.unlocked) -- 670
		print("[escape-velocity] opening skipped (already seen)") -- 671
	end -- 671
	threadLoop(function() -- 676
		if opening ~= nil and opening.running() then -- 676
			if introHold < 0 or opening.frameIndex() < introHold then -- 676
				opening.step() -- 680
			end -- 680
			if App.deltaTime > 0.05 then -- 680
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 684
					opening.frameIndex(), -- 684
					0 -- 684
				)) -- 684
			end -- 684
		end -- 684
		local runtime = activeRuntime() -- 688
		if runtime ~= nil then -- 688
			runtime.game:update(App.deltaTime) -- 690
			if runtime.levelHasTimeWindow then -- 690
				runtime.aim:setDate( -- 693
					runtime.game:dateNow(), -- 693
					runtime.dateSpan -- 693
				) -- 693
			end -- 693
			local phaseNow = runtime.game:phase() -- 697
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 698
			runtime.aim:update(App.deltaTime) -- 699
			runtime.aim:setArmed(runtime.game:armed()) -- 701
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 703
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 705
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 706
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 706
				autoFrame = autoFrame + 1 -- 709
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 709
					autoArmAt = -1 -- 712
					print("[escape-velocity] auto arm (enter-request)") -- 713
					runtime.game:aimReady() -- 714
				end -- 714
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 714
					autoLaunchAt = -1 -- 717
					print("[escape-velocity] auto launch") -- 718
					if autoWarpSteps > 0 then -- 718
						do -- 718
							local s = 0 -- 722
							while s < autoWarpSteps do -- 722
								runtime.game:stepTime(1, runtime.dateSpan) -- 722
								s = s + 1 -- 722
							end -- 722
						end -- 722
						autoWarpSteps = 0 -- 723
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 724
							runtime.game:dateNow(), -- 724
							0 -- 724
						)) .. ")") -- 724
					end -- 724
					runtime.game:launch({x = autoVX, y = autoVY}) -- 726
					autoBackAt = autoFrame + 320 -- 727
					autoReenterAt = autoFrame + 380 -- 728
				end -- 728
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 728
					autoBackAt = -1 -- 732
					if runtime.game:backToSelect() then -- 732
						print("[escape-velocity] auto back to select") -- 733
					end -- 733
				end -- 733
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 733
					autoReenterAt = -1 -- 736
					print("[escape-velocity] auto re-enter") -- 737
					enterLevel(0) -- 738
				end -- 738
			end -- 738
		end -- 738
		return false -- 743
	end) -- 676
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 747
end -- 747
return ____exports -- 747
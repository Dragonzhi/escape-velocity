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
local ____Ui = require("game.Ui") -- 31
local advanceUiClock = ____Ui.advanceUiClock -- 31
local ____Opening = require("game.Opening") -- 32
local createOpening = ____Opening.createOpening -- 32
local loadIntroSeen = ____Opening.loadIntroSeen -- 32
local saveIntroSeen = ____Opening.saveIntroSeen -- 32
local levelTotal = levelCount() -- 60
if levelTotal <= 0 then -- 60
	print("[escape-velocity] FATAL: no level data") -- 63
else -- 63
	local opening, startOpening, introHold -- 63
	local viewW = View.size.width -- 65
	local viewH = View.size.height -- 66
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 69
	local levelLayers = {} -- 75
	do -- 75
		local i = 0 -- 76
		while i < levelTotal do -- 76
			local layer = Node() -- 77
			layer.size = Size(viewW, viewH) -- 78
			layer.anchor = Vec2(0.5, 0.5) -- 79
			layer.position = Vec2(0, 0) -- 80
			Director.ui:addChild(layer) -- 81
			levelLayers[#levelLayers + 1] = layer -- 82
			i = i + 1 -- 76
		end -- 76
	end -- 76
	local openingLayer = Node() -- 87
	openingLayer.size = Size(viewW, viewH) -- 88
	openingLayer.anchor = Vec2(0.5, 0.5) -- 89
	openingLayer.position = Vec2(0, 0) -- 90
	Director.ui:addChild(openingLayer) -- 91
	local openingRoot = Node3D() -- 94
	openingRoot.visible = false -- 95
	Director.entry:addChild(openingRoot) -- 96
	local openingCamera = Camera3D() -- 97
	local uiLayer = Node() -- 100
	uiLayer.size = Size(viewW, viewH) -- 101
	uiLayer.anchor = Vec2(0.5, 0.5) -- 102
	uiLayer.position = Vec2(0, 0) -- 103
	Director.ui:addChild(uiLayer) -- 104
	local levelNames = {} -- 107
	do -- 107
		local i = 0 -- 108
		while i < levelTotal do -- 108
			local def = getLevel(i) -- 109
			local title = def ~= nil and def.title or "" -- 110
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 111
			i = i + 1 -- 108
		end -- 108
	end -- 108
	local levelEntries = {} -- 113
	do -- 113
		local i = 0 -- 114
		while i < levelTotal do -- 114
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 114
			i = i + 1 -- 114
		end -- 114
	end -- 114
	local progress = loadProgress(levelTotal) -- 117
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 118
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 119
	local slots = {} -- 121
	do -- 121
		local i = 0 -- 122
		while i < levelTotal do -- 122
			slots[#slots + 1] = {built = false, runtime = nil} -- 122
			i = i + 1 -- 122
		end -- 122
	end -- 122
	local activeIndex = -1 -- 124
	local select = nil -- 125
	local resultPanel = nil -- 126
	local finalePanel = nil -- 128
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 130
	local resultIndex = -1 -- 135
	local function activeRuntime() -- 137
		if activeIndex < 0 then -- 137
			return nil -- 138
		end -- 138
		return slots[activeIndex + 1].runtime -- 139
	end -- 137
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 147
		do -- 147
			local i = 0 -- 148
			while i < levelTotal do -- 148
				do -- 148
					local slot = slots[i + 1] -- 149
					levelLayers[i + 1].visible = i == index -- 152
					if slot.runtime == nil then -- 152
						goto __continue16 -- 153
					end -- 153
					local active = i == index -- 154
					slot.runtime.world.visible = active -- 155
					slot.runtime.aim:setEnabled(active) -- 156
					if active then -- 156
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 158
					end -- 158
				end -- 158
				::__continue16:: -- 158
				i = i + 1 -- 148
			end -- 148
		end -- 148
	end -- 147
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 167
		local game -- 167
		local slot = slots[index + 1] -- 168
		if slot.built and slot.runtime ~= nil then -- 168
			return slot.runtime -- 169
		end -- 169
		local def = getLevel(index) -- 171
		if def == nil then -- 171
			return nil -- 172
		end -- 172
		local bodies = scaledPlanets(def) -- 174
		local level = { -- 175
			bodies = bodies, -- 176
			probeStart = def.probeStart, -- 177
			probeVel0 = def.probeVel0, -- 179
			goal = def.goal, -- 180
			escapeRadius = def.escapeRadius, -- 181
			maxSteps = def.maxSteps -- 182
		} -- 182
		local world = Node3D() -- 185
		Director.entry:addChild(world) -- 186
		world.visible = false -- 187
		local rtg = def.probeVariant == "rtg" -- 189
		local scene = buildScene({ -- 190
			root = world, -- 191
			bodies = bodies, -- 192
			visuals = def.visuals, -- 193
			probeStart = level.probeStart, -- 194
			probeScale = 2.2, -- 198
			spherePath = "Assets/Model/Sphere.gltf", -- 199
			ringPath = "Assets/Model/Ring.gltf", -- 200
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 201
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 208
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 209
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 210
			probeBodyRadius = rtg and 0.871 or 1.084, -- 211
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 213
		}) -- 213
		if scene == nil then -- 213
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 216
			return nil -- 217
		end -- 217
		local camera = Camera3D() -- 220
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 223
		local trajectory = createTrajectoryView( -- 224
			levelLayers[index + 1], -- 224
			trajectoryOptions() -- 224
		) -- 224
		local plan = createPlanView( -- 227
			levelLayers[index + 1], -- 227
			viewW, -- 227
			viewH, -- 227
			defaultPlanOptions() -- 227
		) -- 227
		local planTolerance = def.goal.tolerance -- 228
		local planChain = goalWaypoints(def.goal) -- 229
		do -- 229
			local w = 0 -- 230
			while w < #planChain do -- 230
				if planChain[w + 1].tolerance > planTolerance then -- 230
					planTolerance = planChain[w + 1].tolerance -- 231
				end -- 231
				w = w + 1 -- 230
			end -- 230
		end -- 230
		plan:fitTo(planFitRadius(bodies, level.probeStart, def.goal.planetIndex, planTolerance)) -- 233
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 235
		aim:setBurnInfo(0, def.dvBudget) -- 237
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 239
		aim:setDate(0, dateSpan) -- 240
		aim:onWarp(function(dir) -- 241
			game:stepTime(dir, dateSpan) -- 242
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 243
		end) -- 241
		game = createGame( -- 246
			level, -- 246
			{ -- 246
				scene = scene, -- 247
				camera = camera, -- 248
				rig = rig, -- 249
				trajectory = trajectory, -- 250
				plan = plan, -- 251
				visuals = def.visuals, -- 253
				setWorldVisible = function(____, on) -- 255
					world.visible = on -- 256
				end, -- 255
				aim = aim, -- 258
				viewW = viewW, -- 259
				viewH = viewH, -- 260
				fovYDeg = View.fieldOfView, -- 261
				aspect = View.aspectRatio, -- 262
				onPhase = function(____, p) -- 263
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 264
					if index == activeIndex then -- 264
						if p == "Finale" then -- 264
							if resultPanel ~= nil then -- 264
								resultPanel:hide() -- 272
							end -- 272
							if finalePanel ~= nil then -- 272
								finalePanel:show(finaleText.main, finaleText.sub) -- 273
							end -- 273
						else -- 273
							if p ~= "Result" and resultPanel ~= nil then -- 273
								resultPanel:hide() -- 275
							end -- 275
							if finalePanel ~= nil then -- 275
								finalePanel:hide() -- 276
							end -- 276
						end -- 276
					end -- 276
				end, -- 263
				onResult = function(____, r) -- 280
					if r == "success" then -- 280
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 283
						if next ~= progress.unlocked then -- 283
							progress = {unlocked = next} -- 285
							saveProgress(progress) -- 286
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 287
						end -- 287
					end -- 287
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 290
					resultIndex = index -- 291
					if resultPanel ~= nil then -- 291
						resultPanel:show(r, levelNames[index + 1]) -- 292
					end -- 292
				end, -- 280
				onFinale = function(____, info) -- 295
					finaleText = { -- 296
						main = FinaleMainText, -- 296
						sub = finaleSubtitle(info.distance, info.time) -- 296
					} -- 296
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 297
				end, -- 295
				finale = index == levelTotal - 1 -- 302
			} -- 302
		) -- 302
		aim:onDrag(function(a) -- 308
			game:onAimDrag(a) -- 309
			aim:setBurnInfo( -- 311
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 311
				def.dvBudget -- 311
			) -- 311
		end) -- 308
		aim:onAimReady(function(a) -- 314
			game:onAimDrag(a) -- 315
			game:aimReady() -- 316
			print("[escape-velocity] aim ready -> Armed") -- 317
		end) -- 314
		aim:onLaunch(function() -- 319
			print("[escape-velocity] launch button tap") -- 320
			game:launchArmed() -- 321
		end) -- 319
		aim:onObserve(function(dx, dy) -- 324
			game:observeDrag(dx, dy) -- 325
		end) -- 324
		aim:onZoom(function(deltaDist) -- 327
			game:observeZoom(deltaDist) -- 328
		end) -- 327
		aim:onViewToggle(function() -- 331
			game:toggleViewMode() -- 332
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 333
		end) -- 331
		aim:onBrake(function(on) -- 336
			game:setBrakeMode(on) -- 337
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 338
		end) -- 336
		aim:setBrake(game:brakeMode()) -- 340
		aim:onPlayback(function(speed) -- 343
			game:setPlaybackSpeed(speed) -- 344
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 345
		end) -- 343
		aim:setPlayback(game:playbackSpeed()) -- 347
		local runtime = { -- 349
			index = index, -- 350
			name = levelNames[index + 1], -- 351
			world = world, -- 352
			camera = camera, -- 353
			game = game, -- 354
			aim = aim, -- 355
			trajectory = trajectory, -- 356
			plan = plan, -- 357
			levelHasTimeWindow = def.timeWindow ~= nil, -- 358
			dateSpan = dateSpan -- 359
		} -- 359
		slot.built = true -- 361
		slot.runtime = runtime -- 362
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 363
		return runtime -- 364
	end -- 167
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 368
		local runtime = ensureLevel(index) -- 369
		if runtime == nil then -- 369
			return -- 370
		end -- 370
		local wasActive = activeIndex == index -- 373
		if opening ~= nil then -- 373
			opening.hide() -- 375
		end -- 375
		if select ~= nil then -- 375
			select:hide() -- 376
		end -- 376
		activeIndex = index -- 377
		showOnlyLevel(index) -- 378
		if not wasActive then -- 378
			Director:pushCamera(runtime.camera) -- 379
		end -- 379
		runtime.game:startLevel() -- 380
		print("[escape-velocity] enter " .. runtime.name) -- 381
	end -- 368
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 385
		if resultIndex >= 0 and resultIndex < levelTotal then -- 385
			local rt = slots[resultIndex + 1].runtime -- 387
			if rt ~= nil then -- 387
				return rt -- 388
			end -- 388
		end -- 388
		return activeRuntime() -- 390
	end -- 385
	local function onRetryTap() -- 393
		local rt = resultRuntime() -- 395
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 396
		if resultPanel ~= nil then -- 396
			resultPanel:hide() -- 397
		end -- 397
		if rt ~= nil then -- 397
			rt.game:retry() -- 398
		end -- 398
	end -- 393
	local function onBackToSelectTap() -- 401
		local rt = resultRuntime() -- 402
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 403
		if rt == nil then -- 403
			return -- 404
		end -- 404
		local runtime = rt -- 405
		if not runtime.game:backToSelect() then -- 405
			return -- 407
		end -- 407
		runtime.world.visible = false -- 408
		runtime.aim:setEnabled(false) -- 409
		if resultPanel ~= nil then -- 409
			resultPanel:hide() -- 410
		end -- 410
		if finalePanel ~= nil then -- 410
			finalePanel:hide() -- 412
		end -- 412
		progress = loadProgress(levelTotal) -- 414
		if select ~= nil then -- 414
			select:show(progress.unlocked) -- 415
		end -- 415
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 416
	end -- 401
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 429
		finalePanel = createFinalePanel( -- 432
			uiLayer, -- 432
			viewW, -- 432
			viewH, -- 432
			{onBackToSelect = function() return onBackToSelectTap() end} -- 432
		) -- 432
		resultPanel = createResultPanel( -- 435
			uiLayer, -- 435
			viewW, -- 435
			viewH, -- 435
			{ -- 435
				onRetry = function() return onRetryTap() end, -- 436
				onBackToSelect = function() return onBackToSelectTap() end -- 437
			} -- 437
		) -- 437
		local created = createLevelSelect( -- 439
			uiLayer, -- 439
			viewW, -- 439
			viewH, -- 439
			{ -- 439
				levels = levelEntries, -- 440
				onPick = function(____, index) -- 441
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 442
					if select ~= nil then -- 442
						select:hide() -- 443
					end -- 443
					enterLevel(index) -- 444
				end, -- 441
				onReplayIntro = function() -- 447
					if select ~= nil then -- 447
						select:hide() -- 448
					end -- 448
					startOpening() -- 449
					print("[escape-velocity] opening replay (user)") -- 450
				end -- 447
			} -- 447
		) -- 447
		select = created -- 453
		return created -- 454
	end -- 429
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 467
		local w = View.size.width -- 468
		local h = View.size.height -- 469
		if w == viewW and h == viewH then -- 469
			return -- 470
		end -- 470
		if opening ~= nil then -- 470
			opening.hide() -- 476
			opening = nil -- 477
		end -- 477
		if select ~= nil then -- 477
			select:hide() -- 479
		end -- 479
		if resultPanel ~= nil then -- 479
			resultPanel:hide() -- 480
		end -- 480
		if finalePanel ~= nil then -- 480
			finalePanel:hide() -- 481
		end -- 481
		do -- 481
			local i = 0 -- 482
			while i < levelTotal do -- 482
				local slot = slots[i + 1] -- 483
				if slot.runtime ~= nil then -- 483
					slot.runtime.world.visible = false -- 485
					slot.runtime.aim:setEnabled(false) -- 486
					slot.runtime.trajectory:clearPrediction() -- 489
					slot.runtime.trajectory:clearTrail() -- 490
					slot.runtime.trajectory:clearGoalRings() -- 492
					slot.runtime.plan:setVisible(false) -- 495
					slot.runtime.plan:clear() -- 496
				end -- 496
				slot.built = false -- 498
				slot.runtime = nil -- 499
				i = i + 1 -- 482
			end -- 482
		end -- 482
		viewW = w -- 503
		viewH = h -- 504
		uiLayer.size = Size(viewW, viewH) -- 505
		openingLayer.size = Size(viewW, viewH) -- 506
		do -- 506
			local i = 0 -- 507
			while i < levelTotal do -- 507
				levelLayers[i + 1].size = Size(viewW, viewH) -- 507
				i = i + 1 -- 507
			end -- 507
		end -- 507
		local panel = buildPanels() -- 510
		if activeIndex >= 0 then -- 510
			local keep = activeIndex -- 512
			activeIndex = -1 -- 513
			enterLevel(keep) -- 514
		else -- 514
			panel:show(progress.unlocked) -- 516
		end -- 516
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 518
	end -- 467
	Director.entry:onAppChange(function(name) -- 522
		if name == "Size" then -- 522
			relayoutForViewport() -- 523
		end -- 523
	end) -- 522
	local introSeen = loadIntroSeen() -- 531
	local forceIntro = false -- 532
	opening = nil -- 533
	startOpening = function() -- 535
		if opening == nil then -- 535
			opening = createOpening({ -- 537
				root = openingRoot, -- 538
				camera = openingCamera, -- 539
				layer = openingLayer, -- 540
				viewW = viewW, -- 541
				viewH = viewH, -- 542
				fovYDeg = View.fieldOfView, -- 543
				aspect = View.aspectRatio, -- 544
				spherePath = "Assets/Model/Sphere.gltf", -- 545
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 546
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 547
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 548
				onFinish = function() -- 549
					introHold = -1 -- 550
					if not introSeen then -- 550
						saveIntroSeen() -- 552
						introSeen = true -- 553
						print("[escape-velocity] intro seen -> saved") -- 554
					end -- 554
					if select ~= nil then -- 554
						select:show(progress.unlocked) -- 557
					end -- 557
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 558
						opening.frameIndex(), -- 558
						0 -- 558
					) or "?")) -- 558
				end -- 549
			}) -- 549
		end -- 549
		if opening == nil then -- 549
			return -- 562
		end -- 562
		Director:pushCamera(openingCamera) -- 563
		opening.start() -- 564
		print("[escape-velocity] opening start (first launch)") -- 565
	end -- 535
	local startupPanel = buildPanels() -- 568
	local enterReq = Path( -- 580
		Path(".", ".agent", "test-results"), -- 580
		"enter-request.txt" -- 580
	) -- 580
	local autoLaunchAt = -1 -- 581
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 583
	local autoFrame = 0 -- 584
	local autoVX = 0 -- 585
	local autoVY = 0 -- 586
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 594
	local autoBackAt = -1 -- 596
	local autoReenterAt = -1 -- 597
	local autoEntered = false -- 598
	introHold = -1 -- 600
	if Content:exist(enterReq) then -- 600
		local spec = Content:load(enterReq) -- 602
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 603
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 604
		if head == "intro" then -- 604
			forceIntro = true -- 606
			if at >= 0 then -- 606
				local rest = __TS__StringSubstring(spec, at + 1) -- 608
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 609
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 609
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 611
					if v ~= nil and v >= 0 then -- 611
						introHold = v -- 613
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 614
					end -- 614
				end -- 614
			end -- 614
		end -- 614
		local n = tonumber(head) -- 619
		if n ~= nil and n >= 1 and n <= levelTotal then -- 619
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 621
			enterLevel(n - 1) -- 622
			autoEntered = true -- 623
			if at >= 0 then -- 623
				local rest = __TS__StringSubstring(spec, at + 1) -- 625
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 625
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 630
					if f ~= nil and f >= 0 then -- 630
						autoArmAt = f -- 632
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 633
					end -- 633
				else -- 633
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 636
					local c2 = (string.find( -- 637
						rest, -- 637
						":", -- 637
						math.max(c1 + 1 + 1, 1), -- 637
						true -- 637
					) or 0) - 1 -- 637
					if c1 > 0 and c2 > c1 then -- 637
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 639
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 640
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 643
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 644
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 645
						local vy = tonumber(vyText) -- 646
						local ____temp_0 -- 647
						if c3 > 0 then -- 647
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 647
						else -- 647
							____temp_0 = nil -- 647
						end -- 647
						local steps = ____temp_0 -- 647
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 647
							autoLaunchAt = frames -- 649
							autoVX = vx -- 650
							autoVY = vy -- 651
							if steps ~= nil and steps > 0 then -- 651
								autoWarpSteps = math.floor(steps) -- 653
							end -- 653
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 655
						end -- 655
					end -- 655
				end -- 655
			end -- 655
		end -- 655
	end -- 655
	if autoEntered then -- 655
		print("[escape-velocity] opening skipped (auto enter)") -- 668
	elseif forceIntro or not introSeen then -- 668
		startOpening() -- 670
	else -- 670
		startupPanel:show(progress.unlocked) -- 672
		print("[escape-velocity] opening skipped (already seen)") -- 673
	end -- 673
	threadLoop(function() -- 678
		advanceUiClock(App.deltaTime) -- 682
		if opening ~= nil and opening.running() then -- 682
			if introHold < 0 or opening.frameIndex() < introHold then -- 682
				opening.step() -- 686
			end -- 686
			if App.deltaTime > 0.05 then -- 686
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 690
					opening.frameIndex(), -- 690
					0 -- 690
				)) -- 690
			end -- 690
		end -- 690
		local runtime = activeRuntime() -- 694
		if runtime ~= nil then -- 694
			runtime.game:update(App.deltaTime) -- 696
			if runtime.levelHasTimeWindow then -- 696
				runtime.aim:setDate( -- 699
					runtime.game:dateNow(), -- 699
					runtime.dateSpan -- 699
				) -- 699
			end -- 699
			local phaseNow = runtime.game:phase() -- 703
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 704
			runtime.aim:update(App.deltaTime) -- 705
			runtime.aim:setArmed(runtime.game:armed()) -- 707
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 709
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 711
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 712
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 712
				autoFrame = autoFrame + 1 -- 715
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 715
					autoArmAt = -1 -- 718
					print("[escape-velocity] auto arm (enter-request)") -- 719
					runtime.game:aimReady() -- 720
				end -- 720
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 720
					autoLaunchAt = -1 -- 723
					print("[escape-velocity] auto launch") -- 724
					if autoWarpSteps > 0 then -- 724
						do -- 724
							local s = 0 -- 728
							while s < autoWarpSteps do -- 728
								runtime.game:stepTime(1, runtime.dateSpan) -- 728
								s = s + 1 -- 728
							end -- 728
						end -- 728
						autoWarpSteps = 0 -- 729
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 730
							runtime.game:dateNow(), -- 730
							0 -- 730
						)) .. ")") -- 730
					end -- 730
					runtime.game:launch({x = autoVX, y = autoVY}) -- 732
					autoBackAt = autoFrame + 320 -- 733
					autoReenterAt = autoFrame + 380 -- 734
				end -- 734
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 734
					autoBackAt = -1 -- 738
					if runtime.game:backToSelect() then -- 738
						print("[escape-velocity] auto back to select") -- 739
					end -- 739
				end -- 739
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 739
					autoReenterAt = -1 -- 742
					print("[escape-velocity] auto re-enter") -- 743
					enterLevel(0) -- 744
				end -- 744
			end -- 744
		end -- 744
		return false -- 749
	end) -- 678
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 753
end -- 753
return ____exports -- 753
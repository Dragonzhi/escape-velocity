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
local ____Hud = require("game.Hud") -- 26
local createAimInput = ____Hud.createAimInput -- 26
local createLevelSelect = ____Hud.createLevelSelect -- 26
local createResultPanel = ____Hud.createResultPanel -- 26
local ____Game = require("game.Game") -- 27
local createGame = ____Game.createGame -- 27
local ____Progress = require("game.Progress") -- 28
local advanceUnlocked = ____Progress.advanceUnlocked -- 28
local loadProgress = ____Progress.loadProgress -- 28
local progressFilePath = ____Progress.progressFilePath -- 28
local saveProgress = ____Progress.saveProgress -- 28
local ____Opening = require("game.Opening") -- 29
local createOpening = ____Opening.createOpening -- 29
local loadIntroSeen = ____Opening.loadIntroSeen -- 29
local saveIntroSeen = ____Opening.saveIntroSeen -- 29
local levelTotal = levelCount() -- 55
if levelTotal <= 0 then -- 55
	print("[escape-velocity] FATAL: no level data") -- 58
else -- 58
	local opening, startOpening, introHold -- 58
	local viewW = View.size.width -- 60
	local viewH = View.size.height -- 61
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 64
	local levelLayers = {} -- 70
	do -- 70
		local i = 0 -- 71
		while i < levelTotal do -- 71
			local layer = Node() -- 72
			layer.size = Size(viewW, viewH) -- 73
			layer.anchor = Vec2(0.5, 0.5) -- 74
			layer.position = Vec2(0, 0) -- 75
			Director.ui:addChild(layer) -- 76
			levelLayers[#levelLayers + 1] = layer -- 77
			i = i + 1 -- 71
		end -- 71
	end -- 71
	local openingLayer = Node() -- 82
	openingLayer.size = Size(viewW, viewH) -- 83
	openingLayer.anchor = Vec2(0.5, 0.5) -- 84
	openingLayer.position = Vec2(0, 0) -- 85
	Director.ui:addChild(openingLayer) -- 86
	local openingRoot = Node3D() -- 89
	openingRoot.visible = false -- 90
	Director.entry:addChild(openingRoot) -- 91
	local openingCamera = Camera3D() -- 92
	local uiLayer = Node() -- 95
	uiLayer.size = Size(viewW, viewH) -- 96
	uiLayer.anchor = Vec2(0.5, 0.5) -- 97
	uiLayer.position = Vec2(0, 0) -- 98
	Director.ui:addChild(uiLayer) -- 99
	local levelNames = {} -- 102
	do -- 102
		local i = 0 -- 103
		while i < levelTotal do -- 103
			local def = getLevel(i) -- 104
			local title = def ~= nil and def.title or "" -- 105
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 106
			i = i + 1 -- 103
		end -- 103
	end -- 103
	local levelEntries = {} -- 108
	do -- 108
		local i = 0 -- 109
		while i < levelTotal do -- 109
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 109
			i = i + 1 -- 109
		end -- 109
	end -- 109
	local progress = loadProgress(levelTotal) -- 112
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 113
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 114
	local slots = {} -- 116
	do -- 116
		local i = 0 -- 117
		while i < levelTotal do -- 117
			slots[#slots + 1] = {built = false, runtime = nil} -- 117
			i = i + 1 -- 117
		end -- 117
	end -- 117
	local activeIndex = -1 -- 119
	local select = nil -- 120
	local resultPanel = nil -- 121
	local resultIndex = -1 -- 126
	local function activeRuntime() -- 128
		if activeIndex < 0 then -- 128
			return nil -- 129
		end -- 129
		return slots[activeIndex + 1].runtime -- 130
	end -- 128
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 138
		do -- 138
			local i = 0 -- 139
			while i < levelTotal do -- 139
				do -- 139
					local slot = slots[i + 1] -- 140
					levelLayers[i + 1].visible = i == index -- 143
					if slot.runtime == nil then -- 143
						goto __continue16 -- 144
					end -- 144
					local active = i == index -- 145
					slot.runtime.world.visible = active -- 146
					slot.runtime.aim:setEnabled(active) -- 147
					if active then -- 147
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 149
					end -- 149
				end -- 149
				::__continue16:: -- 149
				i = i + 1 -- 139
			end -- 139
		end -- 139
	end -- 138
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 158
		local game -- 158
		local slot = slots[index + 1] -- 159
		if slot.built and slot.runtime ~= nil then -- 159
			return slot.runtime -- 160
		end -- 160
		local def = getLevel(index) -- 162
		if def == nil then -- 162
			return nil -- 163
		end -- 163
		local bodies = scaledPlanets(def) -- 165
		local level = { -- 166
			bodies = bodies, -- 167
			probeStart = def.probeStart, -- 168
			probeVel0 = def.probeVel0, -- 170
			goal = def.goal, -- 171
			escapeRadius = def.escapeRadius, -- 172
			maxSteps = def.maxSteps -- 173
		} -- 173
		local world = Node3D() -- 176
		Director.entry:addChild(world) -- 177
		world.visible = false -- 178
		local scene = buildScene({ -- 180
			root = world, -- 181
			bodies = bodies, -- 182
			visuals = def.visuals, -- 183
			probeStart = level.probeStart, -- 184
			probeScale = 1.2, -- 189
			spherePath = "Assets/Model/Sphere.gltf", -- 190
			ringPath = "Assets/Model/Ring.gltf", -- 191
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 192
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 198
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 199
		}) -- 199
		if scene == nil then -- 199
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 202
			return nil -- 203
		end -- 203
		local camera = Camera3D() -- 206
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 209
		local trajectory = createTrajectoryView( -- 210
			levelLayers[index + 1], -- 210
			trajectoryOptions() -- 210
		) -- 210
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 212
		aim:setBurnInfo(0, def.dvBudget) -- 214
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 216
		aim:setDate(0, dateSpan) -- 217
		aim:onWarp(function(dir) -- 218
			game:stepTime(dir, dateSpan) -- 219
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 220
		end) -- 218
		game = createGame( -- 223
			level, -- 223
			{ -- 223
				scene = scene, -- 224
				camera = camera, -- 225
				rig = rig, -- 226
				trajectory = trajectory, -- 227
				aim = aim, -- 228
				viewW = viewW, -- 229
				viewH = viewH, -- 230
				fovYDeg = View.fieldOfView, -- 231
				aspect = View.aspectRatio, -- 232
				onPhase = function(____, p) -- 233
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 234
					if p ~= "Result" and index == activeIndex and resultPanel ~= nil then -- 234
						resultPanel:hide() -- 239
					end -- 239
				end, -- 233
				onResult = function(____, r) -- 241
					if r == "success" then -- 241
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 244
						if next ~= progress.unlocked then -- 244
							progress = {unlocked = next} -- 246
							saveProgress(progress) -- 247
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 248
						end -- 248
					end -- 248
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 251
					resultIndex = index -- 252
					if resultPanel ~= nil then -- 252
						resultPanel:show(r, levelNames[index + 1]) -- 253
					end -- 253
				end -- 241
			} -- 241
		) -- 241
		aim:onDrag(function(a) -- 260
			game:onAimDrag(a) -- 261
			aim:setBurnInfo( -- 263
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 263
				def.dvBudget -- 263
			) -- 263
		end) -- 260
		aim:onAimReady(function(a) -- 266
			game:onAimDrag(a) -- 267
			game:aimReady() -- 268
			print("[escape-velocity] aim ready -> Armed") -- 269
		end) -- 266
		aim:onLaunch(function() -- 271
			print("[escape-velocity] launch button tap") -- 272
			game:launchArmed() -- 273
		end) -- 271
		aim:onObserve(function(dx, dy) -- 276
			game:observeDrag(dx, dy) -- 277
		end) -- 276
		aim:onZoom(function(deltaDist) -- 279
			game:observeZoom(deltaDist) -- 280
		end) -- 279
		aim:onBrake(function(on) -- 283
			game:setBrakeMode(on) -- 284
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 285
		end) -- 283
		aim:setBrake(game:brakeMode()) -- 287
		local runtime = { -- 289
			index = index, -- 290
			name = levelNames[index + 1], -- 291
			world = world, -- 292
			camera = camera, -- 293
			game = game, -- 294
			aim = aim, -- 295
			trajectory = trajectory, -- 296
			levelHasTimeWindow = def.timeWindow ~= nil, -- 297
			dateSpan = dateSpan -- 298
		} -- 298
		slot.built = true -- 300
		slot.runtime = runtime -- 301
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 302
		return runtime -- 303
	end -- 158
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 307
		local runtime = ensureLevel(index) -- 308
		if runtime == nil then -- 308
			return -- 309
		end -- 309
		local wasActive = activeIndex == index -- 312
		if opening ~= nil then -- 312
			opening.hide() -- 314
		end -- 314
		if select ~= nil then -- 314
			select:hide() -- 315
		end -- 315
		activeIndex = index -- 316
		showOnlyLevel(index) -- 317
		if not wasActive then -- 317
			Director:pushCamera(runtime.camera) -- 318
		end -- 318
		runtime.game:startLevel() -- 319
		print("[escape-velocity] enter " .. runtime.name) -- 320
	end -- 307
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 324
		if resultIndex >= 0 and resultIndex < levelTotal then -- 324
			local rt = slots[resultIndex + 1].runtime -- 326
			if rt ~= nil then -- 326
				return rt -- 327
			end -- 327
		end -- 327
		return activeRuntime() -- 329
	end -- 324
	local function onRetryTap() -- 332
		local rt = resultRuntime() -- 334
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 335
		if resultPanel ~= nil then -- 335
			resultPanel:hide() -- 336
		end -- 336
		if rt ~= nil then -- 336
			rt.game:retry() -- 337
		end -- 337
	end -- 332
	local function onBackToSelectTap() -- 340
		local rt = resultRuntime() -- 341
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 342
		if rt == nil then -- 342
			return -- 343
		end -- 343
		local runtime = rt -- 344
		if not runtime.game:backToSelect() then -- 344
			return -- 346
		end -- 346
		runtime.world.visible = false -- 347
		runtime.aim:setEnabled(false) -- 348
		if resultPanel ~= nil then -- 348
			resultPanel:hide() -- 349
		end -- 349
		progress = loadProgress(levelTotal) -- 351
		if select ~= nil then -- 351
			select:show(progress.unlocked) -- 352
		end -- 352
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 353
	end -- 340
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 366
		resultPanel = createResultPanel( -- 367
			uiLayer, -- 367
			viewW, -- 367
			viewH, -- 367
			{ -- 367
				onRetry = function() return onRetryTap() end, -- 368
				onBackToSelect = function() return onBackToSelectTap() end -- 369
			} -- 369
		) -- 369
		local created = createLevelSelect( -- 371
			uiLayer, -- 371
			viewW, -- 371
			viewH, -- 371
			{ -- 371
				levels = levelEntries, -- 372
				onPick = function(____, index) -- 373
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 374
					if select ~= nil then -- 374
						select:hide() -- 375
					end -- 375
					enterLevel(index) -- 376
				end, -- 373
				onReplayIntro = function() -- 379
					if select ~= nil then -- 379
						select:hide() -- 380
					end -- 380
					startOpening() -- 381
					print("[escape-velocity] opening replay (user)") -- 382
				end -- 379
			} -- 379
		) -- 379
		select = created -- 385
		return created -- 386
	end -- 366
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 399
		local w = View.size.width -- 400
		local h = View.size.height -- 401
		if w == viewW and h == viewH then -- 401
			return -- 402
		end -- 402
		if opening ~= nil then -- 402
			opening.hide() -- 408
			opening = nil -- 409
		end -- 409
		if select ~= nil then -- 409
			select:hide() -- 411
		end -- 411
		if resultPanel ~= nil then -- 411
			resultPanel:hide() -- 412
		end -- 412
		do -- 412
			local i = 0 -- 413
			while i < levelTotal do -- 413
				local slot = slots[i + 1] -- 414
				if slot.runtime ~= nil then -- 414
					slot.runtime.world.visible = false -- 416
					slot.runtime.aim:setEnabled(false) -- 417
					slot.runtime.trajectory:clearPrediction() -- 420
					slot.runtime.trajectory:clearTrail() -- 421
					slot.runtime.trajectory:clearGoalRings() -- 423
				end -- 423
				slot.built = false -- 425
				slot.runtime = nil -- 426
				i = i + 1 -- 413
			end -- 413
		end -- 413
		viewW = w -- 430
		viewH = h -- 431
		uiLayer.size = Size(viewW, viewH) -- 432
		openingLayer.size = Size(viewW, viewH) -- 433
		do -- 433
			local i = 0 -- 434
			while i < levelTotal do -- 434
				levelLayers[i + 1].size = Size(viewW, viewH) -- 434
				i = i + 1 -- 434
			end -- 434
		end -- 434
		local panel = buildPanels() -- 437
		if activeIndex >= 0 then -- 437
			local keep = activeIndex -- 439
			activeIndex = -1 -- 440
			enterLevel(keep) -- 441
		else -- 441
			panel:show(progress.unlocked) -- 443
		end -- 443
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 445
	end -- 399
	Director.entry:onAppChange(function(name) -- 449
		if name == "Size" then -- 449
			relayoutForViewport() -- 450
		end -- 450
	end) -- 449
	local introSeen = loadIntroSeen() -- 458
	local forceIntro = false -- 459
	opening = nil -- 460
	startOpening = function() -- 462
		if opening == nil then -- 462
			opening = createOpening({ -- 464
				root = openingRoot, -- 465
				camera = openingCamera, -- 466
				layer = openingLayer, -- 467
				viewW = viewW, -- 468
				viewH = viewH, -- 469
				fovYDeg = View.fieldOfView, -- 470
				aspect = View.aspectRatio, -- 471
				spherePath = "Assets/Model/Sphere.gltf", -- 472
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 473
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 474
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 475
				onFinish = function() -- 476
					introHold = -1 -- 477
					if not introSeen then -- 477
						saveIntroSeen() -- 479
						introSeen = true -- 480
						print("[escape-velocity] intro seen -> saved") -- 481
					end -- 481
					if select ~= nil then -- 481
						select:show(progress.unlocked) -- 484
					end -- 484
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 485
						opening.frameIndex(), -- 485
						0 -- 485
					) or "?")) -- 485
				end -- 476
			}) -- 476
		end -- 476
		if opening == nil then -- 476
			return -- 489
		end -- 489
		Director:pushCamera(openingCamera) -- 490
		opening.start() -- 491
		print("[escape-velocity] opening start (first launch)") -- 492
	end -- 462
	local startupPanel = buildPanels() -- 495
	local enterReq = Path( -- 507
		Path(".", ".agent", "test-results"), -- 507
		"enter-request.txt" -- 507
	) -- 507
	local autoLaunchAt = -1 -- 508
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 510
	local autoFrame = 0 -- 511
	local autoVX = 0 -- 512
	local autoVY = 0 -- 513
	local autoBackAt = -1 -- 515
	local autoReenterAt = -1 -- 516
	local autoEntered = false -- 517
	introHold = -1 -- 519
	if Content:exist(enterReq) then -- 519
		local spec = Content:load(enterReq) -- 521
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 522
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 523
		if head == "intro" then -- 523
			forceIntro = true -- 525
			if at >= 0 then -- 525
				local rest = __TS__StringSubstring(spec, at + 1) -- 527
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 528
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 528
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 530
					if v ~= nil and v >= 0 then -- 530
						introHold = v -- 532
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 533
					end -- 533
				end -- 533
			end -- 533
		end -- 533
		local n = tonumber(head) -- 538
		if n ~= nil and n >= 1 and n <= levelTotal then -- 538
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 540
			enterLevel(n - 1) -- 541
			autoEntered = true -- 542
			if at >= 0 then -- 542
				local rest = __TS__StringSubstring(spec, at + 1) -- 544
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 544
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 549
					if f ~= nil and f >= 0 then -- 549
						autoArmAt = f -- 551
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 552
					end -- 552
				else -- 552
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 555
					local c2 = (string.find( -- 556
						rest, -- 556
						":", -- 556
						math.max(c1 + 1 + 1, 1), -- 556
						true -- 556
					) or 0) - 1 -- 556
					if c1 > 0 and c2 > c1 then -- 556
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 558
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 559
						local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 560
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 560
							autoLaunchAt = frames -- 562
							autoVX = vx -- 563
							autoVY = vy -- 564
							print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 565
						end -- 565
					end -- 565
				end -- 565
			end -- 565
		end -- 565
	end -- 565
	if autoEntered then -- 565
		print("[escape-velocity] opening skipped (auto enter)") -- 576
	elseif forceIntro or not introSeen then -- 576
		startOpening() -- 578
	else -- 578
		startupPanel:show(progress.unlocked) -- 580
		print("[escape-velocity] opening skipped (already seen)") -- 581
	end -- 581
	threadLoop(function() -- 586
		if opening ~= nil and opening.running() then -- 586
			if introHold < 0 or opening.frameIndex() < introHold then -- 586
				opening.step() -- 590
			end -- 590
			if App.deltaTime > 0.05 then -- 590
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 594
					opening.frameIndex(), -- 594
					0 -- 594
				)) -- 594
			end -- 594
		end -- 594
		local runtime = activeRuntime() -- 598
		if runtime ~= nil then -- 598
			runtime.game:update(App.deltaTime) -- 600
			if runtime.levelHasTimeWindow then -- 600
				runtime.aim:setDate( -- 603
					runtime.game:dateNow(), -- 603
					runtime.dateSpan -- 603
				) -- 603
			end -- 603
			local phaseNow = runtime.game:phase() -- 607
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 608
			runtime.aim:update(App.deltaTime) -- 609
			runtime.aim:setArmed(runtime.game:armed()) -- 611
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 611
				autoFrame = autoFrame + 1 -- 614
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 614
					autoArmAt = -1 -- 617
					print("[escape-velocity] auto arm (enter-request)") -- 618
					runtime.game:aimReady() -- 619
				end -- 619
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 619
					autoLaunchAt = -1 -- 622
					print("[escape-velocity] auto launch") -- 623
					runtime.game:launch({x = autoVX, y = autoVY}) -- 624
					autoBackAt = autoFrame + 320 -- 625
					autoReenterAt = autoFrame + 380 -- 626
				end -- 626
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 626
					autoBackAt = -1 -- 630
					if runtime.game:backToSelect() then -- 630
						print("[escape-velocity] auto back to select") -- 631
					end -- 631
				end -- 631
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 631
					autoReenterAt = -1 -- 634
					print("[escape-velocity] auto re-enter") -- 635
					enterLevel(0) -- 636
				end -- 636
			end -- 636
		end -- 636
		return false -- 641
	end) -- 586
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 645
end -- 645
return ____exports -- 645
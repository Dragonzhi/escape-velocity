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
		local rtg = def.probeVariant == "rtg" -- 180
		local scene = buildScene({ -- 181
			root = world, -- 182
			bodies = bodies, -- 183
			visuals = def.visuals, -- 184
			probeStart = level.probeStart, -- 185
			probeScale = 2.2, -- 189
			spherePath = "Assets/Model/Sphere.gltf", -- 190
			ringPath = "Assets/Model/Ring.gltf", -- 191
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 192
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 199
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 200
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 201
			probeBodyRadius = rtg and 0.871 or 1.084, -- 202
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 204
		}) -- 204
		if scene == nil then -- 204
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 207
			return nil -- 208
		end -- 208
		local camera = Camera3D() -- 211
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 214
		local trajectory = createTrajectoryView( -- 215
			levelLayers[index + 1], -- 215
			trajectoryOptions() -- 215
		) -- 215
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 217
		aim:setBurnInfo(0, def.dvBudget) -- 219
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 221
		aim:setDate(0, dateSpan) -- 222
		aim:onWarp(function(dir) -- 223
			game:stepTime(dir, dateSpan) -- 224
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 225
		end) -- 223
		game = createGame( -- 228
			level, -- 228
			{ -- 228
				scene = scene, -- 229
				camera = camera, -- 230
				rig = rig, -- 231
				trajectory = trajectory, -- 232
				aim = aim, -- 233
				viewW = viewW, -- 234
				viewH = viewH, -- 235
				fovYDeg = View.fieldOfView, -- 236
				aspect = View.aspectRatio, -- 237
				onPhase = function(____, p) -- 238
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 239
					if p ~= "Result" and index == activeIndex and resultPanel ~= nil then -- 239
						resultPanel:hide() -- 244
					end -- 244
				end, -- 238
				onResult = function(____, r) -- 246
					if r == "success" then -- 246
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 249
						if next ~= progress.unlocked then -- 249
							progress = {unlocked = next} -- 251
							saveProgress(progress) -- 252
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 253
						end -- 253
					end -- 253
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 256
					resultIndex = index -- 257
					if resultPanel ~= nil then -- 257
						resultPanel:show(r, levelNames[index + 1]) -- 258
					end -- 258
				end -- 246
			} -- 246
		) -- 246
		aim:onDrag(function(a) -- 265
			game:onAimDrag(a) -- 266
			aim:setBurnInfo( -- 268
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 268
				def.dvBudget -- 268
			) -- 268
		end) -- 265
		aim:onAimReady(function(a) -- 271
			game:onAimDrag(a) -- 272
			game:aimReady() -- 273
			print("[escape-velocity] aim ready -> Armed") -- 274
		end) -- 271
		aim:onLaunch(function() -- 276
			print("[escape-velocity] launch button tap") -- 277
			game:launchArmed() -- 278
		end) -- 276
		aim:onObserve(function(dx, dy) -- 281
			game:observeDrag(dx, dy) -- 282
		end) -- 281
		aim:onZoom(function(deltaDist) -- 284
			game:observeZoom(deltaDist) -- 285
		end) -- 284
		aim:onBrake(function(on) -- 288
			game:setBrakeMode(on) -- 289
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 290
		end) -- 288
		aim:setBrake(game:brakeMode()) -- 292
		local runtime = { -- 294
			index = index, -- 295
			name = levelNames[index + 1], -- 296
			world = world, -- 297
			camera = camera, -- 298
			game = game, -- 299
			aim = aim, -- 300
			trajectory = trajectory, -- 301
			levelHasTimeWindow = def.timeWindow ~= nil, -- 302
			dateSpan = dateSpan -- 303
		} -- 303
		slot.built = true -- 305
		slot.runtime = runtime -- 306
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 307
		return runtime -- 308
	end -- 158
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 312
		local runtime = ensureLevel(index) -- 313
		if runtime == nil then -- 313
			return -- 314
		end -- 314
		local wasActive = activeIndex == index -- 317
		if opening ~= nil then -- 317
			opening.hide() -- 319
		end -- 319
		if select ~= nil then -- 319
			select:hide() -- 320
		end -- 320
		activeIndex = index -- 321
		showOnlyLevel(index) -- 322
		if not wasActive then -- 322
			Director:pushCamera(runtime.camera) -- 323
		end -- 323
		runtime.game:startLevel() -- 324
		print("[escape-velocity] enter " .. runtime.name) -- 325
	end -- 312
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 329
		if resultIndex >= 0 and resultIndex < levelTotal then -- 329
			local rt = slots[resultIndex + 1].runtime -- 331
			if rt ~= nil then -- 331
				return rt -- 332
			end -- 332
		end -- 332
		return activeRuntime() -- 334
	end -- 329
	local function onRetryTap() -- 337
		local rt = resultRuntime() -- 339
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 340
		if resultPanel ~= nil then -- 340
			resultPanel:hide() -- 341
		end -- 341
		if rt ~= nil then -- 341
			rt.game:retry() -- 342
		end -- 342
	end -- 337
	local function onBackToSelectTap() -- 345
		local rt = resultRuntime() -- 346
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 347
		if rt == nil then -- 347
			return -- 348
		end -- 348
		local runtime = rt -- 349
		if not runtime.game:backToSelect() then -- 349
			return -- 351
		end -- 351
		runtime.world.visible = false -- 352
		runtime.aim:setEnabled(false) -- 353
		if resultPanel ~= nil then -- 353
			resultPanel:hide() -- 354
		end -- 354
		progress = loadProgress(levelTotal) -- 356
		if select ~= nil then -- 356
			select:show(progress.unlocked) -- 357
		end -- 357
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 358
	end -- 345
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 371
		resultPanel = createResultPanel( -- 372
			uiLayer, -- 372
			viewW, -- 372
			viewH, -- 372
			{ -- 372
				onRetry = function() return onRetryTap() end, -- 373
				onBackToSelect = function() return onBackToSelectTap() end -- 374
			} -- 374
		) -- 374
		local created = createLevelSelect( -- 376
			uiLayer, -- 376
			viewW, -- 376
			viewH, -- 376
			{ -- 376
				levels = levelEntries, -- 377
				onPick = function(____, index) -- 378
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 379
					if select ~= nil then -- 379
						select:hide() -- 380
					end -- 380
					enterLevel(index) -- 381
				end, -- 378
				onReplayIntro = function() -- 384
					if select ~= nil then -- 384
						select:hide() -- 385
					end -- 385
					startOpening() -- 386
					print("[escape-velocity] opening replay (user)") -- 387
				end -- 384
			} -- 384
		) -- 384
		select = created -- 390
		return created -- 391
	end -- 371
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 404
		local w = View.size.width -- 405
		local h = View.size.height -- 406
		if w == viewW and h == viewH then -- 406
			return -- 407
		end -- 407
		if opening ~= nil then -- 407
			opening.hide() -- 413
			opening = nil -- 414
		end -- 414
		if select ~= nil then -- 414
			select:hide() -- 416
		end -- 416
		if resultPanel ~= nil then -- 416
			resultPanel:hide() -- 417
		end -- 417
		do -- 417
			local i = 0 -- 418
			while i < levelTotal do -- 418
				local slot = slots[i + 1] -- 419
				if slot.runtime ~= nil then -- 419
					slot.runtime.world.visible = false -- 421
					slot.runtime.aim:setEnabled(false) -- 422
					slot.runtime.trajectory:clearPrediction() -- 425
					slot.runtime.trajectory:clearTrail() -- 426
					slot.runtime.trajectory:clearGoalRings() -- 428
				end -- 428
				slot.built = false -- 430
				slot.runtime = nil -- 431
				i = i + 1 -- 418
			end -- 418
		end -- 418
		viewW = w -- 435
		viewH = h -- 436
		uiLayer.size = Size(viewW, viewH) -- 437
		openingLayer.size = Size(viewW, viewH) -- 438
		do -- 438
			local i = 0 -- 439
			while i < levelTotal do -- 439
				levelLayers[i + 1].size = Size(viewW, viewH) -- 439
				i = i + 1 -- 439
			end -- 439
		end -- 439
		local panel = buildPanels() -- 442
		if activeIndex >= 0 then -- 442
			local keep = activeIndex -- 444
			activeIndex = -1 -- 445
			enterLevel(keep) -- 446
		else -- 446
			panel:show(progress.unlocked) -- 448
		end -- 448
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 450
	end -- 404
	Director.entry:onAppChange(function(name) -- 454
		if name == "Size" then -- 454
			relayoutForViewport() -- 455
		end -- 455
	end) -- 454
	local introSeen = loadIntroSeen() -- 463
	local forceIntro = false -- 464
	opening = nil -- 465
	startOpening = function() -- 467
		if opening == nil then -- 467
			opening = createOpening({ -- 469
				root = openingRoot, -- 470
				camera = openingCamera, -- 471
				layer = openingLayer, -- 472
				viewW = viewW, -- 473
				viewH = viewH, -- 474
				fovYDeg = View.fieldOfView, -- 475
				aspect = View.aspectRatio, -- 476
				spherePath = "Assets/Model/Sphere.gltf", -- 477
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 478
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 479
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 480
				onFinish = function() -- 481
					introHold = -1 -- 482
					if not introSeen then -- 482
						saveIntroSeen() -- 484
						introSeen = true -- 485
						print("[escape-velocity] intro seen -> saved") -- 486
					end -- 486
					if select ~= nil then -- 486
						select:show(progress.unlocked) -- 489
					end -- 489
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 490
						opening.frameIndex(), -- 490
						0 -- 490
					) or "?")) -- 490
				end -- 481
			}) -- 481
		end -- 481
		if opening == nil then -- 481
			return -- 494
		end -- 494
		Director:pushCamera(openingCamera) -- 495
		opening.start() -- 496
		print("[escape-velocity] opening start (first launch)") -- 497
	end -- 467
	local startupPanel = buildPanels() -- 500
	local enterReq = Path( -- 512
		Path(".", ".agent", "test-results"), -- 512
		"enter-request.txt" -- 512
	) -- 512
	local autoLaunchAt = -1 -- 513
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 515
	local autoFrame = 0 -- 516
	local autoVX = 0 -- 517
	local autoVY = 0 -- 518
	local autoBackAt = -1 -- 520
	local autoReenterAt = -1 -- 521
	local autoEntered = false -- 522
	introHold = -1 -- 524
	if Content:exist(enterReq) then -- 524
		local spec = Content:load(enterReq) -- 526
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 527
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 528
		if head == "intro" then -- 528
			forceIntro = true -- 530
			if at >= 0 then -- 530
				local rest = __TS__StringSubstring(spec, at + 1) -- 532
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 533
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 533
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 535
					if v ~= nil and v >= 0 then -- 535
						introHold = v -- 537
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 538
					end -- 538
				end -- 538
			end -- 538
		end -- 538
		local n = tonumber(head) -- 543
		if n ~= nil and n >= 1 and n <= levelTotal then -- 543
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 545
			enterLevel(n - 1) -- 546
			autoEntered = true -- 547
			if at >= 0 then -- 547
				local rest = __TS__StringSubstring(spec, at + 1) -- 549
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 549
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 554
					if f ~= nil and f >= 0 then -- 554
						autoArmAt = f -- 556
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 557
					end -- 557
				else -- 557
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 560
					local c2 = (string.find( -- 561
						rest, -- 561
						":", -- 561
						math.max(c1 + 1 + 1, 1), -- 561
						true -- 561
					) or 0) - 1 -- 561
					if c1 > 0 and c2 > c1 then -- 561
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 563
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 564
						local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 565
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 565
							autoLaunchAt = frames -- 567
							autoVX = vx -- 568
							autoVY = vy -- 569
							print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 570
						end -- 570
					end -- 570
				end -- 570
			end -- 570
		end -- 570
	end -- 570
	if autoEntered then -- 570
		print("[escape-velocity] opening skipped (auto enter)") -- 581
	elseif forceIntro or not introSeen then -- 581
		startOpening() -- 583
	else -- 583
		startupPanel:show(progress.unlocked) -- 585
		print("[escape-velocity] opening skipped (already seen)") -- 586
	end -- 586
	threadLoop(function() -- 591
		if opening ~= nil and opening.running() then -- 591
			if introHold < 0 or opening.frameIndex() < introHold then -- 591
				opening.step() -- 595
			end -- 595
			if App.deltaTime > 0.05 then -- 595
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 599
					opening.frameIndex(), -- 599
					0 -- 599
				)) -- 599
			end -- 599
		end -- 599
		local runtime = activeRuntime() -- 603
		if runtime ~= nil then -- 603
			runtime.game:update(App.deltaTime) -- 605
			if runtime.levelHasTimeWindow then -- 605
				runtime.aim:setDate( -- 608
					runtime.game:dateNow(), -- 608
					runtime.dateSpan -- 608
				) -- 608
			end -- 608
			local phaseNow = runtime.game:phase() -- 612
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 613
			runtime.aim:update(App.deltaTime) -- 614
			runtime.aim:setArmed(runtime.game:armed()) -- 616
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 616
				autoFrame = autoFrame + 1 -- 619
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 619
					autoArmAt = -1 -- 622
					print("[escape-velocity] auto arm (enter-request)") -- 623
					runtime.game:aimReady() -- 624
				end -- 624
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 624
					autoLaunchAt = -1 -- 627
					print("[escape-velocity] auto launch") -- 628
					runtime.game:launch({x = autoVX, y = autoVY}) -- 629
					autoBackAt = autoFrame + 320 -- 630
					autoReenterAt = autoFrame + 380 -- 631
				end -- 631
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 631
					autoBackAt = -1 -- 635
					if runtime.game:backToSelect() then -- 635
						print("[escape-velocity] auto back to select") -- 636
					end -- 636
				end -- 636
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 636
					autoReenterAt = -1 -- 639
					print("[escape-velocity] auto re-enter") -- 640
					enterLevel(0) -- 641
				end -- 641
			end -- 641
		end -- 641
		return false -- 646
	end) -- 591
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 650
end -- 650
return ____exports -- 650
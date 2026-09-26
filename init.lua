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
		local ____buildScene_4 = buildScene -- 180
		local ____bodies_1 = bodies -- 182
		local ____def_visuals_2 = def.visuals -- 183
		local ____level_probeStart_3 = level.probeStart -- 184
		local ____temp_0 -- 196
		if def.homeAnchor == false then -- 196
			____temp_0 = nil -- 196
		else -- 196
			____temp_0 = {x = level.probeStart.x, y = level.probeStart.y + 4.2} -- 196
		end -- 196
		local scene = ____buildScene_4({ -- 180
			root = world, -- 181
			bodies = ____bodies_1, -- 182
			visuals = ____def_visuals_2, -- 183
			probeStart = ____level_probeStart_3, -- 184
			probeScale = 1.2, -- 189
			spherePath = "Assets/Model/Sphere.gltf", -- 190
			ringPath = "Assets/Model/Ring.gltf", -- 191
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 192
			home = ____temp_0, -- 196
			homeRadius = def.homeRadius, -- 197
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 199
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 200
		}) -- 200
		if scene == nil then -- 200
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 203
			return nil -- 204
		end -- 204
		local camera = Camera3D() -- 207
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 210
		local trajectory = createTrajectoryView( -- 211
			levelLayers[index + 1], -- 211
			trajectoryOptions() -- 211
		) -- 211
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 213
		aim:setBurnInfo(0, def.dvBudget) -- 215
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 217
		aim:setDate(0, dateSpan) -- 218
		aim:onWarp(function(dir) -- 219
			game:stepTime(dir, dateSpan) -- 220
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 221
		end) -- 219
		game = createGame( -- 224
			level, -- 224
			{ -- 224
				scene = scene, -- 225
				camera = camera, -- 226
				rig = rig, -- 227
				trajectory = trajectory, -- 228
				aim = aim, -- 229
				viewW = viewW, -- 230
				viewH = viewH, -- 231
				fovYDeg = View.fieldOfView, -- 232
				aspect = View.aspectRatio, -- 233
				onPhase = function(____, p) -- 234
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 235
					if p ~= "Result" and index == activeIndex and resultPanel ~= nil then -- 235
						resultPanel:hide() -- 240
					end -- 240
				end, -- 234
				onResult = function(____, r) -- 242
					if r == "success" then -- 242
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 245
						if next ~= progress.unlocked then -- 245
							progress = {unlocked = next} -- 247
							saveProgress(progress) -- 248
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 249
						end -- 249
					end -- 249
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 252
					resultIndex = index -- 253
					if resultPanel ~= nil then -- 253
						resultPanel:show(r, levelNames[index + 1]) -- 254
					end -- 254
				end -- 242
			} -- 242
		) -- 242
		aim:onDrag(function(a) -- 261
			game:onAimDrag(a) -- 262
			aim:setBurnInfo( -- 264
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 264
				def.dvBudget -- 264
			) -- 264
		end) -- 261
		aim:onAimReady(function(a) -- 267
			game:onAimDrag(a) -- 268
			game:aimReady() -- 269
			print("[escape-velocity] aim ready -> Armed") -- 270
		end) -- 267
		aim:onLaunch(function() -- 272
			print("[escape-velocity] launch button tap") -- 273
			game:launchArmed() -- 274
		end) -- 272
		aim:onObserve(function(dx, dy) -- 277
			game:observeDrag(dx, dy) -- 278
		end) -- 277
		aim:onZoom(function(deltaDist) -- 280
			game:observeZoom(deltaDist) -- 281
		end) -- 280
		aim:onBrake(function(on) -- 284
			game:setBrakeMode(on) -- 285
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 286
		end) -- 284
		aim:setBrake(game:brakeMode()) -- 288
		local runtime = { -- 290
			index = index, -- 291
			name = levelNames[index + 1], -- 292
			world = world, -- 293
			camera = camera, -- 294
			game = game, -- 295
			aim = aim, -- 296
			trajectory = trajectory, -- 297
			levelHasTimeWindow = def.timeWindow ~= nil, -- 298
			dateSpan = dateSpan -- 299
		} -- 299
		slot.built = true -- 301
		slot.runtime = runtime -- 302
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 303
		return runtime -- 304
	end -- 158
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 308
		local runtime = ensureLevel(index) -- 309
		if runtime == nil then -- 309
			return -- 310
		end -- 310
		local wasActive = activeIndex == index -- 313
		if opening ~= nil then -- 313
			opening.hide() -- 315
		end -- 315
		if select ~= nil then -- 315
			select:hide() -- 316
		end -- 316
		activeIndex = index -- 317
		showOnlyLevel(index) -- 318
		if not wasActive then -- 318
			Director:pushCamera(runtime.camera) -- 319
		end -- 319
		runtime.game:startLevel() -- 320
		print("[escape-velocity] enter " .. runtime.name) -- 321
	end -- 308
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 325
		if resultIndex >= 0 and resultIndex < levelTotal then -- 325
			local rt = slots[resultIndex + 1].runtime -- 327
			if rt ~= nil then -- 327
				return rt -- 328
			end -- 328
		end -- 328
		return activeRuntime() -- 330
	end -- 325
	local function onRetryTap() -- 333
		local rt = resultRuntime() -- 335
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 336
		if resultPanel ~= nil then -- 336
			resultPanel:hide() -- 337
		end -- 337
		if rt ~= nil then -- 337
			rt.game:retry() -- 338
		end -- 338
	end -- 333
	local function onBackToSelectTap() -- 341
		local rt = resultRuntime() -- 342
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 343
		if rt == nil then -- 343
			return -- 344
		end -- 344
		local runtime = rt -- 345
		if not runtime.game:backToSelect() then -- 345
			return -- 347
		end -- 347
		runtime.world.visible = false -- 348
		runtime.aim:setEnabled(false) -- 349
		if resultPanel ~= nil then -- 349
			resultPanel:hide() -- 350
		end -- 350
		progress = loadProgress(levelTotal) -- 352
		if select ~= nil then -- 352
			select:show(progress.unlocked) -- 353
		end -- 353
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 354
	end -- 341
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 367
		resultPanel = createResultPanel( -- 368
			uiLayer, -- 368
			viewW, -- 368
			viewH, -- 368
			{ -- 368
				onRetry = function() return onRetryTap() end, -- 369
				onBackToSelect = function() return onBackToSelectTap() end -- 370
			} -- 370
		) -- 370
		local created = createLevelSelect( -- 372
			uiLayer, -- 372
			viewW, -- 372
			viewH, -- 372
			{ -- 372
				levels = levelEntries, -- 373
				onPick = function(____, index) -- 374
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 375
					if select ~= nil then -- 375
						select:hide() -- 376
					end -- 376
					enterLevel(index) -- 377
				end, -- 374
				onReplayIntro = function() -- 380
					if select ~= nil then -- 380
						select:hide() -- 381
					end -- 381
					startOpening() -- 382
					print("[escape-velocity] opening replay (user)") -- 383
				end -- 380
			} -- 380
		) -- 380
		select = created -- 386
		return created -- 387
	end -- 367
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 400
		local w = View.size.width -- 401
		local h = View.size.height -- 402
		if w == viewW and h == viewH then -- 402
			return -- 403
		end -- 403
		if opening ~= nil then -- 403
			opening.hide() -- 409
			opening = nil -- 410
		end -- 410
		if select ~= nil then -- 410
			select:hide() -- 412
		end -- 412
		if resultPanel ~= nil then -- 412
			resultPanel:hide() -- 413
		end -- 413
		do -- 413
			local i = 0 -- 414
			while i < levelTotal do -- 414
				local slot = slots[i + 1] -- 415
				if slot.runtime ~= nil then -- 415
					slot.runtime.world.visible = false -- 417
					slot.runtime.aim:setEnabled(false) -- 418
					slot.runtime.trajectory:clearPrediction() -- 421
					slot.runtime.trajectory:clearTrail() -- 422
					slot.runtime.trajectory:clearGoalRings() -- 424
				end -- 424
				slot.built = false -- 426
				slot.runtime = nil -- 427
				i = i + 1 -- 414
			end -- 414
		end -- 414
		viewW = w -- 431
		viewH = h -- 432
		uiLayer.size = Size(viewW, viewH) -- 433
		openingLayer.size = Size(viewW, viewH) -- 434
		do -- 434
			local i = 0 -- 435
			while i < levelTotal do -- 435
				levelLayers[i + 1].size = Size(viewW, viewH) -- 435
				i = i + 1 -- 435
			end -- 435
		end -- 435
		local panel = buildPanels() -- 438
		if activeIndex >= 0 then -- 438
			local keep = activeIndex -- 440
			activeIndex = -1 -- 441
			enterLevel(keep) -- 442
		else -- 442
			panel:show(progress.unlocked) -- 444
		end -- 444
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 446
	end -- 400
	Director.entry:onAppChange(function(name) -- 450
		if name == "Size" then -- 450
			relayoutForViewport() -- 451
		end -- 451
	end) -- 450
	local introSeen = loadIntroSeen() -- 459
	local forceIntro = false -- 460
	opening = nil -- 461
	startOpening = function() -- 463
		if opening == nil then -- 463
			opening = createOpening({ -- 465
				root = openingRoot, -- 466
				camera = openingCamera, -- 467
				layer = openingLayer, -- 468
				viewW = viewW, -- 469
				viewH = viewH, -- 470
				fovYDeg = View.fieldOfView, -- 471
				aspect = View.aspectRatio, -- 472
				spherePath = "Assets/Model/Sphere.gltf", -- 473
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 474
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 475
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 476
				onFinish = function() -- 477
					introHold = -1 -- 478
					if not introSeen then -- 478
						saveIntroSeen() -- 480
						introSeen = true -- 481
						print("[escape-velocity] intro seen -> saved") -- 482
					end -- 482
					if select ~= nil then -- 482
						select:show(progress.unlocked) -- 485
					end -- 485
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 486
						opening.frameIndex(), -- 486
						0 -- 486
					) or "?")) -- 486
				end -- 477
			}) -- 477
		end -- 477
		if opening == nil then -- 477
			return -- 490
		end -- 490
		Director:pushCamera(openingCamera) -- 491
		opening.start() -- 492
		print("[escape-velocity] opening start (first launch)") -- 493
	end -- 463
	local startupPanel = buildPanels() -- 496
	local enterReq = Path( -- 508
		Path(".", ".agent", "test-results"), -- 508
		"enter-request.txt" -- 508
	) -- 508
	local autoLaunchAt = -1 -- 509
	local autoFrame = 0 -- 510
	local autoVX = 0 -- 511
	local autoVY = 0 -- 512
	local autoBackAt = -1 -- 514
	local autoReenterAt = -1 -- 515
	local autoEntered = false -- 516
	introHold = -1 -- 518
	if Content:exist(enterReq) then -- 518
		local spec = Content:load(enterReq) -- 520
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 521
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 522
		if head == "intro" then -- 522
			forceIntro = true -- 524
			if at >= 0 then -- 524
				local rest = __TS__StringSubstring(spec, at + 1) -- 526
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 527
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 527
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 529
					if v ~= nil and v >= 0 then -- 529
						introHold = v -- 531
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 532
					end -- 532
				end -- 532
			end -- 532
		end -- 532
		local n = tonumber(head) -- 537
		if n ~= nil and n >= 1 and n <= levelTotal then -- 537
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 539
			enterLevel(n - 1) -- 540
			autoEntered = true -- 541
			if at >= 0 then -- 541
				local rest = __TS__StringSubstring(spec, at + 1) -- 543
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 544
				local c2 = (string.find( -- 545
					rest, -- 545
					":", -- 545
					math.max(c1 + 1 + 1, 1), -- 545
					true -- 545
				) or 0) - 1 -- 545
				if c1 > 0 and c2 > c1 then -- 545
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 547
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 548
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 549
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 549
						autoLaunchAt = frames -- 551
						autoVX = vx -- 552
						autoVY = vy -- 553
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 554
					end -- 554
				end -- 554
			end -- 554
		end -- 554
	end -- 554
	if autoEntered then -- 554
		print("[escape-velocity] opening skipped (auto enter)") -- 564
	elseif forceIntro or not introSeen then -- 564
		startOpening() -- 566
	else -- 566
		startupPanel:show(progress.unlocked) -- 568
		print("[escape-velocity] opening skipped (already seen)") -- 569
	end -- 569
	threadLoop(function() -- 574
		if opening ~= nil and opening.running() then -- 574
			if introHold < 0 or opening.frameIndex() < introHold then -- 574
				opening.step() -- 578
			end -- 578
			if App.deltaTime > 0.05 then -- 578
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 582
					opening.frameIndex(), -- 582
					0 -- 582
				)) -- 582
			end -- 582
		end -- 582
		local runtime = activeRuntime() -- 586
		if runtime ~= nil then -- 586
			runtime.game:update(App.deltaTime) -- 588
			if runtime.levelHasTimeWindow then -- 588
				runtime.aim:setDate( -- 591
					runtime.game:dateNow(), -- 591
					runtime.dateSpan -- 591
				) -- 591
			end -- 591
			local phaseNow = runtime.game:phase() -- 595
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 596
			runtime.aim:update(App.deltaTime) -- 597
			runtime.aim:setArmed(runtime.game:armed()) -- 599
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 599
				autoFrame = autoFrame + 1 -- 602
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 602
					autoLaunchAt = -1 -- 604
					print("[escape-velocity] auto launch") -- 605
					runtime.game:launch({x = autoVX, y = autoVY}) -- 606
					autoBackAt = autoFrame + 320 -- 607
					autoReenterAt = autoFrame + 380 -- 608
				end -- 608
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 608
					autoBackAt = -1 -- 612
					if runtime.game:backToSelect() then -- 612
						print("[escape-velocity] auto back to select") -- 613
					end -- 613
				end -- 613
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 613
					autoReenterAt = -1 -- 616
					print("[escape-velocity] auto re-enter") -- 617
					enterLevel(0) -- 618
				end -- 618
			end -- 618
		end -- 618
		return false -- 623
	end) -- 574
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 627
end -- 627
return ____exports -- 627
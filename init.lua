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
local createAimInput = ____Hud.createAimInput -- 27
local createLevelSelect = ____Hud.createLevelSelect -- 27
local createResultPanel = ____Hud.createResultPanel -- 27
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
	local resultIndex = -1 -- 129
	local function activeRuntime() -- 131
		if activeIndex < 0 then -- 131
			return nil -- 132
		end -- 132
		return slots[activeIndex + 1].runtime -- 133
	end -- 131
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 141
		do -- 141
			local i = 0 -- 142
			while i < levelTotal do -- 142
				do -- 142
					local slot = slots[i + 1] -- 143
					levelLayers[i + 1].visible = i == index -- 146
					if slot.runtime == nil then -- 146
						goto __continue16 -- 147
					end -- 147
					local active = i == index -- 148
					slot.runtime.world.visible = active -- 149
					slot.runtime.aim:setEnabled(active) -- 150
					if active then -- 150
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 152
					end -- 152
				end -- 152
				::__continue16:: -- 152
				i = i + 1 -- 142
			end -- 142
		end -- 142
	end -- 141
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 161
		local game -- 161
		local slot = slots[index + 1] -- 162
		if slot.built and slot.runtime ~= nil then -- 162
			return slot.runtime -- 163
		end -- 163
		local def = getLevel(index) -- 165
		if def == nil then -- 165
			return nil -- 166
		end -- 166
		local bodies = scaledPlanets(def) -- 168
		local level = { -- 169
			bodies = bodies, -- 170
			probeStart = def.probeStart, -- 171
			probeVel0 = def.probeVel0, -- 173
			goal = def.goal, -- 174
			escapeRadius = def.escapeRadius, -- 175
			maxSteps = def.maxSteps -- 176
		} -- 176
		local world = Node3D() -- 179
		Director.entry:addChild(world) -- 180
		world.visible = false -- 181
		local rtg = def.probeVariant == "rtg" -- 183
		local scene = buildScene({ -- 184
			root = world, -- 185
			bodies = bodies, -- 186
			visuals = def.visuals, -- 187
			probeStart = level.probeStart, -- 188
			probeScale = 2.2, -- 192
			spherePath = "Assets/Model/Sphere.gltf", -- 193
			ringPath = "Assets/Model/Ring.gltf", -- 194
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 195
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 202
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 203
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 204
			probeBodyRadius = rtg and 0.871 or 1.084, -- 205
			probeAtlasPath = "Assets/Image/probe_atlas.jpg" -- 207
		}) -- 207
		if scene == nil then -- 207
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 210
			return nil -- 211
		end -- 211
		local camera = Camera3D() -- 214
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 217
		local trajectory = createTrajectoryView( -- 218
			levelLayers[index + 1], -- 218
			trajectoryOptions() -- 218
		) -- 218
		local plan = createPlanView( -- 221
			levelLayers[index + 1], -- 221
			viewW, -- 221
			viewH, -- 221
			defaultPlanOptions() -- 221
		) -- 221
		local planTolerance = def.goal.tolerance -- 222
		local planChain = goalWaypoints(def.goal) -- 223
		do -- 223
			local w = 0 -- 224
			while w < #planChain do -- 224
				if planChain[w + 1].tolerance > planTolerance then -- 224
					planTolerance = planChain[w + 1].tolerance -- 225
				end -- 225
				w = w + 1 -- 224
			end -- 224
		end -- 224
		plan:fitTo(planFitRadius(bodies, level.probeStart, def.goal.planetIndex, planTolerance)) -- 227
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 229
		aim:setBurnInfo(0, def.dvBudget) -- 231
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 233
		aim:setDate(0, dateSpan) -- 234
		aim:onWarp(function(dir) -- 235
			game:stepTime(dir, dateSpan) -- 236
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 237
		end) -- 235
		game = createGame( -- 240
			level, -- 240
			{ -- 240
				scene = scene, -- 241
				camera = camera, -- 242
				rig = rig, -- 243
				trajectory = trajectory, -- 244
				plan = plan, -- 245
				visuals = def.visuals, -- 247
				setWorldVisible = function(____, on) -- 249
					world.visible = on -- 250
				end, -- 249
				aim = aim, -- 252
				viewW = viewW, -- 253
				viewH = viewH, -- 254
				fovYDeg = View.fieldOfView, -- 255
				aspect = View.aspectRatio, -- 256
				onPhase = function(____, p) -- 257
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 258
					if p ~= "Result" and index == activeIndex and resultPanel ~= nil then -- 258
						resultPanel:hide() -- 263
					end -- 263
				end, -- 257
				onResult = function(____, r) -- 265
					if r == "success" then -- 265
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 268
						if next ~= progress.unlocked then -- 268
							progress = {unlocked = next} -- 270
							saveProgress(progress) -- 271
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 272
						end -- 272
					end -- 272
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 275
					resultIndex = index -- 276
					if resultPanel ~= nil then -- 276
						resultPanel:show(r, levelNames[index + 1]) -- 277
					end -- 277
				end -- 265
			} -- 265
		) -- 265
		aim:onDrag(function(a) -- 284
			game:onAimDrag(a) -- 285
			aim:setBurnInfo( -- 287
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 287
				def.dvBudget -- 287
			) -- 287
		end) -- 284
		aim:onAimReady(function(a) -- 290
			game:onAimDrag(a) -- 291
			game:aimReady() -- 292
			print("[escape-velocity] aim ready -> Armed") -- 293
		end) -- 290
		aim:onLaunch(function() -- 295
			print("[escape-velocity] launch button tap") -- 296
			game:launchArmed() -- 297
		end) -- 295
		aim:onObserve(function(dx, dy) -- 300
			game:observeDrag(dx, dy) -- 301
		end) -- 300
		aim:onZoom(function(deltaDist) -- 303
			game:observeZoom(deltaDist) -- 304
		end) -- 303
		aim:onViewToggle(function() -- 307
			game:toggleViewMode() -- 308
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 309
		end) -- 307
		aim:onBrake(function(on) -- 312
			game:setBrakeMode(on) -- 313
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 314
		end) -- 312
		aim:setBrake(game:brakeMode()) -- 316
		aim:onPlayback(function(speed) -- 319
			game:setPlaybackSpeed(speed) -- 320
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 321
		end) -- 319
		aim:setPlayback(game:playbackSpeed()) -- 323
		local runtime = { -- 325
			index = index, -- 326
			name = levelNames[index + 1], -- 327
			world = world, -- 328
			camera = camera, -- 329
			game = game, -- 330
			aim = aim, -- 331
			trajectory = trajectory, -- 332
			plan = plan, -- 333
			levelHasTimeWindow = def.timeWindow ~= nil, -- 334
			dateSpan = dateSpan -- 335
		} -- 335
		slot.built = true -- 337
		slot.runtime = runtime -- 338
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 339
		return runtime -- 340
	end -- 161
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 344
		local runtime = ensureLevel(index) -- 345
		if runtime == nil then -- 345
			return -- 346
		end -- 346
		local wasActive = activeIndex == index -- 349
		if opening ~= nil then -- 349
			opening.hide() -- 351
		end -- 351
		if select ~= nil then -- 351
			select:hide() -- 352
		end -- 352
		activeIndex = index -- 353
		showOnlyLevel(index) -- 354
		if not wasActive then -- 354
			Director:pushCamera(runtime.camera) -- 355
		end -- 355
		runtime.game:startLevel() -- 356
		print("[escape-velocity] enter " .. runtime.name) -- 357
	end -- 344
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 361
		if resultIndex >= 0 and resultIndex < levelTotal then -- 361
			local rt = slots[resultIndex + 1].runtime -- 363
			if rt ~= nil then -- 363
				return rt -- 364
			end -- 364
		end -- 364
		return activeRuntime() -- 366
	end -- 361
	local function onRetryTap() -- 369
		local rt = resultRuntime() -- 371
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 372
		if resultPanel ~= nil then -- 372
			resultPanel:hide() -- 373
		end -- 373
		if rt ~= nil then -- 373
			rt.game:retry() -- 374
		end -- 374
	end -- 369
	local function onBackToSelectTap() -- 377
		local rt = resultRuntime() -- 378
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 379
		if rt == nil then -- 379
			return -- 380
		end -- 380
		local runtime = rt -- 381
		if not runtime.game:backToSelect() then -- 381
			return -- 383
		end -- 383
		runtime.world.visible = false -- 384
		runtime.aim:setEnabled(false) -- 385
		if resultPanel ~= nil then -- 385
			resultPanel:hide() -- 386
		end -- 386
		progress = loadProgress(levelTotal) -- 388
		if select ~= nil then -- 388
			select:show(progress.unlocked) -- 389
		end -- 389
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 390
	end -- 377
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 403
		resultPanel = createResultPanel( -- 404
			uiLayer, -- 404
			viewW, -- 404
			viewH, -- 404
			{ -- 404
				onRetry = function() return onRetryTap() end, -- 405
				onBackToSelect = function() return onBackToSelectTap() end -- 406
			} -- 406
		) -- 406
		local created = createLevelSelect( -- 408
			uiLayer, -- 408
			viewW, -- 408
			viewH, -- 408
			{ -- 408
				levels = levelEntries, -- 409
				onPick = function(____, index) -- 410
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 411
					if select ~= nil then -- 411
						select:hide() -- 412
					end -- 412
					enterLevel(index) -- 413
				end, -- 410
				onReplayIntro = function() -- 416
					if select ~= nil then -- 416
						select:hide() -- 417
					end -- 417
					startOpening() -- 418
					print("[escape-velocity] opening replay (user)") -- 419
				end -- 416
			} -- 416
		) -- 416
		select = created -- 422
		return created -- 423
	end -- 403
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 436
		local w = View.size.width -- 437
		local h = View.size.height -- 438
		if w == viewW and h == viewH then -- 438
			return -- 439
		end -- 439
		if opening ~= nil then -- 439
			opening.hide() -- 445
			opening = nil -- 446
		end -- 446
		if select ~= nil then -- 446
			select:hide() -- 448
		end -- 448
		if resultPanel ~= nil then -- 448
			resultPanel:hide() -- 449
		end -- 449
		do -- 449
			local i = 0 -- 450
			while i < levelTotal do -- 450
				local slot = slots[i + 1] -- 451
				if slot.runtime ~= nil then -- 451
					slot.runtime.world.visible = false -- 453
					slot.runtime.aim:setEnabled(false) -- 454
					slot.runtime.trajectory:clearPrediction() -- 457
					slot.runtime.trajectory:clearTrail() -- 458
					slot.runtime.trajectory:clearGoalRings() -- 460
					slot.runtime.plan:setVisible(false) -- 463
					slot.runtime.plan:clear() -- 464
				end -- 464
				slot.built = false -- 466
				slot.runtime = nil -- 467
				i = i + 1 -- 450
			end -- 450
		end -- 450
		viewW = w -- 471
		viewH = h -- 472
		uiLayer.size = Size(viewW, viewH) -- 473
		openingLayer.size = Size(viewW, viewH) -- 474
		do -- 474
			local i = 0 -- 475
			while i < levelTotal do -- 475
				levelLayers[i + 1].size = Size(viewW, viewH) -- 475
				i = i + 1 -- 475
			end -- 475
		end -- 475
		local panel = buildPanels() -- 478
		if activeIndex >= 0 then -- 478
			local keep = activeIndex -- 480
			activeIndex = -1 -- 481
			enterLevel(keep) -- 482
		else -- 482
			panel:show(progress.unlocked) -- 484
		end -- 484
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 486
	end -- 436
	Director.entry:onAppChange(function(name) -- 490
		if name == "Size" then -- 490
			relayoutForViewport() -- 491
		end -- 491
	end) -- 490
	local introSeen = loadIntroSeen() -- 499
	local forceIntro = false -- 500
	opening = nil -- 501
	startOpening = function() -- 503
		if opening == nil then -- 503
			opening = createOpening({ -- 505
				root = openingRoot, -- 506
				camera = openingCamera, -- 507
				layer = openingLayer, -- 508
				viewW = viewW, -- 509
				viewH = viewH, -- 510
				fovYDeg = View.fieldOfView, -- 511
				aspect = View.aspectRatio, -- 512
				spherePath = "Assets/Model/Sphere.gltf", -- 513
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 514
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 515
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 516
				onFinish = function() -- 517
					introHold = -1 -- 518
					if not introSeen then -- 518
						saveIntroSeen() -- 520
						introSeen = true -- 521
						print("[escape-velocity] intro seen -> saved") -- 522
					end -- 522
					if select ~= nil then -- 522
						select:show(progress.unlocked) -- 525
					end -- 525
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 526
						opening.frameIndex(), -- 526
						0 -- 526
					) or "?")) -- 526
				end -- 517
			}) -- 517
		end -- 517
		if opening == nil then -- 517
			return -- 530
		end -- 530
		Director:pushCamera(openingCamera) -- 531
		opening.start() -- 532
		print("[escape-velocity] opening start (first launch)") -- 533
	end -- 503
	local startupPanel = buildPanels() -- 536
	local enterReq = Path( -- 548
		Path(".", ".agent", "test-results"), -- 548
		"enter-request.txt" -- 548
	) -- 548
	local autoLaunchAt = -1 -- 549
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 551
	local autoFrame = 0 -- 552
	local autoVX = 0 -- 553
	local autoVY = 0 -- 554
	local autoBackAt = -1 -- 556
	local autoReenterAt = -1 -- 557
	local autoEntered = false -- 558
	introHold = -1 -- 560
	if Content:exist(enterReq) then -- 560
		local spec = Content:load(enterReq) -- 562
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 563
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 564
		if head == "intro" then -- 564
			forceIntro = true -- 566
			if at >= 0 then -- 566
				local rest = __TS__StringSubstring(spec, at + 1) -- 568
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 569
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 569
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 571
					if v ~= nil and v >= 0 then -- 571
						introHold = v -- 573
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 574
					end -- 574
				end -- 574
			end -- 574
		end -- 574
		local n = tonumber(head) -- 579
		if n ~= nil and n >= 1 and n <= levelTotal then -- 579
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 581
			enterLevel(n - 1) -- 582
			autoEntered = true -- 583
			if at >= 0 then -- 583
				local rest = __TS__StringSubstring(spec, at + 1) -- 585
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 585
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 590
					if f ~= nil and f >= 0 then -- 590
						autoArmAt = f -- 592
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 593
					end -- 593
				else -- 593
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 596
					local c2 = (string.find( -- 597
						rest, -- 597
						":", -- 597
						math.max(c1 + 1 + 1, 1), -- 597
						true -- 597
					) or 0) - 1 -- 597
					if c1 > 0 and c2 > c1 then -- 597
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 599
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 600
						local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 601
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 601
							autoLaunchAt = frames -- 603
							autoVX = vx -- 604
							autoVY = vy -- 605
							print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 606
						end -- 606
					end -- 606
				end -- 606
			end -- 606
		end -- 606
	end -- 606
	if autoEntered then -- 606
		print("[escape-velocity] opening skipped (auto enter)") -- 617
	elseif forceIntro or not introSeen then -- 617
		startOpening() -- 619
	else -- 619
		startupPanel:show(progress.unlocked) -- 621
		print("[escape-velocity] opening skipped (already seen)") -- 622
	end -- 622
	threadLoop(function() -- 627
		if opening ~= nil and opening.running() then -- 627
			if introHold < 0 or opening.frameIndex() < introHold then -- 627
				opening.step() -- 631
			end -- 631
			if App.deltaTime > 0.05 then -- 631
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 635
					opening.frameIndex(), -- 635
					0 -- 635
				)) -- 635
			end -- 635
		end -- 635
		local runtime = activeRuntime() -- 639
		if runtime ~= nil then -- 639
			runtime.game:update(App.deltaTime) -- 641
			if runtime.levelHasTimeWindow then -- 641
				runtime.aim:setDate( -- 644
					runtime.game:dateNow(), -- 644
					runtime.dateSpan -- 644
				) -- 644
			end -- 644
			local phaseNow = runtime.game:phase() -- 648
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 649
			runtime.aim:update(App.deltaTime) -- 650
			runtime.aim:setArmed(runtime.game:armed()) -- 652
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 654
			runtime.aim:setPlaybackVisible(phaseNow == "Flying") -- 656
			runtime.aim:setPlayback(runtime.game:playbackSpeed()) -- 657
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 657
				autoFrame = autoFrame + 1 -- 660
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 660
					autoArmAt = -1 -- 663
					print("[escape-velocity] auto arm (enter-request)") -- 664
					runtime.game:aimReady() -- 665
				end -- 665
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 665
					autoLaunchAt = -1 -- 668
					print("[escape-velocity] auto launch") -- 669
					runtime.game:launch({x = autoVX, y = autoVY}) -- 670
					autoBackAt = autoFrame + 320 -- 671
					autoReenterAt = autoFrame + 380 -- 672
				end -- 672
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 672
					autoBackAt = -1 -- 676
					if runtime.game:backToSelect() then -- 676
						print("[escape-velocity] auto back to select") -- 677
					end -- 677
				end -- 677
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 677
					autoReenterAt = -1 -- 680
					print("[escape-velocity] auto re-enter") -- 681
					enterLevel(0) -- 682
				end -- 682
			end -- 682
		end -- 682
		return false -- 687
	end) -- 627
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 691
end -- 691
return ____exports -- 691
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
		local runtime = { -- 318
			index = index, -- 319
			name = levelNames[index + 1], -- 320
			world = world, -- 321
			camera = camera, -- 322
			game = game, -- 323
			aim = aim, -- 324
			trajectory = trajectory, -- 325
			plan = plan, -- 326
			levelHasTimeWindow = def.timeWindow ~= nil, -- 327
			dateSpan = dateSpan -- 328
		} -- 328
		slot.built = true -- 330
		slot.runtime = runtime -- 331
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 332
		return runtime -- 333
	end -- 161
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 337
		local runtime = ensureLevel(index) -- 338
		if runtime == nil then -- 338
			return -- 339
		end -- 339
		local wasActive = activeIndex == index -- 342
		if opening ~= nil then -- 342
			opening.hide() -- 344
		end -- 344
		if select ~= nil then -- 344
			select:hide() -- 345
		end -- 345
		activeIndex = index -- 346
		showOnlyLevel(index) -- 347
		if not wasActive then -- 347
			Director:pushCamera(runtime.camera) -- 348
		end -- 348
		runtime.game:startLevel() -- 349
		print("[escape-velocity] enter " .. runtime.name) -- 350
	end -- 337
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 354
		if resultIndex >= 0 and resultIndex < levelTotal then -- 354
			local rt = slots[resultIndex + 1].runtime -- 356
			if rt ~= nil then -- 356
				return rt -- 357
			end -- 357
		end -- 357
		return activeRuntime() -- 359
	end -- 354
	local function onRetryTap() -- 362
		local rt = resultRuntime() -- 364
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 365
		if resultPanel ~= nil then -- 365
			resultPanel:hide() -- 366
		end -- 366
		if rt ~= nil then -- 366
			rt.game:retry() -- 367
		end -- 367
	end -- 362
	local function onBackToSelectTap() -- 370
		local rt = resultRuntime() -- 371
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 372
		if rt == nil then -- 372
			return -- 373
		end -- 373
		local runtime = rt -- 374
		if not runtime.game:backToSelect() then -- 374
			return -- 376
		end -- 376
		runtime.world.visible = false -- 377
		runtime.aim:setEnabled(false) -- 378
		if resultPanel ~= nil then -- 378
			resultPanel:hide() -- 379
		end -- 379
		progress = loadProgress(levelTotal) -- 381
		if select ~= nil then -- 381
			select:show(progress.unlocked) -- 382
		end -- 382
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 383
	end -- 370
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 396
		resultPanel = createResultPanel( -- 397
			uiLayer, -- 397
			viewW, -- 397
			viewH, -- 397
			{ -- 397
				onRetry = function() return onRetryTap() end, -- 398
				onBackToSelect = function() return onBackToSelectTap() end -- 399
			} -- 399
		) -- 399
		local created = createLevelSelect( -- 401
			uiLayer, -- 401
			viewW, -- 401
			viewH, -- 401
			{ -- 401
				levels = levelEntries, -- 402
				onPick = function(____, index) -- 403
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 404
					if select ~= nil then -- 404
						select:hide() -- 405
					end -- 405
					enterLevel(index) -- 406
				end, -- 403
				onReplayIntro = function() -- 409
					if select ~= nil then -- 409
						select:hide() -- 410
					end -- 410
					startOpening() -- 411
					print("[escape-velocity] opening replay (user)") -- 412
				end -- 409
			} -- 409
		) -- 409
		select = created -- 415
		return created -- 416
	end -- 396
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 429
		local w = View.size.width -- 430
		local h = View.size.height -- 431
		if w == viewW and h == viewH then -- 431
			return -- 432
		end -- 432
		if opening ~= nil then -- 432
			opening.hide() -- 438
			opening = nil -- 439
		end -- 439
		if select ~= nil then -- 439
			select:hide() -- 441
		end -- 441
		if resultPanel ~= nil then -- 441
			resultPanel:hide() -- 442
		end -- 442
		do -- 442
			local i = 0 -- 443
			while i < levelTotal do -- 443
				local slot = slots[i + 1] -- 444
				if slot.runtime ~= nil then -- 444
					slot.runtime.world.visible = false -- 446
					slot.runtime.aim:setEnabled(false) -- 447
					slot.runtime.trajectory:clearPrediction() -- 450
					slot.runtime.trajectory:clearTrail() -- 451
					slot.runtime.trajectory:clearGoalRings() -- 453
					slot.runtime.plan:setVisible(false) -- 456
					slot.runtime.plan:clear() -- 457
				end -- 457
				slot.built = false -- 459
				slot.runtime = nil -- 460
				i = i + 1 -- 443
			end -- 443
		end -- 443
		viewW = w -- 464
		viewH = h -- 465
		uiLayer.size = Size(viewW, viewH) -- 466
		openingLayer.size = Size(viewW, viewH) -- 467
		do -- 467
			local i = 0 -- 468
			while i < levelTotal do -- 468
				levelLayers[i + 1].size = Size(viewW, viewH) -- 468
				i = i + 1 -- 468
			end -- 468
		end -- 468
		local panel = buildPanels() -- 471
		if activeIndex >= 0 then -- 471
			local keep = activeIndex -- 473
			activeIndex = -1 -- 474
			enterLevel(keep) -- 475
		else -- 475
			panel:show(progress.unlocked) -- 477
		end -- 477
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 479
	end -- 429
	Director.entry:onAppChange(function(name) -- 483
		if name == "Size" then -- 483
			relayoutForViewport() -- 484
		end -- 484
	end) -- 483
	local introSeen = loadIntroSeen() -- 492
	local forceIntro = false -- 493
	opening = nil -- 494
	startOpening = function() -- 496
		if opening == nil then -- 496
			opening = createOpening({ -- 498
				root = openingRoot, -- 499
				camera = openingCamera, -- 500
				layer = openingLayer, -- 501
				viewW = viewW, -- 502
				viewH = viewH, -- 503
				fovYDeg = View.fieldOfView, -- 504
				aspect = View.aspectRatio, -- 505
				spherePath = "Assets/Model/Sphere.gltf", -- 506
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 507
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 508
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 509
				onFinish = function() -- 510
					introHold = -1 -- 511
					if not introSeen then -- 511
						saveIntroSeen() -- 513
						introSeen = true -- 514
						print("[escape-velocity] intro seen -> saved") -- 515
					end -- 515
					if select ~= nil then -- 515
						select:show(progress.unlocked) -- 518
					end -- 518
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 519
						opening.frameIndex(), -- 519
						0 -- 519
					) or "?")) -- 519
				end -- 510
			}) -- 510
		end -- 510
		if opening == nil then -- 510
			return -- 523
		end -- 523
		Director:pushCamera(openingCamera) -- 524
		opening.start() -- 525
		print("[escape-velocity] opening start (first launch)") -- 526
	end -- 496
	local startupPanel = buildPanels() -- 529
	local enterReq = Path( -- 541
		Path(".", ".agent", "test-results"), -- 541
		"enter-request.txt" -- 541
	) -- 541
	local autoLaunchAt = -1 -- 542
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 544
	local autoFrame = 0 -- 545
	local autoVX = 0 -- 546
	local autoVY = 0 -- 547
	local autoBackAt = -1 -- 549
	local autoReenterAt = -1 -- 550
	local autoEntered = false -- 551
	introHold = -1 -- 553
	if Content:exist(enterReq) then -- 553
		local spec = Content:load(enterReq) -- 555
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 556
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 557
		if head == "intro" then -- 557
			forceIntro = true -- 559
			if at >= 0 then -- 559
				local rest = __TS__StringSubstring(spec, at + 1) -- 561
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 562
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 562
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 564
					if v ~= nil and v >= 0 then -- 564
						introHold = v -- 566
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 567
					end -- 567
				end -- 567
			end -- 567
		end -- 567
		local n = tonumber(head) -- 572
		if n ~= nil and n >= 1 and n <= levelTotal then -- 572
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 574
			enterLevel(n - 1) -- 575
			autoEntered = true -- 576
			if at >= 0 then -- 576
				local rest = __TS__StringSubstring(spec, at + 1) -- 578
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 578
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 583
					if f ~= nil and f >= 0 then -- 583
						autoArmAt = f -- 585
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 586
					end -- 586
				else -- 586
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 589
					local c2 = (string.find( -- 590
						rest, -- 590
						":", -- 590
						math.max(c1 + 1 + 1, 1), -- 590
						true -- 590
					) or 0) - 1 -- 590
					if c1 > 0 and c2 > c1 then -- 590
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 592
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 593
						local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 594
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 594
							autoLaunchAt = frames -- 596
							autoVX = vx -- 597
							autoVY = vy -- 598
							print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 599
						end -- 599
					end -- 599
				end -- 599
			end -- 599
		end -- 599
	end -- 599
	if autoEntered then -- 599
		print("[escape-velocity] opening skipped (auto enter)") -- 610
	elseif forceIntro or not introSeen then -- 610
		startOpening() -- 612
	else -- 612
		startupPanel:show(progress.unlocked) -- 614
		print("[escape-velocity] opening skipped (already seen)") -- 615
	end -- 615
	threadLoop(function() -- 620
		if opening ~= nil and opening.running() then -- 620
			if introHold < 0 or opening.frameIndex() < introHold then -- 620
				opening.step() -- 624
			end -- 624
			if App.deltaTime > 0.05 then -- 624
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 628
					opening.frameIndex(), -- 628
					0 -- 628
				)) -- 628
			end -- 628
		end -- 628
		local runtime = activeRuntime() -- 632
		if runtime ~= nil then -- 632
			runtime.game:update(App.deltaTime) -- 634
			if runtime.levelHasTimeWindow then -- 634
				runtime.aim:setDate( -- 637
					runtime.game:dateNow(), -- 637
					runtime.dateSpan -- 637
				) -- 637
			end -- 637
			local phaseNow = runtime.game:phase() -- 641
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 642
			runtime.aim:update(App.deltaTime) -- 643
			runtime.aim:setArmed(runtime.game:armed()) -- 645
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 647
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 647
				autoFrame = autoFrame + 1 -- 650
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 650
					autoArmAt = -1 -- 653
					print("[escape-velocity] auto arm (enter-request)") -- 654
					runtime.game:aimReady() -- 655
				end -- 655
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 655
					autoLaunchAt = -1 -- 658
					print("[escape-velocity] auto launch") -- 659
					runtime.game:launch({x = autoVX, y = autoVY}) -- 660
					autoBackAt = autoFrame + 320 -- 661
					autoReenterAt = autoFrame + 380 -- 662
				end -- 662
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 662
					autoBackAt = -1 -- 666
					if runtime.game:backToSelect() then -- 666
						print("[escape-velocity] auto back to select") -- 667
					end -- 667
				end -- 667
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 667
					autoReenterAt = -1 -- 670
					print("[escape-velocity] auto re-enter") -- 671
					enterLevel(0) -- 672
				end -- 672
			end -- 672
		end -- 672
		return false -- 677
	end) -- 620
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 681
end -- 681
return ____exports -- 681
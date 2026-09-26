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
local levelTotal = levelCount() -- 51
if levelTotal <= 0 then -- 51
	print("[escape-velocity] FATAL: no level data") -- 54
else -- 54
	local opening, startOpening, introHold -- 54
	local viewW = View.size.width -- 56
	local viewH = View.size.height -- 57
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 60
	local levelLayers = {} -- 66
	do -- 66
		local i = 0 -- 67
		while i < levelTotal do -- 67
			local layer = Node() -- 68
			layer.size = Size(viewW, viewH) -- 69
			layer.anchor = Vec2(0.5, 0.5) -- 70
			layer.position = Vec2(0, 0) -- 71
			Director.ui:addChild(layer) -- 72
			levelLayers[#levelLayers + 1] = layer -- 73
			i = i + 1 -- 67
		end -- 67
	end -- 67
	local openingLayer = Node() -- 78
	openingLayer.size = Size(viewW, viewH) -- 79
	openingLayer.anchor = Vec2(0.5, 0.5) -- 80
	openingLayer.position = Vec2(0, 0) -- 81
	Director.ui:addChild(openingLayer) -- 82
	local openingRoot = Node3D() -- 85
	openingRoot.visible = false -- 86
	Director.entry:addChild(openingRoot) -- 87
	local openingCamera = Camera3D() -- 88
	local uiLayer = Node() -- 91
	uiLayer.size = Size(viewW, viewH) -- 92
	uiLayer.anchor = Vec2(0.5, 0.5) -- 93
	uiLayer.position = Vec2(0, 0) -- 94
	Director.ui:addChild(uiLayer) -- 95
	local levelNames = {} -- 98
	do -- 98
		local i = 0 -- 99
		while i < levelTotal do -- 99
			local def = getLevel(i) -- 100
			local title = def ~= nil and def.title or "" -- 101
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 102
			i = i + 1 -- 99
		end -- 99
	end -- 99
	local levelEntries = {} -- 104
	do -- 104
		local i = 0 -- 105
		while i < levelTotal do -- 105
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 105
			i = i + 1 -- 105
		end -- 105
	end -- 105
	local progress = loadProgress(levelTotal) -- 108
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 109
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 110
	local slots = {} -- 112
	do -- 112
		local i = 0 -- 113
		while i < levelTotal do -- 113
			slots[#slots + 1] = {built = false, runtime = nil} -- 113
			i = i + 1 -- 113
		end -- 113
	end -- 113
	local activeIndex = -1 -- 115
	local select = nil -- 116
	local resultPanel = nil -- 117
	local function activeRuntime() -- 119
		if activeIndex < 0 then -- 119
			return nil -- 120
		end -- 120
		return slots[activeIndex + 1].runtime -- 121
	end -- 119
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 129
		do -- 129
			local i = 0 -- 130
			while i < levelTotal do -- 130
				do -- 130
					local slot = slots[i + 1] -- 131
					levelLayers[i + 1].visible = i == index -- 134
					if slot.runtime == nil then -- 134
						goto __continue16 -- 135
					end -- 135
					local active = i == index -- 136
					slot.runtime.world.visible = active -- 137
					slot.runtime.aim:setEnabled(active) -- 138
					if active then -- 138
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 140
					end -- 140
				end -- 140
				::__continue16:: -- 140
				i = i + 1 -- 130
			end -- 130
		end -- 130
	end -- 129
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 149
		local slot = slots[index + 1] -- 150
		if slot.built and slot.runtime ~= nil then -- 150
			return slot.runtime -- 151
		end -- 151
		local def = getLevel(index) -- 153
		if def == nil then -- 153
			return nil -- 154
		end -- 154
		local bodies = scaledPlanets(def) -- 156
		local level = { -- 157
			bodies = bodies, -- 158
			probeStart = def.probeStart, -- 159
			probeVel0 = def.probeVel0, -- 161
			goal = def.goal, -- 162
			escapeRadius = def.escapeRadius, -- 163
			maxSteps = def.maxSteps -- 164
		} -- 164
		local world = Node3D() -- 167
		Director.entry:addChild(world) -- 168
		world.visible = false -- 169
		local ____buildScene_4 = buildScene -- 171
		local ____bodies_1 = bodies -- 173
		local ____def_visuals_2 = def.visuals -- 174
		local ____level_probeStart_3 = level.probeStart -- 175
		local ____temp_0 -- 187
		if def.homeAnchor == false then -- 187
			____temp_0 = nil -- 187
		else -- 187
			____temp_0 = {x = level.probeStart.x, y = level.probeStart.y + 4.2} -- 187
		end -- 187
		local scene = ____buildScene_4({ -- 171
			root = world, -- 172
			bodies = ____bodies_1, -- 173
			visuals = ____def_visuals_2, -- 174
			probeStart = ____level_probeStart_3, -- 175
			probeScale = 1.2, -- 180
			spherePath = "Assets/Model/Sphere.gltf", -- 181
			ringPath = "Assets/Model/Ring.gltf", -- 182
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 183
			home = ____temp_0, -- 187
			homeRadius = def.homeRadius, -- 188
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 190
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 191
		}) -- 191
		if scene == nil then -- 191
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 194
			return nil -- 195
		end -- 195
		local camera = Camera3D() -- 198
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 201
		local trajectory = createTrajectoryView( -- 202
			levelLayers[index + 1], -- 202
			trajectoryOptions() -- 202
		) -- 202
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 204
		local game = createGame( -- 206
			level, -- 206
			{ -- 206
				scene = scene, -- 207
				camera = camera, -- 208
				rig = rig, -- 209
				trajectory = trajectory, -- 210
				aim = aim, -- 211
				viewW = viewW, -- 212
				viewH = viewH, -- 213
				fovYDeg = View.fieldOfView, -- 214
				aspect = View.aspectRatio, -- 215
				onPhase = function(____, p) -- 216
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 217
				end, -- 216
				onResult = function(____, r) -- 219
					if r == "success" then -- 219
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 222
						if next ~= progress.unlocked then -- 222
							progress = {unlocked = next} -- 224
							saveProgress(progress) -- 225
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 226
						end -- 226
					end -- 226
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 229
					if resultPanel ~= nil then -- 229
						resultPanel:show(r, levelNames[index + 1]) -- 230
					end -- 230
				end -- 219
			} -- 219
		) -- 219
		aim:onDrag(function(a) -- 237
			game:onAimDrag(a) -- 237
		end) -- 237
		aim:onRelease(function(a) -- 238
			game:launch(a.velocity) -- 238
		end) -- 238
		aim:onBrake(function(on) -- 240
			game:setBrakeMode(on) -- 241
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 242
		end) -- 240
		aim:setBrake(game:brakeMode()) -- 244
		local runtime = { -- 246
			index = index, -- 247
			name = levelNames[index + 1], -- 248
			world = world, -- 249
			camera = camera, -- 250
			game = game, -- 251
			aim = aim, -- 252
			trajectory = trajectory -- 253
		} -- 253
		slot.built = true -- 255
		slot.runtime = runtime -- 256
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 257
		return runtime -- 258
	end -- 149
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 262
		local runtime = ensureLevel(index) -- 263
		if runtime == nil then -- 263
			return -- 264
		end -- 264
		local wasActive = activeIndex == index -- 267
		if opening ~= nil then -- 267
			opening.hide() -- 269
		end -- 269
		if select ~= nil then -- 269
			select:hide() -- 270
		end -- 270
		activeIndex = index -- 271
		showOnlyLevel(index) -- 272
		if not wasActive then -- 272
			Director:pushCamera(runtime.camera) -- 273
		end -- 273
		runtime.game:startLevel() -- 274
		print("[escape-velocity] enter " .. runtime.name) -- 275
	end -- 262
	local function onRetryTap() -- 278
		if resultPanel ~= nil then -- 278
			resultPanel:hide() -- 279
		end -- 279
		local runtime = activeRuntime() -- 280
		if runtime ~= nil then -- 280
			runtime.game:retry() -- 281
		end -- 281
	end -- 278
	local function onBackToSelectTap() -- 284
		local runtime = activeRuntime() -- 285
		if runtime == nil then -- 285
			return -- 286
		end -- 286
		if not runtime.game:backToSelect() then -- 286
			return -- 288
		end -- 288
		runtime.world.visible = false -- 289
		runtime.aim:setEnabled(false) -- 290
		if resultPanel ~= nil then -- 290
			resultPanel:hide() -- 291
		end -- 291
		progress = loadProgress(levelTotal) -- 293
		if select ~= nil then -- 293
			select:show(progress.unlocked) -- 294
		end -- 294
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 295
	end -- 284
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 308
		resultPanel = createResultPanel( -- 309
			uiLayer, -- 309
			viewW, -- 309
			viewH, -- 309
			{ -- 309
				onRetry = function() return onRetryTap() end, -- 310
				onBackToSelect = function() return onBackToSelectTap() end -- 311
			} -- 311
		) -- 311
		local created = createLevelSelect( -- 313
			uiLayer, -- 313
			viewW, -- 313
			viewH, -- 313
			{ -- 313
				levels = levelEntries, -- 314
				onPick = function(____, index) -- 315
					if select ~= nil then -- 315
						select:hide() -- 316
					end -- 316
					enterLevel(index) -- 317
				end, -- 315
				onReplayIntro = function() -- 320
					if select ~= nil then -- 320
						select:hide() -- 321
					end -- 321
					startOpening() -- 322
					print("[escape-velocity] opening replay (user)") -- 323
				end -- 320
			} -- 320
		) -- 320
		select = created -- 326
		return created -- 327
	end -- 308
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 340
		local w = View.size.width -- 341
		local h = View.size.height -- 342
		if w == viewW and h == viewH then -- 342
			return -- 343
		end -- 343
		if opening ~= nil then -- 343
			opening.hide() -- 349
			opening = nil -- 350
		end -- 350
		if select ~= nil then -- 350
			select:hide() -- 352
		end -- 352
		if resultPanel ~= nil then -- 352
			resultPanel:hide() -- 353
		end -- 353
		do -- 353
			local i = 0 -- 354
			while i < levelTotal do -- 354
				local slot = slots[i + 1] -- 355
				if slot.runtime ~= nil then -- 355
					slot.runtime.world.visible = false -- 357
					slot.runtime.aim:setEnabled(false) -- 358
					slot.runtime.trajectory:clearPrediction() -- 361
					slot.runtime.trajectory:clearTrail() -- 362
					slot.runtime.trajectory:clearGoalRings() -- 364
				end -- 364
				slot.built = false -- 366
				slot.runtime = nil -- 367
				i = i + 1 -- 354
			end -- 354
		end -- 354
		viewW = w -- 371
		viewH = h -- 372
		uiLayer.size = Size(viewW, viewH) -- 373
		openingLayer.size = Size(viewW, viewH) -- 374
		do -- 374
			local i = 0 -- 375
			while i < levelTotal do -- 375
				levelLayers[i + 1].size = Size(viewW, viewH) -- 375
				i = i + 1 -- 375
			end -- 375
		end -- 375
		local panel = buildPanels() -- 378
		if activeIndex >= 0 then -- 378
			local keep = activeIndex -- 380
			activeIndex = -1 -- 381
			enterLevel(keep) -- 382
		else -- 382
			panel:show(progress.unlocked) -- 384
		end -- 384
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 386
	end -- 340
	Director.entry:onAppChange(function(name) -- 390
		if name == "Size" then -- 390
			relayoutForViewport() -- 391
		end -- 391
	end) -- 390
	local introSeen = loadIntroSeen() -- 399
	local forceIntro = false -- 400
	opening = nil -- 401
	startOpening = function() -- 403
		if opening == nil then -- 403
			opening = createOpening({ -- 405
				root = openingRoot, -- 406
				camera = openingCamera, -- 407
				layer = openingLayer, -- 408
				viewW = viewW, -- 409
				viewH = viewH, -- 410
				fovYDeg = View.fieldOfView, -- 411
				aspect = View.aspectRatio, -- 412
				spherePath = "Assets/Model/Sphere.gltf", -- 413
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 414
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 415
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 416
				onFinish = function() -- 417
					introHold = -1 -- 418
					if not introSeen then -- 418
						saveIntroSeen() -- 420
						introSeen = true -- 421
						print("[escape-velocity] intro seen -> saved") -- 422
					end -- 422
					if select ~= nil then -- 422
						select:show(progress.unlocked) -- 425
					end -- 425
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 426
						opening.frameIndex(), -- 426
						0 -- 426
					) or "?")) -- 426
				end -- 417
			}) -- 417
		end -- 417
		if opening == nil then -- 417
			return -- 430
		end -- 430
		Director:pushCamera(openingCamera) -- 431
		opening.start() -- 432
		print("[escape-velocity] opening start (first launch)") -- 433
	end -- 403
	local startupPanel = buildPanels() -- 436
	local enterReq = Path( -- 448
		Path(".", ".agent", "test-results"), -- 448
		"enter-request.txt" -- 448
	) -- 448
	local autoLaunchAt = -1 -- 449
	local autoFrame = 0 -- 450
	local autoVX = 0 -- 451
	local autoVY = 0 -- 452
	local autoBackAt = -1 -- 454
	local autoReenterAt = -1 -- 455
	local autoEntered = false -- 456
	introHold = -1 -- 458
	if Content:exist(enterReq) then -- 458
		local spec = Content:load(enterReq) -- 460
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 461
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 462
		if head == "intro" then -- 462
			forceIntro = true -- 464
			if at >= 0 then -- 464
				local rest = __TS__StringSubstring(spec, at + 1) -- 466
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 467
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 467
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 469
					if v ~= nil and v >= 0 then -- 469
						introHold = v -- 471
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 472
					end -- 472
				end -- 472
			end -- 472
		end -- 472
		local n = tonumber(head) -- 477
		if n ~= nil and n >= 1 and n <= levelTotal then -- 477
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 479
			enterLevel(n - 1) -- 480
			autoEntered = true -- 481
			if at >= 0 then -- 481
				local rest = __TS__StringSubstring(spec, at + 1) -- 483
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 484
				local c2 = (string.find( -- 485
					rest, -- 485
					":", -- 485
					math.max(c1 + 1 + 1, 1), -- 485
					true -- 485
				) or 0) - 1 -- 485
				if c1 > 0 and c2 > c1 then -- 485
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 487
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 488
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 489
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 489
						autoLaunchAt = frames -- 491
						autoVX = vx -- 492
						autoVY = vy -- 493
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 494
					end -- 494
				end -- 494
			end -- 494
		end -- 494
	end -- 494
	if autoEntered then -- 494
		print("[escape-velocity] opening skipped (auto enter)") -- 504
	elseif forceIntro or not introSeen then -- 504
		startOpening() -- 506
	else -- 506
		startupPanel:show(progress.unlocked) -- 508
		print("[escape-velocity] opening skipped (already seen)") -- 509
	end -- 509
	threadLoop(function() -- 514
		if opening ~= nil and opening.running() then -- 514
			if introHold < 0 or opening.frameIndex() < introHold then -- 514
				opening.step() -- 518
			end -- 518
			if App.deltaTime > 0.05 then -- 518
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 522
					opening.frameIndex(), -- 522
					0 -- 522
				)) -- 522
			end -- 522
		end -- 522
		local runtime = activeRuntime() -- 526
		if runtime ~= nil then -- 526
			runtime.game:update(App.deltaTime) -- 528
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 528
				autoFrame = autoFrame + 1 -- 531
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 531
					autoLaunchAt = -1 -- 533
					print("[escape-velocity] auto launch") -- 534
					runtime.game:launch({x = autoVX, y = autoVY}) -- 535
					autoBackAt = autoFrame + 320 -- 536
					autoReenterAt = autoFrame + 380 -- 537
				end -- 537
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 537
					autoBackAt = -1 -- 541
					if runtime.game:backToSelect() then -- 541
						print("[escape-velocity] auto back to select") -- 542
					end -- 542
				end -- 542
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 542
					autoReenterAt = -1 -- 545
					print("[escape-velocity] auto re-enter") -- 546
					enterLevel(0) -- 547
				end -- 547
			end -- 547
		end -- 547
		return false -- 552
	end) -- 514
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 556
end -- 556
return ____exports -- 556
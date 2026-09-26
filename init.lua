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
	local resultIndex = -1 -- 122
	local function activeRuntime() -- 124
		if activeIndex < 0 then -- 124
			return nil -- 125
		end -- 125
		return slots[activeIndex + 1].runtime -- 126
	end -- 124
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 134
		do -- 134
			local i = 0 -- 135
			while i < levelTotal do -- 135
				do -- 135
					local slot = slots[i + 1] -- 136
					levelLayers[i + 1].visible = i == index -- 139
					if slot.runtime == nil then -- 139
						goto __continue16 -- 140
					end -- 140
					local active = i == index -- 141
					slot.runtime.world.visible = active -- 142
					slot.runtime.aim:setEnabled(active) -- 143
					if active then -- 143
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 145
					end -- 145
				end -- 145
				::__continue16:: -- 145
				i = i + 1 -- 135
			end -- 135
		end -- 135
	end -- 134
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 154
		local game -- 154
		local slot = slots[index + 1] -- 155
		if slot.built and slot.runtime ~= nil then -- 155
			return slot.runtime -- 156
		end -- 156
		local def = getLevel(index) -- 158
		if def == nil then -- 158
			return nil -- 159
		end -- 159
		local bodies = scaledPlanets(def) -- 161
		local level = { -- 162
			bodies = bodies, -- 163
			probeStart = def.probeStart, -- 164
			probeVel0 = def.probeVel0, -- 166
			goal = def.goal, -- 167
			escapeRadius = def.escapeRadius, -- 168
			maxSteps = def.maxSteps -- 169
		} -- 169
		local world = Node3D() -- 172
		Director.entry:addChild(world) -- 173
		world.visible = false -- 174
		local ____buildScene_4 = buildScene -- 176
		local ____bodies_1 = bodies -- 178
		local ____def_visuals_2 = def.visuals -- 179
		local ____level_probeStart_3 = level.probeStart -- 180
		local ____temp_0 -- 192
		if def.homeAnchor == false then -- 192
			____temp_0 = nil -- 192
		else -- 192
			____temp_0 = {x = level.probeStart.x, y = level.probeStart.y + 4.2} -- 192
		end -- 192
		local scene = ____buildScene_4({ -- 176
			root = world, -- 177
			bodies = ____bodies_1, -- 178
			visuals = ____def_visuals_2, -- 179
			probeStart = ____level_probeStart_3, -- 180
			probeScale = 1.2, -- 185
			spherePath = "Assets/Model/Sphere.gltf", -- 186
			ringPath = "Assets/Model/Ring.gltf", -- 187
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 188
			home = ____temp_0, -- 192
			homeRadius = def.homeRadius, -- 193
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 195
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 196
		}) -- 196
		if scene == nil then -- 196
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 199
			return nil -- 200
		end -- 200
		local camera = Camera3D() -- 203
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 206
		local trajectory = createTrajectoryView( -- 207
			levelLayers[index + 1], -- 207
			trajectoryOptions() -- 207
		) -- 207
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 209
		aim:setBurnInfo(0, def.dvBudget) -- 211
		aim:setDate(0, def.timeWindow ~= nil and def.timeWindow.span or 0) -- 213
		aim:onDate(function(t0) -- 214
			game:setLaunchDate(t0) -- 215
			print(((("[escape-velocity] launch date t0=" .. __TS__NumberToFixed(t0, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 216
		end) -- 214
		game = createGame( -- 219
			level, -- 219
			{ -- 219
				scene = scene, -- 220
				camera = camera, -- 221
				rig = rig, -- 222
				trajectory = trajectory, -- 223
				aim = aim, -- 224
				viewW = viewW, -- 225
				viewH = viewH, -- 226
				fovYDeg = View.fieldOfView, -- 227
				aspect = View.aspectRatio, -- 228
				onPhase = function(____, p) -- 229
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 230
				end, -- 229
				onResult = function(____, r) -- 232
					if r == "success" then -- 232
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 235
						if next ~= progress.unlocked then -- 235
							progress = {unlocked = next} -- 237
							saveProgress(progress) -- 238
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 239
						end -- 239
					end -- 239
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 242
					resultIndex = index -- 243
					if resultPanel ~= nil then -- 243
						resultPanel:show(r, levelNames[index + 1]) -- 244
					end -- 244
				end -- 232
			} -- 232
		) -- 232
		aim:onDrag(function(a) -- 251
			game:onAimDrag(a) -- 252
			aim:setBurnInfo( -- 254
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 254
				def.dvBudget -- 254
			) -- 254
		end) -- 251
		aim:onRelease(function(a) -- 256
			game:launch(a.velocity) -- 256
		end) -- 256
		aim:onBrake(function(on) -- 258
			game:setBrakeMode(on) -- 259
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 260
		end) -- 258
		aim:setBrake(game:brakeMode()) -- 262
		local runtime = { -- 264
			index = index, -- 265
			name = levelNames[index + 1], -- 266
			world = world, -- 267
			camera = camera, -- 268
			game = game, -- 269
			aim = aim, -- 270
			trajectory = trajectory -- 271
		} -- 271
		slot.built = true -- 273
		slot.runtime = runtime -- 274
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 275
		return runtime -- 276
	end -- 154
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 280
		local runtime = ensureLevel(index) -- 281
		if runtime == nil then -- 281
			return -- 282
		end -- 282
		local wasActive = activeIndex == index -- 285
		if opening ~= nil then -- 285
			opening.hide() -- 287
		end -- 287
		if select ~= nil then -- 287
			select:hide() -- 288
		end -- 288
		activeIndex = index -- 289
		showOnlyLevel(index) -- 290
		if not wasActive then -- 290
			Director:pushCamera(runtime.camera) -- 291
		end -- 291
		runtime.game:startLevel() -- 292
		print("[escape-velocity] enter " .. runtime.name) -- 293
	end -- 280
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 297
		if resultIndex >= 0 and resultIndex < levelTotal then -- 297
			local rt = slots[resultIndex + 1].runtime -- 299
			if rt ~= nil then -- 299
				return rt -- 300
			end -- 300
		end -- 300
		return activeRuntime() -- 302
	end -- 297
	local function onRetryTap() -- 305
		local rt = resultRuntime() -- 307
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 308
		if resultPanel ~= nil then -- 308
			resultPanel:hide() -- 309
		end -- 309
		if rt ~= nil then -- 309
			rt.game:retry() -- 310
		end -- 310
	end -- 305
	local function onBackToSelectTap() -- 313
		local rt = resultRuntime() -- 314
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 315
		if rt == nil then -- 315
			return -- 316
		end -- 316
		local runtime = rt -- 317
		if not runtime.game:backToSelect() then -- 317
			return -- 319
		end -- 319
		runtime.world.visible = false -- 320
		runtime.aim:setEnabled(false) -- 321
		if resultPanel ~= nil then -- 321
			resultPanel:hide() -- 322
		end -- 322
		progress = loadProgress(levelTotal) -- 324
		if select ~= nil then -- 324
			select:show(progress.unlocked) -- 325
		end -- 325
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 326
	end -- 313
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 339
		resultPanel = createResultPanel( -- 340
			uiLayer, -- 340
			viewW, -- 340
			viewH, -- 340
			{ -- 340
				onRetry = function() return onRetryTap() end, -- 341
				onBackToSelect = function() return onBackToSelectTap() end -- 342
			} -- 342
		) -- 342
		local created = createLevelSelect( -- 344
			uiLayer, -- 344
			viewW, -- 344
			viewH, -- 344
			{ -- 344
				levels = levelEntries, -- 345
				onPick = function(____, index) -- 346
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 347
					if select ~= nil then -- 347
						select:hide() -- 348
					end -- 348
					enterLevel(index) -- 349
				end, -- 346
				onReplayIntro = function() -- 352
					if select ~= nil then -- 352
						select:hide() -- 353
					end -- 353
					startOpening() -- 354
					print("[escape-velocity] opening replay (user)") -- 355
				end -- 352
			} -- 352
		) -- 352
		select = created -- 358
		return created -- 359
	end -- 339
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 372
		local w = View.size.width -- 373
		local h = View.size.height -- 374
		if w == viewW and h == viewH then -- 374
			return -- 375
		end -- 375
		if opening ~= nil then -- 375
			opening.hide() -- 381
			opening = nil -- 382
		end -- 382
		if select ~= nil then -- 382
			select:hide() -- 384
		end -- 384
		if resultPanel ~= nil then -- 384
			resultPanel:hide() -- 385
		end -- 385
		do -- 385
			local i = 0 -- 386
			while i < levelTotal do -- 386
				local slot = slots[i + 1] -- 387
				if slot.runtime ~= nil then -- 387
					slot.runtime.world.visible = false -- 389
					slot.runtime.aim:setEnabled(false) -- 390
					slot.runtime.trajectory:clearPrediction() -- 393
					slot.runtime.trajectory:clearTrail() -- 394
					slot.runtime.trajectory:clearGoalRings() -- 396
				end -- 396
				slot.built = false -- 398
				slot.runtime = nil -- 399
				i = i + 1 -- 386
			end -- 386
		end -- 386
		viewW = w -- 403
		viewH = h -- 404
		uiLayer.size = Size(viewW, viewH) -- 405
		openingLayer.size = Size(viewW, viewH) -- 406
		do -- 406
			local i = 0 -- 407
			while i < levelTotal do -- 407
				levelLayers[i + 1].size = Size(viewW, viewH) -- 407
				i = i + 1 -- 407
			end -- 407
		end -- 407
		local panel = buildPanels() -- 410
		if activeIndex >= 0 then -- 410
			local keep = activeIndex -- 412
			activeIndex = -1 -- 413
			enterLevel(keep) -- 414
		else -- 414
			panel:show(progress.unlocked) -- 416
		end -- 416
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 418
	end -- 372
	Director.entry:onAppChange(function(name) -- 422
		if name == "Size" then -- 422
			relayoutForViewport() -- 423
		end -- 423
	end) -- 422
	local introSeen = loadIntroSeen() -- 431
	local forceIntro = false -- 432
	opening = nil -- 433
	startOpening = function() -- 435
		if opening == nil then -- 435
			opening = createOpening({ -- 437
				root = openingRoot, -- 438
				camera = openingCamera, -- 439
				layer = openingLayer, -- 440
				viewW = viewW, -- 441
				viewH = viewH, -- 442
				fovYDeg = View.fieldOfView, -- 443
				aspect = View.aspectRatio, -- 444
				spherePath = "Assets/Model/Sphere.gltf", -- 445
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 446
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 447
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 448
				onFinish = function() -- 449
					introHold = -1 -- 450
					if not introSeen then -- 450
						saveIntroSeen() -- 452
						introSeen = true -- 453
						print("[escape-velocity] intro seen -> saved") -- 454
					end -- 454
					if select ~= nil then -- 454
						select:show(progress.unlocked) -- 457
					end -- 457
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 458
						opening.frameIndex(), -- 458
						0 -- 458
					) or "?")) -- 458
				end -- 449
			}) -- 449
		end -- 449
		if opening == nil then -- 449
			return -- 462
		end -- 462
		Director:pushCamera(openingCamera) -- 463
		opening.start() -- 464
		print("[escape-velocity] opening start (first launch)") -- 465
	end -- 435
	local startupPanel = buildPanels() -- 468
	local enterReq = Path( -- 480
		Path(".", ".agent", "test-results"), -- 480
		"enter-request.txt" -- 480
	) -- 480
	local autoLaunchAt = -1 -- 481
	local autoFrame = 0 -- 482
	local autoVX = 0 -- 483
	local autoVY = 0 -- 484
	local autoBackAt = -1 -- 486
	local autoReenterAt = -1 -- 487
	local autoEntered = false -- 488
	introHold = -1 -- 490
	if Content:exist(enterReq) then -- 490
		local spec = Content:load(enterReq) -- 492
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 493
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 494
		if head == "intro" then -- 494
			forceIntro = true -- 496
			if at >= 0 then -- 496
				local rest = __TS__StringSubstring(spec, at + 1) -- 498
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 499
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 499
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 501
					if v ~= nil and v >= 0 then -- 501
						introHold = v -- 503
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 504
					end -- 504
				end -- 504
			end -- 504
		end -- 504
		local n = tonumber(head) -- 509
		if n ~= nil and n >= 1 and n <= levelTotal then -- 509
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 511
			enterLevel(n - 1) -- 512
			autoEntered = true -- 513
			if at >= 0 then -- 513
				local rest = __TS__StringSubstring(spec, at + 1) -- 515
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 516
				local c2 = (string.find( -- 517
					rest, -- 517
					":", -- 517
					math.max(c1 + 1 + 1, 1), -- 517
					true -- 517
				) or 0) - 1 -- 517
				if c1 > 0 and c2 > c1 then -- 517
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 519
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 520
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 521
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 521
						autoLaunchAt = frames -- 523
						autoVX = vx -- 524
						autoVY = vy -- 525
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 526
					end -- 526
				end -- 526
			end -- 526
		end -- 526
	end -- 526
	if autoEntered then -- 526
		print("[escape-velocity] opening skipped (auto enter)") -- 536
	elseif forceIntro or not introSeen then -- 536
		startOpening() -- 538
	else -- 538
		startupPanel:show(progress.unlocked) -- 540
		print("[escape-velocity] opening skipped (already seen)") -- 541
	end -- 541
	threadLoop(function() -- 546
		if opening ~= nil and opening.running() then -- 546
			if introHold < 0 or opening.frameIndex() < introHold then -- 546
				opening.step() -- 550
			end -- 550
			if App.deltaTime > 0.05 then -- 550
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 554
					opening.frameIndex(), -- 554
					0 -- 554
				)) -- 554
			end -- 554
		end -- 554
		local runtime = activeRuntime() -- 558
		if runtime ~= nil then -- 558
			runtime.game:update(App.deltaTime) -- 560
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 560
				autoFrame = autoFrame + 1 -- 563
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 563
					autoLaunchAt = -1 -- 565
					print("[escape-velocity] auto launch") -- 566
					runtime.game:launch({x = autoVX, y = autoVY}) -- 567
					autoBackAt = autoFrame + 320 -- 568
					autoReenterAt = autoFrame + 380 -- 569
				end -- 569
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 569
					autoBackAt = -1 -- 573
					if runtime.game:backToSelect() then -- 573
						print("[escape-velocity] auto back to select") -- 574
					end -- 574
				end -- 574
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 574
					autoReenterAt = -1 -- 577
					print("[escape-velocity] auto re-enter") -- 578
					enterLevel(0) -- 579
				end -- 579
			end -- 579
		end -- 579
		return false -- 584
	end) -- 546
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 588
end -- 588
return ____exports -- 588
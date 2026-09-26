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
				end -- 138
				::__continue16:: -- 138
				i = i + 1 -- 130
			end -- 130
		end -- 130
	end -- 129
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 147
		local slot = slots[index + 1] -- 148
		if slot.built and slot.runtime ~= nil then -- 148
			return slot.runtime -- 149
		end -- 149
		local def = getLevel(index) -- 151
		if def == nil then -- 151
			return nil -- 152
		end -- 152
		local bodies = scaledPlanets(def) -- 154
		local level = { -- 155
			bodies = bodies, -- 156
			probeStart = def.probeStart, -- 157
			probeVel0 = def.probeVel0, -- 159
			goal = def.goal, -- 160
			escapeRadius = def.escapeRadius, -- 161
			maxSteps = def.maxSteps -- 162
		} -- 162
		local world = Node3D() -- 165
		Director.entry:addChild(world) -- 166
		world.visible = false -- 167
		local ____buildScene_4 = buildScene -- 169
		local ____bodies_1 = bodies -- 171
		local ____def_visuals_2 = def.visuals -- 172
		local ____level_probeStart_3 = level.probeStart -- 173
		local ____temp_0 -- 185
		if def.homeAnchor == false then -- 185
			____temp_0 = nil -- 185
		else -- 185
			____temp_0 = {x = level.probeStart.x, y = level.probeStart.y + 4.2} -- 185
		end -- 185
		local scene = ____buildScene_4({ -- 169
			root = world, -- 170
			bodies = ____bodies_1, -- 171
			visuals = ____def_visuals_2, -- 172
			probeStart = ____level_probeStart_3, -- 173
			probeScale = 1.2, -- 178
			spherePath = "Assets/Model/Sphere.gltf", -- 179
			ringPath = "Assets/Model/Ring.gltf", -- 180
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 181
			home = ____temp_0, -- 185
			homeRadius = def.homeRadius, -- 186
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 188
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 189
		}) -- 189
		if scene == nil then -- 189
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 192
			return nil -- 193
		end -- 193
		local camera = Camera3D() -- 196
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 199
		local trajectory = createTrajectoryView( -- 200
			levelLayers[index + 1], -- 200
			trajectoryOptions() -- 200
		) -- 200
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 202
		local game = createGame( -- 204
			level, -- 204
			{ -- 204
				scene = scene, -- 205
				camera = camera, -- 206
				rig = rig, -- 207
				trajectory = trajectory, -- 208
				aim = aim, -- 209
				viewW = viewW, -- 210
				viewH = viewH, -- 211
				fovYDeg = View.fieldOfView, -- 212
				aspect = View.aspectRatio, -- 213
				onPhase = function(____, p) -- 214
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 215
				end, -- 214
				onResult = function(____, r) -- 217
					if r == "success" then -- 217
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 220
						if next ~= progress.unlocked then -- 220
							progress = {unlocked = next} -- 222
							saveProgress(progress) -- 223
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 224
						end -- 224
					end -- 224
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 227
					if resultPanel ~= nil then -- 227
						resultPanel:show(r, levelNames[index + 1]) -- 228
					end -- 228
				end -- 217
			} -- 217
		) -- 217
		aim:onDrag(function(a) -- 235
			game:onAimDrag(a) -- 235
		end) -- 235
		aim:onRelease(function(a) -- 236
			game:launch(a.velocity) -- 236
		end) -- 236
		local runtime = { -- 238
			index = index, -- 239
			name = levelNames[index + 1], -- 240
			world = world, -- 241
			camera = camera, -- 242
			game = game, -- 243
			aim = aim, -- 244
			trajectory = trajectory -- 245
		} -- 245
		slot.built = true -- 247
		slot.runtime = runtime -- 248
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 249
		return runtime -- 250
	end -- 147
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 254
		local runtime = ensureLevel(index) -- 255
		if runtime == nil then -- 255
			return -- 256
		end -- 256
		local wasActive = activeIndex == index -- 259
		if opening ~= nil then -- 259
			opening.hide() -- 261
		end -- 261
		if select ~= nil then -- 261
			select:hide() -- 262
		end -- 262
		activeIndex = index -- 263
		showOnlyLevel(index) -- 264
		if not wasActive then -- 264
			Director:pushCamera(runtime.camera) -- 265
		end -- 265
		runtime.game:startLevel() -- 266
		print("[escape-velocity] enter " .. runtime.name) -- 267
	end -- 254
	local function onRetryTap() -- 270
		if resultPanel ~= nil then -- 270
			resultPanel:hide() -- 271
		end -- 271
		local runtime = activeRuntime() -- 272
		if runtime ~= nil then -- 272
			runtime.game:retry() -- 273
		end -- 273
	end -- 270
	local function onBackToSelectTap() -- 276
		local runtime = activeRuntime() -- 277
		if runtime == nil then -- 277
			return -- 278
		end -- 278
		if not runtime.game:backToSelect() then -- 278
			return -- 280
		end -- 280
		runtime.world.visible = false -- 281
		runtime.aim:setEnabled(false) -- 282
		if resultPanel ~= nil then -- 282
			resultPanel:hide() -- 283
		end -- 283
		progress = loadProgress(levelTotal) -- 285
		if select ~= nil then -- 285
			select:show(progress.unlocked) -- 286
		end -- 286
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 287
	end -- 276
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 300
		resultPanel = createResultPanel( -- 301
			uiLayer, -- 301
			viewW, -- 301
			viewH, -- 301
			{ -- 301
				onRetry = function() return onRetryTap() end, -- 302
				onBackToSelect = function() return onBackToSelectTap() end -- 303
			} -- 303
		) -- 303
		local created = createLevelSelect( -- 305
			uiLayer, -- 305
			viewW, -- 305
			viewH, -- 305
			{ -- 305
				levels = levelEntries, -- 306
				onPick = function(____, index) -- 307
					if select ~= nil then -- 307
						select:hide() -- 308
					end -- 308
					enterLevel(index) -- 309
				end, -- 307
				onReplayIntro = function() -- 312
					if select ~= nil then -- 312
						select:hide() -- 313
					end -- 313
					startOpening() -- 314
					print("[escape-velocity] opening replay (user)") -- 315
				end -- 312
			} -- 312
		) -- 312
		select = created -- 318
		return created -- 319
	end -- 300
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 332
		local w = View.size.width -- 333
		local h = View.size.height -- 334
		if w == viewW and h == viewH then -- 334
			return -- 335
		end -- 335
		if opening ~= nil then -- 335
			opening.hide() -- 341
			opening = nil -- 342
		end -- 342
		if select ~= nil then -- 342
			select:hide() -- 344
		end -- 344
		if resultPanel ~= nil then -- 344
			resultPanel:hide() -- 345
		end -- 345
		do -- 345
			local i = 0 -- 346
			while i < levelTotal do -- 346
				local slot = slots[i + 1] -- 347
				if slot.runtime ~= nil then -- 347
					slot.runtime.world.visible = false -- 349
					slot.runtime.aim:setEnabled(false) -- 350
					slot.runtime.trajectory:clearPrediction() -- 353
					slot.runtime.trajectory:clearTrail() -- 354
					slot.runtime.trajectory:clearGoalRings() -- 356
				end -- 356
				slot.built = false -- 358
				slot.runtime = nil -- 359
				i = i + 1 -- 346
			end -- 346
		end -- 346
		viewW = w -- 363
		viewH = h -- 364
		uiLayer.size = Size(viewW, viewH) -- 365
		openingLayer.size = Size(viewW, viewH) -- 366
		do -- 366
			local i = 0 -- 367
			while i < levelTotal do -- 367
				levelLayers[i + 1].size = Size(viewW, viewH) -- 367
				i = i + 1 -- 367
			end -- 367
		end -- 367
		local panel = buildPanels() -- 370
		if activeIndex >= 0 then -- 370
			local keep = activeIndex -- 372
			activeIndex = -1 -- 373
			enterLevel(keep) -- 374
		else -- 374
			panel:show(progress.unlocked) -- 376
		end -- 376
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 378
	end -- 332
	Director.entry:onAppChange(function(name) -- 382
		if name == "Size" then -- 382
			relayoutForViewport() -- 383
		end -- 383
	end) -- 382
	local introSeen = loadIntroSeen() -- 391
	local forceIntro = false -- 392
	opening = nil -- 393
	startOpening = function() -- 395
		if opening == nil then -- 395
			opening = createOpening({ -- 397
				root = openingRoot, -- 398
				camera = openingCamera, -- 399
				layer = openingLayer, -- 400
				viewW = viewW, -- 401
				viewH = viewH, -- 402
				fovYDeg = View.fieldOfView, -- 403
				aspect = View.aspectRatio, -- 404
				spherePath = "Assets/Model/Sphere.gltf", -- 405
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 406
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 407
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 408
				onFinish = function() -- 409
					introHold = -1 -- 410
					if not introSeen then -- 410
						saveIntroSeen() -- 412
						introSeen = true -- 413
						print("[escape-velocity] intro seen -> saved") -- 414
					end -- 414
					if select ~= nil then -- 414
						select:show(progress.unlocked) -- 417
					end -- 417
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 418
						opening.frameIndex(), -- 418
						0 -- 418
					) or "?")) -- 418
				end -- 409
			}) -- 409
		end -- 409
		if opening == nil then -- 409
			return -- 422
		end -- 422
		Director:pushCamera(openingCamera) -- 423
		opening.start() -- 424
		print("[escape-velocity] opening start (first launch)") -- 425
	end -- 395
	local startupPanel = buildPanels() -- 428
	local enterReq = Path( -- 440
		Path(".", ".agent", "test-results"), -- 440
		"enter-request.txt" -- 440
	) -- 440
	local autoLaunchAt = -1 -- 441
	local autoFrame = 0 -- 442
	local autoVX = 0 -- 443
	local autoVY = 0 -- 444
	local autoBackAt = -1 -- 446
	local autoReenterAt = -1 -- 447
	local autoEntered = false -- 448
	introHold = -1 -- 450
	if Content:exist(enterReq) then -- 450
		local spec = Content:load(enterReq) -- 452
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 453
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 454
		if head == "intro" then -- 454
			forceIntro = true -- 456
			if at >= 0 then -- 456
				local rest = __TS__StringSubstring(spec, at + 1) -- 458
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 459
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 459
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 461
					if v ~= nil and v >= 0 then -- 461
						introHold = v -- 463
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 464
					end -- 464
				end -- 464
			end -- 464
		end -- 464
		local n = tonumber(head) -- 469
		if n ~= nil and n >= 1 and n <= levelTotal then -- 469
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 471
			enterLevel(n - 1) -- 472
			autoEntered = true -- 473
			if at >= 0 then -- 473
				local rest = __TS__StringSubstring(spec, at + 1) -- 475
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 476
				local c2 = (string.find( -- 477
					rest, -- 477
					":", -- 477
					math.max(c1 + 1 + 1, 1), -- 477
					true -- 477
				) or 0) - 1 -- 477
				if c1 > 0 and c2 > c1 then -- 477
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 479
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 480
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 481
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 481
						autoLaunchAt = frames -- 483
						autoVX = vx -- 484
						autoVY = vy -- 485
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 486
					end -- 486
				end -- 486
			end -- 486
		end -- 486
	end -- 486
	if autoEntered then -- 486
		print("[escape-velocity] opening skipped (auto enter)") -- 496
	elseif forceIntro or not introSeen then -- 496
		startOpening() -- 498
	else -- 498
		startupPanel:show(progress.unlocked) -- 500
		print("[escape-velocity] opening skipped (already seen)") -- 501
	end -- 501
	threadLoop(function() -- 506
		if opening ~= nil and opening.running() then -- 506
			if introHold < 0 or opening.frameIndex() < introHold then -- 506
				opening.step() -- 510
			end -- 510
			if App.deltaTime > 0.05 then -- 510
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 514
					opening.frameIndex(), -- 514
					0 -- 514
				)) -- 514
			end -- 514
		end -- 514
		local runtime = activeRuntime() -- 518
		if runtime ~= nil then -- 518
			runtime.game:update(App.deltaTime) -- 520
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 520
				autoFrame = autoFrame + 1 -- 523
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 523
					autoLaunchAt = -1 -- 525
					print("[escape-velocity] auto launch") -- 526
					runtime.game:launch({x = autoVX, y = autoVY}) -- 527
					autoBackAt = autoFrame + 320 -- 528
					autoReenterAt = autoFrame + 380 -- 529
				end -- 529
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 529
					autoBackAt = -1 -- 533
					if runtime.game:backToSelect() then -- 533
						print("[escape-velocity] auto back to select") -- 534
					end -- 534
				end -- 534
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 534
					autoReenterAt = -1 -- 537
					print("[escape-velocity] auto re-enter") -- 538
					enterLevel(0) -- 539
				end -- 539
			end -- 539
		end -- 539
		return false -- 544
	end) -- 506
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 548
end -- 548
return ____exports -- 548
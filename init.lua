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
			goal = def.goal, -- 158
			escapeRadius = def.escapeRadius, -- 159
			maxSteps = def.maxSteps -- 160
		} -- 160
		local world = Node3D() -- 163
		Director.entry:addChild(world) -- 164
		world.visible = false -- 165
		local scene = buildScene({ -- 167
			root = world, -- 168
			bodies = bodies, -- 169
			visuals = def.visuals, -- 170
			probeStart = level.probeStart, -- 171
			probeScale = 1.2, -- 176
			spherePath = "Assets/Model/Sphere.gltf", -- 177
			ringPath = "Assets/Model/Ring.gltf", -- 178
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 179
			home = {x = level.probeStart.x, y = level.probeStart.y + 4.2}, -- 182
			homeRadius = def.homeRadius, -- 183
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 185
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 186
		}) -- 186
		if scene == nil then -- 186
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 189
			return nil -- 190
		end -- 190
		local camera = Camera3D() -- 193
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 196
		local trajectory = createTrajectoryView( -- 197
			levelLayers[index + 1], -- 197
			trajectoryOptions() -- 197
		) -- 197
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH, def.dvBudget) -- 199
		local game = createGame( -- 201
			level, -- 201
			{ -- 201
				scene = scene, -- 202
				camera = camera, -- 203
				rig = rig, -- 204
				trajectory = trajectory, -- 205
				aim = aim, -- 206
				viewW = viewW, -- 207
				viewH = viewH, -- 208
				fovYDeg = View.fieldOfView, -- 209
				aspect = View.aspectRatio, -- 210
				onPhase = function(____, p) -- 211
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 212
				end, -- 211
				onResult = function(____, r) -- 214
					if r == "success" then -- 214
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 217
						if next ~= progress.unlocked then -- 217
							progress = {unlocked = next} -- 219
							saveProgress(progress) -- 220
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 221
						end -- 221
					end -- 221
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 224
					if resultPanel ~= nil then -- 224
						resultPanel:show(r, levelNames[index + 1]) -- 225
					end -- 225
				end -- 214
			} -- 214
		) -- 214
		aim:onDrag(function(a) -- 232
			game:onAimDrag(a) -- 232
		end) -- 232
		aim:onRelease(function(a) -- 233
			game:launch(a.velocity) -- 233
		end) -- 233
		local runtime = { -- 235
			index = index, -- 236
			name = levelNames[index + 1], -- 237
			world = world, -- 238
			camera = camera, -- 239
			game = game, -- 240
			aim = aim, -- 241
			trajectory = trajectory -- 242
		} -- 242
		slot.built = true -- 244
		slot.runtime = runtime -- 245
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 246
		return runtime -- 247
	end -- 147
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 251
		local runtime = ensureLevel(index) -- 252
		if runtime == nil then -- 252
			return -- 253
		end -- 253
		local wasActive = activeIndex == index -- 256
		if opening ~= nil then -- 256
			opening.hide() -- 258
		end -- 258
		if select ~= nil then -- 258
			select:hide() -- 259
		end -- 259
		activeIndex = index -- 260
		showOnlyLevel(index) -- 261
		if not wasActive then -- 261
			Director:pushCamera(runtime.camera) -- 262
		end -- 262
		runtime.game:startLevel() -- 263
		print("[escape-velocity] enter " .. runtime.name) -- 264
	end -- 251
	local function onRetryTap() -- 267
		if resultPanel ~= nil then -- 267
			resultPanel:hide() -- 268
		end -- 268
		local runtime = activeRuntime() -- 269
		if runtime ~= nil then -- 269
			runtime.game:retry() -- 270
		end -- 270
	end -- 267
	local function onBackToSelectTap() -- 273
		local runtime = activeRuntime() -- 274
		if runtime == nil then -- 274
			return -- 275
		end -- 275
		if not runtime.game:backToSelect() then -- 275
			return -- 277
		end -- 277
		runtime.world.visible = false -- 278
		runtime.aim:setEnabled(false) -- 279
		if resultPanel ~= nil then -- 279
			resultPanel:hide() -- 280
		end -- 280
		progress = loadProgress(levelTotal) -- 282
		if select ~= nil then -- 282
			select:show(progress.unlocked) -- 283
		end -- 283
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 284
	end -- 273
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 297
		resultPanel = createResultPanel( -- 298
			uiLayer, -- 298
			viewW, -- 298
			viewH, -- 298
			{ -- 298
				onRetry = function() return onRetryTap() end, -- 299
				onBackToSelect = function() return onBackToSelectTap() end -- 300
			} -- 300
		) -- 300
		local created = createLevelSelect( -- 302
			uiLayer, -- 302
			viewW, -- 302
			viewH, -- 302
			{ -- 302
				levels = levelEntries, -- 303
				onPick = function(____, index) -- 304
					if select ~= nil then -- 304
						select:hide() -- 305
					end -- 305
					enterLevel(index) -- 306
				end, -- 304
				onReplayIntro = function() -- 309
					if select ~= nil then -- 309
						select:hide() -- 310
					end -- 310
					startOpening() -- 311
					print("[escape-velocity] opening replay (user)") -- 312
				end -- 309
			} -- 309
		) -- 309
		select = created -- 315
		return created -- 316
	end -- 297
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 329
		local w = View.size.width -- 330
		local h = View.size.height -- 331
		if w == viewW and h == viewH then -- 331
			return -- 332
		end -- 332
		if opening ~= nil then -- 332
			opening.hide() -- 338
			opening = nil -- 339
		end -- 339
		if select ~= nil then -- 339
			select:hide() -- 341
		end -- 341
		if resultPanel ~= nil then -- 341
			resultPanel:hide() -- 342
		end -- 342
		do -- 342
			local i = 0 -- 343
			while i < levelTotal do -- 343
				local slot = slots[i + 1] -- 344
				if slot.runtime ~= nil then -- 344
					slot.runtime.world.visible = false -- 346
					slot.runtime.aim:setEnabled(false) -- 347
					slot.runtime.trajectory:clearPrediction() -- 350
					slot.runtime.trajectory:clearTrail() -- 351
					slot.runtime.trajectory:clearGoalRings() -- 353
				end -- 353
				slot.built = false -- 355
				slot.runtime = nil -- 356
				i = i + 1 -- 343
			end -- 343
		end -- 343
		viewW = w -- 360
		viewH = h -- 361
		uiLayer.size = Size(viewW, viewH) -- 362
		openingLayer.size = Size(viewW, viewH) -- 363
		do -- 363
			local i = 0 -- 364
			while i < levelTotal do -- 364
				levelLayers[i + 1].size = Size(viewW, viewH) -- 364
				i = i + 1 -- 364
			end -- 364
		end -- 364
		local panel = buildPanels() -- 367
		if activeIndex >= 0 then -- 367
			local keep = activeIndex -- 369
			activeIndex = -1 -- 370
			enterLevel(keep) -- 371
		else -- 371
			panel:show(progress.unlocked) -- 373
		end -- 373
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 375
	end -- 329
	Director.entry:onAppChange(function(name) -- 379
		if name == "Size" then -- 379
			relayoutForViewport() -- 380
		end -- 380
	end) -- 379
	local introSeen = loadIntroSeen() -- 388
	local forceIntro = false -- 389
	opening = nil -- 390
	startOpening = function() -- 392
		if opening == nil then -- 392
			opening = createOpening({ -- 394
				root = openingRoot, -- 395
				camera = openingCamera, -- 396
				layer = openingLayer, -- 397
				viewW = viewW, -- 398
				viewH = viewH, -- 399
				fovYDeg = View.fieldOfView, -- 400
				aspect = View.aspectRatio, -- 401
				spherePath = "Assets/Model/Sphere.gltf", -- 402
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 403
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 404
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 405
				onFinish = function() -- 406
					introHold = -1 -- 407
					if not introSeen then -- 407
						saveIntroSeen() -- 409
						introSeen = true -- 410
						print("[escape-velocity] intro seen -> saved") -- 411
					end -- 411
					if select ~= nil then -- 411
						select:show(progress.unlocked) -- 414
					end -- 414
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 415
						opening.frameIndex(), -- 415
						0 -- 415
					) or "?")) -- 415
				end -- 406
			}) -- 406
		end -- 406
		if opening == nil then -- 406
			return -- 419
		end -- 419
		Director:pushCamera(openingCamera) -- 420
		opening.start() -- 421
		print("[escape-velocity] opening start (first launch)") -- 422
	end -- 392
	local startupPanel = buildPanels() -- 425
	local enterReq = Path( -- 437
		Path(".", ".agent", "test-results"), -- 437
		"enter-request.txt" -- 437
	) -- 437
	local autoLaunchAt = -1 -- 438
	local autoFrame = 0 -- 439
	local autoVX = 0 -- 440
	local autoVY = 0 -- 441
	local autoBackAt = -1 -- 443
	local autoReenterAt = -1 -- 444
	local autoEntered = false -- 445
	introHold = -1 -- 447
	if Content:exist(enterReq) then -- 447
		local spec = Content:load(enterReq) -- 449
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 450
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 451
		if head == "intro" then -- 451
			forceIntro = true -- 453
			if at >= 0 then -- 453
				local rest = __TS__StringSubstring(spec, at + 1) -- 455
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 456
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 456
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 458
					if v ~= nil and v >= 0 then -- 458
						introHold = v -- 460
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 461
					end -- 461
				end -- 461
			end -- 461
		end -- 461
		local n = tonumber(head) -- 466
		if n ~= nil and n >= 1 and n <= levelTotal then -- 466
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 468
			enterLevel(n - 1) -- 469
			autoEntered = true -- 470
			if at >= 0 then -- 470
				local rest = __TS__StringSubstring(spec, at + 1) -- 472
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 473
				local c2 = (string.find( -- 474
					rest, -- 474
					":", -- 474
					math.max(c1 + 1 + 1, 1), -- 474
					true -- 474
				) or 0) - 1 -- 474
				if c1 > 0 and c2 > c1 then -- 474
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 476
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 477
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 478
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 478
						autoLaunchAt = frames -- 480
						autoVX = vx -- 481
						autoVY = vy -- 482
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 483
					end -- 483
				end -- 483
			end -- 483
		end -- 483
	end -- 483
	if autoEntered then -- 483
		print("[escape-velocity] opening skipped (auto enter)") -- 493
	elseif forceIntro or not introSeen then -- 493
		startOpening() -- 495
	else -- 495
		startupPanel:show(progress.unlocked) -- 497
		print("[escape-velocity] opening skipped (already seen)") -- 498
	end -- 498
	threadLoop(function() -- 503
		if opening ~= nil and opening.running() then -- 503
			if introHold < 0 or opening.frameIndex() < introHold then -- 503
				opening.step() -- 507
			end -- 507
			if App.deltaTime > 0.05 then -- 507
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 511
					opening.frameIndex(), -- 511
					0 -- 511
				)) -- 511
			end -- 511
		end -- 511
		local runtime = activeRuntime() -- 515
		if runtime ~= nil then -- 515
			runtime.game:update(App.deltaTime) -- 517
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 517
				autoFrame = autoFrame + 1 -- 520
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 520
					autoLaunchAt = -1 -- 522
					print("[escape-velocity] auto launch") -- 523
					runtime.game:launch({x = autoVX, y = autoVY}) -- 524
					autoBackAt = autoFrame + 320 -- 525
					autoReenterAt = autoFrame + 380 -- 526
				end -- 526
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 526
					autoBackAt = -1 -- 530
					if runtime.game:backToSelect() then -- 530
						print("[escape-velocity] auto back to select") -- 531
					end -- 531
				end -- 531
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 531
					autoReenterAt = -1 -- 534
					print("[escape-velocity] auto re-enter") -- 535
					enterLevel(0) -- 536
				end -- 536
			end -- 536
		end -- 536
		return false -- 541
	end) -- 503
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 545
end -- 545
return ____exports -- 545
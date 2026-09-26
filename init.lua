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
			home = {x = level.probeStart.x, y = level.probeStart.y + 4.2}, -- 181
			probeBodyPath = "Assets/Model/Probe_Body.glb", -- 183
			probeAntennaPath = "Assets/Model/Probe_Antenna.glb" -- 184
		}) -- 184
		if scene == nil then -- 184
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 187
			return nil -- 188
		end -- 188
		local camera = Camera3D() -- 191
		local rig = createCameraRig(defaultRigOptions(View.fieldOfView, View.aspectRatio)) -- 194
		local trajectory = createTrajectoryView( -- 195
			levelLayers[index + 1], -- 195
			trajectoryOptions() -- 195
		) -- 195
		local aim = createAimInput(levelLayers[index + 1], viewW, viewH) -- 196
		local game = createGame( -- 198
			level, -- 198
			{ -- 198
				scene = scene, -- 199
				camera = camera, -- 200
				rig = rig, -- 201
				trajectory = trajectory, -- 202
				aim = aim, -- 203
				viewW = viewW, -- 204
				viewH = viewH, -- 205
				fovYDeg = View.fieldOfView, -- 206
				aspect = View.aspectRatio, -- 207
				onPhase = function(____, p) -- 208
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 209
				end, -- 208
				onResult = function(____, r) -- 211
					if r == "success" then -- 211
						local next = advanceUnlocked(progress.unlocked, r, index, levelTotal) -- 214
						if next ~= progress.unlocked then -- 214
							progress = {unlocked = next} -- 216
							saveProgress(progress) -- 217
							print(("[escape-velocity] unlocked -> " .. __TS__NumberToFixed(next, 0)) .. " (saved)") -- 218
						end -- 218
					end -- 218
					print((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) -- 221
					if resultPanel ~= nil then -- 221
						resultPanel:show(r, levelNames[index + 1]) -- 222
					end -- 222
				end -- 211
			} -- 211
		) -- 211
		aim:onDrag(function(a) -- 229
			game:onAimDrag(a) -- 229
		end) -- 229
		aim:onRelease(function(a) -- 230
			game:launch(a.velocity) -- 230
		end) -- 230
		local runtime = { -- 232
			index = index, -- 233
			name = levelNames[index + 1], -- 234
			world = world, -- 235
			camera = camera, -- 236
			game = game, -- 237
			aim = aim, -- 238
			trajectory = trajectory -- 239
		} -- 239
		slot.built = true -- 241
		slot.runtime = runtime -- 242
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 243
		return runtime -- 244
	end -- 147
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 248
		local runtime = ensureLevel(index) -- 249
		if runtime == nil then -- 249
			return -- 250
		end -- 250
		local wasActive = activeIndex == index -- 253
		if opening ~= nil then -- 253
			opening.hide() -- 255
		end -- 255
		if select ~= nil then -- 255
			select:hide() -- 256
		end -- 256
		activeIndex = index -- 257
		showOnlyLevel(index) -- 258
		if not wasActive then -- 258
			Director:pushCamera(runtime.camera) -- 259
		end -- 259
		runtime.game:startLevel() -- 260
		print("[escape-velocity] enter " .. runtime.name) -- 261
	end -- 248
	local function onRetryTap() -- 264
		if resultPanel ~= nil then -- 264
			resultPanel:hide() -- 265
		end -- 265
		local runtime = activeRuntime() -- 266
		if runtime ~= nil then -- 266
			runtime.game:retry() -- 267
		end -- 267
	end -- 264
	local function onBackToSelectTap() -- 270
		local runtime = activeRuntime() -- 271
		if runtime == nil then -- 271
			return -- 272
		end -- 272
		if not runtime.game:backToSelect() then -- 272
			return -- 274
		end -- 274
		runtime.world.visible = false -- 275
		runtime.aim:setEnabled(false) -- 276
		if resultPanel ~= nil then -- 276
			resultPanel:hide() -- 277
		end -- 277
		progress = loadProgress(levelTotal) -- 279
		if select ~= nil then -- 279
			select:show(progress.unlocked) -- 280
		end -- 280
		print("[escape-velocity] back to select: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 281
	end -- 270
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 294
		resultPanel = createResultPanel( -- 295
			uiLayer, -- 295
			viewW, -- 295
			viewH, -- 295
			{ -- 295
				onRetry = function() return onRetryTap() end, -- 296
				onBackToSelect = function() return onBackToSelectTap() end -- 297
			} -- 297
		) -- 297
		local created = createLevelSelect( -- 299
			uiLayer, -- 299
			viewW, -- 299
			viewH, -- 299
			{ -- 299
				levels = levelEntries, -- 300
				onPick = function(____, index) -- 301
					if select ~= nil then -- 301
						select:hide() -- 302
					end -- 302
					enterLevel(index) -- 303
				end, -- 301
				onReplayIntro = function() -- 306
					if select ~= nil then -- 306
						select:hide() -- 307
					end -- 307
					startOpening() -- 308
					print("[escape-velocity] opening replay (user)") -- 309
				end -- 306
			} -- 306
		) -- 306
		select = created -- 312
		return created -- 313
	end -- 294
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 326
		local w = View.size.width -- 327
		local h = View.size.height -- 328
		if w == viewW and h == viewH then -- 328
			return -- 329
		end -- 329
		if opening ~= nil then -- 329
			opening.hide() -- 335
			opening = nil -- 336
		end -- 336
		if select ~= nil then -- 336
			select:hide() -- 338
		end -- 338
		if resultPanel ~= nil then -- 338
			resultPanel:hide() -- 339
		end -- 339
		do -- 339
			local i = 0 -- 340
			while i < levelTotal do -- 340
				local slot = slots[i + 1] -- 341
				if slot.runtime ~= nil then -- 341
					slot.runtime.world.visible = false -- 343
					slot.runtime.aim:setEnabled(false) -- 344
					slot.runtime.trajectory:clearPrediction() -- 347
					slot.runtime.trajectory:clearTrail() -- 348
				end -- 348
				slot.built = false -- 350
				slot.runtime = nil -- 351
				i = i + 1 -- 340
			end -- 340
		end -- 340
		viewW = w -- 355
		viewH = h -- 356
		uiLayer.size = Size(viewW, viewH) -- 357
		openingLayer.size = Size(viewW, viewH) -- 358
		do -- 358
			local i = 0 -- 359
			while i < levelTotal do -- 359
				levelLayers[i + 1].size = Size(viewW, viewH) -- 359
				i = i + 1 -- 359
			end -- 359
		end -- 359
		local panel = buildPanels() -- 362
		if activeIndex >= 0 then -- 362
			local keep = activeIndex -- 364
			activeIndex = -1 -- 365
			enterLevel(keep) -- 366
		else -- 366
			panel:show(progress.unlocked) -- 368
		end -- 368
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 370
	end -- 326
	Director.entry:onAppChange(function(name) -- 374
		if name == "Size" then -- 374
			relayoutForViewport() -- 375
		end -- 375
	end) -- 374
	local introSeen = loadIntroSeen() -- 383
	local forceIntro = false -- 384
	opening = nil -- 385
	startOpening = function() -- 387
		if opening == nil then -- 387
			opening = createOpening({ -- 389
				root = openingRoot, -- 390
				camera = openingCamera, -- 391
				layer = openingLayer, -- 392
				viewW = viewW, -- 393
				viewH = viewH, -- 394
				fovYDeg = View.fieldOfView, -- 395
				aspect = View.aspectRatio, -- 396
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 397
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 398
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 399
				onFinish = function() -- 400
					introHold = -1 -- 401
					if not introSeen then -- 401
						saveIntroSeen() -- 403
						introSeen = true -- 404
						print("[escape-velocity] intro seen -> saved") -- 405
					end -- 405
					if select ~= nil then -- 405
						select:show(progress.unlocked) -- 408
					end -- 408
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 409
						opening.frameIndex(), -- 409
						0 -- 409
					) or "?")) -- 409
				end -- 400
			}) -- 400
		end -- 400
		if opening == nil then -- 400
			return -- 413
		end -- 413
		Director:pushCamera(openingCamera) -- 414
		opening.start() -- 415
		print("[escape-velocity] opening start (first launch)") -- 416
	end -- 387
	local startupPanel = buildPanels() -- 419
	local enterReq = Path( -- 431
		Path(".", ".agent", "test-results"), -- 431
		"enter-request.txt" -- 431
	) -- 431
	local autoLaunchAt = -1 -- 432
	local autoFrame = 0 -- 433
	local autoVX = 0 -- 434
	local autoVY = 0 -- 435
	local autoBackAt = -1 -- 437
	local autoReenterAt = -1 -- 438
	local autoEntered = false -- 439
	introHold = -1 -- 441
	if Content:exist(enterReq) then -- 441
		local spec = Content:load(enterReq) -- 443
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 444
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 445
		if head == "intro" then -- 445
			forceIntro = true -- 447
			if at >= 0 then -- 447
				local rest = __TS__StringSubstring(spec, at + 1) -- 449
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 450
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 450
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 452
					if v ~= nil and v >= 0 then -- 452
						introHold = v -- 454
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 455
					end -- 455
				end -- 455
			end -- 455
		end -- 455
		local n = tonumber(head) -- 460
		if n ~= nil and n >= 1 and n <= levelTotal then -- 460
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 462
			enterLevel(n - 1) -- 463
			autoEntered = true -- 464
			if at >= 0 then -- 464
				local rest = __TS__StringSubstring(spec, at + 1) -- 466
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 467
				local c2 = (string.find( -- 468
					rest, -- 468
					":", -- 468
					math.max(c1 + 1 + 1, 1), -- 468
					true -- 468
				) or 0) - 1 -- 468
				if c1 > 0 and c2 > c1 then -- 468
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 470
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 471
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 472
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 472
						autoLaunchAt = frames -- 474
						autoVX = vx -- 475
						autoVY = vy -- 476
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 477
					end -- 477
				end -- 477
			end -- 477
		end -- 477
	end -- 477
	if autoEntered then -- 477
		print("[escape-velocity] opening skipped (auto enter)") -- 487
	elseif forceIntro or not introSeen then -- 487
		startOpening() -- 489
	else -- 489
		startupPanel:show(progress.unlocked) -- 491
		print("[escape-velocity] opening skipped (already seen)") -- 492
	end -- 492
	threadLoop(function() -- 497
		if opening ~= nil and opening.running() then -- 497
			if introHold < 0 or opening.frameIndex() < introHold then -- 497
				opening.step() -- 501
			end -- 501
		end -- 501
		local runtime = activeRuntime() -- 504
		if runtime ~= nil then -- 504
			runtime.game:update(App.deltaTime) -- 506
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 506
				autoFrame = autoFrame + 1 -- 509
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 509
					autoLaunchAt = -1 -- 511
					print("[escape-velocity] auto launch") -- 512
					runtime.game:launch({x = autoVX, y = autoVY}) -- 513
					autoBackAt = autoFrame + 320 -- 514
					autoReenterAt = autoFrame + 380 -- 515
				end -- 515
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 515
					autoBackAt = -1 -- 519
					if runtime.game:backToSelect() then -- 519
						print("[escape-velocity] auto back to select") -- 520
					end -- 520
				end -- 520
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 520
					autoReenterAt = -1 -- 523
					print("[escape-velocity] auto re-enter") -- 524
					enterLevel(0) -- 525
				end -- 525
			end -- 525
		end -- 525
		return false -- 530
	end) -- 497
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 534
end -- 534
return ____exports -- 534
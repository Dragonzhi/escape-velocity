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
	local opening, introHold -- 54
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
				end -- 301
			} -- 301
		) -- 301
		select = created -- 306
		return created -- 307
	end -- 294
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 320
		local w = View.size.width -- 321
		local h = View.size.height -- 322
		if w == viewW and h == viewH then -- 322
			return -- 323
		end -- 323
		if opening ~= nil then -- 323
			opening.hide() -- 329
			opening = nil -- 330
		end -- 330
		if select ~= nil then -- 330
			select:hide() -- 332
		end -- 332
		if resultPanel ~= nil then -- 332
			resultPanel:hide() -- 333
		end -- 333
		do -- 333
			local i = 0 -- 334
			while i < levelTotal do -- 334
				local slot = slots[i + 1] -- 335
				if slot.runtime ~= nil then -- 335
					slot.runtime.world.visible = false -- 337
					slot.runtime.aim:setEnabled(false) -- 338
					slot.runtime.trajectory:clearPrediction() -- 341
					slot.runtime.trajectory:clearTrail() -- 342
				end -- 342
				slot.built = false -- 344
				slot.runtime = nil -- 345
				i = i + 1 -- 334
			end -- 334
		end -- 334
		viewW = w -- 349
		viewH = h -- 350
		uiLayer.size = Size(viewW, viewH) -- 351
		openingLayer.size = Size(viewW, viewH) -- 352
		do -- 352
			local i = 0 -- 353
			while i < levelTotal do -- 353
				levelLayers[i + 1].size = Size(viewW, viewH) -- 353
				i = i + 1 -- 353
			end -- 353
		end -- 353
		local panel = buildPanels() -- 356
		if activeIndex >= 0 then -- 356
			local keep = activeIndex -- 358
			activeIndex = -1 -- 359
			enterLevel(keep) -- 360
		else -- 360
			panel:show(progress.unlocked) -- 362
		end -- 362
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 364
	end -- 320
	Director.entry:onAppChange(function(name) -- 368
		if name == "Size" then -- 368
			relayoutForViewport() -- 369
		end -- 369
	end) -- 368
	local introSeen = loadIntroSeen() -- 377
	local forceIntro = false -- 378
	opening = nil -- 379
	local function startOpening() -- 381
		if opening == nil then -- 381
			opening = createOpening({ -- 383
				root = openingRoot, -- 384
				camera = openingCamera, -- 385
				layer = openingLayer, -- 386
				viewW = viewW, -- 387
				viewH = viewH, -- 388
				fovYDeg = View.fieldOfView, -- 389
				aspect = View.aspectRatio, -- 390
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 391
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 392
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 393
				onFinish = function() -- 394
					introHold = -1 -- 395
					if not introSeen then -- 395
						saveIntroSeen() -- 397
						introSeen = true -- 398
						print("[escape-velocity] intro seen -> saved") -- 399
					end -- 399
					if select ~= nil then -- 399
						select:show(progress.unlocked) -- 402
					end -- 402
					print("[escape-velocity] opening finished: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 403
						opening.frameIndex(), -- 403
						0 -- 403
					) or "?")) -- 403
				end -- 394
			}) -- 394
		end -- 394
		if opening == nil then -- 394
			return -- 407
		end -- 407
		Director:pushCamera(openingCamera) -- 408
		opening.start() -- 409
		print("[escape-velocity] opening start (first launch)") -- 410
	end -- 381
	local startupPanel = buildPanels() -- 413
	local enterReq = Path( -- 425
		Path(".", ".agent", "test-results"), -- 425
		"enter-request.txt" -- 425
	) -- 425
	local autoLaunchAt = -1 -- 426
	local autoFrame = 0 -- 427
	local autoVX = 0 -- 428
	local autoVY = 0 -- 429
	local autoBackAt = -1 -- 431
	local autoReenterAt = -1 -- 432
	local autoEntered = false -- 433
	introHold = -1 -- 435
	if Content:exist(enterReq) then -- 435
		local spec = Content:load(enterReq) -- 437
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 438
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 439
		if head == "intro" then -- 439
			forceIntro = true -- 441
			if at >= 0 then -- 441
				local rest = __TS__StringSubstring(spec, at + 1) -- 443
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 444
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 444
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 446
					if v ~= nil and v >= 0 then -- 446
						introHold = v -- 448
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 449
					end -- 449
				end -- 449
			end -- 449
		end -- 449
		local n = tonumber(head) -- 454
		if n ~= nil and n >= 1 and n <= levelTotal then -- 454
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 456
			enterLevel(n - 1) -- 457
			autoEntered = true -- 458
			if at >= 0 then -- 458
				local rest = __TS__StringSubstring(spec, at + 1) -- 460
				local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 461
				local c2 = (string.find( -- 462
					rest, -- 462
					":", -- 462
					math.max(c1 + 1 + 1, 1), -- 462
					true -- 462
				) or 0) - 1 -- 462
				if c1 > 0 and c2 > c1 then -- 462
					local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 464
					local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 465
					local vy = tonumber(__TS__StringSubstring(rest, c2 + 1)) -- 466
					if frames ~= nil and vx ~= nil and vy ~= nil then -- 466
						autoLaunchAt = frames -- 468
						autoVX = vx -- 469
						autoVY = vy -- 470
						print(((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") -- 471
					end -- 471
				end -- 471
			end -- 471
		end -- 471
	end -- 471
	if autoEntered then -- 471
		print("[escape-velocity] opening skipped (auto enter)") -- 481
	elseif forceIntro or not introSeen then -- 481
		startOpening() -- 483
	else -- 483
		startupPanel:show(progress.unlocked) -- 485
		print("[escape-velocity] opening skipped (already seen)") -- 486
	end -- 486
	threadLoop(function() -- 491
		if opening ~= nil and opening.running() then -- 491
			if introHold < 0 or opening.frameIndex() < introHold then -- 491
				opening.step() -- 495
			end -- 495
		end -- 495
		local runtime = activeRuntime() -- 498
		if runtime ~= nil then -- 498
			runtime.game:update(App.deltaTime) -- 500
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 then -- 500
				autoFrame = autoFrame + 1 -- 503
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 503
					autoLaunchAt = -1 -- 505
					print("[escape-velocity] auto launch") -- 506
					runtime.game:launch({x = autoVX, y = autoVY}) -- 507
					autoBackAt = autoFrame + 320 -- 508
					autoReenterAt = autoFrame + 380 -- 509
				end -- 509
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 509
					autoBackAt = -1 -- 513
					if runtime.game:backToSelect() then -- 513
						print("[escape-velocity] auto back to select") -- 514
					end -- 514
				end -- 514
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 514
					autoReenterAt = -1 -- 517
					print("[escape-velocity] auto re-enter") -- 518
					enterLevel(0) -- 519
				end -- 519
			end -- 519
		end -- 519
		return false -- 524
	end) -- 491
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 528
end -- 528
return ____exports -- 528
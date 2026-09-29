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
local json = ____Dora.json -- 21
local threadLoop = ____Dora.threadLoop -- 21
local ____LevelData = require("game.LevelData") -- 22
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 22
local getLevel = ____LevelData.getLevel -- 22
local installArcadeLevels = ____LevelData.installArcadeLevels -- 22
local levelCount = ____LevelData.levelCount -- 22
local scaledPlanets = ____LevelData.scaledPlanets -- 22
local starOrbits = ____LevelData.starOrbits -- 22
local ____Scene = require("game.Scene") -- 23
local buildScene = ____Scene.buildScene -- 23
local ____CameraRig = require("game.CameraRig") -- 24
local createCameraRig = ____CameraRig.createCameraRig -- 24
local defaultRigOptions = ____CameraRig.defaultRigOptions -- 24
local ____Trajectory = require("game.Trajectory") -- 25
local createTrajectoryView = ____Trajectory.createTrajectoryView -- 25
local trajectoryOptions = ____Trajectory.defaultOptions -- 25
local ____PlanView = require("game.PlanView") -- 26
local arrivalRingRadius = ____PlanView.arrivalRingRadius -- 26
local createPlanView = ____PlanView.createPlanView -- 26
local defaultPlanOptions = ____PlanView.defaultPlanOptions -- 26
local planFitRadius = ____PlanView.planFitRadius -- 26
local ____Hud = require("game.Hud") -- 27
local FinaleMainText = ____Hud.FinaleMainText -- 27
local createAimInput = ____Hud.createAimInput -- 27
local createFinalePanel = ____Hud.createFinalePanel -- 27
local createLevelSelect = ____Hud.createLevelSelect -- 27
local createResultPanel = ____Hud.createResultPanel -- 27
local finaleSubtitle = ____Hud.finaleSubtitle -- 27
local ____Game = require("game.Game") -- 28
local createGame = ____Game.createGame -- 28
local ____Progress = require("game.Progress") -- 29
local getMissionRockets = ____Progress.getMissionRockets -- 29
local getTotalRockets = ____Progress.getTotalRockets -- 29
local loadProgress = ____Progress.loadProgress -- 29
local progressFilePath = ____Progress.progressFilePath -- 29
local recordMissionResult = ____Progress.recordMissionResult -- 29
local saveProgress = ____Progress.saveProgress -- 29
local ____Ui = require("game.Ui") -- 31
local advanceUiClock = ____Ui.advanceUiClock -- 31
local ____Tuning = require("game.Tuning") -- 34
local CLIP_NEAR_DEFAULT = ____Tuning.CLIP_NEAR_DEFAULT -- 34
local levelRuntime = ____Tuning.levelRuntime -- 34
local ____Opening = require("game.Opening") -- 35
local createOpening = ____Opening.createOpening -- 35
local loadIntroSeen = ____Opening.loadIntroSeen -- 35
local saveIntroSeen = ____Opening.saveIntroSeen -- 35
local ____SolarHub = require("game.SolarHub") -- 36
local createSolarHub = ____SolarHub.createSolarHub -- 36
local ____Sound = require("game.Sound") -- 37
local playSound = ____Sound.playSound -- 37
local startBackgroundMusic = ____Sound.startBackgroundMusic -- 37
--- 把 `View` 的 3D 裁剪面切到某一关的世界尺度（B 修复①：3D 近裁剪面）。
-- 
-- 为什么需要它：`Camera3D` 的 d.ts 只有 position/target/up/lookAt，**没有 near/far** ——
-- 裁剪面是 `View`（应用级单例）的，默认 `near = 0.1 / far = 10000`（引擎 `Script/Dev/Entry.yue`）。
-- 而 L1 的贴地球机位里相机离地球只有 **~0.0089 单位**（取景要装下视觉半径 0.0034 的地球），
-- 0.1 的近平面比这个距离还大 11 倍 ⇒ **整个地月系被裁掉**，屏幕上只剩天球上的星点
-- （用户实测「切到 3D 啥也看不到」；2026-09-28 截图复现：3D 帧里除星星一无所有）。
-- 
-- 口径：**没有 near 覆盖的关卡就是引擎默认值**，所以切沙盘/开场时也走这里（`index < 0`）——
-- 否则从 L1 回到沙盘会留着 2e-4 的近平面（沙盘的世界是 80 单位级，2e-4 会让深度精度白白变差）。
-- **远平面只在关卡点名时才写**（`cameraFar`）：默认的 10000 谁都够用，
-- 而去动一个全局值就要有理由 —— 改之前先问"这一关真的需要吗"。
-- 
-- 幂等：值没变就一个字节都不写、一行都不打。
-- ⚠️ 比较必须带**容差**：引擎那边存的是 **float32**，写进去的 0.1 读回来是
-- 0.10000000149011612（探针实测）—— 用 `!==` 比会让"没变"永远判成"变了"，
-- 于是每次切相机都白写一次、白打一行日志。
-- 
-- @param index 关卡下标（0 起）；**负值 = 非关卡场景**（太阳系沙盘 / 开场），用引擎默认值。
local function applyClipPlanes(index) -- 82
	local near = CLIP_NEAR_DEFAULT -- 83
	local far = 0 -- 85
	if index >= 0 then -- 85
		local rt = levelRuntime(index) -- 87
		if rt.cameraNear ~= nil and rt.cameraNear > 0 then -- 87
			near = rt.cameraNear -- 88
		end -- 88
		if rt.cameraFar ~= nil and rt.cameraFar > 0 then -- 88
			far = rt.cameraFar -- 89
		end -- 89
	end -- 89
	local prevNear = View.nearPlaneDistance -- 91
	local prevFar = View.farPlaneDistance -- 92
	local changed = math.abs(prevNear - near) > near * 0.000001 -- 94
	if changed then -- 94
		View.nearPlaneDistance = near -- 95
	end -- 95
	if far > 0 and math.abs(prevFar - far) > far * 0.000001 then -- 95
		View.farPlaneDistance = far -- 97
		changed = true -- 98
	end -- 98
	if not changed then -- 98
		return -- 100
	end -- 100
	print(((((((((("[escape-velocity] clip planes near=" .. __TS__NumberToFixed(prevNear, 6)) .. "->") .. __TS__NumberToFixed(View.nearPlaneDistance, 6)) .. " far=") .. __TS__NumberToFixed(prevFar, 0)) .. "->") .. __TS__NumberToFixed(View.farPlaneDistance, 0)) .. " (") .. (index >= 0 and "L" .. __TS__NumberToFixed(index + 1, 0) or "hub/opening")) .. ")") -- 101
end -- 82
--- 切相机：先同步裁剪面再推栈（两者必须一起切，否则下一关的近平面是上一关的）。
local function useCamera(camera, levelIndex) -- 107
	applyClipPlanes(levelIndex) -- 108
	Director:pushCamera(camera) -- 109
end -- 107
local debugTriggerResultFn = nil -- 112
local debugTriggerEnterLevelFn = nil -- 113
local debugTriggerZoomInFn = nil -- 114
local debugTriggerResetViewFn = nil -- 115
local debugGameStateFn = nil -- 116
local activeResultPanel = nil -- 117
local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 125
local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 126
local function decodeLevelJson(text) -- 127
	local decoded = {json.decode(text)} -- 128
	local err = decoded[2] -- 129
	if err ~= nil then -- 129
		return nil -- 130
	end -- 130
	return decoded[1] -- 131
end -- 127
if not installArcadeLevels(levelsText, bodiesText, decodeLevelJson) then -- 127
	print("[escape-velocity] FATAL: levels.json 没有装上") -- 134
end -- 134
local levelTotal = levelCount() -- 136
startBackgroundMusic() -- 137
local totalBonusPoints = 0 -- 138
do -- 138
	local i = 0 -- 139
	while i < levelTotal do -- 139
		local ____opt_2 = getLevel(i) -- 139
		local ____opt_0 = ____opt_2 and ____opt_2.bonusPoints -- 139
		totalBonusPoints = totalBonusPoints + (____opt_0 and #____opt_0 or 0) -- 139
		i = i + 1 -- 139
	end -- 139
end -- 139
if levelTotal <= 0 then -- 139
	print("[escape-velocity] FATAL: no level data") -- 142
else -- 142
	local opening, startOpening, introHold -- 142
	local viewW = View.size.width -- 144
	local viewH = View.size.height -- 145
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 148
	local levelLayers = {} -- 154
	do -- 154
		local i = 0 -- 155
		while i < levelTotal do -- 155
			local layer = Node() -- 156
			layer.size = Size(viewW, viewH) -- 157
			layer.anchor = Vec2(0.5, 0.5) -- 158
			layer.position = Vec2(0, 0) -- 159
			Director.ui:addChild(layer) -- 160
			levelLayers[#levelLayers + 1] = layer -- 161
			i = i + 1 -- 155
		end -- 155
	end -- 155
	local openingLayer = Node() -- 166
	openingLayer.size = Size(viewW, viewH) -- 167
	openingLayer.anchor = Vec2(0.5, 0.5) -- 168
	openingLayer.position = Vec2(0, 0) -- 169
	Director.ui:addChild(openingLayer) -- 170
	local openingRoot = Node3D() -- 173
	openingRoot.visible = false -- 174
	Director.entry:addChild(openingRoot) -- 175
	local openingCamera = Camera3D() -- 176
	local hubRoot = Node3D() -- 179
	hubRoot.visible = false -- 180
	Director.entry:addChild(hubRoot) -- 181
	local hubCamera = Camera3D() -- 182
	local hubLayer = Node() -- 184
	hubLayer.size = Size(viewW, viewH) -- 185
	hubLayer.anchor = Vec2(0.5, 0.5) -- 186
	hubLayer.position = Vec2(0, 0) -- 187
	Director.ui:addChild(hubLayer) -- 188
	local uiLayer = Node() -- 191
	uiLayer.size = Size(viewW, viewH) -- 192
	uiLayer.anchor = Vec2(0.5, 0.5) -- 193
	uiLayer.position = Vec2(0, 0) -- 194
	Director.ui:addChild(uiLayer) -- 195
	local levelNames = {} -- 198
	do -- 198
		local i = 0 -- 199
		while i < levelTotal do -- 199
			local def = getLevel(i) -- 200
			local title = def ~= nil and def.title or "" -- 201
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 202
			i = i + 1 -- 199
		end -- 199
	end -- 199
	local levelEntries = {} -- 204
	do -- 204
		local i = 0 -- 205
		while i < levelTotal do -- 205
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 205
			i = i + 1 -- 205
		end -- 205
	end -- 205
	local progress = loadProgress(levelTotal) -- 208
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 209
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 210
	local slots = {} -- 212
	do -- 212
		local i = 0 -- 213
		while i < levelTotal do -- 213
			slots[#slots + 1] = {built = false, runtime = nil} -- 213
			i = i + 1 -- 213
		end -- 213
	end -- 213
	local activeIndex = -1 -- 215
	local select = nil -- 216
	local solarHub = nil -- 217
	local resultPanel = nil -- 218
	local finalePanel = nil -- 220
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 222
	local resultIndex = -1 -- 227
	local function activeRuntime() -- 229
		if activeIndex < 0 then -- 229
			return nil -- 230
		end -- 230
		return slots[activeIndex + 1].runtime -- 231
	end -- 229
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 239
		do -- 239
			local i = 0 -- 240
			while i < levelTotal do -- 240
				do -- 240
					local slot = slots[i + 1] -- 241
					levelLayers[i + 1].visible = i == index -- 244
					if slot.runtime == nil then -- 244
						goto __continue29 -- 245
					end -- 245
					local active = i == index -- 246
					slot.runtime.world.visible = active -- 247
					slot.runtime.aim:setEnabled(active) -- 248
				end -- 248
				::__continue29:: -- 248
				i = i + 1 -- 240
			end -- 240
		end -- 240
	end -- 239
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 257
		local game -- 257
		local slot = slots[index + 1] -- 258
		if slot.built and slot.runtime ~= nil then -- 258
			return slot.runtime -- 259
		end -- 259
		local def = getLevel(index) -- 261
		if def == nil then -- 261
			return nil -- 262
		end -- 262
		local bodies = scaledPlanets(def) -- 264
		local level = { -- 265
			levelId = index + 1, -- 266
			transfer = def.transfer, -- 267
			bodies = bodies, -- 268
			probeStart = def.probeStart, -- 269
			probeVel0 = def.probeVel0, -- 271
			goal = def.goal, -- 272
			bonusPoints = def.bonusPoints, -- 273
			viewingSeconds = index == 0 and 24 or (index == 1 and 12 or 6), -- 274
			escapeRadius = def.escapeRadius, -- 275
			physicsStep = levelRuntime(index).physicsStep, -- 276
			speedUnit = 1, -- 278
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 279
			speedMinPow = levelRuntime(index).speedMinPow, -- 280
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 281
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 282
			aimFraming = levelRuntime(index).aimFraming, -- 283
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 284
			aimMin = levelRuntime(index).aimMin, -- 285
			maxSteps = def.maxSteps, -- 286
			predictSteps = levelRuntime(index).predictSteps, -- 287
			mission = def.mission, -- 288
			stars = def.stars, -- 289
			starOrbits = starOrbits(index) -- 290
		} -- 290
		local world = Node3D() -- 293
		Director.entry:addChild(world) -- 294
		world.visible = false -- 295
		local rtg = def.probeVariant == "rtg" -- 297
		local scene = buildScene({ -- 298
			root = world, -- 299
			backdropRadius = def.transfer ~= nil and (def.transfer.orbital ~= nil and 6000 or 3000) or nil, -- 300
			bodies = bodies, -- 301
			visuals = def.visuals, -- 302
			probeStart = level.probeStart, -- 303
			stars = def.stars, -- 304
			probeScale = levelRuntime(index).probeVisualRadius, -- 310
			spherePath = "Assets/Model/Sphere.gltf", -- 311
			ringPath = "Assets/Model/Ring.gltf", -- 312
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 313
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 320
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 321
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 322
			probeBodyRadius = rtg and 0.871 or 1.084, -- 323
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 325
			orbitFlowDots = levelRuntime(index).orbitFlowDots, -- 326
			orbitRings = levelRuntime(index).orbitRings -- 329
		}) -- 329
		if scene == nil then -- 329
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 332
			return nil -- 333
		end -- 333
		local rt = levelRuntime(index) -- 336
		local camera = Camera3D() -- 337
		local rigOptions = defaultRigOptions( -- 341
			View.fieldOfView, -- 341
			View.aspectRatio, -- 341
			rt.cameraMin, -- 341
			rt.cameraMax, -- 341
			rt.tiltDeg -- 341
		) -- 341
		if def.transfer ~= nil then -- 341
			rigOptions.margin = 0.16 -- 343
			rigOptions.screenMinY = 2 * math.min(350, viewH * 0.38) / viewH - 1 -- 344
			rigOptions.screenMaxY = 1 - 2 * math.min(205, viewH * 0.23) / viewH -- 345
			rigOptions.screenBiasY = 0.14 -- 346
		end -- 346
		local rig = createCameraRig(rigOptions) -- 348
		local trailOptions = trajectoryOptions() -- 349
		if def.transfer ~= nil then -- 349
			trailOptions.tailPoints = 120 -- 352
			trailOptions.burnLength = 12 -- 353
			trailOptions.trailHeadRadius = 1.2 -- 354
			trailOptions.trailHeadAlpha = 0.45 -- 355
			trailOptions.trailR = 100 -- 356
			trailOptions.trailG = 180 -- 356
			trailOptions.trailB = 230 -- 356
		end -- 356
		local trajectory = createTrajectoryView(levelLayers[index + 1], trailOptions) -- 358
		local planOpts = defaultPlanOptions() -- 362
		planOpts.actualBodySizes = def.id == 2 -- 363
		planOpts.transferTutorial = def.transfer ~= nil -- 364
		if levelRuntime(index).orbitFlowDots == false then -- 364
			planOpts.flowDotRadius = 0 -- 365
		end -- 365
		planOpts.probeVisualRadius = levelRuntime(index).probeVisualRadius -- 368
		if def.transfer ~= nil then -- 368
			planOpts.trailHex = 6599910 -- 369
			planOpts.trailWidth = 1.5 -- 369
		end -- 369
		local plan = createPlanView( -- 370
			levelLayers[index + 1], -- 370
			viewW, -- 370
			viewH, -- 370
			planOpts, -- 370
			def.planCenter -- 370
		) -- 370
		local offset = def.goal.offset -- 371
		local planTolerance = arrivalRingRadius(def.goal) + (offset ~= nil and math.sqrt(offset.x * offset.x + offset.y * offset.y) or 0) -- 372
		plan:fitTo(math.max( -- 373
			planFitRadius( -- 373
				bodies, -- 373
				level.probeStart, -- 373
				def.goal.planetIndex, -- 373
				planTolerance, -- 373
				def.planCenter, -- 373
				starOrbits(index) -- 373
			), -- 373
			def.transfer ~= nil and def.transfer.orbital ~= nil and def.transfer.orbital.region ~= nil and def.transfer.orbital.region.maxRadius + 20 or 0 -- 373
		)) -- 373
		local aim = createAimInput( -- 375
			levelLayers[index + 1], -- 375
			viewW, -- 375
			viewH, -- 375
			def.dvBudget, -- 375
			rt.aimMin, -- 375
			rt.playbackSpeeds, -- 375
			def.transfer ~= nil, -- 375
			def.transfer ~= nil and def.transfer.orbital ~= nil and (def.transfer.mode == "lowerPeriapsis" and "inward" or "outward") or "lunar" -- 375
		) -- 375
		local dragSoundPlayed = false -- 376
		aim:setBurnInfo(0, def.dvBudget) -- 378
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 380
		aim:setDate(0, dateSpan) -- 381
		aim:onWarp(function(dir) -- 382
			game:stepTime(dir, dateSpan) -- 383
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 384
		end) -- 382
		aim:onZoomIn(function() -- 388
			plan:zoomIn() -- 389
		end) -- 388
		aim:onZoomOut(function() -- 391
			plan:zoomOut() -- 392
		end) -- 391
		aim:onFitView(function() -- 394
			plan:resetView() -- 395
		end) -- 394
		local challengesList = {} -- 399
		if def.mission ~= nil then -- 399
			do -- 399
				local k = 0 -- 401
				while k < #def.mission.challenges do -- 401
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 402
					k = k + 1 -- 401
				end -- 401
			end -- 401
		end -- 401
		local initialRockets = getMissionRockets(progress, index) -- 405
		local drawerTitle = def.transfer ~= nil and (("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. (index == 0 and "奔向月球" or (index == 1 and "借金星减速，飞掠水星" or "双星甩尾")) or (def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1]) -- 406
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 407
		game = createGame( -- 409
			level, -- 409
			{ -- 409
				scene = scene, -- 410
				camera = camera, -- 411
				rig = rig, -- 412
				trajectory = trajectory, -- 413
				plan = plan, -- 414
				visuals = def.visuals, -- 416
				setWorldVisible = function(____, on) -- 418
					world.visible = on -- 419
				end, -- 418
				aim = aim, -- 421
				viewW = viewW, -- 422
				viewH = viewH, -- 423
				fovYDeg = View.fieldOfView, -- 424
				aspect = View.aspectRatio, -- 425
				onPhase = function(____, p) -- 426
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 427
					if index == activeIndex then -- 427
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 434
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 435
						aim:setMissionDrawerVisible(inAim) -- 436
						if p == "Finale" then -- 436
							if resultPanel ~= nil then -- 436
								resultPanel:hide() -- 438
							end -- 438
							if finalePanel ~= nil then -- 438
								finalePanel:show(finaleText.main, finaleText.sub) -- 439
							end -- 439
						else -- 439
							if p ~= "Result" and resultPanel ~= nil then -- 439
								resultPanel:hide() -- 441
							end -- 441
							if finalePanel ~= nil then -- 441
								finalePanel:hide() -- 442
							end -- 442
						end -- 442
					end -- 442
				end, -- 426
				onMissionCompleted = function(____, telem) -- 446
					playSound("gate_reach") -- 447
					progress = recordMissionResult( -- 448
						progress, -- 448
						index, -- 448
						def.bonusPoints ~= nil and (telem.bonusRockets or 0) or 0, -- 448
						levelTotal, -- 448
						true -- 448
					) -- 448
					saveProgress(progress) -- 449
					print("[escape-velocity] flyby completion saved L" .. __TS__NumberToFixed(index + 1, 0)) -- 450
				end, -- 446
				onBonusCollected = function(____, score, pointId) -- 452
					playSound(score <= 1 and "star_1" or (score == 2 and "star_2" or "star_3")) -- 453
					aim:setBonusFeedback(1) -- 454
					if game:missionCompleted() then -- 454
						progress = recordMissionResult( -- 456
							progress, -- 456
							index, -- 456
							score, -- 456
							levelTotal, -- 456
							true -- 456
						) -- 456
						saveProgress(progress) -- 457
					end -- 457
					print((("[escape-velocity] bonus +" .. __TS__NumberToFixed(score, 0)) .. " id=") .. pointId) -- 459
				end, -- 452
				onFlyby = function(____, _bodyIndex) -- 461
					playSound("slingshot_whoosh") -- 462
				end, -- 461
				onResult = function(____, r, telemetry) -- 464
					if r == "crashed" then -- 464
						playSound("crash") -- 465
					end -- 465
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 466
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity, starsCollected = telem.starsCollected ~= nil and telem.starsCollected or 0}) -- 472
					local score = def.bonusPoints ~= nil and (r == "success" and (telem.bonusRockets or 0) or 0) or evalInfo.rockets -- 478
					if def.bonusPoints ~= nil then -- 478
						evalInfo.rockets = score -- 480
						evalInfo.achieved = {r == "success", score > 0, score >= (#def.bonusPoints or 1)} -- 481
					end -- 481
					if r == "success" then -- 481
						progress = recordMissionResult( -- 486
							progress, -- 486
							index, -- 486
							score, -- 486
							levelTotal, -- 486
							true -- 486
						) -- 486
						saveProgress(progress) -- 487
					end -- 487
					local currentTotal = getTotalRockets(progress, levelTotal) -- 489
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(totalBonusPoints, 0)) .. ")") -- 491
					resultIndex = index -- 495
					local challengesList = {} -- 497
					if def.bonusPoints == nil and def.mission ~= nil then -- 497
						do -- 497
							local k = 0 -- 499
							while k < #def.mission.challenges do -- 499
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 500
								k = k + 1 -- 499
							end -- 499
						end -- 499
					end -- 499
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 504
					local detailParams = { -- 508
						result = r, -- 509
						levelName = titleWithSub, -- 510
						levelIndex = index, -- 511
						rocketsGot = evalInfo.rockets, -- 512
						challenges = challengesList, -- 513
						completionOnly = def.bonusPoints == nil, -- 514
						bonusPointCount = def.bonusPoints ~= nil and #def.bonusPoints or nil, -- 515
						achieved = evalInfo.achieved, -- 516
						burnDv = telem.burnDv, -- 517
						dvBudget = def.dvBudget, -- 518
						flightTime = telem.flightTime, -- 519
						totalRockets = currentTotal, -- 520
						totalPossibleRockets = totalBonusPoints -- 521
					} -- 521
					if resultPanel ~= nil then -- 521
						resultPanel:show(r, titleWithSub, detailParams) -- 525
					end -- 525
				end, -- 464
				onFinale = function(____, info) -- 529
					finaleText = { -- 530
						main = FinaleMainText, -- 530
						sub = finaleSubtitle(info.distance, info.time) -- 530
					} -- 530
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 531
				end, -- 529
				finale = index == levelTotal - 1 and def.transfer == nil -- 536
			} -- 536
		) -- 536
		aim:onQuickRetry(function() -- 539
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 540
			game:retry() -- 541
		end) -- 539
		aim:onDrag(function(a) -- 547
			if not dragSoundPlayed then -- 547
				playSound("aim_stretch") -- 548
				dragSoundPlayed = true -- 548
			end -- 548
			game:onAimDrag(a) -- 549
			aim:setBurnInfo( -- 551
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 551
				def.dvBudget -- 551
			) -- 551
		end) -- 547
		aim:onAimReady(function(a) -- 554
			dragSoundPlayed = false -- 555
			game:onAimDrag(a) -- 556
			game:aimReady() -- 557
			print("[escape-velocity] aim ready -> Armed") -- 558
		end) -- 554
		aim:onLaunch(function() -- 560
			print("[escape-velocity] launch button tap") -- 561
			playSound("launch") -- 562
			game:launchArmed() -- 563
		end) -- 560
		aim:onCancelAim(function() -- 565
			print("[escape-velocity] cancel aim tap") -- 566
			dragSoundPlayed = false -- 567
			playSound("aim_cancel") -- 568
			game:cancelAim() -- 569
		end) -- 565
		aim:onObserve(function(dx, dy) -- 572
			game:observeDrag(dx, dy) -- 573
		end) -- 572
		aim:onZoom(function(deltaDist) -- 575
			game:observeZoom(deltaDist) -- 576
		end) -- 575
		aim:onSkipTour(function() -- 578
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 579
			game:skipIntroTour() -- 580
		end) -- 578
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 582
		aim:onViewToggle(function() -- 584
			game:toggleViewMode() -- 585
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 586
		end) -- 584
		if aim.onCameraFocus ~= nil then -- 584
			aim:onCameraFocus(function() -- 588
				game:cycleCameraFocus() -- 588
			end) -- 588
		end -- 588
		if aim.onEndViewing ~= nil then -- 588
			aim:onEndViewing(function() -- 589
				game:endViewing() -- 589
			end) -- 589
		end -- 589
		aim:onSpeedUp(function() -- 593
			game:speedUp() -- 594
		end) -- 593
		aim:onSpeedDown(function() -- 596
			game:speedDown() -- 597
		end) -- 596
		aim:onTogglePause(function() -- 599
			game:togglePause() -- 600
		end) -- 599
		aim:onPlayback(function(speed) -- 602
			game:setPlaybackSpeed(speed) -- 603
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 604
		end) -- 602
		aim:setPlayback(game:playbackSpeed()) -- 606
		local runtime = { -- 608
			index = index, -- 609
			name = levelNames[index + 1], -- 610
			world = world, -- 611
			camera = camera, -- 612
			game = game, -- 613
			aim = aim, -- 614
			trajectory = trajectory, -- 615
			plan = plan, -- 616
			levelHasTimeWindow = def.timeWindow ~= nil, -- 617
			dvBudget = def.dvBudget, -- 618
			dateSpan = dateSpan -- 619
		} -- 619
		slot.built = true -- 621
		slot.runtime = runtime -- 622
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 623
		return runtime -- 624
	end -- 257
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 628
		local runtime = ensureLevel(index) -- 629
		if runtime == nil then -- 629
			return -- 630
		end -- 630
		local wasActive = activeIndex == index -- 633
		if opening ~= nil then -- 633
			opening.hide() -- 635
		end -- 635
		if select ~= nil then -- 635
			select:hide() -- 636
		end -- 636
		if solarHub ~= nil then -- 636
			solarHub.hide() -- 637
		end -- 637
		activeIndex = index -- 638
		showOnlyLevel(index) -- 639
		applyClipPlanes(index) -- 641
		if not wasActive then -- 641
			Director:pushCamera(runtime.camera) -- 642
		end -- 642
		runtime.game:startLevel() -- 643
		print("[escape-velocity] enter " .. runtime.name) -- 644
	end -- 628
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 648
		if resultIndex >= 0 and resultIndex < levelTotal then -- 648
			local rt = slots[resultIndex + 1].runtime -- 650
			if rt ~= nil then -- 650
				return rt -- 651
			end -- 651
		end -- 651
		return activeRuntime() -- 653
	end -- 648
	local function onRetryTap() -- 656
		local rt = resultRuntime() -- 658
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 659
		if resultPanel ~= nil then -- 659
			resultPanel:hide() -- 660
		end -- 660
		if rt ~= nil then -- 660
			rt.game:retry() -- 661
		end -- 661
	end -- 656
	local function ensureSolarHub() -- 664
		if solarHub ~= nil then -- 664
			return solarHub -- 665
		end -- 665
		solarHub = createSolarHub({ -- 666
			root = hubRoot, -- 667
			camera = hubCamera, -- 668
			layer = hubLayer, -- 669
			viewW = viewW, -- 670
			viewH = viewH, -- 671
			fovYDeg = View.fieldOfView, -- 672
			aspect = View.aspectRatio, -- 673
			spherePath = "Assets/Model/Sphere.gltf", -- 674
			onLaunch = function(____, levelIndex) -- 675
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 676
				if solarHub ~= nil then -- 676
					solarHub.hide() -- 677
				end -- 677
				enterLevel(levelIndex) -- 678
			end, -- 675
			onReplayIntro = function() -- 680
				if solarHub ~= nil then -- 680
					solarHub.hide() -- 681
				end -- 681
				startOpening() -- 682
				print("[escape-velocity] opening replay from solarHub") -- 683
			end -- 680
		}) -- 680
		return solarHub -- 686
	end -- 664
	local function onBackToSelectTap() -- 689
		local rt = resultRuntime() -- 690
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 691
		if rt == nil then -- 691
			return -- 692
		end -- 692
		local runtime = rt -- 693
		if not runtime.game:backToSelect() then -- 693
			return -- 695
		end -- 695
		showOnlyLevel(-1) -- 698
		activeIndex = -1 -- 699
		if resultPanel ~= nil then -- 699
			resultPanel:hide() -- 700
		end -- 700
		if finalePanel ~= nil then -- 700
			finalePanel:hide() -- 702
		end -- 702
		if select ~= nil then -- 702
			select:hide() -- 703
		end -- 703
		progress = loadProgress(levelTotal) -- 705
		local hub = ensureSolarHub() -- 706
		useCamera(hubCamera, -1) -- 707
		hub.show(progress) -- 708
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 709
			getTotalRockets(progress, levelTotal), -- 709
			0 -- 709
		)) -- 709
	end -- 689
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 722
		finalePanel = createFinalePanel( -- 725
			uiLayer, -- 725
			viewW, -- 725
			viewH, -- 725
			{onBackToSelect = function() return onBackToSelectTap() end} -- 725
		) -- 725
		resultPanel = createResultPanel( -- 728
			uiLayer, -- 728
			viewW, -- 728
			viewH, -- 728
			{ -- 728
				onRetry = function() return onRetryTap() end, -- 729
				onBackToSelect = function() return onBackToSelectTap() end -- 730
			} -- 730
		) -- 730
		activeResultPanel = resultPanel -- 732
		local created = createLevelSelect( -- 733
			uiLayer, -- 733
			viewW, -- 733
			viewH, -- 733
			{ -- 733
				levels = levelEntries, -- 734
				onPick = function(____, index) -- 735
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 736
					if select ~= nil then -- 736
						select:hide() -- 737
					end -- 737
					enterLevel(index) -- 738
				end, -- 735
				onReplayIntro = function() -- 741
					if select ~= nil then -- 741
						select:hide() -- 742
					end -- 742
					startOpening() -- 743
					print("[escape-velocity] opening replay (user)") -- 744
				end -- 741
			} -- 741
		) -- 741
		select = created -- 747
		return created -- 748
	end -- 722
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 761
		local w = View.size.width -- 762
		local h = View.size.height -- 763
		if w == viewW and h == viewH then -- 763
			return -- 764
		end -- 764
		if opening ~= nil then -- 764
			opening.hide() -- 770
			opening = nil -- 771
		end -- 771
		if select ~= nil then -- 771
			select:hide() -- 773
		end -- 773
		if resultPanel ~= nil then -- 773
			resultPanel:hide() -- 774
		end -- 774
		if finalePanel ~= nil then -- 774
			finalePanel:hide() -- 775
		end -- 775
		do -- 775
			local i = 0 -- 776
			while i < levelTotal do -- 776
				local slot = slots[i + 1] -- 777
				if slot.runtime ~= nil then -- 777
					slot.runtime.world.visible = false -- 779
					slot.runtime.aim:setEnabled(false) -- 780
					slot.runtime.trajectory:clearPrediction() -- 783
					slot.runtime.trajectory:clearTrail() -- 784
					slot.runtime.trajectory:clearGoalRings() -- 786
					slot.runtime.plan:setVisible(false) -- 789
					slot.runtime.plan:clear() -- 790
				end -- 790
				slot.built = false -- 792
				slot.runtime = nil -- 793
				i = i + 1 -- 776
			end -- 776
		end -- 776
		viewW = w -- 797
		viewH = h -- 798
		uiLayer.size = Size(viewW, viewH) -- 799
		openingLayer.size = Size(viewW, viewH) -- 800
		hubLayer.size = Size(viewW, viewH) -- 801
		do -- 801
			local i = 0 -- 802
			while i < levelTotal do -- 802
				levelLayers[i + 1].size = Size(viewW, viewH) -- 802
				i = i + 1 -- 802
			end -- 802
		end -- 802
		if solarHub ~= nil then -- 802
			solarHub.relayout(viewW, viewH) -- 804
		end -- 804
		buildPanels() -- 808
		if activeIndex >= 0 then -- 808
			local keep = activeIndex -- 810
			activeIndex = -1 -- 811
			enterLevel(keep) -- 812
		else -- 812
			local hub = ensureSolarHub() -- 814
			useCamera(hubCamera, -1) -- 815
			hub.show(progress) -- 816
		end -- 816
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 818
	end -- 761
	Director.entry:onAppChange(function(name) -- 822
		if name == "Size" then -- 822
			relayoutForViewport() -- 823
		end -- 823
	end) -- 822
	local introSeen = loadIntroSeen() -- 831
	local forceIntro = false -- 832
	opening = nil -- 833
	startOpening = function() -- 835
		if opening == nil then -- 835
			opening = createOpening({ -- 837
				root = openingRoot, -- 838
				camera = openingCamera, -- 839
				layer = openingLayer, -- 840
				viewW = viewW, -- 841
				viewH = viewH, -- 842
				fovYDeg = View.fieldOfView, -- 843
				aspect = View.aspectRatio, -- 844
				spherePath = "Assets/Model/Sphere.gltf", -- 845
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 846
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 847
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 848
				onFinish = function() -- 849
					introHold = -1 -- 850
					if not introSeen then -- 850
						saveIntroSeen() -- 852
						introSeen = true -- 853
						print("[escape-velocity] intro seen -> saved") -- 854
					end -- 854
					if opening ~= nil then -- 854
						opening.hide() -- 857
					end -- 857
					if select ~= nil then -- 857
						select:hide() -- 858
					end -- 858
					local hub = ensureSolarHub() -- 859
					useCamera(hubCamera, -1) -- 860
					hub.show(progress) -- 861
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 862
						opening.frameIndex(), -- 862
						0 -- 862
					) or "?")) -- 862
				end -- 849
			}) -- 849
		end -- 849
		if opening == nil then -- 849
			return -- 866
		end -- 866
		useCamera(openingCamera, -1) -- 867
		opening.start() -- 868
		print("[escape-velocity] opening start (first launch)") -- 869
	end -- 835
	local startupPanel = buildPanels() -- 872
	local enterReq = Path( -- 884
		Path(".", ".agent", "test-results"), -- 884
		"enter-request.txt" -- 884
	) -- 884
	local autoLaunchAt = -1 -- 885
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 887
	local autoFrame = 0 -- 888
	local autoVX = 0 -- 889
	local autoVY = 0 -- 890
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 898
	local autoBackAt = -1 -- 900
	local autoReenterAt = -1 -- 901
	local autoEntered = false -- 902
	introHold = -1 -- 904
	if Content:exist(enterReq) then -- 904
		local spec = Content:load(enterReq) -- 906
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 907
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 908
		if head == "intro" then -- 908
			forceIntro = true -- 910
			if at >= 0 then -- 910
				local rest = __TS__StringSubstring(spec, at + 1) -- 912
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 913
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 913
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 915
					if v ~= nil and v >= 0 then -- 915
						introHold = v -- 917
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 918
					end -- 918
				end -- 918
			end -- 918
		end -- 918
		local n = tonumber(head) -- 923
		if n ~= nil and n >= 1 and n <= levelTotal then -- 923
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 925
			enterLevel(n - 1) -- 926
			autoEntered = true -- 927
			if at >= 0 then -- 927
				local rest = __TS__StringSubstring(spec, at + 1) -- 929
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 929
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 934
					if f ~= nil and f >= 0 then -- 934
						autoArmAt = f -- 936
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 937
					end -- 937
				else -- 937
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 940
					local c2 = (string.find( -- 941
						rest, -- 941
						":", -- 941
						math.max(c1 + 1 + 1, 1), -- 941
						true -- 941
					) or 0) - 1 -- 941
					if c1 > 0 and c2 > c1 then -- 941
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 943
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 944
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 947
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 948
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 949
						local vy = tonumber(vyText) -- 950
						local ____temp_4 -- 951
						if c3 > 0 then -- 951
							____temp_4 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 951
						else -- 951
							____temp_4 = nil -- 951
						end -- 951
						local steps = ____temp_4 -- 951
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 951
							autoLaunchAt = frames -- 953
							autoVX = vx -- 954
							autoVY = vy -- 955
							if steps ~= nil and steps > 0 then -- 955
								autoWarpSteps = math.floor(steps) -- 957
							end -- 957
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 959
						end -- 959
					end -- 959
				end -- 959
			end -- 959
		end -- 959
	end -- 959
	if autoEntered then -- 959
		print("[escape-velocity] opening skipped (auto enter)") -- 972
	elseif forceIntro or not introSeen then -- 972
		startOpening() -- 974
	else -- 974
		local hub = ensureSolarHub() -- 976
		useCamera(hubCamera, -1) -- 977
		hub.show(progress) -- 978
		print("[escape-velocity] entered solarHub (already seen)") -- 979
	end -- 979
	threadLoop(function() -- 984
		advanceUiClock(App.deltaTime) -- 988
		if solarHub ~= nil and solarHub.visible() then -- 988
			solarHub.step(App.deltaTime) -- 992
		end -- 992
		if opening ~= nil and opening.running() then -- 992
			if introHold < 0 or opening.frameIndex() < introHold then -- 992
				opening.step() -- 998
			end -- 998
			if App.deltaTime > 0.05 then -- 998
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 1002
					opening.frameIndex(), -- 1002
					0 -- 1002
				)) -- 1002
			end -- 1002
		end -- 1002
		local runtime = activeRuntime() -- 1006
		if runtime ~= nil then -- 1006
			runtime.game:update(App.deltaTime) -- 1008
			runtime.aim:setBurnInfo( -- 1010
				runtime.game:burnNow(), -- 1010
				runtime.dvBudget -- 1010
			) -- 1010
			if runtime.levelHasTimeWindow then -- 1010
				runtime.aim:setDate( -- 1013
					runtime.game:dateNow(), -- 1013
					runtime.dateSpan -- 1013
				) -- 1013
			end -- 1013
			local phaseNow = runtime.game:phase() -- 1017
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 1018
			runtime.aim:update(App.deltaTime) -- 1019
			runtime.aim:setArmed(runtime.game:armed()) -- 1021
			runtime.aim:setStarsStatus(runtime.game:starsNow()) -- 1022
			runtime.aim:setBonusStatus( -- 1023
				runtime.game:bonusScore(), -- 1023
				runtime.game:bonusTotal() -- 1023
			) -- 1023
			local is2D = runtime.game:viewMode() == "2D" -- 1025
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 1026
			if runtime.aim.setFlightViewing ~= nil then -- 1026
				runtime.aim:setFlightViewing( -- 1027
					phaseNow == "Flying", -- 1027
					runtime.game:missionCompleted(), -- 1027
					runtime.game:cameraFocus(), -- 1027
					not is2D, -- 1027
					runtime.game:flightStage() -- 1027
				) -- 1027
			end -- 1027
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 1028
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 1029
			runtime.aim:setMissionDrawerVisible(inAim) -- 1030
			local curBurn = runtime.game:burnNow() -- 1032
			local fuelLimit = runtime.dvBudget * 0.75 -- 1033
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 1034
			runtime.aim:setTimeControl( -- 1037
				runtime.game:speedPow(), -- 1038
				runtime.game:speedMinPow(), -- 1039
				runtime.game:speedMaxPow(), -- 1040
				runtime.game:isPaused(), -- 1041
				runtime.game:missionSeconds(), -- 1042
				runtime.game:speedRate() -- 1043
			) -- 1043
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 1043
				autoFrame = autoFrame + 1 -- 1047
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 1047
					autoArmAt = -1 -- 1050
					print("[escape-velocity] auto arm (enter-request)") -- 1051
					runtime.game:aimReady() -- 1052
				end -- 1052
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 1052
					autoLaunchAt = -1 -- 1055
					print("[escape-velocity] auto launch") -- 1056
					if autoWarpSteps > 0 then -- 1056
						do -- 1056
							local s = 0 -- 1060
							while s < autoWarpSteps do -- 1060
								runtime.game:stepTime(1, runtime.dateSpan) -- 1060
								s = s + 1 -- 1060
							end -- 1060
						end -- 1060
						autoWarpSteps = 0 -- 1061
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 1062
							runtime.game:dateNow(), -- 1062
							0 -- 1062
						)) .. ")") -- 1062
					end -- 1062
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 1064
					runtime.game:launch({x = autoVX, y = autoVY}) -- 1065
					autoBackAt = autoFrame + 320 -- 1066
					autoReenterAt = autoFrame + 380 -- 1067
				end -- 1067
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 1067
					autoBackAt = -1 -- 1071
					if runtime.game:backToSelect() then -- 1071
						print("[escape-velocity] auto back to select") -- 1072
					end -- 1072
				end -- 1072
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1072
					autoReenterAt = -1 -- 1075
					print("[escape-velocity] auto re-enter") -- 1076
					enterLevel(0) -- 1077
				end -- 1077
			end -- 1077
		end -- 1077
		return false -- 1082
	end) -- 984
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1086
	debugTriggerResultFn = function(levelIndex, outcome) -- 1088
		if outcome == nil then -- 1088
			outcome = "success" -- 1088
		end -- 1088
		if solarHub ~= nil then -- 1088
			solarHub.hide() -- 1089
		end -- 1089
		if opening ~= nil then -- 1089
			opening.hide() -- 1090
		end -- 1090
		local def = getLevel(levelIndex) -- 1091
		if def == nil or resultPanel == nil then -- 1091
			return -- 1092
		end -- 1092
		local burn = def.dvBudget * 0.65 -- 1093
		local challengesList = {} -- 1094
		if def.mission ~= nil then -- 1094
			do -- 1094
				local k = 0 -- 1096
				while k < #def.mission.challenges do -- 1096
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1097
					k = k + 1 -- 1096
				end -- 1096
			end -- 1096
		end -- 1096
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1100
		resultPanel:show(outcome, titleWithSub, { -- 1104
			result = outcome, -- 1105
			levelName = titleWithSub, -- 1106
			levelIndex = levelIndex, -- 1107
			rocketsGot = outcome == "success" and 3 or 0, -- 1108
			challenges = challengesList, -- 1109
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1110
			burnDv = burn, -- 1111
			dvBudget = def.dvBudget, -- 1112
			flightTime = 12.8, -- 1113
			totalRockets = outcome == "success" and 16 or 13, -- 1114
			totalPossibleRockets = 18 -- 1115
		}) -- 1115
	end -- 1088
	debugTriggerEnterLevelFn = function(levelIndex) -- 1119
		if solarHub ~= nil then -- 1119
			solarHub.hide() -- 1120
		end -- 1120
		if opening ~= nil then -- 1120
			opening.hide() -- 1121
		end -- 1121
		enterLevel(levelIndex) -- 1122
	end -- 1119
	debugGameStateFn = function() -- 1124
		local rt = activeRuntime() -- 1125
		if rt == nil then -- 1125
			return "phase=LevelSelect" -- 1126
		end -- 1126
		local g = rt.game -- 1127
		return (((((((((((((((("phase=" .. g:phase()) .. "\ndate=") .. __TS__NumberToFixed( -- 1128
			g:dateNow(), -- 1128
			6 -- 1128
		)) .. "\nworld=") .. __TS__NumberToFixed( -- 1128
			g:missionSeconds(), -- 1128
			6 -- 1128
		)) .. "\nrate=") .. __TS__NumberToFixed( -- 1128
			g:speedRate(), -- 1129
			6 -- 1129
		)) .. "\npaused=") .. (g:isPaused() and "1" or "0")) .. "\nfocus=") .. g:cameraFocus()) .. "\ncompleted=") .. (g:missionCompleted() and "1" or "0")) .. "\nview=") .. g:viewMode()) .. "\nmarker=") .. __TS__NumberToFixed( -- 1129
			g:markerElapsed(), -- 1130
			6 -- 1130
		) -- 1130
	end -- 1124
	debugTriggerZoomInFn = function() -- 1133
		local rt = activeRuntime() -- 1134
		if rt ~= nil then -- 1134
			rt.plan:zoomIn() -- 1136
		end -- 1136
	end -- 1133
	debugTriggerResetViewFn = function() -- 1140
		local rt = activeRuntime() -- 1141
		if rt ~= nil then -- 1141
			rt.plan:resetView() -- 1143
		end -- 1143
	end -- 1140
end -- 1140
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1149
	return activeResultPanel -- 1150
end -- 1149
--- GameShot 专用的只读状态；输入验收据此等待实际状态，避免固定延迟猜时机。
function ____exports.getDebugGameState() -- 1154
	return debugGameStateFn ~= nil and debugGameStateFn() or "phase=Loading" -- 1155
end -- 1154
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1159
	if outcome == nil then -- 1159
		outcome = "success" -- 1159
	end -- 1159
	if debugTriggerResultFn ~= nil then -- 1159
		debugTriggerResultFn(levelIndex, outcome) -- 1161
	end -- 1161
end -- 1159
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1166
	if debugTriggerEnterLevelFn ~= nil then -- 1166
		debugTriggerEnterLevelFn(levelIndex) -- 1168
	end -- 1168
end -- 1166
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1173
	if debugTriggerZoomInFn ~= nil then -- 1173
		debugTriggerZoomInFn() -- 1175
	end -- 1175
end -- 1173
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1180
	if debugTriggerResetViewFn ~= nil then -- 1180
		debugTriggerResetViewFn() -- 1182
	end -- 1182
end -- 1180
return ____exports -- 1180
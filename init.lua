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
						local maxRockets = #def.bonusPoints > 0 and #def.bonusPoints or 1 -- 481
						evalInfo.achieved = {r == "success", score > 0, score >= maxRockets} -- 482
					end -- 482
					if r == "success" then -- 482
						progress = recordMissionResult( -- 487
							progress, -- 487
							index, -- 487
							score, -- 487
							levelTotal, -- 487
							true -- 487
						) -- 487
						saveProgress(progress) -- 488
					end -- 488
					local currentTotal = getTotalRockets(progress, levelTotal) -- 490
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(totalBonusPoints, 0)) .. ")") -- 492
					resultIndex = index -- 496
					local challengesList = {} -- 498
					if def.bonusPoints == nil and def.mission ~= nil then -- 498
						do -- 498
							local k = 0 -- 500
							while k < #def.mission.challenges do -- 500
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 501
								k = k + 1 -- 500
							end -- 500
						end -- 500
					end -- 500
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 505
					local detailParams = { -- 509
						result = r, -- 510
						levelName = titleWithSub, -- 511
						levelIndex = index, -- 512
						rocketsGot = evalInfo.rockets, -- 513
						challenges = challengesList, -- 514
						completionOnly = def.bonusPoints == nil, -- 515
						bonusPointCount = def.bonusPoints ~= nil and #def.bonusPoints or nil, -- 516
						achieved = evalInfo.achieved, -- 517
						burnDv = telem.burnDv, -- 518
						dvBudget = def.dvBudget, -- 519
						flightTime = telem.flightTime, -- 520
						totalRockets = currentTotal, -- 521
						totalPossibleRockets = totalBonusPoints -- 522
					} -- 522
					if resultPanel ~= nil then -- 522
						resultPanel:show(r, titleWithSub, detailParams) -- 526
					end -- 526
				end, -- 464
				onFinale = function(____, info) -- 530
					finaleText = { -- 531
						main = FinaleMainText, -- 531
						sub = finaleSubtitle(info.distance, info.time) -- 531
					} -- 531
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 532
				end, -- 530
				finale = index == levelTotal - 1 and def.transfer == nil -- 537
			} -- 537
		) -- 537
		aim:onQuickRetry(function() -- 540
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 541
			game:retry() -- 542
		end) -- 540
		aim:onDrag(function(a) -- 548
			if not dragSoundPlayed then -- 548
				playSound("aim_stretch") -- 549
				dragSoundPlayed = true -- 549
			end -- 549
			game:onAimDrag(a) -- 550
			aim:setBurnInfo( -- 552
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 552
				def.dvBudget -- 552
			) -- 552
		end) -- 548
		aim:onAimReady(function(a) -- 555
			dragSoundPlayed = false -- 556
			game:onAimDrag(a) -- 557
			game:aimReady() -- 558
			print("[escape-velocity] aim ready -> Armed") -- 559
		end) -- 555
		aim:onLaunch(function() -- 561
			print("[escape-velocity] launch button tap") -- 562
			playSound("launch") -- 563
			game:launchArmed() -- 564
		end) -- 561
		aim:onCancelAim(function() -- 566
			print("[escape-velocity] cancel aim tap") -- 567
			dragSoundPlayed = false -- 568
			playSound("aim_cancel") -- 569
			game:cancelAim() -- 570
		end) -- 566
		aim:onObserve(function(dx, dy) -- 573
			game:observeDrag(dx, dy) -- 574
		end) -- 573
		aim:onZoom(function(deltaDist) -- 576
			game:observeZoom(deltaDist) -- 577
		end) -- 576
		aim:onSkipTour(function() -- 579
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 580
			game:skipIntroTour() -- 581
		end) -- 579
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 583
		aim:onViewToggle(function() -- 585
			game:toggleViewMode() -- 586
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 587
		end) -- 585
		if aim.onCameraFocus ~= nil then -- 585
			aim:onCameraFocus(function() -- 589
				game:cycleCameraFocus() -- 589
			end) -- 589
		end -- 589
		if aim.onEndViewing ~= nil then -- 589
			aim:onEndViewing(function() -- 590
				game:endViewing() -- 590
			end) -- 590
		end -- 590
		aim:onSpeedUp(function() -- 594
			game:speedUp() -- 595
		end) -- 594
		aim:onSpeedDown(function() -- 597
			game:speedDown() -- 598
		end) -- 597
		aim:onTogglePause(function() -- 600
			game:togglePause() -- 601
		end) -- 600
		aim:onPlayback(function(speed) -- 603
			game:setPlaybackSpeed(speed) -- 604
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 605
		end) -- 603
		aim:setPlayback(game:playbackSpeed()) -- 607
		local runtime = { -- 609
			index = index, -- 610
			name = levelNames[index + 1], -- 611
			world = world, -- 612
			camera = camera, -- 613
			game = game, -- 614
			aim = aim, -- 615
			trajectory = trajectory, -- 616
			plan = plan, -- 617
			levelHasTimeWindow = def.timeWindow ~= nil, -- 618
			dvBudget = def.dvBudget, -- 619
			dateSpan = dateSpan -- 620
		} -- 620
		slot.built = true -- 622
		slot.runtime = runtime -- 623
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 624
		return runtime -- 625
	end -- 257
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 629
		local runtime = ensureLevel(index) -- 630
		if runtime == nil then -- 630
			return -- 631
		end -- 631
		local wasActive = activeIndex == index -- 634
		if opening ~= nil then -- 634
			opening.hide() -- 636
		end -- 636
		if select ~= nil then -- 636
			select:hide() -- 637
		end -- 637
		if solarHub ~= nil then -- 637
			solarHub.hide() -- 638
		end -- 638
		activeIndex = index -- 639
		showOnlyLevel(index) -- 640
		applyClipPlanes(index) -- 642
		if not wasActive then -- 642
			Director:pushCamera(runtime.camera) -- 643
		end -- 643
		runtime.game:startLevel() -- 644
		print("[escape-velocity] enter " .. runtime.name) -- 645
	end -- 629
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 649
		if resultIndex >= 0 and resultIndex < levelTotal then -- 649
			local rt = slots[resultIndex + 1].runtime -- 651
			if rt ~= nil then -- 651
				return rt -- 652
			end -- 652
		end -- 652
		return activeRuntime() -- 654
	end -- 649
	local function onRetryTap() -- 657
		local rt = resultRuntime() -- 659
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 660
		if resultPanel ~= nil then -- 660
			resultPanel:hide() -- 661
		end -- 661
		if rt ~= nil then -- 661
			rt.game:retry() -- 662
		end -- 662
	end -- 657
	local function ensureSolarHub() -- 665
		if solarHub ~= nil then -- 665
			return solarHub -- 666
		end -- 666
		solarHub = createSolarHub({ -- 667
			root = hubRoot, -- 668
			camera = hubCamera, -- 669
			layer = hubLayer, -- 670
			viewW = viewW, -- 671
			viewH = viewH, -- 672
			fovYDeg = View.fieldOfView, -- 673
			aspect = View.aspectRatio, -- 674
			spherePath = "Assets/Model/Sphere.gltf", -- 675
			onLaunch = function(____, levelIndex) -- 676
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 677
				if solarHub ~= nil then -- 677
					solarHub.hide() -- 678
				end -- 678
				enterLevel(levelIndex) -- 679
			end, -- 676
			onReplayIntro = function() -- 681
				if solarHub ~= nil then -- 681
					solarHub.hide() -- 682
				end -- 682
				startOpening() -- 683
				print("[escape-velocity] opening replay from solarHub") -- 684
			end -- 681
		}) -- 681
		return solarHub -- 687
	end -- 665
	local function onBackToSelectTap() -- 690
		local rt = resultRuntime() -- 691
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 692
		if rt == nil then -- 692
			return -- 693
		end -- 693
		local runtime = rt -- 694
		if not runtime.game:backToSelect() then -- 694
			return -- 696
		end -- 696
		showOnlyLevel(-1) -- 699
		activeIndex = -1 -- 700
		if resultPanel ~= nil then -- 700
			resultPanel:hide() -- 701
		end -- 701
		if finalePanel ~= nil then -- 701
			finalePanel:hide() -- 703
		end -- 703
		if select ~= nil then -- 703
			select:hide() -- 704
		end -- 704
		progress = loadProgress(levelTotal) -- 706
		local hub = ensureSolarHub() -- 707
		useCamera(hubCamera, -1) -- 708
		hub.show(progress) -- 709
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 710
			getTotalRockets(progress, levelTotal), -- 710
			0 -- 710
		)) -- 710
	end -- 690
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 723
		finalePanel = createFinalePanel( -- 726
			uiLayer, -- 726
			viewW, -- 726
			viewH, -- 726
			{onBackToSelect = function() return onBackToSelectTap() end} -- 726
		) -- 726
		resultPanel = createResultPanel( -- 729
			uiLayer, -- 729
			viewW, -- 729
			viewH, -- 729
			{ -- 729
				onRetry = function() return onRetryTap() end, -- 730
				onBackToSelect = function() return onBackToSelectTap() end -- 731
			} -- 731
		) -- 731
		activeResultPanel = resultPanel -- 733
		local created = createLevelSelect( -- 734
			uiLayer, -- 734
			viewW, -- 734
			viewH, -- 734
			{ -- 734
				levels = levelEntries, -- 735
				onPick = function(____, index) -- 736
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 737
					if select ~= nil then -- 737
						select:hide() -- 738
					end -- 738
					enterLevel(index) -- 739
				end, -- 736
				onReplayIntro = function() -- 742
					if select ~= nil then -- 742
						select:hide() -- 743
					end -- 743
					startOpening() -- 744
					print("[escape-velocity] opening replay (user)") -- 745
				end -- 742
			} -- 742
		) -- 742
		select = created -- 748
		return created -- 749
	end -- 723
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 762
		local w = View.size.width -- 763
		local h = View.size.height -- 764
		if w == viewW and h == viewH then -- 764
			return -- 765
		end -- 765
		if opening ~= nil then -- 765
			opening.hide() -- 771
			opening = nil -- 772
		end -- 772
		if select ~= nil then -- 772
			select:hide() -- 774
		end -- 774
		if resultPanel ~= nil then -- 774
			resultPanel:hide() -- 775
		end -- 775
		if finalePanel ~= nil then -- 775
			finalePanel:hide() -- 776
		end -- 776
		do -- 776
			local i = 0 -- 777
			while i < levelTotal do -- 777
				local slot = slots[i + 1] -- 778
				if slot.runtime ~= nil then -- 778
					slot.runtime.world.visible = false -- 780
					slot.runtime.aim:setEnabled(false) -- 781
					slot.runtime.trajectory:clearPrediction() -- 784
					slot.runtime.trajectory:clearTrail() -- 785
					slot.runtime.trajectory:clearGoalRings() -- 787
					slot.runtime.plan:setVisible(false) -- 790
					slot.runtime.plan:clear() -- 791
				end -- 791
				slot.built = false -- 793
				slot.runtime = nil -- 794
				i = i + 1 -- 777
			end -- 777
		end -- 777
		viewW = w -- 798
		viewH = h -- 799
		uiLayer.size = Size(viewW, viewH) -- 800
		openingLayer.size = Size(viewW, viewH) -- 801
		hubLayer.size = Size(viewW, viewH) -- 802
		do -- 802
			local i = 0 -- 803
			while i < levelTotal do -- 803
				levelLayers[i + 1].size = Size(viewW, viewH) -- 803
				i = i + 1 -- 803
			end -- 803
		end -- 803
		if solarHub ~= nil then -- 803
			solarHub.relayout(viewW, viewH) -- 805
		end -- 805
		buildPanels() -- 809
		if activeIndex >= 0 then -- 809
			local keep = activeIndex -- 811
			activeIndex = -1 -- 812
			enterLevel(keep) -- 813
		else -- 813
			local hub = ensureSolarHub() -- 815
			useCamera(hubCamera, -1) -- 816
			hub.show(progress) -- 817
		end -- 817
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 819
	end -- 762
	Director.entry:onAppChange(function(name) -- 823
		if name == "Size" then -- 823
			relayoutForViewport() -- 824
		end -- 824
	end) -- 823
	local introSeen = loadIntroSeen() -- 832
	local forceIntro = false -- 833
	opening = nil -- 834
	startOpening = function() -- 836
		if opening == nil then -- 836
			opening = createOpening({ -- 838
				root = openingRoot, -- 839
				camera = openingCamera, -- 840
				layer = openingLayer, -- 841
				viewW = viewW, -- 842
				viewH = viewH, -- 843
				fovYDeg = View.fieldOfView, -- 844
				aspect = View.aspectRatio, -- 845
				spherePath = "Assets/Model/Sphere.gltf", -- 846
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 847
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 848
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 849
				onFinish = function() -- 850
					introHold = -1 -- 851
					if not introSeen then -- 851
						saveIntroSeen() -- 853
						introSeen = true -- 854
						print("[escape-velocity] intro seen -> saved") -- 855
					end -- 855
					if opening ~= nil then -- 855
						opening.hide() -- 858
					end -- 858
					if select ~= nil then -- 858
						select:hide() -- 859
					end -- 859
					local hub = ensureSolarHub() -- 860
					useCamera(hubCamera, -1) -- 861
					hub.show(progress) -- 862
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 863
						opening.frameIndex(), -- 863
						0 -- 863
					) or "?")) -- 863
				end -- 850
			}) -- 850
		end -- 850
		if opening == nil then -- 850
			return -- 867
		end -- 867
		useCamera(openingCamera, -1) -- 868
		opening.start() -- 869
		print("[escape-velocity] opening start (first launch)") -- 870
	end -- 836
	local startupPanel = buildPanels() -- 873
	local enterReq = Path( -- 885
		Path(".", ".agent", "test-results"), -- 885
		"enter-request.txt" -- 885
	) -- 885
	local autoLaunchAt = -1 -- 886
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 888
	local autoFrame = 0 -- 889
	local autoVX = 0 -- 890
	local autoVY = 0 -- 891
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 899
	local autoBackAt = -1 -- 901
	local autoReenterAt = -1 -- 902
	local autoEntered = false -- 903
	introHold = -1 -- 905
	if Content:exist(enterReq) then -- 905
		local spec = Content:load(enterReq) -- 907
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 908
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 909
		if head == "intro" then -- 909
			forceIntro = true -- 911
			if at >= 0 then -- 911
				local rest = __TS__StringSubstring(spec, at + 1) -- 913
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 914
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 914
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 916
					if v ~= nil and v >= 0 then -- 916
						introHold = v -- 918
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 919
					end -- 919
				end -- 919
			end -- 919
		end -- 919
		local n = tonumber(head) -- 924
		if n ~= nil and n >= 1 and n <= levelTotal then -- 924
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 926
			enterLevel(n - 1) -- 927
			autoEntered = true -- 928
			if at >= 0 then -- 928
				local rest = __TS__StringSubstring(spec, at + 1) -- 930
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 930
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 935
					if f ~= nil and f >= 0 then -- 935
						autoArmAt = f -- 937
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 938
					end -- 938
				else -- 938
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 941
					local c2 = (string.find( -- 942
						rest, -- 942
						":", -- 942
						math.max(c1 + 1 + 1, 1), -- 942
						true -- 942
					) or 0) - 1 -- 942
					if c1 > 0 and c2 > c1 then -- 942
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 944
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 945
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 948
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 949
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 950
						local vy = tonumber(vyText) -- 951
						local ____temp_4 -- 952
						if c3 > 0 then -- 952
							____temp_4 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 952
						else -- 952
							____temp_4 = nil -- 952
						end -- 952
						local steps = ____temp_4 -- 952
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 952
							autoLaunchAt = frames -- 954
							autoVX = vx -- 955
							autoVY = vy -- 956
							if steps ~= nil and steps > 0 then -- 956
								autoWarpSteps = math.floor(steps) -- 958
							end -- 958
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 960
						end -- 960
					end -- 960
				end -- 960
			end -- 960
		end -- 960
	end -- 960
	if autoEntered then -- 960
		print("[escape-velocity] opening skipped (auto enter)") -- 973
	elseif forceIntro or not introSeen then -- 973
		startOpening() -- 975
	else -- 975
		local hub = ensureSolarHub() -- 977
		useCamera(hubCamera, -1) -- 978
		hub.show(progress) -- 979
		print("[escape-velocity] entered solarHub (already seen)") -- 980
	end -- 980
	threadLoop(function() -- 985
		advanceUiClock(App.deltaTime) -- 989
		if solarHub ~= nil and solarHub.visible() then -- 989
			solarHub.step(App.deltaTime) -- 993
		end -- 993
		if opening ~= nil and opening.running() then -- 993
			if introHold < 0 or opening.frameIndex() < introHold then -- 993
				opening.step() -- 999
			end -- 999
			if App.deltaTime > 0.05 then -- 999
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 1003
					opening.frameIndex(), -- 1003
					0 -- 1003
				)) -- 1003
			end -- 1003
		end -- 1003
		local runtime = activeRuntime() -- 1007
		if runtime ~= nil then -- 1007
			runtime.game:update(App.deltaTime) -- 1009
			runtime.aim:setBurnInfo( -- 1011
				runtime.game:burnNow(), -- 1011
				runtime.dvBudget -- 1011
			) -- 1011
			if runtime.levelHasTimeWindow then -- 1011
				runtime.aim:setDate( -- 1014
					runtime.game:dateNow(), -- 1014
					runtime.dateSpan -- 1014
				) -- 1014
			end -- 1014
			local phaseNow = runtime.game:phase() -- 1018
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 1019
			runtime.aim:update(App.deltaTime) -- 1020
			runtime.aim:setArmed(runtime.game:armed()) -- 1022
			runtime.aim:setStarsStatus(runtime.game:starsNow()) -- 1023
			runtime.aim:setBonusStatus( -- 1024
				runtime.game:bonusScore(), -- 1024
				runtime.game:bonusTotal() -- 1024
			) -- 1024
			local is2D = runtime.game:viewMode() == "2D" -- 1026
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 1027
			if runtime.aim.setFlightViewing ~= nil then -- 1027
				runtime.aim:setFlightViewing( -- 1028
					phaseNow == "Flying", -- 1028
					runtime.game:missionCompleted(), -- 1028
					runtime.game:cameraFocus(), -- 1028
					not is2D, -- 1028
					runtime.game:flightStage() -- 1028
				) -- 1028
			end -- 1028
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 1029
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 1030
			runtime.aim:setMissionDrawerVisible(inAim) -- 1031
			local curBurn = runtime.game:burnNow() -- 1033
			local fuelLimit = runtime.dvBudget * 0.75 -- 1034
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 1035
			runtime.aim:setTimeControl( -- 1038
				runtime.game:speedPow(), -- 1039
				runtime.game:speedMinPow(), -- 1040
				runtime.game:speedMaxPow(), -- 1041
				runtime.game:isPaused(), -- 1042
				runtime.game:missionSeconds(), -- 1043
				runtime.game:speedRate() -- 1044
			) -- 1044
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 1044
				autoFrame = autoFrame + 1 -- 1048
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 1048
					autoArmAt = -1 -- 1051
					print("[escape-velocity] auto arm (enter-request)") -- 1052
					runtime.game:aimReady() -- 1053
				end -- 1053
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 1053
					autoLaunchAt = -1 -- 1056
					print("[escape-velocity] auto launch") -- 1057
					if autoWarpSteps > 0 then -- 1057
						do -- 1057
							local s = 0 -- 1061
							while s < autoWarpSteps do -- 1061
								runtime.game:stepTime(1, runtime.dateSpan) -- 1061
								s = s + 1 -- 1061
							end -- 1061
						end -- 1061
						autoWarpSteps = 0 -- 1062
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 1063
							runtime.game:dateNow(), -- 1063
							0 -- 1063
						)) .. ")") -- 1063
					end -- 1063
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 1065
					runtime.game:launch({x = autoVX, y = autoVY}) -- 1066
					autoBackAt = autoFrame + 320 -- 1067
					autoReenterAt = autoFrame + 380 -- 1068
				end -- 1068
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 1068
					autoBackAt = -1 -- 1072
					if runtime.game:backToSelect() then -- 1072
						print("[escape-velocity] auto back to select") -- 1073
					end -- 1073
				end -- 1073
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1073
					autoReenterAt = -1 -- 1076
					print("[escape-velocity] auto re-enter") -- 1077
					enterLevel(0) -- 1078
				end -- 1078
			end -- 1078
		end -- 1078
		return false -- 1083
	end) -- 985
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1087
	debugTriggerResultFn = function(levelIndex, outcome) -- 1089
		if outcome == nil then -- 1089
			outcome = "success" -- 1089
		end -- 1089
		if solarHub ~= nil then -- 1089
			solarHub.hide() -- 1090
		end -- 1090
		if opening ~= nil then -- 1090
			opening.hide() -- 1091
		end -- 1091
		local def = getLevel(levelIndex) -- 1092
		if def == nil or resultPanel == nil then -- 1092
			return -- 1093
		end -- 1093
		local burn = def.dvBudget * 0.65 -- 1094
		local challengesList = {} -- 1095
		if def.mission ~= nil then -- 1095
			do -- 1095
				local k = 0 -- 1097
				while k < #def.mission.challenges do -- 1097
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1098
					k = k + 1 -- 1097
				end -- 1097
			end -- 1097
		end -- 1097
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1101
		resultPanel:show(outcome, titleWithSub, { -- 1105
			result = outcome, -- 1106
			levelName = titleWithSub, -- 1107
			levelIndex = levelIndex, -- 1108
			rocketsGot = outcome == "success" and 3 or 0, -- 1109
			challenges = challengesList, -- 1110
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1111
			burnDv = burn, -- 1112
			dvBudget = def.dvBudget, -- 1113
			flightTime = 12.8, -- 1114
			totalRockets = outcome == "success" and 16 or 13, -- 1115
			totalPossibleRockets = 18 -- 1116
		}) -- 1116
	end -- 1089
	debugTriggerEnterLevelFn = function(levelIndex) -- 1120
		if solarHub ~= nil then -- 1120
			solarHub.hide() -- 1121
		end -- 1121
		if opening ~= nil then -- 1121
			opening.hide() -- 1122
		end -- 1122
		enterLevel(levelIndex) -- 1123
	end -- 1120
	debugGameStateFn = function() -- 1125
		local rt = activeRuntime() -- 1126
		if rt == nil then -- 1126
			return "phase=LevelSelect" -- 1127
		end -- 1127
		local g = rt.game -- 1128
		return (((((((((((((((("phase=" .. g:phase()) .. "\ndate=") .. __TS__NumberToFixed( -- 1129
			g:dateNow(), -- 1129
			6 -- 1129
		)) .. "\nworld=") .. __TS__NumberToFixed( -- 1129
			g:missionSeconds(), -- 1129
			6 -- 1129
		)) .. "\nrate=") .. __TS__NumberToFixed( -- 1129
			g:speedRate(), -- 1130
			6 -- 1130
		)) .. "\npaused=") .. (g:isPaused() and "1" or "0")) .. "\nfocus=") .. g:cameraFocus()) .. "\ncompleted=") .. (g:missionCompleted() and "1" or "0")) .. "\nview=") .. g:viewMode()) .. "\nmarker=") .. __TS__NumberToFixed( -- 1130
			g:markerElapsed(), -- 1131
			6 -- 1131
		) -- 1131
	end -- 1125
	debugTriggerZoomInFn = function() -- 1134
		local rt = activeRuntime() -- 1135
		if rt ~= nil then -- 1135
			rt.plan:zoomIn() -- 1137
		end -- 1137
	end -- 1134
	debugTriggerResetViewFn = function() -- 1141
		local rt = activeRuntime() -- 1142
		if rt ~= nil then -- 1142
			rt.plan:resetView() -- 1144
		end -- 1144
	end -- 1141
end -- 1141
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1150
	return activeResultPanel -- 1151
end -- 1150
--- GameShot 专用的只读状态；输入验收据此等待实际状态，避免固定延迟猜时机。
function ____exports.getDebugGameState() -- 1155
	return debugGameStateFn ~= nil and debugGameStateFn() or "phase=Loading" -- 1156
end -- 1155
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1160
	if outcome == nil then -- 1160
		outcome = "success" -- 1160
	end -- 1160
	if debugTriggerResultFn ~= nil then -- 1160
		debugTriggerResultFn(levelIndex, outcome) -- 1162
	end -- 1162
end -- 1160
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1167
	if debugTriggerEnterLevelFn ~= nil then -- 1167
		debugTriggerEnterLevelFn(levelIndex) -- 1169
	end -- 1169
end -- 1167
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1174
	if debugTriggerZoomInFn ~= nil then -- 1174
		debugTriggerZoomInFn() -- 1176
	end -- 1176
end -- 1174
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1181
	if debugTriggerResetViewFn ~= nil then -- 1181
		debugTriggerResetViewFn() -- 1183
	end -- 1183
end -- 1181
return ____exports -- 1181
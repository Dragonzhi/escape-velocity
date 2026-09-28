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
local GameSecondsPerRealSecond = ____LevelData.GameSecondsPerRealSecond -- 22
local evaluateRocketsDetailed = ____LevelData.evaluateRocketsDetailed -- 22
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
local function applyClipPlanes(index) -- 81
	local near = CLIP_NEAR_DEFAULT -- 82
	local far = 0 -- 84
	if index >= 0 then -- 84
		local rt = levelRuntime(index) -- 86
		if rt.cameraNear ~= nil and rt.cameraNear > 0 then -- 86
			near = rt.cameraNear -- 87
		end -- 87
		if rt.cameraFar ~= nil and rt.cameraFar > 0 then -- 87
			far = rt.cameraFar -- 88
		end -- 88
	end -- 88
	local prevNear = View.nearPlaneDistance -- 90
	local prevFar = View.farPlaneDistance -- 91
	local changed = math.abs(prevNear - near) > near * 0.000001 -- 93
	if changed then -- 93
		View.nearPlaneDistance = near -- 94
	end -- 94
	if far > 0 and math.abs(prevFar - far) > far * 0.000001 then -- 94
		View.farPlaneDistance = far -- 96
		changed = true -- 97
	end -- 97
	if not changed then -- 97
		return -- 99
	end -- 99
	print(((((((((("[escape-velocity] clip planes near=" .. __TS__NumberToFixed(prevNear, 6)) .. "->") .. __TS__NumberToFixed(View.nearPlaneDistance, 6)) .. " far=") .. __TS__NumberToFixed(prevFar, 0)) .. "->") .. __TS__NumberToFixed(View.farPlaneDistance, 0)) .. " (") .. (index >= 0 and "L" .. __TS__NumberToFixed(index + 1, 0) or "hub/opening")) .. ")") -- 100
end -- 81
--- 切相机：先同步裁剪面再推栈（两者必须一起切，否则下一关的近平面是上一关的）。
local function useCamera(camera, levelIndex) -- 106
	applyClipPlanes(levelIndex) -- 107
	Director:pushCamera(camera) -- 108
end -- 106
local debugTriggerResultFn = nil -- 111
local debugTriggerBrakeWindowFn = nil -- 112
local debugTriggerBrakePressFn = nil -- 113
local debugTriggerEnterLevelFn = nil -- 114
local debugTriggerZoomInFn = nil -- 115
local debugTriggerResetViewFn = nil -- 116
local debugForceBrakeWindow = false -- 117
local debugForceBraked = false -- 118
local activeResultPanel = nil -- 119
local levelTotal = levelCount() -- 127
if levelTotal <= 0 then -- 127
	print("[escape-velocity] FATAL: no level data") -- 130
else -- 130
	local opening, startOpening, introHold -- 130
	local viewW = View.size.width -- 132
	local viewH = View.size.height -- 133
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 136
	local levelLayers = {} -- 142
	do -- 142
		local i = 0 -- 143
		while i < levelTotal do -- 143
			local layer = Node() -- 144
			layer.size = Size(viewW, viewH) -- 145
			layer.anchor = Vec2(0.5, 0.5) -- 146
			layer.position = Vec2(0, 0) -- 147
			Director.ui:addChild(layer) -- 148
			levelLayers[#levelLayers + 1] = layer -- 149
			i = i + 1 -- 143
		end -- 143
	end -- 143
	local openingLayer = Node() -- 154
	openingLayer.size = Size(viewW, viewH) -- 155
	openingLayer.anchor = Vec2(0.5, 0.5) -- 156
	openingLayer.position = Vec2(0, 0) -- 157
	Director.ui:addChild(openingLayer) -- 158
	local openingRoot = Node3D() -- 161
	openingRoot.visible = false -- 162
	Director.entry:addChild(openingRoot) -- 163
	local openingCamera = Camera3D() -- 164
	local hubRoot = Node3D() -- 167
	hubRoot.visible = false -- 168
	Director.entry:addChild(hubRoot) -- 169
	local hubCamera = Camera3D() -- 170
	local hubLayer = Node() -- 172
	hubLayer.size = Size(viewW, viewH) -- 173
	hubLayer.anchor = Vec2(0.5, 0.5) -- 174
	hubLayer.position = Vec2(0, 0) -- 175
	Director.ui:addChild(hubLayer) -- 176
	local uiLayer = Node() -- 179
	uiLayer.size = Size(viewW, viewH) -- 180
	uiLayer.anchor = Vec2(0.5, 0.5) -- 181
	uiLayer.position = Vec2(0, 0) -- 182
	Director.ui:addChild(uiLayer) -- 183
	local levelNames = {} -- 186
	do -- 186
		local i = 0 -- 187
		while i < levelTotal do -- 187
			local def = getLevel(i) -- 188
			local title = def ~= nil and def.title or "" -- 189
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 190
			i = i + 1 -- 187
		end -- 187
	end -- 187
	local levelEntries = {} -- 192
	do -- 192
		local i = 0 -- 193
		while i < levelTotal do -- 193
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 193
			i = i + 1 -- 193
		end -- 193
	end -- 193
	local progress = loadProgress(levelTotal) -- 196
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 197
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 198
	local slots = {} -- 200
	do -- 200
		local i = 0 -- 201
		while i < levelTotal do -- 201
			slots[#slots + 1] = {built = false, runtime = nil} -- 201
			i = i + 1 -- 201
		end -- 201
	end -- 201
	local activeIndex = -1 -- 203
	local select = nil -- 204
	local solarHub = nil -- 205
	local resultPanel = nil -- 206
	local finalePanel = nil -- 208
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 210
	local resultIndex = -1 -- 215
	local function activeRuntime() -- 217
		if activeIndex < 0 then -- 217
			return nil -- 218
		end -- 218
		return slots[activeIndex + 1].runtime -- 219
	end -- 217
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 227
		do -- 227
			local i = 0 -- 228
			while i < levelTotal do -- 228
				do -- 228
					local slot = slots[i + 1] -- 229
					levelLayers[i + 1].visible = i == index -- 232
					if slot.runtime == nil then -- 232
						goto __continue24 -- 233
					end -- 233
					local active = i == index -- 234
					slot.runtime.world.visible = active -- 235
					slot.runtime.aim:setEnabled(active) -- 236
					if active then -- 236
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 238
					end -- 238
				end -- 238
				::__continue24:: -- 238
				i = i + 1 -- 228
			end -- 228
		end -- 228
	end -- 227
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 247
		local game -- 247
		local slot = slots[index + 1] -- 248
		if slot.built and slot.runtime ~= nil then -- 248
			return slot.runtime -- 249
		end -- 249
		local def = getLevel(index) -- 251
		if def == nil then -- 251
			return nil -- 252
		end -- 252
		local bodies = scaledPlanets(def) -- 254
		local level = { -- 255
			bodies = bodies, -- 256
			probeStart = def.probeStart, -- 257
			probeVel0 = def.probeVel0, -- 259
			goal = def.goal, -- 260
			escapeRadius = def.escapeRadius, -- 261
			physicsStep = levelRuntime(index).physicsStep, -- 262
			speedUnit = GameSecondsPerRealSecond, -- 264
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 265
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 266
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 267
			aimFraming = levelRuntime(index).aimFraming, -- 268
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 269
			aimMin = levelRuntime(index).aimMin, -- 270
			maxSteps = def.maxSteps, -- 271
			predictSteps = levelRuntime(index).predictSteps, -- 272
			mission = def.mission, -- 273
			stars = def.stars -- 274
		} -- 274
		local world = Node3D() -- 277
		Director.entry:addChild(world) -- 278
		world.visible = false -- 279
		local rtg = def.probeVariant == "rtg" -- 281
		local scene = buildScene({ -- 282
			root = world, -- 283
			bodies = bodies, -- 284
			visuals = def.visuals, -- 285
			probeStart = level.probeStart, -- 286
			stars = def.stars, -- 287
			probeScale = levelRuntime(index).probeVisualRadius, -- 293
			spherePath = "Assets/Model/Sphere.gltf", -- 294
			ringPath = "Assets/Model/Ring.gltf", -- 295
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 296
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 303
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 304
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 305
			probeBodyRadius = rtg and 0.871 or 1.084, -- 306
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 308
			orbitFlowDots = levelRuntime(index).orbitFlowDots, -- 309
			orbitRings = levelRuntime(index).orbitRings -- 312
		}) -- 312
		if scene == nil then -- 312
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 315
			return nil -- 316
		end -- 316
		local rt = levelRuntime(index) -- 319
		local camera = Camera3D() -- 320
		local rig = createCameraRig(defaultRigOptions( -- 324
			View.fieldOfView, -- 324
			View.aspectRatio, -- 324
			rt.cameraMin, -- 324
			rt.cameraMax, -- 324
			rt.tiltDeg -- 324
		)) -- 324
		local trajectory = createTrajectoryView( -- 325
			levelLayers[index + 1], -- 325
			trajectoryOptions() -- 325
		) -- 325
		local planOpts = defaultPlanOptions() -- 329
		if levelRuntime(index).orbitFlowDots == false then -- 329
			planOpts.flowDotRadius = 0 -- 330
		end -- 330
		planOpts.probeVisualRadius = levelRuntime(index).probeVisualRadius -- 333
		local plan = createPlanView( -- 334
			levelLayers[index + 1], -- 334
			viewW, -- 334
			viewH, -- 334
			planOpts, -- 334
			def.planCenter -- 334
		) -- 334
		local planTolerance = arrivalRingRadius(def.goal) -- 335
		plan:fitTo(planFitRadius( -- 336
			bodies, -- 336
			level.probeStart, -- 336
			def.goal.planetIndex, -- 336
			planTolerance, -- 336
			def.planCenter -- 336
		)) -- 336
		local aim = createAimInput( -- 338
			levelLayers[index + 1], -- 338
			viewW, -- 338
			viewH, -- 338
			def.dvBudget, -- 338
			rt.aimMin, -- 338
			rt.playbackSpeeds -- 338
		) -- 338
		aim:setBurnInfo(0, def.dvBudget) -- 340
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 342
		aim:setDate(0, dateSpan) -- 343
		aim:onWarp(function(dir) -- 344
			game:stepTime(dir, dateSpan) -- 345
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 346
		end) -- 344
		aim:onZoomIn(function() -- 350
			plan:zoomIn() -- 351
		end) -- 350
		aim:onZoomOut(function() -- 353
			plan:zoomOut() -- 354
		end) -- 353
		aim:onFitView(function() -- 356
			plan:resetView() -- 357
		end) -- 356
		local challengesList = {} -- 361
		if def.mission ~= nil then -- 361
			do -- 361
				local k = 0 -- 363
				while k < #def.mission.challenges do -- 363
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 364
					k = k + 1 -- 363
				end -- 363
			end -- 363
		end -- 363
		local initialRockets = getMissionRockets(progress, index) -- 367
		local drawerTitle = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 368
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 369
		game = createGame( -- 371
			level, -- 371
			{ -- 371
				scene = scene, -- 372
				camera = camera, -- 373
				rig = rig, -- 374
				trajectory = trajectory, -- 375
				plan = plan, -- 376
				visuals = def.visuals, -- 378
				setWorldVisible = function(____, on) -- 380
					world.visible = on -- 381
				end, -- 380
				aim = aim, -- 383
				viewW = viewW, -- 384
				viewH = viewH, -- 385
				fovYDeg = View.fieldOfView, -- 386
				aspect = View.aspectRatio, -- 387
				onPhase = function(____, p) -- 388
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 389
					if index == activeIndex then -- 389
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 396
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 397
						aim:setMissionDrawerVisible(inAim) -- 398
						if p == "Finale" then -- 398
							if resultPanel ~= nil then -- 398
								resultPanel:hide() -- 400
							end -- 400
							if finalePanel ~= nil then -- 400
								finalePanel:show(finaleText.main, finaleText.sub) -- 401
							end -- 401
						else -- 401
							if p ~= "Result" and resultPanel ~= nil then -- 401
								resultPanel:hide() -- 403
							end -- 403
							if finalePanel ~= nil then -- 403
								finalePanel:hide() -- 404
							end -- 404
						end -- 404
					end -- 404
				end, -- 388
				onResult = function(____, r, telemetry) -- 408
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 409
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity}) -- 415
					progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 422
					saveProgress(progress) -- 423
					local currentTotal = getTotalRockets(progress, levelTotal) -- 424
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 426
					resultIndex = index -- 430
					local challengesList = {} -- 432
					if def.mission ~= nil then -- 432
						do -- 432
							local k = 0 -- 434
							while k < #def.mission.challenges do -- 434
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 435
								k = k + 1 -- 434
							end -- 434
						end -- 434
					end -- 434
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 439
					local detailParams = { -- 443
						result = r, -- 444
						levelName = titleWithSub, -- 445
						levelIndex = index, -- 446
						rocketsGot = evalInfo.rockets, -- 447
						challenges = challengesList, -- 448
						achieved = evalInfo.achieved, -- 449
						burnDv = telem.burnDv, -- 450
						dvBudget = def.dvBudget, -- 451
						flightTime = telem.flightTime, -- 452
						totalRockets = currentTotal, -- 453
						totalPossibleRockets = levelTotal * 3 -- 454
					} -- 454
					if resultPanel ~= nil then -- 454
						resultPanel:show(r, titleWithSub, detailParams) -- 458
					end -- 458
				end, -- 408
				onFinale = function(____, info) -- 462
					finaleText = { -- 463
						main = FinaleMainText, -- 463
						sub = finaleSubtitle(info.distance, info.time) -- 463
					} -- 463
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 464
				end, -- 462
				finale = index == levelTotal - 1 -- 469
			} -- 469
		) -- 469
		aim:onQuickRetry(function() -- 472
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 473
			game:retry() -- 474
		end) -- 472
		aim:onDrag(function(a) -- 480
			game:onAimDrag(a) -- 481
			aim:setBurnInfo( -- 483
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 483
				def.dvBudget -- 483
			) -- 483
		end) -- 480
		aim:onAimReady(function(a) -- 486
			game:onAimDrag(a) -- 487
			game:aimReady() -- 488
			print("[escape-velocity] aim ready -> Armed") -- 489
		end) -- 486
		aim:onLaunch(function() -- 491
			print("[escape-velocity] launch button tap") -- 492
			game:launchArmed() -- 493
		end) -- 491
		aim:onObserve(function(dx, dy) -- 496
			game:observeDrag(dx, dy) -- 497
		end) -- 496
		aim:onZoom(function(deltaDist) -- 499
			game:observeZoom(deltaDist) -- 500
		end) -- 499
		aim:onSkipTour(function() -- 502
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 503
			game:skipIntroTour() -- 504
		end) -- 502
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 506
		aim:onViewToggle(function() -- 508
			game:toggleViewMode() -- 509
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 510
		end) -- 508
		aim:onBrake(function(on) -- 513
			game:setBrakeMode(on) -- 514
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 515
		end) -- 513
		aim:setBrake(game:brakeMode()) -- 517
		aim:onSpeedUp(function() -- 521
			game:speedUp() -- 522
		end) -- 521
		aim:onSpeedDown(function() -- 524
			game:speedDown() -- 525
		end) -- 524
		aim:onTogglePause(function() -- 527
			game:togglePause() -- 528
		end) -- 527
		aim:onPlayback(function(speed) -- 530
			game:setPlaybackSpeed(speed) -- 531
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 532
		end) -- 530
		aim:setPlayback(game:playbackSpeed()) -- 534
		aim:onLiveBrake(function() -- 536
			print(("[escape-velocity] tap: live brake (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 537
			game:applyInFlightBrake() -- 538
		end) -- 536
		local runtime = { -- 541
			index = index, -- 542
			name = levelNames[index + 1], -- 543
			world = world, -- 544
			camera = camera, -- 545
			game = game, -- 546
			aim = aim, -- 547
			trajectory = trajectory, -- 548
			plan = plan, -- 549
			levelHasTimeWindow = def.timeWindow ~= nil, -- 550
			dvBudget = def.dvBudget, -- 551
			dateSpan = dateSpan -- 552
		} -- 552
		slot.built = true -- 554
		slot.runtime = runtime -- 555
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 556
		return runtime -- 557
	end -- 247
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 561
		local runtime = ensureLevel(index) -- 562
		if runtime == nil then -- 562
			return -- 563
		end -- 563
		local wasActive = activeIndex == index -- 566
		if opening ~= nil then -- 566
			opening.hide() -- 568
		end -- 568
		if select ~= nil then -- 568
			select:hide() -- 569
		end -- 569
		if solarHub ~= nil then -- 569
			solarHub.hide() -- 570
		end -- 570
		activeIndex = index -- 571
		showOnlyLevel(index) -- 572
		applyClipPlanes(index) -- 574
		if not wasActive then -- 574
			Director:pushCamera(runtime.camera) -- 575
		end -- 575
		runtime.game:startLevel() -- 576
		print("[escape-velocity] enter " .. runtime.name) -- 577
	end -- 561
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 581
		if resultIndex >= 0 and resultIndex < levelTotal then -- 581
			local rt = slots[resultIndex + 1].runtime -- 583
			if rt ~= nil then -- 583
				return rt -- 584
			end -- 584
		end -- 584
		return activeRuntime() -- 586
	end -- 581
	local function onRetryTap() -- 589
		local rt = resultRuntime() -- 591
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 592
		if resultPanel ~= nil then -- 592
			resultPanel:hide() -- 593
		end -- 593
		if rt ~= nil then -- 593
			rt.game:retry() -- 594
		end -- 594
	end -- 589
	local function ensureSolarHub() -- 597
		if solarHub ~= nil then -- 597
			return solarHub -- 598
		end -- 598
		solarHub = createSolarHub({ -- 599
			root = hubRoot, -- 600
			camera = hubCamera, -- 601
			layer = hubLayer, -- 602
			viewW = viewW, -- 603
			viewH = viewH, -- 604
			fovYDeg = View.fieldOfView, -- 605
			aspect = View.aspectRatio, -- 606
			spherePath = "Assets/Model/Sphere.gltf", -- 607
			onLaunch = function(____, levelIndex) -- 608
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 609
				if solarHub ~= nil then -- 609
					solarHub.hide() -- 610
				end -- 610
				enterLevel(levelIndex) -- 611
			end, -- 608
			onReplayIntro = function() -- 613
				if solarHub ~= nil then -- 613
					solarHub.hide() -- 614
				end -- 614
				startOpening() -- 615
				print("[escape-velocity] opening replay from solarHub") -- 616
			end -- 613
		}) -- 613
		return solarHub -- 619
	end -- 597
	local function onBackToSelectTap() -- 622
		local rt = resultRuntime() -- 623
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 624
		if rt == nil then -- 624
			return -- 625
		end -- 625
		local runtime = rt -- 626
		if not runtime.game:backToSelect() then -- 626
			return -- 628
		end -- 628
		runtime.world.visible = false -- 629
		runtime.aim:setEnabled(false) -- 630
		if resultPanel ~= nil then -- 630
			resultPanel:hide() -- 631
		end -- 631
		if finalePanel ~= nil then -- 631
			finalePanel:hide() -- 633
		end -- 633
		if select ~= nil then -- 633
			select:hide() -- 634
		end -- 634
		progress = loadProgress(levelTotal) -- 636
		local hub = ensureSolarHub() -- 637
		useCamera(hubCamera, -1) -- 638
		hub.show(progress) -- 639
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 640
			getTotalRockets(progress, levelTotal), -- 640
			0 -- 640
		)) -- 640
	end -- 622
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 653
		finalePanel = createFinalePanel( -- 656
			uiLayer, -- 656
			viewW, -- 656
			viewH, -- 656
			{onBackToSelect = function() return onBackToSelectTap() end} -- 656
		) -- 656
		resultPanel = createResultPanel( -- 659
			uiLayer, -- 659
			viewW, -- 659
			viewH, -- 659
			{ -- 659
				onRetry = function() return onRetryTap() end, -- 660
				onBackToSelect = function() return onBackToSelectTap() end -- 661
			} -- 661
		) -- 661
		activeResultPanel = resultPanel -- 663
		local created = createLevelSelect( -- 664
			uiLayer, -- 664
			viewW, -- 664
			viewH, -- 664
			{ -- 664
				levels = levelEntries, -- 665
				onPick = function(____, index) -- 666
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 667
					if select ~= nil then -- 667
						select:hide() -- 668
					end -- 668
					enterLevel(index) -- 669
				end, -- 666
				onReplayIntro = function() -- 672
					if select ~= nil then -- 672
						select:hide() -- 673
					end -- 673
					startOpening() -- 674
					print("[escape-velocity] opening replay (user)") -- 675
				end -- 672
			} -- 672
		) -- 672
		select = created -- 678
		return created -- 679
	end -- 653
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 692
		local w = View.size.width -- 693
		local h = View.size.height -- 694
		if w == viewW and h == viewH then -- 694
			return -- 695
		end -- 695
		if opening ~= nil then -- 695
			opening.hide() -- 701
			opening = nil -- 702
		end -- 702
		if select ~= nil then -- 702
			select:hide() -- 704
		end -- 704
		if resultPanel ~= nil then -- 704
			resultPanel:hide() -- 705
		end -- 705
		if finalePanel ~= nil then -- 705
			finalePanel:hide() -- 706
		end -- 706
		do -- 706
			local i = 0 -- 707
			while i < levelTotal do -- 707
				local slot = slots[i + 1] -- 708
				if slot.runtime ~= nil then -- 708
					slot.runtime.world.visible = false -- 710
					slot.runtime.aim:setEnabled(false) -- 711
					slot.runtime.trajectory:clearPrediction() -- 714
					slot.runtime.trajectory:clearTrail() -- 715
					slot.runtime.trajectory:clearGoalRings() -- 717
					slot.runtime.plan:setVisible(false) -- 720
					slot.runtime.plan:clear() -- 721
				end -- 721
				slot.built = false -- 723
				slot.runtime = nil -- 724
				i = i + 1 -- 707
			end -- 707
		end -- 707
		viewW = w -- 728
		viewH = h -- 729
		uiLayer.size = Size(viewW, viewH) -- 730
		openingLayer.size = Size(viewW, viewH) -- 731
		hubLayer.size = Size(viewW, viewH) -- 732
		do -- 732
			local i = 0 -- 733
			while i < levelTotal do -- 733
				levelLayers[i + 1].size = Size(viewW, viewH) -- 733
				i = i + 1 -- 733
			end -- 733
		end -- 733
		if solarHub ~= nil then -- 733
			solarHub.relayout(viewW, viewH) -- 735
		end -- 735
		buildPanels() -- 739
		if activeIndex >= 0 then -- 739
			local keep = activeIndex -- 741
			activeIndex = -1 -- 742
			enterLevel(keep) -- 743
		else -- 743
			local hub = ensureSolarHub() -- 745
			useCamera(hubCamera, -1) -- 746
			hub.show(progress) -- 747
		end -- 747
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 749
	end -- 692
	Director.entry:onAppChange(function(name) -- 753
		if name == "Size" then -- 753
			relayoutForViewport() -- 754
		end -- 754
	end) -- 753
	local introSeen = loadIntroSeen() -- 762
	local forceIntro = false -- 763
	opening = nil -- 764
	startOpening = function() -- 766
		if opening == nil then -- 766
			opening = createOpening({ -- 768
				root = openingRoot, -- 769
				camera = openingCamera, -- 770
				layer = openingLayer, -- 771
				viewW = viewW, -- 772
				viewH = viewH, -- 773
				fovYDeg = View.fieldOfView, -- 774
				aspect = View.aspectRatio, -- 775
				spherePath = "Assets/Model/Sphere.gltf", -- 776
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 777
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 778
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 779
				onFinish = function() -- 780
					introHold = -1 -- 781
					if not introSeen then -- 781
						saveIntroSeen() -- 783
						introSeen = true -- 784
						print("[escape-velocity] intro seen -> saved") -- 785
					end -- 785
					if opening ~= nil then -- 785
						opening.hide() -- 788
					end -- 788
					if select ~= nil then -- 788
						select:hide() -- 789
					end -- 789
					local hub = ensureSolarHub() -- 790
					useCamera(hubCamera, -1) -- 791
					hub.show(progress) -- 792
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 793
						opening.frameIndex(), -- 793
						0 -- 793
					) or "?")) -- 793
				end -- 780
			}) -- 780
		end -- 780
		if opening == nil then -- 780
			return -- 797
		end -- 797
		useCamera(openingCamera, -1) -- 798
		opening.start() -- 799
		print("[escape-velocity] opening start (first launch)") -- 800
	end -- 766
	local startupPanel = buildPanels() -- 803
	local enterReq = Path( -- 815
		Path(".", ".agent", "test-results"), -- 815
		"enter-request.txt" -- 815
	) -- 815
	local autoLaunchAt = -1 -- 816
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 818
	local autoFrame = 0 -- 819
	local autoVX = 0 -- 820
	local autoVY = 0 -- 821
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 829
	local autoBackAt = -1 -- 831
	local autoReenterAt = -1 -- 832
	local autoEntered = false -- 833
	introHold = -1 -- 835
	if Content:exist(enterReq) then -- 835
		local spec = Content:load(enterReq) -- 837
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 838
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 839
		if head == "intro" then -- 839
			forceIntro = true -- 841
			if at >= 0 then -- 841
				local rest = __TS__StringSubstring(spec, at + 1) -- 843
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 844
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 844
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 846
					if v ~= nil and v >= 0 then -- 846
						introHold = v -- 848
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 849
					end -- 849
				end -- 849
			end -- 849
		end -- 849
		local n = tonumber(head) -- 854
		if n ~= nil and n >= 1 and n <= levelTotal then -- 854
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 856
			enterLevel(n - 1) -- 857
			autoEntered = true -- 858
			if at >= 0 then -- 858
				local rest = __TS__StringSubstring(spec, at + 1) -- 860
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 860
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 865
					if f ~= nil and f >= 0 then -- 865
						autoArmAt = f -- 867
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 868
					end -- 868
				else -- 868
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 871
					local c2 = (string.find( -- 872
						rest, -- 872
						":", -- 872
						math.max(c1 + 1 + 1, 1), -- 872
						true -- 872
					) or 0) - 1 -- 872
					if c1 > 0 and c2 > c1 then -- 872
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 874
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 875
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 878
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 879
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 880
						local vy = tonumber(vyText) -- 881
						local ____temp_0 -- 882
						if c3 > 0 then -- 882
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 882
						else -- 882
							____temp_0 = nil -- 882
						end -- 882
						local steps = ____temp_0 -- 882
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 882
							autoLaunchAt = frames -- 884
							autoVX = vx -- 885
							autoVY = vy -- 886
							if steps ~= nil and steps > 0 then -- 886
								autoWarpSteps = math.floor(steps) -- 888
							end -- 888
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 890
						end -- 890
					end -- 890
				end -- 890
			end -- 890
		end -- 890
	end -- 890
	if autoEntered then -- 890
		print("[escape-velocity] opening skipped (auto enter)") -- 903
	elseif forceIntro or not introSeen then -- 903
		startOpening() -- 905
	else -- 905
		local hub = ensureSolarHub() -- 907
		useCamera(hubCamera, -1) -- 908
		hub.show(progress) -- 909
		print("[escape-velocity] entered solarHub (already seen)") -- 910
	end -- 910
	threadLoop(function() -- 915
		advanceUiClock(App.deltaTime) -- 919
		if solarHub ~= nil and solarHub.visible() then -- 919
			solarHub.step(App.deltaTime) -- 923
		end -- 923
		if opening ~= nil and opening.running() then -- 923
			if introHold < 0 or opening.frameIndex() < introHold then -- 923
				opening.step() -- 929
			end -- 929
			if App.deltaTime > 0.05 then -- 929
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 933
					opening.frameIndex(), -- 933
					0 -- 933
				)) -- 933
			end -- 933
		end -- 933
		local runtime = activeRuntime() -- 937
		if runtime ~= nil then -- 937
			runtime.game:update(App.deltaTime) -- 939
			runtime.aim:setBurnInfo( -- 941
				runtime.game:burnNow(), -- 941
				runtime.dvBudget -- 941
			) -- 941
			if runtime.levelHasTimeWindow then -- 941
				runtime.aim:setDate( -- 944
					runtime.game:dateNow(), -- 944
					runtime.dateSpan -- 944
				) -- 944
			end -- 944
			local phaseNow = runtime.game:phase() -- 948
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 949
			runtime.aim:update(App.deltaTime) -- 950
			runtime.aim:setArmed(runtime.game:armed()) -- 952
			local is2D = runtime.game:viewMode() == "2D" -- 954
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 955
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 956
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 957
			runtime.aim:setMissionDrawerVisible(inAim) -- 958
			local curBurn = runtime.game:burnNow() -- 960
			local fuelLimit = runtime.dvBudget * 0.75 -- 961
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 962
			runtime.aim:setTimeControl( -- 965
				runtime.game:speedPow(), -- 966
				runtime.game:speedMaxPow(), -- 967
				runtime.game:isPaused(), -- 968
				runtime.game:missionSeconds() -- 969
			) -- 969
			local brakeActive = phaseNow == "Flying" and runtime.game:isBrakeWindowActive() or debugForceBrakeWindow -- 972
			local isBraked = runtime.game:hasBraked() or debugForceBraked -- 973
			runtime.aim:setLiveBrakeVisible(brakeActive) -- 974
			runtime.aim:setLiveBraked(isBraked) -- 975
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 975
				autoFrame = autoFrame + 1 -- 978
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 978
					autoArmAt = -1 -- 981
					print("[escape-velocity] auto arm (enter-request)") -- 982
					runtime.game:aimReady() -- 983
				end -- 983
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 983
					autoLaunchAt = -1 -- 986
					print("[escape-velocity] auto launch") -- 987
					if autoWarpSteps > 0 then -- 987
						do -- 987
							local s = 0 -- 991
							while s < autoWarpSteps do -- 991
								runtime.game:stepTime(1, runtime.dateSpan) -- 991
								s = s + 1 -- 991
							end -- 991
						end -- 991
						autoWarpSteps = 0 -- 992
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 993
							runtime.game:dateNow(), -- 993
							0 -- 993
						)) .. ")") -- 993
					end -- 993
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 995
					runtime.game:launch({x = autoVX, y = autoVY}) -- 996
					autoBackAt = autoFrame + 320 -- 997
					autoReenterAt = autoFrame + 380 -- 998
				end -- 998
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 998
					autoBackAt = -1 -- 1002
					if runtime.game:backToSelect() then -- 1002
						print("[escape-velocity] auto back to select") -- 1003
					end -- 1003
				end -- 1003
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1003
					autoReenterAt = -1 -- 1006
					print("[escape-velocity] auto re-enter") -- 1007
					enterLevel(0) -- 1008
				end -- 1008
			end -- 1008
		end -- 1008
		return false -- 1013
	end) -- 915
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1017
	debugTriggerResultFn = function(levelIndex, outcome) -- 1019
		if outcome == nil then -- 1019
			outcome = "success" -- 1019
		end -- 1019
		if solarHub ~= nil then -- 1019
			solarHub.hide() -- 1020
		end -- 1020
		if opening ~= nil then -- 1020
			opening.hide() -- 1021
		end -- 1021
		local def = getLevel(levelIndex) -- 1022
		if def == nil or resultPanel == nil then -- 1022
			return -- 1023
		end -- 1023
		local burn = def.dvBudget * 0.65 -- 1024
		local challengesList = {} -- 1025
		if def.mission ~= nil then -- 1025
			do -- 1025
				local k = 0 -- 1027
				while k < #def.mission.challenges do -- 1027
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1028
					k = k + 1 -- 1027
				end -- 1027
			end -- 1027
		end -- 1027
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1031
		resultPanel:show(outcome, titleWithSub, { -- 1035
			result = outcome, -- 1036
			levelName = titleWithSub, -- 1037
			levelIndex = levelIndex, -- 1038
			rocketsGot = outcome == "success" and 3 or 0, -- 1039
			challenges = challengesList, -- 1040
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1041
			burnDv = burn, -- 1042
			dvBudget = def.dvBudget, -- 1043
			flightTime = 12.8, -- 1044
			totalRockets = outcome == "success" and 16 or 13, -- 1045
			totalPossibleRockets = 18 -- 1046
		}) -- 1046
	end -- 1019
	debugTriggerBrakeWindowFn = function(levelIndex) -- 1050
		if solarHub ~= nil then -- 1050
			solarHub.hide() -- 1051
		end -- 1051
		if opening ~= nil then -- 1051
			opening.hide() -- 1052
		end -- 1052
		enterLevel(levelIndex) -- 1053
		local rt = activeRuntime() -- 1054
		if rt ~= nil then -- 1054
			rt.game:launch({x = 2, y = -20}) -- 1056
			debugForceBrakeWindow = true -- 1057
			debugForceBraked = false -- 1058
			rt.aim:setLiveBrakeVisible(true) -- 1059
			rt.aim:setLiveBraked(false) -- 1060
			if rt.game:viewMode() ~= "3D" then -- 1060
				rt.game:toggleViewMode() -- 1061
			end -- 1061
		end -- 1061
	end -- 1050
	debugTriggerBrakePressFn = function() -- 1065
		debugForceBrakeWindow = true -- 1066
		debugForceBraked = true -- 1067
		local rt = activeRuntime() -- 1068
		if rt ~= nil then -- 1068
			rt.aim:setLiveBrakeVisible(true) -- 1070
			rt.aim:setLiveBraked(true) -- 1071
		end -- 1071
	end -- 1065
	debugTriggerEnterLevelFn = function(levelIndex) -- 1075
		if solarHub ~= nil then -- 1075
			solarHub.hide() -- 1076
		end -- 1076
		if opening ~= nil then -- 1076
			opening.hide() -- 1077
		end -- 1077
		enterLevel(levelIndex) -- 1078
	end -- 1075
	debugTriggerZoomInFn = function() -- 1081
		local rt = activeRuntime() -- 1082
		if rt ~= nil then -- 1082
			rt.plan:zoomIn() -- 1084
		end -- 1084
	end -- 1081
	debugTriggerResetViewFn = function() -- 1088
		local rt = activeRuntime() -- 1089
		if rt ~= nil then -- 1089
			rt.plan:resetView() -- 1091
		end -- 1091
	end -- 1088
end -- 1088
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1097
	return activeResultPanel -- 1098
end -- 1097
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1102
	if outcome == nil then -- 1102
		outcome = "success" -- 1102
	end -- 1102
	if debugTriggerResultFn ~= nil then -- 1102
		debugTriggerResultFn(levelIndex, outcome) -- 1104
	end -- 1104
end -- 1102
--- 触发进入制动窗口演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakeWindow(levelIndex) -- 1109
	if levelIndex == nil then -- 1109
		levelIndex = 3 -- 1109
	end -- 1109
	if debugTriggerBrakeWindowFn ~= nil then -- 1109
		debugTriggerBrakeWindowFn(levelIndex) -- 1111
	end -- 1111
end -- 1109
--- 触发按下逆喷制动按钮演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakePress() -- 1116
	if debugTriggerBrakePressFn ~= nil then -- 1116
		debugTriggerBrakePressFn() -- 1118
	end -- 1118
end -- 1116
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1123
	if debugTriggerEnterLevelFn ~= nil then -- 1123
		debugTriggerEnterLevelFn(levelIndex) -- 1125
	end -- 1125
end -- 1123
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1130
	if debugTriggerZoomInFn ~= nil then -- 1130
		debugTriggerZoomInFn() -- 1132
	end -- 1132
end -- 1130
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1137
	if debugTriggerResetViewFn ~= nil then -- 1137
		debugTriggerResetViewFn() -- 1139
	end -- 1139
end -- 1137
return ____exports -- 1137
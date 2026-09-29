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
local debugGameStateFn = nil -- 117
local debugForceBrakeWindow = false -- 118
local debugForceBraked = false -- 119
local activeResultPanel = nil -- 120
local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 128
local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 129
local function decodeLevelJson(text) -- 130
	local decoded = {json.decode(text)} -- 131
	local err = decoded[2] -- 132
	if err ~= nil then -- 132
		return nil -- 133
	end -- 133
	return decoded[1] -- 134
end -- 130
if not installArcadeLevels(levelsText, bodiesText, decodeLevelJson) then -- 130
	print("[escape-velocity] FATAL: levels.json 没有装上") -- 137
end -- 137
local levelTotal = levelCount() -- 139
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
						goto __continue27 -- 245
					end -- 245
					local active = i == index -- 246
					slot.runtime.world.visible = active -- 247
					slot.runtime.aim:setEnabled(active) -- 248
					if active then -- 248
						slot.runtime.aim:setBrake(slot.runtime.game:brakeMode()) -- 250
					end -- 250
				end -- 250
				::__continue27:: -- 250
				i = i + 1 -- 240
			end -- 240
		end -- 240
	end -- 239
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 259
		local game -- 259
		local slot = slots[index + 1] -- 260
		if slot.built and slot.runtime ~= nil then -- 260
			return slot.runtime -- 261
		end -- 261
		local def = getLevel(index) -- 263
		if def == nil then -- 263
			return nil -- 264
		end -- 264
		local bodies = scaledPlanets(def) -- 266
		local level = { -- 267
			transfer = def.transfer, -- 268
			bodies = bodies, -- 269
			probeStart = def.probeStart, -- 270
			probeVel0 = def.probeVel0, -- 272
			goal = def.goal, -- 273
			escapeRadius = def.escapeRadius, -- 274
			physicsStep = levelRuntime(index).physicsStep, -- 275
			speedUnit = 1, -- 277
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 278
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 279
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 280
			aimFraming = levelRuntime(index).aimFraming, -- 281
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 282
			aimMin = levelRuntime(index).aimMin, -- 283
			maxSteps = def.maxSteps, -- 284
			predictSteps = levelRuntime(index).predictSteps, -- 285
			mission = def.mission, -- 286
			stars = def.stars, -- 287
			starOrbits = starOrbits(index) -- 288
		} -- 288
		local world = Node3D() -- 291
		Director.entry:addChild(world) -- 292
		world.visible = false -- 293
		local rtg = def.probeVariant == "rtg" -- 295
		local scene = buildScene({ -- 296
			root = world, -- 297
			backdropRadius = def.transfer ~= nil and (def.transfer.orbital ~= nil and 6000 or 3000) or nil, -- 298
			bodies = bodies, -- 299
			visuals = def.visuals, -- 300
			probeStart = level.probeStart, -- 301
			stars = def.stars, -- 302
			probeScale = levelRuntime(index).probeVisualRadius, -- 308
			spherePath = "Assets/Model/Sphere.gltf", -- 309
			ringPath = "Assets/Model/Ring.gltf", -- 310
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 311
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 318
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 319
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 320
			probeBodyRadius = rtg and 0.871 or 1.084, -- 321
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 323
			orbitFlowDots = levelRuntime(index).orbitFlowDots, -- 324
			orbitRings = levelRuntime(index).orbitRings -- 327
		}) -- 327
		if scene == nil then -- 327
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 330
			return nil -- 331
		end -- 331
		local rt = levelRuntime(index) -- 334
		local camera = Camera3D() -- 335
		local rigOptions = defaultRigOptions( -- 339
			View.fieldOfView, -- 339
			View.aspectRatio, -- 339
			rt.cameraMin, -- 339
			rt.cameraMax, -- 339
			rt.tiltDeg -- 339
		) -- 339
		if def.transfer ~= nil then -- 339
			rigOptions.margin = 0.16 -- 341
			rigOptions.screenMinY = 2 * math.min(350, viewH * 0.38) / viewH - 1 -- 342
			rigOptions.screenMaxY = 1 - 2 * math.min(205, viewH * 0.23) / viewH -- 343
			rigOptions.screenBiasY = 0.14 -- 344
		end -- 344
		local rig = createCameraRig(rigOptions) -- 346
		local trailOptions = trajectoryOptions() -- 347
		if def.transfer ~= nil then -- 347
			trailOptions.tailPoints = 120 -- 350
			trailOptions.burnLength = 12 -- 351
			trailOptions.trailHeadRadius = 1.2 -- 352
			trailOptions.trailHeadAlpha = 0.45 -- 353
			trailOptions.trailR = 100 -- 354
			trailOptions.trailG = 180 -- 354
			trailOptions.trailB = 230 -- 354
		end -- 354
		local trajectory = createTrajectoryView(levelLayers[index + 1], trailOptions) -- 356
		local planOpts = defaultPlanOptions() -- 360
		planOpts.transferTutorial = def.transfer ~= nil -- 361
		if levelRuntime(index).orbitFlowDots == false then -- 361
			planOpts.flowDotRadius = 0 -- 362
		end -- 362
		planOpts.probeVisualRadius = levelRuntime(index).probeVisualRadius -- 365
		if def.transfer ~= nil then -- 365
			planOpts.trailHex = 6599910 -- 366
			planOpts.trailWidth = 1.5 -- 366
		end -- 366
		local plan = createPlanView( -- 367
			levelLayers[index + 1], -- 367
			viewW, -- 367
			viewH, -- 367
			planOpts, -- 367
			def.planCenter -- 367
		) -- 367
		local offset = def.goal.offset -- 368
		local planTolerance = arrivalRingRadius(def.goal) + (offset ~= nil and math.sqrt(offset.x * offset.x + offset.y * offset.y) or 0) -- 369
		plan:fitTo(math.max( -- 370
			planFitRadius( -- 370
				bodies, -- 370
				level.probeStart, -- 370
				def.goal.planetIndex, -- 370
				planTolerance, -- 370
				def.planCenter, -- 370
				starOrbits(index) -- 370
			), -- 370
			def.transfer ~= nil and def.transfer.orbital ~= nil and def.transfer.orbital.region.maxRadius + 20 or 0 -- 370
		)) -- 370
		local aim = createAimInput( -- 372
			levelLayers[index + 1], -- 372
			viewW, -- 372
			viewH, -- 372
			def.dvBudget, -- 372
			rt.aimMin, -- 372
			rt.playbackSpeeds, -- 372
			def.transfer ~= nil, -- 372
			def.transfer ~= nil and def.transfer.orbital ~= nil and (def.transfer.mode == "lowerPeriapsis" and "inward" or "outward") or "lunar" -- 372
		) -- 372
		aim:setBurnInfo(0, def.dvBudget) -- 374
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 376
		aim:setDate(0, dateSpan) -- 377
		aim:onWarp(function(dir) -- 378
			game:stepTime(dir, dateSpan) -- 379
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 380
		end) -- 378
		aim:onZoomIn(function() -- 384
			plan:zoomIn() -- 385
		end) -- 384
		aim:onZoomOut(function() -- 387
			plan:zoomOut() -- 388
		end) -- 387
		aim:onFitView(function() -- 390
			plan:resetView() -- 391
		end) -- 390
		local challengesList = {} -- 395
		if def.mission ~= nil then -- 395
			do -- 395
				local k = 0 -- 397
				while k < #def.mission.challenges do -- 397
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 398
					k = k + 1 -- 397
				end -- 397
			end -- 397
		end -- 397
		local initialRockets = getMissionRockets(progress, index) -- 401
		local drawerTitle = def.transfer ~= nil and (("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. (index == 0 and "奔向月球" or (index == 1 and "金星逆向" or "双星甩尾")) or (def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1]) -- 402
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 403
		game = createGame( -- 405
			level, -- 405
			{ -- 405
				scene = scene, -- 406
				camera = camera, -- 407
				rig = rig, -- 408
				trajectory = trajectory, -- 409
				plan = plan, -- 410
				visuals = def.visuals, -- 412
				setWorldVisible = function(____, on) -- 414
					world.visible = on -- 415
				end, -- 414
				aim = aim, -- 417
				viewW = viewW, -- 418
				viewH = viewH, -- 419
				fovYDeg = View.fieldOfView, -- 420
				aspect = View.aspectRatio, -- 421
				onPhase = function(____, p) -- 422
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 423
					if index == activeIndex then -- 423
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 430
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 431
						aim:setMissionDrawerVisible(inAim) -- 432
						if p == "Finale" then -- 432
							if resultPanel ~= nil then -- 432
								resultPanel:hide() -- 434
							end -- 434
							if finalePanel ~= nil then -- 434
								finalePanel:show(finaleText.main, finaleText.sub) -- 435
							end -- 435
						else -- 435
							if p ~= "Result" and resultPanel ~= nil then -- 435
								resultPanel:hide() -- 437
							end -- 437
							if finalePanel ~= nil then -- 437
								finalePanel:hide() -- 438
							end -- 438
						end -- 438
					end -- 438
				end, -- 422
				onMissionCompleted = function() -- 442
					progress = recordMissionResult(progress, index, 1, levelTotal) -- 443
					saveProgress(progress) -- 444
					print("[escape-velocity] flyby completion saved L" .. __TS__NumberToFixed(index + 1, 0)) -- 445
				end, -- 442
				onResult = function(____, r, telemetry) -- 447
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 448
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity, starsCollected = telem.starsCollected ~= nil and telem.starsCollected or 0}) -- 454
					if not game:missionCompleted() then -- 454
						progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 463
						saveProgress(progress) -- 464
					end -- 464
					local currentTotal = getTotalRockets(progress, levelTotal) -- 466
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 468
					resultIndex = index -- 472
					local challengesList = {} -- 474
					if def.mission ~= nil then -- 474
						do -- 474
							local k = 0 -- 476
							while k < #def.mission.challenges do -- 476
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 477
								k = k + 1 -- 476
							end -- 476
						end -- 476
					end -- 476
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 481
					local detailParams = { -- 485
						result = r, -- 486
						levelName = titleWithSub, -- 487
						levelIndex = index, -- 488
						rocketsGot = evalInfo.rockets, -- 489
						challenges = challengesList, -- 490
						completionOnly = def.transfer ~= nil, -- 491
						achieved = evalInfo.achieved, -- 492
						burnDv = telem.burnDv, -- 493
						dvBudget = def.dvBudget, -- 494
						flightTime = telem.flightTime, -- 495
						totalRockets = currentTotal, -- 496
						totalPossibleRockets = levelTotal * 3 -- 497
					} -- 497
					if resultPanel ~= nil then -- 497
						resultPanel:show(r, titleWithSub, detailParams) -- 501
					end -- 501
				end, -- 447
				onFinale = function(____, info) -- 505
					finaleText = { -- 506
						main = FinaleMainText, -- 506
						sub = finaleSubtitle(info.distance, info.time) -- 506
					} -- 506
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 507
				end, -- 505
				finale = index == levelTotal - 1 and def.transfer == nil -- 512
			} -- 512
		) -- 512
		aim:onQuickRetry(function() -- 515
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 516
			game:retry() -- 517
		end) -- 515
		aim:onDrag(function(a) -- 523
			game:onAimDrag(a) -- 524
			aim:setBurnInfo( -- 526
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 526
				def.dvBudget -- 526
			) -- 526
		end) -- 523
		aim:onAimReady(function(a) -- 529
			game:onAimDrag(a) -- 530
			game:aimReady() -- 531
			print("[escape-velocity] aim ready -> Armed") -- 532
		end) -- 529
		aim:onLaunch(function() -- 534
			print("[escape-velocity] launch button tap") -- 535
			game:launchArmed() -- 536
		end) -- 534
		aim:onCancelAim(function() -- 538
			print("[escape-velocity] cancel aim tap") -- 539
			game:cancelAim() -- 540
		end) -- 538
		aim:onObserve(function(dx, dy) -- 543
			game:observeDrag(dx, dy) -- 544
		end) -- 543
		aim:onZoom(function(deltaDist) -- 546
			game:observeZoom(deltaDist) -- 547
		end) -- 546
		aim:onSkipTour(function() -- 549
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 550
			game:skipIntroTour() -- 551
		end) -- 549
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 553
		aim:onViewToggle(function() -- 555
			game:toggleViewMode() -- 556
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 557
		end) -- 555
		if aim.onCameraFocus ~= nil then -- 555
			aim:onCameraFocus(function() -- 559
				game:cycleCameraFocus() -- 559
			end) -- 559
		end -- 559
		if aim.onEndViewing ~= nil then -- 559
			aim:onEndViewing(function() -- 560
				game:endViewing() -- 560
			end) -- 560
		end -- 560
		aim:onBrake(function(on) -- 562
			game:setBrakeMode(on) -- 563
			print(((("[escape-velocity] brake mode = " .. (on and "on" or "off")) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 564
		end) -- 562
		aim:setBrake(game:brakeMode()) -- 566
		aim:onSpeedUp(function() -- 570
			game:speedUp() -- 571
		end) -- 570
		aim:onSpeedDown(function() -- 573
			game:speedDown() -- 574
		end) -- 573
		aim:onTogglePause(function() -- 576
			game:togglePause() -- 577
		end) -- 576
		aim:onPlayback(function(speed) -- 579
			game:setPlaybackSpeed(speed) -- 580
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 581
		end) -- 579
		aim:setPlayback(game:playbackSpeed()) -- 583
		aim:onLiveBrake(function() -- 585
			print(("[escape-velocity] tap: live brake (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 586
			game:applyInFlightBrake() -- 587
		end) -- 585
		local runtime = { -- 590
			index = index, -- 591
			name = levelNames[index + 1], -- 592
			world = world, -- 593
			camera = camera, -- 594
			game = game, -- 595
			aim = aim, -- 596
			trajectory = trajectory, -- 597
			plan = plan, -- 598
			levelHasTimeWindow = def.timeWindow ~= nil, -- 599
			dvBudget = def.dvBudget, -- 600
			dateSpan = dateSpan -- 601
		} -- 601
		slot.built = true -- 603
		slot.runtime = runtime -- 604
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 605
		return runtime -- 606
	end -- 259
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 610
		local runtime = ensureLevel(index) -- 611
		if runtime == nil then -- 611
			return -- 612
		end -- 612
		local wasActive = activeIndex == index -- 615
		if opening ~= nil then -- 615
			opening.hide() -- 617
		end -- 617
		if select ~= nil then -- 617
			select:hide() -- 618
		end -- 618
		if solarHub ~= nil then -- 618
			solarHub.hide() -- 619
		end -- 619
		activeIndex = index -- 620
		showOnlyLevel(index) -- 621
		applyClipPlanes(index) -- 623
		if not wasActive then -- 623
			Director:pushCamera(runtime.camera) -- 624
		end -- 624
		runtime.game:startLevel() -- 625
		print("[escape-velocity] enter " .. runtime.name) -- 626
	end -- 610
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 630
		if resultIndex >= 0 and resultIndex < levelTotal then -- 630
			local rt = slots[resultIndex + 1].runtime -- 632
			if rt ~= nil then -- 632
				return rt -- 633
			end -- 633
		end -- 633
		return activeRuntime() -- 635
	end -- 630
	local function onRetryTap() -- 638
		local rt = resultRuntime() -- 640
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 641
		if resultPanel ~= nil then -- 641
			resultPanel:hide() -- 642
		end -- 642
		if rt ~= nil then -- 642
			rt.game:retry() -- 643
		end -- 643
	end -- 638
	local function ensureSolarHub() -- 646
		if solarHub ~= nil then -- 646
			return solarHub -- 647
		end -- 647
		solarHub = createSolarHub({ -- 648
			root = hubRoot, -- 649
			camera = hubCamera, -- 650
			layer = hubLayer, -- 651
			viewW = viewW, -- 652
			viewH = viewH, -- 653
			fovYDeg = View.fieldOfView, -- 654
			aspect = View.aspectRatio, -- 655
			spherePath = "Assets/Model/Sphere.gltf", -- 656
			onLaunch = function(____, levelIndex) -- 657
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 658
				if solarHub ~= nil then -- 658
					solarHub.hide() -- 659
				end -- 659
				enterLevel(levelIndex) -- 660
			end, -- 657
			onReplayIntro = function() -- 662
				if solarHub ~= nil then -- 662
					solarHub.hide() -- 663
				end -- 663
				startOpening() -- 664
				print("[escape-velocity] opening replay from solarHub") -- 665
			end -- 662
		}) -- 662
		return solarHub -- 668
	end -- 646
	local function onBackToSelectTap() -- 671
		local rt = resultRuntime() -- 672
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 673
		if rt == nil then -- 673
			return -- 674
		end -- 674
		local runtime = rt -- 675
		if not runtime.game:backToSelect() then -- 675
			return -- 677
		end -- 677
		runtime.world.visible = false -- 678
		runtime.aim:setEnabled(false) -- 679
		if resultPanel ~= nil then -- 679
			resultPanel:hide() -- 680
		end -- 680
		if finalePanel ~= nil then -- 680
			finalePanel:hide() -- 682
		end -- 682
		if select ~= nil then -- 682
			select:hide() -- 683
		end -- 683
		progress = loadProgress(levelTotal) -- 685
		local hub = ensureSolarHub() -- 686
		useCamera(hubCamera, -1) -- 687
		hub.show(progress) -- 688
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 689
			getTotalRockets(progress, levelTotal), -- 689
			0 -- 689
		)) -- 689
	end -- 671
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 702
		finalePanel = createFinalePanel( -- 705
			uiLayer, -- 705
			viewW, -- 705
			viewH, -- 705
			{onBackToSelect = function() return onBackToSelectTap() end} -- 705
		) -- 705
		resultPanel = createResultPanel( -- 708
			uiLayer, -- 708
			viewW, -- 708
			viewH, -- 708
			{ -- 708
				onRetry = function() return onRetryTap() end, -- 709
				onBackToSelect = function() return onBackToSelectTap() end -- 710
			} -- 710
		) -- 710
		activeResultPanel = resultPanel -- 712
		local created = createLevelSelect( -- 713
			uiLayer, -- 713
			viewW, -- 713
			viewH, -- 713
			{ -- 713
				levels = levelEntries, -- 714
				onPick = function(____, index) -- 715
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 716
					if select ~= nil then -- 716
						select:hide() -- 717
					end -- 717
					enterLevel(index) -- 718
				end, -- 715
				onReplayIntro = function() -- 721
					if select ~= nil then -- 721
						select:hide() -- 722
					end -- 722
					startOpening() -- 723
					print("[escape-velocity] opening replay (user)") -- 724
				end -- 721
			} -- 721
		) -- 721
		select = created -- 727
		return created -- 728
	end -- 702
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 741
		local w = View.size.width -- 742
		local h = View.size.height -- 743
		if w == viewW and h == viewH then -- 743
			return -- 744
		end -- 744
		if opening ~= nil then -- 744
			opening.hide() -- 750
			opening = nil -- 751
		end -- 751
		if select ~= nil then -- 751
			select:hide() -- 753
		end -- 753
		if resultPanel ~= nil then -- 753
			resultPanel:hide() -- 754
		end -- 754
		if finalePanel ~= nil then -- 754
			finalePanel:hide() -- 755
		end -- 755
		do -- 755
			local i = 0 -- 756
			while i < levelTotal do -- 756
				local slot = slots[i + 1] -- 757
				if slot.runtime ~= nil then -- 757
					slot.runtime.world.visible = false -- 759
					slot.runtime.aim:setEnabled(false) -- 760
					slot.runtime.trajectory:clearPrediction() -- 763
					slot.runtime.trajectory:clearTrail() -- 764
					slot.runtime.trajectory:clearGoalRings() -- 766
					slot.runtime.plan:setVisible(false) -- 769
					slot.runtime.plan:clear() -- 770
				end -- 770
				slot.built = false -- 772
				slot.runtime = nil -- 773
				i = i + 1 -- 756
			end -- 756
		end -- 756
		viewW = w -- 777
		viewH = h -- 778
		uiLayer.size = Size(viewW, viewH) -- 779
		openingLayer.size = Size(viewW, viewH) -- 780
		hubLayer.size = Size(viewW, viewH) -- 781
		do -- 781
			local i = 0 -- 782
			while i < levelTotal do -- 782
				levelLayers[i + 1].size = Size(viewW, viewH) -- 782
				i = i + 1 -- 782
			end -- 782
		end -- 782
		if solarHub ~= nil then -- 782
			solarHub.relayout(viewW, viewH) -- 784
		end -- 784
		buildPanels() -- 788
		if activeIndex >= 0 then -- 788
			local keep = activeIndex -- 790
			activeIndex = -1 -- 791
			enterLevel(keep) -- 792
		else -- 792
			local hub = ensureSolarHub() -- 794
			useCamera(hubCamera, -1) -- 795
			hub.show(progress) -- 796
		end -- 796
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 798
	end -- 741
	Director.entry:onAppChange(function(name) -- 802
		if name == "Size" then -- 802
			relayoutForViewport() -- 803
		end -- 803
	end) -- 802
	local introSeen = loadIntroSeen() -- 811
	local forceIntro = false -- 812
	opening = nil -- 813
	startOpening = function() -- 815
		if opening == nil then -- 815
			opening = createOpening({ -- 817
				root = openingRoot, -- 818
				camera = openingCamera, -- 819
				layer = openingLayer, -- 820
				viewW = viewW, -- 821
				viewH = viewH, -- 822
				fovYDeg = View.fieldOfView, -- 823
				aspect = View.aspectRatio, -- 824
				spherePath = "Assets/Model/Sphere.gltf", -- 825
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 826
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 827
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 828
				onFinish = function() -- 829
					introHold = -1 -- 830
					if not introSeen then -- 830
						saveIntroSeen() -- 832
						introSeen = true -- 833
						print("[escape-velocity] intro seen -> saved") -- 834
					end -- 834
					if opening ~= nil then -- 834
						opening.hide() -- 837
					end -- 837
					if select ~= nil then -- 837
						select:hide() -- 838
					end -- 838
					local hub = ensureSolarHub() -- 839
					useCamera(hubCamera, -1) -- 840
					hub.show(progress) -- 841
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 842
						opening.frameIndex(), -- 842
						0 -- 842
					) or "?")) -- 842
				end -- 829
			}) -- 829
		end -- 829
		if opening == nil then -- 829
			return -- 846
		end -- 846
		useCamera(openingCamera, -1) -- 847
		opening.start() -- 848
		print("[escape-velocity] opening start (first launch)") -- 849
	end -- 815
	local startupPanel = buildPanels() -- 852
	local enterReq = Path( -- 864
		Path(".", ".agent", "test-results"), -- 864
		"enter-request.txt" -- 864
	) -- 864
	local autoLaunchAt = -1 -- 865
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 867
	local autoFrame = 0 -- 868
	local autoVX = 0 -- 869
	local autoVY = 0 -- 870
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 878
	local autoBackAt = -1 -- 880
	local autoReenterAt = -1 -- 881
	local autoEntered = false -- 882
	introHold = -1 -- 884
	if Content:exist(enterReq) then -- 884
		local spec = Content:load(enterReq) -- 886
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 887
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 888
		if head == "intro" then -- 888
			forceIntro = true -- 890
			if at >= 0 then -- 890
				local rest = __TS__StringSubstring(spec, at + 1) -- 892
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 893
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 893
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 895
					if v ~= nil and v >= 0 then -- 895
						introHold = v -- 897
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 898
					end -- 898
				end -- 898
			end -- 898
		end -- 898
		local n = tonumber(head) -- 903
		if n ~= nil and n >= 1 and n <= levelTotal then -- 903
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 905
			enterLevel(n - 1) -- 906
			autoEntered = true -- 907
			if at >= 0 then -- 907
				local rest = __TS__StringSubstring(spec, at + 1) -- 909
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 909
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 914
					if f ~= nil and f >= 0 then -- 914
						autoArmAt = f -- 916
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 917
					end -- 917
				else -- 917
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 920
					local c2 = (string.find( -- 921
						rest, -- 921
						":", -- 921
						math.max(c1 + 1 + 1, 1), -- 921
						true -- 921
					) or 0) - 1 -- 921
					if c1 > 0 and c2 > c1 then -- 921
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 923
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 924
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 927
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 928
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 929
						local vy = tonumber(vyText) -- 930
						local ____temp_0 -- 931
						if c3 > 0 then -- 931
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 931
						else -- 931
							____temp_0 = nil -- 931
						end -- 931
						local steps = ____temp_0 -- 931
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 931
							autoLaunchAt = frames -- 933
							autoVX = vx -- 934
							autoVY = vy -- 935
							if steps ~= nil and steps > 0 then -- 935
								autoWarpSteps = math.floor(steps) -- 937
							end -- 937
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 939
						end -- 939
					end -- 939
				end -- 939
			end -- 939
		end -- 939
	end -- 939
	if autoEntered then -- 939
		print("[escape-velocity] opening skipped (auto enter)") -- 952
	elseif forceIntro or not introSeen then -- 952
		startOpening() -- 954
	else -- 954
		local hub = ensureSolarHub() -- 956
		useCamera(hubCamera, -1) -- 957
		hub.show(progress) -- 958
		print("[escape-velocity] entered solarHub (already seen)") -- 959
	end -- 959
	threadLoop(function() -- 964
		advanceUiClock(App.deltaTime) -- 968
		if solarHub ~= nil and solarHub.visible() then -- 968
			solarHub.step(App.deltaTime) -- 972
		end -- 972
		if opening ~= nil and opening.running() then -- 972
			if introHold < 0 or opening.frameIndex() < introHold then -- 972
				opening.step() -- 978
			end -- 978
			if App.deltaTime > 0.05 then -- 978
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 982
					opening.frameIndex(), -- 982
					0 -- 982
				)) -- 982
			end -- 982
		end -- 982
		local runtime = activeRuntime() -- 986
		if runtime ~= nil then -- 986
			runtime.game:update(App.deltaTime) -- 988
			runtime.aim:setBurnInfo( -- 990
				runtime.game:burnNow(), -- 990
				runtime.dvBudget -- 990
			) -- 990
			if runtime.levelHasTimeWindow then -- 990
				runtime.aim:setDate( -- 993
					runtime.game:dateNow(), -- 993
					runtime.dateSpan -- 993
				) -- 993
			end -- 993
			local phaseNow = runtime.game:phase() -- 997
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 998
			runtime.aim:update(App.deltaTime) -- 999
			runtime.aim:setArmed(runtime.game:armed()) -- 1001
			runtime.aim:setStarsStatus(runtime.game:starsNow()) -- 1002
			local is2D = runtime.game:viewMode() == "2D" -- 1004
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 1005
			if runtime.aim.setFlightViewing ~= nil then -- 1005
				runtime.aim:setFlightViewing( -- 1006
					phaseNow == "Flying", -- 1006
					runtime.game:missionCompleted(), -- 1006
					runtime.game:cameraFocus(), -- 1006
					not is2D, -- 1006
					runtime.game:flightStage() -- 1006
				) -- 1006
			end -- 1006
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 1007
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 1008
			runtime.aim:setMissionDrawerVisible(inAim) -- 1009
			local curBurn = runtime.game:burnNow() -- 1011
			local fuelLimit = runtime.dvBudget * 0.75 -- 1012
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 1013
			runtime.aim:setTimeControl( -- 1016
				runtime.game:speedPow(), -- 1017
				runtime.game:speedMaxPow(), -- 1018
				runtime.game:isPaused(), -- 1019
				runtime.game:missionSeconds(), -- 1020
				runtime.game:speedRate() -- 1021
			) -- 1021
			local brakeActive = phaseNow == "Flying" and runtime.game:isBrakeWindowActive() or debugForceBrakeWindow -- 1024
			local isBraked = runtime.game:hasBraked() or debugForceBraked -- 1025
			runtime.aim:setLiveBrakeVisible(brakeActive) -- 1026
			runtime.aim:setLiveBraked(isBraked) -- 1027
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 1027
				autoFrame = autoFrame + 1 -- 1030
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 1030
					autoArmAt = -1 -- 1033
					print("[escape-velocity] auto arm (enter-request)") -- 1034
					runtime.game:aimReady() -- 1035
				end -- 1035
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 1035
					autoLaunchAt = -1 -- 1038
					print("[escape-velocity] auto launch") -- 1039
					if autoWarpSteps > 0 then -- 1039
						do -- 1039
							local s = 0 -- 1043
							while s < autoWarpSteps do -- 1043
								runtime.game:stepTime(1, runtime.dateSpan) -- 1043
								s = s + 1 -- 1043
							end -- 1043
						end -- 1043
						autoWarpSteps = 0 -- 1044
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 1045
							runtime.game:dateNow(), -- 1045
							0 -- 1045
						)) .. ")") -- 1045
					end -- 1045
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 1047
					runtime.game:launch({x = autoVX, y = autoVY}) -- 1048
					autoBackAt = autoFrame + 320 -- 1049
					autoReenterAt = autoFrame + 380 -- 1050
				end -- 1050
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 1050
					autoBackAt = -1 -- 1054
					if runtime.game:backToSelect() then -- 1054
						print("[escape-velocity] auto back to select") -- 1055
					end -- 1055
				end -- 1055
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1055
					autoReenterAt = -1 -- 1058
					print("[escape-velocity] auto re-enter") -- 1059
					enterLevel(0) -- 1060
				end -- 1060
			end -- 1060
		end -- 1060
		return false -- 1065
	end) -- 964
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1069
	debugTriggerResultFn = function(levelIndex, outcome) -- 1071
		if outcome == nil then -- 1071
			outcome = "success" -- 1071
		end -- 1071
		if solarHub ~= nil then -- 1071
			solarHub.hide() -- 1072
		end -- 1072
		if opening ~= nil then -- 1072
			opening.hide() -- 1073
		end -- 1073
		local def = getLevel(levelIndex) -- 1074
		if def == nil or resultPanel == nil then -- 1074
			return -- 1075
		end -- 1075
		local burn = def.dvBudget * 0.65 -- 1076
		local challengesList = {} -- 1077
		if def.mission ~= nil then -- 1077
			do -- 1077
				local k = 0 -- 1079
				while k < #def.mission.challenges do -- 1079
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1080
					k = k + 1 -- 1079
				end -- 1079
			end -- 1079
		end -- 1079
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1083
		resultPanel:show(outcome, titleWithSub, { -- 1087
			result = outcome, -- 1088
			levelName = titleWithSub, -- 1089
			levelIndex = levelIndex, -- 1090
			rocketsGot = outcome == "success" and 3 or 0, -- 1091
			challenges = challengesList, -- 1092
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1093
			burnDv = burn, -- 1094
			dvBudget = def.dvBudget, -- 1095
			flightTime = 12.8, -- 1096
			totalRockets = outcome == "success" and 16 or 13, -- 1097
			totalPossibleRockets = 18 -- 1098
		}) -- 1098
	end -- 1071
	debugTriggerBrakeWindowFn = function(levelIndex) -- 1102
		if solarHub ~= nil then -- 1102
			solarHub.hide() -- 1103
		end -- 1103
		if opening ~= nil then -- 1103
			opening.hide() -- 1104
		end -- 1104
		enterLevel(levelIndex) -- 1105
		local rt = activeRuntime() -- 1106
		if rt ~= nil then -- 1106
			rt.game:launch({x = 2, y = -20}) -- 1108
			debugForceBrakeWindow = true -- 1109
			debugForceBraked = false -- 1110
			rt.aim:setLiveBrakeVisible(true) -- 1111
			rt.aim:setLiveBraked(false) -- 1112
			if rt.game:viewMode() ~= "3D" then -- 1112
				rt.game:toggleViewMode() -- 1113
			end -- 1113
		end -- 1113
	end -- 1102
	debugTriggerBrakePressFn = function() -- 1117
		debugForceBrakeWindow = true -- 1118
		debugForceBraked = true -- 1119
		local rt = activeRuntime() -- 1120
		if rt ~= nil then -- 1120
			rt.aim:setLiveBrakeVisible(true) -- 1122
			rt.aim:setLiveBraked(true) -- 1123
		end -- 1123
	end -- 1117
	debugTriggerEnterLevelFn = function(levelIndex) -- 1127
		if solarHub ~= nil then -- 1127
			solarHub.hide() -- 1128
		end -- 1128
		if opening ~= nil then -- 1128
			opening.hide() -- 1129
		end -- 1129
		enterLevel(levelIndex) -- 1130
	end -- 1127
	debugGameStateFn = function() -- 1132
		local rt = activeRuntime() -- 1133
		if rt == nil then -- 1133
			return "phase=LevelSelect" -- 1134
		end -- 1134
		local g = rt.game -- 1135
		return (((((((((((((("phase=" .. g:phase()) .. "\ndate=") .. __TS__NumberToFixed( -- 1136
			g:dateNow(), -- 1136
			6 -- 1136
		)) .. "\nworld=") .. __TS__NumberToFixed( -- 1136
			g:missionSeconds(), -- 1136
			6 -- 1136
		)) .. "\nrate=") .. __TS__NumberToFixed( -- 1136
			g:speedRate(), -- 1137
			6 -- 1137
		)) .. "\npaused=") .. (g:isPaused() and "1" or "0")) .. "\nfocus=") .. g:cameraFocus()) .. "\ncompleted=") .. (g:missionCompleted() and "1" or "0")) .. "\nview=") .. g:viewMode() -- 1137
	end -- 1132
	debugTriggerZoomInFn = function() -- 1141
		local rt = activeRuntime() -- 1142
		if rt ~= nil then -- 1142
			rt.plan:zoomIn() -- 1144
		end -- 1144
	end -- 1141
	debugTriggerResetViewFn = function() -- 1148
		local rt = activeRuntime() -- 1149
		if rt ~= nil then -- 1149
			rt.plan:resetView() -- 1151
		end -- 1151
	end -- 1148
end -- 1148
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1157
	return activeResultPanel -- 1158
end -- 1157
--- GameShot 专用的只读状态；输入验收据此等待实际状态，避免固定延迟猜时机。
function ____exports.getDebugGameState() -- 1162
	return debugGameStateFn ~= nil and debugGameStateFn() or "phase=Loading" -- 1163
end -- 1162
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1167
	if outcome == nil then -- 1167
		outcome = "success" -- 1167
	end -- 1167
	if debugTriggerResultFn ~= nil then -- 1167
		debugTriggerResultFn(levelIndex, outcome) -- 1169
	end -- 1169
end -- 1167
--- 触发进入制动窗口演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakeWindow(levelIndex) -- 1174
	if levelIndex == nil then -- 1174
		levelIndex = 3 -- 1174
	end -- 1174
	if debugTriggerBrakeWindowFn ~= nil then -- 1174
		debugTriggerBrakeWindowFn(levelIndex) -- 1176
	end -- 1176
end -- 1174
--- 触发按下逆喷制动按钮演示（调试/自动化截图用）。
function ____exports.triggerDebugBrakePress() -- 1181
	if debugTriggerBrakePressFn ~= nil then -- 1181
		debugTriggerBrakePressFn() -- 1183
	end -- 1183
end -- 1181
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1188
	if debugTriggerEnterLevelFn ~= nil then -- 1188
		debugTriggerEnterLevelFn(levelIndex) -- 1190
	end -- 1190
end -- 1188
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1195
	if debugTriggerZoomInFn ~= nil then -- 1195
		debugTriggerZoomInFn() -- 1197
	end -- 1197
end -- 1195
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1202
	if debugTriggerResetViewFn ~= nil then -- 1202
		debugTriggerResetViewFn() -- 1204
	end -- 1204
end -- 1202
return ____exports -- 1202
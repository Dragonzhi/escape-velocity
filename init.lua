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
local debugTriggerEnterLevelFn = nil -- 112
local debugTriggerZoomInFn = nil -- 113
local debugTriggerResetViewFn = nil -- 114
local debugGameStateFn = nil -- 115
local activeResultPanel = nil -- 116
local levelsText = Content:exist("Assets/Levels/levels.json") and Content:load("Assets/Levels/levels.json") or "" -- 124
local bodiesText = Content:exist("Assets/Levels/bodies.json") and Content:load("Assets/Levels/bodies.json") or "" -- 125
local function decodeLevelJson(text) -- 126
	local decoded = {json.decode(text)} -- 127
	local err = decoded[2] -- 128
	if err ~= nil then -- 128
		return nil -- 129
	end -- 129
	return decoded[1] -- 130
end -- 126
if not installArcadeLevels(levelsText, bodiesText, decodeLevelJson) then -- 126
	print("[escape-velocity] FATAL: levels.json 没有装上") -- 133
end -- 133
local levelTotal = levelCount() -- 135
if levelTotal <= 0 then -- 135
	print("[escape-velocity] FATAL: no level data") -- 138
else -- 138
	local opening, startOpening, introHold -- 138
	local viewW = View.size.width -- 140
	local viewH = View.size.height -- 141
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 144
	local levelLayers = {} -- 150
	do -- 150
		local i = 0 -- 151
		while i < levelTotal do -- 151
			local layer = Node() -- 152
			layer.size = Size(viewW, viewH) -- 153
			layer.anchor = Vec2(0.5, 0.5) -- 154
			layer.position = Vec2(0, 0) -- 155
			Director.ui:addChild(layer) -- 156
			levelLayers[#levelLayers + 1] = layer -- 157
			i = i + 1 -- 151
		end -- 151
	end -- 151
	local openingLayer = Node() -- 162
	openingLayer.size = Size(viewW, viewH) -- 163
	openingLayer.anchor = Vec2(0.5, 0.5) -- 164
	openingLayer.position = Vec2(0, 0) -- 165
	Director.ui:addChild(openingLayer) -- 166
	local openingRoot = Node3D() -- 169
	openingRoot.visible = false -- 170
	Director.entry:addChild(openingRoot) -- 171
	local openingCamera = Camera3D() -- 172
	local hubRoot = Node3D() -- 175
	hubRoot.visible = false -- 176
	Director.entry:addChild(hubRoot) -- 177
	local hubCamera = Camera3D() -- 178
	local hubLayer = Node() -- 180
	hubLayer.size = Size(viewW, viewH) -- 181
	hubLayer.anchor = Vec2(0.5, 0.5) -- 182
	hubLayer.position = Vec2(0, 0) -- 183
	Director.ui:addChild(hubLayer) -- 184
	local uiLayer = Node() -- 187
	uiLayer.size = Size(viewW, viewH) -- 188
	uiLayer.anchor = Vec2(0.5, 0.5) -- 189
	uiLayer.position = Vec2(0, 0) -- 190
	Director.ui:addChild(uiLayer) -- 191
	local levelNames = {} -- 194
	do -- 194
		local i = 0 -- 195
		while i < levelTotal do -- 195
			local def = getLevel(i) -- 196
			local title = def ~= nil and def.title or "" -- 197
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 198
			i = i + 1 -- 195
		end -- 195
	end -- 195
	local levelEntries = {} -- 200
	do -- 200
		local i = 0 -- 201
		while i < levelTotal do -- 201
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 201
			i = i + 1 -- 201
		end -- 201
	end -- 201
	local progress = loadProgress(levelTotal) -- 204
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 205
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 206
	local slots = {} -- 208
	do -- 208
		local i = 0 -- 209
		while i < levelTotal do -- 209
			slots[#slots + 1] = {built = false, runtime = nil} -- 209
			i = i + 1 -- 209
		end -- 209
	end -- 209
	local activeIndex = -1 -- 211
	local select = nil -- 212
	local solarHub = nil -- 213
	local resultPanel = nil -- 214
	local finalePanel = nil -- 216
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 218
	local resultIndex = -1 -- 223
	local function activeRuntime() -- 225
		if activeIndex < 0 then -- 225
			return nil -- 226
		end -- 226
		return slots[activeIndex + 1].runtime -- 227
	end -- 225
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 235
		do -- 235
			local i = 0 -- 236
			while i < levelTotal do -- 236
				do -- 236
					local slot = slots[i + 1] -- 237
					levelLayers[i + 1].visible = i == index -- 240
					if slot.runtime == nil then -- 240
						goto __continue27 -- 241
					end -- 241
					local active = i == index -- 242
					slot.runtime.world.visible = active -- 243
					slot.runtime.aim:setEnabled(active) -- 244
				end -- 244
				::__continue27:: -- 244
				i = i + 1 -- 236
			end -- 236
		end -- 236
	end -- 235
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 253
		local game -- 253
		local slot = slots[index + 1] -- 254
		if slot.built and slot.runtime ~= nil then -- 254
			return slot.runtime -- 255
		end -- 255
		local def = getLevel(index) -- 257
		if def == nil then -- 257
			return nil -- 258
		end -- 258
		local bodies = scaledPlanets(def) -- 260
		local level = { -- 261
			transfer = def.transfer, -- 262
			bodies = bodies, -- 263
			probeStart = def.probeStart, -- 264
			probeVel0 = def.probeVel0, -- 266
			goal = def.goal, -- 267
			escapeRadius = def.escapeRadius, -- 268
			physicsStep = levelRuntime(index).physicsStep, -- 269
			speedUnit = 1, -- 271
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 272
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 273
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 274
			aimFraming = levelRuntime(index).aimFraming, -- 275
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 276
			aimMin = levelRuntime(index).aimMin, -- 277
			maxSteps = def.maxSteps, -- 278
			predictSteps = levelRuntime(index).predictSteps, -- 279
			mission = def.mission, -- 280
			stars = def.stars, -- 281
			starOrbits = starOrbits(index) -- 282
		} -- 282
		local world = Node3D() -- 285
		Director.entry:addChild(world) -- 286
		world.visible = false -- 287
		local rtg = def.probeVariant == "rtg" -- 289
		local scene = buildScene({ -- 290
			root = world, -- 291
			backdropRadius = def.transfer ~= nil and (def.transfer.orbital ~= nil and 6000 or 3000) or nil, -- 292
			bodies = bodies, -- 293
			visuals = def.visuals, -- 294
			probeStart = level.probeStart, -- 295
			stars = def.stars, -- 296
			probeScale = levelRuntime(index).probeVisualRadius, -- 302
			spherePath = "Assets/Model/Sphere.gltf", -- 303
			ringPath = "Assets/Model/Ring.gltf", -- 304
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 305
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 312
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 313
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 314
			probeBodyRadius = rtg and 0.871 or 1.084, -- 315
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 317
			orbitFlowDots = levelRuntime(index).orbitFlowDots, -- 318
			orbitRings = levelRuntime(index).orbitRings -- 321
		}) -- 321
		if scene == nil then -- 321
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 324
			return nil -- 325
		end -- 325
		local rt = levelRuntime(index) -- 328
		local camera = Camera3D() -- 329
		local rigOptions = defaultRigOptions( -- 333
			View.fieldOfView, -- 333
			View.aspectRatio, -- 333
			rt.cameraMin, -- 333
			rt.cameraMax, -- 333
			rt.tiltDeg -- 333
		) -- 333
		if def.transfer ~= nil then -- 333
			rigOptions.margin = 0.16 -- 335
			rigOptions.screenMinY = 2 * math.min(350, viewH * 0.38) / viewH - 1 -- 336
			rigOptions.screenMaxY = 1 - 2 * math.min(205, viewH * 0.23) / viewH -- 337
			rigOptions.screenBiasY = 0.14 -- 338
		end -- 338
		local rig = createCameraRig(rigOptions) -- 340
		local trailOptions = trajectoryOptions() -- 341
		if def.transfer ~= nil then -- 341
			trailOptions.tailPoints = 120 -- 344
			trailOptions.burnLength = 12 -- 345
			trailOptions.trailHeadRadius = 1.2 -- 346
			trailOptions.trailHeadAlpha = 0.45 -- 347
			trailOptions.trailR = 100 -- 348
			trailOptions.trailG = 180 -- 348
			trailOptions.trailB = 230 -- 348
		end -- 348
		local trajectory = createTrajectoryView(levelLayers[index + 1], trailOptions) -- 350
		local planOpts = defaultPlanOptions() -- 354
		planOpts.actualBodySizes = def.id == 2 -- 355
		planOpts.transferTutorial = def.transfer ~= nil -- 356
		if levelRuntime(index).orbitFlowDots == false then -- 356
			planOpts.flowDotRadius = 0 -- 357
		end -- 357
		planOpts.probeVisualRadius = levelRuntime(index).probeVisualRadius -- 360
		if def.transfer ~= nil then -- 360
			planOpts.trailHex = 6599910 -- 361
			planOpts.trailWidth = 1.5 -- 361
		end -- 361
		local plan = createPlanView( -- 362
			levelLayers[index + 1], -- 362
			viewW, -- 362
			viewH, -- 362
			planOpts, -- 362
			def.planCenter -- 362
		) -- 362
		local offset = def.goal.offset -- 363
		local planTolerance = arrivalRingRadius(def.goal) + (offset ~= nil and math.sqrt(offset.x * offset.x + offset.y * offset.y) or 0) -- 364
		plan:fitTo(math.max( -- 365
			planFitRadius( -- 365
				bodies, -- 365
				level.probeStart, -- 365
				def.goal.planetIndex, -- 365
				planTolerance, -- 365
				def.planCenter, -- 365
				starOrbits(index) -- 365
			), -- 365
			def.transfer ~= nil and def.transfer.orbital ~= nil and def.transfer.orbital.region ~= nil and def.transfer.orbital.region.maxRadius + 20 or 0 -- 365
		)) -- 365
		local aim = createAimInput( -- 367
			levelLayers[index + 1], -- 367
			viewW, -- 367
			viewH, -- 367
			def.dvBudget, -- 367
			rt.aimMin, -- 367
			rt.playbackSpeeds, -- 367
			def.transfer ~= nil, -- 367
			def.transfer ~= nil and def.transfer.orbital ~= nil and (def.transfer.mode == "lowerPeriapsis" and "inward" or "outward") or "lunar" -- 367
		) -- 367
		aim:setBurnInfo(0, def.dvBudget) -- 369
		local dateSpan = def.timeWindow ~= nil and def.timeWindow.span or 0 -- 371
		aim:setDate(0, dateSpan) -- 372
		aim:onWarp(function(dir) -- 373
			game:stepTime(dir, dateSpan) -- 374
			print(((("[escape-velocity] time warp dir=" .. __TS__NumberToFixed(dir, 0)) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 375
		end) -- 373
		aim:onZoomIn(function() -- 379
			plan:zoomIn() -- 380
		end) -- 379
		aim:onZoomOut(function() -- 382
			plan:zoomOut() -- 383
		end) -- 382
		aim:onFitView(function() -- 385
			plan:resetView() -- 386
		end) -- 385
		local challengesList = {} -- 390
		if def.mission ~= nil then -- 390
			do -- 390
				local k = 0 -- 392
				while k < #def.mission.challenges do -- 392
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 393
					k = k + 1 -- 392
				end -- 392
			end -- 392
		end -- 392
		local initialRockets = getMissionRockets(progress, index) -- 396
		local drawerTitle = def.transfer ~= nil and (("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. (index == 0 and "奔向月球" or (index == 1 and "借金星减速，飞掠水星" or "双星甩尾")) or (def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1]) -- 397
		aim:setMissionDrawer(drawerTitle, challengesList, initialRockets) -- 398
		game = createGame( -- 400
			level, -- 400
			{ -- 400
				scene = scene, -- 401
				camera = camera, -- 402
				rig = rig, -- 403
				trajectory = trajectory, -- 404
				plan = plan, -- 405
				visuals = def.visuals, -- 407
				setWorldVisible = function(____, on) -- 409
					world.visible = on -- 410
				end, -- 409
				aim = aim, -- 412
				viewW = viewW, -- 413
				viewH = viewH, -- 414
				fovYDeg = View.fieldOfView, -- 415
				aspect = View.aspectRatio, -- 416
				onPhase = function(____, p) -- 417
					print(((("[escape-velocity] phase -> " .. p) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 418
					if index == activeIndex then -- 418
						local inAim = (p == "Aiming" or p == "Armed") and not game:isIntroTourActive() -- 425
						aim:setZoomControlsVisible(inAim and game:viewMode() == "2D") -- 426
						aim:setMissionDrawerVisible(inAim) -- 427
						if p == "Finale" then -- 427
							if resultPanel ~= nil then -- 427
								resultPanel:hide() -- 429
							end -- 429
							if finalePanel ~= nil then -- 429
								finalePanel:show(finaleText.main, finaleText.sub) -- 430
							end -- 430
						else -- 430
							if p ~= "Result" and resultPanel ~= nil then -- 430
								resultPanel:hide() -- 432
							end -- 432
							if finalePanel ~= nil then -- 432
								finalePanel:hide() -- 433
							end -- 433
						end -- 433
					end -- 433
				end, -- 417
				onMissionCompleted = function() -- 437
					progress = recordMissionResult(progress, index, 1, levelTotal) -- 438
					saveProgress(progress) -- 439
					print("[escape-velocity] flyby completion saved L" .. __TS__NumberToFixed(index + 1, 0)) -- 440
				end, -- 437
				onResult = function(____, r, telemetry) -- 442
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 443
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity, starsCollected = telem.starsCollected ~= nil and telem.starsCollected or 0}) -- 449
					if not game:missionCompleted() then -- 449
						progress = recordMissionResult(progress, index, evalInfo.rockets, levelTotal) -- 458
						saveProgress(progress) -- 459
					end -- 459
					local currentTotal = getTotalRockets(progress, levelTotal) -- 461
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(levelTotal * 3, 0)) .. ")") -- 463
					resultIndex = index -- 467
					local challengesList = {} -- 469
					if def.mission ~= nil then -- 469
						do -- 469
							local k = 0 -- 471
							while k < #def.mission.challenges do -- 471
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 472
								k = k + 1 -- 471
							end -- 471
						end -- 471
					end -- 471
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 476
					local detailParams = { -- 480
						result = r, -- 481
						levelName = titleWithSub, -- 482
						levelIndex = index, -- 483
						rocketsGot = evalInfo.rockets, -- 484
						challenges = challengesList, -- 485
						completionOnly = def.transfer ~= nil, -- 486
						achieved = evalInfo.achieved, -- 487
						burnDv = telem.burnDv, -- 488
						dvBudget = def.dvBudget, -- 489
						flightTime = telem.flightTime, -- 490
						totalRockets = currentTotal, -- 491
						totalPossibleRockets = levelTotal * 3 -- 492
					} -- 492
					if resultPanel ~= nil then -- 492
						resultPanel:show(r, titleWithSub, detailParams) -- 496
					end -- 496
				end, -- 442
				onFinale = function(____, info) -- 500
					finaleText = { -- 501
						main = FinaleMainText, -- 501
						sub = finaleSubtitle(info.distance, info.time) -- 501
					} -- 501
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 502
				end, -- 500
				finale = index == levelTotal - 1 and def.transfer == nil -- 507
			} -- 507
		) -- 507
		aim:onQuickRetry(function() -- 510
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 511
			game:retry() -- 512
		end) -- 510
		aim:onDrag(function(a) -- 518
			game:onAimDrag(a) -- 519
			aim:setBurnInfo( -- 521
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 521
				def.dvBudget -- 521
			) -- 521
		end) -- 518
		aim:onAimReady(function(a) -- 524
			game:onAimDrag(a) -- 525
			game:aimReady() -- 526
			print("[escape-velocity] aim ready -> Armed") -- 527
		end) -- 524
		aim:onLaunch(function() -- 529
			print("[escape-velocity] launch button tap") -- 530
			game:launchArmed() -- 531
		end) -- 529
		aim:onCancelAim(function() -- 533
			print("[escape-velocity] cancel aim tap") -- 534
			game:cancelAim() -- 535
		end) -- 533
		aim:onObserve(function(dx, dy) -- 538
			game:observeDrag(dx, dy) -- 539
		end) -- 538
		aim:onZoom(function(deltaDist) -- 541
			game:observeZoom(deltaDist) -- 542
		end) -- 541
		aim:onSkipTour(function() -- 544
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 545
			game:skipIntroTour() -- 546
		end) -- 544
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 548
		aim:onViewToggle(function() -- 550
			game:toggleViewMode() -- 551
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 552
		end) -- 550
		if aim.onCameraFocus ~= nil then -- 550
			aim:onCameraFocus(function() -- 554
				game:cycleCameraFocus() -- 554
			end) -- 554
		end -- 554
		if aim.onEndViewing ~= nil then -- 554
			aim:onEndViewing(function() -- 555
				game:endViewing() -- 555
			end) -- 555
		end -- 555
		aim:onSpeedUp(function() -- 559
			game:speedUp() -- 560
		end) -- 559
		aim:onSpeedDown(function() -- 562
			game:speedDown() -- 563
		end) -- 562
		aim:onTogglePause(function() -- 565
			game:togglePause() -- 566
		end) -- 565
		aim:onPlayback(function(speed) -- 568
			game:setPlaybackSpeed(speed) -- 569
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 570
		end) -- 568
		aim:setPlayback(game:playbackSpeed()) -- 572
		local runtime = { -- 574
			index = index, -- 575
			name = levelNames[index + 1], -- 576
			world = world, -- 577
			camera = camera, -- 578
			game = game, -- 579
			aim = aim, -- 580
			trajectory = trajectory, -- 581
			plan = plan, -- 582
			levelHasTimeWindow = def.timeWindow ~= nil, -- 583
			dvBudget = def.dvBudget, -- 584
			dateSpan = dateSpan -- 585
		} -- 585
		slot.built = true -- 587
		slot.runtime = runtime -- 588
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 589
		return runtime -- 590
	end -- 253
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 594
		local runtime = ensureLevel(index) -- 595
		if runtime == nil then -- 595
			return -- 596
		end -- 596
		local wasActive = activeIndex == index -- 599
		if opening ~= nil then -- 599
			opening.hide() -- 601
		end -- 601
		if select ~= nil then -- 601
			select:hide() -- 602
		end -- 602
		if solarHub ~= nil then -- 602
			solarHub.hide() -- 603
		end -- 603
		activeIndex = index -- 604
		showOnlyLevel(index) -- 605
		applyClipPlanes(index) -- 607
		if not wasActive then -- 607
			Director:pushCamera(runtime.camera) -- 608
		end -- 608
		runtime.game:startLevel() -- 609
		print("[escape-velocity] enter " .. runtime.name) -- 610
	end -- 594
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 614
		if resultIndex >= 0 and resultIndex < levelTotal then -- 614
			local rt = slots[resultIndex + 1].runtime -- 616
			if rt ~= nil then -- 616
				return rt -- 617
			end -- 617
		end -- 617
		return activeRuntime() -- 619
	end -- 614
	local function onRetryTap() -- 622
		local rt = resultRuntime() -- 624
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 625
		if resultPanel ~= nil then -- 625
			resultPanel:hide() -- 626
		end -- 626
		if rt ~= nil then -- 626
			rt.game:retry() -- 627
		end -- 627
	end -- 622
	local function ensureSolarHub() -- 630
		if solarHub ~= nil then -- 630
			return solarHub -- 631
		end -- 631
		solarHub = createSolarHub({ -- 632
			root = hubRoot, -- 633
			camera = hubCamera, -- 634
			layer = hubLayer, -- 635
			viewW = viewW, -- 636
			viewH = viewH, -- 637
			fovYDeg = View.fieldOfView, -- 638
			aspect = View.aspectRatio, -- 639
			spherePath = "Assets/Model/Sphere.gltf", -- 640
			onLaunch = function(____, levelIndex) -- 641
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 642
				if solarHub ~= nil then -- 642
					solarHub.hide() -- 643
				end -- 643
				enterLevel(levelIndex) -- 644
			end, -- 641
			onReplayIntro = function() -- 646
				if solarHub ~= nil then -- 646
					solarHub.hide() -- 647
				end -- 647
				startOpening() -- 648
				print("[escape-velocity] opening replay from solarHub") -- 649
			end -- 646
		}) -- 646
		return solarHub -- 652
	end -- 630
	local function onBackToSelectTap() -- 655
		local rt = resultRuntime() -- 656
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 657
		if rt == nil then -- 657
			return -- 658
		end -- 658
		local runtime = rt -- 659
		if not runtime.game:backToSelect() then -- 659
			return -- 661
		end -- 661
		runtime.world.visible = false -- 662
		runtime.aim:setEnabled(false) -- 663
		if resultPanel ~= nil then -- 663
			resultPanel:hide() -- 664
		end -- 664
		if finalePanel ~= nil then -- 664
			finalePanel:hide() -- 666
		end -- 666
		if select ~= nil then -- 666
			select:hide() -- 667
		end -- 667
		progress = loadProgress(levelTotal) -- 669
		local hub = ensureSolarHub() -- 670
		useCamera(hubCamera, -1) -- 671
		hub.show(progress) -- 672
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 673
			getTotalRockets(progress, levelTotal), -- 673
			0 -- 673
		)) -- 673
	end -- 655
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 686
		finalePanel = createFinalePanel( -- 689
			uiLayer, -- 689
			viewW, -- 689
			viewH, -- 689
			{onBackToSelect = function() return onBackToSelectTap() end} -- 689
		) -- 689
		resultPanel = createResultPanel( -- 692
			uiLayer, -- 692
			viewW, -- 692
			viewH, -- 692
			{ -- 692
				onRetry = function() return onRetryTap() end, -- 693
				onBackToSelect = function() return onBackToSelectTap() end -- 694
			} -- 694
		) -- 694
		activeResultPanel = resultPanel -- 696
		local created = createLevelSelect( -- 697
			uiLayer, -- 697
			viewW, -- 697
			viewH, -- 697
			{ -- 697
				levels = levelEntries, -- 698
				onPick = function(____, index) -- 699
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 700
					if select ~= nil then -- 700
						select:hide() -- 701
					end -- 701
					enterLevel(index) -- 702
				end, -- 699
				onReplayIntro = function() -- 705
					if select ~= nil then -- 705
						select:hide() -- 706
					end -- 706
					startOpening() -- 707
					print("[escape-velocity] opening replay (user)") -- 708
				end -- 705
			} -- 705
		) -- 705
		select = created -- 711
		return created -- 712
	end -- 686
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 725
		local w = View.size.width -- 726
		local h = View.size.height -- 727
		if w == viewW and h == viewH then -- 727
			return -- 728
		end -- 728
		if opening ~= nil then -- 728
			opening.hide() -- 734
			opening = nil -- 735
		end -- 735
		if select ~= nil then -- 735
			select:hide() -- 737
		end -- 737
		if resultPanel ~= nil then -- 737
			resultPanel:hide() -- 738
		end -- 738
		if finalePanel ~= nil then -- 738
			finalePanel:hide() -- 739
		end -- 739
		do -- 739
			local i = 0 -- 740
			while i < levelTotal do -- 740
				local slot = slots[i + 1] -- 741
				if slot.runtime ~= nil then -- 741
					slot.runtime.world.visible = false -- 743
					slot.runtime.aim:setEnabled(false) -- 744
					slot.runtime.trajectory:clearPrediction() -- 747
					slot.runtime.trajectory:clearTrail() -- 748
					slot.runtime.trajectory:clearGoalRings() -- 750
					slot.runtime.plan:setVisible(false) -- 753
					slot.runtime.plan:clear() -- 754
				end -- 754
				slot.built = false -- 756
				slot.runtime = nil -- 757
				i = i + 1 -- 740
			end -- 740
		end -- 740
		viewW = w -- 761
		viewH = h -- 762
		uiLayer.size = Size(viewW, viewH) -- 763
		openingLayer.size = Size(viewW, viewH) -- 764
		hubLayer.size = Size(viewW, viewH) -- 765
		do -- 765
			local i = 0 -- 766
			while i < levelTotal do -- 766
				levelLayers[i + 1].size = Size(viewW, viewH) -- 766
				i = i + 1 -- 766
			end -- 766
		end -- 766
		if solarHub ~= nil then -- 766
			solarHub.relayout(viewW, viewH) -- 768
		end -- 768
		buildPanels() -- 772
		if activeIndex >= 0 then -- 772
			local keep = activeIndex -- 774
			activeIndex = -1 -- 775
			enterLevel(keep) -- 776
		else -- 776
			local hub = ensureSolarHub() -- 778
			useCamera(hubCamera, -1) -- 779
			hub.show(progress) -- 780
		end -- 780
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 782
	end -- 725
	Director.entry:onAppChange(function(name) -- 786
		if name == "Size" then -- 786
			relayoutForViewport() -- 787
		end -- 787
	end) -- 786
	local introSeen = loadIntroSeen() -- 795
	local forceIntro = false -- 796
	opening = nil -- 797
	startOpening = function() -- 799
		if opening == nil then -- 799
			opening = createOpening({ -- 801
				root = openingRoot, -- 802
				camera = openingCamera, -- 803
				layer = openingLayer, -- 804
				viewW = viewW, -- 805
				viewH = viewH, -- 806
				fovYDeg = View.fieldOfView, -- 807
				aspect = View.aspectRatio, -- 808
				spherePath = "Assets/Model/Sphere.gltf", -- 809
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 810
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 811
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 812
				onFinish = function() -- 813
					introHold = -1 -- 814
					if not introSeen then -- 814
						saveIntroSeen() -- 816
						introSeen = true -- 817
						print("[escape-velocity] intro seen -> saved") -- 818
					end -- 818
					if opening ~= nil then -- 818
						opening.hide() -- 821
					end -- 821
					if select ~= nil then -- 821
						select:hide() -- 822
					end -- 822
					local hub = ensureSolarHub() -- 823
					useCamera(hubCamera, -1) -- 824
					hub.show(progress) -- 825
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 826
						opening.frameIndex(), -- 826
						0 -- 826
					) or "?")) -- 826
				end -- 813
			}) -- 813
		end -- 813
		if opening == nil then -- 813
			return -- 830
		end -- 830
		useCamera(openingCamera, -1) -- 831
		opening.start() -- 832
		print("[escape-velocity] opening start (first launch)") -- 833
	end -- 799
	local startupPanel = buildPanels() -- 836
	local enterReq = Path( -- 848
		Path(".", ".agent", "test-results"), -- 848
		"enter-request.txt" -- 848
	) -- 848
	local autoLaunchAt = -1 -- 849
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 851
	local autoFrame = 0 -- 852
	local autoVX = 0 -- 853
	local autoVY = 0 -- 854
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 862
	local autoBackAt = -1 -- 864
	local autoReenterAt = -1 -- 865
	local autoEntered = false -- 866
	introHold = -1 -- 868
	if Content:exist(enterReq) then -- 868
		local spec = Content:load(enterReq) -- 870
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 871
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 872
		if head == "intro" then -- 872
			forceIntro = true -- 874
			if at >= 0 then -- 874
				local rest = __TS__StringSubstring(spec, at + 1) -- 876
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 877
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 877
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 879
					if v ~= nil and v >= 0 then -- 879
						introHold = v -- 881
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 882
					end -- 882
				end -- 882
			end -- 882
		end -- 882
		local n = tonumber(head) -- 887
		if n ~= nil and n >= 1 and n <= levelTotal then -- 887
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 889
			enterLevel(n - 1) -- 890
			autoEntered = true -- 891
			if at >= 0 then -- 891
				local rest = __TS__StringSubstring(spec, at + 1) -- 893
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 893
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 898
					if f ~= nil and f >= 0 then -- 898
						autoArmAt = f -- 900
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 901
					end -- 901
				else -- 901
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 904
					local c2 = (string.find( -- 905
						rest, -- 905
						":", -- 905
						math.max(c1 + 1 + 1, 1), -- 905
						true -- 905
					) or 0) - 1 -- 905
					if c1 > 0 and c2 > c1 then -- 905
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 907
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 908
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 911
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 912
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 913
						local vy = tonumber(vyText) -- 914
						local ____temp_0 -- 915
						if c3 > 0 then -- 915
							____temp_0 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 915
						else -- 915
							____temp_0 = nil -- 915
						end -- 915
						local steps = ____temp_0 -- 915
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 915
							autoLaunchAt = frames -- 917
							autoVX = vx -- 918
							autoVY = vy -- 919
							if steps ~= nil and steps > 0 then -- 919
								autoWarpSteps = math.floor(steps) -- 921
							end -- 921
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 923
						end -- 923
					end -- 923
				end -- 923
			end -- 923
		end -- 923
	end -- 923
	if autoEntered then -- 923
		print("[escape-velocity] opening skipped (auto enter)") -- 936
	elseif forceIntro or not introSeen then -- 936
		startOpening() -- 938
	else -- 938
		local hub = ensureSolarHub() -- 940
		useCamera(hubCamera, -1) -- 941
		hub.show(progress) -- 942
		print("[escape-velocity] entered solarHub (already seen)") -- 943
	end -- 943
	threadLoop(function() -- 948
		advanceUiClock(App.deltaTime) -- 952
		if solarHub ~= nil and solarHub.visible() then -- 952
			solarHub.step(App.deltaTime) -- 956
		end -- 956
		if opening ~= nil and opening.running() then -- 956
			if introHold < 0 or opening.frameIndex() < introHold then -- 956
				opening.step() -- 962
			end -- 962
			if App.deltaTime > 0.05 then -- 962
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 966
					opening.frameIndex(), -- 966
					0 -- 966
				)) -- 966
			end -- 966
		end -- 966
		local runtime = activeRuntime() -- 970
		if runtime ~= nil then -- 970
			runtime.game:update(App.deltaTime) -- 972
			runtime.aim:setBurnInfo( -- 974
				runtime.game:burnNow(), -- 974
				runtime.dvBudget -- 974
			) -- 974
			if runtime.levelHasTimeWindow then -- 974
				runtime.aim:setDate( -- 977
					runtime.game:dateNow(), -- 977
					runtime.dateSpan -- 977
				) -- 977
			end -- 977
			local phaseNow = runtime.game:phase() -- 981
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 982
			runtime.aim:update(App.deltaTime) -- 983
			runtime.aim:setArmed(runtime.game:armed()) -- 985
			runtime.aim:setStarsStatus(runtime.game:starsNow()) -- 986
			local is2D = runtime.game:viewMode() == "2D" -- 988
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 989
			if runtime.aim.setFlightViewing ~= nil then -- 989
				runtime.aim:setFlightViewing( -- 990
					phaseNow == "Flying", -- 990
					runtime.game:missionCompleted(), -- 990
					runtime.game:cameraFocus(), -- 990
					not is2D, -- 990
					runtime.game:flightStage() -- 990
				) -- 990
			end -- 990
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 991
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 992
			runtime.aim:setMissionDrawerVisible(inAim) -- 993
			local curBurn = runtime.game:burnNow() -- 995
			local fuelLimit = runtime.dvBudget * 0.75 -- 996
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 997
			runtime.aim:setTimeControl( -- 1000
				runtime.game:speedPow(), -- 1001
				runtime.game:speedMaxPow(), -- 1002
				runtime.game:isPaused(), -- 1003
				runtime.game:missionSeconds(), -- 1004
				runtime.game:speedRate() -- 1005
			) -- 1005
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 1005
				autoFrame = autoFrame + 1 -- 1009
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 1009
					autoArmAt = -1 -- 1012
					print("[escape-velocity] auto arm (enter-request)") -- 1013
					runtime.game:aimReady() -- 1014
				end -- 1014
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 1014
					autoLaunchAt = -1 -- 1017
					print("[escape-velocity] auto launch") -- 1018
					if autoWarpSteps > 0 then -- 1018
						do -- 1018
							local s = 0 -- 1022
							while s < autoWarpSteps do -- 1022
								runtime.game:stepTime(1, runtime.dateSpan) -- 1022
								s = s + 1 -- 1022
							end -- 1022
						end -- 1022
						autoWarpSteps = 0 -- 1023
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 1024
							runtime.game:dateNow(), -- 1024
							0 -- 1024
						)) .. ")") -- 1024
					end -- 1024
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 1026
					runtime.game:launch({x = autoVX, y = autoVY}) -- 1027
					autoBackAt = autoFrame + 320 -- 1028
					autoReenterAt = autoFrame + 380 -- 1029
				end -- 1029
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 1029
					autoBackAt = -1 -- 1033
					if runtime.game:backToSelect() then -- 1033
						print("[escape-velocity] auto back to select") -- 1034
					end -- 1034
				end -- 1034
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1034
					autoReenterAt = -1 -- 1037
					print("[escape-velocity] auto re-enter") -- 1038
					enterLevel(0) -- 1039
				end -- 1039
			end -- 1039
		end -- 1039
		return false -- 1044
	end) -- 948
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1048
	debugTriggerResultFn = function(levelIndex, outcome) -- 1050
		if outcome == nil then -- 1050
			outcome = "success" -- 1050
		end -- 1050
		if solarHub ~= nil then -- 1050
			solarHub.hide() -- 1051
		end -- 1051
		if opening ~= nil then -- 1051
			opening.hide() -- 1052
		end -- 1052
		local def = getLevel(levelIndex) -- 1053
		if def == nil or resultPanel == nil then -- 1053
			return -- 1054
		end -- 1054
		local burn = def.dvBudget * 0.65 -- 1055
		local challengesList = {} -- 1056
		if def.mission ~= nil then -- 1056
			do -- 1056
				local k = 0 -- 1058
				while k < #def.mission.challenges do -- 1058
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1059
					k = k + 1 -- 1058
				end -- 1058
			end -- 1058
		end -- 1058
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1062
		resultPanel:show(outcome, titleWithSub, { -- 1066
			result = outcome, -- 1067
			levelName = titleWithSub, -- 1068
			levelIndex = levelIndex, -- 1069
			rocketsGot = outcome == "success" and 3 or 0, -- 1070
			challenges = challengesList, -- 1071
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1072
			burnDv = burn, -- 1073
			dvBudget = def.dvBudget, -- 1074
			flightTime = 12.8, -- 1075
			totalRockets = outcome == "success" and 16 or 13, -- 1076
			totalPossibleRockets = 18 -- 1077
		}) -- 1077
	end -- 1050
	debugTriggerEnterLevelFn = function(levelIndex) -- 1081
		if solarHub ~= nil then -- 1081
			solarHub.hide() -- 1082
		end -- 1082
		if opening ~= nil then -- 1082
			opening.hide() -- 1083
		end -- 1083
		enterLevel(levelIndex) -- 1084
	end -- 1081
	debugGameStateFn = function() -- 1086
		local rt = activeRuntime() -- 1087
		if rt == nil then -- 1087
			return "phase=LevelSelect" -- 1088
		end -- 1088
		local g = rt.game -- 1089
		return (((((((((((((((("phase=" .. g:phase()) .. "\ndate=") .. __TS__NumberToFixed( -- 1090
			g:dateNow(), -- 1090
			6 -- 1090
		)) .. "\nworld=") .. __TS__NumberToFixed( -- 1090
			g:missionSeconds(), -- 1090
			6 -- 1090
		)) .. "\nrate=") .. __TS__NumberToFixed( -- 1090
			g:speedRate(), -- 1091
			6 -- 1091
		)) .. "\npaused=") .. (g:isPaused() and "1" or "0")) .. "\nfocus=") .. g:cameraFocus()) .. "\ncompleted=") .. (g:missionCompleted() and "1" or "0")) .. "\nview=") .. g:viewMode()) .. "\nmarker=") .. __TS__NumberToFixed( -- 1091
			g:markerElapsed(), -- 1092
			6 -- 1092
		) -- 1092
	end -- 1086
	debugTriggerZoomInFn = function() -- 1095
		local rt = activeRuntime() -- 1096
		if rt ~= nil then -- 1096
			rt.plan:zoomIn() -- 1098
		end -- 1098
	end -- 1095
	debugTriggerResetViewFn = function() -- 1102
		local rt = activeRuntime() -- 1103
		if rt ~= nil then -- 1103
			rt.plan:resetView() -- 1105
		end -- 1105
	end -- 1102
end -- 1102
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1111
	return activeResultPanel -- 1112
end -- 1111
--- GameShot 专用的只读状态；输入验收据此等待实际状态，避免固定延迟猜时机。
function ____exports.getDebugGameState() -- 1116
	return debugGameStateFn ~= nil and debugGameStateFn() or "phase=Loading" -- 1117
end -- 1116
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1121
	if outcome == nil then -- 1121
		outcome = "success" -- 1121
	end -- 1121
	if debugTriggerResultFn ~= nil then -- 1121
		debugTriggerResultFn(levelIndex, outcome) -- 1123
	end -- 1123
end -- 1121
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1128
	if debugTriggerEnterLevelFn ~= nil then -- 1128
		debugTriggerEnterLevelFn(levelIndex) -- 1130
	end -- 1130
end -- 1128
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1135
	if debugTriggerZoomInFn ~= nil then -- 1135
		debugTriggerZoomInFn() -- 1137
	end -- 1137
end -- 1135
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1142
	if debugTriggerResetViewFn ~= nil then -- 1142
		debugTriggerResetViewFn() -- 1144
	end -- 1144
end -- 1142
return ____exports -- 1142
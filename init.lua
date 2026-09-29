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
local totalBonusPoints = 0 -- 136
do -- 136
	local i = 0 -- 137
	while i < levelTotal do -- 137
		local ____opt_2 = getLevel(i) -- 137
		local ____opt_0 = ____opt_2 and ____opt_2.bonusPoints -- 137
		totalBonusPoints = totalBonusPoints + (____opt_0 and #____opt_0 or 0) -- 137
		i = i + 1 -- 137
	end -- 137
end -- 137
if levelTotal <= 0 then -- 137
	print("[escape-velocity] FATAL: no level data") -- 140
else -- 140
	local opening, startOpening, introHold -- 140
	local viewW = View.size.width -- 142
	local viewH = View.size.height -- 143
	Director.entry:setEnvironmentIntensity(0.12, 0.12, 1) -- 146
	local levelLayers = {} -- 152
	do -- 152
		local i = 0 -- 153
		while i < levelTotal do -- 153
			local layer = Node() -- 154
			layer.size = Size(viewW, viewH) -- 155
			layer.anchor = Vec2(0.5, 0.5) -- 156
			layer.position = Vec2(0, 0) -- 157
			Director.ui:addChild(layer) -- 158
			levelLayers[#levelLayers + 1] = layer -- 159
			i = i + 1 -- 153
		end -- 153
	end -- 153
	local openingLayer = Node() -- 164
	openingLayer.size = Size(viewW, viewH) -- 165
	openingLayer.anchor = Vec2(0.5, 0.5) -- 166
	openingLayer.position = Vec2(0, 0) -- 167
	Director.ui:addChild(openingLayer) -- 168
	local openingRoot = Node3D() -- 171
	openingRoot.visible = false -- 172
	Director.entry:addChild(openingRoot) -- 173
	local openingCamera = Camera3D() -- 174
	local hubRoot = Node3D() -- 177
	hubRoot.visible = false -- 178
	Director.entry:addChild(hubRoot) -- 179
	local hubCamera = Camera3D() -- 180
	local hubLayer = Node() -- 182
	hubLayer.size = Size(viewW, viewH) -- 183
	hubLayer.anchor = Vec2(0.5, 0.5) -- 184
	hubLayer.position = Vec2(0, 0) -- 185
	Director.ui:addChild(hubLayer) -- 186
	local uiLayer = Node() -- 189
	uiLayer.size = Size(viewW, viewH) -- 190
	uiLayer.anchor = Vec2(0.5, 0.5) -- 191
	uiLayer.position = Vec2(0, 0) -- 192
	Director.ui:addChild(uiLayer) -- 193
	local levelNames = {} -- 196
	do -- 196
		local i = 0 -- 197
		while i < levelTotal do -- 197
			local def = getLevel(i) -- 198
			local title = def ~= nil and def.title or "" -- 199
			levelNames[#levelNames + 1] = (("L" .. __TS__NumberToFixed(i + 1, 0)) .. " ") .. title -- 200
			i = i + 1 -- 197
		end -- 197
	end -- 197
	local levelEntries = {} -- 202
	do -- 202
		local i = 0 -- 203
		while i < levelTotal do -- 203
			levelEntries[#levelEntries + 1] = {name = levelNames[i + 1]} -- 203
			i = i + 1 -- 203
		end -- 203
	end -- 203
	local progress = loadProgress(levelTotal) -- 206
	print("[escape-velocity] progress file: " .. progressFilePath()) -- 207
	print("[escape-velocity] progress loaded: unlocked=" .. __TS__NumberToFixed(progress.unlocked, 0)) -- 208
	local slots = {} -- 210
	do -- 210
		local i = 0 -- 211
		while i < levelTotal do -- 211
			slots[#slots + 1] = {built = false, runtime = nil} -- 211
			i = i + 1 -- 211
		end -- 211
	end -- 211
	local activeIndex = -1 -- 213
	local select = nil -- 214
	local solarHub = nil -- 215
	local resultPanel = nil -- 216
	local finalePanel = nil -- 218
	--- 终章要显示的两行字。主文案是常量，小字等 onFinale 把飞行距离/用时送过来。
	local finaleText = {main = FinaleMainText, sub = ""} -- 220
	local resultIndex = -1 -- 225
	local function activeRuntime() -- 227
		if activeIndex < 0 then -- 227
			return nil -- 228
		end -- 228
		return slots[activeIndex + 1].runtime -- 229
	end -- 227
	--- 只让当前关可见：其余关留在树里但 visible=false（不渲染、不更新），
	-- 并且**关掉它们的矄准输入** —— 它们的全屏触摸层是会独占触摸的，
	-- 只隐藏 3D 节点的话，玩家在第二关拖不动（点击被上一关的层吞掉）。
	local function showOnlyLevel(index) -- 237
		do -- 237
			local i = 0 -- 238
			while i < levelTotal do -- 238
				do -- 238
					local slot = slots[i + 1] -- 239
					levelLayers[i + 1].visible = i == index -- 242
					if slot.runtime == nil then -- 242
						goto __continue29 -- 243
					end -- 243
					local active = i == index -- 244
					slot.runtime.world.visible = active -- 245
					slot.runtime.aim:setEnabled(active) -- 246
				end -- 246
				::__continue29:: -- 246
				i = i + 1 -- 238
			end -- 238
		end -- 238
	end -- 237
	--- 惰性创建某一关的运行时：3D 容器 → 场景 → 相机/机架/轨迹/矄准 → 状态机。
	-- 
	-- @returns 该关运行时；已建则直接返回，建场景失败返回 undefined。
	local function ensureLevel(index) -- 255
		local game -- 255
		local slot = slots[index + 1] -- 256
		if slot.built and slot.runtime ~= nil then -- 256
			return slot.runtime -- 257
		end -- 257
		local def = getLevel(index) -- 259
		if def == nil then -- 259
			return nil -- 260
		end -- 260
		local bodies = scaledPlanets(def) -- 262
		local level = { -- 263
			levelId = index + 1, -- 264
			transfer = def.transfer, -- 265
			bodies = bodies, -- 266
			probeStart = def.probeStart, -- 267
			probeVel0 = def.probeVel0, -- 269
			goal = def.goal, -- 270
			bonusPoints = def.bonusPoints, -- 271
			viewingSeconds = index == 0 and 24 or (index == 1 and 12 or 6), -- 272
			escapeRadius = def.escapeRadius, -- 273
			physicsStep = levelRuntime(index).physicsStep, -- 274
			speedUnit = 1, -- 276
			speedDefaultPow = levelRuntime(index).speedDefaultPow, -- 277
			speedMaxPow = levelRuntime(index).speedMaxPow, -- 278
			flightSpeedPow = levelRuntime(index).flightSpeedPow, -- 279
			aimFraming = levelRuntime(index).aimFraming, -- 280
			slowMoFloor = levelRuntime(index).slowMoFloor, -- 281
			aimMin = levelRuntime(index).aimMin, -- 282
			maxSteps = def.maxSteps, -- 283
			predictSteps = levelRuntime(index).predictSteps, -- 284
			mission = def.mission, -- 285
			stars = def.stars, -- 286
			starOrbits = starOrbits(index) -- 287
		} -- 287
		local world = Node3D() -- 290
		Director.entry:addChild(world) -- 291
		world.visible = false -- 292
		local rtg = def.probeVariant == "rtg" -- 294
		local scene = buildScene({ -- 295
			root = world, -- 296
			backdropRadius = def.transfer ~= nil and (def.transfer.orbital ~= nil and 6000 or 3000) or nil, -- 297
			bodies = bodies, -- 298
			visuals = def.visuals, -- 299
			probeStart = level.probeStart, -- 300
			stars = def.stars, -- 301
			probeScale = levelRuntime(index).probeVisualRadius, -- 307
			spherePath = "Assets/Model/Sphere.gltf", -- 308
			ringPath = "Assets/Model/Ring.gltf", -- 309
			probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 310
			probeBodyPath = rtg and "Assets/Model/Probe_RTG_Body.glb" or "Assets/Model/Probe_Solar_Body.glb", -- 317
			probeAntennaPath = rtg and "Assets/Model/Probe_RTG_Antenna.glb" or "Assets/Model/Probe_Solar_Antenna.glb", -- 318
			probeAntennaPivotY = rtg and 0.6641 or 0.6495, -- 319
			probeBodyRadius = rtg and 0.871 or 1.084, -- 320
			probeAtlasPath = "Assets/Image/probe_atlas.jpg", -- 322
			orbitFlowDots = levelRuntime(index).orbitFlowDots, -- 323
			orbitRings = levelRuntime(index).orbitRings -- 326
		}) -- 326
		if scene == nil then -- 326
			print("[escape-velocity] FATAL: scene build failed for L" .. __TS__NumberToFixed(index + 1, 0)) -- 329
			return nil -- 330
		end -- 330
		local rt = levelRuntime(index) -- 333
		local camera = Camera3D() -- 334
		local rigOptions = defaultRigOptions( -- 338
			View.fieldOfView, -- 338
			View.aspectRatio, -- 338
			rt.cameraMin, -- 338
			rt.cameraMax, -- 338
			rt.tiltDeg -- 338
		) -- 338
		if def.transfer ~= nil then -- 338
			rigOptions.margin = 0.16 -- 340
			rigOptions.screenMinY = 2 * math.min(350, viewH * 0.38) / viewH - 1 -- 341
			rigOptions.screenMaxY = 1 - 2 * math.min(205, viewH * 0.23) / viewH -- 342
			rigOptions.screenBiasY = 0.14 -- 343
		end -- 343
		local rig = createCameraRig(rigOptions) -- 345
		local trailOptions = trajectoryOptions() -- 346
		if def.transfer ~= nil then -- 346
			trailOptions.tailPoints = 120 -- 349
			trailOptions.burnLength = 12 -- 350
			trailOptions.trailHeadRadius = 1.2 -- 351
			trailOptions.trailHeadAlpha = 0.45 -- 352
			trailOptions.trailR = 100 -- 353
			trailOptions.trailG = 180 -- 353
			trailOptions.trailB = 230 -- 353
		end -- 353
		local trajectory = createTrajectoryView(levelLayers[index + 1], trailOptions) -- 355
		local planOpts = defaultPlanOptions() -- 359
		planOpts.actualBodySizes = def.id == 2 -- 360
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
			def.transfer ~= nil and def.transfer.orbital ~= nil and def.transfer.orbital.region ~= nil and def.transfer.orbital.region.maxRadius + 20 or 0 -- 370
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
		local drawerTitle = def.transfer ~= nil and (("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. (index == 0 and "奔向月球" or (index == 1 and "借金星减速，飞掠水星" or "双星甩尾")) or (def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1]) -- 402
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
				onMissionCompleted = function(____, telem) -- 442
					progress = recordMissionResult( -- 443
						progress, -- 443
						index, -- 443
						def.bonusPoints ~= nil and (telem.bonusRockets or 0) or 0, -- 443
						levelTotal, -- 443
						true -- 443
					) -- 443
					saveProgress(progress) -- 444
					print("[escape-velocity] flyby completion saved L" .. __TS__NumberToFixed(index + 1, 0)) -- 445
				end, -- 442
				onBonusCollected = function(____, score, pointId) -- 447
					aim:setBonusFeedback(1) -- 448
					if game:missionCompleted() then -- 448
						progress = recordMissionResult( -- 450
							progress, -- 450
							index, -- 450
							score, -- 450
							levelTotal, -- 450
							true -- 450
						) -- 450
						saveProgress(progress) -- 451
					end -- 451
					print((("[escape-velocity] bonus +" .. __TS__NumberToFixed(score, 0)) .. " id=") .. pointId) -- 453
				end, -- 447
				onResult = function(____, r, telemetry) -- 455
					local telem = telemetry ~= nil and telemetry or ({burnDv = 0, flightTime = 0, closestDist = 0, maxSpeed = 0}) -- 456
					local evalInfo = evaluateRocketsDetailed(def, r, telem.burnDv, {closestDist = telem.closestDist, maxSpeed = telem.maxSpeed, eccentricity = telem.eccentricity, starsCollected = telem.starsCollected ~= nil and telem.starsCollected or 0}) -- 462
					local score = def.bonusPoints ~= nil and (r == "success" and (telem.bonusRockets or 0) or 0) or evalInfo.rockets -- 468
					if def.bonusPoints ~= nil then -- 468
						evalInfo.rockets = score -- 470
						evalInfo.achieved = {r == "success", score > 0, score >= (#def.bonusPoints or 1)} -- 471
					end -- 471
					if r == "success" then -- 471
						progress = recordMissionResult( -- 476
							progress, -- 476
							index, -- 476
							score, -- 476
							levelTotal, -- 476
							true -- 476
						) -- 476
						saveProgress(progress) -- 477
					end -- 477
					local currentTotal = getTotalRockets(progress, levelTotal) -- 479
					print(((((((((("[escape-velocity] result = " .. r) .. " on ") .. levelNames[index + 1]) .. " rockets=") .. __TS__NumberToFixed(evalInfo.rockets, 0)) .. " (total=") .. __TS__NumberToFixed(currentTotal, 0)) .. "/") .. __TS__NumberToFixed(totalBonusPoints, 0)) .. ")") -- 481
					resultIndex = index -- 485
					local challengesList = {} -- 487
					if def.bonusPoints == nil and def.mission ~= nil then -- 487
						do -- 487
							local k = 0 -- 489
							while k < #def.mission.challenges do -- 489
								challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 490
								k = k + 1 -- 489
							end -- 489
						end -- 489
					end -- 489
					local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(index + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or levelNames[index + 1] -- 494
					local detailParams = { -- 498
						result = r, -- 499
						levelName = titleWithSub, -- 500
						levelIndex = index, -- 501
						rocketsGot = evalInfo.rockets, -- 502
						challenges = challengesList, -- 503
						completionOnly = def.bonusPoints == nil, -- 504
						bonusPointCount = def.bonusPoints ~= nil and #def.bonusPoints or nil, -- 505
						achieved = evalInfo.achieved, -- 506
						burnDv = telem.burnDv, -- 507
						dvBudget = def.dvBudget, -- 508
						flightTime = telem.flightTime, -- 509
						totalRockets = currentTotal, -- 510
						totalPossibleRockets = totalBonusPoints -- 511
					} -- 511
					if resultPanel ~= nil then -- 511
						resultPanel:show(r, titleWithSub, detailParams) -- 515
					end -- 515
				end, -- 455
				onFinale = function(____, info) -- 519
					finaleText = { -- 520
						main = FinaleMainText, -- 520
						sub = finaleSubtitle(info.distance, info.time) -- 520
					} -- 520
					print((((("[escape-velocity] finale: dist=" .. __TS__NumberToFixed(info.distance, 0)) .. " time=") .. __TS__NumberToFixed(info.time, 1)) .. " tWorld=") .. __TS__NumberToFixed(info.tWorld, 0)) -- 521
				end, -- 519
				finale = index == levelTotal - 1 and def.transfer == nil -- 526
			} -- 526
		) -- 526
		aim:onQuickRetry(function() -- 529
			print(("[escape-velocity] quick retry tapped (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 530
			game:retry() -- 531
		end) -- 529
		aim:onDrag(function(a) -- 537
			game:onAimDrag(a) -- 538
			aim:setBurnInfo( -- 540
				math.sqrt(a.velocity.x * a.velocity.x + a.velocity.y * a.velocity.y), -- 540
				def.dvBudget -- 540
			) -- 540
		end) -- 537
		aim:onAimReady(function(a) -- 543
			game:onAimDrag(a) -- 544
			game:aimReady() -- 545
			print("[escape-velocity] aim ready -> Armed") -- 546
		end) -- 543
		aim:onLaunch(function() -- 548
			print("[escape-velocity] launch button tap") -- 549
			game:launchArmed() -- 550
		end) -- 548
		aim:onCancelAim(function() -- 552
			print("[escape-velocity] cancel aim tap") -- 553
			game:cancelAim() -- 554
		end) -- 552
		aim:onObserve(function(dx, dy) -- 557
			game:observeDrag(dx, dy) -- 558
		end) -- 557
		aim:onZoom(function(deltaDist) -- 560
			game:observeZoom(deltaDist) -- 561
		end) -- 560
		aim:onSkipTour(function() -- 563
			print(("[escape-velocity] tap to skip tour (L" .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 564
			game:skipIntroTour() -- 565
		end) -- 563
		aim:setTourActiveChecker(function() return game:isIntroTourActive() end) -- 567
		aim:onViewToggle(function() -- 569
			game:toggleViewMode() -- 570
			print(((("[escape-velocity] view toggle -> " .. game:viewMode()) .. " (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 571
		end) -- 569
		if aim.onCameraFocus ~= nil then -- 569
			aim:onCameraFocus(function() -- 573
				game:cycleCameraFocus() -- 573
			end) -- 573
		end -- 573
		if aim.onEndViewing ~= nil then -- 573
			aim:onEndViewing(function() -- 574
				game:endViewing() -- 574
			end) -- 574
		end -- 574
		aim:onSpeedUp(function() -- 578
			game:speedUp() -- 579
		end) -- 578
		aim:onSpeedDown(function() -- 581
			game:speedDown() -- 582
		end) -- 581
		aim:onTogglePause(function() -- 584
			game:togglePause() -- 585
		end) -- 584
		aim:onPlayback(function(speed) -- 587
			game:setPlaybackSpeed(speed) -- 588
			print(((("[escape-velocity] playback speed -> " .. __TS__NumberToFixed(speed, 0)) .. "x (L") .. __TS__NumberToFixed(index + 1, 0)) .. ")") -- 589
		end) -- 587
		aim:setPlayback(game:playbackSpeed()) -- 591
		local runtime = { -- 593
			index = index, -- 594
			name = levelNames[index + 1], -- 595
			world = world, -- 596
			camera = camera, -- 597
			game = game, -- 598
			aim = aim, -- 599
			trajectory = trajectory, -- 600
			plan = plan, -- 601
			levelHasTimeWindow = def.timeWindow ~= nil, -- 602
			dvBudget = def.dvBudget, -- 603
			dateSpan = dateSpan -- 604
		} -- 604
		slot.built = true -- 606
		slot.runtime = runtime -- 607
		print((("[escape-velocity] built L" .. __TS__NumberToFixed(index + 1, 0)) .. " ") .. levelNames[index + 1]) -- 608
		return runtime -- 609
	end -- 255
	--- 选关：隐藏选择界面 → 激活该关 → 回到 Aiming。
	local function enterLevel(index) -- 613
		local runtime = ensureLevel(index) -- 614
		if runtime == nil then -- 614
			return -- 615
		end -- 615
		local wasActive = activeIndex == index -- 618
		if opening ~= nil then -- 618
			opening.hide() -- 620
		end -- 620
		if select ~= nil then -- 620
			select:hide() -- 621
		end -- 621
		if solarHub ~= nil then -- 621
			solarHub.hide() -- 622
		end -- 622
		activeIndex = index -- 623
		showOnlyLevel(index) -- 624
		applyClipPlanes(index) -- 626
		if not wasActive then -- 626
			Director:pushCamera(runtime.camera) -- 627
		end -- 627
		runtime.game:startLevel() -- 628
		print("[escape-velocity] enter " .. runtime.name) -- 629
	end -- 613
	--- 结算面板那一关的运行时（面板显示的 index；越界就退回当前关）。
	local function resultRuntime() -- 633
		if resultIndex >= 0 and resultIndex < levelTotal then -- 633
			local rt = slots[resultIndex + 1].runtime -- 635
			if rt ~= nil then -- 635
				return rt -- 636
			end -- 636
		end -- 636
		return activeRuntime() -- 638
	end -- 633
	local function onRetryTap() -- 641
		local rt = resultRuntime() -- 643
		print(((("[escape-velocity] tap: retry (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 644
		if resultPanel ~= nil then -- 644
			resultPanel:hide() -- 645
		end -- 645
		if rt ~= nil then -- 645
			rt.game:retry() -- 646
		end -- 646
	end -- 641
	local function ensureSolarHub() -- 649
		if solarHub ~= nil then -- 649
			return solarHub -- 650
		end -- 650
		solarHub = createSolarHub({ -- 651
			root = hubRoot, -- 652
			camera = hubCamera, -- 653
			layer = hubLayer, -- 654
			viewW = viewW, -- 655
			viewH = viewH, -- 656
			fovYDeg = View.fieldOfView, -- 657
			aspect = View.aspectRatio, -- 658
			spherePath = "Assets/Model/Sphere.gltf", -- 659
			onLaunch = function(____, levelIndex) -- 660
				print("[escape-velocity] solarHub launch: L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 661
				if solarHub ~= nil then -- 661
					solarHub.hide() -- 662
				end -- 662
				enterLevel(levelIndex) -- 663
			end, -- 660
			onReplayIntro = function() -- 665
				if solarHub ~= nil then -- 665
					solarHub.hide() -- 666
				end -- 666
				startOpening() -- 667
				print("[escape-velocity] opening replay from solarHub") -- 668
			end -- 665
		}) -- 665
		return solarHub -- 671
	end -- 649
	local function onBackToSelectTap() -- 674
		local rt = resultRuntime() -- 675
		print(((("[escape-velocity] tap: back-to-select (resultIndex=" .. __TS__NumberToFixed(resultIndex, 0)) .. " phase=") .. (rt ~= nil and rt.game:phase() or "none")) .. ")") -- 676
		if rt == nil then -- 676
			return -- 677
		end -- 677
		local runtime = rt -- 678
		if not runtime.game:backToSelect() then -- 678
			return -- 680
		end -- 680
		runtime.world.visible = false -- 681
		runtime.aim:setEnabled(false) -- 682
		if resultPanel ~= nil then -- 682
			resultPanel:hide() -- 683
		end -- 683
		if finalePanel ~= nil then -- 683
			finalePanel:hide() -- 685
		end -- 685
		if select ~= nil then -- 685
			select:hide() -- 686
		end -- 686
		progress = loadProgress(levelTotal) -- 688
		local hub = ensureSolarHub() -- 689
		useCamera(hubCamera, -1) -- 690
		hub.show(progress) -- 691
		print("[escape-velocity] back to solarHub: total rockets=" .. __TS__NumberToFixed( -- 692
			getTotalRockets(progress, levelTotal), -- 692
			0 -- 692
		)) -- 692
	end -- 674
	--- 建（或重建）UI 面板。
	-- 
	-- 面板几何全部按 viewW/viewH 推导，所以**视口尺寸一变就必须重建** ——
	-- 真机（手机浏览器）实测：Web 版画布在启动后还会变一次，旧代码只在启动时读一次 View.size，
	-- 结果「预测线跑到别的地方」「竖屏没适配」。见下面的 relayoutForViewport。
	-- 
	-- ⚠️ 必须包一层箭头函数：直接把局部函数赋给“成员函数式”的属性会触发
	-- TS100016（无 this 的函数不能转成带 this 的成员），手册 §5.7 第 4 条
	local function buildPanels() -- 705
		finalePanel = createFinalePanel( -- 708
			uiLayer, -- 708
			viewW, -- 708
			viewH, -- 708
			{onBackToSelect = function() return onBackToSelectTap() end} -- 708
		) -- 708
		resultPanel = createResultPanel( -- 711
			uiLayer, -- 711
			viewW, -- 711
			viewH, -- 711
			{ -- 711
				onRetry = function() return onRetryTap() end, -- 712
				onBackToSelect = function() return onBackToSelectTap() end -- 713
			} -- 713
		) -- 713
		activeResultPanel = resultPanel -- 715
		local created = createLevelSelect( -- 716
			uiLayer, -- 716
			viewW, -- 716
			viewH, -- 716
			{ -- 716
				levels = levelEntries, -- 717
				onPick = function(____, index) -- 718
					print("[escape-velocity] tap: pick L" .. __TS__NumberToFixed(index + 1, 0)) -- 719
					if select ~= nil then -- 719
						select:hide() -- 720
					end -- 720
					enterLevel(index) -- 721
				end, -- 718
				onReplayIntro = function() -- 724
					if select ~= nil then -- 724
						select:hide() -- 725
					end -- 725
					startOpening() -- 726
					print("[escape-velocity] opening replay (user)") -- 727
				end -- 724
			} -- 724
		) -- 724
		select = created -- 730
		return created -- 731
	end -- 705
	--- 视口尺寸变化时的整体重建。
	-- 
	-- 为什么必须重建：2D 节点的子坐标原点是「位置 − anchor × 尺寸」（本轮已两次踩到），
	-- 所以容器（uiLayer / levelLayers）的尺寸**直接决定**子节点坐标系的原点与新区域覆盖。
	-- 尺寸变了却沿用旧几何 ⇒ 整体错位（预测线偏移）+ 新区域收不到触摸（没适配）。
	-- 
	-- 旧的层与关卡运行时只**隐藏 + 断触摸**，不销毁（避免依赖不确定的销毁 API）；
	-- 关卡运行时按需重建（slots 标记为未建）。
	local function relayoutForViewport() -- 744
		local w = View.size.width -- 745
		local h = View.size.height -- 746
		if w == viewW and h == viewH then -- 746
			return -- 747
		end -- 747
		if opening ~= nil then -- 747
			opening.hide() -- 753
			opening = nil -- 754
		end -- 754
		if select ~= nil then -- 754
			select:hide() -- 756
		end -- 756
		if resultPanel ~= nil then -- 756
			resultPanel:hide() -- 757
		end -- 757
		if finalePanel ~= nil then -- 757
			finalePanel:hide() -- 758
		end -- 758
		do -- 758
			local i = 0 -- 759
			while i < levelTotal do -- 759
				local slot = slots[i + 1] -- 760
				if slot.runtime ~= nil then -- 760
					slot.runtime.world.visible = false -- 762
					slot.runtime.aim:setEnabled(false) -- 763
					slot.runtime.trajectory:clearPrediction() -- 766
					slot.runtime.trajectory:clearTrail() -- 767
					slot.runtime.trajectory:clearGoalRings() -- 769
					slot.runtime.plan:setVisible(false) -- 772
					slot.runtime.plan:clear() -- 773
				end -- 773
				slot.built = false -- 775
				slot.runtime = nil -- 776
				i = i + 1 -- 759
			end -- 759
		end -- 759
		viewW = w -- 780
		viewH = h -- 781
		uiLayer.size = Size(viewW, viewH) -- 782
		openingLayer.size = Size(viewW, viewH) -- 783
		hubLayer.size = Size(viewW, viewH) -- 784
		do -- 784
			local i = 0 -- 785
			while i < levelTotal do -- 785
				levelLayers[i + 1].size = Size(viewW, viewH) -- 785
				i = i + 1 -- 785
			end -- 785
		end -- 785
		if solarHub ~= nil then -- 785
			solarHub.relayout(viewW, viewH) -- 787
		end -- 787
		buildPanels() -- 791
		if activeIndex >= 0 then -- 791
			local keep = activeIndex -- 793
			activeIndex = -1 -- 794
			enterLevel(keep) -- 795
		else -- 795
			local hub = ensureSolarHub() -- 797
			useCamera(hubCamera, -1) -- 798
			hub.show(progress) -- 799
		end -- 799
		print((("[escape-velocity] viewport rebuilt: " .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) -- 801
	end -- 744
	Director.entry:onAppChange(function(name) -- 805
		if name == "Size" then -- 805
			relayoutForViewport() -- 806
		end -- 806
	end) -- 805
	local introSeen = loadIntroSeen() -- 814
	local forceIntro = false -- 815
	opening = nil -- 816
	startOpening = function() -- 818
		if opening == nil then -- 818
			opening = createOpening({ -- 820
				root = openingRoot, -- 821
				camera = openingCamera, -- 822
				layer = openingLayer, -- 823
				viewW = viewW, -- 824
				viewH = viewH, -- 825
				fovYDeg = View.fieldOfView, -- 826
				aspect = View.aspectRatio, -- 827
				spherePath = "Assets/Model/Sphere.gltf", -- 828
				probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 829
				probeBodyPath = "Assets/Model/Probe_Body.glb", -- 830
				probeAntennaPath = "Assets/Model/Probe_Antenna.glb", -- 831
				onFinish = function() -- 832
					introHold = -1 -- 833
					if not introSeen then -- 833
						saveIntroSeen() -- 835
						introSeen = true -- 836
						print("[escape-velocity] intro seen -> saved") -- 837
					end -- 837
					if opening ~= nil then -- 837
						opening.hide() -- 840
					end -- 840
					if select ~= nil then -- 840
						select:hide() -- 841
					end -- 841
					local hub = ensureSolarHub() -- 842
					useCamera(hubCamera, -1) -- 843
					hub.show(progress) -- 844
					print("[escape-velocity] opening finished -> show solarHub: frame=" .. (opening ~= nil and __TS__NumberToFixed( -- 845
						opening.frameIndex(), -- 845
						0 -- 845
					) or "?")) -- 845
				end -- 832
			}) -- 832
		end -- 832
		if opening == nil then -- 832
			return -- 849
		end -- 849
		useCamera(openingCamera, -1) -- 850
		opening.start() -- 851
		print("[escape-velocity] opening start (first launch)") -- 852
	end -- 818
	local startupPanel = buildPanels() -- 855
	local enterReq = Path( -- 867
		Path(".", ".agent", "test-results"), -- 867
		"enter-request.txt" -- 867
	) -- 867
	local autoLaunchAt = -1 -- 868
	--- "N@arm:<frames>"：自动进 Armed 的帧号（-1 = 不自动）。
	local autoArmAt = -1 -- 870
	local autoFrame = 0 -- 871
	local autoVX = 0 -- 872
	local autoVY = 0 -- 873
	--- "N@frames:vx:vy:steps"：自动发射**之前**先按 steps 次「加速 ▶」（每次 TimeWarpStep 秒）。
	-- 为什么需要它：L4/L6 的可行解在**特定发射日期**上（L6 在 t0 = 180），而
	-- `game.launch()` 只认 core.t0 —— 不先把世界时钟拨过去，发出去的就是第 0 天的航线。
	-- 走的是 `Game.stepTime`（玩家按时间流按钮的同一条公开路径，含相态守卫与 span 夹紧），
	-- 不是直接写 core.t0 ⇒ 与真机操作等价。0 / 缺省 = 不拨（旧行为不变）。
	local autoWarpSteps = 0 -- 881
	local autoBackAt = -1 -- 883
	local autoReenterAt = -1 -- 884
	local autoEntered = false -- 885
	introHold = -1 -- 887
	if Content:exist(enterReq) then -- 887
		local spec = Content:load(enterReq) -- 889
		local at = (string.find(spec, "@", nil, true) or 0) - 1 -- 890
		local head = __TS__StringTrim(at < 0 and spec or __TS__StringSubstring(spec, 0, at)) -- 891
		if head == "intro" then -- 891
			forceIntro = true -- 893
			if at >= 0 then -- 893
				local rest = __TS__StringSubstring(spec, at + 1) -- 895
				local colon = (string.find(rest, ":", nil, true) or 0) - 1 -- 896
				if colon > 0 and __TS__StringTrim(__TS__StringSubstring(rest, 0, colon)) == "hold" then -- 896
					local v = tonumber(__TS__StringSubstring(rest, colon + 1)) -- 898
					if v ~= nil and v >= 0 then -- 898
						introHold = v -- 900
						print("[escape-velocity] opening hold at frame " .. __TS__NumberToFixed(v, 0)) -- 901
					end -- 901
				end -- 901
			end -- 901
		end -- 901
		local n = tonumber(head) -- 906
		if n ~= nil and n >= 1 and n <= levelTotal then -- 906
			print(("[escape-velocity] auto enter L" .. __TS__NumberToFixed(n, 0)) .. " (enter-request)") -- 908
			enterLevel(n - 1) -- 909
			autoEntered = true -- 910
			if at >= 0 then -- 910
				local rest = __TS__StringSubstring(spec, at + 1) -- 912
				if __TS__StringSubstring(rest, 0, 4) == "arm:" then -- 912
					local f = tonumber(__TS__StringSubstring(rest, 4)) -- 917
					if f ~= nil and f >= 0 then -- 917
						autoArmAt = f -- 919
						print("[escape-velocity] auto arm scheduled: frame " .. __TS__NumberToFixed(f, 0)) -- 920
					end -- 920
				else -- 920
					local c1 = (string.find(rest, ":", nil, true) or 0) - 1 -- 923
					local c2 = (string.find( -- 924
						rest, -- 924
						":", -- 924
						math.max(c1 + 1 + 1, 1), -- 924
						true -- 924
					) or 0) - 1 -- 924
					if c1 > 0 and c2 > c1 then -- 924
						local frames = tonumber(__TS__StringSubstring(rest, 0, c1)) -- 926
						local vx = tonumber(__TS__StringSubstring(rest, c1 + 1, c2)) -- 927
						local tail = __TS__StringSubstring(rest, c2 + 1) -- 930
						local c3 = (string.find(tail, ":", nil, true) or 0) - 1 -- 931
						local vyText = c3 > 0 and __TS__StringSubstring(tail, 0, c3) or tail -- 932
						local vy = tonumber(vyText) -- 933
						local ____temp_4 -- 934
						if c3 > 0 then -- 934
							____temp_4 = tonumber(__TS__StringSubstring(tail, c3 + 1)) -- 934
						else -- 934
							____temp_4 = nil -- 934
						end -- 934
						local steps = ____temp_4 -- 934
						if frames ~= nil and vx ~= nil and vy ~= nil then -- 934
							autoLaunchAt = frames -- 936
							autoVX = vx -- 937
							autoVY = vy -- 938
							if steps ~= nil and steps > 0 then -- 938
								autoWarpSteps = math.floor(steps) -- 940
							end -- 940
							print(((((((("[escape-velocity] auto launch scheduled: frame " .. __TS__NumberToFixed(frames, 0)) .. " v=(") .. __TS__NumberToFixed(vx, 1)) .. ",") .. __TS__NumberToFixed(vy, 1)) .. ")") .. " warpSteps=") .. __TS__NumberToFixed(autoWarpSteps, 0)) -- 942
						end -- 942
					end -- 942
				end -- 942
			end -- 942
		end -- 942
	end -- 942
	if autoEntered then -- 942
		print("[escape-velocity] opening skipped (auto enter)") -- 955
	elseif forceIntro or not introSeen then -- 955
		startOpening() -- 957
	else -- 957
		local hub = ensureSolarHub() -- 959
		useCamera(hubCamera, -1) -- 960
		hub.show(progress) -- 961
		print("[escape-velocity] entered solarHub (already seen)") -- 962
	end -- 962
	threadLoop(function() -- 967
		advanceUiClock(App.deltaTime) -- 971
		if solarHub ~= nil and solarHub.visible() then -- 971
			solarHub.step(App.deltaTime) -- 975
		end -- 975
		if opening ~= nil and opening.running() then -- 975
			if introHold < 0 or opening.frameIndex() < introHold then -- 975
				opening.step() -- 981
			end -- 981
			if App.deltaTime > 0.05 then -- 981
				print((("[escape-velocity] hitch " .. __TS__NumberToFixed(App.deltaTime * 1000, 0)) .. "ms @ opening frame ") .. __TS__NumberToFixed( -- 985
					opening.frameIndex(), -- 985
					0 -- 985
				)) -- 985
			end -- 985
		end -- 985
		local runtime = activeRuntime() -- 989
		if runtime ~= nil then -- 989
			runtime.game:update(App.deltaTime) -- 991
			runtime.aim:setBurnInfo( -- 993
				runtime.game:burnNow(), -- 993
				runtime.dvBudget -- 993
			) -- 993
			if runtime.levelHasTimeWindow then -- 993
				runtime.aim:setDate( -- 996
					runtime.game:dateNow(), -- 996
					runtime.dateSpan -- 996
				) -- 996
			end -- 996
			local phaseNow = runtime.game:phase() -- 1000
			runtime.aim:setTimeEnabled(phaseNow == "Aiming" or phaseNow == "Armed") -- 1001
			runtime.aim:update(App.deltaTime) -- 1002
			runtime.aim:setArmed(runtime.game:armed()) -- 1004
			runtime.aim:setStarsStatus(runtime.game:starsNow()) -- 1005
			runtime.aim:setBonusStatus( -- 1006
				runtime.game:bonusScore(), -- 1006
				runtime.game:bonusTotal() -- 1006
			) -- 1006
			local is2D = runtime.game:viewMode() == "2D" -- 1008
			runtime.aim:setViewMode(runtime.game:viewMode()) -- 1009
			if runtime.aim.setFlightViewing ~= nil then -- 1009
				runtime.aim:setFlightViewing( -- 1010
					phaseNow == "Flying", -- 1010
					runtime.game:missionCompleted(), -- 1010
					runtime.game:cameraFocus(), -- 1010
					not is2D, -- 1010
					runtime.game:flightStage() -- 1010
				) -- 1010
			end -- 1010
			local inAim = (phaseNow == "Aiming" or phaseNow == "Armed") and not runtime.game:isIntroTourActive() -- 1011
			runtime.aim:setZoomControlsVisible(is2D and inAim) -- 1012
			runtime.aim:setMissionDrawerVisible(inAim) -- 1013
			local curBurn = runtime.game:burnNow() -- 1015
			local fuelLimit = runtime.dvBudget * 0.75 -- 1016
			runtime.aim:setLiveFuelChallengeStatus(curBurn <= fuelLimit and curBurn >= 0.001) -- 1017
			runtime.aim:setTimeControl( -- 1020
				runtime.game:speedPow(), -- 1021
				runtime.game:speedMaxPow(), -- 1022
				runtime.game:isPaused(), -- 1023
				runtime.game:missionSeconds(), -- 1024
				runtime.game:speedRate() -- 1025
			) -- 1025
			if autoLaunchAt >= 0 or autoBackAt >= 0 or autoReenterAt >= 0 or autoArmAt >= 0 then -- 1025
				autoFrame = autoFrame + 1 -- 1029
				if autoArmAt >= 0 and autoFrame >= autoArmAt then -- 1029
					autoArmAt = -1 -- 1032
					print("[escape-velocity] auto arm (enter-request)") -- 1033
					runtime.game:aimReady() -- 1034
				end -- 1034
				if autoLaunchAt >= 0 and autoFrame >= autoLaunchAt then -- 1034
					autoLaunchAt = -1 -- 1037
					print("[escape-velocity] auto launch") -- 1038
					if autoWarpSteps > 0 then -- 1038
						do -- 1038
							local s = 0 -- 1042
							while s < autoWarpSteps do -- 1042
								runtime.game:stepTime(1, runtime.dateSpan) -- 1042
								s = s + 1 -- 1042
							end -- 1042
						end -- 1042
						autoWarpSteps = 0 -- 1043
						print(("[escape-velocity] auto warp done (date=" .. __TS__NumberToFixed( -- 1044
							runtime.game:dateNow(), -- 1044
							0 -- 1044
						)) .. ")") -- 1044
					end -- 1044
					print(((("[escape-velocity] auto launch burn=(" .. __TS__NumberToFixed(autoVX, 5)) .. ",") .. __TS__NumberToFixed(autoVY, 5)) .. ")") -- 1046
					runtime.game:launch({x = autoVX, y = autoVY}) -- 1047
					autoBackAt = autoFrame + 320 -- 1048
					autoReenterAt = autoFrame + 380 -- 1049
				end -- 1049
				if autoBackAt >= 0 and autoFrame >= autoBackAt then -- 1049
					autoBackAt = -1 -- 1053
					if runtime.game:backToSelect() then -- 1053
						print("[escape-velocity] auto back to select") -- 1054
					end -- 1054
				end -- 1054
				if autoReenterAt >= 0 and autoFrame >= autoReenterAt then -- 1054
					autoReenterAt = -1 -- 1057
					print("[escape-velocity] auto re-enter") -- 1058
					enterLevel(0) -- 1059
				end -- 1059
			end -- 1059
		end -- 1059
		return false -- 1064
	end) -- 967
	print((((((((((("[escape-velocity] started: " .. __TS__NumberToFixed(levelTotal, 0)) .. " levels, unlocked=") .. __TS__NumberToFixed(progress.unlocked, 0)) .. ", view=") .. __TS__NumberToFixed(viewW, 0)) .. "x") .. __TS__NumberToFixed(viewH, 0)) .. ", platform=") .. App.platform) .. ", introSeen=") .. (introSeen and "yes" or "no")) -- 1068
	debugTriggerResultFn = function(levelIndex, outcome) -- 1070
		if outcome == nil then -- 1070
			outcome = "success" -- 1070
		end -- 1070
		if solarHub ~= nil then -- 1070
			solarHub.hide() -- 1071
		end -- 1071
		if opening ~= nil then -- 1071
			opening.hide() -- 1072
		end -- 1072
		local def = getLevel(levelIndex) -- 1073
		if def == nil or resultPanel == nil then -- 1073
			return -- 1074
		end -- 1074
		local burn = def.dvBudget * 0.65 -- 1075
		local challengesList = {} -- 1076
		if def.mission ~= nil then -- 1076
			do -- 1076
				local k = 0 -- 1078
				while k < #def.mission.challenges do -- 1078
					challengesList[#challengesList + 1] = def.mission.challenges[k + 1].desc -- 1079
					k = k + 1 -- 1078
				end -- 1078
			end -- 1078
		end -- 1078
		local titleWithSub = def.mission ~= nil and (((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. def.title) .. " · ") .. def.mission.subtitle or "L" .. __TS__NumberToFixed(levelIndex + 1, 0) -- 1082
		resultPanel:show(outcome, titleWithSub, { -- 1086
			result = outcome, -- 1087
			levelName = titleWithSub, -- 1088
			levelIndex = levelIndex, -- 1089
			rocketsGot = outcome == "success" and 3 or 0, -- 1090
			challenges = challengesList, -- 1091
			achieved = outcome == "success" and ({true, true, true}) or ({false, false, false}), -- 1092
			burnDv = burn, -- 1093
			dvBudget = def.dvBudget, -- 1094
			flightTime = 12.8, -- 1095
			totalRockets = outcome == "success" and 16 or 13, -- 1096
			totalPossibleRockets = 18 -- 1097
		}) -- 1097
	end -- 1070
	debugTriggerEnterLevelFn = function(levelIndex) -- 1101
		if solarHub ~= nil then -- 1101
			solarHub.hide() -- 1102
		end -- 1102
		if opening ~= nil then -- 1102
			opening.hide() -- 1103
		end -- 1103
		enterLevel(levelIndex) -- 1104
	end -- 1101
	debugGameStateFn = function() -- 1106
		local rt = activeRuntime() -- 1107
		if rt == nil then -- 1107
			return "phase=LevelSelect" -- 1108
		end -- 1108
		local g = rt.game -- 1109
		return (((((((((((((((("phase=" .. g:phase()) .. "\ndate=") .. __TS__NumberToFixed( -- 1110
			g:dateNow(), -- 1110
			6 -- 1110
		)) .. "\nworld=") .. __TS__NumberToFixed( -- 1110
			g:missionSeconds(), -- 1110
			6 -- 1110
		)) .. "\nrate=") .. __TS__NumberToFixed( -- 1110
			g:speedRate(), -- 1111
			6 -- 1111
		)) .. "\npaused=") .. (g:isPaused() and "1" or "0")) .. "\nfocus=") .. g:cameraFocus()) .. "\ncompleted=") .. (g:missionCompleted() and "1" or "0")) .. "\nview=") .. g:viewMode()) .. "\nmarker=") .. __TS__NumberToFixed( -- 1111
			g:markerElapsed(), -- 1112
			6 -- 1112
		) -- 1112
	end -- 1106
	debugTriggerZoomInFn = function() -- 1115
		local rt = activeRuntime() -- 1116
		if rt ~= nil then -- 1116
			rt.plan:zoomIn() -- 1118
		end -- 1118
	end -- 1115
	debugTriggerResetViewFn = function() -- 1122
		local rt = activeRuntime() -- 1123
		if rt ~= nil then -- 1123
			rt.plan:resetView() -- 1125
		end -- 1125
	end -- 1122
end -- 1122
--- 获取当前处于激活状态的结算面板（调试/截图用）。
function ____exports.getActiveResultPanel() -- 1131
	return activeResultPanel -- 1132
end -- 1131
--- GameShot 专用的只读状态；输入验收据此等待实际状态，避免固定延迟猜时机。
function ____exports.getDebugGameState() -- 1136
	return debugGameStateFn ~= nil and debugGameStateFn() or "phase=Loading" -- 1137
end -- 1136
--- 触发一次指定关卡的结算卡片演出（调试/自动化截图用）。
function ____exports.triggerDebugResult(levelIndex, outcome) -- 1141
	if outcome == nil then -- 1141
		outcome = "success" -- 1141
	end -- 1141
	if debugTriggerResultFn ~= nil then -- 1141
		debugTriggerResultFn(levelIndex, outcome) -- 1143
	end -- 1143
end -- 1141
--- 触发进入关卡并启动入场 3D 运镜（调试/截图用）。
function ____exports.triggerDebugEnterLevel(levelIndex) -- 1148
	if debugTriggerEnterLevelFn ~= nil then -- 1148
		debugTriggerEnterLevelFn(levelIndex) -- 1150
	end -- 1150
end -- 1148
--- 触发 2D 规划视口放大（调试/截图用）。
function ____exports.triggerDebugZoomIn() -- 1155
	if debugTriggerZoomInFn ~= nil then -- 1155
		debugTriggerZoomInFn() -- 1157
	end -- 1157
end -- 1155
--- 触发 2D 规划视口自适应重置（调试/截图用）。
function ____exports.triggerDebugResetView() -- 1162
	if debugTriggerResetViewFn ~= nil then -- 1162
		debugTriggerResetViewFn() -- 1164
	end -- 1164
end -- 1162
return ____exports -- 1162
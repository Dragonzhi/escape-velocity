-- [ts]: SolarHub.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local currentHubInstance -- 1
local ____Dora = require("Dora") -- 12
local Color = ____Dora.Color -- 14
local Color3 = ____Dora.Color3 -- 15
local Content = ____Dora.Content -- 16
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 17
local Model3D = ____Dora.Model3D -- 19
local Node = ____Dora.Node -- 20
local PointLight3D = ____Dora.PointLight3D -- 22
local Size = ____Dora.Size -- 23
local Vec2 = ____Dora.Vec2 -- 25
local Vec3 = ____Dora.Vec3 -- 26
local ____Config = require("game.Config") -- 29
local MiniSunLightIntensity = ____Config.MiniSunLightIntensity -- 29
local SunFillIntensity = ____Config.SunFillIntensity -- 29
local ____LevelData = require("game.LevelData") -- 30
local getLevel = ____LevelData.getLevel -- 30
local levelCount = ____LevelData.levelCount -- 30
local ____Progress = require("game.Progress") -- 31
local getMissionCompleted = ____Progress.getMissionCompleted -- 31
local getMissionRockets = ____Progress.getMissionRockets -- 31
local getTotalRockets = ____Progress.getTotalRockets -- 31
local ____Scene = require("game.Scene") -- 32
local applyPlanetTexture = ____Scene.applyPlanetTexture -- 33
local createProbe = ____Scene.createProbe -- 34
local createStarBackdrop = ____Scene.createStarBackdrop -- 35
local modelRadius = ____Scene.modelRadius -- 36
local planeToWorld = ____Scene.planeToWorld -- 37
local pointAntenna = ____Scene.pointAntenna -- 38
local probeYawForVelocity = ____Scene.probeYawForVelocity -- 39
local ____Projection = require("game.Projection") -- 42
local FLIP_Y = ____Projection.FLIP_Y -- 45
local HANDEDNESS = ____Projection.HANDEDNESS -- 46
local prepareCamera = ____Projection.prepareCamera -- 47
local projectPrepared = ____Projection.projectPrepared -- 48
local toOverlay = ____Projection.toOverlay -- 49
local ____Ui = require("game.Ui") -- 51
local createButton = ____Ui.createButton -- 53
local createLabel = ____Ui.createLabel -- 54
local createPanel = ____Ui.createPanel -- 55
local setLabelCenter = ____Ui.setLabelCenter -- 56
local setLabelColor = ____Ui.setLabelColor -- 57
local setLabelText = ____Ui.setLabelText -- 58
local setLabelVisible = ____Ui.setLabelVisible -- 59
local DegToRad = math.pi / 180 -- 62
--- 太阳系沙盘中的天体排布。
____exports.HUB_STATIONS = { -- 78
	{ -- 80
		model = "Planet_Mercury", -- 80
		radius = 0.85, -- 80
		orbit = 7.5, -- 80
		baseAngleDeg = 340, -- 80
		orbitSpeedDegPerSec = 4.2, -- 80
		rotSpeedDegPerSec = 5, -- 80
		colorHex = 10129286, -- 80
		emissiveHex = 0, -- 80
		levelIndex = 1 -- 80
	}, -- 80
	{ -- 82
		model = "Planet_Venus", -- 82
		radius = 1.6, -- 82
		orbit = 11.5, -- 82
		baseAngleDeg = 300, -- 82
		orbitSpeedDegPerSec = 2.8, -- 82
		rotSpeedDegPerSec = -2, -- 82
		colorHex = 15785134, -- 82
		emissiveHex = 0 -- 82
	}, -- 82
	{ -- 84
		model = "Planet_Earth", -- 84
		radius = 2.2, -- 84
		orbit = 17, -- 84
		baseAngleDeg = 262, -- 84
		orbitSpeedDegPerSec = 1.8, -- 84
		rotSpeedDegPerSec = 15, -- 84
		colorHex = 6003680, -- 84
		emissiveHex = 0, -- 84
		levelIndex = 0 -- 84
	}, -- 84
	{ -- 86
		model = "Planet_Mars", -- 86
		radius = 1.5, -- 86
		orbit = 22.5, -- 86
		baseAngleDeg = 318, -- 86
		orbitSpeedDegPerSec = 1.3, -- 86
		rotSpeedDegPerSec = 14, -- 86
		colorHex = 13664074, -- 86
		emissiveHex = 0 -- 86
	}, -- 86
	{ -- 88
		model = "Planet_Jupiter", -- 88
		radius = 4.6, -- 88
		orbit = 30, -- 88
		baseAngleDeg = 12, -- 88
		orbitSpeedDegPerSec = 0.8, -- 88
		rotSpeedDegPerSec = 25, -- 88
		colorHex = 14729362, -- 88
		emissiveHex = 0 -- 88
	}, -- 88
	{ -- 90
		model = "Planet_Saturn", -- 90
		radius = 3.2, -- 90
		orbit = 38.5, -- 90
		baseAngleDeg = 68, -- 90
		orbitSpeedDegPerSec = 0.5, -- 90
		rotSpeedDegPerSec = 22, -- 90
		colorHex = 13878426, -- 90
		emissiveHex = 0 -- 90
	}, -- 90
	{ -- 92
		model = "Planet_Uranus", -- 92
		radius = 2, -- 92
		orbit = 47, -- 92
		baseAngleDeg = 124, -- 92
		orbitSpeedDegPerSec = 0.35, -- 92
		rotSpeedDegPerSec = 12, -- 92
		colorHex = 11066852, -- 92
		emissiveHex = 0 -- 92
	}, -- 92
	{ -- 94
		model = "Planet_Neptune", -- 94
		radius = 1.9, -- 94
		orbit = 55, -- 94
		baseAngleDeg = 180, -- 94
		orbitSpeedDegPerSec = 0.25, -- 94
		rotSpeedDegPerSec = 11, -- 94
		colorHex = 8099312, -- 94
		emissiveHex = 0, -- 94
		levelIndex = 2 -- 94
	} -- 94
} -- 94
--- 关卡索引 -> HUB_STATIONS 下标的映射（L1 地球: 2, L2 水星: 0, L3 海王星: 7）。
____exports.LEVEL_TO_STATION_INDEX = {2, 0, 7} -- 98
--- 视觉配置常量。
local SunRadius = 4.8 -- 101
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 102
local OrbitRingsHex = 4153224 -- 103
local CardBgHex = 792102 -- 105
local CardBorderHex = 3033193 -- 106
local PrimaryBtnBgHex = 1921679 -- 107
local PrimaryBtnFgHex = 16777215 -- 108
local PrimaryBtnBorderHex = 6002142 -- 109
local SecondaryBtnBgHex = 1385011 -- 110
local SecondaryBtnFgHex = 10468571 -- 111
local SecondaryBtnBorderHex = 3691898 -- 112
local PinBgHex = 859957 -- 113
local PinBorderHex = 4289190 -- 114
local GoldStarHex = 16762939 -- 115
local DimStarHex = 5663877 -- 116
local function clampNumber(value, lo, hi) -- 118
	if value < lo then -- 118
		return lo -- 119
	end -- 119
	if value > hi then -- 119
		return hi -- 120
	end -- 120
	return value -- 121
end -- 118
local function lerp(a, b, t) -- 124
	return a + (b - a) * t -- 125
end -- 124
local function lerp3(a, b, t) -- 128
	return Vec3( -- 129
		lerp(a.x, b.x, t), -- 129
		lerp(a.y, b.y, t), -- 129
		lerp(a.z, b.z, t) -- 129
	) -- 129
end -- 128
--- 格式化火箭星级字符：如 2 枚火箭显示「★ ★ ☆」
function ____exports.formatRocketsString(count) -- 133
	local c = math.max( -- 134
		0, -- 134
		math.min( -- 134
			3, -- 134
			math.floor(count) -- 134
		) -- 134
	) -- 134
	if c == 0 then -- 134
		return "☆  ☆  ☆" -- 135
	end -- 135
	if c == 1 then -- 135
		return "★  ☆  ☆" -- 136
	end -- 136
	if c == 2 then -- 136
		return "★  ★  ☆" -- 137
	end -- 137
	return "★  ★  ★" -- 138
end -- 133
--- 当前转移关按通关计数，旧存档的多枚火箭仍只代表完成了一关。
function ____exports.formatProgressSummary(progress) -- 142
	local count = levelCount() -- 143
	local completed = 0 -- 144
	local possible = 0 -- 145
	do -- 145
		local i = 0 -- 146
		while i < count do -- 146
			if getMissionCompleted(progress, i) then -- 146
				completed = completed + 1 -- 146
			end -- 146
			local ____opt_2 = getLevel(i) -- 146
			local ____opt_0 = ____opt_2 and ____opt_2.bonusPoints -- 146
			possible = possible + (____opt_0 and #____opt_0 or 0) -- 146
			i = i + 1 -- 146
		end -- 146
	end -- 146
	return (((((("已完成 " .. __TS__NumberToFixed(completed, 0)) .. " / ") .. __TS__NumberToFixed(count, 0)) .. " · 火箭 ") .. __TS__NumberToFixed( -- 147
		getTotalRockets(progress, count), -- 147
		0 -- 147
	)) .. " / ") .. __TS__NumberToFixed(possible, 0) -- 147
end -- 142
--- 创建微缩 3D 太阳系选关中心。
function ____exports.createSolarHub(options) -- 180
	local focusMission, backToPanorama, currentProgress -- 180
	local viewW = options.viewW -- 181
	local viewH = options.viewH -- 182
	local root = options.root -- 183
	local camera = options.camera -- 184
	local layer = options.layer -- 185
	local ui = Node() -- 188
	ui.size = Size(viewW, viewH) -- 189
	ui.anchor = Vec2(0, 0) -- 190
	ui.position = Vec2(0, 0) -- 191
	layer:addChild(ui) -- 192
	local sunLight = PointLight3D() -- 195
	sunLight.color = Color3(16774106) -- 196
	sunLight.intensity = MiniSunLightIntensity -- 197
	sunLight.range = 700 -- 198
	sunLight.position = Vec3(0, 0, 0) -- 199
	root:addChild(sunLight) -- 200
	local fillLight = DirectionalLight3D() -- 202
	fillLight.color = Color3(12243691) -- 203
	fillLight.intensity = SunFillIntensity -- 204
	fillLight.angleX = -38 -- 205
	fillLight.angleY = 65 -- 206
	root:addChild(fillLight) -- 207
	local backdrop = createStarBackdrop(root) -- 209
	local sun = Model3D("Assets/Model/Sun.glb") -- 212
	if sun ~= nil then -- 212
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 214
		applyPlanetTexture(sun, "Sun", 0, 0) -- 215
		root:addChild(sun) -- 216
	end -- 216
	if Content:exist(OrbitRingsPath) then -- 216
		local rings = Model3D(OrbitRingsPath) -- 221
		if rings ~= nil then -- 221
			local rm = rings:getMaterial(0) -- 223
			if rm ~= nil then -- 223
				rm.baseColor = Color(0, 0, 0, 255) -- 225
				rm.emissive = Color3(OrbitRingsHex) -- 226
			end -- 226
			root:addChild(rings) -- 228
		end -- 228
	end -- 228
	local planets = {} -- 239
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 240
	do -- 240
		local i = 0 -- 242
		while i < #____exports.HUB_STATIONS do -- 242
			local st = ____exports.HUB_STATIONS[i + 1] -- 243
			local modelPath = st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb" -- 244
			local model = Model3D(modelPath) -- 245
			if model ~= nil then -- 245
				local scale = st.radius / modelRadius(st.model) -- 247
				model.scale = Vec3(scale, scale, scale) -- 248
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 249
				root:addChild(model) -- 250
				local a = st.baseAngleDeg * DegToRad -- 251
				local pos = { -- 252
					x = math.cos(a) * st.orbit, -- 252
					y = math.sin(a) * st.orbit -- 252
				} -- 252
				model.position = planeToWorld(pos, 0) -- 253
				planets[#planets + 1] = {station = st, node = model, currentAngleDeg = st.baseAngleDeg, currentPos = pos} -- 254
			end -- 254
			i = i + 1 -- 242
		end -- 242
	end -- 242
	local probeHandle = nil -- 264
	probeHandle = createProbe(root, { -- 265
		scale = 0.95, -- 266
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 267
		bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 268
		antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 269
		antennaPivotY = 0.6495, -- 270
		bodyRadius = 1.084, -- 271
		atlasPath = "Assets/Image/probe_atlas.jpg" -- 272
	}) -- 272
	local camMode = "panorama" -- 276
	local focusLevelIndex = -1 -- 277
	local panoYawDeg = 24 -- 280
	local panoPitchDeg = 36 -- 281
	local PanoDist = 230 -- 282
	local curEye = Vec3(0, 130, 190) -- 285
	local curTarget = Vec3(0, 0, 0) -- 286
	local targetEye = Vec3(0, 130, 190) -- 287
	local targetTarget = Vec3(0, 0, 0) -- 288
	--- 计算全景模式下的相机机位。
	local function calcPanoEye() -- 291
		local pitchRad = panoPitchDeg * DegToRad -- 292
		local yawRad = panoYawDeg * DegToRad -- 293
		local rHorizontal = PanoDist * math.cos(pitchRad) -- 294
		local y = PanoDist * math.sin(pitchRad) -- 295
		local x = rHorizontal * math.sin(yawRad) -- 296
		local z = rHorizontal * math.cos(yawRad) -- 297
		return Vec3(x, y, z) -- 298
	end -- 291
	--- 计算特写模式下的相机机位。
	local function calcFocusPose(stIndex) -- 302
		if stIndex == -1 then -- 302
			local dist = 22 -- 305
			return { -- 306
				eye = Vec3(0, dist * 0.42, dist * 0.9), -- 306
				target = Vec3(0, 0, 0) -- 306
			} -- 306
		end -- 306
		local h = planets[stIndex + 1] -- 308
		if h == nil then -- 308
			return { -- 309
				eye = calcPanoEye(), -- 309
				target = Vec3(0, 0, 0) -- 309
			} -- 309
		end -- 309
		local p = h.currentPos -- 310
		local t = planeToWorld(p, 0) -- 311
		local planetRadius = h.station.radius -- 312
		local dist = math.max(14, planetRadius * 4.2) -- 313
		local offsetAngle = (h.currentAngleDeg + 45) * DegToRad -- 314
		local eyeX = t.x + math.cos(offsetAngle) * dist * 0.85 -- 315
		local eyeY = t.y + dist * 0.55 -- 316
		local eyeZ = t.z + math.sin(offsetAngle) * dist * 0.85 -- 317
		return { -- 318
			eye = Vec3(eyeX, eyeY, eyeZ), -- 318
			target = t -- 318
		} -- 318
	end -- 302
	local gestureLayer = Node() -- 322
	gestureLayer.size = Size(viewW, viewH) -- 323
	gestureLayer.anchor = Vec2(0, 0) -- 324
	gestureLayer.position = Vec2(0, 0) -- 325
	gestureLayer.touchEnabled = false -- 326
	ui:addChild(gestureLayer) -- 327
	local isDragging = false -- 329
	local lastTouchPos = Vec2(0, 0) -- 330
	gestureLayer:onTapBegan(function(touch) -- 332
		isDragging = true -- 333
		lastTouchPos = touch.location -- 334
		return true -- 335
	end) -- 332
	gestureLayer:onTapMoved(function(touch) -- 338
		if not isDragging then -- 338
			return -- 339
		end -- 339
		local loc = touch.location -- 340
		local dx = loc.x - lastTouchPos.x -- 341
		local dy = loc.y - lastTouchPos.y -- 342
		lastTouchPos = loc -- 343
		if camMode == "panorama" then -- 343
			panoYawDeg = panoYawDeg - dx * 0.22 -- 346
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75) -- 347
			targetEye = calcPanoEye() -- 348
		end -- 348
	end) -- 338
	gestureLayer:onTapEnded(function() -- 352
		isDragging = false -- 353
	end) -- 352
	local pins = {} -- 365
	local PinW = 138 -- 367
	local PinH = 50 -- 368
	do -- 368
		local i = 0 -- 370
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 370
			local lvIndex = i -- 371
			local stIndex = ____exports.LEVEL_TO_STATION_INDEX[lvIndex + 1] -- 372
			local def = getLevel(lvIndex) -- 373
			local title = def ~= nil and def.title or "" -- 374
			local pinRoot = Node() -- 376
			pinRoot.size = Size(PinW, PinH) -- 377
			pinRoot.anchor = Vec2(0, 0) -- 378
			ui:addChild(pinRoot) -- 379
			local btn = createButton( -- 381
				pinRoot, -- 381
				{ -- 381
					w = PinW, -- 382
					h = PinH, -- 383
					text = "", -- 384
					fontSize = 18, -- 385
					bgHex = PinBgHex, -- 386
					fgHex = 16777215, -- 387
					borderHex = PinBorderHex, -- 388
					fireOn = "press", -- 389
					onTap = function() -- 390
						focusMission(lvIndex) -- 391
					end -- 390
				} -- 390
			) -- 390
			btn.root.position = Vec2(0, 0) -- 394
			local nameLabel = createLabel( -- 396
				btn.root, -- 396
				(("L" .. __TS__NumberToFixed(lvIndex + 1, 0)) .. " · ") .. title, -- 396
				18, -- 396
				15398143 -- 396
			) -- 396
			setLabelCenter(nameLabel, PinW / 2, PinH - 16) -- 397
			local rocketLabel = createLabel(btn.root, "☆  ☆  ☆", 15, GoldStarHex) -- 399
			setLabelCenter(rocketLabel, PinW / 2, 14) -- 400
			pins[#pins + 1] = { -- 402
				levelIndex = lvIndex, -- 403
				stIndex = stIndex, -- 404
				root = pinRoot, -- 405
				nameLabel = nameLabel, -- 406
				rocketLabel = rocketLabel, -- 407
				btn = btn -- 408
			} -- 408
			i = i + 1 -- 370
		end -- 370
	end -- 370
	local topBar = Node() -- 413
	topBar.size = Size(viewW, 90) -- 414
	topBar.anchor = Vec2(0, 0) -- 415
	topBar.position = Vec2(0, viewH - 90) -- 416
	ui:addChild(topBar) -- 417
	local titleLabel = createLabel(topBar, "深空航迹 · 太阳系沙盘", 32, 16777215) -- 419
	setLabelCenter(titleLabel, viewW / 2, 60) -- 420
	local totalRocketsLabel = createLabel(topBar, "任务完成: 0", 22, 10405355) -- 422
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 423
	local replayIntroBtn = nil -- 425
	if options.onReplayIntro ~= nil then -- 425
		replayIntroBtn = createButton( -- 427
			topBar, -- 427
			{ -- 427
				w = 130, -- 428
				h = 44, -- 429
				text = "重看开场", -- 430
				fontSize = 20, -- 431
				bgHex = SecondaryBtnBgHex, -- 432
				fgHex = SecondaryBtnFgHex, -- 433
				borderHex = SecondaryBtnBorderHex, -- 434
				fireOn = "press", -- 435
				onTap = function() -- 436
					if options.onReplayIntro ~= nil then -- 436
						options:onReplayIntro() -- 437
					end -- 437
				end -- 436
			} -- 436
		) -- 436
		replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 440
	end -- 440
	local dockNode = Node() -- 444
	dockNode.size = Size(viewW, 64) -- 445
	dockNode.anchor = Vec2(0, 0) -- 446
	dockNode.position = Vec2(0, 76) -- 447
	ui:addChild(dockNode) -- 448
	local dockButtons = {} -- 450
	local dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110) -- 451
	local dockBtnH = 50 -- 452
	local dockTotalW = dockBtnW * 6 + 10 * 5 -- 453
	local dockStartX = (viewW - dockTotalW) / 2 -- 454
	do -- 454
		local i = 0 -- 456
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 456
			local lvIndex = i -- 457
			local btn = createButton( -- 458
				dockNode, -- 458
				{ -- 458
					w = dockBtnW, -- 459
					h = dockBtnH, -- 460
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 461
					fontSize = 20, -- 462
					bgHex = PinBgHex, -- 463
					fgHex = 14084346, -- 464
					borderHex = PinBorderHex, -- 465
					fireOn = "press", -- 466
					onTap = function() -- 467
						focusMission(lvIndex) -- 468
					end -- 467
				} -- 467
			) -- 467
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0) -- 471
			dockButtons[#dockButtons + 1] = btn -- 472
			i = i + 1 -- 456
		end -- 456
	end -- 456
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 476
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 477
	local briefCard = createPanel( -- 479
		ui, -- 479
		cardW, -- 479
		cardH, -- 479
		CardBgHex, -- 479
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 479
	) -- 479
	briefCard.anchor = Vec2(0, 0) -- 484
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 485
	briefCard.visible = false -- 486
	local bTitleLabel = createLabel(briefCard, "", 28, 16777215) -- 488
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34) -- 489
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 491
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66) -- 492
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 494
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96) -- 495
	local challengeLabels = {} -- 498
	do -- 498
		local k = 0 -- 499
		while k < 3 do -- 499
			local cl = createLabel(briefCard, "", 19, 13689589) -- 500
			if cl ~= nil then -- 500
				cl.textWidth = cardW - 48 -- 502
				setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44) -- 503
				challengeLabels[#challengeLabels + 1] = cl -- 504
			end -- 504
			k = k + 1 -- 499
		end -- 499
	end -- 499
	local btnRowY = 22 -- 509
	local backBtnW = 120 -- 510
	local launchBtnW = cardW - backBtnW - 40 -- 511
	local btnH = 64 -- 512
	local backBtn = createButton( -- 514
		briefCard, -- 514
		{ -- 514
			w = backBtnW, -- 515
			h = btnH, -- 516
			text = "❮ 返回", -- 517
			fontSize = 22, -- 518
			bgHex = SecondaryBtnBgHex, -- 519
			fgHex = SecondaryBtnFgHex, -- 520
			borderHex = SecondaryBtnBorderHex, -- 521
			fireOn = "press", -- 522
			onTap = function() -- 523
				backToPanorama() -- 524
			end -- 523
		} -- 523
	) -- 523
	backBtn.root.position = Vec2(16, btnRowY) -- 527
	local launchBtn = createButton( -- 529
		briefCard, -- 529
		{ -- 529
			w = launchBtnW, -- 530
			h = btnH, -- 531
			text = "启动任务 / LAUNCH", -- 532
			fontSize = 24, -- 533
			bgHex = PrimaryBtnBgHex, -- 534
			fgHex = PrimaryBtnFgHex, -- 535
			borderHex = PrimaryBtnBorderHex, -- 536
			fireOn = "press", -- 537
			onTap = function() -- 538
				if focusLevelIndex >= 0 then -- 538
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 540
					options:onLaunch(focusLevelIndex) -- 541
				end -- 541
			end -- 538
		} -- 538
	) -- 538
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY) -- 545
	backBtn:setEnabled(false) -- 547
	launchBtn:setEnabled(false) -- 548
	local function updateBriefCard(levelIndex, progress) -- 551
		local lv = getLevel(levelIndex) -- 552
		if lv == nil then -- 552
			return -- 553
		end -- 553
		local m = lv.mission -- 554
		if m == nil then -- 554
			return -- 555
		end -- 555
		setLabelText( -- 557
			bTitleLabel, -- 557
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 557
		) -- 557
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 558
		local savedScore = getMissionRockets(progress, levelIndex) -- 560
		local cleared = getMissionCompleted(progress, levelIndex) -- 561
		local bonusCount = lv.bonusPoints ~= nil and #lv.bonusPoints or 0 -- 562
		setLabelText( -- 563
			bVehicleLabel, -- 563
			(((("【 飞掠型探测器 】 · " .. (cleared and "已完成" or "待完成")) .. " · 火箭最高分 ") .. __TS__NumberToFixed(savedScore, 0)) .. "/") .. __TS__NumberToFixed(bonusCount, 0) -- 563
		) -- 563
		setLabelColor(bVehicleLabel, 8381344) -- 564
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 566
		if lv.bonusPoints ~= nil then -- 566
			local names = { -- 568
				["moon-pass"] = "月球掠过", -- 568
				["venus-assist"] = "金星借力", -- 568
				["mercury-pass"] = "水星飞掠", -- 568
				["jupiter-assist"] = "木星借力", -- 568
				["saturn-assist"] = "土星借力", -- 568
				["deep-space"] = "深空航点" -- 568
			} -- 568
			do -- 568
				local k = 0 -- 569
				while k < 3 do -- 569
					do -- 569
						if k >= #lv.bonusPoints then -- 569
							setLabelVisible(challengeLabels[k + 1], false) -- 570
							goto __continue52 -- 570
						end -- 570
						setLabelVisible(challengeLabels[k + 1], true) -- 571
						local id = lv.bonusPoints[k + 1].id -- 572
						setLabelText(challengeLabels[k + 1], "绿色光点 · " .. (names[id] ~= nil and names[id] or id)) -- 573
						setLabelColor(challengeLabels[k + 1], 9240475) -- 574
					end -- 574
					::__continue52:: -- 574
					k = k + 1 -- 569
				end -- 569
			end -- 569
			return -- 576
		end -- 576
		do -- 576
			local k = 0 -- 578
			while k < 3 do -- 578
				do -- 578
					local c = m.challenges[k + 1] -- 579
					if c == nil then -- 579
						setLabelVisible(challengeLabels[k + 1], false) -- 580
						goto __continue55 -- 580
					end -- 580
					setLabelVisible(challengeLabels[k + 1], true) -- 581
					local achieved = rocketsGot >= k + 1 -- 582
					local icon = achieved and "★" or "☆" -- 583
					local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 584
					local text = lv.transfer ~= nil and (rocketsGot >= 1 and "已完成 · " or "目标 · ") .. c.desc or (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 585
					setLabelText(challengeLabels[k + 1], text) -- 586
					setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 587
				end -- 587
				::__continue55:: -- 587
				k = k + 1 -- 578
			end -- 578
		end -- 578
	end -- 551
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 592
		camMode = "focus" -- 593
		focusLevelIndex = levelIndex -- 594
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 595
		local pose = calcFocusPose(stIndex) -- 596
		targetEye = pose.eye -- 597
		targetTarget = pose.target -- 598
		do -- 598
			local i = 0 -- 601
			while i < #pins do -- 601
				pins[i + 1].root.visible = false -- 602
				pins[i + 1].btn:setEnabled(false) -- 603
				i = i + 1 -- 601
			end -- 601
		end -- 601
		dockNode.visible = false -- 605
		do -- 605
			local i = 0 -- 606
			while i < #dockButtons do -- 606
				dockButtons[i + 1]:setEnabled(false) -- 606
				i = i + 1 -- 606
			end -- 606
		end -- 606
		briefCard.visible = true -- 609
		backBtn:setEnabled(true) -- 610
		launchBtn:setEnabled(true) -- 611
		local curProg = currentProgress -- 614
		if curProg ~= nil then -- 614
			updateBriefCard(levelIndex, curProg) -- 615
		end -- 615
	end -- 592
	--- 返回全景模式。
	backToPanorama = function() -- 619
		camMode = "panorama" -- 620
		focusLevelIndex = -1 -- 621
		targetEye = calcPanoEye() -- 622
		targetTarget = Vec3(0, 0, 0) -- 623
		do -- 623
			local i = 0 -- 626
			while i < #pins do -- 626
				pins[i + 1].root.visible = true -- 627
				pins[i + 1].btn:setEnabled(true) -- 628
				i = i + 1 -- 626
			end -- 626
		end -- 626
		dockNode.visible = true -- 630
		do -- 630
			local i = 0 -- 631
			while i < #dockButtons do -- 631
				dockButtons[i + 1]:setEnabled(true) -- 631
				i = i + 1 -- 631
			end -- 631
		end -- 631
		briefCard.visible = false -- 634
		backBtn:setEnabled(false) -- 635
		launchBtn:setEnabled(false) -- 636
	end -- 619
	local isVisible = false -- 639
	currentProgress = nil -- 640
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 643
		currentProgress = prog -- 644
		setLabelText( -- 645
			totalRocketsLabel, -- 645
			____exports.formatProgressSummary(prog) -- 645
		) -- 645
		do -- 645
			local i = 0 -- 647
			while i < #pins do -- 647
				local p = pins[i + 1] -- 648
				local count = getMissionRockets(prog, p.levelIndex) -- 649
				local complete = getMissionCompleted(prog, p.levelIndex) -- 650
				local ____opt_6 = getLevel(p.levelIndex) -- 650
				local ____opt_4 = ____opt_6 and ____opt_6.bonusPoints -- 650
				local total = ____opt_4 and #____opt_4 or 0 -- 651
				setLabelText( -- 652
					p.rocketLabel, -- 652
					((((complete and "已完成" or "待完成") .. " · 🚀 ") .. __TS__NumberToFixed(count, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 652
				) -- 652
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 653
				dockButtons[i + 1]:setText((((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (complete and "✓" or "")) .. " 🚀") .. __TS__NumberToFixed(count, 0)) -- 656
				i = i + 1 -- 647
			end -- 647
		end -- 647
	end -- 643
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 661
		do -- 661
			local i = 0 -- 663
			while i < #planets do -- 663
				local h = planets[i + 1] -- 664
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 665
				local rad = h.currentAngleDeg * DegToRad -- 666
				h.currentPos = { -- 667
					x = math.cos(rad) * h.station.orbit, -- 668
					y = math.sin(rad) * h.station.orbit -- 669
				} -- 669
				h.node.position = planeToWorld(h.currentPos, 0) -- 671
				local ____h_node_8, ____angleY_9 = h.node, "angleY" -- 671
				____h_node_8[____angleY_9] = ____h_node_8[____angleY_9] + h.station.rotSpeedDegPerSec * dt -- 672
				i = i + 1 -- 663
			end -- 663
		end -- 663
		if probeHandle ~= nil and planets[3] ~= nil then -- 663
			local earthPos = planets[3].currentPos -- 677
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 678
			local probeP = { -- 679
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 680
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 681
			} -- 681
			probeHandle.node.position = planeToWorld(probeP, 0) -- 683
			local vel = { -- 684
				x = -math.sin(probeAngle), -- 685
				y = math.cos(probeAngle) -- 686
			} -- 686
			local yaw = probeYawForVelocity(vel) -- 688
			if yaw ~= nil then -- 688
				probeHandle.node.angleY = yaw -- 689
			end -- 689
			if probeHandle.antenna ~= nil then -- 689
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 691
			end -- 691
		end -- 691
		if camMode == "panorama" and not isDragging then -- 691
			panoYawDeg = panoYawDeg + 0.035 -- 697
			targetEye = calcPanoEye() -- 698
		elseif camMode == "focus" then -- 698
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 701
			targetEye = pose.eye -- 702
			targetTarget = pose.target -- 703
		end -- 703
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 707
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 708
		camera:lookAt( -- 709
			curEye, -- 709
			curTarget, -- 709
			Vec3(0, 1, 0) -- 709
		) -- 709
		if backdrop ~= nil then -- 709
			backdrop:sync(curEye, curTarget) -- 710
		end -- 710
		if camMode == "panorama" then -- 710
			local camView = { -- 714
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 715
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 716
				up = {x = 0, y = 1, z = 0}, -- 717
				fovYDeg = options.fovYDeg, -- 718
				aspect = options.aspect, -- 719
				viewW = viewW, -- 720
				viewH = viewH -- 721
			} -- 721
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 723
			do -- 723
				local i = 0 -- 725
				while i < #pins do -- 725
					do -- 725
						local p = pins[i + 1] -- 726
						local worldPos -- 727
						local yOffset = 24 -- 728
						if p.stIndex == -1 then -- 728
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 731
							yOffset = 48 -- 732
						else -- 732
							local planetHandle = planets[p.stIndex + 1] -- 734
							if planetHandle == nil then -- 734
								goto __continue82 -- 735
							end -- 735
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 736
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 738
						end -- 738
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 741
						if proj ~= nil and proj.vz > 1 then -- 741
							p.root.visible = true -- 744
							local over = toOverlay(proj) -- 745
							local screenX = viewW / 2 + over.x -- 747
							local screenY = viewH / 2 + over.y -- 748
							p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset) -- 749
						else -- 749
							p.root.visible = false -- 751
						end -- 751
					end -- 751
					::__continue82:: -- 751
					i = i + 1 -- 725
				end -- 725
			end -- 725
		end -- 725
	end -- 661
	local hub = { -- 757
		show = function(prog) -- 758
			isVisible = true -- 759
			root.visible = true -- 760
			ui.visible = true -- 761
			gestureLayer.touchEnabled = true -- 762
			refreshRocketsDisplay(prog) -- 764
			backToPanorama() -- 765
			curEye = calcPanoEye() -- 767
			curTarget = Vec3(0, 0, 0) -- 768
			targetEye = curEye -- 769
			targetTarget = curTarget -- 770
			camera:lookAt( -- 771
				curEye, -- 771
				curTarget, -- 771
				Vec3(0, 1, 0) -- 771
			) -- 771
			doStep(0) -- 774
		end, -- 758
		hide = function() -- 777
			isVisible = false -- 778
			root.visible = false -- 779
			ui.visible = false -- 780
			gestureLayer.touchEnabled = false -- 781
			do -- 781
				local i = 0 -- 783
				while i < #pins do -- 783
					pins[i + 1].btn:setEnabled(false) -- 783
					i = i + 1 -- 783
				end -- 783
			end -- 783
			do -- 783
				local i = 0 -- 784
				while i < #dockButtons do -- 784
					dockButtons[i + 1]:setEnabled(false) -- 784
					i = i + 1 -- 784
				end -- 784
			end -- 784
			if replayIntroBtn ~= nil then -- 784
				replayIntroBtn:setEnabled(false) -- 785
			end -- 785
			backBtn:setEnabled(false) -- 786
			launchBtn:setEnabled(false) -- 787
		end, -- 777
		step = function(dt) -- 790
			if not isVisible then -- 790
				return -- 791
			end -- 791
			doStep(dt) -- 792
		end, -- 790
		focusMission = function(levelIndex) -- 795
			focusMission(levelIndex) -- 796
		end, -- 795
		backToPanorama = function() -- 799
			backToPanorama() -- 800
		end, -- 799
		launchCurrentMission = function() -- 803
			if focusLevelIndex >= 0 then -- 803
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 805
				options:onLaunch(focusLevelIndex) -- 806
			end -- 806
		end, -- 803
		relayout = function(w, h) -- 810
			viewW = w -- 811
			viewH = h -- 812
			ui.size = Size(viewW, viewH) -- 813
			ui.position = Vec2(0, 0) -- 814
			gestureLayer.size = Size(viewW, viewH) -- 815
			topBar.size = Size(viewW, 90) -- 816
			topBar.position = Vec2(0, viewH - 90) -- 817
			setLabelCenter(titleLabel, viewW / 2, 60) -- 818
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 819
			if replayIntroBtn ~= nil then -- 819
				replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 821
			end -- 821
			dockNode.position = Vec2(0, 76) -- 823
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 824
		end, -- 810
		visible = function() return isVisible end -- 827
	} -- 827
	currentHubInstance = hub -- 829
	return hub -- 830
end -- 180
currentHubInstance = nil -- 833
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 836
	return currentHubInstance -- 837
end -- 836
return ____exports -- 836
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
		emissiveHex = 0, -- 90
		levelIndex = 2 -- 90
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
		emissiveHex = 0 -- 94
	} -- 94
} -- 94
--- 关卡索引 -> HUB_STATIONS 下标的映射（L1 地球: 2, L2 水星: 0, L3 土星: 5）。
____exports.LEVEL_TO_STATION_INDEX = {2, 0, 5} -- 98
--- 视觉配置常量。
local SunRadius = 4.8 -- 101
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 102
local OrbitRingsHex = 4153224 -- 103
local CardBgHex = 792102 -- 105
local CardBorderHex = 3033193 -- 106
local PrimaryBtnBgHex = 1319732 -- 107
local PrimaryBtnFgHex = 16777215 -- 108
local PrimaryBtnBorderHex = 5143454 -- 109
local SecondaryBtnBgHex = 1319732 -- 110
local SecondaryBtnFgHex = 10468571 -- 111
local SecondaryBtnBorderHex = 5143454 -- 112
local PinBgHex = 1319732 -- 113
local PinBorderHex = 5143454 -- 114
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
	local PinW = 208 -- 367
	local PinH = 72 -- 368
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
	topBar.size = Size(viewW, 120) -- 414
	topBar.anchor = Vec2(0, 0) -- 415
	topBar.position = Vec2(0, viewH - 120) -- 416
	ui:addChild(topBar) -- 417
	local titleLabel = createLabel(topBar, "太阳系沙盘", 26, 16777215) -- 419
	if titleLabel ~= nil then -- 419
		titleLabel.anchor = Vec2(0, 0.5) -- 420
		titleLabel.position = Vec2(24, 84) -- 420
	end -- 420
	local totalRocketsLabel = createLabel(topBar, "任务完成: 0", 22, 10405355) -- 422
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 423
	local replayIntroBtn = nil -- 425
	if options.onReplayIntro ~= nil then -- 425
		replayIntroBtn = createButton( -- 427
			topBar, -- 427
			{ -- 427
				w = 144, -- 428
				h = 72, -- 429
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
		replayIntroBtn.root.position = Vec2(viewW - 160, 44) -- 440
	end -- 440
	local dockNode = Node() -- 444
	dockNode.size = Size(viewW, 64) -- 445
	dockNode.anchor = Vec2(0, 0) -- 446
	dockNode.position = Vec2(0, 76) -- 447
	ui:addChild(dockNode) -- 448
	local dockButtons = {} -- 450
	local dockBtnW = 144 -- 451
	local dockBtnH = 72 -- 452
	local dockTotalW = dockBtnW * #____exports.LEVEL_TO_STATION_INDEX + 8 * (#____exports.LEVEL_TO_STATION_INDEX - 1) -- 453
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
					icon = "launch", -- 462
					fontSize = 20, -- 463
					bgHex = PinBgHex, -- 464
					fgHex = 14084346, -- 465
					borderHex = PinBorderHex, -- 466
					fireOn = "press", -- 467
					onTap = function() -- 468
						focusMission(lvIndex) -- 469
					end -- 468
				} -- 468
			) -- 468
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 8), 0) -- 472
			dockButtons[#dockButtons + 1] = btn -- 473
			i = i + 1 -- 456
		end -- 456
	end -- 456
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 477
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 478
	local briefCard = createPanel( -- 480
		ui, -- 480
		cardW, -- 480
		cardH, -- 480
		CardBgHex, -- 480
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 480
	) -- 480
	briefCard.anchor = Vec2(0, 0) -- 485
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 486
	briefCard.visible = false -- 487
	local bTitleLabel = createLabel(briefCard, "", 22, 16777215) -- 489
	if bTitleLabel ~= nil then -- 489
		bTitleLabel.textWidth = cardW - 48 -- 490
	end -- 490
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 40) -- 491
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 493
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 83) -- 494
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 496
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 110) -- 497
	local challengeLabels = {} -- 500
	do -- 500
		local k = 0 -- 501
		while k < 3 do -- 501
			local cl = createLabel(briefCard, "", 19, 13689589) -- 502
			if cl ~= nil then -- 502
				cl.textWidth = cardW - 48 -- 504
				setLabelCenter(cl, cardW / 2, cardH - 153 - k * 44) -- 505
				challengeLabels[#challengeLabels + 1] = cl -- 506
			end -- 506
			k = k + 1 -- 501
		end -- 501
	end -- 501
	local btnRowY = 22 -- 511
	local backBtnW = 72 -- 512
	local launchBtnW = 144 -- 513
	local btnH = 72 -- 514
	local backBtn = createButton( -- 516
		briefCard, -- 516
		{ -- 516
			w = backBtnW, -- 517
			h = btnH, -- 518
			text = "", -- 519
			icon = "back", -- 519
			fontSize = 22, -- 520
			bgHex = SecondaryBtnBgHex, -- 521
			fgHex = SecondaryBtnFgHex, -- 522
			borderHex = SecondaryBtnBorderHex, -- 523
			fireOn = "press", -- 524
			onTap = function() -- 525
				backToPanorama() -- 526
			end -- 525
		} -- 525
	) -- 525
	backBtn.root.position = Vec2(16, btnRowY) -- 529
	local launchBtn = createButton( -- 531
		briefCard, -- 531
		{ -- 531
			w = launchBtnW, -- 532
			h = btnH, -- 533
			text = "出发", -- 534
			icon = "launch", -- 534
			fontSize = 24, -- 535
			bgHex = PrimaryBtnBgHex, -- 536
			fgHex = PrimaryBtnFgHex, -- 537
			borderHex = PrimaryBtnBorderHex, -- 538
			fireOn = "press", -- 539
			onTap = function() -- 540
				if focusLevelIndex >= 0 then -- 540
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 542
					options:onLaunch(focusLevelIndex) -- 543
				end -- 543
			end -- 540
		} -- 540
	) -- 540
	launchBtn.root.position = Vec2(cardW - launchBtnW - 16, btnRowY) -- 547
	backBtn:setEnabled(false) -- 549
	launchBtn:setEnabled(false) -- 550
	local function updateBriefCard(levelIndex, progress) -- 553
		local lv = getLevel(levelIndex) -- 554
		if lv == nil then -- 554
			return -- 555
		end -- 555
		local m = lv.mission -- 556
		if m == nil then -- 556
			return -- 557
		end -- 557
		setLabelText( -- 559
			bTitleLabel, -- 559
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 559
		) -- 559
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 560
		local savedScore = getMissionRockets(progress, levelIndex) -- 562
		local cleared = getMissionCompleted(progress, levelIndex) -- 563
		local bonusCount = lv.bonusPoints ~= nil and #lv.bonusPoints or 0 -- 564
		setLabelText( -- 565
			bVehicleLabel, -- 565
			(((("【 飞掠型探测器 】 · " .. (cleared and "已完成" or "待完成")) .. " · 火箭最高分 ") .. __TS__NumberToFixed(savedScore, 0)) .. "/") .. __TS__NumberToFixed(bonusCount, 0) -- 565
		) -- 565
		setLabelColor(bVehicleLabel, 8381344) -- 566
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 568
		if lv.bonusPoints ~= nil then -- 568
			local names = { -- 570
				["moon-pass"] = "月球掠过", -- 570
				["venus-assist"] = "金星借力", -- 570
				["mercury-pass"] = "水星飞掠", -- 570
				["jupiter-assist"] = "木星借力", -- 570
				["saturn-assist"] = "土星借力", -- 570
				["deep-space"] = "深空航点" -- 570
			} -- 570
			do -- 570
				local k = 0 -- 571
				while k < 3 do -- 571
					do -- 571
						if k >= #lv.bonusPoints then -- 571
							setLabelVisible(challengeLabels[k + 1], false) -- 572
							goto __continue54 -- 572
						end -- 572
						setLabelVisible(challengeLabels[k + 1], true) -- 573
						local id = lv.bonusPoints[k + 1].id -- 574
						setLabelText(challengeLabels[k + 1], "绿色光点 · " .. (names[id] ~= nil and names[id] or id)) -- 575
						setLabelColor(challengeLabels[k + 1], 9240475) -- 576
					end -- 576
					::__continue54:: -- 576
					k = k + 1 -- 571
				end -- 571
			end -- 571
			return -- 578
		end -- 578
		do -- 578
			local k = 0 -- 580
			while k < 3 do -- 580
				do -- 580
					local c = m.challenges[k + 1] -- 581
					if c == nil then -- 581
						setLabelVisible(challengeLabels[k + 1], false) -- 582
						goto __continue57 -- 582
					end -- 582
					setLabelVisible(challengeLabels[k + 1], true) -- 583
					local achieved = rocketsGot >= k + 1 -- 584
					local icon = achieved and "★" or "☆" -- 585
					local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 586
					local text = lv.transfer ~= nil and (rocketsGot >= 1 and "已完成 · " or "目标 · ") .. c.desc or (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 587
					setLabelText(challengeLabels[k + 1], text) -- 588
					setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 589
				end -- 589
				::__continue57:: -- 589
				k = k + 1 -- 580
			end -- 580
		end -- 580
	end -- 553
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 594
		print("[escape-velocity] hub brief L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 595
		camMode = "focus" -- 596
		focusLevelIndex = levelIndex -- 597
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 598
		local pose = calcFocusPose(stIndex) -- 599
		targetEye = pose.eye -- 600
		targetTarget = pose.target -- 601
		do -- 601
			local i = 0 -- 604
			while i < #pins do -- 604
				pins[i + 1].root.visible = false -- 605
				pins[i + 1].btn:setEnabled(false) -- 606
				i = i + 1 -- 604
			end -- 604
		end -- 604
		dockNode.visible = false -- 608
		do -- 608
			local i = 0 -- 609
			while i < #dockButtons do -- 609
				dockButtons[i + 1]:setEnabled(false) -- 609
				i = i + 1 -- 609
			end -- 609
		end -- 609
		briefCard.visible = true -- 612
		backBtn:setEnabled(true) -- 613
		launchBtn:setEnabled(true) -- 614
		local curProg = currentProgress -- 617
		if curProg ~= nil then -- 617
			updateBriefCard(levelIndex, curProg) -- 618
		end -- 618
	end -- 594
	--- 返回全景模式。
	backToPanorama = function() -- 622
		camMode = "panorama" -- 623
		focusLevelIndex = -1 -- 624
		targetEye = calcPanoEye() -- 625
		targetTarget = Vec3(0, 0, 0) -- 626
		do -- 626
			local i = 0 -- 629
			while i < #pins do -- 629
				pins[i + 1].root.visible = true -- 630
				pins[i + 1].btn:setEnabled(true) -- 631
				i = i + 1 -- 629
			end -- 629
		end -- 629
		dockNode.visible = true -- 633
		do -- 633
			local i = 0 -- 634
			while i < #dockButtons do -- 634
				dockButtons[i + 1]:setEnabled(true) -- 634
				i = i + 1 -- 634
			end -- 634
		end -- 634
		briefCard.visible = false -- 637
		backBtn:setEnabled(false) -- 638
		launchBtn:setEnabled(false) -- 639
	end -- 622
	local isVisible = false -- 642
	currentProgress = nil -- 643
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 646
		currentProgress = prog -- 647
		setLabelText( -- 648
			totalRocketsLabel, -- 648
			____exports.formatProgressSummary(prog) -- 648
		) -- 648
		do -- 648
			local i = 0 -- 650
			while i < #pins do -- 650
				local p = pins[i + 1] -- 651
				local count = getMissionRockets(prog, p.levelIndex) -- 652
				local complete = getMissionCompleted(prog, p.levelIndex) -- 653
				local ____opt_6 = getLevel(p.levelIndex) -- 653
				local ____opt_4 = ____opt_6 and ____opt_6.bonusPoints -- 653
				local total = ____opt_4 and #____opt_4 or 0 -- 654
				setLabelText( -- 655
					p.rocketLabel, -- 655
					((((complete and "已完成" or "待完成") .. " · 火箭 ") .. __TS__NumberToFixed(count, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 655
				) -- 655
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 656
				dockButtons[i + 1]:setText((((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (complete and "✓" or "")) .. " ") .. __TS__NumberToFixed(count, 0)) -- 659
				i = i + 1 -- 650
			end -- 650
		end -- 650
	end -- 646
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 664
		do -- 664
			local i = 0 -- 666
			while i < #planets do -- 666
				local h = planets[i + 1] -- 667
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 668
				local rad = h.currentAngleDeg * DegToRad -- 669
				h.currentPos = { -- 670
					x = math.cos(rad) * h.station.orbit, -- 671
					y = math.sin(rad) * h.station.orbit -- 672
				} -- 672
				h.node.position = planeToWorld(h.currentPos, 0) -- 674
				local ____h_node_8, ____angleY_9 = h.node, "angleY" -- 674
				____h_node_8[____angleY_9] = ____h_node_8[____angleY_9] + h.station.rotSpeedDegPerSec * dt -- 675
				i = i + 1 -- 666
			end -- 666
		end -- 666
		if probeHandle ~= nil and planets[3] ~= nil then -- 666
			local earthPos = planets[3].currentPos -- 680
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 681
			local probeP = { -- 682
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 683
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 684
			} -- 684
			probeHandle.node.position = planeToWorld(probeP, 0) -- 686
			local vel = { -- 687
				x = -math.sin(probeAngle), -- 688
				y = math.cos(probeAngle) -- 689
			} -- 689
			local yaw = probeYawForVelocity(vel) -- 691
			if yaw ~= nil then -- 691
				probeHandle.node.angleY = yaw -- 692
			end -- 692
			if probeHandle.antenna ~= nil then -- 692
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 694
			end -- 694
		end -- 694
		if camMode == "panorama" and not isDragging then -- 694
			panoYawDeg = panoYawDeg + 0.035 -- 700
			targetEye = calcPanoEye() -- 701
		elseif camMode == "focus" then -- 701
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 704
			targetEye = pose.eye -- 705
			targetTarget = pose.target -- 706
		end -- 706
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 710
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 711
		camera:lookAt( -- 712
			curEye, -- 712
			curTarget, -- 712
			Vec3(0, 1, 0) -- 712
		) -- 712
		if backdrop ~= nil then -- 712
			backdrop:sync(curEye, curTarget) -- 713
		end -- 713
		if camMode == "panorama" then -- 713
			local camView = { -- 717
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 718
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 719
				up = {x = 0, y = 1, z = 0}, -- 720
				fovYDeg = options.fovYDeg, -- 721
				aspect = options.aspect, -- 722
				viewW = viewW, -- 723
				viewH = viewH -- 724
			} -- 724
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 726
			do -- 726
				local i = 0 -- 728
				while i < #pins do -- 728
					do -- 728
						local p = pins[i + 1] -- 729
						local worldPos -- 730
						local yOffset = 24 -- 731
						if p.stIndex == -1 then -- 731
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 734
							yOffset = 48 -- 735
						else -- 735
							local planetHandle = planets[p.stIndex + 1] -- 737
							if planetHandle == nil then -- 737
								goto __continue84 -- 738
							end -- 738
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 739
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 741
						end -- 741
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 744
						if proj ~= nil and proj.vz > 1 then -- 744
							p.root.visible = true -- 747
							local over = toOverlay(proj) -- 748
							local screenX = viewW / 2 + over.x -- 750
							local screenY = viewH / 2 + over.y -- 751
							local x = clampNumber(screenX - PinW / 2, 12, viewW - PinW - 12) -- 752
							local y = clampNumber(screenY + yOffset, 168, viewH - 200) -- 753
							do -- 753
								local j = 0 -- 754
								while j < i do -- 754
									local other = pins[j + 1].root -- 755
									if other.visible and x < other.x + PinW + 8 and x + PinW + 8 > other.x and y < other.y + PinH + 8 and y + PinH + 8 > other.y then -- 755
										y = math.min(viewH - 200, other.y + PinH + 8) -- 756
									end -- 756
									j = j + 1 -- 754
								end -- 754
							end -- 754
							p.root.position = Vec2(x, y) -- 758
						else -- 758
							p.root.visible = false -- 760
						end -- 760
					end -- 760
					::__continue84:: -- 760
					i = i + 1 -- 728
				end -- 728
			end -- 728
		end -- 728
	end -- 664
	local hub = { -- 766
		show = function(prog) -- 767
			isVisible = true -- 768
			root.visible = true -- 769
			ui.visible = true -- 770
			gestureLayer.touchEnabled = true -- 771
			refreshRocketsDisplay(prog) -- 773
			backToPanorama() -- 774
			curEye = calcPanoEye() -- 776
			curTarget = Vec3(0, 0, 0) -- 777
			targetEye = curEye -- 778
			targetTarget = curTarget -- 779
			camera:lookAt( -- 780
				curEye, -- 780
				curTarget, -- 780
				Vec3(0, 1, 0) -- 780
			) -- 780
			doStep(0) -- 783
		end, -- 767
		hide = function() -- 786
			isVisible = false -- 787
			root.visible = false -- 788
			ui.visible = false -- 789
			gestureLayer.touchEnabled = false -- 790
			do -- 790
				local i = 0 -- 792
				while i < #pins do -- 792
					pins[i + 1].btn:setEnabled(false) -- 792
					i = i + 1 -- 792
				end -- 792
			end -- 792
			do -- 792
				local i = 0 -- 793
				while i < #dockButtons do -- 793
					dockButtons[i + 1]:setEnabled(false) -- 793
					i = i + 1 -- 793
				end -- 793
			end -- 793
			if replayIntroBtn ~= nil then -- 793
				replayIntroBtn:setEnabled(false) -- 794
			end -- 794
			backBtn:setEnabled(false) -- 795
			launchBtn:setEnabled(false) -- 796
		end, -- 786
		step = function(dt) -- 799
			if not isVisible then -- 799
				return -- 800
			end -- 800
			doStep(dt) -- 801
		end, -- 799
		focusMission = function(levelIndex) -- 804
			focusMission(levelIndex) -- 805
		end, -- 804
		backToPanorama = function() -- 808
			backToPanorama() -- 809
		end, -- 808
		launchCurrentMission = function() -- 812
			if focusLevelIndex >= 0 then -- 812
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 814
				options:onLaunch(focusLevelIndex) -- 815
			end -- 815
		end, -- 812
		relayout = function(w, h) -- 819
			viewW = w -- 820
			viewH = h -- 821
			ui.size = Size(viewW, viewH) -- 822
			ui.position = Vec2(0, 0) -- 823
			gestureLayer.size = Size(viewW, viewH) -- 824
			topBar.size = Size(viewW, 120) -- 825
			topBar.position = Vec2(0, viewH - 120) -- 826
			setLabelCenter(titleLabel, 24, 84) -- 827
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 828
			if replayIntroBtn ~= nil then -- 828
				replayIntroBtn.root.position = Vec2(viewW - 160, 44) -- 830
			end -- 830
			dockNode.position = Vec2(0, 76) -- 832
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 833
		end, -- 819
		visible = function() return isVisible end -- 836
	} -- 836
	currentHubInstance = hub -- 838
	return hub -- 839
end -- 180
currentHubInstance = nil -- 842
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 845
	return currentHubInstance -- 846
end -- 845
return ____exports -- 845
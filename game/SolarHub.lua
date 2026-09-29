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
	ui:addChild(dockNode) -- 447
	local dockButtons = {} -- 449
	local dockBtnW = 144 -- 450
	local dockBtnH = 72 -- 451
	local dockTotalW = dockBtnW * #____exports.LEVEL_TO_STATION_INDEX + 8 * (#____exports.LEVEL_TO_STATION_INDEX - 1) -- 452
	do -- 452
		local i = 0 -- 454
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 454
			local lvIndex = i -- 455
			local btn = createButton( -- 456
				dockNode, -- 456
				{ -- 456
					w = dockBtnW, -- 457
					h = dockBtnH, -- 458
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 459
					icon = "launch", -- 460
					fontSize = 20, -- 461
					bgHex = PinBgHex, -- 462
					fgHex = 14084346, -- 463
					borderHex = PinBorderHex, -- 464
					fireOn = "press", -- 465
					onTap = function() -- 466
						focusMission(lvIndex) -- 467
					end -- 466
				} -- 466
			) -- 466
			btn.root.position = Vec2(lvIndex * (dockBtnW + 8), 0) -- 470
			dockButtons[#dockButtons + 1] = btn -- 471
			i = i + 1 -- 454
		end -- 454
	end -- 454
	local function layoutDock() -- 473
		local scaleX = math.min( -- 474
			1, -- 474
			math.max(0.35, (viewW - 24) / dockTotalW) -- 474
		) -- 474
		dockNode.scaleX = scaleX -- 475
		dockNode.position = Vec2((viewW - dockTotalW * scaleX) / 2, 76) -- 476
	end -- 473
	layoutDock() -- 478
	local cardW = math.max( -- 481
		1, -- 481
		math.min( -- 481
			viewW - 24, -- 481
			clampNumber(viewW * 0.92, 280, 540) -- 481
		) -- 481
	) -- 481
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 482
	local briefCard = createPanel( -- 484
		ui, -- 484
		cardW, -- 484
		cardH, -- 484
		CardBgHex, -- 484
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 484
	) -- 484
	briefCard.anchor = Vec2(0, 0) -- 489
	local function layoutBriefCard() -- 490
		local scale = math.max( -- 491
			0.35, -- 491
			math.min(1, (viewW - 24) / cardW, (viewH - 80) / cardH) -- 491
		) -- 491
		briefCard.scaleX = scale -- 492
		briefCard.scaleY = scale -- 493
		briefCard.position = Vec2((viewW - cardW * scale) / 2, 40) -- 494
	end -- 490
	layoutBriefCard() -- 496
	briefCard.visible = false -- 497
	local bTitleLabel = createLabel(briefCard, "", 22, 16777215) -- 499
	if bTitleLabel ~= nil then -- 499
		bTitleLabel.textWidth = cardW - 48 -- 500
	end -- 500
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 40) -- 501
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 503
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 83) -- 504
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 506
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 110) -- 507
	local challengeLabels = {} -- 510
	do -- 510
		local k = 0 -- 511
		while k < 3 do -- 511
			local cl = createLabel(briefCard, "", 19, 13689589) -- 512
			if cl ~= nil then -- 512
				cl.textWidth = cardW - 48 -- 514
				setLabelCenter(cl, cardW / 2, cardH - 153 - k * 44) -- 515
				challengeLabels[#challengeLabels + 1] = cl -- 516
			end -- 516
			k = k + 1 -- 511
		end -- 511
	end -- 511
	local btnRowY = 22 -- 521
	local actionW = math.max(1, cardW - 40) -- 522
	local backBtnW = math.min(72, actionW * 0.32) -- 523
	local launchBtnW = math.min( -- 524
		144, -- 524
		math.max(1, actionW - backBtnW - 8) -- 524
	) -- 524
	local btnH = 72 -- 525
	local backBtn = createButton( -- 527
		briefCard, -- 527
		{ -- 527
			w = backBtnW, -- 528
			h = btnH, -- 529
			text = "", -- 530
			icon = "back", -- 530
			fontSize = 22, -- 531
			bgHex = SecondaryBtnBgHex, -- 532
			fgHex = SecondaryBtnFgHex, -- 533
			borderHex = SecondaryBtnBorderHex, -- 534
			fireOn = "press", -- 535
			onTap = function() -- 536
				backToPanorama() -- 537
			end -- 536
		} -- 536
	) -- 536
	backBtn.root.position = Vec2(16, btnRowY) -- 540
	local launchBtn = createButton( -- 542
		briefCard, -- 542
		{ -- 542
			w = launchBtnW, -- 543
			h = btnH, -- 544
			text = "出发", -- 545
			icon = "launch", -- 545
			fontSize = 24, -- 546
			bgHex = PrimaryBtnBgHex, -- 547
			fgHex = PrimaryBtnFgHex, -- 548
			borderHex = PrimaryBtnBorderHex, -- 549
			fireOn = "press", -- 550
			onTap = function() -- 551
				if focusLevelIndex >= 0 then -- 551
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 553
					options:onLaunch(focusLevelIndex) -- 554
				end -- 554
			end -- 551
		} -- 551
	) -- 551
	launchBtn.root.position = Vec2(cardW - launchBtnW - 16, btnRowY) -- 558
	backBtn:setEnabled(false) -- 560
	launchBtn:setEnabled(false) -- 561
	local function updateBriefCard(levelIndex, progress) -- 564
		local lv = getLevel(levelIndex) -- 565
		if lv == nil then -- 565
			return -- 566
		end -- 566
		local m = lv.mission -- 567
		if m == nil then -- 567
			return -- 568
		end -- 568
		setLabelText( -- 570
			bTitleLabel, -- 570
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 570
		) -- 570
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 571
		local savedScore = getMissionRockets(progress, levelIndex) -- 573
		local cleared = getMissionCompleted(progress, levelIndex) -- 574
		local bonusCount = lv.bonusPoints ~= nil and #lv.bonusPoints or 0 -- 575
		setLabelText( -- 576
			bVehicleLabel, -- 576
			(((("【 飞掠型探测器 】 · " .. (cleared and "已完成" or "待完成")) .. " · 火箭最高分 ") .. __TS__NumberToFixed(savedScore, 0)) .. "/") .. __TS__NumberToFixed(bonusCount, 0) -- 576
		) -- 576
		setLabelColor(bVehicleLabel, 8381344) -- 577
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 579
		if lv.bonusPoints ~= nil then -- 579
			local names = { -- 581
				["moon-pass"] = "月球掠过", -- 581
				["venus-assist"] = "金星借力", -- 581
				["mercury-pass"] = "水星飞掠", -- 581
				["jupiter-assist"] = "木星借力", -- 581
				["saturn-assist"] = "土星借力", -- 581
				["deep-space"] = "深空航点" -- 581
			} -- 581
			do -- 581
				local k = 0 -- 582
				while k < 3 do -- 582
					do -- 582
						if k >= #lv.bonusPoints then -- 582
							setLabelVisible(challengeLabels[k + 1], false) -- 583
							goto __continue56 -- 583
						end -- 583
						setLabelVisible(challengeLabels[k + 1], true) -- 584
						local id = lv.bonusPoints[k + 1].id -- 585
						setLabelText(challengeLabels[k + 1], "绿色光点 · " .. (names[id] ~= nil and names[id] or id)) -- 586
						setLabelColor(challengeLabels[k + 1], 9240475) -- 587
					end -- 587
					::__continue56:: -- 587
					k = k + 1 -- 582
				end -- 582
			end -- 582
			return -- 589
		end -- 589
		do -- 589
			local k = 0 -- 591
			while k < 3 do -- 591
				do -- 591
					local c = m.challenges[k + 1] -- 592
					if c == nil then -- 592
						setLabelVisible(challengeLabels[k + 1], false) -- 593
						goto __continue59 -- 593
					end -- 593
					setLabelVisible(challengeLabels[k + 1], true) -- 594
					local achieved = rocketsGot >= k + 1 -- 595
					local icon = achieved and "★" or "☆" -- 596
					local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 597
					local text = lv.transfer ~= nil and (rocketsGot >= 1 and "已完成 · " or "目标 · ") .. c.desc or (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 598
					setLabelText(challengeLabels[k + 1], text) -- 599
					setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 600
				end -- 600
				::__continue59:: -- 600
				k = k + 1 -- 591
			end -- 591
		end -- 591
	end -- 564
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 605
		print("[escape-velocity] hub brief L" .. __TS__NumberToFixed(levelIndex + 1, 0)) -- 606
		camMode = "focus" -- 607
		focusLevelIndex = levelIndex -- 608
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 609
		local pose = calcFocusPose(stIndex) -- 610
		targetEye = pose.eye -- 611
		targetTarget = pose.target -- 612
		do -- 612
			local i = 0 -- 615
			while i < #pins do -- 615
				pins[i + 1].root.visible = false -- 616
				pins[i + 1].btn:setEnabled(false) -- 617
				i = i + 1 -- 615
			end -- 615
		end -- 615
		dockNode.visible = false -- 619
		do -- 619
			local i = 0 -- 620
			while i < #dockButtons do -- 620
				dockButtons[i + 1]:setEnabled(false) -- 620
				i = i + 1 -- 620
			end -- 620
		end -- 620
		briefCard.visible = true -- 623
		backBtn:setEnabled(true) -- 624
		launchBtn:setEnabled(true) -- 625
		local curProg = currentProgress -- 628
		if curProg ~= nil then -- 628
			updateBriefCard(levelIndex, curProg) -- 629
		end -- 629
	end -- 605
	--- 返回全景模式。
	backToPanorama = function() -- 633
		camMode = "panorama" -- 634
		focusLevelIndex = -1 -- 635
		targetEye = calcPanoEye() -- 636
		targetTarget = Vec3(0, 0, 0) -- 637
		do -- 637
			local i = 0 -- 640
			while i < #pins do -- 640
				pins[i + 1].root.visible = true -- 641
				pins[i + 1].btn:setEnabled(true) -- 642
				i = i + 1 -- 640
			end -- 640
		end -- 640
		dockNode.visible = true -- 644
		do -- 644
			local i = 0 -- 645
			while i < #dockButtons do -- 645
				dockButtons[i + 1]:setEnabled(true) -- 645
				i = i + 1 -- 645
			end -- 645
		end -- 645
		briefCard.visible = false -- 648
		backBtn:setEnabled(false) -- 649
		launchBtn:setEnabled(false) -- 650
	end -- 633
	local isVisible = false -- 653
	currentProgress = nil -- 654
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 657
		currentProgress = prog -- 658
		setLabelText( -- 659
			totalRocketsLabel, -- 659
			____exports.formatProgressSummary(prog) -- 659
		) -- 659
		do -- 659
			local i = 0 -- 661
			while i < #pins do -- 661
				local p = pins[i + 1] -- 662
				local count = getMissionRockets(prog, p.levelIndex) -- 663
				local complete = getMissionCompleted(prog, p.levelIndex) -- 664
				local ____opt_6 = getLevel(p.levelIndex) -- 664
				local ____opt_4 = ____opt_6 and ____opt_6.bonusPoints -- 664
				local total = ____opt_4 and #____opt_4 or 0 -- 665
				setLabelText( -- 666
					p.rocketLabel, -- 666
					((((complete and "已完成" or "待完成") .. " · 火箭 ") .. __TS__NumberToFixed(count, 0)) .. "/") .. __TS__NumberToFixed(total, 0) -- 666
				) -- 666
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 667
				dockButtons[i + 1]:setText((((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (complete and "✓" or "")) .. " ") .. __TS__NumberToFixed(count, 0)) -- 670
				i = i + 1 -- 661
			end -- 661
		end -- 661
	end -- 657
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 675
		do -- 675
			local i = 0 -- 677
			while i < #planets do -- 677
				local h = planets[i + 1] -- 678
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 679
				local rad = h.currentAngleDeg * DegToRad -- 680
				h.currentPos = { -- 681
					x = math.cos(rad) * h.station.orbit, -- 682
					y = math.sin(rad) * h.station.orbit -- 683
				} -- 683
				h.node.position = planeToWorld(h.currentPos, 0) -- 685
				local ____h_node_8, ____angleY_9 = h.node, "angleY" -- 685
				____h_node_8[____angleY_9] = ____h_node_8[____angleY_9] + h.station.rotSpeedDegPerSec * dt -- 686
				i = i + 1 -- 677
			end -- 677
		end -- 677
		if probeHandle ~= nil and planets[3] ~= nil then -- 677
			local earthPos = planets[3].currentPos -- 691
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 692
			local probeP = { -- 693
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 694
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 695
			} -- 695
			probeHandle.node.position = planeToWorld(probeP, 0) -- 697
			local vel = { -- 698
				x = -math.sin(probeAngle), -- 699
				y = math.cos(probeAngle) -- 700
			} -- 700
			local yaw = probeYawForVelocity(vel) -- 702
			if yaw ~= nil then -- 702
				probeHandle.node.angleY = yaw -- 703
			end -- 703
			if probeHandle.antenna ~= nil then -- 703
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 705
			end -- 705
		end -- 705
		if camMode == "panorama" and not isDragging then -- 705
			panoYawDeg = panoYawDeg + 0.035 -- 711
			targetEye = calcPanoEye() -- 712
		elseif camMode == "focus" then -- 712
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 715
			targetEye = pose.eye -- 716
			targetTarget = pose.target -- 717
		end -- 717
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 721
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 722
		camera:lookAt( -- 723
			curEye, -- 723
			curTarget, -- 723
			Vec3(0, 1, 0) -- 723
		) -- 723
		if backdrop ~= nil then -- 723
			backdrop:sync(curEye, curTarget) -- 724
		end -- 724
		if camMode == "panorama" then -- 724
			local camView = { -- 728
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 729
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 730
				up = {x = 0, y = 1, z = 0}, -- 731
				fovYDeg = options.fovYDeg, -- 732
				aspect = options.aspect, -- 733
				viewW = viewW, -- 734
				viewH = viewH -- 735
			} -- 735
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 737
			do -- 737
				local i = 0 -- 739
				while i < #pins do -- 739
					do -- 739
						local p = pins[i + 1] -- 740
						local worldPos -- 741
						local yOffset = 24 -- 742
						if p.stIndex == -1 then -- 742
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 745
							yOffset = 48 -- 746
						else -- 746
							local planetHandle = planets[p.stIndex + 1] -- 748
							if planetHandle == nil then -- 748
								goto __continue86 -- 749
							end -- 749
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 750
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 752
						end -- 752
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 755
						if proj ~= nil and proj.vz > 1 then -- 755
							p.root.visible = true -- 758
							local over = toOverlay(proj) -- 759
							local screenX = viewW / 2 + over.x -- 761
							local screenY = viewH / 2 + over.y -- 762
							local x = clampNumber(screenX - PinW / 2, 12, viewW - PinW - 12) -- 763
							local y = clampNumber(screenY + yOffset, 168, viewH - 200) -- 764
							do -- 764
								local j = 0 -- 765
								while j < i do -- 765
									local other = pins[j + 1].root -- 766
									if other.visible and x < other.x + PinW + 8 and x + PinW + 8 > other.x and y < other.y + PinH + 8 and y + PinH + 8 > other.y then -- 766
										y = math.min(viewH - 200, other.y + PinH + 8) -- 767
									end -- 767
									j = j + 1 -- 765
								end -- 765
							end -- 765
							p.root.position = Vec2(x, y) -- 769
						else -- 769
							p.root.visible = false -- 771
						end -- 771
					end -- 771
					::__continue86:: -- 771
					i = i + 1 -- 739
				end -- 739
			end -- 739
		end -- 739
	end -- 675
	local hub = { -- 777
		show = function(prog) -- 778
			isVisible = true -- 779
			root.visible = true -- 780
			ui.visible = true -- 781
			gestureLayer.touchEnabled = true -- 782
			refreshRocketsDisplay(prog) -- 784
			backToPanorama() -- 785
			curEye = calcPanoEye() -- 787
			curTarget = Vec3(0, 0, 0) -- 788
			targetEye = curEye -- 789
			targetTarget = curTarget -- 790
			camera:lookAt( -- 791
				curEye, -- 791
				curTarget, -- 791
				Vec3(0, 1, 0) -- 791
			) -- 791
			doStep(0) -- 794
		end, -- 778
		hide = function() -- 797
			isVisible = false -- 798
			root.visible = false -- 799
			ui.visible = false -- 800
			gestureLayer.touchEnabled = false -- 801
			do -- 801
				local i = 0 -- 803
				while i < #pins do -- 803
					pins[i + 1].btn:setEnabled(false) -- 803
					i = i + 1 -- 803
				end -- 803
			end -- 803
			do -- 803
				local i = 0 -- 804
				while i < #dockButtons do -- 804
					dockButtons[i + 1]:setEnabled(false) -- 804
					i = i + 1 -- 804
				end -- 804
			end -- 804
			if replayIntroBtn ~= nil then -- 804
				replayIntroBtn:setEnabled(false) -- 805
			end -- 805
			backBtn:setEnabled(false) -- 806
			launchBtn:setEnabled(false) -- 807
		end, -- 797
		step = function(dt) -- 810
			if not isVisible then -- 810
				return -- 811
			end -- 811
			doStep(dt) -- 812
		end, -- 810
		focusMission = function(levelIndex) -- 815
			focusMission(levelIndex) -- 816
		end, -- 815
		backToPanorama = function() -- 819
			backToPanorama() -- 820
		end, -- 819
		launchCurrentMission = function() -- 823
			if focusLevelIndex >= 0 then -- 823
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 825
				options:onLaunch(focusLevelIndex) -- 826
			end -- 826
		end, -- 823
		relayout = function(w, h) -- 830
			viewW = w -- 831
			viewH = h -- 832
			ui.size = Size(viewW, viewH) -- 833
			ui.position = Vec2(0, 0) -- 834
			gestureLayer.size = Size(viewW, viewH) -- 835
			topBar.size = Size(viewW, 120) -- 836
			topBar.position = Vec2(0, viewH - 120) -- 837
			setLabelCenter(titleLabel, 24, 84) -- 838
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 839
			if replayIntroBtn ~= nil then -- 839
				replayIntroBtn.root.position = Vec2(viewW - 160, 44) -- 841
			end -- 841
			layoutDock() -- 843
			layoutBriefCard() -- 844
		end, -- 830
		visible = function() return isVisible end -- 847
	} -- 847
	currentHubInstance = hub -- 849
	return hub -- 850
end -- 180
currentHubInstance = nil -- 853
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 856
	return currentHubInstance -- 857
end -- 856
return ____exports -- 856
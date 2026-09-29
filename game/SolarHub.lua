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
local ____LevelData = require("game.LevelData") -- 29
local getLevel = ____LevelData.getLevel -- 29
local levelCount = ____LevelData.levelCount -- 29
local ____Progress = require("game.Progress") -- 30
local getMissionRockets = ____Progress.getMissionRockets -- 30
local getTotalRockets = ____Progress.getTotalRockets -- 30
local ____Scene = require("game.Scene") -- 31
local applyPlanetTexture = ____Scene.applyPlanetTexture -- 32
local createProbe = ____Scene.createProbe -- 33
local createStarBackdrop = ____Scene.createStarBackdrop -- 34
local modelRadius = ____Scene.modelRadius -- 35
local planeToWorld = ____Scene.planeToWorld -- 36
local pointAntenna = ____Scene.pointAntenna -- 37
local probeYawForVelocity = ____Scene.probeYawForVelocity -- 38
local ____Projection = require("game.Projection") -- 41
local FLIP_Y = ____Projection.FLIP_Y -- 44
local HANDEDNESS = ____Projection.HANDEDNESS -- 45
local prepareCamera = ____Projection.prepareCamera -- 46
local projectPrepared = ____Projection.projectPrepared -- 47
local toOverlay = ____Projection.toOverlay -- 48
local ____Ui = require("game.Ui") -- 50
local createButton = ____Ui.createButton -- 52
local createLabel = ____Ui.createLabel -- 53
local createPanel = ____Ui.createPanel -- 54
local setLabelCenter = ____Ui.setLabelCenter -- 55
local setLabelColor = ____Ui.setLabelColor -- 56
local setLabelText = ____Ui.setLabelText -- 57
local setLabelVisible = ____Ui.setLabelVisible -- 58
local DegToRad = math.pi / 180 -- 61
--- 太阳系沙盘中的天体排布。
____exports.HUB_STATIONS = { -- 77
	{ -- 79
		model = "Planet_Mercury", -- 79
		radius = 0.85, -- 79
		orbit = 7.5, -- 79
		baseAngleDeg = 340, -- 79
		orbitSpeedDegPerSec = 4.2, -- 79
		rotSpeedDegPerSec = 5, -- 79
		colorHex = 10129286, -- 79
		emissiveHex = 0, -- 79
		levelIndex = 1 -- 79
	}, -- 79
	{ -- 81
		model = "Planet_Venus", -- 81
		radius = 1.6, -- 81
		orbit = 11.5, -- 81
		baseAngleDeg = 300, -- 81
		orbitSpeedDegPerSec = 2.8, -- 81
		rotSpeedDegPerSec = -2, -- 81
		colorHex = 15785134, -- 81
		emissiveHex = 0 -- 81
	}, -- 81
	{ -- 83
		model = "Planet_Earth", -- 83
		radius = 2.2, -- 83
		orbit = 17, -- 83
		baseAngleDeg = 262, -- 83
		orbitSpeedDegPerSec = 1.8, -- 83
		rotSpeedDegPerSec = 15, -- 83
		colorHex = 6003680, -- 83
		emissiveHex = 0, -- 83
		levelIndex = 0 -- 83
	}, -- 83
	{ -- 85
		model = "Planet_Mars", -- 85
		radius = 1.5, -- 85
		orbit = 22.5, -- 85
		baseAngleDeg = 318, -- 85
		orbitSpeedDegPerSec = 1.3, -- 85
		rotSpeedDegPerSec = 14, -- 85
		colorHex = 13664074, -- 85
		emissiveHex = 0 -- 85
	}, -- 85
	{ -- 87
		model = "Planet_Jupiter", -- 87
		radius = 4.6, -- 87
		orbit = 30, -- 87
		baseAngleDeg = 12, -- 87
		orbitSpeedDegPerSec = 0.8, -- 87
		rotSpeedDegPerSec = 25, -- 87
		colorHex = 14729362, -- 87
		emissiveHex = 0 -- 87
	}, -- 87
	{ -- 89
		model = "Planet_Saturn", -- 89
		radius = 3.2, -- 89
		orbit = 38.5, -- 89
		baseAngleDeg = 68, -- 89
		orbitSpeedDegPerSec = 0.5, -- 89
		rotSpeedDegPerSec = 22, -- 89
		colorHex = 13878426, -- 89
		emissiveHex = 0 -- 89
	}, -- 89
	{ -- 91
		model = "Planet_Uranus", -- 91
		radius = 2, -- 91
		orbit = 47, -- 91
		baseAngleDeg = 124, -- 91
		orbitSpeedDegPerSec = 0.35, -- 91
		rotSpeedDegPerSec = 12, -- 91
		colorHex = 11066852, -- 91
		emissiveHex = 0 -- 91
	}, -- 91
	{ -- 93
		model = "Planet_Neptune", -- 93
		radius = 1.9, -- 93
		orbit = 55, -- 93
		baseAngleDeg = 180, -- 93
		orbitSpeedDegPerSec = 0.25, -- 93
		rotSpeedDegPerSec = 11, -- 93
		colorHex = 8099312, -- 93
		emissiveHex = 0, -- 93
		levelIndex = 2 -- 93
	} -- 93
} -- 93
--- 关卡索引 -> HUB_STATIONS 下标的映射（L1 地球: 2, L2 水星: 0, L3 海王星: 7）。
____exports.LEVEL_TO_STATION_INDEX = {2, 0, 7} -- 97
--- 视觉配置常量。
local SunRadius = 4.8 -- 100
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 101
local OrbitRingsHex = 4153224 -- 102
local CardBgHex = 792102 -- 104
local CardBorderHex = 3033193 -- 105
local PrimaryBtnBgHex = 1921679 -- 106
local PrimaryBtnFgHex = 16777215 -- 107
local PrimaryBtnBorderHex = 6002142 -- 108
local SecondaryBtnBgHex = 1385011 -- 109
local SecondaryBtnFgHex = 10468571 -- 110
local SecondaryBtnBorderHex = 3691898 -- 111
local PinBgHex = 859957 -- 112
local PinBorderHex = 4289190 -- 113
local GoldStarHex = 16762939 -- 114
local DimStarHex = 5663877 -- 115
local function clampNumber(value, lo, hi) -- 117
	if value < lo then -- 117
		return lo -- 118
	end -- 118
	if value > hi then -- 118
		return hi -- 119
	end -- 119
	return value -- 120
end -- 117
local function lerp(a, b, t) -- 123
	return a + (b - a) * t -- 124
end -- 123
local function lerp3(a, b, t) -- 127
	return Vec3( -- 128
		lerp(a.x, b.x, t), -- 128
		lerp(a.y, b.y, t), -- 128
		lerp(a.z, b.z, t) -- 128
	) -- 128
end -- 127
--- 格式化火箭星级字符：如 2 枚火箭显示「★ ★ ☆」
function ____exports.formatRocketsString(count) -- 132
	local c = math.max( -- 133
		0, -- 133
		math.min( -- 133
			3, -- 133
			math.floor(count) -- 133
		) -- 133
	) -- 133
	if c == 0 then -- 133
		return "☆  ☆  ☆" -- 134
	end -- 134
	if c == 1 then -- 134
		return "★  ☆  ☆" -- 135
	end -- 135
	if c == 2 then -- 135
		return "★  ★  ☆" -- 136
	end -- 136
	return "★  ★  ★" -- 137
end -- 132
--- 创建微缩 3D 太阳系选关中心。
function ____exports.createSolarHub(options) -- 170
	local focusMission, backToPanorama, currentProgress -- 170
	local viewW = options.viewW -- 171
	local viewH = options.viewH -- 172
	local root = options.root -- 173
	local camera = options.camera -- 174
	local layer = options.layer -- 175
	local ui = Node() -- 178
	ui.size = Size(viewW, viewH) -- 179
	ui.anchor = Vec2(0, 0) -- 180
	ui.position = Vec2(0, 0) -- 181
	layer:addChild(ui) -- 182
	local sunLight = PointLight3D() -- 185
	sunLight.color = Color3(16774106) -- 186
	sunLight.intensity = 20 -- 187
	sunLight.range = 700 -- 188
	sunLight.position = Vec3(0, 0, 0) -- 189
	root:addChild(sunLight) -- 190
	local fillLight = DirectionalLight3D() -- 192
	fillLight.color = Color3(12243691) -- 193
	fillLight.intensity = 1.6 -- 194
	fillLight.angleX = -38 -- 195
	fillLight.angleY = 65 -- 196
	root:addChild(fillLight) -- 197
	local backdrop = createStarBackdrop(root) -- 199
	local sun = Model3D("Assets/Model/Sun.glb") -- 202
	if sun ~= nil then -- 202
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 204
		applyPlanetTexture(sun, "Sun", 0, 0) -- 205
		root:addChild(sun) -- 206
	end -- 206
	if Content:exist(OrbitRingsPath) then -- 206
		local rings = Model3D(OrbitRingsPath) -- 211
		if rings ~= nil then -- 211
			local rm = rings:getMaterial(0) -- 213
			if rm ~= nil then -- 213
				rm.baseColor = Color(0, 0, 0, 255) -- 215
				rm.emissive = Color3(OrbitRingsHex) -- 216
			end -- 216
			root:addChild(rings) -- 218
		end -- 218
	end -- 218
	local planets = {} -- 229
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 230
	do -- 230
		local i = 0 -- 232
		while i < #____exports.HUB_STATIONS do -- 232
			local st = ____exports.HUB_STATIONS[i + 1] -- 233
			local modelPath = st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb" -- 234
			local model = Model3D(modelPath) -- 235
			if model ~= nil then -- 235
				local scale = st.radius / modelRadius(st.model) -- 237
				model.scale = Vec3(scale, scale, scale) -- 238
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 239
				root:addChild(model) -- 240
				local a = st.baseAngleDeg * DegToRad -- 241
				local pos = { -- 242
					x = math.cos(a) * st.orbit, -- 242
					y = math.sin(a) * st.orbit -- 242
				} -- 242
				model.position = planeToWorld(pos, 0) -- 243
				planets[#planets + 1] = {station = st, node = model, currentAngleDeg = st.baseAngleDeg, currentPos = pos} -- 244
			end -- 244
			i = i + 1 -- 232
		end -- 232
	end -- 232
	local probeHandle = nil -- 254
	probeHandle = createProbe(root, { -- 255
		scale = 0.95, -- 256
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 257
		bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 258
		antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 259
		antennaPivotY = 0.6495, -- 260
		bodyRadius = 1.084, -- 261
		atlasPath = "Assets/Image/probe_atlas.jpg" -- 262
	}) -- 262
	local camMode = "panorama" -- 266
	local focusLevelIndex = -1 -- 267
	local panoYawDeg = 24 -- 270
	local panoPitchDeg = 36 -- 271
	local PanoDist = 230 -- 272
	local curEye = Vec3(0, 130, 190) -- 275
	local curTarget = Vec3(0, 0, 0) -- 276
	local targetEye = Vec3(0, 130, 190) -- 277
	local targetTarget = Vec3(0, 0, 0) -- 278
	--- 计算全景模式下的相机机位。
	local function calcPanoEye() -- 281
		local pitchRad = panoPitchDeg * DegToRad -- 282
		local yawRad = panoYawDeg * DegToRad -- 283
		local rHorizontal = PanoDist * math.cos(pitchRad) -- 284
		local y = PanoDist * math.sin(pitchRad) -- 285
		local x = rHorizontal * math.sin(yawRad) -- 286
		local z = rHorizontal * math.cos(yawRad) -- 287
		return Vec3(x, y, z) -- 288
	end -- 281
	--- 计算特写模式下的相机机位。
	local function calcFocusPose(stIndex) -- 292
		if stIndex == -1 then -- 292
			local dist = 22 -- 295
			return { -- 296
				eye = Vec3(0, dist * 0.42, dist * 0.9), -- 296
				target = Vec3(0, 0, 0) -- 296
			} -- 296
		end -- 296
		local h = planets[stIndex + 1] -- 298
		if h == nil then -- 298
			return { -- 299
				eye = calcPanoEye(), -- 299
				target = Vec3(0, 0, 0) -- 299
			} -- 299
		end -- 299
		local p = h.currentPos -- 300
		local t = planeToWorld(p, 0) -- 301
		local planetRadius = h.station.radius -- 302
		local dist = math.max(14, planetRadius * 4.2) -- 303
		local offsetAngle = (h.currentAngleDeg + 45) * DegToRad -- 304
		local eyeX = t.x + math.cos(offsetAngle) * dist * 0.85 -- 305
		local eyeY = t.y + dist * 0.55 -- 306
		local eyeZ = t.z + math.sin(offsetAngle) * dist * 0.85 -- 307
		return { -- 308
			eye = Vec3(eyeX, eyeY, eyeZ), -- 308
			target = t -- 308
		} -- 308
	end -- 292
	local gestureLayer = Node() -- 312
	gestureLayer.size = Size(viewW, viewH) -- 313
	gestureLayer.anchor = Vec2(0, 0) -- 314
	gestureLayer.position = Vec2(0, 0) -- 315
	gestureLayer.touchEnabled = false -- 316
	ui:addChild(gestureLayer) -- 317
	local isDragging = false -- 319
	local lastTouchPos = Vec2(0, 0) -- 320
	gestureLayer:onTapBegan(function(touch) -- 322
		isDragging = true -- 323
		lastTouchPos = touch.location -- 324
		return true -- 325
	end) -- 322
	gestureLayer:onTapMoved(function(touch) -- 328
		if not isDragging then -- 328
			return -- 329
		end -- 329
		local loc = touch.location -- 330
		local dx = loc.x - lastTouchPos.x -- 331
		local dy = loc.y - lastTouchPos.y -- 332
		lastTouchPos = loc -- 333
		if camMode == "panorama" then -- 333
			panoYawDeg = panoYawDeg - dx * 0.22 -- 336
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75) -- 337
			targetEye = calcPanoEye() -- 338
		end -- 338
	end) -- 328
	gestureLayer:onTapEnded(function() -- 342
		isDragging = false -- 343
	end) -- 342
	local pins = {} -- 355
	local PinW = 138 -- 357
	local PinH = 50 -- 358
	do -- 358
		local i = 0 -- 360
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 360
			local lvIndex = i -- 361
			local stIndex = ____exports.LEVEL_TO_STATION_INDEX[lvIndex + 1] -- 362
			local def = getLevel(lvIndex) -- 363
			local title = def ~= nil and def.title or "" -- 364
			local pinRoot = Node() -- 366
			pinRoot.size = Size(PinW, PinH) -- 367
			pinRoot.anchor = Vec2(0, 0) -- 368
			ui:addChild(pinRoot) -- 369
			local btn = createButton( -- 371
				pinRoot, -- 371
				{ -- 371
					w = PinW, -- 372
					h = PinH, -- 373
					text = "", -- 374
					fontSize = 18, -- 375
					bgHex = PinBgHex, -- 376
					fgHex = 16777215, -- 377
					borderHex = PinBorderHex, -- 378
					fireOn = "press", -- 379
					onTap = function() -- 380
						focusMission(lvIndex) -- 381
					end -- 380
				} -- 380
			) -- 380
			btn.root.position = Vec2(0, 0) -- 384
			local nameLabel = createLabel( -- 386
				btn.root, -- 386
				(("L" .. __TS__NumberToFixed(lvIndex + 1, 0)) .. " · ") .. title, -- 386
				18, -- 386
				15398143 -- 386
			) -- 386
			setLabelCenter(nameLabel, PinW / 2, PinH - 16) -- 387
			local rocketLabel = createLabel(btn.root, "☆  ☆  ☆", 15, GoldStarHex) -- 389
			setLabelCenter(rocketLabel, PinW / 2, 14) -- 390
			pins[#pins + 1] = { -- 392
				levelIndex = lvIndex, -- 393
				stIndex = stIndex, -- 394
				root = pinRoot, -- 395
				nameLabel = nameLabel, -- 396
				rocketLabel = rocketLabel, -- 397
				btn = btn -- 398
			} -- 398
			i = i + 1 -- 360
		end -- 360
	end -- 360
	local topBar = Node() -- 403
	topBar.size = Size(viewW, 90) -- 404
	topBar.anchor = Vec2(0, 0) -- 405
	topBar.position = Vec2(0, viewH - 90) -- 406
	ui:addChild(topBar) -- 407
	local titleLabel = createLabel(topBar, "深空航迹 · 太阳系沙盘", 32, 16777215) -- 409
	setLabelCenter(titleLabel, viewW / 2, 60) -- 410
	local totalRocketsLabel = createLabel(topBar, "全深空火箭勋章: 0 / 18 ★", 22, 10405355) -- 412
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 413
	local replayIntroBtn = nil -- 415
	if options.onReplayIntro ~= nil then -- 415
		replayIntroBtn = createButton( -- 417
			topBar, -- 417
			{ -- 417
				w = 130, -- 418
				h = 44, -- 419
				text = "重看开场", -- 420
				fontSize = 20, -- 421
				bgHex = SecondaryBtnBgHex, -- 422
				fgHex = SecondaryBtnFgHex, -- 423
				borderHex = SecondaryBtnBorderHex, -- 424
				fireOn = "press", -- 425
				onTap = function() -- 426
					if options.onReplayIntro ~= nil then -- 426
						options:onReplayIntro() -- 427
					end -- 427
				end -- 426
			} -- 426
		) -- 426
		replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 430
	end -- 430
	local dockNode = Node() -- 434
	dockNode.size = Size(viewW, 64) -- 435
	dockNode.anchor = Vec2(0, 0) -- 436
	dockNode.position = Vec2(0, 76) -- 437
	ui:addChild(dockNode) -- 438
	local dockButtons = {} -- 440
	local dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110) -- 441
	local dockBtnH = 50 -- 442
	local dockTotalW = dockBtnW * 6 + 10 * 5 -- 443
	local dockStartX = (viewW - dockTotalW) / 2 -- 444
	do -- 444
		local i = 0 -- 446
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 446
			local lvIndex = i -- 447
			local btn = createButton( -- 448
				dockNode, -- 448
				{ -- 448
					w = dockBtnW, -- 449
					h = dockBtnH, -- 450
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 451
					fontSize = 20, -- 452
					bgHex = PinBgHex, -- 453
					fgHex = 14084346, -- 454
					borderHex = PinBorderHex, -- 455
					fireOn = "press", -- 456
					onTap = function() -- 457
						focusMission(lvIndex) -- 458
					end -- 457
				} -- 457
			) -- 457
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0) -- 461
			dockButtons[#dockButtons + 1] = btn -- 462
			i = i + 1 -- 446
		end -- 446
	end -- 446
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 466
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 467
	local briefCard = createPanel( -- 469
		ui, -- 469
		cardW, -- 469
		cardH, -- 469
		CardBgHex, -- 469
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 469
	) -- 469
	briefCard.anchor = Vec2(0, 0) -- 474
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 475
	briefCard.visible = false -- 476
	local bTitleLabel = createLabel(briefCard, "", 28, 16777215) -- 478
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34) -- 479
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 481
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66) -- 482
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 484
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96) -- 485
	local challengeLabels = {} -- 488
	do -- 488
		local k = 0 -- 489
		while k < 3 do -- 489
			local cl = createLabel(briefCard, "", 19, 13689589) -- 490
			if cl ~= nil then -- 490
				cl.textWidth = cardW - 48 -- 492
				setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44) -- 493
				challengeLabels[#challengeLabels + 1] = cl -- 494
			end -- 494
			k = k + 1 -- 489
		end -- 489
	end -- 489
	local btnRowY = 22 -- 499
	local backBtnW = 120 -- 500
	local launchBtnW = cardW - backBtnW - 40 -- 501
	local btnH = 64 -- 502
	local backBtn = createButton( -- 504
		briefCard, -- 504
		{ -- 504
			w = backBtnW, -- 505
			h = btnH, -- 506
			text = "❮ 返回", -- 507
			fontSize = 22, -- 508
			bgHex = SecondaryBtnBgHex, -- 509
			fgHex = SecondaryBtnFgHex, -- 510
			borderHex = SecondaryBtnBorderHex, -- 511
			fireOn = "press", -- 512
			onTap = function() -- 513
				backToPanorama() -- 514
			end -- 513
		} -- 513
	) -- 513
	backBtn.root.position = Vec2(16, btnRowY) -- 517
	local launchBtn = createButton( -- 519
		briefCard, -- 519
		{ -- 519
			w = launchBtnW, -- 520
			h = btnH, -- 521
			text = "启动任务 / LAUNCH ★", -- 522
			fontSize = 24, -- 523
			bgHex = PrimaryBtnBgHex, -- 524
			fgHex = PrimaryBtnFgHex, -- 525
			borderHex = PrimaryBtnBorderHex, -- 526
			fireOn = "press", -- 527
			onTap = function() -- 528
				if focusLevelIndex >= 0 then -- 528
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 530
					options:onLaunch(focusLevelIndex) -- 531
				end -- 531
			end -- 528
		} -- 528
	) -- 528
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY) -- 535
	backBtn:setEnabled(false) -- 537
	launchBtn:setEnabled(false) -- 538
	local function updateBriefCard(levelIndex, progress) -- 541
		local lv = getLevel(levelIndex) -- 542
		if lv == nil then -- 542
			return -- 543
		end -- 543
		local m = lv.mission -- 544
		if m == nil then -- 544
			return -- 545
		end -- 545
		setLabelText( -- 547
			bTitleLabel, -- 547
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 547
		) -- 547
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 548
		local vehText = m.vehicle == "orbiter" and "【 轨道器型 · 具备变轨制动引擎 】" or "【 飞掠型探测器 · 深空高速引力借力 】" -- 550
		setLabelText(bVehicleLabel, vehText) -- 553
		setLabelColor(bVehicleLabel, m.vehicle == "orbiter" and 16766073 or 8381344) -- 554
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 556
		do -- 556
			local k = 0 -- 557
			while k < 3 do -- 557
				do -- 557
					local c = m.challenges[k + 1] -- 558
					if c == nil then -- 558
						setLabelVisible(challengeLabels[k + 1], false) -- 559
						goto __continue47 -- 559
					end -- 559
					setLabelVisible(challengeLabels[k + 1], true) -- 560
					local achieved = rocketsGot >= k + 1 -- 561
					local icon = achieved and "★" or "☆" -- 562
					local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 563
					local text = lv.transfer ~= nil and (rocketsGot >= 1 and "已完成 · " or "目标 · ") .. c.desc or (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 564
					setLabelText(challengeLabels[k + 1], text) -- 565
					setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 566
				end -- 566
				::__continue47:: -- 566
				k = k + 1 -- 557
			end -- 557
		end -- 557
	end -- 541
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 571
		camMode = "focus" -- 572
		focusLevelIndex = levelIndex -- 573
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 574
		local pose = calcFocusPose(stIndex) -- 575
		targetEye = pose.eye -- 576
		targetTarget = pose.target -- 577
		do -- 577
			local i = 0 -- 580
			while i < #pins do -- 580
				pins[i + 1].root.visible = false -- 581
				pins[i + 1].btn:setEnabled(false) -- 582
				i = i + 1 -- 580
			end -- 580
		end -- 580
		dockNode.visible = false -- 584
		do -- 584
			local i = 0 -- 585
			while i < #dockButtons do -- 585
				dockButtons[i + 1]:setEnabled(false) -- 585
				i = i + 1 -- 585
			end -- 585
		end -- 585
		briefCard.visible = true -- 588
		backBtn:setEnabled(true) -- 589
		launchBtn:setEnabled(true) -- 590
		local curProg = currentProgress -- 593
		if curProg ~= nil then -- 593
			updateBriefCard(levelIndex, curProg) -- 594
		end -- 594
	end -- 571
	--- 返回全景模式。
	backToPanorama = function() -- 598
		camMode = "panorama" -- 599
		focusLevelIndex = -1 -- 600
		targetEye = calcPanoEye() -- 601
		targetTarget = Vec3(0, 0, 0) -- 602
		do -- 602
			local i = 0 -- 605
			while i < #pins do -- 605
				pins[i + 1].root.visible = true -- 606
				pins[i + 1].btn:setEnabled(true) -- 607
				i = i + 1 -- 605
			end -- 605
		end -- 605
		dockNode.visible = true -- 609
		do -- 609
			local i = 0 -- 610
			while i < #dockButtons do -- 610
				dockButtons[i + 1]:setEnabled(true) -- 610
				i = i + 1 -- 610
			end -- 610
		end -- 610
		briefCard.visible = false -- 613
		backBtn:setEnabled(false) -- 614
		launchBtn:setEnabled(false) -- 615
	end -- 598
	local isVisible = false -- 618
	currentProgress = nil -- 619
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 622
		currentProgress = prog -- 623
		local total = getTotalRockets( -- 624
			prog, -- 624
			levelCount() -- 624
		) -- 624
		setLabelText( -- 625
			totalRocketsLabel, -- 625
			((("全深空火箭勋章: " .. __TS__NumberToFixed(total, 0)) .. " / ") .. __TS__NumberToFixed( -- 625
				levelCount() * 3, -- 625
				0 -- 625
			)) .. " ★" -- 625
		) -- 625
		do -- 625
			local i = 0 -- 627
			while i < #pins do -- 627
				local p = pins[i + 1] -- 628
				local count = getMissionRockets(prog, p.levelIndex) -- 629
				local ____opt_0 = getLevel(p.levelIndex) -- 629
				local teaching = (____opt_0 and ____opt_0.transfer) ~= nil -- 630
				setLabelText( -- 631
					p.rocketLabel, -- 631
					teaching and (count > 0 and "已完成" or "转移练习") or ____exports.formatRocketsString(count) -- 631
				) -- 631
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 632
				dockButtons[i + 1]:setText((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (count > 0 and (teaching and "已完成" or __TS__NumberToFixed(count, 0) .. "★") or "")) -- 635
				i = i + 1 -- 627
			end -- 627
		end -- 627
	end -- 622
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 640
		do -- 640
			local i = 0 -- 642
			while i < #planets do -- 642
				local h = planets[i + 1] -- 643
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 644
				local rad = h.currentAngleDeg * DegToRad -- 645
				h.currentPos = { -- 646
					x = math.cos(rad) * h.station.orbit, -- 647
					y = math.sin(rad) * h.station.orbit -- 648
				} -- 648
				h.node.position = planeToWorld(h.currentPos, 0) -- 650
				local ____h_node_2, ____angleY_3 = h.node, "angleY" -- 650
				____h_node_2[____angleY_3] = ____h_node_2[____angleY_3] + h.station.rotSpeedDegPerSec * dt -- 651
				i = i + 1 -- 642
			end -- 642
		end -- 642
		if probeHandle ~= nil and planets[3] ~= nil then -- 642
			local earthPos = planets[3].currentPos -- 656
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 657
			local probeP = { -- 658
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 659
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 660
			} -- 660
			probeHandle.node.position = planeToWorld(probeP, 0) -- 662
			local vel = { -- 663
				x = -math.sin(probeAngle), -- 664
				y = math.cos(probeAngle) -- 665
			} -- 665
			local yaw = probeYawForVelocity(vel) -- 667
			if yaw ~= nil then -- 667
				probeHandle.node.angleY = yaw -- 668
			end -- 668
			if probeHandle.antenna ~= nil then -- 668
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 670
			end -- 670
		end -- 670
		if camMode == "panorama" and not isDragging then -- 670
			panoYawDeg = panoYawDeg + 0.035 -- 676
			targetEye = calcPanoEye() -- 677
		elseif camMode == "focus" then -- 677
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 680
			targetEye = pose.eye -- 681
			targetTarget = pose.target -- 682
		end -- 682
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 686
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 687
		camera:lookAt( -- 688
			curEye, -- 688
			curTarget, -- 688
			Vec3(0, 1, 0) -- 688
		) -- 688
		if backdrop ~= nil then -- 688
			backdrop:sync(curEye, curTarget) -- 689
		end -- 689
		if camMode == "panorama" then -- 689
			local camView = { -- 693
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 694
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 695
				up = {x = 0, y = 1, z = 0}, -- 696
				fovYDeg = options.fovYDeg, -- 697
				aspect = options.aspect, -- 698
				viewW = viewW, -- 699
				viewH = viewH -- 700
			} -- 700
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 702
			do -- 702
				local i = 0 -- 704
				while i < #pins do -- 704
					do -- 704
						local p = pins[i + 1] -- 705
						local worldPos -- 706
						local yOffset = 24 -- 707
						if p.stIndex == -1 then -- 707
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 710
							yOffset = 48 -- 711
						else -- 711
							local planetHandle = planets[p.stIndex + 1] -- 713
							if planetHandle == nil then -- 713
								goto __continue74 -- 714
							end -- 714
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 715
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 717
						end -- 717
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 720
						if proj ~= nil and proj.vz > 1 then -- 720
							p.root.visible = true -- 723
							local over = toOverlay(proj) -- 724
							local screenX = viewW / 2 + over.x -- 726
							local screenY = viewH / 2 + over.y -- 727
							p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset) -- 728
						else -- 728
							p.root.visible = false -- 730
						end -- 730
					end -- 730
					::__continue74:: -- 730
					i = i + 1 -- 704
				end -- 704
			end -- 704
		end -- 704
	end -- 640
	local hub = { -- 736
		show = function(prog) -- 737
			isVisible = true -- 738
			root.visible = true -- 739
			ui.visible = true -- 740
			gestureLayer.touchEnabled = true -- 741
			refreshRocketsDisplay(prog) -- 743
			backToPanorama() -- 744
			curEye = calcPanoEye() -- 746
			curTarget = Vec3(0, 0, 0) -- 747
			targetEye = curEye -- 748
			targetTarget = curTarget -- 749
			camera:lookAt( -- 750
				curEye, -- 750
				curTarget, -- 750
				Vec3(0, 1, 0) -- 750
			) -- 750
			doStep(0) -- 753
		end, -- 737
		hide = function() -- 756
			isVisible = false -- 757
			root.visible = false -- 758
			ui.visible = false -- 759
			gestureLayer.touchEnabled = false -- 760
			do -- 760
				local i = 0 -- 762
				while i < #pins do -- 762
					pins[i + 1].btn:setEnabled(false) -- 762
					i = i + 1 -- 762
				end -- 762
			end -- 762
			do -- 762
				local i = 0 -- 763
				while i < #dockButtons do -- 763
					dockButtons[i + 1]:setEnabled(false) -- 763
					i = i + 1 -- 763
				end -- 763
			end -- 763
			if replayIntroBtn ~= nil then -- 763
				replayIntroBtn:setEnabled(false) -- 764
			end -- 764
			backBtn:setEnabled(false) -- 765
			launchBtn:setEnabled(false) -- 766
		end, -- 756
		step = function(dt) -- 769
			if not isVisible then -- 769
				return -- 770
			end -- 770
			doStep(dt) -- 771
		end, -- 769
		focusMission = function(levelIndex) -- 774
			focusMission(levelIndex) -- 775
		end, -- 774
		backToPanorama = function() -- 778
			backToPanorama() -- 779
		end, -- 778
		launchCurrentMission = function() -- 782
			if focusLevelIndex >= 0 then -- 782
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 784
				options:onLaunch(focusLevelIndex) -- 785
			end -- 785
		end, -- 782
		relayout = function(w, h) -- 789
			viewW = w -- 790
			viewH = h -- 791
			ui.size = Size(viewW, viewH) -- 792
			ui.position = Vec2(0, 0) -- 793
			gestureLayer.size = Size(viewW, viewH) -- 794
			topBar.size = Size(viewW, 90) -- 795
			topBar.position = Vec2(0, viewH - 90) -- 796
			setLabelCenter(titleLabel, viewW / 2, 60) -- 797
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 798
			if replayIntroBtn ~= nil then -- 798
				replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 800
			end -- 800
			dockNode.position = Vec2(0, 76) -- 802
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 803
		end, -- 789
		visible = function() return isVisible end -- 806
	} -- 806
	currentHubInstance = hub -- 808
	return hub -- 809
end -- 170
currentHubInstance = nil -- 812
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 815
	return currentHubInstance -- 816
end -- 815
return ____exports -- 815
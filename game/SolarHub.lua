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
local DegToRad = math.pi / 180 -- 60
--- 太阳系沙盘中的天体排布。
____exports.HUB_STATIONS = { -- 76
	{ -- 78
		model = "Sphere", -- 78
		radius = 0.85, -- 78
		orbit = 7.5, -- 78
		baseAngleDeg = 340, -- 78
		orbitSpeedDegPerSec = 4.2, -- 78
		rotSpeedDegPerSec = 5, -- 78
		colorHex = 10129286, -- 78
		emissiveHex = 0 -- 78
	}, -- 78
	{ -- 80
		model = "Planet_Venus", -- 80
		radius = 1.6, -- 80
		orbit = 11.5, -- 80
		baseAngleDeg = 300, -- 80
		orbitSpeedDegPerSec = 2.8, -- 80
		rotSpeedDegPerSec = -2, -- 80
		colorHex = 15785134, -- 80
		emissiveHex = 0, -- 80
		levelIndex = 1 -- 80
	}, -- 80
	{ -- 82
		model = "Planet_Earth", -- 82
		radius = 2.2, -- 82
		orbit = 17, -- 82
		baseAngleDeg = 262, -- 82
		orbitSpeedDegPerSec = 1.8, -- 82
		rotSpeedDegPerSec = 15, -- 82
		colorHex = 6003680, -- 82
		emissiveHex = 0, -- 82
		levelIndex = 0 -- 82
	}, -- 82
	{ -- 84
		model = "Planet_Mars", -- 84
		radius = 1.5, -- 84
		orbit = 22.5, -- 84
		baseAngleDeg = 318, -- 84
		orbitSpeedDegPerSec = 1.3, -- 84
		rotSpeedDegPerSec = 14, -- 84
		colorHex = 13664074, -- 84
		emissiveHex = 0 -- 84
	}, -- 84
	{ -- 86
		model = "Planet_Jupiter", -- 86
		radius = 4.6, -- 86
		orbit = 30, -- 86
		baseAngleDeg = 12, -- 86
		orbitSpeedDegPerSec = 0.8, -- 86
		rotSpeedDegPerSec = 25, -- 86
		colorHex = 14729362, -- 86
		emissiveHex = 0, -- 86
		levelIndex = 2 -- 86
	}, -- 86
	{ -- 88
		model = "Planet_Saturn", -- 88
		radius = 3.2, -- 88
		orbit = 38.5, -- 88
		baseAngleDeg = 68, -- 88
		orbitSpeedDegPerSec = 0.5, -- 88
		rotSpeedDegPerSec = 22, -- 88
		colorHex = 13878426, -- 88
		emissiveHex = 0, -- 88
		levelIndex = 3 -- 88
	}, -- 88
	{ -- 90
		model = "Planet_Uranus", -- 90
		radius = 2, -- 90
		orbit = 47, -- 90
		baseAngleDeg = 124, -- 90
		orbitSpeedDegPerSec = 0.35, -- 90
		rotSpeedDegPerSec = 12, -- 90
		colorHex = 11066852, -- 90
		emissiveHex = 0, -- 90
		levelIndex = 4 -- 90
	}, -- 90
	{ -- 92
		model = "Planet_Neptune", -- 92
		radius = 1.9, -- 92
		orbit = 55, -- 92
		baseAngleDeg = 180, -- 92
		orbitSpeedDegPerSec = 0.25, -- 92
		rotSpeedDegPerSec = 11, -- 92
		colorHex = 8099312, -- 92
		emissiveHex = 0, -- 92
		levelIndex = 5 -- 92
	} -- 92
} -- 92
--- 关卡索引 -> HUB_STATIONS 下标的映射。
____exports.LEVEL_TO_STATION_INDEX = { -- 96
	2, -- 96
	1, -- 96
	4, -- 96
	5, -- 96
	6, -- 96
	7 -- 96
} -- 96
--- 视觉配置常量。
local SunRadius = 4.8 -- 99
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 100
local OrbitRingsHex = 4153224 -- 101
local CardBgHex = 792102 -- 103
local CardBorderHex = 3033193 -- 104
local PrimaryBtnBgHex = 1921679 -- 105
local PrimaryBtnFgHex = 16777215 -- 106
local PrimaryBtnBorderHex = 6002142 -- 107
local SecondaryBtnBgHex = 1385011 -- 108
local SecondaryBtnFgHex = 10468571 -- 109
local SecondaryBtnBorderHex = 3691898 -- 110
local PinBgHex = 859957 -- 111
local PinBorderHex = 4289190 -- 112
local GoldStarHex = 16762939 -- 113
local DimStarHex = 5663877 -- 114
local function clampNumber(value, lo, hi) -- 116
	if value < lo then -- 116
		return lo -- 117
	end -- 117
	if value > hi then -- 117
		return hi -- 118
	end -- 118
	return value -- 119
end -- 116
local function lerp(a, b, t) -- 122
	return a + (b - a) * t -- 123
end -- 122
local function lerp3(a, b, t) -- 126
	return Vec3( -- 127
		lerp(a.x, b.x, t), -- 127
		lerp(a.y, b.y, t), -- 127
		lerp(a.z, b.z, t) -- 127
	) -- 127
end -- 126
--- 格式化火箭星级字符：如 2 枚火箭显示「★ ★ ☆」
function ____exports.formatRocketsString(count) -- 131
	local c = math.max( -- 132
		0, -- 132
		math.min( -- 132
			3, -- 132
			math.floor(count) -- 132
		) -- 132
	) -- 132
	if c == 0 then -- 132
		return "☆  ☆  ☆" -- 133
	end -- 133
	if c == 1 then -- 133
		return "★  ☆  ☆" -- 134
	end -- 134
	if c == 2 then -- 134
		return "★  ★  ☆" -- 135
	end -- 135
	return "★  ★  ★" -- 136
end -- 131
--- 创建微缩 3D 太阳系选关中心。
function ____exports.createSolarHub(options) -- 169
	local focusMission, backToPanorama, currentProgress -- 169
	local viewW = options.viewW -- 170
	local viewH = options.viewH -- 171
	local root = options.root -- 172
	local camera = options.camera -- 173
	local layer = options.layer -- 174
	local ui = Node() -- 177
	ui.size = Size(viewW, viewH) -- 178
	ui.anchor = Vec2(0, 0) -- 179
	ui.position = Vec2(0, 0) -- 180
	layer:addChild(ui) -- 181
	local sunLight = PointLight3D() -- 184
	sunLight.color = Color3(16774106) -- 185
	sunLight.intensity = 20 -- 186
	sunLight.range = 700 -- 187
	sunLight.position = Vec3(0, 0, 0) -- 188
	root:addChild(sunLight) -- 189
	local fillLight = DirectionalLight3D() -- 191
	fillLight.color = Color3(12243691) -- 192
	fillLight.intensity = 1.6 -- 193
	fillLight.angleX = -38 -- 194
	fillLight.angleY = 65 -- 195
	root:addChild(fillLight) -- 196
	local backdrop = createStarBackdrop(root) -- 198
	local sun = Model3D("Assets/Model/Sun.glb") -- 201
	if sun ~= nil then -- 201
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 203
		applyPlanetTexture(sun, "Sun", 0, 0) -- 204
		root:addChild(sun) -- 205
	end -- 205
	if Content:exist(OrbitRingsPath) then -- 205
		local rings = Model3D(OrbitRingsPath) -- 210
		if rings ~= nil then -- 210
			local rm = rings:getMaterial(0) -- 212
			if rm ~= nil then -- 212
				rm.baseColor = Color(0, 0, 0, 255) -- 214
				rm.emissive = Color3(OrbitRingsHex) -- 215
			end -- 215
			root:addChild(rings) -- 217
		end -- 217
	end -- 217
	local planets = {} -- 228
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 229
	do -- 229
		local i = 0 -- 231
		while i < #____exports.HUB_STATIONS do -- 231
			local st = ____exports.HUB_STATIONS[i + 1] -- 232
			local modelPath = st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb" -- 233
			local model = Model3D(modelPath) -- 234
			if model ~= nil then -- 234
				local scale = st.radius / modelRadius(st.model) -- 236
				model.scale = Vec3(scale, scale, scale) -- 237
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 238
				root:addChild(model) -- 239
				local a = st.baseAngleDeg * DegToRad -- 240
				local pos = { -- 241
					x = math.cos(a) * st.orbit, -- 241
					y = math.sin(a) * st.orbit -- 241
				} -- 241
				model.position = planeToWorld(pos, 0) -- 242
				planets[#planets + 1] = {station = st, node = model, currentAngleDeg = st.baseAngleDeg, currentPos = pos} -- 243
			end -- 243
			i = i + 1 -- 231
		end -- 231
	end -- 231
	local probeHandle = nil -- 253
	probeHandle = createProbe(root, { -- 254
		scale = 0.95, -- 255
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 256
		bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 257
		antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 258
		antennaPivotY = 0.6495, -- 259
		bodyRadius = 1.084, -- 260
		atlasPath = "Assets/Image/probe_atlas.jpg" -- 261
	}) -- 261
	local camMode = "panorama" -- 265
	local focusLevelIndex = -1 -- 266
	local panoYawDeg = 24 -- 269
	local panoPitchDeg = 36 -- 270
	local PanoDist = 230 -- 271
	local curEye = Vec3(0, 130, 190) -- 274
	local curTarget = Vec3(0, 0, 0) -- 275
	local targetEye = Vec3(0, 130, 190) -- 276
	local targetTarget = Vec3(0, 0, 0) -- 277
	--- 计算全景模式下的相机机位。
	local function calcPanoEye() -- 280
		local pitchRad = panoPitchDeg * DegToRad -- 281
		local yawRad = panoYawDeg * DegToRad -- 282
		local rHorizontal = PanoDist * math.cos(pitchRad) -- 283
		local y = PanoDist * math.sin(pitchRad) -- 284
		local x = rHorizontal * math.sin(yawRad) -- 285
		local z = rHorizontal * math.cos(yawRad) -- 286
		return Vec3(x, y, z) -- 287
	end -- 280
	--- 计算特写模式下的相机机位。
	local function calcFocusPose(stIndex) -- 291
		local h = planets[stIndex + 1] -- 292
		if h == nil then -- 292
			return { -- 293
				eye = calcPanoEye(), -- 293
				target = Vec3(0, 0, 0) -- 293
			} -- 293
		end -- 293
		local p = h.currentPos -- 294
		local t = planeToWorld(p, 0) -- 295
		local planetRadius = h.station.radius -- 296
		local dist = math.max(14, planetRadius * 4.2) -- 297
		local offsetAngle = (h.currentAngleDeg + 45) * DegToRad -- 298
		local eyeX = t.x + math.cos(offsetAngle) * dist * 0.85 -- 299
		local eyeY = t.y + dist * 0.55 -- 300
		local eyeZ = t.z + math.sin(offsetAngle) * dist * 0.85 -- 301
		return { -- 302
			eye = Vec3(eyeX, eyeY, eyeZ), -- 302
			target = t -- 302
		} -- 302
	end -- 291
	local gestureLayer = Node() -- 306
	gestureLayer.size = Size(viewW, viewH) -- 307
	gestureLayer.anchor = Vec2(0, 0) -- 308
	gestureLayer.position = Vec2(0, 0) -- 309
	gestureLayer.touchEnabled = false -- 310
	ui:addChild(gestureLayer) -- 311
	local isDragging = false -- 313
	local lastTouchPos = Vec2(0, 0) -- 314
	gestureLayer:onTapBegan(function(touch) -- 316
		isDragging = true -- 317
		lastTouchPos = touch.location -- 318
		return true -- 319
	end) -- 316
	gestureLayer:onTapMoved(function(touch) -- 322
		if not isDragging then -- 322
			return -- 323
		end -- 323
		local loc = touch.location -- 324
		local dx = loc.x - lastTouchPos.x -- 325
		local dy = loc.y - lastTouchPos.y -- 326
		lastTouchPos = loc -- 327
		if camMode == "panorama" then -- 327
			panoYawDeg = panoYawDeg - dx * 0.22 -- 330
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75) -- 331
			targetEye = calcPanoEye() -- 332
		end -- 332
	end) -- 322
	gestureLayer:onTapEnded(function() -- 336
		isDragging = false -- 337
	end) -- 336
	local pins = {} -- 349
	local PinW = 138 -- 351
	local PinH = 50 -- 352
	do -- 352
		local i = 0 -- 354
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 354
			local lvIndex = i -- 355
			local stIndex = ____exports.LEVEL_TO_STATION_INDEX[lvIndex + 1] -- 356
			local def = getLevel(lvIndex) -- 357
			local title = def ~= nil and def.title or "" -- 358
			local pinRoot = Node() -- 360
			pinRoot.size = Size(PinW, PinH) -- 361
			pinRoot.anchor = Vec2(0, 0) -- 362
			ui:addChild(pinRoot) -- 363
			local btn = createButton( -- 365
				pinRoot, -- 365
				{ -- 365
					w = PinW, -- 366
					h = PinH, -- 367
					text = "", -- 368
					fontSize = 18, -- 369
					bgHex = PinBgHex, -- 370
					fgHex = 16777215, -- 371
					borderHex = PinBorderHex, -- 372
					fireOn = "press", -- 373
					onTap = function() -- 374
						focusMission(lvIndex) -- 375
					end -- 374
				} -- 374
			) -- 374
			btn.root.position = Vec2(0, 0) -- 378
			local nameLabel = createLabel( -- 380
				btn.root, -- 380
				(("L" .. __TS__NumberToFixed(lvIndex + 1, 0)) .. " · ") .. title, -- 380
				18, -- 380
				15398143 -- 380
			) -- 380
			setLabelCenter(nameLabel, PinW / 2, PinH - 16) -- 381
			local rocketLabel = createLabel(btn.root, "☆  ☆  ☆", 15, GoldStarHex) -- 383
			setLabelCenter(rocketLabel, PinW / 2, 14) -- 384
			pins[#pins + 1] = { -- 386
				levelIndex = lvIndex, -- 387
				stIndex = stIndex, -- 388
				root = pinRoot, -- 389
				nameLabel = nameLabel, -- 390
				rocketLabel = rocketLabel, -- 391
				btn = btn -- 392
			} -- 392
			i = i + 1 -- 354
		end -- 354
	end -- 354
	local topBar = Node() -- 397
	topBar.size = Size(viewW, 90) -- 398
	topBar.anchor = Vec2(0, 0) -- 399
	topBar.position = Vec2(0, viewH - 90) -- 400
	ui:addChild(topBar) -- 401
	local titleLabel = createLabel(topBar, "深空航迹 · 太阳系沙盘", 32, 16777215) -- 403
	setLabelCenter(titleLabel, viewW / 2, 60) -- 404
	local totalRocketsLabel = createLabel(topBar, "全深空火箭勋章: 0 / 18 ★", 22, 10405355) -- 406
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 407
	local replayIntroBtn = nil -- 409
	if options.onReplayIntro ~= nil then -- 409
		replayIntroBtn = createButton( -- 411
			topBar, -- 411
			{ -- 411
				w = 130, -- 412
				h = 44, -- 413
				text = "重看开场", -- 414
				fontSize = 20, -- 415
				bgHex = SecondaryBtnBgHex, -- 416
				fgHex = SecondaryBtnFgHex, -- 417
				borderHex = SecondaryBtnBorderHex, -- 418
				fireOn = "press", -- 419
				onTap = function() -- 420
					if options.onReplayIntro ~= nil then -- 420
						options:onReplayIntro() -- 421
					end -- 421
				end -- 420
			} -- 420
		) -- 420
		replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 424
	end -- 424
	local dockNode = Node() -- 428
	dockNode.size = Size(viewW, 64) -- 429
	dockNode.anchor = Vec2(0, 0) -- 430
	dockNode.position = Vec2(0, 76) -- 431
	ui:addChild(dockNode) -- 432
	local dockButtons = {} -- 434
	local dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110) -- 435
	local dockBtnH = 50 -- 436
	local dockTotalW = dockBtnW * 6 + 10 * 5 -- 437
	local dockStartX = (viewW - dockTotalW) / 2 -- 438
	do -- 438
		local i = 0 -- 440
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 440
			local lvIndex = i -- 441
			local btn = createButton( -- 442
				dockNode, -- 442
				{ -- 442
					w = dockBtnW, -- 443
					h = dockBtnH, -- 444
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 445
					fontSize = 20, -- 446
					bgHex = PinBgHex, -- 447
					fgHex = 14084346, -- 448
					borderHex = PinBorderHex, -- 449
					fireOn = "press", -- 450
					onTap = function() -- 451
						focusMission(lvIndex) -- 452
					end -- 451
				} -- 451
			) -- 451
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0) -- 455
			dockButtons[#dockButtons + 1] = btn -- 456
			i = i + 1 -- 440
		end -- 440
	end -- 440
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 460
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 461
	local briefCard = createPanel( -- 463
		ui, -- 463
		cardW, -- 463
		cardH, -- 463
		CardBgHex, -- 463
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 463
	) -- 463
	briefCard.anchor = Vec2(0, 0) -- 468
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 469
	briefCard.visible = false -- 470
	local bTitleLabel = createLabel(briefCard, "", 28, 16777215) -- 472
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34) -- 473
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 475
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66) -- 476
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 478
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96) -- 479
	local challengeLabels = {} -- 482
	do -- 482
		local k = 0 -- 483
		while k < 3 do -- 483
			local cl = createLabel(briefCard, "", 19, 13689589) -- 484
			if cl ~= nil then -- 484
				cl.textWidth = cardW - 48 -- 486
				setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44) -- 487
				challengeLabels[#challengeLabels + 1] = cl -- 488
			end -- 488
			k = k + 1 -- 483
		end -- 483
	end -- 483
	local btnRowY = 22 -- 493
	local backBtnW = 120 -- 494
	local launchBtnW = cardW - backBtnW - 40 -- 495
	local btnH = 64 -- 496
	local backBtn = createButton( -- 498
		briefCard, -- 498
		{ -- 498
			w = backBtnW, -- 499
			h = btnH, -- 500
			text = "❮ 返回", -- 501
			fontSize = 22, -- 502
			bgHex = SecondaryBtnBgHex, -- 503
			fgHex = SecondaryBtnFgHex, -- 504
			borderHex = SecondaryBtnBorderHex, -- 505
			fireOn = "press", -- 506
			onTap = function() -- 507
				backToPanorama() -- 508
			end -- 507
		} -- 507
	) -- 507
	backBtn.root.position = Vec2(16, btnRowY) -- 511
	local launchBtn = createButton( -- 513
		briefCard, -- 513
		{ -- 513
			w = launchBtnW, -- 514
			h = btnH, -- 515
			text = "启动任务 / LAUNCH ★", -- 516
			fontSize = 24, -- 517
			bgHex = PrimaryBtnBgHex, -- 518
			fgHex = PrimaryBtnFgHex, -- 519
			borderHex = PrimaryBtnBorderHex, -- 520
			fireOn = "press", -- 521
			onTap = function() -- 522
				if focusLevelIndex >= 0 then -- 522
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 524
					options:onLaunch(focusLevelIndex) -- 525
				end -- 525
			end -- 522
		} -- 522
	) -- 522
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY) -- 529
	backBtn:setEnabled(false) -- 531
	launchBtn:setEnabled(false) -- 532
	local function updateBriefCard(levelIndex, progress) -- 535
		local lv = getLevel(levelIndex) -- 536
		if lv == nil then -- 536
			return -- 537
		end -- 537
		local m = lv.mission -- 538
		if m == nil then -- 538
			return -- 539
		end -- 539
		setLabelText( -- 541
			bTitleLabel, -- 541
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 541
		) -- 541
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 542
		local vehText = m.vehicle == "orbiter" and "【 轨道器型 · 具备变轨制动引擎 】" or "【 飞掠型探测器 · 深空高速引力借力 】" -- 544
		setLabelText(bVehicleLabel, vehText) -- 547
		setLabelColor(bVehicleLabel, m.vehicle == "orbiter" and 16766073 or 8381344) -- 548
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 550
		do -- 550
			local k = 0 -- 551
			while k < 3 do -- 551
				local c = m.challenges[k + 1] -- 552
				local achieved = rocketsGot >= k + 1 -- 553
				local icon = achieved and "★" or "☆" -- 554
				local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 555
				local text = (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 556
				setLabelText(challengeLabels[k + 1], text) -- 557
				setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 558
				k = k + 1 -- 551
			end -- 551
		end -- 551
	end -- 535
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 563
		camMode = "focus" -- 564
		focusLevelIndex = levelIndex -- 565
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 566
		local pose = calcFocusPose(stIndex) -- 567
		targetEye = pose.eye -- 568
		targetTarget = pose.target -- 569
		do -- 569
			local i = 0 -- 572
			while i < #pins do -- 572
				pins[i + 1].root.visible = false -- 573
				pins[i + 1].btn:setEnabled(false) -- 574
				i = i + 1 -- 572
			end -- 572
		end -- 572
		dockNode.visible = false -- 576
		do -- 576
			local i = 0 -- 577
			while i < #dockButtons do -- 577
				dockButtons[i + 1]:setEnabled(false) -- 577
				i = i + 1 -- 577
			end -- 577
		end -- 577
		briefCard.visible = true -- 580
		backBtn:setEnabled(true) -- 581
		launchBtn:setEnabled(true) -- 582
		local curProg = currentProgress -- 585
		if curProg ~= nil then -- 585
			updateBriefCard(levelIndex, curProg) -- 586
		end -- 586
	end -- 563
	--- 返回全景模式。
	backToPanorama = function() -- 590
		camMode = "panorama" -- 591
		focusLevelIndex = -1 -- 592
		targetEye = calcPanoEye() -- 593
		targetTarget = Vec3(0, 0, 0) -- 594
		do -- 594
			local i = 0 -- 597
			while i < #pins do -- 597
				pins[i + 1].root.visible = true -- 598
				pins[i + 1].btn:setEnabled(true) -- 599
				i = i + 1 -- 597
			end -- 597
		end -- 597
		dockNode.visible = true -- 601
		do -- 601
			local i = 0 -- 602
			while i < #dockButtons do -- 602
				dockButtons[i + 1]:setEnabled(true) -- 602
				i = i + 1 -- 602
			end -- 602
		end -- 602
		briefCard.visible = false -- 605
		backBtn:setEnabled(false) -- 606
		launchBtn:setEnabled(false) -- 607
	end -- 590
	local isVisible = false -- 610
	currentProgress = nil -- 611
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 614
		currentProgress = prog -- 615
		local total = getTotalRockets( -- 616
			prog, -- 616
			levelCount() -- 616
		) -- 616
		setLabelText( -- 617
			totalRocketsLabel, -- 617
			("全深空火箭勋章: " .. __TS__NumberToFixed(total, 0)) .. " / 18 ★" -- 617
		) -- 617
		do -- 617
			local i = 0 -- 619
			while i < #pins do -- 619
				local p = pins[i + 1] -- 620
				local count = getMissionRockets(prog, p.levelIndex) -- 621
				setLabelText( -- 622
					p.rocketLabel, -- 622
					____exports.formatRocketsString(count) -- 622
				) -- 622
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 623
				dockButtons[i + 1]:setText((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (count > 0 and __TS__NumberToFixed(count, 0) .. "★" or "")) -- 626
				i = i + 1 -- 619
			end -- 619
		end -- 619
	end -- 614
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 631
		do -- 631
			local i = 0 -- 633
			while i < #planets do -- 633
				local h = planets[i + 1] -- 634
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 635
				local rad = h.currentAngleDeg * DegToRad -- 636
				h.currentPos = { -- 637
					x = math.cos(rad) * h.station.orbit, -- 638
					y = math.sin(rad) * h.station.orbit -- 639
				} -- 639
				h.node.position = planeToWorld(h.currentPos, 0) -- 641
				local ____h_node_0, ____angleY_1 = h.node, "angleY" -- 641
				____h_node_0[____angleY_1] = ____h_node_0[____angleY_1] + h.station.rotSpeedDegPerSec * dt -- 642
				i = i + 1 -- 633
			end -- 633
		end -- 633
		if probeHandle ~= nil and planets[3] ~= nil then -- 633
			local earthPos = planets[3].currentPos -- 647
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 648
			local probeP = { -- 649
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 650
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 651
			} -- 651
			probeHandle.node.position = planeToWorld(probeP, 0) -- 653
			local vel = { -- 654
				x = -math.sin(probeAngle), -- 655
				y = math.cos(probeAngle) -- 656
			} -- 656
			local yaw = probeYawForVelocity(vel) -- 658
			if yaw ~= nil then -- 658
				probeHandle.node.angleY = yaw -- 659
			end -- 659
			if probeHandle.antenna ~= nil then -- 659
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 661
			end -- 661
		end -- 661
		if camMode == "panorama" and not isDragging then -- 661
			panoYawDeg = panoYawDeg + 0.035 -- 667
			targetEye = calcPanoEye() -- 668
		elseif camMode == "focus" then -- 668
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 671
			targetEye = pose.eye -- 672
			targetTarget = pose.target -- 673
		end -- 673
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 677
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 678
		camera:lookAt( -- 679
			curEye, -- 679
			curTarget, -- 679
			Vec3(0, 1, 0) -- 679
		) -- 679
		if backdrop ~= nil then -- 679
			backdrop:sync(curEye, curTarget) -- 680
		end -- 680
		if camMode == "panorama" then -- 680
			local camView = { -- 684
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 685
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 686
				up = {x = 0, y = 1, z = 0}, -- 687
				fovYDeg = options.fovYDeg, -- 688
				aspect = options.aspect, -- 689
				viewW = viewW, -- 690
				viewH = viewH -- 691
			} -- 691
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 693
			do -- 693
				local i = 0 -- 695
				while i < #pins do -- 695
					do -- 695
						local p = pins[i + 1] -- 696
						local planetHandle = planets[p.stIndex + 1] -- 697
						if planetHandle == nil then -- 697
							goto __continue72 -- 698
						end -- 698
						local worldPos = planeToWorld(planetHandle.currentPos, 0) -- 700
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 701
						if proj ~= nil and proj.vz > 1 then -- 701
							p.root.visible = true -- 704
							local over = toOverlay(proj) -- 705
							local screenX = viewW / 2 + over.x -- 707
							local screenY = viewH / 2 + over.y -- 708
							local yOffset = p.stIndex == 2 and 40 or (p.stIndex == 1 and 16 or 24) -- 710
							p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset) -- 711
						else -- 711
							p.root.visible = false -- 713
						end -- 713
					end -- 713
					::__continue72:: -- 713
					i = i + 1 -- 695
				end -- 695
			end -- 695
		end -- 695
	end -- 631
	local hub = { -- 719
		show = function(prog) -- 720
			isVisible = true -- 721
			root.visible = true -- 722
			ui.visible = true -- 723
			gestureLayer.touchEnabled = true -- 724
			refreshRocketsDisplay(prog) -- 726
			backToPanorama() -- 727
			curEye = calcPanoEye() -- 729
			curTarget = Vec3(0, 0, 0) -- 730
			targetEye = curEye -- 731
			targetTarget = curTarget -- 732
			camera:lookAt( -- 733
				curEye, -- 733
				curTarget, -- 733
				Vec3(0, 1, 0) -- 733
			) -- 733
			doStep(0) -- 736
		end, -- 720
		hide = function() -- 739
			isVisible = false -- 740
			root.visible = false -- 741
			ui.visible = false -- 742
			gestureLayer.touchEnabled = false -- 743
			do -- 743
				local i = 0 -- 745
				while i < #pins do -- 745
					pins[i + 1].btn:setEnabled(false) -- 745
					i = i + 1 -- 745
				end -- 745
			end -- 745
			do -- 745
				local i = 0 -- 746
				while i < #dockButtons do -- 746
					dockButtons[i + 1]:setEnabled(false) -- 746
					i = i + 1 -- 746
				end -- 746
			end -- 746
			if replayIntroBtn ~= nil then -- 746
				replayIntroBtn:setEnabled(false) -- 747
			end -- 747
			backBtn:setEnabled(false) -- 748
			launchBtn:setEnabled(false) -- 749
		end, -- 739
		step = function(dt) -- 752
			if not isVisible then -- 752
				return -- 753
			end -- 753
			doStep(dt) -- 754
		end, -- 752
		focusMission = function(levelIndex) -- 757
			focusMission(levelIndex) -- 758
		end, -- 757
		backToPanorama = function() -- 761
			backToPanorama() -- 762
		end, -- 761
		launchCurrentMission = function() -- 765
			if focusLevelIndex >= 0 then -- 765
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 767
				options:onLaunch(focusLevelIndex) -- 768
			end -- 768
		end, -- 765
		relayout = function(w, h) -- 772
			viewW = w -- 773
			viewH = h -- 774
			ui.size = Size(viewW, viewH) -- 775
			ui.position = Vec2(0, 0) -- 776
			gestureLayer.size = Size(viewW, viewH) -- 777
			topBar.size = Size(viewW, 90) -- 778
			topBar.position = Vec2(0, viewH - 90) -- 779
			setLabelCenter(titleLabel, viewW / 2, 60) -- 780
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 781
			if replayIntroBtn ~= nil then -- 781
				replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 783
			end -- 783
			dockNode.position = Vec2(0, 76) -- 785
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 786
		end, -- 772
		visible = function() return isVisible end -- 789
	} -- 789
	currentHubInstance = hub -- 791
	return hub -- 792
end -- 169
currentHubInstance = nil -- 795
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 798
	return currentHubInstance -- 799
end -- 798
return ____exports -- 798
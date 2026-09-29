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
	do -- 144
		local i = 0 -- 145
		while i < count do -- 145
			local ____opt_0 = getLevel(i) -- 145
			if (____opt_0 and ____opt_0.transfer) == nil then -- 145
				return ((("全深空火箭勋章: " .. __TS__NumberToFixed( -- 147
					getTotalRockets(progress, count), -- 147
					0 -- 147
				)) .. " / ") .. __TS__NumberToFixed(count * 3, 0)) .. " ★" -- 147
			end -- 147
			if getMissionRockets(progress, i) > 0 then -- 147
				completed = completed + 1 -- 149
			end -- 149
			i = i + 1 -- 145
		end -- 145
	end -- 145
	return (("任务完成: " .. __TS__NumberToFixed(completed, 0)) .. " / ") .. __TS__NumberToFixed(count, 0) -- 151
end -- 142
--- 创建微缩 3D 太阳系选关中心。
function ____exports.createSolarHub(options) -- 184
	local focusMission, backToPanorama, currentProgress -- 184
	local viewW = options.viewW -- 185
	local viewH = options.viewH -- 186
	local root = options.root -- 187
	local camera = options.camera -- 188
	local layer = options.layer -- 189
	local ui = Node() -- 192
	ui.size = Size(viewW, viewH) -- 193
	ui.anchor = Vec2(0, 0) -- 194
	ui.position = Vec2(0, 0) -- 195
	layer:addChild(ui) -- 196
	local sunLight = PointLight3D() -- 199
	sunLight.color = Color3(16774106) -- 200
	sunLight.intensity = MiniSunLightIntensity -- 201
	sunLight.range = 700 -- 202
	sunLight.position = Vec3(0, 0, 0) -- 203
	root:addChild(sunLight) -- 204
	local fillLight = DirectionalLight3D() -- 206
	fillLight.color = Color3(12243691) -- 207
	fillLight.intensity = SunFillIntensity -- 208
	fillLight.angleX = -38 -- 209
	fillLight.angleY = 65 -- 210
	root:addChild(fillLight) -- 211
	local backdrop = createStarBackdrop(root) -- 213
	local sun = Model3D("Assets/Model/Sun.glb") -- 216
	if sun ~= nil then -- 216
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 218
		applyPlanetTexture(sun, "Sun", 0, 0) -- 219
		root:addChild(sun) -- 220
	end -- 220
	if Content:exist(OrbitRingsPath) then -- 220
		local rings = Model3D(OrbitRingsPath) -- 225
		if rings ~= nil then -- 225
			local rm = rings:getMaterial(0) -- 227
			if rm ~= nil then -- 227
				rm.baseColor = Color(0, 0, 0, 255) -- 229
				rm.emissive = Color3(OrbitRingsHex) -- 230
			end -- 230
			root:addChild(rings) -- 232
		end -- 232
	end -- 232
	local planets = {} -- 243
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 244
	do -- 244
		local i = 0 -- 246
		while i < #____exports.HUB_STATIONS do -- 246
			local st = ____exports.HUB_STATIONS[i + 1] -- 247
			local modelPath = st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb" -- 248
			local model = Model3D(modelPath) -- 249
			if model ~= nil then -- 249
				local scale = st.radius / modelRadius(st.model) -- 251
				model.scale = Vec3(scale, scale, scale) -- 252
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 253
				root:addChild(model) -- 254
				local a = st.baseAngleDeg * DegToRad -- 255
				local pos = { -- 256
					x = math.cos(a) * st.orbit, -- 256
					y = math.sin(a) * st.orbit -- 256
				} -- 256
				model.position = planeToWorld(pos, 0) -- 257
				planets[#planets + 1] = {station = st, node = model, currentAngleDeg = st.baseAngleDeg, currentPos = pos} -- 258
			end -- 258
			i = i + 1 -- 246
		end -- 246
	end -- 246
	local probeHandle = nil -- 268
	probeHandle = createProbe(root, { -- 269
		scale = 0.95, -- 270
		probePath = "Assets/Model/Probe_Voyager_v1.glb", -- 271
		bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 272
		antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 273
		antennaPivotY = 0.6495, -- 274
		bodyRadius = 1.084, -- 275
		atlasPath = "Assets/Image/probe_atlas.jpg" -- 276
	}) -- 276
	local camMode = "panorama" -- 280
	local focusLevelIndex = -1 -- 281
	local panoYawDeg = 24 -- 284
	local panoPitchDeg = 36 -- 285
	local PanoDist = 230 -- 286
	local curEye = Vec3(0, 130, 190) -- 289
	local curTarget = Vec3(0, 0, 0) -- 290
	local targetEye = Vec3(0, 130, 190) -- 291
	local targetTarget = Vec3(0, 0, 0) -- 292
	--- 计算全景模式下的相机机位。
	local function calcPanoEye() -- 295
		local pitchRad = panoPitchDeg * DegToRad -- 296
		local yawRad = panoYawDeg * DegToRad -- 297
		local rHorizontal = PanoDist * math.cos(pitchRad) -- 298
		local y = PanoDist * math.sin(pitchRad) -- 299
		local x = rHorizontal * math.sin(yawRad) -- 300
		local z = rHorizontal * math.cos(yawRad) -- 301
		return Vec3(x, y, z) -- 302
	end -- 295
	--- 计算特写模式下的相机机位。
	local function calcFocusPose(stIndex) -- 306
		if stIndex == -1 then -- 306
			local dist = 22 -- 309
			return { -- 310
				eye = Vec3(0, dist * 0.42, dist * 0.9), -- 310
				target = Vec3(0, 0, 0) -- 310
			} -- 310
		end -- 310
		local h = planets[stIndex + 1] -- 312
		if h == nil then -- 312
			return { -- 313
				eye = calcPanoEye(), -- 313
				target = Vec3(0, 0, 0) -- 313
			} -- 313
		end -- 313
		local p = h.currentPos -- 314
		local t = planeToWorld(p, 0) -- 315
		local planetRadius = h.station.radius -- 316
		local dist = math.max(14, planetRadius * 4.2) -- 317
		local offsetAngle = (h.currentAngleDeg + 45) * DegToRad -- 318
		local eyeX = t.x + math.cos(offsetAngle) * dist * 0.85 -- 319
		local eyeY = t.y + dist * 0.55 -- 320
		local eyeZ = t.z + math.sin(offsetAngle) * dist * 0.85 -- 321
		return { -- 322
			eye = Vec3(eyeX, eyeY, eyeZ), -- 322
			target = t -- 322
		} -- 322
	end -- 306
	local gestureLayer = Node() -- 326
	gestureLayer.size = Size(viewW, viewH) -- 327
	gestureLayer.anchor = Vec2(0, 0) -- 328
	gestureLayer.position = Vec2(0, 0) -- 329
	gestureLayer.touchEnabled = false -- 330
	ui:addChild(gestureLayer) -- 331
	local isDragging = false -- 333
	local lastTouchPos = Vec2(0, 0) -- 334
	gestureLayer:onTapBegan(function(touch) -- 336
		isDragging = true -- 337
		lastTouchPos = touch.location -- 338
		return true -- 339
	end) -- 336
	gestureLayer:onTapMoved(function(touch) -- 342
		if not isDragging then -- 342
			return -- 343
		end -- 343
		local loc = touch.location -- 344
		local dx = loc.x - lastTouchPos.x -- 345
		local dy = loc.y - lastTouchPos.y -- 346
		lastTouchPos = loc -- 347
		if camMode == "panorama" then -- 347
			panoYawDeg = panoYawDeg - dx * 0.22 -- 350
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75) -- 351
			targetEye = calcPanoEye() -- 352
		end -- 352
	end) -- 342
	gestureLayer:onTapEnded(function() -- 356
		isDragging = false -- 357
	end) -- 356
	local pins = {} -- 369
	local PinW = 138 -- 371
	local PinH = 50 -- 372
	do -- 372
		local i = 0 -- 374
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 374
			local lvIndex = i -- 375
			local stIndex = ____exports.LEVEL_TO_STATION_INDEX[lvIndex + 1] -- 376
			local def = getLevel(lvIndex) -- 377
			local title = def ~= nil and def.title or "" -- 378
			local pinRoot = Node() -- 380
			pinRoot.size = Size(PinW, PinH) -- 381
			pinRoot.anchor = Vec2(0, 0) -- 382
			ui:addChild(pinRoot) -- 383
			local btn = createButton( -- 385
				pinRoot, -- 385
				{ -- 385
					w = PinW, -- 386
					h = PinH, -- 387
					text = "", -- 388
					fontSize = 18, -- 389
					bgHex = PinBgHex, -- 390
					fgHex = 16777215, -- 391
					borderHex = PinBorderHex, -- 392
					fireOn = "press", -- 393
					onTap = function() -- 394
						focusMission(lvIndex) -- 395
					end -- 394
				} -- 394
			) -- 394
			btn.root.position = Vec2(0, 0) -- 398
			local nameLabel = createLabel( -- 400
				btn.root, -- 400
				(("L" .. __TS__NumberToFixed(lvIndex + 1, 0)) .. " · ") .. title, -- 400
				18, -- 400
				15398143 -- 400
			) -- 400
			setLabelCenter(nameLabel, PinW / 2, PinH - 16) -- 401
			local rocketLabel = createLabel(btn.root, "☆  ☆  ☆", 15, GoldStarHex) -- 403
			setLabelCenter(rocketLabel, PinW / 2, 14) -- 404
			pins[#pins + 1] = { -- 406
				levelIndex = lvIndex, -- 407
				stIndex = stIndex, -- 408
				root = pinRoot, -- 409
				nameLabel = nameLabel, -- 410
				rocketLabel = rocketLabel, -- 411
				btn = btn -- 412
			} -- 412
			i = i + 1 -- 374
		end -- 374
	end -- 374
	local topBar = Node() -- 417
	topBar.size = Size(viewW, 90) -- 418
	topBar.anchor = Vec2(0, 0) -- 419
	topBar.position = Vec2(0, viewH - 90) -- 420
	ui:addChild(topBar) -- 421
	local titleLabel = createLabel(topBar, "深空航迹 · 太阳系沙盘", 32, 16777215) -- 423
	setLabelCenter(titleLabel, viewW / 2, 60) -- 424
	local totalRocketsLabel = createLabel(topBar, "任务完成: 0", 22, 10405355) -- 426
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 427
	local replayIntroBtn = nil -- 429
	if options.onReplayIntro ~= nil then -- 429
		replayIntroBtn = createButton( -- 431
			topBar, -- 431
			{ -- 431
				w = 130, -- 432
				h = 44, -- 433
				text = "重看开场", -- 434
				fontSize = 20, -- 435
				bgHex = SecondaryBtnBgHex, -- 436
				fgHex = SecondaryBtnFgHex, -- 437
				borderHex = SecondaryBtnBorderHex, -- 438
				fireOn = "press", -- 439
				onTap = function() -- 440
					if options.onReplayIntro ~= nil then -- 440
						options:onReplayIntro() -- 441
					end -- 441
				end -- 440
			} -- 440
		) -- 440
		replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 444
	end -- 444
	local dockNode = Node() -- 448
	dockNode.size = Size(viewW, 64) -- 449
	dockNode.anchor = Vec2(0, 0) -- 450
	dockNode.position = Vec2(0, 76) -- 451
	ui:addChild(dockNode) -- 452
	local dockButtons = {} -- 454
	local dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110) -- 455
	local dockBtnH = 50 -- 456
	local dockTotalW = dockBtnW * 6 + 10 * 5 -- 457
	local dockStartX = (viewW - dockTotalW) / 2 -- 458
	do -- 458
		local i = 0 -- 460
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 460
			local lvIndex = i -- 461
			local btn = createButton( -- 462
				dockNode, -- 462
				{ -- 462
					w = dockBtnW, -- 463
					h = dockBtnH, -- 464
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 465
					fontSize = 20, -- 466
					bgHex = PinBgHex, -- 467
					fgHex = 14084346, -- 468
					borderHex = PinBorderHex, -- 469
					fireOn = "press", -- 470
					onTap = function() -- 471
						focusMission(lvIndex) -- 472
					end -- 471
				} -- 471
			) -- 471
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0) -- 475
			dockButtons[#dockButtons + 1] = btn -- 476
			i = i + 1 -- 460
		end -- 460
	end -- 460
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 480
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 481
	local briefCard = createPanel( -- 483
		ui, -- 483
		cardW, -- 483
		cardH, -- 483
		CardBgHex, -- 483
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 483
	) -- 483
	briefCard.anchor = Vec2(0, 0) -- 488
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 489
	briefCard.visible = false -- 490
	local bTitleLabel = createLabel(briefCard, "", 28, 16777215) -- 492
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34) -- 493
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 495
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66) -- 496
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 498
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96) -- 499
	local challengeLabels = {} -- 502
	do -- 502
		local k = 0 -- 503
		while k < 3 do -- 503
			local cl = createLabel(briefCard, "", 19, 13689589) -- 504
			if cl ~= nil then -- 504
				cl.textWidth = cardW - 48 -- 506
				setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44) -- 507
				challengeLabels[#challengeLabels + 1] = cl -- 508
			end -- 508
			k = k + 1 -- 503
		end -- 503
	end -- 503
	local btnRowY = 22 -- 513
	local backBtnW = 120 -- 514
	local launchBtnW = cardW - backBtnW - 40 -- 515
	local btnH = 64 -- 516
	local backBtn = createButton( -- 518
		briefCard, -- 518
		{ -- 518
			w = backBtnW, -- 519
			h = btnH, -- 520
			text = "❮ 返回", -- 521
			fontSize = 22, -- 522
			bgHex = SecondaryBtnBgHex, -- 523
			fgHex = SecondaryBtnFgHex, -- 524
			borderHex = SecondaryBtnBorderHex, -- 525
			fireOn = "press", -- 526
			onTap = function() -- 527
				backToPanorama() -- 528
			end -- 527
		} -- 527
	) -- 527
	backBtn.root.position = Vec2(16, btnRowY) -- 531
	local launchBtn = createButton( -- 533
		briefCard, -- 533
		{ -- 533
			w = launchBtnW, -- 534
			h = btnH, -- 535
			text = "启动任务 / LAUNCH", -- 536
			fontSize = 24, -- 537
			bgHex = PrimaryBtnBgHex, -- 538
			fgHex = PrimaryBtnFgHex, -- 539
			borderHex = PrimaryBtnBorderHex, -- 540
			fireOn = "press", -- 541
			onTap = function() -- 542
				if focusLevelIndex >= 0 then -- 542
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 544
					options:onLaunch(focusLevelIndex) -- 545
				end -- 545
			end -- 542
		} -- 542
	) -- 542
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY) -- 549
	backBtn:setEnabled(false) -- 551
	launchBtn:setEnabled(false) -- 552
	local function updateBriefCard(levelIndex, progress) -- 555
		local lv = getLevel(levelIndex) -- 556
		if lv == nil then -- 556
			return -- 557
		end -- 557
		local m = lv.mission -- 558
		if m == nil then -- 558
			return -- 559
		end -- 559
		setLabelText( -- 561
			bTitleLabel, -- 561
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 561
		) -- 561
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 562
		setLabelText(bVehicleLabel, "【 飞掠型探测器 · 深空高速引力借力 】") -- 564
		setLabelColor(bVehicleLabel, 8381344) -- 565
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 567
		do -- 567
			local k = 0 -- 568
			while k < 3 do -- 568
				do -- 568
					local c = m.challenges[k + 1] -- 569
					if c == nil then -- 569
						setLabelVisible(challengeLabels[k + 1], false) -- 570
						goto __continue52 -- 570
					end -- 570
					setLabelVisible(challengeLabels[k + 1], true) -- 571
					local achieved = rocketsGot >= k + 1 -- 572
					local icon = achieved and "★" or "☆" -- 573
					local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 574
					local text = lv.transfer ~= nil and (rocketsGot >= 1 and "已完成 · " or "目标 · ") .. c.desc or (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 575
					setLabelText(challengeLabels[k + 1], text) -- 576
					setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 577
				end -- 577
				::__continue52:: -- 577
				k = k + 1 -- 568
			end -- 568
		end -- 568
	end -- 555
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 582
		camMode = "focus" -- 583
		focusLevelIndex = levelIndex -- 584
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 585
		local pose = calcFocusPose(stIndex) -- 586
		targetEye = pose.eye -- 587
		targetTarget = pose.target -- 588
		do -- 588
			local i = 0 -- 591
			while i < #pins do -- 591
				pins[i + 1].root.visible = false -- 592
				pins[i + 1].btn:setEnabled(false) -- 593
				i = i + 1 -- 591
			end -- 591
		end -- 591
		dockNode.visible = false -- 595
		do -- 595
			local i = 0 -- 596
			while i < #dockButtons do -- 596
				dockButtons[i + 1]:setEnabled(false) -- 596
				i = i + 1 -- 596
			end -- 596
		end -- 596
		briefCard.visible = true -- 599
		backBtn:setEnabled(true) -- 600
		launchBtn:setEnabled(true) -- 601
		local curProg = currentProgress -- 604
		if curProg ~= nil then -- 604
			updateBriefCard(levelIndex, curProg) -- 605
		end -- 605
	end -- 582
	--- 返回全景模式。
	backToPanorama = function() -- 609
		camMode = "panorama" -- 610
		focusLevelIndex = -1 -- 611
		targetEye = calcPanoEye() -- 612
		targetTarget = Vec3(0, 0, 0) -- 613
		do -- 613
			local i = 0 -- 616
			while i < #pins do -- 616
				pins[i + 1].root.visible = true -- 617
				pins[i + 1].btn:setEnabled(true) -- 618
				i = i + 1 -- 616
			end -- 616
		end -- 616
		dockNode.visible = true -- 620
		do -- 620
			local i = 0 -- 621
			while i < #dockButtons do -- 621
				dockButtons[i + 1]:setEnabled(true) -- 621
				i = i + 1 -- 621
			end -- 621
		end -- 621
		briefCard.visible = false -- 624
		backBtn:setEnabled(false) -- 625
		launchBtn:setEnabled(false) -- 626
	end -- 609
	local isVisible = false -- 629
	currentProgress = nil -- 630
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 633
		currentProgress = prog -- 634
		setLabelText( -- 635
			totalRocketsLabel, -- 635
			____exports.formatProgressSummary(prog) -- 635
		) -- 635
		do -- 635
			local i = 0 -- 637
			while i < #pins do -- 637
				local p = pins[i + 1] -- 638
				local count = getMissionRockets(prog, p.levelIndex) -- 639
				local ____opt_2 = getLevel(p.levelIndex) -- 639
				local teaching = (____opt_2 and ____opt_2.transfer) ~= nil -- 640
				setLabelText( -- 641
					p.rocketLabel, -- 641
					teaching and (count > 0 and "已完成" or "转移练习") or ____exports.formatRocketsString(count) -- 641
				) -- 641
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 642
				dockButtons[i + 1]:setText((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (count > 0 and (teaching and "已完成" or __TS__NumberToFixed(count, 0) .. "★") or "")) -- 645
				i = i + 1 -- 637
			end -- 637
		end -- 637
	end -- 633
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 650
		do -- 650
			local i = 0 -- 652
			while i < #planets do -- 652
				local h = planets[i + 1] -- 653
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 654
				local rad = h.currentAngleDeg * DegToRad -- 655
				h.currentPos = { -- 656
					x = math.cos(rad) * h.station.orbit, -- 657
					y = math.sin(rad) * h.station.orbit -- 658
				} -- 658
				h.node.position = planeToWorld(h.currentPos, 0) -- 660
				local ____h_node_4, ____angleY_5 = h.node, "angleY" -- 660
				____h_node_4[____angleY_5] = ____h_node_4[____angleY_5] + h.station.rotSpeedDegPerSec * dt -- 661
				i = i + 1 -- 652
			end -- 652
		end -- 652
		if probeHandle ~= nil and planets[3] ~= nil then -- 652
			local earthPos = planets[3].currentPos -- 666
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 667
			local probeP = { -- 668
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 669
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 670
			} -- 670
			probeHandle.node.position = planeToWorld(probeP, 0) -- 672
			local vel = { -- 673
				x = -math.sin(probeAngle), -- 674
				y = math.cos(probeAngle) -- 675
			} -- 675
			local yaw = probeYawForVelocity(vel) -- 677
			if yaw ~= nil then -- 677
				probeHandle.node.angleY = yaw -- 678
			end -- 678
			if probeHandle.antenna ~= nil then -- 678
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 680
			end -- 680
		end -- 680
		if camMode == "panorama" and not isDragging then -- 680
			panoYawDeg = panoYawDeg + 0.035 -- 686
			targetEye = calcPanoEye() -- 687
		elseif camMode == "focus" then -- 687
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 690
			targetEye = pose.eye -- 691
			targetTarget = pose.target -- 692
		end -- 692
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 696
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 697
		camera:lookAt( -- 698
			curEye, -- 698
			curTarget, -- 698
			Vec3(0, 1, 0) -- 698
		) -- 698
		if backdrop ~= nil then -- 698
			backdrop:sync(curEye, curTarget) -- 699
		end -- 699
		if camMode == "panorama" then -- 699
			local camView = { -- 703
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 704
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 705
				up = {x = 0, y = 1, z = 0}, -- 706
				fovYDeg = options.fovYDeg, -- 707
				aspect = options.aspect, -- 708
				viewW = viewW, -- 709
				viewH = viewH -- 710
			} -- 710
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 712
			do -- 712
				local i = 0 -- 714
				while i < #pins do -- 714
					do -- 714
						local p = pins[i + 1] -- 715
						local worldPos -- 716
						local yOffset = 24 -- 717
						if p.stIndex == -1 then -- 717
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 720
							yOffset = 48 -- 721
						else -- 721
							local planetHandle = planets[p.stIndex + 1] -- 723
							if planetHandle == nil then -- 723
								goto __continue79 -- 724
							end -- 724
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 725
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 727
						end -- 727
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 730
						if proj ~= nil and proj.vz > 1 then -- 730
							p.root.visible = true -- 733
							local over = toOverlay(proj) -- 734
							local screenX = viewW / 2 + over.x -- 736
							local screenY = viewH / 2 + over.y -- 737
							p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset) -- 738
						else -- 738
							p.root.visible = false -- 740
						end -- 740
					end -- 740
					::__continue79:: -- 740
					i = i + 1 -- 714
				end -- 714
			end -- 714
		end -- 714
	end -- 650
	local hub = { -- 746
		show = function(prog) -- 747
			isVisible = true -- 748
			root.visible = true -- 749
			ui.visible = true -- 750
			gestureLayer.touchEnabled = true -- 751
			refreshRocketsDisplay(prog) -- 753
			backToPanorama() -- 754
			curEye = calcPanoEye() -- 756
			curTarget = Vec3(0, 0, 0) -- 757
			targetEye = curEye -- 758
			targetTarget = curTarget -- 759
			camera:lookAt( -- 760
				curEye, -- 760
				curTarget, -- 760
				Vec3(0, 1, 0) -- 760
			) -- 760
			doStep(0) -- 763
		end, -- 747
		hide = function() -- 766
			isVisible = false -- 767
			root.visible = false -- 768
			ui.visible = false -- 769
			gestureLayer.touchEnabled = false -- 770
			do -- 770
				local i = 0 -- 772
				while i < #pins do -- 772
					pins[i + 1].btn:setEnabled(false) -- 772
					i = i + 1 -- 772
				end -- 772
			end -- 772
			do -- 772
				local i = 0 -- 773
				while i < #dockButtons do -- 773
					dockButtons[i + 1]:setEnabled(false) -- 773
					i = i + 1 -- 773
				end -- 773
			end -- 773
			if replayIntroBtn ~= nil then -- 773
				replayIntroBtn:setEnabled(false) -- 774
			end -- 774
			backBtn:setEnabled(false) -- 775
			launchBtn:setEnabled(false) -- 776
		end, -- 766
		step = function(dt) -- 779
			if not isVisible then -- 779
				return -- 780
			end -- 780
			doStep(dt) -- 781
		end, -- 779
		focusMission = function(levelIndex) -- 784
			focusMission(levelIndex) -- 785
		end, -- 784
		backToPanorama = function() -- 788
			backToPanorama() -- 789
		end, -- 788
		launchCurrentMission = function() -- 792
			if focusLevelIndex >= 0 then -- 792
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 794
				options:onLaunch(focusLevelIndex) -- 795
			end -- 795
		end, -- 792
		relayout = function(w, h) -- 799
			viewW = w -- 800
			viewH = h -- 801
			ui.size = Size(viewW, viewH) -- 802
			ui.position = Vec2(0, 0) -- 803
			gestureLayer.size = Size(viewW, viewH) -- 804
			topBar.size = Size(viewW, 90) -- 805
			topBar.position = Vec2(0, viewH - 90) -- 806
			setLabelCenter(titleLabel, viewW / 2, 60) -- 807
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 808
			if replayIntroBtn ~= nil then -- 808
				replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 810
			end -- 810
			dockNode.position = Vec2(0, 76) -- 812
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 813
		end, -- 799
		visible = function() return isVisible end -- 816
	} -- 816
	currentHubInstance = hub -- 818
	return hub -- 819
end -- 184
currentHubInstance = nil -- 822
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 825
	return currentHubInstance -- 826
end -- 825
return ____exports -- 825
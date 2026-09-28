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
		emissiveHex = 0, -- 78
		levelIndex = 1 -- 78
	}, -- 78
	{ -- 80
		model = "Planet_Venus", -- 80
		radius = 1.6, -- 80
		orbit = 11.5, -- 80
		baseAngleDeg = 300, -- 80
		orbitSpeedDegPerSec = 2.8, -- 80
		rotSpeedDegPerSec = -2, -- 80
		colorHex = 15785134, -- 80
		emissiveHex = 0 -- 80
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
		levelIndex = 3 -- 86
	}, -- 86
	{ -- 88
		model = "Planet_Saturn", -- 88
		radius = 3.2, -- 88
		orbit = 38.5, -- 88
		baseAngleDeg = 68, -- 88
		orbitSpeedDegPerSec = 0.5, -- 88
		rotSpeedDegPerSec = 22, -- 88
		colorHex = 13878426, -- 88
		emissiveHex = 0 -- 88
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
--- 关卡索引 -> HUB_STATIONS 下标的映射（L3 为太阳，用 -1 表示）。
____exports.LEVEL_TO_STATION_INDEX = { -- 96
	2, -- 96
	0, -- 96
	-1, -- 96
	4, -- 96
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
		if stIndex == -1 then -- 291
			local dist = 22 -- 294
			return { -- 295
				eye = Vec3(0, dist * 0.42, dist * 0.9), -- 295
				target = Vec3(0, 0, 0) -- 295
			} -- 295
		end -- 295
		local h = planets[stIndex + 1] -- 297
		if h == nil then -- 297
			return { -- 298
				eye = calcPanoEye(), -- 298
				target = Vec3(0, 0, 0) -- 298
			} -- 298
		end -- 298
		local p = h.currentPos -- 299
		local t = planeToWorld(p, 0) -- 300
		local planetRadius = h.station.radius -- 301
		local dist = math.max(14, planetRadius * 4.2) -- 302
		local offsetAngle = (h.currentAngleDeg + 45) * DegToRad -- 303
		local eyeX = t.x + math.cos(offsetAngle) * dist * 0.85 -- 304
		local eyeY = t.y + dist * 0.55 -- 305
		local eyeZ = t.z + math.sin(offsetAngle) * dist * 0.85 -- 306
		return { -- 307
			eye = Vec3(eyeX, eyeY, eyeZ), -- 307
			target = t -- 307
		} -- 307
	end -- 291
	local gestureLayer = Node() -- 311
	gestureLayer.size = Size(viewW, viewH) -- 312
	gestureLayer.anchor = Vec2(0, 0) -- 313
	gestureLayer.position = Vec2(0, 0) -- 314
	gestureLayer.touchEnabled = false -- 315
	ui:addChild(gestureLayer) -- 316
	local isDragging = false -- 318
	local lastTouchPos = Vec2(0, 0) -- 319
	gestureLayer:onTapBegan(function(touch) -- 321
		isDragging = true -- 322
		lastTouchPos = touch.location -- 323
		return true -- 324
	end) -- 321
	gestureLayer:onTapMoved(function(touch) -- 327
		if not isDragging then -- 327
			return -- 328
		end -- 328
		local loc = touch.location -- 329
		local dx = loc.x - lastTouchPos.x -- 330
		local dy = loc.y - lastTouchPos.y -- 331
		lastTouchPos = loc -- 332
		if camMode == "panorama" then -- 332
			panoYawDeg = panoYawDeg - dx * 0.22 -- 335
			panoPitchDeg = clampNumber(panoPitchDeg + dy * 0.16, 16, 75) -- 336
			targetEye = calcPanoEye() -- 337
		end -- 337
	end) -- 327
	gestureLayer:onTapEnded(function() -- 341
		isDragging = false -- 342
	end) -- 341
	local pins = {} -- 354
	local PinW = 138 -- 356
	local PinH = 50 -- 357
	do -- 357
		local i = 0 -- 359
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 359
			local lvIndex = i -- 360
			local stIndex = ____exports.LEVEL_TO_STATION_INDEX[lvIndex + 1] -- 361
			local def = getLevel(lvIndex) -- 362
			local title = def ~= nil and def.title or "" -- 363
			local pinRoot = Node() -- 365
			pinRoot.size = Size(PinW, PinH) -- 366
			pinRoot.anchor = Vec2(0, 0) -- 367
			ui:addChild(pinRoot) -- 368
			local btn = createButton( -- 370
				pinRoot, -- 370
				{ -- 370
					w = PinW, -- 371
					h = PinH, -- 372
					text = "", -- 373
					fontSize = 18, -- 374
					bgHex = PinBgHex, -- 375
					fgHex = 16777215, -- 376
					borderHex = PinBorderHex, -- 377
					fireOn = "press", -- 378
					onTap = function() -- 379
						focusMission(lvIndex) -- 380
					end -- 379
				} -- 379
			) -- 379
			btn.root.position = Vec2(0, 0) -- 383
			local nameLabel = createLabel( -- 385
				btn.root, -- 385
				(("L" .. __TS__NumberToFixed(lvIndex + 1, 0)) .. " · ") .. title, -- 385
				18, -- 385
				15398143 -- 385
			) -- 385
			setLabelCenter(nameLabel, PinW / 2, PinH - 16) -- 386
			local rocketLabel = createLabel(btn.root, "☆  ☆  ☆", 15, GoldStarHex) -- 388
			setLabelCenter(rocketLabel, PinW / 2, 14) -- 389
			pins[#pins + 1] = { -- 391
				levelIndex = lvIndex, -- 392
				stIndex = stIndex, -- 393
				root = pinRoot, -- 394
				nameLabel = nameLabel, -- 395
				rocketLabel = rocketLabel, -- 396
				btn = btn -- 397
			} -- 397
			i = i + 1 -- 359
		end -- 359
	end -- 359
	local topBar = Node() -- 402
	topBar.size = Size(viewW, 90) -- 403
	topBar.anchor = Vec2(0, 0) -- 404
	topBar.position = Vec2(0, viewH - 90) -- 405
	ui:addChild(topBar) -- 406
	local titleLabel = createLabel(topBar, "深空航迹 · 太阳系沙盘", 32, 16777215) -- 408
	setLabelCenter(titleLabel, viewW / 2, 60) -- 409
	local totalRocketsLabel = createLabel(topBar, "全深空火箭勋章: 0 / 18 ★", 22, 10405355) -- 411
	setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 412
	local replayIntroBtn = nil -- 414
	if options.onReplayIntro ~= nil then -- 414
		replayIntroBtn = createButton( -- 416
			topBar, -- 416
			{ -- 416
				w = 130, -- 417
				h = 44, -- 418
				text = "重看开场", -- 419
				fontSize = 20, -- 420
				bgHex = SecondaryBtnBgHex, -- 421
				fgHex = SecondaryBtnFgHex, -- 422
				borderHex = SecondaryBtnBorderHex, -- 423
				fireOn = "press", -- 424
				onTap = function() -- 425
					if options.onReplayIntro ~= nil then -- 425
						options:onReplayIntro() -- 426
					end -- 426
				end -- 425
			} -- 425
		) -- 425
		replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 429
	end -- 429
	local dockNode = Node() -- 433
	dockNode.size = Size(viewW, 64) -- 434
	dockNode.anchor = Vec2(0, 0) -- 435
	dockNode.position = Vec2(0, 76) -- 436
	ui:addChild(dockNode) -- 437
	local dockButtons = {} -- 439
	local dockBtnW = clampNumber((viewW * 0.94 - 10 * 5) / 6, 76, 110) -- 440
	local dockBtnH = 50 -- 441
	local dockTotalW = dockBtnW * 6 + 10 * 5 -- 442
	local dockStartX = (viewW - dockTotalW) / 2 -- 443
	do -- 443
		local i = 0 -- 445
		while i < #____exports.LEVEL_TO_STATION_INDEX do -- 445
			local lvIndex = i -- 446
			local btn = createButton( -- 447
				dockNode, -- 447
				{ -- 447
					w = dockBtnW, -- 448
					h = dockBtnH, -- 449
					text = "L" .. __TS__NumberToFixed(lvIndex + 1, 0), -- 450
					fontSize = 20, -- 451
					bgHex = PinBgHex, -- 452
					fgHex = 14084346, -- 453
					borderHex = PinBorderHex, -- 454
					fireOn = "press", -- 455
					onTap = function() -- 456
						focusMission(lvIndex) -- 457
					end -- 456
				} -- 456
			) -- 456
			btn.root.position = Vec2(dockStartX + lvIndex * (dockBtnW + 10), 0) -- 460
			dockButtons[#dockButtons + 1] = btn -- 461
			i = i + 1 -- 445
		end -- 445
	end -- 445
	local cardW = clampNumber(viewW * 0.92, 340, 540) -- 465
	local cardH = clampNumber(viewH * 0.44, 380, 500) -- 466
	local briefCard = createPanel( -- 468
		ui, -- 468
		cardW, -- 468
		cardH, -- 468
		CardBgHex, -- 468
		{alpha = 0.96, borderHex = CardBorderHex, borderWidth = 2} -- 468
	) -- 468
	briefCard.anchor = Vec2(0, 0) -- 473
	briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 474
	briefCard.visible = false -- 475
	local bTitleLabel = createLabel(briefCard, "", 28, 16777215) -- 477
	setLabelCenter(bTitleLabel, cardW / 2, cardH - 34) -- 478
	local bSubtitleLabel = createLabel(briefCard, "", 20, 9090268) -- 480
	setLabelCenter(bSubtitleLabel, cardW / 2, cardH - 66) -- 481
	local bVehicleLabel = createLabel(briefCard, "", 18, 16766073) -- 483
	setLabelCenter(bVehicleLabel, cardW / 2, cardH - 96) -- 484
	local challengeLabels = {} -- 487
	do -- 487
		local k = 0 -- 488
		while k < 3 do -- 488
			local cl = createLabel(briefCard, "", 19, 13689589) -- 489
			if cl ~= nil then -- 489
				cl.textWidth = cardW - 48 -- 491
				setLabelCenter(cl, cardW / 2, cardH - 138 - k * 44) -- 492
				challengeLabels[#challengeLabels + 1] = cl -- 493
			end -- 493
			k = k + 1 -- 488
		end -- 488
	end -- 488
	local btnRowY = 22 -- 498
	local backBtnW = 120 -- 499
	local launchBtnW = cardW - backBtnW - 40 -- 500
	local btnH = 64 -- 501
	local backBtn = createButton( -- 503
		briefCard, -- 503
		{ -- 503
			w = backBtnW, -- 504
			h = btnH, -- 505
			text = "❮ 返回", -- 506
			fontSize = 22, -- 507
			bgHex = SecondaryBtnBgHex, -- 508
			fgHex = SecondaryBtnFgHex, -- 509
			borderHex = SecondaryBtnBorderHex, -- 510
			fireOn = "press", -- 511
			onTap = function() -- 512
				backToPanorama() -- 513
			end -- 512
		} -- 512
	) -- 512
	backBtn.root.position = Vec2(16, btnRowY) -- 516
	local launchBtn = createButton( -- 518
		briefCard, -- 518
		{ -- 518
			w = launchBtnW, -- 519
			h = btnH, -- 520
			text = "启动任务 / LAUNCH ★", -- 521
			fontSize = 24, -- 522
			bgHex = PrimaryBtnBgHex, -- 523
			fgHex = PrimaryBtnFgHex, -- 524
			borderHex = PrimaryBtnBorderHex, -- 525
			fireOn = "press", -- 526
			onTap = function() -- 527
				if focusLevelIndex >= 0 then -- 527
					print("[escape-velocity] launch mission: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 529
					options:onLaunch(focusLevelIndex) -- 530
				end -- 530
			end -- 527
		} -- 527
	) -- 527
	launchBtn.root.position = Vec2(backBtnW + 28, btnRowY) -- 534
	backBtn:setEnabled(false) -- 536
	launchBtn:setEnabled(false) -- 537
	local function updateBriefCard(levelIndex, progress) -- 540
		local lv = getLevel(levelIndex) -- 541
		if lv == nil then -- 541
			return -- 542
		end -- 542
		local m = lv.mission -- 543
		if m == nil then -- 543
			return -- 544
		end -- 544
		setLabelText( -- 546
			bTitleLabel, -- 546
			(((("L" .. __TS__NumberToFixed(levelIndex + 1, 0)) .. " · ") .. lv.title) .. " · ") .. m.subtitle -- 546
		) -- 546
		setLabelText(bSubtitleLabel, ((m.historicalRef .. " (") .. m.codeName) .. ")") -- 547
		local vehText = m.vehicle == "orbiter" and "【 轨道器型 · 具备变轨制动引擎 】" or "【 飞掠型探测器 · 深空高速引力借力 】" -- 549
		setLabelText(bVehicleLabel, vehText) -- 552
		setLabelColor(bVehicleLabel, m.vehicle == "orbiter" and 16766073 or 8381344) -- 553
		local rocketsGot = getMissionRockets(progress, levelIndex) -- 555
		do -- 555
			local k = 0 -- 556
			while k < 3 do -- 556
				local c = m.challenges[k + 1] -- 557
				local achieved = rocketsGot >= k + 1 -- 558
				local icon = achieved and "★" or "☆" -- 559
				local prefix = k == 0 and "一星" or (k == 1 and "二星" or "三星") -- 560
				local text = (((icon .. " [") .. prefix) .. "] ") .. c.desc -- 561
				setLabelText(challengeLabels[k + 1], text) -- 562
				setLabelColor(challengeLabels[k + 1], achieved and GoldStarHex or 10270937) -- 563
				k = k + 1 -- 556
			end -- 556
		end -- 556
	end -- 540
	--- 聚焦某关特写。
	focusMission = function(levelIndex) -- 568
		camMode = "focus" -- 569
		focusLevelIndex = levelIndex -- 570
		local stIndex = ____exports.LEVEL_TO_STATION_INDEX[levelIndex + 1] -- 571
		local pose = calcFocusPose(stIndex) -- 572
		targetEye = pose.eye -- 573
		targetTarget = pose.target -- 574
		do -- 574
			local i = 0 -- 577
			while i < #pins do -- 577
				pins[i + 1].root.visible = false -- 578
				pins[i + 1].btn:setEnabled(false) -- 579
				i = i + 1 -- 577
			end -- 577
		end -- 577
		dockNode.visible = false -- 581
		do -- 581
			local i = 0 -- 582
			while i < #dockButtons do -- 582
				dockButtons[i + 1]:setEnabled(false) -- 582
				i = i + 1 -- 582
			end -- 582
		end -- 582
		briefCard.visible = true -- 585
		backBtn:setEnabled(true) -- 586
		launchBtn:setEnabled(true) -- 587
		local curProg = currentProgress -- 590
		if curProg ~= nil then -- 590
			updateBriefCard(levelIndex, curProg) -- 591
		end -- 591
	end -- 568
	--- 返回全景模式。
	backToPanorama = function() -- 595
		camMode = "panorama" -- 596
		focusLevelIndex = -1 -- 597
		targetEye = calcPanoEye() -- 598
		targetTarget = Vec3(0, 0, 0) -- 599
		do -- 599
			local i = 0 -- 602
			while i < #pins do -- 602
				pins[i + 1].root.visible = true -- 603
				pins[i + 1].btn:setEnabled(true) -- 604
				i = i + 1 -- 602
			end -- 602
		end -- 602
		dockNode.visible = true -- 606
		do -- 606
			local i = 0 -- 607
			while i < #dockButtons do -- 607
				dockButtons[i + 1]:setEnabled(true) -- 607
				i = i + 1 -- 607
			end -- 607
		end -- 607
		briefCard.visible = false -- 610
		backBtn:setEnabled(false) -- 611
		launchBtn:setEnabled(false) -- 612
	end -- 595
	local isVisible = false -- 615
	currentProgress = nil -- 616
	--- 刷新所有火箭指示与统计标签。
	local function refreshRocketsDisplay(prog) -- 619
		currentProgress = prog -- 620
		local total = getTotalRockets( -- 621
			prog, -- 621
			levelCount() -- 621
		) -- 621
		setLabelText( -- 622
			totalRocketsLabel, -- 622
			("全深空火箭勋章: " .. __TS__NumberToFixed(total, 0)) .. " / 18 ★" -- 622
		) -- 622
		do -- 622
			local i = 0 -- 624
			while i < #pins do -- 624
				local p = pins[i + 1] -- 625
				local count = getMissionRockets(prog, p.levelIndex) -- 626
				setLabelText( -- 627
					p.rocketLabel, -- 627
					____exports.formatRocketsString(count) -- 627
				) -- 627
				setLabelColor(p.rocketLabel, count > 0 and GoldStarHex or DimStarHex) -- 628
				dockButtons[i + 1]:setText((("L" .. __TS__NumberToFixed(p.levelIndex + 1, 0)) .. " ") .. (count > 0 and __TS__NumberToFixed(count, 0) .. "★" or "")) -- 631
				i = i + 1 -- 624
			end -- 624
		end -- 624
	end -- 619
	--- 执行一帧更新与投影。
	local function doStep(dt) -- 636
		do -- 636
			local i = 0 -- 638
			while i < #planets do -- 638
				local h = planets[i + 1] -- 639
				h.currentAngleDeg = h.currentAngleDeg + h.station.orbitSpeedDegPerSec * dt -- 640
				local rad = h.currentAngleDeg * DegToRad -- 641
				h.currentPos = { -- 642
					x = math.cos(rad) * h.station.orbit, -- 643
					y = math.sin(rad) * h.station.orbit -- 644
				} -- 644
				h.node.position = planeToWorld(h.currentPos, 0) -- 646
				local ____h_node_0, ____angleY_1 = h.node, "angleY" -- 646
				____h_node_0[____angleY_1] = ____h_node_0[____angleY_1] + h.station.rotSpeedDegPerSec * dt -- 647
				i = i + 1 -- 638
			end -- 638
		end -- 638
		if probeHandle ~= nil and planets[3] ~= nil then -- 638
			local earthPos = planets[3].currentPos -- 652
			local probeAngle = planets[3].node.angleY * 2.5 * DegToRad -- 653
			local probeP = { -- 654
				x = earthPos.x + math.cos(probeAngle) * 4.2, -- 655
				y = earthPos.y + math.sin(probeAngle) * 4.2 -- 656
			} -- 656
			probeHandle.node.position = planeToWorld(probeP, 0) -- 658
			local vel = { -- 659
				x = -math.sin(probeAngle), -- 660
				y = math.cos(probeAngle) -- 661
			} -- 661
			local yaw = probeYawForVelocity(vel) -- 663
			if yaw ~= nil then -- 663
				probeHandle.node.angleY = yaw -- 664
			end -- 664
			if probeHandle.antenna ~= nil then -- 664
				pointAntenna(probeHandle.antenna, probeP, earthPos, probeHandle.node.angleY) -- 666
			end -- 666
		end -- 666
		if camMode == "panorama" and not isDragging then -- 666
			panoYawDeg = panoYawDeg + 0.035 -- 672
			targetEye = calcPanoEye() -- 673
		elseif camMode == "focus" then -- 673
			local pose = calcFocusPose(____exports.LEVEL_TO_STATION_INDEX[focusLevelIndex + 1]) -- 676
			targetEye = pose.eye -- 677
			targetTarget = pose.target -- 678
		end -- 678
		curEye = dt > 0 and lerp3(curEye, targetEye, 0.08) or targetEye -- 682
		curTarget = dt > 0 and lerp3(curTarget, targetTarget, 0.08) or targetTarget -- 683
		camera:lookAt( -- 684
			curEye, -- 684
			curTarget, -- 684
			Vec3(0, 1, 0) -- 684
		) -- 684
		if backdrop ~= nil then -- 684
			backdrop:sync(curEye, curTarget) -- 685
		end -- 685
		if camMode == "panorama" then -- 685
			local camView = { -- 689
				eye = {x = curEye.x, y = curEye.y, z = curEye.z}, -- 690
				target = {x = curTarget.x, y = curTarget.y, z = curTarget.z}, -- 691
				up = {x = 0, y = 1, z = 0}, -- 692
				fovYDeg = options.fovYDeg, -- 693
				aspect = options.aspect, -- 694
				viewW = viewW, -- 695
				viewH = viewH -- 696
			} -- 696
			local basis = prepareCamera(camView, HANDEDNESS, FLIP_Y) -- 698
			do -- 698
				local i = 0 -- 700
				while i < #pins do -- 700
					do -- 700
						local p = pins[i + 1] -- 701
						local worldPos -- 702
						local yOffset = 24 -- 703
						if p.stIndex == -1 then -- 703
							worldPos = planeToWorld({x = 0, y = 0}, 0) -- 706
							yOffset = 48 -- 707
						else -- 707
							local planetHandle = planets[p.stIndex + 1] -- 709
							if planetHandle == nil then -- 709
								goto __continue73 -- 710
							end -- 710
							worldPos = planeToWorld(planetHandle.currentPos, 0) -- 711
							yOffset = p.stIndex == 2 and 40 or (p.stIndex == 0 and 32 or 24) -- 713
						end -- 713
						local proj = projectPrepared({x = worldPos.x, y = worldPos.y, z = worldPos.z}, basis) -- 716
						if proj ~= nil and proj.vz > 1 then -- 716
							p.root.visible = true -- 719
							local over = toOverlay(proj) -- 720
							local screenX = viewW / 2 + over.x -- 722
							local screenY = viewH / 2 + over.y -- 723
							p.root.position = Vec2(screenX - PinW / 2, screenY + yOffset) -- 724
						else -- 724
							p.root.visible = false -- 726
						end -- 726
					end -- 726
					::__continue73:: -- 726
					i = i + 1 -- 700
				end -- 700
			end -- 700
		end -- 700
	end -- 636
	local hub = { -- 732
		show = function(prog) -- 733
			isVisible = true -- 734
			root.visible = true -- 735
			ui.visible = true -- 736
			gestureLayer.touchEnabled = true -- 737
			refreshRocketsDisplay(prog) -- 739
			backToPanorama() -- 740
			curEye = calcPanoEye() -- 742
			curTarget = Vec3(0, 0, 0) -- 743
			targetEye = curEye -- 744
			targetTarget = curTarget -- 745
			camera:lookAt( -- 746
				curEye, -- 746
				curTarget, -- 746
				Vec3(0, 1, 0) -- 746
			) -- 746
			doStep(0) -- 749
		end, -- 733
		hide = function() -- 752
			isVisible = false -- 753
			root.visible = false -- 754
			ui.visible = false -- 755
			gestureLayer.touchEnabled = false -- 756
			do -- 756
				local i = 0 -- 758
				while i < #pins do -- 758
					pins[i + 1].btn:setEnabled(false) -- 758
					i = i + 1 -- 758
				end -- 758
			end -- 758
			do -- 758
				local i = 0 -- 759
				while i < #dockButtons do -- 759
					dockButtons[i + 1]:setEnabled(false) -- 759
					i = i + 1 -- 759
				end -- 759
			end -- 759
			if replayIntroBtn ~= nil then -- 759
				replayIntroBtn:setEnabled(false) -- 760
			end -- 760
			backBtn:setEnabled(false) -- 761
			launchBtn:setEnabled(false) -- 762
		end, -- 752
		step = function(dt) -- 765
			if not isVisible then -- 765
				return -- 766
			end -- 766
			doStep(dt) -- 767
		end, -- 765
		focusMission = function(levelIndex) -- 770
			focusMission(levelIndex) -- 771
		end, -- 770
		backToPanorama = function() -- 774
			backToPanorama() -- 775
		end, -- 774
		launchCurrentMission = function() -- 778
			if focusLevelIndex >= 0 then -- 778
				print("[escape-velocity] launch mission via api: L" .. __TS__NumberToFixed(focusLevelIndex + 1, 0)) -- 780
				options:onLaunch(focusLevelIndex) -- 781
			end -- 781
		end, -- 778
		relayout = function(w, h) -- 785
			viewW = w -- 786
			viewH = h -- 787
			ui.size = Size(viewW, viewH) -- 788
			ui.position = Vec2(0, 0) -- 789
			gestureLayer.size = Size(viewW, viewH) -- 790
			topBar.size = Size(viewW, 90) -- 791
			topBar.position = Vec2(0, viewH - 90) -- 792
			setLabelCenter(titleLabel, viewW / 2, 60) -- 793
			setLabelCenter(totalRocketsLabel, viewW / 2, 24) -- 794
			if replayIntroBtn ~= nil then -- 794
				replayIntroBtn.root.position = Vec2(viewW - 146, 22) -- 796
			end -- 796
			dockNode.position = Vec2(0, 76) -- 798
			briefCard.position = Vec2((viewW - cardW) / 2, 40) -- 799
		end, -- 785
		visible = function() return isVisible end -- 802
	} -- 802
	currentHubInstance = hub -- 804
	return hub -- 805
end -- 169
currentHubInstance = nil -- 808
--- 获取当前处于活动状态的 SolarHub 单例。
function ____exports.getActiveSolarHub() -- 811
	return currentHubInstance -- 812
end -- 811
return ____exports -- 811
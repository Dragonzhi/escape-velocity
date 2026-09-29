-- [ts]: Opening.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 24
local Color = ____Dora.Color -- 24
local Color3 = ____Dora.Color3 -- 24
local Content = ____Dora.Content -- 24
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 24
local Model3D = ____Dora.Model3D -- 24
local Node = ____Dora.Node -- 24
local Path = ____Dora.Path -- 24
local PointLight3D = ____Dora.PointLight3D -- 24
local Size = ____Dora.Size -- 24
local Vec2 = ____Dora.Vec2 -- 24
local Vec3 = ____Dora.Vec3 -- 24
local ____Config = require("game.Config") -- 26
local MiniSunLightIntensity = ____Config.MiniSunLightIntensity -- 26
local SunFillIntensity = ____Config.SunFillIntensity -- 26
local ____Scene = require("game.Scene") -- 27
local applyPlanetTexture = ____Scene.applyPlanetTexture -- 27
local createProbe = ____Scene.createProbe -- 27
local createStarBackdrop = ____Scene.createStarBackdrop -- 27
local modelRadius = ____Scene.modelRadius -- 27
local planeToWorld = ____Scene.planeToWorld -- 27
local pointAntenna = ____Scene.pointAntenna -- 27
local probeYawForVelocity = ____Scene.probeYawForVelocity -- 27
local ____Ui = require("game.Ui") -- 28
local colorFromHex = ____Ui.colorFromHex -- 28
local createLabel = ____Ui.createLabel -- 28
local setLabelCenter = ____Ui.setLabelCenter -- 28
local DegToRad = math.pi / 180 -- 30
--- 全景时长。
____exports.WideFrames = 170 -- 34
--- 俯冲聚焦时长。
____exports.FocusFrames = 260 -- 36
--- 聚焦后的停留时长（探测器继续绕地球转）。
____exports.HoldFrames = 110 -- 38
--- 开场总帧数：到这一帧交还选关。
____exports.TotalFrames = ____exports.WideFrames + ____exports.FocusFrames + ____exports.HoldFrames -- 40
--- 交还选关后，相机拉回全景所用的帧数。
____exports.PullBackFrames = 240 -- 42
--- 全景时的相机距离：刚好装下最外圈（海王星轨道 55 → 竖屏半宽 0.2335·d ⇒ d ≈ 235，留一点余量）。
local WideDist = 245 -- 46
local WideTiltDeg = 42 -- 47
local WideAzDeg = 18 -- 48
--- 聚焦时的相机距离：装下「地球 + 轨道上的探测器」（轨道 3.0 + 探测器半径 ~0.7）。
-- 竖屏半宽 = 0.2335·d；探测器轨道 4.6 要留在画面内 ⇒ d ≥ 20（取 22）：
-- 地球在画面里约 260 px 直径，探测器在 4.6 单位外的轨道上绕行、始终在框内。
local CloseDist = 22 -- 54
local CloseTiltDeg = 20 -- 55
--- 特写的方位角：与「地球 → 太阳」方向**差约 90° 的侧后方**，太阳因此完全在画面外，
-- 地球呈半明半暗（晨昏线正好对着镜头）。orbitEye 的平面方位 = 90° − az；
-- 地球轨道方位 262°、日地方位 82° ⇒ 取相机水平方位 156° ⇒ az = 278°。
-- （首版取 56°、次版取 188° 时太阳都压在画面左下角抢戏——2026-09-26 截图实测。）
local CloseAzDeg = 278 -- 62
--- 方位角漂移（度/帧）：全景与特写共用一个缓慢环绕速度，交叠时不打转。
local AzDriftDegPerFrame = 0.035 -- 64
--- 太阳半径（世界单位）。
local SunRadius = 4.8 -- 67
--- 探测器在开场里的缩放与轨道（比关卡内小一号：全景尺度下才协调）。
____exports.ProbeScale = 1.15 -- 71
____exports.ProbeOrbitRadius = 4.6 -- 72
____exports.ProbeOrbitStartDeg = 40 -- 73
--- 探测器绕地球的公转角速度（度/帧）——540 帧转约 297°，看得见「在轨」。
____exports.ProbeOrbitDegPerFrame = 0.55 -- 75
--- 轨道线改成 **3D 网格**（2026-09-26 用户第 4 条反馈）：
-- 2D 虚线永远画在 3D 之上，行星挡不住线（"线压在行星上"）；烘成网格后由深度缓冲决定遮挡。
-- 资产 = Assets/Model/OrbitRings.gltf（八条轨道一个 mesh，1 draw call，
-- 半径与世界单位一致 ⇒ 不做缩放；由 Test/gen_orbit_assets.py 从本文件的 Stations 解析生成）。
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 83
--- 轨道线亮度（emissive 0xRRGGBB）。压暗过一版：用户反馈"线条过分明显"。
local OrbitRingsHex = 4153224 -- 85
--- 混合系数超过它就**整条藏掉**轨道线。
-- 
-- 为什么不能只"调暗"：环是不透明的网格（baseColor 黑 + emissive 亮），调暗只是让它变黑 ——
-- 贴脸时线宽会涨到几十像素，画面里就成了一根根**黑棍子**，比亮线更糟（实测截图）。
-- 全景/拉回段看得到，俯冲进特写就收起来（它是"地图"元素，不是场景元素）。
local OrbitRingsHideBlend = 0.45 -- 93
--- 地球在 Stations 里的下标（聚焦目标）。
____exports.EarthStationIndex = 2 -- 117
____exports.Stations = { -- 119
	{ -- 122
		model = "Sphere", -- 122
		radius = 0.85, -- 122
		orbit = 7.5, -- 122
		angleDeg = 340, -- 122
		colorHex = 10129286, -- 122
		emissiveHex = 0 -- 122
	}, -- 122
	{ -- 125
		model = "Planet_Venus", -- 125
		radius = 1.6, -- 125
		orbit = 11.5, -- 125
		angleDeg = 300, -- 125
		colorHex = 15785134, -- 125
		emissiveHex = 0 -- 125
	}, -- 125
	{ -- 127
		model = "Planet_Earth", -- 127
		radius = 2.2, -- 127
		orbit = 17, -- 127
		angleDeg = 262, -- 127
		colorHex = 6003680, -- 127
		emissiveHex = 0 -- 127
	}, -- 127
	{ -- 128
		model = "Planet_Mars", -- 128
		radius = 1.5, -- 128
		orbit = 22.5, -- 128
		angleDeg = 318, -- 128
		colorHex = 13664074, -- 128
		emissiveHex = 0 -- 128
	}, -- 128
	{ -- 129
		model = "Planet_Jupiter", -- 129
		radius = 4.6, -- 129
		orbit = 30, -- 129
		angleDeg = 12, -- 129
		colorHex = 14729362, -- 129
		emissiveHex = 0 -- 129
	}, -- 129
	{ -- 132
		model = "Planet_Saturn", -- 132
		radius = 3.2, -- 132
		orbit = 38.5, -- 132
		angleDeg = 68, -- 132
		colorHex = 13878426, -- 132
		emissiveHex = 0 -- 132
	}, -- 132
	{ -- 133
		model = "Planet_Uranus", -- 133
		radius = 2, -- 133
		orbit = 47, -- 133
		angleDeg = 124, -- 133
		colorHex = 11066852, -- 133
		emissiveHex = 0 -- 133
	}, -- 133
	{ -- 134
		model = "Planet_Neptune", -- 134
		radius = 1.9, -- 134
		orbit = 55, -- 134
		angleDeg = 180, -- 134
		colorHex = 8099312, -- 134
		emissiveHex = 0 -- 134
	} -- 134
} -- 134
--- 一站所在的平面坐标。下标越界返回原点（调用方不必再判空）。
function ____exports.stationPlane(index) -- 138
	if index < 0 or index >= #____exports.Stations then -- 138
		return {x = 0, y = 0} -- 139
	end -- 139
	local st = ____exports.Stations[index + 1] -- 140
	local a = st.angleDeg * DegToRad -- 141
	return { -- 142
		x = math.cos(a) * st.orbit, -- 142
		y = math.sin(a) * st.orbit -- 142
	} -- 142
end -- 138
local function smoothstep(t) -- 145
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 146
	return u * u * (3 - 2 * u) -- 147
end -- 145
local function lerp3(a, b, k) -- 150
	return Vec3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k) -- 151
end -- 150
--- 绕注视点的一圈机位：方位角 az、俯角 tilt、距离 dist。
local function orbitEye(focus, dist, tiltDeg, azDeg) -- 155
	local target = planeToWorld(focus, 0) -- 156
	local tilt = tiltDeg * DegToRad -- 157
	local az = azDeg * DegToRad -- 158
	local horiz = math.cos(tilt) * dist -- 159
	return Vec3( -- 160
		target.x + math.sin(az) * horiz, -- 161
		target.y + math.sin(tilt) * dist, -- 162
		target.z + math.cos(az) * horiz -- 163
	) -- 163
end -- 155
--- 全景 ↔ 特写的混合系数（纯函数）：
--   0 = 全景（太阳系全貌）→ 1 = 特写（地球旁的探测器）→ 交还选关后缓缓退回 0（全景）。
function ____exports.openingBlend(frame) -- 171
	if frame <= ____exports.WideFrames then -- 171
		return 0 -- 172
	end -- 172
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 172
		return smoothstep((frame - ____exports.WideFrames) / ____exports.FocusFrames) -- 173
	end -- 173
	if frame <= ____exports.TotalFrames then -- 173
		return 1 -- 174
	end -- 174
	local back = (frame - ____exports.TotalFrames) / ____exports.PullBackFrames -- 175
	return back >= 1 and 0 or 1 - smoothstep(back) -- 176
end -- 171
--- 第 frame 帧所处的相态（纯函数，供日志与测试断言）。
function ____exports.openingPhase(frame) -- 183
	if frame < 0 then -- 183
		return "off" -- 184
	end -- 184
	if frame < ____exports.WideFrames then -- 184
		return "wide" -- 185
	end -- 185
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 185
		return "focus" -- 186
	end -- 186
	if frame <= ____exports.TotalFrames then -- 186
		return "hold" -- 187
	end -- 187
	return "pullback" -- 188
end -- 183
--- 第 frame 帧的机位（纯函数；earth = 聚焦目标在地球轨道上的平面坐标）。
function ____exports.openingPose(frame, earth) -- 198
	local k = ____exports.openingBlend(frame) -- 199
	local az = AzDriftDegPerFrame * frame -- 200
	local wideEye = orbitEye({x = 0, y = 0}, WideDist, WideTiltDeg, WideAzDeg + az) -- 201
	local closeEye = orbitEye(earth, CloseDist, CloseTiltDeg, CloseAzDeg + az) -- 202
	return { -- 203
		eye = lerp3(wideEye, closeEye, k), -- 204
		target = lerp3( -- 205
			planeToWorld({x = 0, y = 0}, 0), -- 205
			planeToWorld(earth, 0), -- 205
			k -- 205
		) -- 205
	} -- 205
end -- 198
--- 第 frame 帧探测器在地球轨道上的平面位置（纯函数）。
function ____exports.probeOrbitPos(frame, earth) -- 210
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 211
	return { -- 212
		x = earth.x + math.cos(a) * ____exports.ProbeOrbitRadius, -- 212
		y = earth.y + math.sin(a) * ____exports.ProbeOrbitRadius -- 212
	} -- 212
end -- 210
--- 第 frame 帧探测器的平面速度（轨道切线；纯函数）。
function ____exports.probeOrbitVel(frame) -- 216
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 217
	local v = ____exports.ProbeOrbitRadius * ____exports.ProbeOrbitDegPerFrame * DegToRad -- 218
	return { -- 219
		x = -math.sin(a) * v, -- 219
		y = math.cos(a) * v -- 219
	} -- 219
end -- 216
--- 标记文件名（相对 Content.writablePath）。文件存在 = 看过；内容无所谓。
____exports.IntroFlagFileName = "escape-velocity.intro" -- 224
--- 标记文件绝对路径。
function ____exports.introFlagPath() -- 226
	return Path(Content.writablePath, ____exports.IntroFlagFileName) -- 227
end -- 226
--- 是否已经看过开场（存档语义就是「文件在不在」）。
function ____exports.loadIntroSeen() -- 230
	return Content:exist(____exports.introFlagPath()) -- 231
end -- 230
--- 记下「看过开场」。
function ____exports.saveIntroSeen() -- 234
	Content:save( -- 235
		____exports.introFlagPath(), -- 235
		"seen=1" -- 235
	) -- 235
end -- 234
local TitleHex = 15398143 -- 284
local SubtitleHex = 10470632 -- 285
local TaglineHex = 7309478 -- 286
local NarrationHex = 14149367 -- 287
local SkipHex = 8229803 -- 288
local function clampNumber(value, lo, hi) -- 290
	if value < lo then -- 290
		return lo -- 291
	end -- 291
	if value > hi then -- 291
		return hi -- 292
	end -- 292
	return value -- 293
end -- 290
--- 淡入淡出窗口：返回某一帧的不透明度（0–1）。
local function fadeWindow(f, inStart, inEnd, outStart, outEnd) -- 298
	if f < inStart then -- 298
		return 0 -- 299
	end -- 299
	if f < inEnd then -- 299
		return smoothstep((f - inStart) / (inEnd - inStart)) -- 300
	end -- 300
	if f < outStart then -- 300
		return 1 -- 301
	end -- 301
	if f < outEnd then -- 301
		return 1 - smoothstep((f - outStart) / (outEnd - outStart)) -- 302
	end -- 302
	return 0 -- 303
end -- 298
local function hideLabel(label) -- 306
	if label ~= nil then -- 306
		label.visible = false -- 307
	end -- 307
end -- 306
local function applyAlpha(label, colorHex, alpha) -- 310
	if label == nil then -- 310
		return -- 311
	end -- 311
	local on = alpha > 0.01 -- 312
	label.visible = on -- 313
	if on then -- 313
		label.color = colorFromHex(colorHex, alpha) -- 314
	end -- 314
end -- 310
--- 建立开场（只建一次场景；播放由 start 驱动）。
function ____exports.createOpening(options) -- 318
	local viewW = options.viewW -- 319
	local viewH = options.viewH -- 320
	local root = options.root -- 321
	local layer = options.layer -- 322
	local ui = Node() -- 328
	ui.size = Size(options.viewW, options.viewH) -- 329
	ui.anchor = Vec2(0, 0) -- 330
	ui.position = Vec2(0, 0) -- 331
	layer:addChild(ui) -- 332
	local sunLight = PointLight3D() -- 338
	sunLight.color = Color3(16774106) -- 339
	sunLight.intensity = MiniSunLightIntensity -- 340
	sunLight.range = 600 -- 341
	sunLight.position = Vec3(0, 0, 0) -- 342
	root:addChild(sunLight) -- 343
	local fillLight = DirectionalLight3D() -- 346
	fillLight.color = Color3(16774106) -- 347
	fillLight.intensity = SunFillIntensity -- 348
	fillLight.angleX = -42 -- 349
	fillLight.angleY = 75 -- 350
	root:addChild(fillLight) -- 351
	local backdrop = createStarBackdrop(root) -- 354
	local sun = Model3D("Assets/Model/Sun.glb") -- 357
	if sun ~= nil then -- 357
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 359
		applyPlanetTexture(sun, "Sun", 0, 0) -- 362
		root:addChild(sun) -- 363
	end -- 363
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 370
	local buildQueue = {} -- 371
	do -- 371
		local i = 0 -- 372
		while i < #____exports.Stations do -- 372
			local st = ____exports.Stations[i + 1] -- 373
			local p = ____exports.stationPlane(i) -- 374
			buildQueue[#buildQueue + 1] = function() -- 375
				local model = Model3D(st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb") -- 377
				if model == nil then -- 377
					print("[escape-velocity] opening model MISSING: " .. st.model) -- 379
					return -- 380
				end -- 380
				local scale = st.radius / modelRadius(st.model) -- 382
				model.scale = Vec3(scale, scale, scale) -- 383
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 386
				model.position = planeToWorld(p, 0) -- 387
				root:addChild(model) -- 388
			end -- 375
			i = i + 1 -- 372
		end -- 372
	end -- 372
	local rings = nil -- 393
	if Content:exist(OrbitRingsPath) then -- 393
		rings = Model3D(OrbitRingsPath) -- 395
		if rings ~= nil then -- 395
			local rm = rings:getMaterial(0) -- 397
			if rm ~= nil then -- 397
				rm.baseColor = Color(0, 0, 0, 255) -- 399
				rm.emissive = Color3(OrbitRingsHex) -- 400
			end -- 400
			root:addChild(rings) -- 402
		end -- 402
	end -- 402
	local probe = nil -- 407
	buildQueue[#buildQueue + 1] = function() -- 408
		probe = createProbe(root, { -- 409
			scale = ____exports.ProbeScale, -- 411
			probePath = options.probePath, -- 412
			bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 413
			antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 414
			antennaPivotY = 0.6495, -- 415
			bodyRadius = 1.084, -- 416
			atlasPath = "Assets/Image/probe_atlas.jpg" -- 417
		}) -- 417
	end -- 408
	local titleSize = math.floor(clampNumber(viewH * 0.085, 54, 104) + 0.5) -- 423
	local taglineSize = math.floor(clampNumber(viewH * 0.028, 22, 34) + 0.5) -- 424
	local titleY = viewH * 0.63 -- 425
	local title = createLabel(ui, "单程", titleSize, TitleHex) -- 426
	setLabelCenter(title, viewW / 2, titleY) -- 427
	local subtitle = createLabel(ui, "ESCAPE VELOCITY", taglineSize, SubtitleHex) -- 428
	setLabelCenter(subtitle, viewW / 2, titleY - titleSize * 0.95) -- 429
	local tagline = createLabel(ui, "一次没有返程的旅行", taglineSize, TaglineHex) -- 430
	setLabelCenter(tagline, viewW / 2, titleY - titleSize * 0.95 - taglineSize * 1.8) -- 431
	local narration = createLabel(ui, "地球轨道上，最后一次告别", taglineSize, NarrationHex) -- 432
	setLabelCenter(narration, viewW / 2, viewH * 0.26) -- 433
	local skip = createLabel(ui, "轻触跳过", taglineSize, SkipHex) -- 434
	setLabelCenter( -- 435
		skip, -- 435
		viewW / 2, -- 435
		clampNumber(viewH * 0.06, 34, 88) -- 435
	) -- 435
	local skipLayer = Node() -- 438
	skipLayer.size = Size(viewW, viewH) -- 439
	skipLayer.anchor = Vec2(0, 0) -- 440
	skipLayer.position = Vec2(0, 0) -- 441
	skipLayer.swallowTouches = true -- 442
	skipLayer.touchEnabled = true -- 443
	ui:addChild(skipLayer) -- 444
	print((("[escape-velocity] opening assets: rings=" .. (rings ~= nil and "ok" or "MISSING")) .. " sky=") .. (backdrop ~= nil and "ok" or "MISSING")) -- 447
	local earth = ____exports.stationPlane(____exports.EarthStationIndex) -- 450
	local mode = "off" -- 452
	local frame = -1 -- 453
	local bodyYawDeg = 0 -- 454
	local function probeNow() -- 459
		return probe -- 459
	end -- 459
	--- 把某一帧的世界状态摆好。
	local function updateWorld(f) -- 462
		local hp = probeNow() -- 463
		if hp ~= nil then -- 463
			local p = ____exports.probeOrbitPos(f, earth) -- 465
			hp.node.position = planeToWorld(p, 0) -- 466
			local yaw = probeYawForVelocity(____exports.probeOrbitVel(f)) -- 467
			if yaw ~= nil then -- 467
				bodyYawDeg = yaw -- 469
				hp.node.angleY = yaw -- 470
			end -- 470
			if hp.antenna ~= nil then -- 470
				pointAntenna(hp.antenna, p, earth, bodyYawDeg) -- 472
			end -- 472
		end -- 472
		local pose = ____exports.openingPose(f, earth) -- 475
		options.camera:lookAt( -- 476
			pose.eye, -- 476
			pose.target, -- 476
			Vec3(0, 1, 0) -- 476
		) -- 476
		if backdrop ~= nil then -- 476
			backdrop:sync(pose.eye, pose.target) -- 477
		end -- 477
		local k = ____exports.openingBlend(f) -- 479
		if rings ~= nil then -- 479
			rings.visible = k < OrbitRingsHideBlend -- 482
		end -- 482
	end -- 462
	--- 文案的呼吸节奏（帧号写死在这里 = 分镜表）。
	local function updateLabels(f) -- 486
		if mode == "idle" then -- 486
			hideLabel(title) -- 489
			hideLabel(subtitle) -- 490
			hideLabel(tagline) -- 491
			hideLabel(narration) -- 492
			hideLabel(skip) -- 493
			return -- 494
		end -- 494
		local outA = ____exports.WideFrames - 10 -- 496
		local outB = ____exports.WideFrames + 40 -- 497
		applyAlpha( -- 498
			title, -- 498
			TitleHex, -- 498
			fadeWindow( -- 498
				f, -- 498
				14, -- 498
				48, -- 498
				outA, -- 498
				outB -- 498
			) -- 498
		) -- 498
		applyAlpha( -- 499
			subtitle, -- 499
			SubtitleHex, -- 499
			fadeWindow( -- 499
				f, -- 499
				20, -- 499
				54, -- 499
				outA, -- 499
				outB -- 499
			) -- 499
		) -- 499
		applyAlpha( -- 500
			tagline, -- 500
			TaglineHex, -- 500
			fadeWindow( -- 500
				f, -- 500
				26, -- 500
				62, -- 500
				outA, -- 500
				outB -- 500
			) -- 500
		) -- 500
		applyAlpha( -- 501
			narration, -- 501
			NarrationHex, -- 501
			fadeWindow( -- 502
				f, -- 502
				____exports.WideFrames + 70, -- 502
				____exports.WideFrames + 130, -- 502
				____exports.TotalFrames - 70, -- 502
				____exports.TotalFrames - 10 -- 502
			) -- 502
		) -- 502
		applyAlpha( -- 503
			skip, -- 503
			SkipHex, -- 503
			fadeWindow( -- 503
				f, -- 503
				60, -- 503
				100, -- 503
				____exports.TotalFrames - 40, -- 503
				____exports.TotalFrames + 10 -- 503
			) -- 503
		) -- 503
	end -- 486
	local function update(f) -- 506
		if #buildQueue > 0 then -- 506
			local job = table.remove(buildQueue, 1) -- 509
			if job ~= nil then -- 509
				job() -- 510
			end -- 510
		end -- 510
		updateWorld(f) -- 512
		updateLabels(f) -- 513
	end -- 506
	local function finish() -- 516
		if mode ~= "intro" then -- 516
			return -- 517
		end -- 517
		mode = "idle" -- 518
		skipLayer.touchEnabled = false -- 519
		options:onFinish() -- 520
	end -- 516
	skipLayer:onTapEnded(function() -- 523
		finish() -- 524
	end) -- 523
	skipLayer.touchEnabled = false -- 527
	ui.visible = false -- 528
	return { -- 530
		start = function() -- 531
			mode = "intro" -- 532
			frame = 0 -- 533
			root.visible = true -- 534
			ui.visible = true -- 535
			skipLayer.touchEnabled = true -- 536
			update(0) -- 537
		end, -- 531
		step = function() -- 539
			if mode == "off" then -- 539
				return -- 540
			end -- 540
			frame = frame + 1 -- 541
			update(frame) -- 542
			if mode == "intro" and frame >= ____exports.TotalFrames then -- 542
				finish() -- 543
			end -- 543
		end, -- 539
		skip = function() -- 545
			finish() -- 546
		end, -- 545
		frameIndex = function() return frame end, -- 548
		idle = function() -- 549
			mode = "idle" -- 550
			root.visible = true -- 551
			ui.visible = true -- 552
			skipLayer.touchEnabled = false -- 553
			update(frame < 0 and 0 or frame) -- 554
		end, -- 549
		phase = function() return mode == "off" and "off" or ____exports.openingPhase(frame) end, -- 556
		running = function() return mode ~= "off" end, -- 557
		hide = function() -- 558
			mode = "off" -- 559
			root.visible = false -- 560
			ui.visible = false -- 561
			skipLayer.touchEnabled = false -- 562
		end -- 558
	} -- 558
end -- 318
return ____exports -- 318
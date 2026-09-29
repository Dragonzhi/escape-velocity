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
local createButton = ____Ui.createButton -- 28
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
	local finish -- 318
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
	local skip = createLabel(ui, "", taglineSize, SkipHex) -- 434
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
	local skipButton = createButton( -- 445
		ui, -- 445
		{ -- 445
			w = 144, -- 445
			h = 72, -- 445
			text = "跳过", -- 445
			icon = "fast", -- 445
			fontSize = 22, -- 445
			bgHex = 1319732, -- 446
			fgHex = 15398143, -- 446
			borderHex = 5143454, -- 446
			fireOn = "press", -- 446
			onTap = function() return finish() end -- 446
		} -- 446
	) -- 446
	skipButton.root.position = Vec2(viewW - 168, 80) -- 447
	skipButton.root.order = 100 -- 448
	skipButton:setEnabled(false) -- 449
	print((("[escape-velocity] opening assets: rings=" .. (rings ~= nil and "ok" or "MISSING")) .. " sky=") .. (backdrop ~= nil and "ok" or "MISSING")) -- 452
	local earth = ____exports.stationPlane(____exports.EarthStationIndex) -- 455
	local mode = "off" -- 457
	local frame = -1 -- 458
	local bodyYawDeg = 0 -- 459
	local function probeNow() -- 464
		return probe -- 464
	end -- 464
	--- 把某一帧的世界状态摆好。
	local function updateWorld(f) -- 467
		local hp = probeNow() -- 468
		if hp ~= nil then -- 468
			local p = ____exports.probeOrbitPos(f, earth) -- 470
			hp.node.position = planeToWorld(p, 0) -- 471
			local yaw = probeYawForVelocity(____exports.probeOrbitVel(f)) -- 472
			if yaw ~= nil then -- 472
				bodyYawDeg = yaw -- 474
				hp.node.angleY = yaw -- 475
			end -- 475
			if hp.antenna ~= nil then -- 475
				pointAntenna(hp.antenna, p, earth, bodyYawDeg) -- 477
			end -- 477
		end -- 477
		local pose = ____exports.openingPose(f, earth) -- 480
		options.camera:lookAt( -- 481
			pose.eye, -- 481
			pose.target, -- 481
			Vec3(0, 1, 0) -- 481
		) -- 481
		if backdrop ~= nil then -- 481
			backdrop:sync(pose.eye, pose.target) -- 482
		end -- 482
		local k = ____exports.openingBlend(f) -- 484
		if rings ~= nil then -- 484
			rings.visible = k < OrbitRingsHideBlend -- 487
		end -- 487
	end -- 467
	--- 文案的呼吸节奏（帧号写死在这里 = 分镜表）。
	local function updateLabels(f) -- 491
		if mode == "idle" then -- 491
			hideLabel(title) -- 494
			hideLabel(subtitle) -- 495
			hideLabel(tagline) -- 496
			hideLabel(narration) -- 497
			hideLabel(skip) -- 498
			return -- 499
		end -- 499
		local outA = ____exports.WideFrames - 10 -- 501
		local outB = ____exports.WideFrames + 40 -- 502
		applyAlpha( -- 503
			title, -- 503
			TitleHex, -- 503
			fadeWindow( -- 503
				f, -- 503
				14, -- 503
				48, -- 503
				outA, -- 503
				outB -- 503
			) -- 503
		) -- 503
		applyAlpha( -- 504
			subtitle, -- 504
			SubtitleHex, -- 504
			fadeWindow( -- 504
				f, -- 504
				20, -- 504
				54, -- 504
				outA, -- 504
				outB -- 504
			) -- 504
		) -- 504
		applyAlpha( -- 505
			tagline, -- 505
			TaglineHex, -- 505
			fadeWindow( -- 505
				f, -- 505
				26, -- 505
				62, -- 505
				outA, -- 505
				outB -- 505
			) -- 505
		) -- 505
		applyAlpha( -- 506
			narration, -- 506
			NarrationHex, -- 506
			fadeWindow( -- 507
				f, -- 507
				____exports.WideFrames + 70, -- 507
				____exports.WideFrames + 130, -- 507
				____exports.TotalFrames - 70, -- 507
				____exports.TotalFrames - 10 -- 507
			) -- 507
		) -- 507
		applyAlpha( -- 508
			skip, -- 508
			SkipHex, -- 508
			fadeWindow( -- 508
				f, -- 508
				60, -- 508
				100, -- 508
				____exports.TotalFrames - 40, -- 508
				____exports.TotalFrames + 10 -- 508
			) -- 508
		) -- 508
	end -- 491
	local function update(f) -- 511
		if #buildQueue > 0 then -- 511
			local job = table.remove(buildQueue, 1) -- 514
			if job ~= nil then -- 514
				job() -- 515
			end -- 515
		end -- 515
		updateWorld(f) -- 517
		updateLabels(f) -- 518
	end -- 511
	finish = function() -- 521
		if mode ~= "intro" then -- 521
			return -- 522
		end -- 522
		mode = "idle" -- 523
		skipLayer.touchEnabled = false -- 524
		skipButton:setEnabled(false) -- 525
		skipButton.root.visible = false -- 525
		options:onFinish() -- 526
	end -- 521
	skipLayer:onTapEnded(function() -- 529
		finish() -- 530
	end) -- 529
	skipLayer.touchEnabled = false -- 533
	ui.visible = false -- 534
	return { -- 536
		start = function() -- 537
			mode = "intro" -- 538
			frame = 0 -- 539
			root.visible = true -- 540
			ui.visible = true -- 541
			skipLayer.touchEnabled = true -- 542
			skipButton:setEnabled(true) -- 543
			skipButton.root.visible = true -- 543
			update(0) -- 544
		end, -- 537
		step = function() -- 546
			if mode == "off" then -- 546
				return -- 547
			end -- 547
			frame = frame + 1 -- 548
			update(frame) -- 549
			if mode == "intro" and frame >= ____exports.TotalFrames then -- 549
				finish() -- 550
			end -- 550
		end, -- 546
		skip = function() -- 552
			finish() -- 553
		end, -- 552
		frameIndex = function() return frame end, -- 555
		idle = function() -- 556
			mode = "idle" -- 557
			root.visible = true -- 558
			ui.visible = true -- 559
			skipLayer.touchEnabled = false -- 560
			skipButton:setEnabled(false) -- 561
			skipButton.root.visible = false -- 561
			update(frame < 0 and 0 or frame) -- 562
		end, -- 556
		phase = function() return mode == "off" and "off" or ____exports.openingPhase(frame) end, -- 564
		running = function() return mode ~= "off" end, -- 565
		hide = function() -- 566
			mode = "off" -- 567
			root.visible = false -- 568
			ui.visible = false -- 569
			skipLayer.touchEnabled = false -- 570
			skipButton:setEnabled(false) -- 571
			skipButton.root.visible = false -- 571
		end -- 566
	} -- 566
end -- 318
return ____exports -- 318
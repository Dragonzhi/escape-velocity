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
local ____Scene = require("game.Scene") -- 26
local applyPlanetTexture = ____Scene.applyPlanetTexture -- 26
local createProbe = ____Scene.createProbe -- 26
local createStarBackdrop = ____Scene.createStarBackdrop -- 26
local modelRadius = ____Scene.modelRadius -- 26
local planeToWorld = ____Scene.planeToWorld -- 26
local pointAntenna = ____Scene.pointAntenna -- 26
local probeYawForVelocity = ____Scene.probeYawForVelocity -- 26
local ____Ui = require("game.Ui") -- 27
local colorFromHex = ____Ui.colorFromHex -- 27
local createLabel = ____Ui.createLabel -- 27
local setLabelCenter = ____Ui.setLabelCenter -- 27
local DegToRad = math.pi / 180 -- 29
--- 全景时长。
____exports.WideFrames = 170 -- 33
--- 俯冲聚焦时长。
____exports.FocusFrames = 260 -- 35
--- 聚焦后的停留时长（探测器继续绕地球转）。
____exports.HoldFrames = 110 -- 37
--- 开场总帧数：到这一帧交还选关。
____exports.TotalFrames = ____exports.WideFrames + ____exports.FocusFrames + ____exports.HoldFrames -- 39
--- 交还选关后，相机拉回全景所用的帧数。
____exports.PullBackFrames = 240 -- 41
--- 全景时的相机距离：刚好装下最外圈（海王星轨道 55 → 竖屏半宽 0.2335·d ⇒ d ≈ 235，留一点余量）。
local WideDist = 245 -- 45
local WideTiltDeg = 42 -- 46
local WideAzDeg = 18 -- 47
--- 聚焦时的相机距离：装下「地球 + 轨道上的探测器」（轨道 3.0 + 探测器半径 ~0.7）。
-- 竖屏半宽 = 0.2335·d；探测器轨道 4.6 要留在画面内 ⇒ d ≥ 20（取 22）：
-- 地球在画面里约 260 px 直径，探测器在 4.6 单位外的轨道上绕行、始终在框内。
local CloseDist = 22 -- 53
local CloseTiltDeg = 20 -- 54
--- 特写的方位角：与「地球 → 太阳」方向**差约 90° 的侧后方**，太阳因此完全在画面外，
-- 地球呈半明半暗（晨昏线正好对着镜头）。orbitEye 的平面方位 = 90° − az；
-- 地球轨道方位 262°、日地方位 82° ⇒ 取相机水平方位 156° ⇒ az = 278°。
-- （首版取 56°、次版取 188° 时太阳都压在画面左下角抢戏——2026-09-26 截图实测。）
local CloseAzDeg = 278 -- 61
--- 方位角漂移（度/帧）：全景与特写共用一个缓慢环绕速度，交叠时不打转。
local AzDriftDegPerFrame = 0.035 -- 63
--- 太阳半径（世界单位）。
local SunRadius = 4.8 -- 66
--- 探测器在开场里的缩放与轨道（比关卡内小一号：全景尺度下才协调）。
____exports.ProbeScale = 1.15 -- 70
____exports.ProbeOrbitRadius = 4.6 -- 71
____exports.ProbeOrbitStartDeg = 40 -- 72
--- 探测器绕地球的公转角速度（度/帧）——540 帧转约 297°，看得见「在轨」。
____exports.ProbeOrbitDegPerFrame = 0.55 -- 74
--- 轨道线改成 **3D 网格**（2026-09-26 用户第 4 条反馈）：
-- 2D 虚线永远画在 3D 之上，行星挡不住线（"线压在行星上"）；烘成网格后由深度缓冲决定遮挡。
-- 资产 = Assets/Model/OrbitRings.gltf（八条轨道一个 mesh，1 draw call，
-- 半径与世界单位一致 ⇒ 不做缩放；由 Test/gen_orbit_assets.py 从本文件的 Stations 解析生成）。
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 82
--- 轨道线亮度（emissive 0xRRGGBB）。压暗过一版：用户反馈"线条过分明显"。
local OrbitRingsHex = 4153224 -- 84
--- 混合系数超过它就**整条藏掉**轨道线。
-- 
-- 为什么不能只"调暗"：环是不透明的网格（baseColor 黑 + emissive 亮），调暗只是让它变黑 ——
-- 贴脸时线宽会涨到几十像素，画面里就成了一根根**黑棍子**，比亮线更糟（实测截图）。
-- 全景/拉回段看得到，俯冲进特写就收起来（它是"地图"元素，不是场景元素）。
local OrbitRingsHideBlend = 0.45 -- 92
--- 地球在 Stations 里的下标（聚焦目标）。
____exports.EarthStationIndex = 2 -- 116
____exports.Stations = { -- 118
	{ -- 121
		model = "Sphere", -- 121
		radius = 0.85, -- 121
		orbit = 7.5, -- 121
		angleDeg = 340, -- 121
		colorHex = 10129286, -- 121
		emissiveHex = 0 -- 121
	}, -- 121
	{ -- 124
		model = "Planet_Venus", -- 124
		radius = 1.6, -- 124
		orbit = 11.5, -- 124
		angleDeg = 300, -- 124
		colorHex = 15785134, -- 124
		emissiveHex = 0 -- 124
	}, -- 124
	{ -- 126
		model = "Planet_Earth", -- 126
		radius = 2.2, -- 126
		orbit = 17, -- 126
		angleDeg = 262, -- 126
		colorHex = 6003680, -- 126
		emissiveHex = 0 -- 126
	}, -- 126
	{ -- 127
		model = "Planet_Mars", -- 127
		radius = 1.5, -- 127
		orbit = 22.5, -- 127
		angleDeg = 318, -- 127
		colorHex = 13664074, -- 127
		emissiveHex = 0 -- 127
	}, -- 127
	{ -- 128
		model = "Planet_Jupiter", -- 128
		radius = 4.6, -- 128
		orbit = 30, -- 128
		angleDeg = 12, -- 128
		colorHex = 14729362, -- 128
		emissiveHex = 0 -- 128
	}, -- 128
	{ -- 131
		model = "Planet_Saturn", -- 131
		radius = 3.2, -- 131
		orbit = 38.5, -- 131
		angleDeg = 68, -- 131
		colorHex = 13878426, -- 131
		emissiveHex = 0 -- 131
	}, -- 131
	{ -- 132
		model = "Planet_Uranus", -- 132
		radius = 2, -- 132
		orbit = 47, -- 132
		angleDeg = 124, -- 132
		colorHex = 11066852, -- 132
		emissiveHex = 0 -- 132
	}, -- 132
	{ -- 133
		model = "Planet_Neptune", -- 133
		radius = 1.9, -- 133
		orbit = 55, -- 133
		angleDeg = 180, -- 133
		colorHex = 8099312, -- 133
		emissiveHex = 0 -- 133
	} -- 133
} -- 133
--- 一站所在的平面坐标。下标越界返回原点（调用方不必再判空）。
function ____exports.stationPlane(index) -- 137
	if index < 0 or index >= #____exports.Stations then -- 137
		return {x = 0, y = 0} -- 138
	end -- 138
	local st = ____exports.Stations[index + 1] -- 139
	local a = st.angleDeg * DegToRad -- 140
	return { -- 141
		x = math.cos(a) * st.orbit, -- 141
		y = math.sin(a) * st.orbit -- 141
	} -- 141
end -- 137
local function smoothstep(t) -- 144
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 145
	return u * u * (3 - 2 * u) -- 146
end -- 144
local function lerp3(a, b, k) -- 149
	return Vec3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k) -- 150
end -- 149
--- 绕注视点的一圈机位：方位角 az、俯角 tilt、距离 dist。
local function orbitEye(focus, dist, tiltDeg, azDeg) -- 154
	local target = planeToWorld(focus, 0) -- 155
	local tilt = tiltDeg * DegToRad -- 156
	local az = azDeg * DegToRad -- 157
	local horiz = math.cos(tilt) * dist -- 158
	return Vec3( -- 159
		target.x + math.sin(az) * horiz, -- 160
		target.y + math.sin(tilt) * dist, -- 161
		target.z + math.cos(az) * horiz -- 162
	) -- 162
end -- 154
--- 全景 ↔ 特写的混合系数（纯函数）：
--   0 = 全景（太阳系全貌）→ 1 = 特写（地球旁的探测器）→ 交还选关后缓缓退回 0（全景）。
function ____exports.openingBlend(frame) -- 170
	if frame <= ____exports.WideFrames then -- 170
		return 0 -- 171
	end -- 171
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 171
		return smoothstep((frame - ____exports.WideFrames) / ____exports.FocusFrames) -- 172
	end -- 172
	if frame <= ____exports.TotalFrames then -- 172
		return 1 -- 173
	end -- 173
	local back = (frame - ____exports.TotalFrames) / ____exports.PullBackFrames -- 174
	return back >= 1 and 0 or 1 - smoothstep(back) -- 175
end -- 170
--- 第 frame 帧所处的相态（纯函数，供日志与测试断言）。
function ____exports.openingPhase(frame) -- 182
	if frame < 0 then -- 182
		return "off" -- 183
	end -- 183
	if frame < ____exports.WideFrames then -- 183
		return "wide" -- 184
	end -- 184
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 184
		return "focus" -- 185
	end -- 185
	if frame <= ____exports.TotalFrames then -- 185
		return "hold" -- 186
	end -- 186
	return "pullback" -- 187
end -- 182
--- 第 frame 帧的机位（纯函数；earth = 聚焦目标在地球轨道上的平面坐标）。
function ____exports.openingPose(frame, earth) -- 197
	local k = ____exports.openingBlend(frame) -- 198
	local az = AzDriftDegPerFrame * frame -- 199
	local wideEye = orbitEye({x = 0, y = 0}, WideDist, WideTiltDeg, WideAzDeg + az) -- 200
	local closeEye = orbitEye(earth, CloseDist, CloseTiltDeg, CloseAzDeg + az) -- 201
	return { -- 202
		eye = lerp3(wideEye, closeEye, k), -- 203
		target = lerp3( -- 204
			planeToWorld({x = 0, y = 0}, 0), -- 204
			planeToWorld(earth, 0), -- 204
			k -- 204
		) -- 204
	} -- 204
end -- 197
--- 第 frame 帧探测器在地球轨道上的平面位置（纯函数）。
function ____exports.probeOrbitPos(frame, earth) -- 209
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 210
	return { -- 211
		x = earth.x + math.cos(a) * ____exports.ProbeOrbitRadius, -- 211
		y = earth.y + math.sin(a) * ____exports.ProbeOrbitRadius -- 211
	} -- 211
end -- 209
--- 第 frame 帧探测器的平面速度（轨道切线；纯函数）。
function ____exports.probeOrbitVel(frame) -- 215
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 216
	local v = ____exports.ProbeOrbitRadius * ____exports.ProbeOrbitDegPerFrame * DegToRad -- 217
	return { -- 218
		x = -math.sin(a) * v, -- 218
		y = math.cos(a) * v -- 218
	} -- 218
end -- 215
--- 标记文件名（相对 Content.writablePath）。文件存在 = 看过；内容无所谓。
____exports.IntroFlagFileName = "escape-velocity.intro" -- 223
--- 标记文件绝对路径。
function ____exports.introFlagPath() -- 225
	return Path(Content.writablePath, ____exports.IntroFlagFileName) -- 226
end -- 225
--- 是否已经看过开场（存档语义就是「文件在不在」）。
function ____exports.loadIntroSeen() -- 229
	return Content:exist(____exports.introFlagPath()) -- 230
end -- 229
--- 记下「看过开场」。
function ____exports.saveIntroSeen() -- 233
	Content:save( -- 234
		____exports.introFlagPath(), -- 234
		"seen=1" -- 234
	) -- 234
end -- 233
local TitleHex = 15398143 -- 283
local SubtitleHex = 10470632 -- 284
local TaglineHex = 7309478 -- 285
local NarrationHex = 14149367 -- 286
local SkipHex = 8229803 -- 287
local function clampNumber(value, lo, hi) -- 289
	if value < lo then -- 289
		return lo -- 290
	end -- 290
	if value > hi then -- 290
		return hi -- 291
	end -- 291
	return value -- 292
end -- 289
--- 淡入淡出窗口：返回某一帧的不透明度（0–1）。
local function fadeWindow(f, inStart, inEnd, outStart, outEnd) -- 297
	if f < inStart then -- 297
		return 0 -- 298
	end -- 298
	if f < inEnd then -- 298
		return smoothstep((f - inStart) / (inEnd - inStart)) -- 299
	end -- 299
	if f < outStart then -- 299
		return 1 -- 300
	end -- 300
	if f < outEnd then -- 300
		return 1 - smoothstep((f - outStart) / (outEnd - outStart)) -- 301
	end -- 301
	return 0 -- 302
end -- 297
local function hideLabel(label) -- 305
	if label ~= nil then -- 305
		label.visible = false -- 306
	end -- 306
end -- 305
local function applyAlpha(label, colorHex, alpha) -- 309
	if label == nil then -- 309
		return -- 310
	end -- 310
	local on = alpha > 0.01 -- 311
	label.visible = on -- 312
	if on then -- 312
		label.color = colorFromHex(colorHex, alpha) -- 313
	end -- 313
end -- 309
--- 建立开场（只建一次场景；播放由 start 驱动）。
function ____exports.createOpening(options) -- 317
	local viewW = options.viewW -- 318
	local viewH = options.viewH -- 319
	local root = options.root -- 320
	local layer = options.layer -- 321
	local ui = Node() -- 327
	ui.size = Size(options.viewW, options.viewH) -- 328
	ui.anchor = Vec2(0, 0) -- 329
	ui.position = Vec2(0, 0) -- 330
	layer:addChild(ui) -- 331
	local sunLight = PointLight3D() -- 337
	sunLight.color = Color3(16774106) -- 338
	sunLight.intensity = 0 -- 339
	sunLight.range = 600 -- 340
	sunLight.position = Vec3(0, 0, 0) -- 341
	root:addChild(sunLight) -- 342
	local fillLight = DirectionalLight3D() -- 348
	fillLight.color = Color3(16774106) -- 349
	fillLight.intensity = 3.6 -- 350
	fillLight.angleX = -42 -- 351
	fillLight.angleY = 75 -- 352
	root:addChild(fillLight) -- 353
	local backdrop = createStarBackdrop(root) -- 356
	local sun = Model3D("Assets/Model/Sun.glb") -- 359
	if sun ~= nil then -- 359
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 361
		applyPlanetTexture(sun, "Sun", 0, 0) -- 364
		root:addChild(sun) -- 365
	end -- 365
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 372
	local buildQueue = {} -- 373
	do -- 373
		local i = 0 -- 374
		while i < #____exports.Stations do -- 374
			local st = ____exports.Stations[i + 1] -- 375
			local p = ____exports.stationPlane(i) -- 376
			buildQueue[#buildQueue + 1] = function() -- 377
				local model = Model3D(st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb") -- 379
				if model == nil then -- 379
					print("[escape-velocity] opening model MISSING: " .. st.model) -- 381
					return -- 382
				end -- 382
				local scale = st.radius / modelRadius(st.model) -- 384
				model.scale = Vec3(scale, scale, scale) -- 385
				applyPlanetTexture(model, st.model, st.colorHex, st.emissiveHex) -- 388
				model.position = planeToWorld(p, 0) -- 389
				root:addChild(model) -- 390
			end -- 377
			i = i + 1 -- 374
		end -- 374
	end -- 374
	local rings = nil -- 395
	if Content:exist(OrbitRingsPath) then -- 395
		rings = Model3D(OrbitRingsPath) -- 397
		if rings ~= nil then -- 397
			local rm = rings:getMaterial(0) -- 399
			if rm ~= nil then -- 399
				rm.baseColor = Color(0, 0, 0, 255) -- 401
				rm.emissive = Color3(OrbitRingsHex) -- 402
			end -- 402
			root:addChild(rings) -- 404
		end -- 404
	end -- 404
	local probe = nil -- 409
	buildQueue[#buildQueue + 1] = function() -- 410
		probe = createProbe(root, { -- 411
			scale = ____exports.ProbeScale, -- 413
			probePath = options.probePath, -- 414
			bodyPath = "Assets/Model/Probe_Solar_Body.glb", -- 415
			antennaPath = "Assets/Model/Probe_Solar_Antenna.glb", -- 416
			antennaPivotY = 0.6495, -- 417
			bodyRadius = 1.084, -- 418
			atlasPath = "Assets/Image/probe_atlas.jpg" -- 419
		}) -- 419
	end -- 410
	local titleSize = math.floor(clampNumber(viewH * 0.085, 54, 104) + 0.5) -- 425
	local taglineSize = math.floor(clampNumber(viewH * 0.028, 22, 34) + 0.5) -- 426
	local titleY = viewH * 0.63 -- 427
	local title = createLabel(ui, "单程", titleSize, TitleHex) -- 428
	setLabelCenter(title, viewW / 2, titleY) -- 429
	local subtitle = createLabel(ui, "ESCAPE VELOCITY", taglineSize, SubtitleHex) -- 430
	setLabelCenter(subtitle, viewW / 2, titleY - titleSize * 0.95) -- 431
	local tagline = createLabel(ui, "一次没有返程的旅行", taglineSize, TaglineHex) -- 432
	setLabelCenter(tagline, viewW / 2, titleY - titleSize * 0.95 - taglineSize * 1.8) -- 433
	local narration = createLabel(ui, "地球轨道上，最后一次告别", taglineSize, NarrationHex) -- 434
	setLabelCenter(narration, viewW / 2, viewH * 0.26) -- 435
	local skip = createLabel(ui, "轻触跳过", taglineSize, SkipHex) -- 436
	setLabelCenter( -- 437
		skip, -- 437
		viewW / 2, -- 437
		clampNumber(viewH * 0.06, 34, 88) -- 437
	) -- 437
	local skipLayer = Node() -- 440
	skipLayer.size = Size(viewW, viewH) -- 441
	skipLayer.anchor = Vec2(0, 0) -- 442
	skipLayer.position = Vec2(0, 0) -- 443
	skipLayer.swallowTouches = true -- 444
	skipLayer.touchEnabled = true -- 445
	ui:addChild(skipLayer) -- 446
	print((("[escape-velocity] opening assets: rings=" .. (rings ~= nil and "ok" or "MISSING")) .. " sky=") .. (backdrop ~= nil and "ok" or "MISSING")) -- 449
	local earth = ____exports.stationPlane(____exports.EarthStationIndex) -- 452
	local mode = "off" -- 454
	local frame = -1 -- 455
	local bodyYawDeg = 0 -- 456
	local function probeNow() -- 461
		return probe -- 461
	end -- 461
	--- 把某一帧的世界状态摆好。
	local function updateWorld(f) -- 464
		local hp = probeNow() -- 465
		if hp ~= nil then -- 465
			local p = ____exports.probeOrbitPos(f, earth) -- 467
			hp.node.position = planeToWorld(p, 0) -- 468
			local yaw = probeYawForVelocity(____exports.probeOrbitVel(f)) -- 469
			if yaw ~= nil then -- 469
				bodyYawDeg = yaw -- 471
				hp.node.angleY = yaw -- 472
			end -- 472
			if hp.antenna ~= nil then -- 472
				pointAntenna(hp.antenna, p, earth, bodyYawDeg) -- 474
			end -- 474
		end -- 474
		local pose = ____exports.openingPose(f, earth) -- 477
		options.camera:lookAt( -- 478
			pose.eye, -- 478
			pose.target, -- 478
			Vec3(0, 1, 0) -- 478
		) -- 478
		if backdrop ~= nil then -- 478
			backdrop:sync(pose.eye, pose.target) -- 479
		end -- 479
		local k = ____exports.openingBlend(f) -- 482
		fillLight.intensity = 3.6 * (1 - k) + 0.9 -- 483
		sunLight.intensity = 90 * k * k -- 484
		if rings ~= nil then -- 484
			rings.visible = k < OrbitRingsHideBlend -- 487
		end -- 487
	end -- 464
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
	local function finish() -- 521
		if mode ~= "intro" then -- 521
			return -- 522
		end -- 522
		mode = "idle" -- 523
		skipLayer.touchEnabled = false -- 524
		options:onFinish() -- 525
	end -- 521
	skipLayer:onTapEnded(function() -- 528
		finish() -- 529
	end) -- 528
	skipLayer.touchEnabled = false -- 532
	ui.visible = false -- 533
	return { -- 535
		start = function() -- 536
			mode = "intro" -- 537
			frame = 0 -- 538
			root.visible = true -- 539
			ui.visible = true -- 540
			skipLayer.touchEnabled = true -- 541
			update(0) -- 542
		end, -- 536
		step = function() -- 544
			if mode == "off" then -- 544
				return -- 545
			end -- 545
			frame = frame + 1 -- 546
			update(frame) -- 547
			if mode == "intro" and frame >= ____exports.TotalFrames then -- 547
				finish() -- 548
			end -- 548
		end, -- 544
		skip = function() -- 550
			finish() -- 551
		end, -- 550
		frameIndex = function() return frame end, -- 553
		idle = function() -- 554
			mode = "idle" -- 555
			root.visible = true -- 556
			ui.visible = true -- 557
			skipLayer.touchEnabled = false -- 558
			update(frame < 0 and 0 or frame) -- 559
		end, -- 554
		phase = function() return mode == "off" and "off" or ____exports.openingPhase(frame) end, -- 561
		running = function() return mode ~= "off" end, -- 562
		hide = function() -- 563
			mode = "off" -- 564
			root.visible = false -- 565
			ui.visible = false -- 566
			skipLayer.touchEnabled = false -- 567
		end -- 563
	} -- 563
end -- 317
return ____exports -- 317
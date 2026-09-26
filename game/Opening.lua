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
____exports.ProbeScale = 0.55 -- 69
____exports.ProbeOrbitRadius = 4.6 -- 70
____exports.ProbeOrbitStartDeg = 40 -- 71
--- 探测器绕地球的公转角速度（度/帧）——540 帧转约 297°，看得见「在轨」。
____exports.ProbeOrbitDegPerFrame = 0.55 -- 73
--- 轨道线改成 **3D 网格**（2026-09-26 用户第 4 条反馈）：
-- 2D 虚线永远画在 3D 之上，行星挡不住线（"线压在行星上"）；烘成网格后由深度缓冲决定遮挡。
-- 资产 = Assets/Model/OrbitRings.gltf（八条轨道一个 mesh，1 draw call，
-- 半径与世界单位一致 ⇒ 不做缩放；由 Test/gen_orbit_assets.py 从本文件的 Stations 解析生成）。
local OrbitRingsPath = "Assets/Model/OrbitRings.gltf" -- 81
--- 轨道线亮度（emissive 0xRRGGBB）。压暗过一版：用户反馈"线条过分明显"。
local OrbitRingsHex = 4153224 -- 83
--- 混合系数超过它就**整条藏掉**轨道线。
-- 
-- 为什么不能只"调暗"：环是不透明的网格（baseColor 黑 + emissive 亮），调暗只是让它变黑 ——
-- 贴脸时线宽会涨到几十像素，画面里就成了一根根**黑棍子**，比亮线更糟（实测截图）。
-- 全景/拉回段看得到，俯冲进特写就收起来（它是"地图"元素，不是场景元素）。
local OrbitRingsHideBlend = 0.45 -- 91
--- 地球在 Stations 里的下标（聚焦目标）。
____exports.EarthStationIndex = 2 -- 115
____exports.Stations = { -- 117
	{ -- 120
		model = "Sphere", -- 120
		radius = 0.85, -- 120
		orbit = 7.5, -- 120
		angleDeg = 340, -- 120
		colorHex = 10129286, -- 120
		emissiveHex = 0 -- 120
	}, -- 120
	{ -- 123
		model = "Planet_Venus", -- 123
		radius = 1.6, -- 123
		orbit = 11.5, -- 123
		angleDeg = 300, -- 123
		colorHex = 15785134, -- 123
		emissiveHex = 0 -- 123
	}, -- 123
	{ -- 125
		model = "Planet_Earth", -- 125
		radius = 2.2, -- 125
		orbit = 17, -- 125
		angleDeg = 262, -- 125
		colorHex = 6003680, -- 125
		emissiveHex = 1452092 -- 125
	}, -- 125
	{ -- 126
		model = "Planet_Mars", -- 126
		radius = 1.5, -- 126
		orbit = 22.5, -- 126
		angleDeg = 318, -- 126
		colorHex = 13664074, -- 126
		emissiveHex = 0 -- 126
	}, -- 126
	{ -- 127
		model = "Planet_Jupiter", -- 127
		radius = 4.6, -- 127
		orbit = 30, -- 127
		angleDeg = 12, -- 127
		colorHex = 14729362, -- 127
		emissiveHex = 0 -- 127
	}, -- 127
	{ -- 130
		model = "Planet_Saturn", -- 130
		radius = 3.2, -- 130
		orbit = 38.5, -- 130
		angleDeg = 68, -- 130
		colorHex = 13878426, -- 130
		emissiveHex = 0 -- 130
	}, -- 130
	{ -- 131
		model = "Planet_Uranus", -- 131
		radius = 2, -- 131
		orbit = 47, -- 131
		angleDeg = 124, -- 131
		colorHex = 11066852, -- 131
		emissiveHex = 0 -- 131
	}, -- 131
	{ -- 132
		model = "Planet_Neptune", -- 132
		radius = 1.9, -- 132
		orbit = 55, -- 132
		angleDeg = 180, -- 132
		colorHex = 8099312, -- 132
		emissiveHex = 0 -- 132
	} -- 132
} -- 132
--- 一站所在的平面坐标。下标越界返回原点（调用方不必再判空）。
function ____exports.stationPlane(index) -- 136
	if index < 0 or index >= #____exports.Stations then -- 136
		return {x = 0, y = 0} -- 137
	end -- 137
	local st = ____exports.Stations[index + 1] -- 138
	local a = st.angleDeg * DegToRad -- 139
	return { -- 140
		x = math.cos(a) * st.orbit, -- 140
		y = math.sin(a) * st.orbit -- 140
	} -- 140
end -- 136
local function smoothstep(t) -- 143
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 144
	return u * u * (3 - 2 * u) -- 145
end -- 143
local function lerp3(a, b, k) -- 148
	return Vec3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k) -- 149
end -- 148
--- 绕注视点的一圈机位：方位角 az、俯角 tilt、距离 dist。
local function orbitEye(focus, dist, tiltDeg, azDeg) -- 153
	local target = planeToWorld(focus, 0) -- 154
	local tilt = tiltDeg * DegToRad -- 155
	local az = azDeg * DegToRad -- 156
	local horiz = math.cos(tilt) * dist -- 157
	return Vec3( -- 158
		target.x + math.sin(az) * horiz, -- 159
		target.y + math.sin(tilt) * dist, -- 160
		target.z + math.cos(az) * horiz -- 161
	) -- 161
end -- 153
--- 全景 ↔ 特写的混合系数（纯函数）：
--   0 = 全景（太阳系全貌）→ 1 = 特写（地球旁的探测器）→ 交还选关后缓缓退回 0（全景）。
function ____exports.openingBlend(frame) -- 169
	if frame <= ____exports.WideFrames then -- 169
		return 0 -- 170
	end -- 170
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 170
		return smoothstep((frame - ____exports.WideFrames) / ____exports.FocusFrames) -- 171
	end -- 171
	if frame <= ____exports.TotalFrames then -- 171
		return 1 -- 172
	end -- 172
	local back = (frame - ____exports.TotalFrames) / ____exports.PullBackFrames -- 173
	return back >= 1 and 0 or 1 - smoothstep(back) -- 174
end -- 169
--- 第 frame 帧所处的相态（纯函数，供日志与测试断言）。
function ____exports.openingPhase(frame) -- 181
	if frame < 0 then -- 181
		return "off" -- 182
	end -- 182
	if frame < ____exports.WideFrames then -- 182
		return "wide" -- 183
	end -- 183
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 183
		return "focus" -- 184
	end -- 184
	if frame <= ____exports.TotalFrames then -- 184
		return "hold" -- 185
	end -- 185
	return "pullback" -- 186
end -- 181
--- 第 frame 帧的机位（纯函数；earth = 聚焦目标在地球轨道上的平面坐标）。
function ____exports.openingPose(frame, earth) -- 196
	local k = ____exports.openingBlend(frame) -- 197
	local az = AzDriftDegPerFrame * frame -- 198
	local wideEye = orbitEye({x = 0, y = 0}, WideDist, WideTiltDeg, WideAzDeg + az) -- 199
	local closeEye = orbitEye(earth, CloseDist, CloseTiltDeg, CloseAzDeg + az) -- 200
	return { -- 201
		eye = lerp3(wideEye, closeEye, k), -- 202
		target = lerp3( -- 203
			planeToWorld({x = 0, y = 0}, 0), -- 203
			planeToWorld(earth, 0), -- 203
			k -- 203
		) -- 203
	} -- 203
end -- 196
--- 第 frame 帧探测器在地球轨道上的平面位置（纯函数）。
function ____exports.probeOrbitPos(frame, earth) -- 208
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 209
	return { -- 210
		x = earth.x + math.cos(a) * ____exports.ProbeOrbitRadius, -- 210
		y = earth.y + math.sin(a) * ____exports.ProbeOrbitRadius -- 210
	} -- 210
end -- 208
--- 第 frame 帧探测器的平面速度（轨道切线；纯函数）。
function ____exports.probeOrbitVel(frame) -- 214
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 215
	local v = ____exports.ProbeOrbitRadius * ____exports.ProbeOrbitDegPerFrame * DegToRad -- 216
	return { -- 217
		x = -math.sin(a) * v, -- 217
		y = math.cos(a) * v -- 217
	} -- 217
end -- 214
--- 标记文件名（相对 Content.writablePath）。文件存在 = 看过；内容无所谓。
____exports.IntroFlagFileName = "escape-velocity.intro" -- 222
--- 标记文件绝对路径。
function ____exports.introFlagPath() -- 224
	return Path(Content.writablePath, ____exports.IntroFlagFileName) -- 225
end -- 224
--- 是否已经看过开场（存档语义就是「文件在不在」）。
function ____exports.loadIntroSeen() -- 228
	return Content:exist(____exports.introFlagPath()) -- 229
end -- 228
--- 记下「看过开场」。
function ____exports.saveIntroSeen() -- 232
	Content:save( -- 233
		____exports.introFlagPath(), -- 233
		"seen=1" -- 233
	) -- 233
end -- 232
local TitleHex = 15398143 -- 282
local SubtitleHex = 10470632 -- 283
local TaglineHex = 7309478 -- 284
local NarrationHex = 14149367 -- 285
local SkipHex = 8229803 -- 286
local function clampNumber(value, lo, hi) -- 288
	if value < lo then -- 288
		return lo -- 289
	end -- 289
	if value > hi then -- 289
		return hi -- 290
	end -- 290
	return value -- 291
end -- 288
--- 模型整体染色（循环到 getMaterial 返回 undefined —— 材质数量不写死的同一套规矩）。
local function tint(model, colorHex, emissiveHex) -- 295
	local i = 0 -- 296
	while i < 64 do -- 296
		local mat = model:getMaterial(i) -- 298
		if mat == nil then -- 298
			break -- 299
		end -- 299
		mat.baseColor = colorFromHex(colorHex, 1) -- 300
		if emissiveHex > 0 then -- 300
			mat.emissive = Color3(emissiveHex) -- 301
		end -- 301
		i = i + 1 -- 302
	end -- 302
end -- 295
--- 淡入淡出窗口：返回某一帧的不透明度（0–1）。
local function fadeWindow(f, inStart, inEnd, outStart, outEnd) -- 307
	if f < inStart then -- 307
		return 0 -- 308
	end -- 308
	if f < inEnd then -- 308
		return smoothstep((f - inStart) / (inEnd - inStart)) -- 309
	end -- 309
	if f < outStart then -- 309
		return 1 -- 310
	end -- 310
	if f < outEnd then -- 310
		return 1 - smoothstep((f - outStart) / (outEnd - outStart)) -- 311
	end -- 311
	return 0 -- 312
end -- 307
local function hideLabel(label) -- 315
	if label ~= nil then -- 315
		label.visible = false -- 316
	end -- 316
end -- 315
local function applyAlpha(label, colorHex, alpha) -- 319
	if label == nil then -- 319
		return -- 320
	end -- 320
	local on = alpha > 0.01 -- 321
	label.visible = on -- 322
	if on then -- 322
		label.color = colorFromHex(colorHex, alpha) -- 323
	end -- 323
end -- 319
--- 建立开场（只建一次场景；播放由 start 驱动）。
function ____exports.createOpening(options) -- 327
	local viewW = options.viewW -- 328
	local viewH = options.viewH -- 329
	local root = options.root -- 330
	local layer = options.layer -- 331
	local ui = Node() -- 337
	ui.size = Size(options.viewW, options.viewH) -- 338
	ui.anchor = Vec2(0, 0) -- 339
	ui.position = Vec2(0, 0) -- 340
	layer:addChild(ui) -- 341
	local sunLight = PointLight3D() -- 347
	sunLight.color = Color3(16774106) -- 348
	sunLight.intensity = 0 -- 349
	sunLight.range = 600 -- 350
	sunLight.position = Vec3(0, 0, 0) -- 351
	root:addChild(sunLight) -- 352
	local fillLight = DirectionalLight3D() -- 358
	fillLight.color = Color3(16774106) -- 359
	fillLight.intensity = 3.6 -- 360
	fillLight.angleX = -42 -- 361
	fillLight.angleY = 75 -- 362
	root:addChild(fillLight) -- 363
	local backdrop = createStarBackdrop(root) -- 366
	local sun = Model3D("Assets/Model/Sun.glb") -- 369
	if sun ~= nil then -- 369
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 371
		tint(sun, 16769434, 9071136) -- 372
		root:addChild(sun) -- 373
	end -- 373
	local spherePath = options.spherePath ~= nil and options.spherePath or "Assets/Model/Sphere.gltf" -- 380
	local buildQueue = {} -- 381
	do -- 381
		local i = 0 -- 382
		while i < #____exports.Stations do -- 382
			local st = ____exports.Stations[i + 1] -- 383
			local p = ____exports.stationPlane(i) -- 384
			buildQueue[#buildQueue + 1] = function() -- 385
				local model = Model3D(st.model == "Sphere" and spherePath or ("Assets/Model/" .. st.model) .. ".glb") -- 387
				if model == nil then -- 387
					print("[escape-velocity] opening model MISSING: " .. st.model) -- 389
					return -- 390
				end -- 390
				local scale = st.radius / modelRadius(st.model) -- 392
				model.scale = Vec3(scale, scale, scale) -- 393
				tint(model, st.colorHex, st.emissiveHex) -- 394
				model.position = planeToWorld(p, 0) -- 395
				root:addChild(model) -- 396
			end -- 385
			i = i + 1 -- 382
		end -- 382
	end -- 382
	local rings = nil -- 401
	if Content:exist(OrbitRingsPath) then -- 401
		rings = Model3D(OrbitRingsPath) -- 403
		if rings ~= nil then -- 403
			local rm = rings:getMaterial(0) -- 405
			if rm ~= nil then -- 405
				rm.baseColor = Color(0, 0, 0, 255) -- 407
				rm.emissive = Color3(OrbitRingsHex) -- 408
			end -- 408
			root:addChild(rings) -- 410
		end -- 410
	end -- 410
	local probe = nil -- 415
	buildQueue[#buildQueue + 1] = function() -- 416
		probe = createProbe(root, {scale = ____exports.ProbeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 417
	end -- 416
	local titleSize = math.floor(clampNumber(viewH * 0.085, 54, 104) + 0.5) -- 427
	local taglineSize = math.floor(clampNumber(viewH * 0.028, 22, 34) + 0.5) -- 428
	local titleY = viewH * 0.63 -- 429
	local title = createLabel(ui, "单程", titleSize, TitleHex) -- 430
	setLabelCenter(title, viewW / 2, titleY) -- 431
	local subtitle = createLabel(ui, "ESCAPE VELOCITY", taglineSize, SubtitleHex) -- 432
	setLabelCenter(subtitle, viewW / 2, titleY - titleSize * 0.95) -- 433
	local tagline = createLabel(ui, "一次没有返程的旅行", taglineSize, TaglineHex) -- 434
	setLabelCenter(tagline, viewW / 2, titleY - titleSize * 0.95 - taglineSize * 1.8) -- 435
	local narration = createLabel(ui, "地球轨道上，最后一次告别", taglineSize, NarrationHex) -- 436
	setLabelCenter(narration, viewW / 2, viewH * 0.26) -- 437
	local skip = createLabel(ui, "轻触跳过", taglineSize, SkipHex) -- 438
	setLabelCenter( -- 439
		skip, -- 439
		viewW / 2, -- 439
		clampNumber(viewH * 0.06, 34, 88) -- 439
	) -- 439
	local skipLayer = Node() -- 442
	skipLayer.size = Size(viewW, viewH) -- 443
	skipLayer.anchor = Vec2(0, 0) -- 444
	skipLayer.position = Vec2(0, 0) -- 445
	skipLayer.swallowTouches = true -- 446
	skipLayer.touchEnabled = true -- 447
	ui:addChild(skipLayer) -- 448
	print((("[escape-velocity] opening assets: rings=" .. (rings ~= nil and "ok" or "MISSING")) .. " sky=") .. (backdrop ~= nil and "ok" or "MISSING")) -- 451
	local earth = ____exports.stationPlane(____exports.EarthStationIndex) -- 454
	local mode = "off" -- 456
	local frame = -1 -- 457
	local bodyYawDeg = 0 -- 458
	local function probeNow() -- 463
		return probe -- 463
	end -- 463
	--- 把某一帧的世界状态摆好。
	local function updateWorld(f) -- 466
		local hp = probeNow() -- 467
		if hp ~= nil then -- 467
			local p = ____exports.probeOrbitPos(f, earth) -- 469
			hp.node.position = planeToWorld(p, 0) -- 470
			local yaw = probeYawForVelocity(____exports.probeOrbitVel(f)) -- 471
			if yaw ~= nil then -- 471
				bodyYawDeg = yaw -- 473
				hp.node.angleY = yaw -- 474
			end -- 474
			if hp.antenna ~= nil then -- 474
				pointAntenna(hp.antenna, p, earth, bodyYawDeg) -- 476
			end -- 476
		end -- 476
		local pose = ____exports.openingPose(f, earth) -- 479
		options.camera:lookAt( -- 480
			pose.eye, -- 480
			pose.target, -- 480
			Vec3(0, 1, 0) -- 480
		) -- 480
		if backdrop ~= nil then -- 480
			backdrop:sync(pose.eye, pose.target) -- 481
		end -- 481
		local k = ____exports.openingBlend(f) -- 484
		fillLight.intensity = 3.6 * (1 - k) + 0.9 -- 485
		sunLight.intensity = 90 * k * k -- 486
		if rings ~= nil then -- 486
			rings.visible = k < OrbitRingsHideBlend -- 489
		end -- 489
	end -- 466
	--- 文案的呼吸节奏（帧号写死在这里 = 分镜表）。
	local function updateLabels(f) -- 493
		if mode == "idle" then -- 493
			hideLabel(title) -- 496
			hideLabel(subtitle) -- 497
			hideLabel(tagline) -- 498
			hideLabel(narration) -- 499
			hideLabel(skip) -- 500
			return -- 501
		end -- 501
		local outA = ____exports.WideFrames - 10 -- 503
		local outB = ____exports.WideFrames + 40 -- 504
		applyAlpha( -- 505
			title, -- 505
			TitleHex, -- 505
			fadeWindow( -- 505
				f, -- 505
				14, -- 505
				48, -- 505
				outA, -- 505
				outB -- 505
			) -- 505
		) -- 505
		applyAlpha( -- 506
			subtitle, -- 506
			SubtitleHex, -- 506
			fadeWindow( -- 506
				f, -- 506
				20, -- 506
				54, -- 506
				outA, -- 506
				outB -- 506
			) -- 506
		) -- 506
		applyAlpha( -- 507
			tagline, -- 507
			TaglineHex, -- 507
			fadeWindow( -- 507
				f, -- 507
				26, -- 507
				62, -- 507
				outA, -- 507
				outB -- 507
			) -- 507
		) -- 507
		applyAlpha( -- 508
			narration, -- 508
			NarrationHex, -- 508
			fadeWindow( -- 509
				f, -- 509
				____exports.WideFrames + 70, -- 509
				____exports.WideFrames + 130, -- 509
				____exports.TotalFrames - 70, -- 509
				____exports.TotalFrames - 10 -- 509
			) -- 509
		) -- 509
		applyAlpha( -- 510
			skip, -- 510
			SkipHex, -- 510
			fadeWindow( -- 510
				f, -- 510
				60, -- 510
				100, -- 510
				____exports.TotalFrames - 40, -- 510
				____exports.TotalFrames + 10 -- 510
			) -- 510
		) -- 510
	end -- 493
	local function update(f) -- 513
		if #buildQueue > 0 then -- 513
			local job = table.remove(buildQueue, 1) -- 516
			if job ~= nil then -- 516
				job() -- 517
			end -- 517
		end -- 517
		updateWorld(f) -- 519
		updateLabels(f) -- 520
	end -- 513
	local function finish() -- 523
		if mode ~= "intro" then -- 523
			return -- 524
		end -- 524
		mode = "idle" -- 525
		skipLayer.touchEnabled = false -- 526
		options:onFinish() -- 527
	end -- 523
	skipLayer:onTapEnded(function() -- 530
		finish() -- 531
	end) -- 530
	skipLayer.touchEnabled = false -- 534
	ui.visible = false -- 535
	return { -- 537
		start = function() -- 538
			mode = "intro" -- 539
			frame = 0 -- 540
			root.visible = true -- 541
			ui.visible = true -- 542
			skipLayer.touchEnabled = true -- 543
			update(0) -- 544
		end, -- 538
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
			update(frame < 0 and 0 or frame) -- 561
		end, -- 556
		phase = function() return mode == "off" and "off" or ____exports.openingPhase(frame) end, -- 563
		running = function() return mode ~= "off" end, -- 564
		hide = function() -- 565
			mode = "off" -- 566
			root.visible = false -- 567
			ui.visible = false -- 568
			skipLayer.touchEnabled = false -- 569
		end -- 565
	} -- 565
end -- 327
return ____exports -- 327
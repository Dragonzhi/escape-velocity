-- [ts]: Opening.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 24
local Color3 = ____Dora.Color3 -- 24
local Content = ____Dora.Content -- 24
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 24
local DrawNode = ____Dora.DrawNode -- 24
local Model3D = ____Dora.Model3D -- 24
local Node = ____Dora.Node -- 24
local Path = ____Dora.Path -- 24
local Size = ____Dora.Size -- 24
local Vec2 = ____Dora.Vec2 -- 24
local Vec3 = ____Dora.Vec3 -- 24
local ____Projection = require("game.Projection") -- 26
local FLIP_Y = ____Projection.FLIP_Y -- 26
local HANDEDNESS = ____Projection.HANDEDNESS -- 26
local prepareCamera = ____Projection.prepareCamera -- 26
local ____Scene = require("game.Scene") -- 27
local createProbe = ____Scene.createProbe -- 27
local createStarBackdrop = ____Scene.createStarBackdrop -- 27
local modelRadius = ____Scene.modelRadius -- 27
local planeToWorld = ____Scene.planeToWorld -- 27
local pointAntenna = ____Scene.pointAntenna -- 27
local probeYawForVelocity = ____Scene.probeYawForVelocity -- 27
local ____Trajectory = require("game.Trajectory") -- 28
local drawDashedPolyline = ____Trajectory.drawDashedPolyline -- 28
local projectPolyline = ____Trajectory.projectPolyline -- 28
local ____Ui = require("game.Ui") -- 29
local colorFromHex = ____Ui.colorFromHex -- 29
local createLabel = ____Ui.createLabel -- 29
local setLabelCenter = ____Ui.setLabelCenter -- 29
local DegToRad = math.pi / 180 -- 31
--- 全景时长。
____exports.WideFrames = 170 -- 35
--- 俯冲聚焦时长。
____exports.FocusFrames = 260 -- 37
--- 聚焦后的停留时长（探测器继续绕地球转）。
____exports.HoldFrames = 110 -- 39
--- 开场总帧数：到这一帧交还选关。
____exports.TotalFrames = ____exports.WideFrames + ____exports.FocusFrames + ____exports.HoldFrames -- 41
--- 交还选关后，相机拉回全景所用的帧数。
____exports.PullBackFrames = 240 -- 43
--- 全景时的相机距离：刚好装下最外圈（海王星轨道 47 → 竖屏半宽 0.234·d ⇒ d ≈ 200）。
local WideDist = 205 -- 47
local WideTiltDeg = 42 -- 48
local WideAzDeg = 18 -- 49
--- 聚焦时的相机距离：装下「地球 + 轨道上的探测器」（轨道 3.0 + 探测器半径 ~0.7）。
-- 竖屏半宽 = 0.2335·d；探测器轨道 2.4 要留在画面内 ⇒ d ≥ 11（取 12，地球在画面里也够大）。
local CloseDist = 12 -- 54
local CloseTiltDeg = 20 -- 55
--- 特写的方位角：与「地球 → 太阳」方向**差约 90° 的侧后方**，太阳因此完全在画面外，
-- 地球呈半明半暗（晨昏线正好对着镜头）。orbitEye 的平面方位 = 90° − az；
-- 地球轨道方位 262°、日地方位 82° ⇒ 取相机水平方位 156° ⇒ az = 278°。
-- （首版取 56°、次版取 188° 时太阳都压在画面左下角抢戏——2026-09-26 截图实测。）
local CloseAzDeg = 278 -- 62
--- 方位角漂移（度/帧）：全景与特写共用一个缓慢环绕速度，交叠时不打转。
local AzDriftDegPerFrame = 0.035 -- 64
--- 太阳半径（世界单位）。
local SunRadius = 3.6 -- 67
--- 探测器在开场里的缩放与轨道（比关卡内小一号：全景尺度下才协调）。
____exports.ProbeScale = 0.45 -- 70
____exports.ProbeOrbitRadius = 2.4 -- 71
____exports.ProbeOrbitStartDeg = 40 -- 72
--- 探测器绕地球的公转角速度（度/帧）——540 帧转约 297°，看得见「在轨」。
____exports.ProbeOrbitDegPerFrame = 0.55 -- 74
--- 轨道虚线圈的采样段数（每圈）。
local RingSamples = 96 -- 77
local RingRadius = 1.7 -- 78
local RingGlowFactor = 2.4 -- 79
local RingGlowAlpha = 0.16 -- 80
local RingDashOn = 14 -- 81
local RingDashOff = 12 -- 82
local RingRgb = {r = 96, g = 128, b = 176} -- 83
--- 地球在 Stations 里的下标（聚焦目标）。
____exports.EarthStationIndex = 1 -- 107
____exports.Stations = { -- 109
	{ -- 110
		model = "Planet_Venus", -- 110
		radius = 1.15, -- 110
		orbit = 8.5, -- 110
		angleDeg = 205, -- 110
		colorHex = 15785134, -- 110
		emissiveHex = 0 -- 110
	}, -- 110
	{ -- 111
		model = "Planet_Earth", -- 111
		radius = 1.35, -- 111
		orbit = 14, -- 111
		angleDeg = 262, -- 111
		colorHex = 6003680, -- 111
		emissiveHex = 792098 -- 111
	}, -- 111
	{ -- 112
		model = "Planet_Mars", -- 112
		radius = 1, -- 112
		orbit = 19, -- 112
		angleDeg = 318, -- 112
		colorHex = 13664074, -- 112
		emissiveHex = 0 -- 112
	}, -- 112
	{ -- 113
		model = "Planet_Jupiter", -- 113
		radius = 2.7, -- 113
		orbit = 25, -- 113
		angleDeg = 12, -- 113
		colorHex = 14729362, -- 113
		emissiveHex = 0 -- 113
	}, -- 113
	{ -- 114
		model = "Planet_Saturn", -- 114
		radius = 2.1, -- 114
		orbit = 32, -- 114
		angleDeg = 68, -- 114
		colorHex = 13878426, -- 114
		emissiveHex = 0 -- 114
	}, -- 114
	{ -- 115
		model = "Planet_Uranus", -- 115
		radius = 1.35, -- 115
		orbit = 39.5, -- 115
		angleDeg = 124, -- 115
		colorHex = 11066852, -- 115
		emissiveHex = 0 -- 115
	}, -- 115
	{ -- 116
		model = "Planet_Neptune", -- 116
		radius = 1.3, -- 116
		orbit = 47, -- 116
		angleDeg = 180, -- 116
		colorHex = 8099312, -- 116
		emissiveHex = 0 -- 116
	} -- 116
} -- 116
--- 一站所在的平面坐标。下标越界返回原点（调用方不必再判空）。
function ____exports.stationPlane(index) -- 120
	if index < 0 or index >= #____exports.Stations then -- 120
		return {x = 0, y = 0} -- 121
	end -- 121
	local st = ____exports.Stations[index + 1] -- 122
	local a = st.angleDeg * DegToRad -- 123
	return { -- 124
		x = math.cos(a) * st.orbit, -- 124
		y = math.sin(a) * st.orbit -- 124
	} -- 124
end -- 120
local function smoothstep(t) -- 127
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 128
	return u * u * (3 - 2 * u) -- 129
end -- 127
local function lerp3(a, b, k) -- 132
	return Vec3(a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k, a.z + (b.z - a.z) * k) -- 133
end -- 132
--- 绕注视点的一圈机位：方位角 az、俯角 tilt、距离 dist。
local function orbitEye(focus, dist, tiltDeg, azDeg) -- 137
	local target = planeToWorld(focus, 0) -- 138
	local tilt = tiltDeg * DegToRad -- 139
	local az = azDeg * DegToRad -- 140
	local horiz = math.cos(tilt) * dist -- 141
	return Vec3( -- 142
		target.x + math.sin(az) * horiz, -- 143
		target.y + math.sin(tilt) * dist, -- 144
		target.z + math.cos(az) * horiz -- 145
	) -- 145
end -- 137
--- 全景 ↔ 特写的混合系数（纯函数）：
--   0 = 全景（太阳系全貌）→ 1 = 特写（地球旁的探测器）→ 交还选关后缓缓退回 0（全景）。
function ____exports.openingBlend(frame) -- 153
	if frame <= ____exports.WideFrames then -- 153
		return 0 -- 154
	end -- 154
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 154
		return smoothstep((frame - ____exports.WideFrames) / ____exports.FocusFrames) -- 155
	end -- 155
	if frame <= ____exports.TotalFrames then -- 155
		return 1 -- 156
	end -- 156
	local back = (frame - ____exports.TotalFrames) / ____exports.PullBackFrames -- 157
	return back >= 1 and 0 or 1 - smoothstep(back) -- 158
end -- 153
--- 第 frame 帧所处的相态（纯函数，供日志与测试断言）。
function ____exports.openingPhase(frame) -- 165
	if frame < 0 then -- 165
		return "off" -- 166
	end -- 166
	if frame < ____exports.WideFrames then -- 166
		return "wide" -- 167
	end -- 167
	if frame < ____exports.WideFrames + ____exports.FocusFrames then -- 167
		return "focus" -- 168
	end -- 168
	if frame <= ____exports.TotalFrames then -- 168
		return "hold" -- 169
	end -- 169
	return "pullback" -- 170
end -- 165
--- 第 frame 帧的机位（纯函数；earth = 聚焦目标在地球轨道上的平面坐标）。
function ____exports.openingPose(frame, earth) -- 180
	local k = ____exports.openingBlend(frame) -- 181
	local az = AzDriftDegPerFrame * frame -- 182
	local wideEye = orbitEye({x = 0, y = 0}, WideDist, WideTiltDeg, WideAzDeg + az) -- 183
	local closeEye = orbitEye(earth, CloseDist, CloseTiltDeg, CloseAzDeg + az) -- 184
	return { -- 185
		eye = lerp3(wideEye, closeEye, k), -- 186
		target = lerp3( -- 187
			planeToWorld({x = 0, y = 0}, 0), -- 187
			planeToWorld(earth, 0), -- 187
			k -- 187
		) -- 187
	} -- 187
end -- 180
--- 第 frame 帧探测器在地球轨道上的平面位置（纯函数）。
function ____exports.probeOrbitPos(frame, earth) -- 192
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 193
	return { -- 194
		x = earth.x + math.cos(a) * ____exports.ProbeOrbitRadius, -- 194
		y = earth.y + math.sin(a) * ____exports.ProbeOrbitRadius -- 194
	} -- 194
end -- 192
--- 第 frame 帧探测器的平面速度（轨道切线；纯函数）。
function ____exports.probeOrbitVel(frame) -- 198
	local a = (____exports.ProbeOrbitStartDeg + frame * ____exports.ProbeOrbitDegPerFrame) * DegToRad -- 199
	local v = ____exports.ProbeOrbitRadius * ____exports.ProbeOrbitDegPerFrame * DegToRad -- 200
	return { -- 201
		x = -math.sin(a) * v, -- 201
		y = math.cos(a) * v -- 201
	} -- 201
end -- 198
--- 标记文件名（相对 Content.writablePath）。文件存在 = 看过；内容无所谓。
____exports.IntroFlagFileName = "escape-velocity.intro" -- 206
--- 标记文件绝对路径。
function ____exports.introFlagPath() -- 208
	return Path(Content.writablePath, ____exports.IntroFlagFileName) -- 209
end -- 208
--- 是否已经看过开场（存档语义就是「文件在不在」）。
function ____exports.loadIntroSeen() -- 212
	return Content:exist(____exports.introFlagPath()) -- 213
end -- 212
--- 记下「看过开场」。
function ____exports.saveIntroSeen() -- 216
	Content:save( -- 217
		____exports.introFlagPath(), -- 217
		"seen=1" -- 217
	) -- 217
end -- 216
local TitleHex = 15398143 -- 264
local SubtitleHex = 10470632 -- 265
local TaglineHex = 7309478 -- 266
local NarrationHex = 14149367 -- 267
local SkipHex = 8229803 -- 268
local function clampNumber(value, lo, hi) -- 270
	if value < lo then -- 270
		return lo -- 271
	end -- 271
	if value > hi then -- 271
		return hi -- 272
	end -- 272
	return value -- 273
end -- 270
--- 模型整体染色（循环到 getMaterial 返回 undefined —— 材质数量不写死的同一套规矩）。
local function tint(model, colorHex, emissiveHex) -- 277
	local i = 0 -- 278
	while i < 64 do -- 278
		local mat = model:getMaterial(i) -- 280
		if mat == nil then -- 280
			break -- 281
		end -- 281
		mat.baseColor = colorFromHex(colorHex, 1) -- 282
		if emissiveHex > 0 then -- 282
			mat.emissive = Color3(emissiveHex) -- 283
		end -- 283
		i = i + 1 -- 284
	end -- 284
end -- 277
--- 淡入淡出窗口：返回某一帧的不透明度（0–1）。
local function fadeWindow(f, inStart, inEnd, outStart, outEnd) -- 289
	if f < inStart then -- 289
		return 0 -- 290
	end -- 290
	if f < inEnd then -- 290
		return smoothstep((f - inStart) / (inEnd - inStart)) -- 291
	end -- 291
	if f < outStart then -- 291
		return 1 -- 292
	end -- 292
	if f < outEnd then -- 292
		return 1 - smoothstep((f - outStart) / (outEnd - outStart)) -- 293
	end -- 293
	return 0 -- 294
end -- 289
local function hideLabel(label) -- 297
	if label ~= nil then -- 297
		label.visible = false -- 298
	end -- 298
end -- 297
local function applyAlpha(label, colorHex, alpha) -- 301
	if label == nil then -- 301
		return -- 302
	end -- 302
	local on = alpha > 0.01 -- 303
	label.visible = on -- 304
	if on then -- 304
		label.color = colorFromHex(colorHex, alpha) -- 305
	end -- 305
end -- 301
--- 建立开场（只建一次场景；播放由 start 驱动）。
function ____exports.createOpening(options) -- 309
	local viewW = options.viewW -- 310
	local viewH = options.viewH -- 311
	local root = options.root -- 312
	local layer = options.layer -- 313
	local ui = Node() -- 319
	ui.size = Size(options.viewW, options.viewH) -- 320
	ui.anchor = Vec2(0, 0) -- 321
	ui.position = Vec2(0, 0) -- 322
	layer:addChild(ui) -- 323
	local light = DirectionalLight3D() -- 326
	light.color = Color3(16774106) -- 327
	light.intensity = 3.6 -- 328
	light.angleX = -42 -- 329
	light.angleY = 75 -- 330
	root:addChild(light) -- 331
	local backdrop = createStarBackdrop(root) -- 334
	local sun = Model3D("Assets/Model/Sun.glb") -- 337
	if sun ~= nil then -- 337
		sun.scale = Vec3(SunRadius, SunRadius, SunRadius) -- 339
		tint(sun, 16769434, 9071136) -- 340
		root:addChild(sun) -- 341
	end -- 341
	do -- 341
		local i = 0 -- 344
		while i < #____exports.Stations do -- 344
			do -- 344
				local st = ____exports.Stations[i + 1] -- 345
				local model = Model3D(("Assets/Model/" .. st.model) .. ".glb") -- 346
				if model == nil then -- 346
					goto __continue42 -- 347
				end -- 347
				local scale = st.radius / modelRadius(st.model) -- 348
				model.scale = Vec3(scale, scale, scale) -- 349
				tint(model, st.colorHex, st.emissiveHex) -- 350
				model.position = planeToWorld( -- 351
					____exports.stationPlane(i), -- 351
					0 -- 351
				) -- 351
				root:addChild(model) -- 352
			end -- 352
			::__continue42:: -- 352
			i = i + 1 -- 344
		end -- 344
	end -- 344
	local probe = createProbe(root, {scale = ____exports.ProbeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 356
	local orbitDraw = DrawNode() -- 364
	ui:addChild(orbitDraw) -- 365
	local titleSize = math.floor(clampNumber(viewH * 0.085, 54, 104) + 0.5) -- 367
	local taglineSize = math.floor(clampNumber(viewH * 0.028, 22, 34) + 0.5) -- 368
	local titleY = viewH * 0.63 -- 369
	local title = createLabel(ui, "单程", titleSize, TitleHex) -- 370
	setLabelCenter(title, viewW / 2, titleY) -- 371
	local subtitle = createLabel(ui, "ESCAPE VELOCITY", taglineSize, SubtitleHex) -- 372
	setLabelCenter(subtitle, viewW / 2, titleY - titleSize * 0.95) -- 373
	local tagline = createLabel(ui, "一次没有返程的旅行", taglineSize, TaglineHex) -- 374
	setLabelCenter(tagline, viewW / 2, titleY - titleSize * 0.95 - taglineSize * 1.8) -- 375
	local narration = createLabel(ui, "地球轨道上，最后一次告别", taglineSize, NarrationHex) -- 376
	setLabelCenter(narration, viewW / 2, viewH * 0.26) -- 377
	local skip = createLabel(ui, "轻触跳过", taglineSize, SkipHex) -- 378
	setLabelCenter( -- 379
		skip, -- 379
		viewW / 2, -- 379
		clampNumber(viewH * 0.06, 34, 88) -- 379
	) -- 379
	local skipLayer = Node() -- 382
	skipLayer.size = Size(viewW, viewH) -- 383
	skipLayer.anchor = Vec2(0, 0) -- 384
	skipLayer.position = Vec2(0, 0) -- 385
	skipLayer.swallowTouches = true -- 386
	skipLayer.touchEnabled = true -- 387
	ui:addChild(skipLayer) -- 388
	local ringSamples = {} -- 391
	do -- 391
		local i = 0 -- 392
		while i < #____exports.Stations do -- 392
			local r = ____exports.Stations[i + 1].orbit -- 393
			local pts = {} -- 394
			do -- 394
				local j = 0 -- 395
				while j <= RingSamples do -- 395
					local a = j / RingSamples * math.pi * 2 -- 396
					pts[#pts + 1] = { -- 397
						x = math.cos(a) * r, -- 397
						y = math.sin(a) * r -- 397
					} -- 397
					j = j + 1 -- 395
				end -- 395
			end -- 395
			ringSamples[#ringSamples + 1] = pts -- 399
			i = i + 1 -- 392
		end -- 392
	end -- 392
	local earth = ____exports.stationPlane(____exports.EarthStationIndex) -- 402
	local mode = "off" -- 404
	local frame = -1 -- 405
	local bodyYawDeg = 0 -- 406
	--- 把某一帧的世界状态摆好，返回这一帧的相机基（轨道线共用同一份投影）。
	local function updateWorld(f) -- 409
		if probe ~= nil then -- 409
			local p = ____exports.probeOrbitPos(f, earth) -- 411
			probe.node.position = planeToWorld(p, 0) -- 412
			local yaw = probeYawForVelocity(____exports.probeOrbitVel(f)) -- 413
			if yaw ~= nil then -- 413
				bodyYawDeg = yaw -- 415
				probe.node.angleY = yaw -- 416
			end -- 416
			if probe.antenna ~= nil then -- 416
				pointAntenna(probe.antenna, p, earth, bodyYawDeg) -- 418
			end -- 418
		end -- 418
		local pose = ____exports.openingPose(f, earth) -- 421
		options.camera:lookAt( -- 422
			pose.eye, -- 422
			pose.target, -- 422
			Vec3(0, 1, 0) -- 422
		) -- 422
		if backdrop ~= nil then -- 422
			backdrop:sync(pose.eye, pose.target) -- 423
		end -- 423
		local view = { -- 425
			eye = pose.eye, -- 426
			target = pose.target, -- 427
			up = {x = 0, y = 1, z = 0}, -- 428
			fovYDeg = options.fovYDeg, -- 429
			aspect = options.aspect, -- 430
			viewW = viewW, -- 431
			viewH = viewH -- 432
		} -- 432
		return prepareCamera(view, HANDEDNESS, FLIP_Y) -- 434
	end -- 409
	local function drawRings(basis) -- 437
		orbitDraw:clear() -- 438
		do -- 438
			local i = 0 -- 439
			while i < #ringSamples do -- 439
				local verts = projectPolyline( -- 440
					ringSamples[i + 1], -- 440
					0, -- 440
					basis, -- 440
					viewW * 0.5, -- 440
					viewH * 0.5 -- 440
				) -- 440
				drawDashedPolyline( -- 441
					orbitDraw, -- 442
					verts, -- 442
					RingRadius, -- 442
					RingRgb, -- 442
					1, -- 442
					RingGlowFactor, -- 442
					RingGlowAlpha, -- 442
					RingDashOn, -- 443
					RingDashOff, -- 443
					false -- 443
				) -- 443
				i = i + 1 -- 439
			end -- 439
		end -- 439
	end -- 437
	--- 文案的呼吸节奏（帧号写死在这里 = 分镜表）。
	local function updateLabels(f) -- 449
		if mode == "idle" then -- 449
			hideLabel(title) -- 452
			hideLabel(subtitle) -- 453
			hideLabel(tagline) -- 454
			hideLabel(narration) -- 455
			hideLabel(skip) -- 456
			return -- 457
		end -- 457
		local outA = ____exports.WideFrames - 10 -- 459
		local outB = ____exports.WideFrames + 40 -- 460
		applyAlpha( -- 461
			title, -- 461
			TitleHex, -- 461
			fadeWindow( -- 461
				f, -- 461
				14, -- 461
				48, -- 461
				outA, -- 461
				outB -- 461
			) -- 461
		) -- 461
		applyAlpha( -- 462
			subtitle, -- 462
			SubtitleHex, -- 462
			fadeWindow( -- 462
				f, -- 462
				20, -- 462
				54, -- 462
				outA, -- 462
				outB -- 462
			) -- 462
		) -- 462
		applyAlpha( -- 463
			tagline, -- 463
			TaglineHex, -- 463
			fadeWindow( -- 463
				f, -- 463
				26, -- 463
				62, -- 463
				outA, -- 463
				outB -- 463
			) -- 463
		) -- 463
		applyAlpha( -- 464
			narration, -- 464
			NarrationHex, -- 464
			fadeWindow( -- 465
				f, -- 465
				____exports.WideFrames + 70, -- 465
				____exports.WideFrames + 130, -- 465
				____exports.TotalFrames - 70, -- 465
				____exports.TotalFrames - 10 -- 465
			) -- 465
		) -- 465
		applyAlpha( -- 466
			skip, -- 466
			SkipHex, -- 466
			fadeWindow( -- 466
				f, -- 466
				60, -- 466
				100, -- 466
				____exports.TotalFrames - 40, -- 466
				____exports.TotalFrames + 10 -- 466
			) -- 466
		) -- 466
	end -- 449
	local function update(f) -- 469
		local basis = updateWorld(f) -- 470
		drawRings(basis) -- 471
		updateLabels(f) -- 472
	end -- 469
	local function finish() -- 475
		if mode ~= "intro" then -- 475
			return -- 476
		end -- 476
		mode = "idle" -- 477
		skipLayer.touchEnabled = false -- 478
		options:onFinish() -- 479
	end -- 475
	skipLayer:onTapEnded(function() -- 482
		finish() -- 483
	end) -- 482
	skipLayer.touchEnabled = false -- 486
	ui.visible = false -- 487
	return { -- 489
		start = function() -- 490
			mode = "intro" -- 491
			frame = 0 -- 492
			root.visible = true -- 493
			ui.visible = true -- 494
			skipLayer.touchEnabled = true -- 495
			update(0) -- 496
		end, -- 490
		step = function() -- 498
			if mode == "off" then -- 498
				return -- 499
			end -- 499
			frame = frame + 1 -- 500
			update(frame) -- 501
			if mode == "intro" and frame >= ____exports.TotalFrames then -- 501
				finish() -- 502
			end -- 502
		end, -- 498
		skip = function() -- 504
			finish() -- 505
		end, -- 504
		frameIndex = function() return frame end, -- 507
		idle = function() -- 508
			mode = "idle" -- 509
			root.visible = true -- 510
			ui.visible = true -- 511
			skipLayer.touchEnabled = false -- 512
			update(frame < 0 and 0 or frame) -- 513
		end, -- 508
		phase = function() return mode == "off" and "off" or ____exports.openingPhase(frame) end, -- 515
		running = function() return mode ~= "off" end, -- 516
		hide = function() -- 517
			mode = "off" -- 518
			root.visible = false -- 519
			ui.visible = false -- 520
			skipLayer.touchEnabled = false -- 521
		end -- 517
	} -- 517
end -- 309
return ____exports -- 309
-- [ts]: PlanView.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 28
local Color = ____Dora.Color -- 28
local DrawNode = ____Dora.DrawNode -- 28
local Node = ____Dora.Node -- 28
local Vec2 = ____Dora.Vec2 -- 28
local ____Gravity = require("game.Gravity") -- 29
local bodyPositionAt = ____Gravity.bodyPositionAt -- 29
local distance = ____Gravity.distance -- 29
local ____OrbitFlow = require("game.OrbitFlow") -- 30
local FlowDotsPerOrbit = ____OrbitFlow.FlowDotsPerOrbit -- 30
local flowDotPosition = ____OrbitFlow.flowDotPosition -- 30
local ____Trajectory = require("game.Trajectory") -- 31
local decimate = ____Trajectory.decimate -- 31
local ____Tuning = require("game.Tuning") -- 33
local PROBE_VISUAL_RADIUS = ____Tuning.PROBE_VISUAL_RADIUS -- 33
local ____Ui = require("game.Ui") -- 34
local colorFromHex = ____Ui.colorFromHex -- 34
--- 求"把半径 `radius` 的圆完整放进视口"的等比映射，四周留 `marginFrac` 的边距。
-- 
-- 取 x / y 两个方向里**更紧**的那个比例 ⇒ 至少一个方向正好贴住边距，另一个方向更宽松。
-- `marginFrac` 夹在 [0, 0.45]：写 0.5 会让可用区域变成 0（映射退化）。
function ____exports.computePlanMapping(viewW, viewH, radius, marginFrac, centerX, centerY) -- 68
	local m = marginFrac -- 69
	if m < 0 then -- 69
		m = 0 -- 70
	end -- 70
	if m > 0.45 then -- 70
		m = 0.45 -- 71
	end -- 71
	local usable = 1 - 2 * m -- 72
	local r = radius > 0.000001 and radius or 1 -- 73
	local sx = viewW * usable / (2 * r) -- 74
	local sy = viewH * usable / (2 * r) -- 75
	local scale = sx < sy and sx or sy -- 76
	if not (scale > 0) then -- 76
		scale = 1 -- 77
	end -- 77
	return { -- 78
		scale = scale, -- 79
		originX = viewW / 2, -- 80
		originY = viewH / 2, -- 81
		centerX = centerX ~= nil and centerX or 0, -- 82
		centerY = centerY ~= nil and centerY or 0 -- 83
	} -- 83
end -- 68
--- 平面点 → 屏幕像素（左下原点、+Y 向上）。
-- 
-- ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
function ____exports.planeToScreen(p, m) -- 92
	return {x = m.originX + (p.x - m.centerX) * m.scale, y = m.originY - (p.y - m.centerY) * m.scale} -- 94
end -- 92
--- `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。
function ____exports.screenToPlane(q, m) -- 98
	return {x = (q.x - m.originX) / m.scale + m.centerX, y = (m.originY - q.y) / m.scale + m.centerY} -- 99
end -- 98
--- 天体（含卫星的宿主链）到平面原点的**最大**距离。
-- 
-- 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
local function bodyCenterDist(b) -- 107
	local own = b.orbitRadius > 0 and b.orbitRadius or 0 -- 108
	if b.host ~= nil then -- 108
		return bodyCenterDist(b.host) + own -- 109
	end -- 109
	return own -- 110
end -- 107
--- 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
-- 
-- - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
-- - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance, centerIndex) -- 119
	if centerIndex ~= nil and centerIndex >= 0 and centerIndex < #bodies then -- 119
		local c = bodies[centerIndex + 1] -- 122
		local cp = bodyPositionAt(c, 0) -- 123
		local r = 0 -- 124
		local lim = c.orbitRadius * 0.5 -- 130
		do -- 130
			local i = 0 -- 131
			while i < #bodies do -- 131
				do -- 131
					local b = bodies[i + 1] -- 132
					if b ~= c then -- 132
						if b.orbitRadius <= 0 or b.orbitRadius >= lim then -- 132
							goto __continue13 -- 134
						end -- 134
						if distance( -- 134
							bodyPositionAt(b, 0), -- 135
							cp -- 135
						) >= lim then -- 135
							goto __continue13 -- 135
						end -- 135
					end -- 135
					local p = bodyPositionAt(b, 0) -- 137
					local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 138
					local d = distance(p, cp) + pad -- 139
					if d > r then -- 139
						r = d -- 140
					end -- 140
				end -- 140
				::__continue13:: -- 140
				i = i + 1 -- 131
			end -- 131
		end -- 131
		local pd = distance(probeStart, cp) -- 142
		if pd > r then -- 142
			r = pd -- 143
		end -- 143
		return r > 0.000001 and r or 1 -- 144
	end -- 144
	local r = 0 -- 146
	do -- 146
		local i = 0 -- 147
		while i < #bodies do -- 147
			local b = bodies[i + 1] -- 148
			local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 149
			local d = bodyCenterDist(b) + pad -- 150
			if d > r then -- 150
				r = d -- 151
			end -- 151
			i = i + 1 -- 147
		end -- 147
	end -- 147
	local pd = math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y) -- 153
	if pd > r then -- 153
		r = pd -- 154
	end -- 154
	return r > 0.000001 and r or 1 -- 155
end -- 119
--- 判定"这两个天体是不是同一个"（scaledPlanets 拷贝过宿主链 ⇒ 不能比对象身份，比位置与 gm）。
function ____exports.sameBody(a, b) -- 159
	return a.gm == b.gm and a.radius == b.radius and a.orbitRadius == b.orbitRadius -- 160
end -- 159
--- 2D 到达圈的半径（平面单位）—— **就是航点容差，绝不是视觉半径**。
-- 
-- S5 §3.8 规则 3：旧的硬约束「视觉半径必须等于物理半径」作废之后，
-- 玩家判断"够不够得着"的唯一依据变成了这个圈。所以它必须由容差算出，
-- 且**不随视觉半径变化** —— Test/PlanViewTest 有断言守着这两条。
function ____exports.arrivalRingRadius(goal) -- 170
	local r = goal.tolerance -- 171
	if goal.chain ~= nil then -- 171
		do -- 171
			local i = 0 -- 173
			while i < #goal.chain do -- 173
				if goal.chain[i + 1].tolerance > r then -- 173
					r = goal.chain[i + 1].tolerance -- 174
				end -- 174
				i = i + 1 -- 173
			end -- 173
		end -- 173
	end -- 173
	return r -- 177
end -- 170
function ____exports.defaultPlanOptions() -- 227
	return { -- 228
		marginFrac = 0.12, -- 229
		orbitHex = 4610157, -- 230
		orbitWidth = 1.5, -- 231
		orbitSegments = 72, -- 232
		ringHex = 9890780, -- 233
		ringWidth = 2.5, -- 234
		ringSegments = 48, -- 235
		pinRadius = 8, -- 236
		sunPinRadius = 13, -- 237
		sunGmMin = 10000, -- 238
		probePinRadius = 11, -- 239
		maxPinRadius = 26, -- 240
		probeTickLen = 22, -- 241
		predictHex = 7915775, -- 242
		predictWidth = 2.5, -- 243
		polylineMaxPoints = 240, -- 244
		trailHex = 16772266, -- 245
		trailWidth = 3.5, -- 246
		flowDotRadius = 3.5, -- 247
		flowDotHex = 16773327, -- 248
		probeHex = 15398143, -- 249
		probeOrbitHex = 6127526 -- 250
	} -- 250
end -- 227
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 307
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 308
	local root = Node() -- 311
	local orbitDraw = DrawNode() -- 312
	local dotDraw = DrawNode() -- 313
	local ringDraw = DrawNode() -- 314
	local pathDraw = DrawNode() -- 315
	local pinDraw = DrawNode() -- 316
	local beaconDraw = DrawNode() -- 317
	root:addChild(orbitDraw) -- 318
	root:addChild(dotDraw) -- 319
	root:addChild(ringDraw) -- 320
	root:addChild(pathDraw) -- 321
	root:addChild(pinDraw) -- 322
	root:addChild(beaconDraw) -- 323
	layer:addChild(root) -- 324
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 326
	local ringColor = colorFromHex(options.ringHex, 1) -- 327
	local predictColor = colorFromHex(options.predictHex, 1) -- 328
	local trailColor = colorFromHex(options.trailHex, 1) -- 329
	local probeColor = colorFromHex(options.probeHex, 1) -- 330
	local probeOrbitColor = colorFromHex(options.probeOrbitHex, 1) -- 331
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 332
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 334
	local isVisible = true -- 336
	local currentZoom = 1 -- 337
	local panOffsetX = 0 -- 338
	local panOffsetY = 0 -- 339
	local baseFitRadius = 1 -- 340
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 341
	local dirty = true -- 342
	local function recomputeMap() -- 344
		local effectiveR = baseFitRadius / currentZoom -- 345
		local newMap = ____exports.computePlanMapping( -- 346
			viewW, -- 346
			viewH, -- 346
			effectiveR, -- 346
			options.marginFrac, -- 346
			map.centerX, -- 346
			map.centerY -- 346
		) -- 346
		newMap.originX = viewW / 2 + panOffsetX -- 347
		newMap.originY = viewH / 2 + panOffsetY -- 348
		map = newMap -- 349
		dirty = true -- 350
	end -- 344
	local bodies = {} -- 354
	local visuals = {} -- 355
	local probeOrbitCenter = {x = 0, y = 0} -- 357
	local probeOrbitRadius = 0 -- 358
	local tWorld = 0 -- 359
	local probe = {x = 0, y = 0} -- 360
	local probeVel = {x = 0, y = 0} -- 361
	local pred = {} -- 362
	local trail = {} -- 363
	local rings = {} -- 364
	local function clearAll() -- 366
		orbitDraw:clear() -- 367
		dotDraw:clear() -- 368
		ringDraw:clear() -- 369
		pathDraw:clear() -- 370
		pinDraw:clear() -- 371
		beaconDraw:clear() -- 372
	end -- 366
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 376
		local seg = n > 8 and n or 8 -- 377
		local out = {} -- 378
		do -- 378
			local i = 0 -- 379
			while i < seg do -- 379
				local a = i / seg * 2 * math.pi -- 380
				out[#out + 1] = Vec2( -- 381
					cx + rPx * math.cos(a), -- 381
					cy + rPx * math.sin(a) -- 381
				) -- 381
				i = i + 1 -- 379
			end -- 379
		end -- 379
		return out -- 383
	end -- 376
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 387
		if #pts < 2 then -- 387
			return -- 388
		end -- 388
		local dec = decimate(pts, options.polylineMaxPoints) -- 389
		local prev = nil -- 390
		for ____, p in ipairs(dec) do -- 391
			local s = ____exports.planeToScreen(p, map) -- 392
			local cur = Vec2(s.x, s.y) -- 393
			if prev ~= nil then -- 393
				pathDraw:drawSegment(prev, cur, width, color) -- 394
			end -- 394
			prev = cur -- 395
		end -- 395
	end -- 387
	local function redraw() -- 399
		clearAll() -- 400
		if not isVisible then -- 400
			return -- 401
		end -- 401
		for ____, b in ipairs(bodies) do -- 404
			do -- 404
				if b.orbitRadius <= 0 then -- 404
					goto __continue43 -- 405
				end -- 405
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 406
				local s = ____exports.planeToScreen(center, map) -- 407
				local rPx = b.orbitRadius * map.scale -- 408
				if rPx < 1 then -- 408
					goto __continue43 -- 409
				end -- 409
				orbitDraw:drawPolygon( -- 410
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 410
					noFill, -- 410
					options.orbitWidth, -- 410
					orbitColor -- 410
				) -- 410
			end -- 410
			::__continue43:: -- 410
		end -- 410
		if probeOrbitRadius > 0 then -- 410
			local ps = ____exports.planeToScreen(probeOrbitCenter, map) -- 415
			local pr = probeOrbitRadius * map.scale -- 416
			if pr >= 1 then -- 416
				orbitDraw:drawPolygon( -- 417
					circleVerts(ps.x, ps.y, pr, options.orbitSegments), -- 417
					noFill, -- 417
					options.orbitWidth, -- 417
					probeOrbitColor -- 417
				) -- 417
			end -- 417
		end -- 417
		if options.flowDotRadius > 0 then -- 417
			for ____, b in ipairs(bodies) do -- 424
				do -- 424
					if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 424
						goto __continue50 -- 425
					end -- 425
					local rPx = b.orbitRadius * map.scale -- 426
					if rPx < 1 then -- 426
						goto __continue50 -- 427
					end -- 427
					do -- 427
						local k = 0 -- 428
						while k < FlowDotsPerOrbit do -- 428
							local s = ____exports.planeToScreen( -- 429
								flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 429
								map -- 429
							) -- 429
							dotDraw:drawDot( -- 430
								Vec2(s.x, s.y), -- 430
								options.flowDotRadius, -- 430
								flowDotColor -- 430
							) -- 430
							k = k + 1 -- 428
						end -- 428
					end -- 428
				end -- 428
				::__continue50:: -- 428
			end -- 428
		end -- 428
		for ____, ring in ipairs(rings) do -- 435
			do -- 435
				local s = ____exports.planeToScreen(ring.center, map) -- 436
				local rPx = ring.radius * map.scale -- 437
				if rPx < 1 then -- 437
					goto __continue56 -- 438
				end -- 438
				ringDraw:drawPolygon( -- 439
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 439
					noFill, -- 439
					options.ringWidth, -- 439
					ringColor -- 439
				) -- 439
			end -- 439
			::__continue56:: -- 439
		end -- 439
		drawPolyline(trail, trailColor, options.trailWidth) -- 443
		drawPolyline(pred, predictColor, options.predictWidth) -- 444
		do -- 444
			local i = 0 -- 452
			while i < #bodies do -- 452
				local b = bodies[i + 1] -- 453
				local s = ____exports.planeToScreen( -- 454
					bodyPositionAt(b, tWorld), -- 454
					map -- 454
				) -- 454
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 455
				if i < #visuals then -- 455
					local v = visuals[i + 1] -- 457
					local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 458
					if vr > r then -- 458
						r = vr -- 459
					end -- 459
					if r > options.maxPinRadius then -- 459
						r = options.maxPinRadius -- 460
					end -- 460
				end -- 460
				local col = orbitColor -- 462
				if i < #visuals then -- 462
					local v = visuals[i + 1] -- 464
					col = Color( -- 465
						math.floor(v.r * 255), -- 465
						math.floor(v.g * 255), -- 465
						math.floor(v.b * 255), -- 465
						255 -- 465
					) -- 465
				end -- 465
				pinDraw:drawDot( -- 467
					Vec2(s.x, s.y), -- 467
					r, -- 467
					col -- 467
				) -- 467
				i = i + 1 -- 452
			end -- 452
		end -- 452
		local ps = ____exports.planeToScreen(probe, map) -- 471
		local pr = options.probePinRadius -- 472
		if PROBE_VISUAL_RADIUS > 0 and PROBE_VISUAL_RADIUS * map.scale > pr then -- 472
			pr = PROBE_VISUAL_RADIUS * map.scale -- 473
		end -- 473
		if pr > options.maxPinRadius then -- 473
			pr = options.maxPinRadius -- 474
		end -- 474
		pinDraw:drawDot( -- 475
			Vec2(ps.x, ps.y), -- 475
			pr, -- 475
			probeColor -- 475
		) -- 475
		pinDraw:drawPolygon( -- 476
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 476
			noFill, -- 476
			1.5, -- 476
			probeColor -- 476
		) -- 476
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 477
		if vlen > 0.000001 then -- 477
			local dx = probeVel.x / vlen -- 479
			local dy = probeVel.y / vlen -- 480
			pinDraw:drawSegment( -- 481
				Vec2(ps.x, ps.y), -- 482
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 483
				2, -- 484
				probeColor -- 485
			) -- 485
		end -- 485
		if #rings > 0 then -- 485
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 491
			local pad = 48 -- 492
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 493
			if isOffscreen then -- 493
				local cx = viewW / 2 -- 495
				local cy = viewH / 2 -- 496
				local dirX = targetScreen.x - cx -- 497
				local dirY = targetScreen.y - cy -- 498
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 499
				if len > 0.0001 then -- 499
					local ux = dirX / len -- 501
					local uy = dirY / len -- 502
					local halfW = viewW / 2 - pad -- 503
					local halfH = viewH / 2 - pad -- 504
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 505
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 506
					local tHit = math.min(scaleX, scaleY) -- 507
					local hitX = cx + ux * tHit -- 508
					local hitY = cy + uy * tHit -- 509
					local arrowLen = 18 -- 510
					local arrowHalf = 9 -- 511
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 512
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 513
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 514
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 515
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 516
					beaconDraw:drawDot( -- 517
						Vec2(hitX, hitY), -- 517
						4, -- 517
						ringColor -- 517
					) -- 517
				end -- 517
			end -- 517
		end -- 517
		dirty = false -- 521
	end -- 399
	return { -- 524
		setVisible = function(self, on) -- 525
			isVisible = on -- 526
			root.visible = on -- 527
			if not on then -- 527
				clearAll() -- 530
				dirty = false -- 531
			else -- 531
				dirty = true -- 533
			end -- 533
		end, -- 525
		visible = function(self) -- 536
			return isVisible -- 537
		end, -- 536
		fitTo = function(self, radius) -- 539
			baseFitRadius = radius -- 540
			recomputeMap() -- 541
		end, -- 539
		syncBodies = function(self, bs, vs, t) -- 543
			bodies = bs -- 544
			visuals = vs -- 545
			tWorld = t -- 546
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 546
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 550
				map.centerX = cp.x -- 551
				map.centerY = cp.y -- 552
				dirty = true -- 554
			end -- 554
			dirty = true -- 556
		end, -- 543
		syncProbe = function(self, p, v) -- 558
			probe = p -- 559
			probeVel = v -- 560
			dirty = true -- 561
		end, -- 558
		setPrediction = function(self, points) -- 563
			pred = points -- 564
			dirty = true -- 565
		end, -- 563
		clearPrediction = function(self) -- 567
			pred = {} -- 568
			dirty = true -- 569
		end, -- 567
		setTrail = function(self, points) -- 571
			trail = points -- 572
			dirty = true -- 573
		end, -- 571
		clearTrail = function(self) -- 575
			trail = {} -- 576
			dirty = true -- 577
		end, -- 575
		setProbeOrbit = function(self, center, radius) -- 579
			probeOrbitCenter = center -- 580
			probeOrbitRadius = radius -- 581
			dirty = true -- 582
		end, -- 579
		clearProbeOrbit = function(self) -- 584
			probeOrbitRadius = 0 -- 585
			dirty = true -- 586
		end, -- 584
		setGoalRings = function(self, rs) -- 588
			rings = rs -- 589
			dirty = true -- 590
		end, -- 588
		clearGoalRings = function(self) -- 592
			rings = {} -- 593
			dirty = true -- 594
		end, -- 592
		flush = function(self) -- 596
			if not isVisible then -- 596
				return -- 598
			end -- 598
			if not dirty then -- 598
				return -- 599
			end -- 599
			redraw() -- 600
		end, -- 596
		clear = function(self) -- 602
			clearAll() -- 603
			dirty = true -- 604
		end, -- 602
		probeScreen = function(self) -- 606
			return ____exports.planeToScreen(probe, map) -- 607
		end, -- 606
		mapping = function(self) -- 609
			return map -- 610
		end, -- 609
		zoomIn = function(self) -- 612
			currentZoom = math.min(60, currentZoom * 1.5) -- 615
			recomputeMap() -- 616
		end, -- 612
		zoomOut = function(self) -- 618
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 619
			recomputeMap() -- 620
		end, -- 618
		resetView = function(self) -- 622
			currentZoom = 1 -- 623
			panOffsetX = 0 -- 624
			panOffsetY = 0 -- 625
			recomputeMap() -- 626
		end, -- 622
		pan = function(self, dx, dy) -- 628
			panOffsetX = panOffsetX + dx -- 629
			panOffsetY = panOffsetY + dy -- 630
			recomputeMap() -- 631
		end, -- 628
		getZoom = function(self) -- 633
			return currentZoom -- 634
		end, -- 633
		root = root -- 636
	} -- 636
end -- 307
return ____exports -- 307
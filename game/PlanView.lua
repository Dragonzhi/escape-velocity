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
function ____exports.defaultPlanOptions() -- 225
	return { -- 226
		marginFrac = 0.12, -- 227
		orbitHex = 4610157, -- 228
		orbitWidth = 1.5, -- 229
		orbitSegments = 72, -- 230
		ringHex = 9890780, -- 231
		ringWidth = 2.5, -- 232
		ringSegments = 48, -- 233
		pinRadius = 8, -- 234
		sunPinRadius = 13, -- 235
		sunGmMin = 10000, -- 236
		probePinRadius = 11, -- 237
		maxPinRadius = 26, -- 238
		probeTickLen = 22, -- 239
		predictHex = 7915775, -- 240
		predictWidth = 2.5, -- 241
		polylineMaxPoints = 240, -- 242
		trailHex = 16772266, -- 243
		trailWidth = 3.5, -- 244
		flowDotRadius = 3.5, -- 245
		flowDotHex = 16773327, -- 246
		probeHex = 15398143 -- 247
	} -- 247
end -- 225
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 301
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 302
	local root = Node() -- 305
	local orbitDraw = DrawNode() -- 306
	local dotDraw = DrawNode() -- 307
	local ringDraw = DrawNode() -- 308
	local pathDraw = DrawNode() -- 309
	local pinDraw = DrawNode() -- 310
	local beaconDraw = DrawNode() -- 311
	root:addChild(orbitDraw) -- 312
	root:addChild(dotDraw) -- 313
	root:addChild(ringDraw) -- 314
	root:addChild(pathDraw) -- 315
	root:addChild(pinDraw) -- 316
	root:addChild(beaconDraw) -- 317
	layer:addChild(root) -- 318
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 320
	local ringColor = colorFromHex(options.ringHex, 1) -- 321
	local predictColor = colorFromHex(options.predictHex, 1) -- 322
	local trailColor = colorFromHex(options.trailHex, 1) -- 323
	local probeColor = colorFromHex(options.probeHex, 1) -- 324
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 325
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 327
	local isVisible = true -- 329
	local currentZoom = 1 -- 330
	local panOffsetX = 0 -- 331
	local panOffsetY = 0 -- 332
	local baseFitRadius = 1 -- 333
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 334
	local dirty = true -- 335
	local function recomputeMap() -- 337
		local effectiveR = baseFitRadius / currentZoom -- 338
		local newMap = ____exports.computePlanMapping( -- 339
			viewW, -- 339
			viewH, -- 339
			effectiveR, -- 339
			options.marginFrac, -- 339
			map.centerX, -- 339
			map.centerY -- 339
		) -- 339
		newMap.originX = viewW / 2 + panOffsetX -- 340
		newMap.originY = viewH / 2 + panOffsetY -- 341
		map = newMap -- 342
		dirty = true -- 343
	end -- 337
	local bodies = {} -- 347
	local visuals = {} -- 348
	local tWorld = 0 -- 349
	local probe = {x = 0, y = 0} -- 350
	local probeVel = {x = 0, y = 0} -- 351
	local pred = {} -- 352
	local trail = {} -- 353
	local rings = {} -- 354
	local function clearAll() -- 356
		orbitDraw:clear() -- 357
		dotDraw:clear() -- 358
		ringDraw:clear() -- 359
		pathDraw:clear() -- 360
		pinDraw:clear() -- 361
		beaconDraw:clear() -- 362
	end -- 356
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 366
		local seg = n > 8 and n or 8 -- 367
		local out = {} -- 368
		do -- 368
			local i = 0 -- 369
			while i < seg do -- 369
				local a = i / seg * 2 * math.pi -- 370
				out[#out + 1] = Vec2( -- 371
					cx + rPx * math.cos(a), -- 371
					cy + rPx * math.sin(a) -- 371
				) -- 371
				i = i + 1 -- 369
			end -- 369
		end -- 369
		return out -- 373
	end -- 366
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 377
		if #pts < 2 then -- 377
			return -- 378
		end -- 378
		local dec = decimate(pts, options.polylineMaxPoints) -- 379
		local prev = nil -- 380
		for ____, p in ipairs(dec) do -- 381
			local s = ____exports.planeToScreen(p, map) -- 382
			local cur = Vec2(s.x, s.y) -- 383
			if prev ~= nil then -- 383
				pathDraw:drawSegment(prev, cur, width, color) -- 384
			end -- 384
			prev = cur -- 385
		end -- 385
	end -- 377
	local function redraw() -- 389
		clearAll() -- 390
		if not isVisible then -- 390
			return -- 391
		end -- 391
		for ____, b in ipairs(bodies) do -- 394
			do -- 394
				if b.orbitRadius <= 0 then -- 394
					goto __continue43 -- 395
				end -- 395
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 396
				local s = ____exports.planeToScreen(center, map) -- 397
				local rPx = b.orbitRadius * map.scale -- 398
				if rPx < 1 then -- 398
					goto __continue43 -- 399
				end -- 399
				orbitDraw:drawPolygon( -- 400
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 400
					noFill, -- 400
					options.orbitWidth, -- 400
					orbitColor -- 400
				) -- 400
			end -- 400
			::__continue43:: -- 400
		end -- 400
		for ____, b in ipairs(bodies) do -- 407
			do -- 407
				if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 407
					goto __continue47 -- 408
				end -- 408
				local rPx = b.orbitRadius * map.scale -- 409
				if rPx < 1 then -- 409
					goto __continue47 -- 410
				end -- 410
				do -- 410
					local k = 0 -- 411
					while k < FlowDotsPerOrbit do -- 411
						local s = ____exports.planeToScreen( -- 412
							flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 412
							map -- 412
						) -- 412
						dotDraw:drawDot( -- 413
							Vec2(s.x, s.y), -- 413
							options.flowDotRadius, -- 413
							flowDotColor -- 413
						) -- 413
						k = k + 1 -- 411
					end -- 411
				end -- 411
			end -- 411
			::__continue47:: -- 411
		end -- 411
		for ____, ring in ipairs(rings) do -- 418
			do -- 418
				local s = ____exports.planeToScreen(ring.center, map) -- 419
				local rPx = ring.radius * map.scale -- 420
				if rPx < 1 then -- 420
					goto __continue53 -- 421
				end -- 421
				ringDraw:drawPolygon( -- 422
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 422
					noFill, -- 422
					options.ringWidth, -- 422
					ringColor -- 422
				) -- 422
			end -- 422
			::__continue53:: -- 422
		end -- 422
		drawPolyline(trail, trailColor, options.trailWidth) -- 426
		drawPolyline(pred, predictColor, options.predictWidth) -- 427
		do -- 427
			local i = 0 -- 435
			while i < #bodies do -- 435
				local b = bodies[i + 1] -- 436
				local s = ____exports.planeToScreen( -- 437
					bodyPositionAt(b, tWorld), -- 437
					map -- 437
				) -- 437
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 438
				if i < #visuals then -- 438
					local v = visuals[i + 1] -- 440
					local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 441
					if vr > r then -- 441
						r = vr -- 442
					end -- 442
					if r > options.maxPinRadius then -- 442
						r = options.maxPinRadius -- 443
					end -- 443
				end -- 443
				local col = orbitColor -- 445
				if i < #visuals then -- 445
					local v = visuals[i + 1] -- 447
					col = Color( -- 448
						math.floor(v.r * 255), -- 448
						math.floor(v.g * 255), -- 448
						math.floor(v.b * 255), -- 448
						255 -- 448
					) -- 448
				end -- 448
				pinDraw:drawDot( -- 450
					Vec2(s.x, s.y), -- 450
					r, -- 450
					col -- 450
				) -- 450
				i = i + 1 -- 435
			end -- 435
		end -- 435
		local ps = ____exports.planeToScreen(probe, map) -- 454
		local pr = options.probePinRadius -- 455
		if PROBE_VISUAL_RADIUS > 0 and PROBE_VISUAL_RADIUS * map.scale > pr then -- 455
			pr = PROBE_VISUAL_RADIUS * map.scale -- 456
		end -- 456
		if pr > options.maxPinRadius then -- 456
			pr = options.maxPinRadius -- 457
		end -- 457
		pinDraw:drawDot( -- 458
			Vec2(ps.x, ps.y), -- 458
			pr, -- 458
			probeColor -- 458
		) -- 458
		pinDraw:drawPolygon( -- 459
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 459
			noFill, -- 459
			1.5, -- 459
			probeColor -- 459
		) -- 459
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 460
		if vlen > 0.000001 then -- 460
			local dx = probeVel.x / vlen -- 462
			local dy = probeVel.y / vlen -- 463
			pinDraw:drawSegment( -- 464
				Vec2(ps.x, ps.y), -- 465
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 466
				2, -- 467
				probeColor -- 468
			) -- 468
		end -- 468
		if #rings > 0 then -- 468
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 474
			local pad = 48 -- 475
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 476
			if isOffscreen then -- 476
				local cx = viewW / 2 -- 478
				local cy = viewH / 2 -- 479
				local dirX = targetScreen.x - cx -- 480
				local dirY = targetScreen.y - cy -- 481
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 482
				if len > 0.0001 then -- 482
					local ux = dirX / len -- 484
					local uy = dirY / len -- 485
					local halfW = viewW / 2 - pad -- 486
					local halfH = viewH / 2 - pad -- 487
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 488
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 489
					local tHit = math.min(scaleX, scaleY) -- 490
					local hitX = cx + ux * tHit -- 491
					local hitY = cy + uy * tHit -- 492
					local arrowLen = 18 -- 493
					local arrowHalf = 9 -- 494
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 495
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 496
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 497
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 498
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 499
					beaconDraw:drawDot( -- 500
						Vec2(hitX, hitY), -- 500
						4, -- 500
						ringColor -- 500
					) -- 500
				end -- 500
			end -- 500
		end -- 500
		dirty = false -- 504
	end -- 389
	return { -- 507
		setVisible = function(self, on) -- 508
			isVisible = on -- 509
			root.visible = on -- 510
			if not on then -- 510
				clearAll() -- 513
				dirty = false -- 514
			else -- 514
				dirty = true -- 516
			end -- 516
		end, -- 508
		visible = function(self) -- 519
			return isVisible -- 520
		end, -- 519
		fitTo = function(self, radius) -- 522
			baseFitRadius = radius -- 523
			recomputeMap() -- 524
		end, -- 522
		syncBodies = function(self, bs, vs, t) -- 526
			bodies = bs -- 527
			visuals = vs -- 528
			tWorld = t -- 529
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 529
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 533
				map.centerX = cp.x -- 534
				map.centerY = cp.y -- 535
				dirty = true -- 537
			end -- 537
			dirty = true -- 539
		end, -- 526
		syncProbe = function(self, p, v) -- 541
			probe = p -- 542
			probeVel = v -- 543
			dirty = true -- 544
		end, -- 541
		setPrediction = function(self, points) -- 546
			pred = points -- 547
			dirty = true -- 548
		end, -- 546
		clearPrediction = function(self) -- 550
			pred = {} -- 551
			dirty = true -- 552
		end, -- 550
		setTrail = function(self, points) -- 554
			trail = points -- 555
			dirty = true -- 556
		end, -- 554
		clearTrail = function(self) -- 558
			trail = {} -- 559
			dirty = true -- 560
		end, -- 558
		setGoalRings = function(self, rs) -- 562
			rings = rs -- 563
			dirty = true -- 564
		end, -- 562
		clearGoalRings = function(self) -- 566
			rings = {} -- 567
			dirty = true -- 568
		end, -- 566
		flush = function(self) -- 570
			if not isVisible then -- 570
				return -- 572
			end -- 572
			if not dirty then -- 572
				return -- 573
			end -- 573
			redraw() -- 574
		end, -- 570
		clear = function(self) -- 576
			clearAll() -- 577
			dirty = true -- 578
		end, -- 576
		probeScreen = function(self) -- 580
			return ____exports.planeToScreen(probe, map) -- 581
		end, -- 580
		mapping = function(self) -- 583
			return map -- 584
		end, -- 583
		zoomIn = function(self) -- 586
			currentZoom = math.min(6, currentZoom * 1.35) -- 587
			recomputeMap() -- 588
		end, -- 586
		zoomOut = function(self) -- 590
			currentZoom = math.max(0.25, currentZoom / 1.35) -- 591
			recomputeMap() -- 592
		end, -- 590
		resetView = function(self) -- 594
			currentZoom = 1 -- 595
			panOffsetX = 0 -- 596
			panOffsetY = 0 -- 597
			recomputeMap() -- 598
		end, -- 594
		pan = function(self, dx, dy) -- 600
			panOffsetX = panOffsetX + dx -- 601
			panOffsetY = panOffsetY + dy -- 602
			recomputeMap() -- 603
		end, -- 600
		getZoom = function(self) -- 605
			return currentZoom -- 606
		end, -- 605
		root = root -- 608
	} -- 608
end -- 301
return ____exports -- 301
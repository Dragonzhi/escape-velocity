-- [ts]: PlanView.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local __TS__StringCharAt = ____lualib.__TS__StringCharAt -- 1
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
local ____Scale = require("game.Scale") -- 33
local KmPerUnit = ____Scale.KmPerUnit -- 33
local ____Tuning = require("game.Tuning") -- 34
local PROBE_VISUAL_RADIUS = ____Tuning.PROBE_VISUAL_RADIUS -- 34
local bodyLabel = ____Tuning.bodyLabel -- 34
local ____Ui = require("game.Ui") -- 35
local colorFromHex = ____Ui.colorFromHex -- 35
local createLabel = ____Ui.createLabel -- 35
local setLabelCenter = ____Ui.setLabelCenter -- 35
local setLabelText = ____Ui.setLabelText -- 35
local setLabelVisible = ____Ui.setLabelVisible -- 35
--- 求"把半径 `radius` 的圆完整放进视口"的等比映射，四周留 `marginFrac` 的边距。
-- 
-- 取 x / y 两个方向里**更紧**的那个比例 ⇒ 至少一个方向正好贴住边距，另一个方向更宽松。
-- `marginFrac` 夹在 [0, 0.45]：写 0.5 会让可用区域变成 0（映射退化）。
function ____exports.computePlanMapping(viewW, viewH, radius, marginFrac, centerX, centerY) -- 69
	local m = marginFrac -- 70
	if m < 0 then -- 70
		m = 0 -- 71
	end -- 71
	if m > 0.45 then -- 71
		m = 0.45 -- 72
	end -- 72
	local usable = 1 - 2 * m -- 73
	local r = radius > 0.000001 and radius or 1 -- 74
	local sx = viewW * usable / (2 * r) -- 75
	local sy = viewH * usable / (2 * r) -- 76
	local scale = sx < sy and sx or sy -- 77
	if not (scale > 0) then -- 77
		scale = 1 -- 78
	end -- 78
	return { -- 79
		scale = scale, -- 80
		originX = viewW / 2, -- 81
		originY = viewH / 2, -- 82
		centerX = centerX ~= nil and centerX or 0, -- 83
		centerY = centerY ~= nil and centerY or 0 -- 84
	} -- 84
end -- 69
--- 平面点 → 屏幕像素（左下原点、+Y 向上）。
-- 
-- ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
function ____exports.planeToScreen(p, m) -- 93
	return {x = m.originX + (p.x - m.centerX) * m.scale, y = m.originY - (p.y - m.centerY) * m.scale} -- 95
end -- 93
--- `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。
function ____exports.screenToPlane(q, m) -- 99
	return {x = (q.x - m.originX) / m.scale + m.centerX, y = (m.originY - q.y) / m.scale + m.centerY} -- 100
end -- 99
--- 天体（含卫星的宿主链）到平面原点的**最大**距离。
-- 
-- 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
local function bodyCenterDist(b) -- 108
	local own = b.orbitRadius > 0 and b.orbitRadius or 0 -- 109
	if b.host ~= nil then -- 109
		return bodyCenterDist(b.host) + own -- 110
	end -- 110
	return own -- 111
end -- 108
--- 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
-- 
-- - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
-- - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance, centerIndex) -- 120
	if centerIndex ~= nil and centerIndex >= 0 and centerIndex < #bodies then -- 120
		local c = bodies[centerIndex + 1] -- 123
		local cp = bodyPositionAt(c, 0) -- 124
		local r = 0 -- 125
		local lim = c.orbitRadius * 0.5 -- 131
		do -- 131
			local i = 0 -- 132
			while i < #bodies do -- 132
				do -- 132
					local b = bodies[i + 1] -- 133
					if b ~= c then -- 133
						if b.orbitRadius <= 0 or b.orbitRadius >= lim then -- 133
							goto __continue13 -- 135
						end -- 135
						if distance( -- 135
							bodyPositionAt(b, 0), -- 136
							cp -- 136
						) >= lim then -- 136
							goto __continue13 -- 136
						end -- 136
					end -- 136
					local p = bodyPositionAt(b, 0) -- 138
					local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 139
					local d = distance(p, cp) + pad -- 140
					if d > r then -- 140
						r = d -- 141
					end -- 141
				end -- 141
				::__continue13:: -- 141
				i = i + 1 -- 132
			end -- 132
		end -- 132
		local pd = distance(probeStart, cp) -- 143
		if pd > r then -- 143
			r = pd -- 144
		end -- 144
		return r > 0.000001 and r or 1 -- 145
	end -- 145
	local r = 0 -- 147
	do -- 147
		local i = 0 -- 148
		while i < #bodies do -- 148
			local b = bodies[i + 1] -- 149
			local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 150
			local d = bodyCenterDist(b) + pad -- 151
			if d > r then -- 151
				r = d -- 152
			end -- 152
			i = i + 1 -- 148
		end -- 148
	end -- 148
	local pd = math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y) -- 154
	if pd > r then -- 154
		r = pd -- 155
	end -- 155
	return r > 0.000001 and r or 1 -- 156
end -- 120
--- 判定"这两个天体是不是同一个"（scaledPlanets 拷贝过宿主链 ⇒ 不能比对象身份，比位置与 gm）。
function ____exports.sameBody(a, b) -- 160
	return a.gm == b.gm and a.radius == b.radius and a.orbitRadius == b.orbitRadius -- 161
end -- 160
--- 2D 到达圈的半径（平面单位）—— **就是航点容差，绝不是视觉半径**。
-- 
-- S5 §3.8 规则 3：旧的硬约束「视觉半径必须等于物理半径」作废之后，
-- 玩家判断"够不够得着"的唯一依据变成了这个圈。所以它必须由容差算出，
-- 且**不随视觉半径变化** —— Test/PlanViewTest 有断言守着这两条。
function ____exports.arrivalRingRadius(goal) -- 171
	local r = goal.tolerance -- 172
	if goal.chain ~= nil then -- 172
		do -- 172
			local i = 0 -- 174
			while i < #goal.chain do -- 174
				if goal.chain[i + 1].tolerance > r then -- 174
					r = goal.chain[i + 1].tolerance -- 175
				end -- 175
				i = i + 1 -- 174
			end -- 174
		end -- 174
	end -- 174
	return r -- 178
end -- 171
function ____exports.defaultPlanOptions() -- 245
	return { -- 246
		marginFrac = 0.12, -- 247
		orbitHex = 4610157, -- 248
		orbitWidth = 1.5, -- 249
		orbitSegments = 72, -- 250
		ringHex = 9890780, -- 251
		ringWidth = 2.5, -- 252
		ringSegments = 48, -- 253
		pinRadius = 8, -- 254
		sunPinRadius = 13, -- 255
		sunGmMin = 10000, -- 256
		probePinRadius = 11, -- 257
		maxPinRadius = 26, -- 258
		probeTickLen = 22, -- 259
		predictHex = 7915775, -- 260
		predictWidth = 2.5, -- 261
		polylineMaxPoints = 240, -- 262
		trailHex = 16772266, -- 263
		trailWidth = 3.5, -- 264
		flowDotRadius = 3.5, -- 265
		flowDotHex = 16773327, -- 266
		probeHex = 15398143, -- 267
		probeOrbitHex = 6127526, -- 268
		labelFontSize = 20, -- 269
		labelHex = 12834536, -- 270
		labelGapY = 18, -- 271
		probeVisualRadius = PROBE_VISUAL_RADIUS -- 272
	} -- 272
end -- 245
--- 公里数 → 中文读数（航天模拟器那种）。
-- 
-- 口径：< 1 万 km 给整数带千分位（「6,571 km」）、< 1 亿给「万」（「38.4 万 km」）、
-- 再往上给「亿」（「1.50 亿 km」）。**不做科学计数法**：tstl 没有 toExponential（AGENTS 第 21 条），
-- 而且玩家读数要的是"38.4 万"这种人话，不是 3.844e5。
function ____exports.formatKm(km) -- 283
	if not (km > 0) then -- 283
		return "0 km" -- 284
	end -- 284
	if km < 10000 then -- 284
		local s = __TS__NumberToFixed( -- 287
			math.floor(km + 0.5), -- 287
			0 -- 287
		) -- 287
		local out = "" -- 288
		local count = 0 -- 289
		do -- 289
			local i = #s - 1 -- 290
			while i >= 0 do -- 290
				out = __TS__StringCharAt(s, i) .. out -- 291
				count = count + 1 -- 292
				if count % 3 == 0 and i > 0 then -- 292
					out = "," .. out -- 293
				end -- 293
				i = i - 1 -- 290
			end -- 290
		end -- 290
		return out .. " km" -- 295
	end -- 295
	if km < 100000000 then -- 295
		return __TS__NumberToFixed(km / 10000, 1) .. " 万 km" -- 297
	end -- 297
	return __TS__NumberToFixed(km / 100000000, 2) .. " 亿 km" -- 298
end -- 283
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 356
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 357
	local root = Node() -- 360
	local orbitDraw = DrawNode() -- 361
	local dotDraw = DrawNode() -- 362
	local ringDraw = DrawNode() -- 363
	local pathDraw = DrawNode() -- 364
	local pinDraw = DrawNode() -- 365
	local beaconDraw = DrawNode() -- 366
	root:addChild(orbitDraw) -- 367
	root:addChild(dotDraw) -- 368
	root:addChild(ringDraw) -- 369
	root:addChild(pathDraw) -- 370
	root:addChild(pinDraw) -- 371
	root:addChild(beaconDraw) -- 372
	local labelRoot = Node() -- 376
	root:addChild(labelRoot) -- 377
	--- 探测器读数标签（惰性建一次）。
	local probeLabel = nil -- 379
	--- 天体读数标签（与 bodies 一一对应，惰性建）。
	local bodyLabels = {} -- 381
	--- 探测器的读数文字（在 syncProbe 里按"此刻离哪个天体最近"算出来）。
	local probeReadout = "探测器" -- 383
	--- 上次写进 Label 的文字（**没变就别碰 Label**：文字布局每帧重算是纯浪费，Hud 同款纪律）。
	local lastProbeReadout = "" -- 385
	local lastBodyReadout = {} -- 386
	layer:addChild(root) -- 387
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 389
	local ringColor = colorFromHex(options.ringHex, 1) -- 390
	local predictColor = colorFromHex(options.predictHex, 1) -- 391
	local trailColor = colorFromHex(options.trailHex, 1) -- 392
	local probeColor = colorFromHex(options.probeHex, 1) -- 393
	local probeOrbitColor = colorFromHex(options.probeOrbitHex, 1) -- 394
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 395
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 397
	local isVisible = true -- 399
	local currentZoom = 1 -- 400
	local panOffsetX = 0 -- 401
	local panOffsetY = 0 -- 402
	local baseFitRadius = 1 -- 403
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 404
	local dirty = true -- 405
	local function recomputeMap() -- 407
		local effectiveR = baseFitRadius / currentZoom -- 408
		local newMap = ____exports.computePlanMapping( -- 409
			viewW, -- 409
			viewH, -- 409
			effectiveR, -- 409
			options.marginFrac, -- 409
			map.centerX, -- 409
			map.centerY -- 409
		) -- 409
		newMap.originX = viewW / 2 + panOffsetX -- 410
		newMap.originY = viewH / 2 + panOffsetY -- 411
		map = newMap -- 412
		dirty = true -- 413
	end -- 407
	local bodies = {} -- 417
	local visuals = {} -- 418
	local probeOrbitCenter = {x = 0, y = 0} -- 420
	local probeOrbitRadius = 0 -- 421
	local tWorld = 0 -- 422
	local probe = {x = 0, y = 0} -- 423
	local probeVel = {x = 0, y = 0} -- 424
	local pred = {} -- 425
	local trail = {} -- 426
	local rings = {} -- 427
	local stars = {} -- 428
	local collectedStars = {} -- 429
	--- 标签贴边时别被切掉。
	-- 
	-- Label 是**居中锚点**（anchor 0.5/0.5），所以左右各留 1/6 屏宽 —— 够放 7–11 个字
	-- （「月球 · 38.4 万 km」在 20px 下约 150px，竖屏 840 宽 ⇒ 140 的余量正好）。
	local function clampLabelX(x) -- 437
		local pad = viewW / 6 -- 438
		if x < pad then -- 438
			return pad -- 439
		end -- 439
		if x > viewW - pad then -- 439
			return viewW - pad -- 440
		end -- 440
		return x -- 441
	end -- 437
	--- 上下留 26px（字号 20 的半高 + 一点余地）。
	local function clampLabelY(y) -- 444
		if y < 26 then -- 444
			return 26 -- 445
		end -- 445
		if y > viewH - 26 then -- 445
			return viewH - 26 -- 446
		end -- 446
		return y -- 447
	end -- 444
	local function clearAll() -- 450
		orbitDraw:clear() -- 451
		dotDraw:clear() -- 452
		ringDraw:clear() -- 453
		pathDraw:clear() -- 454
		pinDraw:clear() -- 455
		beaconDraw:clear() -- 456
	end -- 450
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 460
		local seg = n > 8 and n or 8 -- 461
		local out = {} -- 462
		do -- 462
			local i = 0 -- 463
			while i < seg do -- 463
				local a = i / seg * 2 * math.pi -- 464
				out[#out + 1] = Vec2( -- 465
					cx + rPx * math.cos(a), -- 465
					cy + rPx * math.sin(a) -- 465
				) -- 465
				i = i + 1 -- 463
			end -- 463
		end -- 463
		return out -- 467
	end -- 460
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 471
		if #pts < 2 then -- 471
			return -- 472
		end -- 472
		local dec = decimate(pts, options.polylineMaxPoints) -- 473
		local prev = nil -- 474
		for ____, p in ipairs(dec) do -- 475
			local s = ____exports.planeToScreen(p, map) -- 476
			local cur = Vec2(s.x, s.y) -- 477
			if prev ~= nil then -- 477
				pathDraw:drawSegment(prev, cur, width, color) -- 478
			end -- 478
			prev = cur -- 479
		end -- 479
	end -- 471
	local function redraw() -- 483
		clearAll() -- 484
		if not isVisible then -- 484
			return -- 485
		end -- 485
		for ____, b in ipairs(bodies) do -- 488
			do -- 488
				if b.orbitRadius <= 0 then -- 488
					goto __continue56 -- 489
				end -- 489
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 490
				local s = ____exports.planeToScreen(center, map) -- 491
				local rPx = b.orbitRadius * map.scale -- 492
				if rPx < 1 then -- 492
					goto __continue56 -- 493
				end -- 493
				orbitDraw:drawPolygon( -- 494
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 494
					noFill, -- 494
					options.orbitWidth, -- 494
					orbitColor -- 494
				) -- 494
			end -- 494
			::__continue56:: -- 494
		end -- 494
		if probeOrbitRadius > 0 then -- 494
			local ps = ____exports.planeToScreen(probeOrbitCenter, map) -- 499
			local pr = probeOrbitRadius * map.scale -- 500
			if pr >= 1 then -- 500
				orbitDraw:drawPolygon( -- 501
					circleVerts(ps.x, ps.y, pr, options.orbitSegments), -- 501
					noFill, -- 501
					options.orbitWidth, -- 501
					probeOrbitColor -- 501
				) -- 501
			end -- 501
		end -- 501
		if options.flowDotRadius > 0 then -- 501
			for ____, b in ipairs(bodies) do -- 508
				do -- 508
					if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 508
						goto __continue63 -- 509
					end -- 509
					local rPx = b.orbitRadius * map.scale -- 510
					if rPx < 1 then -- 510
						goto __continue63 -- 511
					end -- 511
					do -- 511
						local k = 0 -- 512
						while k < FlowDotsPerOrbit do -- 512
							local s = ____exports.planeToScreen( -- 513
								flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 513
								map -- 513
							) -- 513
							dotDraw:drawDot( -- 514
								Vec2(s.x, s.y), -- 514
								options.flowDotRadius, -- 514
								flowDotColor -- 514
							) -- 514
							k = k + 1 -- 512
						end -- 512
					end -- 512
				end -- 512
				::__continue63:: -- 512
			end -- 512
		end -- 512
		local gravityRingColor = Color(100, 180, 255, 70) -- 519
		for ____, b in ipairs(bodies) do -- 520
			if b.gm > 0 and not b.isObstacle then -- 520
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 522
				local s = ____exports.planeToScreen(center, map) -- 523
				local gravR = (b.radius * 3.6 + math.sin(tWorld * 3) * 4) * map.scale -- 524
				if gravR >= 5 then -- 524
					orbitDraw:drawPolygon( -- 526
						circleVerts(s.x, s.y, gravR, 48), -- 526
						noFill, -- 526
						1.5, -- 526
						gravityRingColor -- 526
					) -- 526
				end -- 526
			end -- 526
		end -- 526
		for ____, ring in ipairs(rings) do -- 532
			do -- 532
				local s = ____exports.planeToScreen(ring.center, map) -- 533
				local rPx = ring.radius * map.scale -- 534
				if rPx < 1 then -- 534
					goto __continue73 -- 535
				end -- 535
				ringDraw:drawPolygon( -- 536
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 536
					noFill, -- 536
					options.ringWidth, -- 536
					ringColor -- 536
				) -- 536
			end -- 536
			::__continue73:: -- 536
		end -- 536
		drawPolyline(trail, trailColor, options.trailWidth) -- 540
		drawPolyline(pred, predictColor, options.predictWidth) -- 541
		do -- 541
			local i = 0 -- 549
			while i < #bodies do -- 549
				do -- 549
					local b = bodies[i + 1] -- 550
					local s = ____exports.planeToScreen( -- 551
						bodyPositionAt(b, tWorld), -- 551
						map -- 551
					) -- 551
					local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 552
					if i < #visuals then -- 552
						local v = visuals[i + 1] -- 554
						local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 555
						if vr > r then -- 555
							r = vr -- 556
						end -- 556
						if r > options.maxPinRadius then -- 556
							r = options.maxPinRadius -- 557
						end -- 557
					end -- 557
					local col = orbitColor -- 559
					if i < #visuals then -- 559
						local v = visuals[i + 1] -- 561
						col = Color( -- 562
							math.floor(v.r * 255), -- 562
							math.floor(v.g * 255), -- 562
							math.floor(v.b * 255), -- 562
							255 -- 562
						) -- 562
					end -- 562
					pinDraw:drawDot( -- 564
						Vec2(s.x, s.y), -- 564
						r, -- 564
						col -- 564
					) -- 564
					if i < #bodyLabels then -- 564
						local lb = bodyLabels[i + 1] -- 569
						local near = s.x > -60 and s.x < viewW + 60 and s.y > -60 and s.y < viewH + 60 -- 573
						setLabelVisible(lb, near) -- 574
						if not near then -- 574
							goto __continue77 -- 575
						end -- 575
						local name = i < #visuals and bodyLabel(visuals[i + 1].model) or "天体" -- 576
						local text = b.orbitRadius > 0 and (name .. " · ") .. ____exports.formatKm(b.orbitRadius * KmPerUnit) or name -- 577
						if i >= #lastBodyReadout or lastBodyReadout[i + 1] ~= text then -- 577
							lastBodyReadout[i + 1] = text -- 579
							setLabelText(lb, text) -- 580
						end -- 580
						setLabelCenter( -- 582
							lb, -- 582
							clampLabelX(s.x), -- 582
							clampLabelY(s.y + r + options.labelGapY) -- 582
						) -- 582
					end -- 582
				end -- 582
				::__continue77:: -- 582
				i = i + 1 -- 549
			end -- 549
		end -- 549
		local ps = ____exports.planeToScreen(probe, map) -- 587
		local pr = options.probePinRadius -- 588
		local pvr = options.probeVisualRadius ~= nil and options.probeVisualRadius or PROBE_VISUAL_RADIUS -- 589
		if pvr > 0 and pvr * map.scale > pr then -- 589
			pr = pvr * map.scale -- 590
		end -- 590
		if pr > options.maxPinRadius then -- 590
			pr = options.maxPinRadius -- 591
		end -- 591
		pinDraw:drawDot( -- 592
			Vec2(ps.x, ps.y), -- 592
			pr, -- 592
			probeColor -- 592
		) -- 592
		pinDraw:drawPolygon( -- 593
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 593
			noFill, -- 593
			1.5, -- 593
			probeColor -- 593
		) -- 593
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 594
		if vlen > 0.000001 then -- 594
			local dx = probeVel.x / vlen -- 596
			local dy = probeVel.y / vlen -- 597
			pinDraw:drawSegment( -- 598
				Vec2(ps.x, ps.y), -- 599
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 600
				2, -- 601
				probeColor -- 602
			) -- 602
		end -- 602
		do -- 602
			local i = 0 -- 607
			while i < #stars do -- 607
				local st = stars[i + 1] -- 608
				local isCol = i < #collectedStars and collectedStars[i + 1] -- 609
				local ss = ____exports.planeToScreen(st, map) -- 610
				if not isCol then -- 610
					pinDraw:drawDot( -- 612
						Vec2(ss.x, ss.y), -- 612
						8, -- 612
						Color(255, 215, 0, 255) -- 612
					) -- 612
					pinDraw:drawPolygon( -- 613
						circleVerts(ss.x, ss.y, 14, 16), -- 613
						noFill, -- 613
						1.5, -- 613
						Color(255, 230, 100, 200) -- 613
					) -- 613
				else -- 613
					pinDraw:drawDot( -- 615
						Vec2(ss.x, ss.y), -- 615
						5, -- 615
						Color(120, 120, 120, 100) -- 615
					) -- 615
				end -- 615
				i = i + 1 -- 607
			end -- 607
		end -- 607
		if probeLabel == nil then -- 607
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex) -- 621
			lastProbeReadout = probeReadout -- 622
		elseif lastProbeReadout ~= probeReadout then -- 622
			lastProbeReadout = probeReadout -- 624
			setLabelText(probeLabel, probeReadout) -- 625
		end -- 625
		setLabelVisible(probeLabel, ps.x > -60 and ps.x < viewW + 60 and ps.y > -60 and ps.y < viewH + 60) -- 627
		setLabelCenter( -- 628
			probeLabel, -- 628
			clampLabelX(ps.x), -- 628
			clampLabelY(ps.y - pr - options.labelGapY) -- 628
		) -- 628
		if #rings > 0 then -- 628
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 632
			local pad = 48 -- 633
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 634
			if isOffscreen then -- 634
				local cx = viewW / 2 -- 636
				local cy = viewH / 2 -- 637
				local dirX = targetScreen.x - cx -- 638
				local dirY = targetScreen.y - cy -- 639
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 640
				if len > 0.0001 then -- 640
					local ux = dirX / len -- 642
					local uy = dirY / len -- 643
					local halfW = viewW / 2 - pad -- 644
					local halfH = viewH / 2 - pad -- 645
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 646
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 647
					local tHit = math.min(scaleX, scaleY) -- 648
					local hitX = cx + ux * tHit -- 649
					local hitY = cy + uy * tHit -- 650
					local arrowLen = 18 -- 651
					local arrowHalf = 9 -- 652
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 653
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 654
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 655
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 656
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 657
					beaconDraw:drawDot( -- 658
						Vec2(hitX, hitY), -- 658
						4, -- 658
						ringColor -- 658
					) -- 658
				end -- 658
			end -- 658
		end -- 658
		dirty = false -- 662
	end -- 483
	return { -- 665
		setVisible = function(self, on) -- 666
			isVisible = on -- 667
			root.visible = on -- 668
			if not on then -- 668
				clearAll() -- 671
				dirty = false -- 672
			else -- 672
				dirty = true -- 674
			end -- 674
		end, -- 666
		visible = function(self) -- 677
			return isVisible -- 678
		end, -- 677
		fitTo = function(self, radius) -- 680
			baseFitRadius = radius -- 681
			recomputeMap() -- 682
		end, -- 680
		syncBodies = function(self, bs, vs, t) -- 684
			bodies = bs -- 685
			visuals = vs -- 686
			tWorld = t -- 687
			if #bodyLabels ~= #bs then -- 687
				bodyLabels = {} -- 690
				do -- 690
					local i = 0 -- 691
					while i < #bs do -- 691
						bodyLabels[#bodyLabels + 1] = createLabel(labelRoot, "", options.labelFontSize, options.labelHex) -- 692
						i = i + 1 -- 691
					end -- 691
				end -- 691
			end -- 691
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 691
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 698
				map.centerX = cp.x -- 699
				map.centerY = cp.y -- 700
				dirty = true -- 702
			end -- 702
			dirty = true -- 704
		end, -- 684
		syncProbe = function(self, p, v) -- 706
			probe = p -- 707
			probeVel = v -- 708
			dirty = true -- 709
			local best = -1 -- 715
			local bestPull = 0 -- 716
			local bestDist = 0 -- 717
			do -- 717
				local i = 0 -- 718
				while i < #bodies do -- 718
					do -- 718
						local b = bodies[i + 1] -- 719
						local d = distance( -- 720
							p, -- 720
							bodyPositionAt(b, tWorld) -- 720
						) -- 720
						if d < 1e-9 then -- 720
							goto __continue109 -- 721
						end -- 721
						local pull = b.gm / (d * d) -- 722
						if pull > bestPull then -- 722
							bestPull = pull -- 724
							best = i -- 725
							bestDist = d -- 726
						end -- 726
					end -- 726
					::__continue109:: -- 726
					i = i + 1 -- 718
				end -- 718
			end -- 718
			if best >= 0 then -- 718
				local alt = (bestDist - bodies[best + 1].radius) * KmPerUnit -- 730
				probeReadout = "探测器 · 高度 " .. ____exports.formatKm(alt > 0 and alt or 0) -- 731
			else -- 731
				probeReadout = "探测器" -- 733
			end -- 733
		end, -- 706
		setPrediction = function(self, points) -- 736
			pred = points -- 737
			dirty = true -- 738
		end, -- 736
		clearPrediction = function(self) -- 740
			pred = {} -- 741
			dirty = true -- 742
		end, -- 740
		setTrail = function(self, points) -- 744
			trail = points -- 745
			dirty = true -- 746
		end, -- 744
		clearTrail = function(self) -- 748
			trail = {} -- 749
			dirty = true -- 750
		end, -- 748
		setProbeOrbit = function(self, center, radius) -- 752
			probeOrbitCenter = center -- 753
			probeOrbitRadius = radius -- 754
			dirty = true -- 755
		end, -- 752
		clearProbeOrbit = function(self) -- 757
			probeOrbitRadius = 0 -- 758
			dirty = true -- 759
		end, -- 757
		setGoalRings = function(self, rs) -- 761
			rings = rs -- 762
			dirty = true -- 763
		end, -- 761
		clearGoalRings = function(self) -- 765
			rings = {} -- 766
			dirty = true -- 767
		end, -- 765
		setStars = function(self, s, c) -- 769
			stars = s -- 770
			collectedStars = c -- 771
			dirty = true -- 772
		end, -- 769
		flush = function(self) -- 774
			if not isVisible then -- 774
				return -- 776
			end -- 776
			if not dirty then -- 776
				return -- 777
			end -- 777
			redraw() -- 778
		end, -- 774
		clear = function(self) -- 780
			clearAll() -- 781
			dirty = true -- 782
		end, -- 780
		probeScreen = function(self) -- 784
			return ____exports.planeToScreen(probe, map) -- 785
		end, -- 784
		mapping = function(self) -- 787
			return map -- 788
		end, -- 787
		zoomIn = function(self) -- 790
			currentZoom = math.min(60, currentZoom * 1.5) -- 793
			recomputeMap() -- 794
		end, -- 790
		zoomOut = function(self) -- 796
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 797
			recomputeMap() -- 798
		end, -- 796
		resetView = function(self) -- 800
			currentZoom = 1 -- 801
			panOffsetX = 0 -- 802
			panOffsetY = 0 -- 803
			recomputeMap() -- 804
		end, -- 800
		pan = function(self, dx, dy) -- 806
			panOffsetX = panOffsetX + dx -- 807
			panOffsetY = panOffsetY + dy -- 808
			recomputeMap() -- 809
		end, -- 806
		getZoom = function(self) -- 811
			return currentZoom -- 812
		end, -- 811
		root = root -- 814
	} -- 814
end -- 356
return ____exports -- 356
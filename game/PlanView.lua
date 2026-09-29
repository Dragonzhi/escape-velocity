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
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance, centerIndex, starOrbits) -- 120
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
	if starOrbits ~= nil then -- 155
		do -- 155
			local i = 0 -- 158
			while i < #starOrbits do -- 158
				local sd = starOrbits[i + 1].orbitRadius > 0 and starOrbits[i + 1].orbitRadius or math.sqrt(starOrbits[i + 1].orbitCenter.x * starOrbits[i + 1].orbitCenter.x + starOrbits[i + 1].orbitCenter.y * starOrbits[i + 1].orbitCenter.y) -- 159
				if sd > r then -- 159
					r = sd -- 162
				end -- 162
				i = i + 1 -- 158
			end -- 158
		end -- 158
	end -- 158
	return r > 0.000001 and r or 1 -- 165
end -- 120
--- 判定"这两个天体是不是同一个"（scaledPlanets 拷贝过宿主链 ⇒ 不能比对象身份，比位置与 gm）。
function ____exports.sameBody(a, b) -- 169
	return a.gm == b.gm and a.radius == b.radius and a.orbitRadius == b.orbitRadius -- 170
end -- 169
--- 2D 到达圈的半径（平面单位）—— **就是航点容差，绝不是视觉半径**。
-- 
-- S5 §3.8 规则 3：旧的硬约束「视觉半径必须等于物理半径」作废之后，
-- 玩家判断"够不够得着"的唯一依据变成了这个圈。所以它必须由容差算出，
-- 且**不随视觉半径变化** —— Test/PlanViewTest 有断言守着这两条。
function ____exports.arrivalRingRadius(goal) -- 180
	local r = goal.tolerance -- 181
	if goal.chain ~= nil then -- 181
		do -- 181
			local i = 0 -- 183
			while i < #goal.chain do -- 183
				if goal.chain[i + 1].tolerance > r then -- 183
					r = goal.chain[i + 1].tolerance -- 184
				end -- 184
				i = i + 1 -- 183
			end -- 183
		end -- 183
	end -- 183
	return r -- 187
end -- 180
function ____exports.defaultPlanOptions() -- 254
	return { -- 255
		marginFrac = 0.12, -- 256
		orbitHex = 4610157, -- 257
		orbitWidth = 1.5, -- 258
		orbitSegments = 72, -- 259
		ringHex = 9890780, -- 260
		ringWidth = 2.5, -- 261
		ringSegments = 48, -- 262
		pinRadius = 8, -- 263
		sunPinRadius = 13, -- 264
		probePinRadius = 11, -- 265
		maxPinRadius = 26, -- 266
		probeTickLen = 22, -- 267
		predictHex = 7915775, -- 268
		predictWidth = 2.5, -- 269
		polylineMaxPoints = 240, -- 270
		trailHex = 16772266, -- 271
		trailWidth = 3.5, -- 272
		flowDotRadius = 3.5, -- 273
		flowDotHex = 16773327, -- 274
		probeHex = 15398143, -- 275
		probeOrbitHex = 6127526, -- 276
		labelFontSize = 20, -- 277
		labelHex = 12834536, -- 278
		labelGapY = 18, -- 279
		probeVisualRadius = PROBE_VISUAL_RADIUS -- 280
	} -- 280
end -- 254
--- 公里数 → 中文读数（航天模拟器那种）。
-- 
-- 口径：< 1 万 km 给整数带千分位（「6,571 km」）、< 1 亿给「万」（「38.4 万 km」）、
-- 再往上给「亿」（「1.50 亿 km」）。**不做科学计数法**：tstl 没有 toExponential（AGENTS 第 21 条），
-- 而且玩家读数要的是"38.4 万"这种人话，不是 3.844e5。
function ____exports.formatKm(km) -- 291
	if not (km > 0) then -- 291
		return "0 km" -- 292
	end -- 292
	if km < 10000 then -- 292
		local s = __TS__NumberToFixed( -- 295
			math.floor(km + 0.5), -- 295
			0 -- 295
		) -- 295
		local out = "" -- 296
		local count = 0 -- 297
		do -- 297
			local i = #s - 1 -- 298
			while i >= 0 do -- 298
				out = __TS__StringCharAt(s, i) .. out -- 299
				count = count + 1 -- 300
				if count % 3 == 0 and i > 0 then -- 300
					out = "," .. out -- 301
				end -- 301
				i = i - 1 -- 298
			end -- 298
		end -- 298
		return out .. " km" -- 303
	end -- 303
	if km < 100000000 then -- 303
		return __TS__NumberToFixed(km / 10000, 1) .. " 万 km" -- 305
	end -- 305
	return __TS__NumberToFixed(km / 100000000, 2) .. " 亿 km" -- 306
end -- 291
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 365
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 366
	local root = Node() -- 369
	local orbitDraw = DrawNode() -- 370
	local dotDraw = DrawNode() -- 371
	local ringDraw = DrawNode() -- 372
	local pathDraw = DrawNode() -- 373
	local pinDraw = DrawNode() -- 374
	local beaconDraw = DrawNode() -- 375
	root:addChild(orbitDraw) -- 376
	root:addChild(dotDraw) -- 377
	root:addChild(ringDraw) -- 378
	root:addChild(pathDraw) -- 379
	root:addChild(pinDraw) -- 380
	root:addChild(beaconDraw) -- 381
	local labelRoot = Node() -- 385
	root:addChild(labelRoot) -- 386
	--- 探测器读数标签（惰性建一次）。
	local probeLabel = nil -- 388
	--- 天体读数标签（与 bodies 一一对应，惰性建）。
	local bodyLabels = {} -- 390
	--- 探测器的读数文字（在 syncProbe 里按"此刻离哪个天体最近"算出来）。
	local probeReadout = "探测器" -- 392
	--- 上次写进 Label 的文字（**没变就别碰 Label**：文字布局每帧重算是纯浪费，Hud 同款纪律）。
	local lastProbeReadout = "" -- 394
	local lastBodyReadout = {} -- 395
	layer:addChild(root) -- 396
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 398
	local ringColor = colorFromHex(options.ringHex, 1) -- 399
	local predictColor = colorFromHex(options.predictHex, 1) -- 400
	local trailColor = colorFromHex(options.trailHex, 1) -- 401
	local probeColor = colorFromHex(options.probeHex, 1) -- 402
	local probeOrbitColor = colorFromHex(options.probeOrbitHex, 1) -- 403
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 404
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 406
	local isVisible = true -- 408
	local currentZoom = 1 -- 409
	local panOffsetX = 0 -- 410
	local panOffsetY = 0 -- 411
	local baseFitRadius = 1 -- 412
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 413
	local dirty = true -- 414
	local function recomputeMap() -- 416
		local effectiveR = baseFitRadius / currentZoom -- 417
		local newMap = ____exports.computePlanMapping( -- 418
			viewW, -- 418
			viewH, -- 418
			effectiveR, -- 418
			options.marginFrac, -- 418
			map.centerX, -- 418
			map.centerY -- 418
		) -- 418
		newMap.originX = viewW / 2 + panOffsetX -- 419
		newMap.originY = viewH / 2 + panOffsetY -- 420
		map = newMap -- 421
		dirty = true -- 422
	end -- 416
	local bodies = {} -- 426
	local visuals = {} -- 427
	local burning = false -- 428
	local burnDirection = {x = 0, y = 0} -- 429
	local probeOrbitCenter = {x = 0, y = 0} -- 431
	local probeOrbitRadius = 0 -- 432
	local tWorld = 0 -- 433
	local probe = {x = 0, y = 0} -- 434
	local probeVel = {x = 0, y = 0} -- 435
	local pred = {} -- 436
	local trail = {} -- 437
	local rings = {} -- 438
	local stars = {} -- 439
	local collectedStars = {} -- 440
	--- 标签贴边时别被切掉。
	-- 
	-- Label 是**居中锚点**（anchor 0.5/0.5），所以左右各留 1/6 屏宽 —— 够放 7–11 个字
	-- （「月球 · 38.4 万 km」在 20px 下约 150px，竖屏 840 宽 ⇒ 140 的余量正好）。
	local function clampLabelX(x) -- 448
		local pad = viewW / 6 -- 449
		if x < pad then -- 449
			return pad -- 450
		end -- 450
		if x > viewW - pad then -- 450
			return viewW - pad -- 451
		end -- 451
		return x -- 452
	end -- 448
	--- 上下留 26px（字号 20 的半高 + 一点余地）。
	local function clampLabelY(y) -- 455
		if y < 26 then -- 455
			return 26 -- 456
		end -- 456
		if y > viewH - 26 then -- 456
			return viewH - 26 -- 457
		end -- 457
		return y -- 458
	end -- 455
	local function clearAll() -- 461
		orbitDraw:clear() -- 462
		dotDraw:clear() -- 463
		ringDraw:clear() -- 464
		pathDraw:clear() -- 465
		pinDraw:clear() -- 466
		beaconDraw:clear() -- 467
	end -- 461
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 471
		local seg = n > 8 and n or 8 -- 472
		local out = {} -- 473
		do -- 473
			local i = 0 -- 474
			while i < seg do -- 474
				local a = i / seg * 2 * math.pi -- 475
				out[#out + 1] = Vec2( -- 476
					cx + rPx * math.cos(a), -- 476
					cy + rPx * math.sin(a) -- 476
				) -- 476
				i = i + 1 -- 474
			end -- 474
		end -- 474
		return out -- 478
	end -- 471
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 482
		if #pts < 2 then -- 482
			return -- 483
		end -- 483
		local dec = decimate(pts, options.polylineMaxPoints) -- 484
		local prev = nil -- 485
		for ____, p in ipairs(dec) do -- 486
			local s = ____exports.planeToScreen(p, map) -- 487
			local cur = Vec2(s.x, s.y) -- 488
			if prev ~= nil then -- 488
				pathDraw:drawSegment(prev, cur, width, color) -- 489
			end -- 489
			prev = cur -- 490
		end -- 490
	end -- 482
	local function redraw() -- 494
		clearAll() -- 495
		if not isVisible then -- 495
			return -- 496
		end -- 496
		for ____, b in ipairs(bodies) do -- 499
			do -- 499
				if b.orbitRadius <= 0 then -- 499
					goto __continue60 -- 500
				end -- 500
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 501
				local s = ____exports.planeToScreen(center, map) -- 502
				local rPx = b.orbitRadius * map.scale -- 503
				if rPx < 1 then -- 503
					goto __continue60 -- 504
				end -- 504
				orbitDraw:drawPolygon( -- 505
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 505
					noFill, -- 505
					options.orbitWidth, -- 505
					orbitColor -- 505
				) -- 505
			end -- 505
			::__continue60:: -- 505
		end -- 505
		if probeOrbitRadius > 0 then -- 505
			local ps = ____exports.planeToScreen(probeOrbitCenter, map) -- 510
			local pr = probeOrbitRadius * map.scale -- 511
			if pr >= 1 then -- 511
				orbitDraw:drawPolygon( -- 512
					circleVerts(ps.x, ps.y, pr, options.orbitSegments), -- 512
					noFill, -- 512
					options.orbitWidth, -- 512
					probeOrbitColor -- 512
				) -- 512
			end -- 512
		end -- 512
		if options.flowDotRadius > 0 then -- 512
			for ____, b in ipairs(bodies) do -- 519
				do -- 519
					if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 519
						goto __continue67 -- 520
					end -- 520
					local rPx = b.orbitRadius * map.scale -- 521
					if rPx < 1 then -- 521
						goto __continue67 -- 522
					end -- 522
					do -- 522
						local k = 0 -- 523
						while k < FlowDotsPerOrbit do -- 523
							local s = ____exports.planeToScreen( -- 524
								flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 524
								map -- 524
							) -- 524
							dotDraw:drawDot( -- 525
								Vec2(s.x, s.y), -- 525
								options.flowDotRadius, -- 525
								flowDotColor -- 525
							) -- 525
							k = k + 1 -- 523
						end -- 523
					end -- 523
				end -- 523
				::__continue67:: -- 523
			end -- 523
		end -- 523
		local gravityRingColor = Color(100, 180, 255, 70) -- 530
		for ____, b in ipairs(bodies) do -- 531
			if b.gm > 0 and not b.isObstacle then -- 531
				local center = options.transferTutorial == true and bodyPositionAt(b, tWorld) or (b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter) -- 533
				local s = ____exports.planeToScreen(center, map) -- 534
				local gravR = (b.radius * 3.6 + math.sin(tWorld * 3) * 4) * map.scale -- 535
				if gravR >= 5 then -- 535
					orbitDraw:drawPolygon( -- 537
						circleVerts(s.x, s.y, gravR, 48), -- 537
						noFill, -- 537
						1.5, -- 537
						gravityRingColor -- 537
					) -- 537
				end -- 537
			end -- 537
		end -- 537
		for ____, ring in ipairs(rings) do -- 543
			do -- 543
				local s = ____exports.planeToScreen(ring.center, map) -- 544
				if ring.point == true then -- 544
					local alpha = ring.pointAlpha ~= nil and ring.pointAlpha or 1 -- 546
					local scale = ring.pulse ~= nil and ring.pulse or 1 -- 547
					ringDraw:drawDot( -- 548
						Vec2(s.x, s.y), -- 548
						10 * scale, -- 548
						Color( -- 548
							70, -- 548
							245, -- 548
							105, -- 548
							math.floor(55 * alpha * math.min(2, scale)) -- 548
						) -- 548
					) -- 548
					ringDraw:drawDot( -- 549
						Vec2(s.x, s.y), -- 549
						3.5 * scale, -- 549
						Color( -- 549
							200, -- 549
							255, -- 549
							205, -- 549
							math.floor(255 * alpha) -- 549
						) -- 549
					) -- 549
					if ring.burstRadius ~= nil and ring.burstRadius > 0 then -- 549
						ringDraw:drawPolygon( -- 550
							circleVerts(s.x, s.y, ring.burstRadius, 32), -- 550
							noFill, -- 550
							1.5, -- 550
							Color( -- 550
								120, -- 550
								255, -- 550
								145, -- 550
								math.floor(180 * alpha) -- 550
							) -- 550
						) -- 550
					end -- 550
				end -- 550
				if ring.showRange == false then -- 550
					goto __continue77 -- 552
				end -- 552
				local rPx = ring.radius * map.scale -- 553
				if rPx < 1 then -- 553
					goto __continue77 -- 554
				end -- 554
				if ring.bandOuterRadius ~= nil and ring.bandOuterRadius > ring.radius then -- 554
					local inner = circleVerts(s.x, s.y, rPx, options.ringSegments) -- 556
					local outer = circleVerts(s.x, s.y, ring.bandOuterRadius * map.scale, options.ringSegments) -- 557
					do -- 557
						local i = 1 -- 558
						while i < #inner and i < #outer do -- 558
							ringDraw:drawPolygon( -- 558
								{inner[i], outer[i], outer[i + 1], inner[i + 1]}, -- 558
								Color(80, 255, 130, 18), -- 558
								0, -- 558
								Color(80, 255, 130, 0) -- 558
							) -- 558
							i = i + 1 -- 558
						end -- 558
					end -- 558
				end -- 558
				local ringTint = ring.point == true and colorFromHex(6750088, ring.pointAlpha ~= nil and ring.pointAlpha or 1) or (ring.pointAlpha ~= nil and colorFromHex(options.ringHex, ring.pointAlpha) or ringColor) -- 560
				ringDraw:drawPolygon( -- 561
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 561
					noFill, -- 561
					options.ringWidth, -- 561
					ringTint -- 561
				) -- 561
			end -- 561
			::__continue77:: -- 561
		end -- 561
		drawPolyline(trail, trailColor, options.trailWidth) -- 565
		drawPolyline(pred, predictColor, options.predictWidth) -- 566
		do -- 566
			local i = 0 -- 574
			while i < #bodies do -- 574
				do -- 574
					local b = bodies[i + 1] -- 575
					local s = ____exports.planeToScreen( -- 576
						bodyPositionAt(b, tWorld), -- 576
						map -- 576
					) -- 576
					local r = i < #visuals and visuals[i + 1].model == "Sun" and options.sunPinRadius or options.pinRadius -- 577
					if i < #visuals then -- 577
						local v = visuals[i + 1] -- 579
						local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 580
						if vr > r then -- 580
							r = vr -- 581
						end -- 581
						if options.actualBodySizes then -- 581
							r = vr -- 582
						elseif r > options.maxPinRadius then -- 582
							r = options.maxPinRadius -- 583
						end -- 583
					end -- 583
					local col = orbitColor -- 585
					if i < #visuals then -- 585
						local v = visuals[i + 1] -- 587
						col = Color( -- 588
							math.floor(v.r * 255), -- 588
							math.floor(v.g * 255), -- 588
							math.floor(v.b * 255), -- 588
							255 -- 588
						) -- 588
					end -- 588
					pinDraw:drawDot( -- 590
						Vec2(s.x, s.y), -- 590
						r, -- 590
						col -- 590
					) -- 590
					if i < #bodyLabels then -- 590
						local lb = bodyLabels[i + 1] -- 595
						local near = s.x > -60 and s.x < viewW + 60 and s.y > -60 and s.y < viewH + 60 -- 599
						setLabelVisible(lb, near) -- 600
						if not near then -- 600
							goto __continue87 -- 601
						end -- 601
						local name = i < #visuals and bodyLabel(visuals[i + 1].model) or "天体" -- 602
						local text = name -- 603
						if i >= #lastBodyReadout or lastBodyReadout[i + 1] ~= text then -- 603
							lastBodyReadout[i + 1] = text -- 605
							setLabelText(lb, text) -- 606
						end -- 606
						setLabelCenter( -- 608
							lb, -- 608
							clampLabelX(s.x), -- 608
							clampLabelY(s.y + r + options.labelGapY) -- 608
						) -- 608
					end -- 608
				end -- 608
				::__continue87:: -- 608
				i = i + 1 -- 574
			end -- 574
		end -- 574
		local ps = ____exports.planeToScreen(probe, map) -- 613
		local pr = options.probePinRadius -- 614
		local pvr = options.probeVisualRadius ~= nil and options.probeVisualRadius or PROBE_VISUAL_RADIUS -- 615
		if pvr > 0 and pvr * map.scale > pr then -- 615
			pr = pvr * map.scale -- 616
		end -- 616
		if pr > options.maxPinRadius then -- 616
			pr = options.maxPinRadius -- 617
		end -- 617
		pinDraw:drawDot( -- 618
			Vec2(ps.x, ps.y), -- 618
			pr, -- 618
			probeColor -- 618
		) -- 618
		pinDraw:drawPolygon( -- 619
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 619
			noFill, -- 619
			1.5, -- 619
			probeColor -- 619
		) -- 619
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 620
		if vlen > 0.000001 then -- 620
			local dx = probeVel.x / vlen -- 622
			local dy = probeVel.y / vlen -- 623
			pinDraw:drawSegment( -- 624
				Vec2(ps.x, ps.y), -- 625
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 626
				2, -- 627
				probeColor -- 628
			) -- 628
		end -- 628
		local burnMag = math.sqrt(burnDirection.x * burnDirection.x + burnDirection.y * burnDirection.y) -- 633
		if burning and burnMag > 0 then -- 633
			local ____end = ____exports.planeToScreen({x = probe.x - burnDirection.x * 32 / burnMag, y = probe.y - burnDirection.y * 32 / burnMag}, map) -- 635
			pinDraw:drawSegment( -- 636
				Vec2(ps.x, ps.y), -- 636
				Vec2(____end.x, ____end.y), -- 636
				4, -- 636
				Color(255, 135, 35, 160) -- 636
			) -- 636
			pinDraw:drawSegment( -- 637
				Vec2(ps.x, ps.y), -- 637
				Vec2(____end.x, ____end.y), -- 637
				1.5, -- 637
				Color(255, 235, 145, 255) -- 637
			) -- 637
		end -- 637
		do -- 637
			local i = 0 -- 639
			while i < #stars do -- 639
				local st = stars[i + 1] -- 640
				local isCol = i < #collectedStars and collectedStars[i + 1] -- 641
				local ss = ____exports.planeToScreen(st, map) -- 642
				if not isCol then -- 642
					pinDraw:drawDot( -- 644
						Vec2(ss.x, ss.y), -- 644
						8, -- 644
						Color(255, 215, 0, 255) -- 644
					) -- 644
					pinDraw:drawPolygon( -- 645
						circleVerts(ss.x, ss.y, 14, 16), -- 645
						noFill, -- 645
						1.5, -- 645
						Color(255, 230, 100, 200) -- 645
					) -- 645
				else -- 645
					pinDraw:drawDot( -- 647
						Vec2(ss.x, ss.y), -- 647
						5, -- 647
						Color(120, 120, 120, 100) -- 647
					) -- 647
				end -- 647
				i = i + 1 -- 639
			end -- 639
		end -- 639
		if probeLabel == nil then -- 639
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex) -- 653
			lastProbeReadout = probeReadout -- 654
		elseif lastProbeReadout ~= probeReadout then -- 654
			lastProbeReadout = probeReadout -- 656
			setLabelText(probeLabel, probeReadout) -- 657
		end -- 657
		setLabelVisible(probeLabel, ps.x > -60 and ps.x < viewW + 60 and ps.y > -60 and ps.y < viewH + 60) -- 659
		setLabelCenter( -- 660
			probeLabel, -- 660
			clampLabelX(ps.x), -- 660
			clampLabelY(ps.y - pr - options.labelGapY) -- 660
		) -- 660
		if #rings > 0 then -- 660
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 664
			local pad = 48 -- 665
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 666
			if isOffscreen then -- 666
				local cx = viewW / 2 -- 668
				local cy = viewH / 2 -- 669
				local dirX = targetScreen.x - cx -- 670
				local dirY = targetScreen.y - cy -- 671
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 672
				if len > 0.0001 then -- 672
					local ux = dirX / len -- 674
					local uy = dirY / len -- 675
					local halfW = viewW / 2 - pad -- 676
					local halfH = viewH / 2 - pad -- 677
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 678
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 679
					local tHit = math.min(scaleX, scaleY) -- 680
					local hitX = cx + ux * tHit -- 681
					local hitY = cy + uy * tHit -- 682
					local arrowLen = 18 -- 683
					local arrowHalf = 9 -- 684
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 685
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 686
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 687
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 688
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 689
					beaconDraw:drawDot( -- 690
						Vec2(hitX, hitY), -- 690
						4, -- 690
						ringColor -- 690
					) -- 690
				end -- 690
			end -- 690
		end -- 690
		dirty = false -- 694
	end -- 494
	return { -- 697
		setVisible = function(self, on) -- 698
			isVisible = on -- 699
			root.visible = on -- 700
			if not on then -- 700
				clearAll() -- 703
				dirty = false -- 704
			else -- 704
				dirty = true -- 706
			end -- 706
		end, -- 698
		visible = function(self) -- 709
			return isVisible -- 710
		end, -- 709
		fitTo = function(self, radius) -- 712
			baseFitRadius = radius -- 713
			recomputeMap() -- 714
		end, -- 712
		syncBodies = function(self, bs, vs, t) -- 716
			bodies = bs -- 717
			visuals = vs -- 718
			tWorld = t -- 719
			if #bodyLabels ~= #bs then -- 719
				bodyLabels = {} -- 722
				do -- 722
					local i = 0 -- 723
					while i < #bs do -- 723
						bodyLabels[#bodyLabels + 1] = createLabel(labelRoot, "", options.labelFontSize, options.labelHex) -- 724
						i = i + 1 -- 723
					end -- 723
				end -- 723
			end -- 723
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 723
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 730
				map.centerX = cp.x -- 731
				map.centerY = cp.y -- 732
				dirty = true -- 734
			end -- 734
			dirty = true -- 736
		end, -- 716
		syncProbe = function(self, p, v) -- 738
			probe = p -- 739
			probeVel = v -- 740
			dirty = true -- 741
			local best = -1 -- 747
			local bestPull = 0 -- 748
			local bestDist = 0 -- 749
			do -- 749
				local i = 0 -- 750
				while i < #bodies do -- 750
					do -- 750
						local b = bodies[i + 1] -- 751
						local d = distance( -- 752
							p, -- 752
							bodyPositionAt(b, tWorld) -- 752
						) -- 752
						if d < 1e-9 then -- 752
							goto __continue121 -- 753
						end -- 753
						local pull = b.gm / (d * d) -- 754
						if pull > bestPull then -- 754
							bestPull = pull -- 756
							best = i -- 757
							bestDist = d -- 758
						end -- 758
					end -- 758
					::__continue121:: -- 758
					i = i + 1 -- 750
				end -- 750
			end -- 750
			if best >= 0 then -- 750
				local alt = bestDist - bodies[best + 1].radius -- 762
				probeReadout = "探测器 · " .. __TS__NumberToFixed(alt > 0 and alt or 0, 0) -- 763
			else -- 763
				probeReadout = "探测器" -- 765
			end -- 765
		end, -- 738
		setPrediction = function(self, points) -- 768
			pred = points -- 769
			dirty = true -- 770
		end, -- 768
		clearPrediction = function(self) -- 772
			pred = {} -- 773
			dirty = true -- 774
		end, -- 772
		setTrail = function(self, points) -- 776
			trail = points -- 777
			dirty = true -- 778
		end, -- 776
		clearTrail = function(self) -- 780
			trail = {} -- 781
			dirty = true -- 782
		end, -- 780
		setProbeOrbit = function(self, center, radius) -- 784
			probeOrbitCenter = center -- 785
			probeOrbitRadius = radius -- 786
			dirty = true -- 787
		end, -- 784
		clearProbeOrbit = function(self) -- 789
			probeOrbitRadius = 0 -- 790
			dirty = true -- 791
		end, -- 789
		setGoalRings = function(self, rs) -- 793
			rings = rs -- 794
			dirty = true -- 795
		end, -- 793
		setBurn = function(____, direction, on) -- 797
			burnDirection = direction -- 797
			burning = on -- 797
		end, -- 797
		clearGoalRings = function(self) -- 798
			rings = {} -- 799
			dirty = true -- 800
		end, -- 798
		setStars = function(self, s, c) -- 802
			stars = s -- 803
			collectedStars = c -- 804
			dirty = true -- 805
		end, -- 802
		flush = function(self) -- 807
			if not isVisible then -- 807
				return -- 809
			end -- 809
			if not dirty then -- 809
				return -- 810
			end -- 810
			redraw() -- 811
		end, -- 807
		clear = function(self) -- 813
			clearAll() -- 814
			dirty = true -- 815
		end, -- 813
		probeScreen = function(self) -- 817
			return ____exports.planeToScreen(probe, map) -- 818
		end, -- 817
		mapping = function(self) -- 820
			return map -- 821
		end, -- 820
		zoomIn = function(self) -- 823
			currentZoom = math.min(60, currentZoom * 1.5) -- 826
			recomputeMap() -- 827
		end, -- 823
		zoomOut = function(self) -- 829
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 830
			recomputeMap() -- 831
		end, -- 829
		resetView = function(self) -- 833
			currentZoom = 1 -- 834
			panOffsetX = 0 -- 835
			panOffsetY = 0 -- 836
			recomputeMap() -- 837
		end, -- 833
		pan = function(self, dx, dy) -- 839
			panOffsetX = panOffsetX + dx -- 840
			panOffsetY = panOffsetY + dy -- 841
			recomputeMap() -- 842
		end, -- 839
		getZoom = function(self) -- 844
			return currentZoom -- 845
		end, -- 844
		root = root -- 847
	} -- 847
end -- 365
return ____exports -- 365
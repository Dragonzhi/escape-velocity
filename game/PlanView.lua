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
							220, -- 548
							190, -- 548
							math.floor(45 * alpha * math.min(2, scale)) -- 548
						) -- 548
					) -- 548
					ringDraw:drawDot( -- 549
						Vec2(s.x, s.y), -- 549
						3.5 * scale, -- 549
						Color( -- 549
							170, -- 549
							255, -- 549
							230, -- 549
							math.floor(255 * alpha) -- 549
						) -- 549
					) -- 549
					if ring.burstRadius ~= nil and ring.burstRadius > 0 then -- 549
						ringDraw:drawPolygon( -- 550
							circleVerts(s.x, s.y, ring.burstRadius, 32), -- 550
							noFill, -- 550
							1.5, -- 550
							Color( -- 550
								140, -- 550
								255, -- 550
								215, -- 550
								math.floor(160 * alpha) -- 550
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
				ringDraw:drawPolygon( -- 555
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 555
					noFill, -- 555
					options.ringWidth, -- 555
					ringColor -- 555
				) -- 555
			end -- 555
			::__continue77:: -- 555
		end -- 555
		drawPolyline(trail, trailColor, options.trailWidth) -- 559
		drawPolyline(pred, predictColor, options.predictWidth) -- 560
		do -- 560
			local i = 0 -- 568
			while i < #bodies do -- 568
				do -- 568
					local b = bodies[i + 1] -- 569
					local s = ____exports.planeToScreen( -- 570
						bodyPositionAt(b, tWorld), -- 570
						map -- 570
					) -- 570
					local r = i < #visuals and visuals[i + 1].model == "Sun" and options.sunPinRadius or options.pinRadius -- 571
					if i < #visuals then -- 571
						local v = visuals[i + 1] -- 573
						local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 574
						if vr > r then -- 574
							r = vr -- 575
						end -- 575
						if options.actualBodySizes then -- 575
							r = vr -- 576
						elseif r > options.maxPinRadius then -- 576
							r = options.maxPinRadius -- 577
						end -- 577
					end -- 577
					local col = orbitColor -- 579
					if i < #visuals then -- 579
						local v = visuals[i + 1] -- 581
						col = Color( -- 582
							math.floor(v.r * 255), -- 582
							math.floor(v.g * 255), -- 582
							math.floor(v.b * 255), -- 582
							255 -- 582
						) -- 582
					end -- 582
					pinDraw:drawDot( -- 584
						Vec2(s.x, s.y), -- 584
						r, -- 584
						col -- 584
					) -- 584
					if i < #bodyLabels then -- 584
						local lb = bodyLabels[i + 1] -- 589
						local near = s.x > -60 and s.x < viewW + 60 and s.y > -60 and s.y < viewH + 60 -- 593
						setLabelVisible(lb, near) -- 594
						if not near then -- 594
							goto __continue84 -- 595
						end -- 595
						local name = i < #visuals and bodyLabel(visuals[i + 1].model) or "天体" -- 596
						local text = name -- 597
						if i >= #lastBodyReadout or lastBodyReadout[i + 1] ~= text then -- 597
							lastBodyReadout[i + 1] = text -- 599
							setLabelText(lb, text) -- 600
						end -- 600
						setLabelCenter( -- 602
							lb, -- 602
							clampLabelX(s.x), -- 602
							clampLabelY(s.y + r + options.labelGapY) -- 602
						) -- 602
					end -- 602
				end -- 602
				::__continue84:: -- 602
				i = i + 1 -- 568
			end -- 568
		end -- 568
		local ps = ____exports.planeToScreen(probe, map) -- 607
		local pr = options.probePinRadius -- 608
		local pvr = options.probeVisualRadius ~= nil and options.probeVisualRadius or PROBE_VISUAL_RADIUS -- 609
		if pvr > 0 and pvr * map.scale > pr then -- 609
			pr = pvr * map.scale -- 610
		end -- 610
		if pr > options.maxPinRadius then -- 610
			pr = options.maxPinRadius -- 611
		end -- 611
		pinDraw:drawDot( -- 612
			Vec2(ps.x, ps.y), -- 612
			pr, -- 612
			probeColor -- 612
		) -- 612
		pinDraw:drawPolygon( -- 613
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 613
			noFill, -- 613
			1.5, -- 613
			probeColor -- 613
		) -- 613
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 614
		if vlen > 0.000001 then -- 614
			local dx = probeVel.x / vlen -- 616
			local dy = probeVel.y / vlen -- 617
			pinDraw:drawSegment( -- 618
				Vec2(ps.x, ps.y), -- 619
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 620
				2, -- 621
				probeColor -- 622
			) -- 622
		end -- 622
		local burnMag = math.sqrt(burnDirection.x * burnDirection.x + burnDirection.y * burnDirection.y) -- 627
		if burning and burnMag > 0 then -- 627
			local ____end = ____exports.planeToScreen({x = probe.x - burnDirection.x * 32 / burnMag, y = probe.y - burnDirection.y * 32 / burnMag}, map) -- 629
			pinDraw:drawSegment( -- 630
				Vec2(ps.x, ps.y), -- 630
				Vec2(____end.x, ____end.y), -- 630
				4, -- 630
				Color(255, 135, 35, 160) -- 630
			) -- 630
			pinDraw:drawSegment( -- 631
				Vec2(ps.x, ps.y), -- 631
				Vec2(____end.x, ____end.y), -- 631
				1.5, -- 631
				Color(255, 235, 145, 255) -- 631
			) -- 631
		end -- 631
		do -- 631
			local i = 0 -- 633
			while i < #stars do -- 633
				local st = stars[i + 1] -- 634
				local isCol = i < #collectedStars and collectedStars[i + 1] -- 635
				local ss = ____exports.planeToScreen(st, map) -- 636
				if not isCol then -- 636
					pinDraw:drawDot( -- 638
						Vec2(ss.x, ss.y), -- 638
						8, -- 638
						Color(255, 215, 0, 255) -- 638
					) -- 638
					pinDraw:drawPolygon( -- 639
						circleVerts(ss.x, ss.y, 14, 16), -- 639
						noFill, -- 639
						1.5, -- 639
						Color(255, 230, 100, 200) -- 639
					) -- 639
				else -- 639
					pinDraw:drawDot( -- 641
						Vec2(ss.x, ss.y), -- 641
						5, -- 641
						Color(120, 120, 120, 100) -- 641
					) -- 641
				end -- 641
				i = i + 1 -- 633
			end -- 633
		end -- 633
		if probeLabel == nil then -- 633
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex) -- 647
			lastProbeReadout = probeReadout -- 648
		elseif lastProbeReadout ~= probeReadout then -- 648
			lastProbeReadout = probeReadout -- 650
			setLabelText(probeLabel, probeReadout) -- 651
		end -- 651
		setLabelVisible(probeLabel, ps.x > -60 and ps.x < viewW + 60 and ps.y > -60 and ps.y < viewH + 60) -- 653
		setLabelCenter( -- 654
			probeLabel, -- 654
			clampLabelX(ps.x), -- 654
			clampLabelY(ps.y - pr - options.labelGapY) -- 654
		) -- 654
		if #rings > 0 then -- 654
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 658
			local pad = 48 -- 659
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 660
			if isOffscreen then -- 660
				local cx = viewW / 2 -- 662
				local cy = viewH / 2 -- 663
				local dirX = targetScreen.x - cx -- 664
				local dirY = targetScreen.y - cy -- 665
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 666
				if len > 0.0001 then -- 666
					local ux = dirX / len -- 668
					local uy = dirY / len -- 669
					local halfW = viewW / 2 - pad -- 670
					local halfH = viewH / 2 - pad -- 671
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 672
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 673
					local tHit = math.min(scaleX, scaleY) -- 674
					local hitX = cx + ux * tHit -- 675
					local hitY = cy + uy * tHit -- 676
					local arrowLen = 18 -- 677
					local arrowHalf = 9 -- 678
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 679
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 680
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 681
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 682
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 683
					beaconDraw:drawDot( -- 684
						Vec2(hitX, hitY), -- 684
						4, -- 684
						ringColor -- 684
					) -- 684
				end -- 684
			end -- 684
		end -- 684
		dirty = false -- 688
	end -- 494
	return { -- 691
		setVisible = function(self, on) -- 692
			isVisible = on -- 693
			root.visible = on -- 694
			if not on then -- 694
				clearAll() -- 697
				dirty = false -- 698
			else -- 698
				dirty = true -- 700
			end -- 700
		end, -- 692
		visible = function(self) -- 703
			return isVisible -- 704
		end, -- 703
		fitTo = function(self, radius) -- 706
			baseFitRadius = radius -- 707
			recomputeMap() -- 708
		end, -- 706
		syncBodies = function(self, bs, vs, t) -- 710
			bodies = bs -- 711
			visuals = vs -- 712
			tWorld = t -- 713
			if #bodyLabels ~= #bs then -- 713
				bodyLabels = {} -- 716
				do -- 716
					local i = 0 -- 717
					while i < #bs do -- 717
						bodyLabels[#bodyLabels + 1] = createLabel(labelRoot, "", options.labelFontSize, options.labelHex) -- 718
						i = i + 1 -- 717
					end -- 717
				end -- 717
			end -- 717
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 717
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 724
				map.centerX = cp.x -- 725
				map.centerY = cp.y -- 726
				dirty = true -- 728
			end -- 728
			dirty = true -- 730
		end, -- 710
		syncProbe = function(self, p, v) -- 732
			probe = p -- 733
			probeVel = v -- 734
			dirty = true -- 735
			local best = -1 -- 741
			local bestPull = 0 -- 742
			local bestDist = 0 -- 743
			do -- 743
				local i = 0 -- 744
				while i < #bodies do -- 744
					do -- 744
						local b = bodies[i + 1] -- 745
						local d = distance( -- 746
							p, -- 746
							bodyPositionAt(b, tWorld) -- 746
						) -- 746
						if d < 1e-9 then -- 746
							goto __continue118 -- 747
						end -- 747
						local pull = b.gm / (d * d) -- 748
						if pull > bestPull then -- 748
							bestPull = pull -- 750
							best = i -- 751
							bestDist = d -- 752
						end -- 752
					end -- 752
					::__continue118:: -- 752
					i = i + 1 -- 744
				end -- 744
			end -- 744
			if best >= 0 then -- 744
				local alt = bestDist - bodies[best + 1].radius -- 756
				probeReadout = "探测器 · " .. __TS__NumberToFixed(alt > 0 and alt or 0, 0) -- 757
			else -- 757
				probeReadout = "探测器" -- 759
			end -- 759
		end, -- 732
		setPrediction = function(self, points) -- 762
			pred = points -- 763
			dirty = true -- 764
		end, -- 762
		clearPrediction = function(self) -- 766
			pred = {} -- 767
			dirty = true -- 768
		end, -- 766
		setTrail = function(self, points) -- 770
			trail = points -- 771
			dirty = true -- 772
		end, -- 770
		clearTrail = function(self) -- 774
			trail = {} -- 775
			dirty = true -- 776
		end, -- 774
		setProbeOrbit = function(self, center, radius) -- 778
			probeOrbitCenter = center -- 779
			probeOrbitRadius = radius -- 780
			dirty = true -- 781
		end, -- 778
		clearProbeOrbit = function(self) -- 783
			probeOrbitRadius = 0 -- 784
			dirty = true -- 785
		end, -- 783
		setGoalRings = function(self, rs) -- 787
			rings = rs -- 788
			dirty = true -- 789
		end, -- 787
		setBurn = function(____, direction, on) -- 791
			burnDirection = direction -- 791
			burning = on -- 791
		end, -- 791
		clearGoalRings = function(self) -- 792
			rings = {} -- 793
			dirty = true -- 794
		end, -- 792
		setStars = function(self, s, c) -- 796
			stars = s -- 797
			collectedStars = c -- 798
			dirty = true -- 799
		end, -- 796
		flush = function(self) -- 801
			if not isVisible then -- 801
				return -- 803
			end -- 803
			if not dirty then -- 803
				return -- 804
			end -- 804
			redraw() -- 805
		end, -- 801
		clear = function(self) -- 807
			clearAll() -- 808
			dirty = true -- 809
		end, -- 807
		probeScreen = function(self) -- 811
			return ____exports.planeToScreen(probe, map) -- 812
		end, -- 811
		mapping = function(self) -- 814
			return map -- 815
		end, -- 814
		zoomIn = function(self) -- 817
			currentZoom = math.min(60, currentZoom * 1.5) -- 820
			recomputeMap() -- 821
		end, -- 817
		zoomOut = function(self) -- 823
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 824
			recomputeMap() -- 825
		end, -- 823
		resetView = function(self) -- 827
			currentZoom = 1 -- 828
			panOffsetX = 0 -- 829
			panOffsetY = 0 -- 830
			recomputeMap() -- 831
		end, -- 827
		pan = function(self, dx, dy) -- 833
			panOffsetX = panOffsetX + dx -- 834
			panOffsetY = panOffsetY + dy -- 835
			recomputeMap() -- 836
		end, -- 833
		getZoom = function(self) -- 838
			return currentZoom -- 839
		end, -- 838
		root = root -- 841
	} -- 841
end -- 365
return ____exports -- 365
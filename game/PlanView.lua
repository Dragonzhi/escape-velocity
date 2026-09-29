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
function ____exports.defaultPlanOptions() -- 255
	return { -- 256
		marginFrac = 0.12, -- 257
		orbitHex = 4610157, -- 258
		orbitWidth = 1.5, -- 259
		orbitSegments = 72, -- 260
		ringHex = 9890780, -- 261
		ringWidth = 2.5, -- 262
		ringSegments = 48, -- 263
		pinRadius = 8, -- 264
		sunPinRadius = 13, -- 265
		sunGmMin = 10000, -- 266
		probePinRadius = 11, -- 267
		maxPinRadius = 26, -- 268
		probeTickLen = 22, -- 269
		predictHex = 7915775, -- 270
		predictWidth = 2.5, -- 271
		polylineMaxPoints = 240, -- 272
		trailHex = 16772266, -- 273
		trailWidth = 3.5, -- 274
		flowDotRadius = 3.5, -- 275
		flowDotHex = 16773327, -- 276
		probeHex = 15398143, -- 277
		probeOrbitHex = 6127526, -- 278
		labelFontSize = 20, -- 279
		labelHex = 12834536, -- 280
		labelGapY = 18, -- 281
		probeVisualRadius = PROBE_VISUAL_RADIUS -- 282
	} -- 282
end -- 255
--- 公里数 → 中文读数（航天模拟器那种）。
-- 
-- 口径：< 1 万 km 给整数带千分位（「6,571 km」）、< 1 亿给「万」（「38.4 万 km」）、
-- 再往上给「亿」（「1.50 亿 km」）。**不做科学计数法**：tstl 没有 toExponential（AGENTS 第 21 条），
-- 而且玩家读数要的是"38.4 万"这种人话，不是 3.844e5。
function ____exports.formatKm(km) -- 293
	if not (km > 0) then -- 293
		return "0 km" -- 294
	end -- 294
	if km < 10000 then -- 294
		local s = __TS__NumberToFixed( -- 297
			math.floor(km + 0.5), -- 297
			0 -- 297
		) -- 297
		local out = "" -- 298
		local count = 0 -- 299
		do -- 299
			local i = #s - 1 -- 300
			while i >= 0 do -- 300
				out = __TS__StringCharAt(s, i) .. out -- 301
				count = count + 1 -- 302
				if count % 3 == 0 and i > 0 then -- 302
					out = "," .. out -- 303
				end -- 303
				i = i - 1 -- 300
			end -- 300
		end -- 300
		return out .. " km" -- 305
	end -- 305
	if km < 100000000 then -- 305
		return __TS__NumberToFixed(km / 10000, 1) .. " 万 km" -- 307
	end -- 307
	return __TS__NumberToFixed(km / 100000000, 2) .. " 亿 km" -- 308
end -- 293
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 367
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 368
	local root = Node() -- 371
	local orbitDraw = DrawNode() -- 372
	local dotDraw = DrawNode() -- 373
	local ringDraw = DrawNode() -- 374
	local pathDraw = DrawNode() -- 375
	local pinDraw = DrawNode() -- 376
	local beaconDraw = DrawNode() -- 377
	root:addChild(orbitDraw) -- 378
	root:addChild(dotDraw) -- 379
	root:addChild(ringDraw) -- 380
	root:addChild(pathDraw) -- 381
	root:addChild(pinDraw) -- 382
	root:addChild(beaconDraw) -- 383
	local labelRoot = Node() -- 387
	root:addChild(labelRoot) -- 388
	--- 探测器读数标签（惰性建一次）。
	local probeLabel = nil -- 390
	--- 天体读数标签（与 bodies 一一对应，惰性建）。
	local bodyLabels = {} -- 392
	--- 探测器的读数文字（在 syncProbe 里按"此刻离哪个天体最近"算出来）。
	local probeReadout = "探测器" -- 394
	--- 上次写进 Label 的文字（**没变就别碰 Label**：文字布局每帧重算是纯浪费，Hud 同款纪律）。
	local lastProbeReadout = "" -- 396
	local lastBodyReadout = {} -- 397
	layer:addChild(root) -- 398
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 400
	local ringColor = colorFromHex(options.ringHex, 1) -- 401
	local predictColor = colorFromHex(options.predictHex, 1) -- 402
	local trailColor = colorFromHex(options.trailHex, 1) -- 403
	local probeColor = colorFromHex(options.probeHex, 1) -- 404
	local probeOrbitColor = colorFromHex(options.probeOrbitHex, 1) -- 405
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 406
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 408
	local isVisible = true -- 410
	local currentZoom = 1 -- 411
	local panOffsetX = 0 -- 412
	local panOffsetY = 0 -- 413
	local baseFitRadius = 1 -- 414
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 415
	local dirty = true -- 416
	local function recomputeMap() -- 418
		local effectiveR = baseFitRadius / currentZoom -- 419
		local newMap = ____exports.computePlanMapping( -- 420
			viewW, -- 420
			viewH, -- 420
			effectiveR, -- 420
			options.marginFrac, -- 420
			map.centerX, -- 420
			map.centerY -- 420
		) -- 420
		newMap.originX = viewW / 2 + panOffsetX -- 421
		newMap.originY = viewH / 2 + panOffsetY -- 422
		map = newMap -- 423
		dirty = true -- 424
	end -- 418
	local bodies = {} -- 428
	local visuals = {} -- 429
	local burning = false -- 430
	local burnDirection = {x = 0, y = 0} -- 431
	local probeOrbitCenter = {x = 0, y = 0} -- 433
	local probeOrbitRadius = 0 -- 434
	local tWorld = 0 -- 435
	local probe = {x = 0, y = 0} -- 436
	local probeVel = {x = 0, y = 0} -- 437
	local pred = {} -- 438
	local trail = {} -- 439
	local rings = {} -- 440
	local stars = {} -- 441
	local collectedStars = {} -- 442
	--- 标签贴边时别被切掉。
	-- 
	-- Label 是**居中锚点**（anchor 0.5/0.5），所以左右各留 1/6 屏宽 —— 够放 7–11 个字
	-- （「月球 · 38.4 万 km」在 20px 下约 150px，竖屏 840 宽 ⇒ 140 的余量正好）。
	local function clampLabelX(x) -- 450
		local pad = viewW / 6 -- 451
		if x < pad then -- 451
			return pad -- 452
		end -- 452
		if x > viewW - pad then -- 452
			return viewW - pad -- 453
		end -- 453
		return x -- 454
	end -- 450
	--- 上下留 26px（字号 20 的半高 + 一点余地）。
	local function clampLabelY(y) -- 457
		if y < 26 then -- 457
			return 26 -- 458
		end -- 458
		if y > viewH - 26 then -- 458
			return viewH - 26 -- 459
		end -- 459
		return y -- 460
	end -- 457
	local function clearAll() -- 463
		orbitDraw:clear() -- 464
		dotDraw:clear() -- 465
		ringDraw:clear() -- 466
		pathDraw:clear() -- 467
		pinDraw:clear() -- 468
		beaconDraw:clear() -- 469
	end -- 463
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 473
		local seg = n > 8 and n or 8 -- 474
		local out = {} -- 475
		do -- 475
			local i = 0 -- 476
			while i < seg do -- 476
				local a = i / seg * 2 * math.pi -- 477
				out[#out + 1] = Vec2( -- 478
					cx + rPx * math.cos(a), -- 478
					cy + rPx * math.sin(a) -- 478
				) -- 478
				i = i + 1 -- 476
			end -- 476
		end -- 476
		return out -- 480
	end -- 473
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 484
		if #pts < 2 then -- 484
			return -- 485
		end -- 485
		local dec = decimate(pts, options.polylineMaxPoints) -- 486
		local prev = nil -- 487
		for ____, p in ipairs(dec) do -- 488
			local s = ____exports.planeToScreen(p, map) -- 489
			local cur = Vec2(s.x, s.y) -- 490
			if prev ~= nil then -- 490
				pathDraw:drawSegment(prev, cur, width, color) -- 491
			end -- 491
			prev = cur -- 492
		end -- 492
	end -- 484
	local function redraw() -- 496
		clearAll() -- 497
		if not isVisible then -- 497
			return -- 498
		end -- 498
		for ____, b in ipairs(bodies) do -- 501
			do -- 501
				if b.orbitRadius <= 0 then -- 501
					goto __continue60 -- 502
				end -- 502
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 503
				local s = ____exports.planeToScreen(center, map) -- 504
				local rPx = b.orbitRadius * map.scale -- 505
				if rPx < 1 then -- 505
					goto __continue60 -- 506
				end -- 506
				orbitDraw:drawPolygon( -- 507
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 507
					noFill, -- 507
					options.orbitWidth, -- 507
					orbitColor -- 507
				) -- 507
			end -- 507
			::__continue60:: -- 507
		end -- 507
		if probeOrbitRadius > 0 then -- 507
			local ps = ____exports.planeToScreen(probeOrbitCenter, map) -- 512
			local pr = probeOrbitRadius * map.scale -- 513
			if pr >= 1 then -- 513
				orbitDraw:drawPolygon( -- 514
					circleVerts(ps.x, ps.y, pr, options.orbitSegments), -- 514
					noFill, -- 514
					options.orbitWidth, -- 514
					probeOrbitColor -- 514
				) -- 514
			end -- 514
		end -- 514
		if options.flowDotRadius > 0 then -- 514
			for ____, b in ipairs(bodies) do -- 521
				do -- 521
					if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 521
						goto __continue67 -- 522
					end -- 522
					local rPx = b.orbitRadius * map.scale -- 523
					if rPx < 1 then -- 523
						goto __continue67 -- 524
					end -- 524
					do -- 524
						local k = 0 -- 525
						while k < FlowDotsPerOrbit do -- 525
							local s = ____exports.planeToScreen( -- 526
								flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 526
								map -- 526
							) -- 526
							dotDraw:drawDot( -- 527
								Vec2(s.x, s.y), -- 527
								options.flowDotRadius, -- 527
								flowDotColor -- 527
							) -- 527
							k = k + 1 -- 525
						end -- 525
					end -- 525
				end -- 525
				::__continue67:: -- 525
			end -- 525
		end -- 525
		local gravityRingColor = Color(100, 180, 255, 70) -- 532
		for ____, b in ipairs(bodies) do -- 533
			if b.gm > 0 and not b.isObstacle then -- 533
				local center = options.transferTutorial == true and bodyPositionAt(b, tWorld) or (b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter) -- 535
				local s = ____exports.planeToScreen(center, map) -- 536
				local gravR = (b.radius * 3.6 + math.sin(tWorld * 3) * 4) * map.scale -- 537
				if gravR >= 5 then -- 537
					orbitDraw:drawPolygon( -- 539
						circleVerts(s.x, s.y, gravR, 48), -- 539
						noFill, -- 539
						1.5, -- 539
						gravityRingColor -- 539
					) -- 539
				end -- 539
			end -- 539
		end -- 539
		for ____, ring in ipairs(rings) do -- 545
			do -- 545
				local s = ____exports.planeToScreen(ring.center, map) -- 546
				if ring.point == true then -- 546
					ringDraw:drawDot( -- 548
						Vec2(s.x, s.y), -- 548
						10 * (ring.pulse ~= nil and ring.pulse or 1), -- 548
						Color(70, 220, 190, 45) -- 548
					) -- 548
					ringDraw:drawDot( -- 549
						Vec2(s.x, s.y), -- 549
						3.5, -- 549
						Color(170, 255, 230, 255) -- 549
					) -- 549
				end -- 549
				if ring.showRange == false then -- 549
					goto __continue77 -- 551
				end -- 551
				local rPx = ring.radius * map.scale -- 552
				if rPx < 1 then -- 552
					goto __continue77 -- 553
				end -- 553
				ringDraw:drawPolygon( -- 554
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 554
					noFill, -- 554
					options.ringWidth, -- 554
					ringColor -- 554
				) -- 554
			end -- 554
			::__continue77:: -- 554
		end -- 554
		drawPolyline(trail, trailColor, options.trailWidth) -- 558
		drawPolyline(pred, predictColor, options.predictWidth) -- 559
		do -- 559
			local i = 0 -- 567
			while i < #bodies do -- 567
				do -- 567
					local b = bodies[i + 1] -- 568
					local s = ____exports.planeToScreen( -- 569
						bodyPositionAt(b, tWorld), -- 569
						map -- 569
					) -- 569
					local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 570
					if i < #visuals then -- 570
						local v = visuals[i + 1] -- 572
						local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 573
						if vr > r then -- 573
							r = vr -- 574
						end -- 574
						if r > options.maxPinRadius then -- 574
							r = options.maxPinRadius -- 575
						end -- 575
					end -- 575
					local col = orbitColor -- 577
					if i < #visuals then -- 577
						local v = visuals[i + 1] -- 579
						col = Color( -- 580
							math.floor(v.r * 255), -- 580
							math.floor(v.g * 255), -- 580
							math.floor(v.b * 255), -- 580
							255 -- 580
						) -- 580
					end -- 580
					pinDraw:drawDot( -- 582
						Vec2(s.x, s.y), -- 582
						r, -- 582
						col -- 582
					) -- 582
					if i < #bodyLabels then -- 582
						local lb = bodyLabels[i + 1] -- 587
						local near = s.x > -60 and s.x < viewW + 60 and s.y > -60 and s.y < viewH + 60 -- 591
						setLabelVisible(lb, near) -- 592
						if not near then -- 592
							goto __continue83 -- 593
						end -- 593
						local name = i < #visuals and bodyLabel(visuals[i + 1].model) or "天体" -- 594
						local text = name -- 595
						if i >= #lastBodyReadout or lastBodyReadout[i + 1] ~= text then -- 595
							lastBodyReadout[i + 1] = text -- 597
							setLabelText(lb, text) -- 598
						end -- 598
						setLabelCenter( -- 600
							lb, -- 600
							clampLabelX(s.x), -- 600
							clampLabelY(s.y + r + options.labelGapY) -- 600
						) -- 600
					end -- 600
				end -- 600
				::__continue83:: -- 600
				i = i + 1 -- 567
			end -- 567
		end -- 567
		local ps = ____exports.planeToScreen(probe, map) -- 605
		local pr = options.probePinRadius -- 606
		local pvr = options.probeVisualRadius ~= nil and options.probeVisualRadius or PROBE_VISUAL_RADIUS -- 607
		if pvr > 0 and pvr * map.scale > pr then -- 607
			pr = pvr * map.scale -- 608
		end -- 608
		if pr > options.maxPinRadius then -- 608
			pr = options.maxPinRadius -- 609
		end -- 609
		pinDraw:drawDot( -- 610
			Vec2(ps.x, ps.y), -- 610
			pr, -- 610
			probeColor -- 610
		) -- 610
		pinDraw:drawPolygon( -- 611
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 611
			noFill, -- 611
			1.5, -- 611
			probeColor -- 611
		) -- 611
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 612
		if vlen > 0.000001 then -- 612
			local dx = probeVel.x / vlen -- 614
			local dy = probeVel.y / vlen -- 615
			pinDraw:drawSegment( -- 616
				Vec2(ps.x, ps.y), -- 617
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 618
				2, -- 619
				probeColor -- 620
			) -- 620
		end -- 620
		local burnMag = math.sqrt(burnDirection.x * burnDirection.x + burnDirection.y * burnDirection.y) -- 625
		if burning and burnMag > 0 then -- 625
			local ____end = ____exports.planeToScreen({x = probe.x - burnDirection.x * 32 / burnMag, y = probe.y - burnDirection.y * 32 / burnMag}, map) -- 627
			pinDraw:drawSegment( -- 628
				Vec2(ps.x, ps.y), -- 628
				Vec2(____end.x, ____end.y), -- 628
				4, -- 628
				Color(255, 135, 35, 160) -- 628
			) -- 628
			pinDraw:drawSegment( -- 629
				Vec2(ps.x, ps.y), -- 629
				Vec2(____end.x, ____end.y), -- 629
				1.5, -- 629
				Color(255, 235, 145, 255) -- 629
			) -- 629
		end -- 629
		do -- 629
			local i = 0 -- 631
			while i < #stars do -- 631
				local st = stars[i + 1] -- 632
				local isCol = i < #collectedStars and collectedStars[i + 1] -- 633
				local ss = ____exports.planeToScreen(st, map) -- 634
				if not isCol then -- 634
					pinDraw:drawDot( -- 636
						Vec2(ss.x, ss.y), -- 636
						8, -- 636
						Color(255, 215, 0, 255) -- 636
					) -- 636
					pinDraw:drawPolygon( -- 637
						circleVerts(ss.x, ss.y, 14, 16), -- 637
						noFill, -- 637
						1.5, -- 637
						Color(255, 230, 100, 200) -- 637
					) -- 637
				else -- 637
					pinDraw:drawDot( -- 639
						Vec2(ss.x, ss.y), -- 639
						5, -- 639
						Color(120, 120, 120, 100) -- 639
					) -- 639
				end -- 639
				i = i + 1 -- 631
			end -- 631
		end -- 631
		if probeLabel == nil then -- 631
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex) -- 645
			lastProbeReadout = probeReadout -- 646
		elseif lastProbeReadout ~= probeReadout then -- 646
			lastProbeReadout = probeReadout -- 648
			setLabelText(probeLabel, probeReadout) -- 649
		end -- 649
		setLabelVisible(probeLabel, ps.x > -60 and ps.x < viewW + 60 and ps.y > -60 and ps.y < viewH + 60) -- 651
		setLabelCenter( -- 652
			probeLabel, -- 652
			clampLabelX(ps.x), -- 652
			clampLabelY(ps.y - pr - options.labelGapY) -- 652
		) -- 652
		if #rings > 0 then -- 652
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 656
			local pad = 48 -- 657
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 658
			if isOffscreen then -- 658
				local cx = viewW / 2 -- 660
				local cy = viewH / 2 -- 661
				local dirX = targetScreen.x - cx -- 662
				local dirY = targetScreen.y - cy -- 663
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 664
				if len > 0.0001 then -- 664
					local ux = dirX / len -- 666
					local uy = dirY / len -- 667
					local halfW = viewW / 2 - pad -- 668
					local halfH = viewH / 2 - pad -- 669
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 670
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 671
					local tHit = math.min(scaleX, scaleY) -- 672
					local hitX = cx + ux * tHit -- 673
					local hitY = cy + uy * tHit -- 674
					local arrowLen = 18 -- 675
					local arrowHalf = 9 -- 676
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 677
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 678
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 679
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 680
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 681
					beaconDraw:drawDot( -- 682
						Vec2(hitX, hitY), -- 682
						4, -- 682
						ringColor -- 682
					) -- 682
				end -- 682
			end -- 682
		end -- 682
		dirty = false -- 686
	end -- 496
	return { -- 689
		setVisible = function(self, on) -- 690
			isVisible = on -- 691
			root.visible = on -- 692
			if not on then -- 692
				clearAll() -- 695
				dirty = false -- 696
			else -- 696
				dirty = true -- 698
			end -- 698
		end, -- 690
		visible = function(self) -- 701
			return isVisible -- 702
		end, -- 701
		fitTo = function(self, radius) -- 704
			baseFitRadius = radius -- 705
			recomputeMap() -- 706
		end, -- 704
		syncBodies = function(self, bs, vs, t) -- 708
			bodies = bs -- 709
			visuals = vs -- 710
			tWorld = t -- 711
			if #bodyLabels ~= #bs then -- 711
				bodyLabels = {} -- 714
				do -- 714
					local i = 0 -- 715
					while i < #bs do -- 715
						bodyLabels[#bodyLabels + 1] = createLabel(labelRoot, "", options.labelFontSize, options.labelHex) -- 716
						i = i + 1 -- 715
					end -- 715
				end -- 715
			end -- 715
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 715
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 722
				map.centerX = cp.x -- 723
				map.centerY = cp.y -- 724
				dirty = true -- 726
			end -- 726
			dirty = true -- 728
		end, -- 708
		syncProbe = function(self, p, v) -- 730
			probe = p -- 731
			probeVel = v -- 732
			dirty = true -- 733
			local best = -1 -- 739
			local bestPull = 0 -- 740
			local bestDist = 0 -- 741
			do -- 741
				local i = 0 -- 742
				while i < #bodies do -- 742
					do -- 742
						local b = bodies[i + 1] -- 743
						local d = distance( -- 744
							p, -- 744
							bodyPositionAt(b, tWorld) -- 744
						) -- 744
						if d < 1e-9 then -- 744
							goto __continue116 -- 745
						end -- 745
						local pull = b.gm / (d * d) -- 746
						if pull > bestPull then -- 746
							bestPull = pull -- 748
							best = i -- 749
							bestDist = d -- 750
						end -- 750
					end -- 750
					::__continue116:: -- 750
					i = i + 1 -- 742
				end -- 742
			end -- 742
			if best >= 0 then -- 742
				local alt = bestDist - bodies[best + 1].radius -- 754
				probeReadout = "探测器 · " .. __TS__NumberToFixed(alt > 0 and alt or 0, 0) -- 755
			else -- 755
				probeReadout = "探测器" -- 757
			end -- 757
		end, -- 730
		setPrediction = function(self, points) -- 760
			pred = points -- 761
			dirty = true -- 762
		end, -- 760
		clearPrediction = function(self) -- 764
			pred = {} -- 765
			dirty = true -- 766
		end, -- 764
		setTrail = function(self, points) -- 768
			trail = points -- 769
			dirty = true -- 770
		end, -- 768
		clearTrail = function(self) -- 772
			trail = {} -- 773
			dirty = true -- 774
		end, -- 772
		setProbeOrbit = function(self, center, radius) -- 776
			probeOrbitCenter = center -- 777
			probeOrbitRadius = radius -- 778
			dirty = true -- 779
		end, -- 776
		clearProbeOrbit = function(self) -- 781
			probeOrbitRadius = 0 -- 782
			dirty = true -- 783
		end, -- 781
		setGoalRings = function(self, rs) -- 785
			rings = rs -- 786
			dirty = true -- 787
		end, -- 785
		setBurn = function(____, direction, on) -- 789
			burnDirection = direction -- 789
			burning = on -- 789
		end, -- 789
		clearGoalRings = function(self) -- 790
			rings = {} -- 791
			dirty = true -- 792
		end, -- 790
		setStars = function(self, s, c) -- 794
			stars = s -- 795
			collectedStars = c -- 796
			dirty = true -- 797
		end, -- 794
		flush = function(self) -- 799
			if not isVisible then -- 799
				return -- 801
			end -- 801
			if not dirty then -- 801
				return -- 802
			end -- 802
			redraw() -- 803
		end, -- 799
		clear = function(self) -- 805
			clearAll() -- 806
			dirty = true -- 807
		end, -- 805
		probeScreen = function(self) -- 809
			return ____exports.planeToScreen(probe, map) -- 810
		end, -- 809
		mapping = function(self) -- 812
			return map -- 813
		end, -- 812
		zoomIn = function(self) -- 815
			currentZoom = math.min(60, currentZoom * 1.5) -- 818
			recomputeMap() -- 819
		end, -- 815
		zoomOut = function(self) -- 821
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 822
			recomputeMap() -- 823
		end, -- 821
		resetView = function(self) -- 825
			currentZoom = 1 -- 826
			panOffsetX = 0 -- 827
			panOffsetY = 0 -- 828
			recomputeMap() -- 829
		end, -- 825
		pan = function(self, dx, dy) -- 831
			panOffsetX = panOffsetX + dx -- 832
			panOffsetY = panOffsetY + dy -- 833
			recomputeMap() -- 834
		end, -- 831
		getZoom = function(self) -- 836
			return currentZoom -- 837
		end, -- 836
		root = root -- 839
	} -- 839
end -- 367
return ____exports -- 367
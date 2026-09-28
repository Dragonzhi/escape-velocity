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
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 354
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 355
	local root = Node() -- 358
	local orbitDraw = DrawNode() -- 359
	local dotDraw = DrawNode() -- 360
	local ringDraw = DrawNode() -- 361
	local pathDraw = DrawNode() -- 362
	local pinDraw = DrawNode() -- 363
	local beaconDraw = DrawNode() -- 364
	root:addChild(orbitDraw) -- 365
	root:addChild(dotDraw) -- 366
	root:addChild(ringDraw) -- 367
	root:addChild(pathDraw) -- 368
	root:addChild(pinDraw) -- 369
	root:addChild(beaconDraw) -- 370
	local labelRoot = Node() -- 374
	root:addChild(labelRoot) -- 375
	--- 探测器读数标签（惰性建一次）。
	local probeLabel = nil -- 377
	--- 天体读数标签（与 bodies 一一对应，惰性建）。
	local bodyLabels = {} -- 379
	--- 探测器的读数文字（在 syncProbe 里按"此刻离哪个天体最近"算出来）。
	local probeReadout = "探测器" -- 381
	--- 上次写进 Label 的文字（**没变就别碰 Label**：文字布局每帧重算是纯浪费，Hud 同款纪律）。
	local lastProbeReadout = "" -- 383
	local lastBodyReadout = {} -- 384
	layer:addChild(root) -- 385
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 387
	local ringColor = colorFromHex(options.ringHex, 1) -- 388
	local predictColor = colorFromHex(options.predictHex, 1) -- 389
	local trailColor = colorFromHex(options.trailHex, 1) -- 390
	local probeColor = colorFromHex(options.probeHex, 1) -- 391
	local probeOrbitColor = colorFromHex(options.probeOrbitHex, 1) -- 392
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 393
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 395
	local isVisible = true -- 397
	local currentZoom = 1 -- 398
	local panOffsetX = 0 -- 399
	local panOffsetY = 0 -- 400
	local baseFitRadius = 1 -- 401
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 402
	local dirty = true -- 403
	local function recomputeMap() -- 405
		local effectiveR = baseFitRadius / currentZoom -- 406
		local newMap = ____exports.computePlanMapping( -- 407
			viewW, -- 407
			viewH, -- 407
			effectiveR, -- 407
			options.marginFrac, -- 407
			map.centerX, -- 407
			map.centerY -- 407
		) -- 407
		newMap.originX = viewW / 2 + panOffsetX -- 408
		newMap.originY = viewH / 2 + panOffsetY -- 409
		map = newMap -- 410
		dirty = true -- 411
	end -- 405
	local bodies = {} -- 415
	local visuals = {} -- 416
	local probeOrbitCenter = {x = 0, y = 0} -- 418
	local probeOrbitRadius = 0 -- 419
	local tWorld = 0 -- 420
	local probe = {x = 0, y = 0} -- 421
	local probeVel = {x = 0, y = 0} -- 422
	local pred = {} -- 423
	local trail = {} -- 424
	local rings = {} -- 425
	--- 标签贴边时别被切掉。
	-- 
	-- Label 是**居中锚点**（anchor 0.5/0.5），所以左右各留 1/6 屏宽 —— 够放 7–11 个字
	-- （「月球 · 38.4 万 km」在 20px 下约 150px，竖屏 840 宽 ⇒ 140 的余量正好）。
	local function clampLabelX(x) -- 433
		local pad = viewW / 6 -- 434
		if x < pad then -- 434
			return pad -- 435
		end -- 435
		if x > viewW - pad then -- 435
			return viewW - pad -- 436
		end -- 436
		return x -- 437
	end -- 433
	--- 上下留 26px（字号 20 的半高 + 一点余地）。
	local function clampLabelY(y) -- 440
		if y < 26 then -- 440
			return 26 -- 441
		end -- 441
		if y > viewH - 26 then -- 441
			return viewH - 26 -- 442
		end -- 442
		return y -- 443
	end -- 440
	local function clearAll() -- 446
		orbitDraw:clear() -- 447
		dotDraw:clear() -- 448
		ringDraw:clear() -- 449
		pathDraw:clear() -- 450
		pinDraw:clear() -- 451
		beaconDraw:clear() -- 452
	end -- 446
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 456
		local seg = n > 8 and n or 8 -- 457
		local out = {} -- 458
		do -- 458
			local i = 0 -- 459
			while i < seg do -- 459
				local a = i / seg * 2 * math.pi -- 460
				out[#out + 1] = Vec2( -- 461
					cx + rPx * math.cos(a), -- 461
					cy + rPx * math.sin(a) -- 461
				) -- 461
				i = i + 1 -- 459
			end -- 459
		end -- 459
		return out -- 463
	end -- 456
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 467
		if #pts < 2 then -- 467
			return -- 468
		end -- 468
		local dec = decimate(pts, options.polylineMaxPoints) -- 469
		local prev = nil -- 470
		for ____, p in ipairs(dec) do -- 471
			local s = ____exports.planeToScreen(p, map) -- 472
			local cur = Vec2(s.x, s.y) -- 473
			if prev ~= nil then -- 473
				pathDraw:drawSegment(prev, cur, width, color) -- 474
			end -- 474
			prev = cur -- 475
		end -- 475
	end -- 467
	local function redraw() -- 479
		clearAll() -- 480
		if not isVisible then -- 480
			return -- 481
		end -- 481
		for ____, b in ipairs(bodies) do -- 484
			do -- 484
				if b.orbitRadius <= 0 then -- 484
					goto __continue56 -- 485
				end -- 485
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 486
				local s = ____exports.planeToScreen(center, map) -- 487
				local rPx = b.orbitRadius * map.scale -- 488
				if rPx < 1 then -- 488
					goto __continue56 -- 489
				end -- 489
				orbitDraw:drawPolygon( -- 490
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 490
					noFill, -- 490
					options.orbitWidth, -- 490
					orbitColor -- 490
				) -- 490
			end -- 490
			::__continue56:: -- 490
		end -- 490
		if probeOrbitRadius > 0 then -- 490
			local ps = ____exports.planeToScreen(probeOrbitCenter, map) -- 495
			local pr = probeOrbitRadius * map.scale -- 496
			if pr >= 1 then -- 496
				orbitDraw:drawPolygon( -- 497
					circleVerts(ps.x, ps.y, pr, options.orbitSegments), -- 497
					noFill, -- 497
					options.orbitWidth, -- 497
					probeOrbitColor -- 497
				) -- 497
			end -- 497
		end -- 497
		if options.flowDotRadius > 0 then -- 497
			for ____, b in ipairs(bodies) do -- 504
				do -- 504
					if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 504
						goto __continue63 -- 505
					end -- 505
					local rPx = b.orbitRadius * map.scale -- 506
					if rPx < 1 then -- 506
						goto __continue63 -- 507
					end -- 507
					do -- 507
						local k = 0 -- 508
						while k < FlowDotsPerOrbit do -- 508
							local s = ____exports.planeToScreen( -- 509
								flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 509
								map -- 509
							) -- 509
							dotDraw:drawDot( -- 510
								Vec2(s.x, s.y), -- 510
								options.flowDotRadius, -- 510
								flowDotColor -- 510
							) -- 510
							k = k + 1 -- 508
						end -- 508
					end -- 508
				end -- 508
				::__continue63:: -- 508
			end -- 508
		end -- 508
		for ____, ring in ipairs(rings) do -- 515
			do -- 515
				local s = ____exports.planeToScreen(ring.center, map) -- 516
				local rPx = ring.radius * map.scale -- 517
				if rPx < 1 then -- 517
					goto __continue69 -- 518
				end -- 518
				ringDraw:drawPolygon( -- 519
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 519
					noFill, -- 519
					options.ringWidth, -- 519
					ringColor -- 519
				) -- 519
			end -- 519
			::__continue69:: -- 519
		end -- 519
		drawPolyline(trail, trailColor, options.trailWidth) -- 523
		drawPolyline(pred, predictColor, options.predictWidth) -- 524
		do -- 524
			local i = 0 -- 532
			while i < #bodies do -- 532
				do -- 532
					local b = bodies[i + 1] -- 533
					local s = ____exports.planeToScreen( -- 534
						bodyPositionAt(b, tWorld), -- 534
						map -- 534
					) -- 534
					local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 535
					if i < #visuals then -- 535
						local v = visuals[i + 1] -- 537
						local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 538
						if vr > r then -- 538
							r = vr -- 539
						end -- 539
						if r > options.maxPinRadius then -- 539
							r = options.maxPinRadius -- 540
						end -- 540
					end -- 540
					local col = orbitColor -- 542
					if i < #visuals then -- 542
						local v = visuals[i + 1] -- 544
						col = Color( -- 545
							math.floor(v.r * 255), -- 545
							math.floor(v.g * 255), -- 545
							math.floor(v.b * 255), -- 545
							255 -- 545
						) -- 545
					end -- 545
					pinDraw:drawDot( -- 547
						Vec2(s.x, s.y), -- 547
						r, -- 547
						col -- 547
					) -- 547
					if i < #bodyLabels then -- 547
						local lb = bodyLabels[i + 1] -- 552
						local near = s.x > -60 and s.x < viewW + 60 and s.y > -60 and s.y < viewH + 60 -- 556
						setLabelVisible(lb, near) -- 557
						if not near then -- 557
							goto __continue73 -- 558
						end -- 558
						local name = i < #visuals and bodyLabel(visuals[i + 1].model) or "天体" -- 559
						local text = b.orbitRadius > 0 and (name .. " · ") .. ____exports.formatKm(b.orbitRadius * KmPerUnit) or name -- 560
						if i >= #lastBodyReadout or lastBodyReadout[i + 1] ~= text then -- 560
							lastBodyReadout[i + 1] = text -- 562
							setLabelText(lb, text) -- 563
						end -- 563
						setLabelCenter( -- 565
							lb, -- 565
							clampLabelX(s.x), -- 565
							clampLabelY(s.y + r + options.labelGapY) -- 565
						) -- 565
					end -- 565
				end -- 565
				::__continue73:: -- 565
				i = i + 1 -- 532
			end -- 532
		end -- 532
		local ps = ____exports.planeToScreen(probe, map) -- 570
		local pr = options.probePinRadius -- 571
		local pvr = options.probeVisualRadius ~= nil and options.probeVisualRadius or PROBE_VISUAL_RADIUS -- 572
		if pvr > 0 and pvr * map.scale > pr then -- 572
			pr = pvr * map.scale -- 573
		end -- 573
		if pr > options.maxPinRadius then -- 573
			pr = options.maxPinRadius -- 574
		end -- 574
		pinDraw:drawDot( -- 575
			Vec2(ps.x, ps.y), -- 575
			pr, -- 575
			probeColor -- 575
		) -- 575
		pinDraw:drawPolygon( -- 576
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 576
			noFill, -- 576
			1.5, -- 576
			probeColor -- 576
		) -- 576
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 577
		if vlen > 0.000001 then -- 577
			local dx = probeVel.x / vlen -- 579
			local dy = probeVel.y / vlen -- 580
			pinDraw:drawSegment( -- 581
				Vec2(ps.x, ps.y), -- 582
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 583
				2, -- 584
				probeColor -- 585
			) -- 585
		end -- 585
		if probeLabel == nil then -- 585
			probeLabel = createLabel(labelRoot, probeReadout, options.labelFontSize, options.labelHex) -- 591
			lastProbeReadout = probeReadout -- 592
		elseif lastProbeReadout ~= probeReadout then -- 592
			lastProbeReadout = probeReadout -- 594
			setLabelText(probeLabel, probeReadout) -- 595
		end -- 595
		setLabelVisible(probeLabel, ps.x > -60 and ps.x < viewW + 60 and ps.y > -60 and ps.y < viewH + 60) -- 597
		setLabelCenter( -- 598
			probeLabel, -- 598
			clampLabelX(ps.x), -- 598
			clampLabelY(ps.y - pr - options.labelGapY) -- 598
		) -- 598
		if #rings > 0 then -- 598
			local targetScreen = ____exports.planeToScreen(rings[1].center, map) -- 602
			local pad = 48 -- 603
			local isOffscreen = targetScreen.x < pad or targetScreen.x > viewW - pad or targetScreen.y < pad or targetScreen.y > viewH - pad -- 604
			if isOffscreen then -- 604
				local cx = viewW / 2 -- 606
				local cy = viewH / 2 -- 607
				local dirX = targetScreen.x - cx -- 608
				local dirY = targetScreen.y - cy -- 609
				local len = math.sqrt(dirX * dirX + dirY * dirY) -- 610
				if len > 0.0001 then -- 610
					local ux = dirX / len -- 612
					local uy = dirY / len -- 613
					local halfW = viewW / 2 - pad -- 614
					local halfH = viewH / 2 - pad -- 615
					local scaleX = math.abs(ux) > 0.000001 and halfW / math.abs(ux) or 1000000000 -- 616
					local scaleY = math.abs(uy) > 0.000001 and halfH / math.abs(uy) or 1000000000 -- 617
					local tHit = math.min(scaleX, scaleY) -- 618
					local hitX = cx + ux * tHit -- 619
					local hitY = cy + uy * tHit -- 620
					local arrowLen = 18 -- 621
					local arrowHalf = 9 -- 622
					local tip = Vec2(hitX + ux * 6, hitY + uy * 6) -- 623
					local back = Vec2(hitX - ux * arrowLen, hitY - uy * arrowLen) -- 624
					local left = Vec2(back.x - uy * arrowHalf, back.y + ux * arrowHalf) -- 625
					local right = Vec2(back.x + uy * arrowHalf, back.y - ux * arrowHalf) -- 626
					beaconDraw:drawPolygon({tip, left, right}, ringColor, 1.5, ringColor) -- 627
					beaconDraw:drawDot( -- 628
						Vec2(hitX, hitY), -- 628
						4, -- 628
						ringColor -- 628
					) -- 628
				end -- 628
			end -- 628
		end -- 628
		dirty = false -- 632
	end -- 479
	return { -- 635
		setVisible = function(self, on) -- 636
			isVisible = on -- 637
			root.visible = on -- 638
			if not on then -- 638
				clearAll() -- 641
				dirty = false -- 642
			else -- 642
				dirty = true -- 644
			end -- 644
		end, -- 636
		visible = function(self) -- 647
			return isVisible -- 648
		end, -- 647
		fitTo = function(self, radius) -- 650
			baseFitRadius = radius -- 651
			recomputeMap() -- 652
		end, -- 650
		syncBodies = function(self, bs, vs, t) -- 654
			bodies = bs -- 655
			visuals = vs -- 656
			tWorld = t -- 657
			if #bodyLabels ~= #bs then -- 657
				bodyLabels = {} -- 660
				do -- 660
					local i = 0 -- 661
					while i < #bs do -- 661
						bodyLabels[#bodyLabels + 1] = createLabel(labelRoot, "", options.labelFontSize, options.labelHex) -- 662
						i = i + 1 -- 661
					end -- 661
				end -- 661
			end -- 661
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 661
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 668
				map.centerX = cp.x -- 669
				map.centerY = cp.y -- 670
				dirty = true -- 672
			end -- 672
			dirty = true -- 674
		end, -- 654
		syncProbe = function(self, p, v) -- 676
			probe = p -- 677
			probeVel = v -- 678
			dirty = true -- 679
			local best = -1 -- 685
			local bestPull = 0 -- 686
			local bestDist = 0 -- 687
			do -- 687
				local i = 0 -- 688
				while i < #bodies do -- 688
					do -- 688
						local b = bodies[i + 1] -- 689
						local d = distance( -- 690
							p, -- 690
							bodyPositionAt(b, tWorld) -- 690
						) -- 690
						if d < 1e-9 then -- 690
							goto __continue101 -- 691
						end -- 691
						local pull = b.gm / (d * d) -- 692
						if pull > bestPull then -- 692
							bestPull = pull -- 694
							best = i -- 695
							bestDist = d -- 696
						end -- 696
					end -- 696
					::__continue101:: -- 696
					i = i + 1 -- 688
				end -- 688
			end -- 688
			if best >= 0 then -- 688
				local alt = (bestDist - bodies[best + 1].radius) * KmPerUnit -- 700
				probeReadout = "探测器 · 高度 " .. ____exports.formatKm(alt > 0 and alt or 0) -- 701
			else -- 701
				probeReadout = "探测器" -- 703
			end -- 703
		end, -- 676
		setPrediction = function(self, points) -- 706
			pred = points -- 707
			dirty = true -- 708
		end, -- 706
		clearPrediction = function(self) -- 710
			pred = {} -- 711
			dirty = true -- 712
		end, -- 710
		setTrail = function(self, points) -- 714
			trail = points -- 715
			dirty = true -- 716
		end, -- 714
		clearTrail = function(self) -- 718
			trail = {} -- 719
			dirty = true -- 720
		end, -- 718
		setProbeOrbit = function(self, center, radius) -- 722
			probeOrbitCenter = center -- 723
			probeOrbitRadius = radius -- 724
			dirty = true -- 725
		end, -- 722
		clearProbeOrbit = function(self) -- 727
			probeOrbitRadius = 0 -- 728
			dirty = true -- 729
		end, -- 727
		setGoalRings = function(self, rs) -- 731
			rings = rs -- 732
			dirty = true -- 733
		end, -- 731
		clearGoalRings = function(self) -- 735
			rings = {} -- 736
			dirty = true -- 737
		end, -- 735
		flush = function(self) -- 739
			if not isVisible then -- 739
				return -- 741
			end -- 741
			if not dirty then -- 741
				return -- 742
			end -- 742
			redraw() -- 743
		end, -- 739
		clear = function(self) -- 745
			clearAll() -- 746
			dirty = true -- 747
		end, -- 745
		probeScreen = function(self) -- 749
			return ____exports.planeToScreen(probe, map) -- 750
		end, -- 749
		mapping = function(self) -- 752
			return map -- 753
		end, -- 752
		zoomIn = function(self) -- 755
			currentZoom = math.min(60, currentZoom * 1.5) -- 758
			recomputeMap() -- 759
		end, -- 755
		zoomOut = function(self) -- 761
			currentZoom = math.max(0.25, currentZoom / 1.5) -- 762
			recomputeMap() -- 763
		end, -- 761
		resetView = function(self) -- 765
			currentZoom = 1 -- 766
			panOffsetX = 0 -- 767
			panOffsetY = 0 -- 768
			recomputeMap() -- 769
		end, -- 765
		pan = function(self, dx, dy) -- 771
			panOffsetX = panOffsetX + dx -- 772
			panOffsetY = panOffsetY + dy -- 773
			recomputeMap() -- 774
		end, -- 771
		getZoom = function(self) -- 776
			return currentZoom -- 777
		end, -- 776
		root = root -- 779
	} -- 779
end -- 354
return ____exports -- 354
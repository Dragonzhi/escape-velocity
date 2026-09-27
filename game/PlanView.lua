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
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 295
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 296
	local root = Node() -- 299
	local orbitDraw = DrawNode() -- 300
	local dotDraw = DrawNode() -- 301
	local ringDraw = DrawNode() -- 302
	local pathDraw = DrawNode() -- 303
	local pinDraw = DrawNode() -- 304
	root:addChild(orbitDraw) -- 305
	root:addChild(dotDraw) -- 306
	root:addChild(ringDraw) -- 307
	root:addChild(pathDraw) -- 308
	root:addChild(pinDraw) -- 309
	layer:addChild(root) -- 310
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 312
	local ringColor = colorFromHex(options.ringHex, 1) -- 313
	local predictColor = colorFromHex(options.predictHex, 1) -- 314
	local trailColor = colorFromHex(options.trailHex, 1) -- 315
	local probeColor = colorFromHex(options.probeHex, 1) -- 316
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 317
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 319
	local isVisible = true -- 321
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 322
	local dirty = true -- 323
	local bodies = {} -- 326
	local visuals = {} -- 327
	local tWorld = 0 -- 328
	local probe = {x = 0, y = 0} -- 329
	local probeVel = {x = 0, y = 0} -- 330
	local pred = {} -- 331
	local trail = {} -- 332
	local rings = {} -- 333
	local function clearAll() -- 335
		orbitDraw:clear() -- 336
		dotDraw:clear() -- 337
		ringDraw:clear() -- 338
		pathDraw:clear() -- 339
		pinDraw:clear() -- 340
	end -- 335
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 344
		local seg = n > 8 and n or 8 -- 345
		local out = {} -- 346
		do -- 346
			local i = 0 -- 347
			while i < seg do -- 347
				local a = i / seg * 2 * math.pi -- 348
				out[#out + 1] = Vec2( -- 349
					cx + rPx * math.cos(a), -- 349
					cy + rPx * math.sin(a) -- 349
				) -- 349
				i = i + 1 -- 347
			end -- 347
		end -- 347
		return out -- 351
	end -- 344
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 355
		if #pts < 2 then -- 355
			return -- 356
		end -- 356
		local dec = decimate(pts, options.polylineMaxPoints) -- 357
		local prev = nil -- 358
		for ____, p in ipairs(dec) do -- 359
			local s = ____exports.planeToScreen(p, map) -- 360
			local cur = Vec2(s.x, s.y) -- 361
			if prev ~= nil then -- 361
				pathDraw:drawSegment(prev, cur, width, color) -- 362
			end -- 362
			prev = cur -- 363
		end -- 363
	end -- 355
	local function redraw() -- 367
		clearAll() -- 368
		if not isVisible then -- 368
			return -- 369
		end -- 369
		for ____, b in ipairs(bodies) do -- 372
			do -- 372
				if b.orbitRadius <= 0 then -- 372
					goto __continue42 -- 373
				end -- 373
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 374
				local s = ____exports.planeToScreen(center, map) -- 375
				local rPx = b.orbitRadius * map.scale -- 376
				if rPx < 1 then -- 376
					goto __continue42 -- 377
				end -- 377
				orbitDraw:drawPolygon( -- 378
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 378
					noFill, -- 378
					options.orbitWidth, -- 378
					orbitColor -- 378
				) -- 378
			end -- 378
			::__continue42:: -- 378
		end -- 378
		for ____, b in ipairs(bodies) do -- 385
			do -- 385
				if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 385
					goto __continue46 -- 386
				end -- 386
				local rPx = b.orbitRadius * map.scale -- 387
				if rPx < 1 then -- 387
					goto __continue46 -- 388
				end -- 388
				do -- 388
					local k = 0 -- 389
					while k < FlowDotsPerOrbit do -- 389
						local s = ____exports.planeToScreen( -- 390
							flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 390
							map -- 390
						) -- 390
						dotDraw:drawDot( -- 391
							Vec2(s.x, s.y), -- 391
							options.flowDotRadius, -- 391
							flowDotColor -- 391
						) -- 391
						k = k + 1 -- 389
					end -- 389
				end -- 389
			end -- 389
			::__continue46:: -- 389
		end -- 389
		for ____, ring in ipairs(rings) do -- 396
			do -- 396
				local s = ____exports.planeToScreen(ring.center, map) -- 397
				local rPx = ring.radius * map.scale -- 398
				if rPx < 1 then -- 398
					goto __continue52 -- 399
				end -- 399
				ringDraw:drawPolygon( -- 400
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 400
					noFill, -- 400
					options.ringWidth, -- 400
					ringColor -- 400
				) -- 400
			end -- 400
			::__continue52:: -- 400
		end -- 400
		drawPolyline(trail, trailColor, options.trailWidth) -- 404
		drawPolyline(pred, predictColor, options.predictWidth) -- 405
		do -- 405
			local i = 0 -- 413
			while i < #bodies do -- 413
				local b = bodies[i + 1] -- 414
				local s = ____exports.planeToScreen( -- 415
					bodyPositionAt(b, tWorld), -- 415
					map -- 415
				) -- 415
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 416
				if i < #visuals then -- 416
					local v = visuals[i + 1] -- 418
					local vr = v.displayRadius > 0 and v.displayRadius * map.scale or 0 -- 419
					if vr > r then -- 419
						r = vr -- 420
					end -- 420
					if r > options.maxPinRadius then -- 420
						r = options.maxPinRadius -- 421
					end -- 421
				end -- 421
				local col = orbitColor -- 423
				if i < #visuals then -- 423
					local v = visuals[i + 1] -- 425
					col = Color( -- 426
						math.floor(v.r * 255), -- 426
						math.floor(v.g * 255), -- 426
						math.floor(v.b * 255), -- 426
						255 -- 426
					) -- 426
				end -- 426
				pinDraw:drawDot( -- 428
					Vec2(s.x, s.y), -- 428
					r, -- 428
					col -- 428
				) -- 428
				i = i + 1 -- 413
			end -- 413
		end -- 413
		local ps = ____exports.planeToScreen(probe, map) -- 432
		local pr = options.probePinRadius -- 433
		if PROBE_VISUAL_RADIUS > 0 and PROBE_VISUAL_RADIUS * map.scale > pr then -- 433
			pr = PROBE_VISUAL_RADIUS * map.scale -- 434
		end -- 434
		if pr > options.maxPinRadius then -- 434
			pr = options.maxPinRadius -- 435
		end -- 435
		pinDraw:drawDot( -- 436
			Vec2(ps.x, ps.y), -- 436
			pr, -- 436
			probeColor -- 436
		) -- 436
		pinDraw:drawPolygon( -- 437
			circleVerts(ps.x, ps.y, pr + 5, 24), -- 437
			noFill, -- 437
			1.5, -- 437
			probeColor -- 437
		) -- 437
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 438
		if vlen > 0.000001 then -- 438
			local dx = probeVel.x / vlen -- 440
			local dy = probeVel.y / vlen -- 441
			pinDraw:drawSegment( -- 442
				Vec2(ps.x, ps.y), -- 443
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 444
				2, -- 445
				probeColor -- 446
			) -- 446
		end -- 446
		dirty = false -- 449
	end -- 367
	return { -- 452
		setVisible = function(self, on) -- 453
			isVisible = on -- 454
			root.visible = on -- 455
			if not on then -- 455
				clearAll() -- 458
				dirty = false -- 459
			else -- 459
				dirty = true -- 461
			end -- 461
		end, -- 453
		visible = function(self) -- 464
			return isVisible -- 465
		end, -- 464
		fitTo = function(self, radius) -- 467
			map = ____exports.computePlanMapping(viewW, viewH, radius, options.marginFrac) -- 468
			dirty = true -- 469
		end, -- 467
		syncBodies = function(self, bs, vs, t) -- 471
			bodies = bs -- 472
			visuals = vs -- 473
			tWorld = t -- 474
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 474
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 478
				map.centerX = cp.x -- 479
				map.centerY = cp.y -- 480
				dirty = true -- 482
			end -- 482
			dirty = true -- 484
		end, -- 471
		syncProbe = function(self, p, v) -- 486
			probe = p -- 487
			probeVel = v -- 488
			dirty = true -- 489
		end, -- 486
		setPrediction = function(self, points) -- 491
			pred = points -- 492
			dirty = true -- 493
		end, -- 491
		clearPrediction = function(self) -- 495
			pred = {} -- 496
			dirty = true -- 497
		end, -- 495
		setTrail = function(self, points) -- 499
			trail = points -- 500
			dirty = true -- 501
		end, -- 499
		clearTrail = function(self) -- 503
			trail = {} -- 504
			dirty = true -- 505
		end, -- 503
		setGoalRings = function(self, rs) -- 507
			rings = rs -- 508
			dirty = true -- 509
		end, -- 507
		clearGoalRings = function(self) -- 511
			rings = {} -- 512
			dirty = true -- 513
		end, -- 511
		flush = function(self) -- 515
			if not isVisible then -- 515
				return -- 517
			end -- 517
			if not dirty then -- 517
				return -- 518
			end -- 518
			redraw() -- 519
		end, -- 515
		clear = function(self) -- 521
			clearAll() -- 522
			dirty = true -- 523
		end, -- 521
		probeScreen = function(self) -- 525
			return ____exports.planeToScreen(probe, map) -- 526
		end, -- 525
		mapping = function(self) -- 528
			return map -- 529
		end, -- 528
		root = root -- 531
	} -- 531
end -- 295
return ____exports -- 295
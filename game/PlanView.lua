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
local ____Ui = require("game.Ui") -- 33
local colorFromHex = ____Ui.colorFromHex -- 33
--- 求"把半径 `radius` 的圆完整放进视口"的等比映射，四周留 `marginFrac` 的边距。
-- 
-- 取 x / y 两个方向里**更紧**的那个比例 ⇒ 至少一个方向正好贴住边距，另一个方向更宽松。
-- `marginFrac` 夹在 [0, 0.45]：写 0.5 会让可用区域变成 0（映射退化）。
function ____exports.computePlanMapping(viewW, viewH, radius, marginFrac, centerX, centerY) -- 67
	local m = marginFrac -- 68
	if m < 0 then -- 68
		m = 0 -- 69
	end -- 69
	if m > 0.45 then -- 69
		m = 0.45 -- 70
	end -- 70
	local usable = 1 - 2 * m -- 71
	local r = radius > 0.000001 and radius or 1 -- 72
	local sx = viewW * usable / (2 * r) -- 73
	local sy = viewH * usable / (2 * r) -- 74
	local scale = sx < sy and sx or sy -- 75
	if not (scale > 0) then -- 75
		scale = 1 -- 76
	end -- 76
	return { -- 77
		scale = scale, -- 78
		originX = viewW / 2, -- 79
		originY = viewH / 2, -- 80
		centerX = centerX ~= nil and centerX or 0, -- 81
		centerY = centerY ~= nil and centerY or 0 -- 82
	} -- 82
end -- 67
--- 平面点 → 屏幕像素（左下原点、+Y 向上）。
-- 
-- ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
function ____exports.planeToScreen(p, m) -- 91
	return {x = m.originX + (p.x - m.centerX) * m.scale, y = m.originY - (p.y - m.centerY) * m.scale} -- 93
end -- 91
--- `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。
function ____exports.screenToPlane(q, m) -- 97
	return {x = (q.x - m.originX) / m.scale + m.centerX, y = (m.originY - q.y) / m.scale + m.centerY} -- 98
end -- 97
--- 天体（含卫星的宿主链）到平面原点的**最大**距离。
-- 
-- 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
local function bodyCenterDist(b) -- 106
	local own = b.orbitRadius > 0 and b.orbitRadius or 0 -- 107
	if b.host ~= nil then -- 107
		return bodyCenterDist(b.host) + own -- 108
	end -- 108
	return own -- 109
end -- 106
--- 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
-- 
-- - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
-- - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance, centerIndex) -- 118
	if centerIndex ~= nil and centerIndex >= 0 and centerIndex < #bodies then -- 118
		local c = bodies[centerIndex + 1] -- 121
		local cp = bodyPositionAt(c, 0) -- 122
		local r = 0 -- 123
		local lim = c.orbitRadius * 0.5 -- 129
		do -- 129
			local i = 0 -- 130
			while i < #bodies do -- 130
				do -- 130
					local b = bodies[i + 1] -- 131
					if b ~= c then -- 131
						if b.orbitRadius <= 0 or b.orbitRadius >= lim then -- 131
							goto __continue13 -- 133
						end -- 133
						if distance( -- 133
							bodyPositionAt(b, 0), -- 134
							cp -- 134
						) >= lim then -- 134
							goto __continue13 -- 134
						end -- 134
					end -- 134
					local p = bodyPositionAt(b, 0) -- 136
					local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 137
					local d = distance(p, cp) + pad -- 138
					if d > r then -- 138
						r = d -- 139
					end -- 139
				end -- 139
				::__continue13:: -- 139
				i = i + 1 -- 130
			end -- 130
		end -- 130
		local pd = distance(probeStart, cp) -- 141
		if pd > r then -- 141
			r = pd -- 142
		end -- 142
		return r > 0.000001 and r or 1 -- 143
	end -- 143
	local r = 0 -- 145
	do -- 145
		local i = 0 -- 146
		while i < #bodies do -- 146
			local b = bodies[i + 1] -- 147
			local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 148
			local d = bodyCenterDist(b) + pad -- 149
			if d > r then -- 149
				r = d -- 150
			end -- 150
			i = i + 1 -- 146
		end -- 146
	end -- 146
	local pd = math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y) -- 152
	if pd > r then -- 152
		r = pd -- 153
	end -- 153
	return r > 0.000001 and r or 1 -- 154
end -- 118
--- 判定"这两个天体是不是同一个"（scaledPlanets 拷贝过宿主链 ⇒ 不能比对象身份，比位置与 gm）。
function ____exports.sameBody(a, b) -- 158
	return a.gm == b.gm and a.radius == b.radius and a.orbitRadius == b.orbitRadius -- 159
end -- 158
--- 2D 到达圈的半径（平面单位）—— **就是航点容差，绝不是视觉半径**。
-- 
-- S5 §3.8 规则 3：旧的硬约束「视觉半径必须等于物理半径」作废之后，
-- 玩家判断"够不够得着"的唯一依据变成了这个圈。所以它必须由容差算出，
-- 且**不随视觉半径变化** —— Test/PlanViewTest 有断言守着这两条。
function ____exports.arrivalRingRadius(goal) -- 169
	local r = goal.tolerance -- 170
	if goal.chain ~= nil then -- 170
		do -- 170
			local i = 0 -- 172
			while i < #goal.chain do -- 172
				if goal.chain[i + 1].tolerance > r then -- 172
					r = goal.chain[i + 1].tolerance -- 173
				end -- 173
				i = i + 1 -- 172
			end -- 172
		end -- 172
	end -- 172
	return r -- 176
end -- 169
function ____exports.defaultPlanOptions() -- 218
	return { -- 219
		marginFrac = 0.12, -- 220
		orbitHex = 4610157, -- 221
		orbitWidth = 1.5, -- 222
		orbitSegments = 72, -- 223
		ringHex = 9890780, -- 224
		ringWidth = 2.5, -- 225
		ringSegments = 48, -- 226
		pinRadius = 8, -- 227
		sunPinRadius = 13, -- 228
		sunGmMin = 10000, -- 229
		probePinRadius = 11, -- 230
		probeTickLen = 22, -- 231
		predictHex = 7915775, -- 232
		predictWidth = 2.5, -- 233
		polylineMaxPoints = 240, -- 234
		trailHex = 16772266, -- 235
		trailWidth = 3.5, -- 236
		flowDotRadius = 3.5, -- 237
		flowDotHex = 16773327, -- 238
		probeHex = 15398143 -- 239
	} -- 239
end -- 218
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts, centerBodyIndex) -- 287
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 288
	local root = Node() -- 291
	local orbitDraw = DrawNode() -- 292
	local dotDraw = DrawNode() -- 293
	local ringDraw = DrawNode() -- 294
	local pathDraw = DrawNode() -- 295
	local pinDraw = DrawNode() -- 296
	root:addChild(orbitDraw) -- 297
	root:addChild(dotDraw) -- 298
	root:addChild(ringDraw) -- 299
	root:addChild(pathDraw) -- 300
	root:addChild(pinDraw) -- 301
	layer:addChild(root) -- 302
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 304
	local ringColor = colorFromHex(options.ringHex, 1) -- 305
	local predictColor = colorFromHex(options.predictHex, 1) -- 306
	local trailColor = colorFromHex(options.trailHex, 1) -- 307
	local probeColor = colorFromHex(options.probeHex, 1) -- 308
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 309
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 311
	local isVisible = true -- 313
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 314
	local dirty = true -- 315
	local bodies = {} -- 318
	local visuals = {} -- 319
	local tWorld = 0 -- 320
	local probe = {x = 0, y = 0} -- 321
	local probeVel = {x = 0, y = 0} -- 322
	local pred = {} -- 323
	local trail = {} -- 324
	local rings = {} -- 325
	local function clearAll() -- 327
		orbitDraw:clear() -- 328
		dotDraw:clear() -- 329
		ringDraw:clear() -- 330
		pathDraw:clear() -- 331
		pinDraw:clear() -- 332
	end -- 327
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 336
		local seg = n > 8 and n or 8 -- 337
		local out = {} -- 338
		do -- 338
			local i = 0 -- 339
			while i < seg do -- 339
				local a = i / seg * 2 * math.pi -- 340
				out[#out + 1] = Vec2( -- 341
					cx + rPx * math.cos(a), -- 341
					cy + rPx * math.sin(a) -- 341
				) -- 341
				i = i + 1 -- 339
			end -- 339
		end -- 339
		return out -- 343
	end -- 336
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 347
		if #pts < 2 then -- 347
			return -- 348
		end -- 348
		local dec = decimate(pts, options.polylineMaxPoints) -- 349
		local prev = nil -- 350
		for ____, p in ipairs(dec) do -- 351
			local s = ____exports.planeToScreen(p, map) -- 352
			local cur = Vec2(s.x, s.y) -- 353
			if prev ~= nil then -- 353
				pathDraw:drawSegment(prev, cur, width, color) -- 354
			end -- 354
			prev = cur -- 355
		end -- 355
	end -- 347
	local function redraw() -- 359
		clearAll() -- 360
		if not isVisible then -- 360
			return -- 361
		end -- 361
		for ____, b in ipairs(bodies) do -- 364
			do -- 364
				if b.orbitRadius <= 0 then -- 364
					goto __continue42 -- 365
				end -- 365
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 366
				local s = ____exports.planeToScreen(center, map) -- 367
				local rPx = b.orbitRadius * map.scale -- 368
				if rPx < 1 then -- 368
					goto __continue42 -- 369
				end -- 369
				orbitDraw:drawPolygon( -- 370
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 370
					noFill, -- 370
					options.orbitWidth, -- 370
					orbitColor -- 370
				) -- 370
			end -- 370
			::__continue42:: -- 370
		end -- 370
		for ____, b in ipairs(bodies) do -- 377
			do -- 377
				if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 377
					goto __continue46 -- 378
				end -- 378
				local rPx = b.orbitRadius * map.scale -- 379
				if rPx < 1 then -- 379
					goto __continue46 -- 380
				end -- 380
				do -- 380
					local k = 0 -- 381
					while k < FlowDotsPerOrbit do -- 381
						local s = ____exports.planeToScreen( -- 382
							flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 382
							map -- 382
						) -- 382
						dotDraw:drawDot( -- 383
							Vec2(s.x, s.y), -- 383
							options.flowDotRadius, -- 383
							flowDotColor -- 383
						) -- 383
						k = k + 1 -- 381
					end -- 381
				end -- 381
			end -- 381
			::__continue46:: -- 381
		end -- 381
		for ____, ring in ipairs(rings) do -- 388
			do -- 388
				local s = ____exports.planeToScreen(ring.center, map) -- 389
				local rPx = ring.radius * map.scale -- 390
				if rPx < 1 then -- 390
					goto __continue52 -- 391
				end -- 391
				ringDraw:drawPolygon( -- 392
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 392
					noFill, -- 392
					options.ringWidth, -- 392
					ringColor -- 392
				) -- 392
			end -- 392
			::__continue52:: -- 392
		end -- 392
		drawPolyline(trail, trailColor, options.trailWidth) -- 396
		drawPolyline(pred, predictColor, options.predictWidth) -- 397
		do -- 397
			local i = 0 -- 400
			while i < #bodies do -- 400
				local b = bodies[i + 1] -- 401
				local s = ____exports.planeToScreen( -- 402
					bodyPositionAt(b, tWorld), -- 402
					map -- 402
				) -- 402
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 403
				local col = orbitColor -- 404
				if i < #visuals then -- 404
					local v = visuals[i + 1] -- 406
					col = Color( -- 407
						math.floor(v.r * 255), -- 407
						math.floor(v.g * 255), -- 407
						math.floor(v.b * 255), -- 407
						255 -- 407
					) -- 407
				end -- 407
				pinDraw:drawDot( -- 409
					Vec2(s.x, s.y), -- 409
					r, -- 409
					col -- 409
				) -- 409
				i = i + 1 -- 400
			end -- 400
		end -- 400
		local ps = ____exports.planeToScreen(probe, map) -- 413
		pinDraw:drawDot( -- 414
			Vec2(ps.x, ps.y), -- 414
			options.probePinRadius, -- 414
			probeColor -- 414
		) -- 414
		pinDraw:drawPolygon( -- 415
			circleVerts(ps.x, ps.y, options.probePinRadius + 5, 24), -- 415
			noFill, -- 415
			1.5, -- 415
			probeColor -- 415
		) -- 415
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 416
		if vlen > 0.000001 then -- 416
			local dx = probeVel.x / vlen -- 418
			local dy = probeVel.y / vlen -- 419
			pinDraw:drawSegment( -- 420
				Vec2(ps.x, ps.y), -- 421
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 422
				2, -- 423
				probeColor -- 424
			) -- 424
		end -- 424
		dirty = false -- 427
	end -- 359
	return { -- 430
		setVisible = function(self, on) -- 431
			isVisible = on -- 432
			root.visible = on -- 433
			if not on then -- 433
				clearAll() -- 436
				dirty = false -- 437
			else -- 437
				dirty = true -- 439
			end -- 439
		end, -- 431
		visible = function(self) -- 442
			return isVisible -- 443
		end, -- 442
		fitTo = function(self, radius) -- 445
			map = ____exports.computePlanMapping(viewW, viewH, radius, options.marginFrac) -- 446
			dirty = true -- 447
		end, -- 445
		syncBodies = function(self, bs, vs, t) -- 449
			bodies = bs -- 450
			visuals = vs -- 451
			tWorld = t -- 452
			if centerBodyIndex ~= nil and centerBodyIndex >= 0 and centerBodyIndex < #bs then -- 452
				local cp = bodyPositionAt(bs[centerBodyIndex + 1], t) -- 456
				map.centerX = cp.x -- 457
				map.centerY = cp.y -- 458
				dirty = true -- 460
			end -- 460
			dirty = true -- 462
		end, -- 449
		syncProbe = function(self, p, v) -- 464
			probe = p -- 465
			probeVel = v -- 466
			dirty = true -- 467
		end, -- 464
		setPrediction = function(self, points) -- 469
			pred = points -- 470
			dirty = true -- 471
		end, -- 469
		clearPrediction = function(self) -- 473
			pred = {} -- 474
			dirty = true -- 475
		end, -- 473
		setTrail = function(self, points) -- 477
			trail = points -- 478
			dirty = true -- 479
		end, -- 477
		clearTrail = function(self) -- 481
			trail = {} -- 482
			dirty = true -- 483
		end, -- 481
		setGoalRings = function(self, rs) -- 485
			rings = rs -- 486
			dirty = true -- 487
		end, -- 485
		clearGoalRings = function(self) -- 489
			rings = {} -- 490
			dirty = true -- 491
		end, -- 489
		flush = function(self) -- 493
			if not isVisible then -- 493
				return -- 495
			end -- 495
			if not dirty then -- 495
				return -- 496
			end -- 496
			redraw() -- 497
		end, -- 493
		clear = function(self) -- 499
			clearAll() -- 500
			dirty = true -- 501
		end, -- 499
		probeScreen = function(self) -- 503
			return ____exports.planeToScreen(probe, map) -- 504
		end, -- 503
		mapping = function(self) -- 506
			return map -- 507
		end, -- 506
		root = root -- 509
	} -- 509
end -- 287
return ____exports -- 287
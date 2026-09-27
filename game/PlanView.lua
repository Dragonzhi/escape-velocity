-- [ts]: PlanView.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 28
local Color = ____Dora.Color -- 28
local DrawNode = ____Dora.DrawNode -- 28
local Node = ____Dora.Node -- 28
local Vec2 = ____Dora.Vec2 -- 28
local ____Gravity = require("game.Gravity") -- 29
local bodyPositionAt = ____Gravity.bodyPositionAt -- 29
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
function ____exports.computePlanMapping(viewW, viewH, radius, marginFrac) -- 57
	local m = marginFrac -- 58
	if m < 0 then -- 58
		m = 0 -- 59
	end -- 59
	if m > 0.45 then -- 59
		m = 0.45 -- 60
	end -- 60
	local usable = 1 - 2 * m -- 61
	local r = radius > 0.000001 and radius or 1 -- 62
	local sx = viewW * usable / (2 * r) -- 63
	local sy = viewH * usable / (2 * r) -- 64
	local scale = sx < sy and sx or sy -- 65
	if not (scale > 0) then -- 65
		scale = 1 -- 66
	end -- 66
	return {scale = scale, originX = viewW / 2, originY = viewH / 2} -- 67
end -- 57
--- 平面点 → 屏幕像素（左下原点、+Y 向上）。
-- 
-- ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
function ____exports.planeToScreen(p, m) -- 75
	return {x = m.originX + p.x * m.scale, y = m.originY - p.y * m.scale} -- 76
end -- 75
--- `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。
function ____exports.screenToPlane(q, m) -- 80
	return {x = (q.x - m.originX) / m.scale, y = (m.originY - q.y) / m.scale} -- 81
end -- 80
--- 天体（含卫星的宿主链）到平面原点的**最大**距离。
-- 
-- 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
local function bodyCenterDist(b) -- 89
	local own = b.orbitRadius > 0 and b.orbitRadius or 0 -- 90
	if b.host ~= nil then -- 90
		return bodyCenterDist(b.host) + own -- 91
	end -- 91
	return own -- 92
end -- 89
--- 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
-- 
-- - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
-- - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance) -- 101
	local r = 0 -- 102
	do -- 102
		local i = 0 -- 103
		while i < #bodies do -- 103
			local b = bodies[i + 1] -- 104
			local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 105
			local d = bodyCenterDist(b) + pad -- 106
			if d > r then -- 106
				r = d -- 107
			end -- 107
			i = i + 1 -- 103
		end -- 103
	end -- 103
	local pd = math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y) -- 109
	if pd > r then -- 109
		r = pd -- 110
	end -- 110
	return r > 0.000001 and r or 1 -- 111
end -- 101
function ____exports.defaultPlanOptions() -- 153
	return { -- 154
		marginFrac = 0.12, -- 155
		orbitHex = 4610157, -- 156
		orbitWidth = 1.5, -- 157
		orbitSegments = 72, -- 158
		ringHex = 9890780, -- 159
		ringWidth = 2.5, -- 160
		ringSegments = 48, -- 161
		pinRadius = 8, -- 162
		sunPinRadius = 13, -- 163
		sunGmMin = 10000, -- 164
		probePinRadius = 11, -- 165
		probeTickLen = 22, -- 166
		predictHex = 7915775, -- 167
		predictWidth = 2.5, -- 168
		polylineMaxPoints = 240, -- 169
		trailHex = 16772266, -- 170
		trailWidth = 3.5, -- 171
		flowDotRadius = 3.5, -- 172
		flowDotHex = 16773327, -- 173
		probeHex = 15398143 -- 174
	} -- 174
end -- 153
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts) -- 222
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 223
	local root = Node() -- 226
	local orbitDraw = DrawNode() -- 227
	local dotDraw = DrawNode() -- 228
	local ringDraw = DrawNode() -- 229
	local pathDraw = DrawNode() -- 230
	local pinDraw = DrawNode() -- 231
	root:addChild(orbitDraw) -- 232
	root:addChild(dotDraw) -- 233
	root:addChild(ringDraw) -- 234
	root:addChild(pathDraw) -- 235
	root:addChild(pinDraw) -- 236
	layer:addChild(root) -- 237
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 239
	local ringColor = colorFromHex(options.ringHex, 1) -- 240
	local predictColor = colorFromHex(options.predictHex, 1) -- 241
	local trailColor = colorFromHex(options.trailHex, 1) -- 242
	local probeColor = colorFromHex(options.probeHex, 1) -- 243
	local flowDotColor = colorFromHex(options.flowDotHex, 1) -- 244
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 246
	local isVisible = true -- 248
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 249
	local dirty = true -- 250
	local bodies = {} -- 253
	local visuals = {} -- 254
	local tWorld = 0 -- 255
	local probe = {x = 0, y = 0} -- 256
	local probeVel = {x = 0, y = 0} -- 257
	local pred = {} -- 258
	local trail = {} -- 259
	local rings = {} -- 260
	local function clearAll() -- 262
		orbitDraw:clear() -- 263
		dotDraw:clear() -- 264
		ringDraw:clear() -- 265
		pathDraw:clear() -- 266
		pinDraw:clear() -- 267
	end -- 262
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 271
		local seg = n > 8 and n or 8 -- 272
		local out = {} -- 273
		do -- 273
			local i = 0 -- 274
			while i < seg do -- 274
				local a = i / seg * 2 * math.pi -- 275
				out[#out + 1] = Vec2( -- 276
					cx + rPx * math.cos(a), -- 276
					cy + rPx * math.sin(a) -- 276
				) -- 276
				i = i + 1 -- 274
			end -- 274
		end -- 274
		return out -- 278
	end -- 271
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 282
		if #pts < 2 then -- 282
			return -- 283
		end -- 283
		local dec = decimate(pts, options.polylineMaxPoints) -- 284
		local prev = nil -- 285
		for ____, p in ipairs(dec) do -- 286
			local s = ____exports.planeToScreen(p, map) -- 287
			local cur = Vec2(s.x, s.y) -- 288
			if prev ~= nil then -- 288
				pathDraw:drawSegment(prev, cur, width, color) -- 289
			end -- 289
			prev = cur -- 290
		end -- 290
	end -- 282
	local function redraw() -- 294
		clearAll() -- 295
		if not isVisible then -- 295
			return -- 296
		end -- 296
		for ____, b in ipairs(bodies) do -- 299
			do -- 299
				if b.orbitRadius <= 0 then -- 299
					goto __continue28 -- 300
				end -- 300
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 301
				local s = ____exports.planeToScreen(center, map) -- 302
				local rPx = b.orbitRadius * map.scale -- 303
				if rPx < 1 then -- 303
					goto __continue28 -- 304
				end -- 304
				orbitDraw:drawPolygon( -- 305
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 305
					noFill, -- 305
					options.orbitWidth, -- 305
					orbitColor -- 305
				) -- 305
			end -- 305
			::__continue28:: -- 305
		end -- 305
		for ____, b in ipairs(bodies) do -- 312
			do -- 312
				if b.orbitRadius <= 0 or b.orbitPeriod == 0 then -- 312
					goto __continue32 -- 313
				end -- 313
				local rPx = b.orbitRadius * map.scale -- 314
				if rPx < 1 then -- 314
					goto __continue32 -- 315
				end -- 315
				do -- 315
					local k = 0 -- 316
					while k < FlowDotsPerOrbit do -- 316
						local s = ____exports.planeToScreen( -- 317
							flowDotPosition(b, tWorld, k, FlowDotsPerOrbit), -- 317
							map -- 317
						) -- 317
						dotDraw:drawDot( -- 318
							Vec2(s.x, s.y), -- 318
							options.flowDotRadius, -- 318
							flowDotColor -- 318
						) -- 318
						k = k + 1 -- 316
					end -- 316
				end -- 316
			end -- 316
			::__continue32:: -- 316
		end -- 316
		for ____, ring in ipairs(rings) do -- 323
			do -- 323
				local s = ____exports.planeToScreen(ring.center, map) -- 324
				local rPx = ring.radius * map.scale -- 325
				if rPx < 1 then -- 325
					goto __continue38 -- 326
				end -- 326
				ringDraw:drawPolygon( -- 327
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 327
					noFill, -- 327
					options.ringWidth, -- 327
					ringColor -- 327
				) -- 327
			end -- 327
			::__continue38:: -- 327
		end -- 327
		drawPolyline(trail, trailColor, options.trailWidth) -- 331
		drawPolyline(pred, predictColor, options.predictWidth) -- 332
		do -- 332
			local i = 0 -- 335
			while i < #bodies do -- 335
				local b = bodies[i + 1] -- 336
				local s = ____exports.planeToScreen( -- 337
					bodyPositionAt(b, tWorld), -- 337
					map -- 337
				) -- 337
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 338
				local col = orbitColor -- 339
				if i < #visuals then -- 339
					local v = visuals[i + 1] -- 341
					col = Color( -- 342
						math.floor(v.r * 255), -- 342
						math.floor(v.g * 255), -- 342
						math.floor(v.b * 255), -- 342
						255 -- 342
					) -- 342
				end -- 342
				pinDraw:drawDot( -- 344
					Vec2(s.x, s.y), -- 344
					r, -- 344
					col -- 344
				) -- 344
				i = i + 1 -- 335
			end -- 335
		end -- 335
		local ps = ____exports.planeToScreen(probe, map) -- 348
		pinDraw:drawDot( -- 349
			Vec2(ps.x, ps.y), -- 349
			options.probePinRadius, -- 349
			probeColor -- 349
		) -- 349
		pinDraw:drawPolygon( -- 350
			circleVerts(ps.x, ps.y, options.probePinRadius + 5, 24), -- 350
			noFill, -- 350
			1.5, -- 350
			probeColor -- 350
		) -- 350
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 351
		if vlen > 0.000001 then -- 351
			local dx = probeVel.x / vlen -- 353
			local dy = probeVel.y / vlen -- 354
			pinDraw:drawSegment( -- 355
				Vec2(ps.x, ps.y), -- 356
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 357
				2, -- 358
				probeColor -- 359
			) -- 359
		end -- 359
		dirty = false -- 362
	end -- 294
	return { -- 365
		setVisible = function(self, on) -- 366
			isVisible = on -- 367
			root.visible = on -- 368
			if not on then -- 368
				clearAll() -- 371
				dirty = false -- 372
			else -- 372
				dirty = true -- 374
			end -- 374
		end, -- 366
		visible = function(self) -- 377
			return isVisible -- 378
		end, -- 377
		fitTo = function(self, radius) -- 380
			map = ____exports.computePlanMapping(viewW, viewH, radius, options.marginFrac) -- 381
			dirty = true -- 382
		end, -- 380
		syncBodies = function(self, bs, vs, t) -- 384
			bodies = bs -- 385
			visuals = vs -- 386
			tWorld = t -- 387
			dirty = true -- 388
		end, -- 384
		syncProbe = function(self, p, v) -- 390
			probe = p -- 391
			probeVel = v -- 392
			dirty = true -- 393
		end, -- 390
		setPrediction = function(self, points) -- 395
			pred = points -- 396
			dirty = true -- 397
		end, -- 395
		clearPrediction = function(self) -- 399
			pred = {} -- 400
			dirty = true -- 401
		end, -- 399
		setTrail = function(self, points) -- 403
			trail = points -- 404
			dirty = true -- 405
		end, -- 403
		clearTrail = function(self) -- 407
			trail = {} -- 408
			dirty = true -- 409
		end, -- 407
		setGoalRings = function(self, rs) -- 411
			rings = rs -- 412
			dirty = true -- 413
		end, -- 411
		clearGoalRings = function(self) -- 415
			rings = {} -- 416
			dirty = true -- 417
		end, -- 415
		flush = function(self) -- 419
			if not isVisible then -- 419
				return -- 421
			end -- 421
			if not dirty then -- 421
				return -- 422
			end -- 422
			redraw() -- 423
		end, -- 419
		clear = function(self) -- 425
			clearAll() -- 426
			dirty = true -- 427
		end, -- 425
		probeScreen = function(self) -- 429
			return ____exports.planeToScreen(probe, map) -- 430
		end, -- 429
		mapping = function(self) -- 432
			return map -- 433
		end, -- 432
		root = root -- 435
	} -- 435
end -- 222
return ____exports -- 222
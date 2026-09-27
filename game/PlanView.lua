-- [ts]: PlanView.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Color = ____Dora.Color -- 26
local DrawNode = ____Dora.DrawNode -- 26
local Node = ____Dora.Node -- 26
local Vec2 = ____Dora.Vec2 -- 26
local ____Gravity = require("game.Gravity") -- 27
local bodyPositionAt = ____Gravity.bodyPositionAt -- 27
local ____Trajectory = require("game.Trajectory") -- 28
local decimate = ____Trajectory.decimate -- 28
local ____Ui = require("game.Ui") -- 30
local colorFromHex = ____Ui.colorFromHex -- 30
--- 求"把半径 `radius` 的圆完整放进视口"的等比映射，四周留 `marginFrac` 的边距。
-- 
-- 取 x / y 两个方向里**更紧**的那个比例 ⇒ 至少一个方向正好贴住边距，另一个方向更宽松。
-- `marginFrac` 夹在 [0, 0.45]：写 0.5 会让可用区域变成 0（映射退化）。
function ____exports.computePlanMapping(viewW, viewH, radius, marginFrac) -- 54
	local m = marginFrac -- 55
	if m < 0 then -- 55
		m = 0 -- 56
	end -- 56
	if m > 0.45 then -- 56
		m = 0.45 -- 57
	end -- 57
	local usable = 1 - 2 * m -- 58
	local r = radius > 0.000001 and radius or 1 -- 59
	local sx = viewW * usable / (2 * r) -- 60
	local sy = viewH * usable / (2 * r) -- 61
	local scale = sx < sy and sx or sy -- 62
	if not (scale > 0) then -- 62
		scale = 1 -- 63
	end -- 63
	return {scale = scale, originX = viewW / 2, originY = viewH / 2} -- 64
end -- 54
--- 平面点 → 屏幕像素（左下原点、+Y 向上）。
-- 
-- ⚠️ **y 取负**：平面 +y 画在屏幕**下方**（理由见文件头第 3 条）。
function ____exports.planeToScreen(p, m) -- 72
	return {x = m.originX + p.x * m.scale, y = m.originY - p.y * m.scale} -- 73
end -- 72
--- `planeToScreen` 的逆（诊断、以及将来"点图定位"用）。
function ____exports.screenToPlane(q, m) -- 77
	return {x = (q.x - m.originX) / m.scale, y = (m.originY - q.y) / m.scale} -- 78
end -- 77
--- 天体（含卫星的宿主链）到平面原点的**最大**距离。
-- 
-- 月球这种卫星的圆心是**会动的宿主**（地球），所以它的最远距离 = 宿主的轨道半径 + 自己的轨道半径。
local function bodyCenterDist(b) -- 86
	local own = b.orbitRadius > 0 and b.orbitRadius or 0 -- 87
	if b.host ~= nil then -- 87
		return bodyCenterDist(b.host) + own -- 88
	end -- 88
	return own -- 89
end -- 86
--- 2D 视图要装下的**平面半径** = 最外圈轨道 + 到达容差（设计稿："最外圈轨道 + 目标容差"）。
-- 
-- - 每颗天体：自己的最远距离 + `max(本体半径, 目标容差)`（目标那颗要留出圈的余量）；
-- - 探测器的出发点也要在画面内（L1 的探测器在 90，比地球轨道 80 还远）。
function ____exports.planFitRadius(bodies, probeStart, goalIndex, goalTolerance) -- 98
	local r = 0 -- 99
	do -- 99
		local i = 0 -- 100
		while i < #bodies do -- 100
			local b = bodies[i + 1] -- 101
			local pad = i == goalIndex and goalTolerance > b.radius and goalTolerance or b.radius -- 102
			local d = bodyCenterDist(b) + pad -- 103
			if d > r then -- 103
				r = d -- 104
			end -- 104
			i = i + 1 -- 100
		end -- 100
	end -- 100
	local pd = math.sqrt(probeStart.x * probeStart.x + probeStart.y * probeStart.y) -- 106
	if pd > r then -- 106
		r = pd -- 107
	end -- 107
	return r > 0.000001 and r or 1 -- 108
end -- 98
function ____exports.defaultPlanOptions() -- 146
	return { -- 147
		marginFrac = 0.12, -- 148
		orbitHex = 4610157, -- 149
		orbitWidth = 1.5, -- 150
		orbitSegments = 72, -- 151
		ringHex = 9890780, -- 152
		ringWidth = 2.5, -- 153
		ringSegments = 48, -- 154
		pinRadius = 8, -- 155
		sunPinRadius = 13, -- 156
		sunGmMin = 10000, -- 157
		probePinRadius = 11, -- 158
		probeTickLen = 22, -- 159
		predictHex = 7915775, -- 160
		predictWidth = 2.5, -- 161
		polylineMaxPoints = 240, -- 162
		trailHex = 16772266, -- 163
		trailWidth = 3.5, -- 164
		probeHex = 15398143 -- 165
	} -- 165
end -- 146
--- 创建 2D 规划视图。
-- 
-- @param layer 挂载的父节点，必须是**关卡 2D 层**（左下原点绝对像素空间，见文件头）
-- @param viewW 视图逻辑宽（`View.size.width`）
-- @param viewH 视图逻辑高
function ____exports.createPlanView(layer, viewW, viewH, opts) -- 213
	local options = opts ~= nil and opts or ____exports.defaultPlanOptions() -- 214
	local root = Node() -- 217
	local orbitDraw = DrawNode() -- 218
	local ringDraw = DrawNode() -- 219
	local pathDraw = DrawNode() -- 220
	local pinDraw = DrawNode() -- 221
	root:addChild(orbitDraw) -- 222
	root:addChild(ringDraw) -- 223
	root:addChild(pathDraw) -- 224
	root:addChild(pinDraw) -- 225
	layer:addChild(root) -- 226
	local orbitColor = colorFromHex(options.orbitHex, 1) -- 228
	local ringColor = colorFromHex(options.ringHex, 1) -- 229
	local predictColor = colorFromHex(options.predictHex, 1) -- 230
	local trailColor = colorFromHex(options.trailHex, 1) -- 231
	local probeColor = colorFromHex(options.probeHex, 1) -- 232
	--- 只描边不填充：`drawPolygon` 的填充用全透明色（与 Ui.createPanel 的手法一致）。
	local noFill = colorFromHex(0, 0) -- 234
	local isVisible = true -- 236
	local map = ____exports.computePlanMapping(viewW, viewH, 1, options.marginFrac) -- 237
	local dirty = true -- 238
	local bodies = {} -- 241
	local visuals = {} -- 242
	local tWorld = 0 -- 243
	local probe = {x = 0, y = 0} -- 244
	local probeVel = {x = 0, y = 0} -- 245
	local pred = {} -- 246
	local trail = {} -- 247
	local rings = {} -- 248
	local function clearAll() -- 250
		orbitDraw:clear() -- 251
		ringDraw:clear() -- 252
		pathDraw:clear() -- 253
		pinDraw:clear() -- 254
	end -- 250
	--- 圆周顶点（`n` 段；返回 Vec2 给 drawPolygon 描边用）。
	local function circleVerts(cx, cy, rPx, n) -- 258
		local seg = n > 8 and n or 8 -- 259
		local out = {} -- 260
		do -- 260
			local i = 0 -- 261
			while i < seg do -- 261
				local a = i / seg * 2 * math.pi -- 262
				out[#out + 1] = Vec2( -- 263
					cx + rPx * math.cos(a), -- 263
					cy + rPx * math.sin(a) -- 263
				) -- 263
				i = i + 1 -- 261
			end -- 261
		end -- 261
		return out -- 265
	end -- 258
	--- 平面折线 → 屏幕折线（抽稀后逐段画）。
	local function drawPolyline(pts, color, width) -- 269
		if #pts < 2 then -- 269
			return -- 270
		end -- 270
		local dec = decimate(pts, options.polylineMaxPoints) -- 271
		local prev = nil -- 272
		for ____, p in ipairs(dec) do -- 273
			local s = ____exports.planeToScreen(p, map) -- 274
			local cur = Vec2(s.x, s.y) -- 275
			if prev ~= nil then -- 275
				pathDraw:drawSegment(prev, cur, width, color) -- 276
			end -- 276
			prev = cur -- 277
		end -- 277
	end -- 269
	local function redraw() -- 281
		clearAll() -- 282
		if not isVisible then -- 282
			return -- 283
		end -- 283
		for ____, b in ipairs(bodies) do -- 286
			do -- 286
				if b.orbitRadius <= 0 then -- 286
					goto __continue28 -- 287
				end -- 287
				local center = b.host ~= nil and bodyPositionAt(b.host, tWorld) or b.orbitCenter -- 288
				local s = ____exports.planeToScreen(center, map) -- 289
				local rPx = b.orbitRadius * map.scale -- 290
				if rPx < 1 then -- 290
					goto __continue28 -- 291
				end -- 291
				orbitDraw:drawPolygon( -- 292
					circleVerts(s.x, s.y, rPx, options.orbitSegments), -- 292
					noFill, -- 292
					options.orbitWidth, -- 292
					orbitColor -- 292
				) -- 292
			end -- 292
			::__continue28:: -- 292
		end -- 292
		for ____, ring in ipairs(rings) do -- 296
			do -- 296
				local s = ____exports.planeToScreen(ring.center, map) -- 297
				local rPx = ring.radius * map.scale -- 298
				if rPx < 1 then -- 298
					goto __continue32 -- 299
				end -- 299
				ringDraw:drawPolygon( -- 300
					circleVerts(s.x, s.y, rPx, options.ringSegments), -- 300
					noFill, -- 300
					options.ringWidth, -- 300
					ringColor -- 300
				) -- 300
			end -- 300
			::__continue32:: -- 300
		end -- 300
		drawPolyline(trail, trailColor, options.trailWidth) -- 304
		drawPolyline(pred, predictColor, options.predictWidth) -- 305
		do -- 305
			local i = 0 -- 308
			while i < #bodies do -- 308
				local b = bodies[i + 1] -- 309
				local s = ____exports.planeToScreen( -- 310
					bodyPositionAt(b, tWorld), -- 310
					map -- 310
				) -- 310
				local r = b.gm >= options.sunGmMin and options.sunPinRadius or options.pinRadius -- 311
				local col = orbitColor -- 312
				if i < #visuals then -- 312
					local v = visuals[i + 1] -- 314
					col = Color( -- 315
						math.floor(v.r * 255), -- 315
						math.floor(v.g * 255), -- 315
						math.floor(v.b * 255), -- 315
						255 -- 315
					) -- 315
				end -- 315
				pinDraw:drawDot( -- 317
					Vec2(s.x, s.y), -- 317
					r, -- 317
					col -- 317
				) -- 317
				i = i + 1 -- 308
			end -- 308
		end -- 308
		local ps = ____exports.planeToScreen(probe, map) -- 321
		pinDraw:drawDot( -- 322
			Vec2(ps.x, ps.y), -- 322
			options.probePinRadius, -- 322
			probeColor -- 322
		) -- 322
		pinDraw:drawPolygon( -- 323
			circleVerts(ps.x, ps.y, options.probePinRadius + 5, 24), -- 323
			noFill, -- 323
			1.5, -- 323
			probeColor -- 323
		) -- 323
		local vlen = math.sqrt(probeVel.x * probeVel.x + probeVel.y * probeVel.y) -- 324
		if vlen > 0.000001 then -- 324
			local dx = probeVel.x / vlen -- 326
			local dy = probeVel.y / vlen -- 327
			pinDraw:drawSegment( -- 328
				Vec2(ps.x, ps.y), -- 329
				Vec2(ps.x + dx * options.probeTickLen, ps.y - dy * options.probeTickLen), -- 330
				2, -- 331
				probeColor -- 332
			) -- 332
		end -- 332
		dirty = false -- 335
	end -- 281
	return { -- 338
		setVisible = function(self, on) -- 339
			isVisible = on -- 340
			root.visible = on -- 341
			if not on then -- 341
				clearAll() -- 344
				dirty = false -- 345
			else -- 345
				dirty = true -- 347
			end -- 347
		end, -- 339
		visible = function(self) -- 350
			return isVisible -- 351
		end, -- 350
		fitTo = function(self, radius) -- 353
			map = ____exports.computePlanMapping(viewW, viewH, radius, options.marginFrac) -- 354
			dirty = true -- 355
		end, -- 353
		syncBodies = function(self, bs, vs, t) -- 357
			bodies = bs -- 358
			visuals = vs -- 359
			tWorld = t -- 360
			dirty = true -- 361
		end, -- 357
		syncProbe = function(self, p, v) -- 363
			probe = p -- 364
			probeVel = v -- 365
			dirty = true -- 366
		end, -- 363
		setPrediction = function(self, points) -- 368
			pred = points -- 369
			dirty = true -- 370
		end, -- 368
		clearPrediction = function(self) -- 372
			pred = {} -- 373
			dirty = true -- 374
		end, -- 372
		setTrail = function(self, points) -- 376
			trail = points -- 377
			dirty = true -- 378
		end, -- 376
		clearTrail = function(self) -- 380
			trail = {} -- 381
			dirty = true -- 382
		end, -- 380
		setGoalRings = function(self, rs) -- 384
			rings = rs -- 385
			dirty = true -- 386
		end, -- 384
		clearGoalRings = function(self) -- 388
			rings = {} -- 389
			dirty = true -- 390
		end, -- 388
		flush = function(self) -- 392
			if not isVisible then -- 392
				return -- 394
			end -- 394
			if not dirty then -- 394
				return -- 395
			end -- 395
			redraw() -- 396
		end, -- 392
		clear = function(self) -- 398
			clearAll() -- 399
			dirty = true -- 400
		end, -- 398
		probeScreen = function(self) -- 402
			return ____exports.planeToScreen(probe, map) -- 403
		end, -- 402
		mapping = function(self) -- 405
			return map -- 406
		end, -- 405
		root = root -- 408
	} -- 408
end -- 213
return ____exports -- 213
-- [ts]: Trajectory.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__ArraySlice = ____lualib.__TS__ArraySlice -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 23
local BlendFunc = ____Dora.BlendFunc -- 23
local Color = ____Dora.Color -- 23
local DrawNode = ____Dora.DrawNode -- 23
local Node = ____Dora.Node -- 23
local Vec2 = ____Dora.Vec2 -- 23
local View = ____Dora.View -- 23
local ____Projection = require("game.Projection") -- 24
local projectPrepared = ____Projection.projectPrepared -- 24
local ____Config = require("game.Config") -- 26
local PlaneToWorldX = ____Config.PlaneToWorldX -- 26
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 26
--- 把平面采样点批量投影成**绘制层坐标**。
-- 
-- @param originX 绘制层坐标原点相对"投影输出（中心原点）"的 x 偏移
-- @param originY 同上，y 偏移
-- 
-- 为什么必须显式传：投影输出是中心原点偏移，而**绘制层自己的空间不一定是中心原点**
-- （取决于这个节点挂在谁下面）。把空间当成隐式全局（例如直接读 View.size）会让
-- 调用方与测试都无法表达"这一层到底是什么空间"，S2.2 的坐标错位正是这么来的。
function ____exports.projectPolyline(points, y, basis, originX, originY) -- 38
	local out = {} -- 39
	for ____, p in ipairs(points) do -- 40
		do -- 40
			local world = {x = p.x * PlaneToWorldX, y = y, z = p.y * PlaneToWorldZ} -- 41
			local proj = projectPrepared(world, basis) -- 46
			if proj == nil then -- 46
				goto __continue3 -- 47
			end -- 47
			local x = proj.x + originX -- 48
			local yy = proj.y + originY -- 49
			local limit = math.max(View.size.width, View.size.height) * 5 -- 53
			out[#out + 1] = Vec2(x > limit and limit or (x < -limit and -limit or x), yy > limit and limit or (yy < -limit and -limit or yy)) -- 54
		end -- 54
		::__continue3:: -- 54
	end -- 54
	return out -- 59
end -- 38
function ____exports.defaultOptions() -- 176
	return { -- 177
		y = 0.02, -- 178
		layerOriginX = View.size.width / 2, -- 180
		layerOriginY = View.size.height / 2, -- 181
		maxPoints = 240, -- 182
		predictRadius = 2, -- 183
		dashOn = 12, -- 185
		dashOff = 9, -- 186
		predictFadeMin = 0.1, -- 187
		glowRadiusFactor = 1.9, -- 188
		glowAlpha = 0.13, -- 189
		tailPoints = 280, -- 190
		trailHeadRadius = 3.4, -- 191
		trailHeadAlpha = 0.85, -- 192
		predictR = 120, -- 193
		predictG = 200, -- 194
		predictB = 255, -- 195
		ringR = 150, -- 197
		ringG = 235, -- 198
		ringB = 220, -- 199
		ringRadius = 1.6, -- 200
		ringGlowAlpha = 0.2, -- 201
		ringSegments = 56, -- 202
		orbitRingR = 138, -- 205
		orbitRingG = 176, -- 206
		orbitRingB = 205, -- 207
		orbitRingRadius = 1.5, -- 208
		orbitRingAlpha = 0.5, -- 209
		orbitRingFarAlpha = 0.16, -- 210
		orbitRingSegments = 72, -- 211
		trailR = 255, -- 212
		trailG = 236, -- 213
		trailB = 170 -- 214
	} -- 214
end -- 176
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 219
	if maxPoints <= 0 or #points <= maxPoints then -- 219
		return points -- 220
	end -- 220
	local out = {} -- 221
	local step = (#points - 1) / (maxPoints - 1) -- 222
	do -- 222
		local i = 0 -- 223
		while i < maxPoints do -- 223
			local idx = math.floor(i * step) -- 224
			local safe = idx < #points and idx or #points - 1 -- 225
			out[#out + 1] = points[safe + 1] -- 226
			i = i + 1 -- 223
		end -- 223
	end -- 223
	out[maxPoints] = points[#points] -- 229
	return out -- 230
end -- 219
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 237
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 238
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 239
end -- 237
local function segColor(rgb, alpha) -- 244
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 247
	return Color( -- 248
		math.floor(rgb.r * a + 0.5), -- 248
		math.floor(rgb.g * a + 0.5), -- 248
		math.floor(rgb.b * a + 0.5), -- 248
		255 -- 248
	) -- 248
end -- 244
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 259
	local maxSeg = 800 -- 274
	if clearFirst ~= false then -- 274
		draw:clear() -- 275
	end -- 275
	local n = #verts -- 276
	if n < 2 then -- 276
		return -- 277
	end -- 277
	local segLen = {} -- 280
	local total = 0 -- 281
	do -- 281
		local i = 1 -- 282
		while i < n do -- 282
			local dx = verts[i + 1].x - verts[i].x -- 283
			local dy = verts[i + 1].y - verts[i].y -- 284
			local l = math.sqrt(dx * dx + dy * dy) -- 285
			segLen[#segLen + 1] = l -- 286
			total = total + l -- 287
			i = i + 1 -- 282
		end -- 282
	end -- 282
	if total < 0.001 then -- 282
		return -- 289
	end -- 289
	local cycle = dashOn + dashOff -- 291
	local glowRadius = coreRadius * glowRadiusFactor -- 292
	local pen = 0 -- 293
	do -- 293
		local i = 1 -- 294
		while i < n do -- 294
			do -- 294
				local ax = verts[i].x -- 295
				local ay = verts[i].y -- 295
				local bx = verts[i + 1].x -- 296
				local by = verts[i + 1].y -- 296
				local len = segLen[i] -- 297
				if len < 0.001 or len > maxSeg then -- 297
					goto __continue20 -- 299
				end -- 299
				local s = 0 -- 300
				while s < len - 0.001 do -- 300
					local c = pen % cycle -- 302
					local run = math.min(cycle - c, len - s) -- 303
					if c < dashOn then -- 303
						local t0 = s / len -- 305
						local t1 = (s + run) / len -- 306
						local x0 = ax + (bx - ax) * t0 -- 307
						local y0 = ay + (by - ay) * t0 -- 308
						local x1 = ax + (bx - ax) * t1 -- 309
						local y1 = ay + (by - ay) * t1 -- 310
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 311
						local p0 = Vec2(x0, y0) -- 312
						local p1 = Vec2(x1, y1) -- 313
						draw:drawSegment( -- 314
							p0, -- 314
							p1, -- 314
							glowRadius, -- 314
							segColor(rgb, glowAlpha * al) -- 314
						) -- 314
						draw:drawSegment( -- 315
							p0, -- 315
							p1, -- 315
							coreRadius, -- 315
							segColor(rgb, al) -- 315
						) -- 315
					end -- 315
					pen = pen + run -- 317
					s = s + run -- 318
				end -- 318
			end -- 318
			::__continue20:: -- 318
			i = i + 1 -- 294
		end -- 294
	end -- 294
end -- 259
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 324
	draw:clear() -- 333
	local n = #verts -- 334
	if n < 2 then -- 334
		return -- 335
	end -- 335
	local tailRadius = headRadius * 0.15 -- 336
	local glowRadius = headRadius * glowRadiusFactor -- 337
	local maxSeg = 800 -- 338
	do -- 338
		local i = 1 -- 339
		while i < n do -- 339
			do -- 339
				local u = i / (n - 1) -- 341
				local up = u ^ 1.2 -- 342
				local r = tailRadius + (headRadius - tailRadius) * up -- 343
				local al = headAlpha * u ^ 1.6 -- 344
				local dxv = verts[i + 1].x - verts[i].x -- 345
				local dyv = verts[i + 1].y - verts[i].y -- 346
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 346
					goto __continue27 -- 347
				end -- 347
				draw:drawSegment( -- 348
					verts[i], -- 348
					verts[i + 1], -- 348
					r * glowRadiusFactor, -- 348
					segColor(rgb, glowAlpha * al) -- 348
				) -- 348
				draw:drawSegment( -- 349
					verts[i], -- 349
					verts[i + 1], -- 349
					r, -- 349
					segColor(rgb, al) -- 349
				) -- 349
			end -- 349
			::__continue27:: -- 349
			i = i + 1 -- 339
		end -- 339
	end -- 339
	draw:drawDot( -- 352
		verts[n], -- 352
		headRadius * 1.5, -- 352
		segColor(rgb, headAlpha) -- 352
	) -- 352
end -- 324
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 361
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 365
	local root = Node() -- 368
	local orbitDraw = DrawNode() -- 371
	orbitDraw.blendFunc = BlendFunc("One", "One") -- 372
	root:addChild(orbitDraw) -- 373
	local ringDraw = DrawNode() -- 375
	local burnDraw = DrawNode() -- 376
	root:addChild(burnDraw) -- 377
	ringDraw.blendFunc = BlendFunc("One", "One") -- 378
	root:addChild(ringDraw) -- 379
	local trailDraw = DrawNode() -- 381
	trailDraw.blendFunc = BlendFunc("One", "One") -- 383
	root:addChild(trailDraw) -- 384
	local predictDraw = DrawNode() -- 386
	predictDraw.blendFunc = BlendFunc("One", "One") -- 387
	root:addChild(predictDraw) -- 388
	parent:addChild(root) -- 390
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 392
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 393
	return { -- 395
		setPrediction = function(self, points, basis) -- 396
			local verts = ____exports.projectPolyline( -- 397
				____exports.decimate(points, options.maxPoints), -- 397
				options.y, -- 397
				basis, -- 397
				options.layerOriginX, -- 397
				options.layerOriginY -- 397
			) -- 397
			____exports.drawDashedPolyline( -- 398
				predictDraw, -- 399
				verts, -- 400
				options.predictRadius, -- 401
				predictRGB, -- 402
				options.predictFadeMin, -- 403
				options.glowRadiusFactor, -- 404
				options.glowAlpha, -- 405
				options.dashOn, -- 406
				options.dashOff -- 407
			) -- 407
		end, -- 396
		clearPrediction = function(self) -- 410
			predictDraw:clear() -- 411
		end, -- 410
		setTrail = function(self, points, basis) -- 413
			if #points < 2 then -- 413
				trailDraw:clear() -- 417
				return -- 418
			end -- 418
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 420
			local verts = ____exports.projectPolyline( -- 423
				____exports.decimate(tail, options.maxPoints), -- 423
				options.y, -- 423
				basis, -- 423
				options.layerOriginX, -- 423
				options.layerOriginY -- 423
			) -- 423
			drawComet( -- 424
				trailDraw, -- 425
				verts, -- 426
				options.trailHeadRadius, -- 427
				trailRGB, -- 428
				options.trailHeadAlpha, -- 429
				options.glowRadiusFactor, -- 430
				options.glowAlpha -- 431
			) -- 431
		end, -- 413
		clearTrail = function(self) -- 434
			trailDraw:clear() -- 435
			burnDraw:clear() -- 436
		end, -- 434
		setGoalRings = function(self, rings, basis) -- 438
			ringDraw:clear() -- 439
			for ____, ring in ipairs(rings) do -- 440
				do -- 440
					if ring.point == true then -- 440
						local pts = ____exports.projectPolyline( -- 442
							{ring.center}, -- 442
							options.y, -- 442
							basis, -- 442
							options.layerOriginX, -- 442
							options.layerOriginY -- 442
						) -- 442
						if #pts > 0 then -- 442
							ringDraw:drawDot( -- 444
								pts[1], -- 444
								10 * (ring.pulse ~= nil and ring.pulse or 1), -- 444
								Color(70, 220, 190, 45) -- 444
							) -- 444
							ringDraw:drawDot( -- 445
								pts[1], -- 445
								3.5, -- 445
								Color(170, 255, 230, 255) -- 445
							) -- 445
						end -- 445
					end -- 445
					if ring.showRange == false then -- 445
						goto __continue36 -- 448
					end -- 448
					if ring.radius <= 0 then -- 448
						goto __continue36 -- 449
					end -- 449
					local n = options.ringSegments -- 451
					local circle = {} -- 452
					do -- 452
						local i = 0 -- 453
						while i <= n do -- 453
							local a = i / n * 2 * math.pi -- 454
							circle[#circle + 1] = { -- 455
								x = ring.center.x + ring.radius * math.cos(a), -- 455
								y = ring.center.y + ring.radius * math.sin(a) -- 455
							} -- 455
							i = i + 1 -- 453
						end -- 453
					end -- 453
					local verts = ____exports.projectPolyline( -- 457
						circle, -- 457
						options.y, -- 457
						basis, -- 457
						options.layerOriginX, -- 457
						options.layerOriginY -- 457
					) -- 457
					if #verts < 3 then -- 457
						goto __continue36 -- 458
					end -- 458
					local rgb = ring.passed and ({r = options.ringR * 0.35, g = options.ringG * 0.35, b = options.ringB * 0.35}) or ({r = options.ringR, g = options.ringG, b = options.ringB}) -- 459
					____exports.drawDashedPolyline( -- 462
						ringDraw, -- 462
						verts, -- 462
						options.ringRadius, -- 462
						rgb, -- 462
						1, -- 462
						options.glowRadiusFactor, -- 462
						options.ringGlowAlpha, -- 462
						options.dashOn * 1.5, -- 462
						options.dashOff, -- 462
						false -- 462
					) -- 462
				end -- 462
				::__continue36:: -- 462
			end -- 462
		end, -- 438
		clearGoalRings = function(self) -- 465
			ringDraw:clear() -- 466
		end, -- 465
		setBurn = function(____, p, direction, on, basis) -- 468
			burnDraw:clear() -- 469
			if not on then -- 469
				return -- 470
			end -- 470
			local mag = math.sqrt(direction.x * direction.x + direction.y * direction.y) -- 471
			if mag <= 0 then -- 471
				return -- 472
			end -- 472
			local length = options.burnLength ~= nil and options.burnLength or 32 -- 473
			local pts = ____exports.projectPolyline( -- 474
				{p, {x = p.x - direction.x * length / mag, y = p.y - direction.y * length / mag}}, -- 474
				options.y, -- 474
				basis, -- 474
				options.layerOriginX, -- 474
				options.layerOriginY -- 474
			) -- 474
			if #pts == 2 then -- 474
				burnDraw:drawSegment( -- 476
					pts[1], -- 476
					pts[2], -- 476
					5, -- 476
					Color(255, 135, 35, 140) -- 476
				) -- 476
				burnDraw:drawSegment( -- 477
					pts[1], -- 477
					pts[2], -- 477
					2, -- 477
					Color(255, 235, 145, 255) -- 477
				) -- 477
			end -- 477
		end, -- 468
		setOrbitRing = function(self, center, radius, basis) -- 480
			orbitDraw:clear() -- 481
			if radius <= 0 then -- 481
				return -- 482
			end -- 482
			local n = options.orbitRingSegments -- 483
			local circle = {} -- 484
			do -- 484
				local i = 0 -- 485
				while i <= n do -- 485
					local a = i / n * 2 * math.pi -- 486
					circle[#circle + 1] = { -- 487
						x = center.x + radius * math.cos(a), -- 487
						y = center.y + radius * math.sin(a) -- 487
					} -- 487
					i = i + 1 -- 485
				end -- 485
			end -- 485
			local verts = ____exports.projectPolyline( -- 489
				circle, -- 489
				options.y, -- 489
				basis, -- 489
				options.layerOriginX, -- 489
				options.layerOriginY -- 489
			) -- 489
			if #verts < 2 then -- 489
				return -- 490
			end -- 490
			local vx = basis.forward.x -- 492
			local vy = basis.forward.z -- 493
			local vl = math.sqrt(vx * vx + vy * vy) -- 494
			if vl > 1e-9 then -- 494
				vx = vx / vl -- 496
				vy = vy / vl -- 497
			end -- 497
			local rgb = {r = options.orbitRingR, g = options.orbitRingG, b = options.orbitRingB} -- 499
			local nearCol = segColor(rgb, options.orbitRingAlpha) -- 500
			local farCol = segColor(rgb, options.orbitRingFarAlpha) -- 501
			do -- 501
				local i = 1 -- 502
				while i < #verts and i < #circle do -- 502
					local far = (circle[i + 1].x - center.x) * vx + (circle[i + 1].y - center.y) * vy > 0 -- 503
					orbitDraw:drawSegment(verts[i], verts[i + 1], options.orbitRingRadius, far and farCol or nearCol) -- 504
					i = i + 1 -- 502
				end -- 502
			end -- 502
		end, -- 480
		clearOrbitRing = function(self) -- 507
			orbitDraw:clear() -- 508
		end, -- 507
		root = root -- 510
	} -- 510
end -- 361
return ____exports -- 361
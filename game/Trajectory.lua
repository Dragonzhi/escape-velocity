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
function ____exports.defaultOptions() -- 179
	return { -- 180
		y = 0.02, -- 181
		layerOriginX = View.size.width / 2, -- 183
		layerOriginY = View.size.height / 2, -- 184
		maxPoints = 240, -- 185
		predictRadius = 2, -- 186
		dashOn = 12, -- 188
		dashOff = 9, -- 189
		predictFadeMin = 0.1, -- 190
		glowRadiusFactor = 1.9, -- 191
		glowAlpha = 0.13, -- 192
		tailPoints = 280, -- 193
		trailHeadRadius = 3.4, -- 194
		trailHeadAlpha = 0.85, -- 195
		predictR = 120, -- 196
		predictG = 200, -- 197
		predictB = 255, -- 198
		ringR = 150, -- 200
		ringG = 235, -- 201
		ringB = 220, -- 202
		ringRadius = 1.6, -- 203
		ringGlowAlpha = 0.2, -- 204
		ringSegments = 56, -- 205
		orbitRingR = 138, -- 208
		orbitRingG = 176, -- 209
		orbitRingB = 205, -- 210
		orbitRingRadius = 1.5, -- 211
		orbitRingAlpha = 0.5, -- 212
		orbitRingFarAlpha = 0.16, -- 213
		orbitRingSegments = 72, -- 214
		trailR = 255, -- 215
		trailG = 236, -- 216
		trailB = 170 -- 217
	} -- 217
end -- 179
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 222
	if maxPoints <= 0 or #points <= maxPoints then -- 222
		return points -- 223
	end -- 223
	local out = {} -- 224
	local step = (#points - 1) / (maxPoints - 1) -- 225
	do -- 225
		local i = 0 -- 226
		while i < maxPoints do -- 226
			local idx = math.floor(i * step) -- 227
			local safe = idx < #points and idx or #points - 1 -- 228
			out[#out + 1] = points[safe + 1] -- 229
			i = i + 1 -- 226
		end -- 226
	end -- 226
	out[maxPoints] = points[#points] -- 232
	return out -- 233
end -- 222
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 240
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 241
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 242
end -- 240
local function segColor(rgb, alpha) -- 247
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 250
	return Color( -- 251
		math.floor(rgb.r * a + 0.5), -- 251
		math.floor(rgb.g * a + 0.5), -- 251
		math.floor(rgb.b * a + 0.5), -- 251
		255 -- 251
	) -- 251
end -- 247
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 262
	local maxSeg = 800 -- 277
	if clearFirst ~= false then -- 277
		draw:clear() -- 278
	end -- 278
	local n = #verts -- 279
	if n < 2 then -- 279
		return -- 280
	end -- 280
	local segLen = {} -- 283
	local total = 0 -- 284
	do -- 284
		local i = 1 -- 285
		while i < n do -- 285
			local dx = verts[i + 1].x - verts[i].x -- 286
			local dy = verts[i + 1].y - verts[i].y -- 287
			local l = math.sqrt(dx * dx + dy * dy) -- 288
			segLen[#segLen + 1] = l -- 289
			total = total + l -- 290
			i = i + 1 -- 285
		end -- 285
	end -- 285
	if total < 0.001 then -- 285
		return -- 292
	end -- 292
	local cycle = dashOn + dashOff -- 294
	local glowRadius = coreRadius * glowRadiusFactor -- 295
	local pen = 0 -- 296
	do -- 296
		local i = 1 -- 297
		while i < n do -- 297
			do -- 297
				local ax = verts[i].x -- 298
				local ay = verts[i].y -- 298
				local bx = verts[i + 1].x -- 299
				local by = verts[i + 1].y -- 299
				local len = segLen[i] -- 300
				if len < 0.001 or len > maxSeg then -- 300
					goto __continue20 -- 302
				end -- 302
				local s = 0 -- 303
				while s < len - 0.001 do -- 303
					local c = pen % cycle -- 305
					local run = math.min(cycle - c, len - s) -- 306
					if c < dashOn then -- 306
						local t0 = s / len -- 308
						local t1 = (s + run) / len -- 309
						local x0 = ax + (bx - ax) * t0 -- 310
						local y0 = ay + (by - ay) * t0 -- 311
						local x1 = ax + (bx - ax) * t1 -- 312
						local y1 = ay + (by - ay) * t1 -- 313
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 314
						local p0 = Vec2(x0, y0) -- 315
						local p1 = Vec2(x1, y1) -- 316
						draw:drawSegment( -- 317
							p0, -- 317
							p1, -- 317
							glowRadius, -- 317
							segColor(rgb, glowAlpha * al) -- 317
						) -- 317
						draw:drawSegment( -- 318
							p0, -- 318
							p1, -- 318
							coreRadius, -- 318
							segColor(rgb, al) -- 318
						) -- 318
					end -- 318
					pen = pen + run -- 320
					s = s + run -- 321
				end -- 321
			end -- 321
			::__continue20:: -- 321
			i = i + 1 -- 297
		end -- 297
	end -- 297
end -- 262
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 327
	draw:clear() -- 336
	local n = #verts -- 337
	if n < 2 then -- 337
		return -- 338
	end -- 338
	local tailRadius = headRadius * 0.15 -- 339
	local glowRadius = headRadius * glowRadiusFactor -- 340
	local maxSeg = 800 -- 341
	do -- 341
		local i = 1 -- 342
		while i < n do -- 342
			do -- 342
				local u = i / (n - 1) -- 344
				local up = u ^ 1.2 -- 345
				local r = tailRadius + (headRadius - tailRadius) * up -- 346
				local al = headAlpha * u ^ 1.6 -- 347
				local dxv = verts[i + 1].x - verts[i].x -- 348
				local dyv = verts[i + 1].y - verts[i].y -- 349
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 349
					goto __continue27 -- 350
				end -- 350
				draw:drawSegment( -- 351
					verts[i], -- 351
					verts[i + 1], -- 351
					r * glowRadiusFactor, -- 351
					segColor(rgb, glowAlpha * al) -- 351
				) -- 351
				draw:drawSegment( -- 352
					verts[i], -- 352
					verts[i + 1], -- 352
					r, -- 352
					segColor(rgb, al) -- 352
				) -- 352
			end -- 352
			::__continue27:: -- 352
			i = i + 1 -- 342
		end -- 342
	end -- 342
	draw:drawDot( -- 355
		verts[n], -- 355
		headRadius * 1.5, -- 355
		segColor(rgb, headAlpha) -- 355
	) -- 355
end -- 327
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 364
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 368
	local root = Node() -- 371
	local orbitDraw = DrawNode() -- 374
	orbitDraw.blendFunc = BlendFunc("One", "One") -- 375
	root:addChild(orbitDraw) -- 376
	local ringDraw = DrawNode() -- 378
	local burnDraw = DrawNode() -- 379
	root:addChild(burnDraw) -- 380
	ringDraw.blendFunc = BlendFunc("One", "One") -- 381
	root:addChild(ringDraw) -- 382
	local trailDraw = DrawNode() -- 384
	trailDraw.blendFunc = BlendFunc("One", "One") -- 386
	root:addChild(trailDraw) -- 387
	local predictDraw = DrawNode() -- 389
	predictDraw.blendFunc = BlendFunc("One", "One") -- 390
	root:addChild(predictDraw) -- 391
	parent:addChild(root) -- 393
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 395
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 396
	return { -- 398
		setPrediction = function(self, points, basis) -- 399
			local verts = ____exports.projectPolyline( -- 400
				____exports.decimate(points, options.maxPoints), -- 400
				options.y, -- 400
				basis, -- 400
				options.layerOriginX, -- 400
				options.layerOriginY -- 400
			) -- 400
			____exports.drawDashedPolyline( -- 401
				predictDraw, -- 402
				verts, -- 403
				options.predictRadius, -- 404
				predictRGB, -- 405
				options.predictFadeMin, -- 406
				options.glowRadiusFactor, -- 407
				options.glowAlpha, -- 408
				options.dashOn, -- 409
				options.dashOff -- 410
			) -- 410
		end, -- 399
		clearPrediction = function(self) -- 413
			predictDraw:clear() -- 414
		end, -- 413
		setTrail = function(self, points, basis) -- 416
			if #points < 2 then -- 416
				trailDraw:clear() -- 420
				return -- 421
			end -- 421
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 423
			local verts = ____exports.projectPolyline( -- 426
				____exports.decimate(tail, options.maxPoints), -- 426
				options.y, -- 426
				basis, -- 426
				options.layerOriginX, -- 426
				options.layerOriginY -- 426
			) -- 426
			drawComet( -- 427
				trailDraw, -- 428
				verts, -- 429
				options.trailHeadRadius, -- 430
				trailRGB, -- 431
				options.trailHeadAlpha, -- 432
				options.glowRadiusFactor, -- 433
				options.glowAlpha -- 434
			) -- 434
		end, -- 416
		clearTrail = function(self) -- 437
			trailDraw:clear() -- 438
			burnDraw:clear() -- 439
		end, -- 437
		setGoalRings = function(self, rings, basis) -- 441
			ringDraw:clear() -- 442
			for ____, ring in ipairs(rings) do -- 443
				do -- 443
					if ring.point == true then -- 443
						local pts = ____exports.projectPolyline( -- 445
							{ring.center}, -- 445
							options.y, -- 445
							basis, -- 445
							options.layerOriginX, -- 445
							options.layerOriginY -- 445
						) -- 445
						if #pts > 0 then -- 445
							local alpha = ring.pointAlpha ~= nil and ring.pointAlpha or 1 -- 447
							local scale = ring.pulse ~= nil and ring.pulse or 1 -- 448
							ringDraw:drawDot( -- 449
								pts[1], -- 449
								10 * scale, -- 449
								Color( -- 449
									70, -- 449
									245, -- 449
									105, -- 449
									math.floor(55 * alpha * math.min(2, scale)) -- 449
								) -- 449
							) -- 449
							ringDraw:drawDot( -- 450
								pts[1], -- 450
								3.5 * scale, -- 450
								Color( -- 450
									200, -- 450
									255, -- 450
									205, -- 450
									math.floor(255 * alpha) -- 450
								) -- 450
							) -- 450
							if ring.burstRadius ~= nil and ring.burstRadius > 0 then -- 450
								local circle = {} -- 452
								do -- 452
									local i = 0 -- 453
									while i < 32 do -- 453
										local a = i * math.pi / 16 -- 453
										circle[#circle + 1] = Vec2( -- 453
											pts[1].x + ring.burstRadius * math.cos(a), -- 453
											pts[1].y + ring.burstRadius * math.sin(a) -- 453
										) -- 453
										i = i + 1 -- 453
									end -- 453
								end -- 453
								ringDraw:drawPolygon( -- 454
									circle, -- 454
									Color(0, 0, 0, 0), -- 454
									1.5, -- 454
									Color( -- 454
										120, -- 454
										255, -- 454
										145, -- 454
										math.floor(180 * alpha) -- 454
									) -- 454
								) -- 454
							end -- 454
						end -- 454
					end -- 454
					if ring.showRange == false then -- 454
						goto __continue36 -- 458
					end -- 458
					if ring.radius <= 0 then -- 458
						goto __continue36 -- 459
					end -- 459
					local n = options.ringSegments -- 461
					local circle = {} -- 462
					do -- 462
						local i = 0 -- 463
						while i <= n do -- 463
							local a = i / n * 2 * math.pi -- 464
							circle[#circle + 1] = { -- 465
								x = ring.center.x + ring.radius * math.cos(a), -- 465
								y = ring.center.y + ring.radius * math.sin(a) -- 465
							} -- 465
							i = i + 1 -- 463
						end -- 463
					end -- 463
					local verts = ____exports.projectPolyline( -- 467
						circle, -- 467
						options.y, -- 467
						basis, -- 467
						options.layerOriginX, -- 467
						options.layerOriginY -- 467
					) -- 467
					if #verts < 3 then -- 467
						goto __continue36 -- 468
					end -- 468
					local opacity = ring.pointAlpha ~= nil and ring.pointAlpha or 1 -- 469
					if ring.bandOuterRadius ~= nil and ring.bandOuterRadius > ring.radius then -- 469
						local outer = {} -- 471
						do -- 471
							local i = 0 -- 472
							while i <= n do -- 472
								local a = i / n * 2 * math.pi -- 472
								outer[#outer + 1] = { -- 472
									x = ring.center.x + ring.bandOuterRadius * math.cos(a), -- 472
									y = ring.center.y + ring.bandOuterRadius * math.sin(a) -- 472
								} -- 472
								i = i + 1 -- 472
							end -- 472
						end -- 472
						local ov = ____exports.projectPolyline( -- 473
							outer, -- 473
							options.y, -- 473
							basis, -- 473
							options.layerOriginX, -- 473
							options.layerOriginY -- 473
						) -- 473
						local fill = Color( -- 474
							math.floor(80 * opacity), -- 474
							math.floor(255 * opacity), -- 474
							math.floor(130 * opacity), -- 474
							math.floor(27 * opacity) -- 474
						) -- 474
						do -- 474
							local i = 1 -- 475
							while i < #verts and i < #ov do -- 475
								ringDraw:drawPolygon( -- 475
									{verts[i], ov[i], ov[i + 1], verts[i + 1]}, -- 475
									fill, -- 475
									0, -- 475
									Color(80, 255, 130, 0) -- 475
								) -- 475
								i = i + 1 -- 475
							end -- 475
						end -- 475
					end -- 475
					local base = ring.point == true and ({r = 90, g = 255, b = 125}) or ({r = options.ringR, g = options.ringG, b = options.ringB}) -- 477
					local dim = ring.passed and 0.35 or 1 -- 478
					local rgb = {r = base.r * dim * opacity, g = base.g * dim * opacity, b = base.b * dim * opacity} -- 479
					____exports.drawDashedPolyline( -- 480
						ringDraw, -- 480
						verts, -- 480
						options.ringRadius, -- 480
						rgb, -- 480
						1, -- 480
						options.glowRadiusFactor, -- 480
						options.ringGlowAlpha, -- 480
						options.dashOn * 1.5, -- 480
						options.dashOff, -- 480
						false -- 480
					) -- 480
				end -- 480
				::__continue36:: -- 480
			end -- 480
		end, -- 441
		clearGoalRings = function(self) -- 483
			ringDraw:clear() -- 484
		end, -- 483
		setBurn = function(____, p, direction, on, basis) -- 486
			burnDraw:clear() -- 487
			if not on then -- 487
				return -- 488
			end -- 488
			local mag = math.sqrt(direction.x * direction.x + direction.y * direction.y) -- 489
			if mag <= 0 then -- 489
				return -- 490
			end -- 490
			local length = options.burnLength ~= nil and options.burnLength or 32 -- 491
			local pts = ____exports.projectPolyline( -- 492
				{p, {x = p.x - direction.x * length / mag, y = p.y - direction.y * length / mag}}, -- 492
				options.y, -- 492
				basis, -- 492
				options.layerOriginX, -- 492
				options.layerOriginY -- 492
			) -- 492
			if #pts == 2 then -- 492
				burnDraw:drawSegment( -- 494
					pts[1], -- 494
					pts[2], -- 494
					5, -- 494
					Color(255, 135, 35, 140) -- 494
				) -- 494
				burnDraw:drawSegment( -- 495
					pts[1], -- 495
					pts[2], -- 495
					2, -- 495
					Color(255, 235, 145, 255) -- 495
				) -- 495
			end -- 495
		end, -- 486
		setOrbitRing = function(self, center, radius, basis) -- 498
			orbitDraw:clear() -- 499
			if radius <= 0 then -- 499
				return -- 500
			end -- 500
			local n = options.orbitRingSegments -- 501
			local circle = {} -- 502
			do -- 502
				local i = 0 -- 503
				while i <= n do -- 503
					local a = i / n * 2 * math.pi -- 504
					circle[#circle + 1] = { -- 505
						x = center.x + radius * math.cos(a), -- 505
						y = center.y + radius * math.sin(a) -- 505
					} -- 505
					i = i + 1 -- 503
				end -- 503
			end -- 503
			local verts = ____exports.projectPolyline( -- 507
				circle, -- 507
				options.y, -- 507
				basis, -- 507
				options.layerOriginX, -- 507
				options.layerOriginY -- 507
			) -- 507
			if #verts < 2 then -- 507
				return -- 508
			end -- 508
			local vx = basis.forward.x -- 510
			local vy = basis.forward.z -- 511
			local vl = math.sqrt(vx * vx + vy * vy) -- 512
			if vl > 1e-9 then -- 512
				vx = vx / vl -- 514
				vy = vy / vl -- 515
			end -- 515
			local rgb = {r = options.orbitRingR, g = options.orbitRingG, b = options.orbitRingB} -- 517
			local nearCol = segColor(rgb, options.orbitRingAlpha) -- 518
			local farCol = segColor(rgb, options.orbitRingFarAlpha) -- 519
			do -- 519
				local i = 1 -- 520
				while i < #verts and i < #circle do -- 520
					local far = (circle[i + 1].x - center.x) * vx + (circle[i + 1].y - center.y) * vy > 0 -- 521
					orbitDraw:drawSegment(verts[i], verts[i + 1], options.orbitRingRadius, far and farCol or nearCol) -- 522
					i = i + 1 -- 520
				end -- 520
			end -- 520
		end, -- 498
		clearOrbitRing = function(self) -- 525
			orbitDraw:clear() -- 526
		end, -- 525
		root = root -- 528
	} -- 528
end -- 364
return ____exports -- 364
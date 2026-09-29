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
function ____exports.defaultOptions() -- 178
	return { -- 179
		y = 0.02, -- 180
		layerOriginX = View.size.width / 2, -- 182
		layerOriginY = View.size.height / 2, -- 183
		maxPoints = 240, -- 184
		predictRadius = 2, -- 185
		dashOn = 12, -- 187
		dashOff = 9, -- 188
		predictFadeMin = 0.1, -- 189
		glowRadiusFactor = 1.9, -- 190
		glowAlpha = 0.13, -- 191
		tailPoints = 280, -- 192
		trailHeadRadius = 3.4, -- 193
		trailHeadAlpha = 0.85, -- 194
		predictR = 120, -- 195
		predictG = 200, -- 196
		predictB = 255, -- 197
		ringR = 150, -- 199
		ringG = 235, -- 200
		ringB = 220, -- 201
		ringRadius = 1.6, -- 202
		ringGlowAlpha = 0.2, -- 203
		ringSegments = 56, -- 204
		orbitRingR = 138, -- 207
		orbitRingG = 176, -- 208
		orbitRingB = 205, -- 209
		orbitRingRadius = 1.5, -- 210
		orbitRingAlpha = 0.5, -- 211
		orbitRingFarAlpha = 0.16, -- 212
		orbitRingSegments = 72, -- 213
		trailR = 255, -- 214
		trailG = 236, -- 215
		trailB = 170 -- 216
	} -- 216
end -- 178
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 221
	if maxPoints <= 0 or #points <= maxPoints then -- 221
		return points -- 222
	end -- 222
	local out = {} -- 223
	local step = (#points - 1) / (maxPoints - 1) -- 224
	do -- 224
		local i = 0 -- 225
		while i < maxPoints do -- 225
			local idx = math.floor(i * step) -- 226
			local safe = idx < #points and idx or #points - 1 -- 227
			out[#out + 1] = points[safe + 1] -- 228
			i = i + 1 -- 225
		end -- 225
	end -- 225
	out[maxPoints] = points[#points] -- 231
	return out -- 232
end -- 221
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 239
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 240
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 241
end -- 239
local function segColor(rgb, alpha) -- 246
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 249
	return Color( -- 250
		math.floor(rgb.r * a + 0.5), -- 250
		math.floor(rgb.g * a + 0.5), -- 250
		math.floor(rgb.b * a + 0.5), -- 250
		255 -- 250
	) -- 250
end -- 246
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 261
	local maxSeg = 800 -- 276
	if clearFirst ~= false then -- 276
		draw:clear() -- 277
	end -- 277
	local n = #verts -- 278
	if n < 2 then -- 278
		return -- 279
	end -- 279
	local segLen = {} -- 282
	local total = 0 -- 283
	do -- 283
		local i = 1 -- 284
		while i < n do -- 284
			local dx = verts[i + 1].x - verts[i].x -- 285
			local dy = verts[i + 1].y - verts[i].y -- 286
			local l = math.sqrt(dx * dx + dy * dy) -- 287
			segLen[#segLen + 1] = l -- 288
			total = total + l -- 289
			i = i + 1 -- 284
		end -- 284
	end -- 284
	if total < 0.001 then -- 284
		return -- 291
	end -- 291
	local cycle = dashOn + dashOff -- 293
	local glowRadius = coreRadius * glowRadiusFactor -- 294
	local pen = 0 -- 295
	do -- 295
		local i = 1 -- 296
		while i < n do -- 296
			do -- 296
				local ax = verts[i].x -- 297
				local ay = verts[i].y -- 297
				local bx = verts[i + 1].x -- 298
				local by = verts[i + 1].y -- 298
				local len = segLen[i] -- 299
				if len < 0.001 or len > maxSeg then -- 299
					goto __continue20 -- 301
				end -- 301
				local s = 0 -- 302
				while s < len - 0.001 do -- 302
					local c = pen % cycle -- 304
					local run = math.min(cycle - c, len - s) -- 305
					if c < dashOn then -- 305
						local t0 = s / len -- 307
						local t1 = (s + run) / len -- 308
						local x0 = ax + (bx - ax) * t0 -- 309
						local y0 = ay + (by - ay) * t0 -- 310
						local x1 = ax + (bx - ax) * t1 -- 311
						local y1 = ay + (by - ay) * t1 -- 312
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 313
						local p0 = Vec2(x0, y0) -- 314
						local p1 = Vec2(x1, y1) -- 315
						draw:drawSegment( -- 316
							p0, -- 316
							p1, -- 316
							glowRadius, -- 316
							segColor(rgb, glowAlpha * al) -- 316
						) -- 316
						draw:drawSegment( -- 317
							p0, -- 317
							p1, -- 317
							coreRadius, -- 317
							segColor(rgb, al) -- 317
						) -- 317
					end -- 317
					pen = pen + run -- 319
					s = s + run -- 320
				end -- 320
			end -- 320
			::__continue20:: -- 320
			i = i + 1 -- 296
		end -- 296
	end -- 296
end -- 261
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 326
	draw:clear() -- 335
	local n = #verts -- 336
	if n < 2 then -- 336
		return -- 337
	end -- 337
	local tailRadius = headRadius * 0.15 -- 338
	local glowRadius = headRadius * glowRadiusFactor -- 339
	local maxSeg = 800 -- 340
	do -- 340
		local i = 1 -- 341
		while i < n do -- 341
			do -- 341
				local u = i / (n - 1) -- 343
				local up = u ^ 1.2 -- 344
				local r = tailRadius + (headRadius - tailRadius) * up -- 345
				local al = headAlpha * u ^ 1.6 -- 346
				local dxv = verts[i + 1].x - verts[i].x -- 347
				local dyv = verts[i + 1].y - verts[i].y -- 348
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 348
					goto __continue27 -- 349
				end -- 349
				draw:drawSegment( -- 350
					verts[i], -- 350
					verts[i + 1], -- 350
					r * glowRadiusFactor, -- 350
					segColor(rgb, glowAlpha * al) -- 350
				) -- 350
				draw:drawSegment( -- 351
					verts[i], -- 351
					verts[i + 1], -- 351
					r, -- 351
					segColor(rgb, al) -- 351
				) -- 351
			end -- 351
			::__continue27:: -- 351
			i = i + 1 -- 341
		end -- 341
	end -- 341
	draw:drawDot( -- 354
		verts[n], -- 354
		headRadius * 1.5, -- 354
		segColor(rgb, headAlpha) -- 354
	) -- 354
end -- 326
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 363
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 367
	local root = Node() -- 370
	local orbitDraw = DrawNode() -- 373
	orbitDraw.blendFunc = BlendFunc("One", "One") -- 374
	root:addChild(orbitDraw) -- 375
	local ringDraw = DrawNode() -- 377
	local burnDraw = DrawNode() -- 378
	root:addChild(burnDraw) -- 379
	ringDraw.blendFunc = BlendFunc("One", "One") -- 380
	root:addChild(ringDraw) -- 381
	local trailDraw = DrawNode() -- 383
	trailDraw.blendFunc = BlendFunc("One", "One") -- 385
	root:addChild(trailDraw) -- 386
	local predictDraw = DrawNode() -- 388
	predictDraw.blendFunc = BlendFunc("One", "One") -- 389
	root:addChild(predictDraw) -- 390
	parent:addChild(root) -- 392
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 394
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 395
	return { -- 397
		setPrediction = function(self, points, basis) -- 398
			local verts = ____exports.projectPolyline( -- 399
				____exports.decimate(points, options.maxPoints), -- 399
				options.y, -- 399
				basis, -- 399
				options.layerOriginX, -- 399
				options.layerOriginY -- 399
			) -- 399
			____exports.drawDashedPolyline( -- 400
				predictDraw, -- 401
				verts, -- 402
				options.predictRadius, -- 403
				predictRGB, -- 404
				options.predictFadeMin, -- 405
				options.glowRadiusFactor, -- 406
				options.glowAlpha, -- 407
				options.dashOn, -- 408
				options.dashOff -- 409
			) -- 409
		end, -- 398
		clearPrediction = function(self) -- 412
			predictDraw:clear() -- 413
		end, -- 412
		setTrail = function(self, points, basis) -- 415
			if #points < 2 then -- 415
				trailDraw:clear() -- 419
				return -- 420
			end -- 420
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 422
			local verts = ____exports.projectPolyline( -- 425
				____exports.decimate(tail, options.maxPoints), -- 425
				options.y, -- 425
				basis, -- 425
				options.layerOriginX, -- 425
				options.layerOriginY -- 425
			) -- 425
			drawComet( -- 426
				trailDraw, -- 427
				verts, -- 428
				options.trailHeadRadius, -- 429
				trailRGB, -- 430
				options.trailHeadAlpha, -- 431
				options.glowRadiusFactor, -- 432
				options.glowAlpha -- 433
			) -- 433
		end, -- 415
		clearTrail = function(self) -- 436
			trailDraw:clear() -- 437
			burnDraw:clear() -- 438
		end, -- 436
		setGoalRings = function(self, rings, basis) -- 440
			ringDraw:clear() -- 441
			for ____, ring in ipairs(rings) do -- 442
				do -- 442
					if ring.point == true then -- 442
						local pts = ____exports.projectPolyline( -- 444
							{ring.center}, -- 444
							options.y, -- 444
							basis, -- 444
							options.layerOriginX, -- 444
							options.layerOriginY -- 444
						) -- 444
						if #pts > 0 then -- 444
							local alpha = ring.pointAlpha ~= nil and ring.pointAlpha or 1 -- 446
							local scale = ring.pulse ~= nil and ring.pulse or 1 -- 447
							ringDraw:drawDot( -- 448
								pts[1], -- 448
								10 * scale, -- 448
								Color( -- 448
									70, -- 448
									220, -- 448
									190, -- 448
									math.floor(45 * alpha * math.min(2, scale)) -- 448
								) -- 448
							) -- 448
							ringDraw:drawDot( -- 449
								pts[1], -- 449
								3.5 * scale, -- 449
								Color( -- 449
									170, -- 449
									255, -- 449
									230, -- 449
									math.floor(255 * alpha) -- 449
								) -- 449
							) -- 449
							if ring.burstRadius ~= nil and ring.burstRadius > 0 then -- 449
								local circle = {} -- 451
								do -- 451
									local i = 0 -- 452
									while i < 32 do -- 452
										local a = i * math.pi / 16 -- 452
										circle[#circle + 1] = Vec2( -- 452
											pts[1].x + ring.burstRadius * math.cos(a), -- 452
											pts[1].y + ring.burstRadius * math.sin(a) -- 452
										) -- 452
										i = i + 1 -- 452
									end -- 452
								end -- 452
								ringDraw:drawPolygon( -- 453
									circle, -- 453
									Color(0, 0, 0, 0), -- 453
									1.5, -- 453
									Color( -- 453
										140, -- 453
										255, -- 453
										215, -- 453
										math.floor(160 * alpha) -- 453
									) -- 453
								) -- 453
							end -- 453
						end -- 453
					end -- 453
					if ring.showRange == false then -- 453
						goto __continue36 -- 457
					end -- 457
					if ring.radius <= 0 then -- 457
						goto __continue36 -- 458
					end -- 458
					local n = options.ringSegments -- 460
					local circle = {} -- 461
					do -- 461
						local i = 0 -- 462
						while i <= n do -- 462
							local a = i / n * 2 * math.pi -- 463
							circle[#circle + 1] = { -- 464
								x = ring.center.x + ring.radius * math.cos(a), -- 464
								y = ring.center.y + ring.radius * math.sin(a) -- 464
							} -- 464
							i = i + 1 -- 462
						end -- 462
					end -- 462
					local verts = ____exports.projectPolyline( -- 466
						circle, -- 466
						options.y, -- 466
						basis, -- 466
						options.layerOriginX, -- 466
						options.layerOriginY -- 466
					) -- 466
					if #verts < 3 then -- 466
						goto __continue36 -- 467
					end -- 467
					local rgb = ring.passed and ({r = options.ringR * 0.35, g = options.ringG * 0.35, b = options.ringB * 0.35}) or ({r = options.ringR, g = options.ringG, b = options.ringB}) -- 468
					____exports.drawDashedPolyline( -- 471
						ringDraw, -- 471
						verts, -- 471
						options.ringRadius, -- 471
						rgb, -- 471
						1, -- 471
						options.glowRadiusFactor, -- 471
						options.ringGlowAlpha, -- 471
						options.dashOn * 1.5, -- 471
						options.dashOff, -- 471
						false -- 471
					) -- 471
				end -- 471
				::__continue36:: -- 471
			end -- 471
		end, -- 440
		clearGoalRings = function(self) -- 474
			ringDraw:clear() -- 475
		end, -- 474
		setBurn = function(____, p, direction, on, basis) -- 477
			burnDraw:clear() -- 478
			if not on then -- 478
				return -- 479
			end -- 479
			local mag = math.sqrt(direction.x * direction.x + direction.y * direction.y) -- 480
			if mag <= 0 then -- 480
				return -- 481
			end -- 481
			local length = options.burnLength ~= nil and options.burnLength or 32 -- 482
			local pts = ____exports.projectPolyline( -- 483
				{p, {x = p.x - direction.x * length / mag, y = p.y - direction.y * length / mag}}, -- 483
				options.y, -- 483
				basis, -- 483
				options.layerOriginX, -- 483
				options.layerOriginY -- 483
			) -- 483
			if #pts == 2 then -- 483
				burnDraw:drawSegment( -- 485
					pts[1], -- 485
					pts[2], -- 485
					5, -- 485
					Color(255, 135, 35, 140) -- 485
				) -- 485
				burnDraw:drawSegment( -- 486
					pts[1], -- 486
					pts[2], -- 486
					2, -- 486
					Color(255, 235, 145, 255) -- 486
				) -- 486
			end -- 486
		end, -- 477
		setOrbitRing = function(self, center, radius, basis) -- 489
			orbitDraw:clear() -- 490
			if radius <= 0 then -- 490
				return -- 491
			end -- 491
			local n = options.orbitRingSegments -- 492
			local circle = {} -- 493
			do -- 493
				local i = 0 -- 494
				while i <= n do -- 494
					local a = i / n * 2 * math.pi -- 495
					circle[#circle + 1] = { -- 496
						x = center.x + radius * math.cos(a), -- 496
						y = center.y + radius * math.sin(a) -- 496
					} -- 496
					i = i + 1 -- 494
				end -- 494
			end -- 494
			local verts = ____exports.projectPolyline( -- 498
				circle, -- 498
				options.y, -- 498
				basis, -- 498
				options.layerOriginX, -- 498
				options.layerOriginY -- 498
			) -- 498
			if #verts < 2 then -- 498
				return -- 499
			end -- 499
			local vx = basis.forward.x -- 501
			local vy = basis.forward.z -- 502
			local vl = math.sqrt(vx * vx + vy * vy) -- 503
			if vl > 1e-9 then -- 503
				vx = vx / vl -- 505
				vy = vy / vl -- 506
			end -- 506
			local rgb = {r = options.orbitRingR, g = options.orbitRingG, b = options.orbitRingB} -- 508
			local nearCol = segColor(rgb, options.orbitRingAlpha) -- 509
			local farCol = segColor(rgb, options.orbitRingFarAlpha) -- 510
			do -- 510
				local i = 1 -- 511
				while i < #verts and i < #circle do -- 511
					local far = (circle[i + 1].x - center.x) * vx + (circle[i + 1].y - center.y) * vy > 0 -- 512
					orbitDraw:drawSegment(verts[i], verts[i + 1], options.orbitRingRadius, far and farCol or nearCol) -- 513
					i = i + 1 -- 511
				end -- 511
			end -- 511
		end, -- 489
		clearOrbitRing = function(self) -- 516
			orbitDraw:clear() -- 517
		end, -- 516
		root = root -- 519
	} -- 519
end -- 363
return ____exports -- 363
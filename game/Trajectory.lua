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
function ____exports.defaultOptions() -- 170
	return { -- 171
		y = 0.02, -- 172
		layerOriginX = View.size.width / 2, -- 174
		layerOriginY = View.size.height / 2, -- 175
		maxPoints = 240, -- 176
		predictRadius = 2, -- 177
		dashOn = 12, -- 179
		dashOff = 9, -- 180
		predictFadeMin = 0.1, -- 181
		glowRadiusFactor = 1.9, -- 182
		glowAlpha = 0.13, -- 183
		tailPoints = 280, -- 184
		trailHeadRadius = 3.4, -- 185
		trailHeadAlpha = 0.85, -- 186
		predictR = 120, -- 187
		predictG = 200, -- 188
		predictB = 255, -- 189
		ringR = 150, -- 191
		ringG = 235, -- 192
		ringB = 220, -- 193
		ringRadius = 1.6, -- 194
		ringGlowAlpha = 0.2, -- 195
		ringSegments = 56, -- 196
		orbitRingR = 138, -- 199
		orbitRingG = 176, -- 200
		orbitRingB = 205, -- 201
		orbitRingRadius = 1.5, -- 202
		orbitRingAlpha = 0.5, -- 203
		orbitRingFarAlpha = 0.16, -- 204
		orbitRingSegments = 72, -- 205
		trailR = 255, -- 206
		trailG = 236, -- 207
		trailB = 170 -- 208
	} -- 208
end -- 170
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 213
	if maxPoints <= 0 or #points <= maxPoints then -- 213
		return points -- 214
	end -- 214
	local out = {} -- 215
	local step = (#points - 1) / (maxPoints - 1) -- 216
	do -- 216
		local i = 0 -- 217
		while i < maxPoints do -- 217
			local idx = math.floor(i * step) -- 218
			local safe = idx < #points and idx or #points - 1 -- 219
			out[#out + 1] = points[safe + 1] -- 220
			i = i + 1 -- 217
		end -- 217
	end -- 217
	out[maxPoints] = points[#points] -- 223
	return out -- 224
end -- 213
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 231
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 232
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 233
end -- 231
local function segColor(rgb, alpha) -- 238
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 241
	return Color( -- 242
		math.floor(rgb.r * a + 0.5), -- 242
		math.floor(rgb.g * a + 0.5), -- 242
		math.floor(rgb.b * a + 0.5), -- 242
		255 -- 242
	) -- 242
end -- 238
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 253
	local maxSeg = 800 -- 268
	if clearFirst ~= false then -- 268
		draw:clear() -- 269
	end -- 269
	local n = #verts -- 270
	if n < 2 then -- 270
		return -- 271
	end -- 271
	local segLen = {} -- 274
	local total = 0 -- 275
	do -- 275
		local i = 1 -- 276
		while i < n do -- 276
			local dx = verts[i + 1].x - verts[i].x -- 277
			local dy = verts[i + 1].y - verts[i].y -- 278
			local l = math.sqrt(dx * dx + dy * dy) -- 279
			segLen[#segLen + 1] = l -- 280
			total = total + l -- 281
			i = i + 1 -- 276
		end -- 276
	end -- 276
	if total < 0.001 then -- 276
		return -- 283
	end -- 283
	local cycle = dashOn + dashOff -- 285
	local glowRadius = coreRadius * glowRadiusFactor -- 286
	local pen = 0 -- 287
	do -- 287
		local i = 1 -- 288
		while i < n do -- 288
			do -- 288
				local ax = verts[i].x -- 289
				local ay = verts[i].y -- 289
				local bx = verts[i + 1].x -- 290
				local by = verts[i + 1].y -- 290
				local len = segLen[i] -- 291
				if len < 0.001 or len > maxSeg then -- 291
					goto __continue20 -- 293
				end -- 293
				local s = 0 -- 294
				while s < len - 0.001 do -- 294
					local c = pen % cycle -- 296
					local run = math.min(cycle - c, len - s) -- 297
					if c < dashOn then -- 297
						local t0 = s / len -- 299
						local t1 = (s + run) / len -- 300
						local x0 = ax + (bx - ax) * t0 -- 301
						local y0 = ay + (by - ay) * t0 -- 302
						local x1 = ax + (bx - ax) * t1 -- 303
						local y1 = ay + (by - ay) * t1 -- 304
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 305
						local p0 = Vec2(x0, y0) -- 306
						local p1 = Vec2(x1, y1) -- 307
						draw:drawSegment( -- 308
							p0, -- 308
							p1, -- 308
							glowRadius, -- 308
							segColor(rgb, glowAlpha * al) -- 308
						) -- 308
						draw:drawSegment( -- 309
							p0, -- 309
							p1, -- 309
							coreRadius, -- 309
							segColor(rgb, al) -- 309
						) -- 309
					end -- 309
					pen = pen + run -- 311
					s = s + run -- 312
				end -- 312
			end -- 312
			::__continue20:: -- 312
			i = i + 1 -- 288
		end -- 288
	end -- 288
end -- 253
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 318
	draw:clear() -- 327
	local n = #verts -- 328
	if n < 2 then -- 328
		return -- 329
	end -- 329
	local tailRadius = headRadius * 0.15 -- 330
	local glowRadius = headRadius * glowRadiusFactor -- 331
	local maxSeg = 800 -- 332
	do -- 332
		local i = 1 -- 333
		while i < n do -- 333
			do -- 333
				local u = i / (n - 1) -- 335
				local up = u ^ 1.2 -- 336
				local r = tailRadius + (headRadius - tailRadius) * up -- 337
				local al = headAlpha * u ^ 1.6 -- 338
				local dxv = verts[i + 1].x - verts[i].x -- 339
				local dyv = verts[i + 1].y - verts[i].y -- 340
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 340
					goto __continue27 -- 341
				end -- 341
				draw:drawSegment( -- 342
					verts[i], -- 342
					verts[i + 1], -- 342
					r * glowRadiusFactor, -- 342
					segColor(rgb, glowAlpha * al) -- 342
				) -- 342
				draw:drawSegment( -- 343
					verts[i], -- 343
					verts[i + 1], -- 343
					r, -- 343
					segColor(rgb, al) -- 343
				) -- 343
			end -- 343
			::__continue27:: -- 343
			i = i + 1 -- 333
		end -- 333
	end -- 333
	draw:drawDot( -- 346
		verts[n], -- 346
		headRadius * 1.5, -- 346
		segColor(rgb, headAlpha) -- 346
	) -- 346
end -- 318
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 355
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 359
	local root = Node() -- 362
	local orbitDraw = DrawNode() -- 365
	orbitDraw.blendFunc = BlendFunc("One", "One") -- 366
	root:addChild(orbitDraw) -- 367
	local ringDraw = DrawNode() -- 369
	ringDraw.blendFunc = BlendFunc("One", "One") -- 370
	root:addChild(ringDraw) -- 371
	local trailDraw = DrawNode() -- 373
	trailDraw.blendFunc = BlendFunc("One", "One") -- 375
	root:addChild(trailDraw) -- 376
	local predictDraw = DrawNode() -- 378
	predictDraw.blendFunc = BlendFunc("One", "One") -- 379
	root:addChild(predictDraw) -- 380
	parent:addChild(root) -- 382
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 384
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 385
	return { -- 387
		setPrediction = function(self, points, basis) -- 388
			local verts = ____exports.projectPolyline( -- 389
				____exports.decimate(points, options.maxPoints), -- 389
				options.y, -- 389
				basis, -- 389
				options.layerOriginX, -- 389
				options.layerOriginY -- 389
			) -- 389
			____exports.drawDashedPolyline( -- 390
				predictDraw, -- 391
				verts, -- 392
				options.predictRadius, -- 393
				predictRGB, -- 394
				options.predictFadeMin, -- 395
				options.glowRadiusFactor, -- 396
				options.glowAlpha, -- 397
				options.dashOn, -- 398
				options.dashOff -- 399
			) -- 399
		end, -- 388
		clearPrediction = function(self) -- 402
			predictDraw:clear() -- 403
		end, -- 402
		setTrail = function(self, points, basis) -- 405
			if #points < 2 then -- 405
				trailDraw:clear() -- 409
				return -- 410
			end -- 410
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 412
			local verts = ____exports.projectPolyline( -- 415
				____exports.decimate(tail, options.maxPoints), -- 415
				options.y, -- 415
				basis, -- 415
				options.layerOriginX, -- 415
				options.layerOriginY -- 415
			) -- 415
			drawComet( -- 416
				trailDraw, -- 417
				verts, -- 418
				options.trailHeadRadius, -- 419
				trailRGB, -- 420
				options.trailHeadAlpha, -- 421
				options.glowRadiusFactor, -- 422
				options.glowAlpha -- 423
			) -- 423
		end, -- 405
		clearTrail = function(self) -- 426
			trailDraw:clear() -- 427
		end, -- 426
		setGoalRings = function(self, rings, basis) -- 429
			ringDraw:clear() -- 430
			for ____, ring in ipairs(rings) do -- 431
				do -- 431
					if ring.radius <= 0 then -- 431
						goto __continue36 -- 432
					end -- 432
					local n = options.ringSegments -- 434
					local circle = {} -- 435
					do -- 435
						local i = 0 -- 436
						while i <= n do -- 436
							local a = i / n * 2 * math.pi -- 437
							circle[#circle + 1] = { -- 438
								x = ring.center.x + ring.radius * math.cos(a), -- 438
								y = ring.center.y + ring.radius * math.sin(a) -- 438
							} -- 438
							i = i + 1 -- 436
						end -- 436
					end -- 436
					local verts = ____exports.projectPolyline( -- 440
						circle, -- 440
						options.y, -- 440
						basis, -- 440
						options.layerOriginX, -- 440
						options.layerOriginY -- 440
					) -- 440
					if #verts < 3 then -- 440
						goto __continue36 -- 441
					end -- 441
					local rgb = ring.passed and ({r = options.ringR * 0.35, g = options.ringG * 0.35, b = options.ringB * 0.35}) or ({r = options.ringR, g = options.ringG, b = options.ringB}) -- 442
					____exports.drawDashedPolyline( -- 445
						ringDraw, -- 445
						verts, -- 445
						options.ringRadius, -- 445
						rgb, -- 445
						1, -- 445
						options.glowRadiusFactor, -- 445
						options.ringGlowAlpha, -- 445
						options.dashOn * 1.5, -- 445
						options.dashOff, -- 445
						false -- 445
					) -- 445
				end -- 445
				::__continue36:: -- 445
			end -- 445
		end, -- 429
		clearGoalRings = function(self) -- 448
			ringDraw:clear() -- 449
		end, -- 448
		setOrbitRing = function(self, center, radius, basis) -- 451
			orbitDraw:clear() -- 452
			if radius <= 0 then -- 452
				return -- 453
			end -- 453
			local n = options.orbitRingSegments -- 454
			local circle = {} -- 455
			do -- 455
				local i = 0 -- 456
				while i <= n do -- 456
					local a = i / n * 2 * math.pi -- 457
					circle[#circle + 1] = { -- 458
						x = center.x + radius * math.cos(a), -- 458
						y = center.y + radius * math.sin(a) -- 458
					} -- 458
					i = i + 1 -- 456
				end -- 456
			end -- 456
			local verts = ____exports.projectPolyline( -- 460
				circle, -- 460
				options.y, -- 460
				basis, -- 460
				options.layerOriginX, -- 460
				options.layerOriginY -- 460
			) -- 460
			if #verts < 2 then -- 460
				return -- 461
			end -- 461
			local vx = basis.forward.x -- 463
			local vy = basis.forward.z -- 464
			local vl = math.sqrt(vx * vx + vy * vy) -- 465
			if vl > 1e-9 then -- 465
				vx = vx / vl -- 467
				vy = vy / vl -- 468
			end -- 468
			local rgb = {r = options.orbitRingR, g = options.orbitRingG, b = options.orbitRingB} -- 470
			local nearCol = segColor(rgb, options.orbitRingAlpha) -- 471
			local farCol = segColor(rgb, options.orbitRingFarAlpha) -- 472
			do -- 472
				local i = 1 -- 473
				while i < #verts and i < #circle do -- 473
					local far = (circle[i + 1].x - center.x) * vx + (circle[i + 1].y - center.y) * vy > 0 -- 474
					orbitDraw:drawSegment(verts[i], verts[i + 1], options.orbitRingRadius, far and farCol or nearCol) -- 475
					i = i + 1 -- 473
				end -- 473
			end -- 473
		end, -- 451
		clearOrbitRing = function(self) -- 478
			orbitDraw:clear() -- 479
		end, -- 478
		root = root -- 481
	} -- 481
end -- 355
return ____exports -- 355
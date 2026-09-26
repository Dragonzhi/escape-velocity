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
function ____exports.defaultOptions() -- 148
	return { -- 149
		y = 0.02, -- 150
		layerOriginX = View.size.width / 2, -- 152
		layerOriginY = View.size.height / 2, -- 153
		maxPoints = 240, -- 154
		predictRadius = 2, -- 155
		dashOn = 12, -- 157
		dashOff = 9, -- 158
		predictFadeMin = 0.1, -- 159
		glowRadiusFactor = 1.9, -- 160
		glowAlpha = 0.13, -- 161
		tailPoints = 280, -- 162
		trailHeadRadius = 3.4, -- 163
		trailHeadAlpha = 0.85, -- 164
		predictR = 120, -- 165
		predictG = 200, -- 166
		predictB = 255, -- 167
		ringR = 150, -- 169
		ringG = 235, -- 170
		ringB = 220, -- 171
		ringRadius = 1.6, -- 172
		ringGlowAlpha = 0.2, -- 173
		ringSegments = 56, -- 174
		trailR = 255, -- 175
		trailG = 236, -- 176
		trailB = 170 -- 177
	} -- 177
end -- 148
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 182
	if maxPoints <= 0 or #points <= maxPoints then -- 182
		return points -- 183
	end -- 183
	local out = {} -- 184
	local step = (#points - 1) / (maxPoints - 1) -- 185
	do -- 185
		local i = 0 -- 186
		while i < maxPoints do -- 186
			local idx = math.floor(i * step) -- 187
			local safe = idx < #points and idx or #points - 1 -- 188
			out[#out + 1] = points[safe + 1] -- 189
			i = i + 1 -- 186
		end -- 186
	end -- 186
	out[maxPoints] = points[#points] -- 192
	return out -- 193
end -- 182
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 200
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 201
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 202
end -- 200
local function segColor(rgb, alpha) -- 207
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 210
	return Color( -- 211
		math.floor(rgb.r * a + 0.5), -- 211
		math.floor(rgb.g * a + 0.5), -- 211
		math.floor(rgb.b * a + 0.5), -- 211
		255 -- 211
	) -- 211
end -- 207
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 222
	local maxSeg = 800 -- 237
	if clearFirst ~= false then -- 237
		draw:clear() -- 238
	end -- 238
	local n = #verts -- 239
	if n < 2 then -- 239
		return -- 240
	end -- 240
	local segLen = {} -- 243
	local total = 0 -- 244
	do -- 244
		local i = 1 -- 245
		while i < n do -- 245
			local dx = verts[i + 1].x - verts[i].x -- 246
			local dy = verts[i + 1].y - verts[i].y -- 247
			local l = math.sqrt(dx * dx + dy * dy) -- 248
			segLen[#segLen + 1] = l -- 249
			total = total + l -- 250
			i = i + 1 -- 245
		end -- 245
	end -- 245
	if total < 0.001 then -- 245
		return -- 252
	end -- 252
	local cycle = dashOn + dashOff -- 254
	local glowRadius = coreRadius * glowRadiusFactor -- 255
	local pen = 0 -- 256
	do -- 256
		local i = 1 -- 257
		while i < n do -- 257
			do -- 257
				local ax = verts[i].x -- 258
				local ay = verts[i].y -- 258
				local bx = verts[i + 1].x -- 259
				local by = verts[i + 1].y -- 259
				local len = segLen[i] -- 260
				if len < 0.001 or len > maxSeg then -- 260
					goto __continue20 -- 262
				end -- 262
				local s = 0 -- 263
				while s < len - 0.001 do -- 263
					local c = pen % cycle -- 265
					local run = math.min(cycle - c, len - s) -- 266
					if c < dashOn then -- 266
						local t0 = s / len -- 268
						local t1 = (s + run) / len -- 269
						local x0 = ax + (bx - ax) * t0 -- 270
						local y0 = ay + (by - ay) * t0 -- 271
						local x1 = ax + (bx - ax) * t1 -- 272
						local y1 = ay + (by - ay) * t1 -- 273
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 274
						local p0 = Vec2(x0, y0) -- 275
						local p1 = Vec2(x1, y1) -- 276
						draw:drawSegment( -- 277
							p0, -- 277
							p1, -- 277
							glowRadius, -- 277
							segColor(rgb, glowAlpha * al) -- 277
						) -- 277
						draw:drawSegment( -- 278
							p0, -- 278
							p1, -- 278
							coreRadius, -- 278
							segColor(rgb, al) -- 278
						) -- 278
					end -- 278
					pen = pen + run -- 280
					s = s + run -- 281
				end -- 281
			end -- 281
			::__continue20:: -- 281
			i = i + 1 -- 257
		end -- 257
	end -- 257
end -- 222
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 287
	draw:clear() -- 296
	local n = #verts -- 297
	if n < 2 then -- 297
		return -- 298
	end -- 298
	local tailRadius = headRadius * 0.15 -- 299
	local glowRadius = headRadius * glowRadiusFactor -- 300
	local maxSeg = 800 -- 301
	do -- 301
		local i = 1 -- 302
		while i < n do -- 302
			do -- 302
				local u = i / (n - 1) -- 304
				local up = u ^ 1.2 -- 305
				local r = tailRadius + (headRadius - tailRadius) * up -- 306
				local al = headAlpha * u ^ 1.6 -- 307
				local dxv = verts[i + 1].x - verts[i].x -- 308
				local dyv = verts[i + 1].y - verts[i].y -- 309
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 309
					goto __continue27 -- 310
				end -- 310
				draw:drawSegment( -- 311
					verts[i], -- 311
					verts[i + 1], -- 311
					r * glowRadiusFactor, -- 311
					segColor(rgb, glowAlpha * al) -- 311
				) -- 311
				draw:drawSegment( -- 312
					verts[i], -- 312
					verts[i + 1], -- 312
					r, -- 312
					segColor(rgb, al) -- 312
				) -- 312
			end -- 312
			::__continue27:: -- 312
			i = i + 1 -- 302
		end -- 302
	end -- 302
	draw:drawDot( -- 315
		verts[n], -- 315
		headRadius * 1.5, -- 315
		segColor(rgb, headAlpha) -- 315
	) -- 315
end -- 287
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 324
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 328
	local root = Node() -- 331
	local ringDraw = DrawNode() -- 334
	ringDraw.blendFunc = BlendFunc("One", "One") -- 335
	root:addChild(ringDraw) -- 336
	local trailDraw = DrawNode() -- 338
	trailDraw.blendFunc = BlendFunc("One", "One") -- 340
	root:addChild(trailDraw) -- 341
	local predictDraw = DrawNode() -- 343
	predictDraw.blendFunc = BlendFunc("One", "One") -- 344
	root:addChild(predictDraw) -- 345
	parent:addChild(root) -- 347
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 349
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 350
	return { -- 352
		setPrediction = function(self, points, basis) -- 353
			local verts = ____exports.projectPolyline( -- 354
				____exports.decimate(points, options.maxPoints), -- 354
				options.y, -- 354
				basis, -- 354
				options.layerOriginX, -- 354
				options.layerOriginY -- 354
			) -- 354
			____exports.drawDashedPolyline( -- 355
				predictDraw, -- 356
				verts, -- 357
				options.predictRadius, -- 358
				predictRGB, -- 359
				options.predictFadeMin, -- 360
				options.glowRadiusFactor, -- 361
				options.glowAlpha, -- 362
				options.dashOn, -- 363
				options.dashOff -- 364
			) -- 364
		end, -- 353
		clearPrediction = function(self) -- 367
			predictDraw:clear() -- 368
		end, -- 367
		setTrail = function(self, points, basis) -- 370
			if #points < 2 then -- 370
				trailDraw:clear() -- 374
				return -- 375
			end -- 375
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 377
			local verts = ____exports.projectPolyline( -- 380
				____exports.decimate(tail, options.maxPoints), -- 380
				options.y, -- 380
				basis, -- 380
				options.layerOriginX, -- 380
				options.layerOriginY -- 380
			) -- 380
			drawComet( -- 381
				trailDraw, -- 382
				verts, -- 383
				options.trailHeadRadius, -- 384
				trailRGB, -- 385
				options.trailHeadAlpha, -- 386
				options.glowRadiusFactor, -- 387
				options.glowAlpha -- 388
			) -- 388
		end, -- 370
		clearTrail = function(self) -- 391
			trailDraw:clear() -- 392
		end, -- 391
		setGoalRings = function(self, rings, basis) -- 394
			ringDraw:clear() -- 395
			for ____, ring in ipairs(rings) do -- 396
				do -- 396
					if ring.radius <= 0 then -- 396
						goto __continue36 -- 397
					end -- 397
					local n = options.ringSegments -- 399
					local circle = {} -- 400
					do -- 400
						local i = 0 -- 401
						while i <= n do -- 401
							local a = i / n * 2 * math.pi -- 402
							circle[#circle + 1] = { -- 403
								x = ring.center.x + ring.radius * math.cos(a), -- 403
								y = ring.center.y + ring.radius * math.sin(a) -- 403
							} -- 403
							i = i + 1 -- 401
						end -- 401
					end -- 401
					local verts = ____exports.projectPolyline( -- 405
						circle, -- 405
						options.y, -- 405
						basis, -- 405
						options.layerOriginX, -- 405
						options.layerOriginY -- 405
					) -- 405
					if #verts < 3 then -- 405
						goto __continue36 -- 406
					end -- 406
					local rgb = ring.passed and ({r = options.ringR * 0.35, g = options.ringG * 0.35, b = options.ringB * 0.35}) or ({r = options.ringR, g = options.ringG, b = options.ringB}) -- 407
					____exports.drawDashedPolyline( -- 410
						ringDraw, -- 410
						verts, -- 410
						options.ringRadius, -- 410
						rgb, -- 410
						1, -- 410
						options.glowRadiusFactor, -- 410
						options.ringGlowAlpha, -- 410
						options.dashOn * 1.5, -- 410
						options.dashOff, -- 410
						false -- 410
					) -- 410
				end -- 410
				::__continue36:: -- 410
			end -- 410
		end, -- 394
		clearGoalRings = function(self) -- 413
			ringDraw:clear() -- 414
		end, -- 413
		root = root -- 416
	} -- 416
end -- 324
return ____exports -- 324
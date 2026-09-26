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
function ____exports.defaultOptions() -- 122
	return { -- 123
		y = 0.02, -- 124
		layerOriginX = View.size.width / 2, -- 126
		layerOriginY = View.size.height / 2, -- 127
		maxPoints = 240, -- 128
		predictRadius = 2, -- 129
		dashOn = 12, -- 131
		dashOff = 9, -- 132
		predictFadeMin = 0.1, -- 133
		glowRadiusFactor = 1.9, -- 134
		glowAlpha = 0.13, -- 135
		tailPoints = 280, -- 136
		trailHeadRadius = 3.4, -- 137
		trailHeadAlpha = 0.85, -- 138
		predictR = 120, -- 139
		predictG = 200, -- 140
		predictB = 255, -- 141
		trailR = 255, -- 142
		trailG = 236, -- 143
		trailB = 170 -- 144
	} -- 144
end -- 122
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 149
	if maxPoints <= 0 or #points <= maxPoints then -- 149
		return points -- 150
	end -- 150
	local out = {} -- 151
	local step = (#points - 1) / (maxPoints - 1) -- 152
	do -- 152
		local i = 0 -- 153
		while i < maxPoints do -- 153
			local idx = math.floor(i * step) -- 154
			local safe = idx < #points and idx or #points - 1 -- 155
			out[#out + 1] = points[safe + 1] -- 156
			i = i + 1 -- 153
		end -- 153
	end -- 153
	out[maxPoints] = points[#points] -- 159
	return out -- 160
end -- 149
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 167
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 168
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 169
end -- 167
local function segColor(rgb, alpha) -- 174
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 177
	return Color( -- 178
		math.floor(rgb.r * a + 0.5), -- 178
		math.floor(rgb.g * a + 0.5), -- 178
		math.floor(rgb.b * a + 0.5), -- 178
		255 -- 178
	) -- 178
end -- 174
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
-- 
-- 导出给 S3.3 开场复用（太阳系轨道虚线圈）——轨道是**整圈均匀**的，
-- 调 `fadeMin = 1` 即可关掉沿线渐隐；`clearFirst = false` 让同一个 DrawNode
-- 上叠多条环（预测线/尾迹每帧重画，仍用默认的 clear）。
function ____exports.drawDashedPolyline(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff, clearFirst) -- 189
	local maxSeg = 800 -- 204
	if clearFirst ~= false then -- 204
		draw:clear() -- 205
	end -- 205
	local n = #verts -- 206
	if n < 2 then -- 206
		return -- 207
	end -- 207
	local segLen = {} -- 210
	local total = 0 -- 211
	do -- 211
		local i = 1 -- 212
		while i < n do -- 212
			local dx = verts[i + 1].x - verts[i].x -- 213
			local dy = verts[i + 1].y - verts[i].y -- 214
			local l = math.sqrt(dx * dx + dy * dy) -- 215
			segLen[#segLen + 1] = l -- 216
			total = total + l -- 217
			i = i + 1 -- 212
		end -- 212
	end -- 212
	if total < 0.001 then -- 212
		return -- 219
	end -- 219
	local cycle = dashOn + dashOff -- 221
	local glowRadius = coreRadius * glowRadiusFactor -- 222
	local pen = 0 -- 223
	do -- 223
		local i = 1 -- 224
		while i < n do -- 224
			do -- 224
				local ax = verts[i].x -- 225
				local ay = verts[i].y -- 225
				local bx = verts[i + 1].x -- 226
				local by = verts[i + 1].y -- 226
				local len = segLen[i] -- 227
				if len < 0.001 or len > maxSeg then -- 227
					goto __continue20 -- 229
				end -- 229
				local s = 0 -- 230
				while s < len - 0.001 do -- 230
					local c = pen % cycle -- 232
					local run = math.min(cycle - c, len - s) -- 233
					if c < dashOn then -- 233
						local t0 = s / len -- 235
						local t1 = (s + run) / len -- 236
						local x0 = ax + (bx - ax) * t0 -- 237
						local y0 = ay + (by - ay) * t0 -- 238
						local x1 = ax + (bx - ax) * t1 -- 239
						local y1 = ay + (by - ay) * t1 -- 240
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 241
						local p0 = Vec2(x0, y0) -- 242
						local p1 = Vec2(x1, y1) -- 243
						draw:drawSegment( -- 244
							p0, -- 244
							p1, -- 244
							glowRadius, -- 244
							segColor(rgb, glowAlpha * al) -- 244
						) -- 244
						draw:drawSegment( -- 245
							p0, -- 245
							p1, -- 245
							coreRadius, -- 245
							segColor(rgb, al) -- 245
						) -- 245
					end -- 245
					pen = pen + run -- 247
					s = s + run -- 248
				end -- 248
			end -- 248
			::__continue20:: -- 248
			i = i + 1 -- 224
		end -- 224
	end -- 224
end -- 189
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 254
	draw:clear() -- 263
	local n = #verts -- 264
	if n < 2 then -- 264
		return -- 265
	end -- 265
	local tailRadius = headRadius * 0.15 -- 266
	local glowRadius = headRadius * glowRadiusFactor -- 267
	local maxSeg = 800 -- 268
	do -- 268
		local i = 1 -- 269
		while i < n do -- 269
			do -- 269
				local u = i / (n - 1) -- 271
				local up = u ^ 1.2 -- 272
				local r = tailRadius + (headRadius - tailRadius) * up -- 273
				local al = headAlpha * u ^ 1.6 -- 274
				local dxv = verts[i + 1].x - verts[i].x -- 275
				local dyv = verts[i + 1].y - verts[i].y -- 276
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 276
					goto __continue27 -- 277
				end -- 277
				draw:drawSegment( -- 278
					verts[i], -- 278
					verts[i + 1], -- 278
					r * glowRadiusFactor, -- 278
					segColor(rgb, glowAlpha * al) -- 278
				) -- 278
				draw:drawSegment( -- 279
					verts[i], -- 279
					verts[i + 1], -- 279
					r, -- 279
					segColor(rgb, al) -- 279
				) -- 279
			end -- 279
			::__continue27:: -- 279
			i = i + 1 -- 269
		end -- 269
	end -- 269
	draw:drawDot( -- 282
		verts[n], -- 282
		headRadius * 1.5, -- 282
		segColor(rgb, headAlpha) -- 282
	) -- 282
end -- 254
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 291
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 295
	local root = Node() -- 298
	local trailDraw = DrawNode() -- 301
	trailDraw.blendFunc = BlendFunc("One", "One") -- 303
	root:addChild(trailDraw) -- 304
	local predictDraw = DrawNode() -- 306
	predictDraw.blendFunc = BlendFunc("One", "One") -- 307
	root:addChild(predictDraw) -- 308
	parent:addChild(root) -- 310
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 312
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 313
	return { -- 315
		setPrediction = function(self, points, basis) -- 316
			local verts = ____exports.projectPolyline( -- 317
				____exports.decimate(points, options.maxPoints), -- 317
				options.y, -- 317
				basis, -- 317
				options.layerOriginX, -- 317
				options.layerOriginY -- 317
			) -- 317
			____exports.drawDashedPolyline( -- 318
				predictDraw, -- 319
				verts, -- 320
				options.predictRadius, -- 321
				predictRGB, -- 322
				options.predictFadeMin, -- 323
				options.glowRadiusFactor, -- 324
				options.glowAlpha, -- 325
				options.dashOn, -- 326
				options.dashOff -- 327
			) -- 327
		end, -- 316
		clearPrediction = function(self) -- 330
			predictDraw:clear() -- 331
		end, -- 330
		setTrail = function(self, points, basis) -- 333
			if #points < 2 then -- 333
				trailDraw:clear() -- 337
				return -- 338
			end -- 338
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 340
			local verts = ____exports.projectPolyline( -- 343
				____exports.decimate(tail, options.maxPoints), -- 343
				options.y, -- 343
				basis, -- 343
				options.layerOriginX, -- 343
				options.layerOriginY -- 343
			) -- 343
			drawComet( -- 344
				trailDraw, -- 345
				verts, -- 346
				options.trailHeadRadius, -- 347
				trailRGB, -- 348
				options.trailHeadAlpha, -- 349
				options.glowRadiusFactor, -- 350
				options.glowAlpha -- 351
			) -- 351
		end, -- 333
		clearTrail = function(self) -- 354
			trailDraw:clear() -- 355
		end, -- 354
		root = root -- 357
	} -- 357
end -- 291
return ____exports -- 291
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
local function drawDashed(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff) -- 185
	local maxSeg = 800 -- 199
	draw:clear() -- 200
	local n = #verts -- 201
	if n < 2 then -- 201
		return -- 202
	end -- 202
	local segLen = {} -- 205
	local total = 0 -- 206
	do -- 206
		local i = 1 -- 207
		while i < n do -- 207
			local dx = verts[i + 1].x - verts[i].x -- 208
			local dy = verts[i + 1].y - verts[i].y -- 209
			local l = math.sqrt(dx * dx + dy * dy) -- 210
			segLen[#segLen + 1] = l -- 211
			total = total + l -- 212
			i = i + 1 -- 207
		end -- 207
	end -- 207
	if total < 0.001 then -- 207
		return -- 214
	end -- 214
	local cycle = dashOn + dashOff -- 216
	local glowRadius = coreRadius * glowRadiusFactor -- 217
	local pen = 0 -- 218
	do -- 218
		local i = 1 -- 219
		while i < n do -- 219
			do -- 219
				local ax = verts[i].x -- 220
				local ay = verts[i].y -- 220
				local bx = verts[i + 1].x -- 221
				local by = verts[i + 1].y -- 221
				local len = segLen[i] -- 222
				if len < 0.001 or len > maxSeg then -- 222
					goto __continue19 -- 224
				end -- 224
				local s = 0 -- 225
				while s < len - 0.001 do -- 225
					local c = pen % cycle -- 227
					local run = math.min(cycle - c, len - s) -- 228
					if c < dashOn then -- 228
						local t0 = s / len -- 230
						local t1 = (s + run) / len -- 231
						local x0 = ax + (bx - ax) * t0 -- 232
						local y0 = ay + (by - ay) * t0 -- 233
						local x1 = ax + (bx - ax) * t1 -- 234
						local y1 = ay + (by - ay) * t1 -- 235
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 236
						local p0 = Vec2(x0, y0) -- 237
						local p1 = Vec2(x1, y1) -- 238
						draw:drawSegment( -- 239
							p0, -- 239
							p1, -- 239
							glowRadius, -- 239
							segColor(rgb, glowAlpha * al) -- 239
						) -- 239
						draw:drawSegment( -- 240
							p0, -- 240
							p1, -- 240
							coreRadius, -- 240
							segColor(rgb, al) -- 240
						) -- 240
					end -- 240
					pen = pen + run -- 242
					s = s + run -- 243
				end -- 243
			end -- 243
			::__continue19:: -- 243
			i = i + 1 -- 219
		end -- 219
	end -- 219
end -- 185
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 249
	draw:clear() -- 258
	local n = #verts -- 259
	if n < 2 then -- 259
		return -- 260
	end -- 260
	local tailRadius = headRadius * 0.15 -- 261
	local glowRadius = headRadius * glowRadiusFactor -- 262
	local maxSeg = 800 -- 263
	do -- 263
		local i = 1 -- 264
		while i < n do -- 264
			do -- 264
				local u = i / (n - 1) -- 266
				local up = u ^ 1.2 -- 267
				local r = tailRadius + (headRadius - tailRadius) * up -- 268
				local al = headAlpha * u ^ 1.6 -- 269
				local dxv = verts[i + 1].x - verts[i].x -- 270
				local dyv = verts[i + 1].y - verts[i].y -- 271
				if dxv * dxv + dyv * dyv > maxSeg * maxSeg then -- 271
					goto __continue26 -- 272
				end -- 272
				draw:drawSegment( -- 273
					verts[i], -- 273
					verts[i + 1], -- 273
					r * glowRadiusFactor, -- 273
					segColor(rgb, glowAlpha * al) -- 273
				) -- 273
				draw:drawSegment( -- 274
					verts[i], -- 274
					verts[i + 1], -- 274
					r, -- 274
					segColor(rgb, al) -- 274
				) -- 274
			end -- 274
			::__continue26:: -- 274
			i = i + 1 -- 264
		end -- 264
	end -- 264
	draw:drawDot( -- 277
		verts[n], -- 277
		headRadius * 1.5, -- 277
		segColor(rgb, headAlpha) -- 277
	) -- 277
end -- 249
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 286
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 290
	local root = Node() -- 293
	local trailDraw = DrawNode() -- 296
	trailDraw.blendFunc = BlendFunc("One", "One") -- 298
	root:addChild(trailDraw) -- 299
	local predictDraw = DrawNode() -- 301
	predictDraw.blendFunc = BlendFunc("One", "One") -- 302
	root:addChild(predictDraw) -- 303
	parent:addChild(root) -- 305
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 307
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 308
	return { -- 310
		setPrediction = function(self, points, basis) -- 311
			local verts = ____exports.projectPolyline( -- 312
				____exports.decimate(points, options.maxPoints), -- 312
				options.y, -- 312
				basis, -- 312
				options.layerOriginX, -- 312
				options.layerOriginY -- 312
			) -- 312
			drawDashed( -- 313
				predictDraw, -- 314
				verts, -- 315
				options.predictRadius, -- 316
				predictRGB, -- 317
				options.predictFadeMin, -- 318
				options.glowRadiusFactor, -- 319
				options.glowAlpha, -- 320
				options.dashOn, -- 321
				options.dashOff -- 322
			) -- 322
		end, -- 311
		clearPrediction = function(self) -- 325
			predictDraw:clear() -- 326
		end, -- 325
		setTrail = function(self, points, basis) -- 328
			if #points < 2 then -- 328
				trailDraw:clear() -- 332
				return -- 333
			end -- 333
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 335
			local verts = ____exports.projectPolyline( -- 338
				____exports.decimate(tail, options.maxPoints), -- 338
				options.y, -- 338
				basis, -- 338
				options.layerOriginX, -- 338
				options.layerOriginY -- 338
			) -- 338
			drawComet( -- 339
				trailDraw, -- 340
				verts, -- 341
				options.trailHeadRadius, -- 342
				trailRGB, -- 343
				options.trailHeadAlpha, -- 344
				options.glowRadiusFactor, -- 345
				options.glowAlpha -- 346
			) -- 346
		end, -- 328
		clearTrail = function(self) -- 349
			trailDraw:clear() -- 350
		end, -- 349
		root = root -- 352
	} -- 352
end -- 286
return ____exports -- 286
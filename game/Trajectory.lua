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
			out[#out + 1] = Vec2(proj.x + originX, proj.y + originY) -- 48
		end -- 48
		::__continue3:: -- 48
	end -- 48
	return out -- 50
end -- 38
function ____exports.defaultOptions() -- 113
	return { -- 114
		y = 0.02, -- 115
		layerOriginX = View.size.width / 2, -- 117
		layerOriginY = View.size.height / 2, -- 118
		maxPoints = 240, -- 119
		predictRadius = 2, -- 120
		dashOn = 12, -- 122
		dashOff = 9, -- 123
		predictFadeMin = 0.1, -- 124
		glowRadiusFactor = 1.9, -- 125
		glowAlpha = 0.13, -- 126
		tailPoints = 280, -- 127
		trailHeadRadius = 3.4, -- 128
		trailHeadAlpha = 0.85, -- 129
		predictR = 120, -- 130
		predictG = 200, -- 131
		predictB = 255, -- 132
		trailR = 255, -- 133
		trailG = 236, -- 134
		trailB = 170 -- 135
	} -- 135
end -- 113
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 140
	if maxPoints <= 0 or #points <= maxPoints then -- 140
		return points -- 141
	end -- 141
	local out = {} -- 142
	local step = (#points - 1) / (maxPoints - 1) -- 143
	do -- 143
		local i = 0 -- 144
		while i < maxPoints do -- 144
			local idx = math.floor(i * step) -- 145
			local safe = idx < #points and idx or #points - 1 -- 146
			out[#out + 1] = points[safe + 1] -- 147
			i = i + 1 -- 144
		end -- 144
	end -- 144
	out[maxPoints] = points[#points] -- 150
	return out -- 151
end -- 140
--- 沿线 alpha 渐变（0 = 起点，1 = 末端）：平滑衰减，末端保留 `minA`。
-- 幂次 1.35 让前半段基本保持实色、后半段加速变淡（愤怒小鸟的观感）。
local function fadeAlpha(t, minA) -- 158
	local u = t < 0 and 0 or (t > 1 and 1 or t) -- 159
	return minA + (1 - minA) * (1 - u) ^ 1.35 -- 160
end -- 158
local function segColor(rgb, alpha) -- 165
	local a = alpha < 0 and 0 or (alpha > 1 and 1 or alpha) -- 168
	return Color( -- 169
		math.floor(rgb.r * a + 0.5), -- 169
		math.floor(rgb.g * a + 0.5), -- 169
		math.floor(rgb.b * a + 0.5), -- 169
		255 -- 169
	) -- 169
end -- 165
--- 虚线 + 渐隐 + 光晕：沿折线按"实段/空段"节奏走笔，
-- 每个实段按其中点的沿线比例取 alpha（光晕层同 alpha、更宽）。
local function drawDashed(draw, verts, coreRadius, rgb, fadeMin, glowRadiusFactor, glowAlpha, dashOn, dashOff) -- 176
	draw:clear() -- 187
	local n = #verts -- 188
	if n < 2 then -- 188
		return -- 189
	end -- 189
	local segLen = {} -- 192
	local total = 0 -- 193
	do -- 193
		local i = 1 -- 194
		while i < n do -- 194
			local dx = verts[i + 1].x - verts[i].x -- 195
			local dy = verts[i + 1].y - verts[i].y -- 196
			local l = math.sqrt(dx * dx + dy * dy) -- 197
			segLen[#segLen + 1] = l -- 198
			total = total + l -- 199
			i = i + 1 -- 194
		end -- 194
	end -- 194
	if total < 0.001 then -- 194
		return -- 201
	end -- 201
	local cycle = dashOn + dashOff -- 203
	local glowRadius = coreRadius * glowRadiusFactor -- 204
	local pen = 0 -- 205
	do -- 205
		local i = 1 -- 206
		while i < n do -- 206
			do -- 206
				local ax = verts[i].x -- 207
				local ay = verts[i].y -- 207
				local bx = verts[i + 1].x -- 208
				local by = verts[i + 1].y -- 208
				local len = segLen[i] -- 209
				if len < 0.001 then -- 209
					goto __continue19 -- 210
				end -- 210
				local s = 0 -- 211
				while s < len - 0.001 do -- 211
					local c = pen % cycle -- 213
					local run = math.min(cycle - c, len - s) -- 214
					if c < dashOn then -- 214
						local t0 = s / len -- 216
						local t1 = (s + run) / len -- 217
						local x0 = ax + (bx - ax) * t0 -- 218
						local y0 = ay + (by - ay) * t0 -- 219
						local x1 = ax + (bx - ax) * t1 -- 220
						local y1 = ay + (by - ay) * t1 -- 221
						local al = fadeAlpha((pen + run * 0.5) / total, fadeMin) -- 222
						local p0 = Vec2(x0, y0) -- 223
						local p1 = Vec2(x1, y1) -- 224
						draw:drawSegment( -- 225
							p0, -- 225
							p1, -- 225
							glowRadius, -- 225
							segColor(rgb, glowAlpha * al) -- 225
						) -- 225
						draw:drawSegment( -- 226
							p0, -- 226
							p1, -- 226
							coreRadius, -- 226
							segColor(rgb, al) -- 226
						) -- 226
					end -- 226
					pen = pen + run -- 228
					s = s + run -- 229
				end -- 229
			end -- 229
			::__continue19:: -- 229
			i = i + 1 -- 206
		end -- 206
	end -- 206
end -- 176
--- 彗星拖尾：宽度与 alpha 从头部向尾部收窄 + 光晕 + 头部亮点。
local function drawComet(draw, verts, headRadius, rgb, headAlpha, glowRadiusFactor, glowAlpha) -- 235
	draw:clear() -- 244
	local n = #verts -- 245
	if n < 2 then -- 245
		return -- 246
	end -- 246
	local tailRadius = headRadius * 0.15 -- 247
	local glowRadius = headRadius * glowRadiusFactor -- 248
	do -- 248
		local i = 1 -- 249
		while i < n do -- 249
			local u = i / (n - 1) -- 251
			local up = u ^ 1.2 -- 252
			local r = tailRadius + (headRadius - tailRadius) * up -- 253
			local al = headAlpha * u ^ 1.6 -- 254
			draw:drawSegment( -- 255
				verts[i], -- 255
				verts[i + 1], -- 255
				r * glowRadiusFactor, -- 255
				segColor(rgb, glowAlpha * al) -- 255
			) -- 255
			draw:drawSegment( -- 256
				verts[i], -- 256
				verts[i + 1], -- 256
				r, -- 256
				segColor(rgb, al) -- 256
			) -- 256
			i = i + 1 -- 249
		end -- 249
	end -- 249
	draw:drawDot( -- 259
		verts[n], -- 259
		headRadius * 1.5, -- 259
		segColor(rgb, headAlpha) -- 259
	) -- 259
end -- 235
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 268
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 272
	local root = Node() -- 275
	local trailDraw = DrawNode() -- 278
	trailDraw.blendFunc = BlendFunc("One", "One") -- 280
	root:addChild(trailDraw) -- 281
	local predictDraw = DrawNode() -- 283
	predictDraw.blendFunc = BlendFunc("One", "One") -- 284
	root:addChild(predictDraw) -- 285
	parent:addChild(root) -- 287
	local predictRGB = {r = options.predictR, g = options.predictG, b = options.predictB} -- 289
	local trailRGB = {r = options.trailR, g = options.trailG, b = options.trailB} -- 290
	return { -- 292
		setPrediction = function(self, points, basis) -- 293
			local verts = ____exports.projectPolyline( -- 294
				____exports.decimate(points, options.maxPoints), -- 294
				options.y, -- 294
				basis, -- 294
				options.layerOriginX, -- 294
				options.layerOriginY -- 294
			) -- 294
			drawDashed( -- 295
				predictDraw, -- 296
				verts, -- 297
				options.predictRadius, -- 298
				predictRGB, -- 299
				options.predictFadeMin, -- 300
				options.glowRadiusFactor, -- 301
				options.glowAlpha, -- 302
				options.dashOn, -- 303
				options.dashOff -- 304
			) -- 304
		end, -- 293
		clearPrediction = function(self) -- 307
			predictDraw:clear() -- 308
		end, -- 307
		setTrail = function(self, points, basis) -- 310
			if #points < 2 then -- 310
				trailDraw:clear() -- 314
				return -- 315
			end -- 315
			local tail = #points > options.tailPoints and __TS__ArraySlice(points, #points - options.tailPoints) or points -- 317
			local verts = ____exports.projectPolyline( -- 320
				____exports.decimate(tail, options.maxPoints), -- 320
				options.y, -- 320
				basis, -- 320
				options.layerOriginX, -- 320
				options.layerOriginY -- 320
			) -- 320
			drawComet( -- 321
				trailDraw, -- 322
				verts, -- 323
				options.trailHeadRadius, -- 324
				trailRGB, -- 325
				options.trailHeadAlpha, -- 326
				options.glowRadiusFactor, -- 327
				options.glowAlpha -- 328
			) -- 328
		end, -- 310
		clearTrail = function(self) -- 331
			trailDraw:clear() -- 332
		end, -- 331
		root = root -- 334
	} -- 334
end -- 268
return ____exports -- 268
-- [ts]: Trajectory.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 20
local BlendFunc = ____Dora.BlendFunc -- 20
local Color = ____Dora.Color -- 20
local DrawNode = ____Dora.DrawNode -- 20
local Node = ____Dora.Node -- 20
local Vec2 = ____Dora.Vec2 -- 20
local View = ____Dora.View -- 20
local ____Projection = require("game.Projection") -- 21
local projectPrepared = ____Projection.projectPrepared -- 21
local ____Config = require("game.Config") -- 23
local PlaneToWorldX = ____Config.PlaneToWorldX -- 23
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 23
--- 把平面采样点批量投影成**绘制层坐标**。
-- 
-- @param originX 绘制层坐标原点相对"投影输出（中心原点）"的 x 偏移
-- @param originY 同上，y 偏移
-- 
-- 为什么必须显式传：投影输出是中心原点偏移，而**绘制层自己的空间不一定是中心原点**
-- （取决于这个节点挂在谁下面）。把空间当成隐式全局（例如直接读 View.size）会让
-- 调用方与测试都无法表达"这一层到底是什么空间"，S2.2 的坐标错位正是这么来的。
function ____exports.projectPolyline(points, y, basis, originX, originY) -- 35
	local out = {} -- 36
	for ____, p in ipairs(points) do -- 37
		do -- 37
			local world = {x = p.x * PlaneToWorldX, y = y, z = p.y * PlaneToWorldZ} -- 38
			local proj = projectPrepared(world, basis) -- 43
			if proj == nil then -- 43
				goto __continue3 -- 44
			end -- 44
			out[#out + 1] = Vec2(proj.x + originX, proj.y + originY) -- 45
		end -- 45
		::__continue3:: -- 45
	end -- 45
	return out -- 47
end -- 35
function ____exports.defaultOptions() -- 94
	return { -- 95
		y = 0.02, -- 96
		layerOriginX = View.size.width / 2, -- 98
		layerOriginY = View.size.height / 2, -- 99
		maxPoints = 240, -- 100
		predictRadius = 2.5, -- 101
		trailRadius = 3.5, -- 102
		predictColor = Color(120, 200, 255, 180), -- 104
		trailColor = Color(255, 236, 170, 235) -- 106
	} -- 106
end -- 94
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 111
	if maxPoints <= 0 or #points <= maxPoints then -- 111
		return points -- 112
	end -- 112
	local out = {} -- 113
	local step = (#points - 1) / (maxPoints - 1) -- 114
	do -- 114
		local i = 0 -- 115
		while i < maxPoints do -- 115
			local idx = math.floor(i * step) -- 116
			local safe = idx < #points and idx or #points - 1 -- 117
			out[#out + 1] = points[safe + 1] -- 118
			i = i + 1 -- 115
		end -- 115
	end -- 115
	out[maxPoints] = points[#points] -- 121
	return out -- 122
end -- 111
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 131
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 135
	local root = Node() -- 138
	local trailDraw = DrawNode() -- 141
	trailDraw.blendFunc = BlendFunc("One", "One") -- 143
	root:addChild(trailDraw) -- 144
	local predictDraw = DrawNode() -- 146
	predictDraw.blendFunc = BlendFunc("One", "One") -- 147
	root:addChild(predictDraw) -- 148
	parent:addChild(root) -- 150
	local trailCount = 0 -- 152
	--- 把投影后的顶点用圆头线段连成一条光滑折线。
	local function drawPolyline(draw, verts, radius, color) -- 155
		draw:clear() -- 156
		do -- 156
			local i = 1 -- 157
			while i < #verts do -- 157
				draw:drawSegment(verts[i], verts[i + 1], radius, color) -- 158
				i = i + 1 -- 157
			end -- 157
		end -- 157
		for ____, v in ipairs(verts) do -- 161
			draw:drawDot(v, radius, color) -- 162
		end -- 162
	end -- 155
	return { -- 166
		setPrediction = function(self, points, basis) -- 167
			local verts = ____exports.projectPolyline( -- 168
				____exports.decimate(points, options.maxPoints), -- 168
				options.y, -- 168
				basis, -- 168
				options.layerOriginX, -- 168
				options.layerOriginY -- 168
			) -- 168
			drawPolyline(predictDraw, verts, options.predictRadius, options.predictColor) -- 169
		end, -- 167
		clearPrediction = function(self) -- 171
			predictDraw:clear() -- 172
		end, -- 171
		setTrail = function(self, points, basis) -- 174
			if #points < 2 then -- 174
				trailDraw:clear() -- 176
				trailCount = 0 -- 177
				return -- 178
			end -- 178
			if #points == trailCount then -- 178
				return -- 181
			end -- 181
			trailCount = #points -- 182
			local verts = ____exports.projectPolyline( -- 183
				____exports.decimate(points, options.maxPoints), -- 183
				options.y, -- 183
				basis, -- 183
				options.layerOriginX, -- 183
				options.layerOriginY -- 183
			) -- 183
			drawPolyline(trailDraw, verts, options.trailRadius, options.trailColor) -- 184
		end, -- 174
		clearTrail = function(self) -- 186
			trailDraw:clear() -- 187
			trailCount = 0 -- 188
		end, -- 186
		root = root -- 190
	} -- 190
end -- 131
return ____exports -- 131
-- [ts]: Trajectory.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 20
local BlendFunc = ____Dora.BlendFunc -- 20
local Color = ____Dora.Color -- 20
local DrawNode = ____Dora.DrawNode -- 20
local Node = ____Dora.Node -- 20
local Vec2 = ____Dora.Vec2 -- 20
local ____Projection = require("game.Projection") -- 21
local projectPrepared = ____Projection.projectPrepared -- 21
local ____Config = require("game.Config") -- 23
local PlaneToWorldX = ____Config.PlaneToWorldX -- 23
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 23
--- 把平面采样点批量投影成覆盖层坐标。
function ____exports.projectPolyline(points, y, basis) -- 26
	local out = {} -- 27
	for ____, p in ipairs(points) do -- 28
		do -- 28
			local world = {x = p.x * PlaneToWorldX, y = y, z = p.y * PlaneToWorldZ} -- 29
			local proj = projectPrepared(world, basis) -- 34
			if proj == nil then -- 34
				goto __continue3 -- 35
			end -- 35
			out[#out + 1] = Vec2(proj.x, proj.y) -- 37
		end -- 37
		::__continue3:: -- 37
	end -- 37
	return out -- 39
end -- 26
function ____exports.defaultOptions() -- 76
	return { -- 77
		y = 0.02, -- 78
		maxPoints = 240, -- 79
		predictRadius = 2.5, -- 80
		trailRadius = 3.5, -- 81
		predictColor = Color(120, 200, 255, 180), -- 83
		trailColor = Color(255, 236, 170, 235) -- 85
	} -- 85
end -- 76
--- 均匀抽稀到不超过 maxPoints 个点（保留首尾）。
function ____exports.decimate(points, maxPoints) -- 90
	if maxPoints <= 0 or #points <= maxPoints then -- 90
		return points -- 91
	end -- 91
	local out = {} -- 92
	local step = (#points - 1) / (maxPoints - 1) -- 93
	do -- 93
		local i = 0 -- 94
		while i < maxPoints do -- 94
			local idx = math.floor(i * step) -- 95
			local safe = idx < #points and idx or #points - 1 -- 96
			out[#out + 1] = points[safe + 1] -- 97
			i = i + 1 -- 94
		end -- 94
	end -- 94
	out[maxPoints] = points[#points] -- 100
	return out -- 101
end -- 90
--- 创建轨迹视图。
-- 
-- @param parent 挂载的父节点。必须是 **2D** 节点（通常是 `Director.ui`）——
-- `Director.entry` 是 `View3D`，不能挂 2D 绘制节点。
function ____exports.createTrajectoryView(parent, opts) -- 110
	local options = opts ~= nil and opts or ____exports.defaultOptions() -- 114
	local root = Node() -- 117
	local trailDraw = DrawNode() -- 120
	trailDraw.blendFunc = BlendFunc("One", "One") -- 122
	root:addChild(trailDraw) -- 123
	local predictDraw = DrawNode() -- 125
	predictDraw.blendFunc = BlendFunc("One", "One") -- 126
	root:addChild(predictDraw) -- 127
	parent:addChild(root) -- 129
	local trailCount = 0 -- 131
	--- 把投影后的顶点用圆头线段连成一条光滑折线。
	local function drawPolyline(draw, verts, radius, color) -- 134
		draw:clear() -- 135
		do -- 135
			local i = 1 -- 136
			while i < #verts do -- 136
				draw:drawSegment(verts[i], verts[i + 1], radius, color) -- 137
				i = i + 1 -- 136
			end -- 136
		end -- 136
		for ____, v in ipairs(verts) do -- 140
			draw:drawDot(v, radius, color) -- 141
		end -- 141
	end -- 134
	return { -- 145
		setPrediction = function(self, points, basis) -- 146
			local verts = ____exports.projectPolyline( -- 147
				____exports.decimate(points, options.maxPoints), -- 147
				options.y, -- 147
				basis -- 147
			) -- 147
			drawPolyline(predictDraw, verts, options.predictRadius, options.predictColor) -- 148
		end, -- 146
		clearPrediction = function(self) -- 150
			predictDraw:clear() -- 151
		end, -- 150
		setTrail = function(self, points, basis) -- 153
			if #points < 2 then -- 153
				trailDraw:clear() -- 155
				trailCount = 0 -- 156
				return -- 157
			end -- 157
			if #points == trailCount then -- 157
				return -- 160
			end -- 160
			trailCount = #points -- 161
			local verts = ____exports.projectPolyline( -- 162
				____exports.decimate(points, options.maxPoints), -- 162
				options.y, -- 162
				basis -- 162
			) -- 162
			drawPolyline(trailDraw, verts, options.trailRadius, options.trailColor) -- 163
		end, -- 153
		clearTrail = function(self) -- 165
			trailDraw:clear() -- 166
			trailCount = 0 -- 167
		end, -- 165
		root = root -- 169
	} -- 169
end -- 110
return ____exports -- 110
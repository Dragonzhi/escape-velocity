-- [ts]: Scene.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 16
local Color = ____Dora.Color -- 16
local Color3 = ____Dora.Color3 -- 16
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 16
local Model3D = ____Dora.Model3D -- 16
local Vec3 = ____Dora.Vec3 -- 16
local ____Config = require("game.Config") -- 17
local PlaneToWorldX = ____Config.PlaneToWorldX -- 17
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 17
local ____Gravity = require("game.Gravity") -- 18
local bodyPositionAt = ____Gravity.bodyPositionAt -- 18
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 21
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 22
end -- 21
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 98
	local ____options_0 = options -- 99
	local root = ____options_0.root -- 99
	local bodies = ____options_0.bodies -- 99
	local visuals = ____options_0.visuals -- 99
	local probeStart = ____options_0.probeStart -- 99
	local light = DirectionalLight3D() -- 102
	light.color = Color3(16774106) -- 103
	light.intensity = 3.2 -- 104
	light.angleX = -48 -- 105
	light.angleY = 28 -- 106
	root:addChild(light) -- 107
	local planets = {} -- 110
	do -- 110
		local i = 0 -- 111
		while i < #bodies do -- 111
			local def = bodies[i + 1] -- 112
			local vis = visuals[i + 1] -- 113
			local sphere = Model3D(options.spherePath) -- 115
			if sphere == nil then -- 115
				return nil -- 116
			end -- 116
			local scale = vis.displayRadius -- 118
			sphere.scale = Vec3(scale, scale, scale) -- 119
			local mat = sphere:getMaterial(0) -- 122
			if mat ~= nil then -- 122
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 124
			end -- 124
			root:addChild(sphere) -- 127
			local ringNode = nil -- 129
			if vis.ring then -- 129
				local ring = Model3D(options.ringPath) -- 131
				if ring ~= nil then -- 131
					local rs = scale * 1.5 -- 134
					ring.scale = Vec3(rs, rs, rs) -- 135
					root:addChild(ring) -- 136
					ringNode = ring -- 137
				end -- 137
			end -- 137
			planets[#planets + 1] = {body = sphere, ring = ringNode, def = def} -- 141
			i = i + 1 -- 111
		end -- 111
	end -- 111
	local probeModel = Model3D(options.probePath) -- 145
	if probeModel == nil then -- 145
		return nil -- 146
	end -- 146
	probeModel.scale = Vec3(options.probeScale, options.probeScale, options.probeScale) -- 147
	root:addChild(probeModel) -- 148
	local probeNode = probeModel -- 150
	local function syncBodies(t) -- 153
		for ____, p in ipairs(planets) do -- 154
			local wp = ____exports.planeToWorld( -- 155
				bodyPositionAt(p.def, t), -- 155
				0 -- 155
			) -- 155
			p.body.position = wp -- 156
			if p.ring ~= nil then -- 156
				p.ring.position = wp -- 157
			end -- 157
		end -- 157
	end -- 153
	local function syncProbe(p) -- 161
		probeNode.position = ____exports.planeToWorld(p, 0) -- 162
	end -- 161
	local function faceVelocity(v) -- 167
		local wx = v.x * PlaneToWorldX -- 168
		local wz = v.y * PlaneToWorldZ -- 169
		if wx * wx + wz * wz < 1e-12 then -- 169
			return -- 170
		end -- 170
		probeNode.angleY = math.atan(-wz, wx) * 180 / math.pi -- 171
	end -- 167
	syncBodies(0) -- 175
	syncProbe(probeStart) -- 176
	return { -- 178
		syncBodies = syncBodies, -- 178
		syncProbe = syncProbe, -- 178
		faceVelocity = faceVelocity, -- 178
		probe = probeNode, -- 178
		planets = planets -- 178
	} -- 178
end -- 98
return ____exports -- 98
-- [ts]: Scene.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 22
local Color = ____Dora.Color -- 22
local Color3 = ____Dora.Color3 -- 22
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 22
local Model3D = ____Dora.Model3D -- 22
local Vec3 = ____Dora.Vec3 -- 22
local ____Config = require("game.Config") -- 23
local PlaneToWorldX = ____Config.PlaneToWorldX -- 23
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 23
local ____Gravity = require("game.Gravity") -- 24
local bodyPositionAt = ____Gravity.bodyPositionAt -- 24
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 27
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 28
end -- 27
local MODEL_RADIUS = { -- 46
	{name = "Planet_Earth", k = 1.0343}, -- 47
	{name = "Planet_Mars", k = 1.0227}, -- 48
	{name = "Planet_Venus", k = 1.0215}, -- 49
	{name = "Planet_Jupiter", k = 1}, -- 50
	{name = "Planet_Saturn", k = 0.9837}, -- 51
	{name = "Planet_Neptune", k = 1.017} -- 52
} -- 52
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
local function modelRadius(name) -- 56
	do -- 56
		local i = 0 -- 57
		while i < #MODEL_RADIUS do -- 57
			if MODEL_RADIUS[i + 1].name == name then -- 57
				return MODEL_RADIUS[i + 1].k -- 58
			end -- 58
			i = i + 1 -- 57
		end -- 57
	end -- 57
	return 1 -- 60
end -- 56
--- 探测器朝向偏移（度）。
-- 
-- 实测（Test/ModelCalibProbe.ts → .agent/test-results/s31-orient.txt）：
-- - 引擎的 angleY 把**局部 +X** 旋到世界 (cos θ, 0, -sin θ)、局部 +Z 旋到 (sin θ, 0, cos θ)——
--   用已知朝 +X 的旧 Probe.gltf（正四面体）在 yaw=0/90/180/270 读**世界**包围盒验证
--   （yaw=0: 顶点在 world x=+1；yaw=90: 顶点在 world z=-1）。所以 faceVelocity 里
--   现有的 atan2(-wz, wx) 含义就是“让局部 +X 对准速度方向”。
-- - Probe_Voyager_v1.glb 的体轴**不是 X 而是 Z**（俯视 yaw=0 实测）：
--   抛物面天线是一块朝上的圆盘（直径 3.227 = 模型最长边），
--   两根粗主杆沿 **+Z** 伸出（到 z=+1.00，图中朝屏幕下方），
--   一根细长磁强计杆沿 **-Z** 伸出（到 z=-1.85，图中朝屏幕上方）。
--   ⇒ 让 **-Z（细杆）朝前、+Z（两根主杆）拖在后**，就是飞船“在飞”的样子。
--   即需要 局部 +Z → 速度的反方向：θ = θ_faceVelocity - 90°。
local ProbeYawOffsetDeg = -90 -- 78
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 156
	local ____options_0 = options -- 157
	local root = ____options_0.root -- 157
	local bodies = ____options_0.bodies -- 157
	local visuals = ____options_0.visuals -- 157
	local probeStart = ____options_0.probeStart -- 157
	local light = DirectionalLight3D() -- 160
	light.color = Color3(16774106) -- 161
	light.intensity = 3.2 -- 162
	light.angleX = -48 -- 163
	light.angleY = 28 -- 164
	root:addChild(light) -- 165
	local planets = {} -- 168
	do -- 168
		local i = 0 -- 169
		while i < #bodies do -- 169
			local def = bodies[i + 1] -- 170
			local vis = visuals[i + 1] -- 171
			local bodyModel = nil -- 174
			local k = 1 -- 175
			local modelName = vis.model ~= nil and vis.model or "" -- 176
			if modelName ~= "" then -- 176
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 178
				if loaded ~= nil then -- 178
					bodyModel = loaded -- 180
					k = modelRadius(modelName) -- 181
				end -- 181
			end -- 181
			if bodyModel == nil then -- 181
				bodyModel = Model3D(options.spherePath) -- 185
				k = 1 -- 186
			end -- 186
			if bodyModel == nil then -- 186
				return nil -- 188
			end -- 188
			local scale = vis.displayRadius / k -- 191
			bodyModel.scale = Vec3(scale, scale, scale) -- 192
			local mi = 0 -- 195
			while mi < 64 do -- 195
				local mat = bodyModel:getMaterial(mi) -- 197
				if mat == nil then -- 197
					break -- 198
				end -- 198
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 199
				mi = mi + 1 -- 200
			end -- 200
			root:addChild(bodyModel) -- 203
			local ringNode = nil -- 206
			if modelName == "" and vis.ring then -- 206
				local ring = Model3D(options.ringPath) -- 208
				if ring ~= nil then -- 208
					local rs = scale * 1.5 -- 211
					ring.scale = Vec3(rs, rs, rs) -- 212
					root:addChild(ring) -- 213
					ringNode = ring -- 214
				end -- 214
			end -- 214
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 218
			i = i + 1 -- 169
		end -- 169
	end -- 169
	local probeModel = Model3D(options.probePath) -- 222
	if probeModel == nil then -- 222
		return nil -- 223
	end -- 223
	probeModel.scale = Vec3(options.probeScale, options.probeScale, options.probeScale) -- 224
	root:addChild(probeModel) -- 225
	local probeNode = probeModel -- 227
	local probeRadius = 1.5 * options.probeScale -- 234
	do -- 234
		local function ____catch(e) -- 234
			print("[escape-velocity] probe bounds unavailable, using fallback radius " .. __TS__NumberToFixed(probeRadius, 2)) -- 246
		end -- 246
		local ____try, ____hasReturned = pcall(function() -- 246
			local lo = probeModel:getLocalBoundsMin() -- 236
			local hi = probeModel:getLocalBoundsMax() -- 237
			local ex = hi.x - lo.x -- 238
			local ey = hi.y - lo.y -- 239
			local ez = hi.z - lo.z -- 240
			local maxDim = ex > ey and ex or ey -- 241
			if ez > maxDim then -- 241
				maxDim = ez -- 242
			end -- 242
			if maxDim > 0 then -- 242
				probeRadius = 0.5 * maxDim * options.probeScale * 1.1 -- 243
			end -- 243
		end) -- 243
		if not ____try then -- 243
			____catch(____hasReturned) -- 243
		end -- 243
	end -- 243
	local shell = Model3D("Assets/Model/StarShell.gltf") -- 253
	if shell ~= nil then -- 253
		local sm = shell:getMaterial(0) -- 255
		if sm ~= nil then -- 255
			sm.baseColor = Color(255, 255, 255, 255) -- 257
			sm.emissive = Color3(16777215) -- 258
			sm.roughness = 1 -- 259
			sm.metallic = 0 -- 260
		end -- 260
		root:addChild(shell) -- 262
	end -- 262
	local shellBright = Model3D("Assets/Model/StarShellBright.gltf") -- 264
	if shellBright ~= nil then -- 264
		local bm = shellBright:getMaterial(0) -- 266
		if bm ~= nil then -- 266
			bm.baseColor = Color(255, 255, 255, 255) -- 268
			bm.emissive = Color3(16773840) -- 269
			bm.roughness = 1 -- 270
			bm.metallic = 0 -- 271
		end -- 271
		root:addChild(shellBright) -- 273
	end -- 273
	local function syncBodies(t) -- 277
		for ____, p in ipairs(planets) do -- 278
			local wp = ____exports.planeToWorld( -- 279
				bodyPositionAt(p.def, t), -- 279
				0 -- 279
			) -- 279
			p.body.position = wp -- 280
			if p.ring ~= nil then -- 280
				p.ring.position = wp -- 281
			end -- 281
		end -- 281
	end -- 277
	local function syncProbe(p) -- 285
		probeNode.position = ____exports.planeToWorld(p, 0) -- 286
	end -- 285
	local function faceVelocity(v) -- 292
		local wx = v.x * PlaneToWorldX -- 293
		local wz = v.y * PlaneToWorldZ -- 294
		if wx * wx + wz * wz < 1e-12 then -- 294
			return -- 295
		end -- 295
		probeNode.angleY = math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 296
	end -- 292
	syncBodies(0) -- 300
	syncProbe(probeStart) -- 301
	return { -- 303
		syncBodies = syncBodies, -- 303
		syncProbe = syncProbe, -- 303
		faceVelocity = faceVelocity, -- 303
		probe = probeNode, -- 303
		planets = planets, -- 303
		probeRadius = probeRadius -- 303
	} -- 303
end -- 156
return ____exports -- 156
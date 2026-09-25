-- [ts]: Scene.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 23
local Color = ____Dora.Color -- 23
local Color3 = ____Dora.Color3 -- 23
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 23
local Model3D = ____Dora.Model3D -- 23
local Texture2D = ____Dora.Texture2D -- 23
local Vec3 = ____Dora.Vec3 -- 23
local ____Config = require("game.Config") -- 24
local PlaneToWorldX = ____Config.PlaneToWorldX -- 24
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 24
local ____Gravity = require("game.Gravity") -- 25
local bodyPositionAt = ____Gravity.bodyPositionAt -- 25
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 28
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 29
end -- 28
local MODEL_RADIUS = { -- 47
	{name = "Planet_Earth", k = 1.0343}, -- 48
	{name = "Planet_Mars", k = 1.0227}, -- 49
	{name = "Planet_Venus", k = 1.0215}, -- 50
	{name = "Planet_Jupiter", k = 1}, -- 51
	{name = "Planet_Saturn", k = 0.9837}, -- 52
	{name = "Planet_Neptune", k = 1.017} -- 53
} -- 53
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
local function modelRadius(name) -- 57
	do -- 57
		local i = 0 -- 58
		while i < #MODEL_RADIUS do -- 58
			if MODEL_RADIUS[i + 1].name == name then -- 58
				return MODEL_RADIUS[i + 1].k -- 59
			end -- 59
			i = i + 1 -- 58
		end -- 58
	end -- 58
	return 1 -- 61
end -- 57
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
local ProbeYawOffsetDeg = -90 -- 79
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 159
	local ____options_0 = options -- 160
	local root = ____options_0.root -- 160
	local bodies = ____options_0.bodies -- 160
	local visuals = ____options_0.visuals -- 160
	local probeStart = ____options_0.probeStart -- 160
	local light = DirectionalLight3D() -- 163
	light.color = Color3(16774106) -- 164
	light.intensity = 3.2 -- 165
	light.angleX = -48 -- 166
	light.angleY = 28 -- 167
	root:addChild(light) -- 168
	local planets = {} -- 171
	do -- 171
		local i = 0 -- 172
		while i < #bodies do -- 172
			local def = bodies[i + 1] -- 173
			local vis = visuals[i + 1] -- 174
			local bodyModel = nil -- 177
			local k = 1 -- 178
			local modelName = vis.model ~= nil and vis.model or "" -- 179
			if modelName ~= "" then -- 179
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 181
				if loaded ~= nil then -- 181
					bodyModel = loaded -- 183
					k = modelRadius(modelName) -- 184
				end -- 184
			end -- 184
			if bodyModel == nil then -- 184
				bodyModel = Model3D(options.spherePath) -- 188
				k = 1 -- 189
			end -- 189
			if bodyModel == nil then -- 189
				return nil -- 191
			end -- 191
			local scale = vis.displayRadius / k -- 194
			bodyModel.scale = Vec3(scale, scale, scale) -- 195
			local mi = 0 -- 198
			while mi < 64 do -- 198
				local mat = bodyModel:getMaterial(mi) -- 200
				if mat == nil then -- 200
					break -- 201
				end -- 201
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 202
				mi = mi + 1 -- 203
			end -- 203
			root:addChild(bodyModel) -- 206
			local ringNode = nil -- 209
			if modelName == "" and vis.ring then -- 209
				local ring = Model3D(options.ringPath) -- 211
				if ring ~= nil then -- 211
					local rs = scale * 1.5 -- 214
					ring.scale = Vec3(rs, rs, rs) -- 215
					root:addChild(ring) -- 216
					ringNode = ring -- 217
				end -- 217
			end -- 217
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 221
			i = i + 1 -- 172
		end -- 172
	end -- 172
	local probeModel = Model3D(options.probePath) -- 225
	if probeModel == nil then -- 225
		return nil -- 226
	end -- 226
	probeModel.scale = Vec3(options.probeScale, options.probeScale, options.probeScale) -- 227
	root:addChild(probeModel) -- 228
	local probeNode = probeModel -- 230
	local probeRadius = 1.5 * options.probeScale -- 237
	do -- 237
		local function ____catch(e) -- 237
			print("[escape-velocity] probe bounds unavailable, using fallback radius " .. __TS__NumberToFixed(probeRadius, 2)) -- 249
		end -- 249
		local ____try, ____hasReturned = pcall(function() -- 249
			local lo = probeModel:getLocalBoundsMin() -- 239
			local hi = probeModel:getLocalBoundsMax() -- 240
			local ex = hi.x - lo.x -- 241
			local ey = hi.y - lo.y -- 242
			local ez = hi.z - lo.z -- 243
			local maxDim = ex > ey and ex or ey -- 244
			if ez > maxDim then -- 244
				maxDim = ez -- 245
			end -- 245
			if maxDim > 0 then -- 245
				probeRadius = 0.5 * maxDim * options.probeScale * 1.1 -- 246
			end -- 246
		end) -- 246
		if not ____try then -- 246
			____catch(____hasReturned) -- 246
		end -- 246
	end -- 246
	local BackdropDist = 600 -- 262
	local BackdropHalf = 560 -- 263
	local backdropNode = nil -- 264
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 265
	if backdrop ~= nil then -- 265
		local tex = Texture2D("Assets/Image/starfield.png") -- 267
		local bm = backdrop:getMaterial(0) -- 268
		if bm ~= nil and tex ~= nil then -- 268
			bm:setBaseColorTexture(tex) -- 271
			bm:setEmissiveTexture(tex) -- 272
			bm.baseColor = Color(255, 255, 255, 255) -- 273
			bm.emissive = Color3(16777215) -- 274
			bm.roughness = 1 -- 275
			bm.metallic = 0 -- 276
		end -- 276
		backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 278
		backdrop.angleX = -45 -- 281
		backdrop.position = Vec3(0, 0, -BackdropDist) -- 282
		root:addChild(backdrop) -- 283
		backdropNode = backdrop -- 284
	end -- 284
	local function syncBodies(t) -- 288
		for ____, p in ipairs(planets) do -- 289
			local wp = ____exports.planeToWorld( -- 290
				bodyPositionAt(p.def, t), -- 290
				0 -- 290
			) -- 290
			p.body.position = wp -- 291
			if p.ring ~= nil then -- 291
				p.ring.position = wp -- 292
			end -- 292
		end -- 292
	end -- 288
	local function syncProbe(p) -- 296
		probeNode.position = ____exports.planeToWorld(p, 0) -- 297
	end -- 296
	local function faceVelocity(v) -- 303
		local wx = v.x * PlaneToWorldX -- 304
		local wz = v.y * PlaneToWorldZ -- 305
		if wx * wx + wz * wz < 1e-12 then -- 305
			return -- 306
		end -- 306
		probeNode.angleY = math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 307
	end -- 303
	local function syncBackdrop(eye, target) -- 311
		if backdropNode == nil then -- 311
			return -- 312
		end -- 312
		local dx = target.x - eye.x -- 313
		local dy = target.y - eye.y -- 314
		local dz = target.z - eye.z -- 315
		local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 316
		if len < 0.000001 then -- 316
			return -- 317
		end -- 317
		local s = BackdropDist / len -- 318
		backdropNode.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 319
	end -- 311
	syncBodies(0) -- 323
	syncProbe(probeStart) -- 324
	return { -- 326
		syncBodies = syncBodies, -- 326
		syncProbe = syncProbe, -- 326
		faceVelocity = faceVelocity, -- 326
		syncBackdrop = syncBackdrop, -- 326
		probe = probeNode, -- 326
		planets = planets, -- 326
		probeRadius = probeRadius -- 326
	} -- 326
end -- 159
return ____exports -- 159
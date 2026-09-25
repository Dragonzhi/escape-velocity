-- [ts]: Scene.ts
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Color = ____Dora.Color -- 26
local Color3 = ____Dora.Color3 -- 26
local Content = ____Dora.Content -- 26
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 26
local Model3D = ____Dora.Model3D -- 26
local Node3D = ____Dora.Node3D -- 26
local Texture2D = ____Dora.Texture2D -- 26
local Vec3 = ____Dora.Vec3 -- 26
local ____Config = require("game.Config") -- 27
local PlaneToWorldX = ____Config.PlaneToWorldX -- 27
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 27
local ____Gravity = require("game.Gravity") -- 28
local bodyPositionAt = ____Gravity.bodyPositionAt -- 28
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 31
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 32
end -- 31
local MODEL_RADIUS = { -- 50
	{name = "Planet_Earth", k = 1.0343}, -- 51
	{name = "Planet_Mars", k = 1.0227}, -- 52
	{name = "Planet_Venus", k = 1.0215}, -- 53
	{name = "Planet_Jupiter", k = 1}, -- 54
	{name = "Planet_Saturn", k = 0.9837}, -- 55
	{name = "Planet_Neptune", k = 1.017} -- 56
} -- 56
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
local function modelRadius(name) -- 60
	do -- 60
		local i = 0 -- 61
		while i < #MODEL_RADIUS do -- 61
			if MODEL_RADIUS[i + 1].name == name then -- 61
				return MODEL_RADIUS[i + 1].k -- 62
			end -- 62
			i = i + 1 -- 61
		end -- 61
	end -- 61
	return 1 -- 64
end -- 60
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
local ProbeYawOffsetDeg = -90 -- 82
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
local AntennaPivotY = 0.2 -- 89
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 174
	local ____options_0 = options -- 175
	local root = ____options_0.root -- 175
	local bodies = ____options_0.bodies -- 175
	local visuals = ____options_0.visuals -- 175
	local probeStart = ____options_0.probeStart -- 175
	local light = DirectionalLight3D() -- 182
	light.color = Color3(16774106) -- 183
	light.intensity = 3.6 -- 184
	light.angleX = -42 -- 185
	light.angleY = 75 -- 186
	root:addChild(light) -- 187
	local planets = {} -- 190
	do -- 190
		local i = 0 -- 191
		while i < #bodies do -- 191
			local def = bodies[i + 1] -- 192
			local vis = visuals[i + 1] -- 193
			local bodyModel = nil -- 196
			local k = 1 -- 197
			local modelName = vis.model ~= nil and vis.model or "" -- 198
			if modelName ~= "" then -- 198
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 200
				if loaded ~= nil then -- 200
					bodyModel = loaded -- 202
					k = modelRadius(modelName) -- 203
				end -- 203
			end -- 203
			if bodyModel == nil then -- 203
				bodyModel = Model3D(options.spherePath) -- 207
				k = 1 -- 208
			end -- 208
			if bodyModel == nil then -- 208
				return nil -- 210
			end -- 210
			local scale = vis.displayRadius / k -- 213
			bodyModel.scale = Vec3(scale, scale, scale) -- 214
			local mi = 0 -- 217
			while mi < 64 do -- 217
				local mat = bodyModel:getMaterial(mi) -- 219
				if mat == nil then -- 219
					break -- 220
				end -- 220
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 221
				mi = mi + 1 -- 222
			end -- 222
			root:addChild(bodyModel) -- 225
			local ringNode = nil -- 228
			if modelName == "" and vis.ring then -- 228
				local ring = Model3D(options.ringPath) -- 230
				if ring ~= nil then -- 230
					local rs = scale * 1.5 -- 233
					ring.scale = Vec3(rs, rs, rs) -- 234
					root:addChild(ring) -- 235
					ringNode = ring -- 236
				end -- 236
			end -- 236
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 240
			i = i + 1 -- 191
		end -- 191
	end -- 191
	if options.home ~= nil then -- 191
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 248
		if earth ~= nil then -- 248
			local ke = modelRadius("Planet_Earth") -- 250
			local es = 1.15 / ke -- 251
			earth.scale = Vec3(es, es, es) -- 252
			local emi = 0 -- 253
			while emi < 64 do -- 253
				local em = earth:getMaterial(emi) -- 255
				if em == nil then -- 255
					break -- 256
				end -- 256
				em.baseColor = Color(110, 170, 235, 255) -- 257
				em.emissive = Color3(792098) -- 259
				emi = emi + 1 -- 260
			end -- 260
			earth.position = ____exports.planeToWorld(options.home, 0) -- 262
			root:addChild(earth) -- 263
		end -- 263
	end -- 263
	local probeScale = options.probeScale -- 272
	local bodyModel = options.probeBodyPath ~= nil and Content:exist(options.probeBodyPath) and Model3D(options.probeBodyPath) or nil -- 276
	local antennaModel = bodyModel ~= nil and options.probeAntennaPath ~= nil and Content:exist(options.probeAntennaPath) and Model3D(options.probeAntennaPath) or nil -- 279
	local singleModel = bodyModel == nil and Model3D(options.probePath) or nil -- 282
	if bodyModel == nil and singleModel == nil then -- 282
		return nil -- 283
	end -- 283
	local probeNode = Node3D() -- 285
	root:addChild(probeNode) -- 286
	if bodyModel ~= nil then -- 286
		bodyModel.scale = Vec3(probeScale, probeScale, probeScale) -- 289
		probeNode:addChild(bodyModel) -- 290
	end -- 290
	if singleModel ~= nil then -- 290
		singleModel.scale = Vec3(probeScale, probeScale, probeScale) -- 293
		probeNode:addChild(singleModel) -- 294
	end -- 294
	local antennaPivot = nil -- 299
	if bodyModel ~= nil and antennaModel ~= nil then -- 299
		antennaModel.scale = Vec3(probeScale, probeScale, probeScale) -- 301
		antennaPivot = Node3D() -- 302
		antennaPivot.position = Vec3(0, AntennaPivotY * probeScale, 0) -- 303
		antennaPivot:addChild(antennaModel) -- 304
		probeNode:addChild(antennaPivot) -- 305
	end -- 305
	local probeRadius = 0.5 * 3.227 * probeScale * 1.1 -- 314
	local bodyYawDeg = 0 -- 317
	local BackdropDist = 600 -- 329
	local BackdropHalf = 560 -- 330
	local backdropNode = nil -- 331
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 332
	if backdrop ~= nil then -- 332
		local tex = Texture2D("Assets/Image/starfield.png") -- 334
		local bm = backdrop:getMaterial(0) -- 335
		if bm ~= nil and tex ~= nil then -- 335
			bm:setEmissiveTexture(tex) -- 339
			bm.baseColor = Color(0, 0, 0, 255) -- 340
			bm.emissive = Color3(9211020) -- 341
			bm.roughness = 1 -- 342
			bm.metallic = 0 -- 343
		end -- 343
		backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 345
		backdrop.angleX = -45 -- 348
		backdrop.position = Vec3(0, 0, -BackdropDist) -- 349
		root:addChild(backdrop) -- 350
		backdropNode = backdrop -- 351
	end -- 351
	local function syncBodies(t) -- 355
		for ____, p in ipairs(planets) do -- 356
			local wp = ____exports.planeToWorld( -- 357
				bodyPositionAt(p.def, t), -- 357
				0 -- 357
			) -- 357
			p.body.position = wp -- 358
			if p.ring ~= nil then -- 358
				p.ring.position = wp -- 359
			end -- 359
		end -- 359
	end -- 355
	local function syncProbe(p) -- 363
		probeNode.position = ____exports.planeToWorld(p, 0) -- 364
		if antennaPivot ~= nil and options.home ~= nil then -- 364
			local ex = (options.home.x - p.x) * PlaneToWorldX -- 370
			local ez = (options.home.y - p.y) * PlaneToWorldZ -- 371
			local dist = math.sqrt(ex * ex + ez * ez) -- 372
			if dist > 0.0001 then -- 372
				local tiltFactor = (dist - 0.5) / 3 -- 374
				if tiltFactor < 0 then -- 374
					tiltFactor = 0 -- 375
				end -- 375
				if tiltFactor > 1 then -- 375
					tiltFactor = 1 -- 376
				end -- 376
				local tilt = 46 * tiltFactor -- 377
				local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 378
				antennaPivot.angleY = phiWorld - bodyYawDeg -- 379
				antennaPivot.angleZ = -tilt -- 380
			end -- 380
		end -- 380
	end -- 363
	local function faceVelocity(v) -- 388
		local wx = v.x * PlaneToWorldX -- 389
		local wz = v.y * PlaneToWorldZ -- 390
		if wx * wx + wz * wz < 1e-12 then -- 390
			return -- 391
		end -- 391
		bodyYawDeg = math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 392
		probeNode.angleY = bodyYawDeg -- 393
	end -- 388
	local function syncBackdrop(eye, target) -- 397
		if backdropNode == nil then -- 397
			return -- 398
		end -- 398
		local dx = target.x - eye.x -- 399
		local dy = target.y - eye.y -- 400
		local dz = target.z - eye.z -- 401
		local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 402
		if len < 0.000001 then -- 402
			return -- 403
		end -- 403
		local s = BackdropDist / len -- 404
		backdropNode.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 405
	end -- 397
	syncBodies(0) -- 409
	syncProbe(probeStart) -- 410
	return { -- 412
		syncBodies = syncBodies, -- 412
		syncProbe = syncProbe, -- 412
		faceVelocity = faceVelocity, -- 412
		syncBackdrop = syncBackdrop, -- 412
		probe = probeNode, -- 412
		planets = planets, -- 412
		probeRadius = probeRadius -- 412
	} -- 412
end -- 174
return ____exports -- 174
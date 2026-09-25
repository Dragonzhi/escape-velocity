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
function ____exports.buildScene(options) -- 176
	local ____options_0 = options -- 177
	local root = ____options_0.root -- 177
	local bodies = ____options_0.bodies -- 177
	local visuals = ____options_0.visuals -- 177
	local probeStart = ____options_0.probeStart -- 177
	local light = DirectionalLight3D() -- 184
	light.color = Color3(16774106) -- 185
	light.intensity = 3.6 -- 186
	light.angleX = -42 -- 187
	light.angleY = 75 -- 188
	root:addChild(light) -- 189
	local planets = {} -- 192
	do -- 192
		local i = 0 -- 193
		while i < #bodies do -- 193
			local def = bodies[i + 1] -- 194
			local vis = visuals[i + 1] -- 195
			local bodyModel = nil -- 198
			local k = 1 -- 199
			local modelName = vis.model ~= nil and vis.model or "" -- 200
			if modelName ~= "" then -- 200
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 202
				if loaded ~= nil then -- 202
					bodyModel = loaded -- 204
					k = modelRadius(modelName) -- 205
				end -- 205
			end -- 205
			if bodyModel == nil then -- 205
				bodyModel = Model3D(options.spherePath) -- 209
				k = 1 -- 210
			end -- 210
			if bodyModel == nil then -- 210
				return nil -- 212
			end -- 212
			local scale = vis.displayRadius / k -- 215
			bodyModel.scale = Vec3(scale, scale, scale) -- 216
			local mi = 0 -- 219
			while mi < 64 do -- 219
				local mat = bodyModel:getMaterial(mi) -- 221
				if mat == nil then -- 221
					break -- 222
				end -- 222
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 223
				mi = mi + 1 -- 224
			end -- 224
			root:addChild(bodyModel) -- 227
			local ringNode = nil -- 230
			if modelName == "" and vis.ring then -- 230
				local ring = Model3D(options.ringPath) -- 232
				if ring ~= nil then -- 232
					local rs = scale * 1.5 -- 235
					ring.scale = Vec3(rs, rs, rs) -- 236
					root:addChild(ring) -- 237
					ringNode = ring -- 238
				end -- 238
			end -- 238
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 242
			i = i + 1 -- 193
		end -- 193
	end -- 193
	if options.home ~= nil then -- 193
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 250
		if earth ~= nil then -- 250
			local ke = modelRadius("Planet_Earth") -- 252
			local es = 1.15 / ke -- 253
			earth.scale = Vec3(es, es, es) -- 254
			local emi = 0 -- 255
			while emi < 64 do -- 255
				local em = earth:getMaterial(emi) -- 257
				if em == nil then -- 257
					break -- 258
				end -- 258
				em.baseColor = Color(110, 170, 235, 255) -- 259
				em.emissive = Color3(792098) -- 261
				emi = emi + 1 -- 262
			end -- 262
			earth.position = ____exports.planeToWorld(options.home, 0) -- 264
			root:addChild(earth) -- 265
		end -- 265
	end -- 265
	local probeScale = options.probeScale -- 274
	local bodyModel = options.probeBodyPath ~= nil and Content:exist(options.probeBodyPath) and Model3D(options.probeBodyPath) or nil -- 278
	local antennaModel = bodyModel ~= nil and options.probeAntennaPath ~= nil and Content:exist(options.probeAntennaPath) and Model3D(options.probeAntennaPath) or nil -- 281
	local singleModel = bodyModel == nil and Model3D(options.probePath) or nil -- 284
	if bodyModel == nil and singleModel == nil then -- 284
		return nil -- 285
	end -- 285
	local probeNode = Node3D() -- 287
	root:addChild(probeNode) -- 288
	if bodyModel ~= nil then -- 288
		bodyModel.scale = Vec3(probeScale, probeScale, probeScale) -- 291
		probeNode:addChild(bodyModel) -- 292
	end -- 292
	if singleModel ~= nil then -- 292
		singleModel.scale = Vec3(probeScale, probeScale, probeScale) -- 295
		probeNode:addChild(singleModel) -- 296
	end -- 296
	if bodyModel ~= nil and antennaModel ~= nil then -- 296
		antennaModel.scale = Vec3(probeScale, probeScale, probeScale) -- 305
		antennaModel.position = Vec3(0, AntennaPivotY * probeScale, 0) -- 306
		probeNode:addChild(antennaModel) -- 307
	end -- 307
	local probeRadius = 0.5 * 3.227 * probeScale * 1.1 -- 316
	local bodyYawDeg = 0 -- 319
	local BackdropDist = 600 -- 331
	local BackdropHalf = 560 -- 332
	local backdropNode = nil -- 333
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 334
	if backdrop ~= nil then -- 334
		local tex = Texture2D("Assets/Image/starfield.png") -- 336
		local bm = backdrop:getMaterial(0) -- 337
		if bm ~= nil and tex ~= nil then -- 337
			bm:setEmissiveTexture(tex) -- 341
			bm.baseColor = Color(0, 0, 0, 255) -- 342
			bm.emissive = Color3(9211020) -- 343
			bm.roughness = 1 -- 344
			bm.metallic = 0 -- 345
		end -- 345
		backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 347
		backdrop.angleX = -45 -- 350
		backdrop.position = Vec3(0, 0, -BackdropDist) -- 351
		root:addChild(backdrop) -- 352
		backdropNode = backdrop -- 353
	end -- 353
	local function syncBodies(t) -- 357
		for ____, p in ipairs(planets) do -- 358
			local wp = ____exports.planeToWorld( -- 359
				bodyPositionAt(p.def, t), -- 359
				0 -- 359
			) -- 359
			p.body.position = wp -- 360
			if p.ring ~= nil then -- 360
				p.ring.position = wp -- 361
			end -- 361
		end -- 361
	end -- 357
	local function syncProbe(p) -- 365
		probeNode.position = ____exports.planeToWorld(p, 0) -- 366
		if antennaModel ~= nil and options.home ~= nil then -- 366
			local ex = (options.home.x - p.x) * PlaneToWorldX -- 372
			local ez = (options.home.y - p.y) * PlaneToWorldZ -- 373
			local dist = math.sqrt(ex * ex + ez * ez) -- 374
			if dist > 0.0001 then -- 374
				local tiltFactor = (dist - 0.5) / 3 -- 376
				if tiltFactor < 0 then -- 376
					tiltFactor = 0 -- 377
				end -- 377
				if tiltFactor > 1 then -- 377
					tiltFactor = 1 -- 378
				end -- 378
				local tilt = 46 * tiltFactor -- 379
				local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 380
				antennaModel.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 383
			end -- 383
		end -- 383
	end -- 365
	local function faceVelocity(v) -- 391
		local wx = v.x * PlaneToWorldX -- 392
		local wz = v.y * PlaneToWorldZ -- 393
		if wx * wx + wz * wz < 1e-12 then -- 393
			return -- 394
		end -- 394
		bodyYawDeg = math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 395
		probeNode.angleY = bodyYawDeg -- 396
	end -- 391
	local function syncBackdrop(eye, target) -- 400
		if backdropNode == nil then -- 400
			return -- 401
		end -- 401
		local dx = target.x - eye.x -- 402
		local dy = target.y - eye.y -- 403
		local dz = target.z - eye.z -- 404
		local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 405
		if len < 0.000001 then -- 405
			return -- 406
		end -- 406
		local s = BackdropDist / len -- 407
		backdropNode.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 408
	end -- 400
	syncBodies(0) -- 412
	syncProbe(probeStart) -- 413
	return { -- 415
		syncBodies = syncBodies, -- 416
		syncProbe = syncProbe, -- 417
		faceVelocity = faceVelocity, -- 418
		syncBackdrop = syncBackdrop, -- 419
		probe = probeNode, -- 420
		antenna = antennaModel, -- 421
		planets = planets, -- 422
		probeRadius = probeRadius -- 423
	} -- 423
end -- 176
return ____exports -- 176
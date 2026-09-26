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
	{name = "Planet_Neptune", k = 1.017}, -- 56
	{name = "Planet_Uranus", k = 1.023} -- 61
} -- 61
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 65
	do -- 65
		local i = 0 -- 66
		while i < #MODEL_RADIUS do -- 66
			if MODEL_RADIUS[i + 1].name == name then -- 66
				return MODEL_RADIUS[i + 1].k -- 67
			end -- 67
			i = i + 1 -- 66
		end -- 66
	end -- 66
	return 1 -- 69
end -- 65
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
local ProbeYawOffsetDeg = -90 -- 87
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 94
--- 按"分体"约定组装探测器（关卡与 S3.3 开场共用）。
-- 
-- ⚠️ 引擎的 Node3D **不把 glTF 子节点暴露成可寻址节点**（Test/AntennaProbe 实测：
--    children/eachChild/name 全部不可访问，hasChildren 恒 false），所以"大天线回头指向地球"
--    只能靠**拆文件**：Probe_Body.glb（去掉天线）+ Probe_Antenna.glb（仅天线，转轴在文件原点）。
--    两个文件都在 → 天线可绕转轴旋转；缺任何一个 → 回退单体（天线刚性，不影响玩法）。
-- ⚠️ Model3D 对**不存在的文件**不是返回 nil 而是**抛运行时错误**（"can not locate full path"
--    → Object::createNotNull failed，实测把整个建关流程炸掉、画面全黑）——
--    所以"可选资产"必须先用 Content.exist 守卫，绝不能拿 Model3D 的返回值做存在性判断。
-- ⚠️ 不要给天线再套一层普通 Node3D 枢轴容器并每帧旋转它：会触发引擎堆损坏（0xc0000374）。
-- 
-- @returns 句柄；连单体文件都加载不上时返回 undefined（调用方应报错）。
function ____exports.createProbe(parent, opts) -- 212
	local scale = opts.scale -- 213
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 214
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 217
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 220
	if bodyModel == nil and singleModel == nil then -- 220
		return nil -- 221
	end -- 221
	local node = Node3D() -- 223
	parent:addChild(node) -- 224
	if bodyModel ~= nil then -- 224
		bodyModel.scale = Vec3(scale, scale, scale) -- 227
		node:addChild(bodyModel) -- 228
	end -- 228
	if singleModel ~= nil then -- 228
		singleModel.scale = Vec3(scale, scale, scale) -- 231
		node:addChild(singleModel) -- 232
	end -- 232
	if bodyModel ~= nil and antennaModel ~= nil then -- 232
		antennaModel.scale = Vec3(scale, scale, scale) -- 238
		antennaModel.position = Vec3(0, ____exports.AntennaPivotY * scale, 0) -- 239
		node:addChild(antennaModel) -- 240
	end -- 240
	return {node = node, antenna = antennaModel, radius = 0.5 * 3.227 * scale * 1.1} -- 243
end -- 212
--- "大天线回头指向地球"的目标法线（关卡与 S3.3 开场共用同一份算式）。
-- 
-- 目标法线 = 从"朝上"向目标方向倾斜（倾角随距离渐入——刚出发距离 ≈ 0 时不倾）；
-- 方位角在**机身本地系**里算（机身自己会被 faceVelocity 转到速度方向）。
-- Euler 次序（angleY 后 angleZ）按截图标定；若天线倾倒方向不随位置变，说明次序反了。
-- 
-- ⚠️ 不要拆成 angleY/angleZ 两次赋值：每帧两次独立 Euler setter 会触发引擎
--    堆损坏（0xc0000374，二分 C1 实测定位）；一次性写 angles 整体更新则稳定。
-- 
-- @param probe 探测器位置（平面坐标）
-- @param target 指向目标（平面坐标；关卡传地球锚点，开场传地球）
-- @param bodyYawDeg 机身当前朝向（度；由 probeYawForVelocity 维护）
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 267
	local ex = (target.x - probe.x) * PlaneToWorldX -- 268
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 269
	local dist = math.sqrt(ex * ex + ez * ez) -- 270
	if dist <= 0.0001 then -- 270
		return -- 271
	end -- 271
	local tiltFactor = (dist - 0.5) / 3 -- 272
	if tiltFactor < 0 then -- 272
		tiltFactor = 0 -- 273
	end -- 273
	if tiltFactor > 1 then -- 273
		tiltFactor = 1 -- 274
	end -- 274
	local tilt = 46 * tiltFactor -- 275
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 276
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 277
end -- 267
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 287
	local wx = v.x * PlaneToWorldX -- 288
	local wz = v.y * PlaneToWorldZ -- 289
	if wx * wx + wz * wz < 1e-12 then -- 289
		return nil -- 290
	end -- 290
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 291
end -- 287
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 295
local BackdropHalf = 560 -- 296
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 299
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 301
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 309
--- 建星空：**世界尺度的天球 + 每帧把球心挪到相机位置**（2026-09-26，用户第 5 条反馈）。
-- 
-- 为什么换掉面片：旧的四边形是"钉在视线前方 600"的，但它**朝向写死**（angleX = -45）。
-- 开场里相机要从全景俯冲到特写（俯角 42°→20°、方位角差 60°+），朝向不匹配时星图会被拉伸/透视错位，
-- 一眼看出是块贴片。天球没有朝向问题：转到哪个角度看都对。
-- 球心跟着相机 ⇒ 旋转带着星空一起转（正确），平移不产生视差（等价于无穷远，也正确）。
-- 
-- 天球半径 1200：远大于任何场景跨度（全景最外轨道 55、关卡 25–100），
-- 又远小于远裁剪面（实测 > 2000，Test/FarPlaneProbe，2026-09-25）。
-- 
-- 素材由 Test/gen_orbit_assets.py 代码生成：starfield.png（2048×1024 等距圆柱）
-- + StarSphere.gltf（单位球，**scale = 天球半径**，材质自带 doubleSided）。
-- 旧的 StarQuad.gltf / 1024² 贴图保留作回退。
function ____exports.createStarBackdrop(root) -- 334
	local tex = Texture2D("Assets/Image/starfield.png") -- 335
	if Content:exist(SkySpherePath) then -- 335
		local sphere = Model3D(SkySpherePath) -- 339
		if sphere ~= nil then -- 339
			local sm = sphere:getMaterial(0) -- 341
			if sm ~= nil and tex ~= nil then -- 341
				sm:setEmissiveTexture(tex) -- 345
				sm.baseColor = Color(0, 0, 0, 255) -- 346
				sm.emissive = Color3(StarBrightnessHex) -- 347
				sm.roughness = 1 -- 348
				sm.metallic = 0 -- 349
			end -- 349
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 351
			sphere.position = Vec3(0, 0, 0) -- 352
			root:addChild(sphere) -- 353
			return { -- 354
				node = sphere, -- 355
				sync = function(____, eye, target) -- 356
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 357
				end -- 356
			} -- 356
		end -- 356
	end -- 356
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 364
	if backdrop == nil then -- 364
		return nil -- 365
	end -- 365
	local bm = backdrop:getMaterial(0) -- 366
	if bm ~= nil and tex ~= nil then -- 366
		bm:setEmissiveTexture(tex) -- 368
		bm.baseColor = Color(0, 0, 0, 255) -- 369
		bm.emissive = Color3(StarBrightnessHex) -- 370
		bm.roughness = 1 -- 371
		bm.metallic = 0 -- 372
	end -- 372
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 374
	backdrop.angleX = -45 -- 375
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 376
	root:addChild(backdrop) -- 377
	return { -- 378
		node = backdrop, -- 379
		sync = function(____, eye, target) -- 380
			local dx = target.x - eye.x -- 381
			local dy = target.y - eye.y -- 382
			local dz = target.z - eye.z -- 383
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 384
			if len < 0.000001 then -- 384
				return -- 385
			end -- 385
			local s = BackdropDist / len -- 386
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 387
		end -- 380
	} -- 380
end -- 334
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 397
	local ____options_0 = options -- 398
	local root = ____options_0.root -- 398
	local bodies = ____options_0.bodies -- 398
	local visuals = ____options_0.visuals -- 398
	local probeStart = ____options_0.probeStart -- 398
	local light = DirectionalLight3D() -- 405
	light.color = Color3(16774106) -- 406
	light.intensity = 3.6 -- 407
	light.angleX = -42 -- 408
	light.angleY = 75 -- 409
	root:addChild(light) -- 410
	local planets = {} -- 413
	do -- 413
		local i = 0 -- 414
		while i < #bodies do -- 414
			local def = bodies[i + 1] -- 415
			local vis = visuals[i + 1] -- 416
			local bodyModel = nil -- 419
			local k = 1 -- 420
			local modelName = vis.model ~= nil and vis.model or "" -- 421
			if modelName ~= "" then -- 421
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 423
				if loaded ~= nil then -- 423
					bodyModel = loaded -- 425
					k = ____exports.modelRadius(modelName) -- 426
				end -- 426
			end -- 426
			if bodyModel == nil then -- 426
				bodyModel = Model3D(options.spherePath) -- 430
				k = 1 -- 431
			end -- 431
			if bodyModel == nil then -- 431
				return nil -- 433
			end -- 433
			local scale = vis.displayRadius / k -- 436
			bodyModel.scale = Vec3(scale, scale, scale) -- 437
			local mi = 0 -- 440
			while mi < 64 do -- 440
				local mat = bodyModel:getMaterial(mi) -- 442
				if mat == nil then -- 442
					break -- 443
				end -- 443
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 444
				mi = mi + 1 -- 445
			end -- 445
			root:addChild(bodyModel) -- 448
			local ringNode = nil -- 451
			if modelName == "" and vis.ring then -- 451
				local ring = Model3D(options.ringPath) -- 453
				if ring ~= nil then -- 453
					local rs = scale * 1.5 -- 456
					ring.scale = Vec3(rs, rs, rs) -- 457
					root:addChild(ring) -- 458
					ringNode = ring -- 459
				end -- 459
			end -- 459
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 463
			i = i + 1 -- 414
		end -- 414
	end -- 414
	if options.home ~= nil then -- 414
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 471
		if earth ~= nil then -- 471
			local ke = ____exports.modelRadius("Planet_Earth") -- 473
			local es = 1.15 / ke -- 474
			earth.scale = Vec3(es, es, es) -- 475
			local emi = 0 -- 476
			while emi < 64 do -- 476
				local em = earth:getMaterial(emi) -- 478
				if em == nil then -- 478
					break -- 479
				end -- 479
				em.baseColor = Color(110, 170, 235, 255) -- 480
				em.emissive = Color3(792098) -- 482
				emi = emi + 1 -- 483
			end -- 483
			earth.position = ____exports.planeToWorld(options.home, 0) -- 485
			root:addChild(earth) -- 486
		end -- 486
	end -- 486
	local probe = ____exports.createProbe(root, {scale = options.probeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 496
	if probe == nil then -- 496
		return nil -- 502
	end -- 502
	local probeNode = probe.node -- 503
	local antennaModel = probe.antenna -- 504
	local probeRadius = probe.radius -- 505
	local bodyYawDeg = 0 -- 508
	local backdrop = ____exports.createStarBackdrop(root) -- 512
	local function syncBodies(t) -- 515
		for ____, p in ipairs(planets) do -- 516
			local wp = ____exports.planeToWorld( -- 517
				bodyPositionAt(p.def, t), -- 517
				0 -- 517
			) -- 517
			p.body.position = wp -- 518
			if p.ring ~= nil then -- 518
				p.ring.position = wp -- 519
			end -- 519
		end -- 519
	end -- 515
	local function syncProbe(p) -- 523
		probeNode.position = ____exports.planeToWorld(p, 0) -- 524
		if antennaModel ~= nil and options.home ~= nil then -- 524
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 530
		end -- 530
	end -- 523
	local function faceVelocity(v) -- 537
		local yaw = ____exports.probeYawForVelocity(v) -- 538
		if yaw == nil then -- 538
			return -- 539
		end -- 539
		bodyYawDeg = yaw -- 540
		probeNode.angleY = bodyYawDeg -- 541
	end -- 537
	local function syncBackdrop(eye, target) -- 545
		if backdrop ~= nil then -- 545
			backdrop:sync(eye, target) -- 546
		end -- 546
	end -- 545
	syncBodies(0) -- 550
	syncProbe(probeStart) -- 551
	return { -- 553
		syncBodies = syncBodies, -- 554
		syncProbe = syncProbe, -- 555
		faceVelocity = faceVelocity, -- 556
		syncBackdrop = syncBackdrop, -- 557
		probe = probeNode, -- 558
		antenna = antennaModel, -- 559
		planets = planets, -- 560
		probeRadius = probeRadius -- 561
	} -- 561
end -- 397
return ____exports -- 397
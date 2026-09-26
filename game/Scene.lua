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
function ____exports.createProbe(parent, opts) -- 214
	local scale = opts.scale -- 215
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 216
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 219
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 222
	if bodyModel == nil and singleModel == nil then -- 222
		return nil -- 223
	end -- 223
	local node = Node3D() -- 225
	parent:addChild(node) -- 226
	if bodyModel ~= nil then -- 226
		bodyModel.scale = Vec3(scale, scale, scale) -- 229
		node:addChild(bodyModel) -- 230
	end -- 230
	if singleModel ~= nil then -- 230
		singleModel.scale = Vec3(scale, scale, scale) -- 233
		node:addChild(singleModel) -- 234
	end -- 234
	if bodyModel ~= nil and antennaModel ~= nil then -- 234
		antennaModel.scale = Vec3(scale, scale, scale) -- 240
		antennaModel.position = Vec3(0, ____exports.AntennaPivotY * scale, 0) -- 241
		node:addChild(antennaModel) -- 242
	end -- 242
	return {node = node, antenna = antennaModel, radius = 0.5 * 3.227 * scale * 1.1} -- 245
end -- 214
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 269
	local ex = (target.x - probe.x) * PlaneToWorldX -- 270
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 271
	local dist = math.sqrt(ex * ex + ez * ez) -- 272
	if dist <= 0.0001 then -- 272
		return -- 273
	end -- 273
	local tiltFactor = (dist - 0.5) / 3 -- 274
	if tiltFactor < 0 then -- 274
		tiltFactor = 0 -- 275
	end -- 275
	if tiltFactor > 1 then -- 275
		tiltFactor = 1 -- 276
	end -- 276
	local tilt = 46 * tiltFactor -- 277
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 278
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 279
end -- 269
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 289
	local wx = v.x * PlaneToWorldX -- 290
	local wz = v.y * PlaneToWorldZ -- 291
	if wx * wx + wz * wz < 1e-12 then -- 291
		return nil -- 292
	end -- 292
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 293
end -- 289
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 297
local BackdropHalf = 560 -- 298
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 301
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 303
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 311
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
function ____exports.createStarBackdrop(root) -- 336
	local tex = Texture2D("Assets/Image/starfield.png") -- 337
	if Content:exist(SkySpherePath) then -- 337
		local sphere = Model3D(SkySpherePath) -- 341
		if sphere ~= nil then -- 341
			local sm = sphere:getMaterial(0) -- 343
			if sm ~= nil and tex ~= nil then -- 343
				sm:setEmissiveTexture(tex) -- 347
				sm.baseColor = Color(0, 0, 0, 255) -- 348
				sm.emissive = Color3(StarBrightnessHex) -- 349
				sm.roughness = 1 -- 350
				sm.metallic = 0 -- 351
			end -- 351
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 353
			sphere.position = Vec3(0, 0, 0) -- 354
			root:addChild(sphere) -- 355
			return { -- 356
				node = sphere, -- 357
				sync = function(____, eye, target) -- 358
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 359
				end -- 358
			} -- 358
		end -- 358
	end -- 358
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 366
	if backdrop == nil then -- 366
		return nil -- 367
	end -- 367
	local bm = backdrop:getMaterial(0) -- 368
	if bm ~= nil and tex ~= nil then -- 368
		bm:setEmissiveTexture(tex) -- 370
		bm.baseColor = Color(0, 0, 0, 255) -- 371
		bm.emissive = Color3(StarBrightnessHex) -- 372
		bm.roughness = 1 -- 373
		bm.metallic = 0 -- 374
	end -- 374
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 376
	backdrop.angleX = -45 -- 377
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 378
	root:addChild(backdrop) -- 379
	return { -- 380
		node = backdrop, -- 381
		sync = function(____, eye, target) -- 382
			local dx = target.x - eye.x -- 383
			local dy = target.y - eye.y -- 384
			local dz = target.z - eye.z -- 385
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 386
			if len < 0.000001 then -- 386
				return -- 387
			end -- 387
			local s = BackdropDist / len -- 388
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 389
		end -- 382
	} -- 382
end -- 336
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 399
	local ____options_0 = options -- 400
	local root = ____options_0.root -- 400
	local bodies = ____options_0.bodies -- 400
	local visuals = ____options_0.visuals -- 400
	local probeStart = ____options_0.probeStart -- 400
	local light = DirectionalLight3D() -- 407
	light.color = Color3(16774106) -- 408
	light.intensity = 3.6 -- 409
	light.angleX = -42 -- 410
	light.angleY = 75 -- 411
	root:addChild(light) -- 412
	local planets = {} -- 415
	do -- 415
		local i = 0 -- 416
		while i < #bodies do -- 416
			local def = bodies[i + 1] -- 417
			local vis = visuals[i + 1] -- 418
			local bodyModel = nil -- 421
			local k = 1 -- 422
			local modelName = vis.model ~= nil and vis.model or "" -- 423
			if modelName ~= "" then -- 423
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 425
				if loaded ~= nil then -- 425
					bodyModel = loaded -- 427
					k = ____exports.modelRadius(modelName) -- 428
				end -- 428
			end -- 428
			if bodyModel == nil then -- 428
				bodyModel = Model3D(options.spherePath) -- 432
				k = 1 -- 433
			end -- 433
			if bodyModel == nil then -- 433
				return nil -- 435
			end -- 435
			local scale = vis.displayRadius / k -- 438
			bodyModel.scale = Vec3(scale, scale, scale) -- 439
			local mi = 0 -- 442
			while mi < 64 do -- 442
				local mat = bodyModel:getMaterial(mi) -- 444
				if mat == nil then -- 444
					break -- 445
				end -- 445
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 446
				mi = mi + 1 -- 447
			end -- 447
			root:addChild(bodyModel) -- 450
			local ringNode = nil -- 453
			if modelName == "" and vis.ring then -- 453
				local ring = Model3D(options.ringPath) -- 455
				if ring ~= nil then -- 455
					local rs = scale * 1.5 -- 458
					ring.scale = Vec3(rs, rs, rs) -- 459
					root:addChild(ring) -- 460
					ringNode = ring -- 461
				end -- 461
			end -- 461
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 465
			i = i + 1 -- 416
		end -- 416
	end -- 416
	if options.home ~= nil then -- 416
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 473
		if earth ~= nil then -- 473
			local ke = ____exports.modelRadius("Planet_Earth") -- 475
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 476
			local es = hr / ke -- 477
			earth.scale = Vec3(es, es, es) -- 478
			local emi = 0 -- 479
			while emi < 64 do -- 479
				local em = earth:getMaterial(emi) -- 481
				if em == nil then -- 481
					break -- 482
				end -- 482
				em.baseColor = Color(110, 170, 235, 255) -- 483
				em.emissive = Color3(792098) -- 485
				emi = emi + 1 -- 486
			end -- 486
			earth.position = ____exports.planeToWorld(options.home, 0) -- 488
			root:addChild(earth) -- 489
		end -- 489
	end -- 489
	local probe = ____exports.createProbe(root, {scale = options.probeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 499
	if probe == nil then -- 499
		return nil -- 505
	end -- 505
	local probeNode = probe.node -- 506
	local antennaModel = probe.antenna -- 507
	local probeRadius = probe.radius -- 508
	local bodyYawDeg = 0 -- 511
	local backdrop = ____exports.createStarBackdrop(root) -- 515
	local function syncBodies(t) -- 518
		for ____, p in ipairs(planets) do -- 519
			local wp = ____exports.planeToWorld( -- 520
				bodyPositionAt(p.def, t), -- 520
				0 -- 520
			) -- 520
			p.body.position = wp -- 521
			if p.ring ~= nil then -- 521
				p.ring.position = wp -- 522
			end -- 522
		end -- 522
	end -- 518
	local function syncProbe(p) -- 526
		probeNode.position = ____exports.planeToWorld(p, 0) -- 527
		if antennaModel ~= nil and options.home ~= nil then -- 527
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 533
		end -- 533
	end -- 526
	local function faceVelocity(v) -- 540
		local yaw = ____exports.probeYawForVelocity(v) -- 541
		if yaw == nil then -- 541
			return -- 542
		end -- 542
		bodyYawDeg = yaw -- 543
		probeNode.angleY = bodyYawDeg -- 544
	end -- 540
	local function syncBackdrop(eye, target) -- 548
		if backdrop ~= nil then -- 548
			backdrop:sync(eye, target) -- 549
		end -- 549
	end -- 548
	syncBodies(0) -- 553
	syncProbe(probeStart) -- 554
	return { -- 556
		syncBodies = syncBodies, -- 557
		syncProbe = syncProbe, -- 558
		faceVelocity = faceVelocity, -- 559
		syncBackdrop = syncBackdrop, -- 560
		probe = probeNode, -- 561
		antenna = antennaModel, -- 562
		planets = planets, -- 563
		probeRadius = probeRadius -- 564
	} -- 564
end -- 399
return ____exports -- 399
-- [ts]: Scene.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 26
local Color = ____Dora.Color -- 27
local Color3 = ____Dora.Color3 -- 27
local Content = ____Dora.Content -- 27
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 27
local Model3D = ____Dora.Model3D -- 27
local Node3D = ____Dora.Node3D -- 27
local Texture2D = ____Dora.Texture2D -- 27
local Vec3 = ____Dora.Vec3 -- 27
local ____Config = require("game.Config") -- 29
local OrbitRingTintHex = ____Config.OrbitRingTintHex -- 30
local PlaneToWorldX = ____Config.PlaneToWorldX -- 30
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 30
local SunGlowScale = ____Config.SunGlowScale -- 31
local SunMinGmForLight = ____Config.SunMinGmForLight -- 31
local ____Gravity = require("game.Gravity") -- 33
local bodyPositionAt = ____Gravity.bodyPositionAt -- 33
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 36
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 37
end -- 36
local MODEL_RADIUS = { -- 55
	{name = "Planet_Earth", k = 1.0343}, -- 56
	{name = "Planet_Mars", k = 1.0227}, -- 57
	{name = "Planet_Venus", k = 1.0215}, -- 58
	{name = "Planet_Jupiter", k = 1}, -- 59
	{name = "Planet_Saturn", k = 0.9837}, -- 60
	{name = "Planet_Neptune", k = 1.017}, -- 61
	{name = "Planet_Uranus", k = 1.023} -- 66
} -- 66
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 70
	do -- 70
		local i = 0 -- 71
		while i < #MODEL_RADIUS do -- 71
			if MODEL_RADIUS[i + 1].name == name then -- 71
				return MODEL_RADIUS[i + 1].k -- 72
			end -- 72
			i = i + 1 -- 71
		end -- 71
	end -- 71
	return 1 -- 74
end -- 70
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
local ProbeYawOffsetDeg = -90 -- 92
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 99
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
function ____exports.createProbe(parent, opts) -- 221
	local scale = opts.scale -- 222
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 223
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 226
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 229
	if bodyModel == nil and singleModel == nil then -- 229
		return nil -- 230
	end -- 230
	local node = Node3D() -- 232
	parent:addChild(node) -- 233
	if bodyModel ~= nil then -- 233
		bodyModel.scale = Vec3(scale, scale, scale) -- 236
		node:addChild(bodyModel) -- 237
	end -- 237
	if singleModel ~= nil then -- 237
		singleModel.scale = Vec3(scale, scale, scale) -- 240
		node:addChild(singleModel) -- 241
	end -- 241
	if bodyModel ~= nil and antennaModel ~= nil then -- 241
		antennaModel.scale = Vec3(scale, scale, scale) -- 247
		antennaModel.position = Vec3(0, ____exports.AntennaPivotY * scale, 0) -- 248
		node:addChild(antennaModel) -- 249
	end -- 249
	return {node = node, antenna = antennaModel, radius = 0.5 * 3.227 * scale * 1.1} -- 252
end -- 221
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 276
	local ex = (target.x - probe.x) * PlaneToWorldX -- 277
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 278
	local dist = math.sqrt(ex * ex + ez * ez) -- 279
	if dist <= 0.0001 then -- 279
		return -- 280
	end -- 280
	local tiltFactor = (dist - 0.5) / 3 -- 281
	if tiltFactor < 0 then -- 281
		tiltFactor = 0 -- 282
	end -- 282
	if tiltFactor > 1 then -- 282
		tiltFactor = 1 -- 283
	end -- 283
	local tilt = 46 * tiltFactor -- 284
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 285
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 286
end -- 276
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 296
	local wx = v.x * PlaneToWorldX -- 297
	local wz = v.y * PlaneToWorldZ -- 298
	if wx * wx + wz * wz < 1e-12 then -- 298
		return nil -- 299
	end -- 299
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 300
end -- 296
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 304
local BackdropHalf = 560 -- 305
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 308
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 310
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 318
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
function ____exports.createStarBackdrop(root) -- 343
	local tex = Texture2D("Assets/Image/starfield.png") -- 344
	if Content:exist(SkySpherePath) then -- 344
		local sphere = Model3D(SkySpherePath) -- 348
		if sphere ~= nil then -- 348
			local sm = sphere:getMaterial(0) -- 350
			if sm ~= nil and tex ~= nil then -- 350
				sm:setEmissiveTexture(tex) -- 354
				sm.baseColor = Color(0, 0, 0, 255) -- 355
				sm.emissive = Color3(StarBrightnessHex) -- 356
				sm.roughness = 1 -- 357
				sm.metallic = 0 -- 358
			end -- 358
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 360
			sphere.position = Vec3(0, 0, 0) -- 361
			root:addChild(sphere) -- 362
			return { -- 363
				node = sphere, -- 364
				sync = function(____, eye, target) -- 365
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 366
				end -- 365
			} -- 365
		end -- 365
	end -- 365
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 373
	if backdrop == nil then -- 373
		return nil -- 374
	end -- 374
	local bm = backdrop:getMaterial(0) -- 375
	if bm ~= nil and tex ~= nil then -- 375
		bm:setEmissiveTexture(tex) -- 377
		bm.baseColor = Color(0, 0, 0, 255) -- 378
		bm.emissive = Color3(StarBrightnessHex) -- 379
		bm.roughness = 1 -- 380
		bm.metallic = 0 -- 381
	end -- 381
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 383
	backdrop.angleX = -45 -- 384
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 385
	root:addChild(backdrop) -- 386
	return { -- 387
		node = backdrop, -- 388
		sync = function(____, eye, target) -- 389
			local dx = target.x - eye.x -- 390
			local dy = target.y - eye.y -- 391
			local dz = target.z - eye.z -- 392
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 393
			if len < 0.000001 then -- 393
				return -- 394
			end -- 394
			local s = BackdropDist / len -- 395
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 396
		end -- 389
	} -- 389
end -- 343
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 406
	local ____options_0 = options -- 407
	local root = ____options_0.root -- 407
	local bodies = ____options_0.bodies -- 407
	local visuals = ____options_0.visuals -- 407
	local probeStart = ____options_0.probeStart -- 407
	local starWorld = nil -- 415
	local starRadius = 0 -- 416
	local starGm = 0 -- 417
	do -- 417
		local i = 0 -- 418
		while i < #bodies do -- 418
			do -- 418
				local b = bodies[i + 1] -- 419
				if b.orbitRadius ~= 0 then -- 419
					goto __continue29 -- 420
				end -- 420
				if b.gm <= starGm then -- 420
					goto __continue29 -- 421
				end -- 421
				starGm = b.gm -- 422
				starRadius = b.radius -- 423
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 424
			end -- 424
			::__continue29:: -- 424
			i = i + 1 -- 418
		end -- 418
	end -- 418
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 426
	local ____hasStar_1 -- 427
	if hasStar then -- 427
		____hasStar_1 = Texture2D("Assets/Image/sun_tex.png") -- 427
	else -- 427
		____hasStar_1 = nil -- 427
	end -- 427
	local sunTex = ____hasStar_1 -- 427
	do -- 427
		local light = DirectionalLight3D() -- 436
		light.color = Color3(16774106) -- 437
		light.intensity = 3.6 -- 438
		light.angleX = -42 -- 439
		light.angleY = 75 -- 440
		root:addChild(light) -- 441
	end -- 441
	local starIndex = -1 -- 444
	if hasStar then -- 444
		local best = 0 -- 446
		do -- 446
			local i = 0 -- 447
			while i < #bodies do -- 447
				local b = bodies[i + 1] -- 448
				if b.orbitRadius == 0 and b.gm > best then -- 448
					best = b.gm -- 450
					starIndex = i -- 451
				end -- 451
				i = i + 1 -- 447
			end -- 447
		end -- 447
	end -- 447
	local planets = {} -- 457
	do -- 457
		local i = 0 -- 458
		while i < #bodies do -- 458
			local def = bodies[i + 1] -- 459
			local vis = visuals[i + 1] -- 460
			local bodyModel = nil -- 463
			local k = 1 -- 464
			local modelName = vis.model ~= nil and vis.model or "" -- 465
			if modelName ~= "" then -- 465
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 467
				if loaded ~= nil then -- 467
					bodyModel = loaded -- 469
					k = ____exports.modelRadius(modelName) -- 470
				end -- 470
			end -- 470
			if bodyModel == nil then -- 470
				bodyModel = Model3D(options.spherePath) -- 474
				k = 1 -- 475
			end -- 475
			if bodyModel == nil then -- 475
				return nil -- 477
			end -- 477
			local scale = vis.displayRadius / k -- 480
			bodyModel.scale = Vec3(scale, scale, scale) -- 481
			local mi = 0 -- 484
			while mi < 64 do -- 484
				local mat = bodyModel:getMaterial(mi) -- 486
				if mat == nil then -- 486
					break -- 487
				end -- 487
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 488
				local em = vis.emissive -- 489
				if em ~= nil then -- 489
					mat.emissive = Color3( -- 491
						math.floor(em.r * 255 + 0.5), -- 491
						math.floor(em.g * 255 + 0.5), -- 491
						math.floor(em.b * 255 + 0.5) -- 491
					) -- 491
				end -- 491
				if i == starIndex and sunTex ~= nil then -- 491
					mat:setEmissiveTexture(sunTex) -- 495
				end -- 495
				mi = mi + 1 -- 496
			end -- 496
			root:addChild(bodyModel) -- 499
			local ringNode = nil -- 502
			if modelName == "" and vis.ring then -- 502
				local ring = Model3D(options.ringPath) -- 504
				if ring ~= nil then -- 504
					local rs = scale * 1.5 -- 507
					ring.scale = Vec3(rs, rs, rs) -- 508
					root:addChild(ring) -- 509
					ringNode = ring -- 510
				end -- 510
			end -- 510
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 514
			i = i + 1 -- 458
		end -- 458
	end -- 458
	do -- 458
		local i = 0 -- 522
		while i < #bodies do -- 522
			do -- 522
				local def = bodies[i + 1] -- 523
				if def.orbitRadius <= 0 then -- 523
					goto __continue50 -- 524
				end -- 524
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 525
				if not Content:exist(ringPath) then -- 525
					goto __continue50 -- 527
				end -- 527
				local orbitNode = Model3D(ringPath) -- 528
				if orbitNode == nil then -- 528
					goto __continue50 -- 529
				end -- 529
				local oi = 0 -- 530
				while oi < 8 do -- 530
					local om = orbitNode:getMaterial(oi) -- 532
					if om == nil then -- 532
						break -- 533
					end -- 533
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 535
					oi = oi + 1 -- 536
				end -- 536
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 538
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 539
				root:addChild(orbitNode) -- 540
			end -- 540
			::__continue50:: -- 540
			i = i + 1 -- 522
		end -- 522
	end -- 522
	if options.home ~= nil then -- 522
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 548
		if earth ~= nil then -- 548
			local ke = ____exports.modelRadius("Planet_Earth") -- 550
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 551
			local es = hr / ke -- 552
			earth.scale = Vec3(es, es, es) -- 553
			local emi = 0 -- 554
			while emi < 64 do -- 554
				local em = earth:getMaterial(emi) -- 556
				if em == nil then -- 556
					break -- 557
				end -- 557
				em.baseColor = Color(110, 170, 235, 255) -- 558
				em.emissive = Color3(792098) -- 560
				emi = emi + 1 -- 561
			end -- 561
			earth.position = ____exports.planeToWorld(options.home, 0) -- 563
			root:addChild(earth) -- 564
		end -- 564
	end -- 564
	local probe = ____exports.createProbe(root, {scale = options.probeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 574
	if probe == nil then -- 574
		return nil -- 580
	end -- 580
	local probeNode = probe.node -- 581
	local antennaModel = probe.antenna -- 582
	local probeRadius = probe.radius -- 583
	local bodyYawDeg = 0 -- 586
	local backdrop = ____exports.createStarBackdrop(root) -- 590
	local glowNode = nil -- 598
	local glowScale = 0 -- 601
	if hasStar and starWorld ~= nil then -- 601
		glowScale = SunGlowScale * starRadius * 2 -- 603
		local glowPath = "Assets/Model/StarQuad.gltf" -- 604
		if Content:exist(glowPath) then -- 604
			local glowModel = Model3D(glowPath) -- 606
			if glowModel ~= nil then -- 606
				local glowTex = Texture2D("Assets/Image/glow.png") -- 608
				local gl = glowModel:getMaterial(0) -- 609
				if gl ~= nil and glowTex ~= nil then -- 609
					gl:setBaseColorTexture(glowTex) -- 611
					gl:setEmissiveTexture(glowTex) -- 612
					gl.baseColor = Color(0, 0, 0, 255) -- 613
					gl.emissive = Color3(13154456) -- 614
					gl.roughness = 1 -- 615
					gl.metallic = 0 -- 616
					gl.alphaMode = 2 -- 617
				end -- 617
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 619
				glowModel.position = starWorld -- 620
				root:addChild(glowModel) -- 621
				glowNode = glowModel -- 622
			end -- 622
		end -- 622
	end -- 622
	local function syncBodies(t) -- 628
		for ____, p in ipairs(planets) do -- 629
			local wp = ____exports.planeToWorld( -- 630
				bodyPositionAt(p.def, t), -- 630
				0 -- 630
			) -- 630
			p.body.position = wp -- 631
			if p.ring ~= nil then -- 631
				p.ring.position = wp -- 632
			end -- 632
		end -- 632
	end -- 628
	local function syncProbe(p) -- 636
		probeNode.position = ____exports.planeToWorld(p, 0) -- 637
		if antennaModel ~= nil and options.home ~= nil then -- 637
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 643
		end -- 643
	end -- 636
	local function faceVelocity(v) -- 650
		local yaw = ____exports.probeYawForVelocity(v) -- 651
		if yaw == nil then -- 651
			return -- 652
		end -- 652
		bodyYawDeg = yaw -- 653
		probeNode.angleY = bodyYawDeg -- 654
	end -- 650
	local function syncBackdrop(eye, target) -- 658
		if backdrop ~= nil then -- 658
			backdrop:sync(eye, target) -- 659
		end -- 659
		if glowNode ~= nil and starWorld ~= nil then -- 659
			local dx = eye.x - starWorld.x -- 662
			local dy = eye.y - starWorld.y -- 663
			local dz = eye.z - starWorld.z -- 664
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 664
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 666
			end -- 666
			local flat = math.sqrt(dy * dy + dz * dz) -- 669
			local tilt = flat > 0.000001 and math.atan( -- 670
				math.abs(dy), -- 670
				flat -- 670
			) or 0 -- 670
			local c = math.cos(tilt) -- 671
			local stretch = c > 0.45 and 1 / c or 2.2 -- 672
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 673
		end -- 673
	end -- 658
	syncBodies(0) -- 678
	syncProbe(probeStart) -- 679
	return { -- 681
		syncBodies = syncBodies, -- 682
		syncProbe = syncProbe, -- 683
		faceVelocity = faceVelocity, -- 684
		syncBackdrop = syncBackdrop, -- 685
		probe = probeNode, -- 686
		antenna = antennaModel, -- 687
		planets = planets, -- 688
		probeRadius = probeRadius -- 689
	} -- 689
end -- 406
return ____exports -- 406
-- [ts]: Scene.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
local ____exports = {} -- 1
local ____Dora = require("Dora") -- 28
local Color = ____Dora.Color -- 29
local Color3 = ____Dora.Color3 -- 29
local Content = ____Dora.Content -- 29
local DirectionalLight3D = ____Dora.DirectionalLight3D -- 29
local Model3D = ____Dora.Model3D -- 29
local Node3D = ____Dora.Node3D -- 29
local Texture2D = ____Dora.Texture2D -- 29
local Vec3 = ____Dora.Vec3 -- 29
local ____Config = require("game.Config") -- 31
local OrbitRingTintHex = ____Config.OrbitRingTintHex -- 32
local PlaneToWorldX = ____Config.PlaneToWorldX -- 32
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 32
local SunGlowScale = ____Config.SunGlowScale -- 33
local SunMinGmForLight = ____Config.SunMinGmForLight -- 33
local ____Gravity = require("game.Gravity") -- 35
local bodyPositionAt = ____Gravity.bodyPositionAt -- 35
local ____OrbitFlow = require("game.OrbitFlow") -- 36
local FlowDotsPerOrbit = ____OrbitFlow.FlowDotsPerOrbit -- 36
local flowDotAngle = ____OrbitFlow.flowDotAngle -- 36
local orbitCenterAt = ____OrbitFlow.orbitCenterAt -- 36
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 39
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 40
end -- 39
local MODEL_RADIUS = { -- 58
	{name = "Sun", k = 1}, -- 61
	{name = "Moon", k = 1}, -- 62
	{name = "Planet_Earth", k = 1}, -- 63
	{name = "Planet_Venus", k = 1}, -- 64
	{name = "Planet_Mars", k = 1}, -- 65
	{name = "Planet_Jupiter", k = 1}, -- 66
	{name = "Planet_Neptune", k = 1}, -- 67
	{name = "Planet_Saturn", k = 1}, -- 71
	{name = "Planet_Uranus", k = 1} -- 72
} -- 72
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 76
	do -- 76
		local i = 0 -- 77
		while i < #MODEL_RADIUS do -- 77
			if MODEL_RADIUS[i + 1].name == name then -- 77
				return MODEL_RADIUS[i + 1].k -- 78
			end -- 78
			i = i + 1 -- 77
		end -- 77
	end -- 77
	return 1 -- 80
end -- 76
--- 贴图表（S3.14 建模交付）。
-- 
-- ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
--    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
-- ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
--    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
--    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
local PLANET_TEX = { -- 106
	{name = "Sun", base = "sun.jpg", emissive = "sun.jpg", emisMul = 16777215}, -- 107
	{name = "Moon", base = "moon.jpg"}, -- 108
	{name = "Planet_Earth", base = "planet_earth.jpg", emissive = "planet_earth_emissive.png", emisMul = 2763306}, -- 109
	{name = "Planet_Venus", base = "planet_venus.jpg"}, -- 110
	{name = "Planet_Mars", base = "planet_mars.jpg"}, -- 111
	{name = "Planet_Jupiter", base = "planet_jupiter.jpg"}, -- 112
	{name = "Planet_Saturn", base = "planet_saturn.jpg", ring = "planet_saturn_ring.png"}, -- 113
	{name = "Planet_Uranus", base = "planet_uranus.jpg", ring = "planet_uranus_ring.png"}, -- 114
	{name = "Planet_Neptune", base = "planet_neptune.jpg"} -- 115
} -- 115
--- 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。
local function redOf(hex) -- 119
	return math.floor(hex / 65536) % 256 -- 119
end -- 119
local function greenOf(hex) -- 120
	return math.floor(hex / 256) % 256 -- 120
end -- 120
local function blueOf(hex) -- 121
	return math.floor(hex) % 256 -- 121
end -- 121
--- 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。
function ____exports.packColor(r, g, b) -- 124
	return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) -- 125
end -- 124
--- 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。
local function textureOf(file) -- 129
	if file == "" then -- 129
		return nil -- 130
	end -- 130
	local path = "Assets/Image/" .. file -- 131
	if not Content:exist(path) then -- 131
		return nil -- 132
	end -- 132
	return Texture2D(path) -- 133
end -- 129
--- 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
-- 
-- @param model 已加载的模型
-- @param modelName 模型名（不含路径与扩展名）
-- @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
-- @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
function ____exports.applyPlanetTexture(model, modelName, tintHex, emissiveHex) -- 144
	local def = nil -- 145
	do -- 145
		local i = 0 -- 146
		while i < #PLANET_TEX do -- 146
			if PLANET_TEX[i + 1].name == modelName then -- 146
				def = PLANET_TEX[i + 1] -- 147
			end -- 147
			i = i + 1 -- 146
		end -- 146
	end -- 146
	local baseTex = textureOf(def ~= nil and def.base or "") -- 149
	local emiTex = textureOf(def ~= nil and def.emissive ~= nil and def.emissive or "") -- 150
	local ringTex = textureOf(def ~= nil and def.ring ~= nil and def.ring or "") -- 151
	local emiMul = emissiveHex -- 152
	if emiMul == 0 and emiTex ~= nil then -- 152
		emiMul = def ~= nil and def.emisMul ~= nil and def.emisMul or 2763306 -- 154
	end -- 154
	local i = 0 -- 157
	while i < 64 do -- 157
		local mat = model:getMaterial(i) -- 159
		if mat == nil then -- 159
			break -- 160
		end -- 160
		local isRing = ringTex ~= nil and mat.alphaMode == 2 -- 161
		if isRing then -- 161
			mat:setBaseColorTexture(ringTex) -- 163
			mat.baseColor = Color(255, 255, 255, 255) -- 164
		elseif baseTex ~= nil then -- 164
			mat:setBaseColorTexture(baseTex) -- 167
			mat.baseColor = Color(255, 255, 255, 255) -- 168
		elseif tintHex > 0 then -- 168
			mat.baseColor = Color( -- 170
				redOf(tintHex), -- 170
				greenOf(tintHex), -- 170
				blueOf(tintHex), -- 170
				255 -- 170
			) -- 170
		end -- 170
		if not isRing and emiTex ~= nil and emiMul > 0 then -- 170
			mat:setEmissiveTexture(emiTex) -- 173
			mat.emissive = Color3(emiMul) -- 174
		end -- 174
		i = i + 1 -- 176
	end -- 176
end -- 144
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
local ProbeYawOffsetDeg = -90 -- 195
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 202
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 346
	local i = 0 -- 347
	while i < 64 do -- 347
		local mat = model:getMaterial(i) -- 349
		if mat == nil then -- 349
			break -- 350
		end -- 350
		mat:setBaseColorTexture(tex) -- 351
		i = i + 1 -- 352
	end -- 352
end -- 346
function ____exports.createProbe(parent, opts) -- 356
	local scale = opts.scale -- 357
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 358
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 359
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 360
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 363
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 366
	if bodyModel == nil and singleModel == nil then -- 366
		return nil -- 367
	end -- 367
	local node = Node3D() -- 369
	parent:addChild(node) -- 370
	if bodyModel ~= nil then -- 370
		bodyModel.scale = Vec3(scale, scale, scale) -- 373
		node:addChild(bodyModel) -- 374
	end -- 374
	if singleModel ~= nil then -- 374
		singleModel.scale = Vec3(scale, scale, scale) -- 377
		node:addChild(singleModel) -- 378
	end -- 378
	if bodyModel ~= nil and antennaModel ~= nil then -- 378
		antennaModel.scale = Vec3(scale, scale, scale) -- 385
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 386
		node:addChild(antennaModel) -- 387
	end -- 387
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 387
		local atlas = Texture2D(opts.atlasPath) -- 393
		if atlas ~= nil then -- 393
			if bodyModel ~= nil then -- 393
				applyAtlas(bodyModel, atlas) -- 395
			end -- 395
			if singleModel ~= nil then -- 395
				applyAtlas(singleModel, atlas) -- 396
			end -- 396
			if antennaModel ~= nil then -- 396
				applyAtlas(antennaModel, atlas) -- 397
			end -- 397
		end -- 397
	end -- 397
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 401
end -- 356
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 426
	local ex = (target.x - probe.x) * PlaneToWorldX -- 427
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 428
	local dist = math.sqrt(ex * ex + ez * ez) -- 429
	if dist <= 0.0001 then -- 429
		return -- 430
	end -- 430
	local tiltFactor = (dist - 0.5) / 3 -- 431
	if tiltFactor < 0 then -- 431
		tiltFactor = 0 -- 432
	end -- 432
	if tiltFactor > 1 then -- 432
		tiltFactor = 1 -- 433
	end -- 433
	local tilt = 46 * tiltFactor -- 434
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 435
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 436
end -- 426
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 446
	local wx = v.x * PlaneToWorldX -- 447
	local wz = v.y * PlaneToWorldZ -- 448
	if wx * wx + wz * wz < 1e-12 then -- 448
		return nil -- 449
	end -- 449
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 450
end -- 446
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 454
local BackdropHalf = 560 -- 455
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 458
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 460
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 468
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
function ____exports.createStarBackdrop(root) -- 493
	local tex = Texture2D("Assets/Image/starfield.png") -- 494
	if Content:exist(SkySpherePath) then -- 494
		local sphere = Model3D(SkySpherePath) -- 498
		if sphere ~= nil then -- 498
			local sm = sphere:getMaterial(0) -- 500
			if sm ~= nil and tex ~= nil then -- 500
				sm:setEmissiveTexture(tex) -- 504
				sm.baseColor = Color(0, 0, 0, 255) -- 505
				sm.emissive = Color3(StarBrightnessHex) -- 506
				sm.roughness = 1 -- 507
				sm.metallic = 0 -- 508
			end -- 508
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 510
			sphere.position = Vec3(0, 0, 0) -- 511
			root:addChild(sphere) -- 512
			return { -- 513
				node = sphere, -- 514
				sync = function(____, eye, target) -- 515
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 516
				end -- 515
			} -- 515
		end -- 515
	end -- 515
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 523
	if backdrop == nil then -- 523
		return nil -- 524
	end -- 524
	local bm = backdrop:getMaterial(0) -- 525
	if bm ~= nil and tex ~= nil then -- 525
		bm:setEmissiveTexture(tex) -- 527
		bm.baseColor = Color(0, 0, 0, 255) -- 528
		bm.emissive = Color3(StarBrightnessHex) -- 529
		bm.roughness = 1 -- 530
		bm.metallic = 0 -- 531
	end -- 531
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 533
	backdrop.angleX = -45 -- 534
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 535
	root:addChild(backdrop) -- 536
	return { -- 537
		node = backdrop, -- 538
		sync = function(____, eye, target) -- 539
			local dx = target.x - eye.x -- 540
			local dy = target.y - eye.y -- 541
			local dz = target.z - eye.z -- 542
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 543
			if len < 0.000001 then -- 543
				return -- 544
			end -- 544
			local s = BackdropDist / len -- 545
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 546
		end -- 539
	} -- 539
end -- 493
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 553
local FlowDotTexturePath = "Assets/Image/glow.png" -- 554
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 559
local FlowDotMaxScale = 2 -- 560
local FlowDotScalePerRadius = 0.012 -- 561
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 563
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 576
	local ____options_0 = options -- 577
	local root = ____options_0.root -- 577
	local bodies = ____options_0.bodies -- 577
	local visuals = ____options_0.visuals -- 577
	local probeStart = ____options_0.probeStart -- 577
	local starWorld = nil -- 585
	local starRadius = 0 -- 586
	local starGm = 0 -- 587
	do -- 587
		local i = 0 -- 588
		while i < #bodies do -- 588
			do -- 588
				local b = bodies[i + 1] -- 589
				if b.orbitRadius ~= 0 then -- 589
					goto __continue55 -- 590
				end -- 590
				if b.gm <= starGm then -- 590
					goto __continue55 -- 591
				end -- 591
				starGm = b.gm -- 592
				starRadius = b.radius -- 593
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 594
			end -- 594
			::__continue55:: -- 594
			i = i + 1 -- 588
		end -- 588
	end -- 588
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 596
	do -- 596
		local light = DirectionalLight3D() -- 605
		light.color = Color3(16774106) -- 606
		light.intensity = 3.6 -- 607
		light.angleX = -42 -- 608
		light.angleY = 75 -- 609
		root:addChild(light) -- 610
	end -- 610
	local starIndex = -1 -- 613
	if hasStar then -- 613
		local best = 0 -- 615
		do -- 615
			local i = 0 -- 616
			while i < #bodies do -- 616
				local b = bodies[i + 1] -- 617
				if b.orbitRadius == 0 and b.gm > best then -- 617
					best = b.gm -- 619
					starIndex = i -- 620
				end -- 620
				i = i + 1 -- 616
			end -- 616
		end -- 616
	end -- 616
	local planets = {} -- 626
	do -- 626
		local i = 0 -- 627
		while i < #bodies do -- 627
			local def = bodies[i + 1] -- 628
			local vis = visuals[i + 1] -- 629
			local bodyModel = nil -- 632
			local k = 1 -- 633
			local modelName = vis.model ~= nil and vis.model or "" -- 634
			if modelName ~= "" then -- 634
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 636
				if loaded ~= nil then -- 636
					bodyModel = loaded -- 638
					k = ____exports.modelRadius(modelName) -- 639
				end -- 639
			end -- 639
			if bodyModel == nil then -- 639
				bodyModel = Model3D(options.spherePath) -- 643
				k = 1 -- 644
			end -- 644
			if bodyModel == nil then -- 644
				return nil -- 646
			end -- 646
			local scale = vis.displayRadius / k -- 649
			bodyModel.scale = Vec3(scale, scale, scale) -- 650
			____exports.applyPlanetTexture( -- 657
				bodyModel, -- 657
				modelName, -- 657
				____exports.packColor(vis.r, vis.g, vis.b), -- 657
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 658
			) -- 658
			root:addChild(bodyModel) -- 660
			local ringNode = nil -- 663
			if modelName == "" and vis.ring then -- 663
				local ring = Model3D(options.ringPath) -- 665
				if ring ~= nil then -- 665
					local rs = scale * 1.5 -- 668
					ring.scale = Vec3(rs, rs, rs) -- 669
					root:addChild(ring) -- 670
					ringNode = ring -- 671
				end -- 671
			end -- 671
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 675
			i = i + 1 -- 627
		end -- 627
	end -- 627
	do -- 627
		local i = 0 -- 683
		while i < #bodies do -- 683
			do -- 683
				local def = bodies[i + 1] -- 684
				if def.orbitRadius <= 0 then -- 684
					goto __continue72 -- 685
				end -- 685
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 686
				if not Content:exist(ringPath) then -- 686
					goto __continue72 -- 688
				end -- 688
				local orbitNode = Model3D(ringPath) -- 689
				if orbitNode == nil then -- 689
					goto __continue72 -- 690
				end -- 690
				local oi = 0 -- 691
				while oi < 8 do -- 691
					local om = orbitNode:getMaterial(oi) -- 693
					if om == nil then -- 693
						break -- 694
					end -- 694
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 696
					oi = oi + 1 -- 697
				end -- 697
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 699
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 700
				root:addChild(orbitNode) -- 701
			end -- 701
			::__continue72:: -- 701
			i = i + 1 -- 683
		end -- 683
	end -- 683
	local flowOrbits = {} -- 714
	local ____Content_exist_result_1 -- 715
	if Content:exist(FlowDotTexturePath) then -- 715
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 715
	else -- 715
		____Content_exist_result_1 = nil -- 715
	end -- 715
	local flowDotTex = ____Content_exist_result_1 -- 715
	if Content:exist(FlowDotModelPath) then -- 715
		do -- 715
			local i = 0 -- 717
			while i < #bodies do -- 717
				do -- 717
					local def = bodies[i + 1] -- 718
					if def.orbitRadius <= 0 or def.orbitPeriod == 0 then -- 718
						goto __continue80 -- 719
					end -- 719
					local dots = {} -- 720
					do -- 720
						local k = 0 -- 721
						while k < FlowDotsPerOrbit do -- 721
							local dot = Model3D(FlowDotModelPath) -- 722
							if dot == nil then -- 722
								break -- 723
							end -- 723
							local dm = dot:getMaterial(0) -- 727
							if dm ~= nil then -- 727
								if flowDotTex ~= nil then -- 727
									dm:setBaseColorTexture(flowDotTex) -- 730
									dm:setEmissiveTexture(flowDotTex) -- 731
								end -- 731
								dm.baseColor = Color(0, 0, 0, 255) -- 733
								dm.emissive = Color3(FlowDotEmissiveHex) -- 734
								dm.roughness = 1 -- 735
								dm.metallic = 0 -- 736
								dm.alphaMode = 2 -- 737
							end -- 737
							local s = def.orbitRadius * FlowDotScalePerRadius -- 739
							if s < FlowDotMinScale then -- 739
								s = FlowDotMinScale -- 740
							end -- 740
							if s > FlowDotMaxScale then -- 740
								s = FlowDotMaxScale -- 741
							end -- 741
							dot.scale = Vec3(s, s, s) -- 742
							dot.angleX = -90 -- 743
							root:addChild(dot) -- 744
							dots[#dots + 1] = dot -- 745
							k = k + 1 -- 721
						end -- 721
					end -- 721
					if #dots == 0 then -- 721
						goto __continue80 -- 747
					end -- 747
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 748
				end -- 748
				::__continue80:: -- 748
				i = i + 1 -- 717
			end -- 717
		end -- 717
		if #flowOrbits > 0 then -- 717
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 751
		end -- 751
	end -- 751
	if options.home ~= nil then -- 751
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 760
		if earth ~= nil then -- 760
			local ke = ____exports.modelRadius("Planet_Earth") -- 762
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 763
			local es = hr / ke -- 764
			earth.scale = Vec3(es, es, es) -- 765
			local emi = 0 -- 766
			while emi < 64 do -- 766
				local em = earth:getMaterial(emi) -- 768
				if em == nil then -- 768
					break -- 769
				end -- 769
				em.baseColor = Color(110, 170, 235, 255) -- 770
				em.emissive = Color3(792098) -- 772
				emi = emi + 1 -- 773
			end -- 773
			earth.position = ____exports.planeToWorld(options.home, 0) -- 775
			root:addChild(earth) -- 776
		end -- 776
	end -- 776
	local probe = ____exports.createProbe(root, { -- 786
		scale = options.probeScale, -- 787
		probePath = options.probePath, -- 788
		bodyPath = options.probeBodyPath, -- 789
		antennaPath = options.probeAntennaPath, -- 790
		antennaPivotY = options.probeAntennaPivotY, -- 791
		bodyRadius = options.probeBodyRadius, -- 792
		atlasPath = options.probeAtlasPath -- 793
	}) -- 793
	if probe == nil then -- 793
		return nil -- 795
	end -- 795
	local probeNode = probe.node -- 796
	local antennaModel = probe.antenna -- 797
	local probeRadius = probe.radius -- 798
	local bodyYawDeg = 0 -- 801
	local backdrop = ____exports.createStarBackdrop(root) -- 805
	local glowNode = nil -- 813
	local glowScale = 0 -- 816
	if hasStar and starWorld ~= nil then -- 816
		glowScale = SunGlowScale * starRadius * 2 -- 818
		local glowPath = "Assets/Model/StarQuad.gltf" -- 819
		if Content:exist(glowPath) then -- 819
			local glowModel = Model3D(glowPath) -- 821
			if glowModel ~= nil then -- 821
				local glowTex = Texture2D("Assets/Image/glow.png") -- 823
				local gl = glowModel:getMaterial(0) -- 824
				if gl ~= nil and glowTex ~= nil then -- 824
					gl:setBaseColorTexture(glowTex) -- 826
					gl:setEmissiveTexture(glowTex) -- 827
					gl.baseColor = Color(0, 0, 0, 255) -- 828
					gl.emissive = Color3(13154456) -- 829
					gl.roughness = 1 -- 830
					gl.metallic = 0 -- 831
					gl.alphaMode = 2 -- 832
				end -- 832
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 834
				glowModel.position = starWorld -- 835
				root:addChild(glowModel) -- 836
				glowNode = glowModel -- 837
			end -- 837
		end -- 837
	end -- 837
	local function syncBodies(t) -- 843
		for ____, p in ipairs(planets) do -- 844
			local wp = ____exports.planeToWorld( -- 845
				bodyPositionAt(p.def, t), -- 845
				0 -- 845
			) -- 845
			p.body.position = wp -- 846
			if p.ring ~= nil then -- 846
				p.ring.position = wp -- 847
			end -- 847
		end -- 847
		for ____, fo in ipairs(flowOrbits) do -- 853
			local c = orbitCenterAt(fo.def, t) -- 854
			local r = fo.def.orbitRadius -- 855
			local n = #fo.dots -- 856
			do -- 856
				local k = 0 -- 857
				while k < n do -- 857
					local a = flowDotAngle(fo.def, t, k, n) -- 858
					fo.dots[k + 1].position = Vec3( -- 859
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 860
						0, -- 861
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 862
					) -- 862
					k = k + 1 -- 857
				end -- 857
			end -- 857
		end -- 857
	end -- 843
	local function syncProbe(p) -- 868
		probeNode.position = ____exports.planeToWorld(p, 0) -- 869
		if antennaModel ~= nil and options.home ~= nil then -- 869
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 875
		end -- 875
	end -- 868
	local function faceVelocity(v) -- 882
		local yaw = ____exports.probeYawForVelocity(v) -- 883
		if yaw == nil then -- 883
			return -- 884
		end -- 884
		bodyYawDeg = yaw -- 885
		probeNode.angleY = bodyYawDeg -- 886
	end -- 882
	local function syncBackdrop(eye, target) -- 890
		if backdrop ~= nil then -- 890
			backdrop:sync(eye, target) -- 891
		end -- 891
		if glowNode ~= nil and starWorld ~= nil then -- 891
			local dx = eye.x - starWorld.x -- 894
			local dy = eye.y - starWorld.y -- 895
			local dz = eye.z - starWorld.z -- 896
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 896
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 898
			end -- 898
			local flat = math.sqrt(dy * dy + dz * dz) -- 901
			local tilt = flat > 0.000001 and math.atan( -- 902
				math.abs(dy), -- 902
				flat -- 902
			) or 0 -- 902
			local c = math.cos(tilt) -- 903
			local stretch = c > 0.45 and 1 / c or 2.2 -- 904
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 905
		end -- 905
	end -- 890
	syncBodies(0) -- 910
	syncProbe(probeStart) -- 911
	return { -- 913
		syncBodies = syncBodies, -- 914
		syncProbe = syncProbe, -- 915
		faceVelocity = faceVelocity, -- 916
		syncBackdrop = syncBackdrop, -- 917
		probe = probeNode, -- 918
		antenna = antennaModel, -- 919
		planets = planets, -- 920
		probeRadius = probeRadius -- 921
	} -- 921
end -- 576
return ____exports -- 576
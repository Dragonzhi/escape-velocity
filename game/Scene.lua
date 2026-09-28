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
local ____Tuning = require("game.Tuning") -- 37
local SPIN_GAME_SEC = ____Tuning.SPIN_GAME_SEC -- 37
--- 平面坐标 → 世界坐标（y 恒为 0，黄道面水平）。
function ____exports.planeToWorld(p, y) -- 40
	return Vec3(p.x * PlaneToWorldX, y, p.y * PlaneToWorldZ) -- 41
end -- 40
local MODEL_RADIUS = { -- 59
	{name = "Sun", k = 1}, -- 62
	{name = "Moon", k = 1}, -- 63
	{name = "Planet_Earth", k = 1}, -- 64
	{name = "Planet_Venus", k = 1}, -- 65
	{name = "Planet_Mars", k = 1}, -- 66
	{name = "Planet_Jupiter", k = 1}, -- 67
	{name = "Planet_Neptune", k = 1}, -- 68
	{name = "Planet_Saturn", k = 1}, -- 72
	{name = "Planet_Uranus", k = 1} -- 73
} -- 73
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 77
	do -- 77
		local i = 0 -- 78
		while i < #MODEL_RADIUS do -- 78
			if MODEL_RADIUS[i + 1].name == name then -- 78
				return MODEL_RADIUS[i + 1].k -- 79
			end -- 79
			i = i + 1 -- 78
		end -- 78
	end -- 78
	return 1 -- 81
end -- 77
--- 贴图表（S3.14 建模交付）。
-- 
-- ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
--    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
-- ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
--    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
--    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
local PLANET_TEX = { -- 107
	{name = "Sun", base = "sun.jpg", emissive = "sun.jpg", emisMul = 16777215}, -- 108
	{name = "Moon", base = "moon.jpg"}, -- 109
	{name = "Planet_Earth", base = "planet_earth.jpg", emissive = "planet_earth_emissive.png", emisMul = 2763306}, -- 110
	{name = "Planet_Venus", base = "planet_venus.jpg"}, -- 111
	{name = "Planet_Mars", base = "planet_mars.jpg"}, -- 112
	{name = "Planet_Jupiter", base = "planet_jupiter.jpg"}, -- 113
	{name = "Planet_Saturn", base = "planet_saturn.jpg", ring = "planet_saturn_ring.png"}, -- 114
	{name = "Planet_Uranus", base = "planet_uranus.jpg", ring = "planet_uranus_ring.png"}, -- 115
	{name = "Planet_Neptune", base = "planet_neptune.jpg"} -- 116
} -- 116
--- 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。
local function redOf(hex) -- 120
	return math.floor(hex / 65536) % 256 -- 120
end -- 120
local function greenOf(hex) -- 121
	return math.floor(hex / 256) % 256 -- 121
end -- 121
local function blueOf(hex) -- 122
	return math.floor(hex) % 256 -- 122
end -- 122
--- 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。
function ____exports.packColor(r, g, b) -- 125
	return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) -- 126
end -- 125
--- 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。
local function textureOf(file) -- 130
	if file == "" then -- 130
		return nil -- 131
	end -- 131
	local path = "Assets/Image/" .. file -- 132
	if not Content:exist(path) then -- 132
		return nil -- 133
	end -- 133
	return Texture2D(path) -- 134
end -- 130
--- 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
-- 
-- @param model 已加载的模型
-- @param modelName 模型名（不含路径与扩展名）
-- @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
-- @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
function ____exports.applyPlanetTexture(model, modelName, tintHex, emissiveHex) -- 145
	local def = nil -- 146
	do -- 146
		local i = 0 -- 147
		while i < #PLANET_TEX do -- 147
			if PLANET_TEX[i + 1].name == modelName then -- 147
				def = PLANET_TEX[i + 1] -- 148
			end -- 148
			i = i + 1 -- 147
		end -- 147
	end -- 147
	local baseTex = textureOf(def ~= nil and def.base or "") -- 150
	local emiTex = textureOf(def ~= nil and def.emissive ~= nil and def.emissive or "") -- 151
	local ringTex = textureOf(def ~= nil and def.ring ~= nil and def.ring or "") -- 152
	local emiMul = emissiveHex -- 153
	if emiMul == 0 and emiTex ~= nil then -- 153
		emiMul = def ~= nil and def.emisMul ~= nil and def.emisMul or 2763306 -- 155
	end -- 155
	local i = 0 -- 158
	while i < 64 do -- 158
		local mat = model:getMaterial(i) -- 160
		if mat == nil then -- 160
			break -- 161
		end -- 161
		local isRing = ringTex ~= nil and mat.alphaMode == 2 -- 162
		if isRing then -- 162
			mat:setBaseColorTexture(ringTex) -- 164
			mat.baseColor = Color(255, 255, 255, 255) -- 165
		elseif baseTex ~= nil then -- 165
			mat:setBaseColorTexture(baseTex) -- 168
			mat.baseColor = Color(255, 255, 255, 255) -- 169
		elseif tintHex > 0 then -- 169
			mat.baseColor = Color( -- 171
				redOf(tintHex), -- 171
				greenOf(tintHex), -- 171
				blueOf(tintHex), -- 171
				255 -- 171
			) -- 171
		end -- 171
		if not isRing and emiTex ~= nil and emiMul > 0 then -- 171
			mat:setEmissiveTexture(emiTex) -- 174
			mat.emissive = Color3(emiMul) -- 175
		end -- 175
		i = i + 1 -- 177
	end -- 177
end -- 145
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
local ProbeYawOffsetDeg = -90 -- 196
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 203
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 349
	local i = 0 -- 350
	while i < 64 do -- 350
		local mat = model:getMaterial(i) -- 352
		if mat == nil then -- 352
			break -- 353
		end -- 353
		mat:setBaseColorTexture(tex) -- 354
		i = i + 1 -- 355
	end -- 355
end -- 349
function ____exports.createProbe(parent, opts) -- 359
	local scale = opts.scale -- 360
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 361
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 362
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 363
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 366
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 369
	if bodyModel == nil and singleModel == nil then -- 369
		return nil -- 370
	end -- 370
	local node = Node3D() -- 372
	parent:addChild(node) -- 373
	if bodyModel ~= nil then -- 373
		bodyModel.scale = Vec3(scale, scale, scale) -- 376
		node:addChild(bodyModel) -- 377
	end -- 377
	if singleModel ~= nil then -- 377
		singleModel.scale = Vec3(scale, scale, scale) -- 380
		node:addChild(singleModel) -- 381
	end -- 381
	if bodyModel ~= nil and antennaModel ~= nil then -- 381
		antennaModel.scale = Vec3(scale, scale, scale) -- 388
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 389
		node:addChild(antennaModel) -- 390
	end -- 390
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 390
		local atlas = Texture2D(opts.atlasPath) -- 396
		if atlas ~= nil then -- 396
			if bodyModel ~= nil then -- 396
				applyAtlas(bodyModel, atlas) -- 398
			end -- 398
			if singleModel ~= nil then -- 398
				applyAtlas(singleModel, atlas) -- 399
			end -- 399
			if antennaModel ~= nil then -- 399
				applyAtlas(antennaModel, atlas) -- 400
			end -- 400
		end -- 400
	end -- 400
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 404
end -- 359
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 429
	local ex = (target.x - probe.x) * PlaneToWorldX -- 430
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 431
	local dist = math.sqrt(ex * ex + ez * ez) -- 432
	if dist <= 0.0001 then -- 432
		return -- 433
	end -- 433
	local tiltFactor = (dist - 0.5) / 3 -- 434
	if tiltFactor < 0 then -- 434
		tiltFactor = 0 -- 435
	end -- 435
	if tiltFactor > 1 then -- 435
		tiltFactor = 1 -- 436
	end -- 436
	local tilt = 46 * tiltFactor -- 437
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 438
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 439
end -- 429
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 449
	local wx = v.x * PlaneToWorldX -- 450
	local wz = v.y * PlaneToWorldZ -- 451
	if wx * wx + wz * wz < 1e-12 then -- 451
		return nil -- 452
	end -- 452
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 453
end -- 449
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 457
local BackdropHalf = 560 -- 458
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 461
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 463
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 471
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
function ____exports.createStarBackdrop(root) -- 496
	local tex = Texture2D("Assets/Image/starfield.png") -- 497
	if Content:exist(SkySpherePath) then -- 497
		local sphere = Model3D(SkySpherePath) -- 501
		if sphere ~= nil then -- 501
			local sm = sphere:getMaterial(0) -- 503
			if sm ~= nil and tex ~= nil then -- 503
				sm:setEmissiveTexture(tex) -- 507
				sm.baseColor = Color(0, 0, 0, 255) -- 508
				sm.emissive = Color3(StarBrightnessHex) -- 509
				sm.roughness = 1 -- 510
				sm.metallic = 0 -- 511
			end -- 511
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 513
			sphere.position = Vec3(0, 0, 0) -- 514
			root:addChild(sphere) -- 515
			return { -- 516
				node = sphere, -- 517
				sync = function(____, eye, target) -- 518
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 519
				end -- 518
			} -- 518
		end -- 518
	end -- 518
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 526
	if backdrop == nil then -- 526
		return nil -- 527
	end -- 527
	local bm = backdrop:getMaterial(0) -- 528
	if bm ~= nil and tex ~= nil then -- 528
		bm:setEmissiveTexture(tex) -- 530
		bm.baseColor = Color(0, 0, 0, 255) -- 531
		bm.emissive = Color3(StarBrightnessHex) -- 532
		bm.roughness = 1 -- 533
		bm.metallic = 0 -- 534
	end -- 534
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 536
	backdrop.angleX = -45 -- 537
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 538
	root:addChild(backdrop) -- 539
	return { -- 540
		node = backdrop, -- 541
		sync = function(____, eye, target) -- 542
			local dx = target.x - eye.x -- 543
			local dy = target.y - eye.y -- 544
			local dz = target.z - eye.z -- 545
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 546
			if len < 0.000001 then -- 546
				return -- 547
			end -- 547
			local s = BackdropDist / len -- 548
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 549
		end -- 542
	} -- 542
end -- 496
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 556
local FlowDotTexturePath = "Assets/Image/glow.png" -- 557
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 562
local FlowDotMaxScale = 2 -- 563
local FlowDotScalePerRadius = 0.012 -- 564
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 566
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 579
	local ____options_0 = options -- 580
	local root = ____options_0.root -- 580
	local bodies = ____options_0.bodies -- 580
	local visuals = ____options_0.visuals -- 580
	local probeStart = ____options_0.probeStart -- 580
	local starWorld = nil -- 588
	local starRadius = 0 -- 589
	local starGm = 0 -- 590
	do -- 590
		local i = 0 -- 591
		while i < #bodies do -- 591
			do -- 591
				local b = bodies[i + 1] -- 592
				if b.orbitRadius ~= 0 then -- 592
					goto __continue55 -- 593
				end -- 593
				if b.gm <= starGm then -- 593
					goto __continue55 -- 594
				end -- 594
				starGm = b.gm -- 595
				starRadius = b.radius -- 596
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 597
			end -- 597
			::__continue55:: -- 597
			i = i + 1 -- 591
		end -- 591
	end -- 591
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 599
	do -- 599
		local light = DirectionalLight3D() -- 608
		light.color = Color3(16774106) -- 609
		light.intensity = 3.6 -- 610
		light.angleX = -42 -- 611
		light.angleY = 75 -- 612
		root:addChild(light) -- 613
	end -- 613
	local starIndex = -1 -- 616
	if hasStar then -- 616
		local best = 0 -- 618
		do -- 618
			local i = 0 -- 619
			while i < #bodies do -- 619
				local b = bodies[i + 1] -- 620
				if b.orbitRadius == 0 and b.gm > best then -- 620
					best = b.gm -- 622
					starIndex = i -- 623
				end -- 623
				i = i + 1 -- 619
			end -- 619
		end -- 619
	end -- 619
	local planets = {} -- 629
	do -- 629
		local i = 0 -- 630
		while i < #bodies do -- 630
			local def = bodies[i + 1] -- 631
			local vis = visuals[i + 1] -- 632
			local bodyModel = nil -- 635
			local k = 1 -- 636
			local modelName = vis.model ~= nil and vis.model or "" -- 637
			if modelName ~= "" then -- 637
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 639
				if loaded ~= nil then -- 639
					bodyModel = loaded -- 641
					k = ____exports.modelRadius(modelName) -- 642
				end -- 642
			end -- 642
			if bodyModel == nil then -- 642
				bodyModel = Model3D(options.spherePath) -- 646
				k = 1 -- 647
			end -- 647
			if bodyModel == nil then -- 647
				return nil -- 649
			end -- 649
			local scale = vis.displayRadius / k -- 652
			bodyModel.scale = Vec3(scale, scale, scale) -- 653
			____exports.applyPlanetTexture( -- 660
				bodyModel, -- 660
				modelName, -- 660
				____exports.packColor(vis.r, vis.g, vis.b), -- 660
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 661
			) -- 661
			root:addChild(bodyModel) -- 663
			local ringNode = nil -- 666
			if modelName == "" and vis.ring then -- 666
				local ring = Model3D(options.ringPath) -- 668
				if ring ~= nil then -- 668
					local rs = scale * 1.5 -- 671
					ring.scale = Vec3(rs, rs, rs) -- 672
					root:addChild(ring) -- 673
					ringNode = ring -- 674
				end -- 674
			end -- 674
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 678
			i = i + 1 -- 630
		end -- 630
	end -- 630
	do -- 630
		local i = 0 -- 686
		while i < #bodies do -- 686
			do -- 686
				local def = bodies[i + 1] -- 687
				if def.orbitRadius <= 0 then -- 687
					goto __continue72 -- 688
				end -- 688
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 689
				if not Content:exist(ringPath) then -- 689
					goto __continue72 -- 691
				end -- 691
				local orbitNode = Model3D(ringPath) -- 692
				if orbitNode == nil then -- 692
					goto __continue72 -- 693
				end -- 693
				local oi = 0 -- 694
				while oi < 8 do -- 694
					local om = orbitNode:getMaterial(oi) -- 696
					if om == nil then -- 696
						break -- 697
					end -- 697
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 699
					oi = oi + 1 -- 700
				end -- 700
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 702
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 703
				root:addChild(orbitNode) -- 704
			end -- 704
			::__continue72:: -- 704
			i = i + 1 -- 686
		end -- 686
	end -- 686
	local flowOrbits = {} -- 717
	local ____Content_exist_result_1 -- 718
	if Content:exist(FlowDotTexturePath) then -- 718
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 718
	else -- 718
		____Content_exist_result_1 = nil -- 718
	end -- 718
	local flowDotTex = ____Content_exist_result_1 -- 718
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 718
		do -- 718
			local i = 0 -- 721
			while i < #bodies do -- 721
				do -- 721
					local def = bodies[i + 1] -- 722
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 722
						goto __continue80 -- 724
					end -- 724
					local dots = {} -- 725
					do -- 725
						local k = 0 -- 726
						while k < FlowDotsPerOrbit do -- 726
							local dot = Model3D(FlowDotModelPath) -- 727
							if dot == nil then -- 727
								break -- 728
							end -- 728
							local dm = dot:getMaterial(0) -- 732
							if dm ~= nil then -- 732
								if flowDotTex ~= nil then -- 732
									dm:setBaseColorTexture(flowDotTex) -- 735
									dm:setEmissiveTexture(flowDotTex) -- 736
								end -- 736
								dm.baseColor = Color(0, 0, 0, 255) -- 738
								dm.emissive = Color3(FlowDotEmissiveHex) -- 739
								dm.roughness = 1 -- 740
								dm.metallic = 0 -- 741
								dm.alphaMode = 2 -- 742
							end -- 742
							local s = def.orbitRadius * FlowDotScalePerRadius -- 744
							if s < FlowDotMinScale then -- 744
								s = FlowDotMinScale -- 745
							end -- 745
							if s > FlowDotMaxScale then -- 745
								s = FlowDotMaxScale -- 746
							end -- 746
							dot.scale = Vec3(s, s, s) -- 747
							dot.angleX = -90 -- 748
							root:addChild(dot) -- 749
							dots[#dots + 1] = dot -- 750
							k = k + 1 -- 726
						end -- 726
					end -- 726
					if #dots == 0 then -- 726
						goto __continue80 -- 752
					end -- 752
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 753
				end -- 753
				::__continue80:: -- 753
				i = i + 1 -- 721
			end -- 721
		end -- 721
		if #flowOrbits > 0 then -- 721
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 756
		end -- 756
	end -- 756
	if options.home ~= nil then -- 756
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 765
		if earth ~= nil then -- 765
			local ke = ____exports.modelRadius("Planet_Earth") -- 767
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 768
			local es = hr / ke -- 769
			earth.scale = Vec3(es, es, es) -- 770
			local emi = 0 -- 771
			while emi < 64 do -- 771
				local em = earth:getMaterial(emi) -- 773
				if em == nil then -- 773
					break -- 774
				end -- 774
				em.baseColor = Color(110, 170, 235, 255) -- 775
				em.emissive = Color3(792098) -- 777
				emi = emi + 1 -- 778
			end -- 778
			earth.position = ____exports.planeToWorld(options.home, 0) -- 780
			root:addChild(earth) -- 781
		end -- 781
	end -- 781
	local probe = ____exports.createProbe(root, { -- 791
		scale = options.probeScale, -- 792
		probePath = options.probePath, -- 793
		bodyPath = options.probeBodyPath, -- 794
		antennaPath = options.probeAntennaPath, -- 795
		antennaPivotY = options.probeAntennaPivotY, -- 796
		bodyRadius = options.probeBodyRadius, -- 797
		atlasPath = options.probeAtlasPath -- 798
	}) -- 798
	if probe == nil then -- 798
		return nil -- 800
	end -- 800
	local probeNode = probe.node -- 801
	local antennaModel = probe.antenna -- 802
	local probeRadius = probe.radius -- 803
	local bodyYawDeg = 0 -- 806
	local backdrop = ____exports.createStarBackdrop(root) -- 810
	local glowNode = nil -- 818
	local glowScale = 0 -- 821
	if hasStar and starWorld ~= nil then -- 821
		glowScale = SunGlowScale * starRadius * 2 -- 823
		local glowPath = "Assets/Model/StarQuad.gltf" -- 824
		if Content:exist(glowPath) then -- 824
			local glowModel = Model3D(glowPath) -- 826
			if glowModel ~= nil then -- 826
				local glowTex = Texture2D("Assets/Image/glow.png") -- 828
				local gl = glowModel:getMaterial(0) -- 829
				if gl ~= nil and glowTex ~= nil then -- 829
					gl:setBaseColorTexture(glowTex) -- 831
					gl:setEmissiveTexture(glowTex) -- 832
					gl.baseColor = Color(0, 0, 0, 255) -- 833
					gl.emissive = Color3(13154456) -- 834
					gl.roughness = 1 -- 835
					gl.metallic = 0 -- 836
					gl.alphaMode = 2 -- 837
				end -- 837
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 839
				glowModel.position = starWorld -- 840
				root:addChild(glowModel) -- 841
				glowNode = glowModel -- 842
			end -- 842
		end -- 842
	end -- 842
	local function syncBodies(t) -- 848
		do -- 848
			local i = 0 -- 849
			while i < #planets do -- 849
				local p = planets[i + 1] -- 850
				local wp = ____exports.planeToWorld( -- 851
					bodyPositionAt(p.def, t), -- 851
					0 -- 851
				) -- 851
				p.body.position = wp -- 852
				if p.ring ~= nil then -- 852
					p.ring.position = wp -- 853
				end -- 853
				local vis = visuals[i + 1] -- 857
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 858
				if spin ~= nil and spin > 0 then -- 858
					local turns = t / spin -- 860
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 861
				end -- 861
				i = i + 1 -- 849
			end -- 849
		end -- 849
		for ____, fo in ipairs(flowOrbits) do -- 868
			local c = orbitCenterAt(fo.def, t) -- 869
			local r = fo.def.orbitRadius -- 870
			local n = #fo.dots -- 871
			do -- 871
				local k = 0 -- 872
				while k < n do -- 872
					local a = flowDotAngle(fo.def, t, k, n) -- 873
					fo.dots[k + 1].position = Vec3( -- 874
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 875
						0, -- 876
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 877
					) -- 877
					k = k + 1 -- 872
				end -- 872
			end -- 872
		end -- 872
	end -- 848
	local function syncProbe(p) -- 883
		probeNode.position = ____exports.planeToWorld(p, 0) -- 884
		if antennaModel ~= nil and options.home ~= nil then -- 884
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 890
		end -- 890
	end -- 883
	local function faceVelocity(v) -- 897
		local yaw = ____exports.probeYawForVelocity(v) -- 898
		if yaw == nil then -- 898
			return -- 899
		end -- 899
		bodyYawDeg = yaw -- 900
		probeNode.angleY = bodyYawDeg -- 901
	end -- 897
	local function syncBackdrop(eye, target) -- 905
		if backdrop ~= nil then -- 905
			backdrop:sync(eye, target) -- 906
		end -- 906
		if glowNode ~= nil and starWorld ~= nil then -- 906
			local dx = eye.x - starWorld.x -- 909
			local dy = eye.y - starWorld.y -- 910
			local dz = eye.z - starWorld.z -- 911
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 911
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 913
			end -- 913
			local flat = math.sqrt(dy * dy + dz * dz) -- 916
			local tilt = flat > 0.000001 and math.atan( -- 917
				math.abs(dy), -- 917
				flat -- 917
			) or 0 -- 917
			local c = math.cos(tilt) -- 918
			local stretch = c > 0.45 and 1 / c or 2.2 -- 919
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 920
		end -- 920
	end -- 905
	syncBodies(0) -- 925
	syncProbe(probeStart) -- 926
	return { -- 928
		syncBodies = syncBodies, -- 929
		syncProbe = syncProbe, -- 930
		faceVelocity = faceVelocity, -- 931
		syncBackdrop = syncBackdrop, -- 932
		probe = probeNode, -- 933
		antenna = antennaModel, -- 934
		planets = planets, -- 935
		probeRadius = probeRadius -- 936
	} -- 936
end -- 579
return ____exports -- 579
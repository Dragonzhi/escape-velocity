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
	{name = "Planet_Mercury", k = 1}, -- 65
	{name = "Planet_Venus", k = 1}, -- 66
	{name = "Planet_Mars", k = 1}, -- 67
	{name = "Planet_Jupiter", k = 1}, -- 68
	{name = "Planet_Neptune", k = 1}, -- 69
	{name = "Planet_Saturn", k = 1}, -- 73
	{name = "Planet_Uranus", k = 1} -- 74
} -- 74
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 78
	do -- 78
		local i = 0 -- 79
		while i < #MODEL_RADIUS do -- 79
			if MODEL_RADIUS[i + 1].name == name then -- 79
				return MODEL_RADIUS[i + 1].k -- 80
			end -- 80
			i = i + 1 -- 79
		end -- 79
	end -- 79
	return 1 -- 82
end -- 78
--- 贴图表（S3.14 建模交付）。
-- 
-- ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
--    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
-- ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
--    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
--    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
local PLANET_TEX = { -- 108
	{name = "Sun", base = "sun.jpg", emissive = "sun.jpg", emisMul = 16777215}, -- 109
	{name = "Moon", base = "moon.jpg"}, -- 110
	{name = "Planet_Earth", base = "planet_earth.jpg", emissive = "planet_earth_emissive.png", emisMul = 2763306}, -- 111
	{name = "Planet_Mercury", base = "mercury.jpg"}, -- 112
	{name = "Planet_Venus", base = "planet_venus.jpg"}, -- 113
	{name = "Planet_Mars", base = "planet_mars.jpg"}, -- 114
	{name = "Planet_Jupiter", base = "planet_jupiter.jpg"}, -- 115
	{name = "Planet_Saturn", base = "planet_saturn.jpg", ring = "planet_saturn_ring.png"}, -- 116
	{name = "Planet_Uranus", base = "planet_uranus.jpg", ring = "planet_uranus_ring.png"}, -- 117
	{name = "Planet_Neptune", base = "planet_neptune.jpg"} -- 118
} -- 118
--- 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。
local function redOf(hex) -- 122
	return math.floor(hex / 65536) % 256 -- 122
end -- 122
local function greenOf(hex) -- 123
	return math.floor(hex / 256) % 256 -- 123
end -- 123
local function blueOf(hex) -- 124
	return math.floor(hex) % 256 -- 124
end -- 124
--- 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。
function ____exports.packColor(r, g, b) -- 127
	return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) -- 128
end -- 127
--- 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。
local function textureOf(file) -- 132
	if file == "" then -- 132
		return nil -- 133
	end -- 133
	local path = "Assets/Image/" .. file -- 134
	if not Content:exist(path) then -- 134
		return nil -- 135
	end -- 135
	return Texture2D(path) -- 136
end -- 132
--- 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
-- 
-- @param model 已加载的模型
-- @param modelName 模型名（不含路径与扩展名）
-- @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
-- @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
function ____exports.applyPlanetTexture(model, modelName, tintHex, emissiveHex) -- 147
	local def = nil -- 148
	do -- 148
		local i = 0 -- 149
		while i < #PLANET_TEX do -- 149
			if PLANET_TEX[i + 1].name == modelName then -- 149
				def = PLANET_TEX[i + 1] -- 150
			end -- 150
			i = i + 1 -- 149
		end -- 149
	end -- 149
	local baseTex = textureOf(def ~= nil and def.base or "") -- 152
	local emiTex = textureOf(def ~= nil and def.emissive ~= nil and def.emissive or "") -- 153
	local ringTex = textureOf(def ~= nil and def.ring ~= nil and def.ring or "") -- 154
	local emiMul = emissiveHex -- 155
	if emiMul == 0 and emiTex ~= nil then -- 155
		emiMul = def ~= nil and def.emisMul ~= nil and def.emisMul or 2763306 -- 157
	end -- 157
	local i = 0 -- 160
	while i < 64 do -- 160
		local mat = model:getMaterial(i) -- 162
		if mat == nil then -- 162
			break -- 163
		end -- 163
		local isRing = ringTex ~= nil and mat.alphaMode == 2 -- 164
		if isRing then -- 164
			mat:setBaseColorTexture(ringTex) -- 166
			mat.baseColor = Color(255, 255, 255, 255) -- 167
		elseif baseTex ~= nil then -- 167
			mat:setBaseColorTexture(baseTex) -- 170
			mat.baseColor = Color(255, 255, 255, 255) -- 171
		elseif tintHex > 0 then -- 171
			mat.baseColor = Color( -- 173
				redOf(tintHex), -- 173
				greenOf(tintHex), -- 173
				blueOf(tintHex), -- 173
				255 -- 173
			) -- 173
		end -- 173
		if not isRing and emiTex ~= nil and emiMul > 0 then -- 173
			mat:setEmissiveTexture(emiTex) -- 176
			mat.emissive = Color3(emiMul) -- 177
		end -- 177
		i = i + 1 -- 179
	end -- 179
end -- 147
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
local ProbeYawOffsetDeg = -90 -- 198
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 205
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 357
	local i = 0 -- 358
	while i < 64 do -- 358
		local mat = model:getMaterial(i) -- 360
		if mat == nil then -- 360
			break -- 361
		end -- 361
		mat:setBaseColorTexture(tex) -- 362
		i = i + 1 -- 363
	end -- 363
end -- 357
function ____exports.createProbe(parent, opts) -- 367
	local scale = opts.scale -- 368
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 369
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 370
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 371
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 374
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 377
	if bodyModel == nil and singleModel == nil then -- 377
		return nil -- 378
	end -- 378
	local node = Node3D() -- 380
	parent:addChild(node) -- 381
	if bodyModel ~= nil then -- 381
		bodyModel.scale = Vec3(scale, scale, scale) -- 384
		node:addChild(bodyModel) -- 385
	end -- 385
	if singleModel ~= nil then -- 385
		singleModel.scale = Vec3(scale, scale, scale) -- 388
		node:addChild(singleModel) -- 389
	end -- 389
	if bodyModel ~= nil and antennaModel ~= nil then -- 389
		antennaModel.scale = Vec3(scale, scale, scale) -- 396
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 397
		node:addChild(antennaModel) -- 398
	end -- 398
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 398
		local atlas = Texture2D(opts.atlasPath) -- 404
		if atlas ~= nil then -- 404
			if bodyModel ~= nil then -- 404
				applyAtlas(bodyModel, atlas) -- 406
			end -- 406
			if singleModel ~= nil then -- 406
				applyAtlas(singleModel, atlas) -- 407
			end -- 407
			if antennaModel ~= nil then -- 407
				applyAtlas(antennaModel, atlas) -- 408
			end -- 408
		end -- 408
	end -- 408
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 412
end -- 367
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 437
	local ex = (target.x - probe.x) * PlaneToWorldX -- 438
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 439
	local dist = math.sqrt(ex * ex + ez * ez) -- 440
	if dist <= 0.0001 then -- 440
		return -- 441
	end -- 441
	local tiltFactor = (dist - 0.5) / 3 -- 442
	if tiltFactor < 0 then -- 442
		tiltFactor = 0 -- 443
	end -- 443
	if tiltFactor > 1 then -- 443
		tiltFactor = 1 -- 444
	end -- 444
	local tilt = 46 * tiltFactor -- 445
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 446
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 447
end -- 437
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 457
	local wx = v.x * PlaneToWorldX -- 458
	local wz = v.y * PlaneToWorldZ -- 459
	if wx * wx + wz * wz < 1e-12 then -- 459
		return nil -- 460
	end -- 460
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 461
end -- 457
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 465
local BackdropHalf = 560 -- 466
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 469
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 471
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 479
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
function ____exports.createStarBackdrop(root) -- 504
	local tex = Texture2D("Assets/Image/starfield.png") -- 505
	if Content:exist(SkySpherePath) then -- 505
		local sphere = Model3D(SkySpherePath) -- 509
		if sphere ~= nil then -- 509
			local sm = sphere:getMaterial(0) -- 511
			if sm ~= nil and tex ~= nil then -- 511
				sm:setEmissiveTexture(tex) -- 515
				sm.baseColor = Color(0, 0, 0, 255) -- 516
				sm.emissive = Color3(StarBrightnessHex) -- 517
				sm.roughness = 1 -- 518
				sm.metallic = 0 -- 519
			end -- 519
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 521
			sphere.position = Vec3(0, 0, 0) -- 522
			root:addChild(sphere) -- 523
			return { -- 524
				node = sphere, -- 525
				sync = function(____, eye, target) -- 526
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 527
				end -- 526
			} -- 526
		end -- 526
	end -- 526
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 534
	if backdrop == nil then -- 534
		return nil -- 535
	end -- 535
	local bm = backdrop:getMaterial(0) -- 536
	if bm ~= nil and tex ~= nil then -- 536
		bm:setEmissiveTexture(tex) -- 538
		bm.baseColor = Color(0, 0, 0, 255) -- 539
		bm.emissive = Color3(StarBrightnessHex) -- 540
		bm.roughness = 1 -- 541
		bm.metallic = 0 -- 542
	end -- 542
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 544
	backdrop.angleX = -45 -- 545
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 546
	root:addChild(backdrop) -- 547
	return { -- 548
		node = backdrop, -- 549
		sync = function(____, eye, target) -- 550
			local dx = target.x - eye.x -- 551
			local dy = target.y - eye.y -- 552
			local dz = target.z - eye.z -- 553
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 554
			if len < 0.000001 then -- 554
				return -- 555
			end -- 555
			local s = BackdropDist / len -- 556
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 557
		end -- 550
	} -- 550
end -- 504
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 564
local FlowDotTexturePath = "Assets/Image/glow.png" -- 565
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 570
local FlowDotMaxScale = 2 -- 571
local FlowDotScalePerRadius = 0.012 -- 572
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 574
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 587
	local ____options_0 = options -- 588
	local root = ____options_0.root -- 588
	local bodies = ____options_0.bodies -- 588
	local visuals = ____options_0.visuals -- 588
	local probeStart = ____options_0.probeStart -- 588
	local starWorld = nil -- 596
	local starRadius = 0 -- 597
	local starGm = 0 -- 598
	do -- 598
		local i = 0 -- 599
		while i < #bodies do -- 599
			do -- 599
				local b = bodies[i + 1] -- 600
				if b.orbitRadius ~= 0 then -- 600
					goto __continue55 -- 601
				end -- 601
				if b.gm <= starGm then -- 601
					goto __continue55 -- 602
				end -- 602
				starGm = b.gm -- 603
				starRadius = b.radius -- 604
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 605
			end -- 605
			::__continue55:: -- 605
			i = i + 1 -- 599
		end -- 599
	end -- 599
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 607
	do -- 607
		local light = DirectionalLight3D() -- 616
		light.color = Color3(16774106) -- 617
		light.intensity = 3.6 -- 618
		light.angleX = -42 -- 619
		light.angleY = 75 -- 620
		root:addChild(light) -- 621
	end -- 621
	local starIndex = -1 -- 624
	if hasStar then -- 624
		local best = 0 -- 626
		do -- 626
			local i = 0 -- 627
			while i < #bodies do -- 627
				local b = bodies[i + 1] -- 628
				if b.orbitRadius == 0 and b.gm > best then -- 628
					best = b.gm -- 630
					starIndex = i -- 631
				end -- 631
				i = i + 1 -- 627
			end -- 627
		end -- 627
	end -- 627
	local planets = {} -- 637
	do -- 637
		local i = 0 -- 638
		while i < #bodies do -- 638
			local def = bodies[i + 1] -- 639
			local vis = visuals[i + 1] -- 640
			local bodyModel = nil -- 643
			local k = 1 -- 644
			local modelName = vis.model ~= nil and vis.model or "" -- 645
			if modelName ~= "" then -- 645
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 647
				if loaded ~= nil then -- 647
					bodyModel = loaded -- 649
					k = ____exports.modelRadius(modelName) -- 650
				end -- 650
			end -- 650
			if bodyModel == nil then -- 650
				bodyModel = Model3D(options.spherePath) -- 654
				k = 1 -- 655
			end -- 655
			if bodyModel == nil then -- 655
				return nil -- 657
			end -- 657
			local scale = vis.displayRadius / k -- 660
			bodyModel.scale = Vec3(scale, scale, scale) -- 661
			____exports.applyPlanetTexture( -- 668
				bodyModel, -- 668
				modelName, -- 668
				____exports.packColor(vis.r, vis.g, vis.b), -- 668
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 669
			) -- 669
			root:addChild(bodyModel) -- 671
			local ringNode = nil -- 674
			if modelName == "" and vis.ring then -- 674
				local ring = Model3D(options.ringPath) -- 676
				if ring ~= nil then -- 676
					local rs = scale * 1.5 -- 679
					ring.scale = Vec3(rs, rs, rs) -- 680
					root:addChild(ring) -- 681
					ringNode = ring -- 682
				end -- 682
			end -- 682
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 686
			i = i + 1 -- 638
		end -- 638
	end -- 638
	do -- 638
		local i = 0 -- 697
		while i < #bodies do -- 697
			do -- 697
				if options.orbitRings == false then -- 697
					break -- 698
				end -- 698
				local def = bodies[i + 1] -- 699
				if def.orbitRadius <= 0 then -- 699
					goto __continue72 -- 700
				end -- 700
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 701
				if not Content:exist(ringPath) then -- 701
					goto __continue72 -- 703
				end -- 703
				local orbitNode = Model3D(ringPath) -- 704
				if orbitNode == nil then -- 704
					goto __continue72 -- 705
				end -- 705
				local oi = 0 -- 706
				while oi < 8 do -- 706
					local om = orbitNode:getMaterial(oi) -- 708
					if om == nil then -- 708
						break -- 709
					end -- 709
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 711
					oi = oi + 1 -- 712
				end -- 712
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 714
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 715
				root:addChild(orbitNode) -- 716
			end -- 716
			::__continue72:: -- 716
			i = i + 1 -- 697
		end -- 697
	end -- 697
	local flowOrbits = {} -- 729
	local ____Content_exist_result_1 -- 730
	if Content:exist(FlowDotTexturePath) then -- 730
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 730
	else -- 730
		____Content_exist_result_1 = nil -- 730
	end -- 730
	local flowDotTex = ____Content_exist_result_1 -- 730
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 730
		do -- 730
			local i = 0 -- 733
			while i < #bodies do -- 733
				do -- 733
					local def = bodies[i + 1] -- 734
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 734
						goto __continue81 -- 736
					end -- 736
					local dots = {} -- 737
					do -- 737
						local k = 0 -- 738
						while k < FlowDotsPerOrbit do -- 738
							local dot = Model3D(FlowDotModelPath) -- 739
							if dot == nil then -- 739
								break -- 740
							end -- 740
							local dm = dot:getMaterial(0) -- 744
							if dm ~= nil then -- 744
								if flowDotTex ~= nil then -- 744
									dm:setBaseColorTexture(flowDotTex) -- 747
									dm:setEmissiveTexture(flowDotTex) -- 748
								end -- 748
								dm.baseColor = Color(0, 0, 0, 255) -- 750
								dm.emissive = Color3(FlowDotEmissiveHex) -- 751
								dm.roughness = 1 -- 752
								dm.metallic = 0 -- 753
								dm.alphaMode = 2 -- 754
							end -- 754
							local s = def.orbitRadius * FlowDotScalePerRadius -- 756
							if s < FlowDotMinScale then -- 756
								s = FlowDotMinScale -- 757
							end -- 757
							if s > FlowDotMaxScale then -- 757
								s = FlowDotMaxScale -- 758
							end -- 758
							dot.scale = Vec3(s, s, s) -- 759
							dot.angleX = -90 -- 760
							root:addChild(dot) -- 761
							dots[#dots + 1] = dot -- 762
							k = k + 1 -- 738
						end -- 738
					end -- 738
					if #dots == 0 then -- 738
						goto __continue81 -- 764
					end -- 764
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 765
				end -- 765
				::__continue81:: -- 765
				i = i + 1 -- 733
			end -- 733
		end -- 733
		if #flowOrbits > 0 then -- 733
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 768
		end -- 768
	end -- 768
	if options.home ~= nil then -- 768
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 777
		if earth ~= nil then -- 777
			local ke = ____exports.modelRadius("Planet_Earth") -- 779
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 780
			local es = hr / ke -- 781
			earth.scale = Vec3(es, es, es) -- 782
			local emi = 0 -- 783
			while emi < 64 do -- 783
				local em = earth:getMaterial(emi) -- 785
				if em == nil then -- 785
					break -- 786
				end -- 786
				em.baseColor = Color(110, 170, 235, 255) -- 787
				em.emissive = Color3(792098) -- 789
				emi = emi + 1 -- 790
			end -- 790
			earth.position = ____exports.planeToWorld(options.home, 0) -- 792
			root:addChild(earth) -- 793
		end -- 793
	end -- 793
	local probe = ____exports.createProbe(root, { -- 803
		scale = options.probeScale, -- 804
		probePath = options.probePath, -- 805
		bodyPath = options.probeBodyPath, -- 806
		antennaPath = options.probeAntennaPath, -- 807
		antennaPivotY = options.probeAntennaPivotY, -- 808
		bodyRadius = options.probeBodyRadius, -- 809
		atlasPath = options.probeAtlasPath -- 810
	}) -- 810
	if probe == nil then -- 810
		return nil -- 812
	end -- 812
	local probeNode = probe.node -- 813
	local antennaModel = probe.antenna -- 814
	local probeRadius = probe.radius -- 815
	local bodyYawDeg = 0 -- 818
	local backdrop = ____exports.createStarBackdrop(root) -- 822
	local glowNode = nil -- 830
	local glowScale = 0 -- 833
	if hasStar and starWorld ~= nil then -- 833
		glowScale = SunGlowScale * starRadius * 2 -- 835
		local glowPath = "Assets/Model/StarQuad.gltf" -- 836
		if Content:exist(glowPath) then -- 836
			local glowModel = Model3D(glowPath) -- 838
			if glowModel ~= nil then -- 838
				local glowTex = Texture2D("Assets/Image/glow.png") -- 840
				local gl = glowModel:getMaterial(0) -- 841
				if gl ~= nil and glowTex ~= nil then -- 841
					gl:setBaseColorTexture(glowTex) -- 843
					gl:setEmissiveTexture(glowTex) -- 844
					gl.baseColor = Color(0, 0, 0, 255) -- 845
					gl.emissive = Color3(13154456) -- 846
					gl.roughness = 1 -- 847
					gl.metallic = 0 -- 848
					gl.alphaMode = 2 -- 849
				end -- 849
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 851
				glowModel.position = starWorld -- 852
				root:addChild(glowModel) -- 853
				glowNode = glowModel -- 854
			end -- 854
		end -- 854
	end -- 854
	local function syncBodies(t) -- 860
		do -- 860
			local i = 0 -- 861
			while i < #planets do -- 861
				local p = planets[i + 1] -- 862
				local wp = ____exports.planeToWorld( -- 863
					bodyPositionAt(p.def, t), -- 863
					0 -- 863
				) -- 863
				p.body.position = wp -- 864
				if p.ring ~= nil then -- 864
					p.ring.position = wp -- 865
				end -- 865
				local vis = visuals[i + 1] -- 869
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 870
				if spin ~= nil and spin > 0 then -- 870
					local turns = t / spin -- 872
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 873
				end -- 873
				i = i + 1 -- 861
			end -- 861
		end -- 861
		for ____, fo in ipairs(flowOrbits) do -- 880
			local c = orbitCenterAt(fo.def, t) -- 881
			local r = fo.def.orbitRadius -- 882
			local n = #fo.dots -- 883
			do -- 883
				local k = 0 -- 884
				while k < n do -- 884
					local a = flowDotAngle(fo.def, t, k, n) -- 885
					fo.dots[k + 1].position = Vec3( -- 886
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 887
						0, -- 888
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 889
					) -- 889
					k = k + 1 -- 884
				end -- 884
			end -- 884
		end -- 884
	end -- 860
	local function syncProbe(p) -- 895
		probeNode.position = ____exports.planeToWorld(p, 0) -- 896
		if antennaModel ~= nil and options.home ~= nil then -- 896
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 902
		end -- 902
	end -- 895
	local function faceVelocity(v) -- 909
		local yaw = ____exports.probeYawForVelocity(v) -- 910
		if yaw == nil then -- 910
			return -- 911
		end -- 911
		bodyYawDeg = yaw -- 912
		probeNode.angleY = bodyYawDeg -- 913
	end -- 909
	local function syncBackdrop(eye, target) -- 917
		if backdrop ~= nil then -- 917
			backdrop:sync(eye, target) -- 918
		end -- 918
		if glowNode ~= nil and starWorld ~= nil then -- 918
			local dx = eye.x - starWorld.x -- 921
			local dy = eye.y - starWorld.y -- 922
			local dz = eye.z - starWorld.z -- 923
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 923
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 925
			end -- 925
			local flat = math.sqrt(dy * dy + dz * dz) -- 928
			local tilt = flat > 0.000001 and math.atan( -- 929
				math.abs(dy), -- 929
				flat -- 929
			) or 0 -- 929
			local c = math.cos(tilt) -- 930
			local stretch = c > 0.45 and 1 / c or 2.2 -- 931
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 932
		end -- 932
	end -- 917
	syncBodies(0) -- 937
	syncProbe(probeStart) -- 938
	return { -- 940
		syncBodies = syncBodies, -- 941
		syncProbe = syncProbe, -- 942
		faceVelocity = faceVelocity, -- 943
		syncBackdrop = syncBackdrop, -- 944
		probe = probeNode, -- 945
		antenna = antennaModel, -- 946
		planets = planets, -- 947
		probeRadius = probeRadius -- 948
	} -- 948
end -- 587
return ____exports -- 587
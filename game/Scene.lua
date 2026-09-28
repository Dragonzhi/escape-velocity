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
	{name = "Planet_Uranus", k = 1}, -- 74
	{name = "Asteroid_Rock", k = 1}, -- 76
	{name = "Star_Crystal", k = 1}, -- 77
	{name = "Target_Gate", k = 1} -- 78
} -- 78
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 82
	do -- 82
		local i = 0 -- 83
		while i < #MODEL_RADIUS do -- 83
			if MODEL_RADIUS[i + 1].name == name then -- 83
				return MODEL_RADIUS[i + 1].k -- 84
			end -- 84
			i = i + 1 -- 83
		end -- 83
	end -- 83
	return 1 -- 86
end -- 82
--- 贴图表（S3.14 建模交付）。
-- 
-- ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
--    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
-- ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
--    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
--    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
local PLANET_TEX = { -- 112
	{name = "Sun", base = "sun.jpg", emissive = "sun.jpg", emisMul = 16777215}, -- 113
	{name = "Moon", base = "moon.jpg"}, -- 114
	{name = "Planet_Earth", base = "planet_earth.jpg", emissive = "planet_earth_emissive.png", emisMul = 2763306}, -- 115
	{name = "Planet_Mercury", base = "mercury.jpg"}, -- 116
	{name = "Planet_Venus", base = "planet_venus.jpg"}, -- 117
	{name = "Planet_Mars", base = "planet_mars.jpg"}, -- 118
	{name = "Planet_Jupiter", base = "planet_jupiter.jpg"}, -- 119
	{name = "Planet_Saturn", base = "planet_saturn.jpg", ring = "planet_saturn_ring.png"}, -- 120
	{name = "Planet_Uranus", base = "planet_uranus.jpg", ring = "planet_uranus_ring.png"}, -- 121
	{name = "Planet_Neptune", base = "planet_neptune.jpg"} -- 122
} -- 122
--- 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。
local function redOf(hex) -- 126
	return math.floor(hex / 65536) % 256 -- 126
end -- 126
local function greenOf(hex) -- 127
	return math.floor(hex / 256) % 256 -- 127
end -- 127
local function blueOf(hex) -- 128
	return math.floor(hex) % 256 -- 128
end -- 128
--- 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。
function ____exports.packColor(r, g, b) -- 131
	return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) -- 132
end -- 131
--- 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。
local function textureOf(file) -- 136
	if file == "" then -- 136
		return nil -- 137
	end -- 137
	local path = "Assets/Image/" .. file -- 138
	if not Content:exist(path) then -- 138
		return nil -- 139
	end -- 139
	return Texture2D(path) -- 140
end -- 136
--- 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
-- 
-- @param model 已加载的模型
-- @param modelName 模型名（不含路径与扩展名）
-- @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
-- @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
function ____exports.applyPlanetTexture(model, modelName, tintHex, emissiveHex) -- 151
	local def = nil -- 152
	do -- 152
		local i = 0 -- 153
		while i < #PLANET_TEX do -- 153
			if PLANET_TEX[i + 1].name == modelName then -- 153
				def = PLANET_TEX[i + 1] -- 154
			end -- 154
			i = i + 1 -- 153
		end -- 153
	end -- 153
	local baseTex = textureOf(def ~= nil and def.base or "") -- 156
	local emiTex = textureOf(def ~= nil and def.emissive ~= nil and def.emissive or "") -- 157
	local ringTex = textureOf(def ~= nil and def.ring ~= nil and def.ring or "") -- 158
	local emiMul = emissiveHex -- 159
	if emiMul == 0 and emiTex ~= nil then -- 159
		emiMul = def ~= nil and def.emisMul ~= nil and def.emisMul or 2763306 -- 161
	end -- 161
	local i = 0 -- 164
	while i < 64 do -- 164
		local mat = model:getMaterial(i) -- 166
		if mat == nil then -- 166
			break -- 167
		end -- 167
		local isRing = ringTex ~= nil and mat.alphaMode == 2 -- 168
		if isRing then -- 168
			mat:setBaseColorTexture(ringTex) -- 170
			mat.baseColor = Color(255, 255, 255, 255) -- 171
		elseif baseTex ~= nil then -- 171
			mat:setBaseColorTexture(baseTex) -- 174
			mat.baseColor = Color(255, 255, 255, 255) -- 175
		elseif tintHex > 0 then -- 175
			mat.baseColor = Color( -- 177
				redOf(tintHex), -- 177
				greenOf(tintHex), -- 177
				blueOf(tintHex), -- 177
				255 -- 177
			) -- 177
		end -- 177
		if not isRing and emiTex ~= nil and emiMul > 0 then -- 177
			mat:setEmissiveTexture(emiTex) -- 180
			mat.emissive = Color3(emiMul) -- 181
		end -- 181
		i = i + 1 -- 183
	end -- 183
end -- 151
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
local ProbeYawOffsetDeg = -90 -- 202
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 209
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 369
	local i = 0 -- 370
	while i < 64 do -- 370
		local mat = model:getMaterial(i) -- 372
		if mat == nil then -- 372
			break -- 373
		end -- 373
		mat:setBaseColorTexture(tex) -- 374
		i = i + 1 -- 375
	end -- 375
end -- 369
function ____exports.createProbe(parent, opts) -- 379
	local scale = opts.scale -- 380
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 381
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 382
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 383
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 386
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 389
	if bodyModel == nil and singleModel == nil then -- 389
		return nil -- 390
	end -- 390
	local node = Node3D() -- 392
	parent:addChild(node) -- 393
	if bodyModel ~= nil then -- 393
		bodyModel.scale = Vec3(scale, scale, scale) -- 396
		node:addChild(bodyModel) -- 397
	end -- 397
	if singleModel ~= nil then -- 397
		singleModel.scale = Vec3(scale, scale, scale) -- 400
		node:addChild(singleModel) -- 401
	end -- 401
	if bodyModel ~= nil and antennaModel ~= nil then -- 401
		antennaModel.scale = Vec3(scale, scale, scale) -- 408
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 409
		node:addChild(antennaModel) -- 410
	end -- 410
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 410
		local atlas = Texture2D(opts.atlasPath) -- 416
		if atlas ~= nil then -- 416
			if bodyModel ~= nil then -- 416
				applyAtlas(bodyModel, atlas) -- 418
			end -- 418
			if singleModel ~= nil then -- 418
				applyAtlas(singleModel, atlas) -- 419
			end -- 419
			if antennaModel ~= nil then -- 419
				applyAtlas(antennaModel, atlas) -- 420
			end -- 420
		end -- 420
	end -- 420
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 424
end -- 379
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 449
	local ex = (target.x - probe.x) * PlaneToWorldX -- 450
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 451
	local dist = math.sqrt(ex * ex + ez * ez) -- 452
	if dist <= 0.0001 then -- 452
		return -- 453
	end -- 453
	local tiltFactor = (dist - 0.5) / 3 -- 454
	if tiltFactor < 0 then -- 454
		tiltFactor = 0 -- 455
	end -- 455
	if tiltFactor > 1 then -- 455
		tiltFactor = 1 -- 456
	end -- 456
	local tilt = 46 * tiltFactor -- 457
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 458
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 459
end -- 449
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 469
	local wx = v.x * PlaneToWorldX -- 470
	local wz = v.y * PlaneToWorldZ -- 471
	if wx * wx + wz * wz < 1e-12 then -- 471
		return nil -- 472
	end -- 472
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 473
end -- 469
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 477
local BackdropHalf = 560 -- 478
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 481
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 483
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 491
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
function ____exports.createStarBackdrop(root) -- 516
	local tex = Texture2D("Assets/Image/starfield.png") -- 517
	if Content:exist(SkySpherePath) then -- 517
		local sphere = Model3D(SkySpherePath) -- 521
		if sphere ~= nil then -- 521
			local sm = sphere:getMaterial(0) -- 523
			if sm ~= nil and tex ~= nil then -- 523
				sm:setEmissiveTexture(tex) -- 527
				sm.baseColor = Color(0, 0, 0, 255) -- 528
				sm.emissive = Color3(StarBrightnessHex) -- 529
				sm.roughness = 1 -- 530
				sm.metallic = 0 -- 531
			end -- 531
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 533
			sphere.position = Vec3(0, 0, 0) -- 534
			root:addChild(sphere) -- 535
			return { -- 536
				node = sphere, -- 537
				sync = function(____, eye, target) -- 538
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 539
				end -- 538
			} -- 538
		end -- 538
	end -- 538
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 546
	if backdrop == nil then -- 546
		return nil -- 547
	end -- 547
	local bm = backdrop:getMaterial(0) -- 548
	if bm ~= nil and tex ~= nil then -- 548
		bm:setEmissiveTexture(tex) -- 550
		bm.baseColor = Color(0, 0, 0, 255) -- 551
		bm.emissive = Color3(StarBrightnessHex) -- 552
		bm.roughness = 1 -- 553
		bm.metallic = 0 -- 554
	end -- 554
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 556
	backdrop.angleX = -45 -- 557
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 558
	root:addChild(backdrop) -- 559
	return { -- 560
		node = backdrop, -- 561
		sync = function(____, eye, target) -- 562
			local dx = target.x - eye.x -- 563
			local dy = target.y - eye.y -- 564
			local dz = target.z - eye.z -- 565
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 566
			if len < 0.000001 then -- 566
				return -- 567
			end -- 567
			local s = BackdropDist / len -- 568
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 569
		end -- 562
	} -- 562
end -- 516
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 576
local FlowDotTexturePath = "Assets/Image/glow.png" -- 577
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 582
local FlowDotMaxScale = 2 -- 583
local FlowDotScalePerRadius = 0.012 -- 584
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 586
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 599
	local ____options_0 = options -- 600
	local root = ____options_0.root -- 600
	local bodies = ____options_0.bodies -- 600
	local visuals = ____options_0.visuals -- 600
	local probeStart = ____options_0.probeStart -- 600
	local starWorld = nil -- 608
	local starRadius = 0 -- 609
	local starGm = 0 -- 610
	do -- 610
		local i = 0 -- 611
		while i < #bodies do -- 611
			do -- 611
				local b = bodies[i + 1] -- 612
				if b.orbitRadius ~= 0 then -- 612
					goto __continue55 -- 613
				end -- 613
				if b.gm <= starGm then -- 613
					goto __continue55 -- 614
				end -- 614
				starGm = b.gm -- 615
				starRadius = b.radius -- 616
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 617
			end -- 617
			::__continue55:: -- 617
			i = i + 1 -- 611
		end -- 611
	end -- 611
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 619
	do -- 619
		local light = DirectionalLight3D() -- 628
		light.color = Color3(16774106) -- 629
		light.intensity = 3.6 -- 630
		light.angleX = -42 -- 631
		light.angleY = 75 -- 632
		root:addChild(light) -- 633
	end -- 633
	local starIndex = -1 -- 636
	if hasStar then -- 636
		local best = 0 -- 638
		do -- 638
			local i = 0 -- 639
			while i < #bodies do -- 639
				local b = bodies[i + 1] -- 640
				if b.orbitRadius == 0 and b.gm > best then -- 640
					best = b.gm -- 642
					starIndex = i -- 643
				end -- 643
				i = i + 1 -- 639
			end -- 639
		end -- 639
	end -- 639
	local planets = {} -- 649
	do -- 649
		local i = 0 -- 650
		while i < #bodies do -- 650
			local def = bodies[i + 1] -- 651
			local vis = visuals[i + 1] -- 652
			local bodyModel = nil -- 655
			local k = 1 -- 656
			local modelName = vis.model ~= nil and vis.model or "" -- 657
			if modelName ~= "" then -- 657
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 659
				if loaded ~= nil then -- 659
					bodyModel = loaded -- 661
					k = ____exports.modelRadius(modelName) -- 662
				end -- 662
			end -- 662
			if bodyModel == nil then -- 662
				bodyModel = Model3D(options.spherePath) -- 666
				k = 1 -- 667
			end -- 667
			if bodyModel == nil then -- 667
				return nil -- 669
			end -- 669
			local scale = vis.displayRadius / k -- 672
			bodyModel.scale = Vec3(scale, scale, scale) -- 673
			____exports.applyPlanetTexture( -- 680
				bodyModel, -- 680
				modelName, -- 680
				____exports.packColor(vis.r, vis.g, vis.b), -- 680
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 681
			) -- 681
			root:addChild(bodyModel) -- 683
			local ringNode = nil -- 686
			if modelName == "" and vis.ring then -- 686
				local ring = Model3D(options.ringPath) -- 688
				if ring ~= nil then -- 688
					local rs = scale * 1.5 -- 691
					ring.scale = Vec3(rs, rs, rs) -- 692
					root:addChild(ring) -- 693
					ringNode = ring -- 694
				end -- 694
			end -- 694
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 698
			i = i + 1 -- 650
		end -- 650
	end -- 650
	do -- 650
		local i = 0 -- 709
		while i < #bodies do -- 709
			do -- 709
				if options.orbitRings == false then -- 709
					break -- 710
				end -- 710
				local def = bodies[i + 1] -- 711
				if def.orbitRadius <= 0 then -- 711
					goto __continue72 -- 712
				end -- 712
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 713
				if not Content:exist(ringPath) then -- 713
					goto __continue72 -- 715
				end -- 715
				local orbitNode = Model3D(ringPath) -- 716
				if orbitNode == nil then -- 716
					goto __continue72 -- 717
				end -- 717
				local oi = 0 -- 718
				while oi < 8 do -- 718
					local om = orbitNode:getMaterial(oi) -- 720
					if om == nil then -- 720
						break -- 721
					end -- 721
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 723
					oi = oi + 1 -- 724
				end -- 724
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 726
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 727
				root:addChild(orbitNode) -- 728
			end -- 728
			::__continue72:: -- 728
			i = i + 1 -- 709
		end -- 709
	end -- 709
	local flowOrbits = {} -- 741
	local ____Content_exist_result_1 -- 742
	if Content:exist(FlowDotTexturePath) then -- 742
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 742
	else -- 742
		____Content_exist_result_1 = nil -- 742
	end -- 742
	local flowDotTex = ____Content_exist_result_1 -- 742
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 742
		do -- 742
			local i = 0 -- 745
			while i < #bodies do -- 745
				do -- 745
					local def = bodies[i + 1] -- 746
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 746
						goto __continue81 -- 748
					end -- 748
					local dots = {} -- 749
					do -- 749
						local k = 0 -- 750
						while k < FlowDotsPerOrbit do -- 750
							local dot = Model3D(FlowDotModelPath) -- 751
							if dot == nil then -- 751
								break -- 752
							end -- 752
							local dm = dot:getMaterial(0) -- 756
							if dm ~= nil then -- 756
								if flowDotTex ~= nil then -- 756
									dm:setBaseColorTexture(flowDotTex) -- 759
									dm:setEmissiveTexture(flowDotTex) -- 760
								end -- 760
								dm.baseColor = Color(0, 0, 0, 255) -- 762
								dm.emissive = Color3(FlowDotEmissiveHex) -- 763
								dm.roughness = 1 -- 764
								dm.metallic = 0 -- 765
								dm.alphaMode = 2 -- 766
							end -- 766
							local s = def.orbitRadius * FlowDotScalePerRadius -- 768
							if s < FlowDotMinScale then -- 768
								s = FlowDotMinScale -- 769
							end -- 769
							if s > FlowDotMaxScale then -- 769
								s = FlowDotMaxScale -- 770
							end -- 770
							dot.scale = Vec3(s, s, s) -- 771
							dot.angleX = -90 -- 772
							root:addChild(dot) -- 773
							dots[#dots + 1] = dot -- 774
							k = k + 1 -- 750
						end -- 750
					end -- 750
					if #dots == 0 then -- 750
						goto __continue81 -- 776
					end -- 776
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 777
				end -- 777
				::__continue81:: -- 777
				i = i + 1 -- 745
			end -- 745
		end -- 745
		if #flowOrbits > 0 then -- 745
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 780
		end -- 780
	end -- 780
	if options.home ~= nil then -- 780
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 789
		if earth ~= nil then -- 789
			local ke = ____exports.modelRadius("Planet_Earth") -- 791
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 792
			local es = hr / ke -- 793
			earth.scale = Vec3(es, es, es) -- 794
			local emi = 0 -- 795
			while emi < 64 do -- 795
				local em = earth:getMaterial(emi) -- 797
				if em == nil then -- 797
					break -- 798
				end -- 798
				em.baseColor = Color(110, 170, 235, 255) -- 799
				em.emissive = Color3(792098) -- 801
				emi = emi + 1 -- 802
			end -- 802
			earth.position = ____exports.planeToWorld(options.home, 0) -- 804
			root:addChild(earth) -- 805
		end -- 805
	end -- 805
	local probe = ____exports.createProbe(root, { -- 815
		scale = options.probeScale, -- 816
		probePath = options.probePath, -- 817
		bodyPath = options.probeBodyPath, -- 818
		antennaPath = options.probeAntennaPath, -- 819
		antennaPivotY = options.probeAntennaPivotY, -- 820
		bodyRadius = options.probeBodyRadius, -- 821
		atlasPath = options.probeAtlasPath -- 822
	}) -- 822
	if probe == nil then -- 822
		return nil -- 824
	end -- 824
	local probeNode = probe.node -- 825
	local antennaModel = probe.antenna -- 826
	local probeRadius = probe.radius -- 827
	local bodyYawDeg = 0 -- 830
	local backdrop = ____exports.createStarBackdrop(root) -- 834
	local glowNode = nil -- 842
	local glowScale = 0 -- 845
	if hasStar and starWorld ~= nil then -- 845
		glowScale = SunGlowScale * starRadius * 2 -- 847
		local glowPath = "Assets/Model/StarQuad.gltf" -- 848
		if Content:exist(glowPath) then -- 848
			local glowModel = Model3D(glowPath) -- 850
			if glowModel ~= nil then -- 850
				local glowTex = Texture2D("Assets/Image/glow.png") -- 852
				local gl = glowModel:getMaterial(0) -- 853
				if gl ~= nil and glowTex ~= nil then -- 853
					gl:setBaseColorTexture(glowTex) -- 855
					gl:setEmissiveTexture(glowTex) -- 856
					gl.baseColor = Color(0, 0, 0, 255) -- 857
					gl.emissive = Color3(13154456) -- 858
					gl.roughness = 1 -- 859
					gl.metallic = 0 -- 860
					gl.alphaMode = 2 -- 861
				end -- 861
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 863
				glowModel.position = starWorld -- 864
				root:addChild(glowModel) -- 865
				glowNode = glowModel -- 866
			end -- 866
		end -- 866
	end -- 866
	local starNodes = {} -- 872
	local starModelPath = "Assets/Model/Star_Crystal.glb" -- 873
	if options.stars ~= nil and Content:exist(starModelPath) then -- 873
		do -- 873
			local sIdx = 0 -- 875
			while sIdx < #options.stars do -- 875
				local sPos = options.stars[sIdx + 1] -- 876
				local sModel = Model3D(starModelPath) -- 877
				if sModel ~= nil then -- 877
					local sm = sModel:getMaterial(0) -- 879
					if sm ~= nil then -- 879
						sm.baseColor = Color(255, 220, 50, 255) -- 881
						sm.emissive = Color3(16763904) -- 882
					end -- 882
					local sRadius = 14 -- 884
					sModel.scale = Vec3(sRadius, sRadius, sRadius) -- 885
					local wp = ____exports.planeToWorld(sPos, 0) -- 886
					sModel.position = wp -- 887
					root:addChild(sModel) -- 888
					starNodes[#starNodes + 1] = {node = sModel, pos = sPos, collected = false} -- 889
				end -- 889
				sIdx = sIdx + 1 -- 875
			end -- 875
		end -- 875
	end -- 875
	local function syncBodies(t) -- 895
		do -- 895
			local i = 0 -- 896
			while i < #planets do -- 896
				local p = planets[i + 1] -- 897
				local wp = ____exports.planeToWorld( -- 898
					bodyPositionAt(p.def, t), -- 898
					0 -- 898
				) -- 898
				p.body.position = wp -- 899
				if p.ring ~= nil then -- 899
					p.ring.position = wp -- 900
				end -- 900
				local vis = visuals[i + 1] -- 904
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 905
				if spin ~= nil and spin > 0 then -- 905
					local turns = t / spin -- 907
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 908
				end -- 908
				i = i + 1 -- 896
			end -- 896
		end -- 896
		do -- 896
			local i = 0 -- 912
			while i < #starNodes do -- 912
				local sn = starNodes[i + 1] -- 913
				if not sn.collected then -- 913
					sn.node.visible = true -- 915
					sn.node.angleY = (t * 120 + i * 40) % 360 -- 916
					local wp = ____exports.planeToWorld(sn.pos, 0) -- 917
					sn.node.position = Vec3( -- 918
						wp.x, -- 918
						math.sin(t * 4 + i) * 6, -- 918
						wp.z -- 918
					) -- 918
				else -- 918
					sn.node.visible = false -- 920
				end -- 920
				i = i + 1 -- 912
			end -- 912
		end -- 912
		for ____, fo in ipairs(flowOrbits) do -- 924
			local c = orbitCenterAt(fo.def, t) -- 925
			local r = fo.def.orbitRadius -- 926
			local n = #fo.dots -- 927
			do -- 927
				local k = 0 -- 928
				while k < n do -- 928
					local a = flowDotAngle(fo.def, t, k, n) -- 929
					fo.dots[k + 1].position = Vec3( -- 930
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 931
						0, -- 932
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 933
					) -- 933
					k = k + 1 -- 928
				end -- 928
			end -- 928
		end -- 928
	end -- 895
	local function syncProbe(p) -- 939
		probeNode.position = ____exports.planeToWorld(p, 0) -- 940
		if antennaModel ~= nil and options.home ~= nil then -- 940
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 946
		end -- 946
	end -- 939
	local function faceVelocity(v) -- 953
		local yaw = ____exports.probeYawForVelocity(v) -- 954
		if yaw == nil then -- 954
			return -- 955
		end -- 955
		bodyYawDeg = yaw -- 956
		probeNode.angleY = bodyYawDeg -- 957
	end -- 953
	local function syncBackdrop(eye, target) -- 961
		if backdrop ~= nil then -- 961
			backdrop:sync(eye, target) -- 962
		end -- 962
		if glowNode ~= nil and starWorld ~= nil then -- 962
			local dx = eye.x - starWorld.x -- 965
			local dy = eye.y - starWorld.y -- 966
			local dz = eye.z - starWorld.z -- 967
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 967
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 969
			end -- 969
			local flat = math.sqrt(dy * dy + dz * dz) -- 972
			local tilt = flat > 0.000001 and math.atan( -- 973
				math.abs(dy), -- 973
				flat -- 973
			) or 0 -- 973
			local c = math.cos(tilt) -- 974
			local stretch = c > 0.45 and 1 / c or 2.2 -- 975
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 976
		end -- 976
	end -- 961
	syncBodies(0) -- 981
	syncProbe(probeStart) -- 982
	return { -- 984
		syncBodies = syncBodies, -- 985
		syncProbe = syncProbe, -- 986
		faceVelocity = faceVelocity, -- 987
		syncBackdrop = syncBackdrop, -- 988
		probe = probeNode, -- 989
		antenna = antennaModel, -- 990
		planets = planets, -- 991
		probeRadius = probeRadius, -- 992
		starNodes = starNodes, -- 993
		setStarCollected = function(index) -- 994
			if index >= 0 and index < #starNodes then -- 994
				starNodes[index + 1].collected = true -- 996
				starNodes[index + 1].node.visible = false -- 997
			end -- 997
		end, -- 994
		resetStars = function() -- 1000
			do -- 1000
				local i = 0 -- 1001
				while i < #starNodes do -- 1001
					starNodes[i + 1].collected = false -- 1002
					starNodes[i + 1].node.visible = true -- 1003
					i = i + 1 -- 1001
				end -- 1001
			end -- 1001
		end -- 1000
	} -- 1000
end -- 599
return ____exports -- 599
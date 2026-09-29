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
local PointLight3D = ____Dora.PointLight3D -- 29
local Texture2D = ____Dora.Texture2D -- 29
local Vec3 = ____Dora.Vec3 -- 29
local ____Config = require("game.Config") -- 31
local OrbitRingTintHex = ____Config.OrbitRingTintHex -- 32
local PlaneToWorldX = ____Config.PlaneToWorldX -- 32
local PlaneToWorldZ = ____Config.PlaneToWorldZ -- 32
local SunGlowScale = ____Config.SunGlowScale -- 33
local SunLightIntensity = ____Config.SunLightIntensity -- 33
local SunLightRange = ____Config.SunLightRange -- 33
local SunFillIntensity = ____Config.SunFillIntensity -- 33
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
--- 恒星按明确的太阳模型识别，质量大的地球仍是行星。
function ____exports.isSunVisual(visual) -- 228
	return visual ~= nil and visual.model == "Sun" -- 229
end -- 228
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 380
	local i = 0 -- 381
	while i < 64 do -- 381
		local mat = model:getMaterial(i) -- 383
		if mat == nil then -- 383
			break -- 384
		end -- 384
		mat:setBaseColorTexture(tex) -- 385
		i = i + 1 -- 386
	end -- 386
end -- 380
function ____exports.createProbe(parent, opts) -- 390
	local scale = opts.scale -- 391
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 392
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 393
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 394
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 397
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 400
	if bodyModel == nil and singleModel == nil then -- 400
		return nil -- 401
	end -- 401
	local node = Node3D() -- 403
	parent:addChild(node) -- 404
	if bodyModel ~= nil then -- 404
		bodyModel.scale = Vec3(scale, scale, scale) -- 407
		node:addChild(bodyModel) -- 408
	end -- 408
	if singleModel ~= nil then -- 408
		singleModel.scale = Vec3(scale, scale, scale) -- 411
		node:addChild(singleModel) -- 412
	end -- 412
	if bodyModel ~= nil and antennaModel ~= nil then -- 412
		antennaModel.scale = Vec3(scale, scale, scale) -- 419
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 420
		node:addChild(antennaModel) -- 421
	end -- 421
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 421
		local atlas = Texture2D(opts.atlasPath) -- 427
		if atlas ~= nil then -- 427
			if bodyModel ~= nil then -- 427
				applyAtlas(bodyModel, atlas) -- 429
			end -- 429
			if singleModel ~= nil then -- 429
				applyAtlas(singleModel, atlas) -- 430
			end -- 430
			if antennaModel ~= nil then -- 430
				applyAtlas(antennaModel, atlas) -- 431
			end -- 431
		end -- 431
	end -- 431
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 435
end -- 390
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 460
	local ex = (target.x - probe.x) * PlaneToWorldX -- 461
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 462
	local dist = math.sqrt(ex * ex + ez * ez) -- 463
	if dist <= 0.0001 then -- 463
		return -- 464
	end -- 464
	local tiltFactor = (dist - 0.5) / 3 -- 465
	if tiltFactor < 0 then -- 465
		tiltFactor = 0 -- 466
	end -- 466
	if tiltFactor > 1 then -- 466
		tiltFactor = 1 -- 467
	end -- 467
	local tilt = 46 * tiltFactor -- 468
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 469
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 470
end -- 460
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 480
	local wx = v.x * PlaneToWorldX -- 481
	local wz = v.y * PlaneToWorldZ -- 482
	if wx * wx + wz * wz < 1e-12 then -- 482
		return nil -- 483
	end -- 483
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 484
end -- 480
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 488
local BackdropHalf = 560 -- 489
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 492
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 494
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 502
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
function ____exports.createStarBackdrop(root, radius) -- 527
	if radius == nil then -- 527
		radius = SkyRadius -- 527
	end -- 527
	local tex = Texture2D("Assets/Image/starfield.png") -- 528
	if Content:exist(SkySpherePath) then -- 528
		local sphere = Model3D(SkySpherePath) -- 532
		if sphere ~= nil then -- 532
			local sm = sphere:getMaterial(0) -- 534
			if sm ~= nil and tex ~= nil then -- 534
				sm:setEmissiveTexture(tex) -- 538
				sm.baseColor = Color(0, 0, 0, 255) -- 539
				sm.emissive = Color3(StarBrightnessHex) -- 540
				sm.roughness = 1 -- 541
				sm.metallic = 0 -- 542
			end -- 542
			sphere.scale = Vec3(radius, radius, radius) -- 544
			sphere.position = Vec3(0, 0, 0) -- 545
			root:addChild(sphere) -- 546
			return { -- 547
				node = sphere, -- 548
				sync = function(____, eye, target) -- 549
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 550
				end -- 549
			} -- 549
		end -- 549
	end -- 549
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 557
	if backdrop == nil then -- 557
		return nil -- 558
	end -- 558
	local bm = backdrop:getMaterial(0) -- 559
	if bm ~= nil and tex ~= nil then -- 559
		bm:setEmissiveTexture(tex) -- 561
		bm.baseColor = Color(0, 0, 0, 255) -- 562
		bm.emissive = Color3(StarBrightnessHex) -- 563
		bm.roughness = 1 -- 564
		bm.metallic = 0 -- 565
	end -- 565
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 567
	backdrop.angleX = -45 -- 568
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 569
	root:addChild(backdrop) -- 570
	return { -- 571
		node = backdrop, -- 572
		sync = function(____, eye, target) -- 573
			local dx = target.x - eye.x -- 574
			local dy = target.y - eye.y -- 575
			local dz = target.z - eye.z -- 576
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 577
			if len < 0.000001 then -- 577
				return -- 578
			end -- 578
			local s = BackdropDist / len -- 579
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 580
		end -- 573
	} -- 573
end -- 527
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 587
local FlowDotTexturePath = "Assets/Image/glow.png" -- 588
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 593
local FlowDotMaxScale = 2 -- 594
local FlowDotScalePerRadius = 0.012 -- 595
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 597
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 610
	local ____options_0 = options -- 611
	local root = ____options_0.root -- 611
	local bodies = ____options_0.bodies -- 611
	local visuals = ____options_0.visuals -- 611
	local probeStart = ____options_0.probeStart -- 611
	local starWorld = nil -- 614
	local starRadius = 0 -- 615
	local starIndex = -1 -- 616
	do -- 616
		local i = 0 -- 617
		while i < #bodies do -- 617
			do -- 617
				local b = bodies[i + 1] -- 618
				if not ____exports.isSunVisual(visuals[i + 1]) then -- 618
					goto __continue56 -- 619
				end -- 619
				starIndex = i -- 620
				starRadius = b.radius -- 621
				starWorld = ____exports.planeToWorld( -- 622
					bodyPositionAt(b, 0), -- 622
					0 -- 622
				) -- 622
				break -- 623
			end -- 623
			::__continue56:: -- 623
			i = i + 1 -- 617
		end -- 617
	end -- 617
	local hasStar = starIndex >= 0 -- 625
	local sunLight = nil -- 626
	if hasStar and starWorld ~= nil then -- 626
		sunLight = PointLight3D() -- 628
		sunLight.position = starWorld -- 629
		sunLight.color = Color3(16774106) -- 629
		sunLight.intensity = SunLightIntensity -- 630
		sunLight.range = SunLightRange -- 630
		root:addChild(sunLight) -- 631
	end -- 631
	do -- 631
		local light = DirectionalLight3D() -- 634
		light.color = Color3(16774106) -- 635
		light.intensity = hasStar and SunFillIntensity or 3.6 -- 636
		light.angleX = -42 -- 637
		light.angleY = 75 -- 638
		root:addChild(light) -- 639
	end -- 639
	local planets = {} -- 643
	do -- 643
		local i = 0 -- 644
		while i < #bodies do -- 644
			local def = bodies[i + 1] -- 645
			local vis = visuals[i + 1] -- 646
			local bodyModel = nil -- 649
			local k = 1 -- 650
			local modelName = vis.model ~= nil and vis.model or "" -- 651
			if modelName ~= "" then -- 651
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 653
				if loaded ~= nil then -- 653
					bodyModel = loaded -- 655
					k = ____exports.modelRadius(modelName) -- 656
				end -- 656
			end -- 656
			if bodyModel == nil then -- 656
				bodyModel = Model3D(options.spherePath) -- 660
				k = 1 -- 661
			end -- 661
			if bodyModel == nil then -- 661
				return nil -- 663
			end -- 663
			local scale = vis.displayRadius / k -- 666
			bodyModel.scale = Vec3(scale, scale, scale) -- 667
			____exports.applyPlanetTexture( -- 674
				bodyModel, -- 674
				modelName, -- 674
				____exports.packColor(vis.r, vis.g, vis.b), -- 674
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 675
			) -- 675
			root:addChild(bodyModel) -- 677
			local ringNode = nil -- 680
			if modelName == "" and vis.ring then -- 680
				local ring = Model3D(options.ringPath) -- 682
				if ring ~= nil then -- 682
					local rs = scale * 1.5 -- 685
					ring.scale = Vec3(rs, rs, rs) -- 686
					root:addChild(ring) -- 687
					ringNode = ring -- 688
				end -- 688
			end -- 688
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 692
			i = i + 1 -- 644
		end -- 644
	end -- 644
	do -- 644
		local i = 0 -- 703
		while i < #bodies do -- 703
			do -- 703
				if options.orbitRings == false then -- 703
					break -- 704
				end -- 704
				local def = bodies[i + 1] -- 705
				if def.orbitRadius <= 0 then -- 705
					goto __continue69 -- 706
				end -- 706
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 707
				if not Content:exist(ringPath) then -- 707
					goto __continue69 -- 709
				end -- 709
				local orbitNode = Model3D(ringPath) -- 710
				if orbitNode == nil then -- 710
					goto __continue69 -- 711
				end -- 711
				local oi = 0 -- 712
				while oi < 8 do -- 712
					local om = orbitNode:getMaterial(oi) -- 714
					if om == nil then -- 714
						break -- 715
					end -- 715
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 717
					oi = oi + 1 -- 718
				end -- 718
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 720
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 721
				root:addChild(orbitNode) -- 722
			end -- 722
			::__continue69:: -- 722
			i = i + 1 -- 703
		end -- 703
	end -- 703
	local flowOrbits = {} -- 735
	local ____Content_exist_result_1 -- 736
	if Content:exist(FlowDotTexturePath) then -- 736
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 736
	else -- 736
		____Content_exist_result_1 = nil -- 736
	end -- 736
	local flowDotTex = ____Content_exist_result_1 -- 736
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 736
		do -- 736
			local i = 0 -- 739
			while i < #bodies do -- 739
				do -- 739
					local def = bodies[i + 1] -- 740
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 740
						goto __continue78 -- 742
					end -- 742
					local dots = {} -- 743
					do -- 743
						local k = 0 -- 744
						while k < FlowDotsPerOrbit do -- 744
							local dot = Model3D(FlowDotModelPath) -- 745
							if dot == nil then -- 745
								break -- 746
							end -- 746
							local dm = dot:getMaterial(0) -- 750
							if dm ~= nil then -- 750
								if flowDotTex ~= nil then -- 750
									dm:setBaseColorTexture(flowDotTex) -- 753
									dm:setEmissiveTexture(flowDotTex) -- 754
								end -- 754
								dm.baseColor = Color(0, 0, 0, 255) -- 756
								dm.emissive = Color3(FlowDotEmissiveHex) -- 757
								dm.roughness = 1 -- 758
								dm.metallic = 0 -- 759
								dm.alphaMode = 2 -- 760
							end -- 760
							local s = def.orbitRadius * FlowDotScalePerRadius -- 762
							if s < FlowDotMinScale then -- 762
								s = FlowDotMinScale -- 763
							end -- 763
							if s > FlowDotMaxScale then -- 763
								s = FlowDotMaxScale -- 764
							end -- 764
							dot.scale = Vec3(s, s, s) -- 765
							dot.angleX = -90 -- 766
							root:addChild(dot) -- 767
							dots[#dots + 1] = dot -- 768
							k = k + 1 -- 744
						end -- 744
					end -- 744
					if #dots == 0 then -- 744
						goto __continue78 -- 770
					end -- 770
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 771
				end -- 771
				::__continue78:: -- 771
				i = i + 1 -- 739
			end -- 739
		end -- 739
		if #flowOrbits > 0 then -- 739
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 774
		end -- 774
	end -- 774
	if options.home ~= nil then -- 774
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 783
		if earth ~= nil then -- 783
			local ke = ____exports.modelRadius("Planet_Earth") -- 785
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 786
			local es = hr / ke -- 787
			earth.scale = Vec3(es, es, es) -- 788
			local emi = 0 -- 789
			while emi < 64 do -- 789
				local em = earth:getMaterial(emi) -- 791
				if em == nil then -- 791
					break -- 792
				end -- 792
				em.baseColor = Color(110, 170, 235, 255) -- 793
				em.emissive = Color3(792098) -- 795
				emi = emi + 1 -- 796
			end -- 796
			earth.position = ____exports.planeToWorld(options.home, 0) -- 798
			root:addChild(earth) -- 799
		end -- 799
	end -- 799
	local probe = ____exports.createProbe(root, { -- 809
		scale = options.probeScale, -- 810
		probePath = options.probePath, -- 811
		bodyPath = options.probeBodyPath, -- 812
		antennaPath = options.probeAntennaPath, -- 813
		antennaPivotY = options.probeAntennaPivotY, -- 814
		bodyRadius = options.probeBodyRadius, -- 815
		atlasPath = options.probeAtlasPath -- 816
	}) -- 816
	if probe == nil then -- 816
		return nil -- 818
	end -- 818
	local probeNode = probe.node -- 819
	local antennaModel = probe.antenna -- 820
	local probeRadius = probe.radius -- 821
	local bodyYawDeg = 0 -- 824
	local backdrop = ____exports.createStarBackdrop(root, options.backdropRadius) -- 828
	local glowNode = nil -- 836
	local glowScale = 0 -- 839
	if hasStar and starWorld ~= nil then -- 839
		glowScale = SunGlowScale * starRadius * 2 -- 841
		local glowPath = "Assets/Model/StarQuad.gltf" -- 842
		if Content:exist(glowPath) then -- 842
			local glowModel = Model3D(glowPath) -- 844
			if glowModel ~= nil then -- 844
				local glowTex = Texture2D("Assets/Image/glow.png") -- 846
				local gl = glowModel:getMaterial(0) -- 847
				if gl ~= nil and glowTex ~= nil then -- 847
					gl:setBaseColorTexture(glowTex) -- 849
					gl:setEmissiveTexture(glowTex) -- 850
					gl.baseColor = Color(0, 0, 0, 255) -- 851
					gl.emissive = Color3(13154456) -- 852
					gl.roughness = 1 -- 853
					gl.metallic = 0 -- 854
					gl.alphaMode = 2 -- 855
				end -- 855
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 857
				glowModel.position = starWorld -- 858
				root:addChild(glowModel) -- 859
				glowNode = glowModel -- 860
			end -- 860
		end -- 860
	end -- 860
	local starNodes = {} -- 866
	local starModelPath = "Assets/Model/Star_Crystal.glb" -- 867
	if options.stars ~= nil and Content:exist(starModelPath) then -- 867
		do -- 867
			local sIdx = 0 -- 869
			while sIdx < #options.stars do -- 869
				local sPos = options.stars[sIdx + 1] -- 870
				local sModel = Model3D(starModelPath) -- 871
				if sModel ~= nil then -- 871
					local sm = sModel:getMaterial(0) -- 873
					if sm ~= nil then -- 873
						sm.baseColor = Color(255, 220, 50, 255) -- 875
						sm.emissive = Color3(16763904) -- 876
					end -- 876
					local sRadius = 14 -- 878
					sModel.scale = Vec3(sRadius, sRadius, sRadius) -- 879
					local wp = ____exports.planeToWorld(sPos, 0) -- 880
					sModel.position = wp -- 881
					root:addChild(sModel) -- 882
					starNodes[#starNodes + 1] = {node = sModel, pos = sPos, collected = false} -- 883
				end -- 883
				sIdx = sIdx + 1 -- 869
			end -- 869
		end -- 869
	end -- 869
	local function syncBodies(t) -- 889
		if sunLight ~= nil and starIndex >= 0 then -- 889
			starWorld = ____exports.planeToWorld( -- 891
				bodyPositionAt(bodies[starIndex + 1], t), -- 891
				0 -- 891
			) -- 891
			sunLight.position = starWorld -- 892
			if glowNode ~= nil then -- 892
				glowNode.position = starWorld -- 893
			end -- 893
		end -- 893
		do -- 893
			local i = 0 -- 895
			while i < #planets do -- 895
				local p = planets[i + 1] -- 896
				local wp = ____exports.planeToWorld( -- 897
					bodyPositionAt(p.def, t), -- 897
					0 -- 897
				) -- 897
				p.body.position = wp -- 898
				if p.ring ~= nil then -- 898
					p.ring.position = wp -- 899
				end -- 899
				local vis = visuals[i + 1] -- 903
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 904
				if spin ~= nil and spin > 0 then -- 904
					local turns = t / spin -- 906
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 907
				end -- 907
				i = i + 1 -- 895
			end -- 895
		end -- 895
		do -- 895
			local i = 0 -- 911
			while i < #starNodes do -- 911
				local sn = starNodes[i + 1] -- 912
				if not sn.collected then -- 912
					sn.node.visible = true -- 914
					sn.node.angleY = (t * 120 + i * 40) % 360 -- 915
					local wp = ____exports.planeToWorld(sn.pos, 0) -- 916
					sn.node.position = Vec3( -- 917
						wp.x, -- 917
						math.sin(t * 4 + i) * 6, -- 917
						wp.z -- 917
					) -- 917
				else -- 917
					sn.node.visible = false -- 919
				end -- 919
				i = i + 1 -- 911
			end -- 911
		end -- 911
		for ____, fo in ipairs(flowOrbits) do -- 923
			local c = orbitCenterAt(fo.def, t) -- 924
			local r = fo.def.orbitRadius -- 925
			local n = #fo.dots -- 926
			do -- 926
				local k = 0 -- 927
				while k < n do -- 927
					local a = flowDotAngle(fo.def, t, k, n) -- 928
					fo.dots[k + 1].position = Vec3( -- 929
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 930
						0, -- 931
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 932
					) -- 932
					k = k + 1 -- 927
				end -- 927
			end -- 927
		end -- 927
	end -- 889
	local function syncProbe(p) -- 938
		probeNode.position = ____exports.planeToWorld(p, 0) -- 939
		if antennaModel ~= nil and options.home ~= nil then -- 939
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 945
		end -- 945
	end -- 938
	local function faceVelocity(v) -- 952
		local yaw = ____exports.probeYawForVelocity(v) -- 953
		if yaw == nil then -- 953
			return -- 954
		end -- 954
		bodyYawDeg = yaw -- 955
		probeNode.angleY = bodyYawDeg -- 956
	end -- 952
	local function syncBackdrop(eye, target) -- 960
		if backdrop ~= nil then -- 960
			backdrop:sync(eye, target) -- 961
		end -- 961
		if glowNode ~= nil and starWorld ~= nil then -- 961
			local dx = eye.x - starWorld.x -- 964
			local dy = eye.y - starWorld.y -- 965
			local dz = eye.z - starWorld.z -- 966
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 966
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 968
			end -- 968
			local flat = math.sqrt(dy * dy + dz * dz) -- 971
			local tilt = flat > 0.000001 and math.atan( -- 972
				math.abs(dy), -- 972
				flat -- 972
			) or 0 -- 972
			local c = math.cos(tilt) -- 973
			local stretch = c > 0.45 and 1 / c or 2.2 -- 974
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 975
		end -- 975
	end -- 960
	syncBodies(0) -- 980
	syncProbe(probeStart) -- 981
	return { -- 983
		syncBodies = syncBodies, -- 984
		sunLight = sunLight, -- 985
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
end -- 610
return ____exports -- 610
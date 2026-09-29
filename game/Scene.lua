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
local function applyAtlas(model, tex) -- 373
	local i = 0 -- 374
	while i < 64 do -- 374
		local mat = model:getMaterial(i) -- 376
		if mat == nil then -- 376
			break -- 377
		end -- 377
		mat:setBaseColorTexture(tex) -- 378
		i = i + 1 -- 379
	end -- 379
end -- 373
function ____exports.createProbe(parent, opts) -- 383
	local scale = opts.scale -- 384
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 385
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 386
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 387
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 390
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 393
	if bodyModel == nil and singleModel == nil then -- 393
		return nil -- 394
	end -- 394
	local node = Node3D() -- 396
	parent:addChild(node) -- 397
	if bodyModel ~= nil then -- 397
		bodyModel.scale = Vec3(scale, scale, scale) -- 400
		node:addChild(bodyModel) -- 401
	end -- 401
	if singleModel ~= nil then -- 401
		singleModel.scale = Vec3(scale, scale, scale) -- 404
		node:addChild(singleModel) -- 405
	end -- 405
	if bodyModel ~= nil and antennaModel ~= nil then -- 405
		antennaModel.scale = Vec3(scale, scale, scale) -- 412
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 413
		node:addChild(antennaModel) -- 414
	end -- 414
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 414
		local atlas = Texture2D(opts.atlasPath) -- 420
		if atlas ~= nil then -- 420
			if bodyModel ~= nil then -- 420
				applyAtlas(bodyModel, atlas) -- 422
			end -- 422
			if singleModel ~= nil then -- 422
				applyAtlas(singleModel, atlas) -- 423
			end -- 423
			if antennaModel ~= nil then -- 423
				applyAtlas(antennaModel, atlas) -- 424
			end -- 424
		end -- 424
	end -- 424
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 428
end -- 383
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 453
	local ex = (target.x - probe.x) * PlaneToWorldX -- 454
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 455
	local dist = math.sqrt(ex * ex + ez * ez) -- 456
	if dist <= 0.0001 then -- 456
		return -- 457
	end -- 457
	local tiltFactor = (dist - 0.5) / 3 -- 458
	if tiltFactor < 0 then -- 458
		tiltFactor = 0 -- 459
	end -- 459
	if tiltFactor > 1 then -- 459
		tiltFactor = 1 -- 460
	end -- 460
	local tilt = 46 * tiltFactor -- 461
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 462
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 463
end -- 453
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 473
	local wx = v.x * PlaneToWorldX -- 474
	local wz = v.y * PlaneToWorldZ -- 475
	if wx * wx + wz * wz < 1e-12 then -- 475
		return nil -- 476
	end -- 476
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 477
end -- 473
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 481
local BackdropHalf = 560 -- 482
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 485
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 487
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 495
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
function ____exports.createStarBackdrop(root, radius) -- 520
	if radius == nil then -- 520
		radius = SkyRadius -- 520
	end -- 520
	local tex = Texture2D("Assets/Image/starfield.png") -- 521
	if Content:exist(SkySpherePath) then -- 521
		local sphere = Model3D(SkySpherePath) -- 525
		if sphere ~= nil then -- 525
			local sm = sphere:getMaterial(0) -- 527
			if sm ~= nil and tex ~= nil then -- 527
				sm:setEmissiveTexture(tex) -- 531
				sm.baseColor = Color(0, 0, 0, 255) -- 532
				sm.emissive = Color3(StarBrightnessHex) -- 533
				sm.roughness = 1 -- 534
				sm.metallic = 0 -- 535
			end -- 535
			sphere.scale = Vec3(radius, radius, radius) -- 537
			sphere.position = Vec3(0, 0, 0) -- 538
			root:addChild(sphere) -- 539
			return { -- 540
				node = sphere, -- 541
				sync = function(____, eye, target) -- 542
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 543
				end -- 542
			} -- 542
		end -- 542
	end -- 542
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 550
	if backdrop == nil then -- 550
		return nil -- 551
	end -- 551
	local bm = backdrop:getMaterial(0) -- 552
	if bm ~= nil and tex ~= nil then -- 552
		bm:setEmissiveTexture(tex) -- 554
		bm.baseColor = Color(0, 0, 0, 255) -- 555
		bm.emissive = Color3(StarBrightnessHex) -- 556
		bm.roughness = 1 -- 557
		bm.metallic = 0 -- 558
	end -- 558
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 560
	backdrop.angleX = -45 -- 561
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 562
	root:addChild(backdrop) -- 563
	return { -- 564
		node = backdrop, -- 565
		sync = function(____, eye, target) -- 566
			local dx = target.x - eye.x -- 567
			local dy = target.y - eye.y -- 568
			local dz = target.z - eye.z -- 569
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 570
			if len < 0.000001 then -- 570
				return -- 571
			end -- 571
			local s = BackdropDist / len -- 572
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 573
		end -- 566
	} -- 566
end -- 520
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 580
local FlowDotTexturePath = "Assets/Image/glow.png" -- 581
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 586
local FlowDotMaxScale = 2 -- 587
local FlowDotScalePerRadius = 0.012 -- 588
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 590
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 603
	local ____options_0 = options -- 604
	local root = ____options_0.root -- 604
	local bodies = ____options_0.bodies -- 604
	local visuals = ____options_0.visuals -- 604
	local probeStart = ____options_0.probeStart -- 604
	local starWorld = nil -- 612
	local starRadius = 0 -- 613
	local starGm = 0 -- 614
	do -- 614
		local i = 0 -- 615
		while i < #bodies do -- 615
			do -- 615
				local b = bodies[i + 1] -- 616
				if b.orbitRadius ~= 0 then -- 616
					goto __continue55 -- 617
				end -- 617
				if b.gm <= starGm then -- 617
					goto __continue55 -- 618
				end -- 618
				starGm = b.gm -- 619
				starRadius = b.radius -- 620
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 621
			end -- 621
			::__continue55:: -- 621
			i = i + 1 -- 615
		end -- 615
	end -- 615
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 623
	do -- 623
		local light = DirectionalLight3D() -- 632
		light.color = Color3(16774106) -- 633
		light.intensity = 3.6 -- 634
		light.angleX = -42 -- 635
		light.angleY = 75 -- 636
		root:addChild(light) -- 637
	end -- 637
	local starIndex = -1 -- 640
	if hasStar then -- 640
		local best = 0 -- 642
		do -- 642
			local i = 0 -- 643
			while i < #bodies do -- 643
				local b = bodies[i + 1] -- 644
				if b.orbitRadius == 0 and b.gm > best then -- 644
					best = b.gm -- 646
					starIndex = i -- 647
				end -- 647
				i = i + 1 -- 643
			end -- 643
		end -- 643
	end -- 643
	local planets = {} -- 653
	do -- 653
		local i = 0 -- 654
		while i < #bodies do -- 654
			local def = bodies[i + 1] -- 655
			local vis = visuals[i + 1] -- 656
			local bodyModel = nil -- 659
			local k = 1 -- 660
			local modelName = vis.model ~= nil and vis.model or "" -- 661
			if modelName ~= "" then -- 661
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 663
				if loaded ~= nil then -- 663
					bodyModel = loaded -- 665
					k = ____exports.modelRadius(modelName) -- 666
				end -- 666
			end -- 666
			if bodyModel == nil then -- 666
				bodyModel = Model3D(options.spherePath) -- 670
				k = 1 -- 671
			end -- 671
			if bodyModel == nil then -- 671
				return nil -- 673
			end -- 673
			local scale = vis.displayRadius / k -- 676
			bodyModel.scale = Vec3(scale, scale, scale) -- 677
			____exports.applyPlanetTexture( -- 684
				bodyModel, -- 684
				modelName, -- 684
				____exports.packColor(vis.r, vis.g, vis.b), -- 684
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 685
			) -- 685
			root:addChild(bodyModel) -- 687
			local ringNode = nil -- 690
			if modelName == "" and vis.ring then -- 690
				local ring = Model3D(options.ringPath) -- 692
				if ring ~= nil then -- 692
					local rs = scale * 1.5 -- 695
					ring.scale = Vec3(rs, rs, rs) -- 696
					root:addChild(ring) -- 697
					ringNode = ring -- 698
				end -- 698
			end -- 698
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 702
			i = i + 1 -- 654
		end -- 654
	end -- 654
	do -- 654
		local i = 0 -- 713
		while i < #bodies do -- 713
			do -- 713
				if options.orbitRings == false then -- 713
					break -- 714
				end -- 714
				local def = bodies[i + 1] -- 715
				if def.orbitRadius <= 0 then -- 715
					goto __continue72 -- 716
				end -- 716
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 717
				if not Content:exist(ringPath) then -- 717
					goto __continue72 -- 719
				end -- 719
				local orbitNode = Model3D(ringPath) -- 720
				if orbitNode == nil then -- 720
					goto __continue72 -- 721
				end -- 721
				local oi = 0 -- 722
				while oi < 8 do -- 722
					local om = orbitNode:getMaterial(oi) -- 724
					if om == nil then -- 724
						break -- 725
					end -- 725
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 727
					oi = oi + 1 -- 728
				end -- 728
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 730
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 731
				root:addChild(orbitNode) -- 732
			end -- 732
			::__continue72:: -- 732
			i = i + 1 -- 713
		end -- 713
	end -- 713
	local flowOrbits = {} -- 745
	local ____Content_exist_result_1 -- 746
	if Content:exist(FlowDotTexturePath) then -- 746
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 746
	else -- 746
		____Content_exist_result_1 = nil -- 746
	end -- 746
	local flowDotTex = ____Content_exist_result_1 -- 746
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 746
		do -- 746
			local i = 0 -- 749
			while i < #bodies do -- 749
				do -- 749
					local def = bodies[i + 1] -- 750
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 750
						goto __continue81 -- 752
					end -- 752
					local dots = {} -- 753
					do -- 753
						local k = 0 -- 754
						while k < FlowDotsPerOrbit do -- 754
							local dot = Model3D(FlowDotModelPath) -- 755
							if dot == nil then -- 755
								break -- 756
							end -- 756
							local dm = dot:getMaterial(0) -- 760
							if dm ~= nil then -- 760
								if flowDotTex ~= nil then -- 760
									dm:setBaseColorTexture(flowDotTex) -- 763
									dm:setEmissiveTexture(flowDotTex) -- 764
								end -- 764
								dm.baseColor = Color(0, 0, 0, 255) -- 766
								dm.emissive = Color3(FlowDotEmissiveHex) -- 767
								dm.roughness = 1 -- 768
								dm.metallic = 0 -- 769
								dm.alphaMode = 2 -- 770
							end -- 770
							local s = def.orbitRadius * FlowDotScalePerRadius -- 772
							if s < FlowDotMinScale then -- 772
								s = FlowDotMinScale -- 773
							end -- 773
							if s > FlowDotMaxScale then -- 773
								s = FlowDotMaxScale -- 774
							end -- 774
							dot.scale = Vec3(s, s, s) -- 775
							dot.angleX = -90 -- 776
							root:addChild(dot) -- 777
							dots[#dots + 1] = dot -- 778
							k = k + 1 -- 754
						end -- 754
					end -- 754
					if #dots == 0 then -- 754
						goto __continue81 -- 780
					end -- 780
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 781
				end -- 781
				::__continue81:: -- 781
				i = i + 1 -- 749
			end -- 749
		end -- 749
		if #flowOrbits > 0 then -- 749
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 784
		end -- 784
	end -- 784
	if options.home ~= nil then -- 784
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 793
		if earth ~= nil then -- 793
			local ke = ____exports.modelRadius("Planet_Earth") -- 795
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 796
			local es = hr / ke -- 797
			earth.scale = Vec3(es, es, es) -- 798
			local emi = 0 -- 799
			while emi < 64 do -- 799
				local em = earth:getMaterial(emi) -- 801
				if em == nil then -- 801
					break -- 802
				end -- 802
				em.baseColor = Color(110, 170, 235, 255) -- 803
				em.emissive = Color3(792098) -- 805
				emi = emi + 1 -- 806
			end -- 806
			earth.position = ____exports.planeToWorld(options.home, 0) -- 808
			root:addChild(earth) -- 809
		end -- 809
	end -- 809
	local probe = ____exports.createProbe(root, { -- 819
		scale = options.probeScale, -- 820
		probePath = options.probePath, -- 821
		bodyPath = options.probeBodyPath, -- 822
		antennaPath = options.probeAntennaPath, -- 823
		antennaPivotY = options.probeAntennaPivotY, -- 824
		bodyRadius = options.probeBodyRadius, -- 825
		atlasPath = options.probeAtlasPath -- 826
	}) -- 826
	if probe == nil then -- 826
		return nil -- 828
	end -- 828
	local probeNode = probe.node -- 829
	local antennaModel = probe.antenna -- 830
	local probeRadius = probe.radius -- 831
	local bodyYawDeg = 0 -- 834
	local backdrop = ____exports.createStarBackdrop(root, options.backdropRadius) -- 838
	local glowNode = nil -- 846
	local glowScale = 0 -- 849
	if hasStar and starWorld ~= nil then -- 849
		glowScale = SunGlowScale * starRadius * 2 -- 851
		local glowPath = "Assets/Model/StarQuad.gltf" -- 852
		if Content:exist(glowPath) then -- 852
			local glowModel = Model3D(glowPath) -- 854
			if glowModel ~= nil then -- 854
				local glowTex = Texture2D("Assets/Image/glow.png") -- 856
				local gl = glowModel:getMaterial(0) -- 857
				if gl ~= nil and glowTex ~= nil then -- 857
					gl:setBaseColorTexture(glowTex) -- 859
					gl:setEmissiveTexture(glowTex) -- 860
					gl.baseColor = Color(0, 0, 0, 255) -- 861
					gl.emissive = Color3(13154456) -- 862
					gl.roughness = 1 -- 863
					gl.metallic = 0 -- 864
					gl.alphaMode = 2 -- 865
				end -- 865
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 867
				glowModel.position = starWorld -- 868
				root:addChild(glowModel) -- 869
				glowNode = glowModel -- 870
			end -- 870
		end -- 870
	end -- 870
	local starNodes = {} -- 876
	local starModelPath = "Assets/Model/Star_Crystal.glb" -- 877
	if options.stars ~= nil and Content:exist(starModelPath) then -- 877
		do -- 877
			local sIdx = 0 -- 879
			while sIdx < #options.stars do -- 879
				local sPos = options.stars[sIdx + 1] -- 880
				local sModel = Model3D(starModelPath) -- 881
				if sModel ~= nil then -- 881
					local sm = sModel:getMaterial(0) -- 883
					if sm ~= nil then -- 883
						sm.baseColor = Color(255, 220, 50, 255) -- 885
						sm.emissive = Color3(16763904) -- 886
					end -- 886
					local sRadius = 14 -- 888
					sModel.scale = Vec3(sRadius, sRadius, sRadius) -- 889
					local wp = ____exports.planeToWorld(sPos, 0) -- 890
					sModel.position = wp -- 891
					root:addChild(sModel) -- 892
					starNodes[#starNodes + 1] = {node = sModel, pos = sPos, collected = false} -- 893
				end -- 893
				sIdx = sIdx + 1 -- 879
			end -- 879
		end -- 879
	end -- 879
	local function syncBodies(t) -- 899
		do -- 899
			local i = 0 -- 900
			while i < #planets do -- 900
				local p = planets[i + 1] -- 901
				local wp = ____exports.planeToWorld( -- 902
					bodyPositionAt(p.def, t), -- 902
					0 -- 902
				) -- 902
				p.body.position = wp -- 903
				if p.ring ~= nil then -- 903
					p.ring.position = wp -- 904
				end -- 904
				local vis = visuals[i + 1] -- 908
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 909
				if spin ~= nil and spin > 0 then -- 909
					local turns = t / spin -- 911
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 912
				end -- 912
				i = i + 1 -- 900
			end -- 900
		end -- 900
		do -- 900
			local i = 0 -- 916
			while i < #starNodes do -- 916
				local sn = starNodes[i + 1] -- 917
				if not sn.collected then -- 917
					sn.node.visible = true -- 919
					sn.node.angleY = (t * 120 + i * 40) % 360 -- 920
					local wp = ____exports.planeToWorld(sn.pos, 0) -- 921
					sn.node.position = Vec3( -- 922
						wp.x, -- 922
						math.sin(t * 4 + i) * 6, -- 922
						wp.z -- 922
					) -- 922
				else -- 922
					sn.node.visible = false -- 924
				end -- 924
				i = i + 1 -- 916
			end -- 916
		end -- 916
		for ____, fo in ipairs(flowOrbits) do -- 928
			local c = orbitCenterAt(fo.def, t) -- 929
			local r = fo.def.orbitRadius -- 930
			local n = #fo.dots -- 931
			do -- 931
				local k = 0 -- 932
				while k < n do -- 932
					local a = flowDotAngle(fo.def, t, k, n) -- 933
					fo.dots[k + 1].position = Vec3( -- 934
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 935
						0, -- 936
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 937
					) -- 937
					k = k + 1 -- 932
				end -- 932
			end -- 932
		end -- 932
	end -- 899
	local function syncProbe(p) -- 943
		probeNode.position = ____exports.planeToWorld(p, 0) -- 944
		if antennaModel ~= nil and options.home ~= nil then -- 944
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 950
		end -- 950
	end -- 943
	local function faceVelocity(v) -- 957
		local yaw = ____exports.probeYawForVelocity(v) -- 958
		if yaw == nil then -- 958
			return -- 959
		end -- 959
		bodyYawDeg = yaw -- 960
		probeNode.angleY = bodyYawDeg -- 961
	end -- 957
	local function syncBackdrop(eye, target) -- 965
		if backdrop ~= nil then -- 965
			backdrop:sync(eye, target) -- 966
		end -- 966
		if glowNode ~= nil and starWorld ~= nil then -- 966
			local dx = eye.x - starWorld.x -- 969
			local dy = eye.y - starWorld.y -- 970
			local dz = eye.z - starWorld.z -- 971
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 971
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 973
			end -- 973
			local flat = math.sqrt(dy * dy + dz * dz) -- 976
			local tilt = flat > 0.000001 and math.atan( -- 977
				math.abs(dy), -- 977
				flat -- 977
			) or 0 -- 977
			local c = math.cos(tilt) -- 978
			local stretch = c > 0.45 and 1 / c or 2.2 -- 979
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 980
		end -- 980
	end -- 965
	syncBodies(0) -- 985
	syncProbe(probeStart) -- 986
	return { -- 988
		syncBodies = syncBodies, -- 989
		syncProbe = syncProbe, -- 990
		faceVelocity = faceVelocity, -- 991
		syncBackdrop = syncBackdrop, -- 992
		probe = probeNode, -- 993
		antenna = antennaModel, -- 994
		planets = planets, -- 995
		probeRadius = probeRadius, -- 996
		starNodes = starNodes, -- 997
		setStarCollected = function(index) -- 998
			if index >= 0 and index < #starNodes then -- 998
				starNodes[index + 1].collected = true -- 1000
				starNodes[index + 1].node.visible = false -- 1001
			end -- 1001
		end, -- 998
		resetStars = function() -- 1004
			do -- 1004
				local i = 0 -- 1005
				while i < #starNodes do -- 1005
					starNodes[i + 1].collected = false -- 1006
					starNodes[i + 1].node.visible = true -- 1007
					i = i + 1 -- 1005
				end -- 1005
			end -- 1005
		end -- 1004
	} -- 1004
end -- 603
return ____exports -- 603
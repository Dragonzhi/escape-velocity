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
local function applyAtlas(model, tex) -- 351
	local i = 0 -- 352
	while i < 64 do -- 352
		local mat = model:getMaterial(i) -- 354
		if mat == nil then -- 354
			break -- 355
		end -- 355
		mat:setBaseColorTexture(tex) -- 356
		i = i + 1 -- 357
	end -- 357
end -- 351
function ____exports.createProbe(parent, opts) -- 361
	local scale = opts.scale -- 362
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 363
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 364
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 365
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 368
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 371
	if bodyModel == nil and singleModel == nil then -- 371
		return nil -- 372
	end -- 372
	local node = Node3D() -- 374
	parent:addChild(node) -- 375
	if bodyModel ~= nil then -- 375
		bodyModel.scale = Vec3(scale, scale, scale) -- 378
		node:addChild(bodyModel) -- 379
	end -- 379
	if singleModel ~= nil then -- 379
		singleModel.scale = Vec3(scale, scale, scale) -- 382
		node:addChild(singleModel) -- 383
	end -- 383
	if bodyModel ~= nil and antennaModel ~= nil then -- 383
		antennaModel.scale = Vec3(scale, scale, scale) -- 390
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 391
		node:addChild(antennaModel) -- 392
	end -- 392
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 392
		local atlas = Texture2D(opts.atlasPath) -- 398
		if atlas ~= nil then -- 398
			if bodyModel ~= nil then -- 398
				applyAtlas(bodyModel, atlas) -- 400
			end -- 400
			if singleModel ~= nil then -- 400
				applyAtlas(singleModel, atlas) -- 401
			end -- 401
			if antennaModel ~= nil then -- 401
				applyAtlas(antennaModel, atlas) -- 402
			end -- 402
		end -- 402
	end -- 402
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 406
end -- 361
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 431
	local ex = (target.x - probe.x) * PlaneToWorldX -- 432
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 433
	local dist = math.sqrt(ex * ex + ez * ez) -- 434
	if dist <= 0.0001 then -- 434
		return -- 435
	end -- 435
	local tiltFactor = (dist - 0.5) / 3 -- 436
	if tiltFactor < 0 then -- 436
		tiltFactor = 0 -- 437
	end -- 437
	if tiltFactor > 1 then -- 437
		tiltFactor = 1 -- 438
	end -- 438
	local tilt = 46 * tiltFactor -- 439
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 440
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 441
end -- 431
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 451
	local wx = v.x * PlaneToWorldX -- 452
	local wz = v.y * PlaneToWorldZ -- 453
	if wx * wx + wz * wz < 1e-12 then -- 453
		return nil -- 454
	end -- 454
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 455
end -- 451
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 459
local BackdropHalf = 560 -- 460
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 463
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 465
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 473
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
function ____exports.createStarBackdrop(root) -- 498
	local tex = Texture2D("Assets/Image/starfield.png") -- 499
	if Content:exist(SkySpherePath) then -- 499
		local sphere = Model3D(SkySpherePath) -- 503
		if sphere ~= nil then -- 503
			local sm = sphere:getMaterial(0) -- 505
			if sm ~= nil and tex ~= nil then -- 505
				sm:setEmissiveTexture(tex) -- 509
				sm.baseColor = Color(0, 0, 0, 255) -- 510
				sm.emissive = Color3(StarBrightnessHex) -- 511
				sm.roughness = 1 -- 512
				sm.metallic = 0 -- 513
			end -- 513
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 515
			sphere.position = Vec3(0, 0, 0) -- 516
			root:addChild(sphere) -- 517
			return { -- 518
				node = sphere, -- 519
				sync = function(____, eye, target) -- 520
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 521
				end -- 520
			} -- 520
		end -- 520
	end -- 520
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 528
	if backdrop == nil then -- 528
		return nil -- 529
	end -- 529
	local bm = backdrop:getMaterial(0) -- 530
	if bm ~= nil and tex ~= nil then -- 530
		bm:setEmissiveTexture(tex) -- 532
		bm.baseColor = Color(0, 0, 0, 255) -- 533
		bm.emissive = Color3(StarBrightnessHex) -- 534
		bm.roughness = 1 -- 535
		bm.metallic = 0 -- 536
	end -- 536
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 538
	backdrop.angleX = -45 -- 539
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 540
	root:addChild(backdrop) -- 541
	return { -- 542
		node = backdrop, -- 543
		sync = function(____, eye, target) -- 544
			local dx = target.x - eye.x -- 545
			local dy = target.y - eye.y -- 546
			local dz = target.z - eye.z -- 547
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 548
			if len < 0.000001 then -- 548
				return -- 549
			end -- 549
			local s = BackdropDist / len -- 550
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 551
		end -- 544
	} -- 544
end -- 498
--- 光点面片与贴图：与太阳光晕**同源**的仓库内资产（单位四边形 + 径向渐变），不引入新素材。
local FlowDotModelPath = "Assets/Model/StarQuad.gltf" -- 558
local FlowDotTexturePath = "Assets/Image/glow.png" -- 559
--- 光点面片的缩放（StarQuad 顶点是 ±1 ⇒ scale = 直径的一半）。
-- 随轨道半径放大（外圈离相机远，同样屏幕尺寸要更大的世界尺寸），夹在 [min, max]。
local FlowDotMinScale = 0.8 -- 564
local FlowDotMaxScale = 2 -- 565
local FlowDotScalePerRadius = 0.012 -- 566
--- 光点的自发光色（0xRRGGBB）：暖白，与 2D 规划视图的光点同色系（PlanView 的 flowDotHex）。
local FlowDotEmissiveHex = 16767392 -- 568
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 581
	local ____options_0 = options -- 582
	local root = ____options_0.root -- 582
	local bodies = ____options_0.bodies -- 582
	local visuals = ____options_0.visuals -- 582
	local probeStart = ____options_0.probeStart -- 582
	local starWorld = nil -- 590
	local starRadius = 0 -- 591
	local starGm = 0 -- 592
	do -- 592
		local i = 0 -- 593
		while i < #bodies do -- 593
			do -- 593
				local b = bodies[i + 1] -- 594
				if b.orbitRadius ~= 0 then -- 594
					goto __continue55 -- 595
				end -- 595
				if b.gm <= starGm then -- 595
					goto __continue55 -- 596
				end -- 596
				starGm = b.gm -- 597
				starRadius = b.radius -- 598
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 599
			end -- 599
			::__continue55:: -- 599
			i = i + 1 -- 593
		end -- 593
	end -- 593
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 601
	do -- 601
		local light = DirectionalLight3D() -- 610
		light.color = Color3(16774106) -- 611
		light.intensity = 3.6 -- 612
		light.angleX = -42 -- 613
		light.angleY = 75 -- 614
		root:addChild(light) -- 615
	end -- 615
	local starIndex = -1 -- 618
	if hasStar then -- 618
		local best = 0 -- 620
		do -- 620
			local i = 0 -- 621
			while i < #bodies do -- 621
				local b = bodies[i + 1] -- 622
				if b.orbitRadius == 0 and b.gm > best then -- 622
					best = b.gm -- 624
					starIndex = i -- 625
				end -- 625
				i = i + 1 -- 621
			end -- 621
		end -- 621
	end -- 621
	local planets = {} -- 631
	do -- 631
		local i = 0 -- 632
		while i < #bodies do -- 632
			local def = bodies[i + 1] -- 633
			local vis = visuals[i + 1] -- 634
			local bodyModel = nil -- 637
			local k = 1 -- 638
			local modelName = vis.model ~= nil and vis.model or "" -- 639
			if modelName ~= "" then -- 639
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 641
				if loaded ~= nil then -- 641
					bodyModel = loaded -- 643
					k = ____exports.modelRadius(modelName) -- 644
				end -- 644
			end -- 644
			if bodyModel == nil then -- 644
				bodyModel = Model3D(options.spherePath) -- 648
				k = 1 -- 649
			end -- 649
			if bodyModel == nil then -- 649
				return nil -- 651
			end -- 651
			local scale = vis.displayRadius / k -- 654
			bodyModel.scale = Vec3(scale, scale, scale) -- 655
			____exports.applyPlanetTexture( -- 662
				bodyModel, -- 662
				modelName, -- 662
				____exports.packColor(vis.r, vis.g, vis.b), -- 662
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 663
			) -- 663
			root:addChild(bodyModel) -- 665
			local ringNode = nil -- 668
			if modelName == "" and vis.ring then -- 668
				local ring = Model3D(options.ringPath) -- 670
				if ring ~= nil then -- 670
					local rs = scale * 1.5 -- 673
					ring.scale = Vec3(rs, rs, rs) -- 674
					root:addChild(ring) -- 675
					ringNode = ring -- 676
				end -- 676
			end -- 676
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 680
			i = i + 1 -- 632
		end -- 632
	end -- 632
	do -- 632
		local i = 0 -- 688
		while i < #bodies do -- 688
			do -- 688
				local def = bodies[i + 1] -- 689
				if def.orbitRadius <= 0 then -- 689
					goto __continue72 -- 690
				end -- 690
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 691
				if not Content:exist(ringPath) then -- 691
					goto __continue72 -- 693
				end -- 693
				local orbitNode = Model3D(ringPath) -- 694
				if orbitNode == nil then -- 694
					goto __continue72 -- 695
				end -- 695
				local oi = 0 -- 696
				while oi < 8 do -- 696
					local om = orbitNode:getMaterial(oi) -- 698
					if om == nil then -- 698
						break -- 699
					end -- 699
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 701
					oi = oi + 1 -- 702
				end -- 702
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 704
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 705
				root:addChild(orbitNode) -- 706
			end -- 706
			::__continue72:: -- 706
			i = i + 1 -- 688
		end -- 688
	end -- 688
	local flowOrbits = {} -- 719
	local ____Content_exist_result_1 -- 720
	if Content:exist(FlowDotTexturePath) then -- 720
		____Content_exist_result_1 = Texture2D(FlowDotTexturePath) -- 720
	else -- 720
		____Content_exist_result_1 = nil -- 720
	end -- 720
	local flowDotTex = ____Content_exist_result_1 -- 720
	if options.orbitFlowDots ~= false and Content:exist(FlowDotModelPath) then -- 720
		do -- 720
			local i = 0 -- 723
			while i < #bodies do -- 723
				do -- 723
					local def = bodies[i + 1] -- 724
					if def.orbitRadius < 2 or def.orbitPeriod == 0 then -- 724
						goto __continue80 -- 726
					end -- 726
					local dots = {} -- 727
					do -- 727
						local k = 0 -- 728
						while k < FlowDotsPerOrbit do -- 728
							local dot = Model3D(FlowDotModelPath) -- 729
							if dot == nil then -- 729
								break -- 730
							end -- 730
							local dm = dot:getMaterial(0) -- 734
							if dm ~= nil then -- 734
								if flowDotTex ~= nil then -- 734
									dm:setBaseColorTexture(flowDotTex) -- 737
									dm:setEmissiveTexture(flowDotTex) -- 738
								end -- 738
								dm.baseColor = Color(0, 0, 0, 255) -- 740
								dm.emissive = Color3(FlowDotEmissiveHex) -- 741
								dm.roughness = 1 -- 742
								dm.metallic = 0 -- 743
								dm.alphaMode = 2 -- 744
							end -- 744
							local s = def.orbitRadius * FlowDotScalePerRadius -- 746
							if s < FlowDotMinScale then -- 746
								s = FlowDotMinScale -- 747
							end -- 747
							if s > FlowDotMaxScale then -- 747
								s = FlowDotMaxScale -- 748
							end -- 748
							dot.scale = Vec3(s, s, s) -- 749
							dot.angleX = -90 -- 750
							root:addChild(dot) -- 751
							dots[#dots + 1] = dot -- 752
							k = k + 1 -- 728
						end -- 728
					end -- 728
					if #dots == 0 then -- 728
						goto __continue80 -- 754
					end -- 754
					flowOrbits[#flowOrbits + 1] = {def = def, dots = dots} -- 755
				end -- 755
				::__continue80:: -- 755
				i = i + 1 -- 723
			end -- 723
		end -- 723
		if #flowOrbits > 0 then -- 723
			print((("[escape-velocity] flow dots: " .. __TS__NumberToFixed(#flowOrbits, 0)) .. " orbits x ") .. __TS__NumberToFixed(FlowDotsPerOrbit, 0)) -- 758
		end -- 758
	end -- 758
	if options.home ~= nil then -- 758
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 767
		if earth ~= nil then -- 767
			local ke = ____exports.modelRadius("Planet_Earth") -- 769
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 770
			local es = hr / ke -- 771
			earth.scale = Vec3(es, es, es) -- 772
			local emi = 0 -- 773
			while emi < 64 do -- 773
				local em = earth:getMaterial(emi) -- 775
				if em == nil then -- 775
					break -- 776
				end -- 776
				em.baseColor = Color(110, 170, 235, 255) -- 777
				em.emissive = Color3(792098) -- 779
				emi = emi + 1 -- 780
			end -- 780
			earth.position = ____exports.planeToWorld(options.home, 0) -- 782
			root:addChild(earth) -- 783
		end -- 783
	end -- 783
	local probe = ____exports.createProbe(root, { -- 793
		scale = options.probeScale, -- 794
		probePath = options.probePath, -- 795
		bodyPath = options.probeBodyPath, -- 796
		antennaPath = options.probeAntennaPath, -- 797
		antennaPivotY = options.probeAntennaPivotY, -- 798
		bodyRadius = options.probeBodyRadius, -- 799
		atlasPath = options.probeAtlasPath -- 800
	}) -- 800
	if probe == nil then -- 800
		return nil -- 802
	end -- 802
	local probeNode = probe.node -- 803
	local antennaModel = probe.antenna -- 804
	local probeRadius = probe.radius -- 805
	local bodyYawDeg = 0 -- 808
	local backdrop = ____exports.createStarBackdrop(root) -- 812
	local glowNode = nil -- 820
	local glowScale = 0 -- 823
	if hasStar and starWorld ~= nil then -- 823
		glowScale = SunGlowScale * starRadius * 2 -- 825
		local glowPath = "Assets/Model/StarQuad.gltf" -- 826
		if Content:exist(glowPath) then -- 826
			local glowModel = Model3D(glowPath) -- 828
			if glowModel ~= nil then -- 828
				local glowTex = Texture2D("Assets/Image/glow.png") -- 830
				local gl = glowModel:getMaterial(0) -- 831
				if gl ~= nil and glowTex ~= nil then -- 831
					gl:setBaseColorTexture(glowTex) -- 833
					gl:setEmissiveTexture(glowTex) -- 834
					gl.baseColor = Color(0, 0, 0, 255) -- 835
					gl.emissive = Color3(13154456) -- 836
					gl.roughness = 1 -- 837
					gl.metallic = 0 -- 838
					gl.alphaMode = 2 -- 839
				end -- 839
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 841
				glowModel.position = starWorld -- 842
				root:addChild(glowModel) -- 843
				glowNode = glowModel -- 844
			end -- 844
		end -- 844
	end -- 844
	local function syncBodies(t) -- 850
		do -- 850
			local i = 0 -- 851
			while i < #planets do -- 851
				local p = planets[i + 1] -- 852
				local wp = ____exports.planeToWorld( -- 853
					bodyPositionAt(p.def, t), -- 853
					0 -- 853
				) -- 853
				p.body.position = wp -- 854
				if p.ring ~= nil then -- 854
					p.ring.position = wp -- 855
				end -- 855
				local vis = visuals[i + 1] -- 859
				local spin = vis ~= nil and vis.model ~= nil and SPIN_GAME_SEC[vis.model] or nil -- 860
				if spin ~= nil and spin > 0 then -- 860
					local turns = t / spin -- 862
					p.body.angleY = (turns - math.floor(turns)) * 360 -- 863
				end -- 863
				i = i + 1 -- 851
			end -- 851
		end -- 851
		for ____, fo in ipairs(flowOrbits) do -- 870
			local c = orbitCenterAt(fo.def, t) -- 871
			local r = fo.def.orbitRadius -- 872
			local n = #fo.dots -- 873
			do -- 873
				local k = 0 -- 874
				while k < n do -- 874
					local a = flowDotAngle(fo.def, t, k, n) -- 875
					fo.dots[k + 1].position = Vec3( -- 876
						(c.x + r * math.cos(a)) * PlaneToWorldX, -- 877
						0, -- 878
						(c.y + r * math.sin(a)) * PlaneToWorldZ -- 879
					) -- 879
					k = k + 1 -- 874
				end -- 874
			end -- 874
		end -- 874
	end -- 850
	local function syncProbe(p) -- 885
		probeNode.position = ____exports.planeToWorld(p, 0) -- 886
		if antennaModel ~= nil and options.home ~= nil then -- 886
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 892
		end -- 892
	end -- 885
	local function faceVelocity(v) -- 899
		local yaw = ____exports.probeYawForVelocity(v) -- 900
		if yaw == nil then -- 900
			return -- 901
		end -- 901
		bodyYawDeg = yaw -- 902
		probeNode.angleY = bodyYawDeg -- 903
	end -- 899
	local function syncBackdrop(eye, target) -- 907
		if backdrop ~= nil then -- 907
			backdrop:sync(eye, target) -- 908
		end -- 908
		if glowNode ~= nil and starWorld ~= nil then -- 908
			local dx = eye.x - starWorld.x -- 911
			local dy = eye.y - starWorld.y -- 912
			local dz = eye.z - starWorld.z -- 913
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 913
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 915
			end -- 915
			local flat = math.sqrt(dy * dy + dz * dz) -- 918
			local tilt = flat > 0.000001 and math.atan( -- 919
				math.abs(dy), -- 919
				flat -- 919
			) or 0 -- 919
			local c = math.cos(tilt) -- 920
			local stretch = c > 0.45 and 1 / c or 2.2 -- 921
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 922
		end -- 922
	end -- 907
	syncBodies(0) -- 927
	syncProbe(probeStart) -- 928
	return { -- 930
		syncBodies = syncBodies, -- 931
		syncProbe = syncProbe, -- 932
		faceVelocity = faceVelocity, -- 933
		syncBackdrop = syncBackdrop, -- 934
		probe = probeNode, -- 935
		antenna = antennaModel, -- 936
		planets = planets, -- 937
		probeRadius = probeRadius -- 938
	} -- 938
end -- 581
return ____exports -- 581
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
	{name = "Sun", k = 1}, -- 58
	{name = "Moon", k = 1}, -- 59
	{name = "Planet_Earth", k = 1}, -- 60
	{name = "Planet_Venus", k = 1}, -- 61
	{name = "Planet_Mars", k = 1}, -- 62
	{name = "Planet_Jupiter", k = 1}, -- 63
	{name = "Planet_Neptune", k = 1}, -- 64
	{name = "Planet_Saturn", k = 1}, -- 68
	{name = "Planet_Uranus", k = 1} -- 69
} -- 69
--- 取模型半径系数；表里没有的名字按 1.0 处理（等价于旧行为）。
function ____exports.modelRadius(name) -- 73
	do -- 73
		local i = 0 -- 74
		while i < #MODEL_RADIUS do -- 74
			if MODEL_RADIUS[i + 1].name == name then -- 74
				return MODEL_RADIUS[i + 1].k -- 75
			end -- 75
			i = i + 1 -- 74
		end -- 74
	end -- 74
	return 1 -- 77
end -- 73
--- 贴图表（S3.14 建模交付）。
-- 
-- ⚠️ 交付的 .glb **不含内嵌贴图**（tools/glb-check.mjs 核对：images = 0），贴图一律走外部文件、
--    由这里在运行时绑定。行星有 UV（等距圆柱：U 沿经度、接缝在 +Z 背面；V 沿纬度，北极 v=1）。
-- ⚠️ 环的贴图要给**环材质**，而引擎拿不到 glTF 材质名（Material3D 没有 name 字段）——
--    所以用建模约定的 **alphaMode = Blend** 认它（实测 Saturn_Ring_Mat / Uranus_Ring_Mat 都是 BLEND，
--    本体材质是 OPAQUE）。环的 UV 是径向的：U = 0 内环 → U = 1 外环。
local PLANET_TEX = { -- 103
	{name = "Sun", base = "sun.jpg", emissive = "sun.jpg", emisMul = 16777215}, -- 104
	{name = "Moon", base = "moon.jpg"}, -- 105
	{name = "Planet_Earth", base = "planet_earth.jpg", emissive = "planet_earth_emissive.png", emisMul = 2763306}, -- 106
	{name = "Planet_Venus", base = "planet_venus.jpg"}, -- 107
	{name = "Planet_Mars", base = "planet_mars.jpg"}, -- 108
	{name = "Planet_Jupiter", base = "planet_jupiter.jpg"}, -- 109
	{name = "Planet_Saturn", base = "planet_saturn.jpg", ring = "planet_saturn_ring.png"}, -- 110
	{name = "Planet_Uranus", base = "planet_uranus.jpg", ring = "planet_uranus_ring.png"}, -- 111
	{name = "Planet_Neptune", base = "planet_neptune.jpg"} -- 112
} -- 112
--- 0xRRGGBB → 通道（不用位运算：tstl 对算术右移会编译失败，见手册 §7.1）。
local function redOf(hex) -- 116
	return math.floor(hex / 65536) % 256 -- 116
end -- 116
local function greenOf(hex) -- 117
	return math.floor(hex / 256) % 256 -- 117
end -- 117
local function blueOf(hex) -- 118
	return math.floor(hex) % 256 -- 118
end -- 118
--- 0–1 的视觉色 → 0xRRGGBB（给「没有贴图时」的回退染色用）。
function ____exports.packColor(r, g, b) -- 121
	return math.floor(r * 255 + 0.5) * 65536 + math.floor(g * 255 + 0.5) * 256 + math.floor(b * 255 + 0.5) -- 122
end -- 121
--- 按文件名安全取贴图（引擎遇到不存在的文件会**抛异常**，所以先 Content.exist）。
local function textureOf(file) -- 126
	if file == "" then -- 126
		return nil -- 127
	end -- 127
	local path = "Assets/Image/" .. file -- 128
	if not Content:exist(path) then -- 128
		return nil -- 129
	end -- 129
	return Texture2D(path) -- 130
end -- 126
--- 给一颗天体模型绑贴图 / 回退染色（关卡与开场共用同一份）。
-- 
-- @param model 已加载的模型
-- @param modelName 模型名（不含路径与扩展名）
-- @param tintHex 没有贴图时的回退色（0xRRGGBB；0 = 不动 baseColor）
-- @param emissiveHex 自发光乘数（0xRRGGBB；0 = 用贴图表里的默认值）
function ____exports.applyPlanetTexture(model, modelName, tintHex, emissiveHex) -- 141
	local def = nil -- 142
	do -- 142
		local i = 0 -- 143
		while i < #PLANET_TEX do -- 143
			if PLANET_TEX[i + 1].name == modelName then -- 143
				def = PLANET_TEX[i + 1] -- 144
			end -- 144
			i = i + 1 -- 143
		end -- 143
	end -- 143
	local baseTex = textureOf(def ~= nil and def.base or "") -- 146
	local emiTex = textureOf(def ~= nil and def.emissive ~= nil and def.emissive or "") -- 147
	local ringTex = textureOf(def ~= nil and def.ring ~= nil and def.ring or "") -- 148
	local emiMul = emissiveHex -- 149
	if emiMul == 0 and emiTex ~= nil then -- 149
		emiMul = def ~= nil and def.emisMul ~= nil and def.emisMul or 2763306 -- 151
	end -- 151
	local i = 0 -- 154
	while i < 64 do -- 154
		local mat = model:getMaterial(i) -- 156
		if mat == nil then -- 156
			break -- 157
		end -- 157
		local isRing = ringTex ~= nil and mat.alphaMode == 2 -- 158
		if isRing then -- 158
			mat:setBaseColorTexture(ringTex) -- 160
			mat.baseColor = Color(255, 255, 255, 255) -- 161
		elseif baseTex ~= nil then -- 161
			mat:setBaseColorTexture(baseTex) -- 164
			mat.baseColor = Color(255, 255, 255, 255) -- 165
		elseif tintHex > 0 then -- 165
			mat.baseColor = Color( -- 167
				redOf(tintHex), -- 167
				greenOf(tintHex), -- 167
				blueOf(tintHex), -- 167
				255 -- 167
			) -- 167
		end -- 167
		if not isRing and emiTex ~= nil and emiMul > 0 then -- 167
			mat:setEmissiveTexture(emiTex) -- 170
			mat.emissive = Color3(emiMul) -- 171
		end -- 171
		i = i + 1 -- 173
	end -- 173
end -- 141
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
local ProbeYawOffsetDeg = -90 -- 192
--- 天线转轴在探测器本地系的位置（y，模型单位）。
-- 取自拆分前单体文件里 Probe_Antenna 空物体的 translation（建模把它放在碟面背面与
-- 支撑腿的汇交点）。天线文件按"转轴 = 原点"导出，游戏把天线模型放到本常量 × scale 处。
____exports.AntennaPivotY = 0.2 -- 199
--- 把细节图集绑到模型的每个材质（**不改 baseColor**：建模的材质色就是要和图集相乘的）。
local function applyAtlas(model, tex) -- 343
	local i = 0 -- 344
	while i < 64 do -- 344
		local mat = model:getMaterial(i) -- 346
		if mat == nil then -- 346
			break -- 347
		end -- 347
		mat:setBaseColorTexture(tex) -- 348
		i = i + 1 -- 349
	end -- 349
end -- 343
function ____exports.createProbe(parent, opts) -- 353
	local scale = opts.scale -- 354
	local pivotY = opts.antennaPivotY ~= nil and opts.antennaPivotY or ____exports.AntennaPivotY -- 355
	local bodyRadius = opts.bodyRadius ~= nil and opts.bodyRadius or 0.5 * 3.227 -- 356
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 357
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 360
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 363
	if bodyModel == nil and singleModel == nil then -- 363
		return nil -- 364
	end -- 364
	local node = Node3D() -- 366
	parent:addChild(node) -- 367
	if bodyModel ~= nil then -- 367
		bodyModel.scale = Vec3(scale, scale, scale) -- 370
		node:addChild(bodyModel) -- 371
	end -- 371
	if singleModel ~= nil then -- 371
		singleModel.scale = Vec3(scale, scale, scale) -- 374
		node:addChild(singleModel) -- 375
	end -- 375
	if bodyModel ~= nil and antennaModel ~= nil then -- 375
		antennaModel.scale = Vec3(scale, scale, scale) -- 382
		antennaModel.position = Vec3(0, pivotY * scale, 0) -- 383
		node:addChild(antennaModel) -- 384
	end -- 384
	if opts.atlasPath ~= nil and Content:exist(opts.atlasPath) then -- 384
		local atlas = Texture2D(opts.atlasPath) -- 390
		if atlas ~= nil then -- 390
			if bodyModel ~= nil then -- 390
				applyAtlas(bodyModel, atlas) -- 392
			end -- 392
			if singleModel ~= nil then -- 392
				applyAtlas(singleModel, atlas) -- 393
			end -- 393
			if antennaModel ~= nil then -- 393
				applyAtlas(antennaModel, atlas) -- 394
			end -- 394
		end -- 394
	end -- 394
	return {node = node, antenna = antennaModel, radius = bodyRadius * scale * 1.1} -- 398
end -- 353
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 423
	local ex = (target.x - probe.x) * PlaneToWorldX -- 424
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 425
	local dist = math.sqrt(ex * ex + ez * ez) -- 426
	if dist <= 0.0001 then -- 426
		return -- 427
	end -- 427
	local tiltFactor = (dist - 0.5) / 3 -- 428
	if tiltFactor < 0 then -- 428
		tiltFactor = 0 -- 429
	end -- 429
	if tiltFactor > 1 then -- 429
		tiltFactor = 1 -- 430
	end -- 430
	local tilt = 46 * tiltFactor -- 431
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 432
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 433
end -- 423
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 443
	local wx = v.x * PlaneToWorldX -- 444
	local wz = v.y * PlaneToWorldZ -- 445
	if wx * wx + wz * wz < 1e-12 then -- 445
		return nil -- 446
	end -- 446
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 447
end -- 443
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 451
local BackdropHalf = 560 -- 452
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 455
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 457
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 465
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
function ____exports.createStarBackdrop(root) -- 490
	local tex = Texture2D("Assets/Image/starfield.png") -- 491
	if Content:exist(SkySpherePath) then -- 491
		local sphere = Model3D(SkySpherePath) -- 495
		if sphere ~= nil then -- 495
			local sm = sphere:getMaterial(0) -- 497
			if sm ~= nil and tex ~= nil then -- 497
				sm:setEmissiveTexture(tex) -- 501
				sm.baseColor = Color(0, 0, 0, 255) -- 502
				sm.emissive = Color3(StarBrightnessHex) -- 503
				sm.roughness = 1 -- 504
				sm.metallic = 0 -- 505
			end -- 505
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 507
			sphere.position = Vec3(0, 0, 0) -- 508
			root:addChild(sphere) -- 509
			return { -- 510
				node = sphere, -- 511
				sync = function(____, eye, target) -- 512
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 513
				end -- 512
			} -- 512
		end -- 512
	end -- 512
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 520
	if backdrop == nil then -- 520
		return nil -- 521
	end -- 521
	local bm = backdrop:getMaterial(0) -- 522
	if bm ~= nil and tex ~= nil then -- 522
		bm:setEmissiveTexture(tex) -- 524
		bm.baseColor = Color(0, 0, 0, 255) -- 525
		bm.emissive = Color3(StarBrightnessHex) -- 526
		bm.roughness = 1 -- 527
		bm.metallic = 0 -- 528
	end -- 528
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 530
	backdrop.angleX = -45 -- 531
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 532
	root:addChild(backdrop) -- 533
	return { -- 534
		node = backdrop, -- 535
		sync = function(____, eye, target) -- 536
			local dx = target.x - eye.x -- 537
			local dy = target.y - eye.y -- 538
			local dz = target.z - eye.z -- 539
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 540
			if len < 0.000001 then -- 540
				return -- 541
			end -- 541
			local s = BackdropDist / len -- 542
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 543
		end -- 536
	} -- 536
end -- 490
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 553
	local ____options_0 = options -- 554
	local root = ____options_0.root -- 554
	local bodies = ____options_0.bodies -- 554
	local visuals = ____options_0.visuals -- 554
	local probeStart = ____options_0.probeStart -- 554
	local starWorld = nil -- 562
	local starRadius = 0 -- 563
	local starGm = 0 -- 564
	do -- 564
		local i = 0 -- 565
		while i < #bodies do -- 565
			do -- 565
				local b = bodies[i + 1] -- 566
				if b.orbitRadius ~= 0 then -- 566
					goto __continue55 -- 567
				end -- 567
				if b.gm <= starGm then -- 567
					goto __continue55 -- 568
				end -- 568
				starGm = b.gm -- 569
				starRadius = b.radius -- 570
				starWorld = ____exports.planeToWorld({x = b.orbitCenter.x, y = b.orbitCenter.y}, 0) -- 571
			end -- 571
			::__continue55:: -- 571
			i = i + 1 -- 565
		end -- 565
	end -- 565
	local hasStar = starWorld ~= nil and starGm >= SunMinGmForLight -- 573
	do -- 573
		local light = DirectionalLight3D() -- 582
		light.color = Color3(16774106) -- 583
		light.intensity = 3.6 -- 584
		light.angleX = -42 -- 585
		light.angleY = 75 -- 586
		root:addChild(light) -- 587
	end -- 587
	local starIndex = -1 -- 590
	if hasStar then -- 590
		local best = 0 -- 592
		do -- 592
			local i = 0 -- 593
			while i < #bodies do -- 593
				local b = bodies[i + 1] -- 594
				if b.orbitRadius == 0 and b.gm > best then -- 594
					best = b.gm -- 596
					starIndex = i -- 597
				end -- 597
				i = i + 1 -- 593
			end -- 593
		end -- 593
	end -- 593
	local planets = {} -- 603
	do -- 603
		local i = 0 -- 604
		while i < #bodies do -- 604
			local def = bodies[i + 1] -- 605
			local vis = visuals[i + 1] -- 606
			local bodyModel = nil -- 609
			local k = 1 -- 610
			local modelName = vis.model ~= nil and vis.model or "" -- 611
			if modelName ~= "" then -- 611
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 613
				if loaded ~= nil then -- 613
					bodyModel = loaded -- 615
					k = ____exports.modelRadius(modelName) -- 616
				end -- 616
			end -- 616
			if bodyModel == nil then -- 616
				bodyModel = Model3D(options.spherePath) -- 620
				k = 1 -- 621
			end -- 621
			if bodyModel == nil then -- 621
				return nil -- 623
			end -- 623
			local scale = vis.displayRadius / k -- 626
			bodyModel.scale = Vec3(scale, scale, scale) -- 627
			____exports.applyPlanetTexture( -- 634
				bodyModel, -- 634
				modelName, -- 634
				____exports.packColor(vis.r, vis.g, vis.b), -- 634
				vis.emissive ~= nil and ____exports.packColor(vis.emissive.r, vis.emissive.g, vis.emissive.b) or 0 -- 635
			) -- 635
			root:addChild(bodyModel) -- 637
			local ringNode = nil -- 640
			if modelName == "" and vis.ring then -- 640
				local ring = Model3D(options.ringPath) -- 642
				if ring ~= nil then -- 642
					local rs = scale * 1.5 -- 645
					ring.scale = Vec3(rs, rs, rs) -- 646
					root:addChild(ring) -- 647
					ringNode = ring -- 648
				end -- 648
			end -- 648
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 652
			i = i + 1 -- 604
		end -- 604
	end -- 604
	do -- 604
		local i = 0 -- 660
		while i < #bodies do -- 660
			do -- 660
				local def = bodies[i + 1] -- 661
				if def.orbitRadius <= 0 then -- 661
					goto __continue72 -- 662
				end -- 662
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 663
				if not Content:exist(ringPath) then -- 663
					goto __continue72 -- 665
				end -- 665
				local orbitNode = Model3D(ringPath) -- 666
				if orbitNode == nil then -- 666
					goto __continue72 -- 667
				end -- 667
				local oi = 0 -- 668
				while oi < 8 do -- 668
					local om = orbitNode:getMaterial(oi) -- 670
					if om == nil then -- 670
						break -- 671
					end -- 671
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 673
					oi = oi + 1 -- 674
				end -- 674
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 676
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 677
				root:addChild(orbitNode) -- 678
			end -- 678
			::__continue72:: -- 678
			i = i + 1 -- 660
		end -- 660
	end -- 660
	if options.home ~= nil then -- 660
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 686
		if earth ~= nil then -- 686
			local ke = ____exports.modelRadius("Planet_Earth") -- 688
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 689
			local es = hr / ke -- 690
			earth.scale = Vec3(es, es, es) -- 691
			local emi = 0 -- 692
			while emi < 64 do -- 692
				local em = earth:getMaterial(emi) -- 694
				if em == nil then -- 694
					break -- 695
				end -- 695
				em.baseColor = Color(110, 170, 235, 255) -- 696
				em.emissive = Color3(792098) -- 698
				emi = emi + 1 -- 699
			end -- 699
			earth.position = ____exports.planeToWorld(options.home, 0) -- 701
			root:addChild(earth) -- 702
		end -- 702
	end -- 702
	local probe = ____exports.createProbe(root, { -- 712
		scale = options.probeScale, -- 713
		probePath = options.probePath, -- 714
		bodyPath = options.probeBodyPath, -- 715
		antennaPath = options.probeAntennaPath, -- 716
		antennaPivotY = options.probeAntennaPivotY, -- 717
		bodyRadius = options.probeBodyRadius, -- 718
		atlasPath = options.probeAtlasPath -- 719
	}) -- 719
	if probe == nil then -- 719
		return nil -- 721
	end -- 721
	local probeNode = probe.node -- 722
	local antennaModel = probe.antenna -- 723
	local probeRadius = probe.radius -- 724
	local bodyYawDeg = 0 -- 727
	local backdrop = ____exports.createStarBackdrop(root) -- 731
	local glowNode = nil -- 739
	local glowScale = 0 -- 742
	if hasStar and starWorld ~= nil then -- 742
		glowScale = SunGlowScale * starRadius * 2 -- 744
		local glowPath = "Assets/Model/StarQuad.gltf" -- 745
		if Content:exist(glowPath) then -- 745
			local glowModel = Model3D(glowPath) -- 747
			if glowModel ~= nil then -- 747
				local glowTex = Texture2D("Assets/Image/glow.png") -- 749
				local gl = glowModel:getMaterial(0) -- 750
				if gl ~= nil and glowTex ~= nil then -- 750
					gl:setBaseColorTexture(glowTex) -- 752
					gl:setEmissiveTexture(glowTex) -- 753
					gl.baseColor = Color(0, 0, 0, 255) -- 754
					gl.emissive = Color3(13154456) -- 755
					gl.roughness = 1 -- 756
					gl.metallic = 0 -- 757
					gl.alphaMode = 2 -- 758
				end -- 758
				glowModel.scale = Vec3(glowScale, glowScale, glowScale) -- 760
				glowModel.position = starWorld -- 761
				root:addChild(glowModel) -- 762
				glowNode = glowModel -- 763
			end -- 763
		end -- 763
	end -- 763
	local function syncBodies(t) -- 769
		for ____, p in ipairs(planets) do -- 770
			local wp = ____exports.planeToWorld( -- 771
				bodyPositionAt(p.def, t), -- 771
				0 -- 771
			) -- 771
			p.body.position = wp -- 772
			if p.ring ~= nil then -- 772
				p.ring.position = wp -- 773
			end -- 773
		end -- 773
	end -- 769
	local function syncProbe(p) -- 777
		probeNode.position = ____exports.planeToWorld(p, 0) -- 778
		if antennaModel ~= nil and options.home ~= nil then -- 778
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 784
		end -- 784
	end -- 777
	local function faceVelocity(v) -- 791
		local yaw = ____exports.probeYawForVelocity(v) -- 792
		if yaw == nil then -- 792
			return -- 793
		end -- 793
		bodyYawDeg = yaw -- 794
		probeNode.angleY = bodyYawDeg -- 795
	end -- 791
	local function syncBackdrop(eye, target) -- 799
		if backdrop ~= nil then -- 799
			backdrop:sync(eye, target) -- 800
		end -- 800
		if glowNode ~= nil and starWorld ~= nil then -- 800
			local dx = eye.x - starWorld.x -- 803
			local dy = eye.y - starWorld.y -- 804
			local dz = eye.z - starWorld.z -- 805
			if math.abs(dx) > 0.000001 or math.abs(dz) > 0.000001 then -- 805
				glowNode.angleY = math.atan(dx, dz) * 180 / math.pi -- 807
			end -- 807
			local flat = math.sqrt(dy * dy + dz * dz) -- 810
			local tilt = flat > 0.000001 and math.atan( -- 811
				math.abs(dy), -- 811
				flat -- 811
			) or 0 -- 811
			local c = math.cos(tilt) -- 812
			local stretch = c > 0.45 and 1 / c or 2.2 -- 813
			glowNode.scale = Vec3(glowScale, glowScale * stretch, glowScale) -- 814
		end -- 814
	end -- 799
	syncBodies(0) -- 819
	syncProbe(probeStart) -- 820
	return { -- 822
		syncBodies = syncBodies, -- 823
		syncProbe = syncProbe, -- 824
		faceVelocity = faceVelocity, -- 825
		syncBackdrop = syncBackdrop, -- 826
		probe = probeNode, -- 827
		antenna = antennaModel, -- 828
		planets = planets, -- 829
		probeRadius = probeRadius -- 830
	} -- 830
end -- 553
return ____exports -- 553
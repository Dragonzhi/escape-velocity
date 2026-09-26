-- [ts]: Scene.ts
local ____lualib = require("lualib_bundle") -- 1
local __TS__NumberToFixed = ____lualib.__TS__NumberToFixed -- 1
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
local OrbitRingTintHex = ____Config.OrbitRingTintHex -- 27
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
function ____exports.createProbe(parent, opts) -- 216
	local scale = opts.scale -- 217
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 218
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 221
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 224
	if bodyModel == nil and singleModel == nil then -- 224
		return nil -- 225
	end -- 225
	local node = Node3D() -- 227
	parent:addChild(node) -- 228
	if bodyModel ~= nil then -- 228
		bodyModel.scale = Vec3(scale, scale, scale) -- 231
		node:addChild(bodyModel) -- 232
	end -- 232
	if singleModel ~= nil then -- 232
		singleModel.scale = Vec3(scale, scale, scale) -- 235
		node:addChild(singleModel) -- 236
	end -- 236
	if bodyModel ~= nil and antennaModel ~= nil then -- 236
		antennaModel.scale = Vec3(scale, scale, scale) -- 242
		antennaModel.position = Vec3(0, ____exports.AntennaPivotY * scale, 0) -- 243
		node:addChild(antennaModel) -- 244
	end -- 244
	return {node = node, antenna = antennaModel, radius = 0.5 * 3.227 * scale * 1.1} -- 247
end -- 216
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 271
	local ex = (target.x - probe.x) * PlaneToWorldX -- 272
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 273
	local dist = math.sqrt(ex * ex + ez * ez) -- 274
	if dist <= 0.0001 then -- 274
		return -- 275
	end -- 275
	local tiltFactor = (dist - 0.5) / 3 -- 276
	if tiltFactor < 0 then -- 276
		tiltFactor = 0 -- 277
	end -- 277
	if tiltFactor > 1 then -- 277
		tiltFactor = 1 -- 278
	end -- 278
	local tilt = 46 * tiltFactor -- 279
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 280
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 281
end -- 271
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 291
	local wx = v.x * PlaneToWorldX -- 292
	local wz = v.y * PlaneToWorldZ -- 293
	if wx * wx + wz * wz < 1e-12 then -- 293
		return nil -- 294
	end -- 294
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 295
end -- 291
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 299
local BackdropHalf = 560 -- 300
--- 天球半径（世界单位）。
local SkyRadius = 1200 -- 303
--- 天球资产（Test/gen_orbit_assets.py 生成）。
local SkySpherePath = "Assets/Model/StarSphere.gltf" -- 305
--- 星空总亮度（emissive 0xRRGGBB）。
-- 
-- 2026-09-26 换天球时把 0x8c 调到 0x7a：新贴图是 2048×1024（1 texel ≈ 4.2 屏幕像素，
-- 星点直径 1.5–6 px），比旧面片版（1024²，1 texel ≈ 2.3 px）的点更大更亮，
-- 同样的 emissive 会显得"星点变大变吵"，压一档回到原来的观感。
local StarBrightnessHex = 8026746 -- 313
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
function ____exports.createStarBackdrop(root) -- 338
	local tex = Texture2D("Assets/Image/starfield.png") -- 339
	if Content:exist(SkySpherePath) then -- 339
		local sphere = Model3D(SkySpherePath) -- 343
		if sphere ~= nil then -- 343
			local sm = sphere:getMaterial(0) -- 345
			if sm ~= nil and tex ~= nil then -- 345
				sm:setEmissiveTexture(tex) -- 349
				sm.baseColor = Color(0, 0, 0, 255) -- 350
				sm.emissive = Color3(StarBrightnessHex) -- 351
				sm.roughness = 1 -- 352
				sm.metallic = 0 -- 353
			end -- 353
			sphere.scale = Vec3(SkyRadius, SkyRadius, SkyRadius) -- 355
			sphere.position = Vec3(0, 0, 0) -- 356
			root:addChild(sphere) -- 357
			return { -- 358
				node = sphere, -- 359
				sync = function(____, eye, target) -- 360
					sphere.position = Vec3(eye.x, eye.y, eye.z) -- 361
				end -- 360
			} -- 360
		end -- 360
	end -- 360
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 368
	if backdrop == nil then -- 368
		return nil -- 369
	end -- 369
	local bm = backdrop:getMaterial(0) -- 370
	if bm ~= nil and tex ~= nil then -- 370
		bm:setEmissiveTexture(tex) -- 372
		bm.baseColor = Color(0, 0, 0, 255) -- 373
		bm.emissive = Color3(StarBrightnessHex) -- 374
		bm.roughness = 1 -- 375
		bm.metallic = 0 -- 376
	end -- 376
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 378
	backdrop.angleX = -45 -- 379
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 380
	root:addChild(backdrop) -- 381
	return { -- 382
		node = backdrop, -- 383
		sync = function(____, eye, target) -- 384
			local dx = target.x - eye.x -- 385
			local dy = target.y - eye.y -- 386
			local dz = target.z - eye.z -- 387
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 388
			if len < 0.000001 then -- 388
				return -- 389
			end -- 389
			local s = BackdropDist / len -- 390
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 391
		end -- 384
	} -- 384
end -- 338
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 401
	local ____options_0 = options -- 402
	local root = ____options_0.root -- 402
	local bodies = ____options_0.bodies -- 402
	local visuals = ____options_0.visuals -- 402
	local probeStart = ____options_0.probeStart -- 402
	local light = DirectionalLight3D() -- 409
	light.color = Color3(16774106) -- 410
	light.intensity = 3.6 -- 411
	light.angleX = -42 -- 412
	light.angleY = 75 -- 413
	root:addChild(light) -- 414
	local planets = {} -- 417
	do -- 417
		local i = 0 -- 418
		while i < #bodies do -- 418
			local def = bodies[i + 1] -- 419
			local vis = visuals[i + 1] -- 420
			local bodyModel = nil -- 423
			local k = 1 -- 424
			local modelName = vis.model ~= nil and vis.model or "" -- 425
			if modelName ~= "" then -- 425
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 427
				if loaded ~= nil then -- 427
					bodyModel = loaded -- 429
					k = ____exports.modelRadius(modelName) -- 430
				end -- 430
			end -- 430
			if bodyModel == nil then -- 430
				bodyModel = Model3D(options.spherePath) -- 434
				k = 1 -- 435
			end -- 435
			if bodyModel == nil then -- 435
				return nil -- 437
			end -- 437
			local scale = vis.displayRadius / k -- 440
			bodyModel.scale = Vec3(scale, scale, scale) -- 441
			local mi = 0 -- 444
			while mi < 64 do -- 444
				local mat = bodyModel:getMaterial(mi) -- 446
				if mat == nil then -- 446
					break -- 447
				end -- 447
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 448
				local em = vis.emissive -- 449
				if em ~= nil then -- 449
					mat.emissive = Color3( -- 451
						math.floor(em.r * 255 + 0.5), -- 451
						math.floor(em.g * 255 + 0.5), -- 451
						math.floor(em.b * 255 + 0.5) -- 451
					) -- 451
				end -- 451
				mi = mi + 1 -- 452
			end -- 452
			root:addChild(bodyModel) -- 455
			local ringNode = nil -- 458
			if modelName == "" and vis.ring then -- 458
				local ring = Model3D(options.ringPath) -- 460
				if ring ~= nil then -- 460
					local rs = scale * 1.5 -- 463
					ring.scale = Vec3(rs, rs, rs) -- 464
					root:addChild(ring) -- 465
					ringNode = ring -- 466
				end -- 466
			end -- 466
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 470
			i = i + 1 -- 418
		end -- 418
	end -- 418
	do -- 418
		local i = 0 -- 478
		while i < #bodies do -- 478
			do -- 478
				local def = bodies[i + 1] -- 479
				if def.orbitRadius <= 0 then -- 479
					goto __continue40 -- 480
				end -- 480
				local ringPath = ("Assets/Model/OrbitRing_" .. __TS__NumberToFixed(def.orbitRadius, 0)) .. ".gltf" -- 481
				if not Content:exist(ringPath) then -- 481
					goto __continue40 -- 483
				end -- 483
				local orbitNode = Model3D(ringPath) -- 484
				if orbitNode == nil then -- 484
					goto __continue40 -- 485
				end -- 485
				local oi = 0 -- 486
				while oi < 8 do -- 486
					local om = orbitNode:getMaterial(oi) -- 488
					if om == nil then -- 488
						break -- 489
					end -- 489
					om.baseColor = Color((OrbitRingTintHex & 4294967295) >> 16 & 255, (OrbitRingTintHex & 4294967295) >> 8 & 255, OrbitRingTintHex & 255, 255) -- 491
					oi = oi + 1 -- 492
				end -- 492
				local oc = ____exports.planeToWorld(def.orbitCenter, 0) -- 494
				orbitNode.position = Vec3(oc.x, oc.y, oc.z) -- 495
				root:addChild(orbitNode) -- 496
			end -- 496
			::__continue40:: -- 496
			i = i + 1 -- 478
		end -- 478
	end -- 478
	if options.home ~= nil then -- 478
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 504
		if earth ~= nil then -- 504
			local ke = ____exports.modelRadius("Planet_Earth") -- 506
			local hr = options.homeRadius ~= nil and options.homeRadius or 1.15 -- 507
			local es = hr / ke -- 508
			earth.scale = Vec3(es, es, es) -- 509
			local emi = 0 -- 510
			while emi < 64 do -- 510
				local em = earth:getMaterial(emi) -- 512
				if em == nil then -- 512
					break -- 513
				end -- 513
				em.baseColor = Color(110, 170, 235, 255) -- 514
				em.emissive = Color3(792098) -- 516
				emi = emi + 1 -- 517
			end -- 517
			earth.position = ____exports.planeToWorld(options.home, 0) -- 519
			root:addChild(earth) -- 520
		end -- 520
	end -- 520
	local probe = ____exports.createProbe(root, {scale = options.probeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 530
	if probe == nil then -- 530
		return nil -- 536
	end -- 536
	local probeNode = probe.node -- 537
	local antennaModel = probe.antenna -- 538
	local probeRadius = probe.radius -- 539
	local bodyYawDeg = 0 -- 542
	local backdrop = ____exports.createStarBackdrop(root) -- 546
	local function syncBodies(t) -- 549
		for ____, p in ipairs(planets) do -- 550
			local wp = ____exports.planeToWorld( -- 551
				bodyPositionAt(p.def, t), -- 551
				0 -- 551
			) -- 551
			p.body.position = wp -- 552
			if p.ring ~= nil then -- 552
				p.ring.position = wp -- 553
			end -- 553
		end -- 553
	end -- 549
	local function syncProbe(p) -- 557
		probeNode.position = ____exports.planeToWorld(p, 0) -- 558
		if antennaModel ~= nil and options.home ~= nil then -- 558
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 564
		end -- 564
	end -- 557
	local function faceVelocity(v) -- 571
		local yaw = ____exports.probeYawForVelocity(v) -- 572
		if yaw == nil then -- 572
			return -- 573
		end -- 573
		bodyYawDeg = yaw -- 574
		probeNode.angleY = bodyYawDeg -- 575
	end -- 571
	local function syncBackdrop(eye, target) -- 579
		if backdrop ~= nil then -- 579
			backdrop:sync(eye, target) -- 580
		end -- 580
	end -- 579
	syncBodies(0) -- 584
	syncProbe(probeStart) -- 585
	return { -- 587
		syncBodies = syncBodies, -- 588
		syncProbe = syncProbe, -- 589
		faceVelocity = faceVelocity, -- 590
		syncBackdrop = syncBackdrop, -- 591
		probe = probeNode, -- 592
		antenna = antennaModel, -- 593
		planets = planets, -- 594
		probeRadius = probeRadius -- 595
	} -- 595
end -- 401
return ____exports -- 401
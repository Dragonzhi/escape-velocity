-- [ts]: Scene.ts
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
function ____exports.createProbe(parent, opts) -- 212
	local scale = opts.scale -- 213
	local bodyModel = opts.bodyPath ~= nil and Content:exist(opts.bodyPath) and Model3D(opts.bodyPath) or nil -- 214
	local antennaModel = bodyModel ~= nil and opts.antennaPath ~= nil and Content:exist(opts.antennaPath) and Model3D(opts.antennaPath) or nil -- 217
	local singleModel = bodyModel == nil and Model3D(opts.probePath) or nil -- 220
	if bodyModel == nil and singleModel == nil then -- 220
		return nil -- 221
	end -- 221
	local node = Node3D() -- 223
	parent:addChild(node) -- 224
	if bodyModel ~= nil then -- 224
		bodyModel.scale = Vec3(scale, scale, scale) -- 227
		node:addChild(bodyModel) -- 228
	end -- 228
	if singleModel ~= nil then -- 228
		singleModel.scale = Vec3(scale, scale, scale) -- 231
		node:addChild(singleModel) -- 232
	end -- 232
	if bodyModel ~= nil and antennaModel ~= nil then -- 232
		antennaModel.scale = Vec3(scale, scale, scale) -- 238
		antennaModel.position = Vec3(0, ____exports.AntennaPivotY * scale, 0) -- 239
		node:addChild(antennaModel) -- 240
	end -- 240
	return {node = node, antenna = antennaModel, radius = 0.5 * 3.227 * scale * 1.1} -- 243
end -- 212
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
function ____exports.pointAntenna(antenna, probe, target, bodyYawDeg) -- 267
	local ex = (target.x - probe.x) * PlaneToWorldX -- 268
	local ez = (target.y - probe.y) * PlaneToWorldZ -- 269
	local dist = math.sqrt(ex * ex + ez * ez) -- 270
	if dist <= 0.0001 then -- 270
		return -- 271
	end -- 271
	local tiltFactor = (dist - 0.5) / 3 -- 272
	if tiltFactor < 0 then -- 272
		tiltFactor = 0 -- 273
	end -- 273
	if tiltFactor > 1 then -- 273
		tiltFactor = 1 -- 274
	end -- 274
	local tilt = 46 * tiltFactor -- 275
	local phiWorld = math.atan(-ez, ex) * 180 / math.pi -- 276
	antenna.angles = Vec3(0, phiWorld - bodyYawDeg, -tilt) -- 277
end -- 267
--- 速度方向 → 机身 yaw（度）。返回 undefined 表示速度太小（保持原朝向）。
-- 
-- 世界方向 (dx, 0, dz) 对应 yaw = atan2(-dz, dx)（用已知朝 +X 的旧 Probe.gltf 在
-- yaw=0/90/180/270 读世界包围盒标定过）；模型自身"朝前的轴"不是 +X 时由
-- ProbeYawOffsetDeg 补正。
function ____exports.probeYawForVelocity(v) -- 287
	local wx = v.x * PlaneToWorldX -- 288
	local wz = v.y * PlaneToWorldZ -- 289
	if wx * wx + wz * wz < 1e-12 then -- 289
		return nil -- 290
	end -- 290
	return math.atan(-wz, wx) * 180 / math.pi + ProbeYawOffsetDeg -- 291
end -- 287
--- 星空背板距相机的距离（世界单位）与半边尺寸；理由见 createStarBackdrop。
local BackdropDist = 600 -- 295
local BackdropHalf = 560 -- 296
--- 建星空背板：一张程序化星图贴在**贴着相机**的四边形上（方案 B，2026-09-25 用户拍板）。
-- 
-- 为什么每帧贴着相机（sync）：相机距离在 [25,100] 内随包围盒变化、注视点也会移动，
-- 固定位置的背板会被移出画面或露出边缘；钉在"视线前方 600"相当于把星空放在无穷远
-- （无视差），任何距离/宽高比下都正好铺满（半边长 560 > 需求 600·tan(fov/2)·1.645 ≈ 490）。
-- 远裁剪面实测 > 2000（Test/FarPlaneProbe，2026-09-25；早前"z=-900 不可见"是误判）。
-- 
-- 素材由 Test/gen_star_assets.py 代码生成：Assets/Image/starfield.png（1024×1024）
-- + Assets/Model/StarQuad.gltf（顶点 ±1 ⇒ **scale = 半边长**，材质自带 doubleSided）。
function ____exports.createStarBackdrop(root) -- 317
	local backdrop = Model3D("Assets/Model/StarQuad.gltf") -- 318
	if backdrop == nil then -- 318
		return nil -- 319
	end -- 319
	local tex = Texture2D("Assets/Image/starfield.png") -- 320
	local bm = backdrop:getMaterial(0) -- 321
	if bm ~= nil and tex ~= nil then -- 321
		bm:setEmissiveTexture(tex) -- 325
		bm.baseColor = Color(0, 0, 0, 255) -- 326
		bm.emissive = Color3(9211020) -- 327
		bm.roughness = 1 -- 328
		bm.metallic = 0 -- 329
	end -- 329
	backdrop.scale = Vec3(BackdropHalf, BackdropHalf, BackdropHalf) -- 331
	backdrop.angleX = -45 -- 334
	backdrop.position = Vec3(0, 0, -BackdropDist) -- 335
	root:addChild(backdrop) -- 336
	return { -- 337
		node = backdrop, -- 338
		sync = function(____, eye, target) -- 339
			local dx = target.x - eye.x -- 340
			local dy = target.y - eye.y -- 341
			local dz = target.z - eye.z -- 342
			local len = math.sqrt(dx * dx + dy * dy + dz * dz) -- 343
			if len < 0.000001 then -- 343
				return -- 344
			end -- 344
			local s = BackdropDist / len -- 345
			backdrop.position = Vec3(eye.x + dx * s, eye.y + dy * s, eye.z + dz * s) -- 346
		end -- 339
	} -- 339
end -- 317
--- 构建场景。
-- 
-- @returns 场景句柄；若关键模型加载失败则返回 undefined（调用方应报错）。
function ____exports.buildScene(options) -- 356
	local ____options_0 = options -- 357
	local root = ____options_0.root -- 357
	local bodies = ____options_0.bodies -- 357
	local visuals = ____options_0.visuals -- 357
	local probeStart = ____options_0.probeStart -- 357
	local light = DirectionalLight3D() -- 364
	light.color = Color3(16774106) -- 365
	light.intensity = 3.6 -- 366
	light.angleX = -42 -- 367
	light.angleY = 75 -- 368
	root:addChild(light) -- 369
	local planets = {} -- 372
	do -- 372
		local i = 0 -- 373
		while i < #bodies do -- 373
			local def = bodies[i + 1] -- 374
			local vis = visuals[i + 1] -- 375
			local bodyModel = nil -- 378
			local k = 1 -- 379
			local modelName = vis.model ~= nil and vis.model or "" -- 380
			if modelName ~= "" then -- 380
				local loaded = Model3D(("Assets/Model/" .. modelName) .. ".glb") -- 382
				if loaded ~= nil then -- 382
					bodyModel = loaded -- 384
					k = ____exports.modelRadius(modelName) -- 385
				end -- 385
			end -- 385
			if bodyModel == nil then -- 385
				bodyModel = Model3D(options.spherePath) -- 389
				k = 1 -- 390
			end -- 390
			if bodyModel == nil then -- 390
				return nil -- 392
			end -- 392
			local scale = vis.displayRadius / k -- 395
			bodyModel.scale = Vec3(scale, scale, scale) -- 396
			local mi = 0 -- 399
			while mi < 64 do -- 399
				local mat = bodyModel:getMaterial(mi) -- 401
				if mat == nil then -- 401
					break -- 402
				end -- 402
				mat.baseColor = Color(vis.r * 255, vis.g * 255, vis.b * 255, 255) -- 403
				mi = mi + 1 -- 404
			end -- 404
			root:addChild(bodyModel) -- 407
			local ringNode = nil -- 410
			if modelName == "" and vis.ring then -- 410
				local ring = Model3D(options.ringPath) -- 412
				if ring ~= nil then -- 412
					local rs = scale * 1.5 -- 415
					ring.scale = Vec3(rs, rs, rs) -- 416
					root:addChild(ring) -- 417
					ringNode = ring -- 418
				end -- 418
			end -- 418
			planets[#planets + 1] = {body = bodyModel, ring = ringNode, def = def} -- 422
			i = i + 1 -- 373
		end -- 373
	end -- 373
	if options.home ~= nil then -- 373
		local earth = Model3D("Assets/Model/Planet_Earth.glb") -- 430
		if earth ~= nil then -- 430
			local ke = ____exports.modelRadius("Planet_Earth") -- 432
			local es = 1.15 / ke -- 433
			earth.scale = Vec3(es, es, es) -- 434
			local emi = 0 -- 435
			while emi < 64 do -- 435
				local em = earth:getMaterial(emi) -- 437
				if em == nil then -- 437
					break -- 438
				end -- 438
				em.baseColor = Color(110, 170, 235, 255) -- 439
				em.emissive = Color3(792098) -- 441
				emi = emi + 1 -- 442
			end -- 442
			earth.position = ____exports.planeToWorld(options.home, 0) -- 444
			root:addChild(earth) -- 445
		end -- 445
	end -- 445
	local probe = ____exports.createProbe(root, {scale = options.probeScale, probePath = options.probePath, bodyPath = options.probeBodyPath, antennaPath = options.probeAntennaPath}) -- 455
	if probe == nil then -- 455
		return nil -- 461
	end -- 461
	local probeNode = probe.node -- 462
	local antennaModel = probe.antenna -- 463
	local probeRadius = probe.radius -- 464
	local bodyYawDeg = 0 -- 467
	local backdrop = ____exports.createStarBackdrop(root) -- 471
	local function syncBodies(t) -- 474
		for ____, p in ipairs(planets) do -- 475
			local wp = ____exports.planeToWorld( -- 476
				bodyPositionAt(p.def, t), -- 476
				0 -- 476
			) -- 476
			p.body.position = wp -- 477
			if p.ring ~= nil then -- 477
				p.ring.position = wp -- 478
			end -- 478
		end -- 478
	end -- 474
	local function syncProbe(p) -- 482
		probeNode.position = ____exports.planeToWorld(p, 0) -- 483
		if antennaModel ~= nil and options.home ~= nil then -- 483
			____exports.pointAntenna(antennaModel, p, options.home, bodyYawDeg) -- 489
		end -- 489
	end -- 482
	local function faceVelocity(v) -- 496
		local yaw = ____exports.probeYawForVelocity(v) -- 497
		if yaw == nil then -- 497
			return -- 498
		end -- 498
		bodyYawDeg = yaw -- 499
		probeNode.angleY = bodyYawDeg -- 500
	end -- 496
	local function syncBackdrop(eye, target) -- 504
		if backdrop ~= nil then -- 504
			backdrop:sync(eye, target) -- 505
		end -- 505
	end -- 504
	syncBodies(0) -- 509
	syncProbe(probeStart) -- 510
	return { -- 512
		syncBodies = syncBodies, -- 513
		syncProbe = syncProbe, -- 514
		faceVelocity = faceVelocity, -- 515
		syncBackdrop = syncBackdrop, -- 516
		probe = probeNode, -- 517
		antenna = antennaModel, -- 518
		planets = planets, -- 519
		probeRadius = probeRadius -- 520
	} -- 520
end -- 356
return ____exports -- 356
-- [ts]: Tuning.ts
local ____exports = {} -- 1
--- 探测器的视觉半径。
-- 
-- 真实尺寸（几米）在 1.87e6 km/单位 的尺度下是 1e-9 量级，等于不可见。
-- 0.0015 是**可见性下限**（用户 2026-09-27 拍板「探测器视觉半径 0.0015 现在也行」），
-- 比真实值大约 13 个数量级 —— 这是这一层存在的全部理由。
____exports.PROBE_VISUAL_RADIUS = 0.0015 -- 34
--- 各天体的视觉半径（世界单位）。
-- 
-- ⚠️ 单一份表服务六关，但 **L1 的尺度与别处差 130 倍**（别处看 80~2400 单位的日心系，
-- L1 看 0.6 单位宽的地月系）。同一个 0.025 在 L2–L6 是合理的点，在 L1 只占世界宽度的 4%，
-- 3D 里几乎看不见（用户实测「3D 状态下完全看不到地球」）。
-- 
-- ⇒ L1 的地月系用**专用值**：地球 0.06（世界宽度的 10%）、月球 0.02。
-- 取值只影响看得见的大小，**不参与任何物理判定**。
local BODY_VISUAL_L1 = {sun = 0.8, earth = 0.0034, moon = 0.00093, probe = 0.00015} -- 58
____exports.BODY_VISUAL_RADIUS = { -- 74
	sun = 1.6, -- 75
	mercury = 0.022, -- 76
	venus = 0.028, -- 77
	earth = 0.03, -- 78
	moon = 0.012, -- 79
	jupiter = 2, -- 80
	saturn = 1.2, -- 81
	uranus = 0.5, -- 82
	neptune = 0.4 -- 83
} -- 83
--- 取某个天体的视觉半径。
-- 
-- @param levelIndex 关卡下标（0 = L1）：L1 用地月系专用表，别处用日心系表。
-- @param key 天体键（'earth' / 'moon' / ...）
-- @param trueRadius 真实半径（查不到时的兜底，不会静默变成 0）
function ____exports.visualRadius(key, trueRadius, levelIndex) -- 93
	local ____table = levelIndex == 0 and BODY_VISUAL_L1 or ____exports.BODY_VISUAL_RADIUS -- 94
	local v = ____table[key] -- 95
	return v ~= nil and v or trueRadius -- 96
end -- 93
--- 2D 图钉半径（**屏幕像素**，不随视野缩放）。
-- 
-- 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
____exports.PLAN_PIN_PX = {sun = 13, planet = 8, probe = 11} -- 108
--- 各天体的**自转周期**（游戏秒，B2，2026-09-28）。
-- 
-- 口径：真实自转周期 ÷ SecPerGameSec。
--   - 地球 86,164 真实秒 ⇒ **4.5747e-5 游戏秒**（1× 下 24 小时转一圈 —— 就是用户要的
--     「挂机一天才能看到地球自转一圈」那种物理真实的慢）；
--   - 月球**潮汐锁定** ⇒ 自转周期 = 公转周期 1.2593 游戏秒（永远同一面朝地球）。
-- ⚠️ 键是**模型名**（`PlanetVisualDef.model`，Scene 里唯一拿得到的身份）；只影响观感、
--    不参与任何判定。表里没有的天体不自转。
____exports.SPIN_GAME_SEC = {Planet_Earth = 0.000045747, Moon = 1.2593} -- 120
--- 天体的**显示名**（2D 读数用，B 修复③，2026-09-28）。
-- 
-- 键是**模型名**（`PlanetVisualDef.model`）——与 SPIN_GAME_SEC 同一套身份，PlanView/Scene
-- 拿不到中文名，只有模型名。用户要的 2D 观感是"像航天模拟器的地图"：**每个天体挂着名字与距离**，
-- 于是"月球在哪、还有多远"不用靠猜。
____exports.BODY_LABEL = { -- 132
	Sun = "太阳", -- 133
	Moon = "月球", -- 134
	Planet_Earth = "地球", -- 135
	Planet_Mercury = "水星", -- 136
	Planet_Venus = "金星", -- 137
	Planet_Mars = "火星", -- 138
	Planet_Jupiter = "木星", -- 139
	Planet_Saturn = "土星", -- 140
	Planet_Uranus = "天王星", -- 141
	Planet_Neptune = "海王星", -- 142
	Asteroid_Rock = "太空陨石", -- 143
	Target_Gate = "星门终点", -- 144
	Star_Crystal = "星尘晶体" -- 145
} -- 145
--- 取显示名；表里没有的名字退回「天体」（不编造名字，也不留空）。
function ____exports.bodyLabel(model) -- 149
	if model ~= nil then -- 149
		local v = ____exports.BODY_LABEL[model] -- 151
		if v ~= nil then -- 151
			return v -- 152
		end -- 152
	end -- 152
	return "天体" -- 154
end -- 149
--- 引擎默认的近裁剪面（世界单位）。
-- 
-- 出处：引擎的 `Script/Dev/Entry.yue` 里写着 `View.nearPlaneDistance = 0.1`（`farPlaneDistance = 10000`）。
-- ⚠️ 它**是全局的**（`View` 是应用级单例；`Camera3D` 的 d.ts 只有 position/target/up/lookAt，
-- 没有 near/far），所以「近平面跟着世界尺度走」只能由代码在**切关/切相机时**写一遍
-- （见 init.ts 的 `applyClipPlanes`）。
____exports.CLIP_NEAR_DEFAULT = 0.1 -- 169
--- 引擎默认的远裁剪面（世界单位）。星空天球在 600–1200 处，必须装得下。
____exports.CLIP_FAR_DEFAULT = 10000 -- 172
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = {{ -- 335
	physicsStep = 0.016, -- 337
	maxStepsPerFrame = 4, -- 337
	sampleEvery = 1, -- 337
	predictSteps = 800, -- 337
	playback = 1, -- 338
	playbackSpeeds = {0.5, 1, 2}, -- 338
	cameraMin = 200, -- 339
	cameraMax = 1200, -- 339
	aimMin = 60, -- 339
	introCloseDist = 100, -- 339
	aimClockRate = 0, -- 340
	slowMoFloor = 45, -- 340
	probeVisualRadius = 10, -- 340
	aimFraming = "local", -- 341
	tiltDeg = 0, -- 341
	orbitFlowDots = false, -- 341
	orbitRings = false, -- 341
	speedDefaultPow = 0, -- 342
	speedMaxPow = 0, -- 342
	flightSpeedPow = 0, -- 342
	cameraNear = 0.1, -- 343
	cameraFar = 5000 -- 343
}, { -- 343
	physicsStep = 0.016, -- 346
	maxStepsPerFrame = 4, -- 346
	sampleEvery = 1, -- 346
	predictSteps = 800, -- 346
	playback = 1, -- 347
	playbackSpeeds = {0.5, 1, 2}, -- 347
	cameraMin = 200, -- 348
	cameraMax = 1200, -- 348
	aimMin = 60, -- 348
	introCloseDist = 100, -- 348
	aimClockRate = 0, -- 349
	slowMoFloor = 45, -- 349
	probeVisualRadius = 10, -- 349
	aimFraming = "local", -- 350
	tiltDeg = 0, -- 350
	orbitFlowDots = false, -- 350
	orbitRings = false, -- 350
	speedDefaultPow = 0, -- 351
	speedMaxPow = 0, -- 351
	flightSpeedPow = 0, -- 351
	cameraNear = 0.1, -- 352
	cameraFar = 5000 -- 352
}, { -- 352
	physicsStep = 0.016, -- 355
	maxStepsPerFrame = 4, -- 355
	sampleEvery = 1, -- 355
	predictSteps = 800, -- 355
	playback = 1, -- 356
	playbackSpeeds = {0.5, 1, 2}, -- 356
	cameraMin = 200, -- 357
	cameraMax = 1200, -- 357
	aimMin = 60, -- 357
	introCloseDist = 100, -- 357
	aimClockRate = 0, -- 358
	slowMoFloor = 45, -- 358
	probeVisualRadius = 10, -- 358
	aimFraming = "local", -- 359
	tiltDeg = 0, -- 359
	orbitFlowDots = false, -- 359
	orbitRings = false, -- 359
	speedDefaultPow = 0, -- 360
	speedMaxPow = 0, -- 360
	flightSpeedPow = 0, -- 360
	cameraNear = 0.1, -- 361
	cameraFar = 5000 -- 361
}} -- 361
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 366
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 366
		return ____exports.LEVEL_RUNTIME[index + 1] -- 367
	end -- 367
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 368
end -- 366
return ____exports -- 366
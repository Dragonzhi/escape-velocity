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
local BODY_VISUAL_L1 = {sun = 0.8, earth = 0.0015, moon = 0.0004, probe = 0.00015} -- 58
____exports.BODY_VISUAL_RADIUS = { -- 71
	sun = 1.6, -- 72
	mercury = 0.018, -- 73
	venus = 0.03, -- 74
	earth = 0.025, -- 75
	moon = 0.012, -- 76
	jupiter = 2, -- 77
	saturn = 1.2, -- 78
	uranus = 0.5, -- 79
	neptune = 0.4 -- 80
} -- 80
--- 取某个天体的视觉半径。
-- 
-- @param levelIndex 关卡下标（0 = L1）：L1 用地月系专用表，别处用日心系表。
-- @param key 天体键（'earth' / 'moon' / ...）
-- @param trueRadius 真实半径（查不到时的兜底，不会静默变成 0）
function ____exports.visualRadius(key, trueRadius, levelIndex) -- 90
	local ____table = levelIndex == 0 and BODY_VISUAL_L1 or ____exports.BODY_VISUAL_RADIUS -- 91
	local v = ____table[key] -- 92
	return v ~= nil and v or trueRadius -- 93
end -- 90
--- 2D 图钉半径（**屏幕像素**，不随视野缩放）。
-- 
-- 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
____exports.PLAN_PIN_PX = {sun = 13, planet = 8, probe = 11} -- 105
--- 各天体的**自转周期**（游戏秒，B2，2026-09-28）。
-- 
-- 口径：真实自转周期 ÷ SecPerGameSec。
--   - 地球 86,164 真实秒 ⇒ **4.5747e-5 游戏秒**（1× 下 24 小时转一圈 —— 就是用户要的
--     「挂机一天才能看到地球自转一圈」那种物理真实的慢）；
--   - 月球**潮汐锁定** ⇒ 自转周期 = 公转周期 1.2593 游戏秒（永远同一面朝地球）。
-- ⚠️ 键是**模型名**（`PlanetVisualDef.model`，Scene 里唯一拿得到的身份）；只影响观感、
--    不参与任何判定。表里没有的天体不自转。
____exports.SPIN_GAME_SEC = {Planet_Earth = 0.000045747, Moon = 1.2593} -- 117
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 250
	{ -- 251
		physicsStep = 0.00001406967, -- 262
		maxStepsPerFrame = 16, -- 262
		sampleEvery = 4, -- 262
		predictSteps = 8000, -- 262
		playback = 0.25, -- 265
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 265
		cameraMin = 0.002, -- 267
		cameraMax = 1, -- 267
		aimMin = 3, -- 267
		introCloseDist = 0.004, -- 267
		aimClockRate = 0, -- 269
		slowMoFloor = 0.01, -- 269
		probeVisualRadius = 0.00015, -- 269
		aimFraming = "local", -- 271
		tiltDeg = 22, -- 271
		orbitFlowDots = false, -- 271
		speedDefaultPow = 0, -- 272
		speedMaxPow = 7, -- 272
		flightSpeedPow = 4 -- 272
	}, -- 272
	{ -- 274
		physicsStep = 1 / 240, -- 275
		maxStepsPerFrame = 8, -- 275
		sampleEvery = 1, -- 275
		predictSteps = 2400, -- 275
		playback = 2, -- 276
		playbackSpeeds = {1, 2, 4}, -- 276
		cameraMin = 20, -- 277
		cameraMax = 200, -- 277
		aimMin = 0.2, -- 277
		introCloseDist = 26, -- 277
		aimClockRate = 1, -- 277
		slowMoFloor = 8, -- 277
		probeVisualRadius = 2.2 -- 277
	}, -- 277
	{ -- 280
		physicsStep = 1 / 240, -- 281
		maxStepsPerFrame = 16, -- 281
		sampleEvery = 4, -- 281
		predictSteps = 2400, -- 281
		playback = 4, -- 282
		playbackSpeeds = {2, 4, 8}, -- 282
		cameraMin = 60, -- 283
		cameraMax = 900, -- 283
		aimMin = 0.5, -- 283
		introCloseDist = 60, -- 283
		aimClockRate = 1, -- 283
		slowMoFloor = 8, -- 283
		probeVisualRadius = 2.2 -- 283
	}, -- 283
	{ -- 286
		physicsStep = 1 / 240, -- 287
		maxStepsPerFrame = 16, -- 287
		sampleEvery = 8, -- 287
		predictSteps = 2400, -- 287
		playback = 8, -- 288
		playbackSpeeds = {4, 8, 16}, -- 288
		cameraMin = 100, -- 289
		cameraMax = 1800, -- 289
		aimMin = 0.5, -- 289
		introCloseDist = 120, -- 289
		aimClockRate = 1, -- 289
		slowMoFloor = 8, -- 289
		probeVisualRadius = 2.2 -- 289
	}, -- 289
	{ -- 292
		physicsStep = 1 / 120, -- 293
		maxStepsPerFrame = 32, -- 293
		sampleEvery = 16, -- 293
		predictSteps = 2400, -- 293
		playback = 16, -- 294
		playbackSpeeds = {8, 16, 32}, -- 294
		cameraMin = 200, -- 295
		cameraMax = 3600, -- 295
		aimMin = 0.5, -- 295
		introCloseDist = 240, -- 295
		aimClockRate = 1, -- 295
		slowMoFloor = 8, -- 295
		probeVisualRadius = 2.2 -- 295
	}, -- 295
	{ -- 298
		physicsStep = 1 / 120, -- 299
		maxStepsPerFrame = 32, -- 299
		sampleEvery = 16, -- 299
		predictSteps = 2400, -- 299
		playback = 16, -- 300
		playbackSpeeds = {8, 16, 32}, -- 300
		cameraMin = 300, -- 301
		cameraMax = 5600, -- 301
		aimMin = 0.5, -- 301
		introCloseDist = 400, -- 301
		aimClockRate = 1, -- 301
		slowMoFloor = 8, -- 301
		probeVisualRadius = 2.2, -- 301
		speedDefaultPow = 6, -- 303
		speedMaxPow = 9, -- 303
		flightSpeedPow = 8 -- 303
	} -- 303
} -- 303
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 308
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 308
		return ____exports.LEVEL_RUNTIME[index + 1] -- 309
	end -- 309
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 310
end -- 308
return ____exports -- 308
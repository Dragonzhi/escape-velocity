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
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 253
	{ -- 254
		physicsStep = 0.00001406967, -- 265
		maxStepsPerFrame = 16, -- 265
		sampleEvery = 4, -- 265
		predictSteps = 8000, -- 265
		playback = 0.25, -- 268
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 268
		cameraMin = 0.002, -- 270
		cameraMax = 1, -- 270
		aimMin = 3, -- 270
		introCloseDist = 0.004, -- 270
		aimClockRate = 0, -- 272
		slowMoFloor = 0.01, -- 272
		probeVisualRadius = 0.00015, -- 272
		aimFraming = "local", -- 274
		tiltDeg = 22, -- 274
		orbitFlowDots = false, -- 274
		speedDefaultPow = 0, -- 275
		speedMaxPow = 7, -- 275
		flightSpeedPow = 4 -- 275
	}, -- 275
	{ -- 277
		physicsStep = 1 / 240, -- 278
		maxStepsPerFrame = 8, -- 278
		sampleEvery = 1, -- 278
		predictSteps = 2400, -- 278
		playback = 2, -- 279
		playbackSpeeds = {1, 2, 4}, -- 279
		cameraMin = 20, -- 280
		cameraMax = 200, -- 280
		aimMin = 0.2, -- 280
		introCloseDist = 26, -- 280
		aimClockRate = 1, -- 280
		slowMoFloor = 8, -- 280
		probeVisualRadius = 2.2 -- 280
	}, -- 280
	{ -- 283
		physicsStep = 1 / 240, -- 284
		maxStepsPerFrame = 16, -- 284
		sampleEvery = 4, -- 284
		predictSteps = 2400, -- 284
		playback = 4, -- 285
		playbackSpeeds = {2, 4, 8}, -- 285
		cameraMin = 60, -- 286
		cameraMax = 900, -- 286
		aimMin = 0.5, -- 286
		introCloseDist = 60, -- 286
		aimClockRate = 1, -- 286
		slowMoFloor = 8, -- 286
		probeVisualRadius = 2.2 -- 286
	}, -- 286
	{ -- 289
		physicsStep = 1 / 240, -- 290
		maxStepsPerFrame = 16, -- 290
		sampleEvery = 8, -- 290
		predictSteps = 2400, -- 290
		playback = 8, -- 291
		playbackSpeeds = {4, 8, 16}, -- 291
		cameraMin = 100, -- 292
		cameraMax = 1800, -- 292
		aimMin = 0.5, -- 292
		introCloseDist = 120, -- 292
		aimClockRate = 1, -- 292
		slowMoFloor = 8, -- 292
		probeVisualRadius = 2.2 -- 292
	}, -- 292
	{ -- 295
		physicsStep = 1 / 120, -- 296
		maxStepsPerFrame = 32, -- 296
		sampleEvery = 16, -- 296
		predictSteps = 2400, -- 296
		playback = 16, -- 297
		playbackSpeeds = {8, 16, 32}, -- 297
		cameraMin = 200, -- 298
		cameraMax = 3600, -- 298
		aimMin = 0.5, -- 298
		introCloseDist = 240, -- 298
		aimClockRate = 1, -- 298
		slowMoFloor = 8, -- 298
		probeVisualRadius = 2.2 -- 298
	}, -- 298
	{ -- 301
		physicsStep = 1 / 120, -- 302
		maxStepsPerFrame = 32, -- 302
		sampleEvery = 16, -- 302
		predictSteps = 2400, -- 302
		playback = 16, -- 303
		playbackSpeeds = {8, 16, 32}, -- 303
		cameraMin = 300, -- 304
		cameraMax = 5600, -- 304
		aimMin = 0.5, -- 304
		introCloseDist = 400, -- 304
		aimClockRate = 1, -- 304
		slowMoFloor = 8, -- 304
		probeVisualRadius = 2.2, -- 304
		speedDefaultPow = 6, -- 306
		speedMaxPow = 9, -- 306
		flightSpeedPow = 8 -- 306
	} -- 306
} -- 306
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 311
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 311
		return ____exports.LEVEL_RUNTIME[index + 1] -- 312
	end -- 312
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 313
end -- 311
return ____exports -- 311
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
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 205
	{ -- 206
		physicsStep = 0.00001406967, -- 217
		maxStepsPerFrame = 16, -- 217
		sampleEvery = 4, -- 217
		predictSteps = 8000, -- 217
		playback = 0.25, -- 220
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 220
		cameraMin = 0.002, -- 222
		cameraMax = 1, -- 222
		aimMin = 3, -- 222
		introCloseDist = 0.004, -- 222
		aimClockRate = 0, -- 224
		slowMoFloor = 0.01, -- 224
		probeVisualRadius = 0.00015 -- 224
	}, -- 224
	{ -- 226
		physicsStep = 1 / 240, -- 227
		maxStepsPerFrame = 8, -- 227
		sampleEvery = 1, -- 227
		predictSteps = 2400, -- 227
		playback = 2, -- 228
		playbackSpeeds = {1, 2, 4}, -- 228
		cameraMin = 20, -- 229
		cameraMax = 200, -- 229
		aimMin = 0.2, -- 229
		introCloseDist = 26, -- 229
		aimClockRate = 1, -- 229
		slowMoFloor = 8, -- 229
		probeVisualRadius = 2.2 -- 229
	}, -- 229
	{ -- 231
		physicsStep = 1 / 240, -- 232
		maxStepsPerFrame = 16, -- 232
		sampleEvery = 4, -- 232
		predictSteps = 2400, -- 232
		playback = 4, -- 233
		playbackSpeeds = {2, 4, 8}, -- 233
		cameraMin = 60, -- 234
		cameraMax = 900, -- 234
		aimMin = 0.5, -- 234
		introCloseDist = 60, -- 234
		aimClockRate = 1, -- 234
		slowMoFloor = 8, -- 234
		probeVisualRadius = 2.2 -- 234
	}, -- 234
	{ -- 236
		physicsStep = 1 / 240, -- 237
		maxStepsPerFrame = 16, -- 237
		sampleEvery = 8, -- 237
		predictSteps = 2400, -- 237
		playback = 8, -- 238
		playbackSpeeds = {4, 8, 16}, -- 238
		cameraMin = 100, -- 239
		cameraMax = 1800, -- 239
		aimMin = 0.5, -- 239
		introCloseDist = 120, -- 239
		aimClockRate = 1, -- 239
		slowMoFloor = 8, -- 239
		probeVisualRadius = 2.2 -- 239
	}, -- 239
	{ -- 241
		physicsStep = 1 / 120, -- 242
		maxStepsPerFrame = 32, -- 242
		sampleEvery = 16, -- 242
		predictSteps = 2400, -- 242
		playback = 16, -- 243
		playbackSpeeds = {8, 16, 32}, -- 243
		cameraMin = 200, -- 244
		cameraMax = 3600, -- 244
		aimMin = 0.5, -- 244
		introCloseDist = 240, -- 244
		aimClockRate = 1, -- 244
		slowMoFloor = 8, -- 244
		probeVisualRadius = 2.2 -- 244
	}, -- 244
	{ -- 246
		physicsStep = 1 / 120, -- 247
		maxStepsPerFrame = 32, -- 247
		sampleEvery = 16, -- 247
		predictSteps = 2400, -- 247
		playback = 16, -- 248
		playbackSpeeds = {8, 16, 32}, -- 248
		cameraMin = 300, -- 249
		cameraMax = 5600, -- 249
		aimMin = 0.5, -- 249
		introCloseDist = 400, -- 249
		aimClockRate = 1, -- 249
		slowMoFloor = 8, -- 249
		probeVisualRadius = 2.2 -- 249
	} -- 249
} -- 249
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 254
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 254
		return ____exports.LEVEL_RUNTIME[index + 1] -- 255
	end -- 255
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 256
end -- 254
return ____exports -- 254
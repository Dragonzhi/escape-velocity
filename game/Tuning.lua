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
local BODY_VISUAL_L1 = {sun = 0.8, earth = 0.03, moon = 0.012, probe = 0.0015} -- 58
____exports.BODY_VISUAL_RADIUS = { -- 68
	sun = 1.6, -- 69
	venus = 0.03, -- 70
	earth = 0.025, -- 71
	moon = 0.012, -- 72
	jupiter = 2, -- 73
	saturn = 1.2, -- 74
	uranus = 0.5, -- 75
	neptune = 0.4 -- 76
} -- 76
--- 取某个天体的视觉半径。
-- 
-- @param levelIndex 关卡下标（0 = L1）：L1 用地月系专用表，别处用日心系表。
-- @param key 天体键（'earth' / 'moon' / ...）
-- @param trueRadius 真实半径（查不到时的兜底，不会静默变成 0）
function ____exports.visualRadius(key, trueRadius, levelIndex) -- 86
	local ____table = levelIndex == 0 and BODY_VISUAL_L1 or ____exports.BODY_VISUAL_RADIUS -- 87
	local v = ____table[key] -- 88
	return v ~= nil and v or trueRadius -- 89
end -- 86
--- 2D 图钉半径（**屏幕像素**，不随视野缩放）。
-- 
-- 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
____exports.PLAN_PIN_PX = {sun = 13, planet = 8, probe = 11} -- 101
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 192
	{ -- 193
		physicsStep = 1 / 2000, -- 199
		maxStepsPerFrame = 16, -- 199
		sampleEvery = 1, -- 199
		playback = 0.25, -- 200
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 200
		cameraMin = 0.02, -- 201
		cameraMax = 1.2, -- 201
		aimMin = 0.02, -- 201
		introCloseDist = 0.6, -- 201
		aimClockRate = 0, -- 202
		slowMoFloor = 0.05, -- 202
		probeVisualRadius = 0.0015 -- 202
	}, -- 202
	{ -- 204
		physicsStep = 1 / 240, -- 205
		maxStepsPerFrame = 8, -- 205
		sampleEvery = 1, -- 205
		playback = 2, -- 206
		playbackSpeeds = {1, 2, 4}, -- 206
		cameraMin = 20, -- 207
		cameraMax = 200, -- 207
		aimMin = 0.2, -- 207
		introCloseDist = 26, -- 207
		aimClockRate = 1, -- 207
		slowMoFloor = 8, -- 207
		probeVisualRadius = 2.2 -- 207
	}, -- 207
	{ -- 209
		physicsStep = 1 / 240, -- 210
		maxStepsPerFrame = 16, -- 210
		sampleEvery = 4, -- 210
		playback = 4, -- 211
		playbackSpeeds = {2, 4, 8}, -- 211
		cameraMin = 60, -- 212
		cameraMax = 900, -- 212
		aimMin = 0.5, -- 212
		introCloseDist = 60, -- 212
		aimClockRate = 1, -- 212
		slowMoFloor = 8, -- 212
		probeVisualRadius = 2.2 -- 212
	}, -- 212
	{ -- 214
		physicsStep = 1 / 240, -- 215
		maxStepsPerFrame = 16, -- 215
		sampleEvery = 8, -- 215
		playback = 8, -- 216
		playbackSpeeds = {4, 8, 16}, -- 216
		cameraMin = 100, -- 217
		cameraMax = 1800, -- 217
		aimMin = 0.5, -- 217
		introCloseDist = 120, -- 217
		aimClockRate = 1, -- 217
		slowMoFloor = 8, -- 217
		probeVisualRadius = 2.2 -- 217
	}, -- 217
	{ -- 219
		physicsStep = 1 / 120, -- 220
		maxStepsPerFrame = 32, -- 220
		sampleEvery = 16, -- 220
		playback = 16, -- 221
		playbackSpeeds = {8, 16, 32}, -- 221
		cameraMin = 200, -- 222
		cameraMax = 3600, -- 222
		aimMin = 0.5, -- 222
		introCloseDist = 240, -- 222
		aimClockRate = 1, -- 222
		slowMoFloor = 8, -- 222
		probeVisualRadius = 2.2 -- 222
	}, -- 222
	{ -- 224
		physicsStep = 1 / 120, -- 225
		maxStepsPerFrame = 32, -- 225
		sampleEvery = 16, -- 225
		playback = 16, -- 226
		playbackSpeeds = {8, 16, 32}, -- 226
		cameraMin = 300, -- 227
		cameraMax = 5600, -- 227
		aimMin = 0.5, -- 227
		introCloseDist = 400, -- 227
		aimClockRate = 1, -- 227
		slowMoFloor = 8, -- 227
		probeVisualRadius = 2.2 -- 227
	} -- 227
} -- 227
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 232
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 232
		return ____exports.LEVEL_RUNTIME[index + 1] -- 233
	end -- 233
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 234
end -- 232
return ____exports -- 232
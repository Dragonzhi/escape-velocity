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
	mercury = 0.018, -- 70
	venus = 0.03, -- 71
	earth = 0.025, -- 72
	moon = 0.012, -- 73
	jupiter = 2, -- 74
	saturn = 1.2, -- 75
	uranus = 0.5, -- 76
	neptune = 0.4 -- 77
} -- 77
--- 取某个天体的视觉半径。
-- 
-- @param levelIndex 关卡下标（0 = L1）：L1 用地月系专用表，别处用日心系表。
-- @param key 天体键（'earth' / 'moon' / ...）
-- @param trueRadius 真实半径（查不到时的兜底，不会静默变成 0）
function ____exports.visualRadius(key, trueRadius, levelIndex) -- 87
	local ____table = levelIndex == 0 and BODY_VISUAL_L1 or ____exports.BODY_VISUAL_RADIUS -- 88
	local v = ____table[key] -- 89
	return v ~= nil and v or trueRadius -- 90
end -- 87
--- 2D 图钉半径（**屏幕像素**，不随视野缩放）。
-- 
-- 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
____exports.PLAN_PIN_PX = {sun = 13, planet = 8, probe = 11} -- 102
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 193
	{ -- 194
		physicsStep = 1 / 2000, -- 200
		maxStepsPerFrame = 16, -- 200
		sampleEvery = 1, -- 200
		playback = 0.25, -- 201
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 201
		cameraMin = 0.02, -- 202
		cameraMax = 1.2, -- 202
		aimMin = 0.02, -- 202
		introCloseDist = 0.6, -- 202
		aimClockRate = 0, -- 203
		slowMoFloor = 0.05, -- 203
		probeVisualRadius = 0.0015 -- 203
	}, -- 203
	{ -- 205
		physicsStep = 1 / 240, -- 206
		maxStepsPerFrame = 8, -- 206
		sampleEvery = 1, -- 206
		playback = 2, -- 207
		playbackSpeeds = {1, 2, 4}, -- 207
		cameraMin = 20, -- 208
		cameraMax = 200, -- 208
		aimMin = 0.2, -- 208
		introCloseDist = 26, -- 208
		aimClockRate = 1, -- 208
		slowMoFloor = 8, -- 208
		probeVisualRadius = 2.2 -- 208
	}, -- 208
	{ -- 210
		physicsStep = 1 / 240, -- 211
		maxStepsPerFrame = 16, -- 211
		sampleEvery = 4, -- 211
		playback = 4, -- 212
		playbackSpeeds = {2, 4, 8}, -- 212
		cameraMin = 60, -- 213
		cameraMax = 900, -- 213
		aimMin = 0.5, -- 213
		introCloseDist = 60, -- 213
		aimClockRate = 1, -- 213
		slowMoFloor = 8, -- 213
		probeVisualRadius = 2.2 -- 213
	}, -- 213
	{ -- 215
		physicsStep = 1 / 240, -- 216
		maxStepsPerFrame = 16, -- 216
		sampleEvery = 8, -- 216
		playback = 8, -- 217
		playbackSpeeds = {4, 8, 16}, -- 217
		cameraMin = 100, -- 218
		cameraMax = 1800, -- 218
		aimMin = 0.5, -- 218
		introCloseDist = 120, -- 218
		aimClockRate = 1, -- 218
		slowMoFloor = 8, -- 218
		probeVisualRadius = 2.2 -- 218
	}, -- 218
	{ -- 220
		physicsStep = 1 / 120, -- 221
		maxStepsPerFrame = 32, -- 221
		sampleEvery = 16, -- 221
		playback = 16, -- 222
		playbackSpeeds = {8, 16, 32}, -- 222
		cameraMin = 200, -- 223
		cameraMax = 3600, -- 223
		aimMin = 0.5, -- 223
		introCloseDist = 240, -- 223
		aimClockRate = 1, -- 223
		slowMoFloor = 8, -- 223
		probeVisualRadius = 2.2 -- 223
	}, -- 223
	{ -- 225
		physicsStep = 1 / 120, -- 226
		maxStepsPerFrame = 32, -- 226
		sampleEvery = 16, -- 226
		playback = 16, -- 227
		playbackSpeeds = {8, 16, 32}, -- 227
		cameraMin = 300, -- 228
		cameraMax = 5600, -- 228
		aimMin = 0.5, -- 228
		introCloseDist = 400, -- 228
		aimClockRate = 1, -- 228
		slowMoFloor = 8, -- 228
		probeVisualRadius = 2.2 -- 228
	} -- 228
} -- 228
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 233
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 233
		return ____exports.LEVEL_RUNTIME[index + 1] -- 234
	end -- 234
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 235
end -- 233
return ____exports -- 233
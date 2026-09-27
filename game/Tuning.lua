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
-- ⚠️ 这些数与 `Body.radius`（物理）**故意不相等**。曾经有一条硬约束
-- 「displayRadius 必须等于 radius」（"玩家靠肉眼判断会不会撞上，两个数不相等就是不公"），
-- 在真实尺度下**必须作废**：木星物理半径 0.0374，在 416 单位的轨道上看是亚像素。
-- 
-- 替代它的判据是「2D 到达圈画真实容差」（`Test/PlanViewTest` 守着）。
-- 
-- 取值口径：**让玩家在 3D 里能读出「我在被这颗行星掰弯」**，不是"还原真实比例"。
-- 太阳不放大 —— 用户要的就是「很远的地方一颗很亮的恒星」（见 `docs/L1 指示.excalidraw`）。
____exports.BODY_VISUAL_RADIUS = { -- 48
	sun = 1.6, -- 49
	venus = 0.03, -- 50
	earth = 0.025, -- 51
	moon = 0.012, -- 52
	jupiter = 2, -- 53
	saturn = 1.2, -- 54
	uranus = 0.5, -- 55
	neptune = 0.4 -- 56
} -- 56
--- 取某个天体的视觉半径；表里没有就退回真实半径（不会静默变成 0）。
function ____exports.visualRadius(key, trueRadius) -- 60
	local v = ____exports.BODY_VISUAL_RADIUS[key] -- 61
	return v ~= nil and v or trueRadius -- 62
end -- 60
--- 2D 图钉半径（**屏幕像素**，不随视野缩放）。
-- 
-- 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
____exports.PLAN_PIN_PX = {sun = 13, planet = 8, probe = 11} -- 74
--- 六关的运行时参数表。
-- 
-- 播放倍速的推导（每关都要能"看得见"）：
-- L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
____exports.LEVEL_RUNTIME = { -- 143
	{ -- 144
		physicsStep = 1 / 2000, -- 148
		maxStepsPerFrame = 16, -- 148
		sampleEvery = 1, -- 148
		playback = 0.25, -- 149
		playbackSpeeds = {0.1, 0.25, 0.5}, -- 149
		cameraMin = 0.02, -- 150
		cameraMax = 3, -- 150
		aimMin = 0.02, -- 150
		introCloseDist = 0.6, -- 150
		aimClockRate = 0 -- 151
	}, -- 151
	{ -- 153
		physicsStep = 1 / 240, -- 154
		maxStepsPerFrame = 8, -- 154
		sampleEvery = 1, -- 154
		playback = 2, -- 155
		playbackSpeeds = {1, 2, 4}, -- 155
		cameraMin = 20, -- 156
		cameraMax = 200, -- 156
		aimMin = 0.2, -- 156
		introCloseDist = 26, -- 156
		aimClockRate = 1 -- 156
	}, -- 156
	{ -- 158
		physicsStep = 1 / 240, -- 159
		maxStepsPerFrame = 16, -- 159
		sampleEvery = 4, -- 159
		playback = 4, -- 160
		playbackSpeeds = {2, 4, 8}, -- 160
		cameraMin = 60, -- 161
		cameraMax = 900, -- 161
		aimMin = 0.5, -- 161
		introCloseDist = 60, -- 161
		aimClockRate = 1 -- 161
	}, -- 161
	{ -- 163
		physicsStep = 1 / 240, -- 164
		maxStepsPerFrame = 16, -- 164
		sampleEvery = 8, -- 164
		playback = 8, -- 165
		playbackSpeeds = {4, 8, 16}, -- 165
		cameraMin = 100, -- 166
		cameraMax = 1800, -- 166
		aimMin = 0.5, -- 166
		introCloseDist = 120, -- 166
		aimClockRate = 1 -- 166
	}, -- 166
	{ -- 168
		physicsStep = 1 / 120, -- 169
		maxStepsPerFrame = 32, -- 169
		sampleEvery = 16, -- 169
		playback = 16, -- 170
		playbackSpeeds = {8, 16, 32}, -- 170
		cameraMin = 200, -- 171
		cameraMax = 3600, -- 171
		aimMin = 0.5, -- 171
		introCloseDist = 240, -- 171
		aimClockRate = 1 -- 171
	}, -- 171
	{ -- 173
		physicsStep = 1 / 120, -- 174
		maxStepsPerFrame = 32, -- 174
		sampleEvery = 16, -- 174
		playback = 16, -- 175
		playbackSpeeds = {8, 16, 32}, -- 175
		cameraMin = 300, -- 176
		cameraMax = 5600, -- 176
		aimMin = 0.5, -- 176
		introCloseDist = 400, -- 176
		aimClockRate = 1 -- 176
	} -- 176
} -- 176
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 181
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 181
		return ____exports.LEVEL_RUNTIME[index + 1] -- 182
	end -- 182
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 183
end -- 181
return ____exports -- 181
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
____exports.LEVEL_RUNTIME = { -- 123
	{ -- 124
		physicsStep = 1 / 2000, -- 125
		maxStepsPerFrame = 8, -- 125
		sampleEvery = 1, -- 125
		playback = 0.05, -- 126
		playbackSpeeds = {0.02, 0.05, 0.1}, -- 126
		cameraMin = 0.02, -- 127
		cameraMax = 3, -- 127
		aimMin = 0.02, -- 127
		introCloseDist = 0.6 -- 127
	}, -- 127
	{ -- 129
		physicsStep = 1 / 240, -- 130
		maxStepsPerFrame = 8, -- 130
		sampleEvery = 1, -- 130
		playback = 2, -- 131
		playbackSpeeds = {1, 2, 4}, -- 131
		cameraMin = 20, -- 132
		cameraMax = 200, -- 132
		aimMin = 0.2, -- 132
		introCloseDist = 26 -- 132
	}, -- 132
	{ -- 134
		physicsStep = 1 / 240, -- 135
		maxStepsPerFrame = 16, -- 135
		sampleEvery = 4, -- 135
		playback = 4, -- 136
		playbackSpeeds = {2, 4, 8}, -- 136
		cameraMin = 60, -- 137
		cameraMax = 900, -- 137
		aimMin = 0.5, -- 137
		introCloseDist = 60 -- 137
	}, -- 137
	{ -- 139
		physicsStep = 1 / 240, -- 140
		maxStepsPerFrame = 16, -- 140
		sampleEvery = 8, -- 140
		playback = 8, -- 141
		playbackSpeeds = {4, 8, 16}, -- 141
		cameraMin = 100, -- 142
		cameraMax = 1800, -- 142
		aimMin = 0.5, -- 142
		introCloseDist = 120 -- 142
	}, -- 142
	{ -- 144
		physicsStep = 1 / 120, -- 145
		maxStepsPerFrame = 32, -- 145
		sampleEvery = 16, -- 145
		playback = 16, -- 146
		playbackSpeeds = {8, 16, 32}, -- 146
		cameraMin = 200, -- 147
		cameraMax = 3600, -- 147
		aimMin = 0.5, -- 147
		introCloseDist = 240 -- 147
	}, -- 147
	{ -- 149
		physicsStep = 1 / 120, -- 150
		maxStepsPerFrame = 32, -- 150
		sampleEvery = 16, -- 150
		playback = 16, -- 151
		playbackSpeeds = {8, 16, 32}, -- 151
		cameraMin = 300, -- 152
		cameraMax = 5600, -- 152
		aimMin = 0.5, -- 152
		introCloseDist = 400 -- 152
	} -- 152
} -- 152
--- 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。
function ____exports.levelRuntime(index) -- 157
	if index >= 0 and index < #____exports.LEVEL_RUNTIME then -- 157
		return ____exports.LEVEL_RUNTIME[index + 1] -- 158
	end -- 158
	return ____exports.LEVEL_RUNTIME[#____exports.LEVEL_RUNTIME] -- 159
end -- 157
return ____exports -- 157
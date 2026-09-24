-- [ts]: Config.ts
local ____exports = {} -- 1
--- 设计分辨率（竖屏，1080×1920 = 9:16）。
____exports.DesignWidth = 1080 -- 9
____exports.DesignHeight = 1920 -- 10
--- 设计宽高比。
____exports.DesignAspect = ____exports.DesignWidth / ____exports.DesignHeight -- 13
--- 平面横向坐标 u 映射到世界 X 的系数。
____exports.PlaneToWorldX = 1 -- 28
--- 平面纵向坐标 v 映射到世界 Z 的系数。
____exports.PlaneToWorldZ = 1 -- 30
--- 固定物理步长（秒）。固定步长是"同一输入结果一致"的前提。
____exports.PhysicsStep = 1 / 120 -- 33
--- 单帧最多推进的物理步数，防止卡顿后跳帧。
____exports.MaxStepsPerFrame = 8 -- 36
--- 全局引力强度倍率，用于统一调整难度。
____exports.GravityScale = 1 -- 39
--- 行星公转速度倍率。必须让公转"肉眼可见"（决策 D1）。
____exports.OrbitSpeedScale = 1 -- 42
--- 预测轨迹的采样步数。
____exports.PredictSteps = 600 -- 45
--- 相机俯视倾角（度）。安全区间 20–60；超过 70 会贴边。
____exports.CameraTiltMin = 20 -- 52
____exports.CameraTiltMax = 60 -- 53
____exports.CameraTiltDefault = 45 -- 54
--- 相机距离的夹紧范围。竖屏下纵向轨道 dist ≥ 25 即可框住整条轨道。
____exports.CameraMinDistance = 25 -- 57
____exports.CameraMaxDistance = 100 -- 58
--- 相机跟随的平滑系数（0–1，每帧向目标插值的比例）。
____exports.CameraLerp = 0.1 -- 61
--- 发射速度下限（平面单位/秒）。极短拖动时的速度。
____exports.AimMinSpeed = 2 -- 68
--- 发射速度上限（平面单位/秒）。满力时的速度。
____exports.AimMaxSpeed = 22 -- 71
--- 拖动多远算“满力”（**视图像素**）。
____exports.AimMaxDragPx = 380 -- 74
--- 飞行回放速度（模拟秒 / 真实秒）。1 = 实时；2 = 两倍速。
____exports.FlightPlayback = 2 -- 77
return ____exports -- 77
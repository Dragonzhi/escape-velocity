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
--- 进关镜头（S3.9 用户："小框是关卡一开始，然后逐渐变换到大的框，告知玩家目标地"）：
-- 从贴着探测器（能看清它正在起飞）缓动到自动取景（能看见下一站）的时长与初始距离。
-- 玩家一拖就跳过（见 Game.onAimDrag）。
____exports.IntroDurationSec = 1.4 -- 37
____exports.IntroCloseDist = 26 -- 38
--- 关卡轨道圈的着色（S3.9）：用户要求"行星要动，所以要有轨道指示，不起眼的灰就行"。
-- 开场用的是 0x3f5f88（偏蓝、更亮），关卡里要更沉 —— 它是背景参考线，不是 UI。
____exports.OrbitRingTintHex = 3555405 -- 44
--- 固定物理步长（秒）。固定步长是"同一输入结果一致"的前提。
____exports.PhysicsStep = 1 / 120 -- 47
--- 单帧最多推进的物理步数，防止卡顿后跳帧。
____exports.MaxStepsPerFrame = 8 -- 50
--- 全局引力强度倍率，用于统一调整难度。
____exports.GravityScale = 1 -- 53
--- 行星公转速度倍率。必须让公转"肉眼可见"（决策 D1）。
____exports.OrbitSpeedScale = 1 -- 56
--- 预测轨迹的采样步数（S3.7：600 → 2400，覆盖整段飞行）。
-- 
-- 为什么能加这么多：`createGame` 现在**只在瞄准变化时重算**这条线，其余帧只重投影
-- （相机在 lerp，投影每帧都得更新）。2400 步 × 4~5 个天体的代价只付在拖动那几帧上。
____exports.PredictSteps = 2400 -- 64
--- 相机俯视倾角（度）。安全区间 20–60；超过 70 会贴边。
____exports.CameraTiltMin = 20 -- 71
____exports.CameraTiltMax = 60 -- 72
____exports.CameraTiltDefault = 45 -- 73
--- 相机距离的夹紧范围。竖屏下纵向轨道 dist ≥ 25 即可框住整条轨道。
-- 
-- S3.7：关卡尺度 ×2.5（轨道半径 55–195）⇒ 取景范围同步放大到 60–260，
-- 否则远端的行星会被夹在画面外（"拉不开、没有宇宙感"的根因之一）。
____exports.CameraMinDistance = 60 -- 81
____exports.CameraMaxDistance = 420 -- 82
--- 相机跟随的平滑系数（0–1，每帧向目标插值的比例）。
____exports.CameraLerp = 0.1 -- 85
--- 发射速度下限（平面单位/秒）。极短拖动时的速度。
-- 
-- S3.7 关卡重构：世界尺度 ×2.5（见 PLAN S3.7）⇒ 速度同步 ×2.5，轨迹形状与飞行时间不变。
____exports.AimMinSpeed = 5 -- 96
--- 发射速度上限（平面单位/秒）。满力时的速度。
____exports.AimMaxSpeed = 55 -- 99
--- 每关的 Δv 预算缺省值（没写 `LevelDef.dvBudget` 的关卡用它）。
-- 
-- 用户 2026-09-26 的要求："需要一个 delta-v 之类的东西限制玩家可以施加给飞行器的力度，
-- 避免力大砖飞、完全不顾及引力弹弓"。有效上限 = `min(AimMaxSpeed, dvBudget)`。
____exports.DvBudgetDefault = 55 -- 107
--- 拖动多远算“满力”（**视图像素**）。
____exports.AimMaxDragPx = 380 -- 110
--- 飞行回放速度（模拟秒 / 真实秒）。1 = 实时；2 = 两倍速。
____exports.FlightPlayback = 2 -- 113
return ____exports -- 113
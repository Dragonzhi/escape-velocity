-- [ts]: OrbitFlow.ts
local ____exports = {} -- 1
local ____Gravity = require("game.Gravity") -- 25
local bodyPositionAt = ____Gravity.bodyPositionAt -- 25
--- 每条轨道上的光点个数（2D 与 3D 共用）。
-- 
-- 6 个 = 每 60° 一个：既像"一串灯"（能看出流向），又不至于密成一条实线。
-- 节点池按这个数**一次性建好**，之后每帧只改位置（AGENTS：不要每帧重建节点）。
____exports.FlowDotsPerOrbit = 6 -- 33
--- 天体在时刻 t 的轨道角（弧度）。
-- 
-- ⚠️ 必须与 `Gravity.bodyPositionAt` 逐字一致（同一个 `phase0 + direction·2π·t/period`）——
-- 那是全仓库唯一的行星位置公式；这里复制它是为了让光点与行星**共用同一个角**，
-- 而不是为了发明第二种算法。单测用 `bodyPositionAt` 反守着这条等式。
function ____exports.orbitAngleAt(b, t) -- 42
	local angle = b.phase0 -- 43
	if b.orbitPeriod ~= 0 then -- 43
		angle = angle + b.orbitDirection * 2 * math.pi * (t / b.orbitPeriod) -- 45
	end -- 45
	return angle -- 47
end -- 42
--- 轨道角速度（弧度/秒）。**符号带方向**：> 0 = 逆时针（数学正向 / 顺行），< 0 = 顺时针（逆行）。
-- 
-- 光点的"快慢"就是这个量的绝对值：内圈周期短 ⇒ |ω| 大 ⇒ 光点跑得快。
-- `orbitPeriod === 0`（静止天体，如第 2 关那种）返回 0 —— 没有可流动的轨道。
function ____exports.orbitAngularRate(b) -- 56
	if b.orbitPeriod == 0 then -- 56
		return 0 -- 57
	end -- 57
	return b.orbitDirection * 2 * math.pi / b.orbitPeriod -- 58
end -- 56
--- 第 k 个光点的轨道角（`count` 个光点均匀分布）。
-- 
-- `k` 允许越界/负数（取模归一到 [0, count)）——调用方传节点池下标时不必自己夹。
function ____exports.flowDotAngle(b, t, k, count) -- 66
	local n = count > 0 and count or 1 -- 67
	local idx = k % n -- 68
	if idx < 0 then -- 68
		idx = idx + n -- 69
	end -- 69
	return ____exports.orbitAngleAt(b, t) + idx * 2 * math.pi / n -- 70
end -- 66
--- 轨道**圆心**在时刻 t 的位置（平面坐标）。
-- 
-- 卫星（月球绕地球）的圆心是**会动的宿主** —— 与 `bodyPositionAt` 里取圆心的方式一致。
function ____exports.orbitCenterAt(b, t) -- 78
	return b.host ~= nil and bodyPositionAt(b.host, t) or b.orbitCenter -- 79
end -- 78
--- 第 k 个光点的**平面位置**。
-- 
-- 2D 规划视图直接用它换投影；3D 场景用 `orbitCenterAt` + `orbitAngleAt` 现场算
-- （省掉每帧 36 个小对象的分配，见 Scene.syncBodies）。
function ____exports.flowDotPosition(b, t, k, count) -- 88
	local c = ____exports.orbitCenterAt(b, t) -- 89
	local a = ____exports.flowDotAngle(b, t, k, count) -- 90
	local r = b.orbitRadius -- 91
	return { -- 92
		x = c.x + r * math.cos(a), -- 92
		y = c.y + r * math.sin(a) -- 92
	} -- 92
end -- 88
return ____exports -- 88
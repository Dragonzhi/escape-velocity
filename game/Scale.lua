-- [ts]: Scale.ts
local ____exports = {} -- 1
--- 1 AU 折算成多少个平面单位（长度尺度锚点）。
____exports.UnitsPerAu = 80 -- 40
--- 1 AU 的真实长度（km，IAU 2012 定义值）。
local AuKm = 149597870.7 -- 43
--- 太阳的真实引力常数 gm（km³/s²，IAU 2015 决议值）。
____exports.SunGmReal = 132712440018 -- 46
--- 地球轨道的圆轨速度在游戏里定为 30 单位/秒（速度尺度锚点，决定整体节奏）。
____exports.EarthOrbitSpeed = 30 -- 49
--- 长度尺度：真实 km / 平面单位。
____exports.KmPerUnit = AuKm / ____exports.UnitsPerAu -- 52
--- 1 AU 处的真实圆轨速度（km/s）。
-- 
-- 由真实 gm 与真实距离**算出**，不查表 —— 这样改 `SunGmReal` 时速度尺度会跟着自洽。
____exports.RealSpeedAtAu = math.sqrt(____exports.SunGmReal / AuKm) -- 59
--- 速度尺度：真实 km/s 每 (平面单位/游戏秒)。
____exports.KmPerSecPerUnit = ____exports.RealSpeedAtAu / ____exports.EarthOrbitSpeed -- 62
--- 时间尺度：1 游戏秒 = 多少真实秒（≈ 21.8 天）。
____exports.SecPerGameSec = ____exports.KmPerUnit / ____exports.KmPerSecPerUnit -- 65
--- 引力尺度因子：`gm_game = gm_real × GmFactor`。
-- 
-- 量纲换算：距离 ×L、时间 ×τ ⇒ gm 的单位（km³/s² → 单位³/游戏秒²）要乘 `τ²/L³`。
____exports.GmFactor = ____exports.SecPerGameSec * ____exports.SecPerGameSec / (____exports.KmPerUnit * ____exports.KmPerUnit * ____exports.KmPerUnit) -- 72
--- 真实半径 / 直径（km）→ 平面单位。
function ____exports.trueRadius(km) -- 79
	return km / ____exports.KmPerUnit -- 80
end -- 79
--- 真实 gm（km³/s²）→ 平面单位下的 gm。
function ____exports.trueGm(km3s2) -- 84
	return km3s2 * ____exports.GmFactor -- 85
end -- 84
--- 真实轨道半长轴（AU）→ 平面单位。
function ____exports.trueOrbit(au) -- 89
	return au * ____exports.UnitsPerAu -- 90
end -- 89
--- 开普勒第三定律：周期（游戏秒）。
-- 
-- `a` 是平面单位、`mu` 是同一套单位下的 gm。**这就是 KeplerK 的替代品**：
-- 周期不再是手设的 `r^1.5`，而是由天体自己的引力算出来的。
function ____exports.period(a, mu) -- 99
	if a <= 0 or mu <= 0 then -- 99
		return 0 -- 100
	end -- 100
	return 2 * math.pi * math.sqrt(a * a * a / mu) -- 101
end -- 99
--- 圆轨速度（平面单位/游戏秒）。
function ____exports.circularSpeed(mu, r) -- 105
	if r <= 0 or mu <= 0 then -- 105
		return 0 -- 106
	end -- 106
	return math.sqrt(mu / r) -- 107
end -- 105
--- 逃逸速度 = √2 × 圆轨速度（写死常量：tstl 对 Math.SQRT2 的支持面比 Math.sqrt 窄）。
function ____exports.escapeSpeed(mu, r) -- 111
	return ____exports.circularSpeed(mu, r) * 1.4142135623730951 -- 112
end -- 111
--- 希尔球半径：宿主天体靠引力能拢住的卫星最大轨道半径（近似）。
-- 
-- `r_H = a_host · (m_host / 3M_sun)^(1/3)`。用来判断"某条绕行星的轨道在物理上说不说得通"
-- —— L1 的探测器轨道 0.1 对地球希尔球 0.80，占比 0.125，安全。
function ____exports.hillRadius(hostOrbit, hostGm, sunGm) -- 121
	if hostGm <= 0 or sunGm <= 0 or hostOrbit <= 0 then -- 121
		return 0 -- 122
	end -- 122
	return hostOrbit * (hostGm / (3 * sunGm)) ^ (1 / 3) -- 123
end -- 121
--- 真实数据表（NASA/JPL 行星事实表与 IAU 决议值）。
____exports.REAL = { -- 141
	sun = {au = 0, radiusKm = 695700, gm = ____exports.SunGmReal}, -- 142
	mercury = {au = 0.38709893, radiusKm = 2439.7, gm = 22032}, -- 143
	venus = {au = 0.72333199, radiusKm = 6051.8, gm = 324859}, -- 144
	earth = {au = 1.00000011, radiusKm = 6371, gm = 398600.4418}, -- 145
	moon = {au = 0, radiusKm = 1737.4, gm = 4902.8}, -- 146
	jupiter = {au = 5.202887, radiusKm = 69911, gm = 126686534}, -- 147
	saturn = {au = 9.53667594, radiusKm = 58232, gm = 37931187}, -- 148
	uranus = {au = 19.18916464, radiusKm = 25362, gm = 5793939}, -- 149
	neptune = {au = 30.06992276, radiusKm = 24622, gm = 6836529} -- 150
} -- 150
--- 月球绕地球的半长轴（真实 km = 384400）⇒ 平面单位由 `trueRadius` 换算。
____exports.MoonOrbitKm = 384400 -- 154
--- 太阳的 gm（平面单位）—— 等于 72000.0，与归正前手填的值一致（见文件头自检）。
____exports.SunGm = ____exports.trueGm(____exports.REAL.sun.gm) -- 161
--- 太阳的**物理**半径（平面单位，≈ 0.372）。撞毁判定用它，视觉半径另见 Tuning。
____exports.SunRadius = ____exports.trueRadius(____exports.REAL.sun.radiusKm) -- 164
--- 地球的 gm 与物理半径（平面单位）。
____exports.EarthGm = ____exports.trueGm(____exports.REAL.earth.gm) -- 167
____exports.EarthRadius = ____exports.trueRadius(____exports.REAL.earth.radiusKm) -- 168
--- 月球的 gm、物理半径、以及绕地轨道半径（平面单位）。
____exports.MoonGm = ____exports.trueGm(____exports.REAL.moon.gm) -- 171
____exports.MoonRadius = ____exports.trueRadius(____exports.REAL.moon.radiusKm) -- 172
____exports.MoonOrbitRadius = ____exports.trueRadius(____exports.MoonOrbitKm) -- 173
return ____exports -- 173
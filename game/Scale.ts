/**
 * 物理尺度（S5 归正）—— **全项目唯一的物理真值来源**。
 *
 * ===== 这个模块解决什么问题 =====
 *
 * 归正前 `game/LevelData.ts` 里 `SunGm = 72000` 与 `KeplerK = 1.0` **互相矛盾**：
 * 前者要求行星周期 `2π·sqrt(r³/gm)`（地球 16.76 秒），后者却让行星走 `r^1.5`（地球 715 秒），
 * **差 42.7 倍**。于是行星是被一条手设公式推着走的，探测器飞的是真引力 —— 两者永远对不上：
 * L1 探测器默认坠日、引力弹弓收益只有 ~4%、行星相位必须靠工具硬解、「探测器绕地球」动力学上不成立。
 *
 * ===== 归正口径：两个锚点，其余全部导出 =====
 *
 * | 锚点 | 值 | 导出 |
 * |---|---|---|
 * | 1 AU = 80 平面单位 | 长度尺度 | `KmPerUnit = 1.496e8/80 = 1.86997e6 km/单位` |
 * | 地球轨道圆轨速度 = 30 单位/秒 | 速度尺度 | `SecPerGameSec = 1.8835e6 真实秒/游戏秒` |
 *
 * 由此 `GmFactor = τ²/L³ = 5.425264e-7`、`gm_game = gm_real × GmFactor`、`R_game = R_real / L`、
 * 周期一律 `T = 2π·sqrt(a³/μ)`（**删除 KeplerK**）。
 *
 * **自检（单测守着）**：
 * - 太阳 `trueGm(1.32712440018e11) = 72000.0` —— 归正前手填的 72000 本来就是对的，错的只有 KeplerK；
 * - 地球周期 16.755 秒、金星 10.308 秒、木星 198.845 秒；
 * - 月球周期 1.2593 秒 ⇒ 每个地球年绕地 13.31 圈（真实 13.37）。
 *
 * ===== 与 Tuning.ts 的分工（用户 2026-09-27 明确要求）=====
 *
 * - **本模块只放推导与真实天文数据**，一个可调值都不放；
 * - 「想调就调」的那些（视觉半径、每关 Δv/容差/播放速度）全在 `game/Tuning.ts`；
 * - `Body.radius` / `Body.gm` **只放物理真值**，必须由本模块算出，禁止手填。
 *
 * 纯函数、零引擎依赖，可单测。
 */

// ---------------------------------------------------------------------------
// 尺度常量（由真实天文数据导出，不要手改）
// ---------------------------------------------------------------------------

/** 1 AU 折算成多少个平面单位（长度尺度锚点）。 */
export const UnitsPerAu = 80;

/** 1 AU 的真实长度（km，IAU 2012 定义值）。 */
const AuKm = 1.495978707e8;

/** 太阳的真实引力常数 gm（km³/s²，IAU 2015 决议值）。 */
export const SunGmReal = 1.32712440018e11;

/** 地球轨道的圆轨速度在游戏里定为 30 单位/秒（速度尺度锚点，决定整体节奏）。 */
export const EarthOrbitSpeed = 30;

/** 长度尺度：真实 km / 平面单位。 */
export const KmPerUnit = AuKm / UnitsPerAu;

/**
 * 1 AU 处的真实圆轨速度（km/s）。
 *
 * 由真实 gm 与真实距离**算出**，不查表 —— 这样改 `SunGmReal` 时速度尺度会跟着自洽。
 */
export const RealSpeedAtAu = Math.sqrt(SunGmReal / AuKm);

/** 速度尺度：真实 km/s 每 (平面单位/游戏秒)。 */
export const KmPerSecPerUnit = RealSpeedAtAu / EarthOrbitSpeed;

/** 时间尺度：1 游戏秒 = 多少真实秒（≈ 21.8 天）。 */
export const SecPerGameSec = KmPerUnit / KmPerSecPerUnit;

/**
 * 引力尺度因子：`gm_game = gm_real × GmFactor`。
 *
 * 量纲换算：距离 ×L、时间 ×τ ⇒ gm 的单位（km³/s² → 单位³/游戏秒²）要乘 `τ²/L³`。
 */
export const GmFactor = (SecPerGameSec * SecPerGameSec) / (KmPerUnit * KmPerUnit * KmPerUnit);

// ---------------------------------------------------------------------------
// 换算函数
// ---------------------------------------------------------------------------

/** 真实半径 / 直径（km）→ 平面单位。 */
export function trueRadius(km: number): number {
	return km / KmPerUnit;
}

/** 真实 gm（km³/s²）→ 平面单位下的 gm。 */
export function trueGm(km3s2: number): number {
	return km3s2 * GmFactor;
}

/** 真实轨道半长轴（AU）→ 平面单位。 */
export function trueOrbit(au: number): number {
	return au * UnitsPerAu;
}

/**
 * 开普勒第三定律：周期（游戏秒）。
 *
 * `a` 是平面单位、`mu` 是同一套单位下的 gm。**这就是 KeplerK 的替代品**：
 * 周期不再是手设的 `r^1.5`，而是由天体自己的引力算出来的。
 */
export function period(a: number, mu: number): number {
	if (a <= 0 || mu <= 0) return 0;
	return 2 * Math.PI * Math.sqrt((a * a * a) / mu);
}

/** 圆轨速度（平面单位/游戏秒）。 */
export function circularSpeed(mu: number, r: number): number {
	if (r <= 0 || mu <= 0) return 0;
	return Math.sqrt(mu / r);
}

/** 逃逸速度 = √2 × 圆轨速度（写死常量：tstl 对 Math.SQRT2 的支持面比 Math.sqrt 窄）。 */
export function escapeSpeed(mu: number, r: number): number {
	return circularSpeed(mu, r) * 1.4142135623730951;
}

/**
 * 希尔球半径：宿主天体靠引力能拢住的卫星最大轨道半径（近似）。
 *
 * `r_H = a_host · (m_host / 3M_sun)^(1/3)`。用来判断"某条绕行星的轨道在物理上说不说得通"
 * —— L1 的探测器轨道 0.1 对地球希尔球 0.80，占比 0.125，安全。
 */
export function hillRadius(hostOrbit: number, hostGm: number, sunGm: number): number {
	if (hostGm <= 0 || sunGm <= 0 || hostOrbit <= 0) return 0;
	return hostOrbit * Math.pow(hostGm / (3 * sunGm), 1 / 3);
}

// ---------------------------------------------------------------------------
// 真实天文数据（事实，不是调参）
// ---------------------------------------------------------------------------

/** 一颗真实天体的数据。 */
export interface RealBody {
	/** 半长轴（AU）；绕宿主的卫星填 0，改用 `MoonOrbitAu`。 */
	au: number;
	/** 平均半径（km）。 */
	radiusKm: number;
	/** 引力常数（km³/s²）。 */
	gm: number;
}

/** 真实数据表（NASA/JPL 行星事实表与 IAU 决议值）。 */
export const REAL: { [key: string]: RealBody } = {
	sun: { au: 0, radiusKm: 695700, gm: SunGmReal },
	mercury: { au: 0.38709893, radiusKm: 2439.7, gm: 2.2032e4 },
	venus: { au: 0.72333199, radiusKm: 6051.8, gm: 3.24859e5 },
	earth: { au: 1.00000011, radiusKm: 6371.0, gm: 3.986004418e5 },
	moon: { au: 0, radiusKm: 1737.4, gm: 4.9028e3 },
	jupiter: { au: 5.202887, radiusKm: 69911, gm: 1.26686534e8 },
	saturn: { au: 9.53667594, radiusKm: 58232, gm: 3.7931187e7 },
	uranus: { au: 19.18916464, radiusKm: 25362, gm: 5.793939e6 },
	neptune: { au: 30.06992276, radiusKm: 24622, gm: 6.836529e6 },
};

/** 月球绕地球的半长轴（真实 km = 384400）⇒ 平面单位由 `trueRadius` 换算。 */
export const MoonOrbitKm = 384400;

// ---------------------------------------------------------------------------
// 派生值（六关共用，供 LevelData / Tuning / 工具读取）
// ---------------------------------------------------------------------------

/** 太阳的 gm（平面单位）—— 等于 72000.0，与归正前手填的值一致（见文件头自检）。 */
export const SunGm = trueGm(REAL.sun.gm);

/** 太阳的**物理**半径（平面单位，≈ 0.372）。撞毁判定用它，视觉半径另见 Tuning。 */
export const SunRadius = trueRadius(REAL.sun.radiusKm);

/** 地球的 gm 与物理半径（平面单位）。 */
export const EarthGm = trueGm(REAL.earth.gm);
export const EarthRadius = trueRadius(REAL.earth.radiusKm);

/** 月球的 gm、物理半径、以及绕地轨道半径（平面单位）。 */
export const MoonGm = trueGm(REAL.moon.gm);
export const MoonRadius = trueRadius(REAL.moon.radiusKm);
export const MoonOrbitRadius = trueRadius(MoonOrbitKm);

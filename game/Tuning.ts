/**
 * 可调参数唯一入口（S5 归正）—— **所有「想调就调」的值都放这里**。
 *
 * ===== 为什么要有这个文件（用户 2026-09-27 明确要求）=====
 *
 * 原话：「视觉半径和实际影响物理的部分分开来，且要有一个配置文件方便的进行修改，这样子方便之后的调参。」
 *
 * 于是全项目分成三层，**改数值之前先搞清楚自己在改哪一层**：
 *
 * | 层 | 文件 | 放什么 | 谁能读 |
 * |---|---|---|---|
 * | 物理真值 | `game/Scale.ts` | 真实天文数据 → 换算后的半径/gm/周期 | 只被 `LevelData` 读 |
 * | **可调参数** | **本文件** | 视觉半径、图钉像素、每关步长/播放/相机/Δv | Scene / PlanView / Game / Hud / init |
 * | 关卡设计 | `game/LevelData.ts` | 航线、天体、容差、简报 | 大家 |
 *
 * ⚠️ 三条纪律：
 * 1. `Body.radius` / `Body.gm` **只能**由 `Scale` 算出，**禁止手填**；
 * 2. 本文件里的 `BODY_VISUAL_RADIUS` **只影响看得见的大小**，一律不参与碰撞、到达、捕获判定；
 * 3. 玩家判断「够不够得着」的唯一依据是 **2D 视图里画在真实容差上的到达圈**（见 PlanView），
 *    不是天体的视觉大小 —— 视觉放大之后这两者必然不等，这是分层的固有代价。
 */

// ---------------------------------------------------------------------------
// 视觉半径（只影响 3D 模型缩放与 2D 图钉，不参与任何物理判定）
// ---------------------------------------------------------------------------

/**
 * 探测器的视觉半径。
 *
 * 真实尺寸（几米）在 1.87e6 km/单位 的尺度下是 1e-9 量级，等于不可见。
 * 0.0015 是**可见性下限**（用户 2026-09-27 拍板「探测器视觉半径 0.0015 现在也行」），
 * 比真实值大约 13 个数量级 —— 这是这一层存在的全部理由。
 */
export const PROBE_VISUAL_RADIUS = 0.0015;

/**
 * 各天体的视觉半径（世界单位）。
 *
 * ⚠️ 这些数与 `Body.radius`（物理）**故意不相等**。曾经有一条硬约束
 * 「displayRadius 必须等于 radius」（"玩家靠肉眼判断会不会撞上，两个数不相等就是不公"），
 * 在真实尺度下**必须作废**：木星物理半径 0.0374，在 416 单位的轨道上看是亚像素。
 *
 * 替代它的判据是「2D 到达圈画真实容差」（`Test/PlanViewTest` 守着）。
 *
 * 取值口径：**让玩家在 3D 里能读出「我在被这颗行星掰弯」**，不是"还原真实比例"。
 * 太阳不放大 —— 用户要的就是「很远的地方一颗很亮的恒星」（见 `docs/L1 指示.excalidraw`）。
 */
/**
 * 各天体的视觉半径（世界单位）。
 *
 * ⚠️ 单一份表服务六关，但 **L1 的尺度与别处差 130 倍**（别处看 80~2400 单位的日心系，
 * L1 看 0.6 单位宽的地月系）。同一个 0.025 在 L2–L6 是合理的点，在 L1 只占世界宽度的 4%，
 * 3D 里几乎看不见（用户实测「3D 状态下完全看不到地球」）。
 *
 * ⇒ L1 的地月系用**专用值**：地球 0.06（世界宽度的 10%）、月球 0.02。
 * 取值只影响看得见的大小，**不参与任何物理判定**。
 */
const BODY_VISUAL_L1: { [key: string]: number } = {
	sun: 0.8,       // 在 L1 里太阳远在 80 单位外，给它一个"亮星"的尺寸就够
	// 地球 0.03 / 月球 0.012：真实比例里月球轨 = 10 个地球半径，把地球放到 0.06
	// 会让它占满画面、月球被挤成边角料（实测截图）。0.03 ≈ 月球轨的 15%，
	// 三个天体（地球 / 月球 / 探测器）能同框且都看得清。
	earth: 0.03,
	moon: 0.012,
	probe: 0.0015,
};

export const BODY_VISUAL_RADIUS: { [key: string]: number } = {
	sun: 1.6,
	venus: 0.03,
	earth: 0.025,
	moon: 0.012,
	jupiter: 2.0,
	saturn: 1.2,
	uranus: 0.5,
	neptune: 0.4,
};

/**
 * 取某个天体的视觉半径。
 *
 * @param levelIndex 关卡下标（0 = L1）：L1 用地月系专用表，别处用日心系表。
 * @param key 天体键（'earth' / 'moon' / ...）
 * @param trueRadius 真实半径（查不到时的兜底，不会静默变成 0）
 */
export function visualRadius(key: string, trueRadius: number, levelIndex?: number): number {
	const table = levelIndex === 0 ? BODY_VISUAL_L1 : BODY_VISUAL_RADIUS;
	const v = table[key];
	return v !== undefined ? v : trueRadius;
}

// ---------------------------------------------------------------------------
// 2D 规划视图（"东西在哪里"的唯一真相层）
// ---------------------------------------------------------------------------

/**
 * 2D 图钉半径（**屏幕像素**，不随视野缩放）。
 *
 * 天体在 3D 里是点没关系，2D 必须让玩家一眼看到它在哪 —— 这正是分开 3D/2D 的原因。
 */
export const PLAN_PIN_PX = { sun: 13, planet: 8, probe: 11 };

// ---------------------------------------------------------------------------
// 每关运行时参数
// ---------------------------------------------------------------------------

/** 一关的运行时参数。改这里不影响别的关。 */
export interface LevelRuntime {
	/**
	 * 物理步长（秒）。
	 *
	 * ⚠️ 这个值**必须按关卡给**，不能全局一个：L1 的探测器日心速度 30 单位/秒，
	 * 而它绕地球的整条轨道半径只有 0.1 单位 —— 一步 1/120 走 0.25 单位，
	 * **比整条轨道还大**。实测（2026-09-27）：同样初速下 dt=1/120 给出 r ∈ [0.139, 0.361]，
	 * dt=1/5000 才收敛到 [0.084, 0.116]。所以 L1 用 1/2000。
	 *
	 * 外圈关卡反过来：步长太细会烧掉整帧预算（L6 飞行 513 秒），1/120 足够
	 * （掠过容差 5 单位，一步只走 0.25）。
	 */
	physicsStep: number;
	/** 每帧最多推进多少个物理步（决定倍速上限：steps/帧 = 播放倍速 / (60 × physicsStep)）。 */
	maxStepsPerFrame: number;
	/**
	 * 采样间隔（每 N 个物理步存一个采样点）。
	 *
	 * 同时决定三件事：内存（L6 若 N=1 要存 6 万个点）、判定分辨率、预测线点数。
	 * 判据：N × physicsStep × 探测器速度 **远小于** 到达容差。
	 */
	sampleEvery: number;
	/** 飞行回放的默认倍速。 */
	playback: number;
	/** 三颗倍速按钮的档位（HUD 上是 3 颗）。 */
	playbackSpeeds: number[];
	/** 相机距离下限（世界单位）。 */
	cameraMin: number;
	/** 相机距离上限（世界单位）。 */
	cameraMax: number;
	/** 瞄准力度下限（= 最小点火 Δv）。 */
	aimMin: number;
	/** 进关特写镜头的距离（世界单位）。 */
	introCloseDist: number;
	/**
	 * **瞄准期的世界时钟速率**（S5）。
	 *
	 * 瞄准期（Aiming 且没在拖）世界时钟在走，所以探测器沿待机轨道飞、行星也在走 ——
	 * 这个手感本身是好的（用户：「飞行器也是一开始在运动的，围绕地球」）。
	 * 但真实尺度下 L1 的绕地周期只有 **0.427 秒**、月球 1.259 秒：
	 * 1× 就是每秒转 2.3 圈的**陀螺**，玩家连"月球现在在哪"都看不清，更别说打提前量。
	 *
	 * ⇒ 每关一个速率。1 = 真实速度；**0 = 冻结**。
	 *
	 * L1 取 **0（冻结）**：它是教学关，开局状态必须完全确定 —— 探测器在地球外侧 0.1 的圆轨上、
	 * 月球在 154.7°。真实速率下探测器 0.43 秒转一圈、月球 1.26 秒转一圈，
	 * 玩家要同时给"自己的相位 + 月球的位置 + 0.40 秒飞行里的提前量"三者打提前量，
	 * 而屏幕上没有任何读数能支撑这件事。冻结之后这一关的时机只剩**飞行时间的提前量**
	 * （月球在 0.40 秒里走 115°）—— 正是简报里那句「别对着它现在的位置点火」。
	 * 探测器"已经在运动"这件事仍然成立：它由 probeVel0 与预测线那条弧线表达。
	 * ⚠️ 它只缩放**瞄准期**的时间流逝，不碰物理：发射瞬间把 clock 交给 t0，
	 *    此后一切照旧按真实时间算。
	 */
	aimClockRate: number;
	/**
	 * **探测器的视觉半径**（世界单位，S5.1）。
	 *
	 * 它同时决定两件事，所以必须按关卡给：
	 *   ① 3D 模型的 scale（Scene.createProbe 的 opts.scale）；
	 *   ② 相机取景用的 probeRadius（createProbe 的 radius = bodyRadius × scale × 1.1）。
	 * 之前 probeScale 是写死的 2.2（旧尺度），S5 之后 L1 的世界只有 0.6 单位宽 ——
	 * 2.2 的探测器比月球轨道还大，相机要么把它顶满屏幕、要么被它拽着跑
	 * （用户实测：「发射后视角距离探测器太近了，整个屏幕被探测器占满」）。
	 *
	 * L1 取 0.0015（用户 2026-09-27 拍板的可见性下限）；L2–L6 沿用旧的 2.2 ——
	 * 那几关的世界尺度是 80~2400 单位，等它们的验收轮次再统一归一。
	 */
	probeVisualRadius: number;
	/**
	 * 慢动作触发阈值的**地板**（世界单位，S5）。
	 *
	 * 必须按关卡给：全局的 8 是给"木星 23.2 / 月球 8"那一版尺度调的，而 L1 的世界只有
	 * **0.6 单位宽** —— 用 8 会让探测器全程都在慢动作特写里（用户实测「发射后视角距探测器太近、
	 * 整个屏幕被探测器占满」）。L1 取 0.05（= 月球轨 0.2056 的 1/4）：只有真正接近月球才特写。
	 */
	slowMoFloor: number;
}

/**
 * 六关的运行时参数表。
 *
 * 播放倍速的推导（每关都要能"看得见"）：
 * L1 转移飞行 0.40 游戏秒 ⇒ 0.05× 播放 = 8 真实秒；L6 飞行 513 秒 ⇒ 16× = 32 真实秒。
 */
export const LEVEL_RUNTIME: LevelRuntime[] = [
	{ // L1 月球：地月系，整个世界只有 0.6 单位宽
		// 播放倍速：转移飞行 0.40~0.62 秒游戏时间、整段上限 1.2 秒。
		// ⚠️ 不能取太小：0.05× 会让一段飞行要 40 秒挂钟时间（实测验收脚本 6 秒就等不下去把它腰斩了）。
		// 0.25× ⇒ 命中约 2 秒、整段最多 4.8 秒，"看得见"与"不拖沓"的平衡点。
		// cameraMax 3 → 0.9：3 会让"装下整个地月系"的解偏大、地球缩得太小；
		// 0.9 刚好覆盖月球轨 0.2056 + 容差 0.02 再加余量，地球在画面里是主体。
		physicsStep: 1 / 2000, maxStepsPerFrame: 16, sampleEvery: 1,
		playback: 0.25, playbackSpeeds: [0.1, 0.25, 0.5],
		cameraMin: 0.02, cameraMax: 1.2, aimMin: 0.02, introCloseDist: 0.6,
		aimClockRate: 0, slowMoFloor: 0.05, probeVisualRadius: 0.0015,
	},
	{ // L2 金星：飞行 6.7 秒
		physicsStep: 1 / 240, maxStepsPerFrame: 8, sampleEvery: 1,
		playback: 2, playbackSpeeds: [1, 2, 4],
		cameraMin: 20, cameraMax: 200, aimMin: 0.2, introCloseDist: 26, aimClockRate: 1, slowMoFloor: 8, probeVisualRadius: 2.2,
	},
	{ // L3 木星：飞行 45.8 秒
		physicsStep: 1 / 240, maxStepsPerFrame: 16, sampleEvery: 4,
		playback: 4, playbackSpeeds: [2, 4, 8],
		cameraMin: 60, cameraMax: 900, aimMin: 0.5, introCloseDist: 60, aimClockRate: 1, slowMoFloor: 8, probeVisualRadius: 2.2,
	},
	{ // L4 土星：飞行 ~101 秒
		physicsStep: 1 / 240, maxStepsPerFrame: 16, sampleEvery: 8,
		playback: 8, playbackSpeeds: [4, 8, 16],
		cameraMin: 100, cameraMax: 1800, aimMin: 0.5, introCloseDist: 120, aimClockRate: 1, slowMoFloor: 8, probeVisualRadius: 2.2,
	},
	{ // L5 天王星：飞行 ~269 秒
		physicsStep: 1 / 120, maxStepsPerFrame: 32, sampleEvery: 16,
		playback: 16, playbackSpeeds: [8, 16, 32],
		cameraMin: 200, cameraMax: 3600, aimMin: 0.5, introCloseDist: 240, aimClockRate: 1, slowMoFloor: 8, probeVisualRadius: 2.2,
	},
	{ // L6 海王星：飞行 ~513 秒
		physicsStep: 1 / 120, maxStepsPerFrame: 32, sampleEvery: 16,
		playback: 16, playbackSpeeds: [8, 16, 32],
		cameraMin: 300, cameraMax: 5600, aimMin: 0.5, introCloseDist: 400, aimClockRate: 1, slowMoFloor: 8, probeVisualRadius: 2.2,
	},
];

/** 取第 index 关（0 起）的运行时参数；越界退回最后一关（宁可难看，也不要 nil）。 */
export function levelRuntime(index: number): LevelRuntime {
	if (index >= 0 && index < LEVEL_RUNTIME.length) return LEVEL_RUNTIME[index];
	return LEVEL_RUNTIME[LEVEL_RUNTIME.length - 1];
}

/**
 * 关卡数据（S2.1 建立；S3.6.1 六章重排；**S3.7 宏大尺度 + 太阳主导**）。
 *
 * ===== S3.7 的三个决定（用户 2026-09-26 拍板）=====
 *
 * 1. **太阳进物理**：除 L1（"地球附近，先学会瞄准"）外，每关原点都是一颗有引力的太阳
 *    (`SunGm`)。行星改成**绕太阳同向公转**（`orbitCenter = (0,0)`）—— 于是探测器飞的是
 *    **绕日弧线**：向内飞被加速、向外飞被减速，掠过行星是**改向**。这是"宇宙感"的来源。
 * 2. **尺度 ×2.5**：轨道半径 55 / 80 / 105 / 135 / 165 / 195（"压缩太阳系"：**顺序与开普勒
 *    比例真实、绝对半径压缩**），行星半径 ×1.3，发射速度 5–55，相机夹紧 60–260。
 *    距离 ×S / 速度 ×S / gm ×S² 之下轨迹形状与飞行时间都不变（S = 2.5）。
 * 3. **开普勒 + 时间压缩**：`T = KeplerK · r^1.5`（`KeplerK = 1` 秒 ⇒ 相当于把真实速率除以 42.7）。
 *    飞行 15 秒里金星挪 ~13°、木星 ~5°、海王星 ~2°：**看得见但不乱**；想让行星动就拖**日期滑杆**
 *    （`timeWindow.span` 的单位是秒，拖一遍能让木星走完一整圈）。
 *    ⚠️ 诚实的代价：行星慢了 ⇒ 引力弹弓的**能量收益很小**（≤7%），它主要提供**改向**；
 *    真正的速度变化来自太阳。文案必须这么写（见各关 brief）。
 *
 * 圆轨道速度 `v = sqrt(SunGm / r)`：r=80 处 30 单位/秒、逃逸速度 42.4 —— 与 5–55 的发射速度同量级，
 * 所以"绕日弧线"和"能不能逃出去"都是真的在算，不是演出来的。
 *
 * 尺寸层次（S3.6.1 用户拍板，S3.7 整体 ×1.3）：半径 ∝ 真实比^0.4 × 1.35 × 1.3，
 * 并且 **`visuals[i].displayRadius` 必须等于 `planets[i].radius`**（硬约束，单测守着）——
 * 玩家靠肉眼判断"会不会撞上"，两个数不相等就是不公。
 *
 * 本模块**纯数据 + 纯函数**，不 import 'Dora'，可单测；可玩性由 `Test/LevelDataTest.ts` 的扫掠守着，
 * 调数值先用 `node tools/level-sweep.mjs`（秒级、同一套公式）。
 */
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { GravityScale, OrbitSpeedScale } from 'game/Config';

/** 行星视觉描述（与 Scene.PlanetVisual 结构兼容，避免跨模块依赖）。 */
export interface PlanetVisualDef {
	r: number;
	g: number;
	b: number;
	/** 行星网格的显示半径（世界单位）。**必须等于 `Body.radius`**（尺寸层次硬约束）。 */
	displayRadius: number;
	ring: boolean;
	/**
	 * 模型名（不含路径与扩展名，如 'Planet_Mars'），S3.1 已入库的 .glb 之一。
	 * 留空表示回退到代码生成的 Sphere.gltf（单位球）。**只影响视觉，不参与物理**。
	 */
	model?: string;
	/**
	 * 自发光（0–1，可选）。太阳必须给：否则它在画面里就是一颗土黄色石球，不像光源。
	 */
	emissive?: { r: number; g: number; b: number };
}

/** 顺序航线的一个航点（S3.7）。 */
export interface WaypointSpec {
	planetIndex: number;
	/** 掠过容差（平面单位）。 */
	tolerance: number;
	/** 航点名（HUD/简报用，例如 '木星'）。 */
	label?: string;
	/**
	 * 要求**捕获入轨**（S3.9.2，用户："后半段减速的时候，就可以尝试进入某个行星的轨道"）：
	 * 除了进环，还要求**相对行星**的速度 ≤ captureFactor × 该处圆轨道速度。
	 * 中间航点不设（掠过即可）；终点站才设 —— 通常配合「刹车」剖面使用。
	 */
	capture?: boolean;
	/** 捕获的速度上限系数（默认 √2 = 该处**逃逸速度**，即"真的被行星束缚住"）。 */
	captureFactor?: number;
}

/** 目标规格。 */
export interface GoalSpec {
	/** 'planet' = 进入目标容差（掠过/到达）；'escape' = 飞出边界。 */
	kind: 'planet' | 'escape';
	/** 目标行星索引（单目标时有效）。 */
	planetIndex: number;
	/** 到达容差（平面单位）。必须 > 目标行星半径，否则不可达。 */
	tolerance: number;
	/**
	 * 顺序航线（S3.7）：按数组顺序**依次**掠过这些天体才算完成。
	 * 给了 chain 就以它为准（planetIndex/tolerance 只作兼容/工具用）。
	 * 这是"真实编年"的核心：木星 → 土星 → 天王星 → 海王星，一次点火。
	 */
	chain?: WaypointSpec[];
}

/** 一关的完整定义。 */
export interface LevelDef {
	id: number;
	/** 选关按钮上的名字（= 编年章节名）。 */
	title: string;
	/** 关间"航行日志"体简报：我在哪 / 下一站 / 为什么。 */
	brief: string;
	probeStart: P2;
	/**
	 * 出发时探测器**已经有的速度**（S3.9.3）：L1 用它表达"你正在绕地球飞"。
	 * 玩家拖出来的那一下是 **Δv（点火）**，落在它上面：总速度 = probeVel0 + 点火。省略 = 静止出发。
	 */
	probeVel0?: P2;
	planets: Body[];
	visuals: PlanetVisualDef[];
	goal: GoalSpec;
	/**
	 * Δv 预算（S3.9.2b，用户要求）：满力对应的速度就是它 —— "力大砖飞"要被挡住。
	 * 有效上限 = `min(Config.AimMaxSpeed, dvBudget)`；刹车模式下两次点火共享这个数。
	 */
	dvBudget: number;
	/** 越界半径（距原点 = 距太阳）。 */
	escapeRadius: number;
	maxSteps: number;
	/**
	 * 时间轴（S3.6.4）：「发射日期」滑杆的取值范围（秒）。省略 = 这一关没有时间轴。
	 */
	timeWindow?: { span: number };
}

// ---------------------------------------------------------------------------
// 尺度与天体常量（S3.7）
// ---------------------------------------------------------------------------

/** 太阳的引力强度（`v_circ(80) = sqrt(SunGm/80) ≈ 30`，逃逸速度 42.4）。 */
export const SunGm = 72000;

/**
 * 太阳的半径（撞毁半径 = 显示半径，尺寸公平性硬约束）。
 *
 * ⚠️ 2026-09-26 用户参考图（docs/比例尺效果展示图.excalidraw）给的比值：
 *   最内圈轨道 ≈ **1.9 个太阳半径**、太阳直径 ≈ 屏幕宽度的 0.38、行星 ≈ 太阳的 0.19。
 *   原来取 7.0（轨道 = 7.9~27.9 个太阳半径）⇒ 太阳在画面里像一颗行星，"尺度很怪"的根因之一。
 *   改成 28 之后：轨道 55/80/105/135/165/195 = 1.96/2.86/3.75/4.8/5.9/7.0 个太阳半径，与参考图一致。
 */
export const SunRadius = 28.0;

/**
 * 开普勒周期系数：`T = KeplerK · r^1.5`（秒）。
 *
 * 相对快慢 = 真实开普勒（内快外慢），绝对速率被压缩 —— `KeplerK = 1` 相当于把真实值除以 42.7
 * （真实：`T = 2π·r^1.5/sqrt(SunGm) = 0.0234·r^1.5`）。这样飞行十几秒里行星只挪几度。
 */
export const KeplerK = 1.0;

/** 开普勒周期（秒）：r 单位是平面单位。r <= 0 返回 0（静止）。 */
export function keplerPeriod(orbitRadius: number): number {
	if (orbitRadius <= 0) return 0;
	return KeplerK * Math.pow(orbitRadius, 1.5);
}

/** 度 → 弧度（关卡数据里写角度比写弧度好读）。 */
function deg(d: number): number {
	return (d * Math.PI) / 180;
}

// 半径表（真实比^0.4 × 1.35 × 1.3，见文件头）
const R_MOON = 1.0;
// ⚠️ S3.13：L1 不再放大半径（改用标准尺寸层次）—— "近景"由**相机**给，不由尺寸给。
// 理由：物理统一之后 L1 与其它关在同一个太阳系里，地球/月球必须与别处一致。
const R_VENUS = 1.72;
const R_EARTH = 1.76;
const R_JUPITER = 4.63;
const R_SATURN = 4.30;
const R_URANUS = 3.04;
const R_NEPTUNE = 3.00;

/** 巡航轨道半径（压缩太阳系：顺序真实、比例压缩）—— 一律绕原点（太阳）。 */
const ORBIT = { venus: 55, earth: 80, jupiter: 105, saturn: 135, uranus: 165, neptune: 195 };

/** 掠过环的容差（flyby）：比本体大 13 左右 —— 远距离飞行要有"够得着"的手感。 */
const FLYBY_PAD = 13;

/**
 * 引力强度表（S3.13 六站重排）。
 *
 * ⚠️ 这些是**玩法参数**，不是真实比值：真实木星是地球的 318 倍，这里只有 ~1 倍。
 * 按真实比值，木星会在 40 单位外就把探测器抓住，「绕日弧线」这条主玩法就没了。
 * 但**同一颗行星在六关里必须是同一个值** —— 否则玩家在 L3 学到的「木星能把我掰多少」，
 * 到 L5 就不成立了，那正是「物理不统一」最容易被玩家看出来的地方。
 */
const GM = { venus: 2600, jupiter: 2500, saturn: 12000, uranus: 1200, neptune: 8000 };

/**
 * 在飞行采样点中找第一个进入目标容差的索引。
 *
 * 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻）。
 * `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时传 `N * PhysicsStep`）。
 * 返回 -1 表示未到达。
 */
/**
 * 行星自身在时刻 t 的速度（圆轨道 = 位置的导数）。
 * 捕获判据要的是"**相对**行星的速度" —— 行星自己也在跑（虽然慢）。
 */
export function bodyVelocityAt(b: Body, t: number): P2 {
	if (b.orbitPeriod === 0 || b.orbitRadius <= 0) return { x: 0, y: 0 };
	const angle = b.phase0 + b.orbitDirection * (2 * Math.PI) * (t / b.orbitPeriod);
	const w = (b.orbitDirection * 2 * Math.PI) / b.orbitPeriod;
	return { x: -Math.sin(angle) * b.orbitRadius * w, y: Math.cos(angle) * b.orbitRadius * w };
}

export function goalWaypoints(goal: GoalSpec): WaypointSpec[] {
	if (goal.chain !== undefined) return goal.chain;
	if (goal.kind === 'planet') return [{ planetIndex: goal.planetIndex, tolerance: goal.tolerance }];
	return [];
}

/**
 * 顺序航线的进度：返回在 points[0..upto] 里**依次**掠过的航点数与最后一个命中索引。
 *
 * 一次线性扫描：航点必须按顺序命中，且后一个必须出现在更晚的采样点上
 * （"先到土星再路过木星"不算数）。upto 用于飞行中查询"到哪一段了"（画环的明暗）。
 */
/**
 * 采样点 i 处、相对某天体的速度（捕获判据与诊断共用同一份实现）。
 *
 * points 里只有位置 ⇒ 用相邻采样点差分；`dt` 是**相邻采样点之间的有效步长**。
 * `limit` 是最后一个有效采样点索引（末端夹紧用）。
 */
export function relativeSpeedAt(points: P2[], i: number, body: Body, dt: number, t0: number, limit: number, velocities?: P2[]): number {
	let vx = 0;
	let vy = 0;
	if (velocities !== undefined && velocities[i] !== undefined) {
		// 首选：模拟给出的**精确**速度（S3.9.2 加进 SimResult）
		vx = velocities[i].x;
		vy = velocities[i].y;
	} else {
		// 退路：位置差分。⚠️ 撞毁时推演在那一帧截断，最后一点只跨半步 ⇒ 速度会被低估
		// （实测把"撞进行星"判成"入轨"）。所以**调用方应尽量传 velocities**。
		const j1 = i + 1 <= limit ? i + 1 : i;
		const j0 = i > 0 ? i - 1 : i;
		const spanT = (j1 - j0) * dt;
		if (spanT > 0) {
			vx = (points[j1].x - points[j0].x) / spanT;
			vy = (points[j1].y - points[j0].y) / spanT;
		}
	}
	const pv = bodyVelocityAt(body, t0);
	const rx = vx - pv.x;
	const ry = vy - pv.y;
	return Math.sqrt(rx * rx + ry * ry);
}

/** 捕获阈值：该处逃逸速度（圆轨道速度 × 系数 k，k 默认 √2）。 */
export function captureThreshold(body: Body, d: number, k: number): number {
	if (body.gm <= 0 || d <= 1e-6) return 1e9;
	return k * Math.sqrt(body.gm / d);
}

export function waypointProgress(
	points: P2[],
	bodies: Body[],
	goal: GoalSpec,
	dt: number,
	t0?: number,
	upto?: number,
	/** 与 points 一一对应的速度序列（模拟给的精确值；省略则退回位置差分）。 */
	velocities?: P2[],
): { passed: number; lastIndex: number } {
	const wps = goalWaypoints(goal);
	const start = t0 !== undefined ? t0 : 0;
	let limit = points.length - 1;
	if (upto !== undefined && upto >= 0 && upto < limit) limit = upto;
	let next = 0;
	let lastIndex = -1;
	for (let i = 0; i <= limit && next < wps.length; i++) {
		const w = wps[next];
		const body = bodies[w.planetIndex];
		if (body === undefined) return { passed: 0, lastIndex: -1 };
		const gp = bodyPositionAt(body, start + i * dt);
		if (distance(points[i], gp) < w.tolerance) {
			// 捕获（S3.9.2）：进环还不够，还得"慢到能被抓住"。太快 ⇒ 不算，继续扫后面的采样点。
			if (w.capture === true) {
				// 默认 √2：相对速度低于**逃逸速度**（= 圆轨道速度 × √2）⇒ 真的被这颗行星束缚住。
				// 比"圆轨道速度"更宽松，也正是"捕获"在物理上的定义（用户选的宽松档 ⇒ 用这条）。
				const k = w.captureFactor !== undefined ? w.captureFactor : 1.4142135623730951;
				const d = distance(points[i], gp);
				// ⚠️ 撞上去不叫入轨：`simulate` 撞毁时会在那一帧截断，最后一个采样点的"差分速度"
				// 会明显偏小（残段），于是"一头撞进行星"反而被判成捕获（实测踩到：rel=34.7 而阈值=43.1）。
				// 判据上直接排除本体半径以内 —— 物理上也正是如此：要留在轨道上就得先别撞上。
				if (d <= body.radius) continue;
				const rel = relativeSpeedAt(points, i, body, dt, start + i * dt, limit, velocities);
				if (rel > captureThreshold(body, d, k)) continue;
			}
			next += 1;
			lastIndex = i;
		}
	}
	return { passed: next, lastIndex: lastIndex };
}

export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number, t0?: number, velocities?: P2[]): number {
	const wps = goalWaypoints(goal);
	if (wps.length === 0) return -1;
	const st = waypointProgress(points, bodies, goal, dt, t0, undefined, velocities);
	return st.passed >= wps.length ? st.lastIndex : -1;
}


// ---------------------------------------------------------------------------
// 六站数据（S3.13 重排）—— 「同一套物理，去不同的地方」（设计稿：docs/关卡舞台表.md）
//
// 六关共同的四条（改任何数值之前先读一遍）：
//   1. **从地球轨道出发**：probeStart 固定在 (0,80)；太阳在场、行星都在绕日走，
//      引力弹弓 / 碰撞 / 时间轴从第一关起**全部在场** —— 不再有「这一关才引入的机制」。
//   2. **时间轴是全局的**：六关都带 timeWindow。日期一变行星排布就变，这条路通不通也跟着变
//      —— 日期是玩家手里的一根真旋钮，不是装饰。
//   3. **一站一个目的地**：月球 / 金星 / 木星 / 土星 / 天王星 / 海王星。
//      难度 = 要穿几个中继节点 + 距离 + 允许的误差；不靠「新机制」叠难度。
//   4. **预测线 = 真实轨迹**：两边都是 game/Gravity.ts 的同一个 simulate
//      —— 「看得见的那条线」就是「会飞的那条路」。
//
// ⚠️ 相位的口径：orbiter() 的第 4 个参数（phase0，度）**必须**用
//    node tools/level-phases.mjs <关号> --t0 <想让它对齐的发射日期>
//    解出来，不要手填。S3.11 的教训：L3/L5 的相位曾经是「照一条设计航线排的」，而那条航线
//    **撞进太阳**（peakR 只有 80）⇒ 任何日期都对不上，成功率被压到 0.2%~6%，玩家骂「关卡诡异」。
// ---------------------------------------------------------------------------

/** 太阳（每关的第 0 号天体）。 */
function sun(): Body {
	return { gm: SunGm, radius: SunRadius, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 };
}

/** 太阳的视觉（亮黄，模型 Sun.glb）。 */
function sunVisual(): PlanetVisualDef {
	// ⚠️ S3.12：太阳自己照不到自己（光在它内部、表面法线朝外）⇒ 必须靠 emissive 把自己点亮。
	// 原来是 (0.95,0.72,0.30) 的土黄，配上光晕像一颗**被啃掉一半的暗球**（截图实测），改成过曝的暖白。
	return { r: 1.0, g: 0.97, b: 0.88, displayRadius: SunRadius, ring: false, model: 'Sun', emissive: { r: 1.0, g: 0.95, b: 0.82 } };
}

/** 绕日公转的行星（圆心 = 太阳 = 原点）。 */
function orbiter(gm: number, radius: number, orbitRadius: number, phaseDeg: number): Body {
	return {
		gm, radius,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius,
		orbitPeriod: keplerPeriod(orbitRadius),
		phase0: deg(phaseDeg),
		orbitDirection: 1, // 全太阳系一致：顺行（从北极看逆时针）
	};
}

/**
 * 绕**会动的行星**公转的卫星（S3.13）：直接把宿主天体对象传进来，位置就随宿主一起走
 * （见 Gravity.Body.host）。periodSec 显式给 —— 月球绕地球的周期不该用「绕日开普勒」算，
 * 而要与**全局时间压缩**一致（本作 K = 1.0 = 真实周期 ÷ 42.7）。
 */
function satellite(gm: number, radius: number, host: Body, orbitRadius: number, phaseDeg: number, periodSec: number): Body {
	return {
		gm, radius,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius,
		orbitPeriod: periodSec,
		phase0: deg(phaseDeg),
		orbitDirection: 1,
		host,
	};
}

/**
 * 家园地球（L2–L6 的布景天体）：**沿自己的轨道走**，但不参与引力。
 *
 * 为什么 gm = 0：每关都从**地球轨道上的一点**出发（probeStart 固定在 (0,80)），
 * 如果这颗地球带引力，出发点就在它 8 个单位以内 —— 那就等于「从地球引力井里起飞」
 * （a ≈ 37 单位/秒²，一秒内就能把你甩飞），六关的几何 / 相位 / 容差全部要重解；
 * 而太阳系其余部分是按 KeplerK = 1 压缩过的：地球近在咫尺、别处却那么慢，那不是统一物理。
 * 所以它是「**看得见的家**」，不是「拉得动你的家」。真天体的地球在 L1（gm 2600）。
 *
 * ⚠️ 相位 100° 是**挑过的**：出发点在 90°，地球领先 10°（约 14 单位，视觉上「家就在前面」）。
 * 为什么不能随便放：撞毁判定只看半径、**不看 gm**（Gravity.bodyHitIndex），所以地球一旦挪到
 * 出发点上，那一天一进关探测器就直接生成在地球内部。它在时间轴里最多走 151°（span 300 秒），
 * 所以只要让 [phase0, phase0+151°] 不跨过 90°±3° 就行 —— 100° 满足，而且对六关所有 span 都满足。
 */
function homeEarth(): Body {
	return {
		gm: 0, radius: R_EARTH,
		orbitCenter: { x: 0, y: 0 },
		orbitRadius: ORBIT.earth,
		orbitPeriod: keplerPeriod(ORBIT.earth),
		phase0: deg(100),
		orbitDirection: 1,
	};
}

// ---- 行星视觉（六关共用一份配色/模型：同一颗行星在别处也必须长一样）----
// displayRadius 必须等于对应 Body 的 radius（尺寸公平性硬约束，Test/LevelDataTest 守着）

/** 地球（家园）：蓝绿。 */
function earthVisual(): PlanetVisualDef {
	return { r: 0.42, g: 0.62, b: 0.85, displayRadius: R_EARTH, ring: false, model: 'Planet_Earth' };
}
/** 月球（L1）：灰。⚠️ 还没有 Moon.glb —— 回退到代码生成的 Sphere.gltf（在 Trae 的交付清单里）。 */
function moonVisual(): PlanetVisualDef {
	return { r: 0.56, g: 0.56, b: 0.60, displayRadius: R_MOON, ring: false };
}
/** 金星：暖黄的硫酸云。 */
function venusVisual(): PlanetVisualDef {
	return { r: 0.90, g: 0.78, b: 0.55, displayRadius: R_VENUS, ring: false, model: 'Planet_Venus' };
}
/** 木星：条纹橙褐。 */
function jupiterVisual(): PlanetVisualDef {
	return { r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' };
}
/** 土星：淡金 + 环。 */
function saturnVisual(): PlanetVisualDef {
	return { r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' };
}
/** 天王星：青蓝。 */
function uranusVisual(): PlanetVisualDef {
	return { r: 0.62, g: 0.82, b: 0.86, displayRadius: R_URANUS, ring: false, model: 'Planet_Uranus' };
}
/** 海王星：深蓝。 */
function neptuneVisual(): PlanetVisualDef {
	return { r: 0.34, g: 0.50, b: 0.86, displayRadius: R_NEPTUNE, ring: false, model: 'Planet_Neptune' };
}

/**
 * L1 的地球（S3.13）：它是**真天体**，而且**自己在绕日公转** —— 这是「物理统一」的试纸。
 * 月球用它当 host（见 satellite），于是「月球绕地球、地球绕日」两件事同时成立。
 */
const L1_EARTH: Body = {
	gm: 2600,
	radius: R_EARTH,
	orbitCenter: { x: 0, y: 0 },
	orbitRadius: ORBIT.earth,
	orbitPeriod: keplerPeriod(ORBIT.earth),
	phase0: deg(90),
	orbitDirection: 1,
};

/**
 * L1 的月球：绕上面那颗**会动的**地球公转。
 *
 * ⚠️ 周期是**玩法参数**，不是物理常数：15 单位的轨道如果按「与全局时间压缩一致」取 276 秒，
 * 月球在 60 秒的时间轴里只走 78°，每个日期都打得到 —— 窗口就没有意义了（实测每个 t0 都有解）。
 * 取 120 秒 ⇒ 60 秒跨度 = 它走过 **180°**，「挑时机」才真的成立；
 * 飞行 2 秒里的漂移 = 6°，远小于容差，不会让瞄准变难。
 */
const L1_MOON_ORBIT_R = 15;
const L1_MOON_PERIOD = 120;

const LEVELS: LevelDef[] = [
	{
		id: 1,
		title: '月球',
		// 六站里唯一的一次「近景」：地月系。月球**真的在绕地球走**，所以不能对着它现在的位置打。
		brief: '月球任务 · 地球轨道：月球正在绕地球走 —— 别对着它现在的位置点火。这一次点火决定后面的一切。',
		// 探测器已经在绕地球飞（用户：「飞行器也是一开始在运动的，围绕地球」）。
		// 圆轨道速度 = sqrt(gm / 距离) = sqrt(2600 / 10) ≈ 16.12，方向 +x（切向）
		// ⇒ 预测线一上来就是一条弧线，玩家拖出来的那一下是「点火」。
		// ⚠️ 必须是**正好**的圆轨道速度：早先 gm 是 4320、速度没跟着改，v/v_circ = 1.29，
		//    轨迹变成一条**大椭圆**（远地点 147），第一眼就成了「一片星空里一个小点」（截图实测）。
		probeStart: { x: 0, y: 90 },
		probeVel0: { x: 16.12, y: 0 },
		planets: [
			sun(), // 太阳在场（物理统一）—— 对地月之间它只表现为潮汐扰动
			L1_EARTH,
			// 月球：t=0 时在 (0,80)+15·(cos180°,sin180°) = (-15, 80)，离探测器（0,90）约 18 单位
			satellite(0, R_MOON, L1_EARTH, L1_MOON_ORBIT_R, 0, L1_MOON_PERIOD),
		],
		visuals: [sunVisual(), earthVisual(), moonVisual()],
		// 教学关要宽容：容差 5（月球半径只有 1.0）—— 环的角窗口 ±19°，飞行只有 ~2 秒。
		goal: { kind: 'planet', planetIndex: 2, tolerance: 5 },
		dvBudget: 45,
		escapeRadius: 700,
		maxSteps: 1200,
		// 时间轴 60 秒 = 月球走 180°（见 L1_MOON_PERIOD 的说明）：日期一变方位整个换掉。
		timeWindow: { span: 60 },
	},

	{
		id: 2,
		title: '金星',
		brief: '金星任务 · 地球轨道：太阳会一路把你拽快 —— 向内飞，别飞过头。金星在 55 单位的内圈上等着。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			homeEarth(), // 家园地球：沿地球轨道走（gm = 0 的布景，理由见 homeEarth 的长注释）
			// 金星（55）：内圈，有引力 —— 它既是目标，也是「甩你一下」的那只手。
			// 六站里唯一一次**向内飞**：太阳会一路加速你，所以这一关的难点是「收」。
			orbiter(GM.venus, R_VENUS, ORBIT.venus, 358.12),
		],
		visuals: [sunVisual(), earthVisual(), venusVisual()],
		// 容差 = 本体 + 13（≈ ±15° 的角窗口）：远距离飞行要「够得着」的手感。
		goal: { kind: 'planet', planetIndex: 2, tolerance: R_VENUS + FLYBY_PAD },
		dvBudget: 45,
		escapeRadius: 700,
		maxSteps: 1500, // 12.5 秒：向内坠落最快只要 7 秒（径向直落约 1 秒）
		timeWindow: { span: 240 },
	},
	{
		id: 3,
		title: '木星',
		brief: '木星任务 · 地球轨道：第一次真正的行星际飞行。出发得够快，木星才会在你到达时出现在航线上。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			homeEarth(),
			// 木星（105）：这一关唯一的目标，也是本作的「核心瞬间」——
			// 掠过时会被它掰弯：掠过距离 ~17 单位、相对速度 ~24 ⇒ 偏折 20°~40°，肉眼看得出来。
			// （从哪一侧掠过会改变偏折方向，这是玩家在这一关要做的判断。）
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 34.68),
		],
		visuals: [sunVisual(), earthVisual(), jupiterVisual()],
		goal: { kind: 'planet', planetIndex: 2, tolerance: R_JUPITER + FLYBY_PAD },
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400, // 20 秒：地球轨道 → 木星轨道的最省力弧线约 10 秒
		timeWindow: { span: 300 },
	},
	{
		id: 4,
		title: '土星',
		brief: '土星任务 · 地球轨道：先掠过木星，让它替你掰一下方向 —— 土星还在更外面。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			homeEarth(),
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 33.78),
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 66.7),
		],
		visuals: [sunVisual(), earthVisual(), jupiterVisual(), saturnVisual()],
		// 两个节点（S3.13）：先掠过木星，再到土星 —— 一次点火，两个环都要穿对。
		goal: {
			kind: 'planet', planetIndex: 3, tolerance: 45,
			chain: [
				{ planetIndex: 2, tolerance: 30, label: '木星' },
				{ planetIndex: 3, tolerance: 45, label: '土星' },
			],
		},
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400,
		timeWindow: { span: 300 },
	},
	{
		id: 5,
		title: '天王星',
		brief: '天王星任务 · 地球轨道：木星、土星，两次借力，越飞越远。一次点火要串起三个节点。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			homeEarth(),
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 48.58),
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 80),
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 96.33),
		],
		visuals: [sunVisual(), earthVisual(), jupiterVisual(), saturnVisual(), uranusVisual()],
		// 三个节点：木星 → 土星 → 天王星（容差逐站放大 —— 越远，弧线越长、越难对准）。
		goal: {
			kind: 'planet', planetIndex: 4, tolerance: 60,
			chain: [
				{ planetIndex: 2, tolerance: 40, label: '木星' },
				{ planetIndex: 3, tolerance: 50, label: '土星' },
				{ planetIndex: 4, tolerance: 60, label: '天王星' },
			],
		},
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400,
		timeWindow: { span: 300 },
	},
	{
		id: 6,
		title: '海王星',
		brief: '海王星任务 · 地球轨道：四颗巨行星连成一条线的那个日期。一次点火串到底，飞向 195 单位外的海王星。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			homeEarth(),
			// 四颗**连珠**：都在 89.5° 附近（= 从地球向外那条射线的方位）—— 这正是真实 Grand Tour
			// 能成立的原因：八十年代外侧四颗巨行星恰好挤在同一小段方位上。
			// 这里的相位是「第 175 秒才连珠」的解（node tools/level-phases.mjs 6 --t0 175）：
			// t0=0 时它们明显错开，玩家必须先把日期拨过去，四颗才排到出射线上。
			orbiter(GM.jupiter, R_JUPITER, ORBIT.jupiter, 29.3),
			orbiter(GM.saturn, R_SATURN, ORBIT.saturn, 48.2),
			orbiter(GM.uranus, R_URANUS, ORBIT.uranus, 58.9),
			orbiter(GM.neptune, R_NEPTUNE, ORBIT.neptune, 65.7),
		],
		visuals: [sunVisual(), earthVisual(), jupiterVisual(), saturnVisual(), uranusVisual(), neptuneVisual()],
		// 四个节点：一次点火依次穿过木 → 土 → 天 → 海。
		// ⚠️ 这一关**不再**要求逃逸（S3.13）：逃逸归终章「暗淡蓝点」，第 6 关就是一个目的地任务。
		//    旧的 kind:'escape' 版本要求「航线走完 **且** 越过 260」—— 那会让「穿过四颗巨行星」
		//    从任务变成附加条件，也让最后 65 单位的空程变成纯粹的等待。
		goal: {
			kind: 'planet', planetIndex: 5, tolerance: 70,
			chain: [
				{ planetIndex: 2, tolerance: 40, label: '木星' },
				{ planetIndex: 3, tolerance: 50, label: '土星' },
				{ planetIndex: 4, tolerance: 60, label: '天王星' },
				{ planetIndex: 5, tolerance: 70, label: '海王星' },
			],
		},
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400, // 20 秒：地球轨道 → 海王星轨道约 19 秒（顺带卡住「绕远路」的样本）
		timeWindow: { span: 300 },
	},
];

/** 关卡总数。 */
export function levelCount(): number {
	return LEVELS.length;
}

/** 取第 index 关（0 起）。越界返回 undefined。 */
export function getLevel(index: number): LevelDef | undefined {
	return LEVELS[index];
}

/** 应用全局倍率，返回可直接喂给 createGame 的行星数组。不修改关卡原始数据。 */
export function scaledPlanets(level: LevelDef): Body[] {
	return applyScalesLocal(level.planets, GravityScale, OrbitSpeedScale);
}

// 局部引用，避免在模块顶层形成对 Gravity 的额外导出依赖
function applyScalesLocal(bodies: Body[], gravityScale: number, orbitScale: number): Body[] {
	const out: Body[] = [];
	for (const b of bodies) {
		out.push({
			gm: b.gm * gravityScale,
			radius: b.radius,
			orbitCenter: { x: b.orbitCenter.x, y: b.orbitCenter.y },
			orbitRadius: b.orbitRadius,
			orbitPeriod: b.orbitPeriod === 0 || orbitScale <= 0 ? b.orbitPeriod : b.orbitPeriod / orbitScale,
			phase0: b.phase0,
			orbitDirection: b.orbitDirection,
			// ⚠️ 宿主也要一起缩放（否则卫星绕着一颗"没被缩放"的行星转 —— 位置会错开）
			host: b.host !== undefined ? applyScalesLocal([b.host], gravityScale, orbitScale)[0] : undefined,
		});
	}
	return out;
}

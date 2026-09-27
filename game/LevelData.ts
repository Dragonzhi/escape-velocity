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
	/**
	 * 是否还要那个纯视觉的"家园锚点"（地球）。
	 * L1 的地球已经是真天体（有引力、会挡住 1 号候选）⇒ 那里必须置 false，否则叠两个地球。
	 */
	homeAnchor?: boolean;
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
	/** 家园锚点（地球）的显示半径：逐关变小 —— 越飞越远，回头看它越小。 */
	homeRadius: number;
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
// L1 是**近景**（地月系）：这两个值只用于第一关，比例仍是地球/月球 = 1.76，
// 但绝对尺寸放大到肉眼可读 —— 本尺度的轨道有 100+ 单位，1.76 的地球只有几个像素。
const R_EARTH_BIG = 6.0;
const R_MOON_BIG = 3.4;
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
// 六关数据（S3.7：真实编年 —— 出发 / 修正 / 弹弓 / 窗口 / 大巡游 / 单程）
// ---------------------------------------------------------------------------

/** 太阳（除 L1 外每关的第 0 号天体）。 */
function sun(): Body {
	return { gm: SunGm, radius: SunRadius, orbitCenter: { x: 0, y: 0 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 };
}

/** 太阳的视觉（亮黄，模型 Sun.glb）。 */
function sunVisual(): PlanetVisualDef {
	// ⚠️ S3.12：太阳现在是**点光源本体**，它自己的表面再也照不到了（光在它内部 ⇒ 表面法线朝外、
	// 与光的来向相反）⇒ 必须靠 emissive 把自己点亮。原来是 (0.95,0.72,0.30) 的土黄，
	// 配上光晕之后看起来像一颗**被啃掉一半的暗球**（截图实测），改成过曝的暖白。
	return { r: 1.0, g: 0.97, b: 0.88, displayRadius: SunRadius, ring: false, model: 'Sun', emissive: { r: 1.0, g: 0.95, b: 0.82 } };
}

/** 绕日公转的行星（S3.7：圆心 = 太阳 = 原点）。 */
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

const LEVELS: LevelDef[] = [
	{
		id: 1,
		title: '出发',
		// S3.12 用户："每一关其实都应该要符合逻辑的让星球动起来，包括第一关，我现在都不知道第一关是什么。"
		// ⇒ L1 的定位写清楚：**地月转移**（一次点火、把探测器送上月球），月球**真的在绕地球走**。
		// 这一关是本作里唯一的"近景"：地月的半径按同一套比例放大到肉眼可读（地球 6.0 / 月球 3.4，
		// 比值 1.76 与其它关一致），否则在本尺度下地球只有 1.76 而轨道有 100+ 单位，
		// 第一眼就是"一片星空里两个小点"（截图实测）。
		brief: '航行日志 · 第 1 天：地球轨道。探测器在你手里 —— 月球正在绕地球走，别对着它现在的位置打。这一次点火决定后面的一切。',
		probeStart: { x: 0, y: 46 },
		// S3.9.3：出发时探测器**已经在绕地球飞**（用户："飞行器也是一开始在运动的，围绕地球"）。
		// 地球在这一关是**真天体**（有引力）：圆轨道速度 = sqrt(gm / 距离) = sqrt(2600 / 30) ≈ **9.31**，
		// 方向 +x（切向）⇒ 预测线一上来就是一条弧线，玩家拖出来的那一下是"点火"。
		// ⚠️ 这里必须**正好是圆轨道速度**：早先 gm 是 4320（注释里那个 12 就是照它算的），
		//    后来 gm 降到 2600 而速度没跟着改 ⇒ v/v_circ = 1.29，轨迹变成一条**大椭圆**
		//    （远地点 147 = 地球半径的 84 倍），于是进关后探测器一路飞远、相机被迫拉到很大，
		//    第一关的第一眼变成"一片星空里一个小点"（截图实测）。改成 9.31 之后是正圆，贴着地球转。
		probeVel0: { x: 10.41, y: 0 },
		homeAnchor: false, // 地球已经在 planets[0]，别再叠一个纯视觉锚点
		planets: [
			// 地球（真天体）：探测器在它上方 24 单位处绕行（半径 6.0 ⇒ 离地 18，肉眼看得见"贴着地球"）。
			// gm 2600：逃离速度 sqrt(2·2600/24) ≈ 14.7 ⇒ 一次像样的点火就能走（预算 45）。
			{ gm: 2600, radius: R_EARTH_BIG, orbitCenter: { x: 0, y: 70 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 月球：**绕地球公转**（orbitCenter = 地球），周期取该半径的开普勒周期 1000 秒。
			// 飞行 4 秒里它走 1.4°、瞄准 40 秒里走 14° —— 看得见在动，但远小于容差（30 单位 ≈ 22°）⇒ 不会变难。
			{ gm: 0, radius: R_MOON_BIG, orbitCenter: { x: 0, y: 70 }, orbitRadius: 100, orbitPeriod: keplerPeriod(100), phase0: deg(-90), orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.42, g: 0.62, b: 0.85, displayRadius: R_EARTH_BIG, ring: false, model: 'Planet_Earth' },
			{ r: 0.56, g: 0.56, b: 0.60, displayRadius: R_MOON_BIG, ring: false },
		],
		// 教学关要宽容：环放宽到 30（月球半径只有 1.0 —— 等于是"飞到月球附近就算"）。
		// 手写注释一度写着 18 而代码是 24（对不上），这里以代码为准并同步：24 → 30 使
		// 首次上手的方向窗口从 ±12° 变成 ±17°（扫掠成功率 6.1% → 8.9%）。
		goal: { kind: 'planet', planetIndex: 1, tolerance: 30 },
		dvBudget: 45,
		escapeRadius: 700,
		maxSteps: 1200,
		homeRadius: 1.75,
	},
	{
		id: 2,
		title: '修正',
		brief: '航行日志 · 第 12 天：太阳开始拽你了。别直着飞 —— 向内会加速，航线也会被掰弯。目标是掠过金星。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 金星：内圈（55），有引力 —— 它既是障碍也是"甩你一下"的手。
			orbiter(2600, R_VENUS, ORBIT.venus, 180),
		],
		visuals: [
			sunVisual(),
			{ r: 0.90, g: 0.78, b: 0.55, displayRadius: R_VENUS, ring: false, model: 'Planet_Venus' },
		],
		goal: { kind: 'planet', planetIndex: 1, tolerance: R_VENUS + FLYBY_PAD },
		dvBudget: 45,
		escapeRadius: 700,
		maxSteps: 1500,
		homeRadius: 1.60,
	},
	{
		id: 3,
		title: '弹弓',
		brief: '航行日志 · 第 2 年：木星在外圈。想省力就从它背后绕过去 —— 它的引力会把你甩向土星。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 木星：本关的"弹弓"（唯一的强引力源，站在地球到土星的路上）。
			// ⚠️ 相位 89.4 / 89.0 是**相位求解器**（tools/level-phases.mjs）解出来的"设计航线穿越角"：
			// 从 (0,80) 向外飞、能依次穿过 105/135 环的那一族弧线，穿越点几乎都在 89°~90°
			// （因为最好的那族弧线接近**径向**：θ 沿径向不变 ⇒ 行星必须摆在那条射线上）。
			// 旧值 195.5/198 是照着「240° 方向、Δv 35 的绕日弧线」排的 —— 实测那条弧线**撞进太阳**
			// （peakR 只有 80），于是相位和任何可行航线都对不上，成功率被压到 6%（修完约 30%+）。
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 89.4),
			// 土星：终点站，有引力（捕获要算相对速度）
			orbiter(12000, R_SATURN, ORBIT.saturn, 89.0),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
		],
		// 顺序航线（S3.7）：先**贴近**掠过木星（容差只有本体 +6 ⇒ "贴得越近甩得越狠"），再到土星。
		goal: {
			kind: 'planet', planetIndex: 1, tolerance: R_JUPITER + 22,
			chain: [
				{ planetIndex: 1, tolerance: R_JUPITER + 22, label: '木星' },
				// ⚠️ 这一关**不做捕获**：L3 的决策是「方向性 / 加速」（从木星背后抄过去），再叠一个「减速入轨」就成两件事了。
				// 捕获从 L4「窗口」开始 —— 而它正是「选对日期才慢得下来」的那一关（设计上配套）。
				{ planetIndex: 2, tolerance: R_SATURN + 45, label: '土星' },
			],
		},
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400,
		homeRadius: 1.45,
	},
	{
		id: 4,
		title: '窗口',
		brief: '航行日志 · 第 3 年：木星一直在绕太阳走。挑一个它正好在你航线上的日期起飞 —— 拖动时间轴，看它挪位置。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 设计航线（≈ 径向射出、依次穿过 105/135 环）要求两颗都在 **89.5°** 附近。
			// 把它们摆成"**第 180 秒**才对齐"：t0=0 时木星在 29.3°、土星在 48.2°（明显错开 40°~60°），
			// 玩家每按一次「加速▶」世界时间 +15 秒 ⇒ 木星挪 5.0°、土星挪 3.4°，按 12 次正好对上。
			// 为什么是 180 而不是更小：**可行日期带本身有 ~180 秒宽**（方向窗口 ±30° ÷ 木星 0.335°/s），
			// 所以只有把答案放得足够远，t0=0 才真的是"错开的"（实测 t0*=90 时前半段全是可行解，
			// 玩家不用碰时间轴就能过 —— 这一关的教学就没了）。
			// （旧值 315.5/288 同样是照一条不存在的弧线排的，任何日期都对不上。）
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3),
			orbiter(12000, R_SATURN, ORBIT.saturn, 48.2),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
		],
		// 顺序航线（S3.7）：木星 → 土星，两颗都在绕太阳走；日期决定它们相对你的航线在哪。
		goal: {
			kind: 'planet', planetIndex: 1, tolerance: R_JUPITER + FLYBY_PAD,
			chain: [
				{ planetIndex: 1, tolerance: R_JUPITER + 22, label: '木星' },
				{ planetIndex: 2, tolerance: R_SATURN + 30, label: '土星', capture: true },
			],
		},
		dvBudget: 50,
		escapeRadius: 700,
		maxSteps: 1800,
		homeRadius: 1.35,
		// 时间轴跨度：300 秒 = 木星走 100°。可行日期带（约 35–215 秒）整段都在里面，
		// 而尾巴上 215–300 秒是"来晚了"—— 玩家能亲眼看到木星已经转过那条线，掉头按「◀回退」即可。
		// ⚠️ 别把 span 设成一整个周期（1076 秒）：那样一大半行程是纯死区，玩家会以为自己算错了。
		timeWindow: { span: 300 },
	},
	{
		id: 5,
		title: '大巡游',
		brief: '航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 四颗**连珠**：都在 89.5°（= 从地球向外那条射线的方位）。这正是真实 Grand Tour 能成立的原因
			// —— 八十年代外侧四颗巨行星恰好挤在同一小段方位上。相位由 tools/level-phases.mjs 解出：
			// 修掉旧值（195.5/203.1/209.7/216.4，照一条撞太阳的弧线排的）之后，
			// 能走通的点火方向从 6° 宽变成 **60°+ 宽**，这才是"多条路线"（设计稿第五章的原话）。
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 89.5),
			orbiter(2000, R_SATURN, ORBIT.saturn, 89.5),
			orbiter(1200, R_URANUS, ORBIT.uranus, 89.5),
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 89.5),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
			{ r: 0.62, g: 0.82, b: 0.86, displayRadius: R_URANUS, ring: false, model: 'Planet_Uranus' },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: R_NEPTUNE, ring: false, model: 'Planet_Neptune' },
		],
		// 大巡游（S3.7）：一次点火，依次掠过木 → 土 → 天 → 海。
		goal: {
			kind: 'planet', planetIndex: 1, tolerance: R_JUPITER + FLYBY_PAD,
			// 容差 40/50/60/70（≈ 20° 的角窗口）：这是**四站串联**，每一站都要在正确的时刻
			// 被够到，容差给足才谈得上"多条路线"。扫掠实测 26.6/30.3/33/37 → 7.2%，
			// 40/50/60/70 → 17.5%（环本身就是画在容差半径上的，玩家看得见这个"圈"）。
			chain: [
				{ planetIndex: 1, tolerance: 40, label: '木星' },
				{ planetIndex: 2, tolerance: 50, label: '土星' },
				{ planetIndex: 3, tolerance: 60, label: '天王星' },
				// ⚠️ 这里**不设**捕获（L3 一样）：L5 的决策是"路线规划"（怎么摆这条弧线），
				// 再叠一个"到海王星还得慢下来"就变成两件事，而实测那会把可行路线砍掉 4/5（280 → 60 量级）。
				// 捕获留在 L4 的土星 —— 那一关本来就是"选对日期才慢得下来"。
				{ planetIndex: 4, tolerance: 70, label: '海王星' },
			],
		},
		dvBudget: 55,
		escapeRadius: 700,
		maxSteps: 2400,
		homeRadius: 1.25,
	},
	{
		id: 6,
		title: '单程',
		brief: '航行日志 · 第 12 年：没有回程了。四颗巨行星还会连成一条线 —— 等到那一天（拖动时间轴），沿着这条线依次穿过去，再越过 260 单位，就是星际空间。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 四颗与 L5 一样**连珠**（都在 89.5°）：终章的"穿过四颗巨行星"必须是真目标，
			// 而不是一句文案 —— 见下面 goal.chain。
			// phase0 是"第 **180 秒**才连珠"的解（tools/level-phases.mjs 的 t0* 口径）：
			// t0=0 时木星在 29.3°（差 60°），玩家必须先把日期拨到 180 秒附近，四颗才排到出射线上。
			// ⇒ 终章 = **综合**：空间（对准连珠）+ 能量（逃逸）+ 时间（等窗口）+ 多节点（四站）。
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 29.3),
			orbiter(2000, R_SATURN, ORBIT.saturn, 48.2),
			orbiter(1200, R_URANUS, ORBIT.uranus, 58.9),
			orbiter(8000, R_NEPTUNE, ORBIT.neptune, 65.7),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
			{ r: 0.62, g: 0.82, b: 0.86, displayRadius: R_URANUS, ring: false, model: 'Planet_Uranus' },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: R_NEPTUNE, ring: false, model: 'Planet_Neptune' },
		],
		// 逃逸半径 260 = 海王星轨道（195）之外：不是"飞远一点"，是真的离开这几颗行星的地盘。
		// 单程（S3.11）：终章 = **综合** —— 先沿连珠**依次穿过四颗巨行星**，再飞出 260。
		//   ⚠️ 这一关是"两个条件都要"：resolveResult 对 kind='escape' **且带 chain** 的判定是
		//   「航线走完 **并且** 真的越界」，只走完航线 / 只飞出去都不算（S3.11 新增的规则）。
		//   （改之前这里只有 kind:'escape'：朝任何方向猛推一下就能过 —— 32% 的样本可行、
		//     270° 的方向都算赢，"穿过四颗巨行星"纯粹是文案。）
		goal: {
			kind: 'escape', planetIndex: -1, tolerance: 0,
			// 容差与 L5 同一套（40/50/60/70）：同一批巨行星、同一个"圈"的读法。
			chain: [
				{ planetIndex: 1, tolerance: 40, label: '木星' },
				{ planetIndex: 2, tolerance: 50, label: '土星' },
				{ planetIndex: 3, tolerance: 60, label: '天王星' },
				{ planetIndex: 4, tolerance: 70, label: '海王星' },
			],
		},
		// Δv 预算 50：逃逸（r=80 处需 ~37，飞过 260 需 ~37.1）意味着"至少花掉 3/4 的点火量"，
		// 这正是"单程"的另一半意思 —— 没有回程的燃料。
		dvBudget: 50,
		escapeRadius: 260,
		maxSteps: 2400,
		homeRadius: 1.00,
		// 时间轴（与 L4 同一套读数）：四颗巨行星的连珠窗口在第 90~240 秒之间，
		// 之前是"还没连上来"、之后是"已经转过去了"——扫掠逐档成功数：
		// ..111.568999999999999544（每档 12.5 秒）= 窗口真的会关。
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
		});
	}
	return out;
}

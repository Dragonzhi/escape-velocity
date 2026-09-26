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
	planets: Body[];
	visuals: PlanetVisualDef[];
	goal: GoalSpec;
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
export function waypointProgress(
	points: P2[],
	bodies: Body[],
	goal: GoalSpec,
	dt: number,
	t0?: number,
	upto?: number,
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
			next += 1;
			lastIndex = i;
		}
	}
	return { passed: next, lastIndex: lastIndex };
}

export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number, t0?: number): number {
	const wps = goalWaypoints(goal);
	if (wps.length === 0) return -1;
	const st = waypointProgress(points, bodies, goal, dt, t0);
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
	return { r: 1.0, g: 0.90, b: 0.62, displayRadius: SunRadius, ring: false, model: 'Sun', emissive: { r: 0.95, g: 0.72, b: 0.30 } };
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
		brief: '航行日志 · 第 1 天：离开地球。这一段路很干净，没有大天体捣乱 —— 先把拖拽瞄准练熟。月球在正前方。',
		probeStart: { x: 0, y: 40 },
		planets: [
			// 月球方向：无引力的纯靶子（Sphere 单位球染灰代用）。
			{ gm: 0, radius: R_MOON, orbitCenter: { x: 0, y: -70 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.56, g: 0.56, b: 0.60, displayRadius: R_MOON, ring: false },
		],
		goal: { kind: 'planet', planetIndex: 0, tolerance: 14 },
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
			// 相位来自"设计航线"数值解（tools/level-sweep 的思路：先积出一条好弧线，再把行星摆到穿越点上）。
			orbiter(4000, R_JUPITER, ORBIT.jupiter, 195.5),
			// 土星：目标（无引力，掠过即可）。
			orbiter(0, R_SATURN, ORBIT.saturn, 198),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
		],
		// 顺序航线（S3.7）：先**贴近**掠过木星（容差只有本体 +6 ⇒ "贴得越近甩得越狠"），再到土星。
		goal: {
			kind: 'planet', planetIndex: 1, tolerance: R_JUPITER + 8,
			chain: [
				{ planetIndex: 1, tolerance: R_JUPITER + 8, label: '木星' },
				{ planetIndex: 2, tolerance: R_SATURN + 45, label: '土星' },
			],
		},
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
			// t0=0 时两颗**故意错位**（设计航线要 195.5° / 198°）：必须拖日期把它们拨到航线上。
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 315.5),
			orbiter(0, R_SATURN, ORBIT.saturn, 288),
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
				{ planetIndex: 2, tolerance: R_SATURN + 30, label: '土星' },
			],
		},
		escapeRadius: 700,
		maxSteps: 1800,
		homeRadius: 1.35,
		// 时间轴跨度 = 木星周期 / 3（约 360 秒 ≈ 它走 120°）：既拖得动、又能看清它在挪；
		// ⚠️ 别把 span 设成一整个周期 —— "两颗同时在航线上"的窗口只有几十秒宽，滑杆会拖不准。
		timeWindow: { span: keplerPeriod(ORBIT.jupiter) / 3 },
	},
	{
		id: 5,
		title: '大巡游',
		brief: '航行日志 · 第 5 年：一次点火，四颗巨行星。木星改向、土星续航、天王星微调 —— 最后到海王星。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			// 四颗按"设计航线"（240° 方向、速度 35 的绕日弧线）的穿越角排成一线：
			// 这正是真实 Grand Tour 能成立的原因 —— 八十年代外侧四颗巨行星恰好连珠。
			orbiter(2500, R_JUPITER, ORBIT.jupiter, 195.5),
			orbiter(2000, R_SATURN, ORBIT.saturn, 203.1),
			orbiter(1200, R_URANUS, ORBIT.uranus, 209.7),
			orbiter(800, R_NEPTUNE, ORBIT.neptune, 216.4),
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
			chain: [
				{ planetIndex: 1, tolerance: R_JUPITER + 22, label: '木星' },
				{ planetIndex: 2, tolerance: R_SATURN + 26, label: '土星' },
				{ planetIndex: 3, tolerance: R_URANUS + 30, label: '天王星' },
				{ planetIndex: 4, tolerance: R_NEPTUNE + 34, label: '海王星' },
			],
		},
		escapeRadius: 700,
		maxSteps: 2400,
		homeRadius: 1.25,
	},
	{
		id: 6,
		title: '单程',
		brief: '航行日志 · 第 12 年：没有回程了。穿过四颗巨行星，飞出太阳系 —— 越过 260 单位就算离开。',
		probeStart: { x: 0, y: ORBIT.earth },
		planets: [
			sun(),
			orbiter(9400, R_JUPITER, ORBIT.jupiter, 200),
			orbiter(7000, R_SATURN, ORBIT.saturn, 245),
			orbiter(3200, R_URANUS, ORBIT.uranus, 290),
			orbiter(2200, R_NEPTUNE, ORBIT.neptune, 335),
		],
		visuals: [
			sunVisual(),
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: R_JUPITER, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: R_SATURN, ring: true, model: 'Planet_Saturn' },
			{ r: 0.62, g: 0.82, b: 0.86, displayRadius: R_URANUS, ring: false, model: 'Planet_Uranus' },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: R_NEPTUNE, ring: false, model: 'Planet_Neptune' },
		],
		// 逃逸半径 260 = 海王星轨道（195）之外：不是"飞远一点"，是真的离开这几颗行星的地盘。
		goal: { kind: 'escape', planetIndex: -1, tolerance: 0 },
		escapeRadius: 260,
		maxSteps: 2400,
		homeRadius: 1.00,
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

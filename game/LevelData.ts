/**
 * 关卡数据（S2.1 建立，S3.6.1 按《单程_最终玩法与关卡优化方案》的六章结构重排）。
 *
 * 六章曲线（每关只加一个新决策；标题即选关按钮上的名字）：
 *
 * | 关 | 章节 | 新决策 | 天体层 |
 * |---|---|---|---|
 * | 1 | 出发 | 操作（无引力，纯瞄准） | 月球方向（Sphere 代用球） |
 * | 2 | 借力 | 一颗**静止**引力源会掰弯航线 | 木星（静）→ 土星 |
 * | 3 | 加速 | **运动的**行星：从背后追=加速、迎头=减速 | 土星（公转）→ 天王星 |
 * | 4 | 窗口 | **发射时机**（时间轴，S3.6.4） | 木星+土星（都公转）→ 海王星 |
 * | 5 | 连锁 | 规划多段接力（多个引力节点） | 木星+土星+微型节点 → 海王星 |
 * | 6 | 单程 | 综合：没有新机制，只有最后一段路 | 木/土/天/海 → `escape` 飞出太阳系 |
 *
 * 坐标约定：探测器从 +y 侧出发，向 -y（屏幕深处）飞行。
 *
 * **尺寸层次**（S3.6.1 用户拍板：开场可读优先、游玩讲层次）：半径按
 * `真实比^0.4 × 1.35` 压缩（月球 0.75 / 火星 1.05 / 金星 1.32 / 地球 1.35 /
 * 海王星 2.31 / 天王星 2.34 / 土星 3.31 / 木星 3.56），并且
 * **`visuals[i].displayRadius` 必须等于 `planets[i].radius`** ——
 * 玩家肉眼判断「会不会撞上」，两个数不相等就是不公（硬约束，单测守着）。
 *
 * 结算（手册 §5.8）：
 * - 成功 = 进入目标行星的到达容差（未撞毁），或达成 escape 目标
 * - 错过 = 超时 / 越界仍未命中
 * - 撞毁 = 与任一行星中心距离 < 半径
 *
 * 目标容差统一取 `半径 + 3`（大行星本体大，若容差贴着本体就只有一条细缝可打）。
 *
 * 本模块**纯数据 + 纯函数**，不 import 'Dora'，可单测。
 * 可玩性由 `Test/LevelDataTest.ts` 的速度扫掠守着（每关至少一个可行解）；
 * 调数值时先跑 `node tools/level-sweep.mjs`（秒级，同样的公式），再进引擎验收。
 */
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { GravityScale, OrbitSpeedScale } from 'game/Config';

/** 行星视觉描述（与 Scene.PlanetVisual 结构兼容，避免跨模块依赖）。 */
export interface PlanetVisualDef {
	r: number;
	g: number;
	b: number;
	/**
	 * 行星网格的显示半径（世界单位）。**必须等于 `Body.radius`**（尺寸层次硬约束）。
	 */
	displayRadius: number;
	ring: boolean;
	/**
	 * 模型名（不含路径与扩展名，如 'Planet_Mars'），S3.1 已入库的 11 个 .glb 之一。
	 * 留空表示回退到代码生成的 Sphere.gltf（单位球）。**只影响视觉，不参与物理**。
	 */
	model?: string;
}

/** 目标规格。 */
export interface GoalSpec {
	/** 'planet' = 进入目标行星容差；'escape' = 飞出边界。 */
	kind: 'planet' | 'escape';
	/** 目标行星索引（kind='planet' 时有效）。 */
	planetIndex: number;
	/** 到达容差（平面单位）。必须 > 目标行星半径，否则不可达。 */
	tolerance: number;
}

/** 一关的完整定义。 */
export interface LevelDef {
	id: number;
	/** 选关按钮上的名字（= 章节名，两三个字最好看）。 */
	title: string;
	/** 关间一句任务简报（愿景 §8）。 */
	brief: string;
	probeStart: P2;
	planets: Body[];
	visuals: PlanetVisualDef[];
	goal: GoalSpec;
	escapeRadius: number;
	maxSteps: number;
	/**
	 * 家园锚点（地球）的显示半径：逐关变小 —— 越飞越远，回头看它越小（S3.6.1）。
	 * 纯视觉，不进物理、不进相机取景（Scene 的 home 参数）。
	 */
	homeRadius: number;
	/**
	 * 时间轴（S3.6.4）：「发射窗口」滑杆的取值范围（秒）。
	 * 省略 = 这一关没有时间轴（行为与旧版完全一致）。
	 */
	timeWindow?: { span: number };
}

/**
 * 在飞行采样点中找第一个进入目标容差的索引。
 *
 * 目标行星在移动，所以逐点用 `t = t0 + i * dt` 时的行星位置判定（`t0` = 发射时刻，见 Gravity.SimOptions）。
 * `dt` 必须是**采样点之间的有效步长**（采样间隔 N 步时要传 `N * PhysicsStep`，否则移动目标的时间轴是错的）。
 * 返回 -1 表示未到达。
 */
export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number, t0?: number): number {
	if (goal.kind !== 'planet') return -1;
	const body = bodies[goal.planetIndex];
	if (body === undefined) return -1;
	const start = t0 !== undefined ? t0 : 0;
	for (let i = 0; i < points.length; i++) {
		const gp = bodyPositionAt(body, start + i * dt);
		if (distance(points[i], gp) < goal.tolerance) return i;
	}
	return -1;
}

// ---------------------------------------------------------------------------
// 六关数据（S3.6.1：数值由 tools/level-sweep.mjs 扫掠收敛，再进引擎验收）
//
// 半径表（尺寸层次）：木星 3.56 / 土星 3.31 / 天王星 2.34 / 海王星 2.31 /
// 地球 1.35 / 金星 1.32 / 火星 1.05 / 月球 0.75。
// ⚠️ 改任何 radius / gm / 位置之后，必须重跑 tools/level-sweep.mjs 与 Test/LevelDataTest。
// ---------------------------------------------------------------------------

const LEVELS: LevelDef[] = [
	{
		id: 1,
		title: '出发',
		brief: '1977 年 9 月 5 日，旅行者号离开地球。拖动瞄准，松手发射 —— 先学会让它听话。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 月球方向：无引力纯靶子（Sphere 单位球代用，染成灰色月面）。
			{ gm: 0, radius: 0.75, orbitCenter: { x: 0, y: -30 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.56, g: 0.56, b: 0.60, displayRadius: 0.75, ring: false },
		],
		goal: { kind: 'planet', planetIndex: 0, tolerance: 3.75 },
		escapeRadius: 400,
		maxSteps: 1500,
		homeRadius: 1.35,
	},
	{
		id: 2,
		title: '借力',
		brief: '别对准目标，对准木星。它的引力会把你的航线掰过去 —— 但别撞上去。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 木星：静止的巨型引力源，正挡在航线上（gm 已按新半径 3.56 重新标定）。
			{ gm: 1500, radius: 3.56, orbitCenter: { x: 0, y: -6 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 目标：土星（无引力，纯靶子）。
			{ gm: 0, radius: 3.31, orbitCenter: { x: -26, y: -26 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 3.56, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 3.31, ring: true, model: 'Planet_Saturn' },
		],
		goal: { kind: 'planet', planetIndex: 1, tolerance: 6.31 },
		escapeRadius: 400,
		maxSteps: 1800,
		homeRadius: 1.20,
	},
	{
		id: 3,
		title: '加速',
		brief: '土星在动。从它背后追上去，你会被带着加速；迎头撞进它的引力，你会被拖慢。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 土星：**公转中**（半径 10 / 周期 12s，肉眼可见），既是障碍也是唯一的能量来源。
			{ gm: 1100, radius: 3.31, orbitCenter: { x: 0, y: -4 }, orbitRadius: 10, orbitPeriod: 12, phase0: -1.0471975511965976, orbitDirection: 1 },
			// 目标：天王星（无引力）。
			{ gm: 0, radius: 2.34, orbitCenter: { x: -24, y: -28 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 3.31, ring: true, model: 'Planet_Saturn' },
			{ r: 0.62, g: 0.82, b: 0.86, displayRadius: 2.34, ring: false, model: 'Planet_Uranus' },
		],
		goal: { kind: 'planet', planetIndex: 1, tolerance: 5.34 },
		escapeRadius: 400,
		maxSteps: 1800,
		homeRadius: 1.05,
	},
	{
		id: 4,
		title: '窗口',
		brief: '木星和土星都在公转，发射时机就是你的第三个旋钮。拖动时间轴，看它们挪位置。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 木星 6s 一圈、土星 8s 一圈（都比飞行时间短 ⇒ 出发晚半秒，遭遇时它们的角度就完全不同，
			// 时间轴才真的"有东西可调"；两颗都是强引力源，也都会把探测器甩出去）。
			{ gm: 2000, radius: 3.56, orbitCenter: { x: 0, y: -6 }, orbitRadius: 8, orbitPeriod: 6, phase0: 3.141592653589793, orbitDirection: 1 },
			{ gm: 1400, radius: 3.31, orbitCenter: { x: -12, y: -16 }, orbitRadius: 8, orbitPeriod: 8, phase0: 4.71238898038469, orbitDirection: 1 },
			// 目标：海王星（无引力，最远的一站；容差紧到 0.6 —— 贴过去，不是撞上去）。
			{ gm: 0, radius: 2.31, orbitCenter: { x: -28, y: -38 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 3.56, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 3.31, ring: true, model: 'Planet_Saturn' },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: 2.31, ring: false, model: 'Planet_Neptune' },
		],
		goal: { kind: 'planet', planetIndex: 2, tolerance: 2.91 },
		escapeRadius: 400,
		maxSteps: 1800,
		homeRadius: 0.95,
		// 时间轴跨度 16s ≈ 木星 2.7 圈 / 土星 2 圈：拖一遍能看清"两颗行星的相对位置一直在变"。
		timeWindow: { span: 16 },
	},
	{
		id: 5,
		title: '连锁',
		brief: '接力：木星把你甩向土星，土星把你交给那颗小行星，最后由它把航线掰到海王星。',
		probeStart: { x: 0, y: 18 },
		planets: [
			// 第一级：木星。第二级：土星。第三级：一颗微型引力节点（半径 0.6 的小天体，gm 却不小）。
			{ gm: 2240, radius: 3.56, orbitCenter: { x: 5, y: -2 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			{ gm: 1600, radius: 3.31, orbitCenter: { x: -7, y: -18 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			{ gm: 300, radius: 0.6, orbitCenter: { x: -16, y: -27 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 目标：海王星（无引力）。
			{ gm: 0, radius: 2.31, orbitCenter: { x: -26, y: -42 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 3.56, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 3.31, ring: true, model: 'Planet_Saturn' },
			// 微型节点用单位球（k=1 ⇒ 显示半径与撞毁半径精确相等）；换成 Asteroid_01.glb 必须先实测它的 k。
			{ r: 0.52, g: 0.50, b: 0.46, displayRadius: 0.6, ring: false },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: 2.31, ring: false, model: 'Planet_Neptune' },
		],
		goal: { kind: 'planet', planetIndex: 3, tolerance: 5.31 },
		escapeRadius: 400,
		maxSteps: 1800,
		homeRadius: 0.85,
	},
	{
		id: 6,
		title: '单程',
		brief: '最后一次点火。四颗巨行星串成一条路，飞出太阳系 —— 没有回程。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 木星：公转半径 10 / 周期 5s（轨道速度 12.6 —— 全局唯一能把探测器真正加速到逃逸的引擎）。
			{ gm: 2600, radius: 3.56, orbitCenter: { x: 0, y: -10 }, orbitRadius: 10, orbitPeriod: 5, phase0: 3.141592653589793, orbitDirection: 1 },
			// 后三颗：既是风景也是路标（gm 小，只做轻微修正，负责把「串成一条路」演出来）。
			{ gm: 700, radius: 3.31, orbitCenter: { x: -14, y: -30 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			{ gm: 350, radius: 2.34, orbitCenter: { x: 15, y: -32 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			{ gm: 250, radius: 2.31, orbitCenter: { x: -22, y: -40 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 3.56, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 3.31, ring: true, model: 'Planet_Saturn' },
			{ r: 0.62, g: 0.82, b: 0.86, displayRadius: 2.34, ring: false, model: 'Planet_Uranus' },
			{ r: 0.34, g: 0.50, b: 0.86, displayRadius: 2.31, ring: false, model: 'Planet_Neptune' },
		],
		// 逃逸半径 400：直射最远只能飞 366（22 × 15s），**不借力就是飞不出去**。
		goal: { kind: 'escape', planetIndex: -1, tolerance: 0 },
		escapeRadius: 400,
		// 2400 步 = 20 秒物理时间；逃逸必须在这段时间里发生，所以只能靠加速而不是靠拖时间。
		maxSteps: 2400,
		homeRadius: 0.75,
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

/**
 * 应用全局倍率，返回可直接喂给 createGame 的行星数组。
 * 不修改关卡原始数据。
 */
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

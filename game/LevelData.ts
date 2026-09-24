/**
 * 关卡数据（S2.1）。
 *
 * 六关曲线（愿景 §5，每关只引入一个新旋钮）：
 *
 * | 关 | 旋钮 | 学到什么 |
 * |---|---|---|
 * | 1 直飞 | 无引力 | 拖、看线、松手 |
 * | 2 第一次弯曲 | 一颗静止行星 | 轨迹会被引力掰弯 |
 * | 3 从背后抄过去 | 必须借力 | 后方加速、前方减速 |
 * | 4 它动了 | 行星公转 | 发射时机 |
 * | 5 两连弹 | 两颗行星 | 规划多段弹弓 |
 * | 6 贴着过去 | 容差收窄 | 精度 |
 *
 * 坐标约定：探测器从 +y 侧出发，向 -y（屏幕深处）飞行。
 *
 * 结算（手册 §5.8）：
 * - 成功 = 进入目标行星的到达容差（未撞毁），或达成 escape 目标
 * - 错过 = 超时 / 越界仍未命中
 * - 撞毁 = 与任一行星中心距离 < 半径
 *
 * 本模块**纯数据 + 纯函数**，不 import 'Dora'，可单测。
 * 可玩性由 `Test/LevelDataTest.ts` 的速度扫掠守着（每关至少一个可行解）。
 */
import { Body, P2, bodyPositionAt, distance } from 'game/Gravity';
import { GravityScale, OrbitSpeedScale } from 'game/Config';

/** 行星视觉描述（与 Scene.PlanetVisual 结构兼容，避免跨模块依赖）。 */
export interface PlanetVisualDef {
	r: number;
	g: number;
	b: number;
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
	title: string;
	/** 关间一句任务简报（愿景 §8）。 */
	brief: string;
	probeStart: P2;
	planets: Body[];
	visuals: PlanetVisualDef[];
	goal: GoalSpec;
	escapeRadius: number;
	maxSteps: number;
}

/**
 * 在飞行采样点中找第一个进入目标容差的索引。
 *
 * 目标行星在移动，所以逐点用 `t = i * dt` 时的行星位置判定。
 * 返回 -1 表示未到达。
 */
export function findGoalIndex(points: P2[], bodies: Body[], goal: GoalSpec, dt: number): number {
	if (goal.kind !== 'planet') return -1;
	const body = bodies[goal.planetIndex];
	if (body === undefined) return -1;
	for (let i = 0; i < points.length; i++) {
		const gp = bodyPositionAt(body, i * dt);
		if (distance(points[i], gp) < goal.tolerance) return i;
	}
	return -1;
}

// ---------------------------------------------------------------------------
// 六关数据
// ---------------------------------------------------------------------------

const LEVELS: LevelDef[] = [
	{
		id: 1,
		title: '直飞',
		brief: '1977 年，旅行者号启程。先学会瞄准：拖动，看线，松手。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 目标星：火星（无引力，纯靶子）
			{ gm: 0, radius: 1.2, orbitCenter: { x: 0, y: -30 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.80, g: 0.45, b: 0.30, displayRadius: 1.2, ring: false, model: 'Planet_Mars' },
		],
		goal: { kind: 'planet', planetIndex: 0, tolerance: 3.0 },
		escapeRadius: 400,
		maxSteps: 1500,
	},
	{
		id: 2,
		title: '第一次弯曲',
		brief: '金唱片已上路。注意：引力会掰弯你的航线。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 金星：挡在航线右侧，把轨迹往右拽
			{ gm: 700, radius: 1.8, orbitCenter: { x: 7, y: -4 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 目标星：火星
			{ gm: 0, radius: 1.2, orbitCenter: { x: -2, y: -32 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.90, g: 0.78, b: 0.55, displayRadius: 1.8, ring: false, model: 'Planet_Venus' },
			{ r: 0.80, g: 0.45, b: 0.30, displayRadius: 1.2, ring: false, model: 'Planet_Mars' },
		],
		goal: { kind: 'planet', planetIndex: 1, tolerance: 3.0 },
		escapeRadius: 400,
		maxSteps: 1500,
	},
	{
		id: 3,
		title: '从背后抄过去',
		brief: '燃料只够一次发射。借木星的引力，从背后抄过去。',
		probeStart: { x: 0, y: 18 },
		planets: [
			// 木星：巨大的引力源，挡在正前方
			{ gm: 1500, radius: 2.6, orbitCenter: { x: 0, y: -2 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 目标星：土星（带环），藏在木星侧后方
			{ gm: 0, radius: 1.4, orbitCenter: { x: -26, y: -26 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 2.6, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 1.4, ring: true, model: 'Planet_Saturn' },
		],
		goal: { kind: 'planet', planetIndex: 1, tolerance: 3.0 },
		escapeRadius: 400,
		maxSteps: 1800,
	},
	{
		id: 4,
		title: '它动了',
		brief: '行星不会等你。算好它到位的时机。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 火星：绕原点公转，它既是障碍也是目标
			{ gm: 500, radius: 1.6, orbitCenter: { x: 0, y: -6 }, orbitRadius: 9, orbitPeriod: 9, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.80, g: 0.45, b: 0.30, displayRadius: 1.6, ring: false, model: 'Planet_Mars' },
		],
		goal: { kind: 'planet', planetIndex: 0, tolerance: 3.2 },
		escapeRadius: 400,
		maxSteps: 1800,
	},
	{
		id: 5,
		title: '两连弹',
		brief: '两颗巨行星排成一线。规划两次弹弓。',
		probeStart: { x: 0, y: 18 },
		planets: [
			// 木星：第一级弹弓
			{ gm: 1400, radius: 2.4, orbitCenter: { x: 5, y: -2 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 土星：第二级弹弓（带环）
			{ gm: 1000, radius: 2.2, orbitCenter: { x: -7, y: -18 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
			// 目标星：天王星
			{ gm: 0, radius: 1.3, orbitCenter: { x: -20, y: -34 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.85, g: 0.72, b: 0.50, displayRadius: 2.4, ring: false, model: 'Planet_Jupiter' },
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 2.2, ring: true, model: 'Planet_Saturn' },
			// 天王星：库里没有 Uranus，用 Planet_Neptune 代用，靠青蓝色染色区分
			{ r: 0.55, g: 0.75, b: 0.80, displayRadius: 1.3, ring: false, model: 'Planet_Neptune' },
		],
		goal: { kind: 'planet', planetIndex: 2, tolerance: 3.0 },
		escapeRadius: 400,
		maxSteps: 1800,
	},
	{
		id: 6,
		title: '贴着过去',
		brief: '最后一次机会。贴着土星环过去，别碰它。',
		probeStart: { x: 0, y: 16 },
		planets: [
			// 土星：目标就是它 —— 掠过而不撞上（容差只比半径大一点）
			{ gm: 1100, radius: 1.6, orbitCenter: { x: 4, y: -6 }, orbitRadius: 0, orbitPeriod: 0, phase0: 0, orbitDirection: 1 },
		],
		visuals: [
			{ r: 0.75, g: 0.70, b: 0.60, displayRadius: 1.6, ring: true, model: 'Planet_Saturn' },
		],
		goal: { kind: 'planet', planetIndex: 0, tolerance: 2.2 },
		escapeRadius: 400,
		maxSteps: 1800,
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
